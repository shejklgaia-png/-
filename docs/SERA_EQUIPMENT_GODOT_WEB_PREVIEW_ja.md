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
- **FULL BODY:** アイリス（制作モデルD）＋その他の各部位の基準モデルAが初期編成。全7部位の換装を選択でき、大きさ（A外接寸法基準、比率保持初期ON）を編集対象部位だけへ反映する。全身プレビューを表示するのはこのタブ。
- **ICON:** 選択対象部位だけを大きく3D表示し、撮影設定とPNGを書き出す。全身を混在させない。
- **STATS / FX:** 編集対象の単体プレビューを小型スナップショットで表示し、ステータスと自由記述特殊効果を同じタブで編集する。大型3Dビューは表示しない。
- **RECIPE:** 必要素材のみ。ANALYSISの比較画像は各装備部位単体を撮影し、EXPORTのデータ形式は従来の`SERA_EQUIPMENT_INTAKE_V1`を維持。
- 非表示のGodotビューはスナップショット撮影中だけ一時的に描画状態へ戻し、その後再び隠す。WebGL版は同じ部位分離と描画キューを使用するが、ネイティブ描画とは一致しない。

## 2026-11-21 制作用モデルIDと装備の関係
- A/B/C/D/Kは装備品を横断するセット名ではなく、部位ごとの3Dモデル原本を識別する**制作専用の呼び名**。ゲーム本体の製作・装着・所持は装備品UID単位。
- INFOから「装備セット」セレクターを廃止し、全身プレビューの部位別モデル選択が選ばれた製作モデル原本の唯一の選択元となる。
- 出力互換の`equipment.rig_set`は**選択した対象部位の制作用モデルID**（例：アイリス頭部はD）として保存する。装備セットやセットボーナスを表すものではない。プレビュー用`rig_selection`はスロット別のモデル参照マップにすぎない。

## 2026-11-21 全身プレビューの立ち姿勢
- **FULL BODY 3D**は、NEXUSのカスタマイズ画面と同じ`assets/sera_source.json`のユーザー制作アニメーション`NEXUS_pose`（互換名`NEXUSpose`）を0秒でサンプルする。従来の`Wait_motion`（戦闘待機・前屈姿勢）を全身プレビューに使用しない。
- ロード直後と部位換装後は、NEXUS同様`current_clip`、`clip_time`、`blending_for`、`blend_duration`を設定して`SeraRig._apply_animation(0.0)`を呼ぶ。既存の骨格、バード脚の統合トラック、UV、装備モデルはそのまま維持する。
- **ICON/単体ステータスの撮影**では従来の待機ポーズを保持し、BODY→ICON→BODYを切り替えても互いの姿勢が混ざらない。
- `NEXUS_pose`が将来原本から消えた場合だけ、NEXUSと同じbind姿勢＋腕角度のフォールバックを使う。ゲーム内NEXUS固有の脚と腕の接触解消調整は別処理であり、今回の共有対象は**原本の立ちポーズアニメーション**。オフライン簡易WebGL版はこの原本アニメーションを実行しないため、NEXUS立ちポーズ確認にはGodot Web版を使用する。

## 2026-11-21 新規チャット引継ぎ・分布図・安定した2本指・背景
- EXPORTには`handoff.format=SERA_EQUIPMENT_CHAT_HANDOFF_V1`とリポジトリ、原本SHA、実装ガイド`docs/SERA_EQUIPMENT_CROSS_CHAT_HANDOFF_ja.md`への参照を追加する。これにより新規チャットがGitHubの正本から同じ装備を実装できる。
- ANALYSISの分布図は横軸X（右ほど大）と縦軸Y（上ほど大）を正方形のプロット枠の下と左に表示。各軸プルダウンの隣にも同じ説明を置く。単なる画面左上の「X:」「Y:」は避ける。
- `godot_preview.gd`の2本指は2接点の中点と2点距離を前フレームと比較して更新する。指の追加・解除時は基準位置を再設定し、その瞬間にはカメラ操作を発生させない。低距離・異常な大移動・急激なピンチ比率は制限する。旧オフラインWebGLのPointerEventsも同方針。
- 単体プレビューの背景は`scripts/sera_icon_background.gd`と共通の**#111e28単色背景に#55798A（36%）の8分割格子**。全身のNEXUSポーズは変更しない。LABO/倉庫/NEXUSの装備アイコンには1個体1回の画像レンダリングでなく**1設計図に1枚の2D合成済みアイコンをキャッシュ**する。
- LABO装備製作確認は実SeraRigと同じ単体プレビューを使い、指ドラッグで回転。ボタンのタップ・製作と別入力。メニューを閉じたら3D描画を停止する。背景・操作はフォームと一致させる。
