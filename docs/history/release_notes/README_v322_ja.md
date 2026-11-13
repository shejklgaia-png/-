# SERA v322 — カタナソードエフェクトの編集データ取り込み

## 今回の提供ファイル
- 取得元: `models/storage/Katana.bbmodel`（ユーザーによる新規Blockbench編集データ）
- 正本: `models/core/Katana.bbmodel`
- 統合: `Melee_katana` と `Melee_katana2` のアニメーションデータを、既存名のクリップへ置換。キー時刻・値・ボーンUUIDを維持。非アニメーションのモデル・グループ・Pivot・UVは正本を維持。
- 新規Swordeffectトラック:
  - `Melee_katana`：0.33333秒に回転(-12.4539, 1.0809, 4.882)、位置(5.6, -17.3, -15)、スケール(4.05, 1, 3.56)
  - `Melee_katana2`：0秒に回転(0, 0, 75)、位置(1.7, -10.8, -10.2)、スケール(4.84, 1, 4.18)
- 既存の `scripts/sword_trail.gd`（v85のSwordeffectメソッド）をそのまま使用。Standardリグにある`Swordeffect`の同一UUIDへ新しいアニメーショントラックを適用し、不可視の板を移動基準にして、既存の切り抜きアーク・凸型3Dボリューム・粒子を再生します。新しい矩形板や重複したFXメソッドは作りません。
- Android用の`assets/sera_katana_data.gd`を正本から再生成。
- 統合完了後、現在の実行時参照・モデル一覧に含まれない受け渡し用コピーだけを削除。過去の検査用モデルは残します。

## 今後のモデル・モーション取り込み
- `AGENTS.md`に、ユーザーが指定した名称の新しいファイルを`strage/`、`models/strage/`、`models/storage/`で確認し、正本に組み込んでから安全に整理する手順を追記。
- 刀については、`Swordeffect`の位置・回転・スケールキーフレームを必ず検査し、`tools/sera_model_build.py`でAndroid埋込データまで一致させます。
- Python/Godotの新規回帰テストをCIに登録。実機Androidのエフェクト外観は別途確認が必要です。
