#!/usr/bin/env python3
"""Pin, verify, and vendor complete SIL OFL fonts for SERA's Android UI.

Run in GitHub Actions only. Source files are fetched from Google's official
open-font repository and checked against fixed Git blob hashes. The complete
Japanese variable font is retained (no gameplay-string-only subset).
"""
from __future__ import annotations

import hashlib
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen, Request

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "assets" / "fonts"
BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
ASSETS = (
    ("notosansjp/NotoSansJP%5Bwght%5D.ttf", "NotoSansJP-VF.woff2",
     "cdd8f083c1f5928ff3361f8cda4d3fc9462cbe89", "NotoSansJP",
     (0x0041, 0x65E5, 0x6F22, 0x30AB, 0x3042)),
    ("rajdhani/Rajdhani-Bold.ttf", "Rajdhani-Bold.woff2",
     "47af15713b45605a5d98241b8211a3409f522b34", "Rajdhani",
     (0x0041, 0x0030)),
    ("ibmplexmono/IBMPlexMono-Medium.ttf", "IBMPlexMono-Medium.woff2",
     "33c546f68b6007a45a3f10e845523abb2db25399", "IBMPlexMono",
     (0x0041, 0x0030)),
)
LICENSES = (
    ("notosansjp/OFL.txt", "OFL-NotoSansJP.txt",
     "1c9f43281b8f216c5461fe9ac729afbade7724e4"),
    ("rajdhani/OFL.txt", "OFL-Rajdhani.txt",
     "6dd809659a8ccace7ccee108d024d33cd4f936da"),
    ("ibmplexmono/OFL.txt", "OFL-IBMPlexMono.txt",
     "c35c4c618fab33da8695177b3a6cefe0810b7b28"),
)


def get_verified(path: str, expected_sha: str) -> bytes:
    url = BASE + path
    with urlopen(Request(url, headers={"User-Agent": "SERA-font-vendor/1.0"}),
                 timeout=120) as response:
        raw = response.read()
    header = f"blob {len(raw)}\0".encode()
    actual = hashlib.sha1(header + raw).hexdigest()
    if actual != expected_sha:
        raise ValueError(f"Unexpected font source for {path}: {actual}")
    return raw


def check_coverage(font: TTFont, required: tuple[int, ...], path: str) -> None:
    mapped: set[int] = set()
    for table in font["cmap"].tables:
        if table.isUnicode():
            mapped.update(table.cmap.keys())
    absent = [hex(cp) for cp in required if cp not in mapped]
    if absent:
        raise ValueError(f"Required characters missing from {path}: {absent}")


def main() -> None:
    TARGET.mkdir(parents=True, exist_ok=True)
    for src, output, sha, family, points in ASSETS:
        raw = get_verified(src, sha)
        font = TTFont(BytesIO(raw), recalcBBoxes=False, recalcTimestamp=False)
        check_coverage(font, points, family)
        font.flavor = "woff2"
        out = TARGET / output
        font.save(out)
        reopened = TTFont(out)
        check_coverage(reopened, points, family)
        print(f"{family}: {len(raw):,} bytes -> {out.stat().st_size:,} bytes"
              f" ({out.as_posix()})")
    for src, output, sha in LICENSES:
        (TARGET / output).write_bytes(get_verified(src, sha))
    (TARGET / "README.md").write_text(
        "# Bundled SIL OFL fonts for SERA\n\n"
        "These fonts are redistributed under their individual SIL Open Font "
        "License 1.1 texts in this folder.\n\n"
        "- Noto Sans JP variable (100–900), complete Japanese font.\n"
        "- Rajdhani Bold for technical navigation.\n"
        "- IBM Plex Mono Medium for equipment IDs.\n\n"
        "Source: https://github.com/google/fonts/ "
        "(ofl/notosansjp, ofl/rajdhani, ofl/ibmplexmono).\n"
        "Generated using tools/vendor_sera_fonts.py with Git blob SHA checks; "
        "the font glyph sets are not truncated.\n"
        "WOFF2 files load directly as Godot 4.7 FontFile assets.\n",
        encoding="utf-8"
    )


if __name__ == "__main__":
    main()
