"""Renders a creature from a few angles onto one sheet, to check its shape
and colors.

    python preview.py red_fox out.png [pose]
"""
import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "species"))

import bpy
from mathutils import Vector
from PIL import Image

import cartoon
import scene as S


def main(species, out, pose=None, size=480):
    creature = cartoon.load(species, style=os.environ.get("STYLE", "cartoon"))
    sc = S.reset()
    sc.cycles.samples = 64
    arm, body, mesh = S.build(creature)
    if pose:
        import motion
        motion.preview_pose(arm, creature, pose)
    S.lights()
    S.shadow_catcher(8)
    if getattr(creature, "style", "") == "cartoon":
        S.outline(2.5)
    lo, hi = mesh.verts.min(axis=0), mesh.verts.max(axis=0)
    center = (lo + hi) / 2
    span = float(max(hi - lo)) * 1.25
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    views = []
    tmp = out + ".part{}.png"

    def shoot(i):
        sc.render.filepath = tmp.format(i)
        bpy.ops.render.render(write_still=True)
        views.append(tmp.format(i))

    # 1: side, 2: front three-quarter (perspective), 3: game angle, 4: top
    cam = S.perspective_camera((-span * 2.0, center[1], center[2] + 0.05), center, lens=70)
    shoot(1)
    bpy.data.objects.remove(cam)
    cam = S.perspective_camera((-span * 1.1, center[1] + span * 1.5, center[2] + span * 0.5), center, lens=70)
    shoot(2)
    bpy.data.objects.remove(cam)
    arm.rotation_euler = (0, 0, -math.pi / 2)
    cam = S.ortho_camera(50, span * 1.05, target=(0, 0, center[2]))
    shoot(3)
    bpy.data.objects.remove(cam)
    arm.rotation_euler = (0, 0, 0)
    cam = S.ortho_camera(89.9, span * 1.05, target=(0, center[1], center[2]))
    shoot(4)

    sheet = Image.new("RGBA", (size * 2, size * 2), (96, 140, 80, 255))
    for i, path in enumerate(views):
        im = Image.open(path).convert("RGBA")
        sheet.alpha_composite(im, ((i % 2) * size, (i // 2) * size))
        os.remove(path)
    sheet.save(out)
    print("saved", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
