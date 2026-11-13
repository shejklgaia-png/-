# SERA — coding agents (current operating rules)

> **Latest source of truth:** the user's latest instruction; current GitHub `main` and `project.godot`; the actual scripts and `models/manifest.json`. Old README_vNNN, past conversations and archived guidance are history, **not active specifications**. This short file intentionally supersedes the historical `docs/history/AGENTS_THROUGH_V316.md`.

## Fast, safe work sequence
1. Check the latest `main` SHA, current version in `project.godot`, open PRs, and user-selected feature. Do **not** guess an implementation from version history.
2. Run `python3 tools/sera_workplan.py --query <feature> --json` (or `--changed <path> ...`) to locate likely functions, model sources, dependencies, and registered tests. Review the actual referenced code and relevant current docs. The report is **heuristic**, not a proof of independence.
3. Make a targeted diff on a short-lived branch, preserve unrelated mechanics and authoring sources. For GitHub-only work, batch related file reads and commit related edits together; avoid reviewing every historical README and generated snapshot.
4. Run focused checks while editing (`python3 tools/sera_workplan.py --query <feature> --execute` when available), then **the entire** `tools/sera_ci_manifest.txt` suite through PR CI. Never substitute focused checks for full CI.
5. Review the diff, check CI success and mergeability; create a PR and merge to `main` by default. **Do not merge on failure, conflict or unexplained changes.** Report precisely what ran and what was not verified. Android touch/render/audio checks require actual device execution.
6. Append concise dated details to `DEVELOPMENT.md` for meaningful changes. Create/update a versioned README for gameplay changes; increment SERA version **only for user-requested gameplay changes**, not development tooling.

## Current sources and constraints
- Repository: `shejklgaia-png/-`. Root `project.godot` must be named exactly `SERA v<integer>`. Keep the Android portrait GL Compatibility renderer; no unsolicited engine upgrade or migration.
- **Models:** consult `models/manifest.json` and `docs/SERA_MODEL_SOURCES_ja.md`. Canonical editable sources are `models/core/Standard.bbmodel`, `BirdLeg.bbmodel`, `Katana.bbmodel`, `Equipment.bbmodel`, plus `models/storage/Head_C.bbmodel` and `LowerBody_D.bbmodel`. Older model copies are historical fixtures. `assets/sera_source.json` and embedded `assets/sera_*.gd` are **generated**, rebuild via `tools/rebuild_*_data.py`, not manual edits.
- **Model build:** use `python3 tools/sera_model_build.py --check` to detect stale Android snapshots. For intentional source changes run `--write` after editing the canonical `.bbmodel` and review regenerated diff. This does not replace real Godot checks.
- **Model/animation changes:** read `docs/MODEL_PART_WORKFLOW_ja.md` (**SERA_MODEL_PARTS_V1**) and `docs/SERA_ANIMATION_RUNTIME_POLICY_ja.md`; preserve joint UUIDs, pivots, authored keys and bone mapping. Model PR body requires `MODEL_GUIDE_READ: YES` after actually reading the guide. Always run real Godot clip/playback checks; headless CI is not Android visual verification.
- **3D materials/FX:** read `docs/RENDER_PIPELINE_POLICY_ja.md` and `scripts/render_order_policy.gd`. Preserve depth, draw order, nozzle pivot and transparency policies; run the render regression.
- **Gameplay contracts:** read `docs/SERA_ACTIVE_CI_POLICY_ja.md`. `tools/sera_active_specs.json` contains **approved** current STEP/kick values; change it only with an intentional gameplay specification change, never to silence a genuine regression. Superseded vNNN assertions must be distinguished from permanent invariants.
- **Input/HUD changes:** run `tools/sera_parameter_audit.py` when applicable. Source-specific entry points: `docs/SERA_DEVELOPMENT_FASTPATH_ja.md`; broader design notes: `docs/SERA_MEMORY_INDEX.md`.
- **GitSync/phone:** only merged `main` reaches the normal Android checkout; never overwrite unpushed Blockbench/Godot edits or sync while editors write. Do not repeatedly ask the user to synchronize or launch the project.
- No secrets, signing keys, credentials, arbitrary dependencies, or unwarranted deletion of user models. If source is ambiguous, inspect hierarchy/Pivot before assigning a bone.

