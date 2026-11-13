# SERA — Codex / coding-agent repository instructions

## Current-contract CI and fast navigation (2026-11-13)
- Read `docs/SERA_ACTIVE_CI_POLICY_ja.md` before modifying gameplay or tests. The approved numerical STEP/kick contract is `tools/sera_active_specs.json`; update it with intentional gameplay changes only. Never let historical vNNN tests enforce superseded numeric values, and never suppress actual regressions.
- Start scoped investigation with `python3 tools/sera_dev_index.py <term> --json`; inspect relevant source afterward. This index does not resolve dynamic calls.
- Shared PR CI still runs every registered test in isolated processes. Real Godot runtime checks remain mandatory for animation changes; Android verification is separate.


## Goal and baseline
- This is the Godot 4.x, **Android-first portrait 3D action prototype** "SERA". **Do not treat the historical v102/v103 notes below as the current build.** Determine the current integrated version from `project.godot`, then read its `README_vNNN_ja.md` and the actual code. First consult `docs/SERA_DEVELOPMENT_FASTPATH_ja.md` for change-localized investigation.
- `project.godot` must remain **at the repository root**. Read its actual Godot feature version (`config/features`), **GL Compatibility** renderer and portrait viewport rather than relying on old version notes. Do not automatically migrate renderers, upgrade the engine, or change display settings.
- Primary verification is via **Godot Editor on Xperia 1 V (Android)**. A cloud/desktop headless test does not verify touch control feel, rendering or audio on the phone.

## Nonnegotiable edit policy
1. Keep all existing features, input mappings, assets, animation clips, scene paths, and gameplay logic unless the user explicitly asks for a change. Make the **smallest targeted diff**.
2. Before edits, inspect `docs/SERA_DEVELOPMENT_FASTPATH_ja.md`, the current project version and matching README, `DEVELOPMENT.md`, and related actual scripts; check the Git diff and note the commit/branch as baseline. Never silently discard uncommitted changes. Past v102 documents are historical, not the current baseline.
3. Create a separate branch / pull request for each feature. After reviewing the scoped diff and available checks, **merge the PR into `main` as part of the same task by default without requesting a separate user instruction**. Explicitly report any Android/device checks not performed. If checks fail, the PR conflicts, or a change appears unsafe, stop rather than forcing a merge; explain the blocker.
4. Test what you can and report **exactly** which checks ran; do not state Android/Godot runtime validation unless actually executed.
5. For each requested code change, append a concise dated section to `DEVELOPMENT.md`, add/update the relevant versioned README/test, and report changed files, preserved functions, test results, and known untested items. Bump the game version only on actual user-authorized game changes.
6. Never add credentials, tokens, signing keystores or other private data to the repository. Avoid unnecessary dependencies/network access.

## Godot project name (mandatory)
- The `[application]` `config/name` in the root `project.godot` **must be exactly `SERA v<version>`**, e.g. `SERA v146`, with no suffix, subtitle, change summary, extra spaces, or other labels.
- When implementing an approved game change and bumping the game version, derive the next version from the current `project.godot` and update `config/name` to `SERA v<next-number>`; do not assume an old example is current. A project-title-only correction does **not** increment the gameplay version.
- Describe changes in `DEVELOPMENT.md`, the versioned `README_vXXX_ja.md`, Git commits, and PRs; **never** in the visible Godot project title. This keeps the project-switcher text compact and stops changes in subtitle length from shifting the Run button position.
- Run `python3 tools/project_name_self_check.py` when updating the project title. Its regex check is future-version-agnostic.

## Current layout and important behavior (the v102 details below are historical; recheck today's code)
- `project.godot` → `scenes/main.tscn` → `scripts/main.gd`.
- `scripts/sera_rig.gd`: dynamic Blockbench mesh/animation reconstruction; animation state, skeleton, Guard pose.
- `scripts/touch_overlay.gd`, `scripts/enemy_*`, `scripts/sword_trail.gd`, `scripts/hit_burst.gd`, `shaders/`: controls, combat, camera-related effects etc. Inspect actual code before touching.
- Current Blockbench JSON is **`assets/sera_source.json`**. **`assets/sera_data.gd` is generated** by `python3 tools/rebuild_model_data.py` and must match JSON exactly; it allows Godot to load embedded model data.
- `blockbench/SERA_Guardfix_user_input.bbmodel` is the user-provided v102 source, byte identical to the separate `SERA_Guardfix.bbmodel` supplied for this packaging. `blockbench/SERA_v102_guardfix_integrated.bbmodel` equals `assets/sera_source.json`. Preserve the source and the original/history `.bbmodel` files. When updating a model, edit the source and integrated model intentionally, regenerate embedded data, and update matching tests and history.
- v102 guard: stationary hold for ~0.32 s (release to end); block movement/boost/step/attack/jump during guard; guard suppresses normal hit reaction/knockback. **Shield depletion, guard break, bash were not implemented in v102.** Do not invent them.
- Melee: 3 hits with damage `[12, 12, 26]`. Backstep: 4 m. Jump: touch input disabled by default; keep debug-only `JUMP TEST` and keyboard J test. Preserve close-range step/boost, camera and audio behaviors.

## Verification contract
Run from repository root:

```sh
python3 tools/sera_code_map.py camera          # optional targeted code navigation
python3 tools/sera_quick_check.py              # core read-only static checks
python3 tools/sera_quick_check.py --render     # additionally checks 3D render contract
```

The quick check calls the existing `codex_project_check.py`, `self_check.py`, `project_name_self_check.py`, and the new developer-tool self-check; it does **not** replace relevant version-specific regressions (e.g. `v102_guardfix_self_check.py` for historical Guard work), PR CI, or Android device verification.

Additional historical checks may refer to unavailable prior ZIPs; read their preconditions before running them. Use `python3 -m compileall -q tools` for Python syntax if relevant. If a compatible Godot editor binary is available, run `godot --headless --path . --import` and capture its exit code/log; optionally run a short headless scene smoke test. This is **not equivalent to Android runtime verification**. If no Godot binary exists, say "Godot runtime not tested". When updating a feature intentionally, adjust its regression tests without deleting useful coverage.

## GitSync / Android continuation
- The local GitSync repository's directory **must be the same directory** that Godot Android opens, containing `project.godot` at its root.
- A branch/PR alone is not visible through phone sync. By default, finish each verified change by merging its PR into `main` during the same task, then sync GitSync and reopen/reload the Godot project on phone. Do not require a separate “merge” request.
- Never auto-pull while Godot or Blockbench is actively writing the same files; protect local edits from being overwritten. Check `.gitignore` to avoid syncing cache.

