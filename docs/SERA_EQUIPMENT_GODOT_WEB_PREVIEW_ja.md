# SERA 装備設定フォーム — Godotネイティブプレビュー

## 公開URLとHTMLの受け渡し（2026-11-21）
- **配布ポリシー正本:** `docs/SERA_HTML_ARTIFACT_DELIVERY_POLICY_ja.md`。GitHub `raw.githubusercontent.com` のHTMLはAndroidでソース表示になる場合があるため、実行URLとして案内しない。GitHub `blob` URLもコード閲覧用。
- Pagesの公開設定・デプロイ・実URLを確認した後にのみ「タップで開く」URLとして提示する。未有効の場合はGodot版のActionsアーティファクトと、旧版の単体オフラインHTMLを明確に分けて案内する。埋め込みPage表示についても実機未確認の場合は断言しない。

## 現行ルール

- **描画エンジン**はGodot 4.7.2 / GL Compatibility（WebではWebGL 2.0）。装備プレビューの画素をJavaScriptで擬似生成しない。
- **正本**は `scripts/sera_rig.gd`（`SeraRig`）、`scripts/sera_equipment.gd`、`scripts/sera_view_edges.gd`、既存マテリアル・テクスチャ・シェーダー。ステージライトは `scripts/main.gd:_build_world()` および `tools/icon_studio/sera_godot_native_capture.gd` と同じ数値。
- フォームUIの上部タブ・素材/ステータス入力・星型レーダー・分布図は軽量HTMLのまま。3DだけGodot WebAssemblyシーンに移す。
- カスタマイズ時は標準Aを基に各部位の装着を`SeraEquipment.select_part(..., false)`で実行。片手/両手武器占有・HEAD C/D・鳥脚C/下半身Dも本体処理に任せる。
- 新規モデルの寸法変更は選択部位のGodot内の実メッシュを、A部位AABBへ合わせた後に倍率変更。輪郭線とパーツ境界は実3Dの幾何を反映。
- 回転：1本指。移動＋拡縮：2本指（Godotの`InputEventScreenTouch`/`ScreenDrag`で処理）。PCは左ドラッグ、ホイール。
- Godot内の画像からPNGを撮影し、HTMLにbase64経由で渡す。設定テキストの`render.engine`はGodotへ更新。
- HTMLとGodotは同一オリジンの`postMessage`で連携する。JSONメッセージは名前空間`SERA_EQUIPMENT_GODOT_V1`とシーケンス番号で識別し、スクリーンショットはレンダリング完了後に取得。
- **パッケージ**：`tools/equipment_intake/build_web_preview.py`で本体から必要なスクリプト、実装済みモデル、マテリアル、シェーダーを抽出した一時Godotプロジェクトを生成。Webエクスポート結果は同じサイトの`preview/`へ置く。Android版の本体の`project.godot`は変更しない。
- **配布**：`.github/workflows/equipment-godot-web-preview.yml`がGodot 4.7.2のNo-Threads Web出力を作成し、`SERA-Godot-Equipment-Preview-Web`をActionsアーティファクトとして公開する。HTTPSサーバーが必要（`file://`でWASMを開かない）。GitHub Pagesが未設定の場合、Web出力だけを成功させ、Pagesデプロイを安全にスキップする。所有者がSettings → Pages → Build and deployment → SourceをGitHub Actionsに設定した後、Actionsからこのワークフローを再実行すると公開できる。Pagesの有無はGitHub APIで事前確認する。
- **正確さ**：モデル・UV・マテリアル・輪郭線・照明値を共有。WebGL2とAndroid GL CompatibilityはGPU/ブラウザ・ピクセル比やAA等で完全な1ピクセル一致を保証できない。最終公開PNGはAndroid/Godotネイティブ撮影との実機比較を基準にする。
- **特殊効果**は文章のままChatGPTへ引き継ぐ。新分類値の自動登録は禁止。素材とステータスを正本に追加する工程は従来どおり確認・実装・回帰検証を必要とする。

## 動かし方

```bash
python3 tools/equipment_intake/build_web_preview.py \
  --stage /tmp/sera-intake-web --site /tmp/sera-intake-site
godot --headless --editor --path /tmp/sera-intake-web --import --quit
godot --headless --path /tmp/sera-intake-web \
  --export-release "SERA Equipment Web" /tmp/sera-intake-site/preview/preview.html
python3 -m http.server --directory /tmp/sera-intake-site 8080
```

localhostのブラウザで`http://127.0.0.1:8080/`を開く。スマートフォンから開く場合はHTTPSホストを使用。

## 既存のIcon Studioとの差

従来の`tools/equipment_intake/dist/SERA_Equipment_Intake_IRIS.html`はモデル原本を同梱した**旧WebGL版のデータ入力フォーム**で、表示再現性の正本ではない。新しい`index.html`はGodot WASM・PCK・JavaScript・HTMLを含む**複数ファイル構成**である。単体HTMLだけを保存しても3Dは起動しない。

## 2026-11-21 タブ別の3D表示と編集範囲
- **INFO:** 設計図ID・名称・対象部位などの基本情報のみ。大きさ・特殊効果は移動。
- **FULL BODY:** アイリスHEAD D＋その他の部位Aセットが初期編成。全7部位の換装を選択でき、大きさ（A外接寸法基準、比率保持初期ON）を編集対象部位だけへ反映する。全身プレビューを表示するのはこのタブ。
- **ICON:** 選択対象部位だけを大きく3D表示し、撮影設定とPNGを書き出す。全身を混在させない。
- **STATS / FX:** 編集対象の単体プレビューを小型スナップショットで表示し、ステータスと自由記述特殊効果を同じタブで編集する。大型3Dビューは表示しない。
- **RECIPE:** 必要素材のみ。ANALYSISの比較画像は各装備部位単体を撮影し、EXPORTのデータ形式は従来の`SERA_EQUIPMENT_INTAKE_V1`を維持。
- 非表示のGodotビューはスナップショット撮影中だけ一時的に描画状態へ戻し、その後再び隠す。WebGL版は同じ部位分離と描画キューを使用するが、ネイティブ描画とは一致しない。
