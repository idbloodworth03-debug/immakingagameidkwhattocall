"""Makes the logo, the app icon and the splash screen (game/art/logo/) in the
game's own toy look: three of the animals standing behind a wooden trail
sign that says DEN DUEL, and the Red Fox on a sunny sky for the app icon.

    python3 tools/make_logo.py

The animals are pictures the game draws itself (game/art/logo/source/
trio.png and fox.png: the home screen's squad on a see-through background,
see game/tests/squad_shot.gd). To take them again (a screen or xvfb needed):

    godot --path game res://tests/squad_shot.tscn -- "$PWD/game/art/logo/source/trio.png" 2400 1800 \
        brown_bear,red_fox,gray_squirrel pitch=9 target=0.45 camera_distance=3.0 scale=3
    godot --path game res://tests/squad_shot.tscn -- "$PWD/game/art/logo/source/fox.png" 2048 2048 \
        red_fox pitch=5 target=0.62 camera_distance=2.1 scale=4

The sign is the menus' own plank (tools/make_ui_art.py), drawn big; the
letters are Lilita One, as everywhere in the game; the colors are
data/ui_style.json's.
"""
import json
import math
import os
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import make_ui_art as U

OUT = os.path.join(ROOT, "game", "art", "logo")
SOURCE = os.path.join(OUT, "source")
FONT = os.path.join(ROOT, "game", "art", "fonts", "LilitaOne-Regular.ttf")
COLORS = json.load(open(os.path.join(ROOT, "game", "data", "ui_style.json")))["colors"]
NAME = "DEN DUEL"


def rgb(key, lighten=0.0):
    h = COLORS.get(key, key).lstrip("#")
    c = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    return tuple(int(round(v + (255 - v) * lighten)) for v in c)


def cut(path):
    """A picture cropped to what is drawn in it."""
    im = Image.open(path).convert("RGBA")
    return im.crop(im.getbbox())


def plank(w, h):
    """The menus' trail-sign plank (tools/make_ui_art.py "sign"), w x h
    pixels, in the sign's color: drawn at this size with every part of it
    (outline, lip, corners, nails, grain) as big, for its height, as in the
    game."""
    k = h / 122.0   # the menus' plank is 122 texture pixels tall
    radius, outline, lip = 32 * k, 8 * k, 6 * k
    grain = U.wood_grain
    U.wood_grain = lambda gw, gh, seed, amount=1.0, period=14.0: grain(gw, gh, seed, amount, period * k)
    with tempfile.TemporaryDirectory() as tmp:
        was = U.OUT
        U.OUT = tmp
        try:
            U.chunky("plank", w, h, radius, outline, lip, 0, grain=0.9, top=0.98, bottom=0.84, seed=21, highlight=0.5)
        finally:
            U.OUT = was
            U.wood_grain = grain
        base = np.asarray(Image.open(os.path.join(tmp, "plank.png")).convert("RGBA"), dtype=np.float64) / 255.0
        shine = Image.open(os.path.join(tmp, "plank_shine.png")).convert("RGBA")
    c = U.Canvas(w, h)
    c.rgb, c.a = base[..., :3].copy(), base[..., 3].copy()
    mid = (h - lip) / 2
    U.nails(c, [(radius * 0.9, mid), (w - radius * 0.9, mid)], 6 * k)
    tint = np.array(rgb("sign", 0.12)) / 255.0
    rgba = np.dstack([np.clip(c.rgb * tint, 0, 1), np.clip(c.a, 0, 1)])
    out = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")
    out.alpha_composite(shine)
    return out


def with_shadow(piece, drop, soft, strength=0.38):
    """A piece with a soft shadow `drop` pixels under it (a picture with
    room for it all round: `soft` * 3 pixels)."""
    pad = round(soft * 3)
    out = Image.new("RGBA", (piece.size[0] + 2 * pad, piece.size[1] + 2 * pad + drop), (0, 0, 0, 0))
    shade = Image.new("RGBA", out.size, rgb("outline") + (0,))
    alpha = Image.new("L", out.size, 0)
    alpha.paste(piece.getchannel("A"), (pad, pad + drop))
    alpha = alpha.filter(ImageFilter.GaussianBlur(soft)).point(lambda v: int(v * strength))
    shade.putalpha(alpha)
    out.alpha_composite(shade)
    out.alpha_composite(piece, (pad, pad))
    return out, pad