## Do not overstate
- Successful Python static tests do not prove that Godot parses or renders the complete game, and a successful headless import does not prove Android touch behavior.
- The **original 2026-11-06 packaging step** made no functional changes to v102; this is historical information, not a statement about the current game version.

## Shared SERA design-memory documents (2026-11-06)
- Before planning gameplay changes, read `docs/SERA_MEMORY_INDEX.md` and the linked topic documents.
- Before changing RUN/BOOST controller dimensions, run `python3 tools/sera_parameter_audit.py`; for any code change, use `python3 tools/sera_change_impact.py --changed <path>` to suggest scoped regressions (full CI remains mandatory). Details: `docs/SERA_AGENT_MAINTENANCE_ja.md`. They preserve user decisions from ChatGPT conversations for Codex.
- Treat each item's status honestly: **implemented**, **decided but not implemented**, **under consideration**, **historical**, or **needs verification**. Memory does not override actual v102 code or the latest user request. Do not implement future ideas without an explicit instruction.
- Keep documents consistent with the actual code, the relevant versioned README, tests, and `DEVELOPMENT.md` when a feature is approved and changed. This handoff adds documentation only; **do not change game version or assets**.

## Mandatory source of truth and branch policy (2026-11-06)
- **GitHub is the canonical editable source of the SERA project, including Godot code, Blockbench models, animation data, shaders, audio, and project documentation.** Repository: `shejklgaia-png/-`. Work from current GitHub files, not an older chat attachment or ZIP. ZIPs are for backup, exceptional handoff or requested releases only. ChatGPT and Codex both follow this workflow.
- Use **GitHub Flow**: `main` is the latest integrated baseline, **not necessarily Android-tested**. Create one short-lived work branch for each isolated change; no permanent `develop` branch. Names: `feat/<topic>` for features, `fix/<topic>` for defects, `asset/<topic>` for Blockbench/animation/FX/audio, and `docs/<topic>` for documentation. Keep names short and descriptive.
- Before editing: read `AGENTS.md` plus applicable game-memory docs, check latest remote `main`, current commit SHA, pending branches/PRs, and any uncommitted changes. Base new work on the latest suitable commit. Do not overwrite concurrent ChatGPT/Codex work.
- Make the **smallest relevant change** on its work branch; verify GDScript syntax, scene and resource paths, generated model data, regression tests and diff scope as applicable. Describe executed tests and missing tests accurately. Update `DEVELOPMENT.md` and the applicable versioned README for gameplay changes; do not advance the gameplay version for documentation-only updates.
- Open a pull request from the work branch to `main`, review changes/test results, and **merge it before completing the task by default**. The user gave standing authorization on 2026-11-06 to merge future SERA edits automatically, including changes not yet verified on Xperia 1 V. Cloud/headless/static checks are not Android acceptance: report unverified device behavior clearly and never claim phone validation. Do not merge a failed check, unexpected unrelated diff, or unresolved conflict; report the blocker instead of bypassing it.
- For phone testing, prefer a **separate test checkout** (e.g. `/storage/emulated/0/GAME/SERA_TEST/`) from the stable GitSync checkout (currently `/storage/emulated/0/GAME/Git/`). The test checkout must open its own `project.godot` and follow the work branch. Do not make test work modify or overwrite the stable directory.
- After change review and all **available** checks pass, merge the PR to `main` automatically, even if Android verification has not been performed; label that verification as pending. Delete the short-lived branch when no longer needed, if supported. The user then syncs `main` with GitSync and reloads Godot Android. A branch/PR update alone **does not** update the phone's `main` checkout. Avoid sync while Godot or Blockbench is writing files.
- Documentation-only changes may be merged after reviewing the diff without requiring gameplay retesting, provided that no runtime files changed. **The standing auto-merge instruction does not authorize bypassing failed verification or forcing through conflicts.** Never force-push `main`, delete user source assets, or modify unrelated features without express user authorization.
 
## Blockbench customization asset conventions (v164)
- Treat `models/SERA_BOOSTER_allテスト.bbmodel` as the combined full-body authoring file. A is the first character root, B the second; new sets follow in the same outliner. The six runtime slots are head, torso, lower body, arms, right-hand weapon and left-hand weapon.
- The runtime loader resolves meshes by **parent group hierarchy, matching original bone names and pivot coordinates**, not only exact mesh names. Preserve left/right topology and joint locations; e.g. `Head2/sphere` is a valid B head. Never bind an ambiguous renamed joint to an arbitrary bone.
- When edited parts are intended for export, run `python3 tools/rebuild_equipment_data.py` to update the embedded snapshot. Keep the original Blockbench source and all A animations intact; do not replace `assets/sera_source.json` just to switch costume meshes.
 
## Mandatory 3D rendering contract (2026-11-10, v226)
- **Before creating or modifying 3D effects, materials, render overlays, weapons or motion-linked visual meshes, read `docs/RENDER_PIPELINE_POLICY_ja.md` and inspect `scripts/render_order_policy.gd`.** This covers draw order, alpha blending, depth-testing, parent hierarchy and final animation/servo pose. Never treat these as interchangeable causes of visual disappearance.
- All explicit transparent `render_priority` values belong to the named policy roles; do not scatter priority integers or rely on implicit priority 0 for a new transparent effect. `+127` is the Godot upper limit, not an ever-increasing allocation counter.
- New transparent spatial shaders must declare `// RENDER_POLICY: <role>; depth_test=on|off` in their source. Run `tools/render_policy_self_check.py`, relevant v225 regression tests and the normal PR CI. An Android/GL frame check is still necessary to confirm visibility.

## Mandatory model integration guide (2026-11-09)
- **Before adding/editing/replacing 3D models, Blockbench parts, skeletons, animation models, equipment loaders, or related generated assets, read the whole `docs/MODEL_PART_WORKFLOW_ja.md` (WORKFLOW_ID: SERA_MODEL_PARTS_V1).** This covers `models/`, `blockbench/`, `assets/sera_*`, and `scripts/sera_rig.gd` / `scripts/sera_equipment.gd`.
- The user's single-part .bbmodel, group names (including Japanese), folder hierarchy, joint Pivot, skeleton type/body part and optional A-relative scale are sufficient **inputs**. The agent must perform copy/rename/normalization, UUID reconciliation, hierarchy/Pivot/scale alignment, runtime registration, data rebuild, tests and GitHub merge. Multiple meshes per group are fine. Do not require the user to rename their folder for the loader.
- v189 has an explicit six-bone bird-leg D lower-body importer and authored clip tracks; v190 adds bind-pose sole-height adjustment and visual contact footfalls. **Other arbitrary skeletons and automatic per-part importing are not implemented**. Inspect current code; warn on ambiguous mappings and preserve the A rig and animations.
- For any model-related PR, include `MODEL_GUIDE_READ: YES` in the PR body **after reading the guide**. `tools/model_policy_check.py` and `.github/workflows/sera-model-policy.yml` check the explicit acknowledgement and guide reference.

