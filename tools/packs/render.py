"""Renders a pack animal's card portrait and battle sprites.

    python render.py test_colobus --pack <the pack's folder>
    python render.py test_colobus --pack <folder> --only portrait
    python render.py --all --pack <folder>

Writes game/art/units/<id>/portrait.webp (the card: the animal in its hero
pose, packs.json "hero"), sheet.webp (every frame of every animation from
five directions; more pages for a big animal) and sheet.json, in the same
formats tools/creatures/sprites.py writes, so the game needs no changes:
the same battle camera angle, pixels per tile, key light from the front,
dark outline, and the standard card camera (look.json "hero_portrait").

What is tuned for flat-color art (packs.json "look"): cel shading in two
soft tones (a Toon shader instead of realistic skin), part of the color
unlit so the shade stays colorful, a big soft key light for soft shadows,
a slightly bolder palette, and one clean dark line round the animal.
"""
import argparse
import json
import math
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "creatures"))
sys.path.insert(0, os.path.join(HERE, "..", "creatures", "species"))

import bpy
import numpy as np
from mathutils import Vector
from PIL import Image

import pack as P
import scene as S
import sprites as SP

LOOK = P.SETTINGS["look"]
OUT = os.path.join(P.GAME, "art", "units")


def _material():
    """Flat-color cel shading: the palette color in two soft tones (a Toon
    shader), plus a share of it that shows whatever the light."""
    mat = bpy.data.materials.new("toon")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    for node in list(nodes):
        nodes.remove(node)
    color = nodes.new("ShaderNodeVertexColor")
    color.layer_name = "Col"
    hsv = nodes.new("ShaderNodeHueSaturation")
    hsv.inputs["Saturation"].default_value = float(LOOK["color"]["saturation"])
    hsv.inputs["Value"].default_value = float(LOOK["color"]["value"])
    links.new(color.outputs["Color"], hsv.inputs["Color"])
    toon = nodes.new("ShaderNodeBsdfToon")
    toon.component = "DIFFUSE"
    toon.inputs["Size"].default_value = float(LOOK["toon"]["size"])
    toon.inputs["Smooth"].default_value = float(LOOK["toon"]["smooth"])
    links.new(hsv.outputs["Color"], toon.inputs["Color"])
    glow = nodes.new("ShaderNodeEmission")
    glow.inputs["Strength"].default_value = float(LOOK["flat"])
    links.new(hsv.outputs["Color"], glow.inputs["Color"])
    add = nodes.new("ShaderNodeAddShader")
    links.new(toon.outputs[0], add.inputs[0])
    links.new(glow.outputs[0], add.inputs[1])
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(add.outputs[0], out.inputs["Surface"])
    return mat


def _stage(animal_id, where, smoothing=0):
    """The animal in a fresh scene, dressed for rendering (`smoothing`:
    subdivision rounds). Returns (scene, loaded, facing): turn `facing` to
    point it."""
    sc = S.reset()
    loaded = P.load(animal_id, int(P.SETTINGS["lods"]["render"]), where, encode="linear", fresh=False)
    facing = bpy.data.objects.new("facing", None)
    sc.collection.objects.link(facing)
    loaded.arm.parent = facing
    mat = _material()
    for ob in (loaded.body, loaded.face):
        if ob is None:
            continue
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        rounds = int(smoothing)
        if rounds > 0:
            mod = ob.modifiers.new("smooth", "SUBSURF")
            mod.levels = mod.render_levels = rounds
    return sc, loaded, facing


def _lights(strength=1.0):
    S.lights(strength)
    key = bpy.data.objects.get("key")
    if key is not None:
        # A big light: soft-edged shadows.
        key.data.angle = math.radians(float(LOOK["key_angle"]))


def _shadow(size):
    plane = S.shadow_catcher(size)
    return plane


def _hero(loaded, info):
    hero = info.get("hero", {})
    if "clip" in hero:
        P.apply(loaded.arm, P.sample(loaded.clips[hero["clip"]], float(hero.get("at", 0.0))))
    P.set_face(loaded, hero.get("face", {}))
    bpy.context.view_layer.update()
    return hero