def words(text, size):
    """The name in the game's letters: gold, lighter at the top, with a
    thick dark outline and a drop shadow."""
    font = ImageFont.truetype(FONT, size)
    stroke = round(size * 0.1)
    drop = round(size * 0.07)
    box = font.getbbox(text, stroke_width=stroke)
    w, h = box[2] - box[0] + 4, box[3] - box[1] + drop + 4
    at = (2 - box[0], 2 - box[1])
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    ink = rgb("outline")
    draw.text((at[0], at[1] + drop), text, font=font, fill=ink + (255,), stroke_width=stroke, stroke_fill=ink + (255,))
    draw.text(at, text, font=font, fill=ink + (255,), stroke_width=stroke, stroke_fill=ink + (255,))
    # The letters' faces: a gradient, cut to the letters' shape.
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(at, text, font=font, fill=255)
    top, bottom = np.array(rgb("kit_yellow", 0.35), float), np.array(rgb("trophy"), float)
    t = np.clip((np.arange(h) - at[1] - box[1]) / max(1.0, size * 0.75), 0, 1)[:, None, None]
    face = np.broadcast_to(top + (bottom - top) * t, (h, w, 3))
    face = Image.fromarray(face.astype(np.uint8), "RGB").convert("RGBA")
    face.putalpha(mask)
    out.alpha_composite(face)
    return out


def logo(scale=2):
    """The animals behind the sign: 1200 x 760 (drawn `scale` times as big,
    then shrunk, for smooth edges)."""
    W, H = 1200 * scale, 760 * scale
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sign_w, sign_h = round(W * 0.8), round(H * 0.3)
    sign_y = H - sign_h - round(H * 0.06)
    # The animals fill the room above the sign, their feet a little behind it.
    trio = cut(os.path.join(SOURCE, "trio.png"))
    tall = sign_y + round(sign_h * 0.22) - round(H * 0.012)
    trio = trio.resize((round(trio.size[0] * tall / trio.size[1]), tall), Image.LANCZOS)
    # Their feet (and the shadows under them) behind the sign.
    out.alpha_composite(trio, ((W - trio.size[0]) // 2, sign_y + round(sign_h * 0.22) - tall))
    board, pad = with_shadow(plank(sign_w, sign_h), round(sign_h * 0.06), sign_h * 0.035)
    out.alpha_composite(board, ((W - sign_w) // 2 - pad, sign_y - pad))
    name = words(NAME, round(sign_h * 0.66))
    out.alpha_composite(name, ((W - name.size[0]) // 2, sign_y + round(sign_h * 0.49) - name.size[1] // 2))
    return out.resize((1200, 760), Image.LANCZOS)


def splash(mark):
    """The splash screen: the logo in the upper middle of a tall, see-through
    picture (the game's sky color shows round it: project.godot boot_splash)."""
    W, H = 1080, 1920
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wide = round(W * 0.9)
    mark = mark.resize((wide, round(mark.size[1] * wide / mark.size[0])), Image.LANCZOS)
    out.alpha_composite(mark, ((W - wide) // 2, round(H * 0.46) - mark.size[1] // 2))
    return out


def sky(size, rays=14):
    """A sunny sky with soft rays of light from behind the middle."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float64)
    t = (y / (size - 1))[..., None]
    top, bottom = np.array(rgb("secondary"), float), np.array(rgb("sky", 0.25), float)
    pic = top + (bottom - top) * t
    cx, cy = size / 2, size * 0.56
    angle = np.arctan2(y - cy, x - cx)
    wedge = (np.cos(angle * rays + 0.4) > 0.0).astype(np.float64)
    wedge = np.asarray(Image.fromarray((wedge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(size * 0.004)), float) / 255.0
    far = np.hypot(x - cx, y - cy) / size
    light = wedge * 0.2 * np.clip(1.15 - far, 0, 1) + 0.5 * np.clip(1.0 - far / 0.5, 0, 1) ** 2
    pic = pic + (255 - pic) * np.clip(light, 0, 1)[..., None]
    return Image.fromarray(np.clip(pic, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def app_icon(size=1024):
    """The Red Fox on the sunny sky, filling the square."""
    out = sky(size)
    fox = cut(os.path.join(SOURCE, "fox.png"))
    wide = round(size * 0.9)
    fox = fox.resize((wide, round(fox.size[1] * wide / fox.size[0])), Image.LANCZOS)
    out.alpha_composite(fox, ((size - wide) // 2, round(size * 0.035)))
    return out.convert("RGB")


def main():
    mark = logo()
    mark.save(os.path.join(OUT, "logo.png"))
    splash(logo(scale=2)).save(os.path.join(OUT, "splash.png"))
    app_icon().save(os.path.join(OUT, "app_icon.png"))
    for name in ("logo.png", "splash.png", "app_icon.png"):
        print("%s: %s, %d KB" % (name, Image.open(os.path.join(OUT, name)).size, os.path.getsize(os.path.join(OUT, name)) // 1024))


if __name__ == "__main__":
    main()
