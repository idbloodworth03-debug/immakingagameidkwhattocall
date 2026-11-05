"""Sets how Godot stores the animal sprite sheets, portraits and arena
pictures (look.json "import"): sprite sheets GPU-compressed with Basis
Universal (UASTC) or a single lossy WebP pass, from lossless sources, with
mipmaps so zoomed-out animals stay smooth.

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


for path in (glob.glob(os.path.join(ROOT, "units", "*", "*.webp.import"))
             + glob.glob(os.path.join(ROOT, "arenas", "*.webp.import"))):
    name = os.path.basename(path)
    rule = LOOK["arenas"] if "arenas" in path else LOOK["sheets"] if name.startswith("sheet") else LOOK["portraits"]
    text = open(path).read()
    new = settings(text, rule)
    if new != text:
        open(path, "w").write(new)
        print(rule["mode"] + ":", os.path.relpath(path, ROOT))
