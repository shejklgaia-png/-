#!/usr/bin/env python3
"""Install SERA's angular font originals from their official authors.

Run once from a local Godot project (including Android/Termux). No font bytes
from Makinas may be committed or republished with the public source tree.
The application/APK may embed the originals solely for game text display
under the author's published usage permission.
"""
from __future__ import annotations

from io import BytesIO
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "fonts"
MAKINAS_URL = "https://moji-waku.com/download/makinas4.zip"
CHAKRA_ROOT = "https://raw.githubusercontent.com/google/fonts/main/ofl/chakrapetch/"
CHAKRA = ("ChakraPetch-Medium.ttf", "ChakraPetch-SemiBold.ttf")
FONT_LIMIT = 25 * 1024 * 1024
ARCHIVE_LIMIT = 70 * 1024 * 1024


def download(url: str, limit: int) -> bytes:
    request = Request(url, headers={"User-Agent": "SERA-font-local-installer/1.0"})
    with urlopen(request, timeout=40) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise RuntimeError("Official file exceeds the permitted download size")
    if not data:
        raise RuntimeError("Empty font download: " + url)
    return data


def check_font(data: bytes, name: str) -> None:
    if len(data) < 100 or data[:4] not in (b"OTTO", bytes((0, 1, 0, 0)), b"true"):
        raise RuntimeError("Invalid font signature: " + name)


def main() -> int:
    # Stage all source bytes before writing anything to the project.
    fetched: dict[str, bytes] = {}
    print("Downloading Chakra Petch from the Google Fonts official repository...")
    for name in CHAKRA:
        data = download(CHAKRA_ROOT + name, FONT_LIMIT)
        check_font(data, name)
        fetched[name] = data
    fetched["OFL-ChakraPetch.txt"] = download(CHAKRA_ROOT + "OFL.txt", 256_000)

    print("Downloading Makinas 4 from the author's official site...")
    with ZipFile(BytesIO(download(MAKINAS_URL, ARCHIVE_LIMIT))) as archive:
        available = [f for f in archive.infolist()
                     if not f.is_dir() and f.filename.lower().endswith((".otf", ".ttf"))]
        for style, target in (("flat", "Makinas4Flat.otf"),
                              ("square", "Makinas4Square.otf")):
            matches = [f for f in available
                       if style in Path(f.filename).name.lower()]
            if not matches:
                raise RuntimeError("Official ZIP does not contain Makinas 4 " + style)
            source = sorted(matches, key=lambda f: f.filename.lower())[0]
            if source.file_size > FONT_LIMIT:
                raise RuntimeError("Oversized font in official ZIP: " + source.filename)
            data = archive.read(source)
            check_font(data, source.filename)
            fetched[target] = data

    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in fetched.items():
        (OUT / name).write_bytes(data)
        print("Installed locally:", OUT / name)
    print("Complete. Makinas originals are excluded from the public Git repository.")
    print("Open or reimport the Godot project to use these fonts; no game-time internet needed.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("Font setup failed (no partial installation):", exc, file=sys.stderr)
        sys.exit(1)
