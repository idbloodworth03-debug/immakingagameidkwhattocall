"""How well each animal's attacks read from the game's camera, in numbers.

    python strike_check.py                 # every animal on the roster of strikes.json
    python strike_check.py brown_bear wolf_pack
    python strike_check.py --all           # every toy, the ones still on their old attacks too

It plays the attack clips of an animal's built model (art_sources/own/
<id>_LOD1.glb: build it first, tools/toys/build.py) and looks at it the way
the game does: from behind (your own animals) and from the front (the
enemy's), looking down as feel.json "camera" says. For each clip:

    wind-up  the most its outline differs from its outline as the clip
             starts, before the hit, as a share of that outline's area
             (newly covered plus uncovered)
    swing    the most its outline from the hit on (the strike and the
             follow-through) differs from that wind-up's
    tall     its tallest moment on the screen against the start (bodies.json
             "limits" pose_allowance is the most the camera makes room for)
    ahead    how far its front is past where it stood, at the hit and at
             most, in field tiles, against the reach rule's allowance
             (strikes.py), and what the rule drew in to keep it there

A clip under the standard (strikes.json "standard") is marked "low": its
wind-up or its strike would not be seen in a fight. tools/creatures/README.md
("Attacks") has the standard and where it comes from.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "..", "..")
sys.path[:0] = [os.path.join(REPO, "tools", "toys"), os.path.join(REPO, "tools", "packs"), HERE]

import bpy
import numpy as np
from PIL import Image, ImageDraw

import build as B
import motion
import strikes

OWN = os.path.join(REPO, "art_sources", "own")
RES = 110
MOMENTS = 25


def _mesh():
    """The scene's posed triangles: (points Nx3, triangles Mx3)."""
    graph = bpy.context.evaluated_depsgraph_get()
    points, triangles, base = [], [], 0
    for ob in bpy.context.scene.objects:
        # (Only the animal: the importer's own helper shapes are not it.)
        if ob.type != "MESH" or not any(m.type == "ARMATURE" for m in ob.modifiers):
            continue
        posed = ob.evaluated_get(graph)
        me = posed.to_mesh()
        me.calc_loop_triangles()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        m = np.array(posed.matrix_world)
        co = co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
        tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("vertices", tri)
        points.append(co)
        triangles.append(tri.reshape(-1, 3) + base)
        base += len(co)
        posed.to_mesh_clear()
    return np.concatenate(points), np.concatenate(triangles)


def _screen(points, front, down):
    """Where points are on the screen (right, up), seen from behind or from
    the front by a camera looking `down` radians below level."""
    sign = -1.0 if front else 1.0
    return np.stack([points[:, 0] * sign, points[:, 2] * math.cos(down) + sign * points[:, 1] * math.sin(down)], axis=1)


def _outline(xy, triangles, low, size):
    im = Image.new("1", (RES, RES), 0)
    draw = ImageDraw.Draw(im)
    p = (xy - low) / size * RES
    p[:, 1] = RES - p[:, 1]
    for a, b, c in triangles:
        draw.polygon([tuple(p[a]), tuple(p[b]), tuple(p[c])], fill=1)
    return np.array(im, dtype=bool)


