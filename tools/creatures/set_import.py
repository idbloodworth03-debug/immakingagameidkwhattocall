"""Makes Godot store the animal sprite sheets and portraits as lossy WebP
(several times smaller in the web build than the default lossless).

Run after Godot has imported new art once, then import again:
    python tools/creatures/set_import.py
    godot --headless --path game --import
"""
import glob
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "art", "units")

for path in glob.glob(os.path.join(ROOT, "*", "*.webp.import")):
    text = open(path).read()
    new = re.sub(r"compress/mode=\d+", "compress/mode=1", text)
    new = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=0.85", new)
    if os.path.basename(path).startswith("sheet"):
        # Sprites are drawn near their real size, so smaller copies (mipmaps)
        # only add download size. Portraits shrink a lot on cards: keep theirs.
        new = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=false", new)
    if new != text:
        open(path, "w").write(new)
        print("lossy:", os.path.relpath(path, ROOT))