def render_portrait(animal_id, where, out_dir, size=None):
    started = time.time()
    info = P.animal(animal_id)
    size = size or int(S.LOOK["portrait_size"])
    sc, loaded, facing = _stage(animal_id, where, LOOK.get("portrait_subdivide", 0))
    sc.cycles.samples = int(LOOK["portrait_samples"])
    hero = _hero(loaded, info)
    facing.rotation_euler = (0, 0, -math.radians(float(hero.get("turn", 0.0))))
    bpy.context.view_layer.update()
    _lights(1.1)
    pts = P.points(loaded)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    # Standing on the ground whatever the pose (a flier hovering over it).
    facing.location.z = -float(lo[2]) + float(hero.get("lift", 0.0))
    bpy.context.view_layer.update()
    pts = P.points(loaded)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    _shadow(8)
    S.outline(float(LOOK["outline"]["portrait_pixels"]) * size / 512.0, color=LOOK["outline"]["color"])
    center = (lo + hi) / 2
    radius = float(np.linalg.norm(hi - lo)) / 2
    # The same camera as every card (tools/creatures/look.json "hero_portrait").
    view = S.LOOK.get("hero_portrait", {})
    d = np.array(view.get("view", (-0.75, 1.0, 0.55)), float)
    d /= np.linalg.norm(d)
    cam = S.perspective_camera(tuple(center + d * radius * 3.1), tuple(center), lens=float(view.get("lens", 85)))
    sc.render.resolution_x = sc.render.resolution_y = size
    SP._fit_camera(cam, SP._scene_points(), fill=float(view.get("fill", 0.88)))
    path = os.path.join(tempfile.gettempdir(), f"_{animal_id}_portrait.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    im = Image.fromarray(SP.clean_alpha(np.asarray(Image.open(path).convert("RGBA"))))
    os.makedirs(out_dir, exist_ok=True)
    im.save(os.path.join(out_dir, os.environ.get("PORTRAIT_NAME", "portrait.webp")), "WEBP", lossless=True, quality=100, method=4)
    os.remove(path)
    print(f"[pack] {animal_id} portrait: {size}x{size} in {time.time() - started:.1f} s")


def clear_border(im, px=3):
    """The fast denoiser (packs.json "sprite_denoise") leaves a faint line
    along the picture's edge, which would stretch every frame's crop to the
    whole picture. The animal never comes near the edge (the picture is
    nearly twice its size), so the edge is cleared."""
    im = im.copy()
    im[:px, :, 3] = 0
    im[-px:, :, 3] = 0
    im[:, :px, 3] = 0
    im[:, -px:, 3] = 0
    return im


def _eye_pieces(loaded):
    """Each eye's vertices (indices into the face mesh): the pieces a blink
    moves."""
    face = loaded.face
    if face is None or face.data.shape_keys is None:
        return []
    me = face.data
    keys = me.shape_keys.key_blocks
    blink = keys.get("eyes.blink")
    if blink is None:
        return []
    n = len(me.vertices)
    base = np.empty(n * 3)
    keys[0].data.foreach_get("co", base)
    co = np.empty(n * 3)
    blink.data.foreach_get("co", co)
    moved = np.abs(co - base).reshape(-1, 3).max(axis=1) > 1e-6
    base = base.reshape(-1, 3)
    # Left and right of the middle (the pack's eyes mirror across x).
    left = np.nonzero(moved & (base[:, 0] > 0))[0]
    right = np.nonzero(moved & (base[:, 0] <= 0))[0]
    return [p for p in (left, right) if len(p)]


def _eye_spots(sc, cam, side, loaded, pieces):
    """Where each eye is in the frame (pixels) and how squarely it faces
    the camera, as tools/creatures/sprites.py records them."""
    from bpy_extras.object_utils import world_to_camera_view
    if not pieces:
        return []
    deps = bpy.context.evaluated_depsgraph_get()
    ev = loaded.face.evaluated_get(deps)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    normals = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", normals)
    ev.to_mesh_clear()
    m = np.array(loaded.face.matrix_world)
    world = co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
    wn = normals.reshape(-1, 3) @ m[:3, :3].T
    view = np.array((cam.matrix_world.to_3x3() @ Vector((0, 0, -1))).normalized())
    spots = []
    for piece in pieces:
        # (Subdivision adds vertices after the originals: these stay first.)
        c = world[piece].mean(axis=0)
        out = wn[piece].mean(axis=0)
        out /= max(np.linalg.norm(out), 1e-9)
        uv = world_to_camera_view(sc, cam, Vector(c))
        spots.append([float(uv.x) * side, (1.0 - float(uv.y)) * side, float(-out.dot(view))])
    return spots


def render_sprites(animal_id, where, out_dir, samples=None):
    started = time.time()
    info = P.animal(animal_id)
    sc, loaded, facing = _stage(animal_id, where, LOOK.get("sprite_subdivide", 0))
    sc.cycles.samples = int(samples or LOOK["sprite_samples"])
    denoise = LOOK.get("sprite_denoise", {})
    if denoise:
        sc.cycles.denoising_quality = denoise.get("quality", "HIGH")
        sc.cycles.denoising_prefilter = denoise.get("prefilter", "ACCURATE")
    sc.render.use_persistent_data = True
    clips = P.recipes(loaded, animal_id)
    _lights()
    _shadow(20)
    S.outline(float(LOOK["outline"]["sprite_pixels"]) * SP.PIXELS_PER_TILE / 56.0, color=LOOK["outline"]["color"])
    P.rest(loaded.arm)
    pts = P.points(loaded)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    length = float(max(hi[0] - lo[0], hi[1] - lo[1]))
    height = float(hi[2])
    ppm = SP.PIXELS_PER_TILE * float(info["tiles_long"]) / length
    side = int(math.ceil(max(length, height) * 1.9 * ppm / 2)) * 2
    target_z = height * 0.42
    cam = S.ortho_camera(SP.ELEVATION, side / ppm, target=(0, 0, target_z))
    sc.render.resolution_x = sc.render.resolution_y = side
    anchor = (side / 2, side / 2 + target_z * math.cos(math.radians(SP.ELEVATION)) * ppm)
    tmp = os.path.join(tempfile.gettempdir(), f"_{animal_id}_frame.png")
    pieces = _eye_pieces(loaded)
    frames, eyes = {}, {}
    timing = P.timing(animal_id)
    for anim, (count, fps, loops, hit) in timing.items():
        spec = clips[anim]
        for d in SP.DIRECTIONS:
            facing.rotation_euler = (0, 0, -math.radians(d))
            images, spots = [], []
            for f in range(count):
                p = f / count if loops else f / max(count - 1, 1)
                P.apply(loaded.arm, P.pose_at(loaded, spec, p, hit))
                bpy.context.view_layer.update()
                spots.append(_eye_spots(sc, cam, side, loaded, pieces))
                sc.render.filepath = tmp
                bpy.ops.render.render(write_still=True)
                images.append(clear_border(SP.clean_alpha(np.asarray(Image.open(tmp).convert("RGBA")))))
            frames[(anim, d)] = images
            eyes[(anim, d)] = spots
        print(f"  {animal_id} {anim}: {count} frames x {len(SP.DIRECTIONS)} directions", flush=True)
    if os.path.exists(tmp):
        os.remove(tmp)
    crops, anchors = {}, {}
    for name in timing:
        alpha = np.zeros((side, side), bool)
        for d in SP.DIRECTIONS:
            for im in frames[(name, d)]:
                alpha |= im[:, :, 3] > 6
        ys, xs = np.nonzero(alpha)
        x0, x1 = max(xs.min() - 1, 0), min(xs.max() + 2, side)
        y0, y1 = max(ys.min() - 1, 0), min(ys.max() + 2, side)
        for d in SP.DIRECTIONS:
            crops[(name, d)] = [im[y0:y1, x0:x1] for im in frames[(name, d)]]
        anchors[name] = (anchor[0] - x0, anchor[1] - y0)
    plain = {anim: (count, fps, loops) for anim, (count, fps, loops, hit) in timing.items()}
    hits = {anim: hit for anim, (count, fps, loops, hit) in timing.items() if hit is not None}
    pages, meta = SP.pack(crops, plain, hits, anchors)
    if pieces:
        P.rest(loaded.arm)
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        ev = loaded.face.evaluated_get(deps)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        m = np.array(loaded.face.matrix_world)
        world = co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
        radius = float(np.ptp(world[pieces[0]], axis=0).max()) / 2.0 * ppm
        meta["eye_radius"] = round(radius, 2)
        out = {}
        for (anim, d), spots in eyes.items():
            out.setdefault(anim, {})[str(d)] = [
                [[round(x - anchor[0], 1), round(y - anchor[1], 1)] if facing_k > 0.15 else None for x, y, facing_k in spot]
                for spot in spots]
        meta["eyes"] = out
        meta["lid_color"] = info.get("lid_color", "#7a5a3a")
    meta["walk_cycle_tiles"] = round(float(info.get("walk_cycle_tiles", float(info["tiles_long"]) * 0.75)), 3)
    meta["top"] = SP.sprite_top(frames, anchor)
    meta["body"] = info.get("body", "quadruped")
    meta["attack_style"] = info.get("attack_style", "bite")
    if "attack2" in timing:
        meta["attack2_style"] = info.get("attack2_style", meta["attack_style"])
    os.makedirs(out_dir, exist_ok=True)
    for i, page in enumerate(pages):
        page.save(os.path.join(out_dir, SP.page_name(i)), "WEBP", lossless=True, quality=100, method=4)
    i = len(pages)
    while os.path.exists(os.path.join(out_dir, SP.page_name(i))):
        os.remove(os.path.join(out_dir, SP.page_name(i)))
        if os.path.exists(os.path.join(out_dir, SP.page_name(i) + ".import")):
            os.remove(os.path.join(out_dir, SP.page_name(i) + ".import"))
        i += 1
    with open(os.path.join(out_dir, "sheet.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    count = sum(c for c, _, _, _ in timing.values()) * len(SP.DIRECTIONS)
    print(f"[pack] {animal_id} sprites: {count} frames of {side}x{side}, {len(pages)} page(s) "
          + ", ".join(f"{p.size[0]}x{p.size[1]}" for p in pages) + f" in {time.time() - started:.1f} s")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("animals", nargs="*")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--pack", default=None, help="the pack's folder (or PACK_DIR)")
    parser.add_argument("--only", choices=["sprites", "portrait"])
    parser.add_argument("--out", default=OUT)
    parser.add_argument("--samples", type=int, default=None)
    args = parser.parse_args(argv)
    where = P.pack_dir(args.pack)
    for animal_id in (list(P.SETTINGS["animals"]) if args.all else args.animals):
        out_dir = os.path.join(args.out, animal_id)
        if args.only != "sprites":
            render_portrait(animal_id, where, out_dir)
        if args.only != "portrait":
            render_sprites(animal_id, where, out_dir, args.samples)


if __name__ == "__main__":
    main()
