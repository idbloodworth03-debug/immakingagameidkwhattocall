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


def pack(crops, timing, hit, anchor, pixels_per_tile=PIXELS_PER_TILE):
    """Lays every frame out in a near-square grid. `crops` maps (anim, dir)
    to equally sized RGBA arrays; `timing` maps anim to (frames, fps, loops).
    Each animation and direction records where its first frame is."""
    first = next(iter(crops.values()))[0]
    cell_h, cell_w = first.shape[:2]
    total = sum(len(v) for v in crops.values())
    step_w, step_h = cell_w + PADDING * 2, cell_h + PADDING * 2
    columns = max(1, int(math.ceil(math.sqrt(total * step_h / step_w))))
    rows = int(math.ceil(total / columns))
    sheet = Image.new("RGBA", (columns * step_w, rows * step_h), (0, 0, 0, 0))
    meta = {
        "version": 2,
        "cell": [int(cell_w), int(cell_h)],
        "padding": PADDING,
        "columns": columns,
        "anchor": [round(float(anchor[0]), 1), round(float(anchor[1]), 1)],
        "pixels_per_tile": pixels_per_tile,
        "directions": DIRECTIONS,
        "animations": {},
    }
    index = 0
    for anim, (count, fps, loops) in timing.items():
        info = {"frames": count, "fps": fps, "loop": loops, "start": {}}
        if anim == "attack":
            info["hit"] = hit
        for d in DIRECTIONS:
            info["start"][str(d)] = index
            for im in crops[(anim, d)]:
                col, row = index % columns, index // columns
                sheet.paste(Image.fromarray(im), (col * step_w + PADDING, row * step_h + PADDING))
                index += 1
        meta["animations"][anim] = info
    return sheet, meta


def sprite_top(frames, anchor, y0=0):
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


def _old_frames(out_dir, side, anchor, anims):
    """The frames of `anims` from the sheet already in out_dir, put back where
    they were in the full rendered frame. Only works while the creature's
    size and the camera are unchanged since that sheet was rendered."""
    meta = json.load(open(os.path.join(out_dir, "sheet.json")))
    sheet = np.asarray(Image.open(os.path.join(out_dir, "sheet.webp")).convert("RGBA"))
    cw, ch = meta["cell"]
    pad, cols = meta["padding"], meta["columns"]
    ox, oy = anchor[0] - meta["anchor"][0], anchor[1] - meta["anchor"][1]
    lines_up = (meta.get("version") == 2 and meta.get("pixels_per_tile") == PIXELS_PER_TILE
                and abs(ox - round(ox)) < 0.2 and abs(oy - round(oy)) < 0.2
                and 0 <= ox and ox + cw <= side and 0 <= oy and oy + ch <= side)
    if not lines_up:
        raise SystemExit(f"{out_dir}: the old sheet doesn't line up with this creature (offset {ox:.2f}, {oy:.2f}, "
                         f"cell {cw}x{ch} in a {side} frame); render every animation")
    ox, oy = int(round(ox)), int(round(oy))
    frames = {}
    for anim in anims:
        info = meta["animations"][anim]
        if info["frames"] != motion.ANIMATIONS[anim][1]:
            raise SystemExit(f"{out_dir}: {anim} has a different frame count now; render it again too")
        for d in DIRECTIONS:
            images = []
            for f in range(info["frames"]):
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
    if anims:
        frames.update(_old_frames(out_dir, side, anchor, [a for a in motion.ANIMATIONS if a not in anims]))
    for anim, (fn, count, fps, loops) in motion.ANIMATIONS.items():
        if anims and anim not in anims:
            continue
        for d in DIRECTIONS:
            facing.rotation_euler = (0, 0, -math.radians(d))
            images = []
            for f in range(count):
                t = f / count if loops else f / max(count - 1, 1)
                motion.apply(arm, fn(creature, t))
                if anim == "death":
                    motion.rest_on_ground(arm, body)
                sc.render.filepath = tmp
                bpy.ops.render.render(write_still=True)
                images.append(clean_alpha(np.asarray(Image.open(tmp).convert("RGBA"))))
            frames[(anim, d)] = images
            print(f"  {creature.name} {anim} {d}deg: {count} frames", flush=True)
    os.remove(tmp)

    # Crop every frame to the box that fits them all.
    alpha = np.zeros((side, side), bool)
    for images in frames.values():
        for im in images:
            alpha |= im[:, :, 3] > 6
    ys, xs = np.nonzero(alpha)
    x0, x1 = max(xs.min() - 1, 0), min(xs.max() + 2, side)
    y0, y1 = max(ys.min() - 1, 0), min(ys.max() + 2, side)
    crops = {key: [im[y0:y1, x0:x1] for im in images] for key, images in frames.items()}
    timing = {anim: (count, fps, loops) for anim, (fn, count, fps, loops) in motion.ANIMATIONS.items()}
    hit = motion.HIT_AT.get(creature.motion.get("attack", "bite"), 0.45)
    sheet, meta = pack(crops, timing, hit, anchor=(anchor[0] - x0, anchor[1] - y0))
    meta["walk_cycle_tiles"] = round(creature.motion.get("cycle_tiles", creature.tiles_long * 0.75), 3)
    meta["top"] = sprite_top(frames, anchor, y0)
    meta["attack_style"] = creature.motion.get("attack", "bite")

    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, "sheet.webp"), "WEBP", quality=90, method=6)
    with open(os.path.join(out_dir, "sheet.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    print(f"sheet {sheet.size[0]}x{sheet.size[1]}, cell {meta['cell'][0]}x{meta['cell'][1]}")


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
    parser.add_argument("--anims", help="comma-separated animations to render again, keeping the others "
                        "from the existing sheet (e.g. --anims death --only sprites)")
    args = parser.parse_args()
    creature = importlib.import_module(args.species).make()
    out_dir = os.path.join(args.out, args.species)
    os.makedirs(out_dir, exist_ok=True)
    if args.only != "portrait":
        anims = args.anims.split(",") if args.anims else None
        render_sprites(creature, out_dir, args.samples, with_fur=not args.bare, anims=anims)
    if args.only != "sprites":
        render_portrait(creature, out_dir, args.samples, with_fur=not args.bare)


if __name__ == "__main__":
    main()
