#!/usr/bin/env python3
"""Validate or rebuild every Android SERA model snapshot from canonical Blockbench sources.

This executes the existing rebuild scripts in a disposable isolated workspace
first, so a failed generation never partially overwrites the live project.
--check compares bytes without any modifications, --write atomically publishes
only changed outputs after ALL generators succeed. Never modifies .bbmodel.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
STEPS = {
    "rebuild_model_data.py": ("assets/sera_source.json", "assets/sera_data.gd"),
    "rebuild_bird_data.py": ("assets/sera_bird_data.gd",),
    "rebuild_equipment_data.py": ("assets/sera_equipment_data.gd",),
    "rebuild_head_c_data.py": ("assets/sera_head_c_data.gd",),
    "rebuild_katana_data.py": ("assets/sera_katana_data.gd",),
    "rebuild_lower_body_d_data.py": ("assets/sera_lower_body_d_data.gd",),
}


def canonical_sources() -> list[Path]:
    manifest = json.loads((ROOT / "models/manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != 1:
        raise ValueError("Unexpected model manifest schema")
    names = {manifest["body_rig"], *manifest["variants"].values(), *manifest["parts"].values()}
    paths = []
    for value in sorted(names):
        path = Path(value)
        if path.is_absolute() or ".." in path.parts or path.suffix != ".bbmodel":
            raise ValueError(f"Unsafe canonical source: {value}")
        location = ROOT / path
        model = json.loads(location.read_text(encoding="utf-8"))
        for required in ("outliner", "groups", "elements"):
            if not isinstance(model.get(required), list):
                raise ValueError(f"{value}: invalid Blockbench {required}")
        for kind in ("groups", "elements"):
            ids = [entry["uuid"] for entry in model[kind]]
            if len(ids) != len(set(ids)):
                raise ValueError(f"{value}: duplicate {kind} UUID")
        paths.append(path)
    return paths


def build_snapshots(temp: Path) -> dict[str, bytes]:
    # All rebuild scripts write into assets/, including the Standard alias.
    (temp / "assets").mkdir(parents=True, exist_ok=True)
    for source in canonical_sources():
        dest = temp / source
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / source, dest)
    for command in STEPS:
        original = ROOT / "tools" / command
        dest = temp / "tools" / command
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, dest)
    expected: dict[str, bytes] = {}
    for command, outputs in STEPS.items():
        process = subprocess.run(
            [sys.executable, str(temp / "tools" / command)],
            cwd=temp, capture_output=True, text=True, timeout=60, check=False)
        if process.returncode:
            raise RuntimeError(f"{command} failed:\n{process.stdout}\n{process.stderr}")
        for output in outputs:
            destination = temp / output
            if not destination.is_file():
                raise RuntimeError(f"{command} did not generate {output}")
            expected[output] = destination.read_bytes()
    return expected


def same_snapshot(name: str, actual: bytes, expected: bytes) -> bool:
    if actual == expected:
        return True
    # The 2026-11-13 Head C embed was serialized by JSON.stringify.
    # Python's json.dumps may spell mathematically identical floats
    # differently (including -0, exponent formatting). Preserve the
    # already verified original text unless its parsed data or executable
    # wrapper actually differs; other files remain strict byte matches.
    if name != "assets/sera_head_c_data.gd":
        return False

    def unpack(content: bytes) -> tuple[str, dict]:
        lines = content.decode("utf-8").splitlines()
        payload = []
        wrapper = []
        for line in lines:
            if line.startswith('    "') and line.endswith('",'):
                payload.append(json.loads(line.strip().removesuffix(",")))
            else:
                wrapper.append(line)
        if not payload:
            raise ValueError("Missing Head C JSON chunks")
        return "\n".join(wrapper), json.loads("".join(payload))

    return unpack(actual) == unpack(expected)


def check_or_write(write: bool = False, root: Path = ROOT) -> list[str]:
    with tempfile.TemporaryDirectory(prefix="sera-model-build-") as directory:
        expected = build_snapshots(Path(directory))
    stale = []
    for name, content in expected.items():
        destination = root / name
        if not destination.is_file() or not same_snapshot(name, destination.read_bytes(), content):
            stale.append(name)
    if write:
        # No live project files are touched before ALL source validation and
        # generation succeeds. Same-directory temporary files enable os.replace.
        for name in stale:
            destination = root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_name(destination.name + ".sera-new")
            try:
                temporary.write_bytes(expected[name])
                os.replace(temporary, destination)
            finally:
                temporary.unlink(missing_ok=True)
    return stale


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--check", action="store_true", help="fail if generated assets are stale; no writes")
    action.add_argument("--write", action="store_true", help="rebuild only changed generated assets")
    args = parser.parse_args()
    try:
        changed = check_or_write(args.write)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"SERA_MODEL_BUILD_FAILED: {error}", file=sys.stderr)
        return 1
    if changed:
        for path in changed:
            print(("UPDATED " if args.write else "STALE ") + path)
    else:
        print("SERA_MODEL_SNAPSHOTS_CURRENT: all six canonical build steps agree")
    return 0 if args.write or not changed else 1


if __name__ == "__main__":
    raise SystemExit(main())
