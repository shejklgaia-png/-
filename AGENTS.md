# SERA — coding agents (compact entrypoint)

> **Authority:** latest user instructions, latest `main`, `project.godot`, running code, and `models/manifest.json`. Old notes (`docs/history/`) are not current specifications. This file is the small mandatory entrypoint; all prior operative rules were preserved verbatim by section in `docs/agent/`.

## モデリング専用の恒久例外（2026-11-25 ユーザー明示許可）
- モデリングに必要な全動作を許可する。Blenderの起動・モデル制作・専用Actions・レンダリング・成果物回収・画像比較・メッシュ/UV/法線/干渉検査・Godotインポート/描画確認・必要なテストと反復改善を含む。
- この例外は下記CI/テスト禁止およびBASEの撮影禁止より優先する。ただしモデリングに無関係な既存ゲームのCI/テスト項目・ワークフローには適用しない。専用制作・検査経路を分離する。
- 実モデルのレンダリングは画像生成AIではない。従来の画像生成AIの禁止は維持する。実行結果と未確認事項を区別して台帳へ記録する。

## Required for every change
1. 着手時にSERA開発台帳の運用ポリシー・関連作業を参照し、最新の `main` と対象PRを確認する。GitHubをコードと反映状況の正本とし、最新のユーザー指示を優先する。完了時は実際の差分・確認結果・PR・コミット・マージ状態を台帳に記録する。
2. **CI / テスト全面禁止（最優先・解除指示まで継続）:** CIテストの項目・ケース・期待値・登録内容を**確認、修正、追加、適用しない**。テスト用ファイル、manifest、CIワークフローに触れない。GitHub ActionsのCI、ローカルPython/Godotテスト、静的テスト、ランタイムテスト、実機テストを**実行・起動しない**。テスト目的の検証・再実行も禁止する。開発支援ツールもCIテスト項目を調査したりテストを実行するものは使用しない。従来の「CI期待値を先に直す」「各変更でテストする」「検査がない場合はマージ保留」は**適用しない**。
3. Implement only the requested production code/assets/documentation with focused manual source reading and change review **that does not inspect any CI test item or execute a test**. Keep unrelated behavior, save formats, Android compatibility, and model masters intact; avoid speculative rewrites.
4. 通常の開発指示（「実装」「反映」「修正」など）は、変更を実装して差分を確認し、原則 `main` にマージする。「マージしない」と明示された場合は確認後に待機する。「マージ」は対象PRと最新 `main` を確認して統合する。NEXUS・拠点ブラッシュアップの定期作業も現在の設定に従い、反映可能な変更を原則その回でマージする。画像生成は明示された依頼だけを別作業として扱う。
5. Test outcomes must never be described as PASS or verified when no test was run. If needed, report remaining unverified risks plainly; testing being prohibited is not, by itself, a reason to block a user-requested merge.
6. Log meaningful changes in `DEVELOPMENT.md`. Increment SERA version only for requested gameplay changes.

## Routed rules (load when relevant)
- **調査の入口・GitHub再検索:** [`docs/agent/WORKFLOW_ENTRYPOINTS_ja.md`](docs/agent/WORKFLOW_ENTRYPOINTS_ja.md)。枠線、NEXUS装備プレビュー、BASE施設の調査先と、接続・権限・操作可否の切り分け。
- `docs/agent/SOURCE_POLICY.md`: canonical model sources, generated assets, GitSync/Android, import, rendering and diagnostic guards.
- **HTML配布・起動リンク:** `docs/SERA_HTML_ARTIFACT_DELIVERY_POLICY_ja.md` — Raw URLをアプリの直リンクとして提示しない。公開HTTPS/実HTML添付/複数ファイル配布を区別し、起動を確認する。
- `docs/agent/EQUIPMENT.md`: warehouse individual UID / 999-limit rules, Icon Studio handoff, LAB integration, model acceptance. **New-chat equipment implementation contract:** `docs/SERA_EQUIPMENT_CROSS_CHAT_HANDOFF_ja.md` (mandatory for `SERA_EQUIPMENT_INTAKE_V1` exports).
- `docs/agent/RUNTIME_BOUNDARIES.md`: `main.gd` split-contract ownership for input, physics, combat, camera, EN, HUD and FX.
- **BASE external visual changes:** `docs/agent/BASE_VISUAL_REVIEW.md` — 現行画像が利用できる場合は見た目の設計判断に参照できるが、テストとしての実行・撮影・検証は上記禁止ルールにより行わない。
- 機能別の仕様書と実装は調査の入口から直接参照する。 When models or animations change, also read `docs/MODEL_PART_WORKFLOW_ja.md` (**SERA_MODEL_PARTS_V1**), `docs/SERA_ANIMATION_RUNTIME_POLICY_ja.md`, and `models/manifest.json`. When rendering changes, read `docs/RENDER_PIPELINE_POLICY_ja.md`.
- Old, superseded policies are retained at `docs/history/AGENTS_THROUGH_V316.md`, not treated as current.

## テスト運用の優先順位
- `docs/agent/CI_WORKFLOW.md` と `docs/SERA_MANUAL_TEST_WORKFLOW_ja.md` は、上記禁止ルールを正本とする。
- 旧文書に残るテスト実施・CI項目先行更新・CI修正・テスト必須の文言は、2026-11-22のユーザー指示によって無効化する。
