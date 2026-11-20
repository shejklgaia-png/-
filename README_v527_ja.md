# SERA v527 — Android GodotエディターでLABO一覧が空白になる問題の修正

## 実機診断（v526）と原因の範囲
Android Godot 4.7.2 エディターから実行したときに、LABO装備製作は `created 0/7 | stage: starting craft`、素材変換・倉庫素材は `created 0/12 | stage: ... scrap_low icon`、全画面で `atlas: MISSING` を確認しました。APKでは表示できていました。

リストの描画範囲ではなく、**最初のアイコン取得がカードを追加する前に実行されている**ことが中断点でした。スクリーンショットだけではGDScriptの実エラーメッセージを確定できないため、インポートキャッシュが欠落・未生成であっても動作する対策を採用しました。

## v527修正
- `sera_item_icons.gd`: アトラス画像の `preload` を廃止し、通常のインポートテクスチャを遅延取得。Godot Android エディターで `ResourceLoader.exists` が偽でも、GitSyncで同期した `.webp` ソースファイルを `FileAccess` から直接読み、`Image.load_webp_from_buffer` で復号します。キャッシュはセッション内で共通化します。
- `base_facility_system.gd`: 装備7枠・素材12枠・倉庫12枠のネイティブButtonを、アイコン取得より前に作ります。アイコンは作成後にdeferredで適用。画像を取得できなくても文字・欠けた四隅の枠・操作を保ちます。タブの排他性、素材在庫・製作品・保存処理は変更しません。
- 診断欄に `icon source: imported / source-webp / unavailable` とソースWebPの存在を追加。従来の `atlas: MISSING` はインポート済リソースの有無のため、`source-webp` が表示されれば代替経路で読み込めています。

## 追加回帰テスト
- `v527_android_icon_resilience_self_check.py`: eager preload禁止、Raw WebPフォールバック、カード先行生成のコード経路を確認。
- `v527_android_icon_resilience_runtime_check.gd`: Raw WebP読み込み、意図的なアトラス不在状態でも装備7・素材12・倉庫12枠と欠け枠が残ることを確認。
- 既存のv511アトラス領域・UID・保存テスト、v522〜v524実描画とタブテスト、v526診断テストは削除・期待値緩和をしません。

## Android実機確認
GitSyncで最新mainへ同期後、Android GodotエディターでSERA v527を起動。LABOの装備製作・素材変換・倉庫を切り替え、各枠の文字・枠・アイコンを確認してください。診断欄の `created 7/7`、`created 12/12`、`icon source` も確認できます。再インストールは不要です（APKは不要）。なおAndroidエディターの実機表示はGitHub ActionsのLinux Godot検査だけでは保証できません。

前バージョン：[v526](docs/history/release_notes/README_v526_ja.md)
