# トレーニング：ビットタラン同一の完成フレーム表示と頭部赤ちらつき対策
更新日：2026-11-24

## 問題
トレーニングモードはPR #891で深度付き可視RGB12 ID輪郭生成と末尾_processの姿勢同期が共通化されたが、`scenes/main.tscn`だけは旧来のNode3D直描画構造で、ビットタラン戦PR #884の完成フレーム合成を経由していなかった。

また、トレーニングターゲットの真っ赤な`FloatingBox`本体の前面（ローカルZ=1.70m）に対し、頭部pivotのZ=1.85mではNeckMountの後端がZ=1.43m、SensorHousingの後端がZ=1.51mに入り込み、頭部メッシュの合間から赤い本体が見える配置だった。撮影画像だけで時間的なちらつき原因を確定できないが、深度・重なりの疑いを解消する。

## 実装
- 旧`scenes/main.tscn`のNode3D本体＋StageBGMを、`scenes/main_world.tscn`へ**元の階層・スクリプトを保持したまま**移動した。
- `scenes/main.tscn`はビットタラン戦の`scenes/bittaran_battle.tscn`と**同一のSubViewportContainer/CompletedBattleFrame構造・同一Script`scripts/bittaran_complete_frame_presenter.gd`**を使用。内部のインスタンスだけ`SeraTrainingWorld`とした。UI操作イベントはSubViewportContainerの転送、描画FPS・縦画角は同じプレゼンターで管理する。
- ID用Subviewは既存`scripts/sera_scene_id_outlines.gd`の深度付きRGB12・`process_priority=10000`の最終姿勢同期・`UPDATE_ALWAYS`を利用。トレーニングの通常role=1プロファイル0の**内1px／外3px／メッシュ境界3px**を変更しない。ビットタラン戦の**内0px／外3px／境界1px**にも一切影響しない。
- `scripts/target_parts.gd`で、トレーニング頭部のpivotを元Z=1.85mからZ=2.13mへ移動する。NeckMountの後端はZ=1.71mとなり、赤本体の前面Z=1.70mを突き抜けない。頭部の見た目だけでなく、`_add_part()`の元pivot全体を変更するので、照準・部位AABB・カメラロック用Area3D・実メッシュから自動生成される移動用CollisionShape3Dは同じ新しい位置に揃う。
- ターゲット本体の赤い材質、通常のダメージフラッシュ、頭部被弾エフェクトは変更しない。BGM・戦闘入力・HUD・リスポーンなど`scripts/main.gd`の挙動は維持する。

## 注意
- 画像に写った赤は元から存在する赤い`FloatingBox`の材質であり、今回の変更は頭部との重なりを解消するもの。時間的なちらつき原因の全てを特定したわけではない。
- 完成フレームを使ってもGPUの異なるSubViewport画像の描画完了時刻が必ず一致する保証はなく、実機での追従精度・FPSは未確認。
- ユーザーの開発ルールに従い、CI項目/テスト関連の確認・変更・適用、CI/Godot/Androidなど一切の動作テストは行っていない。