## Latest equipment slot correction (2026-11-10, v193)
- FEET is **not** an independent customization slot (the short-lived v192 slot was removed). The new complete standard-skeleton LOWER BODY sourced from `models/storage/足C.bbmodel` is **D**, using all 12 authored source meshes (two pelvis, four thighs, two shins, four feet) normalized to the standard A skeleton. The preexisting bird leg lower body was relocated from **D to C** without changing its source/animation/bones. HEAD C remains independently selectable.
- The current runtime router in `scripts/sera_equipment.gd` intentionally maps Waist3 lower-body meshes to D, Waist3 Head C meshes to C, and bird-tagged mesh instances to C. Do not infer set ID solely from a Blockbench root name.
- `scripts/sera_save.gd` version 2 one-time migrates historical legacy slots and does not remap new version 2 choices. NEXUS exhibition disables sole-height root shifts; training retains them.


## v194 dedicated standard-rig LOWER BODY D registration (2026-11-10)
- Runtime now explicitly loads `models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel`, with generated fallback `assets/sera_lower_body_d_data.gd`, through `scripts/sera_equipment.gd`. The combined Waist3 root remains necessary for HEAD C, but its embedded leg meshes must not also register D. Keep the dedicated D geometry exactly 12 meshes under the standard A leg joints.
- Rebuild the fallback with `python3 tools/rebuild_lower_body_d_data.py` when changing the runtime-ready D source, and run `python3 tools/v194_lower_body_d_customization_self_check.py`. The C bird skeleton, saved slot schema v2, and A animation tracks are unchanged.
- An Android rendering bug was previously reported; a static pass verifies code and asset routing only, not visual acceptance on Xperia 1 V.


## v195 LOWER BODY D visual proportions (2026-11-10)
- The D model must preserve the full 12-mesh source silhouette from models/storage/SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel. Do not independently resize legs, knees, and boots to A's bounding boxes: it caused a visibly incorrect default-like model.
- Rebuild by running python3 tools/rebuild_lower_body_d_from_author.py, then python3 tools/rebuild_lower_body_d_data.py and python3 tools/rebuild_equipment_data.py. Use scale 0.36 and original sole Y=0.2. Run tools/v195_lower_body_d_proportions_self_check.py. Preserve D color indices (1/3 rose, 5 pale blue) in the Godot loader.


## v196 NEXUSpose automatic arm clearance (2026-11-10)
- NEXUS exhibition in `scripts/command_nexus.gd` records the exact sampled NEXUS_pose quaternions for Shoulder_L/R and UpperArm_L/R, then checks collisions against the *selected and visible* LOWER BODY. Only the display rig is modified, never user-authored Blockbench animation or training gameplay.
- When lower body or arms change and when a save is loaded, restore original pose before solving. For each side, raise only if actual 3D mesh bounds intersect the lower body, with small shoulder increments (max 8°) and up to 90° upper-arm lift, stopping at the earliest non-intersecting angle. If clear, restore default angles without residual offsets.
- Re-test with `python3 tools/v196_nexus_pose_arm_clearance_self_check.py`. Static checks and rig-space AABBs are conservative; actual Android display collision and shading remain device checks.

## v197 NEXUSpose over-lift fix (2026-11-10)
- Never change original NEXUSpose quaternions or authored source. Arm/leg contacts use rig-local oriented-box SAT (15 axes), with AABB as broadphase only.
- Limit additional lift to 24° upper arm / 3.2° shoulder, minimizing overlap; if impossible to improve, keep original angles. Re-test on arm/leg equipment selection and saved-profile loads.
- Verify with `tools/v196_nexus_pose_arm_clearance_self_check.py` and `tools/v197_nexus_pose_overlift_self_check.py`.


## v198 unified on-screen version indicator (2026-11-10)
- The launch selector, training room, and NEXUS all create the same `scripts/version_indicator.gd` label. It reads `ProjectSettings.get_setting("application/config/name")`. Do not hardcode a version separately in each scene or in the display helper.
- When updating `project.godot` to `SERA vNNN`, all three labels follow automatically. Keep the small top-right stamp's `MOUSE_FILTER_IGNORE` so combat and menu input remain unchanged.
- `python3 tools/v198_version_indicator_self_check.py` verifies all three entries and the single version source. On-screen appearance remains an Android acceptance check.


## v199 training floor sole grounding (2026-11-10)
- Training model grounding now runs **after every animated pose** via `equipment_handler.snap_grounded_sole_to_floor()` in `scripts/sera_rig.gd`. It uses actual transformed triangle vertices of the currently visible A/B/C/D foot meshes (not AABB corners), and places the lowest sole at the visual grid top Y=-0.0335.
- Only visual `rig.position.y` changes on grounded frames. Player's XZ/velocity, the capsule's bind-pose extension, save slots, foot-contact signal and animation clips are unchanged. Skip while jump playback/airborne; disable completely in NEXUS exhibition mode.
- Preserve exact authored mesh geometry, motion clips and cached triangle arrays; don't move the Player root or introduce a physics floor. Run `python3 tools/v199_animated_sole_grounding_self_check.py`.

## v200 RUN-contact-only grounding and omnidirectional step (2026-11-10)
- In sera_rig.gd, after animation playback first restore the v198 static sole offset via equipment.restore_grounding_baseline(). For WAIT only call snap_grounded_sole_to_floor every frame; for RUN only call it immediately before foot_contact.emit(side) when the audible footstep triggers. All attacks, bash, guard, boost, damage, jumps and all step directions retain the fixed baseline.
- The release-only flick classification returns a normalized 360-degree vector (including forward and diagonals), without direction wedges; keep short/fast/reversal checks, boost suppression, guard-bash precedence and debug-only jump.
- Omnidirectional step combines a target-centered lateral orbit and radial 4m back/2m forward travel. Pose blends Step_L / Step_R / Backstep / provisional Boost_front, 0.12-second entry and 0.16-second exit crossfade. Existing authored files, player collision/movement physics and camera should not be changed.
- Verify tools/v199_animated_sole_grounding_self_check.py and tools/v200_contact_omni_step_self_check.py; Android device acceptance remains separate.

