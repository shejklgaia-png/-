# SERA v120 — Command Nexus 3D基地の再構築（2026-11-08）

## 問題と修正
実機スクリーンショットでは、v119の仮基地に次の問題がありました。
- **セラが小さく、姿勢が崩れていた**：既存の戦闘用 `Wait_motion` は両膝を曲げた姿勢であり、展示用には適切ではありません。
- **基地の形状が参考画像と異なる**：従来の基地はGodotスクリプト内で独自に箱・柱を生成し、追加されていたBlockbenchファイルを一切使っていませんでした。
- **ゲートや端末が画面外に切れ、UIが文字のみ**：カメラ位置と設備配置、表示パネルを見直す必要がありました。

## 実装
1. **Blockbenchで設備を作り、Godotで使用**
   - `blockbench/base/SERA_hangar_shell.bbmodel` — 床・壁・梁・支柱・渡り廊下・床灯。
   - `blockbench/base/SERA_maintenance_pad.bbmodel` — 中央整備プラットフォーム。
   - `blockbench/base/SERA_maintenance_canopy.bbmodel` — 上部の照明リング。
   - `blockbench/base/SERA_deployment_gate.bbmodel` — アーチ・照明・奥行きのある出撃通路。
   - `blockbench/base/SERA_kiosk.bbmodel` — 訓練/システム用共通端末（2台）。
   - `blockbench/base/SERA_data_bank.bbmodel` — データ用2画面端末。
   - これらの原本から `assets/base_command_modules.gd` に埋め込んだ部品座標と色番号を生成し、`scripts/command_nexus.gd` から実際に使用します。**Blockbenchの形状変更後は埋め込みデータの再生成が必要**です。Godotは従来の仮モデルを参照しません。
2. **スマホ向け描画最適化**：約223個の立方体部品を、色別の8色程度の `MultiMesh` に集約。稼働部品・粒子・物理は追加しません。中央台座の12角柱のみGodotの `CylinderMesh` を使用します。
3. **セラの展示姿勢**：既存 `SeraRig` を読み込み、基地内だけアニメーション進行を停止し、バインドポーズに腕の角度だけ調整を加えます。戦闘の `Wait_motion` やアニメーションファイル、アセットは変更しません。
4. **カメラ調整**：画面比720×1280の縦画面前提で、中央のセラに寄りつつ左右設備が入るようレイアウト変更。
5. **基地のUIパネル**：DATA ARCHIVE、DEPLOYMENT、TRAINING、SYSTEM、CUSTOMIZEの5種類。暗色のパネルとシアンの枠、手描き2Dアイコンを表示。**いずれも表示のみで操作不可**。
6. **起動選択は維持**：`TRAINING ROOM` と `SERA COMMAND NEXUS` の2択はv119のままです。

## 変更ファイル
- 新規：`blockbench/base/SERA_*.bbmodel`（6種）、`assets/base_command_modules.gd`、`scripts/nexus_tag_icon.gd`、`tools/v120_command_nexus_self_check.py`、本README
- 変更：`scripts/command_nexus.gd`、`project.godot`、旧版テスト `tools/v119_command_nexus_self_check.py`、`DEVELOPMENT.md`。
- 不変更：`scripts/sera_rig.gd`、`scripts/main.gd`、`assets/sera_source.json`、`assets/sera_data.gd`、`scenes/main.tscn`、音声、格闘・ガード・ブースト・カメラ（訓練）関係。

## 検証上の注意
- `python3 tools/v120_command_nexus_self_check.py`：6つのBlockbench原本とGodot部品データの同一性、部品数、描画方法、表示のみのUI、モデル表示方法、起動先を検査。
- 旧版の `python3 tools/v119_command_nexus_self_check.py`、`python3 tools/codex_project_check.py`、`python3 tools/self_check.py`、`python3 tools/v102_guardfix_self_check.py` 等の静的検査と整合させる。
- Godot本体およびXperia 1 Vでの見た目、フレーミング、タップ、FPSについては、この修正だけでは確認できません。

## Android実機での確認
1. GitSyncでmainを同期し、Godotを再読込。
2. 起動選択で`SERA COMMAND NEXUS`を選択。
3. セラが立った状態で中央に表示され、出撃ゲート、データ・訓練・システム端末、中央リングが見えるか確認。
4. どの基地内設備もタップで遷移しないことを確認。
5. 再起動して訓練シーンが既存どおり動作するか確認。

補足：従来の `blockbench/SERA_Command_Nexus_LowPoly.bbmodel` はv117の試作資産であり、新しい拠点では使用しません。
