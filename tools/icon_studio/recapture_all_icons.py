#!/usr/bin/env python3
"""Production: recapture every equipped SERA part from the native Godot rig.

This is an asset-generation command, not a game/CI test. The camera preset,
NEXUS_pose, material and mesh sources are all read by the live Godot script.
When capture succeeds, attach per-PNG provenance and rewrite the icon manifest.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAPTURE = ROOT / "tools/icon_studio/sera_all_native_capture.gd"
REGISTER = ROOT / "tools/icon_studio/tag_all_icons.py"


def main() -> None:
    engine = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not engine:
        raise SystemExit(
            "Godot GL Compatibility executable not found. Set GODOT_BIN to its path."
        )
    # The native framebuffer capture requires a real graphics/display context.
    # No CI workflow, gameplay test, or test fixture is invoked here.
    subprocess.run([
        engine, "--path", str(ROOT), "--rendering-method", "gl_compatibility",
        "--script", str(CAPTURE)
    ], cwd=ROOT, check=True)
    # Native images are now on disk; preserve their pixels while adding the
    # source identity to each and recording actual hashes in manifest.json.
    subprocess.run([sys.executable, str(REGISTER)], cwd=ROOT, check=True)
    print("SERA equipment PNG recapture and manifest registration completed.")


if __name__ == "__main__":
    main()