## Mandatory future flick control convention (2026-11-12, v253)
- **Superseded by v257 for gameplay flicks**: use the controller's spawn screen point toward the lock marker's displayed screen position as forward, rather than SERA's projected heading. For historical/debug-only controls, keep the previous mapping unless explicitly revised. Use `scripts/flick_direction_policy.gd` and read `docs/SERA_INPUT_MOVEMENT_CAMERA.md` before adding a flick action.
- Capture `projected_forward(camera, player)` when a touch begins and use the saved direction in `within_sector` and `is_flick` during both drag-time candidate gating and release-time recognition. Never add a fresh `displacement.y < 0` gate for a character-forward flick.
- Both Bash paths (GUARD and Melee3 combo) must use the shared classifier; do not alter existing thresholds/priority except when explicitly requested. v252 STEP motion, screen-aligned analog RUN/BOOST, lock buttons and archived debug Jump are unaffected.
- Run `python3 tools/v253_screen_facing_bash_self_check.py` and standard PR CI whenever modifying character-relative gestures.

## Mandatory eight-way 45-degree directional flick sectors (2026-11-12, v254)
- **All future directional flick input** must use `scripts/flick_direction_policy.gd`'s `sector_index(displacement, screen_axis)`: eight equal 45° sectors, centers spaced 45° apart, half-width 22.5°; `-1` for no direction. Index order from the supplied axis is FORWARD (0), FORWARD_RIGHT (1), RIGHT (2), BACK_RIGHT (3), BACK (4), BACK_LEFT (5), LEFT (6), FORWARD_LEFT (7). Clockwise boundary wins ties.
- **v257 supersedes the earlier axis**: STEP and Bash select sectors relative to the **same controller-start → visible lock-reticle** axis snapshot (`gesture_screen_forward`). In STEP, `eight_way_direction(displacement, gesture_screen_forward)` maps sector 0 to forward travel; Bash accepts only sector 0. NEVER give STEP and Bash separate front reference axes. RUN/BOOST remain continuous analog.
- For GUARD held while the camera/reticle moves, reacquire controller-origin → marker direction when the final flick starts and keep it until release; if Android coalesces drag, sample at release. The controller origin itself never moves.
- Bash selects only sector 0 **relative to the screen-projected character forward snapshot** obtained at touch start. Both Guard Bash and combo Bash must use the shared `within_sector`/`is_flick` helper, not raw screen-UP or an independently computed angle tolerance.
- Any newly authored directional flick command must explicitly declare its chosen screen axis (absolute screen or actor-facing) and call the same sector functions for candidate detection, triggering and motion. Do not add another 360° quantizer or hard-coded angle wedges. Read `docs/SERA_INPUT_MOVEMENT_CAMERA.md`, run `tools/v254_eight_way_flick_self_check.py` and standard CI.

## v256 accessible Bash-only touch thresholds (2026-11-12)
- Bash and STEP continue sharing eight 45-degree sectors based on projected actor facing. Do not broaden the directional sectors or change STEP release thresholds as an incidental side effect of Bash accessibility changes.
- For GUARD and Melee3 Bash, use the dedicated `BASH_FLICK_MAX_SECONDS=0.42`, `BASH_FLICK_MIN_FORWARD_PIXELS=30`, and `BASH_FLICK_MIN_FORWARD_SPEED=200`. Candidate cancellation begins only after 38px of movement, and small reversal tolerance is 1.35. Guard-flick history has its own 0.42s tail; debug-only Jump remains 0.20s.
- Validate using `tools/v256_bash_accessibility_self_check.py` and the previous v253/v254/v255 regressions. Android gameplay remains the acceptance criterion.

## v257 controller origin → lock marker is the canonical forward (2026-11-12)
- User-specified input rule supersedes v253/v254/v255 character-facing snapshots: all eight-way action flicks treat the **vector from original controller touch-down screen position `pointer_origin` to the actually rendered HUD lock marker `touch_ui.target_marker_position`** as FORWARD (sector 0); rotate ±45° for the other sectors. Do not substitute SERA's body orientation or screen UP while the marker is visible.
- Read `touch_ui.target_marker_visible` and `touch_ui.target_marker_position` in the same viewport coordinate space as `InputEvent.position`. On marker absence/overlap, use the documented fallback to projected character forward. Freeze on touch-down; for a long GUARD recapture when the last flick begins or on release if no move event occurred.
- Use `_flick_front_from_controller_origin` and `FLICK_DIRECTION_POLICY.toward_lock_marker` for future flicks. Keep `sector_index`, `eight_way_direction`, `within_sector`, `is_flick` and all existing timings/thresholds unchanged. Verify with `tools/v257_lock_marker_flick_axis_self_check.py` and existing CI.

## CURRENT flick policy — v258 overrides all v253–v257 variants (2026-11-12)
- All gameplay directional flicks take FORWARD from `FLICK_DIRECTION_POLICY.projected_forward(camera, player)`, the screen-projected SERA body facing. This explicitly **reverts the v257 controller-origin -> lock-marker axis**, which must not affect input.
- Divide 360 degrees into exactly **four 90-degree sectors**: FORWARD 0, RIGHT 1, BACK 2, LEFT 3; center tolerance ±45 degrees, clockwise on exact boundaries. Diagonal flicks belong to the nearest cardinal sector; no discrete diagonal actions. Use `sector_index` and `four_way_direction`, never `eight_way_direction`.
- STEP and GUARD/Melee3 Bash must share the same axis snapshot. Bash accepts the whole front sector 0; do not additionally narrow it with the historical 0.42 lateral ratio. Preserve v256 Bash time 0.42s, forward 30px, forward speed 200px/s, initial candidate grace and Guard-tail behavior.
- Capture projected facing at touch start, and refresh at the final flick onset after long Guard (or release when no drag event). RUN/BOOST analog direction, 3m front/4m back/2–4m side STEP distances and all equipment/EN/motion/lock visuals remain unchanged. The previous v254/v257 8-sector requirements are historical, not active.
- Use `tools/v258_four_way_character_facing_self_check.py` and the existing PR CI for future changes.

## v259 AUTO lock hold for combo input windows (2026-11-12)
- Melee3->Bash flick (`bash_followup_window_remaining`) and Bash->Melee1 tap (`bash_loop_window_remaining`) remain accepted for 0.65s each **after combat_state is IDLE**. AUTO selection must be blocked during either timer, as it already is during non-IDLE melee and Bash. Use `_combo_followup_input_window_open()` to gate `select_front_part`.
- RUN/BOOST drag must cancel both timers via `_cancel_combo_followup_windows_for_movement()`; a successful STEP must also cancel them after spending EN. Mid-combat cancellation still uses `_cancel_attack()`. Natural window expiry resumes AUTO. Never change current lock ID or AUTO/MANUAL mode in the cancellation helper; keep broken/invalid-target clearing.
- Do not change input timing or damage as a side effect. Run `tools/v259_combo_lock_hold_self_check.py` and existing CI.

