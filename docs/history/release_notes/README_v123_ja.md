# SERA v123 — 高低差のあるCommand Nexus（2026-11-08）

## 目的
- 手前のTRAINING/SYSTEM端末をさらにカメラ側へ寄せ、左右対称に大きく斜めへ向けます。
- DATA ARCHIVEを左奥の高台へ移し、階段を上がってアクセスする基地構造を作ります。
- DEPLOYMENTは他の設備よりも遠い右奥の大型ゲートとして配置し、通路の奥行きが見えるようにします。
- 上段のモデルが手前のメニュー表示と被らないよう、看板の配置も変更します。

## 3D配置（Godotワールド座標）

| 設備 | v122 | v123 |
|---|---|---|
| 左手前 TRAINING | (-1.70, 0, -0.65), +18° | **(-1.82, 0, +0.75), +34°** |
| 右手前 SYSTEM | (+1.70, 0, -0.65), -18° | **(+1.82, 0, +0.75), -34°** |
| DATA ARCHIVE | (-3.12, 0, -8.05) | **(-4.00, 2.19, -8.95)** |
| 高台／階段 | なし | **(-4.00, 0, -6.55)** |
| DEPLOYMENT | (+2.94, 0.02, -8.28), 0.70倍 | **(+4.05, 0.02, -10.48), 横奥行1.20倍・高さ1.50倍** |
| セラ・中央整備台 | z=-4.60 | **z=-4.75** |

ゲートは元のBlockbench形状を拡大して使用します。現行モジュールの全高約4.4mに対し、v123では高さ約6.6m。セラのモデルより大幅に高い右奥のゲートとしています。旧後壁がゲートを遮らないように、奥壁にはゲートに対応する開口部を作成しました。

## カメラと画面内の構成
- カメラ位置：(0, 4.10, 10.20)
- 注視点：(0, 3.00, -5.50)
- 縦FOV：63°
- UI高さ（0〜1基準）：DATA ARCHIVE 0.325、DEPLOYMENT 0.275、TRAINING/SYSTEM 0.850、CUSTOMIZE 0.935。
- 奥の2モデルの画面上端は、それぞれの看板の下へ配置され、手前のパネルはさらに下へ移して奥設備の表示領域を避けます。
- ユーザーが操作するのは起動時の2択のみ。基地内設備のタップによるシステム動作は追加しません。

## Blockbench → Godotの素材管理
- 追加：`blockbench/base/SERA_archive_mezzanine.bbmodel`（6段の階段、踊り場・支柱・手すり・発光ライン）。
- 修正：`blockbench/base/SERA_hangar_shell.bbmodel`（後壁の出撃ゲート開口部）。
- 再生成：`assets/base_command_modules.gd`。更新した2つのBlockbenchモデルの部品座標を反映しています。
- 既存の端末、整備台、出撃ゲート本体、セラのモデル原本は変更せず、Godotの`scripts/command_nexus.gd`で位置・回転・スケールを指定します。追加した高台は多色のMultiMeshで従来の描画バッチに統合されます。

## 変更ファイル
`scripts/command_nexus.gd`、`assets/base_command_modules.gd`、`blockbench/base/SERA_hangar_shell.bbmodel`、`blockbench/base/SERA_archive_mezzanine.bbmodel`、`project.godot`、旧静的検査3種、`tools/v123_nexus_terraced_depth_self_check.py`、`DEVELOPMENT.md`、本README。

## 維持事項と検証範囲
- `scenes/main.tscn`、`scripts/main.gd`、`scripts/sera_rig.gd`、既存キャラクター・コンボ/ブースト/ガード/カメラ、音源、起動2択は変更しません。
- GL Compatibilityと720x1280の縦画面を維持しています。
- 静的テスト：Blockbenchと埋め込み形状の一致、階段上昇、後壁の開口、拡大ゲートの高さ、2つの手前端末の回転角、3DモデルとHUDの投影領域を確認します。
- **Godot実行／Android実機での描画・視認性・FPSは未検証**です。特に高台から階段へつながる見え方とゲートの輪郭は、スマートフォンのスクリーンショットで確認する必要があります。