def check(name, down):
    """[{clip, style, hit, behind: (wind-up, strike), front: (wind-up,
    strike), tall, ...}] for an animal's attack clips."""
    path = os.path.join(OWN, name + "_LOD1.glb")
    if not os.path.exists(path):
        raise SystemExit(f"{path} is not built: python tools/toys/build.py {name}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    arm.animation_data_create()
    c = B.design(name).make().creature
    rows = []
    for clip in ("attack", "attack2", "special"):
        action = bpy.data.actions.get(clip)
        if action is None:
            continue
        style = "special" if clip == "special" else c.motion[clip]
        hit = motion.HIT_AT.get(style, 0.45)
        arm.animation_data.action = action
        first, last = action.frame_range
        moments = sorted(set([i / (MOMENTS - 1) for i in range(MOMENTS)] + [hit]))
        shapes = []
        for t in moments:
            at = first + (last - first) * t
            bpy.context.scene.frame_set(int(at), subframe=at - int(at))
            bpy.context.view_layer.update()
            shapes.append(_mesh())
        row = {"clip": clip, "style": style, "hit": hit, "new": strikes.has(c, style)}
        tall = 0.0
        for view, front in (("behind", False), ("front", True)):
            flat = [_screen(points, front, down) for points, _ in shapes]
            low = np.min([p.min(axis=0) for p in flat], axis=0)
            high = np.max([p.max(axis=0) for p in flat], axis=0)
            size = float(max(high - low)) * 1.04
            low = (low + high) / 2 - size / 2
            outlines = [_outline(p, triangles, low, size) for p, (_, triangles) in zip(flat, shapes)]
            area = float(outlines[0].sum())
            change = [float((o ^ outlines[0]).sum()) / area for o in outlines]
            before = [i for i, t in enumerate(moments) if t < hit - 0.04]
            after = [i for i, t in enumerate(moments) if t >= hit - 1e-6]
            wound = max(before, key=lambda i: change[i]) if before else 0
            # The wind-up against the start, and the blow against the wind-up.
            row[view] = (change[wound], max(float((outlines[i] ^ outlines[wound]).sum()) / area for i in after))
            stands = float(flat[0][:, 1].max() - flat[0][:, 1].min())
            tall = max(tall, max(float(p[:, 1].max() - p[:, 1].min()) for p in flat) / stands)
        row["tall"] = tall
        if row["new"]:
            made = strikes.clip(c, style, hit)
            if made.keep(motion, c) is not None:
                tile = float(strikes._BODIES["models"][name]["tile_scale"])
                row["travel"] = {k: (v * tile if isinstance(v, float) and k != "gain" else v) for k, v in made.travel.items()}
                row["allowed"] = tuple(v * tile for v in made.travel["allowed"])
        rows.append(row)
    return rows


def main():
    argv = [a for a in sys.argv[1:] if a != "--"]
    names = [a for a in argv if not a.startswith("--")]
    if "--all" in argv:
        names = sorted(os.path.basename(p)[:-3] for p in __import__("glob").glob(os.path.join(REPO, "tools", "toys", "animals", "*.py")))
    elif not names:
        names = list(strikes.DATA.get("roster", []))
    feel = json.load(open(os.path.join(REPO, "game", "data", "feel.json")))
    limits = json.load(open(os.path.join(REPO, "game", "data", "bodies.json")))["limits"]
    down = math.radians(90.0 - float(feel["camera"]["tilt_degrees"]))
    standard = strikes.DATA["standard"]
    wind, swing, roof = float(standard["windup"]), float(standard["swing"]), float(limits["pose_allowance"])
    lines, low = [], 0
    for name in names:
        for row in check(name, down):
            marks = []
            if min(row["behind"][0], row["front"][0]) < wind or min(row["behind"][1], row["front"][1]) < swing:
                marks.append("low")
            if row["tall"] > roof:
                marks.append("TALL")
            low += bool(marks) and row["new"]
            line = "%-24s %-8s %-12s behind %.2f / %.2f   front %.2f / %.2f   tall %.2f" % (
                name, row["clip"], row["style"] + ("" if row["new"] else " (old)"), row["behind"][0], row["behind"][1],
                row["front"][0], row["front"][1], row["tall"])
            if "travel" in row:
                t = row["travel"]
                line += "   ahead %.2f at the hit, %.2f at most (allowed %.2f, %.2f)" % (t["ahead_at_hit"], t["ahead_most"], row["allowed"][0], row["allowed"][1])
                if t["gain"] != 1.0 or t["held"] > 0.005:
                    line += "; its steps x%.2f%s" % (t["gain"], ", its body held back %.2f" % t["held"] if t["held"] > 0.005 else "")
            lines.append(line + ("   " + " ".join(marks) if marks else ""))
    print("%-24s %-8s %-12s outline change: wind-up (at least %.2f) / swing into the blow (at least %.2f); tallest (at most %.2f); travel in field tiles" % (
        "animal", "clip", "style", wind, swing, roof))
    print("\n".join(lines))
    print(f"{len(lines)} clips; {low} of the new ones under the standard")


if __name__ == "__main__":
    main()