## Quick commands
```sh
python3 tools/sera_workplan.py --query step --json     # focused edit plan
python3 tools/sera_workplan.py --query katana --execute # local registered Python tests only
python3 tools/sera_quick_check.py                       # core static checks
python3 tools/sera_ci_suite.py static --workers 4      # FULL registered Python suite
# GitHub PR CI runs the FULL Godot suite, in isolated processes.
```

Historical instructions and v102–v292 decisions remain available at `docs/history/AGENTS_THROUGH_V316.md`; their superseded numeric values, model paths and design drafts must not override the current code.

## v317 optional Android diagnostics
- During Android training only, DIAG: OFF toggles diagnostic recording ON. COPY LOG copies bounded local runtime samples to the device clipboard; paste into chat for analysis. No telemetry or network access when OFF. Details in `docs/SERA_ANDROID_DIAGNOSTICS_ja.md`.
- Existing touch controller areas and ordinary game logic must not be changed for diagnostic instrumentation.

## v317 main.gd extraction policy
- The existing main.gd gesture/locomotion wrapper methods remain the public compatibility surface for Godot tests, scene inputs and older scripts. Edit pure gesture classification in `scripts/sera_input_gestures.gd` and actor/screen XZ transforms in `scripts/sera_movement_math.gd`; main.gd passes approved active constants and scene state into them. Do not duplicate thresholds or change their meaning.
- This is the first staged split, **not** a license for a simultaneous high-risk rewrite of `_physics_process`, combat cancellation, camera/locking state or scene lifecycle. Run full PR CI and Android visual checks after further behavioral changes.

## v317 staged main lock extraction
- The live lock state, combo retention, AUTO/MANUAL mode and lock input button ownership remain in `scripts/main.gd`. Candidate selection (actor pair-lines AUTO; projected-X manual wrap), target yaw-facing vector, and reticle projection are in `scripts/sera_lock_management.gd`. Keep the existing public `main.gd` method entry points for compatibility.
- A BODY lock is the empty string; do not introduce artificial 0.22s auto delay or require camera-based rays for AUTO. Existing tests and user-confirmed v317 behavior are mandatory baselines.

## v317 staged main combat-flow split
- Stateless combo/guard eligibility, lock-retention windows, authored strike stage selection, cancel timing and limited tracking-frame durations live in `scripts/sera_combat_flow.gd`. The state and every mutation, resource usage, animation and collision side effect remain in `main.gd` under the original method signatures.
- Do not reset queued follow-up input or move combat_state to another node opportunistically. Preserve Katana 2-stage vs normal 3-stage behavior, Melee3 flick cancel, Bash/Kick/landing lock retention and legacy test coverage.

## v317 staged camera-framing extraction
- `scripts/sera_camera_framing.gd` owns only pure perspective radius and close STEP yaw limits. `main.gd` retains Camera3D, near plane, frustum/viewport loops, live camera state, screen projection, and original method signatures. Preserve all numeric margins, yaw speed, near-plane reserve and runtime behavior.

## v317 staged BOOST state extraction
- `scripts/sera_boost_state.gd` owns stateless RUN/BOOST finger-distance hysteresis and 0.20s speed transition calculations. Main keeps mutable gesture/transition variables, scene pointer, EN eligibility, equipment multipliers, UI/rig effects and method entry points. Do not alter thresholds, confirmation, mid-blend reversal or 60% EN recovery semantics.

## v317 staged EN/SH resource-rules extraction
- `scripts/sera_resource_rules.gd` owns pure EN spending decisions, recovery-pause decay, EN/SH regeneration and 60%-of-max exhaustion unlock tests. Main still owns live resources, scene/UI updates, exhaustion flashing, equipment costs, KO/down/guard-break sequencing, and the final depleted BOOST sliver exhaustion side effect. Rates and thresholds remain defined by current main callers; do not re-order pause decay/recovery within a frame.
