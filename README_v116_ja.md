# SERA v116 — BOOSTの姿勢遷移高速化とRUNアニメーション1.25倍速（2026-11-08）

## 変更仕様

| 処理 | v115 | v116 |
| --- | ---: | ---: |
| BOOSTの方向変更の指数平滑時定数 | 0.12秒 | **0.06秒** |
| RUN／WAIT ⇄ BOOSTの姿勢遷移 | 0.16秒 | **0.08秒** |
| RUNアニメーションの時間倍率 | 1.5倍 | **1.875倍（現行から1.25倍）** |

- BOOSTは既存の4方向姿勢を角度から合成します。方向の切り替えは最短角を用いて追従時間を半減し、180度反転でゼロベクトルへ落ちない仕組みも維持します。
- RUN→BOOST、BOOST→RUN、および静止⇄BOOSTで、いったん表示中の姿勢を保存して新しい姿勢へ0.08秒でクロスフェードします。RUN⇄WAITの通常遷移や戦闘・STEP・GUARD・JUMPの遷移時間を一律短縮する変更ではありません。
- RUNの周期再生は `clip_time += delta * 1.875` に変更。前後RUNの共通位相、後退判定、利き手による切替範囲、頭部スタビライズ、上体追従、旋回バンクはそのままです。
- 移動速度（RUN 3.25m/s、BOOST1.5倍）、BOOST確定の125%＋0.10秒、解除110%未満、加減速0.15秒には変更がありません。

## 保護・検証
- 変更ファイルは `scripts/sera_rig.gd`・`project.godot`・`DEVELOPMENT.md`・`docs/SERA_INPUT_MOVEMENT_CAMERA.md`・旧テスト3ファイル。新規ファイルは本READMEと `tools/v116_animation_timing_self_check.py`。
- `models/`、`assets/`、`blockbench/`、`scripts/main.gd`、コントローラUI、カメラ、音声、残像、ガード・格闘・ステップの処理は変更していません。
- 静的ソース検証・数字による方向応答検証を実施。Python検査スクリプトとGodot、Android端末での実行はこの作業では未実施です。GitSyncで `main` を同期後、RUN前後左右、BOOSTへの移行、BOOST中の90度／180度方向切替、BOOST解除を実機でご確認ください。
