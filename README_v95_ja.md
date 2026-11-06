# セラ v95 — 格闘3段の命中音を統一（2026-11-06）

**基準版：** v94 `sera_portrait_godot_melee_v94_hit_sounds_by_attack.zip`

## 効果音の割り当て

| 条件 | 音源 | 備考 |
|---|---|---|
| 格闘1段目が敵に命中 | `assets/sera_melee_hit_all.wav` | 12ダメージ |
| 格闘2段目が敵に命中 | `assets/sera_melee_hit_all.wav` | 12ダメージ |
| 格闘3段目が敵に命中 | `assets/sera_melee_hit_all.wav` | 26ダメージ |
| 自機がAIM/LEAD弾に被弾 | `assets/sera_bullet_hit_short.wav` | v94から変更なし |
| 自機がSHOCK/ARCに被弾 | `assets/metal_damage_hit.wav` | v94から変更なし |

ユーザー提供の `ロボットを強く殴る2.mp3` を `assets/sera_melee_hit_all_source.mp3` として保持し、48kHz／ステレオ／PCM 16bitの `assets/sera_melee_hit_all.wav` へ変換して使用します。元の音声にトリミング、音程調整、音量補正、エフェクトは追加していません（MP3デコードおよび16bitへの量子化のみ）。ゲーム側再生音量は従来どおり **-5dB** です。

## 実装範囲

- `scripts/main.gd`：格闘1・2段目と3段目の再生ストリームを同一WAVに変更。`strike_index` による再生ノード選択、命中チェック、同時再生、既存の判定は保持。
- `project.godot`：版名のみ更新。
- `assets/sera_melee_hit_all.wav`、`assets/sera_melee_hit_all_source.mp3` を追加。
- `README_v95_ja.md`、`DEVELOPMENT.md`、`tools/v95_melee_sfx_self_check.py`：記録と検証。

過去音源 `assets/sera_melee1_short.wav`、`assets/sera_melee2_long.wav` は互換性・履歴のため残しますが、v95の格闘ヒットでは使用しません。

## 検証

コード・音声形式・前バージョンとのファイル差分・ZIP整合性を静的に検査。Godot本体／Android実機の再生・動作は未検証です。
