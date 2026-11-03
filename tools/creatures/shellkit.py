"""Turtle shells for four-legged bodies: a domed carapace and a flat
plastron, both on the root bone so the shell stays rigid while the legs,
neck and tail inside move, and the scute pattern painted on top.
"""
import numpy as np

from sdf import ellipsoid


def add_shell(c, center, radii, plastron=(0.85, 0.85, 0.4), plastron_drop=0.6, taper=0.0, blend=0.02):
    """A carapace `radii` around `center` and a plastron under it.
    plastron: its radii as a share of the carapace's; plastron_drop: how far
    below the center it sits, as a share of the carapace's height. taper:
    narrows the back half (a heart-shaped sea turtle shell)."""
    cx, cy, cz = center
    rx, ry, rz = radii
    c.shapes.append(ellipsoid(center, radii, "shell", "root", blend=blend))
    if taper:
        # A second, narrower dome over the back half makes it heart-shaped.
        c.shapes.append(ellipsoid((cx, cy - ry * 0.35, cz - rz * 0.05), (rx * (1 - taper), ry * 0.75, rz * 0.92),
                                  "shell", "root", blend=blend))
    c.shapes.append(ellipsoid((cx, cy, cz - rz * plastron_drop), (rx * plastron[0], ry * plastron[1], rz * plastron[2]),
                              "plastron", "root", blend=blend))


def scute_mask(p, center, radii, width=0.05):
    """0-1 lines dividing the carapace into scutes: a middle row, a row each
    side and the small ones round the rim, seen from above."""
    v = p.v
    cx, cy, cz = center
    rx, ry, rz = radii
    x = (v[:, 0] - cx) / rx
    y = (v[:, 1] - cy) / ry
    ax = np.abs(x)
    r = np.sqrt(x ** 2 + y ** 2)
    lines = np.zeros(len(v))
    # Lengthwise lines between the middle row and the side rows.
    lines = np.maximum(lines, p.smooth(width - np.abs(ax - 0.3), 0.0, width * 0.6))
    # Crosswise lines: five middle scutes, four side scutes (offset).
    mid = np.abs(((y + 1) * 2.5) % 1.0 - 0.5) * 2
    side = np.abs(((y + 1) * 2.0 + 0.5) % 1.0 - 0.5) * 2
    lines = np.maximum(lines, np.where(ax < 0.3, p.smooth(mid - (1 - width * 2.5), 0.0, width), 0.0))
    lines = np.maximum(lines, np.where((ax > 0.3) & (r < 0.82), p.smooth(side - (1 - width * 2.5), 0.0, width), 0.0))
    # The ring of small scutes round the rim.
    lines = np.maximum(lines, p.smooth(width - np.abs(r - 0.82), 0.0, width * 0.6))
    return lines * p.smooth(v[:, 2] - (cz - rz * 0.35), 0.0, rz * 0.1)
