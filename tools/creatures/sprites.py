"""Renders a creature's battle sprites and its card portrait.

    python sprites.py red_fox [--out game/art/units] [--samples 32]

Writes <out>/<id>/sheet.webp (every frame of every animation and direction)
and sheet.json (where each frame is, the anchor point under the animal, and
animation timing), plus portrait.webp for the card.

The camera looks down at 50 degrees like the game's view. Five directions
are rendered (facing up, up-right, right, down-right, down); the game
mirrors them for the left-facing ones, so the key light comes from straight
above the viewer to keep mirrored frames lit the same.
"""
import argparse
import importlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "species"))

import bpy
import numpy as np
from PIL import Image

import motion
import cartoon
import scene as S

ELEVATION = 50.0
PIXELS_PER_TILE = 56
DIRECTIONS = [0, 45, 90, 135, 180]      # degrees clockwise from "facing up the screen"
PADDING = 3                             # empty pixels around each frame in the sheet


def clean_alpha(im, floor=14):
    """Drops the faint speckle the shadow catcher leaves across the ground."""
    im = im.copy()
    a = im[:, :, 3].astype(float)
    im[:, :, 3] = np.clip((a - floor) * 255.0 / (255 - floor), 0, 255).astype(np.uint8)
    return im


MAX_SHEET = 4096                        # pixels on a side, the most phones take


def pack(crops, timing, hit, anchors, pixels_per_tile=PIXELS_PER_TILE):
    """Packs every frame into one sheet. `crops` maps (anim, dir) to RGBA
    arrays, all the same size within an animation (each animation is
    cropped to its own box, so a rearing victory doesn't make every idle
    frame bigger); `anchors` maps anim to the anchor point in its frames;
    `timing` maps anim to (frames, fps, loops); `hit` maps each attack to
    the share of it where the blow lands. Frames are shelf-packed, tallest
    first, into the narrowest near-square sheet; each animation records its
    frame size, anchor and where each frame of each direction is."""
    items = []
    for (anim, d), images in crops.items():
        for f, im in enumerate(images):
            items.append((im.shape[0] + PADDING * 2, im.shape[1] + PADDING * 2, anim, d, f, im))
    items.sort(key=lambda it: (-it[0], it[2], it[3], it[4]))
    area = sum(h * w for h, w, *_ in items)
    widest = max(w for h, w, *_ in items)

    def shelves(width):
        spots, x, y, shelf = {}, 0, 0, 0
        for h, w, anim, d, f, im in items:
            if x + w > width:
                x, y, shelf = 0, y + shelf, 0
            spots[(anim, d, f)] = (x + PADDING, y + PADDING)
            x += w
            shelf = max(shelf, h)
        return spots, y + shelf

    best = None
    for k in np.linspace(0.9, 1.4, 11):
        width = max(widest, int(math.ceil(math.sqrt(area) * k)))
        spots, height = shelves(width)
        side = max(width, height)
        if best is None or side < best[0]:
            best = (side, width, height, spots)
    side, width, height, spots = best
    if side > MAX_SHEET:
        raise SystemExit(f"the sheet would be {width}x{height}, over {MAX_SHEET} on a side")
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    meta = {
        "version": 3,
        "padding": PADDING,
        "pixels_per_tile": pixels_per_tile,
        "directions": DIRECTIONS,
        "animations": {},
    }
    for anim, (count, fps, loops) in timing.items():
        im0 = crops[(anim, DIRECTIONS[0])][0]
        info = {"frames": count, "fps": fps, "loop": loops,
                "cell": [int(im0.shape[1]), int(im0.shape[0])],
                "anchor": [round(float(anchors[anim][0]), 1), round(float(anchors[anim][1]), 1)],
                "at": {}}
        if anim in hit:
            info["hit"] = hit[anim]
        for d in DIRECTIONS:
            info["at"][str(d)] = [list(spots[(anim, d, f)]) for f in range(len(crops[(anim, d)]))]
            for f, im in enumerate(crops[(anim, d)]):
                sheet.paste(Image.fromarray(im), spots[(anim, d, f)])
        meta["animations"][anim] = info
    return sheet, meta


def sprite_top(frames, anchor):
    """How far the animal's highest point rises above its anchor while
    idling, in pixels (the median over directions), for placing health bars."""
    tops = []
    for (anim, d), images in frames.items():
        if anim != "idle":
            continue
        rows = np.nonzero((images[0][:, :, 3] > 60).any(axis=1))[0]
        if len(rows):
            tops.append(anchor[1] - rows[0])
    return round(float(np.median(tops)), 1) if tops else 0.0


def existing_animations(out_dir):
    """The animations in the sheet already in out_dir (none if there isn't one)."""
    path = os.path.join(out_dir, "sheet.json")
    return list(json.load(open(path))["animations"]) if os.path.exists(path) else []


