# SERA v70 — ノックバック距離・被弾モーション再生時間の調整

## 基準
- v69 `sera_portrait_godot_melee_v69_damage_knockback.zip` を直接の基準にしています。

## 調整内容
- 被弾ノックバック距離：0.80m → **1.20m**（最大値。衝突時は短縮）。
- 被弾モーション `Damageknock`：0.16667秒 → **0.22秒**。各キーフレーム時刻を同じ比率（約1.32倍）で伸ばし、ポーズ・補間の順番・骨の回転値は変更していません。
- ノックバック移動時間：**0.24秒のまま**。移動には二次ease-outと `CharacterBody3D.move_and_collide` を引き続き利用します。
- 入力ロックはモーションとノックバックの双方が完了するまで。今回も0.24秒で復帰する想定です（実際のフレーム刻みで前後）。
- 予兆0.65秒、射撃間隔2秒、弾速12m/s、カメラ・近接攻撃・移動・操作UIは維持します。
- プレイヤーHP・ガード崩れ・ダウンは未実装のままです。

## 修正対象
- `scripts/main.gd`：ノックバック距離の定数のみ（機能面）。
- `assets/sera_source.json`：`Damageknock` の時刻のみ。
- `assets/sera_data.gd`：APK用の組み込みデータを更新。
- `blockbench/*.bbmodel`：8モーション収録済み3ファイルの `Damageknock` を同様に更新。5モーションだけの旧モデルはそのまま保持。
- `project.godot`：表示版名v70に変更。
- `README_v70_ja.md`, `DEVELOPMENT.md`, `tools/v70_damage_knockback_self_check.py` を追加・更新。従来の `tools/v68_damage_self_check.py` の許容モーション時間に0.22秒を追加（検査内容は同等）。

## 検証
- v69との差分、骨・メッシュ・既存7モーションの完全一致、被弾モーションキーフレームの姿勢データ、組み込み用JSONの一致、移動・射撃コードの不変を静的に検査します。
- Godotエディターでの起動とAndroid実機検証は未実施です。
