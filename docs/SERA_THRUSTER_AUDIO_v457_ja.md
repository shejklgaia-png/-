# SERA v457 — スラスター持続音01・加速音13-1

## 実装内容
- **BOOST**：継続中は音源01をループ再生。
- **STEP**：踏み出し直後に13-1をワンショット再生し、STEP全区間に01を継続再生。
- **MELEE追尾・接近・バッシュなど**：既存のスラスター加速発生タイミングで13-1を鳴らし、噴射継続中は01を維持。両方の音声が同時に鳴る。
- 音源01：元MP3の安定区間1.50〜6.60秒を使用し、200ms等電力クロスフェードで4.90秒OGGループを作成。
- 音源13-1：最初の0.95秒を使用し末尾170msを自然に減衰させたOGGワンショット。
- 01のフェードイン75ms、フェードアウト220ms。
- スラスター炎を停止時に即非表示にせず、**220msでシェーダー強度を0まで下げる**。
- `scripts/sera_thruster_audio.gd`, `scripts/main.gd`, `scripts/back_thruster_fx.gd`, `tools/sera_thruster_audio_runtime_check.gd` を変更。
- Godotのトリガー信号は既存の`exhaust_on`と`acceleration_burst`を利用。移動・回避・攻撃の時間・当たり判定は変更しない。

## 音声アセット登録待ち

このPRには、音声のデコード済みOGGバイナリ2点がまだ含まれていません。生成済みファイルは会話のZIPに同梱しています。

| リポジトリ内の配置 | SHA256 |
|---|---|
| `assets/sera_thruster_01_loop.ogg` | `175a71e43e79ce2925703bf3103ae05279aea0896e964e0cc87f8a161060db44` |
| `assets/sera_thruster_13_1_acceleration.ogg` | `cfb815665d324ab2da7a4b1ddb3c7d3d0241e3e749a531ad8527bc2c90f7e2bf` |

**この2ファイルがGitHubに追加され、Godotの音声再生テストと既存CIが通るまではマージしません。** 書式やコンパイルエラーがないこともこの段階では未検証です。

### 利用規約

13-1は音源メタデータ上の制作者がOtoLogicです。利用時にはOtoLogicの規約に従ってゲーム内などにクレジットを表示してください。
