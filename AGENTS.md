# SERA — Codex / coding-agent repository instructions

## Goal and baseline
- This is the Godot 4.x, **Android-first portrait 3D action prototype** "SERA". The most recently integrated gameplay version is **v103 (2026-11-06)** (red training target); **Android device verification for v103 remains outstanding**. The historical repository-preparation package itself was documentation-only.
- `project.godot` must remain **at the repository root**. Current project declares Godot **4.3+** features, **GL Compatibility** rendering and 720 × 1280 portrait viewport. Do not automatically migrate renderers, upgrade the engine, or change display settings.
- Primary verification is via **Godot Editor on Xperia 1 V (Android)**. A cloud/desktop headless test does not verify touch control feel, rendering or audio on the phone.

## Nonnegotiable edit policy
1. Keep all existing features, input mappings, assets, animation clips, scene paths, and gameplay logic unless the user explicitly asks for a change. Make the **smallest targeted diff**.
2. Before edits, inspect `DEVELOPMENT.md`, `README_v102_ja.md` and related current scripts; check the Git diff and note the commit/branch as baseline. Never silently discard uncommitted changes.
3. Create a separate branch / pull request for each feature. After reviewing the scoped diff and available checks, **merge the PR into `main` as part of the same task by default without requesting a separate user instruction**. Explicitly report any Android/device checks not performed. If checks fail, the PR conflicts, or a change appears unsafe, stop rather than forcing a merge; explain the blocker.
4. Test what you can and report **exactly** which checks ran; do not state Android/Godot runtime validation unless actually executed.
5. For each requested code change, append a concise dated section to `DEVELOPMENT.md`, add/update the relevant versioned README/test, and report changed files, preserved functions, test results, and known untested items. Bump the game version only on actual user-authorized game changes.
6. Never add credentials, tokens, signing keystores or other private data to the repository. Avoid unnecessary dependencies/network access.

## Current layout and important behavior
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
python3 tools/codex_project_check.py
python3 tools/self_check.py
python3 tools/v102_guardfix_self_check.py
```

Additional historical checks may refer to unavailable prior ZIPs; read their preconditions before running them. Use `python3 -m compileall -q tools` for Python syntax if relevant. If a compatible Godot editor binary is available, run `godot --headless --path . --import` and capture its exit code/log; optionally run a short headless scene smoke test. This is **not equivalent to Android runtime verification**. If no Godot binary exists, say "Godot runtime not tested". When updating a feature intentionally, adjust its regression tests without deleting useful coverage.

## GitSync / Android continuation
- The local GitSync repository's directory **must be the same directory** that Godot Android opens, containing `project.godot` at its root.
- A branch/PR alone is not visible through phone sync. By default, finish each verified change by merging its PR into `main` during the same task, then sync GitSync and reopen/reload the Godot project on phone. Do not require a separate “merge” request.
- Never auto-pull while Godot or Blockbench is actively writing the same files; protect local edits from being overwritten. Check `.gitignore` to avoid syncing cache.

## Do not overstate
- Successful Python static tests do not prove that Godot parses or renders the complete game, and a successful headless import does not prove Android touch behavior.
- This repository package made no functional changes to v102.

## Shared SERA design-memory documents (2026-11-06)
- Before planning gameplay changes, read `docs/SERA_MEMORY_INDEX.md` and the linked topic documents. They preserve user decisions from ChatGPT conversations for Codex.
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
