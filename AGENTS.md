# SERA — coding agents (current operating rules)

> **Authority:** current user instructions, `main`, `project.godot`, code, and `models/manifest.json`; old rules: `docs/history/AGENTS_THROUGH_V316.md`.

## Fast, safe work sequence
1. Confirm latest `main` SHA, `project.godot` version, open PRs, and requested feature; never infer live state from old notes.
2. Use `tools/sera_workplan.py --query <feature> --json` (or `--changed <path>`) to find sources and tests. Inspect real code; suggestions are heuristic.
3. Make minimal, reviewed diffs on a short-lived branch. Preserve models and unrelated mechanics.
4. Run focused checks while editing. **Merge first; run the full `tools/sera_ci_manifest.txt` Python/Godot CI suite on `main` afterward.** Focused checks never replace full CI.
5. Before merge check conflicts, unsafe edits, model sources and diff; never merge known destructive changes. After merge, if CI fails, **report the failure and fix without user approval**. Identify the cause, preserve approved gameplay and test coverage, merge a minimal fix, then rerun full post-merge CI. Repeat if needed; never hide a regression by weakening tests. If blocked, report why. Give fix/CI URLs and accurate status. ChatGPT checks code, logs and numeric regressions; humans check Android motion, input, visuals, audio and feel.
6. Log meaningful changes in `DEVELOPMENT.md`. Update versioned README and increment version only for user-requested gameplay changes.

## 更新前のCI仕様確認・先行修正（全アップデートで必須）
**新機能・バグ修正・調整・UI変更・モーション変更など、毎回の更新で必ず実施する。**
1. **変更開始前**に、現在の `.github/workflows/`、登録済みCIテスト、関連するテストケースと期待値を確認する。SERAでは `tools/sera_ci_manifest.txt` と `docs/SERA_ACTIVE_CI_POLICY_ja.md`、必要に応じて `tools/sera_active_specs.json` も確認する。古い履歴テストが現行仕様と整合するか判定する。
2. 依頼された新仕様とテストの関係を「変更する期待値」「新規追加する検証」「保持すべき不変条件」「影響しないテスト」に分類する。影響するテスト名と具体的な変更理由を把握する。
3. **明確に仕様が変わる箇所は、アプリ／ゲーム本体の実装前に、関連CIテストの期待値・条件・フィクスチャを新仕様に合わせて先に編集する。** テストを追加すべき場合も先に追加する。同じ変更セット／PRに本体実装とテスト更新を含める。仕様変更のない既存検査は維持する。
4. 期待値はユーザーが承認した仕様などの**独立した根拠**から定義する。実装の現在値を読み取って無条件に正解扱いしない。テストの削除・一律スキップ・閾値の無根拠な緩和・失敗の握りつぶしは禁止。真の回帰はテストではなく実装を修正する。
5. テスト更新後に本体を実装し、関連する局所テストを実行する。その後、**このリポジトリで定められた全CI実行順序**に従い、全件検証する。SERAは既存規則どおり **マージ後のmainでフルCI** を必ず実施する。
6. CI失敗時は「更新漏れの旧仕様テスト／新実装の不具合／環境問題」を切り分ける。必要な修正と再実行を承認待ちなしで進め、修正不能なら原因を報告する。実機の操作感・動き・表示・音は自動CI合格とは分けて確認する。
7. 完了報告に **事前確認したCI項目、先行更新したテスト（理由と変更点）、新規テスト、CI結果、残る実機確認事項** を明記する。

## 装備・倉庫確定仕様（2026-11-20）
- **詳細正本:** `docs/SERA_WAREHOUSE_UI_AND_CRAFT_AFFIXES_ja.md`。実装前に競合する旧CIの期待値を更新し、テストを削除・無条件スキップしない。
- 倉庫は装備カテゴリ別ハンガー各999個。1個体1枚、装備2列縦スクロール、素材は同系統3ランク横3枚。暗い欠け角枠・正方形アイコン・白いデジタル書体・空枠を維持し、「所持×N」の装備集約表示は廃止。
- 製作成功時に個体UIDへ追加性能5個を抽選・永続保存。NEXUSの追加効果モジュールと別管理し、ロード再抽選・旧装備破壊は禁止。
- 999個に比例したUIノード生成は禁止。標準Buttonの可視セルプールを再利用し、Androidの実機表示とスクロールはCIとは別に検査する。

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

