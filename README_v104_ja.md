# セラ v104 — トレーニングステージBGM（2026-11-06）

- 基準：GitHub `main` v103。
- 提供音源 `sera_training_v08_intro.ogg`（約7.74秒）をステージ開始時に1回再生。
- イントロ終了の `AudioStreamPlayer.finished` を受け、`sera_training_v08_loop.ogg`（約61.94秒）を再生開始し、その後はループします。
- 既存のステージ `scenes/main.tscn` に独立した `StageBGM` Node を追加し、`scripts/stage_bgm.gd` が音源を管理します。戦闘SEや `scripts/main.gd` の動作は変更しません。
- 音源はOgg Vorbis（44.1 kHz、2ch）。BGM音量-9 dB。音源が見つからない場合は警告を出し、ゲーム処理は続行します。
- Godot 4.7系の `AudioStreamOggVorbis.loop` および `AudioStreamPlayer.finished` に準拠。
- Android実機での音量、イントロ→ループ境界の聴感、ループ継ぎ目は未検証です。
- 音源2件は `BGM/` に登録済み。Git blob SHAとユーザー添付のハッシュ照合で同一であることを確認。イントロとループの静的検査済み。Godot/Android実機の再生テストは未実施です。
