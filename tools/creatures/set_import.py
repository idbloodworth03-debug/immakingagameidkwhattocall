"""Sets how Godot stores the animal sprite sheets, portraits, arena
pictures and 3D viewer models (look.json "import"): each picture lossless,
one lossy WebP pass or GPU-compressed Basis Universal, with or without
mipmaps; the models without the extras a close-up, unlit animal doesn't use.

Run after Godot has imported new art once, then import again:
    python tools/creatures/set_import.py
    godot --headless --path game --import
"""
import glob
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "game", "art")
LOOK = json.load(open(os.path.join(HERE, "look.json")))["import"]
MODES = {"lossless": 0, "lossy": 1, "basis": 4}


def settings(text, rule):
    text = re.sub(r"compress/mode=\d+", "compress/mode=%d" % MODES[rule["mode"]], text)
    if "quality" in rule:
        text = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=%s" % rule["quality"], text)
    text = re.sub(r"compress/uastc_level=\d+", "compress/uastc_level=%d" % LOOK["uastc_level"], text)
    text = re.sub(r"compress/rdo_quality_loss=[\d.]+", "compress/rdo_quality_loss=%s" % LOOK["rdo_quality_loss"], text)
    text = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=%s" % ("true" if rule["mipmaps"] else "false"), text)
    # Smooth, halo-free edges when shrunk or filtered.
    text = re.sub(r"process/fix_alpha_border=\w+", "process/fix_alpha_border=true", text)
    return text


def _lossless(webp):
    """True if a WebP file is stored lossless (its image chunk is VP8L)."""
    with open(webp, "rb") as f:
        head = f.read(64)
    return b"VP8L" in head


for path in (glob.glob(os.path.join(ROOT, "units", "*", "*.webp.import"))
             + glob.glob(os.path.join(ROOT, "arenas", "*.webp.import"))
             + glob.glob(os.path.join(ROOT, "arenas", "crowd", "*.webp.import"))):
    name = os.path.basename(path)
    rule = LOOK["crowd"] if "crowd" in path else LOOK["arenas"] if "arenas" in path \
        else LOOK["sheets"] if name.startswith("sheet") else LOOK["portraits"]
    if rule is LOOK["arenas"] and not _lossless(path[:-len(".import")]):
        # Already compressed once when it was saved: keep it as it is.
        rule = dict(rule, mode="lossless")
    text = open(path).read()
    new = settings(text, rule)
    if new != text:
        open(path, "w").write(new)
        print(rule["mode"] + ":", os.path.relpath(path, ROOT))


MODEL = LOOK.get("models", {})
for path in glob.glob(os.path.join(ROOT, "models", "*.glb.import")) + glob.glob(os.path.join(ROOT, "models", "battle", "*.glb.import")):
    text = open(path).read()
    new = text
    for key, value in MODEL.items():
        shown = ("true" if value else "false") if isinstance(value, bool) else str(value)
        new = re.sub(r"meshes/%s=\w+" % key, "meshes/%s=%s" % (key, shown), new)
    if new != text:
        open(path, "w").write(new)
        print("model:", os.path.relpath(path, ROOT))
