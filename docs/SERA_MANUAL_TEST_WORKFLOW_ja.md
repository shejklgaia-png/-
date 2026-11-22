# SERA 開発運用：自動CIに依存しない変更別テスト（2026-11-22）

**現行の優先ルール。** `AGENTS.md` と `docs/agent/CI_WORKFLOW.md` から参照する。過去の「全PR／main pushでフルCI必須」の記述に優先する。
目的は **GitHub Actions のテスト待ちで開発を止めない** ことであり、テストを省略した事実を合格と扱うことではない。

## 変更フロー
1. 最新 `main`、既存PR、`project.godot`、変更対象を確認。既存テストと現行仕様 `tools/sera_active_specs.json` を調べる。
2. `python3 tools/sera_workplan.py --query "変更内容" --json`（または `--changed path`）で影響候補を得る。候補は推測なので、動的参照・共有コード・間接依存は手動で補完する。
3. **仕様変更なら実装前に関連するテスト期待値を更新**。過去の仕様を理由なく維持したり、実装値を正解としてテストを弱めたりしない。
4. 作業ブランチで最小差分実装。可能なローカル静的テスト、Godotの局所ランタイム検査、描画・操作・データ互換性の確認を行う。失敗があれば原因分類・修正する。
5. PRに変更内容・実行したテスト名と結果・未実行の検査と理由・実機で見る箇所・リスクを記載。差分レビューと必要な検査を満たしたら `main` へマージ。
6. Androidでの見た目・タッチ・FPS・音・動きは **Xperia実機確認**として別に記録。Godot headless／静的テストを「実機合格」にしない。

## 変更リスクごとの最低確認
| 変更範囲 | 最低限 | 追加条件 |
| --- | --- | --- |
| 文書・CI設定のみ | 差分・YAML構造／手動dispatchの確認 | ゲーム版は進めない |
| 色・文字・配置・UI | 構文・対象UIテスト・実画面の表示確認 | 画面未取得なら未検証と明記。BASEは `docs/agent/BASE_VISUAL_REVIEW.md` に従う |
| 3Dモデル・描画・アニメ | 正本・該当静的／Godot検査 | 実画面・姿勢・カリング・重なりを実機確認 |
| 戦闘・AI・部位破壊・GRID | 仕様に対応する計算／遷移テスト・実Godot挙動 | 影響する他系統の回帰も追加 |
| 保存・装備数値・共通基盤 | 関連する広範囲の回帰テストと互換性確認 | 重要な検査ができない場合、原則マージを保留して理由を報告 |

## ローカル検査（GitHub Actions不要）
```sh
# 検査候補・変更影響を先に確認
python3 tools/sera_workplan.py --query "BASE 施設" --json
python3 tools/sera_change_impact.py --changed scripts/sera_base_architecture.gd --json

# 最低限の静的プリフライト
python3 tools/sera_quick_check.py

# 登録済みの変更関連テストを個別に指定（パスは manifest から選ぶ）
python3 tools/sera_ci_suite.py static --tests tools/base_visible_silhouette_ribbon_self_check.py
# Godotの実行ファイルを利用できる場合に限る
python3 tools/sera_ci_suite.py godot --godot /path/to/godot --tests tools/base_visible_silhouette_ribbon_runtime_check.gd

# リスクが広い場合、手元で全件実行可能
python3 tools/sera_ci_suite.py static --workers 4
python3 tools/sera_ci_suite.py godot --godot /path/to/godot --workers 3
```
`tools/sera_ci_manifest.txt` をテスト登録の正本とする。登録済みテストは削除・一律スキップ・無根拠な緩和をしない。既存 `tools/sera_workplan.py --query "対象" --execute --godot /path/to/godot` も局所検査に使用可。Godotを渡さない場合はその検査を実行していないと明記する。

## GitHub Actionsの新しい扱い
- テスト専用10ワークフローの `pull_request` / `push` トリガーを削除し、`workflow_dispatch` のみ維持。すでに手動専用だった2本も維持。**Actions全体を無効化するのではない**。
- `sera-model-policy.yml` の大量の検査・19種類の装備画像生成と公開処理は手動起動時のみ実行される。自動生成されなくなる画像は、装備変更時に必要な生成・検証・コミットを別途行う。
- `equipment-godot-web-preview.yml` のWebプレビュー配布も手動起動時に限る。自動で更新されたと誤認しない。
- ゲームAPK、ローダーAPK、GitSync通知、フォント配布・履歴整理の既存ワークフローの発火条件は今回変更しない。これらはActions上に引き続き実行履歴が現れる可能性がある。
- 過去のキュー待ち・実行中ジョブは、トリガー変更だけではキャンセルされない。GitHub画面から管理する。
- 将来の全件検証は、影響範囲が広いときのローカル実行、または明示的な手動Actionsで実施。**全件CIの完了を通常マージの一律条件にはしない**。

## PR検査結果テンプレート
- 変更：対象ファイルと理由
- 仕様・期待値：更新／維持したテストと根拠
- 静的検査：テスト名、実行環境、PASS/FAIL/未実行
- Godot検査：テスト名、実行環境、PASS/FAIL/未実行
- Android実機：確認済み／未確認、見た目・操作・音・FPSなど
- リスク：未検証の重大項目があればマージ保留、または限定条件と対処方針
- マージ：PRとコミット、実施日時

このルールは**開発・検証手順の変更のみ**。ゲームの挙動・モデル・アニメ・既存の期待値は変更しない。
