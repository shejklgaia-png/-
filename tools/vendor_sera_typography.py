#!/usr/bin/env python3
"""Vendor SIL OFL Japanese typefaces for SERA's mixed industrial LAB UI.

Fetch *complete* official Google Fonts binaries, verify Git blob SHA, convert
to compressed WOFF2, retain license notices, and check the glyphs LAB uses.
This script runs inside GitHub Actions; Android never downloads fonts.
"""
from __future__ import annotations

import hashlib
from io import BytesIO
from pathlib import Path
from urllib.request import Request, urlopen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "fonts"
SOURCE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
JAPANESE = tuple(map(ord, "装備製作精製素材倉庫頭部胴体腕脚推進右手左戻る診断最大防御所持数スカウトバイザー空欄未開放属性"))
SOURCES = (
    ("mplus2/MPLUS2%5Bwght%5D.ttf", "MPLUS2-VF.woff2",
     "7f79c56b4dd6b26aa42add535ec763b66678467e", JAPANESE),
    ("mplus1code/MPLUS1Code%5Bwght%5D.ttf", "MPLUS1Code-VF.woff2",
     "9135b5fa00ea59ac8a02eabf3448c266019fd4ee", JAPANESE),
    ("ibmplexsansjp/IBMPlexSansJP-Medium.ttf", "IBMPlexSansJP-Medium.woff2",
     "0f26ce614000d61644b51e8e0722167055f6fec0", JAPANESE),
    ("ibmplexsansjp/IBMPlexSansJP-Bold.ttf", "IBMPlexSansJP-Bold.woff2",
     "8281e3ada7cca6a5d652fbd28bd6447d4a0f54b9", JAPANESE),
)
LICENSES = (
    ("mplus2/OFL.txt", "OFL-MPLUS2.txt", "b038fd111aff94bffc3fc21f239a556a84209a07"),
    ("mplus1code/OFL.txt", "OFL-MPLUS1Code.txt", "b038fd111aff94bffc3fc21f239a556a84209a07"),
    ("ibmplexsansjp/OFL.txt", "OFL-IBMPlexSansJP.txt", "c35c4c618fab33da8695177b3a6cefe0810b7b28"),
)


def read_verified(path: str, expected_git_sha: str) -> bytes:
    request = Request(SOURCE + path, headers={"User-Agent": "SERA-typography-assets/1.0"})
    with urlopen(request, timeout=120) as response:
        data = response.read()
    blob_sha = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
    if blob_sha != expected_git_sha:
        raise RuntimeError(f"Source SHA mismatch for {path}: {blob_sha}")
    return data


def check_glyphs(font: TTFont, required: tuple[int, ...], label: str) -> None:
    available = set()
    for table in font["cmap"].tables:
        if table.isUnicode():
            available.update(table.cmap.keys())
    missing = [f"U+{code:04X}" for code in required if code not in available]
    if missing:
        raise RuntimeError(f"{label}: missing LAB glyphs {', '.join(missing)}")


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    for source, name, sha, required in SOURCES:
        raw = read_verified(source, sha)
        face = TTFont(BytesIO(raw), recalcTimestamp=False)
        check_glyphs(face, required, name)
        face.flavor = "woff2"
        target = ASSETS / name
        face.save(target)
        check_glyphs(TTFont(target), required, name)
        if target.read_bytes()[:4] != b"wOF2":
            raise RuntimeError(f"Invalid WOFF2 signature in {name}")
        print(f"{name}: {len(raw):,} -> {target.stat().st_size:,} bytes")
    for source, name, sha in LICENSES:
        (ASSETS / name).write_bytes(read_verified(source, sha))
    (ASSETS / "TYPOGRAPHY-README.md").write_text(
        "# SERA LAB typography (v548)\n\n"
        "Bundled complete fonts from the Google Fonts upstream repository, "
        "redistributed under their respective SIL Open Font License v1.1 "
        "notices in this folder. Android does not fetch fonts from a CDN.\n\n"
        "M PLUS 2: prominent Japanese headlines and equipment names.\n"
        "IBM Plex Sans JP: Japanese controls, panels and body text.\n"
        "M PLUS 1 Code: Japanese technical information and status lines.\n"
        "Rajdhani Bold + IBM Plex Mono: technical English labels (unchanged).\n"
        "Noto Sans JP remains available for compatibility if needed.\n\n"
        "Sources: https://github.com/google/fonts/tree/main/ofl/mplus2, "
        "/mplus1code, /ibmplexsansjp. Source Git SHA is verified by "
        "tools/vendor_sera_typography.py.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
