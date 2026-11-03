"""Black Tortoise, the guardian of the north in Chinese star lore: a big,
wise, dark teal tortoise whose shell is traced with gold, with a friendly
green snake wound round the rim of its shell, rising up over its back to
look ahead too.

Mythical. Built from the Galapagos tortoise.
"""
import numpy as np

from anatomy import add_face
from cartoon import add_cartoon_eyes
from paint import Painter
from sdf import cone, ellipsoid
from shellkit import scute_mask
import galapagos_giant_tortoise as GT

COLORS = {"shell": "#1f3b3e", "gold": "#e8bf4a", "skin": "#4c6a5e", "dark": "#33493f", "belly": "#9fae86",
          "snake": "#5fbf6a", "snake_belly": "#e8e0a0"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    Wt = p.mesh.region_weight
    p.fill("skin")
    p.region("shell", "shell")
    p.blend("gold", Wt("shell") * scute_mask(p, *GT.SHELL) * 0.95)
    p.region("plastron", "belly")
    snake = Wt("snake") + Wt("snake_head")
    p.blend("snake", snake)
    p.blend("snake_belly", snake * p.smooth(-p.n[:, 2], 0.2, 0.4))
    return p.colors


def _after(c):
    for s in c.shapes:
        if s.region == "snake_head" and s.kind == "ellipsoid":
            add_cartoon_eyes(c, s.a, (-0.55, 0.75, 0.35), bone="root", size=0.75)
            break


def make():
    c = GT.make()
    c.name = "black_tortoise"
    c.paint = paint
    (cx, cy, cz), (rx, ry, rz) = GT.SHELL
    # The snake: round the rim of the shell, then up over the back.
    pts = []
    for a in np.linspace(0.25 * np.pi, 1.75 * np.pi, 16):
        pts.append(np.array([cx + np.sin(a) * rx * 1.02, cy + np.cos(a) * ry * 1.02, cz + rz * 0.15]))
    pts += [np.array([0.0, -ry * 0.95, cz + rz * 0.6]), np.array([0.0, -ry * 0.6, cz + rz * 1.15]),
            np.array([0.0, -ry * 0.1, cz + rz * 1.45]), np.array([0.0, ry * 0.25, cz + rz * 1.55])]
    for i in range(len(pts) - 1):
        r = 0.022 + 0.01 * (i / len(pts))
        c.shapes.append(cone(pts[i], pts[i + 1], r, r, "snake", "root", blend=0.015))
    head = pts[-1] + np.array([0.0, 0.04, 0.0])
    c.shapes.append(ellipsoid(tuple(head), (0.045, 0.055, 0.035), "snake_head", "root", blend=0.015))
    c.shapes.append(cone(head, head + (0, 0.06, -0.008), 0.03, 0.018, "snake_head", "root", blend=0.01))
    c.tiles_long = 2.2
    c.after_cartoon = _after
    return c
