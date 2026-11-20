# SERA v527 — Android GodotエディターでLABO一覧が空白になる問題の修正

## 実機診断（v526）と原因の範囲
Android Godot 4.7.2 エディターから実行したときに、LABO装備製作は `created 0/7 | stage: starting craft`、素材変換・倉庫素材は `created 0/12 | stage: ... scrap_low icon`、全画面で `atlas: MISSING` を確認しました。APKでは表示できていました。

リストの描画範囲ではなく、**最初のアイコン取得がカードを追加する前に実行されている**ことが中断点でした。スクリーンショットだけではGDScriptの実エラーメッセージを確定できないため、インポートキャッシュが欠落・未生成であっても動作する対策を採用しました。

## v527修正
- `sera_item_icons.gd`: アトラス画像の `preload` を廃止し、通常のインポートテクスチャを遅延取得。Godot Android エディターで `ResourceLoader.exists` が偽でも、GitSyncで同期した `.webp` ソースファイルを `FileAccess` から直接読み、`Image.load_webp_from_buffer` で復号します。キャッシュはセッション内で共通化します。
- `base_facility_system.gd`: 装備7枠・素材12枠・倉庫12枠のネイティブButtonを、アイコン取得より前に作ります。アイコンは作成後にdeferredで適用。画像を取得できなくても文字・操作を保ち、四隅欠けの枠もカード生成後に適用します。タブの排他性、素材在庫・製作品・保存処理は変更しません。
- 診断欄に `icon source: imported / source-webp / unavailable` とソースWebPの存在を追加。従来の `atlas: MISSING` はインポート済リソースの有無のため、`source-webp` が表示されれば代替経路で読み込めています。

## 追加回帰テスト
- `v527_android_icon_resilience_self_check.py`: eager preload禁止、Raw WebPフォールバック、カード先行生成のコード経路を確認。
- `v527_android_icon_resilience_runtime_check.gd`: Raw WebP読み込み、意図的なアトラス不在状態でも装備7・素材12・倉庫12枠と欠け枠が残ることを確認。
- 既存のv511アトラス領域・UID・保存テスト、v522〜v524実描画とタブテスト、v526診断テストは削除・期待値緩和をしません。

## Android実機確認
GitSyncで最新mainへ同期後、Android GodotエディターでSERA v527を起動。LABOの装備製作・素材変換・倉庫を切り替え、各枠の文字・枠・アイコンを確認してください。診断欄の `created 7/7`、`created 12/12`、`icon source` も確認できます。再インストールは不要です（APKは不要）。なおAndroidエディターの実機表示はGitHub ActionsのLinux Godot検査だけでは保証できません。

前バージョン：[v526](docs/history/release_notes/README_v526_ja.md)


## 追補：低負荷UI整理（同一バージョン）
- **LABOホーム**のOS・追加効果スロット研究メニューを開いているときは、装備製作タブの選択表示を解除します。実際に装備製作タブへ進むと製作7件を表示し、タブを選択状態にします。LABOホームへの「戻る」と研究項目は残しています。
- **診断機能**は普段はボタンごと非表示です。必要なときのみ、ウィンドウ上部の見出し（LABOなど）を**1.7秒以内に5回タップ**すると「診断」が現れます。もう一度5回タップすると診断欄ごと隠れます。追加のTimer/ScrollContainer、常駐ポーリングはありません。
- 現在の7・12・12カードは画面内に収まり、製作品個体は既存の9件ページ切替を使用しているため、常駐スクロールコンテナーは追加しません。将来カード行数が増えたときにだけ必要性を再判定します。
- 先行追加した`labo_lightweight_ui_self_check.py`と`labo_lightweight_ui_runtime_check.gd`でタブ排他・診断のデフォルト非表示/5タップ・カード維持を検査します。既存のv511/v517/v522〜v527のアイコン・保存・描画・画面遷移テストは維持します。
