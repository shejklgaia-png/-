# SERA v119 — 起動選択画面・拠点シーンの修正（2026-11-08）

## 対応内容
- **起動選択画面**：動的生成と固定位置指定を廃止。Godotのシーン内にフル画面の背景、マージン、CenterContainer、縦並びの2つのボタンを置き、画面中央に配置しました。ボタン幅は画面に合わせ、最大500pxに制限します。
- **Androidタップ操作**：既存の戦闘画面では `input_devices/pointing/emulate_mouse_from_touch=false` です。通常のButtonはこの設定のままではタップをクリックと認識しないため、選択画面の表示中だけ `Input.emulate_mouse_from_touch=true` にし、シーン終了時に元の値に戻します。
- **拠点を開けない問題**：`scripts/command_nexus.gd` にGodot 4では存在しない定数 `Environment.AMBIENT_COLOR` がありました。正しい `Environment.AMBIENT_SOURCE_COLOR` に置換し、環境光の寄与率を調整しました。
- **遷移失敗時**：メニューに失敗メッセージを表示し、Godotデバッガーにもエラーを記録します。成功した場合のみシーン遷移します。
- **テスト整合性**：汎用検査のメインシーンパスを起動選択画面に更新し、v116の過去機能テストも後継バージョンの名称で実行できるようにしました。

## 変更対象
`scenes/launch_menu.tscn`, `scripts/launch_menu.gd`, `scripts/command_nexus.gd`, `project.godot`, `tools/codex_project_check.py`, `tools/v116_animation_timing_self_check.py`, `tools/v119_command_nexus_self_check.py`, `DEVELOPMENT.md`, 本README。

## 維持したもの
- `scenes/main.tscn`、`scripts/main.gd` の戦闘・訓練処理、従来のセラモデル・モーション・コントローラー・オーディオ。
- Blockbenchの簡略化基地素材と拠点内の設備は引き続き静的表示のみ。設備を選ぶ機能は未実装。
- GL Compatibility、720×1280縦画面、Godotのエンジン設定。

## 検証
- `tools/v119_command_nexus_self_check.py` でパス、起動時のボタン構成、センター配置、タッチ変換の復元、環境光定数を静的に検査します。
- `tools/codex_project_check.py`、`tools/self_check.py`、`tools/v102_guardfix_self_check.py`、`tools/v116_animation_timing_self_check.py` が既存の機能を検査します。
- Godotエディターでの実際の起動およびXperia 1 Vでのタップ挙動は**別途実機確認が必要**です。静的検査は実機検証の代わりにはなりません。

## Android確認手順
1. GitSyncで最新 `main` を同期し、Godotでプロジェクトを再読み込みします。
2. 起動時に2つの選択肢が左右に欠けず、画面中央に表示されることを確認します。
3. `SERA COMMAND NEXUS` をタップすると、中央整備台とセラがある基地に移動することを確認します。
4. アプリを再起動して `TRAINING ROOM` をタップし、移動・ブースト・攻撃の片手操作が従来通りであることを確認します。
