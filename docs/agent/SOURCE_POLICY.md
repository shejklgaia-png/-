# SERA エージェント — ソース・モデル・Android運用規則（原本から分離）

## Current sources and constraints
- Repository: `shejklgaia-png/-`. Root `project.godot` must be named exactly `SERA v<integer>`. Keep the Android portrait GL Compatibility renderer; no unsolicited engine upgrade or migration.
- **Models:** consult `models/manifest.json` and `docs/SERA_MODEL_SOURCES_ja.md`. Canonical editable sources are `models/core/Standard.bbmodel`, `BirdLeg.bbmodel`, `Katana.bbmodel`, `Equipment.bbmodel`, plus `models/storage/Head_C.bbmodel` and `LowerBody_D.bbmodel`. Older model copies are historical fixtures. `assets/sera_source.json` and embedded `assets/sera_*.gd` are **generated**, rebuild via `tools/rebuild_*_data.py`, not manual edits.
- **Model build:** use `python3 tools/sera_model_build.py --check` to detect stale Android snapshots. For intentional source changes run `--write` after editing the canonical `.bbmodel` and review regenerated diff. This does not replace real Godot checks.
- **Model/animation changes:** read `docs/MODEL_PART_WORKFLOW_ja.md` (**SERA_MODEL_PARTS_V1**) and `docs/SERA_ANIMATION_RUNTIME_POLICY_ja.md`; preserve joint UUIDs, pivots, authored keys and bone mapping. Model PR body requires `MODEL_GUIDE_READ: YES` after actually reading the guide. Always run real Godot clip/playback checks; headless CI is not Android visual verification.
- **3D materials/FX:** read `docs/RENDER_PIPELINE_POLICY_ja.md` and `scripts/render_order_policy.gd`. Preserve depth, draw order, nozzle pivot and transparency policies; run the render regression.
- **Gameplay contracts:** read `docs/SERA_ACTIVE_CI_POLICY_ja.md`. `tools/sera_active_specs.json` contains **approved** current STEP/kick values; change it only with an intentional gameplay specification change, never to silence a genuine regression. Superseded vNNN assertions must be distinguished from permanent invariants.
- **Input/HUD:** run `tools/sera_parameter_audit.py` when applicable; see `docs/SERA_DEVELOPMENT_FASTPATH_ja.md` and `docs/SERA_MEMORY_INDEX.md`.
- **Repo layout:** follow `docs/SERA_REPOSITORY_LAYOUT_ja.md`; old README notes belong in `docs/history/release_notes/`. Keep model masters, import UIDs and CI fixtures.
- **GitSync/phone:** only merged `main` reaches Android. Preserve unpushed edits; never sync while editors write or repeatedly ask to sync/start.
- No secrets, signing keys, credentials, arbitrary dependencies, or unwarranted deletion of user models. If source is ambiguous, inspect hierarchy/Pivot before assigning a bone.

## Staged model intake
For new `strage`/`storage` uploads, follow `docs/SERA_INCOMING_MODEL_INTAKE_ja.md`: merge canonical clips and Swordeffect, rebuild, review and merge, run full post-merge CI, then delete only unreferenced staging files.

## v317 optional Android diagnostics
- During Android training only, DIAG: OFF toggles diagnostic recording ON. COPY LOG copies bounded local runtime samples to the device clipboard; paste into chat for analysis. No telemetry or network access when OFF. Details in `docs/SERA_ANDROID_DIAGNOSTICS_ja.md`.
- Existing touch controller areas and ordinary game logic must not be changed for diagnostic instrumentation.

