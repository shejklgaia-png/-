# SERA v127 — コンソール選択先の入れ替え・ゲート枠の遮蔽・線幅増加

## 変更内容
- 手前左のコンソールは SYSTEM、手前右は TRAINING に変更。物理的な端末モデル・位置・角度は変更せず、選択ポリゴンの割り当てと接近カメラ先だけ左右で入れ替え。
- 出撃ゲートの2D選択枠が手前のセラ本体を透過して表示される不具合を修正。ゲートの外周を折れ線として生成し、前景のセラ本体の2D投影輪郭で折れ線クリッピング（Geometry2D.clip_polyline_with_polygon）して、セラと重なる区間を非表示にする。
- クリッピング対象はゲート枠だけ。セラ本体の輪郭は4px広げ、5pxの線がセラの前に出るのを抑える。2Dポリゴン全体をクリップしてセラの境界線に余計な線が出る方式は使用しない。
- 選択枠の線幅：通常時2.5→4.5px、選択時3→5px。明滅の周期と透明度は従来どおり（通常15〜62%、選択中98%）。
- 0.18秒のカメラ移動、画面右下戻るUI、Android戻る、TRAININGの既存ステージ遷移は維持。新規3Dモデル、追加描画パス、パーティクルはなし。

## 変更・保全・検証
- 変更：scripts/command_nexus.gd、scripts/nexus_selection_outline.gd、project.godot、v125/v126静的検査、DEVELOPMENT.md。
- 追加：tools/v127_nexus_gate_occlusion_self_check.py、README_v127_ja.md。
- セラ本体、BashとGuard_REACTION、Blockbenchモデル、訓練ステージ、BGM/SEは変更しない。
- 静的ソース検査のみ。Godot起動・Android実機の遮蔽精度やタップ位置、性能の実測は未実施。
