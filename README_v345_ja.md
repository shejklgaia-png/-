# SERA v345 — ビットタラン初登場

## 出撃ゲート
- NEXUSのDEPLOYMENT GATEを選択すると、ボス選択リストを表示します。
- 「ビットタラン / BITTARAN」をタップすると専用の戦闘シーンへ遷移します。通常のTRAINING ROOMには影響しません。

## ビットタラン
- ユーザー制作 `models/storage/ボステスト (2).bbmodel` の姿勢・14関節（本体/頭/前脚4節/後脚4節/足先4個）を保持した正本 `models/bosses/Bittaran.bbmodel` を導入しました。
- `Wait` の原本10キーを保存し、`Idle` 2.4秒、`Turn` 1.8秒、`Approach` 2.8秒のループクリップを追加しました。
- 出撃時は合計100°の水平視野角の外にいるプレイヤーをその場旋回で探索し、内側に入ると緩やかに旋回しつつ接近します。
- 歩行速度0.72m/s、加速度0.60m/s²、停止旋回34°/秒、移動旋回22°/秒、近距離追尾旋回18°/秒、停止距離3.9m・再接近4.3m。
- 攻撃は未実装です（訓練ターゲットの射撃は引き継ぎません）。撃破時は訓練用の自動復活を停止します。
- ゲーム本体のプレイヤー操作、カメラ、SERA装備は既存のコードを共有します。

## モデル運用と検証
- `models/manifest.json` のbossesで正本を定義。`tools/sera_model_build.py` がAndroid向け `assets/bittaran_data.gd` を再生成・整合性確認します。
- `tools/v345_bittaran_self_check.py` と `tools/v345_bittaran_runtime_check.gd` を共通CIに追加しました。
- Godot headlessの検査は3D構造・シーンロード・実行時分岐を検査します。Androidの歩行時の接地・表示・描画FPSは実機確認が必要です。
