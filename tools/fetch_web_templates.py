"""Installs Godot's web export templates without downloading all 1.3 GB.

Godot ships every platform's templates in one big .tpz (a zip). The server
allows partial downloads, so this reads the zip's table of contents and
downloads only the two web templates (about 10 MB each).

    python3 tools/fetch_web_templates.py 4.7.2

They are installed where Godot looks for them:
~/.local/share/godot/export_templates/<version>.stable/
"""
import io
import os
import sys
import urllib.request
import zipfile

WANT = ["version.txt", "web_nothreads_release.zip", "web_nothreads_debug.zip"]


class RemoteFile(io.RawIOBase):
    """A read-only, seekable file backed by HTTP range requests."""

    BLOCK = 1 << 20

    def __init__(self, url):
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD")) as response:
            self.url = response.geturl()  # follow the redirect once
            self.size = int(response.headers["Content-Length"])
        self.pos = 0
        self.cache = {}

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        base = {0: 0, 1: self.pos, 2: self.size}[whence]
        self.pos = base + offset
        return self.pos

    def _block(self, index):
        if index not in self.cache:
            start = index * self.BLOCK
            end = min(self.size, start + self.BLOCK) - 1
            request = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{end}"})
            with urllib.request.urlopen(request) as response:
                self.cache[index] = response.read()
            if len(self.cache) > 64:
                self.cache.pop(next(iter(self.cache)))
        return self.cache[index]

    def read(self, n=-1):
        if n < 0:
            n = self.size - self.pos
        out = bytearray()
        while n > 0 and self.pos < self.size:
            block = self._block(self.pos // self.BLOCK)
            chunk = block[self.pos % self.BLOCK:][:n]
            out += chunk
            self.pos += len(chunk)
            n -= len(chunk)
        return bytes(out)

    def readinto(self, buffer):
        data = self.read(len(buffer))
        buffer[: len(data)] = data
        return len(data)


def main():
    version = sys.argv[1]
    target = os.path.expanduser(f"~/.local/share/godot/export_templates/{version}.stable")
    if all(os.path.exists(os.path.join(target, name)) for name in WANT):
        print("Web templates already installed in", target)
        return
    url = f"https://github.com/godotengine/godot/releases/download/{version}-stable/Godot_v{version}-stable_export_templates.tpz"
    archive = zipfile.ZipFile(RemoteFile(url))
    os.makedirs(target, exist_ok=True)
    for name in WANT:
        with archive.open("templates/" + name) as source, open(os.path.join(target, name), "wb") as dest:
            dest.write(source.read())
        print("installed", name)


if __name__ == "__main__":
    main()
