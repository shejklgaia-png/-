# SERA v509 — 素材選択を独立ページへ・戻る操作を全メニューで統一

## 変換設備の操作
- **精製装置／分解装置**：従来の素材系統`OptionButton`プルダウンを削除。
- 設備タップ → **素材系統の一覧ページ**（スクラップ／合金／電子部品／有機素材、それぞれ大きな行ボタン）→ **選んだ素材の変換専用ページ**（ランク別レシピ、所持数、回数、実行）の2段階で操作。
- 戻る操作は原則一段階のみ。変換画面→素材一覧→拠点画面。ほかの設備は詳細ページ→設備のメニュー→拠点画面。
- 12素材の固定必要品質・数量、既存の暫定2:1精製/1:2分解、セーブ保存は変更しない。
- 戻る印は視覚的な案内として表示。メニュー下部の「戻る」、メニュー外タップ、Androidの戻るジェスチャーのいずれでも前画面へ戻れる。縦画面で4系統を押しやすいようアクション領域を縦スクロール可能にした。

## NEXUSの戻る
- NEXUSで端末の専用メニューを開いた際は、その**メニューの外側をタップすると概要画面へ戻る**。
- NEXUSの概要画面で端末のない場所をタップするかAndroid戻る操作を行うと、拠点へ帰還する。
- 既存の戻る印、`EXIT TO BASE`ボタンの直接退出とアセンブル/トレーニング/出撃/システム/アーカイブは保持。
- SYSTEMの保存/削除の確認が進行中は、戻る操作で確認のみ取り消して誤確定を防止。
- NEXUS/拠点に`Window.go_back_requested`を接続。Godot 4ではAndroidの戻る操作でアプリが終了するのが標準なので`application/config/quit_on_go_back=false`を設定し、ゲーム内の画面遷移として処理。

## 先行CIと安全性
- 既存`tools/sera_ci_manifest.txt`、`tools/base_material_conversion_runtime_check.gd`、`tools/base_facilities_runtime_check.gd`、`tools/base_nexus_navigation_runtime_check.gd`、NEXUS実装、SERA_ACTIVE_CI_POLICYとAGENTSを作業前に調査。
- **実装に先立ち**、`tools/base_page_navigation_runtime_check.gd`と`tools/base_page_navigation_self_check.py`を作成し、マニフェストへ登録。プルダウンなし、素材一覧4項目、変換への遷移、メニュー外タップ、Android Window信号、物理KEY_BACK、NEXUS概要と拠点への復帰を検査。
- 既存の12素材・資源収支・セーブ・設備の配置・NEXUS画面遷移・CRATE・戦闘/モデルの既存テストは維持。全CIはmainへのマージ後に実行し、Android実機のジェスチャー入力・外側タップ判定・画面サイズは別途確認。

前バージョン：[v508](docs/history/release_notes/README_v508_ja.md)
