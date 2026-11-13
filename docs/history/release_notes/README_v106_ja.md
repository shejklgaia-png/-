# セラ v106 — 4方向RUNモーション（2026-11-07）

- 基準：GitHub `main` v105（コミット `63ecd229b82d26afc88e5c1f3fe8ed4b09f1028b`）。
- ユーザー追加の `bbmodel/SERA_back.bbmodel` を検査し、`run_front_original`・`run_back`・`run_right`・`run_Left` の計4クリップを `assets/sera_source.json` へ統合。各1秒のループ。`run_front_original` はユーザーの更新内容を採用。
- **既存の形状・ボーン・階層・材質・その他13クリップは維持**。追加ファイル側の異なる Swordeffect 形状や、既存 `Jump` と名前の違う `ジャンプ` は取り込まない。旧モデルのソースファイルはそのまま保持し、編集用統合モデルは `blockbench/SERA_v106_four_way_run_integrated.bbmodel` に保存。
- RUN中は画面基準ドラッグを従来どおり地面移動ベクトルへ変換し、ターゲット方向を正面として **前／後／右／左** の最大成分でRUNクリップを選択。斜め入力では最も近い方向を用い、境界付近は短い切替抑制を設ける。4方向RUN間は0.16秒で姿勢補間し、アニメーションのループ位相を維持。全4方向に従来の再生倍率1.5を適用。
- BOOSTの `Boost_front`、左右STEP、Backstep、3段格闘、被弾、Guard、Jumpテスト、移動速度、衝突、カメラ、BGMは変更しない。HUDのRUNクリップ名は実際に選ばれた方向を表示する。
- `assets/sera_data.gd` は埋め込み元と一致するよう再生成。`tools/v102_guardfix_self_check.py` は将来のモデル機能追加でも過去の形状とGuard不変性を検査できるよう、旧版と現行版の完全一致判定を形状比較へ変更。
- 検査：コネクタ経由のJSON構造、4クリップのタイムライン／キー、参照ボーン、既存13クリップの一致、既存形状一致、埋め込み再現性、入力方向の静的分岐を検査。リポジトリ内追加テスト `tools/v106_four_way_run_self_check.py` を用意。**Godotランタイム、Pythonテストコマンド、Android実機操作は未実行**。スマホで前後左右、斜め境界、Boost／Step／Guard復帰を確認してください。
