#!/usr/bin/env python3
"""SERA repository layout: current README, archived releases, canonical model files.

This is a contract check, not a generic 'unused file' detector. Runtime res://
and Blockbench references must always be audited before any separate cleanup.
"""
from __future__ import annotations

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
match = re.search(r'^config/name="SERA v(\d+)"$', PROJECT, re.M)
assert match is not None, "project.godot must be the version authority"
current_version = int(match.group(1))
assert current_version >= 318

release_name = re.compile(r"README_v([0-9]+)_ja\.md")
root_releases = sorted(ROOT.glob("README_v*_ja.md"))
# Only the current release README belongs at the repository root.
# Older notes must be archived unchanged to avoid misleading version links.
assert root_releases == [ROOT / f"README_v{current_version}_ja.md"], [
    x.name for x in root_releases]
assert all((found := release_name.fullmatch(file.name)) is not None and
           int(found.group(1)) <= current_version for file in root_releases), [
               x.name for x in root_releases]

archive = ROOT / "docs/history/release_notes"
assert archive.is_dir()
previous_releases = sorted(archive.glob("README_v*_ja.md"))
assert len(previous_releases) >= 288, len(previous_releases)
versions = []
for file in previous_releases:
    found = release_name.fullmatch(file.name)
    assert found is not None, file
    version = int(found.group(1))
    assert version < current_version, (file.name, current_version)
    assert file.is_file() and file.stat().st_size > 0, file
    versions.append(version)
assert len(versions) == len(set(versions))
assert (archive / "README_legacy_ja.md").is_file()
assert (archive / "README.md").is_file()
assert (archive / "README_v317_ja.md").is_file()
# Historical v430-v451 notes are retained byte-identically in the archive.
for version in range(430, 452):
    assert (archive / f"README_v{version}_ja.md").is_file()

# Probe markers and a byte-identical trashed backup had no active roles.
obsolete = (
    "SERA_AUTOSYNC_TEST.txt",
    "SERA_SAFE_SYNC_TEST.txt",
    "SYNC_PROBE_20261107_STAMINA.txt",
    "models/storage/.trashed-1796821878-頭C.bbmodel",
)
for relative in obsolete:
    assert not (ROOT / relative).exists(), f"Obsolete marker recurred: {relative}"
assert (ROOT / "models/storage/頭C (2)_20261109_222329_691.bbmodel").is_file()

# Never treat generated runtime copies as interchangeable with model masters.
manifest = json.loads((ROOT / "models/manifest.json").read_text(encoding="utf-8"))
canonical = {
    manifest["body_rig"],
    *manifest["variants"].values(),
    *manifest["parts"].values(),
}
# HEAD D (camera-eye) is an approved seventh editable source recorded in
# models/manifest.json; verify the actual expected source instead of the old six.
assert manifest["parts"]["head_camera_eye"] == "models/storage/カメラアイ頭部.bbmodel"
assert len(canonical) == 7, canonical
for relative in canonical:
    assert relative.startswith(("models/core/", "models/storage/")), relative
    assert (ROOT / relative).is_file(), f"Missing authoring source: {relative}"
for relative in (
    "assets/sera_source.json",
    "assets/sera_data.gd",
    "scripts/main.gd",
    "scripts/sera_rig.gd",
    "scenes/main.tscn",
    "tools/sera_ci_manifest.txt",
):
    assert (ROOT / relative).is_file(), f"Missing runtime/CI source: {relative}"

index = (ROOT / "README_ja.md").read_text(encoding="utf-8")
root_index = (ROOT / "README.md").read_text(encoding="utf-8")
rules = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
source_policy_path = ROOT / "docs/agent/SOURCE_POLICY.md"
assert source_policy_path.is_file(), "Routed canonical source policy missing"
source_policy = source_policy_path.read_text(encoding="utf-8")
for text in (index, root_index):
    assert f"README_v{current_version}_ja.md" in text
    assert "docs/history/release_notes/" in text
    assert "docs/SERA_REPOSITORY_LAYOUT_ja.md" in text
# The root AGENTS is now a compact routing entrypoint. Verify that it links
# to the real source policy and that the actual layout rule remains in force.
assert "docs/agent/SOURCE_POLICY.md" in rules
assert "docs/SERA_REPOSITORY_LAYOUT_ja.md" in source_policy
assert "docs/history/release_notes/" in source_policy
assert (ROOT / "docs/SERA_REPOSITORY_LAYOUT_ja.md").is_file()

# Avoid moving tests: the CI manifest intentionally uses tools/ paths.
test_lines = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8").splitlines()
assert any("tools/v317_hud_layout_runtime_check.gd" in x for x in test_lines)
assert any("tools/sera_repository_layout_self_check.py" in x for x in test_lines)
print(
    "SERA_REPOSITORY_LAYOUT_PASS:",
    len(previous_releases), "historical releases;",
    len(canonical), "canonical model sources retained;",
    len(obsolete), "obsolete artifacts absent",
)
