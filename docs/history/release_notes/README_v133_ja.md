# SERA v133 — Nexus選択枠の即時切り替え（2026-11-08）

- TRAINING・SYSTEM・CUSTOMIZE・DATA ARCHIVE・DEPLOYMENTは、タップ／クリックした時点で対象の明るい輪郭線を付けます。カメラ移動終了を待ちません。
- 右下の戻るUI、Androidの戻る、Escでは、押した時点で選択中の明るい枠線を消します。全景への移動が完了するまで待ちません。
- 既存の通常時の枠線明滅、選択可能な設備、カメラの0.18秒Cubic Ease Out、カスタマイズ表示、トレーニングへの遷移、3D素材・戦闘機能は維持します。

静的チェック：`python3 tools/v133_nexus_selection_timing_self_check.py`。Godotパーサ・Android画面での実動作は未検証です。
