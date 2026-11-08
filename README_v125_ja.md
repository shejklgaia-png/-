# SERA v125 — Command Nexus 3Dフォーカスメニュー

## 仕様
- 拠点の全景では5つの選択項目の文字ラベル・サブ説明を表示しない。中央壁面の3D「S E R A」装飾はそのまま維持。
- TRAINING（左手前端末）、SYSTEM（右手前端末）、CUSTOMIZE（セラ展示台）、DATA ARCHIVE（左奥高台）、DEPLOYMENT（右奥ゲート）の各輪郭を、3Dカメラ投影から求めた暗いシアンの輪郭でゆっくり明滅（約2.8rad/秒）。
- 対象をワンタップすると、選択対象のみ輪郭を明るく固定し、カメラ位置・回転・FOVを0.18秒のCubic Ease Outで同時補間して対象へ高速接近。
- 移動完了後、対象名を含む最小限のメニューと左上の「<」戻るボタンを表示。左上の戻るボタン、Android戻るキー、Escで0.18秒の逆移動後に全景へ復帰する。
- TRAININGの「ENTER TRAINING」は既存の scenes/main.tscn に遷移する。SYSTEM/CUSTOMIZE/DATA ARCHIVE/DEPLOYMENTは遷移先未実装のため「NOT AVAILABLE YET」と明示し、タップしても偽の操作を発生させない。
- 選択時に追加の画面点滅、グロー、残像、パーティクル、カメラ揺れは使わない。
- Androidは生タップ（InputEventScreenTouch）を直接処理。既存の戦闘用 Input.emulate_mouse_from_touch=false を変えない。PCマウスも対応。

## 変更範囲
- scripts/command_nexus.gd：固定文字プレートを撤去し、選択とカメラ移動/戻るを追加。
- scripts/nexus_selection_outline.gd：軽量CanvasItem輪郭描画。
- project.godot：プロジェクト表示名をv125へ更新。
- tools/v125_nexus_focus_self_check.py：投影形状、タッチ、戻る、補間とソース維持の静的検査。
- v120/121/123/124既存検査：固定プレートを前提にした旧検査のみv125分岐で更新。
- DEVELOPMENT.mdと本READMEで変更履歴を記録。

## 維持内容と検証限界
- 既存戦闘シーン・セラ本体・モーション（Bash, Guard_REACTIONを含む）、Blockbench原本、ゲート照明、メインメニュー起動経路、BGM/SE、GL Compatibilityおよび720×1280の画面設定には変更なし。
- 固定画面の3D空間投影は解析可能ですが、Godotエディタでのスクリプト解析、Android実機でのタップ精度、カメラ接近時の遮蔽・見え方は別途確認が必要です。
