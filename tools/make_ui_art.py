"""Draws the "Ranger Camp" UI pieces into game/art/ui/: chunky nine-slice
skins (painted wood panels, buttons, chips, card frames, a trail-sign
plank...) and the particle sheet.

Each skin is a grayscale *shape* texture (outline, lip, bevel, wood grain,
soft shadow), tinted in the game with a color from data/ui_style.json, plus
a white *shine* texture (top highlight, gloss) drawn over it untinted. So the
colors stay in the data file and one shape serves every color.

Everything is drawn at 2 texture pixels per game pixel (crisp on a 3x
iPhone screen) with signed-distance shapes, so edges are smooth without
supersampling. Writes game/art/ui/skins.json with each skin's slice margins.

    python3 tools/make_ui_art.py
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "ui")
SCALE = 2  # texture pixels per game pixel
LIGHT = np.array([-0.55, -0.83])  # toward the light: top-left
LIGHT = LIGHT / np.linalg.norm(LIGHT)


# --- Shapes -------------------------------------------------------------------

def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    return x + 0.5, y + 0.5


def rrect(x, y, x0, y0, x1, y1, r):
    """Signed distance to a rounded rectangle (negative inside)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(x - cx) - hx, np.abs(y - cy) - hy
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - r


def cover(d, soft=1.0):
    return np.clip(0.5 - d / soft, 0.0, 1.0)


def smoothstep(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def blur(a, radius):
    if radius <= 0:
        return a
    img = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(img, dtype=np.float64) / 255.0


def noise(w, h, gw, gh, rng):
    """Smooth value noise: a small random grid scaled up smoothly."""
    small = rng.random((max(2, gh), max(2, gw)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float64) / 255.0


def wood_grain(w, h, seed, amount=1.0, period=14.0):
    """Soft horizontal wood grain around 1.0 (multiply it in)."""
    rng = np.random.default_rng(seed)
    x, y = grid(w, h)
    warp = noise(w, h, 5, 3, rng) * 2 - 1
    knots = noise(w, h, 9, 5, rng)
    rings = 0.5 + 0.5 * np.sin(2 * np.pi * (y / period + warp * 1.4 + knots * 0.35))
    lines = rings ** 5
    streaks = noise(w, h, max(2, w // 64), max(2, h // 3), rng)
    value = 1.0 - 0.06 * lines - 0.045 * (streaks - 0.5) * 2 + 0.03 * (knots - 0.5)
    return 1.0 + (value - 1.0) * amount


def normals(d):
    gy, gx = np.gradient(d)
    length = np.hypot(gx, gy) + 1e-6
    return gx / length, gy / length


def bevel(d, width):
    """How much the light (top-left) hits the rounded edge: -1..1, near the edge."""
    nx, ny = normals(d)
    facing = nx * LIGHT[0] + ny * LIGHT[1]
    band = smoothstep(width, 0.0, -d) * (d < 0.5)
    return facing * band


# --- Layering -------------------------------------------------------------------

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3))
        self.a = np.zeros((h, w))

    def over(self, value, alpha):
        """Paints `value` (gray or RGB) with coverage `alpha` over what's there."""
        value = np.asarray(value, dtype=np.float64)
        if value.ndim == 1 and value.shape[0] == 3:
            value = np.broadcast_to(value, (self.h, self.w, 3))
        elif value.ndim < 3:
            value = np.broadcast_to(value, (self.h, self.w))[..., None] * np.ones(3)
        a = np.clip(alpha, 0, 1)[..., None]
        out_a = a[..., 0] + self.a * (1 - a[..., 0])
        safe = np.maximum(out_a, 1e-6)[..., None]
        self.rgb = (value * a + self.rgb * self.a[..., None] * (1 - a)) / safe
        self.a = out_a

    def save(self, name):
        rgba = np.dstack([np.clip(self.rgb, 0, 1), np.clip(self.a, 0, 1)])
        Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))


