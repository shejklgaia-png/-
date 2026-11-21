# SERA 全素材3Dモデル（2026-11-21）

## 目的と正本
`scripts/sera_base_materials.gd` が4系統・3等級・12素材の**名称と保存IDの正本**です。既存のスプライト画像 `assets/ui/sera_pixel_material_atlas.webp` と `scripts/sera_item_icons.gd` を変更せず、独立した3D表現を `models/materials/` に追加しました。

| ID | 日本語名 | 造形の特徴 |
| --- | --- | --- |
| `scrap_low` | 汎用スクラップ | 混成した破断板・曲がった金具・旧配管 |
| `scrap_mid` | 応用スクラップ | 破損ギア・駆動リング・機械片 |
| `scrap_high` | 高度スクラップ | 円形ベアリング・曲面部品・精密ローター |
| `alloy_low` | 基礎金属複合材 | 不整形の複合材塊・鈍い金属介在層 |
| `alloy_mid` | 精密金属複合材 | 直線加工した積層インゴット・接合溝 |
| `alloy_high` | 高次金属複合材 | 曲面一体の高次複合材・薄い金属縁取り |
| `electronics_low` | 汎用電子部品 | 再利用基板・抵抗器・コンデンサー・配線 |
| `electronics_mid` | 精密電子部品 | 制御基板・中央IC・金属接点・精密配線 |
| `electronics_high` | 高度電子部品 | 高密度演算コア・環状ハウジング・端子群 |
| `organic_low` | 微弱有機素材 | 乾燥した種核・弱い成長繊維 |
| `organic_mid` | 活性有機素材 | 膨らみのある生体核・伸長した細い導管 |
| `organic_high` | 旺盛有機素材 | 複数の成長葉・発光導管・成熟した核 |

## 形式・利用
- 各 `<ID>.gltf` は **glTF 2.0／独立メッシュ／PBR材質／埋込バッファ**。外部画像を必要としません。Godot 4.7 GL Compatibility の標準glTFインポーターで3Dシーンとして取り込みます。
- 実寸は1モデルおよそ1〜2m以内、原点近傍を中心としたY-up。面の陰影、正面・側面・背面の立体感を持つローポリ造形です。ほぼ不透明で、高光沢・半透明の重い表現を避けます。
- 読込APIは `scripts/sera_material_models.gd` の `scene_for(id)` / `instantiate(id)` を利用してください。無効なIDではnullです。表示する時だけ読み込み、UI全件に大量の3D Viewportを常駐させません。
- 目視用の独立したギャラリー `scenes/material_models_gallery.tscn` をGodotエディターから開いて、全12件を俯瞰確認できます。実ゲームのUI・所持数・精製/分解・製作機構には未接続です。
- glTFはBlender等の一般的な3Dツールで編集可能。Blockbenchの既存骨格マスター `models/manifest.json` は**全く変更しません**。
- 元の素材ID・レアリティ・変換係数・セーブデータ・ドットアイコンは変更しません。

## 品質検証
- 登録済みPython検査: `tools/material_models_3d_self_check.py`。12件・一意の実メッシュ、バッファ・index整合性、材質、頂点位置、既存ID一致を検証。
- 登録済みGodot検査: `tools/material_models_3d_runtime_check.gd`。12件が実際に `PackedScene` へインポートされ、各メッシュ頂点を持つことを検証。
- メインブランチへのマージ後 `.github/workflows/sera-model-policy.yml` で全静的・Godot検査を実行します。**Android実機での見た目／照明／低解像度UIでの見え方は別途目視確認が必要**です。
