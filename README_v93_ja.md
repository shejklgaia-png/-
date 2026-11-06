# セラ v93 — 敵・自機のダメージ効果音を統一（2026-11-06）

**基準版**: v92 `sera_portrait_godot_melee_v92_boost_damage_recovery.zip`

## 変更内容

- ユーザー提供の `金属叩き.mp3` を、音色・再生速度・余韻を編集せず、Godotの短い効果音再生向けに 44.1 kHz / 16-bit / stereo のWAVへデコードし、`assets/metal_damage_hit.wav` として収録しました。
- 原音も `assets/metal_damage_hit_source.mp3` に保管しました。
- **敵への格闘ヒット**：`_register_strike_hit()` の既存効果音 `sword_impact.wav` を新しい音へ差し替え。従来のピッチランダム化を取り除き、指定された音程のまま鳴らします。ヒットストップ、HP、火花は変更しません。
- **自機への敵攻撃ヒット**：`_on_enemy_projectile_hit()` に新音の再生処理を追加。直線弾、偏差弾、全方位衝撃波、円弧攻撃の既存の被弾シグナルで共通の音が鳴ります。Damageknockの最中に別の被弾シグナルが届いた場合も効果音のみ再生し、被弾モーション／ノックバックを再始動しません。
- 敵／自機を個別のAudioStreamPlayerに分け、同時のヒット音と連続攻撃の余韻が重なるように `max_polyphony` を4／3に設定しました。どちらも音量-5 dBです。
- 以前の `assets/sword_impact.wav` は削除せず残していますが、v93の被弾音再生には使用しません。

## 変更ファイル

- `scripts/main.gd` （音源接続・再生のみ）
- `project.godot` （版名のみ）
- `assets/metal_damage_hit.wav` （追加）
- `assets/metal_damage_hit_source.mp3` （追加）
- `README_v93_ja.md` （追加）
- `tools/v93_audio_self_check.py` （追加）
- `DEVELOPMENT.md` （変更履歴追記）

## 維持した機能

v92の敵攻撃4種、デバッグUI、通常移動・ブースト、左右・後方ステップ、被弾復帰、格闘3段コンボ、カメラ・演出・モーション・当たり判定を変更していません。

## 検証の範囲

音源・コード・v92差分・ZIP整合性の静的検査のみ。Godot・Android実機でのオーディオ再生は未検証です。