def chunky(name, w, h, radius, outline, lip, shadow, grain=0.0, gloss=0.0, pressed=False,
           sunken=False, top=1.0, bottom=0.8, seed=1, highlight=0.55, bevel_width=None, metal=False):
    """One chunky piece: soft shadow, dark outline, darker lip, shaded face.

    The body fills the texture except `shadow` pixels at the bottom, where
    the drop shadow shows. Pressed: the face sinks onto the lip.
    Returns the slice margins and how far the shadow reaches below."""
    x, y = grid(w, h)
    body = rrect(x, y, 1, 1, w - 1, h - 1 - shadow, radius)
    base = Canvas(w, h)
    shine = Canvas(w, h)
    if shadow > 0 and not sunken:
        drop = rrect(x, y, 3, 1 + shadow * 0.7, w - 3, h - 1, radius)
        base.over(0.0, blur(cover(drop), shadow * 0.45) * 0.42)
    base.over(0.13, cover(body))  # the outline
    inner = rrect(x, y, 1 + outline, 1 + outline, w - 1 - outline, h - 1 - shadow - outline, max(2, radius - outline * 0.8))
    if sunken:
        t = np.clip((y - outline) / max(1, h - shadow - 2 * outline), 0, 1)
        face = 0.62 + 0.22 * t
        if grain:
            face = face * wood_grain(w, h, seed, grain)
        base.over(face, cover(inner))
        # A soft shadow along the inside top edge.
        shade = blur(cover(-inner + 6) * cover(inner), 3) * smoothstep(h * 0.6, 0, y)
        base.over(0.2, shade * 0.5 * cover(inner))
        base.save(name)
        return
    sink = (lip - 3) if pressed else 0
    lip_shape = inner
    base.over(0.55, cover(lip_shape))  # the lip: seen below the face
    face_d = rrect(x, y, 1 + outline, 1 + outline + sink, w - 1 - outline, h - 1 - shadow - outline - lip + sink,
                   max(2, radius - outline * 0.8))
    fy0, fy1 = 1 + outline + sink, h - 1 - shadow - outline - lip + sink
    t = np.clip((y - fy0) / max(1, fy1 - fy0), 0, 1)
    face = top + (bottom - top) * t
    if metal:
        # Brass: bright top, a darker band, a bright reflection low down.
        face = 0.98 - 0.30 * smoothstep(0.15, 0.55, t) + 0.22 * smoothstep(0.62, 0.9, t) - 0.12 * smoothstep(0.9, 1.0, t)
    if grain:
        face = face * wood_grain(w, h, seed, grain)
    bw = bevel_width if bevel_width is not None else max(4, radius * 0.45)
    lit = bevel(face_d, bw)
    face = face * (1 + 0.16 * np.minimum(lit, 0))  # the far edge in shade
    base.over(face, cover(face_d))
    # Shine: the near edge catching the light, a line along the top, gloss.
    shine.over(1.0, np.maximum(lit, 0) * 0.55 * cover(face_d))
    top_line = cover(np.abs(face_d + 3.0) - 1.4) * smoothstep(fy0 + radius * 1.2, fy0, y)
    shine.over(1.0, top_line * highlight)
    if gloss > 0:
        g = rrect(x, y, 1 + outline + 6, fy0 + 4, w - 1 - outline - 6, fy0 + (fy1 - fy0) * 0.46, max(2, radius - outline - 6))
        fade = smoothstep(fy0 + (fy1 - fy0) * 0.5, fy0, y)
        shine.over(1.0, cover(g, 2.0) * fade * gloss)
    base.save(name)
    shine.save(name + "_shine")


def nails(c, centers, r):
    x, y = grid(c.w, c.h)
    for cx, cy in centers:
        d = np.hypot(x - cx, y - cy) - r
        c.over(0.12, cover(d - 1.5))
        c.over(0.55, cover(d))
        hl = np.hypot(x - cx + r * 0.3, y - cy + r * 0.35) - r * 0.35
        c.over(0.95, cover(hl) * 0.8)


def sign(name, w, h, radius, outline, shadow, seed):
    """A trail-sign plank: wood with grain, a darker rim, two nails."""
    chunky(name, w, h, radius, outline, 6, shadow, grain=0.9, top=0.98, bottom=0.84, seed=seed, highlight=0.5)
    img = np.asarray(Image.open(os.path.join(OUT, name + ".png")), dtype=np.float64) / 255.0
    c = Canvas(w, h)
    c.rgb, c.a = img[..., :3].copy(), img[..., 3].copy()
    mid = (h - shadow - 6) / 2
    nails(c, [(radius * 0.9, mid), (w - radius * 0.9, mid)], 6)
    c.save(name)


def glow(name, w, h, radius, spread):
    x, y = grid(w, h)
    d = rrect(x, y, spread, spread, w - spread, h - spread, radius)
    c = Canvas(w, h)
    c.over(1.0, blur(cover(d), spread * 0.42))
    c.save(name)


# --- Particles ------------------------------------------------------------------

CELL = 128
PARTICLES = ["puff", "star", "sparkle", "confetti", "coin", "petal", "spark", "glow",
             "leaf", "dust", "heart", "acorn", "badge"]


