# SERA v130 — カスタマイズモデル拡大／NEXUSpose自動適用

## 変更内容
- CUSTOMIZE背景、カメラ目標位置、右下戻る、左メニューパネル、設備配置を維持。
- v129では全周フィットの拡大係数上限（1.55倍・1.05倍）が低く、モデルが小さく表示される可能性があった。v130ではプレビュー距離4.60→3.25、初期スケール0.80→1.40、縦の表示可能範囲28.0〜76.5%→15.0〜86.0%へ拡張。モデルの剣・盾・四肢を含む16方向の全周エンベロープを再計算し、実際の空き幅・高さに合う倍率で拡大する。
- 左パネル右端＋18pxから画面幅97%までをモデル表示の安全領域として維持。回転時に剣や盾が左パネルへ重ならないよう調整。背景やカメラではなくモデル本体だけを変更。
- NEXUSposeはBlockbenchアニメーション名の完全一致で探索。models/SERA_BOOSTER_allテスト.bbmodel、models/SERA_BOOSTER_all.bbmodel、assets/sera_source.jsonの順に確認し、見つかれば既存SeraRigのBlockbench ZYX回転変換処理で展示用セラにのみ適用する。戦闘用のアニメーションや元モデルは変更しない。
- GitHub同期前でNEXUSposeがモデルに存在しない場合、架空のポーズを作らず、従来の中立展示姿勢を表示する。モデル同期後は次の拠点起動時に探索・適用する。
- 左右ドラッグ回転、カメラ0.18秒移動、元の展示姿勢への復帰、選択枠、ゲート遮蔽は維持。

## 検証・制限
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧静的検査v125〜v129。新規：tools/v130_nexus_pose_enlarge_self_check.py、README_v130_ja.md。
- Bash・Guard_REACTIONを含むユーザーのBlockbenchモデルと、戦闘シーン、BGM/SE、その他のアセットは編集しない。
- 現行GitHubのテストモデルにはNEXUSposeがまだ見つかっていないため、実ポーズの適用成功は未確認。AndroidのAPK形式で実行する場合は未インポートのbbmodelがパッケージに含まれるかを別途確認する。
- Godotエディタによる実行・Android実機の表示とドラッグ確認は未実施。コードと既存資産の静的検査のみ。
