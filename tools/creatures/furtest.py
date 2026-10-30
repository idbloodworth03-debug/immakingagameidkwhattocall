"""Quick look at a creature with and without fur, from a card angle."""
import importlib
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "species"))

import bpy
import numpy as np
from PIL import Image

import fur
import motion
import scene as S


def shoot(species, out, with_fur, size=420, samples=64):
    creature = importlib.import_module(species).make()
    sc = S.reset()
    sc.cycles.samples = samples
    arm, body, mesh = S.build(creature, with_fur=with_fur)
    motion.apply(arm, motion.idle(creature, 0.0))
    S.lights(1.1)
    S.shadow_catcher(8)
    lo, hi = mesh.verts.min(axis=0), mesh.verts.max(axis=0)
    rest = np.array(arm["rest_offset"])
    center = (lo + hi) / 2 + rest
    radius = float(np.linalg.norm(hi - lo)) / 2
    d = np.array([-0.75, 1.0, 0.55])
    d /= np.linalg.norm(d)
    S.perspective_camera(tuple(center + d * radius * 3.4), tuple(center), lens=85)
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.filepath = out
    t = time.time()
    bpy.ops.render.render(write_still=True)
    print("render", round(time.time() - t, 1), "s")


if __name__ == "__main__":
    species, out = sys.argv[1], sys.argv[2]
    shoot(species, out + "_bare.png", False)
    shoot(species, out + "_fur.png", True)
    a = Image.open(out + "_bare.png").convert("RGBA")
    b = Image.open(out + "_fur.png").convert("RGBA")
    sheet = Image.new("RGBA", (a.width * 2, a.height), (70, 115, 75, 255))
    sheet.alpha_composite(a, (0, 0))
    sheet.alpha_composite(b, (a.width, 0))
    sheet.save(out + ".png")
    print("saved", out + ".png")
