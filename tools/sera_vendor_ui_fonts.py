#!/usr/bin/env python3
"""Vendor the exact, OFL-licensed UDEV Gothic and Moralerspace release TTFs.

No font is generated or modified. Archive SHA-256 values are independently
published by Homebrew, avoiding mutable tags and unexpected substitutions.
Only the four normal/bold faces used by SERA are extracted.
"""
from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import sys
import time
from urllib.request import Request, urlopen
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "fonts"

RELEASES = (
    {
        "name": "UDEV Gothic",
        "version": "2.2.0",
        "archive": "https://github.com/yuru7/udev-gothic/releases/download/v2.2.0/UDEVGothic_v2.2.0.zip",
        "sha256": "c104c171f6ed8922ca52d74cd915a271e427f1e884e51431aae71d99e8b3b47b",
        "files": ("UDEVGothic-Regular.ttf", "UDEVGothic-Bold.ttf"),
        "license_url": "https://raw.githubusercontent.com/yuru7/udev-gothic/v2.2.0/LICENSE",
        "license_name": "OFL-UDEVGothic.txt",
    },
    {
        "name": "Moralerspace Neon",
        "version": "2.0.0",
        "archive": "https://github.com/yuru7/moralerspace/releases/download/v2.0.0/Moralerspace_v2.0.0.zip",
        "sha256": "56175ee16373ba1a3d2fd5ec46f3b0b6bf0412be7db1481ec7dee757f2e3d557",
        "files": ("MoralerspaceNeon-Regular.ttf", "MoralerspaceNeon-Bold.ttf"),
        "license_url": "https://raw.githubusercontent.com/yuru7/moralerspace/v2.0.0/LICENSE",
        "license_name": "OFL-Moralerspace.txt",
    },
)

def _valid_font(data: bytes) -> bool:
    return len(data) > 50_000 and data[:4] in (b"\\x00\\x01\\x00\\x00", b"OTTO")

def _check_one(release: dict) -> None:
    for name in release["files"]:
        path = DEST / name
        if not path.is_file() or not _valid_font(path.read_bytes()):
            raise ValueError(f"Missing or invalid font: {path}")
    license_path = DEST / release["license_name"]
    if not license_path.is_file():
        raise ValueError(f"Missing OFL license: {license_path}")
    text = license_path.read_text("utf-8")
    if "SIL OPEN FONT LICENSE" not in text.upper():
        raise ValueError(f"Unexpected license: {license_path}")

def _download(url: str) -> bytes:
    # Official GitHub release redirects can occasionally be transient.
    for attempt in range(3):
        try:
            request = Request(url, headers={"User-Agent": "SERA-font-vendor/1.0"})
            with urlopen(request, timeout=180) as response:
                content = response.read(350 * 1024 * 1024 + 1)
            if len(content) > 350 * 1024 * 1024:
                raise ValueError("Archive exceeded the 350MB safety cap")
            return content
        except (OSError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)
    raise RuntimeError("Unreachable")

def _install_one(release: dict) -> None:
    try:
        _check_one(release)
        print(f"EXISTS: {release['name']} (license and fonts verified)")
        return
    except (ValueError, OSError):
        pass
    print(f"FETCH: {release['name']} {release['version']}", flush=True)
    archive = _download(release["archive"])
    observed = hashlib.sha256(archive).hexdigest()
    if observed != release["sha256"]:
        raise ValueError(
            f"SHA-256 mismatch for {release['name']}: {observed}")
    selected: dict[str, bytes] = {}
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        for target in release["files"]:
            candidates = [item for item in z.infolist()
                          if not item.is_dir()
                          and PurePosixPath(item.filename).name == target]
            if len(candidates) != 1:
                raise ValueError(f"Expected one archive entry for {target}")
            info = candidates[0]
            if info.file_size > 45 * 1024 * 1024:
                raise ValueError("Font larger than 45MB limit: " + target)
            data = z.read(info)
            if not _valid_font(data):
                raise ValueError("Invalid TrueType font: " + target)
            selected[target] = data
    license_data = _download(release["license_url"])
    if b"SIL OPEN FONT LICENSE" not in license_data.upper():
        raise ValueError("License does not contain SIL OFL declaration")
    DEST.mkdir(parents=True, exist_ok=True)
    for name, data in selected.items():
        (DEST / name).write_bytes(data)
        print(f"VENDORED: {name} ({len(data)} bytes; source ZIP SHA-256 verified)")
    (DEST / release["license_name"]).write_bytes(license_data)
    _check_one(release)

def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--download", action="store_true")
    args = parser.parse_args()
    try:
        for release in RELEASES:
            if args.download:
                _install_one(release)
            else:
                _check_one(release)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"SERA_FONT_VENDOR_FAILED: {exc}", file=sys.stderr)
        return 1
    print("SERA_DUAL_JP_FONTS_VENDOR_PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
