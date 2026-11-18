# SERA v457 — スラスターの継続音01＋加速音13-1

- **ブースト中**：01を途切れずループ。
- **STEP**：開始時だけ13-1を追加、STEP終了まで01は鳴り続ける。
- **追尾・接近**：加速時に13-1、追尾中に01を持続。二層の音は重なって再生。
- **スラスター停止**：01と噴射炎は約220msで滑らかに消える。
- **音源加工**：01は波形を見て1.50–6.60秒の安定区間を切り出し、0.20秒のクロスフェードで4.90秒のループ。13-1は初動0.95秒を抽出して末尾をフェード。
- **技術**：`scripts/sera_thruster_audio.gd`が別々のAudioStreamPlayerで再生し、既存の`exhaust_on`と`acceleration_burst`を使用。移動・攻撃・EN消費／判定は変更なし。
- **テスト**：`tools/sera_thruster_audio_runtime_check.gd`で実Godot音源ロード、BOOST／STEP／追尾音とフェードアウトを確認。Android実機は未検証。

詳細は`docs/SERA_THRUSTER_AUDIO_v457_ja.md`。13-1はOtoLogicの音源です。公開時は公式のライセンスとクレジット表記を確認してください。