def _old_frames(out_dir, side, anchor, anims):
    """The frames of `anims` from the sheet already in out_dir, put back where
    they were in the full rendered frame. Only works while the creature's
    size and the camera are unchanged since that sheet was rendered."""
    meta = json.load(open(os.path.join(out_dir, "sheet.json")))
    missing = [a for a in anims if a not in meta["animations"]]
    if missing:
        raise SystemExit(f"{out_dir}: the old sheet has no {', '.join(missing)}; render those too")
    sheet = np.asarray(Image.open(os.path.join(out_dir, "sheet.webp")).convert("RGBA"))
    if meta.get("pixels_per_tile") != PIXELS_PER_TILE:
        raise SystemExit(f"{out_dir}: the old sheet is at another scale; render every animation")
    frames = {}
    for anim in anims:
        info = meta["animations"][anim]
        if info["frames"] != motion.ANIMATIONS[anim][1]:
            raise SystemExit(f"{out_dir}: {anim} has a different frame count now; render it again too")
        if meta.get("version") == 3:
            cw, ch = info["cell"]
            ax, ay = info["anchor"]
        else:
            cw, ch = meta["cell"]
            ax, ay = meta["anchor"]
        ox, oy = anchor[0] - ax, anchor[1] - ay
        if not (abs(ox - round(ox)) < 0.2 and abs(oy - round(oy)) < 0.2
                and 0 <= ox and ox + cw <= side and 0 <= oy and oy + ch <= side):
            raise SystemExit(f"{out_dir}: the old sheet doesn't line up with this creature (offset {ox:.2f}, {oy:.2f}, "
                             f"cell {cw}x{ch} in a {side} frame); render every animation")
        ox, oy = int(round(ox)), int(round(oy))
        for d in DIRECTIONS:
            images = []
            for f in range(info["frames"]):
                if meta.get("version") == 3:
                    x, y = info["at"][str(d)][f]
                else:
                    pad, cols = meta["padding"], meta["columns"]
                    i = int(info["start"][str(d)]) + f
                    x, y = (i % cols) * (cw + pad * 2) + pad, (i // cols) * (ch + pad * 2) + pad
                full = np.zeros((side, side, 4), np.uint8)
                full[oy:oy + ch, ox:ox + cw] = sheet[y:y + ch, x:x + cw]
                images.append(full)
            frames[(anim, d)] = images
    return frames


def render_sprites(creature, out_dir, samples, with_fur=True, anims=None):
    """Renders every animation, or only those in `anims`, keeping the rest
    from the sheet already in out_dir."""
    sc = S.reset()
    sc.cycles.samples = samples
    # Keep the scene loaded between frames; only the pose changes.
    sc.render.use_persistent_data = True
    creature.fur["children"] = min(int(creature.fur.get("children", 8)), 6)
    arm, body, mesh = S.build(creature, with_fur=with_fur, fur_quality=0.5)
    facing = bpy.data.objects["facing"]
    S.lights()
    S.shadow_catcher(20)
    if getattr(creature, "style", "") == "cartoon":
        S.outline(1.4)

    lo, hi = mesh.verts.min(axis=0), mesh.verts.max(axis=0)
    # tiles_long is the animal's biggest size: nose to tail, or a bird's wingspan.
    length = float(max(hi[0] - lo[0], hi[1] - lo[1]))
    height = float(hi[2]) + float(creature.motion.get("altitude", 0.0))
    ppm = PIXELS_PER_TILE * creature.tiles_long / length          # pixels per meter
    side = int(math.ceil(max(length, height) * 1.7 * ppm / 2)) * 2
    target_z = height * 0.42
    cam = S.ortho_camera(ELEVATION, side / ppm, target=(0, 0, target_z))
    sc.render.resolution_x = side
    sc.render.resolution_y = side
    anchor = (side / 2, side / 2 + target_z * math.cos(math.radians(ELEVATION)) * ppm)

    # Work files go to the system temp folder, not into the game.
    import tempfile
    tmp = os.path.join(tempfile.gettempdir(), f"_{creature.name}_frame.png")
    frames = {}        # (anim, dir) -> list of RGBA arrays
    eyes = {}          # (anim, dir) -> per frame, each eye's [x, y, facing]
    eye_objects = [o for o in bpy.data.objects if o.type == "MESH" and "_eye_" in o.name]
    existing = existing_animations(out_dir)
    animations = motion.animations_for(creature, existing)
    if anims == "new":
        # Only what the sheet is missing; the rest is kept.
        anims = [a for a in animations if a not in existing]
    kept = [a for a in animations if anims is not None and a not in anims]
    if kept:
        frames.update(_old_frames(out_dir, side, anchor, kept))
    for anim, (fn, count, fps, loops) in animations.items():
        render = anims is None or anim in anims
        for d in DIRECTIONS:
            facing.rotation_euler = (0, 0, -math.radians(d))
            images = []
            spots = []
            for f in range(count):
                t = f / count if loops else f / max(count - 1, 1)
                motion.apply(arm, fn(creature, t))
                if anim == "death":
                    motion.rest_on_ground(arm, body)
                spots.append(_eye_spots(sc, cam, side, eye_objects))
                if render:
                    sc.render.filepath = tmp
                    bpy.ops.render.render(write_still=True)
                    images.append(clean_alpha(np.asarray(Image.open(tmp).convert("RGBA"))))
            eyes[(anim, d)] = spots
            if render:
                frames[(anim, d)] = images
                print(f"  {creature.name} {anim} {d}deg: {count} frames", flush=True)
    if os.path.exists(tmp):
        os.remove(tmp)

    # Crop each animation to the box that fits all its frames.
    crops, anchors = {}, {}
    for name in animations:
        alpha = np.zeros((side, side), bool)
        for d in DIRECTIONS:
            for im in frames[(name, d)]:
                alpha |= im[:, :, 3] > 6
        ys, xs = np.nonzero(alpha)
        x0, x1 = max(xs.min() - 1, 0), min(xs.max() + 2, side)
        y0, y1 = max(ys.min() - 1, 0), min(ys.max() + 2, side)
        for d in DIRECTIONS:
            crops[(name, d)] = [im[y0:y1, x0:x1] for im in frames[(name, d)]]
        anchors[name] = (anchor[0] - x0, anchor[1] - y0)
    timing = {anim: (count, fps, loops) for anim, (fn, count, fps, loops) in animations.items()}
    hit = {"attack": motion.HIT_AT.get(creature.motion.get("attack", "bite"), 0.45)}
    if "attack2" in animations:
        hit["attack2"] = motion.HIT_AT.get(creature.motion["attack2"], 0.45)
    if "special" in animations:
        hit["special"] = motion.HIT_AT["special"]
    sheet, meta = pack(crops, timing, hit, anchors)
    _add_eyes(meta, eyes, frames, eye_objects, anchor, ppm)
    meta["walk_cycle_tiles"] = round(creature.motion.get("cycle_tiles", creature.tiles_long * 0.75), 3)
    meta["top"] = sprite_top(frames, anchor)
    # Its body plan, for the game's way of moving it.
    meta["body"] = creature.motion.get("body") or ("biped" if creature.motion.get("gait") == "biped" else "quadruped")
    meta["attack_style"] = creature.motion.get("attack", "bite")
    if "attack2" in animations:
        meta["attack2_style"] = creature.motion["attack2"]

    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, "sheet.webp"), "WEBP", quality=90, method=6)
    with open(os.path.join(out_dir, "sheet.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    print(f"sheet {sheet.size[0]}x{sheet.size[1]}: " + ", ".join(f"{a} {i['cell'][0]}x{i['cell'][1]}" for a, i in meta["animations"].items()))


def _eye_spots(sc, cam, side, eye_objects):
    """Where each eye is in the rendered frame (pixels) and how squarely it
    faces the camera (1 straight at it, 0 edge-on, below 0 turned away)."""
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    bpy.context.view_layer.update()
    view = (cam.matrix_world.to_3x3() @ Vector((0, 0, -1))).normalized()
    spots = []
    for o in eye_objects:
        m = o.matrix_world
        uv = world_to_camera_view(sc, cam, m.translation)
        outward = (m.to_3x3() @ Vector((0, 0, 1))).normalized()
        spots.append([float(uv.x) * side, (1.0 - float(uv.y)) * side, float(-outward.dot(view))])
    return spots


def _add_eyes(meta, eyes, frames, eye_objects, anchor, ppm):
    """Writes where the eyes are into the sheet's data, for the game to draw
    blinks and faces over them: per animation and direction, per frame, each
    eye as [x, y] from the anchor (pixels in the sheet) or null when it
    faces away. Also how big an eye is and the color of the skin around it
    (sampled from the rendered idle, for eyelids)."""
    if not eye_objects:
        return
    # An eye's radius in pixels: its size in meters times pixels per meter.
    size = eye_objects[0].matrix_world.to_scale()
    radius = float(size[0] + size[1]) / 2 * ppm
    meta["eye_radius"] = round(radius, 2)
    out = {}
    for (anim, d), spots in eyes.items():
        per_frame = []
        for spot in spots:
            per_frame.append([[round(x - anchor[0], 1), round(y - anchor[1], 1)] if facing > 0.15 else None
                              for x, y, facing in spot])
        out.setdefault(anim, {})[str(d)] = per_frame
    meta["eyes"] = out
    # The skin just above an eye, from the idle facing down the screen.
    key = ("idle", 180) if ("idle", 180) in frames else next(iter(frames))
    im = frames[key][0]
    colors = []
    for x, y, facing in eyes[key][0]:
        if facing <= 0.15:
            continue
        for k in range(-2, 3):
            px, py = int(round(x + k * radius * 0.3)), int(round(y - radius * 1.45))
            if 0 <= py < im.shape[0] and 0 <= px < im.shape[1] and im[py, px, 3] > 200:
                rgb = im[py, px, :3].astype(float)
                if rgb.mean() > 40:           # skip the dark outline
                    colors.append(rgb)
    if colors:
        c = np.median(np.array(colors), axis=0)
        meta["lid_color"] = "#%02x%02x%02x" % tuple(int(v) for v in c)


def _scene_points():
    """World positions of every posed mesh vertex in the scene (body, ears,
    eyes, horns...), leaving out the ground."""
    deps = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.name == "ground":
            continue
        evaluated = obj.evaluated_get(deps)
        me = evaluated.to_mesh()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        evaluated.to_mesh_clear()
        m = np.array(obj.matrix_world)
        points.append(co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3])
    return np.concatenate(points)


def _fit_camera(cam, points, fill=0.88):
    """Pans and dollies a perspective camera, keeping its direction, until
    `points` are centered and span `fill` of the square frame. The head is
    nearest the camera and looks biggest, so aiming at the middle of the
    bounding box alone would push it out of the picture."""
    half = math.tan(cam.data.angle / 2)
    for _ in range(6):
        bpy.context.view_layer.update()
        view = np.array(cam.matrix_world.inverted())
        p = points @ view[:3, :3].T + view[:3, 3]           # camera space, looking down -Z
        depth = -p[:, 2]
        ndc = p[:, :2] / depth[:, None] / half
        lo, hi = ndc.min(axis=0), ndc.max(axis=0)
        center = (lo + hi) / 2
        extent = float(max(hi - lo)) / 2
        dist = float(depth.mean())
        axes = np.array(cam.matrix_world)[:3, :3]           # right, up, back
        shift = axes[:, 0] * center[0] * half * dist + axes[:, 1] * center[1] * half * dist
        shift += axes[:, 2] * dist * (extent / fill - 1)
        cam.location = tuple(np.array(cam.location) + shift)


def render_portrait(creature, out_dir, samples, size=512, with_fur=True):
    """The whole animal from a three-quarter front view, for its card."""
    sc = S.reset()
    sc.cycles.samples = max(samples * 3, 64)
    arm, body, mesh = S.build(creature, with_fur=with_fur)
    motion.apply(arm, motion.idle(creature, 0.0))
    S.lights(1.1)
    S.shadow_catcher(8)
    if getattr(creature, "style", "") == "cartoon":
        S.outline(3.0)
    lo, hi = mesh.verts.min(axis=0), mesh.verts.max(axis=0)
    center = (lo + hi) / 2 + np.array(arm["rest_offset"])
    radius = float(np.linalg.norm(hi - lo)) / 2
    d = np.array(creature.motion.get("portrait_view", (-0.75, 1.0, 0.55)), float)
    d /= np.linalg.norm(d)
    cam = S.perspective_camera(tuple(center + d * radius * 3.1), tuple(center), lens=85)
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    _fit_camera(cam, _scene_points())
    import tempfile
    path = os.path.join(tempfile.gettempdir(), f"_{creature.name}_portrait.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    im = Image.fromarray(clean_alpha(np.asarray(Image.open(path).convert("RGBA"))))
    im.save(os.path.join(out_dir, "portrait.webp"), "WEBP", quality=92, method=6)
    os.remove(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("species")
    parser.add_argument("--out", default=os.path.join(HERE, "..", "..", "game", "art", "units"))
    parser.add_argument("--samples", type=int, default=20)
    parser.add_argument("--only", choices=["sprites", "portrait"])
    parser.add_argument("--bare", action="store_true", help="no fur strands (much faster, for testing)")
    parser.add_argument("--style", choices=["cartoon", "real"], default="cartoon",
                        help="cartoon (big head and eyes, outlined) or real proportions with fur")
    parser.add_argument("--anims", help="comma-separated animations to render again, keeping the others "
                        "from the existing sheet (e.g. --anims fidget --only sprites); 'new' renders only the "
                        "animations the sheet doesn't have yet")
    args = parser.parse_args()
    creature = cartoon.load(args.species, style=args.style)
    out_dir = os.path.join(args.out, args.species)
    os.makedirs(out_dir, exist_ok=True)
    if args.only != "portrait":
        anims = None if not args.anims else "new" if args.anims == "new" else args.anims.split(",")
        render_sprites(creature, out_dir, args.samples, with_fur=not args.bare, anims=anims)
    if args.only != "sprites":
        render_portrait(creature, out_dir, args.samples, with_fur=not args.bare)


if __name__ == "__main__":
    main()
