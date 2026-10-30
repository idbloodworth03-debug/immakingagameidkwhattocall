"""Renders one animation as a row of frames seen from the side (and a second
row from the game's camera angle), to check the motion.

    python strip.py red_fox walk out.png
"""
import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "species"))

import bpy
from PIL import Image

import motion
import scene as S


def main(species, anim, out, size=220):
    creature = importlib.import_module(species).make()
    sc = S.reset()
    sc.cycles.samples = 24
    arm, body, mesh = S.build(creature)
    facing = bpy.data.objects["facing"]
    S.lights()
    S.shadow_catcher(8)
    span = float(max(mesh.verts.max(axis=0) - mesh.verts.min(axis=0))) * 1.3
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    fn, frames, _, loops = motion.ANIMATIONS[anim]
    rows = [(5, span * 0.62), (50, span * 1.0)]
    sheet = Image.new("RGBA", (size * frames, size * len(rows)), (96, 140, 80, 255))
    facing.rotation_euler = (0, 0, -math.pi / 2)
    for r, (elevation, z) in enumerate(rows):
        cam = S.ortho_camera(elevation, span, target=(0, 0, span * 0.25))
        for f in range(frames):
            t = f / frames if loops else f / (frames - 1)
            motion.apply(arm, fn(creature, t))
            if anim == "death":
                motion.rest_on_ground(arm, body)
            path = f"{out}.f{f}.png"
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)
            sheet.alpha_composite(Image.open(path).convert("RGBA"), (f * size, r * size))
            os.remove(path)
        bpy.data.objects.remove(cam)
    sheet.save(out)
    print("saved", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