## v260 STEP screen-cardinal direction fixes unintended side/back classification (2026-11-12)
- LATEST user-observed issue: downward flick was classified as SIDE STEP and lateral flick as BACK STEP. In v258/v259 this occurred because `_classify_step_flick` quantized relative to camera-projected SERA forward, which varies during camera orbit, despite STEP user intent being screen-directional.
- All **STEP** gestures must be classified with `FLICK_DIRECTION_POLICY.screen_step_direction(displacement)` using `Vector2.UP` as the screen axis: UP=front(0), RIGHT=right(1), DOWN=back(2), LEFT=left(3), sector width 90°. Never use `gesture_screen_forward` for STEP classification. Keep existing STEP 3D travel: actor-forward/back and camera-right lateral, and all timing, EN, pose and collision rules.
- All **Bash** gestures (Guard and 3-hit combo) **continue using SERA's screen-projected facing** from `gesture_screen_forward` as sector zero. This is an intentional axis distinction to match user-observed STEP behavior without changing Bash. The same four-way quantizer underlies both actions; only the supplied front axis differs. The former v258 "same axis for STEP and Bash" instruction is superseded. Keep v259 combo-lock input retention logic.
- Verify `tools/v260_screen_step_direction_self_check.py` and old checks before merging. An actual Android device acceptance run is separate.

## v261 rear-diagonal BOOST nozzle fix (2026-11-12)
- The left-screen exhaust sector historically overrides normal yaw/pitch steering. Its target **must** be interpolated by the target-relative `backstroke_weight` toward `Vector3.DOWN`, even when the thumb also points left, otherwise back-left BOOST/STEP ignores reverse thrust and looks wrong. Preserve pure-left 45° camera down/right aim when weight=0, vertical world-down when weight=1, and smoothly interpolate all intermediate reverse diagonals; see `scripts/main.gd` alongside `scripts/back_thruster_fx.gd`.
- Do not disable the world-down gravity bias, physical authored nozzle pivot animation, servo smoothing, back-thruster world ribbons, 3-strike melee nozzle body-clearance, v260 STEP screen classification or v259 combo lock windows.
- Run the v213/v210/v241 existing checks and `tools/v261_rear_diagonal_thruster_self_check.py` in CI. Android playback remains separately unverified.

## CURRENT v262: continuous 360-degree STEP and 4-way authored pose blend
- Supersede v260/v261 four-sector STEP: `FLICK_DIRECTION_POLICY.screen_step_direction` returns normalized RAW swipe direction (no quadrant snapping). Use same vector for `_start_omni_step` physics and `sera_rig.gd::start_omni_step` authored 4-clip pose blend. Smooth the angle pose alpha at cardinal boundaries.
- Preserve 3m forward, 4m backward, lateral 2–4m, swept collision, EN/timing, camera/screen X and actor-facing Y. Smooth the radial coefficient around screen-side y=0 with `smoothstep(-0.25,0.25,direction.y)`, preserving original diagonal outside this narrow range.
- Bash alone retains four SERA-forward sectors. Keep v259 combo target locking, v261 back-left nozzle fix, RUN/BOOST, original four Blockbench clips. Test `tools/v262_continuous_step_blend_self_check.py`; Android runtime not yet verified.

## v263 close-combat STEP screen-motion contract (2026-11-12)
- Near a locked boss, using camera-right for STEP x and SERA body-forward for STEP y makes a **non-orthogonal basis** (and even produces opposite/canceling diagonals when actor-forward points camera-right). Fix: take **the same fully screen-relative projection `_screen_drag_to_ground(direction)`** used by RUN/BOOST for the *entire* STEP world path. Keep original 360° raw gesture, 3m/4m/2–4m length coefficients, speed/EN, swept collision, and do not insert actor-facing components into the path. The current `scripts/main.gd::_step_local_pose_direction(world_step)` is ONLY for the authored clip weights.
- SERA turns toward the locked target while traversing STEP; update rig direction without restarting the animation via `update_omni_step_direction` with a short 0.08s slerp. Per-frame step backstroke weight should be based on committed world travel relative to SERA rear rather than screen Y, while LEFT sector still obeys screen X. Keep v261 nozzle safety.
- Keep `camera_yaw` stable during actual STEP frames (zoom and frame-fitting still run); resume existing close STEP camera recovery / moving yaw follow afterward so screen travel doesn't visibly rotate mid-step. Leave ordinary RUN/BOOST camera tracking unchanged.
- Add regression `tools/v263_close_step_screen_alignment_self_check.py`; run all old v200/v252/v262, v210/v261, camera/renderer/model tests before merging.

## Animation runtime regression requirements (added 2026-11-12)
- For **any** new/changed Blockbench animation or `scripts/sera_rig.gd` playback lookup, consult `docs/SERA_ANIMATION_RUNTIME_POLICY_ja.md` and ensure the **real-Godot** workflow step `tools/sera_animation_runtime_smoke.gd` passes. Static Python/json checks are insufficient.
- Resolve published animation names directly before alias/heuristic searches. For public playback APIs, verify **lookup, recovery ordering, start, current_clip**, not just whether a clip name exists. Avoid conditional array literals assigned to typed `Array[String]`; prefer explicit branches or canonical strings.
- Do not merge model/animation PRs without Godot runtime CI. An Android test is still distinct; never misstate cloud headless as Android validation. Preserve original Blockbench keys, mesh pivots, and unrelated animations unless requested.


