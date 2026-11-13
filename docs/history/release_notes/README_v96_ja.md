# セラ v96 — 自機の弾被弾音を差し替え（2026-11-06）

**基準版：** v95 `sera_portrait_godot_melee_v95_unified_melee_hit_sfx.zip`

## 効果音の割り当て

| 発生条件 | 再生ファイル |
|---|---|
| 自機が敵の自機狙い弾（AIM）に被弾 | `assets/sera_player_bullet_hit_v96.wav`（新規） |
| 自機が敵の偏差射撃弾（LEAD）に被弾 | `assets/sera_player_bullet_hit_v96.wav`（新規） |
| 自機が全方位衝撃波（SHOCK）に被弾 | `assets/metal_damage_hit.wav`（維持） |
| 自機が円弧型範囲攻撃（ARC）に被弾 | `assets/metal_damage_hit.wav`（維持） |
| 自機の格闘1・2・3段目が敵に命中 | `assets/sera_melee_hit_all.wav`（維持） |

ユーザー提供の「ロボットを殴る3.mp3」を `assets/sera_player_bullet_hit_v96_source.mp3` として原本保存し、Godotで使用する `assets/sera_player_bullet_hit_v96.wav` に変換。音程、音量、長さ、エフェクトの編集は行わず、48kHz／16bit PCM／ステレオ形式にデコードしています。実効再生時間は約1.02秒です。

**再生音量：** 既存の-5dBを維持。**多重再生：** 最大3声を維持。

## 変更したもの

- `scripts/main.gd`：`PlayerBulletHitSound` のAudioStream差し替え1行のみ。
- `project.godot`：バージョン表示名のみ更新。
- `assets/sera_player_bullet_hit_v96.wav` と `assets/sera_player_bullet_hit_v96_source.mp3` を追加。
- `DEVELOPMENT.md` と本ドキュメント、`tools/v96_player_bullet_sfx_self_check.py` を更新／追加。

旧 `assets/sera_bullet_hit_short.wav` は履歴として保管し、使用はしません。敵AI、実際の弾・範囲攻撃の当たり判定、3段格闘、ダメージ数値、モーション、カメラ、ステップ、ブーストの既存仕様は変更しません。

## 検証

静的な音声経路、命中判定、差分・音源・ZIPの整合性は検査しています。Godot本体／Android端末での実動作・再生は未検証です。
