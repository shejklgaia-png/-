# SERA — coding agents (compact entrypoint)

> **Authority:** latest user instructions, latest `main`, `project.godot`, running code, and `models/manifest.json`. Old notes (`docs/history/`) are not current specifications. This file is the small mandatory entrypoint; all prior operative rules were preserved verbatim by section in `docs/agent/`.

## Required for every change
1. Verify current `main` SHA, open PRs, `project.godot` version and real source before editing. Never infer the live state from memory or older README.
2. **Read `docs/agent/CI_WORKFLOW.md` on every change**, and inspect `.github/workflows/`, `tools/sera_ci_manifest.txt`, `docs/SERA_ACTIVE_CI_POLICY_ja.md`, and related current tests **before** implementation. Classify new expectations, old expectations, invariants and unaffected tests. For intentional spec changes, update related CI tests first and keep them in the same PR. Never delete, skip or weaken tests to hide regressions.
3. Generate a focused plan with `python3 tools/sera_workplan.py --query "<user request>" --json` (or `--changed <path>`), then read its `documentation.required` and `documentation.selected`. Inspect selected code/tests; routing is heuristic, not authority. For unmapped or mixed features, manually expand dependencies and run complete CI.
4. Work in a short-lived branch. Keep unrelated behavior, model masters, existing save formats, Android compatibility and inputs intact. Use existing modules; avoid speculative rewrites.
5. Run focused registered checks when appropriate. **Merge first; run the FULL registered Python and Godot CI on `main` afterward.** If CI fails, diagnose and fix the regression, rerun, and report accurate status and links. Headless checks do not establish Android visual, touch, motion or audio correctness.
6. Update `DEVELOPMENT.md` for meaningful changes. Increment SERA version only for requested gameplay changes.

## Routed rules (load when relevant)
- `docs/agent/SOURCE_POLICY.md`: canonical model sources, generated assets, GitSync/Android, import, rendering and diagnostic guards.
- **HTML配布・起動リンク:** `docs/SERA_HTML_ARTIFACT_DELIVERY_POLICY_ja.md` — Raw URLをアプリの直リンクとして提示しない。公開HTTPS/実HTML添付/複数ファイル配布を区別し、起動を確認する。
- `docs/agent/EQUIPMENT.md`: warehouse individual UID / 999-limit rules, Icon Studio handoff, LAB integration, model acceptance. **New-chat equipment implementation contract:** `docs/SERA_EQUIPMENT_CROSS_CHAT_HANDOFF_ja.md` (mandatory for `SERA_EQUIPMENT_INTAKE_V1` exports).
- `docs/agent/RUNTIME_BOUNDARIES.md`: `main.gd` split-contract ownership for input, physics, combat, camera, EN, HUD and FX.
- **BASE external visual changes:** `docs/agent/BASE_VISUAL_REVIEW.md` — every BASE design change requires opening the current actual gameplay screenshot, running a new full-initialization screenshot at the unchanged camera, inspecting the real image, iterating until the on-screen silhouette is readable, and providing before/after image evidence. Do not merge based on CI text alone.
- Feature-specific canonical contracts are selected by `tools/sera_workplan.py`; read the underlying `docs/` specifications and real source. When models or animations change, also read `docs/MODEL_PART_WORKFLOW_ja.md` (**SERA_MODEL_PARTS_V1**), `docs/SERA_ANIMATION_RUNTIME_POLICY_ja.md`, and `models/manifest.json`. When rendering changes, read `docs/RENDER_PIPELINE_POLICY_ja.md`.
- Old, superseded policies are retained at `docs/history/AGENTS_THROUGH_V316.md`, not treated as current.

## Quick checks
```sh
python3 tools/sera_workplan.py --query "倉庫 UI" --json
python3 tools/sera_workplan.py --query step --execute
python3 tools/sera_quick_check.py
python3 tools/sera_ci_suite.py static --workers 4
# Full Godot checks: registered CI workflow on main after merge.
```