## v284 — 最新の格闘フリック・サマーソルト・スラスター仕様（旧v253〜v283の相反する規則より優先）
- **Melee3とGUARD Bashのフリックは画面絶対方向**（`Vector2.UP`）を基準に90°ずつ4分類。**画面上＝Bash、右＝Kick_r、下＝Kick_b、左＝Kick_l**。セラの正面方向、ロック位置、カメラYawから方向を再分類しない。通常STEPは従来の360°連続スクリーン移動を維持。
- Bashフリックの候補維持判定（`_change_drag`）と離指確定（`_is_character_forward_flick`、名前は互換性のため据え置き）はどちらも`Vector2.UP`。左右・下は必ず蹴り派生を優先し、通常STEPとして落とさない。
- **Melee3の15/24秒（0.625秒）の振り切りから0.05秒後＝0.675秒**が予約済みフリック派生専用キャンセル。通常Melee1を再発動できる時間、Melee1/Melee2のタップキャンセルは変更しない。予約がなければ0.83333秒のMelee3終端まで再生する。
- **Kick_bは誘導加速→接地したKick_bモーション開始→蹴り命中キーで接触判定→命中時のみ追尾OFF＋後方ベジェ跳躍**。全体モーション時間0.8秒。ヒットまで約0.211秒、その後の弧状飛行約0.589秒。弧は4m後退・1.5m頂点。空振りなら跳躍せずモーションを完走する。着地0.20秒は命中時のみ。
- **全ての格闘（3連・Bash・Kick_l/r/b）で背面スラスターは接敵・追尾・接触・振り抜きまで継続**。追尾加速時の一瞬の拡散、継続噴射、通常攻撃同様の微小変位時の安定した背面方向を適用する。後ろ跳躍時のみ移動方向の逆噴射を継続。
- バージョンが古いテストと本文にある「Bashはセラ向き基準」「蹴りは最後まで動いた後でジャンプ」「バッシュは追尾中だけ噴射」という記述は歴史的な記録であり、現在の実装仕様ではない。


## v285 — 最新の左右蹴り円弧移動とカメラ角度制限（v284までの直線蹴り仕様に優先）
- `Kick_l`／`Kick_r` のみ、画面左右へ直線移動するSTEP流用から**敵ターゲット中心を軸とする水平円弧**へ変更。通常の360° STEP、Backstepは従来どおり画面方向の直線移動。
- 1発目（0.25の命中キー）と2発目の振りかぶりキー（Kick_r=0.33333、Kick_l=0.41667）までは側方移動しない。1発目のBash式追尾は2発目の振りかぶりまでで打ち切り、**その時点で現在の敵・プレイヤー位置から半径・旋回符号・角度を確定**する。追尾による後方への位置巻き戻り禁止。
- 画面上の左右フリックで敵を中心とする円弧の回転方向を選ぶ（`_screen_drag_to_ground(Vector2.RIGHT)` で旋回接線の向きと照合）。敵位置が移動すれば回転中心も追従。常に `_move_player_swept` で衝突を解決し、壁抜けしない。
- ステップから引き継いだ2〜4mの弧長と速度、2倍の蹴りモーション時間、2回の命中キー、EN・スラスター・ターゲットロックを維持。中心と極端に重なる場合は既存の接線直線フォールバック。
- 敵中心の**カメラ方向とプレイヤー方向の許容角差を65°→45°に変更**。従来はSTEP最中のYawを固定していたため、左右蹴りの円弧旋回中に制限が働かなかった。v285では左右蹴りの最中も `_close_step_target_relative_yaw` を計算し、毎フレーム制限する。Yaw速度上限300°/秒は維持し、超過した初期角度がある場合は段階的に復帰。


## v286 — 添付v285スクリーンショットの近接シルエット／LOCK UI重なり対策（v285のカメラ処理より優先）
- プレイヤーが敵の幅広い脚部に重なる近距離で、低いカメラとターゲット中心へ向けたYawのためSERAが見えにくくなっていた。近距離6m以下は**カメラ・敵・セラの水平角制限±45°を守りつつ、9候補から最大の画面シルエット分離を得られるYawを探索**する。左右蹴り旋回中・その直後だけでなく、**WAIT状態でも近距離なら同じ視認性最優先のYaw探索**を使い、直後に敵と重なる構図へ戻さない。最大旋回速度300°/秒、既存の遠距離／通常STEPの角度・映り方は維持。
- 視点高度（`camera_elevation_ratio_current`）は敵まで6mから徐々に上げ、3.7m以下では`CAMERA_COMBAT_ELEVATION_RATIO=0.82`（約39°俯瞰）とする。通常遠距離の`CAMERA_ELEVATION_RATIO=0.21`は維持。変化は指数補間で滑らかに行い、瞬間的な視点ジャンプを防ぐ。`_place_camera`はこの現在値を用い、画角フィット／端保護は継続。
- Kick_l/rは2段目振りかぶり時点で敵中心旋回角を計算する際、ボス外脚＋セラの肩を考慮した`SIDE_KICK_SAFE_ORBIT_RADIUS=3.55m`を最小半径に用いる。元々それより近い場合には2段目の旋回とともに`smoothstep(0,0.65,t)`で半径を徐々に広げる。**瞬間移動させず`_move_player_swept`で衝突処理**。通常STEP、1・2段目のモーションキー、格闘入力時刻、ENは不変。
- **LOCKボタン列は画面中央50%の高さから、下側76%の高さへ移す**。HUD下の戦闘モデルに重ならないようにするため。水平の左／AUTO／右の位置は不変（`CONTROLLER_REGION_START_RATIO=0.50`を横位置に維持、縦のみ`LOCK_CONTROLS_VERTICAL_RATIO=0.76`）。ボタンの機能・サイズ・タッチ除外判定、全画面アナログ入力範囲は一切変更しない。
- 両者の3D形状が接触／遮蔽されている場合、画面上の完全非重複を保証できるものではない。GitHub実装済み、Godot実機映像は未検証。


## v287 — 最新の視点仕様（v286の俯瞰・9候補Yaw探索を撤回）
- ユーザー提供のv286実機動画(2026-11-12)から、攻撃と蹴りのたびにカメラが上下・左右へ振られ、セラが画面端で横向きになる問題が確認された。**v286の距離連動俯瞰は全面撤回**し、常にv56の固定 `CAMERA_ELEVATION_RATIO=0.21`（約11.9°）とする。`_place_camera`にも固定値を使う。画面に対して低い水平視点を維持。
- 近距離で毎フレーム「見やすいYaw」を9候補検索していた`_visible_combat_camera_yaw`は廃止。セラに真横から向く視点を避け、ターゲットからセラへの方向から**肩越し12°の後方視点**を基準とする。初期カメラも12°肩越し。
- 非攻撃時のYaw追従は指数平滑と**最大32°/秒**の速度制限。3連格闘、バッシュ、左右蹴り、サマーソルト、着地、ヒットストップを含む**攻撃中はYawを固定**し、最後の格闘後も0.45秒そのまま保持。近距離では攻撃中に`_enforce_screen_edge`の補正と自動Yaw探索を入れない。
- 攻撃中は速度に反応する急激な**ズームインを禁止**し、`camera_follow_radius`は縮めない。画面端からはみ出しそうな場合のズームアウト／安全フィットは許可。攻撃終了後のカメラフィット緩和は0.45秒保持が終わってから行う。近距離のゆっくりした通常追従のみ復帰。
- Kick_l/rの敵中心円弧は維持しつつ、**カメラから見てセラが横を向きすぎる左右±30°を最終旋回角の上限**とする。円弧長が長すぎる場合は終点角度で移動距離を制限し、元のモーション時間・2回の命中判定・スラスター・EN・通常STEPの自由度は変更しない。
- v286の脚回避用最小半径3.55mと、下部のLOCKボタン位置76%は維持。デフォルト立ち姿勢／アニメーションを操作しない。Godot実機の動画確認は未実施。


