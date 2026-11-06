# セラ v105 — BGMが再生されない問題の修正（2026-11-06）

- 基準：`main` v104。ユーザーから「BGMが流れない」との報告。
- **推定原因（未実機確定）**：従来の `ResourceLoader.exists()` + `load()` 方式が、Android GitSync直後の未インポート/古いインポートキャッシュで音源を見つけられない可能性。
- `scripts/stage_bgm.gd` の読み込みを、Godot公式のランタイムOGG直接読み込み `AudioStreamOggVorbis.load_from_file("res://BGM/...")` に変更。`ResourceLoader.exists()` による再生中断を廃止。
- ステージがシーンツリーに追加された後、遅延呼び出しでBGMを開始します。失敗時はファイル存在判定を含めて `push_error` し、成功時はイントロ開始／ループ開始を `print` します。
- イントロ1回 → ループ本編の連続再生、BGM音量-9dB、既存の戦闘SEとゲーム処理は変更しません。OGG実体、`scenes/main.tscn`、`scripts/main.gd` 等も変更しません。
- 新規 `tools/v105_stage_bgm_self_check.py` を追加。原本のSHA-256・サイズ・Ogg Vorbis署名・シーン接続・コード配線を検査します。
- 静的単体検査とPython構文検査は合格。**Godot実行およびXperia 1 Vでの音声再生確認は未実施**。端末では `SERA BGM: intro playing` のログ、約8秒後の `SERA BGM: loop playing`、実際の音を確認してください。