## 装備追加の順序：原本同梱アイコンHTMLを最初に渡す（2026-11-21）
- **装備実装の前に** 正本 `.bbmodel` （テクスチャ含む）を `tools/icon_studio/build_sera_icon_studio.py` で単一HTMLへ埋め込み、**このチャットで完成した装備専用HTMLをユーザーに渡す**。ユーザーにBlockbenchファイルの再ダウンロード・手動読み込み・アップロードを求めない。
- HTML受け渡し後、原本モデルをゲームへ実装し、LAB装備作成／製作設計図／レシピ／倉庫／NEXUS／保存まで従来の完了条件を遂行する。ユーザーが撮影構図を未確定なら暫定画像と確定済みを区別し、確定アイコンを勝手に生成・確定しない。
- Icon Studioの「透過PNGを保存」は `SERA_ICON_MANIFEST_V1`（原本のGitHubパスとSHA-256、設計図ID、slot、rig_set、撮影角度・ズーム・移動）をPNG内に埋め込む。他のチャットでユーザーがそのPNGだけをアップロードした場合は `tools/icon_studio/read_sera_icon_png.py` で原本・装備の対応を確認し、ゲームの該当装備アイコンへ反映する。モデル原本はGitHub正本を参照し、再アップロードを要求しない。
- 画像の再エンコードでPNGメタデータが消える場合があるため、ファイル名と設計図で確認。曖昧なときは誤適用しない。カメラ設定はプレビュー、最終アイコンはユーザーの実ファイルを優先。詳細は `tools/icon_studio/README.md` と `docs/MODEL_PART_WORKFLOW_ja.md`。

## 装備モデル追加の完了条件（2026-11-21）
**NEXUS表示のみでは未完了。** LABの装備製作・固有UID/5効果・保存・装着まで同PRで接続しCI検証。HEAD DはLAB未登録のため完了扱い禁止。詳細正本: `docs/SERA_EQUIPMENT_MODEL_LAB_INTAKE_ja.md`。

## Staged model intake
For new `strage`/`storage` uploads, follow `docs/SERA_INCOMING_MODEL_INTAKE_ja.md`: merge canonical clips and Swordeffect, rebuild, review and merge, run full post-merge CI, then delete only unreferenced staging files.

## Quick commands
```sh
python3 tools/sera_workplan.py --query step --json     # focused edit plan
python3 tools/sera_workplan.py --query katana --execute # local registered Python tests only
python3 tools/sera_quick_check.py                       # core static checks
python3 tools/sera_ci_suite.py static --workers 4      # FULL registered Python suite
# GitHub main push CI runs the FULL Godot suite after merge, in isolated processes.
```

Historical instructions and v102–v292 decisions remain available at `docs/history/AGENTS_THROUGH_V316.md`; their superseded numeric values, model paths and design drafts must not override the current code.

## v317 optional Android diagnostics
- During Android training only, DIAG: OFF toggles diagnostic recording ON. COPY LOG copies bounded local runtime samples to the device clipboard; paste into chat for analysis. No telemetry or network access when OFF. Details in `docs/SERA_ANDROID_DIAGNOSTICS_ja.md`.
- Existing touch controller areas and ordinary game logic must not be changed for diagnostic instrumentation.

## v317 main.gd split contracts
Keep `main.gd` live state, inputs, collisions, scene effects, HUD priority and tick ordering. Extract presentation/math only without changing numeric thresholds. Require full post-merge main CI; verify Android visuals separately.

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
- **HUD:** `sera_combat_hud_text.gd` owns action text; `sera_numeric_hud.gd` owns numerical text; `sera_hud_layout.gd` builds panel, vitals and STEP nodes. Main keeps priority, resources, buttons, callbacks and input exclusion.

See `docs/SERA_DEVELOPMENT_FASTPATH_ja.md` and `DEVELOPMENT.md` for details.
