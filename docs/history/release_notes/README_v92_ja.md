# セラ v92 — 被弾後のブースト入力復帰修正

**基準：v91** `sera_portrait_godot_melee_v91_enemy_attack_debug.zip`

## 修正内容

- v91では被弾した時点で `gesture_suppressed_from_damage = true` となり、指を離すまで維持されるため、被弾モーション終了後も同じドラッグからブーストへ移行できませんでした。
- `scripts/main.gd` の `_update_boost_gesture()` について、ブースト抑制条件を `gesture_suppressed_from_damage` から `damage_reaction_active` に変更しました。
- 被弾中はブーストを停止します。ノックバックと `Damageknock` 終了後は、指を離さずに125%以上の位置を0.10秒保持すればブーストを再開できます。110%未満で解除、速度0.15秒の遷移は維持します。
- 被弾で中断されたジェスチャーの `gesture_suppressed_from_damage` は**指を離すまで保持**し、解除時のフリック（ステップ）やタップ（攻撃）への誤判定を引き続き禁止します。
- 被弾していない新規ジェスチャーでは通常どおりステップ・攻撃できます。

## 変更ファイル

- `scripts/main.gd`：ブースト受付条件の1行とその説明コメント、v92履歴コメント。
- `project.godot`：版表示のみ。
- `README_v92_ja.md`、`DEVELOPMENT.md`：変更履歴。
- `tools/v92_boost_damage_regression.py`：静的検査・状態遷移の数値模擬・v91との差分照合。

## 維持した機能

v91の敵4種攻撃・選択デバッグUI、走行／ブーストの閾値、`Boost_front`、ステップ・バックステップ4m、格闘3段、カメラ、残像、モデル、被弾モーションを維持します。

## 検証範囲

静的・数値・ファイル差分検査およびZIPの再展開整合性を確認します。Godot 4.7.2本体・Android実機による操作検証は未実施です。
