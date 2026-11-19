# SERA v502 — 拠点フィールドにLABOと資源設備を実装

## 変更点
- NEXUSの既存の出撃・アセンブル・トレーニング・データ・設定を変更せず、建物を右側へ移動。左隣に独立した3D建物**LABO**を追加。
- 個別に**スクラップ回収機、精製炉、リサイクラー、発電機、資材保管庫、建設端末**を俯瞰拠点フィールドへ直置き。ポリゴン製の各設備に名前・発光アクセント・タップ判定を設ける。
- 設備タップで拠点内専用パネルを表示。LABOで「Shell＝性能向上」「OS＝機能拡充」「追加効果スロットの研究」の役割を確認でき、設備はそれぞれ独立した説明画面を持つ。閉じるボタンと画面外タップで復帰する。
- 発電機の回転アニメーション、CRATEの巡回路変更、装飾モデルを設備から離す配置調整を実施。グリッド床と現行のセラ/コントローラ非表示、およびNEXUSの行き帰りは維持。

## 未確定のため今回操作を接続していない部分
- 資源の獲得量、加工比率・コスト、電力容量、建築費、Shell装備とOS研究の実際の進行は未確定。今回は**施設外観とタップUIの実装**であり、仮の資源消費・獲得や研究完了処理は入れない。

## CI仕様の先行対応
- 作業前に`AGENTS.md`、現行`main`と`project.godot`、`tools/sera_ci_manifest.txt`、`tools/base_exploration_self_check.py`、`tools/base_exploration_runtime_check.gd`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`docs/RENDER_PIPELINE_POLICY_ja.md`、post-mergeワークフローを確認。
- 本体実装に先立ち`tools/base_facilities_self_check.py`と`tools/base_facilities_runtime_check.gd`を作成・CI登録。新規テストは7設備の3Dノードと画面タップ、モーダル開閉、既存NEXUS保持を検査。
- 既存のNEXUS画面遷移、CRATE移動、セラの一時非表示、グリッド床、戦闘を保護するCIの期待値は変更しない。全CIはmainマージ後に実行し、Android実機で可読性・タップ誤操作を別途確認。

前バージョン：[v501](README_v501_ja.md)
