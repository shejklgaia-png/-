# セラ v94 — 命中種類別の効果音（2026-11-06）

**基準版:** v93 `sera_portrait_godot_melee_v93_metal_damage_sound.zip`

## 割り当て

| イベント | 再生するファイル | 備考 |
|---|---|---|
| 自機が自機狙い弾・偏差射撃弾に被弾 | `assets/sera_bullet_hit_short.wav` | 直線弾2種のみ。ヒット時に再生 |
| 自機の格闘1段目が敵に命中 | `assets/sera_melee1_short.wav` | `strike_index = 0`, ダメージ12 |
| 自機の格闘2段目が敵に命中 | `assets/sera_melee1_short.wav` | `strike_index = 1`, ダメージ12 |
| 自機の格闘3段目が敵に命中 | `assets/sera_melee2_long.wav` | `strike_index = 2`, ダメージ26 |
| 自機が全方位衝撃波・円弧範囲攻撃に被弾 | `assets/metal_damage_hit.wav` | v93の金属音を維持（新しい弾音は使わない） |

音声は提供されたWAVの**バイト列をそのまま**同梱しています（48 kHz、16-bitステレオ）。再生音量は従来と同じ -5 dB、ピッチ変更やトリミングなし。格闘の段ごとに別のプレイヤーを使用し、音の余韻が重なれます。格闘が空振りした場合、音は再生されません。

## 変更の範囲

- `scripts/main.gd`：命中時の格闘段階による振り分け、敵の弾／範囲攻撃による振り分け、再生ノードの増設
- `scripts/enemy_shooter.gd`：従来の被弾シグナルに `is_bullet` を追加。各攻撃インスタンスの接続時に `true`（AIM/LEAD）／`false`（SHOCK/ARC）を束縛。デバッグUIの種類を切り替えても着弾済み／飛翔中の弾の種類は混同しません
- `assets/sera_bullet_hit_short.wav`、`assets/sera_melee1_short.wav`、`assets/sera_melee2_long.wav`：ユーザー提供音源を追加
- `project.godot`：v94版名
- `DEVELOPMENT.md`、`README_v94_ja.md`、`tools/v94_sfx_self_check.py`：履歴・検証

既存のヒット判定、ダメージ値（12/12/26）、攻撃モーション、ステップ、ブースト、被弾復帰、カメラ、UI、既存アセットは変更しません。以前の金属叩き音・ソースMP3も削除していません。

## 検証

静的コード確認、音声ファイル一致、版間差分照合、ZIP展開の整合性を検証。Godot／Android実機での動作・再生は未検証です。過去バージョン向け自己検査（`v93_audio_self_check.py` など）は過去の挙動を検査するためv94では内容が一致しない項目があります。v94の確認には `tools/v94_sfx_self_check.py` を使用してください。