def particle_sheet():
    cols = 4
    rows = math.ceil(len(PARTICLES) / cols)
    sheet = Canvas(cols * CELL, rows * CELL)
    for i, kind in enumerate(PARTICLES):
        c = Canvas(CELL, CELL)
        x, y = grid(CELL, CELL)
        cx = cy = CELL / 2
        r = CELL * 0.4
        d = np.hypot(x - cx, y - cy)
        if kind in ("puff", "dust"):
            ball = d - r * 0.92
            c.over(0.62 if kind == "puff" else 0.75, cover(ball + 3) * 0.45)
            shade = 0.86 + 0.14 * smoothstep(r, -r, (x - cx) * 0.6 + (y - cy) * 0.8)
            c.over(shade, cover(ball))
            c.over(1.0, cover(np.hypot(x - cx + r * 0.32, y - cy + r * 0.36) - r * 0.32) * 0.6)
        elif kind in ("star", "sparkle"):
            ang = np.arctan2(y - cy, x - cx) + np.pi / 2
            if kind == "star":
                k = 5
                spike = np.cos(k * ang) * 0.5 + 0.5
                edge = r * (0.5 + 0.5 * spike ** 1.6)
            else:
                k = 4
                spike = np.abs(np.cos(k / 2 * ang)) ** 6
                edge = r * (0.2 + 0.8 * spike)
            shape = d - edge
            if kind == "star":
                c.over(0.18, cover(shape - 7))
                c.over(1.0, cover(shape))
                c.over(1.0, cover(np.hypot(x - cx + 9, y - cy + 10) - 12) * 0.5)
            else:
                c.over(1.0, cover(shape, 1.5))
                c.over(1.0, cover(d - r * 0.25))
        elif kind == "confetti":
            c.over(1.0, cover(rrect(x, y, cx - r, cy - r * 0.55, cx + r, cy + r * 0.55, 10)))
        elif kind == "coin":
            ring = d - r
            c.over(np.array([0.45, 0.28, 0.02]), cover(ring))
            t = np.clip((y - (cy - r)) / (2 * r), 0, 1)
            gold = np.stack([1.0 - 0.1 * t, 0.85 - 0.25 * t, 0.25 - 0.15 * t], -1)
            c.over(gold, cover(ring + 7))
            c.over(np.array([0.85, 0.55, 0.05]), cover(np.abs(d - r * 0.62) - 2.5) * 0.7)
            c.over(1.0, cover(np.hypot(x - cx + r * 0.35, y - cy + r * 0.4) - r * 0.22) * 0.8)
        elif kind == "petal":
            e = np.hypot((x - cx) / 1.0, (y - cy) / 0.55) - r
            c.over(1.0, cover(e, 2.0))
            c.over(0.85, cover(np.abs(y - cy) - 1.0) * cover(e) * 0.4)
        elif kind == "spark":
            e = np.hypot((x - cx) / 1.0, (y - cy) / 0.16) - r
            c.over(1.0, blur(cover(e), 3))
            c.over(1.0, cover(np.hypot((x - cx) / 1.0, (y - cy) / 0.07) - r * 0.8))
        elif kind == "glow":
            c.over(1.0, np.clip(1 - d / r, 0, 1) ** 2.2)
        elif kind == "leaf":
            # A leaf: where two circles overlap (pointed at both ends), with a vein.
            big = r * 1.45
            off = big - r * 0.5
            leaf_d = np.maximum(np.hypot(x - cx, y - cy - off) - big, np.hypot(x - cx, y - cy + off) - big)
            c.over(0.25, cover(leaf_d - 5))
            shade = 0.82 + 0.18 * smoothstep(r * 0.5, -r * 0.5, y - cy)
            c.over(shade, cover(leaf_d))
            c.over(0.62, cover(np.abs(y - cy) - 1.5) * cover(leaf_d + 6))
        elif kind == "heart":
            u = (x - cx) / (r * 0.82)
            v = -(y - cy) / (r * 0.82) + 0.12
            hd = (u ** 2 + v ** 2 - 1) ** 3 - u ** 2 * v ** 3
            c.over(0.2, blur((hd < 0.06).astype(float), 1.0))
            c.over(1.0, blur((hd < 0.0).astype(float), 0.8))
            c.over(1.0, cover(np.hypot(x - cx + r * 0.38, y - cy + r * 0.22) - r * 0.16) * 0.6)
        elif kind == "badge":
            # A round badge (tinted by habitat): dark rim, shaded face, a shine.
            c.over(0.12, cover(d - r))
            t = np.clip((y - (cy - r)) / (2 * r), 0, 1)
            c.over(1.0 - 0.22 * t, cover(d - r + 6))
            c.over(1.0, cover(np.hypot(x - cx + r * 0.38, y - cy + r * 0.42) - r * 0.25) * 0.35)
        elif kind == "acorn":
            cap = rrect(x, y, cx - r * 0.75, cy - r * 0.85, cx + r * 0.75, cy - r * 0.1, r * 0.35)
            nut = np.hypot((x - cx) / 0.72, (y - cy - r * 0.15) / 0.92) - r * 0.62
            c.over(np.array([0.3, 0.16, 0.06]), cover(np.minimum(cap, nut) - 6))
            c.over(np.array([0.85, 0.55, 0.28]), cover(nut))
            c.over(np.array([0.55, 0.33, 0.14]), cover(cap))
            c.over(1.0, cover(np.hypot(x - cx + r * 0.22, y - cy - r * 0.02) - r * 0.14) * 0.6)
        col, row = i % cols, i // cols
        sheet.rgb[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL] = c.rgb
        sheet.a[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL] = c.a
    sheet.save("particles")
    return {"cell": CELL, "columns": cols, "kinds": PARTICLES}