## v288 — 最新のセラ近接追尾カメラ（v287の「攻撃中Yaw完全固定」より優先）
- カメラの**水平位置の注視点（focus）**は、敵原点ではなく**セラのレンダリング補間位置＋敵方向最大2.0mの先行量**に変更。長距離移動ではセラの移動とほぼ1対1の並進カメラ。敵は既存のフルフレーム保護・画角フィットで表示する。
- `_advance_camera_follow_focus(delta)` は毎レンダーフレーム**1回だけ**補間し、`_place_camera`やズーム安全探索では値を変えない。通常追従速度15/秒（時間定数約0.067秒）、最大距離誤差0.65m。誤差が上限を超える場合、目標から0.65m以内へ補正し、その先はセラと同速度で並走する**ハードリード（leash）**。加速度ばねや時間依存アニメーション追加はしない。
- カメラYawもセラ→ターゲット方向＋12°肩越しを目標に**速度10/秒の小遅延**で追従。誤差が12°を超える場合は超過分を当フレームで補正して**最大誤差12°**を保つ。回避／攻撃追尾／ブースト中もカメラが遅れ続けない。
- v287の**「通常攻撃3段・バッシュ・Kick_l/r/bの最中はYaw完全固定」だけ撤回**し、今は格闘中も位置とYawの追従が有効。攻撃中の急なズームイン抑止（0.45秒ホールド）、原本モーション、通常の画面方向STEPの**短時間のYaw固定**、各攻撃のヒットキー等は変更しない。
- `_place_camera`と`_minimum_boost_camera_radius`で**同じSERA中心focus**を使う。高さは`TARGET_BASE_HEIGHT - CAMERA_FOCUS_DROP`の一定値で、敵の0.07mアイドル上下動でカメラが細かく上下しない。上下角は元の`CAMERA_ELEVATION_RATIO=0.21`で固定し、**俯瞰にしない**。
- トレーニングKO／リスポーンなどの位置テレポート時にはプレイヤーとターゲットの補間姿勢からfocusとYawを再初期化し、旧地点からの視点移動が残らない。
- v288の位置・Yawの距離上限を静的テスト・Godotシーン実行テストに追加。GitHubへ実装、Android実機動画での最終確認は未実施。


## v289 — 最新の部位破壊・ロック継続・被弾FX・Kick_b→RUN復帰（v237/v249/v259旧仕様より優先）
- **ロックは3段コンボ／バッシュ／Kick_l/r／Kick_b／Kick_b着地／派生入力受付中に継続**する。部位耐久が0になっても`locked_target_part_id`はその時点でクリアしない。`_combo_lock_retention_active()`で戦闘再生・横蹴り・バク宙・着地・0.65秒派生窓を一元判定。手動切替も継続中はブロック。新規ロック候補は破壊済みを除外しつつ、既存ロックについてはコンボ中だけ破壊済みの攻撃AABBを残す（`_locked_part_hit_volume_available`）。破壊後の追加ヒットはボス共通HPへ通常どおり反映し、部位ゲージは0のまま。コンボ終了後に健全部位へ切り替える。共通HP0によるトレーニングリスポーンも継続中は短く延期する。
- **部位のAUTO正面選択**は、セラの現在位置から敵**全体の中心（カメラ回転軸）**を結んだ水平軸を基準とし、各部位がその前方にあるか・水平角差・高さ・本体/他部位による遮蔽を評価。現在ロック中の部位へ顔が向いたことを次の選択基準にしないため、ロックの自己フィードバックや左右往復を防ぐ。従来の角度ヒステリシスは維持。手動の無傷ロックも維持する。
- **頭・4脚の破壊後表示を維持**。以前消していた前脚2本も`break_mode="remain"`とし、破壊後は損傷色へ変更してメッシュ・衝突判定を残す。頭の追加露出フレームは従来どおり表示。復活時の見た目・衝突・部位HPは元に戻す。
- **全5部位それぞれの命中FXを共通本体FXへ統一**。本体の`HIT_FLASH_SECONDS=0.145`と同じタイマーで、被弾部位のシェル・関節・フレーム・ダーク材に暗赤色/発光および視覚的な小さな左右揺れを与える（`target_parts.trigger_part_hit_fx/advance_part_hit_fx`）。破壊フレーム中も演出し、終了時は元色または損傷色へ戻す。中心本体の既存FX、火花、音は維持。
- **バク宙後RUN不具合**：後方蹴りの追尾`rig.start_melee_approach`が`combat_playback=true`を立てたまま`rig.start_back_somersault`へ遷移し、着地後に`set_moving()`がreturnしていた。空中移行と`finish_jump`で`combat_playback`、`combat_paused`、`freeze_attack_pose`、`attack_windup_active`を解除。0.2秒着地後、既に指が残っていれば`_analog_stick_direction(pointer_location)`を再取得してRUNを復帰。モーションやコンボ受付は変更しない。
- プロジェクト表記`SERA v289`。新規静的・Godot実行用回帰テストをCIに登録。GitHub反映済み、実機映像での最終確認は未実施。


