# セラ v89 — ブースト専用モーション（Boost_front）

## 追加・変更

- 基準版：v88 `sera_portrait_godot_melee_v88_backstep_4m.zip`。
- 添付の `SERA_backstep.bbmodel (1)` を JSON 形式の Blockbench モデルと確認し、**`SERA_boost_front.bbmodel`** という正しい拡張子・用途の名前で保管しました（内容は変更なし）。ZIP 内では `blockbench/SERA_boost_front_user_input.bbmodel`。
- 添付ファイル内の **`Boost_front`** をv88モデルへ取り込みました。時刻0の21キーフレームからなる**単一ポーズ**であり、ブースト中はポーズを維持します。独自の繰り返し動作は生成していません。
- 通常移動：`run_front_original`／円外ロングドラッグ加速移動：`Boost_front`／フリックステップ：`Step_L`, `Step_R`, `Backstep` を使用します。
- ブースト突入・解除時は既存の **0.16秒ポーズブレンド**を使用。速度・入力半径・残像・カメラはv88から変更なしです。
- 格闘接近は引き続き `meleeboost`（別アクション）を使用。3段格闘ダメージ12/12/26も変更ありません。
- バックステップの**4m**、左右ステップの挙動・独自モーション・衝突判定も変更なしです。
- ユーザーモデルには既存クリップの小差分と空名クリップがありましたが、既存機能への影響を防ぐため **Boost_frontクリップのみ**を移植しました。統合編集用モデルは `blockbench/SERA_v89_boost_integrated.bbmodel` です。

## 変更ファイル

- `scripts/sera_rig.gd`：Boost_frontクリップ読み込み要件、加速移動時のモーション切替。
- `scripts/main.gd`：ブースト状態をリグに渡す、状態ラベルにモーション名を表示。
- `assets/sera_source.json` / `assets/sera_data.gd`：原本から取り込んだクリップ、およびAndroid用埋め込みデータ。
- `blockbench/SERA_boost_front_user_input.bbmodel` / `blockbench/SERA_v89_boost_integrated.bbmodel`：正しい拡張子の原本／統合用モデル。
- `tools/v87_backstep_self_check.py`：v89でも旧仕様のチェックが成立するよう対応。
- `tools/v89_boost_self_check.py`：新規静的チェック。
- `project.godot`, `DEVELOPMENT.md`, `README_v89_ja.md`。

## 注意

- Godot 4.7.2安定版での実機起動、Androidでの操作・モーション見栄えは未検証です。
- `Boost_front` はキーフレーム1ポーズであるため、走行サイクルのような身体動作は行わず、移動中に姿勢が固定されます。
