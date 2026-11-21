# SERA HTMLツールの配布・起動リンク規約
<!-- SERA_HTML_DELIVERY_V1 / 2026-11-21 -->

## 発生した不具合と禁止事項
- Androidで `https://raw.githubusercontent.com/.../*.html` を直接開くと、HTMLがWebページとして実行されず、`<!doctype html>` から始まるソースコードがそのまま表示される場合がある。Raw配信先のContent-Type/ブラウザの解釈に依存する。機種の故障やHTML破損と決めつけない。
- **GitHub Raw URLを「タップで起動できるアプリ/フォームの直リンク」として案内しない。** GitHubの `blob` リンクもコード閲覧用であり実行リンクではない。
- 未公開のGitHub Pages URLを推測して提示しない。HTMLを表示できることとJavaScript/WebGL/Godotまで稼働することを混同しない。

## 提示の優先順序
1. **確認済みのHTTPS配信URL**: 実際に公開・応答が確認でき、HTMLが `text/html` で表示され、フォームの入力・タブ・コピーが動くURLを提示する。スマートフォンでは縦表示とタッチ操作を確認する。起動未検証なら明記する。
2. **単体オフラインHTML**（Icon Studio、旧Equipment Intakeなど）: Pagesが未設定/未検証なら、モデル・テクスチャ・スクリプトを同梱した**完成済みの `.html` 実ファイルをChatGPTへ添付**し、ダウンロード後にChrome等でローカルファイルとして開く手順を示す。RawのURLだけで代替しない。ChatGPTのPage上でHTML可視化を使う場合も、埋め込みWebGL/ダウンロード/APIが動くとは限らないため実機未検証を明示する。
3. **GodotネイティブWeb版**（WASM/PCK/JS/HTMLの複数ファイル構成）: 一式を同一オリジンのHTTPSホストへ配置し、公開済みの `index.html` を案内する。Godotは単体HTMLや `file://`、Raw URLでは起動しない。GitHub Pages未有効の場合はActionsアーティファクトを配布できても**公開URLとしては扱わない**。Pages設定を行い、デプロイ後の動作を確認するまで「公開準備中」とする。
4. **検証できるHTML/ホストを提供できないとき**: 動くと断言したリンクを捏造せず、GitHubコード表示や原本へのリンクは「ソース」と明記し、必要なホスト設定/ファイル受け渡し方法を示す。

## ユーザーへ案内する最小確認項目
- 先頭にSERAのタイトル・操作UIが表示されること（`<html>`やCSS/JSのソースが全面表示されない）。
- 装備モデルが読み込まれ、タッチ回転・タブ切替・倍率入力・EXPORTコピーが機能すること。
- オフラインHTMLは旧WebGL簡易プレビューと明記。Godot正本と同じ描画と称しない。
- Web版ではGodotフレーム・WASM/PCKロード・画像撮影まで確認し、Android実機未確認は残課題とする。
- URLの実在や動作を検査できなかった場合、**確認できた範囲だけ**報告する。

## 管理対象
- `tools/icon_studio/dist/SERA_Icon_Studio_*.html`
- `tools/equipment_intake/dist/SERA_Equipment_Intake_*.html`
- `tools/equipment_intake/build_web_preview.py` と `.github/workflows/equipment-godot-web-preview.yml`
- 今後追加するSERAのHTMLツール、素材配置フォーム、プレビューツールも同規約を適用。

本規約はソースコードと配布物の区別を徹底するもので、ゲーム本体のプレイ仕様・Android出力・モデル原本を変更しない。
