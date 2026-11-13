# SERA v69 — ダメージモーション短縮・ノックバック

## ベース
- v68 `sera_portrait_godot_melee_v68_damage_reaction.zip` を基準とし、v67までの射撃間隔2秒・弾速12m/sや操作・カメラ・攻撃等を維持します。
- ユーザー提供 `セラ･カラーエフェクト付き (4).bbmodel` 内の `Damageknock`（0.16667秒、once）を採用し、以前の `Damage_motion`（0.5秒）を置き換えます。
- v68の他の7モーション・モデル要素・階層・骨をそのまま保持します。

## 新しい被弾・ノックバック
- プレイヤーのカプセルに敵弾が命中したとき `Damageknock` を再生します。入射した弾の進行方向を信号で引き継ぎ、XZ水平面上で同じ方向へ押し出します（弾が飛んできた側とは反対方向）。
- ノックバック移動：最大0.80m／0.24秒、二次ease-outで徐々に減速。実際の移動量は対象の障害物との衝突状況で短くなることがあります。
- `CharacterBody3D.move_and_collide` による連続衝突判定を使います。壁／敵キューブのすり抜けや速度のフレームレート依存を防ぎます。
- 入力ロックは短いモーションとノックバックの両方が終了するまで継続。途中の攻撃・ステップを中断し、被弾中のフリック／タップ予約は破棄します。ドラッグを継続している場合は終了後に移動へ復帰。
- 被弾中の追加命中ではフラッシュのみ更新し、ノックバック距離や方向、モーションを再設定しません。
- HP、シールド、ガード崩れ、ダウンは今回追加しません。

## 変更ファイル
- `assets/sera_source.json`, `assets/sera_data.gd`（再埋め込み）、`scripts/sera_rig.gd`, `scripts/main.gd`, `scripts/enemy_shooter.gd`, `scripts/enemy_projectile.gd`, `project.godot`。
- v68の統合済み `.bbmodel` 2ファイルを更新。`blockbench/セラ_ダメージノックバック統合.bbmodel` も同梱。
- `README_v69_ja.md`, `DEVELOPMENT.md`, `tools/v69_damage_knockback_self_check.py`。
- 旧版テスト `tools/v68_damage_self_check.py` はv69で通るよう後方互換チェックに修正します。

## 検査
- 変更前後でオリジナル7モーション、骨・メッシュ・アウトライナーを厳密比較。
- Android向けデータの埋め込み一致、攻撃・移動の衝突処理、射撃パラメータ、変更差分、弾方向シグナルを静的検査。
- Godot本体実行／Android実機テストは未実施。実機でノックバックの体感値を確認してください。
