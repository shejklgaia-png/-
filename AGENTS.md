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

## v317 main.gd split contracts
Keep `main.gd` live state, inputs, collisions, scene effects, HUD priority and tick ordering. Extract presentation/math only without changing numeric thresholds. Require full PR CI; verify Android visuals separately.

- **Gesture/locomotion:** `sera_input_gestures.gd`, `sera_movement_math.gd` own pure input and XZ transforms. Main owns touch, player and camera.
- **Lock:** `sera_lock_management.gd` owns paired-ray AUTO, manual screen-X wrap, facing and reticle geometry; main owns modes, combo lock and buttons. BODY ID is `""`; no delayed acquisition.
- **Combat:** `sera_combat_flow.gd` owns guard/combo gates, timing, clips and homing slices. Main owns strikes, queued input, EN, collision and authored animation. Normal 3-hit/Katana 2-hit and combo locks remain.
- **Camera:** `sera_camera_framing.gd` owns pure fit and STEP yaw; main owns physical camera, framing, zoom and collision.
- **BOOST:** `sera_boost_state.gd` owns finger hysteresis and 0.20s speed smoothstep. Main owns active touch, EN, equipment, visual pose and reversal continuity.
- **EN/SH:** `sera_resource_rules.gd` owns EN spending and recovery. Main owns HUD, KO and final BOOST sliver. Preserve 24/16 per-second rates, 0.25s spend pause, epsilon 0.0001 and 60% unlock.
- **Combat timers:** `sera_combat_timers.gd` owns countdown/stagger math. Main owns KO, UI, stagger/fire ordering and damage completion.
- **Hit FX:** `sera_hit_fx_presentation.gd` updates passed overlay/material/labels only. Main owns timers, hit-stop, parts, FX order and respawn.
- **Target:** `sera_target_lifecycle.gd` decides movement, firing and respawn. Main owns parts, 0.01s combo retry, locks, resets, KO teleport and HUD.
- **Physics frame:** `sera_physics_frame_rules.gd` owns pose grace, flight movement, real velocity, jet and burst gates. Main owns physics, rig/FX and input order; stationary melee retains exhaust.
- **Motion/nozzle:** `sera_motion_direction.gd` computes RUN/jet heading; `sera_nozzle_steering.gd` computes rear/left bias; `sera_thruster_presentation.gd` owns BOOST cache and final FX call. Main retains camera, movement, collision, EN and rig controls. Nozzle articulation limits stay ±80° yaw/up 1°/down 90°.
- **Combat HUD:** `sera_combat_hud_text.gd` owns action text; `sera_numeric_hud.gd` owns HP/EN, target HP bars, DEF/SH, lock stats and STEP telemetry. Main owns status priority, resource/part selection, combat ticks and HUD nodes.

See `docs/SERA_DEVELOPMENT_FASTPATH_ja.md` and `DEVELOPMENT.md` for details.
