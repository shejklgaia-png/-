# SERA v505 — NEXUSを上部中央・LABOを中央・資源設備を周辺へ配置

## 今回の変更
- NEXUSを**俯瞰拠点の画面上部中央**へ移動。従来の建物をタップするとNEXUSメニューへ入る仕様・出撃・アセンブル・トレーニング・データ・設定は維持。
- LABOを**画面中央**へ移動。Shell開発、OS開発、追加効果スロット研究を統合した建物として残す。
- 回収機・精製炉・リサイクラー・発電機・保管庫は中央LABOの左右に、建設端末を下部中央に配置。施設の3D外観・タップメニュー・周辺のグリッド床は変更しない。
- 中央建物への衝突を避けるため、クレートはLABOの外周を巡回する9点経路に変更。画面の中央を歩行する際に建物の内部へ入らない。
- 資源・研究の確定していない消費/獲得/レシピは新設せず、従来の表示・案内UIを維持する。

## CI先行対応
- 既存`tools/sera_ci_manifest.txt`、`tools/base_facilities_runtime_check.gd`、`tools/base_exploration_runtime_check.gd`、NEXUS往復テスト、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`AGENTS.md`、`.github/workflows/sera-model-policy.yml`を事前確認。
- 本体変更前に`tools/base_facilities_runtime_check.gd`へ画面投影に基づくNEXUS上部中央・LABO中央・資源設備の周辺分布チェック、NEXUSとLABOのタップ範囲非干渉、クレートの巡回全区間の障害物検証を追加。
- 既存テストの施設表示・タップ可能範囲・相互距離・ラベル表示、床の全画面表示、セラ/コントローラ非表示、NEXUS画面遷移は維持する。
- main統合後に全Python/Godot CIで検証。Android実機で最終的な見た目・タップ感を別途確認。

前バージョン：[v504](docs/history/release_notes/README_v504_ja.md)
