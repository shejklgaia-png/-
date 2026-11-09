#!/usr/bin/env python3
"""Check SERA model workflow docs, agent references and model PR acknowledgement."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DOC = "docs/MODEL_PART_WORKFLOW_ja.md"
IDENT = "SERA_MODEL_PARTS_V1"
ACK = "MODEL_GUIDE_READ: YES"
AGENTS = ["AGENTS.md", "models/AGENTS.md", "blockbench/AGENTS.md", "assets/AGENTS.md", "scripts/AGENTS.md"]
MODEL_PATHS = {
    "assets/sera_source.json", "assets/sera_data.gd",
    "assets/sera_equipment_data.gd", "scripts/sera_rig.gd",
    "scripts/sera_equipment.gd", "tools/rebuild_model_data.py",
    "tools/rebuild_equipment_data.py",
}

def relevant(path: str) -> bool:
    return path in MODEL_PATHS or (
        path.endswith(".bbmodel") and (path.startswith("models/") or path.startswith("blockbench/"))
    )

def check(files: list[str], body: str) -> list[str]:
    errors = []
    doc = ROOT / DOC
    if not doc.is_file():
        return ["Missing model workflow guide: " + DOC]
    content = doc.read_text(encoding="utf-8")
    for term in (IDENT, ACK, "## 1. ユーザーが用意するもの",
                 "## 2. ChatGPT / Codex が行う処理",
                 "## 3. 骨格・モーション管理方針",
                 "## 4. 現行GitHub実装の基準"):
        if term not in content:
            errors.append("Guide missing expected policy section: " + term)
    for relative in AGENTS:
        path = ROOT / relative
        if not path.is_file():
            errors.append("Missing AGENTS instructions: " + relative)
        else:
            agent_text = path.read_text(encoding="utf-8")
            if "MODEL_PART_WORKFLOW_ja.md" not in agent_text or IDENT not in agent_text:
                errors.append("Missing guide reference in: " + relative)
    model_files = [p for p in files if relevant(p)]
    if model_files and ACK not in body:
        errors.append("Read " + DOC + " and add " + ACK + " to PR body for changes: "
                      + ", ".join(model_files))
    for relative in files:
        if not (relative.endswith(".bbmodel") and
                (relative.startswith("models/") or relative.startswith("blockbench/"))):
            continue
        path = ROOT / relative
        if not path.is_file():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict) or not isinstance(data.get("outliner"), list):
                errors.append("Invalid Blockbench outliner: " + relative)
        except (ValueError, UnicodeError, OSError) as err:
            errors.append("Invalid Blockbench JSON " + relative + ": " + str(err))
    return errors

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base")
    parser.add_argument("--head")
    parser.add_argument("--files", nargs="*")
    parser.add_argument("--pr-body", default=os.environ.get("PR_BODY", ""))
    args = parser.parse_args()
    if args.files is not None:
        files = args.files
    elif args.base and args.head:
        try:
            diff = subprocess.run(
                ["git", "diff", "--name-only", args.base + "..." + args.head],
                cwd=ROOT, capture_output=True, check=True, text=True)
        except (OSError, subprocess.CalledProcessError) as err:
            print("FAIL: Cannot inspect changes:", err)
            return 1
        files = [x.strip() for x in diff.stdout.splitlines() if x.strip()]
    else:
        files = []
    errors = check(files, args.pr_body)
    for error in errors:
        print("FAIL:", error)
    if errors:
        return 1
    print("PASS: Blockbench workflow policy references and PR acknowledgement")
    return 0

if __name__ == "__main__":
    sys.exit(main())
