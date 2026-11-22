#!/usr/bin/env python3
"""Protect manual-only test Actions and retained non-test delivery triggers.

This stdlib-only static check does not start GitHub Actions, Godot or Android.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
MANUAL = {
    "base-roof-visual-preview.yml",
    "equipment-godot-web-preview.yml",
    "sera-armour-visible-ink.yml",
    "sera-bittaran-10min-balance.yml",
    "sera-bittaran-focused.yml",
    "sera-bittaran-four-leg-debug.yml",
    "sera-bittaran-original-replay.yml",
    "sera-bittaran-v534-down.yml",
    "sera-model-policy.yml",
    "sera-v293-auto-lock.yml",
    "sera-v535-regression-fixtures.yml",
    "termux-safe-upload-tests.yml",
}
RETAINED = {
    "sera-game-android-apk.yml",
    "sera-gitsync-notify.yml",
    "sera-loader-build.yml",
    "sera-resolved-failure-cleanup.yml",
    "sera-vendor-font-assets.yml",
    "sera-vendor-typography.yml",
    "sera-vendor-ui-fonts.yml",
}


def triggers(path: Path) -> set[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    start = next((i for i, line in enumerate(lines) if line == "on:"), None)
    assert start is not None, f"Missing workflow triggers: {path}"
    result: set[str] = set()
    for line in lines[start + 1:]:
        if line and not line[0].isspace() and not line.lstrip().startswith("#"):
            break
        match = re.match(r"^  ([a-zA-Z_][\w-]*):", line)
        if match:
            result.add(match.group(1))
    return result


def main() -> None:
    actual = {p.name for p in WORKFLOWS.glob("*.yml")}
    assert actual == MANUAL | RETAINED, (
        f"Review newly added/removed workflows before changing policy: "
        f"unexpected={sorted(actual - (MANUAL | RETAINED))} "
        f"missing={sorted((MANUAL | RETAINED) - actual)}"
    )
    for name in sorted(MANUAL):
        assert triggers(WORKFLOWS / name) == {"workflow_dispatch"}, name
    for name in sorted(RETAINED):
        assert {"push", "workflow_dispatch"} <= triggers(WORKFLOWS / name), name
    assert (ROOT / "docs/SERA_MANUAL_TEST_WORKFLOW_ja.md").is_file()
    manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
    assert "py tools/sera_manual_workflow_policy_self_check.py" in manifest
    print(
        f"SERA_MANUAL_ACTIONS_PASS: {len(MANUAL)} manual test workflows, "
        f"{len(RETAINED)} preserved delivery/maintenance workflows"
    )


if __name__ == "__main__":
    main()