# --- All of it ------------------------------------------------------------------

def main():
    os.makedirs(OUT, exist_ok=True)
    S = SCALE
    skins = {}

    def add(name, w, h, margins, shadow, shine=True):
        """margins: left, top, right, bottom in texture pixels. shadow: the
        drop shadow below the body, in texture pixels (drawn outside the
        control's rect)."""
        skins[name] = {"file": name + ".png", "shine": (name + "_shine.png") if shine else "",
                       "size": [w, h], "margins": margins, "shadow": shadow, "scale": 1.0 / S}

    # Main panel: painted wood with grain, chunky lip and a soft shadow.
    w, h, r, o, lip, sh = 240, 240, 28 * S, 5 * S, 6 * S, 9 * S
    chunky("panel", w, h, r, o, lip, sh, grain=0.7, top=1.0, bottom=0.82, seed=7, highlight=0.5)
    add("panel", w, h, [r + 4, r + 4, r + 4, r + lip + sh + 4], sh)
    # A sunken well inside a panel (darker wood).
    w, h, r, o = 160, 160, 20 * S, 3 * S
    chunky("inset", w, h, r, o, 0, 0, grain=0.8, sunken=True, seed=3)
    add("inset", w, h, [r + 4, r + 4, r + 4, r + 4], 0, shine=False)
    # Buttons: painted wood blocks with a gloss, and their pressed faces.
    w, h, r, o, lip, sh = 200, 176, 22 * S, 4 * S, 8 * S, 4 * S
    for pressed in (False, True):
        chunky("button_pressed" if pressed else "button", w, h, r, o, lip, sh, grain=0.15, gloss=0.32,
               pressed=pressed, top=1.0, bottom=0.78, seed=11, highlight=0.6)
        add("button_pressed" if pressed else "button", w, h, [r + 4, r + 4, r + 4, r + lip + sh + 4], sh)
    # Chips (pills, badges): small and chunky. Brass for money.
    w, h, r, o, lip, sh = 128, 120, 16 * S, 3 * S, 4 * S, 3 * S
    chunky("chip", w, h, r, o, lip, sh, grain=0.35, top=1.0, bottom=0.8, seed=5, highlight=0.45)
    add("chip", w, h, [r + 3, r + 3, r + 3, r + lip + sh + 3], sh)
    chunky("chip_brass", w, h, r, o, lip, sh, metal=True, seed=5, highlight=0.7, gloss=0.18)
    add("chip_brass", w, h, [r + 3, r + 3, r + 3, r + lip + sh + 3], sh)
    # Card frames (tinted by rarity) and the art window (tinted by habitat).
    w, h, r, o, lip, sh = 160, 200, 20 * S, 4 * S, 5 * S, 5 * S
    chunky("card", w, h, r, o, lip, sh, grain=0.25, top=1.0, bottom=0.78, seed=9, highlight=0.65)
    add("card", w, h, [r + 4, r + 4, r + 4, r + lip + sh + 4], sh)
    w, h, r, o = 128, 128, 14 * S, 2 * S
    chunky("window", w, h, r, o, 0, 0, sunken=True, seed=2)
    add("window", w, h, [r + 4, r + 4, r + 4, r + 4], 0, shine=False)
    # The trail sign over a panel: a wooden plank with two nails.
    w, h, r, o, sh = 320, 132, 16 * S, 4 * S, 5 * S
    sign("sign", w, h, r, o, sh, seed=21)
    add("sign", w, h, [56, 40, 56, 40 + sh + 12], sh)
    # A soft glow around picked things.
    glow("glow", 160, 160, 24 * S, 22)
    add("glow", 160, 160, [64, 64, 64, 64], 0, shine=False)

    meta = {"_note": "Written by tools/make_ui_art.py: the nine-slice margins of each UI skin, in texture pixels. Do not edit by hand; change the script and run it again.",
            "skins": skins, "particles": particle_sheet()}
    with open(os.path.join(OUT, "skins.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    print("UI art written to", OUT)


if __name__ == "__main__":
    main()
