"""Rock pigeons: plump and grey, with a shimmering green and purple neck,
two dark bars on each wing, a dark tail band, a small dark beak with a
white cere and pink feet. The game shows a pair of them.

Real size: about 32 cm long, 65 cm wingspan.
"""
from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 0.65
J, R = layout(SPAN, body=0.9, girth=1.45, neck=0.8, head=1.25, beak=(0.55, 0.9), hook=0.0, tail=(0.8, 1.2),
              fingers=0, legs=0.7, fan=0.5)
COLORS = {"grey": "#a3abb5", "dark": "#4b5058", "head": "#7f8792", "green": "#4f8f6c", "purple": "#8a5a92",
          "pink": "#d9707a", "beak": "#3a3a3c", "light": "#c9ced6"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("grey")
    p.blend("light", down * 0.5)
    p.region("head", "head")
    neck = p.mesh.region_weight("neck")
    p.blend("green", neck)
    p.blend("purple", neck * p.smooth(v[:, 2] - J["neck_base"][2] - 0.01, 0.0, 0.01) * 0.6)
    wing = p.mesh.region_weight("wing")
    bars = wing * up * p.smooth(0.45 - out, 0.0, 0.05) * p.smooth(out - 0.12, 0.0, 0.03)
    p.stripes("dark", lambda q: q[:, 1], frequency=1.0 / (SPAN * 0.09), width=0.2, mask=bars)
    p.blend("dark", wing * p.smooth(out - 0.8, 0.0, 0.08) * 0.7)
    p.blend("dark", p.mesh.region_weight("tail") * p.smooth(J["tail_end"][1] * 0.85 - v[:, 1], 0.0, 0.01))
    p.region("beak", "beak")
    p.region("leg", "pink")
    return p.colors


def make():
    c = bird("pigeon_flock", J, R, paint=paint, tiles_long=0.95)
    finish(c, R, iris="#d9692a")
    return flying(c, SPAN, flap=0.85, hover=0.6)