## v290 — 最新仕様：カタナ2段＋鞘/抜き身切替、左右RUN中の全体中心ロック
- カタナ右武器Kは元のBlockbench階層の**鞘側5メッシュ／抜き身側2メッシュ**を区別する（`Katana_l`～`Katana_r_saya`対`Katana_r_nukimi`）。装備選択直後・WAITは鞘のみ、`Melee_katana`の4フレーム目（3/24秒）で鞘非表示＋透明度1、抜き身表示＋透明度0。**2段目中は抜き身を表示したまま**。装備変更・戦闘終了では初期鞘表示へ戻し、残像も同期。従来の`visible`に加えて`GeometryInstance3D.transparency`も設定する。モデル元素自体を複製・削除・着色しない。
- 原本には`Melee_katana2`のユーザー作成キーフレームが現時点で存在しない。元の`Melee_katana`（0.5秒）をGodot実行時に`duplicate(true)`でコピーし、**Waist/Torso/Chest/右腕/右手/抜き身刀支点の水平角の捻りを逆にした**別アニメーション`Melee_katana2`を生成。原本JSON／Blockbenchには手を入れない。もし将来原本`Melee_katana2`が追加された場合はそのキーを優先して派生生成をスキップする。
- **カタナ選択中だけ攻撃は2段（stage 0→1）**。2段目は真の別クリップで、同名`_switch_clip`早期returnが発生しない。2段目の振り抜き7/24秒の0.05秒後（0.34167秒）からフリック派生解放、UP=Bash/RIGHT=Kick_r/LEFT=Kick_l/DOWN=Kick_b。予約フリックがなければ原本0.5秒を完走、派生入力窓0.65秒を維持。1段目からの追撃タップ受付は7/24秒で据え置き。通常武器Aは従来の3段格闘とMelee3の0.675秒派生受付を維持。ダメージ／EN／追尾や方向入力の仕様は変更しない。
- 横移動時、`main.gd`の`player.look_at`を**ターゲット部位ではなく敵全体の中心点（カメラ軸）へ**向ける。部位IDはレティクル・ダメージ・追尾判定だけに利用。さらに`sera_rig.gd::_run_yaw_for_direction`はRUN/後退/左右RUNで移動方向にWaistが最大90°回っていたので、**全体中心からの視覚的なズレを±25°以内に制限**。脚の横移動・スライド/BOOST・入力360°・低いカメラ・v288の追従は維持。
- `project.godot`: SERA v290。静的/シーン回帰テスト`v290_katana_combo_body_lock_*`をCIに追加。Androidでの実映像検証は未実施。


## v291 — 最新のユーザビリティ優先LOCKと対称両手武器ルール（v289の遮蔽除外を破棄）
- v289の部位ロック不能は**距離しきい値ではなく**、全体中心への前方dotと本体AABB・巨大脚AABBの線分遮蔽で候補をスキップし、空文字ロックになっていたことが主因。**現在のAUTOはカメラ画面中央と部位の投影位置との正規化2D距離で選ぶ** `target_parts.select_camera_front_part(camera, current)` を使用し、距離は最大0.03の微弱な同点補正のみ。遮蔽やスクリーン外を完全棄却しない（カメラ背後と破壊済みのみ新規除外）。既存部位のスコア差0.065以内は保持し、横移動による小刻みな切替を抑える。連撃/派生受付中は破壊済みを含め既存ロックを固定するv289の仕様を保持。
- MANUAL左右切替も本体/脚遮蔽で候補全滅しない。スクリーンXの隣候補を選び、右端/左端なら**反対端へ巡回**する。MANUALへ切り替えた際にロックが空なら同じカメラ正面優先で1部位を初期取得する。
- ロックが画面外へ出てもIDはそのまま、HUD上では42px内側へ**橙色の画面端ロックリング**を描く（`touch_overlay.set_target_marker_projection(xy,true,offscreen)`）。攻撃判定位置・距離・当たり判定はクランプしない。ユーザーがロック状態を常時認識できることを優先。
- **両手武器の汎用ルール**：`sera_equipment.gd::TWO_HANDED_WEAPON_LABELS` に武器セットID→名称を登録する（現行`K→KATANA`）。`two_handed_blocker(slot)`は`weapon_r`と`weapon_l`の**反対側**を検査し、右手Kなら左手、将来左手の両手武器なら右手を対称に無効化。使えない側の既存武器メッシュを**非表示**にし、装備カスタマイズの該当行を**グレー**／値欄を占有側武器名`KATANA`へ変更、タップ切替不可。背後に保持しているオフハンド選択/保存値は消さず、両手武器を外すと復元。セーブロード時(`persist=false`)に限り占有側の非表示記録を復元可能。
- **鞘の向き修正**：原本の`Katana_l3`直下メッシュにはローカルY+90°がある。従来の`sera_rig._add_entry`は`Bird_`以外のelement.rotationを捨てていたため、左前腕の鞘が90°ずれて描画されていた。今は`Katana_`階層内のメッシュだけ原本のelement.rotationを`_blockbench_rotation`で復元する。階層ピボットや他のモデルは変更しない。カタナKの5鞘/2抜き身の可視性・透明度・2段格闘は維持。
- 表記SERA v291。静的・Godot実行用の回帰テストをCI登録。実機描画/タッチは未検証。


## v292 — ロックUIは作動しているがモデルの向きが外れる問題の根本対策（v291動画）
- 2026-11-12のユーザー動画（約12.5秒）では`LOCK HEAD`や`LOCK REAR R`が実際に切り替わり、マーカーも追跡する。したがって主因は**部位ID取得ではなく、親`player.look_at`で向けた全体ボス中心と、子`SeraRig`の移動アニメーション中Waist回転の不一致**。原本`Step_R`の腰Yaw=-70°、`run_front_original`の腰Yaw=+74.6407°。後者は既存の-90°修正後もズレが残る。ロック対象が変わっても、移動中は機体の前方がボス中心を向く必要がある。
- `sera_rig._face_locked_boss_with_waist(q,blend_weight)`は`q * Vector3.FORWARD`から描画腰の水平方向を求め、親のロック方向へYawを補正。**RUN・BOOST/SLIDE・通常360°STEPのみ**に適用。原本アニメーションのX前傾/ロール/脚・ノズル・攻撃/防御のポーズは変えない。既存の0.08～0.16秒フェード後に補正し、フェード開始時にスナップしない。メインの`player.look_at`、カメラv288、遠近での動き補正は維持。
- `main._acquire_stable_camera_part(delta,current_broken)`：カメラ中心優先のAUTO部位候補を維持しつつ、**既存の健全部位から別候補への切替だけ0.22秒継続確認**。新規/破壊済みIDの取得は即時。コンボの破壊部位ID維持、MANUALは従来どおり。毎physicsで一時的な候補入替があっても`LOCK HEAD`/脚が過剰に点滅しない。v291で撤去した遮蔽/距離のハード足切りは戻さない。
- 刀2段目の原本について`main`の保存モデル(2026-11-12版を含む)を再検索したが、`Melee_katana2`は存在せず、`Melee_katana`(0.5秒)のみ。新原本がなければ**v290の生成した2段目をそのまま維持**。後に原本が入れば`_build_katana_second_strike`はクリップ存在チェックにより既存の原本を優先する。
- 表示SERA v292。静的/シーン回帰テストをCIへ追加。GitHubコード確認済み、Android実機映像/実行は未確認。
