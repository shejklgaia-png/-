## 2026-11-24 — クレート3Dモデルを設定画に従ってゼロから再構築
- ユーザー添付のSERA Companion Robot設定画を基準に、従来の直方体・球による簡易モデルを新しいポリゴンジオメトリへ全面置換。
- 八角面取り白色ヘルメット、黒紺横長バイザーとシアン一本ライン、左右同心円型耳サーボ、長い双角アンテナを新造。顔文字・絵文字なし。
- 胴体に台形フロント装甲、細いアンバー識別線、背面に工具／資源収納バッテリーを設置。両腕に円筒ジョイントと各3本の湾曲したC型爪を構築。
- 左右独立のクローラーはY-Z長円履帯、連続した独立トレッド、三連ホイール、同心ハブ、外側サービスカバーで生成。実メッシュの法線と面方向を定義。
- 6可動セクション内を材質ごとにArrayMeshへ統合して共有キャッシュ。Opaque PBR／Emissiveシアンを使用し、追加テクスチャ・CSG・毎フレームのメッシュ生成なし。
- BASE巡回とLABO全3景は scripts/sera_crate_model.gd を共用。HeadPivot・左右ArmPivot・Trackノード、前方-Z、character描画ロール、既存シーン・カメラを維持。
- 仕様書 docs/CRATE_3D_REFERENCE_REBUILD_20261124_ja.md を追加。画像生成禁止、CI項目やテストに触れず、実機表示とフレーム負荷は未確認。
## 2026-11-24 — NEXUS単体プレビューの正方形レイアウトと縮小表示
- 直前の全身／単体UI切り替えで、左側の単体SubViewportが全身表示用の縦長領域（画面高61.5%）へ伸張されていた。結果、モデルが過度に大きく映り、正方形を前提とする単体アイコン型プレビューの構図が崩れた。
- `command_nexus.gd` の単体モードに専用の正方形表示範囲を追加。左列の中央に配置し、全身用縦長プレビューおよび右側7部位の常設装備メニューは変更しない。
- `sera_part_preview_widget.gd` の通常単体プレビュー初期ズームを0.86へ下げ、枠内に余白を確保。回転・ピンチ拡縮・ダブルタップ全画面化・アイリス材質設定を維持する。
- 単体モード中は見えていない全身モデルの回転入力を開始しない。ステータス領域・装備選択・保存・カメラ視野角・全身プレビューは従来どおり。
- CI項目・テストファイル・設定を確認・修正せず、CI、Godot、Python、Android等のテストは実行していないため実機の見え方は未確認。

## 2026-11-24 — NEXUS全身プレビューの視野角を戦闘シーンと統一
- NEXUSカスタマイズ全身表示における正投影への切り替えを廃止し、戦闘と同じ透視投影を維持。奥行きに応じた遠近感が有効になる。
- 基準縦視野角61°を `scripts/sera_display_profile.gd` の `COMBAT_REFERENCE_VERTICAL_FOV` に集約。TRAINING・ビットタラン戦（いずれも `main.gd` のカメラを使用）とNEXUSの全身プレビューが共通の定数を参照する。
- 従来の `DisplayProfile.vertical_fov()` による縦長画面補正・NEXUSの全身モデル自動フィット・ドラッグ回転・装備リスト・単体プレビュー・入退場アニメーションを維持。単体プレビューのカメラ方式は変更しない。
- CI項目、テスト用ファイル、ワークフローにはアクセス・変更せず、CI、ローカル、Godot、Android等のテストを実行していないため実機描画は未確認。

## 2026-11-24 — NEXUSカスタマイズ画面を全身／単体の排他表示へ再構成
- 画面上部に「全身表示／単体表示」の大きな切り替えタブを常設。両モードのステータスは同じ上部領域を共有し、全身合計と選択部位の基礎性能・個体特性を同時表示しない。
- 左側プレビューは縦方向に拡大して全身モデル／単体モデルを排他表示。全身は既存NEXUSカメラとGPU輪郭を使用し、単体は既存の実装済み3Dプレビューおよびダブルタップ全画面化を継続。非表示側の単体SubViewport描画を停止する。
- 右の7部位装備メニューはモードによらず常時表示。装備名で部位選択、右端で既存のサムネイル装備選択画面を開き、選択・特性・保存・両手持ち制約はそのまま維持。
- 上段は必要時スクロールし、下段ステータス領域を撤去してタップ操作域を拡張。表示中の単体プレビューと全身モデルの非表示状態を切り替え、戻るときは展示用3Dモデルを必ず復帰させる。
- 指示に従ってCI項目・テスト資産・ワークフローには触れず、CI・Godot・Android・Python等のテストは実行していない。実機のレイアウト・操作感は未確認。

## 2026-11-23 — ビットタランGPU枠線の角接続とAA
- GPU線のスクエア端点延長を廃止し、共有面を持つ接続稜線のジョイントを生成時にキャッシュ。GPUで両稜線の可視条件を判定し、外側の欠落部をMiter/Bevelで接続。鋭角の黒い突起を制限。
- 線とジョイントの外側に最小限の解析エッジAA。輪郭内1px/外5px、開放境界外3px。既存カメラ・GPU深度・アニメーション追従を維持。追加描画パスなし（ただし三角形/頂点計算増）。
- 対象はビットタラン戦のみ。CI項目・テストファイル・テスト設定の確認/修正/適用、各種テスト実行はしていない。実機表示・負荷は未確認。

## 2026-11-23 — ビットタラン戦の角欠け（GPUリボン端点・判定不一致）修正準備

- 実機スクリーンショットで、ビットタランの装甲外周、細長いパーツの接合角に線欠落を確認。GPU輪郭の稜線が互いに端点で終了し、外側5pxの斜め接続を埋めない問題があった。
- `nexus_sera_gpu_convex_silhouette.gd` のビットタラン専用full GPU幾何へ、各稜線に共通のローカル中点(`CUSTOM1`)と端点符号(`UV.y`)を追加。従来のNEXUS凸角モードには不要な新規ドロー処理を追加しない。
- `sera_bittaran_gpu_contours.gdshader` は面の可視判定を線分中点に固定して、端での判定不一致を防止。さらに画面空間のスクエアキャップで接続端を最大5pxだけ重ね、角の三角ギャップを抑制。線幅内1px・外5px／開放境界外3px、凸角OFF、ボーン/カメラ振動への同一パス追従は維持。
- ビットタラン戦以外の描画を変更しない。CI項目・テストファイル・CI設定にはアクセスせず、CI・Godot・Android・Pythonの検査・テストを実行していないため端末表示は未確認。

## 2026-11-23 — ビットタラン戦のシルエット外側を5pxへ変更

- ビットタラン戦のセラ・装備・ビットタラン本体と砲塔について、GPU外側シルエットの設定を3pxから5pxへ変更（内側1px維持）。
- `sera_view_edges.gd` のビットタラン固有設定、`nexus_sera_gpu_convex_silhouette.gd` のフルGPUモード初期値、`sera_bittaran_gpu_contours.gdshader` のシェーダー初期値を5pxに揃えた。
- 分離メッシュの開放境界に設定された独立のseam幅3px、凸角OFF、深度判定、ボーン・カメラ振動への追従、他画面は変更なし。
- CI項目・テストファイル・ワークフローには触れず、CI、Godot、Android、Python等のテストを実行していないため実機表示は未確認。

## 2026-11-23 — ビットタラン戦のシルエットを画面内1px・外3pxへ変更

- ビットタランとプレイヤー（セラ・装備）に限定してGPU外周輪郭の非対称線幅を導入。内側1実画面px・外側3実画面px。開放メッシュ境界にも同じ内外幅を適用。
- `sera_bittaran_gpu_contours.gdshader` で隣接面の法線／稜線ベクトルからモデル面の内側方向を投影、GPUで内外2方向を選び、NDCの画素係数2で正確なオフセットを計算。カメラの移動／揺れ、モデルモーションでも輪郭は同じ投影行列で追従。
- `sera_view_edges.gd` と `nexus_sera_gpu_convex_silhouette.gd` のビットタラン用uniformを `silhouette_inside_px`/`silhouette_outside_px` へ整理。凸角OFF、別メッシュ境界・GPU深度テスト・FX・モデルを維持。
- 他の戦闘/NEXUS/BASE/CRATEの輪郭、保存・設定、CI/テスト項目には変更なし。CI・Godot・Androidのテストは実行せず、実機の内外線幅は未確認。

## 2026-11-23 — 敵・セラ・クレートの凸角描画を停止（外周・メッシュ境界のみ）

- 指示によりキャラクター3種（敵・SERA・CRATE）では同一メッシュの凸角線を描画しない。
- ビットタラン戦のGPU輪郭方式は外周・分離メッシュ輪郭を維持。シェーダーの両面が手前を向く凸角判定と2pxの凸角uniformを除去。カメラ振動や各ボーンとの直接追従、3pxの外周・分離メッシュ境界、GPU深度遮蔽は維持。
- GPU稜線生成器のビットタラン専用フルモードでは、凸性の事前計算と閉鎖メッシュのsigned volume計算を省略。NEXUS/icon診断向け旧凸角モードの幾何生成は互換保持し、実際のSERA描画へ自動適用しない。
- 通常戦闘の `SeraViewEdges` は凸角コントローラーを生成せず、可視IDによる外側輪郭・分離メッシュ境界だけを使用。NEXUSも従来の可視ID方式を維持。
- CRATEは既に可視ID輪郭のみ（`sera_crate_model.gd` にrole `crate`）なので変更なし。建築・施設・小物の凸角線は対象外。
- モデル、FX、攻撃AI、操作、設定ファイル、CI項目/ワークフロー/テスト用ファイルには変更なし。CI・Godot・Android・Python等のテストは実施していないため、実機表示は未確認。

## 2026-11-23 — ビットタラン戦の外周／分離メッシュ境界を完全GPU化

- ユーザー要望によりビットタラン戦のみ可視ID用Viewportと毎フレーム同期処理を外し、外周／独立装甲境界／凸角を3D GPU稜線リボンへ一本化。
- 本番の元メッシュに子として稜線を装着し、同じ投影行列・物理補間・カメラ振動 `h_offset/v_offset` を自動継承。描画負荷が必ず下がるかは未測定。
- 輪郭は外周3px／分離メッシュ境界3px／可視凸角2px。深度テスト有効で隠れた稜線は描かない。
- 既存の `SeraViewEdges` のビットタラン判定でIDパスを登録せず、NEXUSとBASEと普通の戦闘は変更しない。
- 同じメッシュの稜線データはキャッシュ、装備交換・破壊状態は約1.05秒ごとに確認。線をOFFにした際は非表示。
- 詳細：`docs/SERA_BITTARAN_GPU_ONLY_CONTOURS_20261123_ja.md`。CI項目・テストを実施せず、実機FPS／輪郭の完成度は未確認。

## 2026-11-23 — Repair asset-only equipment icon capture for current NEXUS

- Identified the previously failed automated 57-PNG generation (run 45160855480): `_screen_material` is deliberately null with the current NEXUS CanvasLayer contact compositor, so H01 failed before images could be published.
- Rewired the offline Godot capture to get the native `id_viewport` and `ink` TextureRect, make only the capture ink transparent, and use the ID pixels for final-resolution reconstruction. Convex ribbon remains a separate native render pass.
- Kept all gameplay/NEXUS shaders, model originals, 19 IDs and 3 output profiles unchanged. This is a production asset-generation repair only, without CI/test inspection, edits or execution.

## 2026-11-23 — Offline equipment PNG contour reconstruction

- Updated `tools/icon_studio/sera_all_native_capture.gd` to capture 19 authored SeraRig equipment models in three display profiles at 4× framebuffer resolution and perform final-pixel outlines after fitting (no post-ink Lanczos resize).
- Added `tools/icon_studio/sera_pixel_outline_reconstruction.gd`: depth-resolved RGB ID majority reduction, discrete alpha mask, integer-pixel exterior/interior/seam strokes, camera-visible convex ink from native render difference.
- Preserved approved H02 camera, authored model materials and poses, 512/82/96 output profile paths and runtime 2D caches. Capture metadata describes the new offline process.
- Source change only. The native 57-image capture and image-manifest hashes require a real graphics-enabled Godot production render; this environment cannot perform that render. No CI or tests were read, changed or run.

## 2026-11-23 — NEXUSカスタマイズ全身・単体の消えた枠線をCanvas可視ID合成へ修正

- ユーザー画像ではNEXUS全身SERAと頭部単体の外周・接触輪郭が表示されていない。どちらも深度付きID描画は構築していたが、最終合成が透明3Dスクリーンクアッドだったため、GL Compatibility環境で最前面へ出ない恐れがある。
- NEXUSは同じ可視RGB接触IDテクスチャ・同じ1px内側/2px外側/2px接触のシェーダーを既存CanvasLayer 1へ合成するよう変更。建築のネイティブ2px線はそのまま。
- NEXUS単体パーツ表示の共有可視IDも、専用SubViewport内だけCanvas合成へ変更。3D共有インクからCanvas向けに同一計算式のシェーダー `shaders/sera_scene_visible_ink_canvas.gdshader` を分離。アイリスDの専用6-ID描画と素材編集機能は変更しない。
- ほかの画面の戦闘・BASE・CRATEは従来の3D空間合成を維持。IDレンダリング、光源、選択領域、スクリーン座標、入力・操作は変更しない。
- CI項目・テストコード・CI設定の確認・変更、Godot/Android/Pythonの検査・テストは実施していないため、実機での線の復旧は未確認。

## 2026-11-23 — NEXUSのHUD全消失に対する表示経路の復旧

- ユーザー実機画像で3Dは表示される一方、EXIT TO BASE、バージョン、メニュー、COMMAND NEXUS装飾が一括して消える症状を確認。
- 直近で追加した`NexusReferenceFrame`の生成を実行用NEXUS HUDから切り離し、最後に表示できていたCanvasLayer→Controlのシンプルな階層に戻した。3Dモデルやゲーム機能は変更していない。装飾用スクリプトは履歴として残すが、本番HUDは参照しない。
- CanvasLayerの直下に置くHUD ControlへViewportの表示サイズを明示して、0×0の表示領域でボタンが描かれない状況を防ぐ。
- EXIT TO BASEとバージョン表示を他のメニュー初期化より先に生成し、部分的なランタイムエラーでも最低限のナビゲーションが残る構成へ変更。
- HUDレイアウト処理は基本退出ボタンの位置決定を先に行う。既存のフォーカス／パーツ／トレーニング／出撃等のメニュー本体は既存の処理を維持。
- CI項目・テストコード・ワークフローは参照も変更もしない。Godot/Androidの実機操作確認および自動テストは実施しておらず、原因の最終的な確定と復旧効果は未確認。

## 2026-11-23 — NEXUS再構築後のタップ・メニュー復旧（装飾UI分離／遷移停止防止）

- PR #859で追加した画面全面の装飾フレーム `NexusReferenceFrame` を `Control` から `Node2D` に変更し、入力操作のUI階層から分離。描画は同じCanvasLayer上で実行、飾りはGUIヒットテストへ参加しない。
- 既存の `_input` はrawタッチ処理を維持。EXIT TO BASEを遷移ロックより先に処理し、復帰操作を常時可能にする。
- 本来0.18秒のカメラTweenが中断されて `in_transition` が戻らない場合、1.35秒で状態を復帰し、SYSTEM／TRAINING／DATA ARCHIVE／DEPLOYMENT／CUSTOMIZEのメニュー操作が永久停止しないようにする。
- NEXUSモデルの構図・SERA展示リグ・保存・輪郭線シェーダー・全入力ルーティング仕様は原則変更せず、今回の入力保全に限定。
- CI項目・テスト・CI設定は調査・修正せず、Godot・Android・Pythonのテストも実行していないため、実機での操作復旧は未確認。

## 2026-11-23 — 参照画像からNEXUS室内8モジュールを完全再構築

- 参考画像の縦型レイアウトを基に、室内・床・天井・中央柱・整備台とリング・階段・アーカイブ・ゲート・非対称2端末を新しいBlockbenchキューブとUUIDで再設計。
- 大量の反復小部品を置かず、538個の用途を持つ部品と厚みのある装甲・凹部・照明で工業的な密度を表現。7モジュール＋SYSTEM/TRAININGの合計8アクティブモデル。
- 新しいカメラとゲート／左奥設備／端末の設置座標を同時更新し、上下の穴を作らない一体屋根・壁・連続床と、中央柱と右奥ゲートの離隔を重視。
- HUD上下に低負荷な装飾フレームを追加。SERA本体、既存メニュー、選択判定、シェーダー、セーブは保持。
- 詳細：`docs/SERA_NEXUS_REFERENCE_COMPOSITION_REBUILD_20261123_ja.md`。
- CI項目・テストコード・CIワークフローは参照や修正をせず、Godot／Android等のテスト実行も禁止方針により未実施。実機表示・FPSは未確認。

## 2026-11-23 — NEXUS 上下の無駄な空白・過剰反復部品を整理

- 実機画像の上部の明るい抜け、下部の暗い余白、左右端末の切れ、過剰な側壁・床の反復を改修。
- Blockbench 8モジュールの原本とランタイム定義から細かい反復を削減し、主要形状は保持。背面ボールト・前景の延長床・天井の支持材だけ最低限追加。
- NEXUS環境背景は暗色とし、装備プレビュー専用の明るい背景設定は維持。
- SYSTEMは0.85倍、TRAININGは0.82倍で中央側・奥へ移動。端末別の設計は維持し、焦点カメラも同期。NEXUS全体カメラはやや下向きに調整。
- 詳細：`docs/SERA_NEXUS_LEAN_LAYOUT_20261123_ja.md`。CI・テスト項目は変更せず、テストは実施していないため実機見え方・負荷は未確認。

## 2026-11-23 — BASEの施設シルエット内側線幅を0pxに統一

- 可視ID描画シェーダーの拠点施設（role 2）に対して、内側シルエット線幅を1pxから0pxに変更。小物・電源装置・電源コード（role 3）の0px設定は維持。
- 外側輪郭（施設3px／小物・電源設備1px）、接触境界（施設2px／小物・電源設備1px）、凸角、キャラクター、CRATE、装備プレビューには変更なし。
- CIの項目変更およびテストは行わず、Android実機での表示は未確認。

## 2026-11-23 — NEXUS 再再構築：配置干渉を解消する奥行き設計／非対称端末

- スクリーンショットの反省を受け、室内・全設備を新規造形。小型ブランド柱、右奥へ退いたゲート、前景で高さも用途も異なる2つの端末とした。
- ゲート（5.35,0.02,-17.0）／小型中央柱（幅1.64m）を独立配置し、背面壁をさらに後退。SYSTEM端末とTRAINING端末は旧kiosk共通反転を廃止し別モデル化。
- 室内カメラ、タップ対象の対応、各機能のフォーカス視点、ロゴ位置を新配置へ更新。ゲーム機能・セラ・輪郭シェーダー・保存仕様は維持。
- 詳細：`docs/SERA_NEXUS_CLEARANCE_ASYMMETRY_REBUILD_20261123_ja.md`。CI／Godot／Android含めテストは実行しておらず最終映像・性能は未確認。

## 2026-11-23 — NEXUS 参照画像から7モデルを完全再構築（SERA_NEXUS_REBUILD_V2）

- 前回の「既存へ355パーツ追加」方針を破棄し、Blockbench7モデルの全要素をゼロから再制作。参照画像の前景2端末・中央展示台・上部整備リング・左右奥の設備・背景タワー／天井と床のレイヤー構成へ変更。
- 最も大きい変更は上部整備リングをセラの実展示位置へ移動したこと。中央塔と横のアーカイブ・ゲートを明確に分離した。
- 長細い発光スリットや小パーツは輪郭処理から除外。各パーツに本体輪郭と選択用ヒットのフラグを付与し、従来の色別MultiMesh方式を維持。
- 詳細：`docs/SERA_NEXUS_TOTAL_REBUILD_20261123_ja.md`。CI・テストは一切実施せず。実機の視覚品質と性能は未確認。

## 2026-11-23 — BASE小物の密度増加と箱入りスクラップ追加
- 8施設の屋外小物に、四辺を持つ開放式金属箱と、内部の装甲片・配管片などの立体スクラップを追加。物体単位で決定的な形状・数・向きの変化を付与し、既存のマテリアル別MultiMeshバッチに追加する（別MeshInstanceノードなし）。
- 各施設に最大3個の箱入りスクラップ、一次小物ごとに最大2個の小型サテライト小物を配置。既存の主要小物群・建物・入口・盤面境界を保護し、実yawと未回転の両方の保守的占有矩形で衝突候補を除外。空き場所がなければ無理に配置しない。
- 電源装置の位置決定とケーブル経路生成は既存の「全小物をワールド座標の障害物として登録する」AStar経路探索を維持。新しい箱とサテライトも同じ障害物登録に含め、電源装置・ケーブルが小物を横切らないようにする。
- 小物再配置プレビューは元の一次小物だけを再配置し、追加の箱・サテライトを再パッキングする方式に修正。小物数が増えた後も「要素数の半分が一次小物」という旧前提に依存しない。
- CI項目・ファイルの確認／変更や各種テストは実施せず、Godot/Androidでの見た目・動作は未確認。

## 2026-11-23 — NEXUS室内の参照画像に合わせたBlockbench 7モジュール立体ブラッシュアップ

- ご提供のSERA COMMAND NEXUS縦長イメージを基準に、天井、床、側壁、中央タワー、整備リング、展開ゲート、操作端末、データバンク、階段を追加造形。
- 既存7ファイルのBlockbench原本を更新し、実行用 `assets/base_command_modules.gd` と同期。増加したキューブは既存のマテリアル別MultiMeshへ統合し、余分な描画パス／画像背景／新規FXは使わない。
- モデルの設置座標・選択の機能・既存照明／輪郭線・SERA展示モデル・画面UI・Android縦画面を変更しない。
- 詳細：`docs/SERA_NEXUS_REFERENCE_VISUAL_POLISH_20261123_ja.md`。規定に従いCI項目・テスト関連ファイルは変更せず、CIや実行テストを行っていないため最終的な実機表示と負荷は未確認。

## 2026-11-23 — 全19装備PNG：現行NEXUS可視メッシュID撮影へ移行

- 装備の実モデル・材質・NEXUS_pose・H02共通カメラプリセット（512px透過）を維持したまま、オフライン一括撮影の輪郭描画を現行NEXUSの可視メッシュID／深度接合線へ切替。
- アイリス単体のGodot撮影処理も同方式へ統一。
- 制作用ワンコマンド `tools/icon_studio/recapture_all_icons.py` を追加。撮影後にPNGメタデータと19件のmanifest SHAを更新する本番用ツールを整備し、テストコードへの依存を解消。
- LAB・倉庫・NEXUSは既存 `sera_item_icons.gd` の設計図単位PNG読込・合成キャッシュを継続。モデル原本・設計図ID・所持品UID・セーブデータは変更なし。
- **作業環境にはGodotの描画実行環境がなく、本変更でPNG19枚の再撮影自体は未実施。従来画像はそのままです。** Godotのある環境で制作コマンドを実行し、生成PNGを反映する必要があります。CI・各種テストは実施・変更していません。

## 2026-11-22 — NEXUS全身GPU輪郭の線幅を単体プレビューに合わせ、分離メッシュの浅い埋まり線を保持
- Android実機のPR #761描画では単体プレビューの3px輪郭より、NEXUS全身SERAのGPU凸角リボンが細く見え、肩・胸・腕・脚など分離した装甲が差し込まれた部分の線が抜ける。元方式のハードウェア深度テストでリボンの一部が自身／隣接パーツの前面に隠れることが主な原因候補。
- **NEXUS全身SERA専用** `shaders/nexus_sera_gpu_convex_silhouette.gdshader` のみ、旧depth_testあり→depth_test_disabled＋1回だけ不透明シーンの深度テクスチャを参照する軽量リボン描画に変更。フラグメントで実シーン深度とリボン深度を逆射影し、視点距離差0.22m以内なら通過。これで分離したメッシュが**浅く埋まった部分**の線を残し、遠く奥に完全に隠れた面は破棄。Godot CompatibilityのOpenGL NDCとForward+/Mobileのreverse-Zをプリプロセッサで分ける。
- シェーダーはフルスクリーンのID探索を行わず、元の凸角位相エッジリボンだけを描画。リボンの両側がGPUで画面上3px相当となるよう、通常の深度テストによる半幅欠けを防止する。 `nexus_sera_gpu_convex_silhouette.gd` の `PREVIEW_MATCHED_STROKE_PX=3.0`、`EMBEDDED_EDGE_ALLOWANCE_M=0.22` を設定し、`#17212F`を保持。GPU負荷の差分は未測定。
- 対象はNEXUS内の展示用全身SeraDisplayだけで、アイリス／標準パーツの単体プレビュー・戦闘・BASE・NEXUS施設・元メッシュ/装備/材質/陰影/ポーズの描画は変更しない。独立メッシュの**真の交差曲線**は生成せず、既存の位相シルエットを浅い遮蔽から表示する近似。深い埋まりや真の交差曲線には別方式が必要。
- ユーザーのCI禁止ルールに従いCI項目・期待値／テスト／ワークフローへ触れず、CI／Godot／Androidの実行・確認テストを行わない。Androidでの見た目は未確認。

## 2026-11-22 — NEXUS全身SERAだけGPU凸シルエット描画へ切り替え
- ユーザー要望：アクション向けの軽量な「カメラ方向から見えなくなる切り替わりの凸角のみ」を、まずNEXUSの全身プレビューに適用。実機で復旧したアイリス赤ID方式は比較基準としてほかの画面に維持。
- `scripts/nexus_sera_gpu_convex_silhouette.gd` を作成。既存のBASE位相エッジ抽出器から実メッシュの隣接面と頂点位置を受け、閉じたメッシュは符号付き体積を基に凸エッジだけ生成。UV分離重複頂点を位置で共有、同一平面の三角線は非表示。細いリボンは元`MeshInstance3D`の子にしアニメ・可視状態に自然追従。0.65秒スキャンと装備選択直後の即時更新、メッシュごとの形状キャッシュを使用。
- `shaders/nexus_sera_gpu_convex_silhouette.gdshader` を追加。GPU頂点シェーダーで隣接面の表裏切り替わり／開放エッジを判定し、3pxの画面ピクセル幅へ拡張。既存暗色 `#17212F`、通常の深度テストを使用。全画面マスクや追加ID用SubViewportはこの展示SERAに不要。
- `command_nexus.gd` の展示SERAだけに専用除外タグを設け、Rig内の共有ID登録を停止。共通IDレンダラはタグを尊重して全身SERAを除外する一方、NEXUS室内建物・BASE・LAB・戦闘・単体装備プレビューはすべて現状維持。材質シェーダーや原本メッシュ、SeraRig汎用実装、UIに変更なし。
- 既存のID版と見た目が完全一致する保証はない。特に独立メッシュの遮蔽境界、開いた/不均一な巻き方向の形状では差異があり得る。GPU/CPU負荷の改善量も実測できていない。今回の目的は局所的な実装比較。
- CI／テスト項目・テストファイルを調べたり更新したりせず、CI／Godot／Androidなどのテストを実施せずmainへマージ。

## 2026-11-22 — 共通可視ID輪郭をH02アイリスの実装そのものへ移植
- Android実機ではRGB444共通シェーダーのMASK/SOLIDが白（独立BASICのみマゼンタ）。アイリス単体は赤1チャンネルの専用シェーダーで正常。ユーザーの指示により共通版の独自RGBA比較方式を撤去し、**アイリス専用の3つの実コード資源** `sera_iris_mesh_id_closed.gdshader`／`sera_iris_mesh_id_open.gdshader`／`sera_iris_mesh_id_outline.gdshader` を共通版から直接preloadして使用。これら原本は編集しない。
- 共通のMeshInstance3Dにはアイリス同様、赤ID `(index+1)/8`、緑青0、原本の `sera_single_sided` タグに応じたclosed/openを使用。背景床等は赤0の深度遮蔽のみ。MultiMeshは既存のdraw callを維持するため、同じ赤ID式を `INSTANCE_ID` に適用する2つの薄い専用spatialシェーダーを追加。元のモデル・モーション・材質は不変。
- 共通版の輪郭Canvasもアイリス原本の同一 `INK` シェーダーを直接参照。 `TextureRect`＋完全透明1pxの安全な描画元、線幅3px、色 `#17212f`、nearest、深度付きSubViewport、スキャン・動体追従を保持。共通版の921600画素上限と幅縮小補正を外し、アイリスと同じ表示解像度1:1のIDテクセルに変更（高解像度時GPU負荷増加の可能性あり）。
- NEXUS輪郭診断MASKにも同じアイリス原本を直接preloadし、SOLID/BASICの独立診断は維持。CanvasLayer 1／HUD階層は全シーン適用に必要なため現状維持し、アイリス専用プレビューの表示・モデル編集機能は変更しない。
- **制限**：アイリス原本の輪郭シェーダーは赤ID間の差が0.05より大きい必要がある。各Viewportで実際に区別できる赤IDは1/8〜7/8の7種類で、101メッシュ等ではIDが循環し、同じ赤ID同士が接する部分の内部線は欠落し得る。今回はアイリス実績方式そのものが共通の描画経路で動作するかを優先した移植であり、4095個すべての境界を保証するものではない。
- CIテスト項目・ファイル・期待値の確認／変更、およびCI/Godot/Androidなどのテスト実施は全面禁止ルールに従い一切行わず、ユーザー指示に従いmainへマージ。Android実機の復旧とFPSは未確認。

## 2026-11-22 — RGB444共通輪郭の新規シェーダー資源への移行（実機画像継続障害）
- PR #758後のAndroid画像ではRAW ID画像に101メッシュが映り、共通MASKとSOLIDはいずれも白、独立BASICはマゼンタ。共通シェーダー内の変更だけでは復旧せず。診断表示のShader BOUNDはリソース参照の状態であり、GPUコンパイルの成功ではない。
- GL Compatibility上で新旧シェーダーの再コンパイル／キャッシュ差を切り分けられるよう、共通輪郭コードを新規ファイル `shaders/sera_scene_mesh_id_outline_safe.gdshader` へ分離し、共有コンポジタとNEXUS MASKの参照を変更した。H02アイリス専用版と同じ4つのuniform、floatベースのID比較、同じ7×7近傍（円盤3px）を使用。共通のRGB444（最大4095）を画面上の色に基づき最大約521の単一floatへ写像し、以前の11000超の値を避ける。深度パス・元ジオメトリは不変。
- 既存の`diagnostic_mode`を共通本番シェーダーから除去し、NEXUS小窓用に新規 `sera_scene_id_solid_probe.gdshader` を分離した。診断のMASK／SOLID／BASIC切替は保持。SOLIDは独立したサンプラー／uniform宣言つきマゼンタ強制シェーダー、BASICは既存の最小シェーダー。
- 本番の共通インクは引き続き完全透明1px TextureRectを使い、シェーダー不調時の白画面を防ぐ。アイリス専用描画、線色`#17212f`、最大3px、シーンHUD階層、モデル原本と材質は変更しない。
- 本変更は前回の実機結果に基づく対策だが、端末シェーダーログはなく、描画復旧は未確認。CI項目の確認・変更を含め、CI／Godot／Android／手動テストは一切実行していない。ユーザーの継続したマージ指示に従う。

## 2026-11-22 — 共通輪郭のMASK/SOLID不発をIRIS実績の単一float ID比較方式で修正
- 実機診断：RAW IDは101メッシュの識別色を描画、共通MASKと共通SOLIDはいずれも白。一方、完全独立BASICシェーダーはマゼンタを表示。CanvasItem自体は動作しており、問題は共通輪郭シェーダー固有のパース・コンパイル・描画経路に絞られたが、端末ログ未取得のため詳細なGPUエラーは未確定。
- 共通輪郭 `shaders/sera_scene_mesh_id_outline.gdshader` の色ベクトル3成分を関数で逐次比較する独自方式を撤去し、実機で動くH02 IRIS専用の単一float ID取得・比較・3px円盤近傍ループと同じコード経路へ統一。共通SubViewportのRGB444を高重みの3チャネルでひとつの大小比較用floatへ写像し、8bit/sRGB変換後もRGB各チャネルの階層順を維持。最大4095識別子の入力方式と深度遮蔽・片側3px接触線を保持。
- `diagnostic_mode=1` はNEXUS内小窓でのみ強制マゼンタを出す仕様を維持。失敗時も全画面に白ColorRectを置かず、透明1pxの安全なTextureRectを保持。モデル原本・材質、ID書込み専用シェーダー、3Dカメラ、HUD/レイヤー、アイリス専用描画には触れない。
- 原因コード候補を取り除いた修正であり、GL CompatibilityのGPU実機描画の復旧はまだ未確認。ユーザー指示どおりCIテスト項目・テスト用ファイル・設定を確認変更せず、CI/Godot/Android・テストは実行しないままmainへマージ。

## 2026-11-22 — 追加実機画像に基づく共通輪郭シェーダー最小プローブ
- NEXUSの実機画像でRAW IDはメッシュ色と形状を描画、Roots 2／Meshes 101／Camera ON／Overlay ON／Layer 1／ID 636×1449／InkShader BOUND／Quad 720×1640。一方、共通シェーダーによるMASKは白、共通シェーダー自身の強制マゼンタSOLIDでも白を維持。BOUNDは材質参照の設定状態であり、Godot/GL Compatibilityでのshader成功を保証しない。
- 原因候補は共通shaderのパース/コンパイル不成立・GPU側のシェーダー適用不良・描画先のCanvasItem/Material不良。現在の画像だけでは区別不能。
- NEXUSの既存小型「輪郭診断」の右側プローブに第三のBASICモードを追加。完全独立の最小canvas_itemシェーダーで全画素マゼンタのみを出力し、IDテクスチャ、uniform、ループ、比較、入力に依存させない。パネルのタップでMASK→SOLID→BASIC→MASKと循環し、通常の共通輪郭表示は変更しない。
- BASICがマゼンタ・SOLIDが白なら共通輪郭shader固有の問題、BASICも白ならmaterial/CanvasItem/描画経路全般を疑う。どちらも実機画像受領前は未確認。全画面の危険な不透明Rectに戻さず、小型診断窓の外には影響させない。
- CI項目・期待値・テスト用ファイル・ワークフローへ触れず、CI/Godot/Android/手動テストを行わずにユーザーの継続指示に従いmainマージ。

## 2026-11-22 — 全画面白塗りの直接原因を排除／共通輪郭シェーダーの現場診断を追加
- Android実機のBASEとNEXUSがほぼ真っ白になった。HUDは描画されたままなので描画対象は3D領域と一致。直前のPR #755が共通輪郭のCanvasLayer(1)に画面全体を覆う不透明な白ColorRectを追加しており、fragmentによる透明化が効かない状態で白いフォールバックがそのまま前面に現れた、とコードと画像から特定。
- 全画面の共通インクを、もとの安全な**1×1完全透明TextureRect**に戻す。シェーダー実行不能・アルファ処理失敗時でも白い実矩形で3Dを上書きしない。レイヤー1/2、元モデル、材質、原本・装備、3px/線色は維持。共通輪郭が出ない元の理由はまだ特定できない。
- NEXUS既存の「輪郭診断」にRAW ID画像と**共通輪郭シェーダーそのもの**を使う小さなプローブを並列配置。診断パネルのタップで「MASK＝輪郭抽出結果」と「SOLID＝シェーダーが走ればマゼンタ全面」を交互に表示する。シェーダーが無効なら白表示になるのは小さな診断枠**内部のみ**。Productionのviewport-wideインクは常時診断モード0。
- 診断統計には元ViewportのInkShader割当状態と実際の描画矩形サイズを追加。RAWに識別色あり／SOLIDがマゼンタ＝Shader fragment稼働、RAWに識別色あり／SOLIDが白＝Shader/Material適用不成立、SOLID成功／MASK空＝輪郭抽出・ID UV・背景分類など、と不具合の箇所を区別する（どれも実機結果は未観測）。
- CI項目／テストコード・ワークフローには触れず、CI／Godot／Androidなど一切のテストを起動・実行しない。ユーザー指定でmainへマージ。描画改善は実機未確認。

## 2026-11-22 — 共通メッシュID輪郭の描画プリミティブを不透明化
- Android実機ではH02アイリス専用の枠線だけ描画される一方、共通IDバッファはRoots 2／Meshes 101／Camera ON／Overlay ON／ID 636×1449として表示され、全身SERAと標準単体の黒輪郭だけが見えない。単にID未生成・レイヤー順だけの問題ではない。
- 共通合成用の完全透明1×1 TextureRect（旧0.004 alpha ColorRect）をやめ、白・alpha 1のColorRectを確実な描画矩形として使用。シェーダーのRGB444 IDから算出した枠線部分だけ不透明、枠線以外はfragment側のalpha 0で透過する。元の材質、深度付きIDパス、専用アイリス、色#17212F、幅3pxは維持。
- CanvasLayer直下にControlの親がない環境でもインク矩形のサイズ・位置を毎フレーム差分同期し、全身・通常単体・他3D Viewportで矩形が消えないようにする。UIの上には表示しない。
- ユーザーの指示に従ってCI項目・テストコードに触れず、CI／Godot／Android等の動作テストは実行しない。実機での改善は未確認のまま、指定されたmainマージを行う。

## 2026-11-22 — ID画像は描画できているのに輪郭線が消える問題の描画順修正
- PR #753後のAndroid画像で、RAW MESH IDのプレビューにSERAの形状と周囲の識別色が表示され、Roots 2／Meshes 101／Camera ON／Overlay ON／ID 636×1449／Redraw 55と確認できた。共通IDの登録・描画・更新は少なくとも稼働している一方、全身および通常単体の黒輪郭は引き続き見えない。
- 共通輪郭のCanvasLayerを既定Canvasと同じレイヤー0から**明示的に3Dの後ろではなく前景となるレイヤー1**へ変更。NEXUS／BASE／通常戦闘のHUDはレイヤー2へ移し、輪郭は3Dの上・UIの下で重ねる。ビットタラン独自ラベル（30）とアイリス単体の専用ID描画は変更しない。
- 以前のColorRect／TextureRect切替で改善しなかったことを踏まえ、今回は矩形やIDシェーダー本体を変更せず、輪郭表示順のみを分離。現行RGB444／3px／#17212fと材質・モデル・ゲーム処理は変更なし。
- CI項目・テストコードの確認変更、CI・Godot・Androidのテスト実行はユーザーの禁止ルールに従って実施せず。ユーザー指示「修正してマージ」によりmainへ統合予定。実機復旧は未確認。

## 2026-11-22 — メッシュID輪郭が出ない原因をID合成段階へ絞った対応
- NEXUSの「輪郭診断」実機画像で `Roots 2 / Meshes 101 / Camera ON / Overlay ON / ID (636,1449) / Redraw 58` を確認。プレビューにはSERA形状と周辺の大きな緑色背景メッシュ（ID色）が見えており、登録・専用IDビューポート生成・描画更新は稼働している。Overlay ONは単なる可視フラグで、3pxの画素合成成功を示さない。
- 共通シーンID輪郭の合成だけがアイリス単体実績方式と異なり、`ColorRect`（基底色alpha 0.004）を使用していた。低alphaの基底矩形が合成へ影響する可能性を排除するため、**正常描画中のアイリス単体と同じ**`TextureRect`、1x1透明プレースホルダ、EXPAND_IGNORE_SIZE、STRETCH_SCALE、nearest/繰返しなしの設定へ戻す。
- ID用サブViewport・RGB444 ID画像・メッシュ登録・カメラ同期・画面サイズ追従・3px線幅・ShaderMaterialとそのuniform値は変更しない。輪郭生成用の実際のID画像はTextureRectの通常テクスチャには割り当てず、`mesh_id_texture` uniform経由でのみ使用し、シェーダー異常時にIDを生表示しない。
- 実機での復旧は未確認。ユーザーの開発ルールに従いCI項目の確認・編集とCI/Godot/Android/手動テストの実施を行わない。main未マージでPR待機。

## 2026-11-22 — PR #751でも消失する全身/通常単体輪郭の切り分け診断
- 新たな実機スクリーンショットでも、標準頭部の単体ビューポートとNEXUS全身モデルに輪郭が描画されず、H02アイリス専用のID輪郭だけ正常。PR #751によるColorRect/描画レイヤー修正のみでは復旧しなかったため、推測によるシェーダー差し替えを控え、ID描画経路を直接可視化する。
- NEXUS → CUSTOMIZEの上部余白に小型「輪郭診断」ボタンを追加。タップすると生のID描画SubViewportの内容を色を明るくして表示し、同時に登録ルート数・IDメッシュ数・カメラ有無・合成レイヤーの表示状態・ID画像サイズ・再描画要求回数を読み取れる。ボタン再タップで非表示、CUSTOMIZEを離れると自動終了。
- `shaders/sera_scene_id_debug.gdshader` は診断中の小型プレビューでのみ使用。通常の輪郭描画、アイリスの専用描画、3px、モデル・材質・戦闘・セーブの挙動は変更しない。Androidタッチのマウスエミュレーションが無効なので、既存のNEXUS生タッチ処理でトグルを受け付ける。
- 画像の解釈：Roots 0 は登録失敗、Meshes 0 はスキャン/フィルタ失敗、Meshes 正かつプレビューが真っ黒ならIDオフスクリーン描画側、プレビューに色があるのに線が無ければCanvas合成側が疑わしい。これらは原因の切り分けであり、ランタイムでの検証結果ではない。
- ユーザーの運用ルールに従いCI項目/設定/テストコードを確認・更新せず、CI/Godot/Android/手動テスト実行なし。ユーザーから明示的なマージ指示はないためmainへは未反映。

## 2026-11-22 — メッシュID方式の共通輪郭が全面消失する問題への修正
- PR #750適用後、NEXUS全身SERAと通常単体プレビューの線が見えず、H02アイリス専用の輪郭だけ残る実機スクリーンショットを受領。原因候補は共通IDレイヤーの全画面矩形がCanvasLayerで正しく確保されないこと、1x1完全透明テクスチャへの描画が省略されること、ID専用ワールドの描画レイヤー不整合。
- `sera_scene_id_outlines.gd` の全画面インク合成を1x1完全透明TextureRectからColorRectの実際のCanvasItem矩形へ変更。元のViewportの可視矩形を追跡して親ControlとColorRectの寸法を明示的に同期。
- 空白時の全面白塗りを防ぐためColorRectの基底色は0.4%白（ほぼ透明）、シェーダーで3pxの輪郭色・アルファを上書き。識別用SubViewportのCamera3Dと複製メッシュは独立World3Dのレイヤー1へ統一し、元シーンのカメラ描画マスクは複製モデルに引き継がない。
- エラー切り分け用に非侵襲的な`get_outline_metrics()`（登録ルート、コピー数、元Viewport/IDサイズ、カメラ状態、再描画要求回数）を追加。デバッグ用ID色をユーザー画面に表示せず、アイリス専用ID輪郭・元材質・モデル・輪郭色#17212f・輪郭3px・シェーダー陰影設定を変更しない。
- **原因は現時点で仮説**。CI項目/テストコードは確認・変更せず、CI/Godot/Androidテスト実行は行わない。実機表示は未確認。ユーザーの明示的な「マージ」指示は今回ないためPRで待機する。

## 2026-11-22 — アイリス方式の可視メッシュID輪郭を全3D表示へ共通展開
- アイリス単体が綺麗に描けた原因である深度付きID画像＋3px境界抽出を全3D画面へ転用。 `SeraViewEdges` の反転ハル生成は廃止し、Viewportごとに共有するID描画SubViewport（同時に1つ）＋CanvasLayer上の3px輪郭へ変更。
- NEXUS全身/建築、その他の単体パーツ、戦闘SERA/ビットタラン/砲塔/標的、BASE施設/CRATE、LAB製作/精製/倉庫背景と装備プレビューを対象。アイリス専用6メッシュIDだけ既存の正確な方式を維持し、共通側を同時に出さない。
- RGB444最大4095種類のID、MultiMeshは`INSTANCE_ID`ごとに個別輪郭、交換・再生成時のID範囲再利用。1ビューポートにつき1枚のID画像のみ、表示変化時のみ再レンダリング。インク色#17212f、線幅は画面Viewport基準3px（384px単体／720px全画面）へ統一。上限時はバッチ単位IDへ縮退。
- BASE/NEXUSの旧施設輪郭を二重描画しないよう可視輪郭パスを抑制し、煙・発光・透明VFXは輪郭対象外。床はIDゼロの深度遮蔽物として描画。元モデル・戦闘数値・UV・陰影・保存データは不変。
- 詳細: `docs/SERA_VISIBLE_MESH_ID_ROLLOUT_20261122_ja.md`。CI項目・テストコードの確認変更とCI/各種テスト実行は一切行わず、ユーザーの「マージ」指示で統合。実機の表示やFPSは未確認。

## 2026-11-22 — 3D輪郭の3px復帰と急角度面の黒塗り抑制
- 最新Android画面でアイリス単体に対し全身の輪郭が異常に太く、頭部・四肢の折れ目に黒い帯状領域を確認。前回のViewport短辺/384で線幅を自動拡大する変更を取り消し、全てのSeraViewEdges描画で`stroke_px=3.0`を使用。
- 閉じたBlockbench装甲パーツ用の`sera_view_edges_fast.gdshader`は背面の拡張メッシュを無条件に塗りつぶしていたため、`cull_back`を維持したまま深度テクスチャの中心と4方向の近傍に実際の描画表面がある場合のみ描画する方式へ変更。開いたメッシュ用`sera_view_edges.gdshader`にも3pxに合わせた近傍判定を適用。
- 輪郭色#17212f、アイリス専用ID輪郭の3px、施設独自2px/4px、モデル/UV/陰影数値は変更なし。高速版も深度テクスチャを使うためGPU負荷上昇の可能性あり。
- ユーザールールに従いCI項目・manifest・テストコードを確認修正せず、テスト実行もなし。Android/Godotの描画・FPSは未確認。ユーザーの「マージ」指示によりmainへ統合する。

## 2026-11-22 — 全身・通常単体プレビューの輪郭消失を修正（未マージ）
- PR #747後の実機スクリーンショットで、アイリス専用ID輪郭以外の3D輪郭が見えないことを確認。共通輪郭シェーダー `sera_view_edges.gdshader`／`sera_view_edges_fast.gdshader` の新規補助関数が `VIEWPORT_SIZE` ビルトインを直接参照していた点を修正。
- 補助関数を `effective_stroke_px(vec2 viewport_size, float base_stroke_px)` とし、`vertex()`／`fragment()` から `VIEWPORT_SIZE` を引数で渡す。通常版の深度再構成補助関数も `INV_PROJECTION_MATRIX` を明示的に引数で渡す方式へ変更。Godotシェーダーのビルトイン参照スコープを遵守。
- 単体384px基準3px／全画面720px短辺基準5.625pxの比率は維持。アイリスID輪郭、色、モデル、陰影、UV、装備判定、独自施設輪郭は変更しない。
- ユーザーの開発ルールによりCI項目・テストコードへの変更なし、テスト実行なし。Godot／Android実機での表示は未確認。mainへは自動マージしない。

## 2026-11-22 — 全身・戦闘モデルの輪郭を単体ビューポート比率へ揃える
- ユーザーのNEXUSアイリス単体ビューポートの線幅（3px/384px）を基準に、共通 `SeraViewEdges` の2つのシェーダー（標準深度サンプル版／高速背面カリング版）で描画Viewport短辺に比例した輪郭幅に変更。720×1280で5.625px、384×384で3px。深度側の4方向輪郭検出半径にも補正を適用。
- アイリスのID輪郭シェーダー自身は3pxのまま。NEXUS建築の独自角線・施設の2px/4px・色・陰影設定は変更なし。単体プレビュー以外のSeraRig、BITTARAN、LAB立体設備、クレート等に共通スケーリングが届く。
- mainは変更せず `fix/monochrome-armor-world-shading-20261122` ブランチに実装を追加。CI関連ファイルの確認・編集、テスト実行はユーザー指示に従って行わず。Godot／Androidでの見た目や描画負荷は未確認。

## 2026-11-22 — 単色パーツは全て装甲へ固定、陰影/Viewport表示の整合修正
- 現行の単色材質（テクスチャなし、または小テクスチャ全画素同色）を色相・明度・名前・部位に依存せず `armor` に固定。単色の黒/グレーは暗色機構に分類せず、単色の青はレンズに分類しない。複数色のみ元のアイリス色分けまたは名前/構造で暫定分類。HEAD Cから誤って借用していた共通96×32アトラスを外し、本来の単色の装甲色に修正。
- 共通材質シェーダー3種＋アイリス単体シェーダー2種の擬似ライトをビュー空間法線からワールド空間法線へ変更。カメラを回転しても同じ世界方向からの陰影にする。96×32の元から明暗があるテクスチャは陰影の差分を半分にして暗くなりすぎる問題を低減。アイリスのシェーダー初期値も装甲8/0.65・暗色機構2/0.70・レンズ3/0.10へ統一。
- `project.godot`を `window/stretch/aspect="expand"` にして9:16固定レターボックスを回避。HUDが縦長の追加領域でどう配置されるかは実機確認待ち。
- 輪郭の `stroke_px=3` は現在も描画先Viewport基準（VIEWPORT_SIZE）でありテクスチャpxや端末の物理画素と常に等価ではない。線幅設定は変更しない。単体プレビューは384x384のSubViewportのため最終画面への拡大率によって見かけの線幅が違うことに注意。
- 対象はNEXUS・単体プレビュー・戦闘プレイヤー・ボス・拠点・LAB・倉庫へ展開済みの共通シェーダー。原本モデル・戦闘数値・保存済み設定は維持。仕様 `docs/SERA_FULLBODY_MATERIAL_SHADING_20261122_ja.md` を更新。
- 開発ルールによりCI項目・期待値/テストコードの確認変更は行わず、CI・自動・手動テストも実行していない。実際のAndroid描画・タッチ・FPSは未検証。「実装」扱いのためmainへはマージしない。

## 2026-11-22 — 全3D画面へ材質別ポリゴン陰影を展開
- ユーザー提供の `SERA_IRIS_MATERIAL_SHADING_V1` 値（装甲8段/0.65、暗色機構2段/0.70、レンズ3段/0.10、発光OFF）を共通GPUシェーダーへ固定。アイリス個別UIの未保存初期値も一致させ、既存の端末保存値と5枠プリセットは保持。
- SeraRigに共通材質を組み込み、NEXUS展示・全身/部位プレビュー・戦闘プレイヤー・LAB/倉庫の装備プレビューへ一律展開。BittaranRig本体・背中レールガン・腹部砲塔にも適用し、部位被弾・破壊・死亡の色変化をShaderMaterialパラメータで継続。
- BASEの全設備・NEXUS外観・クレート・MultiMesh装飾、およびNEXUS内部建築、LAB製作・精製・倉庫の独立3D背景にも適用。レイアウト再生成時の新しい3Dモデルは再適用。原本UV・頂点色・テクスチャと既存next_pass縁取りを保持し、同一パラメータはGPU材質共有。発光・透明・レーザー・粒子等の特殊演出は原本材質を残す。
- SERA/Bittaranの元Blockbenchポリゴンで三角分割による余分な陰影差を抑える法線集約を適用。SeraViewEdgesの3px輪郭、NEXUS建築の2px線、BASE施設の固有輪郭を保持。クレート・LAB立体モデル・腹部砲塔にも輪郭を追加。射撃エフェクトには輪郭を適用しない。
- `docs/SERA_FULLBODY_MATERIAL_SHADING_20261122_ja.md` に仕様を集約。静止PNGサムネイルと2D HUDは対象外。CI関連の確認/編集/テスト実行はユーザーの運用ルールに従って一切行っていない。Godot/Android実機確認未実施、バージョン据え置き。

## 2026-11-22 — アイリス材質数値をNEXUS全身SERAモデルへ暫定適用
- ユーザーのJSON指定値（装甲8段/0.65、暗色機構2段/0.70、レンズ3段/0.10、水色発光OFF）を、NEXUS展示SERAリグの全装備スロット／各交換候補へ同時適用する全身用シェーダーを新設。色味とUV、オリジナル原本、セーブは変更しない。
- 16×16アイリスはライトグレー／ダークグレー／水色から材質を識別。通常96×32パレットは既存の面ごとの明暗を考慮し、部品名・階層・位置（関節、膝、首、シャフト、サーボ等）を優先して暫定分類。shaderはテクスチャ・色・メッシュ分類ごとに共有し描画パスを追加しない。
- 既存SeraViewEdgesの3px輪郭を全身装備で維持。SeraRigが生成する元のBlockbench面について三角形間の法線をそろえ、不要な斜め陰影を抑制。今回はNEXUSの全身展示だけで、戦闘・倉庫・LAB・アイリス単体の描画は変更しない。
- `docs/SERA_FULLBODY_MATERIAL_SHADING_20261122_ja.md`に仕様と未確認事項を記載。ユーザーのCI禁止ルールに従いCI項目・テストコードには触れず、テスト実行なし。mainへのマージは指示待ち。バージョン据え置き。

## 2026-11-22 — アイリス一括陰影段階ボタン廃止
- NEXUSのH02アイリス単体プレビューから右上のOFF／2〜8段の一括陰影ボタン列と一括切替ハンドラ／タッチ判定を削除。装甲、暗色機構、レンズの材質ごとの段階としきい値は引き続き個別調整可能。
- 既存の5枠プリセット保存／読込、最終値自動復元、JSONコピー／貼り付け、点灯時発光、材質選択の青白い単発点灯、拡大縮小、原本法線、3px輪郭は維持。一括段階数を同期していた旧表示用状態のみ削除。
- 最新の開発ルールに従いCI項目・manifest・テストコードの確認／変更・テスト実行は行わず。ゲームバージョン据え置き。

## 2026-11-22 — 開発運用ルール：CIテスト項目の確認・修正・適用とテスト実施を禁止

- 最新ユーザー指示を最優先とし、すべての今後の開発でCIテスト項目・期待値・登録内容の確認／変更／適用を禁止。CI、ローカル、Godot、実機などのテスト実行も禁止する。
- 旧「CI期待値を先行更新」「変更ごとに局所検査」「実装後にテストを実施」「CI未実施ならマージ保留」の運用を停止。`AGENTS.md`、`docs/agent/CI_WORKFLOW.md`、`docs/SERA_MANUAL_TEST_WORKFLOW_ja.md`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`を更新。
- 今回は文書のみ変更。テスト項目・テストコード・CIワークフロー・manifest・ゲーム本体・素材には変更なし。テスト未実施（ユーザー指示）。ゲームバージョン据置き。

## 2026-11-22 — NEXUS単体アイリス拡大プレビュー：材質別陰影調整
- H02アイリスの単体プレビューの拡大時だけ「材質調整」ボタン・4材質の横並び設定表を追加。ライトグレー＝装甲、濃淡ダークグレー＝暗色機構、水色＝レンズ／点灯時の発光。原本16×16テクスチャの4色を画素単位で識別し、メッシュ／テクスチャ原本は非改変。
- 各材質の陰影OFF/2〜8段としきい値0.00〜1.00（0.05刻み）を個別調整。発光は陰影OFF固定。右上の従来の一括バンドボタンは維持。材質名を押すと対象色だけ0.65秒の青白い単発パルス。発光ON/OFFと全設定JSONのクリップボードコピーを追加。
- 既存3pxのID輪郭・原本四角面法線補正・ダブルタップ拡大・縮小操作を維持。NEXUS以外（LAB/倉庫/戦闘/全身）に描画変更なし。仕様：`docs/SERA_IRIS_MATERIAL_SHADING_EDITOR_20261122_ja.md`。
- 新静的検査`iris_material_shading_editor_self_check.py`を実装に先行追加し、旧一括陰影の`iris_polygon_shading_fullscreen_self_check.py`期待値を更新。Godot構造テスト`iris_material_shading_editor_runtime_check.gd`もmanifest登録。実Androidでの表示・操作・クリップボード・GL Compatibilityは未検証。ゲーム進行や保存仕様を変更しないためバージョン据置き。

## 2026-11-22 — ロード完了カットを2描画フレームから3描画フレームに延長
- 実ロードと50%/37.5%/25%プレビューの「COMPLETE / 100% / ALL SYSTEMS ONLINE」表示を、描画完了シグナルで数える3フレームへ延長。10FPSのため目安は0.3秒。
- `COMPLETE_CUT_FRAMES` を2→3に変更し、ローカルヘッドレス用カウントも同じ定数を利用。起動時のBASEへの切替・プレビュー終了は3描画完了後とする。すべてのインジケータ、発光、ログ、実ロード・プレビュー100段階、FPS復帰の処理は保持。
- 先行更新した`sera_loading_console_self_check.py`と`sera_loading_console_runtime_check.gd`で、1・2描画完了時に閉じず、3描画完了後に閉じることを検証する契約に変更。Godot/Android実機での見え方は別途確認。

## 2026-11-22 — ロード完了「COMPLETE」全システム起動カット（描画2フレーム）
- 共通コンソール表示中に限って実フレーム上限10FPSを適用し、終了時に元のFPS上限を復元（既存PR #737の変更も今回のPRへ統合）。通常のBASE・NEXUS・GRID・戦闘のFPS設定は不変更。
- 起動工程が100%に達すると、`> COMPLETE`、`100%`、`ALL SYSTEMS ONLINE`を表示。COREを最大発光、3層リング全展開、8ノード全点灯、左右各6本の診断ゲージ最大として描画。
- 従来の`process_frame`2回待機を廃止し、`RenderingServer.frame_post_draw`2回目で完了通知を発火して画面を閉じる。BASEプレビューも5秒/100件のログ後、同じ2描画フレームを保持する。
- 仕様・先行CI期待値は`tools/sera_loading_console_self_check.py`、`tools/sera_loading_console_runtime_check.gd`、`tools/base_startup_first_frame_self_check.py`で保護。Godot実行・Android実機での描画回数と表示は要確認。ゲームバージョンは据え置く。

## 2026-11-22 — FPS OPTIONS（拠点/NEXUS・GRID操作・戦闘の3系統）
- NEXUS → SYSTEMにFPS SETTINGSのサブページを新設。3行それぞれタップで60/40/30/20FPSへ巡回、Android戻ると画面内BACKで元のSYSTEMへ。狭幅端末でも従来の3セーブスロット・4アクション・ロック・利き手設定と重ならないようSYSTEMレイアウトを調整。
- `scripts/sera_frame_rate_settings.gd`は端末グローバル`user://sera_settings.cfg`の[fps]へ各値を保存し、[controls]・セーブスロットを保持。初期値はBASE/NEXUS=30、GRID編集=60、戦闘=60。無効な値は初期値にフォールバック。
- BASEは既存`sera_base_frame_budget.gd`の開始/編集ズーム/復帰時に設定を取得し、NEXUSおよび`main.gd`の戦闘（ビットタラン継承を含む）は入場時にそれぞれの設定を適用。隔フレーム描画は再導入せず、物理60Hz・実時間のアニメーション/カメラTween速度を維持。
- 新テスト`sera_fps_options_self_check.py`/`sera_fps_options_runtime_check.gd`を実装前に追加し、旧固定FPS仕様の`base_frame_budget_{self_check.py,runtime_check.gd}`を独立設定へ更新。設計正本は`docs/SERA_FPS_OPTIONS_20261122_ja.md`。CI自動起動なし。Godot・Android実機検証は未実施。

## 2026-11-22 — BASE描画の疑似間引きによる倍速に見える動作を修正

- PR #731で加えた「60FPSで動作させ、Root Viewportを`VIEWPORT_UPDATE_ONCE`/`VIEWPORT_UPDATE_DISABLED`で隔フレーム更新」方式を撤回。1コマに2回分の変化が現れて倍速に見える問題を避けるため、Godot標準の`Engine.max_fps = 30`へ変更し、BASEとGRID俯瞰で30FPSの実フレーム上限制御を使う。
- GRID編集の真上ズーム開始時だけ`Engine.max_fps = 60`、ズームアウトTween完了後に30FPSへ復帰する。物理更新60Hz・入力蓄積無効・直接のタッチイベント処理は保持。NEXUS遷移では元の上限、物理設定、入力設定へ復帰する。
- `_process(delta)`、クレートの移動速度、施設の時計、Tween時間、シェーダーのTIME、`Engine.time_scale`は変更しない。なお30FPS時のGodotイベント配送は毎秒60回と保証できず、物理固定更新60Hzと実際のタッチ取得頻度は別物である。60Hzタップ応答および映像速度の実測はAndroid実機確認が必要。
- 更新前に既存`base_frame_budget_self_check.py`/`base_frame_budget_runtime_check.gd`の期待値を、実30FPSキャップ、Grid編集中60FPS、Viewportモード不変、ゲーム時間不変の契約へ更新。ユーザー要望に従い自動CIを起動せず、GodotとAndroidの動作・操作感は未確認。ゲーム版据え置き。

## 2026-11-22 — BASEは映像30Hz・入力60Hz、GRID編集ズームのみ60Hz

- `scripts/sera_base_frame_budget.gd`を新設。BASEシーン中のメインループ上限を60FPS、物理固定更新を60Hz、入力蓄積を無効化し、`_input()`で受ける施設/GRIDタップを描画キャップへ束縛しない。root viewportの更新モードを`VIEWPORT_UPDATE_ONCE`/`DISABLED`で間引き、通常BASE/GRID俯瞰は描画30Hzとする。
- GRID盤面タップで真上編集ビューへズーム開始した瞬間に`VIEWPORT_UPDATE_ALWAYS`へ切り替え、戻りアニメーションの終了まで60FPSを保持。その後30Hz描画へ戻す。NEXUS移動・BASEシーン終了では従来のEngine・Input・Viewport設定を復元し、戦闘/NEXUSには変更を残さない。
- 拠点の既存タップ判定・タッチ離し・UIヒット領域・カメラ座標計算を変更しない。60Hzとは60FPSメインループおよび60Hz物理処理の基準であり、端末が物理タッチを正確に毎秒60回報告する保証ではない。実際の入力遅延・描画パターンはAndroid実機で計測する。
- 仕様を独立した受入期待値とする`tools/base_frame_budget_self_check.py`および`tools/base_frame_budget_runtime_check.gd`を本体変更より先に作成しmanifest登録。手動CI前提のためGithub Actionsは起動しない。Godot/Android実機でのGPU更新モード・タップ応答性・復帰時のフレーム間隔確認は別途必要。ゲーム版は据え置き。

## 2026-11-22 — ロードコンソールの3段階ドット文字描画（50%・37.5%・25%）

- 専用`sera_terminal_pixel_font.gd`で53種の英数字・記号を5×7ドットから小型Atlas化。通常のフォントの縮小ラスタライズを使わず、`sera_loading_console.gd`内の全文字を整数ピクセル格子へスナップして描画する。50%は大きい進捗率を3pxセル、37.5%では進捗率と短縮見出しを2pxセル、25%では進捗率を原則2pxセルに変更し、その他は小さくても1pxセルを保持する。
- 各倍率で文字幅を正しく計測し、進捗率と最新ログの重なり、履歴ログのはみ出し、診断ラベルの狭幅表示を回避。起動時の実ロードは50%、37.5%・25%はBASEプレビュー用のまま。5秒/100段階・実進捗・システム点灯・横スイープ禁止、ゲーム側解像度は無変更。
- 既存の`sera_loading_console_self_check.py`と`sera_loading_console_runtime_check.gd`の文字仕様・倍率連携のテスト期待値を実装前に更新。GitHubへコード・テスト・仕様を追加。ローカルGodot/Androidによる実描画確認は未実行で別途必要。ゲーム版据え置き。

## 2026-11-22 — SERA 自動CI依存を廃止、変更別ローカル検査へ移行

- ユーザー指示に従い、テスト系10本のGitHub Actionsを `workflow_dispatch` 専用に変更。従来から手動専用の2本は維持し、ゲーム・ローダーAPK、GitSync、フォント資産配布、過去履歴整理の7本は既存トリガーを保持。
- 既存の `tools/sera_ci_suite.py --tests`、`tools/sera_workplan.py`、`tools/sera_quick_check.py` を日常の変更別検査の基盤に採用。全件テストは重要な共通変更や明示的な手動実行で利用。テスト本体・期待値・manifestの旧登録は削除していない。
- 新正本 `docs/SERA_MANUAL_TEST_WORKFLOW_ja.md` を追加し、`AGENTS.md`、`docs/agent/CI_WORKFLOW.md`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、開発ツールの旧「毎回フルCI必須」指示を更新。仕様変更時のテスト期待値の先行更新、既存回帰の保護、重大な未検証リスクでのマージ保留、Android実機確認の区別は維持。
- `tools/sera_manual_workflow_policy_self_check.py` をテストmanifestに新規登録。テスト用Actions 12本の手動専用と、配布・通知7本の従来トリガーの保持を静的チェックする。
- 実装対象は開発インフラ・文書のみ。ゲームコード、モデル、アニメーション、UI、保存形式、ゲーム版は変更しない。GitHubランナー／Android実機実行は本変更の確認には使用していない。既存の滞留Actionsはトリガー変更後も別途管理する。

## 2026-11-22 — SERA/IRIS全身が黒くなる回帰のカリング修正

- Android提供スクリーンショット（SERA v545）で、カスタマイズの全身装甲がほぼ黒色になった。原因は閉メッシュの正の符号付き体積に対してGodotの表面が時計回りであることを考慮せず、元の装甲を`CULL_BACK`、黒い高速ハルを`cull_front`としていた表裏逆転。
- 閉じた原本メッシュの面・法線・UVは一切変更せず、元装甲だけ`CULL_FRONT`、高速輪郭だけ`cull_back`に変更。開いたアイリス側面などの両面描画と従来の深度マスクは維持。3px色/太さ、ボス/装備アニメ/FX/BASE専用6px線は不変。
- 変更より先に`sera_face_culling_self_check.py`と`sera_face_culling_runtime_check.gd`のカリングの契約を修正。GPU画像とAndroidでの黒面消失は実行による再検証が必要。
## 2026-11-22 — SERA/IRIS装甲の面方向修正・片面カリング・可視輪郭軽量化（PRのみ）

- 8正本165メッシュの面方向を監査。155閉メッシュの原本向きは一致。10件（IRIS左右の開放装甲、Chest_Mesh、開放Thruster等）は両面表示を維持。従来の面中心対モデル中心補正は凹形状・管・アイリスで224三角形を誤反転していたため、`sera_face_culling.gd`の共有辺・連結成分・有向体積検査へ置換。
- `sera_rig.gd`と`bittaran_rig.gd`は閉シェルだけ `BaseMaterial3D.CULL_BACK`、例外は`CULL_DISABLED`。自動判定を`sera_single_sided`メタに保存。モデルの原本、UV、骨・IK・モーション、装備・セーブデータは不変。
- `sera_view_edges.gd`から閉シェルを`sera_view_edges_fast.gdshader`へ切り替え、ピクセル法線拡張・深度テスト・3px線を維持して深度テクスチャ参照0回へ削減。開放形状には既存の深度サンプル型を維持。BASE施設専用6/2px・NEXUS室内2pxは変更しない。
- 先行CI: `sera_face_culling_self_check.py`、`sera_face_culling_runtime_check.gd`、旧新を交互に計測する`sera_render_performance_benchmark.gd`を登録。理論枚数・描画負荷の構造比較、実測用手順は`docs/SERA_FACE_CULLING_AUDIT_20261122_ja.md`。
- ユーザー指定により**mainマージは禁止**。PRでCI・外観・性能を確認する段階で停止。Android実機FPSと輪郭の実描画品質は未検証。

## 2026-11-22 — IRIS/SERAカスタマイズ時の黒塗り潰し回帰を修正

- Android実機スクリーンショットでアイリス単体・全身機体の内部に濃い塗り潰しが見える不具合を確認。原本は両面描画、枠線は裏面ハル描画であり、面向きの不統一に弱かった。
- 共通 `shaders/sera_view_edges.gdshader` にGL Compatibility対応の不透明深度テクスチャ比較を追加。自分の実表面と同じ深度の黒ハルは破棄し、上下左右3pxに対応する実表面がある可視輪郭部分だけを残す。線幅3px・深度テスト・FX除外・装備モデル・NEXUS室内2px角線は維持。BASE施設の共通6px外周パスも安全処理を利用。
- 変更前に静的・Godotシェーダー契約検査の期待値を更新。headless CIは実機の見た目を保証しないため、カスタマイズ画面のアイリス角度を変えた比較、全身ポーズ、戦闘、BASE施設の実機確認を残す。

## 2026-11-22 — BASE施設の6pxシルエットを最新SERAシェーダーへ更新（2px角線は保持）

- 2026-11-22 PR #706でSERA本体の輪郭処理は、旧「隣接面エッジリボン」から**頂点の面積加重平均法線＋深度テスト付き背面拡張（inverted hull）**へ変更された。BASEでは旧リボンのシェーダーに新しいSERAの`_build_overlay`（背面三角メッシュ）を渡しており、頂点属性が不一致だったためこの差分を解消。
- 施設の6px輪郭は**最新正本`shaders/sera_view_edges.gdshader`そのもの**を参照し、施設用`ShaderMaterial`で`ink_color=#55798A`、`stroke_px=6.0`を設定。法線生成は`SeraViewEdges._build_overlay`をそのまま呼ぶ。元のフラットシェーディング/装備/ターゲットの3pxシェーダーは未変更。
- 2px角線は変更前の2026-11-21 SERA 80°`_extract_edges`と`_build_overlay`を`scripts/sera_base_facility_crease_geometry.gd`へ**そのまま分離**。BASE従来の`shaders/base_facility_view_edges.gdshader`は二面ともカメラ向きの`COLOR.a > 0.5`だけを描画する専用パスへ切替。幅・線色・深度条件は保持し、旧6pxリボン描画だけを停止して外側で二重にならないようにする。
- 外周と角線は不透明な建築パーツのみに別の`MultiMesh`で描画（`ArchitecturalEdgeInk_*`と`ArchitecturalCreaseInk_*`）。元の外装/屋根/機械アニメは維持。可動部が持つ`ink_mesh`と`crease_mesh`に同じ30Hz変換を適用し、両方のラインを同期させる。
- 煙、炎、光漏れ、床反射、発光ガラス、拠点小物にはどちらも適用しない。2つ前の旧NEXUSと7施設の角張った形状、GRID、CRATE、端末タップの仕様も不変。
- CI受入条件を先に追加・更新：`base_latest_sera_silhouette_{self_check.py,runtime_check.gd}`。既存2つのBASE FX/輪郭テストも二系統描画へ改訂。通常BASEカメラ720×1280のスクリーンショットで輪郭の太さ・ちらつき・内側の余計な線がないか目視確認する。Android実機での検証とは区別する。

## 2026-11-22 — SERA・標的の可視独立メッシュ輪郭へ移行

- アイリス（HEAD D）の比較実験で確定した「急角度の面の線は消し、モデル外周と独立した可視メッシュ輪郭は残す」をセラ・訓練標的・ビットタランの共通 `SeraViewEdges` に採用。80°の隣接ポリゴン判定／表裏切替エッジリボンは廃止。画面に現れる背面ハルのみを3pxで拡張する軽量実装へ置換。FX・非発光・材質・アニメ・装備交換契約は維持。
- 先に `tools/sera_view_edges_self_check.py` と `tools/sera_view_edges_runtime_check.gd` を更新。90°の凸角でも原三角形だけがハルに入り、内部線の追加を生む角度リボンが無いこと、36頂点の立方体・FXツリー非適用・深度付き127優先度・3pxを確認する。
- 前回の比較画像はCPUによるオブジェクトID可視輪郭抽出。実GodotはGL Compatibilityと低負荷を優先した反転ハル方式のため、装甲が密着した細かな境界は実機で最終検査が必要。NEXUS室内の2px角線／BASE施設6px＋2px線は変更なし。

## 2026-11-22 — BASEの施設アウトラインをSERA同等の実メッシュシェーダーに修正

- 実機スクリーンショットでNEXUS等を大きな空間多角形が囲む不具合を確認。原因は`Geometry2D.convex_hull`で施設全体の部品8頂点をまとめたHUD側2Dアウトライン。スクリーンに投影したOBBや凸包からは正確なシルエットと遮蔽を得られないため、`base_exploration.gd`のHUDアウトラインを完全撤去。
- SERA本体の`SeraViewEdges._build_overlay`をそのまま使用して、建物の実`Mesh`（同一MultiMeshバッチ内の不透明な外装だけ）から隣接面の法線・80度以上のハードエッジ・三角化境界除去を生成。GPU shader`shaders/base_facility_view_edges.gdshader`がSERA方式の深度テスト・カメラ法線判定・ピクセル換算幅を適用する。
- 外側のシルエット／背面と前面の境目は6px。ユーザー追加要件に合わせ、**両面が前向き**の80度以上の折れ角を2pxで表示。奥に隠れた稜線は深度テストで消える。線色`#55798A`、不透明、地面や壁は透過しない。
- ポリゴン輪郭は`ArchitecturalEdgeInk_*`という材質別バッチのMultiMeshで描画。SERAのエッジメッシュを形状種ごとにキャッシュし、元モデルの当たり判定やマテリアルを書換えずに表示。既存30Hzの機械モーションで実体変換値を更新する際は、対応するinkのインスタンスも同じ座標へ更新し、クレーンや破砕機の線が外れないようにする。
- 煙、炉の炎、入口からの光漏れ、床反射、発光素材、施設外の小物にはinkバッチを生成しない。NEXUSの旧型・7設備のフラット形状・施設座標・触れる領域・GRID/CRATEを維持。
- シェーダーと描画本体の独立受け入れテスト`base_facility_mesh_edge_shader_*.`をCIに追加し、過去の2D凸包前提のテストを実メッシュ検証へ変更。実プレイカメラ720×1280のPNGレビューを必須とし、Android実機とは区別する。

## 2026-11-22 — BASE 8施設の6px外周/2px手前角ライン、炉煙と室内光

- 施設8棟は現行モデル（NEXUSは2つ前の旧型、他7施設は角張った形状）を維持。既存Batch中の外装・建材のみを`outline_solid_entries`に記録。発光材質（amber/blue_light/glass）や後付けエフェクト、拠点小物をマスクから明示除外。
- `SeraBaseFacilityOutlines`はBASE実ゲーム720×1280カメラで外観3Dメッシュの8頂点を投影し、全体の輪郭を実際の2Dピクセル太さ6pxで描画。手前向きの主要外装の3稜線を2pxで別描画し、輪郭だけでは隠れる手前側の角も表現。線色はUI規定ブルーグレー`#55798A`。カメラ移動時の再描画とGRID画面では非表示を実装。HUDの背後に描画。
- 入口/作業口8つに縦発光面＋床へ伸びる加算型光漏れを独立ノードとして追加。精製装置の2煙突から各21枚の軟らかな半透明CPUParticles3Dスモークが上昇・拡散。炉口直下の床に炎色の擬似反射面を追加し、炉の既存OmniLight3Dも時間関数で明滅（リアルSSRではない）。GL Compatibilityで動く処理。
- 全エフェクトの根本・メッシュ・粒子に`FX_NO_OUTLINE`を付与、アーキテクチャ描画バッチとは分離。新規3Dアニメーション・施設タップ/UI/CRATE/GRID/戦闘とは独立。既存の暗い照明設計を残す。
- 先行受け入れテスト（static＋本物のGodot BASEシーン）をCIに登録し、光漏れ8つ、煙2本、炉の光量揺らぎ、全施設のsolid-onlyラインマスクと投影多角形を調査。自動実画面PNGを撮影して確認。最終Android実機での見え方は別判定。

## 2026-11-22 — NEXUS室内3Dポリゴン角に2pxグレーラインを追加

- Blockbench由来の室内構造物・端末・扉・柱・壁・床を既存のMultiMeshのまま`nexus_polygon_edges.gdshader`の深度付き`next_pass`で描画。画面上で約2pxのグレー（#7E858E）を頂点ローカル座標と`fwidth`でエッジ抽出。中央の12角形整備パッドも専用モードで輪郭と側面ファセットを描画。
- レンダリング順序は新規`RENDER_ORDER.NEXUS_SURFACE_EDGES=-10`。既存の青白い`CanvasLayer`選択シルエットより下で、深度遮蔽を維持。発光パレット5/6/7、入口照明Quad、セラ本体・装備・カスタマイズ時の選択発光は変更しない。元のメタリック/ラフネス、バッチ数、拠点屋外、戦闘は維持。
- 事前に`nexus_polygon_edges_self_check.py`/`nexus_polygon_edges_runtime_check.gd`をCI登録し、`render_policy_self_check.py`の登録優先度期待値を更新。既存の`nexus_material_contrast_self_check.py`と選択発光/描画契約は維持。headless CIは視覚的な実機保証をしない。

## 2026-11-22 — v545 なぎ払いの当たり判定連動ループSEと3秒フェード

- 音源のピーク振幅は元音源で約0.97のため、+2dBでのクリップを防ぐ目的で埋込Oggの元PCMを約0.77倍（約-2.3dB）に調整。ゲームの再生音量+2dBとフェード時間は維持し、最終ピークは約0.94になるようにした。

- 添付「ダウンロード.mp3」は20.06秒ステレオ44100Hzで約4秒周期の繰り返し。約4.0秒を取り出してループ境界を補正し、16kHzモノラルOgg Vorbisに変換して`assets/bittaran_sweep_loop_data.gd`に埋め込み。Androidの初回インポート有無に依存せず再生可能な`AudioStreamOggVorbis.load_from_buffer`を採用。
- `bittaran_battle.gd::_sweep_hit_window_active`は従来どおり、前足ソース0.67–1.38秒／後足0.17–0.63秒・左右4脚、ダメージの1回ラッチから独立。当たり判定中は+2dB/1.0倍/ループ、終了で3秒線形振幅フェード、次のなぎ払い時は減衰解除して同じプレイヤーで音量復帰。リスポーン時プレイヤー停止。判定メッシュ・原本速度・ダメージ・揺れ・土埃は変更しない。
- 既存v544の足音減音設定がmainのBASE並行統合で戻っていたため、同時に歩行のみ-13dBと最大2重再生を維持。攻撃SE+4dB、BGM-8dB、既存4本の効果音データを維持。
- **検査先行**：`tools/bittaran_sweep_audio_v545_self_check.py`・`tools/bittaran_sweep_audio_v545_runtime_check.gd`を先に追加してCI登録。元の`bittaran_sfx_event_runtime_check.gd`には既承認の静音歩行の確認を追加。4脚境界・判定途中ヒット済み継続・3秒フェード・再入・リスポーン・元音源ロードを確認し、旧検査を削除/スキップしない。CIのGodot headlessとAndroid実音の質感は区別して報告。

## 2026-11-22 — BASE 8施設の機械動作を実体3Dパーツで追加

- 拠点8施設に、それぞれ用途に即した周期動作を実装。保存済みのNEXUS旧モデルと、他7施設の角張ったフラットな形状は維持。個別のMeshInstance3Dを複製せず、既存 `Batch` の物理パーツ名と材質別`MultiMesh`上のインスタンス番号を追跡し、`set_instance_transform`で実際の3Dパーツを更新する。
- NEXUS：旧通信アンテナの微小首振り・ビーコン発光体の拍動。LABO：3Dプリンターのサーボ/ヘッド/ノズルが同期して左右走査、造形物が段階的に伸縮。回収機：吊りケーブル伸縮・把持爪の昇降と開閉。精製装置：炉口の4本の熱炎が非同期に脈動。分解装置：2本の水平シャフトとその歯がX軸を中心に逆回転。電力制御施設：前面の4枚羽根が手前方向の軸で連続回転。保管庫：荷役リフトの上下移動。建設端末：青い設計図行の上下走査と通信表示灯の点滅。
- 通常の `_process` から30Hz以下で決定論的にサンプリング。ノードを各モデルに1つ追加するのみで描画バッチ、材質、テクスチャ、透過、光源、当たり判定を追加しない。既存発電所の `EnergyRotor` 制御は変更しない。
- 保存互換、施設位置・Yaw・倍率・タップ領域・小物・床・CRATE・GRID・機能/UI/戦闘を変更しない。
- 新規静的＋実Godotテストを先行登録。8施設全てで数値時刻を変更して実`MultiMesh`変換が更新されること、旧NEXUS維持と操作の不変、増分描画ノードなしを検査。専用BASE CIは通常カメラで静止・動作後の2枚の720×1280画像を撮影する。全main CIとAndroid実機の動きは別々に判定。

## 2026-11-22 — v544 ビットタラン歩行足音の音量低減

- ユーザー指示「ビットタランの足音が大きいな」。歩行の専用音源「ロボットの足音1」の出力を-5.0dBから-13.0dBへ8dB下げ、接地の同時再生音数を最大4→2に制限。音源データ・歩行接地タイミング・カメラ揺れ・土埃は変更しない。
- 攻撃予備SE `arm` +4dB、BGM -8dB、踏みつけ・弾き・なぎ払いのヒット音、倒れるSE・ダウンのけぞりSEと3被弾で次の踏みつけ確定を維持。
- **事前CI期待値更新**：`tools/bittaran_sfx_event_runtime_check.gd`（実オーディオプレイヤーの-13dB/同時2音と攻撃+4dB）、`tools/bittaran_sfx_event_self_check.py`（設定値とBGM保持）。元のイベント再生数・クリップ・素材形式検査は保持。統合後main全Python/Godot CI、Androidでの実際の聞こえ方を分けて確認。

## 2026-11-22 — v543 ビットタラン3被弾後の踏みつけ確定・攻撃音量調整

- セラの近接によるビットタランへの「実ダメージを伴う接触」を3回受けると、次にビットタランが出す攻撃を踏みつけに固定。実HPダメージ処理 `bittaran_battle.gd::_apply_target_part_damage` で1接触ずつカウントし、3回目で`bittaran_attacks.gd`の`guaranteed_stomp_pending`を立てる。攻撃中断時も維持し、次に前足3.7m/後足3.0mのどちらかの実足裏が踏みつけ可能な位置に入った際に、直前技の重複回避より優先してSTOMP選択。無理な距離から踏みつけを出さず、予約を消費した時にカウントを再開。リスポーンでは初期化。
- 攻撃開始の埋込SE（`arm`）-7→+4dB、BGM-5→-8dB、足先着弾thudはstomp -5→-3dB/kick -10→-4dB/sweep -9→-4dB。元MP3/Oggやトリガータイミングは保持。スピーカー音量や歪みはAndroid実機で確認。
- **テスト先行**：`tools/bittaran_three_hits_stomp_v543_self_check.py`・`tools/bittaran_three_hits_stomp_v543_runtime_check.gd`を先に作成・manifest登録。実ダメージ経路、3接触トリガー、射程外保留、前後脚、技の連発抑制の例外、キャンセルと再生成、SE音量を検査。既存のボス10分バランス・ダウン・SFXイベント検査は変更・削除しない。

## 2026-11-22 — BASEの丸み除去とNEXUS旧モデル（2つ前）復元

- ユーザー指示：「丸みを消して」「ネクサスは元のモデル(2つ前)に戻して」。
- 保存ブランチ `archive/base-models-20261122-before-rebuild`（`3ef30727c20c450991bb534b96548764703c4bbb`）のNEXUSを選択。NEXUSの先行改修、`NexusCutCornerShell` / `ArmoredRoof` / `GatePortal` / `SealedGate` / `FrontEmblem` / 上部保守室・サービスアネックスを含む保管済みジオメトリを、現行の`BaseArchitecture.build_nexus`に保存されている旧モードから再有効化。二つの新型モデルは削除せず、将来の比較・再切替に保持。
- **丸みをなくす対象はその他の7施設**。マテリアル・施設のIDと配置・バッチ数抑制・3D灯・画面タップ・GRID・CRATEを維持したまま、描画バッチで形状`bevel/drum/gear/hopper/canvas/tube`を直角の立方体へ解決し、円環は8面から4辺の角張った枠に置換。NEXUSはこの変換を適用しない。
- 仕様受入先行テスト `base_angular_archive_nexus_self_check.py` / `base_angular_archive_nexus_runtime_check.gd` を追加し、NEXUSの旧ジオメトリ有効・新型非表示・7施設の丸い造形不在・全施設タップ/カメラ/倍率を検査。過去の新造NEXUSを前提とする関連ランタイム期待値のみを先に旧版へ修正し、機能CIは保持。
- 実ゲーム720×1280スクリーンショットとmain統合後の全CIを照合。Android実機画面は別途実機確認。

## 2026-11-22 — v542 ビットタラン前足の踏みつけ範囲拡大

- **前足限定**で、STOMPの発動距離を実際の足先XZから3.00m→3.70m、攻撃の追従足先AABB横幅・奥行きを1.50倍→1.80倍に拡大。両前足共通。AABB中心は表示される足先メッシュを追従し、高さは従来どおり。
- 後足STOMPは3.00m／1.50倍で固定。前足と重複する3.10～3.70m帯では従来のSTOMP優先を維持。v541弾き、なぎ払い、実足裏基準の技選択、ダメージ、ピーク後のみ有効、1ヒット/攻撃、着地土埃、振動、音声、原本モーション・IK、その他バランス変更なし。
- **CIテストを先行更新**：`bittaran_attack_distance_priority_runtime_check.gd`（3.70m内前足STOMP優先）、`bittaran_kick_selection_v541_runtime_check.gd`（KICK自体の発動域を保持しつつ前足STOMP選択を反映）、`bittaran_stomp_follow_runtime_check.gd`（前足1.80倍、後足1.50倍と既存の最高点・ヒット・着地ガード）。
- 新規：`bittaran_front_stomp_v542_self_check.py`と`bittaran_front_stomp_v542_runtime_check.gd`をmanifest登録。新旧のフットローカル選択、前後AABB、攻撃判定中心を検査。GitHub Actions全件CIとAndroid実機での視認性/回避/命中率は別に記録。

## 2026-11-22 — 添付拠点リファレンスに合わせた8施設の再造形

- 施設の個別プロシージャルメッシュを、ユーザー提供画像の機械的特徴が読み取れる形へ再設計。既存の `scripts/sera_base_fresh_design.gd` を置換し、既にゲームで有効な `BaseFreshDesign.add_details` から描画する。スクリーンショットをテクスチャに使用しない。
- NEXUS：低い平屋バンカー、厚い正面エアロック、左の布製天幕／荷箱、右の排熱・管路・通信マスト。LABO：奥側だけを覆う天幕、開放した正面、発光ノズルの3Dプリンター、製作台、工具棚と端末。
- 精製装置：二本の縦煙突と正面の橙色炉口。分解装置：開いたV字の投入ジョーと二本の横置き歯付きローラー。発電機：横置き青色タービン、発光コアリブ、独立の制御盤。回収機：腕の曲がり目が見える油圧ブーム、吊りケーブルと開いた爪。資材保管庫：正面へ露出した積荷、後部のみの布カバー。建設端末：大型設計図画面と操作キー。
- 同一MultiMeshバッチ構造・金属の既存テクスチャ・温冷色照明・ゲームの27度正投影カメラ・施設位置とタップ領域・GRID移動・CRATE導線・ジェネレーター動作を維持。以前の新造型は今回のPR直前のmain履歴に、さらに古い型は `archive/base-models-20261122-before-rebuild` に保存済み。
- 既存 `base_fresh_rebuild` 静的／Godotテストに各施設の基準形状を追加し、既存8施設機能・配置・視点・スケール・25〜260個のバッチプリミティブ検査を維持。実画面キャプチャの目視、CI結果とAndroid実機は別々に判定する。

## 2026-11-22 — 添付拠点リファレンスに合わせた8施設の再造形

- 施設の個別プロシージャルメッシュを、ユーザー提供画像の機械的特徴が読み取れる形へ再設計。既存の `scripts/sera_base_fresh_design.gd` を置換し、既にゲームで有効な `BaseFreshDesign.add_details` から描画する。スクリーンショットをテクスチャに使用しない。
- NEXUS：低い平屋バンカー、厚い正面エアロック、左の布製天幕／荷箱、右の排熱・管路・通信マスト。LABO：奥側だけを覆う天幕、開放した正面、発光ノズルの3Dプリンター、製作台、工具棚と端末。
- 精製装置：二本の縦煙突と正面の橙色炉口。分解装置：開いたV字の投入ジョーと二本の横置き歯付きローラー。発電機：横置き青色タービン、発光コアリブ、独立の制御盤。回収機：腕の曲がり目が見える油圧ブーム、吊りケーブルと開いた爪。資材保管庫：正面へ露出した積荷、後部のみの布カバー。建設端末：大型設計図画面と操作キー。
- 同一MultiMeshバッチ構造・金属の既存テクスチャ・温冷色照明・ゲームの27度正投影カメラ・施設位置とタップ領域・GRID移動・CRATE導線・ジェネレーター動作を維持。以前の新造型は今回のPR直前のmain履歴に、さらに古い型は `archive/base-models-20261122-before-rebuild` に保存済み。
- 既存 `base_fresh_rebuild` 静的／Godotテストに各施設の基準形状を追加し、既存8施設機能・配置・視点・スケール・25〜260個のバッチプリミティブ検査を維持。実画面キャプチャの目視、CI結果とAndroid実機は別々に判定する。

## 2026-11-22 — v541 ビットタラン「弾き」発動距離・角度拡大

- 前脚 KICK の有効なAI発動域を、実際の前脚足裏からの距離3.75～5.15m→3.10～6.30m、ボス正面左右38°→60°へ拡大。固定極座標サンプルのカバー数210→750（約3.57倍）。これは発動条件の増加率であり、実戦中の発動頻度や命中率ではありません。
- 足裏の実ワールドXZ距離、踏みつけ3.0m以内優先、SWEEPの従来セクター、後足KICK禁止、直前同技の連発回避、攻撃モーション・原本接触メッシュ・ヒット時刻0.35～0.75秒・威力、ダウン・SE・カメラは維持。
- **テスト先行更新**：`tools/bittaran_attack_distance_priority_runtime_check.gd`の弾き距離境界と`tools/bittaran_keyframe_hit_sector_runtime_check.gd`の角度境界を先に更新。追加した`tools/bittaran_kick_selection_v541_self_check.py`・`tools/bittaran_kick_selection_v541_runtime_check.gd`は前脚左右の新判定、後足禁止、射程境界、STOMP/SWEEP共存、直前技の回避、ソース打撃ヒット窓を保護。全CI登録済み。
- Android実機の攻撃実頻度、空振り・カメラと攻撃前兆の読みやすさはheadlessのCIとは別に確認。

## 2026-11-22 — v540 Bittaran authored fall dust / synchronized impact camera / creator SE

- Following the owner's explicit source-time request, only rear-leg full-body fall FX has moved to author-key `0.75s`, while front fall FX stays `1.75s`; the actual DOWN countdown still starts only at the `1.75s` authored pose for **both**. This preserves full 2.5/6.0s hold, diagonal replant and stand-up.
- Shared `consume_body_fall_impact()` emits exactly once per collapse. On that very FX frame, the scene launches a strong vertical-only decaying camera offset and the uploaded `巨大ロボットが倒れる.mp3` as an Android-safe embedded Ogg.
- Additional creator MP3s embedded and routed: `ロボットの足音1` on finished walking ground contact, `巨大ロボットが腕を動かす3` when the authored attack entry begins (excluding stance setup), and `ロボットを強く殴る3` at the first break/recoil reaction. One-shot latches prevent repeated start sounds on normal ticks or multiple breaks during one fall.
- New asset: `assets/bittaran_sfx_data.gd`, all four original submitted sounds transcoded to 24kHz mono Vorbis at ~48kbps; no external URL and no `.godot` audio cache dependency. Existing attack thuds, background music and other effects remain.
- CI expectations updated FIRST in `tools/v534_bittaran_down_pacing_ground_replant_runtime_check.gd` and `tools/bittaran_body_fall_runtime_check.gd`. Added `tools/bittaran_sfx_event_self_check.py` and `tools/bittaran_sfx_event_runtime_check.gd` to `tools/sera_ci_manifest.txt`, covering original sound payloads, distinct rear/front source FX times, once-only punch/collapse/arm/footstep, unchanged down timer and large vertical shake. Final GitHub CI status must be recorded separately; Android physical-device sound/shake verification remains manual.

## 2026-11-22 — BASE施設8棟の完全新造（旧デザイン保存）

- ユーザー指示：「一から作り直してみて欲しい。現在のモデルは保存しておいて」。
- **元モデル保存先**：GitHub永続ブランチ `archive/base-models-20261122-before-rebuild` / SHA `3ef30727c20c450991bb534b96548764703c4bbb`。既存のBASE全モデル（旧建築・屋根・機械の材質・シーン）、床、小物、操作系、背景と全コードが作業前状態で復元可能。
- **本体**：新規独立ファイル `scripts/sera_base_fresh_design.gd` に8施設を完全新規モデリング。`scripts/sera_base_architecture.gd` の `ACTIVE_BASE_MODEL = "FRESH_20261122"` により実際の施設構築で使用し、旧形状生成モジュール6種を重ねない。バックアップの元関数は引き続き保持し、切替・復元可能。
- **形状方針**：NEXUSは司令バンカー／分割クラウンとゲート、LABOはテント式開放工房と独立巨大プリンター、回収機は大型油圧単脚クレーンと吊り爪、精製装置は双煙突の露出炉、分解装置はV型二枚の破砕ジョーとローラー、発電は回転翼付き大タービンと冷却タンク、資材保管庫は非対称に積み上げた大型コンテナ＋揚重機、建設端末は大画面＋操作台＋送信アンテナ。
- **維持するもの**：機能とUI、基本配置・回転・モデル倍率、各敷地パネル、タップ判定、レールグリッド・GRID遷移、CRATEルート、全既存素材とGL CompatibilityのMultiMesh描画バッチ、施設ごとの元の3D照明とGENERATOR/EnergyRotorアニメーション。
- **検証順**：旧仕様の原本コードを事前確認し、新規期待値を `tools/base_fresh_rebuild_self_check.py`/`tools/base_fresh_rebuild_runtime_check.gd` で本体に先行定義して登録。GLの実ゲーム画面を撮影・目視で改善し、局所CIとmain統合後のフルCIを実施。旧造形固有のテストは新造形へ更新し、影響しない機能・入力・素材のテストは維持する。

## 2026-11-22 — ビットタラン脚破壊デバッグUIの上部横一列化

- ビットタラン戦の「DEBUG / LEG BREAK」を、従来の左側2列×2行（x14/y322、334×158）から、ボス名・勝利表示の下（y276、勝利表示から12px離す）に位置する横幅いっぱいの薄いバーへ変更。
- 前左 → 前右 → 後左 → 後右の4ボタンを均等な1行で配置。各ボタンの高さ44px、間隔8px、幅128px以上を確保し、標準720px縦画面でプレイフィールドを覆う面積を縮小。
- ボス名（y186–220）、勝利表示（y230–264）、体力バー（y109/151）、NEXUS操作（右上）を隠さない。CanvasLayer、既存の入力排他処理・通常の部位破壊・デバッグ1回破壊・復活・10分バランスは変更なし。
- `tools/bittaran_four_leg_debug_runtime_check.gd` のレイアウト期待値を本体変更前に更新し、上部配置、同じY座標、左→右の脚順、クリック領域、タイトル非重複、既存の4脚ダウン・再破壊防止を検証。Android実機での可視性は別途確認。

## 2026-11-22 — BASE actual-screen visual hierarchy redesign and mandatory screenshot review

- Reviewed the real 720×1280 full-game screen (unchanged 27° orthographic BASE camera). The problem was **layers of overlapping girders, covers, duplicate crane arms, and warehouse cage rails**, not a shortage of detail. From gameplay scale LABO lacked a single obvious printer, the collector looked like an indistinct crossed-boom rig, and warehouse cargo was blocked by overhead lines.
- **Subtractive physical rebuild:** shifted LABO's redundant primary gantry backward, relegated tools and side workbench, darkened the floor and created one forward printer cell with parallel cool-blue rails, a clearly visible central housing/nozzle and printed object/bed. Recolored the collector's duplicate rear rods dark and moved them out of the focal plane; the forward hanging claw now has large solid caution-yellow cheek plates. Removed the warehouse's three-row cage pattern, retracted over-long upper roof beams and rear access hoods; the two front cargo cases stay exposed. No additional overall roof layer or facility enlargement.
- Facility names now live on **compact, dark matte blue-grey plates** anchored above each working face, sized to name length rather than spanning a fixed 190×40 transparent label across machinery. Existing names/underline and hit-test behavior are unchanged.
- **Second actual-image review:** the first Godot portrait screenshot exposed further overlapping LABO gantries and low-clutter salvage jaws. Moved functional/structural/reference printer rails behind the print cell; raised the recycler-style grabber to the visual foreground with contrast backing and aligned its cable. Re-captured the unchanged 720×1280 live BASE screen; the final revision is based on this visible second pass, not only on pixel projections.
- Broadened the automatic BASE visual workflow trigger coverage to **all relevant facility, deck, clutter, lighting/material and camera modules**, so future edits to a non-roof script cannot bypass actual screenshot creation.
- Diagnosed an existing main CI failure in `tools/v548_lab_font_mix_runtime_check.gd`: it inspected the asynchronous BASE scene after exactly two frames while the native startup overlay was still constructing the facilities. Kept all shipped font/glyph/UI assertions, and waited for the same bounded startup-completion condition used by the true-game screenshot; no skip, no pass-by-default.
- Added `docs/agent/BASE_VISUAL_REVIEW.md` and a required entry in `AGENTS.md`: any future BASE visual change must inspect the true previous screenshot, render a new fully booted BASE screenshot at the identical camera, compare both (including close crops as useful), and correct visual problems **before merging**. Passing pixel-coordinate tests alone does not establish visual quality.
- Updated registered static and Godot roof/game-camera feature expectations before changing model code; preserved positional, camera, model scale, single slab, CRATE, touch, gameplay and mobile MultiMesh constraints. Full CI required after main integration.

## 2026-11-22 — BASE startup loading: blue-white high-tempo sweep

- Added a procedural, texture/shader-free `LoadingSweep` to the existing dark `SERA / INITIALIZING` overlay. A tapered blue outer glow, cyan edge, icy inner band and white core travel left-to-right in a 0.78-second offscreen-reset loop. The foreground label and Android touch behavior are unchanged.
- Two `process_frame` waits between major construction phases allow the loading animation to repaint while the BASE is assembled; the overlay is freed upon completion.
- Registered new static/Godot loader-loop checks. Updated the BASE startup runtime check from a fixed four frames to a completion-bounded wait. Android visual/speed validation is still required.

## 2026-11-22 — Re-design BASE landmarks against actual gameplay camera

- **Acceptance viewpoint is the LIVE BASE scene**, not a custom beauty render: 720×1280, 38m orthographic height, camera position (21.0, 19.5, 25.0), target (0.0, 2.1, -2.2), elevation ≈26.9°. Pixel-scale review of the actual portrait screenshot showed that large overhead roofs were often more prominent than the machines, while parts behind central members remained visually lost despite detailed geometry.
- Retained the distinct NEXUS portal, clearly glowing SMELTER mouth/dual exhausts, visibly open RECYCLER and terminal screen; **did not enlarge** these already readable silhouettes. Four camera-dependent redesigns: LABO toolhead/nozzle and printed work on the **front +Z** face; SCRAP_COLLECTOR jaws and drop cable moved from behind the hopper to the foreground with wide gold jaw cheeks; GENERATOR's bright turbine ring given a darker separate backplate and three high-contrast bright rotor spokes on the visible plane; STORAGE's opaque roof/canvas confined to the rear, cargo tier stepped forward and two large differently sized/coded shipping cases exposed in the loading opening.
- The metal pad bounds, eight facility positions/yaw/model scales, roof upper-mass cap, CRATE movement, click hit areas, navigation and Android GL Compatibility stay unchanged. All features are reused within the original opaque batched materials: no added OmniLight/Area3D/MultiMesh nodes, no physics/gameplay/version changes.
- Registered **prior to implementation** new static and real Godot acceptance checks measuring primary visual landmarks' projected widths/positions **from the unchanged real camera** and ensuring the facility title does not cover their centers. Updated the CI visual capture to reject partial BASE boot and GRID-mode screenshots; it now captures only after the eight facilities and HUD are fully loaded. Test images are game frames, not stylized mockups. Full post-merge registered Python/Godot suite still required, with Android physical-device image confirmation separate.

## 2026-11-22 — BASE functional silhouette and material focal-point polish

- Refined the accepted **open, non-obscuring roofs** with a restrained front-view equipment identity pass, not extra broad roofs. All 8 facilities receive a readable focal point within the existing model batch: NEXUS outer blast-door frame and blue guide lights; LABO exposed printing toolhead/gantry and canvas safety hem; SCRAP_COLLECTOR raised heavy jib, hydraulic pivot and enlarged open grabber; SMELTER two unequal exhausts with visible heated collars; RECYCLER exposed opposing crusher jaw plates, V-feed edges and cutter-comb; GENERATOR glowing front turbine corona; STORAGE distinct flat steel cargo roof and loading portal; BUILD_TERMINAL bright screen border and shallow cooling fins.
- Existing engine materials, textured metal and cloth, per-device lights, MultiMesh reuse, 1.14/1.45/1.55 model scales, floor pads, yaw, navigable spaces, touches, CRATE patrol, gameplay and Android GL Compatibility remain unchanged. Changes emphasize the **machine role** from the fixed 720×1280 portrait viewpoint, without another layer of big covering structures.
- Updated registered static and Godot runtime acceptance-feature expectations **before** adding production geometry; retained prior readability caps, unique roof identities and structural tests. Inspect a genuine GL-Compatibility screenshot from the PR render job, then check full registered CI on main after merge.

## 2026-11-22 — BASE roof readability correction (supersedes earlier eight-roof embellishment)

- Reviewed the actual 720×1280 Godot BASE image: LABO roof hid the printer workshop; recycler/generator displayed overlapping pitched metal/canvas details; repetitive upper panels obscured functional outlines. User explicitly rejected this design as incomprehensible on first glance.
- **Replaced**, rather than supplemented, `scripts/sera_base_roof_identity.gd` with simplified, purpose-built shapes: NEXUS restrained flat roof/entrance stripe; LABO one rear single-slope fabric cover with open front; SCRAP_COLLECTOR exposed hydraulic boom; SMELTER uncovered dual chimney and a few heat ribs; RECYCLER open intake with narrow side shutters; GENERATOR uncovered arched turbine cage; STORAGE one flat corrugated cargo lid; BUILD_TERMINAL thin illuminated visor over the screen.
- Reduced old redundant canopy polygons in architecture/night/structural/silhouette/polish modules, so the user sees the actual equipment and work opening instead of several stacked wide roofs. Preserved 8 positions, yaw, single dedicated floor pads, 1.14/1.45/1.55 scale, interaction, CRATE navigation, existing emissive work lighting, Android GL MultiMesh batching, equipment/animation masters and all unrelated gameplay.
- Updated the registered independent roof static + live Godot CI contracts **before** editing the production modules. CI now rejects the previous oversized roof-feature vocabulary and oversized upper solid panels on the smaller facilities, verifies each distinct feature's real model metadata, preserved sizes and touch areas. Added a focused GitHub Actions BASE portrait capture PR workflow for human visual review.
- Separate the actual screenshot/manual visual inspection from static/Godot headless verification. Full `sera_ci_manifest.txt` suite is still required on main after merge.

## SERA v535 — ビットタラン4脚独立破壊デバッグUI（2026-11-22）
- ビットタラン戦のみ、画面左上寄りに「DEBUG / LEG BREAK」パネル（前左・前右／後左・後右の2×2配置）を追加。ほかのシーンには表示しない。
- 四肢は独立ボタンとし、押すと選択脚の残り部位破壊ゲージのみ一度で0にする。共通本体HP・予測シールドSP・セラのHP/SH・資源・素材報酬・セーブの攻撃記録は改変しない。
- 操作はAndroidタッチ・PC左クリックともゲームの生入力と排他的に処理し、ボタン領域から移動/攻撃/ガード操作を開始させない。
- 通常の部位破壊と同じダウン処理・攻撃中断・IK／戻りモーションを再利用。既破壊脚のボタンは無効化（DONE）、復活時は4本すべてリセットする。
- 既存の4脚各1回制限・4脚破壊後の胴体ロックと約10分戦闘バランスを維持。開発中のみ使う想定なのでスイッチ `DEBUG_LEG_BUTTONS_ENABLED` を実装し、配布時には無効化できる。
- CI: `tools/bittaran_four_leg_debug_self_check.py`、`tools/bittaran_four_leg_debug_runtime_check.gd` を登録し、実シーンのAndroidタッチ入力・4脚独立破壊・二重破壊防止・復活・通常ヒットとの共有を検査。UI実機の見え方はAndroid実機で確認。

## 2026-11-22 — GRID Ver.2.11の統合設計記録（文書のみ）

- `docs/SERA_GRID_V2_11_DESIGN_ja.md` を新設し、Ver.2.10までの採用方針（出撃帰還時素材/EP、10×10→18×18、3枠配置プリセット、ノード稼働OFF、蓄電池＋500EP、連結、ノード・拡張費、19装備レシピ、ビットタラン固有素材）とVer.2.11の戦闘支援6設備案を一本化。
- A装備を基準としたビットタラン約10分バランスは実戦未検証であり、戦闘支援の＋6%/＋10%等の値も本体調整後に再検証する暫定値として明記。既存8×8 GRID表示と旧版の分単位/熱/GP設計を混同しないよう`docs/BASE_POWER_GRID_V09_ja.md`から最新設計へリンク。
- 仕様記録のみ。Godotコード、UI、現行LAB素材精製2→1、19装備の無償試作、CI期待値、セーブ、バージョンは変更しない。変更するCI期待値はなし。既存GRID画面検査（`base_power_board_runtime_check.gd`、`base_grid_presentation_runtime_check.gd`）は保持し、実装時に新仕様の検証を先行追加する。

## 2026-11-22 — BASE roof identity pass (non-gameplay)

- Replaced the repeated station-sized gable roof foundation with eight differentiated forms while preserving the existing architectural batch and equipment behavior: compact NEXUS stepped blast parapet, LABO asymmetric sail, open SCRAP_COLLECTOR maintenance gantry, SMELTER exhaust heat fins, RECYCLER separated hinged lids, GENERATOR exposed roll cage, STORAGE staggered steel container lids, and BUILD_TERMINAL cantilevered data blade.
- Added `scripts/sera_base_roof_identity.gd`, integrated in `scripts/sera_base_architecture.gd`; narrowed the earlier generic canopies in night/structural passes so new profiles remain visible. No changes to station scale, yaw, floor pads, lighting, tap hitboxes, CRATE route or Android GL Compatibility rendering contract.
- CI contract written before production changes: `tools/base_roof_identity_self_check.py` and `tools/base_roof_identity_runtime_check.gd` registered in `tools/sera_ci_manifest.txt`. Runtime/Android visual checks and complete post-merge CI must be independently confirmed; do not equate static inspection with rendered screenshots.



## SERA v535 — ビットタラン10分討伐バランス（2026-11-22）
- 全身A・標準3段コンボを基準に、8秒ごとに1コンボ成功・四脚各12コンボ破壊・ダウン頭部合計5コンボ・残HPを胴体へ与える試算で約601.7秒を目標に調整。
- 本体HP2550、前脚720／後脚620／頭部150。脚への本体HPダメージ×0.75／頭部×2.5。破壊力と予測シールドは独立で維持。
- セラの全身A HP320・全身B HP416。各装備部位のHPを一律2倍とし、防御・EN・速度・攻撃力は維持。
- ボス専用攻撃威力は踏みつけ30、弾き22、なぎ払い28、腹部砲5.04、レールガン8.1／接触。共通トレーニング攻撃テーブルは変更しない。
- 脚破壊は一度のみ。4脚破壊後に胴体が常時攻撃／ロック可能。頭部はダウン中のみ攻撃可能、破壊後もダウン中の弱点として維持。
- モーション／IK・当たり判定・攻撃選択・シールドSP／SH／EN回復・報酬・セーブ形式は不変更。CI期待値を先に追加し、独立したGodot実シーン検証を登録。
- 約10分は操作・命中間隔を仮定した目標値。Android実操作による実測は別途必要。

## 2026-11-22 — NEXUS hangar opaque metal contrast (night task)
- The existing NEXUS Blockbench MultiMesh batches retain all transforms, sizes, geometry, camera settings, and the seven-index material mapping.
- Opaque structural palette indices 1–3 use metallic 0.28 and roughness 0.52 instead of 0.16/0.70 to separate plate edges under the existing directional light. Other indices and emissive accents 5–7 are unchanged; no new nodes, lights, textures or draw calls.
- Added `tools/nexus_material_contrast_self_check.py` and registered it in CI before editing the renderer. Python/Godot execution and Android visual validation remain pending; this change must not be described as visually verified.
- 6:00 follow-up: first updated the registered NEXUS material regression check, then set structural palette 1–3 `metallic_specular=0.42` (other palette entries retain 0.5) to restrain highlights without new meshes, lights, nodes or texture reads. Camera, pose, interaction, and preview layout were not changed. GitHub content readback is required; Godot/Android portrait screenshot and full CI remain pending.
- Handoff: run focused check and full registered CI on main after merge; capture NEXUS portrait screenshots, verify material highlights, model intersections, UI readability, and performance on Android.

## 2026-11-22 — アイリス指定のカメラ設定で既存19装備をGodot再撮影
- ユーザー提供SERA_ICON_PRESET_V1を`assets/ui/sera_icon_presets/H02.json`へ反映。旧26/-146°ではなくX=11.8749389648438、Y=156.900744628906、Z=0、auto_fit=0.76を全19装備に適用。素材・3Dモデル・UV・NEXUS_poseを維持。
- 撮影`sera_all_native_capture.gd`とPNGメタデータ`tag_all_icons.py`を共通プリセット参照に変更し、`validate_all_icons.py`で全19枚の値を検証。既存の設計図UIDやゲーム内アイコンキャッシュ/共通背景は維持。単体3D初期角度とLABO製作確認も合わせた。
- テスト先行変更：equipment_portrait_ui_contract_self_check.py、native_icon_metadata_self_check.py、godot_native_capture_self_check.py、front_right_orientation_runtime_check.gd。CIで19枚PNGを再レンダリングしPRブランチに書き戻し、マージ後mainでもフルCIを実行。実際の描画/Android表示はCI成果物と実機確認を区別する。

## 2026-11-22 — Bittaran：落下モーション可変速・4足床接地・復帰前踏み替え（v534）
- 最新ユーザー指定：原本0.0〜0.5秒は100→30%へ滑らかに減速、0.5〜0.6秒は30%、0.6〜1.75秒は30→基本55%へ加速。再生速度は「原本キーフレーム時刻」に対する割合であり、フレームレート非依存の分割積分で再生する。
- 部位破壊直後に原本0秒から再生し、原本1.75秒で停止する。モーション開始時点からは倒れ時間に算入しない。着地して初めて従来2.5秒／全脚6.0秒を計時、作者の1.75秒姿勢を維持する。
- 落下区間は原本メッシュ8頂点から足先最低点を毎フレーム抽出し、4本の実骨格IKでY=0へ接地。足先の埋没と浮遊を防止する。キーフレーム、原本メッシュ、14ジョイントUUIDは不変。着地時の胴体全域土埃6レイヤーは一度だけ発火。
- 計時満了後、胴体を起こさず2対の斜め脚ペアを計1.16秒かけて順次踏み替える。両組の接地後に従来1.0秒／1.3秒でC2補間の胴体復帰を開始。頭追尾と通常攻撃の既存契約は維持。
- 先行テスト`tools/v534_bittaran_down_pacing_ground_replant_runtime_check.gd`を登録、ダウン再生の旧等倍・短い予備動作・復帰後踏み替え期待値を改訂。GitHub CIとAndroid実機の検証は分離して記録。

## 2026-11-21 — Bittaran: 作者制作の4方向ダウンモーション統合（v533）

## 2026-11-22 — 装備3Dプレビューの縦ドラッグ回転方向を共通反転
- Godot共通装備プレビューのタッチ・マウスpitch加算符号を変更。LABO、倉庫詳細、NEXUS単体PART VIEW、Godot装備追加フォームへ反映。NEXUS全身のyaw専用ドラッグは不変。
- オフライン装備追加フォーム・Icon Studioテンプレート・配布HTMLにも反映。水平yaw、二指パン／ピンチ、初期角度・保存値は不変。
- CI登録前に上下方向の新仕様を定義したvertical_drag_self_check.pyを追加し、preview_runtime_check.gdに実タッチ・マウス方向の検証を追記。実機Androidは未検証。

- ユーザーが提供したBlockbenchモデルから前脚ダウン_L/R（各2.75秒・78キー）、後足ダウン_L/R（各2.00秒・62キー）を14関節の正本に追加。従来の正本メッシュ、14攻撃/移動クリップ、UUID、HEAD追尾は維持し、Android埋込JSONを同時更新。アップロード版の追加レール/目グループは正本の既存骨格と別のため採用せず、13ボーンのキーフレームだけを統合。
- 実戦で破壊された脚の前後左右に対応するモーションを1倍速で再生。0.60秒の予備動作からダウン保持まで同一ソース時刻を使用し、最終キーをループさせず保持。既存のダウン2.5/6.0秒と立ち上がり1.0/1.3秒を保持し、5次smootherstepでWait姿勢へ復帰。
- ダウン中の旧IKによる四肢/胴体の上書きと二重のルート下降を停止、立ち上がり後に既存の追尾、接地IK、歩行へ復帰。頭は独立した追尾と衝突回避を維持。
- 土埃の発生を旧0.17秒の手続き落下から実モーションの作者接地キー（前1.75秒、後1.00秒）へ変更。既存の6層広域土埃と1回発生の保証を維持。
- 先行CI: tools/bittaran_authored_down_self_check.py / tools/bittaran_authored_down_runtime_check.gd を登録、tools/bittaran_body_fall_runtime_check.gd の接地期待時刻を更新。Godot実戦映像・Android操作は別途確認が必要。

## 2026-11-21 — Bittaran: 胴体ダウン接地の広域土埃と起き上がり補間（v532）
- 通常の脚破壊ダウン2.5秒・全4脚破壊6.0秒、起き上がり1.0秒／1.3秒を維持。ダウン復帰量のみ3次smoothstepからC2連続の5次smootherstepへ変更し、開始・終了で自然な低速度に補間する。ダウン予備0.60秒、下落0.17秒、頭・脚の接地補正、攻撃、判定は維持。
- 最初の胴体着地0.17秒到達時、実BODYメッシュAABBの1.4倍のXZ範囲へ灰色の土・粉・砂・微粒子と岩片／砂利を1回だけ噴出。踏みつけの既存6層シェーダー・GL互換素材・深度テストを再利用し、独立エミッターで踏みつけエフェクトの残留を壊さない。石片は既存の地面接触MultiMeshへ回収。土埃はワールド固定で減衰。衝撃音と一度のカメラ振動を同時発火。
- すでに倒れている最中の追加脚破壊ではタイマーを更新するが、二重の胴体着地パルスは起こさない。新しい検査`tools/bittaran_body_fall_runtime_check.gd`をCIへ先行登録し、ダウン時間・補間・接地単発・胴体より広いFX・リセットを保護。
- **保留：ユーザーが制作した前脚・後脚ダウンのBlockbenchキーフレームは2026-11-21 23時時点のGitHub main/保管モデルにはまだ入っていないため、原本の反転・正本統合・実再生は未実施。** 原本同期後に左右ミラーアニメーションを統合・ランタイム検査する必要がある。既存の攻撃クリップは改変していない。
- 関連の共通CI修正：既存main上のGodot全件検査では、`tools/icon_studio/front_right_orientation_runtime_check.gd`のネストしたファイル名がそのまま`tempfile.TemporaryDirectory(prefix=...)`へ渡され、存在しないディレクトリに対する`FileNotFoundError`で中断していた。`tools/sera_ci_suite.py`の一時フォルダ名ではスラッシュを安全なハイフンへ変換し、テスト各件の隔離と全件実行は維持。対応する静的回帰テストを追加。
- CI成功・GitHub統合・Androidの視覚確認は実際の結果に基づいて別途記録する。

## 2026-11-21 — NEXUS CUSTOMIZE背景をマットなブルーグレー＋暗いグリッドへ変更
- セラの背後にあった青白い放射状ハイライト、発光中心、距離による明度・alpha変化を完全に廃止。シェーダーは単色ブルーグレー `#4A6B7D`（alpha 0.62）に暗いブルーグレー `#213944` のグリッド線（混合強度0.65）を重ねるだけとし、テクスチャ生成や発光計算は行わない。
- CUSTOMIZE画面専用の既存3D QuadMesh、画面全域1.0×1.0の投影、深度テスト、セラ前面表示、NEXUS UI/装備操作/保存/Android GL Compatibilityの描画ルートは維持。グリッドは42px間隔で画面固定し、キャラクター回転・位置で動かさない。
- 不要になったセラの頭/胴体投影による発光・グリッド基準点の計算を削除。既存のシェーダーリソースパス・内部変数名・表示/非表示遷移は互換性のため維持。
- 実装前に `nexus_labo_visual_self_check.py` と `nexus_labo_visual_runtime_check.gd` の旧発光期待値を廃止し、指定された背景・格子色、不透明度、発光式の不存在、全画面投影、グリッドの画素間隔を新仕様として固定。既存の7装備操作、閲覧/選択の分離、UIフォント等の検査は保持。
- Godot/Android画面での実際の透過・濃度・視認性はヘッドレスCIと区別して確認する。

## 2026-11-21 — NEXUSの両手武器ブロックCIの条件式依存を修正
- #647後のPR CI `44914959490` でPython登録テストのうち `v291_camera_lock_twohand_saya_self_check.py` だけが失敗。原因は装備名領域/展開ボタン分割時にブロック条件を `if blocker.is_empty()` から `if not blocker.is_empty(): return true` へ等価に変更した一方、旧テストが条件式の文字列そのものを検証していたこと。
- テスト期待値を**操作禁止時のearly return**に変更。右端展開での装備選択・左側閲覧専用の両方も継続検査。両手装備の選択禁止・モデル・セーブ・性能値は変更しない。該当Python検査以外の全登録テストは維持。

## 2026-11-21 — NEXUS CUSTOMIZE: 装備名の閲覧と右端の選択を分離・ウィンドウ再配置
- 装備行左の名前タップは装備切替を絶対に発生させず、現在装着中のモデルの3D単体プレビューと、その単体の実PartStats.PROFILES由来の性能を同期して表示。右端の2×2サムネイルボタンのみ従来の3列装備選択へ遷移する。両手武器ブロック・UID・保存・製作特性は不変。
- 720×1280縦画面では上段にTOTAL STATUS専用マットパネル（3/2/1列、スクロール可）、中段左にセラ全身3D、下段左にPART VIEW単体3Dと独立PART STATUSスクロールパネル、右に従来の7装備行を配置。上下の窓の間隔・センタリング・サムネイル展開ボタンのタッチ領域を保持。全性能と単体性能を別パネル・別スクロールにして他画面への漏出を防止。
- 単体基礎性能はLaboStats.complete_profile_textの元データを利用。個体UIDがあれば所持している該当UIDの5特性を追加列に表示するが、未承認の戦闘ステータス計算へ混入しない。0項目は既存のソース側非表示処理を尊重。
- テスト先行でnexus_split_inspector_{self_check.py,runtime_check.gd}を新規登録。装備名のみタップで選択ダイアログが出ない、展開ボタンでのみ出る、単体HP表示、ウィンドウの非重なりとページ遷移後非表示を検証。旧NEXUS共有視覚テストのCUSTOMIZE見出し期待値はPART VIEWへ変更。既存装備操作・セーブ検査は維持。Android実機画角・スクロール挙動は別途目視確認。

## 2026-11-21 — NEXUS CUSTOMIZE背景を画面全体の半透明ブルーグレーへ拡張
- CUSTOMIZEのセラ背面にある既存の単一カメラ追従3D QuadMeshを、縦横ともビューポート全域（1.0×1.0）に拡大。新しいSubViewport・テクスチャ・描画ノードは追加せず、既存のAndroid GL Compatibilityを維持。
- シェーダーの四隅も透明化しきらず、マットなブルーグレーの基底不透明度0.34を保つ。既存のシアン放射状発光はセラ本体の前面初期姿勢から捕捉した座標をuniformとして渡し、回転しても背景グリッドと発光中心は追従しない。画面中央にQuadMeshを固定するため、スマホ縦長比率でも左右端に不要な空白を残さない。
- 奥行き判定で機体を前面表示し、既存のカスタマイズ操作、両側メニュー、統計、装備選択・保存は維持。変更前に登録済みNEXUS/LABO静的・Godotランタイムテストを拡張し、全画面領域・背景透過度・発光中心・既存UIの不変条件を確認する。
- Godot/Androidの実画面での色、グリッド濃度、指操作、透過順序は自動静的検査とは別に確認する。

## 2026-11-21 — NEXUS装備選択ウィンドウの共通UIブラッシュアップ
- HEADなど7部位のSELECT PARTポップアップで、3列の選択カード、既存装備・製作UID・アイコンキャッシュ・ドラッグスクロール・タップで装備する処理を保持。モデル・ステータス・セーブ形式は変更しない。
- ウィンドウ外周をLABOと共通の欠け角スキン、上部をマットなブルーグレーに整理。画面名はMoralerspace Neon、装備名はUDEV Gothic Bold、UIDはMoralerspace Neonを使用する。閉じる×を見出しから分離。見出し下に#55798Aの細線。
- 各カードは8px内側余白・正方形サムネイル・日本語名・UIDの順で表示。名称に限って共通の3px青灰下線を付け、未使用のUID欄は空白にする。現在装備中のみ選択色の欠け角枠と下端2pxアクセントで示す。
- 縦スクロールバーと列間隔を引いてカードの実幅を算出し、右端カードのはみ出しを防ぐ。操作用レイヤーは従来どおりタッチイベントを横取りしない。
- 新規の静的・Godotランタイム検証を実装前にCI登録（nexus_part_picker_design_self_check.py / runtime_check.gd）。現行の装備名だけのセレクタ、既存ポートレート・装備切替・保存、NEXUS各画面の振る舞いは既存のCIで保護。Android実機での最終表示／操作とGodot本体CIは別途確認する。

## 2026-11-21 — LABOを画面下へ微調整・BASE施設8棟の形状更新
- LABOの設置座標を(6.26,0,5.80)→(7.15,0,6.95)へ。27°正投影で画面Xを維持しつつ地面の中心を画面y約0.670→0.687（約22px）へ下げる。全8施設専用床・タップ座標・UIラベルは既存のFACILITY_SPECSから一括再生成。ほか7施設の位置、入口Yaw、モデル倍率、GRID、CRATE、サルベージアンカーは変更しない。
- 各建物の主な平坦屋根を、実傾斜を持つ屋根パネルに再設計（LABO、回収機、分解、保管、建設）。LABOは左右二枚の角度の異なる天幕、Aフレーム屋根棟、補強トラスとロールアップ作業ベイを新設。分解機は傾斜した破砕ジョー／ピストン、精製機は高低2本の排気煙突、電力制御は外部冷却ドラムとガード、資材保管は高くした荷役口／テント棟、建設端末は片勾配屋根と整備ハッチ、回収機は重い釣合錘と斜めブレースを設ける。ネクサスは大きくせず外壁バットレスとルーフガターのみ形状精緻化。
- 新しい`scripts/sera_base_structural_mass.gd`を追加し、既存`sera_base_architecture.gd`のNEXUS／各施設生成時に利用。従来のマテリアルバッチ（MultiMesh）と不透明奥行き描画を維持。新たな独立描画ノード・コリジョン・ライト・シェーダー・ランタイム動作は増やさない。
- 仕様に対応する静的・Godotテスト期待値を本体変更より先に更新（isometric/tall-dense/inward/soft-center/lower-larger）。新規`tools/base_structural_mass_{self_check.py,runtime_check.gd}`をCI manifestに登録し、新形状の実ジオメトリ・LABOの画面位置・NEXUS縮尺・タップ領域・小物152個を検証。既存の回収機と建設端末からの画面下方向の余白と床の単板構造は維持。
- 直前の#638 CIは静的284件全合格の後にGodot並列実行の一時ディレクトリ不足（`FileNotFoundError`）で終了しており、Godot全件合格は未確認。今回の変更のmain統合後CIと画面撮影の結果を分離して報告する。

## 2026-11-21 — NEXUS装備一覧の名称左揃えとサムネイル展開操作
- CUSTOMIZEの7行について装着中の装備名称を左揃えにし、文字幅に追従する#55798A・1px下線を追加。装備名が長い場合は右側の専用操作領域を侵さず省略表示する。既存UDEV/Moralerspace混在のLABO共通フォントとマットな欠け角カード色を継続使用。
- 各行右端に最大48×48pxの独立したグリッド型サムネイル展開ボタンを追加。画像/外部文字グリフを増やさず4つのベクタータイルで構成。従来どおり行全体のタップでも既存3列スクロール式サムネイル一覧を開ける。片手操作・戻る操作・2手武器ブロック・装備UID・セーブ内容は変更しない。
- 本体変更より先に `tools/nexus_labo_visual_self_check.py` と `tools/nexus_labo_visual_runtime_check.gd` を更新。名称整列・専用右ボタンの寸法・下線・実際のタップでの3列一覧展開を検証する。既存CI manifestで両テストは登録済みで、ほかの既存期待値・テストは維持。Godot headlessとAndroid実機視覚検査は別扱い。

## 2026-11-21 — LABOを画面下へ微調整・BASE施設8棟の形状更新
- LABOの設置座標を(6.26,0,5.80)→(7.15,0,6.95)へ。27°正投影で画面Xを維持しつつ地面の中心を画面y約0.670→0.687（約22px）へ下げる。全8施設専用床・タップ座標・UIラベルは既存のFACILITY_SPECSから一括再生成。ほか7施設の位置、入口Yaw、モデル倍率、GRID、CRATE、サルベージアンカーは変更しない。
- 各建物の主な平坦屋根を、実傾斜を持つ屋根パネルに再設計（LABO、回収機、分解、保管、建設）。LABOは左右二枚の角度の異なる天幕、Aフレーム屋根棟、補強トラスとロールアップ作業ベイを新設。分解機は傾斜した破砕ジョー／ピストン、精製機は高低2本の排気煙突、電力制御は外部冷却ドラムとガード、資材保管は高くした荷役口／テント棟、建設端末は片勾配屋根と整備ハッチ、回収機は重い釣合錘と斜めブレースを設ける。ネクサスは大きくせず外壁バットレスとルーフガターのみ形状精緻化。
- 新しい`scripts/sera_base_structural_mass.gd`を追加し、既存`sera_base_architecture.gd`のNEXUS／各施設生成時に利用。従来のマテリアルバッチ（MultiMesh）と不透明奥行き描画を維持。新たな独立描画ノード・コリジョン・ライト・シェーダー・ランタイム動作は増やさない。
- 仕様に対応する静的・Godotテスト期待値を本体変更より先に更新（isometric/tall-dense/inward/soft-center/lower-larger）。新規`tools/base_structural_mass_{self_check.py,runtime_check.gd}`をCI manifestに登録し、新形状の実ジオメトリ・LABOの画面位置・NEXUS縮尺・タップ領域・小物152個を検証。既存の回収機と建設端末からの画面下方向の余白と床の単板構造は維持。
- 直前の#638 CIは静的284件全合格の後にGodot並列実行の一時ディレクトリ不足（`FileNotFoundError`）で終了しており、Godot全件合格は未確認。今回の変更のmain統合後CIと画面撮影の結果を分離して報告する。

## 2026-11-21 — BASEの上下方向の余裕と小物配置数2倍
- 俯角26.9°・正投影38・施設モデル倍率・入口Yawを維持し、8施設の実ワールド設置座標をカメラの画面縦方向に沿って5つの異なる高さへ移動。NEXUS (-13.44,0,-19.91)、精製(-12.61,0,-7.70)、分解(-1.85,0,-14.73)、保管(-3.43,0,3.92)、電力(7.37,0,-3.57)、LABO(6.26,0,5.80)、回収(9.95,0,22.18)、建設(19.49,0,15.88)。
- 画面中央点yの最上NEXUS約0.285→下段建設端末約0.861へ、上下の施設間隔を初期0.366〜0.843より拡張。画面Xの左右分布は概ね現状維持。全敷地は施設座標から再生成される単一金属板、タップ判定・ラベル・アニメも同一ルートとし、別メッシュの位置ずれを禁止。
- 周辺小物の総配置個数は76→152。元の76モデル／位置／積載・回転・拡大処理は保持し、24種の軽量な立体小物を既存大物の脇へ各1個ずつ計76個追加。元の物と周囲の物の回転・非回転矩形をともに判定。装置・入口の侵入禁止領域と床パネル中央の通路を避ける。安全な空間がない場合はスケールを段階的に下げ、敷地の空き位置を決定的に探索する。MultiMeshの材質バッチを再利用し、新しい独立描画ノード・シミュレーションはなし。
- 小物再配置プレビューは主モデル76個を移動した後に付属品76個を再パックする。コピー用JSONにもsatelliteフラグを追加。既存の不用品・資源・装備保存形式は変更しない。
- 仕様変更前に画面座標・上下分布と小物数の静的・Godot CI期待値を更新し、`base_tall_dense_composition_{self_check.py,runtime_check.gd}`を新規追加して全152個／追加76個と画面拡張の実描画シーンを検査。主要52群の密度リズム・24種の既存ユニーク小物・施設単一床・入口方向の保護条件は維持。
- Godot画面のスクリーンショットと全CIをmain統合後に確認し、Android実機での表示は別途確認する。

## 2026-11-21 — BASEカメラの水平寄り俯瞰と施設周辺の小物密度増強
- 720×1280ポートレート正投影・水平方位・施設全8件の入口向きは維持し、BASE Camera eye Y 25.1→19.5m（注視点Y2.1m）、俯角約33.8°→約26.9°に変更。建物の前面・天幕・排気機構が見えやすい低い俯瞰とする。GRID遷移は既存のBASE_CAMERA_POSITION定数に追従。
- 前回指定されたLABOからの下段距離を損なわないよう、回収機は(8.91, 0, 20.83)、建設端末は(18.56, 0, 14.68)へ。画面Xの変化を最小化するカメラ下向き世界ベクトル(+1.60,+2.10m)。既存6施設・NEXUS・モデルスケール・板床の仕様は変更しない。
- 施設周辺の独立した小物を従来68→76（8施設に1つずつ）へ増量。追加8種類はNEXUS: service_keypack、LABO: calibration_probe、SMELTER: slag_thermometer、RECYCLER: roller_bearing、SCRAP_COLLECTOR: claw_pins、STORAGE: cargo_latch、GENERATOR: flux_coupler、BUILD_TERMINAL: layout_marker。すべて実体3Dパーツ（ボックス・ロッド・リング）として1枚床の敷地内、既存装置／通路を避けた指定位置に描画。既存のMultiMesh Batchを再利用し、余分なノード・物理演算や非決定的ランダム要素は追加しない。
- 仕様変更前にCI期待値を変更。対象：`base_isometric_layout_self_check.py`、`base_lower_larger_composition_{self_check.py,runtime_check.gd}`、`base_natural_yaw_runtime_check.gd`、`base_soft_center_space_{self_check.py,runtime_check.gd}`、`base_inward_facilities_self_check.py`、`base_isometric_layout_runtime_check.gd`、`base_compact_prop_variety_{self_check.py,runtime_check.gd}`、`base_prop_stacks_runtime_check.gd`、`base_site_prop_variety_runtime_check.gd`。
- 主な保持条件：全施設を正投影画角内に表示・操作可能、LABOと下段2施設のY間隔、全入口の独立角度、8枚の施設単独床、床と小物の非干渉、52主要小物群の粗密リズム、各施設の小物種類の豊富さ。小物24個はすべて独立種類で、追加モデルも実装しCIで描画検証する。
- GodotのスクリーンショットとフルCIはマージ後に確認。Android実機の画面・操作感は別途確認。

## 2026-11-21 — BASE下段再配置のレガシーCI整合
- PR #635をmainへ統合した後の静的CI 283件中282件合格。残り1件(`base_inward_facilities_self_check.py`)は旧承認座標と8施設すべての中心方向距離を固定していたため、新規に下へ離した2施設の変更と競合。
- 既存8施設の独立Yaw・入口のカメラ正面向き・画面左右に応じた角度は継続検証。NEXUS、LABO、精製、分解、保管、電力制御の6施設については既存の中心寄せ不変条件を保持。
- 回収機と建設端末についてのみ新しい承認座標を採用し、旧画面構図から両施設ともworld x+2.61m/z+3.38m（画面約80px下方向）動いたことを数値で固定。テストの削除・スキップなし。
- CIフルGodot検査と実スクリーンショットで別途実描画を検証する。

## 2026-11-21 — BASE下段施設の間隔改善
- 実GodotスクリーンショットでLABOに回収機・建設端末が近接していたため、両施設だけを画面下方向に約80px分ずらす。施設位置は回収機(7.31, 0, 18.73)、建設端末(16.96, 0, 12.58)へ変更。横の画面位置が動かないカメラ下方向の世界座標(+2.61x,+3.38z)。
- NEXUS/LABO、残り施設、カメラの正投影、モデルのスケール、向き、CRATE、GRID、UI、施設別の装飾を維持。施設と一体の専用1枚床・タップ判定はFACILITY_SPECSから生成し追従。
- 変更前に、既存`base_isometric_layout_self_check.py`の画面期待値を下段2施設のみに更新。既存Godotレイアウト2検査の見切れ条件を下段用に更新し、LABOから画面Y方向で0.155〜0.16以上離す実行時アサーションを追加。全施設数・表示とタップの既存不変条件は保持。
- 実GodotスクリーンショットとフルCI、Android実機表示の検査結果はそれぞれ分けて報告する。

## 2026-11-21 — 倉庫装備詳細の閉じるボタンを正方形に固定
- 詳細ウィンドウ右上の閉じる「×」は従来の48×48px・色・角欠けフレームを維持し、HBoxContainer の縦方向の引き伸ばしを禁止。見出し中央に揃える。
- 専用静的/ランタイムCIへ正方形サイズと描画後の縦横比の検証を追加。ほかの見た目、UID、3Dプレビュー、装備性能、操作・セーブは変更なし。

## 2026-11-21 — 装備19種類のサムネイル前後逆修正
- ユーザー報告：正式装備PNGで背面が前面として撮影されていた。原因はカメラ+Z側に対する旧撮影回転X=+26度,Y=-34度が、NEXUS_poseの正面ローカル-Zと逆向きになったこと。
- 全19種の生成角度をX=+26度,Y=-146度,Z=0度へ変更。カメラからモデルの-Z正面/+X右/+Y上が実際に見える向き。H02/武器を含む全設計図に同一角度を適用し、中央余白・ポーズ・材質・元Blockbench・UID・5特性・静止キャッシュに変更なし。
- ゲーム内単体3Dの初期ビューも同じ角度に統一。PNGメタデータも更新し、GL撮影から19枚再生成する。
- 独立Godot CIでカメラ方向と正面・右・上の内積を検査し、前後逆／左右逆／底面を検出。既存ポーズ/余白/全19種/データ保存の検査は維持。Android実機の最終目視は区別する。

## 2026-11-21 — 倉庫装備詳細ポップアップの視覚階層を再構成
- 既存のセーブ・個体UID・5特性・3列表・3D実機材・タッチ回転・戻る動作を変更せず、倉庫の装備詳細だけをマットな欠け角フレームで再構成。
- 上部に「03 / STORAGE」「EQUIPMENT DETAIL」の小さな技術ラベルと薄いブルーグレーの区切りを配置。主見出しは装備名＋下線・UID・既存アイコンとし、右側に現在のお気に入り(黄)／不用品(赤)のベクター状態アイコンを表示。
- 3Dプレビューの周囲を暗い額縁で囲み、回転案内と性能表セクションを分離。プレビューの正方形・サイクル矢印・#111e28グリッド・描画の開閉時制御を維持し、余白とテーブルの配分を調整。
- 下部はネイティブの斜め欠け角ボタン＋同じベクター星／ゴミ箱を使用。選択時のみ黄色／赤の細い枠で状態を明示。文字化けの原因となるUnicode星のボタン文字は使用しない。
- 旧倉庫一覧の2列仮想化、統計の集計式・書体・単色表、保存契約は不変。CI登録前に新画面のPython静的＋Godotランタイム検証を追加し、旧倉庫/性能テストを維持。Godot/Android実描画とタッチを別途確認する。

## 2026-11-21 — BASE縦画面下部の余白を使った構図・施設規模の調整
- 720×1280の実Godot撮影画面を基準に、下部の床だけが広く余る構図を改善。BASEの正投影38、視点の俯角・方位・施設のワールド座標を維持し、カメラ視点と注視点を同時に2.1m上昇。結果として建物群が画面内で約59px下へ移動。
- NEXUSは既存1.14倍を維持。LABOは1.28→1.45倍、ほか6施設は1.36→1.55倍へ。天幕・換気扇・ドア・排気筒と照明を建物モデルとともに拡大。基礎床の区画、GRID遷移、施設タップ座標、CRATE移動経路、周辺小物の独立スケールは保持。
- 仕様変更に先行して、歴史的な数値を固定していたisometric/center/visual/night各静的・ランタイムテストの期待値を変更し、`base_lower_larger_composition_self_check.py`・`base_lower_larger_composition_runtime_check.gd`をCIに登録。
- CI画面はAndroid実機の操作・可読性の保証ではない。Godotスクリーンショットで施設の見切れ・名前・床面・周辺小物の視覚的整合性を別途点検。

## 2026-11-21 — 装備19種の共通俯瞰撮影と倉庫・NEXUS操作UI改修
## 2026-11-21 — 夜間BASE大型化に伴う旧CI期待値の修正
- BASE新仕様の局所検査導入後、既存CIが2件失敗：床の照明エネルギー旧値固定、施設サイズ旧値固定。いずれも旧仕様の上書きで、新承認に合わせ更新する。
- `base_floor_contrast_self_check.py`は床6種類の暗い金属色、材質、床・基礎の明暗差など元の本質的条件を全維持し、環境光0.38・太陽光0.36の夜間仕様へ確認値のみ更新。
- `base_visual_enlargement_self_check.py`とランタイムテストはNEXUS 1.14倍維持、LABO 1.28倍、その他施設1.36倍へ値を統一。描画バッチ、設置面、カメラ、操作など不変条件は変更しない。
- 追加実装の確認はGitHub Actionsの完全CIが必要。ユーザーに実描画スクリーンショットの未取得を明示する。

## 2026-11-21 — BASE夜間工業ヤード：7施設大型化・構成要素・作業灯の強化
- NEXUS本体は承認済み1.14倍のまま据え置き、LABOを1.28倍、ほか6施設を1.36倍へ変更。既存の俯瞰Orthographic・各施設の斜め向き・操作・床の専用1枚パネルは維持。
- ポリゴン直編集層 `sera_base_night_facade.gd` を追加。各施設の布製天幕、正面の立体扉、円形換気ファン、屋根・換気フード、精製装置の高い煙突を目立つサイズで造形。既存の材質別MultiMeshへ統合し、ポリゴン・テクスチャ・UI資産とセーブに影響なし。
- BASE世界環境を夜間の青灰色へ変更。ambient=0.38、directional=0.36、既存4灯を保持して不足する4施設にも局所OmniLightを追加。無影点光源8基、暗い鉄床と暖色の作業灯／寒色の機械灯を共存させ、発光材の強度を高めた。ライト座標と照射距離を建物倍率に追従。
- 工場の大型化に合わせ、小物は既存の固定アンカー・重ね積み・床境界・入口安全判定を維持して最大1.34倍まで条件付き拡大。積荷の角金具、作業灯の遮光板と光源、廃材ボックスの警告ラインを追加。独立MeshInstanceや処理ループを増やさない。
- 実装に先行して独立した静的・Godotランタイム検査を登録し、既存の小物サイズ回帰検査だけ承認済み上限に対応させた。頭部・バトル・GRID・HUD・保存形式に変更なし。Android実機の視覚評価はCIとは別に行う。

## 2026-11-21 — CI訂正：承認済みの暗い鋼板6色を維持
- PR #625の床の明度変更は旧仕様「施設と床の明度差を保ち、床は暗いチャコール」の`base_floor_contrast_self_check.py`（最大輝度0.030）と`base_facility_single_panel_self_check.py`（#1e2326）を違反した。床の6色だけを従来の`#1e2326/#252729/#292b2a/#27292c/#21262a/#302c29`へ復旧。
- 新規の床色・布色テストは先に旧床色の独立契約へ更新し、現行の床は暗いまま。床ジオメトリ・UV・6材質バッチ・外周排水溝・保護金具、施設8種の新しい3D構造、NEXUS左前側への大きな天幕、落ち着いた布の色は維持。
- 従来テストを削除・無効化・閾値緩和せず、mainの全登録CIを再実行して確認する。

## 2026-11-21：金属床の視認性とNEXUS左側天幕の修正
- 直前のGodot720×1280実描画では、全体の床が暗く、サルベージヤードの金属板・工業設備の階層が写真リファレンスより判別しにくい。一方で施設と床が似すぎないように暗い床を維持することが既存仕様。床の6色バッチを(#292d33/#303336/#323432/#303339/#2b3237/#34312e)にそれぞれ調整し、全成分を0.23以下、金属のroughness0.94と施設外装との明度差を維持。現行の大型床板の割当・カメラ・床面高さ・UVと材質バッチは変更しない。
- LABO/コンテナ天幕の基礎色を#78776eから#68685fへ落ち着いた灰茶に変更し、床を少し明るくしたときの画面中のコントラストを調整。
- NEXUSの布製横張り屋根が元の主外壁に埋まり目立たなかったため、左前方へ約0.8m張り出し、3枚の屋根の幅・奥行きを増加。対応する支持柱、天幕筋交い、下の貨物も位置を合わせて移動。原点から最大約4.1mで既存NEXUS専用10.5m床から張り出さない。
- `base_functional_finish_self_check.py`の既存布色期待値を先に更新、新規`base_palette_canopy_self_check.py` / `base_palette_canopy_runtime_check.gd`をCI先行登録。6床色の実材質、低反射、LABO/NEXUSの実布色、布の張り出し位置を検査。
- GRID/基地のタップ/CRATE経路・設備配置・カメラ/保存/元モデル・ゲーム機能は変更しない。最終のGL撮影とAndroid実機での可読性/FPSは別。

## 2026-11-21：工業構造と接地感の第4段階ブラッシュアップ
- Godot720×1280実画面と最初の参考画像を比較。装甲・曲面を増やしても設備の機能構造、炉/ロボット/作業台の読みやすさと、設備の接地感が不足していた。
- `scripts/sera_base_functional_finish.gd`を追加し、既存8施設を同じ回転軸・サイズのまま物理的に具体化。NEXUS：屋上保守通路、はしご、壁面整備ハッチと換気フィン。LABO：二軸式プリンターガントリー、工作床レール、収納、診断モニター。回収機：関節を辿る油圧ラインと接続部、機体据付座。精製炉：側面断熱リブ、排熱ライン、鋳造トレイ。分解装置：投入口保護縁、駆動軸、搬出スリット。発電機：巻線の保護バー、電力ケーブル、コイル表面。資材保管：荷捌き架台、取手、通気口。建設端末：モニター上の作業灯、操作盤、支柱。
- `sera_base_floor_detail.gd`の **8施設の専用一枚床パネルだけ**、端から34cmの外周2か所に短い排水溝・羽根、四隅の接地固定金具を追加。床中心の新たな分割線、経路遮断、施設の接地高さ・各施設へのタップ判定の変更はない。これらは既存の床`MultiMesh`バッチへ追加する静的な箱面であり新規フレーム処理や当たり判定はない。
- 天幕の基礎色を#8c8b80→#78776eに微調整して明るい屋根の浮きを軽減。既存の512px布テクスチャ、その他のカラー、6色の暗い床と低反射材質を保持。
- 新規CI`base_functional_finish_self_check.py`／`base_functional_finish_runtime_check.gd`は先に作成・登録。8施設の実シーン/多重インスタンス、8枚の床の排水溝16組以上・固定金具32個以上、機能操作に影響しない不透明静的描画を検査。
- 位置・回転・床パーティション・グリッドと電力制御・CRATE巡回・NEXUS/LABO/倉庫操作・セーブ・canonicalモデルには変更なし。Android実機FPSと実画面でのディテールの視認性は別途確認。

## 2026-11-21 — 参照画像に向けた施設サイズ・NEXUS左右非対称改修
- スクリーンショットの確認：床とUIに比べ施設の見かけが小さく、NEXUSの両側は同じ装甲外観で密度が不足。従来のカメラ`BASE_ORTHO_SIZE=38`・施設間の配置・入口の向き・タップ範囲は維持。
- バッチ処理の`detail_scale`をNEXUS1.14、LABO1.10、他6施設1.13に設定。建物モデル・機械・布・配管の頂点位置と大きさを原点基準で一体的に伸縮し、接地位置を保つ。実際に施設の床に置く資材・スクラップ等の散らし小物は、その直前に`detail_scale=1.0`へ戻すため従来のまま。
- NEXUSの左側に低い面取り整備棟＋大きい勾配屋根＋複数の本物の立体ルーバー、右側に少し高いスイッチギア棟＋勾配屋根＋側面換気口を追加。張り出しの最外端が1.14倍でも既存NEXUS専用鋼板（10.5m級）内に残るよう設計。
- 両棟のボディ・屋根・換気口は既存の頂点編集`ArrayMesh`を共有し、材質別`MultiMesh`へ統合。個別MeshInstance3D/Collider/新規ライトなし。実装前に`base_visual_enlargement_self_check.py`と`base_visual_enlargement_runtime_check.gd`をCI登録し、1施設につき1建物・8施設の造形表示、NEXUSの両翼、各拡大係数を検査。
- 最終目視・実機FPS評価は別。拠点GRID/セーブ/装備制作/UIの挙動には変更なし。

## 2026-11-21 — 拠点3Dメッシュの頂点陰影仕上げ
- 実GL画面を比較すると、直接編集ポリゴンの輪郭は改善したものの、同一材質の上面・斜面・側面が似た明るさで立体感が弱い。共有`SurfaceTool`の三角面で、外向き法線に応じた0.62〜1.04倍の明暗を各頂点カラーとして事前生成。上面・前面・側面・裏/下面のコントラストを作る。
- 建築の`ArrayMesh`ポリゴン材質だけ`vertex_color_use_as_albedo`をONにし、従来のcube/tube・光源の材質には適用しない。床は既存の共有ベベル鋼板ArrayMeshで同じ頂点カラーを使用。テクスチャ/元の材質・金属反射/ラベル/タップ/物理/UI/施設座標は維持。
- ドローコール・テクスチャ枚数・フレーム単位のシェーダー/オブジェクト計算・追加ライトはゼロ。CPUが初回共有メッシュを生成するときにしか陰影係数を計算しない。
- `base_silhouette_refinement_self_check.py`、`base_silhouette_refinement_runtime_check.gd`の期待値を先に更新し、頂点カラー配列と明暗差（0.15以上）を要求。既存の法線、UV、時計回り表面、全8施設の形状チェックを維持。

## 2026-11-21 — BASE施設のシルエットと奥行き再設計
- 実Godotスクリーンショットの自己点検：面取りポリゴン導入後もNEXUS上面や外周施設が箱形の集合に見え、画面中で正面/側面の奥行きが弱かったため、実形状の区別を強化。
- `sera_base_polygon_meshes.gd`に２種の直接編集三角メッシュを追加。`roof`は6点断面の勾配屋根（妻面と両斜面、段差）、`louver`は裏側が開いた構造の側面枠＋5枚の物理的な斜め羽根。外向き法線・Godot時計回り面・UVを生成し、静的ArrayMeshを各施設で共有する。
- `sera_base_silhouette_refinement.gd`を追加。NEXUS＝せり出し入口屋根・屋上勾配換気カウル・サイド換気口・ドア装甲。LABO＝布製天幕前縁の立体軒・張力コード・側面換気扉。回収機＝可視のギアケース・2重油圧ブーム・角度付き排出口。精製＝煙突を避けた勾配カウル・炉口側面保護・側面吸気。分解＝ルーバー付き駆動箱・傾斜投入口・ガード。発電＝冷却ルーバー・配電上部フード・コア支え。倉庫＝勾配布屋根・A字補強・荷の前面フード。建設端末＝モニター庇・側面吸気・斜め支持材を追加。
- これらはすべて既存`Batch.poly/poly_tilt/rod/box`に登録し、同材質は従来の`MultiMesh`にまとめる。新規MeshInstance3D/Light/Collision、テクスチャ、描画シェーダー、フレームごとの処理は追加しない。
- NEXUS/他7施設の建物根本、拠点での位置・角度・タップ判定、床1施設1パネル、CRATE、GRID、NEXUS/LABO機能、UI、素材テクスチャは保持する。
- 先行CI：`base_silhouette_refinement_self_check.py`と`base_silhouette_refinement_runtime_check.gd`を追加・マニフェスト登録。GDScriptでの形状の非退化、法線と表面順、実シーン各8施設の追加メッシュを検査。実画面とAndroid FPSの最終確認は別。

## 2026-11-21 — BASEポリゴン生成のコンパイル停止を修正
- PR #617の実GL描画で全床・多角形施設が表示されなくなった直接原因は、`sera_base_polygon_meshes.gd`で`_mesh_cache`を参照しながら宣言し忘れたことでした。Godotの実行ログに`Parse Error: Identifier "_mesh_cache" not declared in the current scope`、続いて`Nonexistent function 'make'`が記録されていました。
- `static var _mesh_cache: Dictionary = {}` をクラスレベルに明示。ポリゴン7種の`ArrayMesh`を安全に再利用し、各施設のバッチ生成を復旧します。
- `base_polygon_geometry_self_check.py`に宣言チェック、`base_polygon_geometry_runtime_check.gd`に全7種の同一インスタンス共有テストを先行追加。ポリゴン頂点・材質・配置・床面Y・タップ/セーブ等のゲーム挙動は変更しません。

## 2026-11-21 — 直接ポリゴン面が消える不具合を修正（背面カリング）
- 実GLスクリーンショットで床と8施設の大部分が消える問題を検出。共通`SurfaceTool`で、外向き右手系法線に揃えた頂点順がGodotの時計回り表面規則と逆になっていたことが原因。
- 三角形のGPU送信順だけ`[a, c, b]`へ反転。面の幾何形状・メッシュサイズ・UV・外向き法線・`MultiMesh`・描画パス・材質・カメラ/タップ/セーブは不変。
- 実Godotで全7メッシュの各三角形について、ジオメトリ法線と設定済み外向き法線の内積が-0.96以下になることを検査。`base_polygon_geometry_self_check.py`にも時計回り前面契約を追加。片面カリングを無効化して隠すことはしない。

## 2026-11-21 — BASE：直接編集した三角ポリゴンによる全8施設・床の形状刷新
- `scripts/sera_base_polygon_meshes.gd` に7種類の実ポリゴン原型（deck/bevel/hopper/hood/canvas/drum/gear）を作成。各面の三角形頂点、外向き法線、塗装/布/床用UVを自前で定義する`SurfaceTool`構造です。使い回し時は共有ArrayMeshを取得し、既存の材質別MultiMeshに配置するため、毎フレーム生成しません。
- NEXUSの主壁・屋根・ゲートを8角面取り、装甲板・配電ボックスを多角化。LABOの天幕は4×4ポリゴングリッドをたわみ・張力皺・厚み付きで再構成し、開放された機械室を維持。
- 回収機の広口ホッパーは外側斜面・内側斜面・上縁まで面として構築。精製炉は角落とし本体と蓋、分解装置の5本の歯付き回転ドラムは軸方向を合わせた手動ポリゴン、発電機コアは16分割ラジアルドラム。
- 資材保管庫は面取りコンテナ本体と布カバー、建設端末は斜めの多角形フードと角落とし筐体を実装。全施設の主要基盤・機械ガードにも多角形を適用。
- 床は従来6色の同一MultiMesh配置・Y=-0.03の天面・パネルの論理領域・施設ごとに1枚の床を維持し、3Dの床板メッシュだけ8角のベベル付きに差し替え。下地があるため、角の切り欠きにも隙間から空が見えません。
- 既存テストのうち旧BoxMeshを前提とした`base_uneven_deck_self_check.py`、`base_uneven_deck_runtime_check.gd`、`base_exploration_runtime_check.gd`は、新しいArrayMeshの頂点・描画・配置を独立に検証するよう先行更新。新規`base_polygon_geometry_self_check.py`＋`base_polygon_geometry_runtime_check.gd`をCI登録。
- 既存の素材SVG、ベースカメラ、光源、施設位置・タッチ判定、CRATE巡回、GRID、NEXUS/LABOメニュー、装備データ、原本.bbmodel、セーブを変更しません。Android GL Compatibilityと低描画負荷を維持します。

## 2026-11-21 — LABO装備製作確認の縦長レイアウト＆正方形3Dプレビュー
- 添付Android画面の細長い装備画像と下部余白を修正。製作ダイアログのみ上下アンカー0.105〜0.895へ拡大し、その他確認操作は従来のコンパクトな高さを維持。
- 製作確認を「見出し／装備名／中央の正方形3D・静止画像／モデル回転案内／基礎ステータス／確認質問／作成・キャンセル」の縦配列へ再構成。正方形`LaboConfirmSquarePreview`の比率1.0を保証し、画面幅と高さで一辺248〜380pxの自動サイズ調整。
- マットな濃紺の面・細いブルーグレー境界・UDEV/Moralerspaceの文字階層。元の実3D単体プレビュー、ブルーグレーグリッド、ドラッグ回転、セーブ/UID/ステータス計算を維持。
- 旧v553の製作確認のサイズ検査を先行更新、新規`labo_square_craft_confirmation_self_check.py`と`labo_square_craft_confirmation_runtime_check.gd`をCI登録。Android実機のタッチ・読みやすさは別途検証。

## 2026-11-21：拠点工業材質の追加ブラッシュアップ（テクスチャ込み）
- `assets/base/industrial_armor_chipped.svg`（512px）：装甲の塗装摩耗、下地露出、細かな引っかき傷、薄い垂れ汚れ。NEXUS/LABO/全6設備の塗装系外装に共通。
- `assets/base/industrial_oxidized_metal.svg`（512px）：構造金属・熱機械の酸化皮膜、擦れ、錆の斑を追加。rust/gold材質のみに適用。
- `assets/base/industrial_deck_wear.svg`（512px）：暗い床色を損なわない擦れ、油跡、軽い補修傷。6色の既存床MultiMeshを維持し、UVオフセットと倍率を材質ごとに変えて模様の反復を軽減。
- `assets/base/aged_canvas_weave.svg`（512px）：天幕の織り目・折り皺・縫い目・雨汚れを再制作。既存パスは維持し、LABOなど既存の布面に反映。
- 全てSVGの一回だけのGodot画像インポートで、ランタイムのピクセルノイズ/新規シェーダー/描画パス/新規3Dノードは追加しない。小物・建物は既存材質別MultiMeshを再利用。透明エフェクト、青/橙の光源、設計図の鮮明さは維持。原本bbmodel、カメラ、施設配置、セーブ、NEXUS/LABO/GRID操作を変更しない。
- CI先行登録：`base_surface_textures_self_check.py`・`base_surface_textures_runtime_check.gd`。材質ファイル、読み込み先、全8施設での実バインド、6床バッチ、反射係数と発光の保護を検査。
- 起動初期の表示先行（2フレーム）を尊重し、`base_reference_architecture_runtime_check.gd`／`base_reference_polish_runtime_check.gd`／`base_floor_contrast_runtime_check.gd`／`base_material_weathering_runtime_check.gd`は、シーンの建築が完成してから検証するよう待機条件を修正（検証値は維持）。
- モバイル性能と最終画面品質は実機確認が必要。前回のmain Godot CIはこの修正以前から多数の起動待機依存テストで失敗しており、今回のテクスチャ変更とは別に未解決のケースもあり得る。

## 2026-11-21：参考画像準拠の全施設・鋼板ディテール再調整
- 新規 `scripts/sera_base_reference_polish.gd` に8施設固有の建築仕上げを分離。NEXUSは屋根補強・機器箱・正面踏板・天幕筋交い、LABOはガントリー式製造ヘッド・開放作業棚・テレメトリー、回収機は油圧継手・ホース・追加把持歯を増設。
- 精製装置は耐熱円環・煙突の段巻き・鋳型、分解装置は傾斜投入口・鋸歯・排出スクラップ、発電機は冷却フィン・青色巻線、保管庫はコンテナ波板・結束材、建設端末はディスプレイ内の3D設計線・ひさし・配線で外観を差別化。
- 細かなボルト・配線・角度付き板は既存の`Batch`に追加して材質別`MultiMesh`で一括描画。新規のCollider/Light/毎フレーム処理なし。既存の個体ID、配置、1施設1床パネル、CRATEの巡回、GRID、NEXUS/LABO操作は変更しない。
- `sera_base_floor_detail.gd` の一般鋼板上に短い溶接跡、補修スクラッチ、補助リベットを増設。専用施設板には増設せず、床の暗い6色、素材SVG、反射率、面積、既存の溝・警戒線を維持。
- 先に `base_reference_polish_self_check.py` と `base_reference_polish_runtime_check.gd` を作成してCI登録。描画バッチ実体および全8施設の固有造形を検査する。Android実機の光量・FPS・可視性は別途評価。

## 2026-11-21 — 装備アイコンの欠け角テックフレーム
- 共通表示合成`scripts/sera_icon_background.gd`へ、四隅45度カットの8辺フレームを追加（#6F93A3）。左上と右下にだけ#9FD7E6の短いアクセント、トップ右と左下に薄い補助線。グリッド背景#111e28＋#55798Aは既存のまま。
- 元PNG・旧アトラス・モデルを変えず、背景・装備アートの上に一度だけ線を焼き込む。72pxと512pxへサイズ比例で描画し、`sera_item_icons.gd`の設計図IDキャッシュを経てLABO/倉庫/NEXUSへ共通反映。素材アイコンには適用しない。
- `tools/equipment_icon_tech_frame_self_check.py`と`tools/equipment_icon_tech_frame_runtime_check.gd`をCIへ追加し、直線・斜め・ハイライト・原本不変・キャッシュ・素材保護を実検査。
- Android実機のカード・プレビュー表示は自動CIと分けて確認する。ゲームプレイ/装備UID/製作・セーブへの変更はなし。

## 2026-11-21 — BASE / GRID切替プレート＋GRID真上配置UI（ガワのみ）
- BASE/GRIDを左上の大きな斜め欠け四角プレートで表示。切り替え時は0.24秒の左右スライドで見出しが入れ替わる。既存の施設・電力制御施設ID/保存形式を維持。
- GRID斜め俯瞰の基板8×8を画面タップ（実3Dセル判定）で、真上90度の平行投影に0.58秒でアニメーション。マスタップしたセルに単一の半透明3Dマーカー。端末縦横比に合わせてカメラ表示範囲を自動計算。
- 下からノード候補パレット（G/H/K/P/C/D/R/X/Y/T/O、横スクロール）、右から背景無し線画アイコン（PLACE/MOVE/ROTATE）が出現。UDEV+Moralerspace、ブルーグレー細線、非丸角の切欠きUI。候補・操作モードは選択表示のみ、配置・資源計算・保存は未実装。
- 戻る操作で配置UI→GRID斜め俯瞰→BASEの2段階復帰。コードは `sera_base_grid_cut_control.gd`（描画）、`sera_base_grid_ui.gd`（表示）、`base_exploration.gd`（カメラ・セルタップ）。既存パズルの盤面は64タイルMultiMeshのまま。
- `tools/base_grid_presentation_runtime_check.gd` をCIに登録し、GLで`sera_base_grid_edit_shell.png`を撮影。詳細 `docs/BASE_POWER_GRID_V09_ja.md`。

## 2026-11-21 — BASE板・スクラップの床めり込みを修正
- 床パネル上面は `Y=-0.03`（中心 `-0.18`、板厚 `0.30`）。従来の板/スクラップは歴史的な `FLOOR_OFFSET=-0.16` と小物倍率の組み合わせで床下へ食い込み、俯瞰画面で金属板がほぼ見えなかった。床面を共通の基準にする `_pile_pos` を導入し、すべての倍率で足元を固定した。
- 板材は薄い接地台を床に接する高さへ変更。全ての金属板について3軸回転後の実際の8頂点の最下点を計算し、床面から最低1.2cm上に収まるよう板単位で高さを補正（回転・形状・重ね数は維持）。スクラップのスキッドは床面から上へ伸びる厚みにして、内容物も同じ地面基準に統一した。
- 16独立スクラップ山のMultiMesh拡大中心も、世界原点Y=0ではなく床上面Y=-0.03に変更し、拡大縮小で接地位置が変化しないようにした。施設位置、選択・ランダム再配置、出力JSON、セーブ形式、描画バッチ数は変更なし。
- Godot実描画の確認床を実ゲームに一致させた。`base_pile_ground_contact_runtime_check.gd` は板とスクラップの1〜8個×4パターン×3サイズ、および独立16山の各メッシュ最下点を検査する。

## 2026-11-21 — BASE板材・スクラップの1〜8個重ねモデル
- 固定の単調な縦積みから、1〜8個の主要部材を下層広め／中層少数／上層1個に振り分ける共通プロシージャルモデル4系統へ変更。全32種の枚数×構成で、板の切欠き・折れ・台形・リブ・短板・長板、およびスクラップの装甲片・筐体・軸・ベアリング等の実形状を使い分ける。
- `scripts/sera_base_pile_models.gd` が正規化配置の単一生成元、`sera_base_junk_geometry.gd` が板／スクラップの実3Dマテリアルバッチ、`sera_base_clutter.gd` が施設ごとの部材数・パターン選択。既存施設の座標、通路・床パネル判定、コンテナ1〜4段、保存形式、材質ごとのMultiMeshは維持。
- 独立スクラップ山16か所は初期表示で1〜8を各2件、ランダム再配置では1〜8個と4パターンを再抽選。JSON `SERA_BASE_PROP_LAYOUT_V1` に施設小物と16山の `stack` / `pattern` を追加し、ユーザーが貼り付けた完成図を再現可能。
- テスト：既存の積載・ジャンク・ランダム再配置の回帰契約を更新し、`base_eight_piece_piles_runtime_check.gd` で32×2種類のジオメトリ、階層、コピー用フィールド、MultiMesh互換を検査。実機での見た目は別途確認。

## 2026-11-21 — BASE小物ランダム再配置＋コピー用JSON
- 右上に「小物を再配置」「配置データコピー」を追加。Godot/Androidのクリップボードに `SERA_BASE_PROP_LAYOUT_V1` 全件JSONを渡せるようにした。ステータスは常に「未確定」プレビューで、再起動時・NEXUS遷移時には正本に戻し、ユーザーの承認前に保存データを更新しない。
- 施設8か所の小物は同一床パネル内で、入口/建物保護領域、他の小物、パネル端の衝突候補を排除しつつ座標と角度を抽選。種類と従来の倍率、4段までの積載構造は保持。16スクラップ山も建物敷地とクレート動線を避けて再配置し、材質別MultiMesh方式は維持。
- レンダリング時は既存建築ノードだけを再生成し、施設本体の位置・機能・保存値・テクスチャ原本に触れない。実際に採用された各小物の施設ローカル位置/向き/倍率/段数/種類と、スクラップのワールド位置/形状をJSONへ記録。乱数seedだけに依存せず、後日このチャットへ貼り付けて固定配置として実装可能。
- 操作方法と完全な出力契約は `docs/BASE_LAYOUT_PREVIEW_HANDOFF_ja.md`。Godotランタイム検査 `tools/base_layout_shuffle_export_runtime_check.gd` をCIに登録。Androidのクリップボードと操作感は実機で別途確認。

## 2026-11-21 — BASE小物の視認性向上（施設主役の安全な大型化）
- `sera_base_clutter.gd` の既存68小物を対象に、通常小物最大1.26倍、積載/コンテナ・微細アクセント最大1.18倍まで拡大。既存の配置座標・品種・段数・支持構造は維持。施設中央・出入口・隣接小物との直線/旋回双方の占有領域が重ならない最大倍率を、シーン構築時に決定。安全性を優先して密集箇所では倍率を抑制する。
- 建物外の16スクラップ山も最寄り施設との距離に応じ1.12/1.20/1.26倍へ拡大。既存の材質別MultiMeshバッチにピボット基準スケールを追加し、新たな個別描画ノードや毎フレーム計算は増やさない。既存のスクラップ位置/向き/形状バリエーションは維持。
- 新規実Godot検査で68小物の元配置・成長量・16スクラップ位置と拡大率、バッチのピボットを確認。既存の床パネル/入口安全、積載段数、拠点描画/導線のCIを継続。見た目と実機速度はAndroid実機で別途確認。

## 2026-11-21 — 灰色起動画面の直接原因を修正（施設管理GDScriptパースエラー）
- Godot 4.7.2のCIログで「Could not preload resource script res://scripts/base_facility_system.gd」「Failed to load script res://scripts/base_exploration.gd」を確認。BASEの最初のスクリプトが読み込めず、起動用UIの _ready 自体が実行できなかった。
- v531のH02アイリス説明文に、文字列の外側のリテラル \\n が混入した不正GDScriptを発見。意味と表示内容を保持した明示的なif/else分岐へ置換。
- 同じ形式の誤った改行トークンを検知するPython検査と、施設スクリプト・起動シーン・HUD・カメラの存在を実Godotで検証する検査を追加。CIではインポート前の実行段階で先に起動検査を行い、タイムアウトと早期失敗で無限待機を防ぐ。
- 描画レイアウト、装備の定義、倉庫や既存の保存形式には変更なし。Android実機での再現解消は実機再起動による確認が必要。

## 2026-11-21 — 装備アイコンの描画をSERA本体Godotと一致させるオフライン撮影工程
- `SERA_ICON_PRESET_V1` のカメラ姿勢、拡縮・移動はIcon Studio WebGLからそのまま引き継ぐが、ゲーム用最終画像は独自CPU/WebGLレンダリングを使わずSERA自身のGL Compatibility GPUレンダリングに切り替える。
- `tools/icon_studio/sera_godot_native_capture.gd` は実ゲームのHEAD Dモデル・材質・UV・16x16原本テクスチャと`sera_view_edges.gd`のリアルなアウトラインシェーダーを共用し、戦闘`main.gd`に記載の環境光・KeyLight値を採用。512px透明SubViewportで一度だけ描画・フレームバッファ読込。
- 通常Androidゲームの各装備カードでSubViewportを動かさない。CIのOpenGL/Xvfb撮影成果物として`SERA_H02_IRIS_GODOT_512.png`を保存し、Pythonで正本SHA256とプリセットを`SERA_ICON_MANIFEST_V1`に記録。これを`install_sera_equipment_icon.py`で採用した装備IDへ統合し、既存共有PNGキャッシュで運用する。
- 新規独立静的チェック`tools/icon_studio/godot_native_capture_self_check.py`とCIのGPUフレームバッファ・非透明画素検証を登録。CIにおける描画キャプチャ生成・Android実機表示の結果は別途実測で確認する。

---

## 2026-11-21 — BASE gray-screen startup guard (unversioned bug fix)
- The startup scene now creates a minimal WorldEnvironment, active orthographic camera and native-font loading overlay before the first process frame, rather than synchronously constructing the entire BASE before anything is drawn. The same hub architecture, navigation, scene path and persistent save format remain unchanged.
- BASE boot now emits stage breadcrumbs (FLOOR/NEXUS/FACILITIES/SALVAGE/CRATE/UI/COMPLETE) to isolate any slow or failing startup subtask on Android. Overlay is removed only after the gameplay HUD is ready.
- The disabled outdoor SERA character no longer preloads its full combat rig script graph; that Script is loaded only when HUB_SERA_CONTROLS_ENABLED is re-enabled. This prevents unnecessary startup compilation and preserves the dormant feature.
- Added a registered Python regression for the first-visible-frame contract and lazy rig. Actual Android editor and device cold-start performance remain to be verified; passing headless tests alone cannot prove mobile responsiveness.

## 2026-11-21 — 既存LABO v534/v553 Godotテストの現行UIライフサイクルへの追随
- PR #567の金属パネル/スクラップ改善はStatic/Godot新検査と720x1280実描画2点がPASS。ただし全CIは変更前からLABOのv534/v553が失敗。
- v534: 古い `SpinBox` を必須としていたが、正式な現行UIは「− | 中央数字 `Label` | ＋」の三分割操作。実ラベル中心揃えと3セルの高さ64px以上を検査し直す。サイズ要求そのものを省略しない。
- v553: `sera_warehouse_grid.gd` はサイズ確定時に画面内の可視セルだけを作るO(visible)仮想化構造。画面切替の同期直後（サイズゼロ）にセルを探す旧テストを、2フレーム進めて実際の画面レイアウト・セル再利用後の検査とする。999セルを作ることや空欄のバグを許す変更ではない。
- 変更対象は旧Godot検査2ファイルとこの変更履歴のみ。ゲーム実装・保存/装備・BASE3D・スクショ・既存の他の検査内容は不変更。mainで全CIを再実行する。

---

## 2026-11-21 — IRIS(H02)装備製作とユーザー指定プリセット撮影アイコンの統合
- ユーザーの `SERA_ICON_PRESET_V1`（X=-17.95108886718749,Y=152.8089099121089,Z=-5,scale=1.0311868961757298,pan=-0.10036383734809033/-0.052272971159492435、輪郭80度3px）を原本SHA-256とともにH02.jsonへ保存。
- HEAD Dモデル6メッシュ230面から512px透過PNGをレンダリングし、IconStudioメタデータ付きで装備アイコン共有キャッシュへ登録。画像生成AIは不使用。旧7装備のアイコンは維持。
- LAB H02 アイリス設計図、現行Aからの暫定頭部D性能継承、既存共通の製作5追加効果・固有UID・倉庫999上限・セーブ/NEXUS装着を接続。
- `tools/iris_h02_craft_self_check.py`は元モデルSHAとPNG CRC・表示画素を検査、`tools/iris_h02_craft_runtime_check.gd`で製作・画像・D選択・保存復帰を検査。SERA v531。Godot全CIとAndroid実機表示は結果確認まで未検証扱い。

---

## 2026-11-21 — BASE装飾：厚いパネル塊と直方体スクラップを実形状バリエーションに刷新
- ユーザー画像を受け、現行main、`sera_base_clutter.gd`、`base_exploration.gd`、`sera_base_architecture.gd`、既存のモデルレンダリング規約・全CIマニフェスト・GitHub Actionsを確認。対象は倉庫/建設施設の `panel_stack` と独立する16か所の `ScrapPile`。
- 実装前に `base_junk_models_self_check.py` と `base_junk_models_runtime_check.gd` を追加しマニフェストへ登録。6形状の本物の板の厚み・サイズ差・X/Z傾斜・16安定座標・5構成のスクラップ・低負荷な材質別MultiMesh描画を検査。
- `JunkGeometry.panel_stack` は切欠き・屈曲・台形・リブ付き・短板・長板の6種。重なり方と傾斜・サイズも1枚単位で変化。金属板に細い支えとスペーサーを付け、従来の同じ箱4枚という外見を廃止。
- `JunkGeometry.scrap_heap` は破損装甲、歯車、回転軸、折れた配管、枠、ケーブル、モーター、ピストン、ボルトをランダム風だが再現性のある5型で16か所配置。従来の箱2＋棒1を置換。全個体を共通材質のMultiMeshにまとめ、追加の透明描画パスなし。
- 既存の `LiftedBatch`・古いCapture/RecordingBatchの出力とコンテナ支持構造、敷地内の小物位置・床1枚・CRATE動線・カメラとUIは変更しない。
- フルスクショに加えて `tools/base_junk_visual_capture.gd` を既存GitHub Actionsの仮想720×1280描画に登録し、金属パネル2型とスクラップ4型の拡大スクショを毎回出せるようにした。
- 詳細: `docs/SERA_BASE_JUNK_MODELS_ja.md`。Android実機の最終見え方はCIと区別して報告する。

---

## 2026-11-21 — NEXUS CUSTOMIZE左下に装備ステータスを表示
- CUSTOMIZEの左下正方形パネルを、装備の現在選択セットから算出した性能の読み取り専用表示へ変更。HP・防御・コンボ初段の攻撃/部位破壊・怯み蓄積・攻撃EN・走行/BOOST・ロック距離・ガード倍率・ENコスト・STEP倍率・BASH/CHARGEを簡潔に並べる。
- `sera_part_stats.gd` の戦闘用プロファイルを唯一の数値源とし、値が0の行を除外。既存LABの製作個体に付与される追加性能5種は現段階で戦闘に未接続のため、実性能値へ混入させない。
- フォントと欠け角カードはLAB/NEXUS共通。画面幅に応じて1/2列へ切替、枠内のみ縦スクロール。14セルを一度だけ生成して再利用し、装備変更・読み込み後に更新。既存の装備タブ・モデル・保存・入力・戦闘計算は不変更。
- 実装に先立ち静的＋Godotランタイムの新検証を `tools/sera_ci_manifest.txt` に登録。ゼロ非表示、A/BのHP 160/208、右武器Aの攻撃EN=0非表示/Bの4表示、装備変更の即時反映、他画面への表示漏れを確認対象にした。
- マージ後のmainフルCIとAndroid実機の表示/スクロール確認は別々に評価する。

---

## 2026-11-21 — Icon Studio作業指示を保全しつつAGENTSサイズ制限を回復
- PR #564の拠点入口可視化はmainへ統合し、関連するPython静的テスト全件PASS。しかし並行するIcon Studio追加によってルートAGENTSが12,921バイトとなり、`sera_workplan_self_check.py` の承認済み12,000バイト制限で停止し、GitHub Actionsの画素キャプチャに進めなかった。
- 装備専用Icon Studio先行HTML、PNGの `SERA_ICON_MANIFEST_V1`、他チャット引継ぎ、LAB/倉庫/NEXUS/保存までの接続という**既存規約全文**を `docs/SERA_ICON_STUDIO_HANDOFF_POLICY_ja.md` に移し、AGENTSには短い必須要約と全文リンクを配置。AGENTSは11,752バイトとなる。
- 規約やCIサイズ閾値の緩和、ゲームコード/装備/モデル/アイコンの変更なし。mainで全CIを再実行してBASEの8入口スクショを確認する。

---

## 2026-11-21 — BASE全8施設の入口視認を優先し、カメラ正面から画面中央へ傾ける
- 前回の世界座標の中心方向へ施設を回した結果、LABO・保管庫・回収機・建設端末などの正面が反転し、画面では背面しか見えなかった。ユーザーから「手前にカメラを向いた状態から、画面中央へ傾ける。施設入口は全て見える」と明確化された。
- 採用：カメラ正投影の水平方位約37.67°を基準に、左側の施設はYawを大きく、右側は小さくして、いずれも画面中央へ視線を向ける。正面（ローカル+Z）の法線がカメラと成す角度を27°未満に制限。NEXUS33 / LABO44 / 精製60 / 分解16 / 保管63 / 発電12 / 回収56 / 建設20°。すべて固有角。
- 実装前に既存 `base_inward_facilities_self_check.py`／`base_inward_facilities_runtime_check.gd` と `base_natural_yaw_runtime_check.gd` の旧ワールド中心基準を、入口がカメラから見えること・左右の傾きが画面中心へ向かうこと・入口が縦画面内に収まることへ更新。古いテストファイル名はCI互換のため維持。
- 実装は8施設Yaw定数のみ変更。既存のモデル・施設位置・小物/積み上げ構造・台座/ローター/ライトの追随・タップ領域・正投影カメラ・床・経済・セーブは維持。Godot全登録CIと720×1280レンダリングスクショを確認し、Android実機の最終目視は分けて報告。

---

## 2026-11-21 — 装備原本入りSERA Icon Studioを先渡しする手順を固定
- 次回以降の新装備実装は、まず登録済み最新版Blockbench正本＋テクスチャを自己完結HTMLに埋め込み、ユーザーへ渡す。ユーザーがブラウザ上で原本を探す／読み込む操作は不要。
- HTMLはWebGLによる3D操作と輪郭線・512px透過PNG出力・撮影条件コピーを継承し、PNG `tEXt:SERA_ICON_MANIFEST_V1` に原本パス・SHA-256・装備ID・rig_set・撮影状態を格納する。別チャットから同PNGを受け取った場合、元モデルの再提供を求めずリポジトリ正本へ照合してアイコンに反映する。
- `tools/icon_studio/` に共通テンプレート、HTMLパッケージ生成、PNGメタデータ検証、テスト、運用READMEを追加。アイリス用の原本埋込済みHTMLは `tools/icon_studio/dist/SERA_Icon_Studio_IRIS.html`。
- 本変更はアイコン制作と開発運用のツールのみ。LABにアイリスH02を製作登録したという意味ではない。Android実機WebGL表示とGodot内アイコン反映は未検証。

---

## 2026-11-21 — CIの旧フォント名4検査を現行UDEV/Moralerspaceへ追随
- BASE施設を内向きにするPR #560のmain全CIは、今回の配置と無関係な旧名 `IBMPlexSansJP` / `NotoSansJP` / `Rajdhani` を必須とする4つの静的テスト（v535/v546/v549/v550）のみ失敗し、Godot全実行時検査が始まらなかった。
- ユーザーが採用済みの現行 `scripts/sera_labo_round_skin.gd` は UDEV Gothic Regular/Bold と Moralerspace Neon Regular/Bold のBundled TTFを利用。ランタイムが使用しない旧フォントのファイル有無や名前ではなく、**現に参照される4つの実ファイル、TrueType実バイナリ、ライセンス、全日本語のグリフ要件、UIサイズ・画面配置の従来の不変条件**を静的検査するよう期待値のみを更新した。
- テスト削除・無条件スキップ・非関連UI/ゲーム挙動の変更なし。変更ファイルは4つの旧歴史的Python検査のみ。Godotランタイム検査は従来のまま全実行。

---

## 2026-11-21 — BASEの8施設を少し内側へ寄せ、施設正面をそれぞれ中央へ向ける
- 最新mainと拠点正本・カメラ・各施設Yaw・床単一パネル・小物68群・スクラップ16基・CRATE動線・全CIを確認。旧「全施設がカメラを向く」仕様は撤回し「施設の正面は中央を向く／角度は個別」を最新ルールとする。
- テスト先行：`base_natural_yaw_runtime_check.gd` の旧カメラ正対期待値を中央向きへ置き換え、`base_isometric_layout_self_check.py` の8投影位置と`base_soft_center_space_self_check.py`のLABO目標値を更新。新規 `base_inward_facilities_self_check.py`／`base_inward_facilities_runtime_check.gd` をCIに登録し、計算上の正面向き・固有角度・全8施設の実モデルと台座Yaw・タップを検査。
- 8施設を中央(0,-2.2)へ少し寄せる（8施設の中心距離合計を約3.9m短縮）。YawはNEXUS29 / LABO−159 / 精製93 / 分解−20 / 保管179 / 発電−77 / 回収−151 / 建設−144°。すべて入口側+Zが中央への方位±24°以内となり外向きなし。
- 事前の座標検査で8個の床板が互いに交差せず、計68組の小物が各一枚板からはみ出さないことを確認。NEXUS−精製の隣接区画は格子単位で干渉しないように調整。モデル造形、画面投影方式、俯角、グラフィック負荷、ゲーム経済、セーブ、LAB/倉庫、CRATE、スクラップ個数は不変更。
- 詳細: `docs/SERA_BASE_ANGLED_LAYOUT_ja.md`、`docs/SERA_BASE_ORGANIC_CENTER_ja.md`。マージ後はフルCIとAndroid実機の画面確認を区別して報告。

---

## 2026-11-21 — UDEV Gothic × Moralerspace NeonをSERA全画面で役割別に採用

- 旧Noto/M PLUS混在を撤回し、無料かつ日本語対応の2ファミリーを用途分離。SIL OFL 1.1のライセンス原本を`assets/fonts/OFL-UDEVGothic.txt`/`OFL-Moralerspace.txt`に同梱。配布は加工なしの公式TrueType本体を採用（フォント内部名は変更しない）。
- **UDEV Gothic v2.2.0**：日本語本文／素材名をRegular、日本語ページ見出し・装備名・操作ボタンをBold。**Moralerspace Neon v2.0.0**：ステータスの日本語／混合数値と型番をRegular、NEXUS/LABなど英語ナビゲーションや3D看板をBold。
- 公式Release ZIPのSHA-256を`tools/sera_vendor_ui_fonts.py`でHomebrew公式公開値と照合。GitHub Actions `sera-vendor-ui-fonts.yml`が4つの原本TTFとOFLを`main`に自動保存済み。Android GitSync・APK実行時はネットワーク取得・OSフォント代替不要。
- `scripts/sera_labo_round_skin.gd`の共通書体ロールを変更。役割のFontVariationは従来どおり一度だけ生成、実ファイルは`_bundled_face_cache`でパスごとに共有し、7ロールで4TTFを再読み込みしない。固定ウェイトの公式TTFに不適切なOpenType可変`wght`指定をしない。
- 既存の装備製作・倉庫カード・NEXUS・拠点と戦闘HUD、HP/EN/ボス名、ダメージ数値、RUN/BOOST、バージョン表示の書体を共有経路から更新。戦闘の日本語部位名はUDEVを明示し、Moralerspaceの日本語グリフ有無による誤判定を防止。
- `export_presets.cfg`のAndroid raw-file includeに`*.ttf`とOFLテキストを追加。UI位置・タップ範囲・カード容量999・数値計算・セーブ／モデル・アニメーションは不変更。
- 実装前に`AGENTS.md`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、GitHub Actions workflow、v543/v546/v547/v548および既存font診断・サイバーUI回帰を確認。旧Notoや変動ウェイトを期待していた対象テストを先行更新し、文字欠け・TextServer RID・原本キャッシュを検証する`sera_dual_jp_fonts_runtime_check.gd`を登録。従来の描画、倉庫容量、音、入力テストは保持。
- mainマージ後の全Python/Godot CIとAndroid実機での日本語改行・字幅・照度・スクロール表示は別に確認する。

---

## 2026-11-21 — 新規装備モデルはLAB「装備作成」まで同時登録する開発規約
- 今後の装備可能な新規3Dモデルは、Godotへの読込・NEXUSの選択肢だけで実装完了とせず、`sera_prototype_catalog.gd` の製作設計図ID／装備名／slot／対応rig_set、LABの素材レシピ・アイコン、倉庫個体UID・追加性能、セーブとNEXUS装着まで同じPRで対応する。
- 受入検査は「LAB表示→製作→倉庫→装着3Dモデル→保存/復元」の連続動作。未承認の性能・素材コストは創作せず、既存の999件/部位と5追加性能、軽量UI契約を保持。
- `AGENTS.md`、`models/AGENTS.md`、`scripts/AGENTS.md`、`docs/MODEL_PART_WORKFLOW_ja.md`へ開発規則を明記。今回の変更は文書・手順のみで、既存モデルやLAB製作カタログは変更していない。
- 既存アイリスHEAD DはNEXUSモデル選択済みだがLAB製作設計図は別途未実装。登録済みと誤報しない。

---

## 2026-11-21 — BASE：正方形の大広場ではなく、何となく余白のある疎密配置
- 最新mainの施設7スペック、NEXUS基準、33.8°の正投影カメラ、68組の周辺小物、16基のスクラップ、鋼板1枚単位の床、中央の既存CRATEルートと関連テストを確認。
- 実装前に `base_isometric_layout_self_check.py` の全8施設の投影目標値、`base_isometric_layout_runtime_check.gd` のLABO下端配置、`base_facilities_runtime_check.gd` の中心LABO制限を更新。独立した `base_soft_center_space_self_check.py` と `base_soft_center_space_runtime_check.gd` を登録し、緩い中心余白・左右の不揃い・既存資材の周縁配置・床の1枚板を検査する。
- LABOを画面中央下側(ワールド6.20,5.25)へ移動し、他の左右各3施設の前後位置を微調整。俯瞰・Yaw・モデル・施設のタップ/ラベル・キャラ非表示・ゲーム内のデータは維持。
- スクラップ16基のうちLABOとの位置干渉が生じる2基だけを中央の周縁へ移動。CRATEの既存中央遊歩ルートを残し、中央は自然に歩ける隙間へ。
- `sera_base_floor_detail.gd` の長い格子状警戒ラインを途切れた不規則な短線にし、中央の目立つ四角囲いを作らない。材質・バッチ数と床全体の配色は維持。
- 詳細 `docs/SERA_BASE_ORGANIC_CENTER_ja.md`。統合後CI・Android実機の見え方を別途検証する。

---

## 2026-11-21 — カメラアイ頭部をSERAの独立 HEAD D として統合
- 入力原本：`models/storage/カメラアイ頭部.bbmodel`。2026-11-21同期版の修正済み外装をそのまま新規正本として `models/manifest.json` に登録。従来の `Head_C.bbmodel`（頭部C）は維持。
- `sera_equipment.gd` がA標準アニメーションの `Waist/Torso/Chest/Neck/Head` 配下へ6メッシュを追加。作者のローカル頂点・UV・回転と左右配置は維持し、均一0.66倍・中心補正で装着。HEAD A/B/C/その他部位への変更なし。
- オリジナル16×16 PNGをBlockbench原本から読み込み、生成した `assets/sera_camera_eye_head_data.gd` に完全埋込。Godot標準 `_make_mesh` 用にメモリ内のUVだけ96×32座標系へ写像し、元のBBMODEL/テクスチャを変更しない。
- NEXUSのHEAD選択に正式名称 `D アイリス`（英語名 `IRIS`）を追加。内部装備IDは `head`/`D` を維持。既存の `sera_equipment.cfg` と保存スロットv2、選択時非装備頭部の非表示を継承。既存の戦闘・モーションと7装備部位は維持。
- `rebuild_camera_eye_head_data.py` を統合モデルビルドに追加。事前に `camera_eye_head_self_check.py` をCIへ登録し、実行時のモデル・16pxテクスチャ・切り替え確認 `camera_eye_head_runtime_check.gd` も登録。
- GitHub CI/Android実機での表示・可動・実際の装備サイズは静的構造検査と区別して扱う。

---

## 2026-11-21 — BASEカメラを低くし、施設・小物の正面を画面方向へ統一
- ユーザー指定：建物は全体として画面方向を向かせ、俯瞰視点を緩くして前面と側面が見えるようにする。FOV0正投影と既存中心座標は変更せず、カメラを(21,30,25)→(21,23,25)とし俯角41.1°→33.8°。
- カメラ方位37.7°に対して8施設の入口Yawを19〜61°に再配置し、各々約10〜23°側面が見える。設置位置・床基礎・タップ判定・発電ローターと局所光源の既存動作を保持。
- 独立小物68群は画面方位38°を基準に角度分散し、重複・玄関封鎖・床パネルのはみ出しを避ける。狭い場所に限り角度を減衰し、場合により0°。元位置・積載支持・描画コストは不変更。
- 実装前に `base_isometric_layout_self_check.py` の画面座標期待値とカメラ定数、`base_natural_yaw_runtime_check.gd` の施設向き・俯角・小物角度検査を先行更新。既存の拠点配置・タップ・床板・描画検査を維持。
- 詳細: `docs/SERA_BASE_ANGLED_LAYOUT_ja.md`。Godot CIとAndroid実機表示確認は別記。

---

## 2026-11-21 — SERA全画面のシャープなサイバー書体への統一

- ユーザー要望「全体的にサイバーでもっとキレのあるフォントにして、今のは丸い」に対応。丸みが目立っていた日本語見出し・装備名のM PLUS 2と状態文字のM PLUS 1 Codeを撤回し、既存同梱済みのNoto Sans JP VFを太字850・装備750・ステータス550に用途分離。大見出し・装備名の文字間を1px空けて直線的な印象を強化。
- 日本語操作ボタンは同梱IBM Plex Sans JP Bold（1px文字間）、説明文はIBM Plex Sans JP Mediumを維持。英語見出しは角張ったRajdhani Bold、機械番号・数値はIBM Plex Mono Medium。新しいバイナリフォントの追加やOSフォントフォールバック／実行時ネットワーク取得は行わない。使わなくなったM PLUS同梱ファイルは既存履歴との互換性を保つため削除しない。
- LAB・精製・倉庫・倉庫詳細・装備作成確認・NEXUSは共有`sera_labo_round_skin.gd`から新役割を参照。BASE施設ラベルは既存IBM Plex日本語本文を保持し、NEXUSの3D壁面ロゴだけ既定フォントからRajdhaniへ変更。全画面共通のバージョン番号表示はIBM Plex Mono。
- 戦闘HUDのHP/EN/ボス名・操作状態の英語見出しはRajdhani、HP数値とダメージはIBM Plex Mono、日本語部位名はNoto Sans JP装備書体。RUN/BOOST表示もRajdhaniに統一。UIの位置／当たり判定、色、操作、数値計算、プレイヤー描画などゲームプレイ仕様には変更なし。
- 共通フォントは既存のRAW_BYTESおよび`FontVariation`キャッシュを利用。Notoを見出しと状態で共用して冗長なソース読込を抑制。画面生成のときのみ共通Themeを適用し、毎フレームFontFile/StyleBoxを生成しない。
- 実装前に`AGENTS.md`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、GitHub Actions workflow、v543/v544/v545/v547/v548の静的・Godot実行時テストを確認。旧M PLUSファミリー／700・800ウエイトという旧仕様の期待値を`v543_labo_typography_roles_*`と`v548_lab_font_mix_*`で先に変更。登録済みv548実行テストに戦闘HUDのFontVariation役割確認を追加、`sera_sharp_cyber_fonts_self_check.py`を新規登録。
- mainマージ後に既存の全Python/Godot CIを実行し、Android実機の日本語の収まり、視認性、Font診断によるグリフ表示は別途確認する。

---

## 2026-11-21 — BASE角度描画の既存CI互換・CPU側ジオメトリ検査
- BASE角度変更の初回統合後、追加したGodotテストが実GPU `MultiMesh.get_instance_transform` のヘッドレス読戻しに依存し、`base_prop_stacks_runtime_check.gd` と `base_compact_prop_variety_runtime_check.gd` で旧検査用の簡易Batchにない `yaw/pivot` を参照していた問題を確認。
- テスト側はCPU上の本物の `BaseArchitecture.Batch` 内 `entries["cube|rubber"]` をチェックする方式に先行変更。実レンダラはピボットの有無を `get_property_list()` で1回調べ、旧Capture/RecordingBatchは従来通りbox/rod/crateだけで使えるようにする。
- 角度、コンテナ支持関係、床板数、通常ゲーム描画、マテリアル、他のすべての登録CIの期待値は変更しない。別件の既存LABO検査v534/v553は初回変更前にも失敗しているため、BASE回帰とは切り分ける。

---

## 2026-11-21 — BASE施設・小物の平行配置を解消し自然な角度に散らす
- 添付画面で全施設と置物の直交した平行配置を確認。最新 `main`、拠点の建築MultiMesh・施設定義・床1枚設計・雑多な小物・実行時レイアウト検査・描画方針を事前確認。
- 実装前に `base_natural_yaw_self_check.py` と `base_natural_yaw_runtime_check.gd` を作成し、CIマニフェストに登録。施設独立角、描画バッチへの実回転、小物の正負角度のばらつき、単一床板内収まり、施設のタップを検証する。
- 8施設の本体と床上基礎を各々異なるYaw（±10〜21°）。MultiMeshの元のバッチ構成を維持したまま、建物は施設原点、小物は各個別グループの中心で回転する。コンテナの2+1積み、4個積みの支持関係、既存の密度のリズム・余白は維持。干渉時だけ小物の候補角を縮小する。
- 発電機ローター、光源、NEXUSと7施設の投影ヒット領域、独立したスクラップ山・画面端装飾の向きも整合。拠点カメラ・HUD・クレート・セーブ・施設メニュー・設備位置・鋼板数を変更しない。
- 詳細: `docs/SERA_BASE_ANGLED_LAYOUT_ja.md`。マージ後の全Python/Godot CI結果とAndroid実機での目視検査は別途記録する。

---

## 2026-11-21 — LABOの装備作成確認画面を装備中心に刷新

- Android縦画面で重複していた「SYSTEM CONFIRMATION」「装備の作成確認」「ASSEMBLY / CONFIRMATION」「作成後、この装備は倉庫に保存されます。」を装備作成時に非表示／削除し、「以下の装備を作成します」を大きな画面トップメッセージ（32px）へ変更。
- 装備カードを186→270pxへ拡張。アイコン96→136px、装備名22→28px、基礎ステータス16→19pxとし、装備情報を確認画面のメインに配置。ステータス見出しの「（現行Aセット参照）」注記だけを作成確認画面から除去（実際の基礎値や計算・装備データは不変更）。
- カードの直後に「作成しますか？」（23px）を置き、その下に「キャンセル」「作成」を横並びに配置。以前からの確認ボタン・閉じる・シェードタップ・連続実行防止の動作は保持。
- 共通の精製・分解・不用品廃棄確認は元のタイトル、英語サブヘッダ、本文、実行処理を維持し、クラフト時だけ新表示を使用。
- 変更前に `AGENTS.md`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、Actions workflow、既存v553テストを確認。実装**前**にv553静的テストの古い保存案内期待値を新仕様へ更新し、Godot実行テストに名称/アイコン/基礎値/視覚順/操作ボタン/非クラフト確認の保持を追加。既存の対象外テストは変更しない。
- mainへの統合後に全Python/Godot CIを確認し、Android実機の日本語の収まりと操作感は自動テストと別に確認。

---

## 2026-11-21 — 全12素材を独立したローポリPBR 3Dメッシュに制作

- `scripts/sera_base_materials.gd` の現行4系統×3等級を唯一の名称／ID正本として確認。新規 `models/materials/<ID>.gltf` を12個制作し、スクラップはジャンク・ギア・曲面ローター、金属複合材は原材料塊・精密加工インゴット・曲面一体成形材、電子部品は再利用基板・制御基板・演算コア、有機素材は種核・活性細胞・成熟成長体で造形を差別化。
- すべてglTF 2.0の実三角形メッシュ／PBR材質／法線／埋込バッファ。各シーンは独立、既存素材IDおよび `scripts/sera_item_icons.gd` の72pxドットアイコン、所持数、精製分解・保存データは不変更。Android GL Compatibilityを維持し不透明・低光沢を基本にした。
- 新規 `scripts/sera_material_models.gd` は既存12素材を必要時だけglTFシーンとしてロード。検査用 `scenes/material_models_gallery.tscn` は12モデルを3列×4行で表示する独立シーンで、実ゲームのUIへ常時3D描画を追加しない。
- 変更前に `AGENTS.md`・モデル制作ガイド・モデル正本・描画方針・CIマニフェスト・メインの既存テストとGitHub Actionsを確認。実装前に新規静的検査 `material_models_3d_self_check.py` とGodot実行時検査 `material_models_3d_runtime_check.gd` を追加、既存全CIとともに登録。
- 静的検査は12件のID一致、幾何データとインデックス、三角形数、PBR材質、バッファ境界、一意性を検査。Godot検査は全12件のPackedSceneインポートと実メッシュ頂点を検査。Godot 4.7の実動作、UI縮小表示、Android実機のライトと角度はメインのCI・手動確認結果と分けて報告する。
- Blockbench関節骨格・既存マスタ・エフェクト描画順・ゲームロジックには変更を加えていないため、既存のリグ/モーション資産は維持。

---

## 2026-11-21 — 倉庫の分類完了メッセージ非表示と状態アイコンの配置改善

- 実機画像で装備詳細の「SYSTEM / 分類を保存しました。」と、カード右端に小さく表示された状態アイコンを確認。保存成功時は文字通知を出さず、失敗時のエラーだけ維持。
- 装備詳細上部のタイトルと同じ行の右端に一度生成した34pxのMarkIconを配置。状態は個体の保存データから毎回取得し、ほかのタブに移動する際は解除。星は黄色、不用品は赤いゴミ箱の既存ベクター絵をそのまま使用。
- 倉庫の2列装備一覧では、状態アイコンを18px→20～28pxのレスポンシブ寸法にし、個体の表示名をフォントで計測して文字の直後7pxに配置。名前が収まらない場合は20～17pxで文字サイズ調整、それでも長ければ従来どおり末尾省略。両状態と空欄のときの制御も維持。
- コード変更前に現行 `AGENTS.md`、CI manifest、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、GitHub Actions、倉庫詳細／仮想カード／v553アイコンテストを確認。変更仕様の期待値と新ケース（一覧マーカー位置・拡大、詳細のON/OFF、空欄復帰）を既存の静的/Godot実行時テストへ先行追加。製作・分解・保存処理の契約は変更せず、テストも維持。
- mainマージ後に全Python/Godot CIを実施し、Androidで長い装備名、状態切替、タップと表示密度を目視確認する。

---

## 2026-11-21 — NEXUS装備カードのアイコン余白・サイズ・垂直中央配置を改善

- ユーザー実機スクリーンショットで、CUSTOMIZEの製作品アイコンと名称が近接し、左端にも余裕が不足していたため、名称と型番の分離を保ったままアイコン矩形を調整。
- 720×1280画面基準でカード内のアイコンを48→60px、左余白を7→約16px、アイコン右端から名称先頭までの間隔を15→約24pxに拡張。アイコンの正方形とカード高さ中央揃えを保証し、異なる解像度では行幅と高さに応じて収める。
- 文字を無理に大きくせず、装備名と型番の表示領域は独立。既存の装備切替・タップ範囲・保存データ・他画面への遷移は変更しない。UIノードの追加・継続フレーム処理の追加なし。
- 事前に `AGENTS.md`、現行CI manifest／現行仕様文書、GitHub Actions workflow、NEXUSの静的／実行時回帰を確認。先に静的検査に新レイアウト定数、実行時検査に左余白・サイズ・正方形・縦中央・名称との非重複を追加した後で本体を編集。
- 装備スプライトは元画像が72px四方のAtlasTextureで、TextureRectの既定の最小サイズが48px指定を上書きし得る点も確認。作成時に `TextureRect.EXPAND_IGNORE_SIZE` を明示し、指定した60pxの正方形を実際の制御矩形として使う。静的／実行時テストにもこの条件を追加。
- 720×1280の算出結果は行幅296.8px、行高115.2px、アイコン60px、左余白16.324px、名称との隙間23.744px。mainマージ後の全CIとAndroid画面の実際の視認性は別途確認事項。

---

## 2026-11-21 — NEXUS CUSTOMIZEのアイコン／装備名／型番を分離

- スマートフォン縦画面の装備カードで、装備アイコンと「スカウトバイザー H01-0001」等の長い表示が重なり、名称を読みにくい問題を修正。
- 既存 `command_nexus.gd` の同一ラベル連結を廃止し、名称はアイコンの右側に15px間隔で配置、個体型番（H01-0001等）はカード右下に小さなグレー文字（12px）で独立表示。名前は18px、長文はカード内で末尾省略し、同梱書体・名称下線を維持。
- 製作個体がない部位や両手武器で無効化された部位には型番を表示しない。装備選択・UID・保存処理・カードのタップ範囲は変更しない。
- 先に既存登録済みの `nexus_labo_visual_self_check.py` と `nexus_labo_visual_runtime_check.gd` に名称／型番分離、アイコンとの余白、行内位置、控えめな型番書体の検証を追加。既存CI登録は維持。
- GitHub mainマージ後の全Python/Godot CIとAndroid実画面確認を実装検証として区別する。

---

## 2026-11-21 — 正投影BASEの日本語ラベル文字化け修正

- v530スクリーンショット（720×1280、実GL互換モード）の表示確認で、拠点の施設タグ・3D FacilitySign・下部操作ヒントに日本語の□が出る不具合を確認。標準フォントへの依存を撤廃し、既存のLABO同梱の日本語収録フォント `LaboSkin.ui_font()` を共有。
- 先に `tools/base_isometric_layout_self_check.py` と `tools/base_isometric_layout_runtime_check.gd` に施設全種・3Dサイン・ヒントの文字グリフ検査を追加し、その後に本体側のフォント参照を変更。
- Camera3D、3D施設配置、タップ、倉庫・精製処理は不変更。mainへのマージ後に全Python/Godot CIとXvfbの画面キャプチャを再実行。

---

## 2026-11-21 — BASEカメラをFOV0相当の斜め俯瞰正投影へ変更

- BASEのみ、FOV 0°の視覚的意図を `Camera3D.PROJECTION_ORTHOGONAL` で実現。透視カメラのFOV 0°は設定不可能なため、平行投影と縦方向サイズ38m、固定斜め上視点（21,30,25→0,0,-2.2）で実装。NEXUS内や戦闘のカメラは変更しない。
- スクリーン上の目標構図から逆投影して、NEXUS上部中央、LABO中央、その他6施設を左右3段に分散。床・施設メッシュの衝突、タップ範囲、施設名の表示、クレートの周回経路を維持。クレートは同じ周回経路を回転順序だけ変えて手前から開始。装飾部品/スクラップを施設の物理領域外へ移動、説明文を屋根と重ならない下辺に移設。
- 変更前に `AGENTS.md`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`base_exploration_runtime_check.gd`、`base_facilities_runtime_check.gd` とGitHub Actionsを確認。既存の正本を保ちつつ、旧カメラ座標を復元する部分のテストのみ新カメラ定数へ更新。
- 実装前に `tools/base_isometric_layout_self_check.py` と `tools/base_isometric_layout_runtime_check.gd` を追加・登録。実座標から正投影した8施設全体の画面収まり、スクリーン上の非重複、タップ、施設ラベル、毎フレームのカメラ保持を検査。
- 実際のGL画面を `tools/base_isometric_visual_capture.gd` でPNGに保存してActions artifactに添付。mainへマージ後に全Python/Godot CIを実行し、Android実機での描画・タップ感触は別途確認する。

---

## 2026-11-21 — NEXUSの5画面をLABOのマットな産業UIへ統一

- CUSTOMIZE / TRAINING / DEPLOYMENT / DATA ARCHIVE / SYSTEM の各パネルと補助操作（戻る・退出）に、既存 `sera_labo_round_skin.gd` のブルーグレー、欠け角カード、選択レール、同梱日本語/英数字フォントを採用。パネル透過を控えて文字コントラストを確保し、装備アイコンと文字の重なりを解消。
- 部位切替、セーブ/ロード確認、トレーニング設定、アーカイブの読み取り専用、拠点復帰と3Dモデル視点を保持。StyleBoxのキャッシュは変更せず、動的な確認点滅のみ複製スタイルを更新。追加の描画パスやUIノードの大量生成なし。
- 変更前に `tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、旧NEXUSテストとLABO v542/v543の検査条件を確認。既存仕様の期待値は変更不要。新規静的 `tools/nexus_labo_visual_self_check.py` とGodot実行時 `tools/nexus_labo_visual_runtime_check.gd` を本体変更前に追加・manifest登録。
- GitHub mainへマージ後、モデルポリシーのPython/Godot全CIを実行。Android縦画面での文字の視認性、アイコンと文字の収まり、実機タップ/回転は別途目視確認事項。

---

## 2026-11-21 — LAB画面の白文字をわずかに減光

- ユーザー指示「もう少しだけ暗く」に従い、共通ボタン／ラベル／入力欄、上部ナビの押下・ホバー、画面見出し、精製／装備カード見出し、倉庫装備名・追加性能と詳細テキストの**白〜青白色のみ**約5〜8%程度暗めに調整。
- 青みを残す配色を維持。未選択・ロック済み・補助メタデータ等の階層色、シアンのアクセント／素材FX、フォントファミリー／太さ／サイズ、レイアウト、スクロール、ゲームロジックは不変更。隠しフォント診断の純白サンプルは基準色として維持。
- CIの事前確認：`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、LABO v535/v542/v544 の既存検査、GitHub Actions model-policy。現行数値を固定している既存テストはこの色変更で影響を受けないため期待値変更不要。
- 実装**前**に新規静的テスト `tools/labo_text_brightness_self_check.py` を作成しmanifestに登録。新色・可読性の階層・変更範囲を検査。実機での明るさ評価とタップ状態の見やすさはAndroidで別途目視確認。

---

## 2026-11-21 — 有機素材の名称を「微弱・活性・旺盛」に統一

- ユーザー決定に従い、organic_low / organic_mid / organic_high の表示名を「微弱有機素材」「活性有機素材」「旺盛有機素材」に変更。精製カードは「等級名＋改行＋有機素材」、変換レシピ・倉庫はフルネームを同じ定義から生成。
- 実装前に v552 素材名称静的テストおよび Godot実行時テストの期待値を更新。旧有機名の取り残し禁止を静的チェックに追加。新しい等級名を12素材全体と各導線で検証する契約を維持。
- 内部ID、既存セーブの素材所持数、精製／分解比率、素材アイコン位置、スクラップ初期所持5個、ほか3素材系統の名前は無変更。LABO仕様書を更新。

---

## 2026-11-20 — LABO v535初期化エラーの根本修正

- 実Godot 4.7.2ソフトウェアGLの出力ログを確認：attach_hud()でVBoxContainer.get_child_index(header_row)を呼び出していたが、GodotのNodeにはそのメソッドがなく、res://scripts/base_facility_system.gd の初期化が途中停止していた。結果、モーダル内のノードがnullとなり、スクリーンショット検査が完了しなかった。正しいNode.get_index()を使い、body.move_child(section_tabs, header_row.get_index())へ修正。
- 調査途中のフォント処理・3D看板に対する推測は根本原因ではなかった。GitHub ActionsのみGodot内蔵フォントへ切り替える暫定処理（PR #498）、3D看板の発光プレート代替（PR #497）を撤回し、参考画面に近いNoto Sans JP系文字・Roboto Mono数字・3D PRINTER/SERAの3D看板を復元。
- v535静的CIに「get_child_index()を使わずNode.get_index()を使うこと」を追加し、既存の実Godot UI初期化・操作・描画検査は維持。

---

## 2026-11-20 — LABO v535描画検証のフォントフォールバック

- 参考画像に合わせたUIテキストのフォントサイズ・ボタン寸法・太字タイトルは維持。AndroidではNoto Sans JP系システムフォントとRoboto Mono系数字フォントを利用。
- Godot 4.7.2のLinuxソフトウェアOpenGLスクリーンショット検査にて、OSのfontconfig/CJKシステムフォントの読み込みが長時間終わらない事象を観測。GitHub Actions環境のみ、Godotが既にメモリに保持しているThemeDB.fallback_fontとFontVariationの軽量太字を使用する。Android向けの指定は変更せず、CIでも文字サイズ/カード領域/実描画と操作検査をすべて実施。
- 同時に3DのLabel3Dシステムフォント看板は、軽量な固定発光パネルに変更済み（PR #497）。UIボタンサイズ・倉庫32枚・表示3D30%・アニメーションは維持。

---

## 2026-11-20 — LABO v535：参考画像寄せのフォント・情報階層・配色

- 提示されたLABO 3画面の設定画に合わせ、読みやすい日本語角ゴシック系フォント（Noto Sans JP / Noto Sans CJK JP / M PLUS 1p等の端末フォント、最後はGodotのシステム代替）を共通テーマに登録。見出しは太め、基礎ステータスや数値はRoboto Mono/JetBrains Mono系の数字重視等幅フォントを使う。フォントファイルを同梱せず文字画像も生成しないため、端末で実際の採用書体は異なる可能性がある。
- 既存タップ領域と3D比率は維持：上部3タブ64px・部位タブ58px・製作カード108px・素材カード108px・戻る66px・確認70px。メイン3タブ19〜23px、7部位は17〜22pxを画面幅・日本語文字数で自動決定。倉庫素材3列は幅に応じて画像と文字を縮小するため、画面外へのはみ出しを回避。部位横スクロールは引き続き不可。
- 本文15→18、見出し23→27、製作装備名18→21、素材名16→19、装備基礎値14→17、倉庫・変換・確認・戻るボタン等のラベルも拡大。選択タブはシアンの発光輪郭、背景は暗紺、文字は高コントラスト。参考画像に沿って上部3D→大分類タブ→セクション見出し＋シアン縦線の順に配置。
- 装備製作の下部に選択部位の画像＋装備名＋基礎ステータスの面取りプレビューを追加（視認用で別のタップ領域を増やさない）。ローポリ3Dに工業照明・警告色・工作機3D PRINTER/SERAの看板・精製槽REF看板・倉庫棚IDを軽量な静的ラベル/形状として追加。クレートやプリンター等のアニメ・3D更新停止条件を維持。
- Godot 4.7.2/Androidのフォント代替仕様に依存するため、端末にフォントが存在しない場合はOS/Godot標準の字形を使う。既存v534文字サイズ期待値を先に更新、v535 Python/Godot回帰を追加してラベルサイズ・横幅・階層・プレビュー・32枚倉庫プールを検査。実機の日本語描画、狭幅端末での見切れ、ボタンの押しやすさは手動検証が必要。

---

## 2026-11-20 — LABO v534：全画面のボタンと文字・タップ領域を拡大

- Android実スクリーンショットで、表示は安定したものの全体的なボタンが小さいことを確認。3D背景30%・縦画面・暗いネイビー／シアン面取り配色は維持し、LABO全体の操作対象を拡大。
- 上部3切替ボタン50→64px・フォント16→18、7部位固定タブ44→58px・12→15。7カテゴリは均等幅で横スクロールなし。
- 製作バー82→108px、素材3列カード86→108px、素材画像52→62px、見出し文字13→16・数量11→13。装備画像60→74px、タイトル16→18・詳細12→14。
- 素材変換バー66→84px、数量指定58→72px、倉庫の素材カード96→120px／装備カード156→180px。上部素材／装備切替47→59px、倉庫部位58px、分類・一括削除・製作確認も拡大。
- 戻るボタン48→66px、製作確認2ボタン56→70px。確認ダイアログの文言、製作の二重確認、5特性、倉庫の最大999個/部位および仮想カードプール最大32枚は変更なし。
- v532/v533の既存小さめカード高さ期待値は実装前に更新。新規v534静的・実Godot回帰で上部/部位/素材/製作/変換/倉庫/確認の最小タップ高と横幅を検査。手元Androidの最終視認性・FPS確認は引き続き別途実機検証が必要。

---

## 2026-11-20 — LABOの参考画面準拠UI刷新（v533）

- 参考画像（装備製作・素材変換・倉庫）とAndroid実スクリーンショットを比較し、素材カード／装備カード／セクションタブを再利用可能なGodotシーンに分離。タップ操作の最上位ノードは標準Buttonのまま維持し、画像と文字はButton内部のTextureRect/Labelで独立描画。画像ノードはマウス入力を無視し、カード内にクリップ。
- 素材と装備のカードはネイビー・シアンの面取り枠で統一。LABO全体の背景色・文字色・枠線・タブの選択色・余白・タイトルを参考画面に近づける。確認画面・キャラクター・タブ挙動は維持。
- 素材選択は3列・カード高86、製作バーは1列、倉庫は素材3列／装備2列。倉庫セルは既存の最大32枚再利用を維持しつつ素材サムネイルを62px以下に縮め、文字領域・所持数を別表示。素材の3x4 WebP（各72px）の生ピクセルは変更せず、独立タイルによる隣接画像混入防止を保持。
- 素材変換は入力と出力の両TextureRectを使い、数量SpinBox・確認ダイアログを維持。7部位横並び（スクロール不要）、試作用素材UI廃止、レアリティ・装備管理・保存データには変更なし。
- 実装前に旧CIの「Button.iconが存在すること」「StyleBoxFlatの丸枠が正解」とする検査を、新しいTextureRect＋共通StyleBoxTextureの実描画／タップ／WebPなしフォールバックを検査する条件に更新。v533静的・Godot検査を追加。v522ピクセル実描画テストは維持。
- 元スクリーンショットと設定画の3D背景は既存のアニメーションシーンを維持。新しいUIはAndroid実機の最終視認性確認が必要。

---

## 2026-11-20 — LABO v532 follow-up：装備部位タブの横スクロール廃止とアイコン修正

- 装備作成と倉庫の両方で、7部位の切り替えをScrollContainerから固定HBoxContainerへ切り替え。全タブを同時に表示し、均等伸縮、2px間隔、短縮和文名称、狭幅時の1文字名称と全名称tooltipで溢れ・横スクロールを防止。
- Godot 4.7.2で存在しないButton.icon_max_widthの代わりに、元72px素材アトラスを保存したまま、Image.INTERPOLATE_NEARESTで54/48/44pxの小型独立ImageTextureをキャッシュし、素材カード/変換元/変換先アイコンへ適用。
- 上記の不具合はmain最初のCIの実ピクセル検査で判明。v511/v532回帰項目を先行変更し、7タブが画面幅内に収まることと実アイコンの上限サイズをGodotテストに追加した。

---

## 2026-11-20 — LABO v532：装備製作をトップ化・装備カテゴリ横タブ・アイコン中央寄せ

- 提供されたAndroid縦画面スクリーンショットを確認。LABOの最初の専用「研究メニュー」を廃止し、建物を開くと即座に装備製作部位タブとバー一覧を表示する。装備／素材変換／倉庫の常設3セクションタブはページ移動用に残す。装備製作から戻るとLABOを直接閉じる。
- 「試作用素材を受け取る」項目をLABOホームと製作画面から完全除去。旧セーブデータとの互換性のため、一度だけ試作素材を受け取る永続APIは残すが、新しいUIからは実行できない。
- 倉庫の装備カテゴリをOptionButtonプルダウンから、共通ButtonGroupの7ボタンを持つ水平ScrollContainerへ変更。選択中カテゴリをハイライトし、見切れる端のタブにはスクロールできる。2列仮想倉庫と999個上限は不変。
- 材料素材選択のカード高さを100から86へ、アイコン最大幅54、縦中央揃え＋Button expand_iconで72px WebPの溢れ描画を防止。素材変換バーの高さを78から66へ、アイコン最大幅48、右出力アイコン44x44に調整。元WebPアトラス、12独立タイル、アイコンキャッシュは変更せず、Androidエディターとの整合を保持。
- 修正前に既存CI（ナビ、v517、軽量LABO等）期待値を直近の指示に従い先行更新。新v532静的・Godot回帰をマニフェストへ登録（直接入場・削除した入口・横タブ・全12素材の可視性と寸法）。従来の保存/画像欠損/3D/画面描画は保持。
- main統合後の全Python・Godot CIおよびLinux実描画検査と、Android実機操作/視認性の確認は区別する。

---

## 2026-11-20 — LABO 3画面の製作確認・スクロール・個体管理・独立3D演出

- 画像の装備製作／素材変換／倉庫を共通LABOの3ページとして実装。上部30%の3Dと独立して、下部に標準Godot Buttonを用いるネイティブ縦スクロールを追加。装備製作は横に並ぶ7部位タブと縦に並べる横長バー、素材変換は横長レシピバー＋個数SpinBoxとした。
- 装備バーのタップは基礎ステータスを表示した確認ダイアログを開き、「作成」を押すまでUID発行・追加性能抽選・保存をしない。素材変換も同じ確認UI経由のみ実行し、キャンセル・Android戻るで副作用は発生しない。
- 装備の基礎値は既存sera_part_stats.gdのAモデルを参照。製作画面は基礎値のみ、倉庫個体詳細は基礎値＋各特性の合計と計算途中式を一覧表示。追加性能の戦闘への未接続状態は明示し、適用済みと誤認させない。
- 倉庫個体にお気に入り／不用品を排他的な永続属性として追加。選択ハンガーの不用品だけを確認後に一括削除し、装備中個体を保護。書込失敗はメモリ上の在庫を変更せず、削除後もUID通番を再利用しない。999件上限と最大32枚の仮想カードプールを保持。
- labo_hero_stage.gd に造形機、3本の異色精製チャンバー、棚のある倉庫の独立した実3Dジオメトリを導入。プリンターヘッド・精製結晶のアニメーションとCRATEの移動/検査FSMを共有。半透明描画パスを増やさず、GL Compatibility用の低解像度SubViewportを再利用。
- 事前確認：AGENTS.md、sera_ci_manifest.txt、アクティブCI規約、倉庫UI規約、3D描画規約、v511/v517/v518/v519/v521/v522/v523/v524/v529、labo系回帰、実フレームバッファ検査。旧「スクロール禁止」「全7設計図同時表示」「即時製作」の期待値はユーザー指示に基づき更新し、各部位の7設計図・12素材・倉庫32枚制限等の不変検査は保持。新規v531 Python/GodotテストをCI登録。
- mainマージ後に全CIおよびLinux実描画を確認する。Android Godotエディター実機での日本語、指スクロール、タップ、3D品質/負荷は別途確認が必要。

---

## 2026-11-20 — 素材・装備2アトラスの欠損耐性CI修正

- `v527_android_icon_resilience_runtime_check.gd` は従来、旧マットアトラスの欠損だけで12素材と7装備がすべて消える前提でした。素材を独立画像へ分離したため、**両方のアトラスを欠損状態にして**カードと文字が残ることを検証し、回復時は双方のキャッシュをリセットして素材・装備を再検証します。
- 3列×4行の素材WebPがAndroid未import時にも元データから復号できることを追加。旧テストは無効化せず実際の2アトラス構成に適合させます。

---
## 2026-11-20 — 12素材アイコンのドット絵差し替え

- 基本素材4系統（スクラップ／合金／電子部品／有機素材）×低中高の計12種を、ユーザー最終承認画像から切り出した透明72×72ドット絵へ変更しました。
- 高純度スクラップは円形・曲面の機械部品を含む最新版を採用。高強度合金は段差のない一体形状。素材画像に文字・枠は含めません。
- 新規 `assets/ui/sera_pixel_material_atlas.webp`（216×288 / 3列×4行）を素材専用に読み込み、旧 `sera_matte_icon_atlas.webp` の装備7枠は維持。どちらも共有キャッシュを使用し、GitSync直後の未import状態を考慮した元WebP読込を実装しました。
- 倉庫素材カードとLABO素材カード・変換表示をnearest-neighborで描画し、ドットの輪郭を維持します。
- 先行CI変更: `tools/v511_matte_icons_self_check.py` に透明WebPの実在・形式・寸法・専用読み込みを検査する条件を追加。`v511_matte_icons_runtime_check.gd` の領域キーを「アトラスの実体＋矩形」に修正（異なる画像の同座標は重複でない）。旧装備・所持・製作テストは保持。
- 手元の素材解析: 12領域すべてに不透明画素あり、WebPの216×288と透過を確認。マージ後のGodot CIとAndroid実機表示は別途確認します。

---
## 2026-11-20 — SERA v529：各ハンガー999個・仮想2列倉庫・個体別5性能
- 直近のユーザー確定仕様に従い、装備倉庫を1個体1カードの2列縦スクロール、素材を同系統の低/中/高横3列に変更。素材・装備カードに暗いブルーグレー、白い日本語対応デジタル系フォント、四隅の切り欠き枠を共通適用。空のハンガーも2枠を表示。
- `scripts/sera_warehouse_grid.gd` でScrollContainerの中に最大32個の標準Buttonをプール生成し、表示行だけ更新。大量ノード生成は禁止。アイコンは既存のマットWebPアトラスを共用し、3D研究室・クレート・既存タブは維持。
- `scripts/sera_save.gd`にカテゴリ別999個上限、製作成功時の重複しない5件ランダム追加性能（暫定の小さな百分率、戦闘効果はまだ未接続）と個体UIDごとの永続化、旧データ安全移行を追加。集約所持数表示を削除。
- CI事前確認：tools/sera_ci_manifest.txt、docs/SERA_ACTIVE_CI_POLICY_ja.md、v511/v517/v518/v519/v521/v522/v523/v524、LABO 3D、軽量化・診断・ピクセル検査を確認。実装前に新v529 Python/Godotテストを作成・登録し、競合する倉庫旧期待値を個体・仮想セルに修正。通常の製作と素材変換の検査は保持。
- 検査はPR統合後のmainフルCIを正本とし、Android Godotエディター実機の表示・指スクロール・文字可読性・FPSは別途確認。LinuxのCI成功だけをAndroid成功と宣言しない。

## 2026-11-20 — SERA v526：AndroidエディターとAPKで異なる空白カードの原因を画面上に記録
- **再現**：同じゲームのAPKでは装備製作一覧が表示されるが、GitSync→Android Godotエディター実行ではv525のテクスチャ設定統一と再インポート後も空白。過去のLinux CIは実機エラーを再現できていない。
- **原因特定方針**：描画方式・UI階層の推測による変更を中断し、カード生成の各段階にチェックポイント、実Godotバージョン、アトラス存在、ノード件数・表示数・アイコン・Rectを収集。画面内で確認できる診断ボタンを用意する。Androidエディターのデバッガー情報を優先。
- **テスト先行**：実装前に`tools/android_editor_card_diagnostic_self_check.py`と`tools/android_editor_card_diagnostic_runtime_check.gd`をCIマニフェストに登録。画面上の診断表示を操作し、通常時非表示、実数値7/7・12/12、全カードとアイコンの維持を検査。
- **実装**：`scripts/base_facility_system.gd`へ診断ボタン・ラベルと`_diag_begin`/`_diag_step`/`_diag_update`を追加。製作／素材／倉庫へ手順ごとのチェックポイント。カードを装飾設定より先に標準UIノードとして追加。UIデータやセーブ構造には変更なし。
- **判定保留**：Godot Linux CIで成功してもAndroidエディターの空白が直ったとは宣言しない。診断スクリーンショットにより実際のエラー発生箇所を確定してから本修正を行う。

## 2026-11-20 — APKとGodot Androidエディターのテクスチャ設定を統一
- 実機報告：Androidエディターではカードが空白だが、独立APKではカードが正常に表示された。APKの再インストールを避けてGitSync+Godotのワークフローを維持する。
- 発見：APK用GitHub Actionsが実行時だけETC2/ASTCテクスチャインポート設定をproject.godotに追記していた。GitSync元ではその設定がなかった。これが唯一の原因かは未確認。
- CI先行：AndroidエディターとAPKの設定一致を要求するPythonテストを新設しCIに登録。
- 修正：project.godotに textures/vram_compression/import_etc2_astc=true を追加。APKワークフロー側の設定書き換えを除去し、リポジトリに設定があることを検査。
- 復旧：Godotを閉じて再起動・再インポートし、必要な場合のみ .godot/imported を削除。user:// のセーブは保持する。
- 本体バージョン、セーブ形式、カード、素材/装備、戦闘は変更しない。Linux CIではAndroid実機の成功を保証しない。

## 2026-11-20 — SERA本体のDebug APK配布パイプライン
- **依頼**：「Apkください」：ゲーム本体をAndroidスマートフォンに直接インストールできるAPKとして提供。既存のSERA Loader APKではありません。
- **事前検査**：`tools/sera_ci_manifest.txt`、model-policyワークフロー、Loader用ビルドワークフロー、ゲームの`project.godot`、リリースREADMEルールを確認。ゲームプレイの仕様値・バージョン表記は変更しない。
- **テスト先行**：`tools/sera_android_apk_build_self_check.py`を本体設定前に登録。ARM64・署名・独立パッケージ・Godot4.7.2の一致を検証。
- **実装**：ルートに`export_presets.cfg`を新設。`.github/workflows/sera-game-android-apk.yml`でSDK/Java、Godot本体と公式テンプレート、Android署名鍵キャッシュ、Debug export、APK署名とパッケージの実検査、Artifact公開を追加。発行物は`SERA-Game-Android-APK`。
- **使用上の注意**：Godotエディターのuser://と独立APKのuser://は別データ領域。GitSyncでソースを更新してもインストール済APKの内容は更新されない。実機操作・描画は最終確認が必要。

## 2026-11-20 — SERA v524：Androidの空白カードと2つのタブ同時選択の修正
- **証拠**：ユーザーのv523実機画像でLABO一覧空白、装備製作と素材変換の2タブが同時に選択色になることを確認。別画面のv522/523 Linux描画検査では本件を見逃した。
- **原因**：タブは独立toggle_modeでButtonGroup未設定だった。空白カードの確定原因は不明だが、全画面のitem_layerに対する毎フレームの手動座標・サイズ更新はAndroidで表示が安定しない疑いがあり廃止。
- **CI先行**：既存CI期待値を確認し、v524レイアウト／単一タブ検査を本体編集前に登録。v523オーバーレイ前提、v519旧表示領域前提を更新。
- **実装**：タブ3つを同一ButtonGroupに、倉庫内2つも別のButtonGroupに設定。カードをheader/tabsと同じFacilityContentの直下に配置。全画面絶対座標・z_index・毎フレーム補正を撤廃し、VBoxContainerにサイズ計算を委ねる。大きい空白は戻るボタンを下へ押す余白に分離。
- **維持**：装備7件、素材12件、倉庫素材12件・装備7件、四隅カット、全面タップ、実アイコン、素材・セーブ・戦闘・シールド。
- **検査**：Python・Godot・実OpenGLスクリーンショット再検査。Android実機での最終表示は別途確認する。

## 2026-11-20 — SERA v523：実機の空白一覧を別描画階層へ切り離し
- **報告**：v521とv522の実機画像でLABO一覧は同じく空白。v522仮想ディスプレイの描画成功をAndroid成功とは見なさない。
- **テスト先行**：既存CI確認後、v523オーバーレイ配置検査を本体編集前に登録。v511/v517/v518/v519/v521/v522の旧親参照を修正。
- **変更**：FacilityItemLayerをFacilitySheetと同じFacilityModal直下へ設置。z_index=5で前面に表示し、説明文や操作ボタンの下へ実座標でカードを配置。施設パネルの内側に描かないことでAndroidの不具合原因候補から切り分ける。
- **維持**：3列／四隅欠け／アイコン／全面タップ／未所持枠／個体ID／製作・素材・セーブ・戦闘・モデルの仕様は不変。
- **検証**：mainマージ後にPython/GodotとLinux実ピクセル検査。Androidの最終表示はユーザーの実機画面を基準に判断。

## 2026-11-20 — SERA v522：Android実機で消えるアイテム一覧を標準UIで作り直し、実ピクセル検査を追加
- **報告**：SERA v521の実機画像で装備製作画面も倉庫素材画面も依然一覧が無表示。v518〜v521の修正およびCIの「全件成功」はAndroid実描画を保証できていなかった。GitSync旧版起動説はv521バージョン表示により否定。
- **原因候補と対応**：複数回のレイアウト修正で不変だった独自PanelContainerアイテムカードとGridContainerを廃止し、画面上部タブで実際に描画された標準Button/HBoxContainerを一覧にも採用。
- **事前検査／仕様変更**：model-policy main CI、v511アイコン・v517アクセシビリティ・v518タップ・v519カード・v521全面タップ等を確認。製作・素材数・UID・NEXUS・シールド値は不変。変更されるカード階層・ボタン名・アイコン取得元の既存テストを本体編集前に改訂。新規v522静的と実Godot回帰テストも先にマニフェスト登録。
- **実装**：通常Buttonのアイコン＋複数行テキスト＋全面タップで装備7種、素材12種、倉庫素材12種・装備7種を3列で表示。ImageTexture製の透過角カットStyleBoxTextureを使用。未所持0枠は維持し、追加の架空アイテムは生成しない。
- **実描画検査**：GitHub ActionsのXvfb＋Godot GL Compatibility上でUIを実描画し、3画面のスクリーンショット保存とカード内シアンピクセル検出を新設。従来のheadless UIノードテストだけで成功判定しない。
- **注意**：仮想ディスプレイ結果をAndroid実機の成功と同一視せず、GitSync後のv522で目視確認する。

## 2026-11-20 — SERA v521: グリッドのアイテムカード全面をタップ可能に変更
- **ユーザー依頼**：v519の装備・素材カードで、小さな名前ボタンだけではなく、アイコン・名前・余白の全領域をタップして選択できるようにする。
- **着手時確認**：最新main v520、v519の `_new_slot` が名前部分に44px Buttonを置く設計、四隅欠けの `sera_chamfer_slot.gd`、v511/v517/v518/v519の関連CI、`tools/sera_ci_manifest.txt` と開発規約を確認。素材・倉庫の保存データおよびシールドは変更しない。
- **CI先行**：新規`tools/v521_full_card_touch_self_check.py`と`tools/v521_full_card_touch_runtime_check.gd`を本体変更に先立ち登録。実際のAndroid風タッチイベントでカードの画像中心・名前中心・余白を押し、LABO詳細・素材変換・倉庫個体一覧へ正しく遷移すること、唯一のButtonがカード全面を覆うことを検証。
- **実装**：元の小型選択ボタンを削除し、カードの最前面に透明なButtonを直接配置。画像/名前/所持数は入力無視のラベルとし、同一アクションのみ発火する。古いボタン名とアクション関数、未所持枠、各画像、色と形状を維持。
- **検査方針**：マージ後mainのPython・Godot全登録CIを実行し、不合格ならテストを弱めず原因を解消する。Android実機のタップ感は別途最終確認。

## 2026-11-20 — SERA v520: 敵シールドの六層八角形を少し横長に
- **ユーザー要望**：少し横長にして。6層の正八角形輪郭と中央の膜のみを横幅1.15倍にする。高さは変更しない。
- **既存CI事前確認**：最新main v519、AGENTS.md、CIマニフェスト・GitHub Actionsワークフロー、v516の六層八角形静的/実Godotテスト、v515の中心充填テスト、描画深度規約を確認。
- **本体変更前のテスト更新**：v516静的CIへOCTAGON_HORIZONTAL_STRETCH=1.15と共通頂点への横倍率の確認、実Godot CIへ投影したImmediateMeshの幅:高さ=1.15±0.015の確認を追加。6輪・8辺・312頂点・中心充填・色・6段階の展開・破壊SE等の既存検査は維持。
- **実装**：scripts/enemy_shield_hit_fx.gdの八角形の頂点計算xのみ1.15倍。破壊時のガラス片と横稲妻、攻撃判定・シールド数値・LABO/装備/拠点UIには変更を加えない。
- **統合後**：mainでフルPython/Godot CIを実行。実機では横長感を目視確認。

## 2026-11-20 — SERA v519：Android実機の空白一覧を3列カードへ再実装
- **報告と証拠**：v518のLABO試作製作・精製・倉庫の3画面をAndroidスクリーンショットで確認。見出しとタブだけ表示され、一覧が巨大な空白。拠点下部の重複メニューは不要。未所有も4隅切欠きフレームで表示する要望。
- **原因・欠落していた検査**：v517/v518のheadless CIはツリー内のUIノード存在とビューポート座標を検査したが、AndroidでScrollContainer内部が実際に描画されていることを確認できなかった。ScrollContainerを除外し固定グリッドを直接配置する方式へ変更。
- **事前検査**：v511マットアイコン、v517アクセス性、v518実タップ、拠点設備・素材変換・ページナビゲーション、共通CIマニフェストとワークフローを確認。旧下部3ボタン期待値や直下の一覧ノード期待値を、新仕様に合わせ本体編集前に修正。
- **新規テスト先行**：`tools/v519_card_grid_self_check.py`、`tools/v519_card_grid_runtime_check.gd` をマニフェスト登録。拠点下部3ボタンがないこと、素材12・装備7・倉庫の欠けた枠、アイコン、空欄0、コンテナ内座標と3列配置を検査。
- **実装**：`scripts/sera_chamfer_slot.gd` の8辺輪郭を使用し、装備・素材・倉庫に3列の枠付きグリッドを実装。倉庫は素材/装備切り替え、個体UIDは設計図ごとに9件単位で閲覧。拠点下部の重複ボタンを削除。素材所持/セーブ・NEXUS・戦闘・原本モデルは不変。
- **確認方針**：mainマージ後の全Python/Godot CIを実行し、Android実機の描画（特にScrollContainer除外の効果）は別途目視確認する。

## 2026-11-20 — SERA v517: 装備製作/素材アイコンが実機で見つからない問題の修正
- **報告**：素材・装備アイコンが見えない、製作メニューの入口がない、無駄な記号が項目名に付く。
- **原因確認**：本体には全12素材・全7試作アイコンが登録されているが、拠点の建物を探して開く必要がある。新規セーブは全素材0個で入手経路がなく、試作製作ボタンも有効なセーブがないと無効。装飾記号（▸・›・‹・< >）が複数の画面に混在。
- **事前に確認したCI**：model-policy main push、`tools/sera_ci_manifest.txt`、`base_facilities_runtime_check.gd`、`base_material_conversion_runtime_check.gd`、`base_page_navigation_runtime_check.gd`、`v511_matte_icons_runtime_check.gd`。
- **先行テスト追加**：`v517_base_accessibility_self_check.py` / `v517_base_accessibility_runtime_check.gd`を本体変更前に作成・登録。固定3ボタン、各一覧アイコン、未登録プロファイルからの空きスロット作成、製作個体の倉庫登録、12素材を各6個補充、二重受領禁止・保存を検査。
- **実装**：拠点の装備製作・素材変換・倉庫の固定ボタン、LABOの実製作、空きセーブの安全な作成、1回限りの明示的試作素材補充。各アイテム名の装飾記号を削除し、NEXUSの装備名も整理。既存の装備UID、アイコンアトラス、モデル、戦闘を変更しない。
- **検査**：マージ後mainの登録済み全Python/Godot CIで確認。Android実機のボタン配置・表示は別途必要。

## 2026-11-20 — SERA v516: 6層八角形の予測シールドとガラス破片への変更
- **依頼**：厚い八角形の囲いを内側から放射状に6個展開。外周ほど透明度を上げ、空間的なぼかしを全面撤去。出現0.2秒＋維持0.2秒＋消失0.2秒。破壊時は大きいランダムガラス破片と、左右端が透明になる高速な横稲妻。
- **着手時調査**：main v515、AGENTS、tools/sera_ci_manifest.txt、docs/SERA_ACTIVE_CI_POLICY_ja.md、tools/v510_predictive_shield_*、tools/v515_shield_membrane_*、docs/RENDER_PIPELINE_POLICY_ja.md、scripts/enemy_shield_hit_fx.gd、直前の成功GitHub Actionsを確認。変更する検査＝円形グラデーション／0.44秒／遅い稲妻、維持する検査＝中心充填・破壊時空洞・防御数値・ボス/テストターゲット・描画優先・LABO。
- **テスト先行改訂**：実装前にv510の古い固定秒数期待値とv515の旧円形リング期待値を新しい仕様へ更新し、v516_octagonal_shield_self_check.py、v516_octagonal_shield_runtime_check.gdを作成してCIマニフェストへ登録。8辺×6輪の実ImmediateMesh頂点/アルファ、各輪の0.2秒内の段階出現、0.2秒維持/0.2秒消灯、シャープな均一アルファ、14片のガラス破片、短く先端が透明になる亀裂とSEを検査。既存検査は削除・スキップなし。
- **実装**：命中エフェクトを6つの厚い正八角形フレームに変更し、中心の小八角形を従来どおり埋める。外周ほど層単位で透過率を高め、ぼかしと旧円形グラデーションを使用しない。ガラスの大きな乱数形状14片は破壊ヒット発生時に生成し、一貫した速度・角速度で外側へ散らす。横稲妻は伸長0.065秒・終端0.16秒、外側端のアルファを0へ補間。シールド数値・部位/攻撃判定・HPバー・破壊SEは維持。
- **検証**：mainへマージした後、登録済みPython/GodotフルCIを実行。AndroidのGL Compatibilityで輪郭の8辺・段階出現・大きなガラス片の透明度・SEの気持ちよさを目視確認。

## 2026-11-20 — SERA v515 post-merge CI補修：LABOの旧画面遷移テストを現行機能に対応
- **検査結果**：main v515のCIラン44633849609でPython191/191件成功、Godot149/150件成功。v515のシールド膜専用実Godotテストは成功。唯一の失敗は v509以来のtools/base_page_navigation_runtime_check.gdで、LABOのShell開発を従来の情報ページ(detail)と誤って期待した旧テスト。
- **現行仕様の確認**：v514でShell開発はOpenPrototypeCatalogから7種の試作装備一覧(prototypes)→選択した個体の詳細(prototype_detail)→一覧→LABO home→閉じる、と画面構成が意図的に変わった。scripts/base_facility_system.gdと既存のv511アイコン/製作実行テストに一致。
- **修正**：実装を改変せず旧テストだけを、Shellメニューボタン、7種の一覧アイコン、詳細ページ、戻る操作を1階層ずつ検査する内容へ更新。既存の精製・分解画面、Android戻る、NEXUS、シールド/戦闘回帰テストは保持。
- **再検証**：mainへこのCIテスト補修をマージ後、Python/Godot全CIを再実行する。Android実機の色/膜/裂け目の見た目は別途確認。

## 2026-11-20 — SERA v515: 予測シールドを中心の埋まった膜と破壊時だけの空洞へ
- **ユーザー要望**：通常は膜を叩くので中心は消えない。シールドが剥がれた時のみ中心を空洞にしてよい。全体をよりキレのあるデザインへ変更。
- **着手時確認**：main v514、project.godot、AGENTS.md、tools/sera_ci_manifest.txt、docs/SERA_ACTIVE_CI_POLICY_ja.md、tools/v510_predictive_shield_self_check.py、tools/v510_predictive_shield_runtime_check.gd、docs/RENDER_PIPELINE_POLICY_ja.md、scripts/enemy_shield_hit_fx.gdとGitHub Actionsを調査。変更する条件はヒット中心の充填/破壊穴/破片、維持条件は防御数値・HPバーと層順・色閾値・Bittaran/テストターゲットの共通導線。
- **実装前CI追加**：tools/v515_shield_membrane_self_check.pyとtools/v515_shield_membrane_runtime_check.gdを作成しtools/sera_ci_manifest.txtへ先に登録。実際のImmediateMesh頂点色と投影座標を検査し、膜中心が命中後も不透明度0.5以上で埋まり、破壊時の中央に色付き描画が残らないことを保証する。
- **実装**：scripts/enemy_shield_hit_fx.gdの通常命中中心を半径20%まで均一な彩色膜とし、半径34〜65%は面状の反応、73〜82%は鋭い縁、最外周は透明。破壊時だけ内径14〜23%の空洞を形成し、10方向の鋭い破片を放射状に配置。横亀裂と青白い破裂SEを保持。
- **検証運用**：mainへマージ後全Python/Godot回帰テスト、描画順・モデル原本チェックを実行。Android GL Compatibilityの膜・破裂リングの実際の色/重なり/迫力は別途目視検証。

## 2026-11-20 — SERA v514: LABO素材/試作装備アイコン、製作個体命名、倉庫・アセンブル導線
- **依頼**：全素材の固有アイコンと変換表示、LABOの仮装備製作、製作品アイコン、倉庫保存/カスタマイズ反映、複数個製作のUID衝突防止。
- **現状/事前CI**：main v513では19個のマットアイコン、試作7設計図、倉庫・装着が実装済み。AGENTS.md、v511アイコン静的・Godot検査、素材変換の静的・Godot検査、共通CI manifest、main push後の全CIワークフローを確認。
- **本体より先に改訂したテスト**：v511静的テストに正規UID生成/検証、所持数、表示名、変換元/先ランクUIを追加。v511 Godotテストに19領域の衝突防止、正規UIDと別設計図の連番、装備個体名とスロット保存を追加。旧テストを削除・弱化しない。
- **実装**：Shell開発を実製作カタログに直結して重複メニューを解消。各試作の所持数と素材変換ランク・実行数・所持数を明示。倉庫の表示名をNEXUSと同じ「名称＋正規UID」に統一。セーブに保存したUIDを厳密検証し、重複を除外。試作は無償/Aモデルを維持し、性能・追加効果・素材消費は架空実装しない。
- **残り**：mainマージ後のフルPython/Godot CI、実機縦画面での視認性・入力テスト。詳細は `docs/LABO_CRAFTING_CONTRACT_ja.md`。

- **統合後CIでの配置不整合修正**：v514を上げた後に前版のルートREADMEを整理していなかったため、`sera_repository_layout_self_check.py`が失敗。既存テストは正しく、v513の内容を変更せず履歴へ移し、v514をルートに配置、README二種の参照を更新。mainフルCIを再実行。

## 2026-11-20 — SERA v512: 敵予測シールドを高彩度・鋭い表示に
- **要望**：「もっと色を強く、キレのある表示にして」。v511の拡大サイズは維持し、色が白く流れる表現と長いぼんやりした残光を修正。
- **事前CI調査**：main v511とCI成功ラン44628658454、`AGENTS.md`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/sera_ci_manifest.txt`、`tools/v510_predictive_shield_self_check.py`、`tools/v510_predictive_shield_runtime_check.gd`、`scripts/render_order_policy.gd`、`docs/RENDER_PIPELINE_POLICY_ja.md`と既存本体コードを確認。
- **先行テスト改訂**：本体変更前に`v510_predictive_shield_runtime_check.gd`の色期待値を鮮やかな青`007AFF`、黄`FFE100`、赤`FF2140`に修正。初撃不透明度、急な減衰、白芯消灯、亀裂の成長・消灯時間、`BLEND_MODE_MIX`の実シーン材質を追加確認。`v510_predictive_shield_self_check.py`にも透明合成の新規不変条件と時間曲線を追加。旧テストは削除しない。
- **実装**：シールド専用半透明材質を加算合成から通常アルファ合成へ変更。中心白光は短時間に限定し、鮮やかな外周リングと色面のメリハリを強化。横の破壊亀裂を0.13秒で広げ、約0.32秒で消す。放射状の青白い破裂には強い輪郭を追加。大きさ・深度・位置・SE・防御計算・HP表示・ビットタランモーションは不変。
- **検査**：mainへのマージ後、Python/Godot全登録CIとレンダーポリシーチェックを確認。Android実機の色・発光の読みやすさ・残光のキレ・部位位置の遮蔽は視覚確認が必要。

## 2026-11-20 — SERA v511: 敵シールド防御光・亀裂・破裂を実機向けに大幅拡大
- **ユーザー検証**：v510のシールドが「ほぼ見えない」。シールドを大きく、はっきり見えるようにする。HPバー上の演出を復活させず、命中部位にのみ表示。
- **変更前CI確認**：v510 mainのPython/Godot検査成功（GitHub Actions 44627028157）、`AGENTS.md`、現行`tools/sera_ci_manifest.txt`、`tools/v510_predictive_shield_runtime_check.gd`、`tools/v510_predictive_shield_self_check.py`、`tools/render_policy_self_check.py`、`docs/RENDER_PIPELINE_POLICY_ja.md`、`scripts/enemy_shield_hit_fx.gd`を確認。
- **先行テスト更新**：既存のv510テストに通常防御光半径100→260px、横亀裂最大470px、拡散半径470px、最小表示倍率0.85、装甲前方0.14m以上、効果時間0.44/0.65秒の検証を追加。旧HPバー・軽減率・回復・部位/ロック・描画順の不変条件は保持。
- **描画修正**：`enemy_shield_hit_fx.gd`の通常防御光を広く、中心白寄り+色帯を高輝度化。透明な外周は維持。亀裂の左右伸長・幅・光度および青白い破裂半径を大きくし、効果時間も延長。レンダー優先度115・深度テストONのまま接触表面から0.14m前へオフセット。
- **検証**：mainへのマージ後に全Python/Godot CIを実行。Android縦画面ではBODY/四脚/頭、近接・遠距離カメラ、連撃・低SP・破壊SEの大きさと視認性を人間が最終確認。

## 2026-11-20 — SERA v510: 敵予測シールドの接触演出・亀裂・破壊SE（テストターゲット/ビットタラン）
- **依頼**：HPバー上の青い光はHP減少の印象が弱まるため撤回。攻撃が防御された面に、縁が透明な放射状青/黄/赤エフェクトを火花と本体の間に発生。剥がした瞬間は横一線の青白い電撃亀裂→放射状の青白い破裂とSE。対象はトレーニングターゲットとビットタラン。
- **事前CI調査**：main v509、`AGENTS.md`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/sera_ci_manifest.txt`、`tools/v250_target_hp_self_check.py`、`tools/v302_leg_center_part_fx_runtime_check.gd`、`tools/render_policy_self_check.py`、`docs/RENDER_PIPELINE_POLICY_ja.md`、`.github/workflows/sera-model-policy.yml`を確認。変更する期待値は透明描画のレイヤー役割数(7→8)、新規で防御軽減/回復/色・破壊演出。変更しない既存テストは対象HP・部位ごとのダメージ/HitFlash・Bittaran攻撃/IK/連続ヒット・モデル、主人公SH・既存HUD。
- **CI先行更新**：本体編集前に`v510_predictive_shield_self_check.py`、`v510_predictive_shield_runtime_check.gd`を作成・マニフェスト登録。既存`render_policy_self_check.py`に`SHIELD_IMPACT=115`と新スクリプトのレンダーロールを追加し、旧7ロール固定の期待値を承認した8ロールへ変更。
- **実装**：`enemy_predictive_shield.gd`で100SP、近接最大25%/射撃最大95%軽減、ヒットごとのSP消費、4秒ディレイと毎秒20SP回復。ダメージの攻撃補正だけを共通命中処理に挿入し、部位破壊量は従来通り。`enemy_shield_hit_fx.gd`で部位接触面の半透明放射状グラデーション（青≥60%、黄≥30%、赤<30%）、青白い横方向の亀裂と放射状の破裂、PCM生成の短い電撃・破裂SE。モデルと旧火花は保持。
- **継承対象**：`main.gd`で描画・衝突・部位HP・復活リセットを共通実装し、ビットタランは既存の`super._apply_target_part_damage`と`super._ready`により再利用。体力バー自体にはシールド光を重ねない。
- **残る検証**：mainマージ後の全Python/Godot CIの実行結果と失敗項目を確認・修正。Android実機で色閾値、ヒット部位への描画位置、青白い亀裂→破裂、SEの音量・質感・他エフェクトとの重なりを検証。

## 2026-11-20 — SERA v507: 追加検査で発見した0.7秒の追尾スパイク解消
- **指示**：ビットタラン背部レールガンv506のさらなる検査。既存CI/実装の追尾経路を再点検し、姿勢由来以外の加速を探索。
- **事前確認**：main v506、`AGENTS.md`、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、現行`scripts/bittaran_railgun.gd`、`tools/bittaran_railgun_runtime_check.gd`、`tools/bittaran_world_yaw_independence_runtime_check.gd`、`tools/bittaran_full_frame_level_gun_runtime_check.gd`、`tools/bittaran_chassis_axis_runtime_check.gd`、背部エネルギーFXと実戦統合部を確認。
- **発見**：追尾球体が出て0.7秒の追尾入りが終了した瞬間、`weight<1.0`専用の高応答フィルターから`weight==1.0`の即時目標一致へ切り替わる段差。60Hzで2.54倍／120Hzで4.52倍の一フレーム旋回量スパイク。胴体姿勢が縦になるタイミングと重なって見かけ上の加速になる。
- **ロールの符号も別途検査**：Python/scipy 3Dクォータニオン計算でGodotの`Vector3.BACK=(0,0,1)`を正しく適用した結果、v506の符号に異常なし。不要な符号変更は撤回し実装へ加えない。
- **追加の独立Python CI検査**：`tools/bittaran_railgun_charge_continuity_self_check.py`を追加・`tools/sera_ci_manifest.txt`へ登録。30/60/120/240Hzの時間ステップ不変性、重み0.999999→1.0の連続性、コード上の即時100%旋回分岐がないことを検証。
- **CIを本体変更より先に改訂**：`tools/bittaran_railgun_runtime_check.gd`のFLASH終了直前0.0004s即時スナップ期待値を、承認済みの30/s高速指数フィルターを毎フレーム適用する条件に変更。さらに60/120Hzの重み0.999999→1.0での同じ角度誤差に対する旋回量差が2%以内であることを保護。各段階の開始・終了時刻、縮小後の0.7倍、BEAMの0.85〜1.0倍、距離補正の1.5m、RUN/BOOSTの実戦比較、胴体/脚IK、FX、ダウンとヒット間隔の既存検査は維持。
- **実装**：`scripts/bittaran_railgun.gd`の`fast_charge_tracking`分岐で`actual = angle_error * charge_response`を常時適用。チャージ0.7秒で高応答となっても方向へ瞬間スナップせず、フレームレートに関係なく連続した指数応答を維持。固定角速度制限は追加しない。
- **数学的な外部検査**：30/60/120/240Hzにおいて旧仕様の最大段差1.58/2.54/4.52/8.51倍、新仕様はどのフレームレートでも1.000001倍未満（重み0.999999と1.0の比較）。
- **残る検査**：マージ後mainで登録済みフルPython/Godot CI、Android実機で0.7秒追尾入り境界のフレーム加速とビットタランの起き上がり、球体縮小・ビーム追尾を確認。Godot環境がない作業コンテナでは実エンジンテスト実行不可。結果を誤って成功として報告しない。

## 2026-11-19 — SERA v506: レールガン本体姿勢由来の追尾加速を排除
- **依頼**：ビットタランの胴体が縦姿勢になると追尾が加速する現象と、その他本体姿勢に依存する追尾速度要因を修正。
- **事前確認**：main v505、`AGENTS.md`、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`docs/MODEL_PART_WORKFLOW_ja.md`、`docs/RENDER_PIPELINE_POLICY_ja.md`、`scripts/bittaran_railgun.gd`の全追尾経路、`scripts/bittaran_battle.gd`の姿勢処理順／キャラクター速度入力、既存登録`tools/bittaran_railgun_runtime_check.gd`を確認。
- **CIテスト先行変更**：本体実装より先に登録済みGodotテストへ、傾斜／ロールしたBodyのWAIT→FLASH切替（t=10、10.35、10.70）時にターゲット不動なら砲身世界向きが勝手に変化しないこと、BEAM中Bodyを大きく起こしても同じプレイヤー位置なら角速度基準と地表偏差が不変、0秒刻みで本体の傾きに追尾回転が加算されないこと、78°の砲身俯仰角変化だけでは0～1.5m水平追い付き加速が変化しないことを追加。旧テストが保持する各段階の倍率と時間は変更せず。
- **原因**：待機Body姿勢のyaw/pitchが球体出現時の`charge_entry_pose_offset`として0.7sで戻され、モーター世界yaw/pitchとは別に砲身を追加回転。さらに`_tracking_turn_rate`の距離にモーションに引きずられる実マウント位置を使用、`_ground_ray_gap`の距離には前フレームの`elevation.global_basis`（Body由来の変化と上下俯仰を含む）を使用し、垂直になるほどXZ投影が縮んで速度の追い付き補正が増える経路があった。
- **実装**：照準開始時に実砲身方向をワールドモーターのyaw/pitchへ移し、0.7秒の姿勢復帰で**ロールのみ**を砲身方向不変な座標系にて減衰。`_tracking_speed_anchor_world()`でBodyアニメーションとIKでは動かないリグ固定の取り付け基準を用いて距離から角速度を算出。レーザー追い付き偏差はその基準位置と**世界yawのみの水平レイ**で求め、ピッチや前フレーム姿勢の速度加算を排除。
- **承認仕様の維持**：球体出現前10秒待機、球体出現後の高応答追尾、11秒以降の縮小中0.7倍上限、12～14秒照射の0.85～1.0倍（水平偏差0～1.5m）、RUNより速くBOOSTなら逃げられる角速度、14～14.7秒の復帰と姿勢、レールガンエフェクト／音、ヒット間隔／ガード／ノックバック／原本モデル・脚IK／腹下別砲台の挙動は不変。
- **検査区分**：本PRの差分と登録済みGodotテストの整合確認後にmainへ統合。フルPython/Godot CIはmainで実行するワークフローに従う。Android実機の姿勢移行・射撃挙動／視認性は別途検証。
- **並行版との整合**：作業中に拠点画面のv505が先にmainへマージされたため、v505のNEXUS/LABO/CRATEレイアウトと既存CIをベースとするv506ブランチで変更を再実施。レールガン・対応テスト・関連文書以外は触れない。

## 2026-11-19 — SERA v503: 腹下砲台4秒間隔・レーザー形単発弾・実照明付き銃口閃光
- **ユーザー依頼**：射撃間隔4秒、球弾を細長い単発レーザー状にする。十字が表示だけで光っているように見えない問題を解消する。
- **事前確認**：mainの実際の現行版v502と`project.godot`、`AGENTS.md`、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`docs/MODEL_PART_WORKFLOW_ja.md`、`docs/RENDER_PIPELINE_POLICY_ja.md`、`tools/render_policy_self_check.py`、砲台の実装と登録済み`tools/bittaran_leg_turrets_runtime_check.gd`を確認。
- **CIテスト先行更新**：本体編集より前に登録済みGodot回帰テストの1.2s期待値を4.0sへ変更。4秒まで再発射せず4秒経過で1発、細い長手方向CapsuleMeshと飛翔方向の一致、球弾の撤廃、一体の発光ハローの深度保持、OmniLightの発射時10以上相当の点灯・半周期で減衰・短時間消灯・攻撃中/ダウン中消灯、RadialGradientの存在を追加。腹下1基/3.10m十字/1発単位/追尾と弾道一致/攻撃/ダウン停止/背部レールガン停止は保持。
- **実装**：`scripts/bittaran_leg_turrets.gd`の`SHOT_INTERVAL_SECONDS`を4.0に変更。全弾を長さ1.50m/半径0.065mの細長いCapsuleMeshに変更し、一体の半透明青いCapsuleMeshハローを追加。弾の長軸をワールドの発射方向へ一致させ、銃口から一発ずつ前進。既存の17m/s・3秒寿命・被弾判定を維持。
- **発光改善**：十字の芯や既存の青いハローに加え、透明な円形グラデーション`RadialRadiance`を前面加算表示。銃口に従属する`MuzzleBurstLight`（OmniLight3D、光量10、範囲4.5m、影なし）を発砲時点灯し、0.12秒で二乗減衰して消灯。連続光源生成は行わず既存の1基を再利用し、攻撃/ダウンで即消灯。
- **描画・安全**：銃口十字・放射光輪のみ一時的な前面表示。飛翔弾の発光は深度テストONとし3D遮蔽維持。元Bittaran.bbmodel、歩行・脚IK・攻撃、ダメージ・ガード、背部レールガンは変更なし。
- **残る検査**：mainへマージ後のフルPython/Godot CI。Android GL Compatibilityでの実際の明滅・照射感・十字の強さ・レーザー弾の視認性は実機テストが必要。

## 2026-11-19 — SERA v501: 銃口十字の縦横5倍・前面描画・発光強化
- **依頼**：「十字はもっと長く、長さを5倍くらいで手前に描画、目立たせて」。対象はビットタラン腹下中央の単砲台。弾速・追尾・攻撃などは変更しない。
- **先行CI確認**：`AGENTS.md`、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/bittaran_leg_turrets_runtime_check.gd`、`tools/render_policy_self_check.py`、`scripts/render_order_policy.gd`、`docs/RENDER_PIPELINE_POLICY_ja.md`、`docs/MODEL_PART_WORKFLOW_ja.md`を確認。
- **本体改修前にテスト変更**：登録済み実Godot検査に縦横3.10m（旧0.62mの5倍±0.06）、芯太さ0.11m以上、二重の青いグローバー、実銃口より15～30cm前方、`no_depth_test`・透過・加算・カメラ向き・登録済み前面ロール126、持続0.11～0.15秒を追加。既存の単砲台・追尾・発射/消灯タイミング・1.2秒間隔・ダウン時背部レーザー停止等は保持。
- **実装**：`scripts/bittaran_leg_turrets.gd`の十字棒を縦横0.62→3.10m、芯の幅0.047→0.135m、青い外側ハロー幅0.42m、中心発光球半径0.105→0.17m。銃口前方0.20mに移し、`TRANSPARENCY_ALPHA`＋`BLEND_MODE_ADD`＋`no_depth_test=true`＋`BILLBOARD_ENABLED`＋`RENDER_ORDER.CHARACTER_FOREGROUND`を芯/ハローへ設定。瞬間の発光強度と読みやすさを改善し、時間0.085→0.12秒。機体原本・砲身・弾道・ヒットボックスは無変更。
- **描画例外**：前面描画を行うのは発射時の十字のみ。`docs/RENDER_PIPELINE_POLICY_ja.md`に例外を明記。役割126を再利用し、`render_order_policy.gd`の定数値は変えない。通常の3D材質や透過エフェクトの深度検査は維持。
- **残る確認**：マージ後`main`でフルPython/Godot CI、Androidでの十字の明るさ・画面占有/見切れ・発射時の動作と追尾を別途確認。

## 2026-11-19 — SERA v500: 腹下砲台1基へ統合、重装甲化・発射十字フラッシュ
- **依頼仕様**：腹部の4基を1基にまとめ、少し立派な見た目、発射の瞬間に十字発光。原本Bittaran骨格や脚IK、その他攻撃系は不変。
- **事前確認**：現行main v499、`AGENTS.md`、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`docs/MODEL_PART_WORKFLOW_ja.md`、`docs/RENDER_PIPELINE_POLICY_ja.md`、`scripts/bittaran_leg_turrets.gd`と関連登録済みテストを確認。
- **テストを本体より先に更新**：`tools/bittaran_leg_turrets_runtime_check.gd`の「4基/2×2/近い順4回」期待値を**腹下中央1基**へ変更。半球半径0.33m以上・砲身長0.60m以上・接続ベース・装甲カラー/砲身スリーブの存在、十字の横棒/縦棒・銃口座標・発射時の点灯・短時間消灯・再射撃時再点灯を検査。従来の固定1.2秒間隔、銃口弾道一致、胴体追従、攻撃中射撃停止、ダウン時射撃/追尾/背部レーザー停止は保持。
- **実装**：`TURRET_IDS=["belly_main"]`に一本化し、腹部`Body/body_mesh`下面中央へ固定。半球半径0.24→0.36m、基部直径0.86mの装甲カラー・長さ0.68mの砲身・大型スリーブ/銃口。銃口のローカル`MUZZLE_LOCAL`へ青白い横/縦発光バー＋光球を設置し、発射と同じフレームに0.085秒点灯。停止/ダウン/リセット時には光を即消灯。`render_order_policy.gd`の深度付き発光優先度を適用し、GL Compatibilityの不透明本体を透過しない。
- **不変条件**：攻撃・ダウン時の禁止ゲート、最短間隔1.2秒、既存の17m/s光弾/命中/ガード、砲身実向きへの発射、モデル原本・モーション・接地IK、背部レールガンを保持。
- **検証**：main統合後のGitHub Actions全Python/Godot CI、Android実機における腹部への密着／床との干渉／発光の見え方は別区分で確認。

## 2026-11-19 — SERA v499: 脚外側砲台4基の撤去と胴体腹側への移設
- **ユーザー指定**：脚外側に付いていた砲台を削除し、腹の下へ接続。特段の発射数変更指示はないため、4基／近距離順／1.2秒間隔／最寄り1基追尾／攻撃・ダウン時の射撃停止という直前の承認仕様を保持。
- **更新前の調査**：`main` v498、`AGENTS.md`、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、登録済み`tools/bittaran_leg_turrets_runtime_check.gd`、Bittaran Blockbench原本の`Body/body_mesh`（下部の実メッシュ）と4本脚のBody子階層を確認。`docs/MODEL_PART_WORKFLOW_ja.md`と`docs/RENDER_PIPELINE_POLICY_ja.md`も確認。
- **CI先行変更**：実装前に従来の下肢ボーン4基の外向き接続期待値を撤廃。新規にBodyボーンへの全4基接続、底面の上下0～2.5cm埋込、下向き法線、2×2位置、胴体外形からのはみ出し禁止、Bodyの位置・角度変化に対する追従をチェックするよう登録済みGodotテストを更新。追尾/距離順/弾道/1.2秒/攻撃・ダウン停止の検査は保持。
- **実装**：`bittaran_leg_turrets.gd`の下肢骨参照を全て削除。原本`Body/body_mesh`の3D頂点AABBをBodyローカル座標に変換し、腹下面の前後左右2×2に`BellyCannon_*`を配置。正半球の底面を腹下面内側へ最大1.8cm埋込、半径0.24mへ縮小、ローカル+Yを下向きに固定。砲身は別`TurretAim`ピボットで最寄り1基のみ追尾。下肢IK/本体アニメには触れず、戦闘シーンのノード名も`FourBellyTurrets`に更新。
- **不変条件**：4基の射撃間隔、選択・追尾方法、弾速、ダウン中レーザー停止、原本`models/bosses/Bittaran.bbmodel`/キーフレーム/IK/ヒットボックス/操作等を保持。
- **検証**：`main`マージ後のGitHub ActionsフルCIはプッシュ時に起動。Android実機の見た目、砲身の干渉、ダウン時の床接触は自動CIと別に検査する。

## 2026-11-19 — SERA v498: 半球底面接合と最寄り1基のみの砲塔追尾
- **新仕様**：4基の半球の平面底面を各下肢の外側装甲へ密着固定。プレイヤーに最も近い砲塔1基のみ継続追尾、ダウン中は追尾停止。
- **着手前CI・骨格調査**：`AGENTS.md`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`.github/workflows/sera-model-policy.yml`、Bittaran 4本下肢骨の原本、既存の登録済み`bittaran_leg_turrets_runtime_check.gd`と戦闘状態ゲートを確認。原本頂点/キーフレームは維持。
- **テスト先行**：本体編集前に既存Godot CIの仕様を、底面・装甲の接合と正半球比率、外向き法線、下肢への浅い埋め込み、砲身だけの回転Pivot、距離による追尾1基選択と切替/非選択3基停止、ダウン中の追尾停止、弾方向と砲口の一致に拡張。元からの近距離順4基射撃/1.2秒間隔/ダウン中レーザー停止の検査は削除していない。
- **実装**：`bittaran_leg_turrets.gd`を変更。正半球のメッシュ最下端を取付原点へ一致し、下肢アーマー実AABB外側面へ最大3.5cmの埋め込み。ドームは下肢外向き法線に固定、独立`TurretAim`下の砲身だけを最近接1基で毎フレームセラへ追尾。ダウン/攻撃中は追尾リセット・射撃停止、砲塔取付点と半球はIKの最終下肢姿勢に追従。発射方向は可視砲身と一致。
- **不変条件**：原本Bittaranモデル/アニメ/IK、4基の射撃順・共通間隔・光弾速度、ダウン時レールガン停止を維持。非追尾の3基は通常姿勢から射撃するため狙いが外れ得る。
- **確認**：`main`統合後のGitHub Actionsによる全Python/Godot CI、Android実機での外側装甲接合と射撃/攻撃/ダウン中の向き・干渉をそれぞれ確認する。

## 2026-11-19 — SERA v497: 浮く四脚砲台を下肢装甲の外側へ密着修正
- **実機報告**：添付動画で四脚砲台が浮き、原本下肢装甲に接合していない。元v496は`FrontLeg_`／`RearLeg_`上肢骨を起点に`(0,0.28,0)`を固定オフセットとし、射撃停止中に見た目の位置更新も止まる問題。
- **事前CI確認・テスト先行**：main v496、現行CIマニフェスト、登録済み`bittaran_leg_turrets_runtime_check.gd`、Bittaranモデルの14ボーン/18メッシュ、骨の親子関係、`docs/SERA_ACTIVE_CI_POLICY_ja.md`を確認。実装より先に既存テストの固定位置期待値を上肢→下肢へ更新し、実下肢AABBの内側で外面・上面に寄せた位置と、非射撃中にも下肢の動きへ追従する保証を追加。既存の間隔／距離順／停止検査は維持。
- **実装**：`scripts/bittaran_leg_turrets.gd`の各追従先を`FrontLowerLeg_L/R`と`RearLowerLeg_L/R`に変更。原本メッシュの頂点AABBをBoneローカルへ変換して下肢装甲のサイズと外側・上部の埋込位置を自動算出。IKの子孫メッシュ計測を保護するため、砲台は脚骨の子ではなく独立ノード。最終IK後の下肢ワールド姿勢に毎フレーム同期する（攻撃/ダウンで発砲禁止中も見た目は追従）。
- **不変条件**：砲台4基、半球＋筒、射撃間隔1.2秒、最短距離順、弾速17m/s、攻撃モーション中停止、レーザーのダウン中停止、原本モデル/アニメーション/IK、被弾処理は不変。
- **検証**：マージ後mainでフルCI。Android実機では下肢装甲への接合／各モーション／ダウン中の追従を確認する。新しいModel原本ファイルの生成・変更はなし。

## 2026-11-19 — SERA v496: 四脚砲台・攻撃中停止・ダウン中全武装停止
- **CI事前確認**：現行v495、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/bittaran_railgun_runtime_check.gd`、`tools/bittaran_world_yaw_independence_runtime_check.gd`、Bittaran実シーン攻撃／ダウン検査を確認。
- **本体変更より先に検証追加**：`tools/bittaran_leg_turrets_runtime_check.gd`を追加・manifestへ登録。各脚の実関節と半球＋筒、1.2秒共通発射間隔、最短距離脚からの一巡射撃、攻撃中の停止、ダウン予備動作／ダウン姿勢の砲台＆既存レーザー停止を独立した期待値から確認。旧レールガン追尾・接触テストは維持。
- **追加実装**：`scripts/bittaran_leg_turrets.gd`で実際の前後4本の上肢骨をワールド座標で追従する砲台を別ノードとして配置。IKが再帰的に調べる脚メッシュへ砲台形状を混入させない。17m/sの光弾を発射し、命中時は既存のガード／シールド／HP／ノックバック経路へ28%ダメージ。全砲台共通1.2秒の射撃インターバルで距離順に巡回（次の一巡で順番再計算）。
- **停止処理**：`bittaran_battle.gd`で攻撃準備／攻撃中は四脚砲台を停止・弾を消去。部位破壊予備動作～物理ダウン／起き上がり中は両武装を即停止。既存レールガンは`advance(active=false)`のリセットを使用し青球／レーザー／音を消す。再起動時は射撃待ちを最初から開始。
- **不変条件**：本体モデル原本、IK、脚攻撃モーション、背部レールガンの追尾速度と既存10+2+2+0.7秒シーケンス、既存HitboxとNEXUSのルールは維持。
- **検証・実機**：GitHub mainへのマージ後に登録CI全件を実施。Godot実機では四砲身の表示／足への追従、距離順、射撃の視認性、停止直後のレーザーの消灯と再開を要確認。

## 2026-11-19 — SERA v495: 本体旋回に伴うレールガンの見かけの追尾加算を修正
- **CI事前確認**：main v494、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/bittaran_world_yaw_independence_runtime_check.gd`、`tools/bittaran_railgun_runtime_check.gd`、`tools/bittaran_full_frame_level_gun_runtime_check.gd`を確認。WORLD Yawと速度上限の既存条件は保持。
- **原因調査**：レールガンの砲身Yawは既にワールド独立でしたが、ボスルート／BODY骨旋回で砲台の位置が変わる物理フレームに、追尾目標角度・地表射線距離を前フレームの取付位置で計算し、最後に取付位置を更新していたため、余計な照準補正が発生し得た。
- **実装前にCI更新**：既存登録済み実GodotワールドYawテストへ、同一ワールド方位上のターゲットを最新の本体取付位置から指定し、ルートの連続正逆旋回、BODY骨Yawの正逆変化でも砲台制御Yaw・実際のレンダリングYaw・原本砲身メッシュの方位が変わらない回帰検査を追加。既存テストの期待値は弱めない。
- **実装**：`scripts/bittaran_railgun.gd`の`advance()`先頭で最新のBODY取付位置を同期してから`_desired_player_world_angles`と地表射線ずれを計算。相対Yaw＋本体Yawの足し戻しを追尾モーターから撤廃。元の相対角度診断用`_desired_player_angles`は保持。
- **不変条件**：0〜1.5m追尾補間、最大速度RUN＜追尾＜BOOST、照射0.85倍、14/s・16/s応答、10秒充填、青球体、照射2秒、復帰0.7秒、上部接続軸の本体Yaw同期、威力60%、モデル／エフェクト／音声／IK／セーブを変更しない。
- **検証**：mainマージ後に全Python/Godot CIの結果を確認。Android実機では本体が旋回しながら照射する際、レーザーの余計な回転・瞬間的加速がないか、BOOSTで振り切れるかを別途確認。

## 2026-11-19 — SERA v494: レールガン照射の追尾距離を短縮
- **CI事前確認**：main v493、共通CIワークフロー、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、既存の`tools/bittaran_railgun_runtime_check.gd`、`tools/bittaran_world_yaw_independence_runtime_check.gd`、`tools/bittaran_full_frame_level_gun_runtime_check.gd`を確認。既存のRUN＜追尾＜BOOSTの最大速度上限、青球体の縮小時0.7倍、レーザー接触、世界Yaw分離は不変条件。
- **先行CI更新**：本体修正前に登録済み実Godotレールガン検査を更新。照射中だけ0.85倍基準・0〜1.5mのsmoothstep加速・14/s照準応答・1.5m以遠の最大速度据置、RUNの横移動時の射線誤差0.8m未満、BOOSTで離脱可能、装備5/8/30mでRUN＜追尾＜BOOSTを検査。既存テストの無関係な検証は維持し、manifest変更なし。
- **実装**：照射中に限り射線上の最小追尾係数を0.70→0.85倍、加速補間の最大距離を2.5→1.5m、照準角度応答を10/s→14/sへ変更。最大角速度に用いる装備RUN/BOOST間の補間比率0.65はそのまま。速度命令の16/s時間補間、実角速度の制限を保持し、BOOSTで回避可能な速度差は変えない。
- **変更しないもの**：10〜11秒の青球体高速追尾と11〜12秒の球体縮小時0.7倍、12〜14秒のレーザー照射、14〜14.7秒の復帰、ダメージ、ノックバック、原本モデル／アニメーション／IK／FX／音、レールガン本体の独立Yaw。
- **検証**：マージ後mainで全Python/Godot CI。Android実機ではより近くに追うレーザーとBOOST回避の両立を別確認。

## 2026-11-19 — SERA v493: レールガンの追尾速度をRUN＜追尾＜BOOSTに制限
- **事前確認**：`project.godot` v492、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、既存`tools/bittaran_railgun_runtime_check.gd`、`tools/bittaran_world_yaw_independence_runtime_check.gd`、`tools/bittaran_full_frame_level_gun_runtime_check.gd`を確認。変更対象はレーザー照射中の無制限な距離・速度由来加速のみ。
- **先行CI更新**：本体コードを変更する前に既存登録済み`bittaran_railgun_runtime_check.gd`の追尾補間期待値を更新。0/0.625/1.25/1.875/2.5mでのsmoothstep、2.5m超の速度プラトー、5/8/30mでRUN＜追尾＜BOOSTを独立した定数から検査。さらに実シーンで標準RUN/BOOSTの1.5秒円周横移動時のレーザー追従差を検査。新規CIファイルとmanifest追加は不要。
- **実装**：0〜2.5mでは0.7倍から最大1.0倍まで速度補間。2.5mを超えても角速度は最大CHASE値で固定。瞬間プレイヤー速度と距離に比例した無制限加速を削除。時間補間16/s・照準補間10/sを維持し、現在速度にも距離別の上限を適用して瞬間位置変更で超過しないようにした。
- **不変条件**：0〜10秒充填中の非追尾、青球体の10〜11秒事前高速照準、11〜12秒の0.7倍追尾、12〜14秒の照射、14〜14.7秒復帰、本体Yawと砲身の独立、軸同期、威力60%、0.2秒再ヒット、元のモデルとエフェクトを維持。
- **CI**：PRマージ後のmainフルCI（静的・Godot）で検証。失敗は分類し修正。Android実機ではRUNの被追尾とBOOSTでの横回避の操作感、近距離時の旋回速度を別途確認。

## 2026-11-19 — v492 拠点メニューのSERA・移動コントローラーを一時非表示
- 開発開始前にCI manifest・ワークフロー・拠点静的/実Godot/NEXUS往復テストを確認。新仕様に抵触する「拠点SERAの移動検査」を先に更新し、非表示・入力無効・リグ読み込み回避を先に検証条件へ追加。
- `HUB_SERA_CONTROLS_ENABLED = false`の1か所のフラグで拠点SERA表示・リグ生成・移動スティック表示とSERA移動処理を停止。復旧時にコードを削り戻す必要なし。
- CRATE自律巡回・俯瞰カメラ・床グリッド・建物タップ・NEXUS内部メニュー・ボス戦・セーブスキーマは変更しない。
- main統合後、327件の全CIで検証。Android実機上の表示とタップは別検証。

## 2026-11-19 — v491 拠点の見えるグリッド金属床を画面全面へ拡張
- v490では暗色の連続下地のみを広げ、ユーザーが指定したグリッドプレートは5×7のままだった問題を修正。
- 変更前にCI manifest、拠点の静的/実Godotテスト、レンダリング規約を確認。テストの先行更新で6色・7,225枚相当・四隅カメラ視錐台の表示範囲を検証。
- 85×85枚相当の格子を各色ごとの計6 MultiMesh描画バッチに集約。既存の2.94mパネル、3mピッチ、0.06m隙間、6色と256m四方の下地を維持。遠景の数千個のMeshInstance3Dノード生成を回避。
- 移動・カメラ追従・NEXUS↔拠点遷移・CRATE・戦闘・セーブ仕様は不変。mainマージ後の全CIで最終確認する。

## 2026-11-19 — v490 拠点の床を画面全域に拡張
- 更新前にmain、既存CI manifest、拠点テスト、描画規約を確認。追加するテストでは、俯瞰視点の9地点×画面四隅すべてを不透明な連続床が覆うことを実装より前に規定。
- 既存の35枚のパッチワーク金属プレートの下に単一の256m四方の暗色BoxMeshを追加。床が画面の端で途切れる問題を解消し、遠景の多数インスタンス生成を避ける。
- 移動領域、クレート巡回、NEXUSの建物タップとメニュー、ビットタラン戦闘、セーブ仕様は不変。マージ後に全CIを確認する。

## 2026-11-19 — v489 屋外拠点メニューとNEXUS建物の分離
- 事前にmain・既存PR・`AGENTS.md`・現行CI manifest・NEXUS/BASEシーンを確認。旧「拠点から5種類のNEXUSサブメニューへ直接遷移」を仕様変更として特定し、旧テストの該当条件を先に更新。
- 屋外の継ぎ接ぎ金属床と独立NEXUS建物を配置。CRATEは拠点の安全な地点を自律巡回。SERAは拠点内のみ従来のスティック歩行を維持。
- Nexus建物の実投影面をタップして既存の固定式NEXUSメニューへ移動。NEXUSのEXIT TO BASEは選択中メニューからも利用でき、屋外拠点へ戻る。
- ゲーム起動シーンを拠点に変更。ボス戦はNEXUS出撃メニューからアクセス可能。元のモデル・アニメーション・戦闘・セーブスキーマは変更しない。
- 静的テストと実Godot基礎テストを新仕様へ先行更新し、独立した実Godot往復テストを追加。mainマージ後に全CIを実行する。

## 2026-11-19 — SERA v488: なぎ払いの画面振動を攻撃判定の実時刻に完全同期

- **CI先行確認**：現行v487、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/bittaran_camera_shake_runtime_check.gd`、`tools/bittaran_keyframe_hit_sector_runtime_check.gd`、`scripts/bittaran_attacks.gd`の`source_hit_window`を確認。旧v486の「strikeなら継続」という振動テスト期待値が新しい仕様と衝突。前足の原本時刻0.67〜1.38s、後足0.17〜0.63sはユーザー既存承認の不変条件。
- **テストを先に更新**：`tools/bittaran_camera_shake_runtime_check.gd`で旧「strikeだけ」の条件を撤廃せず拡張し、4脚の前/後・左右すべてで開始直前／開始／途中／終了／終了後の`source_hit_window`同期、命中済みでも時間内の継続、時間外に振動しないことと残留振動・カメラオフセット即時ゼロ、FX注入での判定外発生禁止を先行規定。新規CIファイルの追加は不要（既存登録テストを更新）。
- **実装**：`scripts/bittaran_battle.gd`に`_sweep_hit_window_active`を追加し、directorの`hit_window`（原本キー由来）と`phase=strike`で、定期的な振動と接触/FX由来のなぎ払い振動の双方をゲート。なぎ払い専用`sweep_shake_strength`を独立し、判定窓終了時に即時ゼロへ。踏みつけ・弾き・歩行の共通振動と元の減衰は保持する。
- **保持**：既存の攻撃接触、原本クリップ、判定時間、地面FX/土埃の別タイムライン、1攻撃1ヒット、IK、レールガン、拠点、音声、距離減衰は変更しない。
- **実機**：Android端末で判定開始に合わせた連続振動、後足の早い停止、揺れの終了時に画面が元の位置に戻ることを別途確認。フルCIはmainへのマージ後に実行。

## 2026-11-19 — v487 拠点探索画面（自由歩行の第1段階）
- 作業前に`AGENTS.md`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、既存NEXUS、SeraRig、モデル描画規約を確認。既存NEXUSの展示・装備・SYSTEM・TRAININGと戦闘の契約は不変。
- 新規仕様に対応する静的検査と実Godot検査を先行追加し、CI manifestへ登録。既存数値期待値の変更は不要。
- 実Blockbench格納庫モジュールのMultiMesh描画、端末、廃材、SERA実モデル、仮CRATE、俯瞰カメラ、片手スティック、設備接近とNEXUSメニュー遷移を追加。
- NEXUSの全体画面に「EXPLORE BASE」を追加し、保存済み装備を探索モデルにも反映。プロフィールデータには新規保存項目を増やさない。
- マージ後はmainのCI結果とAndroidでの実操作を別々に報告する。

## 2026-11-19 — SERA v486: ビットタランの縦振動を種類別に強化

- **CI事前確認**：現行v485、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、既存の`v345` Bittaranリグ/モデル・`v435`歩行/IK・`bittaran_ground_fx_rebuild_runtime_check.gd`・`bittaran_keyframe_hit_sector_runtime_check.gd`を確認。旧振動の固定期待値を持つ登録済みテストはなく、旧攻撃/カメラ不変条件は維持。
- **先行CI追加**：実装前に`tools/bittaran_camera_shake_runtime_check.gd`を新規作成して`tools/sera_ci_manifest.txt`へ登録。足先とプレイヤーの水平距離0m=1/5m=0.5/10m以上=0、垂直距離からの独立、単調減衰、踏みつけ大・急収束、弾き一瞬大、なぎ払い中揺れの再発生と回復後停止、上下振動優位、0オフセット復帰を独立した新仕様で検証する。
- **実装**：`scripts/bittaran_battle.gd`の共通フラストラムシェイクを、衝撃種別ごとに強度と指数減衰を切り替える実装へ。水平方向0.60、上下1.55。踏みつけは接地時に0.44→0.17（視距離26m補間）・減衰13.5/s、弾きは強度0.38・減衰20/s、なぎ払いは攻撃中0.14秒ごとに強度0.16・減衰11.5/s。歩行は実足接地時に0.20×smoothstep距離係数・減衰10.5/s。いずれも既存共通倍率1.5を通し、他の演出やモデルを変更しない。
- **操作感確認**：Android実機で振動の最大幅・短さ、なぎ払いの連続性、足元強め／10m消失、カメラのセンタリングを確認。全Python/Godot CIはmainマージ後に実施し、自動検査結果と実機検査を区別する。

## 2026-11-19 — SERA v485: レーザー追尾加速の0〜2.5m連続補間

- **事前CI確認**：`project.godot` v484、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/bittaran_railgun_runtime_check.gd`、`tools/bittaran_world_yaw_independence_runtime_check.gd`を確認。旧期待値「1.5m以下は0.7倍固定／1.5m超で急加速」は今回の新仕様と衝突する。照射前の高速追尾→縮小時0.7倍制限、レーザー照射2秒・無制限再命中・威力60%・本体回転の分離は不変。
- **テスト先行変更**：`tools/bittaran_railgun_runtime_check.gd`の1.5m旧期待値を実装前に2.5mへ更新。0・0.625・1.25・1.875・2.5mのsmoothstep係数(0, 0.15625, 0.5, 0.84375, 1)を独立して固定し、回転速度の単調増加、2.49/2.50/2.51mの継ぎ目連続性、0mで従来0.7倍、実際のレーザー追尾で1m部分加速・2.5m超の全量加速を追加検証。その他の旧テストは削除・緩和しない。
- **実装**：`scripts/bittaran_railgun.gd`で射線地表投影からの水平ずれを`gap`とし、`smoothstep(clamp(gap/2.5,0,1))`を加速追従速度に適用。0mでは基準角速度の0.7倍を維持。2.5mでプレイヤー移動速度+距離補正の追従速度を100%適用。距離補正は0mで0、2.5mで3m/sと連続的に伸び、それ以遠でも状況に応じて増加（追尾角速度に固定上限なし）。既存の追尾速度時間平滑化16/sは維持。
- **影響なし**：本体・縦接続軸の旋回分離、砲身のワールド空間角速度、レーザーの2秒照射・接触判定・0.2秒再ヒット・60%威力、モーション・FX・音声、10秒充填・青球体縮小11秒と復帰0.7秒。CI全件はmainマージ後、Androidの避けやすさは実機で別途確認。

## 2026-11-19 — SERA v484: レールガン砲身Yawと本体Yawの速度合算を除去

- **事前CI確認**：現行 `SERA v483` と `.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/bittaran_railgun_runtime_check.gd`、`tools/bittaran_full_frame_level_gun_runtime_check.gd`、`tools/bittaran_chassis_axis_runtime_check.gd`を確認。10秒充填・青球体2秒・レーザー2秒・0.7秒復帰・追尾0.7倍と1.5m補正、接続軸の本体Yaw同期は維持。
- **テスト先行更新**：新規 `tools/bittaran_world_yaw_independence_runtime_check.gd` を先に作成してCIマニフェストへ登録。物理更新の前後での本体Yaw変化、青球体追尾／レーザー追尾の砲身の実ワールドYaw、照射後0.7秒の復帰、復帰終了時の急な回転加算防止、Bodyへの位置追従を検査。既存テストの数値を緩和・削除せず、不変条件は維持。
- **v484マージ後CI修正**：既存`tools/bittaran_railgun_runtime_check.gd`の実レーザー初回接触検査が失敗。新規ワールド変換砲身は`setup()`後に本体の接地位置を調整しても初期フレームだけ追従しなかったため、`_build_target()`の原本接地補正完了直後に`_level_mount()`で初期ワールド位置を同期。新規世界Yawテストにも初期位置一致を先に追加。既存のレーザー初回当たり判定を緩めず、物理更新前の表示位置も修正。
- **原因と修正**：従来の砲身は `Body` の子であるため更新間に親Yawを継承し、復帰時も親Yaw+相対Yaw補間で見かけの回転速度が増減していた。`scripts/bittaran_railgun.gd` の砲身をワールド変換 `top_level` とし、取付位置のみBodyの現位置に追従。追尾中と復帰中の砲身向きは独立の世界水平Yawで計算。復帰中の本体旋回を砲身へ加算せず、復帰後に本体Yawとの差があれば独立の最大180°/sの補間で接続、急なスナップを回避。元の縦接続軸 `RailgunChassisAxis` は従来どおり本体Yawのみに同期。
- Blockbenchモデル・原本メッシュ・関節/攻撃/ダメージ/レーザーFX/音源を変更せず、Android実機で本体旋回しながらの追尾／戻りの見え方を別途確認。フルCIは従来どおり `main` マージ後に実施する。

## 2026-11-19 — SERA v483: レールガン上側接続軸の本体Yaw同期

- **CI事前点検**：`.github/workflows/sera-model-policy.yml` と `tools/sera_ci_manifest.txt`、現行`docs/SERA_ACTIVE_CI_POLICY_ja.md`を確認。既存の`bittaran_railgun_runtime_check.gd`（10秒充填／追尾／ビーム等）、`bittaran_full_frame_level_gun_runtime_check.gd`（胴体傾斜と砲身の水平保持）、`v433`／`v434`（18メッシュと原本姿勢）を不変条件として維持。変更すべき既存数値期待値なし。
- **テスト先行**：新規`tools/bittaran_chassis_axis_runtime_check.gd`を先に作成し、`tools/sera_ci_manifest.txt`へ登録。実メッシュUUIDの親子関係、複数Yawでの完全同期、Body Pitch/Rollからの分離、砲身の独立した照準Yaw、原点の保持を検査。
- **実装**：`scripts/bittaran_railgun.gd`でBlockbench原本の上側の縦軸メッシュ`4b184c7d-480e-cd99-3dca-596928ffd5cd`を、`Body`配下の新規`RailgunChassisAxis`へ再親子付け。縦軸は本体の世界水平Yawに同期し、取付位置はBodyに従うが、胴体傾き・砲身独立照準Yawには回転しない。台座・砲身・足・14ボーン・原本モデル・キーフレーム・攻撃判定の変更なし。
- **統合後**：`main`上のフルPython/Godot CIによる確認、およびAndroid実機での軸と砲身の接続・旋回時の見た目の確認を区別して報告。

## 2026-11-19 — SERA v482: なぎ払いの足先・下肢当たり判定を指定時刻へ

- `scripts/bittaran_attacks.gd`：旧「横薙ぎ停止フレーム0.5秒前で終了」から**ユーザーの明示した原本クリップ時刻**へ変更。前足左右の判定は**0.67〜1.38秒**、後足左右は**0.17〜0.63秒**。モーションのキーフレームやクリップ速度は変更せず、従来の`source_hit_window`とライブフレーム`hit_window`に直接反映。
- `scripts/bittaran_battle.gd`：下肢＋足先のリアルメッシュ判定・1回の技1ヒットを維持。従来の「薙ぎ払いは地面に接しているときだけ命中」の条件は、新指定の開始時刻0.67s／0.17sが実接地より早いため**ダメージ判定のみ解除**。空中にある下肢・足先に実際に接触したプレイヤーは命中し得るが、上肢／本体・ロック範囲ではダメージを与えない。
- **土埃は別系統**：`source_sweep_fx_window`の開始時刻を直接原本FXキー（前足0.75秒、後足0.25秒）へ固定し、終了もそれぞれ1.25秒、0.75秒のまま保持。ダメージ窓の移動に引きずられて空中で土埃が生じたり、既存のパーティクルが途切れたりしない。モデル原本・IKとエフェクトのプリベイクは変更なし。
- `tools/bittaran_keyframe_hit_sector_runtime_check.gd`：左右前後4種それぞれの命中開始・終了の許可／禁止境界、元のBlockbench関節キー存在、実際の足先・下肢ボックスとの接触、別系統FX区間を検査。
- レーザー威力60%、無制限0.2秒間隔再ヒット、追尾、攻撃威力、音響その他は維持。Android実機では攻撃の見え方／当たり判定を追加確認。

## 2026-11-19 — SERA v481: レーザー威力60%・横薙ぎ終了0.5秒前で当たり判定終了

- `scripts/main.gd`の既存`_on_enemy_projectile_hit`へ末尾の任意引数`damage_multiplier:float=1.0`を追加。通常攻撃のHP／シールド消費は1.0を維持。シールド・防御補正・KO／反動の従来処理は改変せず、指定した攻撃の威力だけを調整。
- `scripts/bittaran_battle.gd`の背部レーザー命中時のみ`LASER_DAMAGE_MULTIPLIER=0.60`を指定し、旧基準HP18→10.8、ガード消費23→13.8（実際のダメージは装備による防御・ガード補正あり）。0.2秒ごとの多段ヒット／無制限ヒット数・1.5m追尾境界は維持。
- `scripts/bittaran_attacks.gd`：なぎ払いの原本Blockbench横薙ぎ停止・折返しの関節キーを前脚の最終静止キーt=2.00s、後脚の最終静止キーt=1.25sとして、`SWEEP_HIT_END_BEFORE_STOP_SECONDS=0.50`を引いた時刻で接触判定を終了。前脚は**0.75〜1.50s**、後脚は**0.25〜0.75s**の当たり判定へ変更。左右の4本共通。モーション原本・判定開始・足先と下肢の実コリジョン・1攻撃1ヒットは変更なし。
- `tools/bittaran_railgun_runtime_check.gd`に実戦のレーザーHP・ガードダメージ60%、通常弾威力100%、リアルなノックバックとビーム連続命中を検証するアサーション追加。`tools/bittaran_keyframe_hit_sector_runtime_check.gd`に実Blockbench停止キーから0.50秒早い判定の終了と、終了後の足先接触でもヒットしない回帰を追加。
- FXのプリベイク書き出しがゲームの短縮した当たり判定範囲を参照すると、元の土埃トレイルを途中で消してしまうことをCIで発見。\n- `source_sweep_fx_window`を別定義し、前脚0.75〜1.25s、後脚0.25〜0.75sの元の土埃軌跡／エミッターを保持。ライブモーションのダメージ窓は最終停止フレームから0.50s前という条件で独立して検査。\n- Android実機での回避・当たり判定感と音量はheadless CIでは検証不可。

## 2026-11-19 — SERA v480: ユーザー提供音源3種をSERA足音・チャージ・レーザー照射へ組み込み

- `ロボットを殴る2.mp3`由来の`assets/sera_player_footstep_v480.ogg`を、`scripts/main.gd`の既存`_on_foot_contact(side)`シグナルに接続。左右接地の際にそれぞれ0.96/1.03ピッチで再生。空中では鳴らさず、既存の合成接地音は未同期時のフォールバックに限定。足音の実効長0.53秒。
- `重力魔法2.mp3`由来の`assets/bittaran_charge_v480.ogg`を青い球体発生10秒で1回再生。10秒間の充填中は無音、11秒の縮小では再起動せず、12秒の発射時に停止。チャージ時間の2秒に調整。
- `sen_mi_b_saberu.mp3`を`assets/bittaran_laser_attack_v480.ogg`（発射瞬間に1回）と`assets/bittaran_laser_sustain_loop_v480.ogg`（照射中ギャップレス反復）へ加工。持続区間の波形を端でオーバーラップ／クロスフェード。12秒開始・14秒終了に実砲台制御を連動。0.08秒立ち上げ、0.14秒減衰、途中再起動はしない。
- `scripts/bittaran_railgun.gd`へ音声の専用`AudioStreamPlayer`3層とAndroid raw-Ogg読み込みフォールバック、死亡／リセット時の停止を追加。レーザー軌道追従（逸脱1.5m超で加速）、青球体縮小11秒からの追尾減速、レーザーダメージ多段ヒット0.2秒間隔は変更なし。
- **音源4ファイルをバイナリGit blobとして格納。** GitHub側のblob SHAとローカルの`git hash-object`結果を4点すべて照合し、一致を確認。
- `tools/sera_footstep_railgun_audio_runtime_check.gd`を`tools/sera_ci_manifest.txt`に登録。実シーンの接地イベント、Ogg原本の読み込み、チャージ・射撃の位相／停止、レーザー2秒維持、終了時フェードを検証。
- Android実機の足音タイミングと連続レーザーの体感音量はheadless CIでは確認不可。

## 2026-11-19 — SERA v479: 青球体縮小開始で砲台減速、照射地点1.5m超で追尾加速

- **11秒を境界にする。** 青球体の縮小開始 = `FLASH_END - FLASH_SHRINK_SECONDS` (=11.0s)。球体発生10秒から縮小開始直前までは0.7秒加速導入後の速度無制限追尾。縮小開始から12秒の発射までの1秒間は旧追尾速度の**0.7倍に制限**。球体の縮小は開始と同時に実行、球体モデルやFXは保持。
- 縮小中はレーザー発射前なので、プレイヤーが射線地面投影から離れてもリアル速度連動の追尾加速を適用しない。照射時のみ加速を許可するよう`_track_player`に追尾モードを追加。
- レーザー照射中の地面投影とプレイヤー足元の水平距離による加速条件は`BEAM_GROUND_GAP_METERS`を**0.5mから1.5m超へ変更**。1.5m以内は従来比0.7倍、1.5m超ではプレイヤー実移動速度＋距離超過補正で加速。
- `tools/bittaran_railgun_runtime_check.gd`でt=11境界の前後、縮小中の速度制限・ビーム専用追尾加速無効、距離1mでは加速せず1.5m超で加速すること、原本演出・多段ヒットの継続を検証。
- 0〜10秒の充填静止、青球体2秒、レーザー2秒、0.7秒復帰、照射0.2秒ごとの無制限再ヒット、ビットタラン本体2倍速の設定は維持。Android実機の見た目は未確認。

## 2026-11-19 — SERA v478: レーザー無制限再ヒットと地面投影0.5m超の追尾加速、ビットタラン2倍速

- `scripts/bittaran_railgun.gd`：1照射1回の命中ラッチを廃止。実際のビーム接触に対して0.20秒の時間制御で何度でもダメージを許可。レーザー2秒間に「最大n回」という上限は設定しない。
- 発射後の基準旋回速度は旧値の0.7倍。レーザー中心線を地面へ投影したプレイヤーと同じ前後位置とのXZ距離が0.5mを超えると、プレイヤーのリアル移動量から算出した速度＋0.5m逸脱の補正に必要な速度へ連続加速する。元の軌道へ戻れば0.7倍まで減速。ワールド水平回転と砲台俯仰、最大射程と原本モデルは維持。
- `scripts/bittaran_ai.gd`：歩行0.936→1.872m/s、加速度0.78→1.56m/s²、静止旋回34→68°/s、移動旋回22→44°/s、停止時の向き微調整18→36°/s。原本歩行キーフレーム周期と脚IKは維持。
- `scripts/bittaran_battle.gd`：再命中時も既存のHP／ガード／Damageknockへ渡す。Damageknock再開は禁止のまま、追加HPダメージを適用。
- `tools/bittaran_railgun_runtime_check.gd`：0.7倍基準・0.5m地面逸脱・移動速度連動、1照射内の複数実ヒットと20/100fps非依存時間間隔、チャージ・照射・復帰、AI定数を検査。
- Android実機の追尾と被弾感覚は未確認。

## 2026-11-19 — SERA v477: 青球体チャージ開始から高速追尾（充填10秒間は基本姿勢）

- 用語を明確化：0〜10秒は**充填**で砲台の基本姿勢を維持しプレイヤーを追尾しない。10〜12秒が**チャージ**であり、球体発生と同時に1度だけ追尾を開始する。
- `scripts/bittaran_railgun.gd`：球体表示開始t=10で0.7秒のsmoothstep導入を使用し、球体が縮小して消えるt=12まで追尾角速度制限なし。発射中t=12〜14は既存RUN/BOOST依存速度制限へ即切替。14〜14.7秒は基本姿勢へ復帰。
- `tools/bittaran_railgun_runtime_check.gd`：プレイヤーがどんなに動いても0〜10秒は無追尾、球体開始の低速導入、球体縮小中の高速追尾、発射時からの角速度制限、1照射1ヒット、RUN/BOOST差、ガード、復帰と次の充填中の静止を検証。
- 原本砲身・エフェクト・ガード・ノックバック・脚IK・攻撃判断は維持。Android実機の動きは別途確認。

## 2026-11-19 — SERA v462: ビットタランの通常歩行の歩幅を2倍に

- 現行の歩行IK `scripts/bittaran_foot_ik.gd` で、通常の対角2脚踏み替えを開始する足先アンカー距離基準を 0.62m → 1.24m（2倍）に変更。歩きの一歩を大きくする。
- `SOURCE_STEP_DURATION_SECONDS=0.52`、脚上げ `SOURCE_STEP_HEIGHT_METERS=0.22`、AIの移動速度・加速度、足先ワールド接地、攻撃後の強制2ペア復帰と攻撃前の正常3歩条件は維持。
- `tools/v435_bittaran_gait_three_support_runtime_check.gd` に新しい距離倍率と従来の脚上げ・周期を検査する条件を追加。既存Godotの接地・反復攻撃回帰も対象。Android実機未確認。
- CIの旧v346接地テストで、長い歩幅のあとボスを瞬間移動すると残存IK姿勢で足の到達誤差が出ることを確認。テレポート時はWaitポーズと4脚IKを再初期化する方式へ修正。
- 歩行中は胴体の現在位置に合わせて着地点を更新するため、実際の足先軌跡距離は移動・旋回状況によって変化する。

## 2026-11-19 — SERA v461: スラスター音を半分に変更

- ユーザー指示「スラスター音量を半分に」に従い、01継続音と13-1加速音の振幅をそれぞれ50%に変更。
- GodotのdBゲインに換算：両方とも-6.0206dB。
- 01：-12.5dB → -18.5206dB。13-1：-3.0dB → -9.0206dB。
- 01ループ、加速時13-1重ね再生、追尾、0.22秒フェードアウト、Android OGG直接読み込み、BGM固定-5dB、モデル・攻撃判定を維持。
- Godot音声実戦テストで、両ゲインと従来BGMゲインを検証。Android実機の聴感は未確認。

## 2026-11-19 — SERA v460: 攻撃選択の距離判定を各足先の実位置に変更

- 問題：`scripts/bittaran_attacks.gd` の `_choose_kind` がプレイヤーと胴体中心のXZ距離から踏みつけ（≤3m）／弾き（3.75〜5.15m）／なぎ払い（2.7〜7.1m）を選んでいた。その後最寄りの脚を選んでいたため、足先に近いのに踏みつけが選択されない場合や、選んだ脚が技の射程外である場合があった。
- 修正：4脚をそれぞれ独立評価し、`player.global_position` と、IK更新後の実際の足先`foot.to_global(sole_local)`の**水平距離**で各攻撃の成立を判定。`_leg_can_reach` は脚ごとに踏みつけ≤3m、前脚のみ弾き3.75〜5.15mかつ±38°、なぎ払い2.7〜7.1m（前脚±115°、後脚±165°）を検証する。
- 脚選択も足先→プレイヤーの実距離を最優先とし、ごく小さい同距離優先度のみ維持。存在しない後脚KICKの生成禁止、原本Blockbenchモーション、実当たり判定・IK・接地FXは変更しない。
- `scripts/bittaran_battle.gd`: 従来の予定足場`available_attack_feet()`ではなく、実行時の足先ノードと`sole_local`から4脚のワールド座標を取得。繰り返し攻撃のブロック判定にも同じ4脚の位置を渡す。
- v453テスト`tools/bittaran_attack_distance_priority_runtime_check.gd`を実足先基準の16境界ケース・リアル3歩攻撃に変更し、`tools/bittaran_attack_variation_runtime_check.gd`も同じ足先距離仕様へ更新。
- 既存の「攻撃前に3歩歩く」「同じ攻撃種類を連続で使わない」ルール、既存の音量（01 -12.5dB／13-1 -3dB／BGM -5dB）はそのまま。

## 2026-11-19 — SERA v459: ユーザー指定で音量をv457へ戻す

- `scripts/sera_thruster_audio.gd`: v458の音量増加を撤回し、01持続音を **-12.5 dB**、13-1加速音を **-3.0 dB** のv457設定へ戻す。
- `scripts/bittaran_battle.gd`: スラスター音に合わせてNeural Flow BGMを最大7dB下げるv458のダッキングを削除。元のBGM **-5.0 dB** 固定へ戻す。
- v458で修正したAndroid OGG直接読み込み・インポート未完了時の再試行・片方の音源だけ届いた場合の再生継続は維持。
- 01の4.90秒ループ・0.22秒フェードアウト、STEP/追尾開始時13-1を重ねる仕様は変更しない。
- Godot実戦音声テストで元の音量とボスBGM非ダッキングを確認。Android実機の最終聴感は未確認。

## 2026-11-18 — SERA v458: Androidでスラスター音が聞こえない不具合修正

- v457の01・13-1は両方ともGitHub mainに実音源が存在するが、静的`preload("res://assets/*.ogg")`がAndroidのGit同期直後の未インポートOGGを利用できない可能性がある。
- `scripts/sera_thruster_audio.gd`: 実行時にResourceLoaderのインポート済みストリームを試し、無い場合は`FileAccess.get_file_as_bytes`と`AudioStreamOggVorbis.load_from_buffer`で直接デコード。アプリ可書込領域`user://`のOGGにも対応。同期後にインポートが遅れたときは2秒ごとに再読み込みし、取得経路をログに出す。音源欠損でもシーン全体のロードを中断しない。
- 既存の持続01ループ／ステップ時と追尾加速時の13-1重ね再生／220msのスラスター音フェードアウトを保持。実際の音源01のRMS約-15dBFS、13-1のRMS約-27dBFSに合わせ、持続プレイヤーを-12.5→-3.0dB、加速音を-3.0→+6.0dBへ調整。ピークは両音ともクリップしない目標。
- `scripts/bittaran_battle.gd`: ボスBGMの-5dBが粉塵音と加速音をマスキングしていたため、スラスター／加速中のみ最大7dBの軽いサイドチェーンダッキングを適用。立ち上がり0.10秒・戻り0.32秒の滑らかな遷移で音楽は止めない。
- `tools/sera_thruster_audio_runtime_check.gd`: インポート無しのuser:// OGG直接デコード、実音源、プレイヤー音量、01と13-1の重ね再生、ボスBGMのダッキングと復帰をテスト。
- Godot headlessは音声デコード／ノードの再生状態を検証できるが、Android実機の音量・外部出力・古いAPKへの即時反映は検証できない。GitHubマージのみでは既存のAPKは更新されない。

## 2026-11-18 — SERA v457: 01の継続噴射音と13-1の加速音を実装

- ユーザー提供音源から4.90秒のクロスフェード済み01 OGGループと0.95秒の13-1 OGGを作成し、`assets/sera_thruster_01_loop.ogg`／`assets/sera_thruster_13_1_acceleration.ogg` に実バイナリを追加。
- `scripts/sera_thruster_audio.gd`: BOOST中は01を連続ループ。STEP開始・追尾加速中に13-1を同時再生、追尾／STEP終了まで01は途切れない。スラスターOFF時は01を220msで振幅フェード。`scripts/back_thruster_fx.gd` も炎を同じ時間で減衰。
- `tools/sera_thruster_audio_runtime_check.gd`: 4.90秒ループ、加速音重ね再生、ゲームのBOOST→STEP→追尾、停止フェードを実OGGで検証。既存攻撃・移動判定は変更しない。Androidでの聴感は別途確認。

## 2026-11-18 — SERA v456: なぎ払いFXを実脚モーションから事前構築

- `tools/bittaran_sweep_fx_export_runtime_check.gd` で4脚の原本なぎ払いを実際の戦闘シーン＋足元IK込みで60fps再生し、実メッシュ最下点の接触XZ座標を収集。前脚は0.75〜1.25秒、後脚は0.25〜0.75秒の範囲を13点ずつのローカル空間時刻表に圧縮。 `scripts/bittaran_sweep_fx_baked_data.gd` としてリポジトリへ保存。Androidでは追加の骨格シミュレーションは実行しない。
- `scripts/bittaran_battle.gd`: 最初のなぎ払い開始時、粉塵放出前のentry中に事前生成済みの4脚の発生点を一度ロード。実行時に原本を再生してシミュレーションを行わず、保存済み時刻表を使う。
- `scripts/bittaran_dirt_fx.gd`: 発生開始時に実メッシュ床接地点で既定の軌跡を一度だけ平行移動して固定し、以後は`authored_time`に応じてタイムラインを再生する。途中から足先が浮いたりIK座標が揺れたりしても発生位置／個数が変わらない。長い足の振り戻しや攻撃の余韻ではFXを追加しない。
- 28基の安全再利用CPUParticles3D、地面に接触して消える小石、実メッシュ当たり判定、踏みつけ／弾きのエフェクト、ダメージ判定・原本IKの仕様は維持。
- `tools/bittaran_sweep_prebaked_fx_runtime_check.gd`: 4脚の事前生成データ・時間同期・実際の戦闘中の放出を検査。発生開始後に足先座標を100m飛ばしても粉塵が追従しないことを検査。 `tools/bittaran_sweep_fx_export_runtime_check.gd` で現行IKを再生した記録と固定軌跡の誤差を検査、`tools/bittaran_sweep_fx_baked_provenance_check.py` でBBMODEL Git Blob SHAと軌跡データの整合を検査。
- Android実機の半透明描画・タッチ操作・端末FPSは未確認。

## 2026-11-18 — SERA v455: 実機動画に基づくビットタランVFXのチラつき・ジャンプ・発生漏れ修正

- ユーザーの約19秒のAndroidゲーム録画で、地面の粉塵が突然現れて消える／離れた場所へ移る／攻撃で途切れる症状を確認。
- `scripts/bittaran_dirt_fx.gd`: v454の10基の一回限りCPUParticles3Dを0.045秒間隔で循環再利用し、寿命1.12秒の途中（約0.45秒）にrestart()していた。プールを28基に増やし、1.12秒＋0.09秒以上経過した空き発生器のみ使用する。プールを使い切った場合は描画を飛ばした数を記録し、CIで発生漏れを検出。
- 同じ`trace_sweep`でソース足先が1フレーム0.32m以上急変したときは、不自然な粉塵ラインを引かず、安定した接地点を再確認。発生済みの粒子は足先に追従させず、ワールド空間に残して自然にフェードする。
- `scripts/bittaran_battle.gd`: 最低点から8.5cm以内に限定して頂点を突然選び直していた接点計算を、連続的な指数加重法に置換。VFX用のみ床近接0.12mまで許容してサンプル抜けを軽減し、ダメージ判定・足先への物理接地は従来の厳密条件のまま保持。
- `tools/bittaran_fx_continuity_runtime_check.gd`: 実時間1.67秒相当の連続掃きテストで前の粒子寿命中の再起動／描画欠落／原点ジャンプを検出、四脚の踏みつけ・なぎ払いと前脚2本の弾きで実戦源モーションの粉塵発生を検査。Android実機の最終レンダリング品質とフレームレートは未検証。

## 2026-11-18 — SERA v454: 実足先に密着した高密度エフェクト再構築

- `scripts/bittaran_battle.gd`: 4脚の実メッシュAABB各頂点をワールド座標で調べ、最下部8.5cmの接地面にある点群のXZ平均を粉塵の発生原点にする。ゲームプレイの当たり判定と踏みつけリングの座標は従来の足先AABB中心で保持。
- `scripts/bittaran_dirt_fx.gd`: なぎ払いの疎らな連続発生器（34粒/1.25秒）を廃止し、10基の使い回し一斉噴出器（36粒/回、約0.045秒間隔）に再設計。各フレームの足先移動量を0.42mに制限して実接地軌跡に追随。粒子はワールド座標固定で自然消滅、再生終了後の新規放出なし。
- 踏みつけは接地した足幅内に灰色の濃淡ある複数層（濃い土・薄い煙・横へ拡がる砂・細粉・小石）を同時噴出。弾きも接地面から進行方向に密集して射出。長距離に飛び散って発生位置が不明確にならないよう初速と発生幅を整理。
- 石・砂粒の地面接触時の即時削除、GL CompatibilityのMultimesh省負荷方式、原本Blockbench・IK・足先接触判定・被弾処理は維持。
- 新設 `tools/bittaran_ground_fx_rebuild_runtime_check.gd`: 4脚の実メッシュ底面に発生点が収まること、移動した親Nodeでもworld座標が不変なこと、各攻撃の密度、軌跡に沿う石・粉塵、実戦SWEEPの足先からの距離を検査。Android実機の見た目/FPSは未確認。

## 2026-11-18 — SERA v453: 近距離STOMP・離れた正面中距離KICKの選択を明確化

- `scripts/bittaran_attacks.gd`: STOMPのボス相対水平距離を3.00m以内、KICKを3.75〜5.15m・正面±38°に限定。至近距離でKICKを選ばず、3.00〜3.75mではなぎ払いの従来セクターが有効。実際の被弾は実メッシュと床接地を基準とする従来方式を維持。
- `scripts/bittaran_ai.gd`: 攻撃前3歩の近距離旋回歩行の条件を3.00mへ揃え、踏みつけ射程からの不用意な後退を防止。技種の連続禁止、他技のための位置調整、後足のKICK禁止は維持。
- `tools/bittaran_attack_distance_priority_runtime_check.gd`: 距離14ケースと実戦シーンの初回攻撃（2.50mからSTOMP、4.35mからKICK）を60Hzで検査。強制攻撃再生なし、最低3歩と実際の攻撃開始距離を照合する。
- Blockbench原本・キーフレーム、踏みつけ接地、なぎ払い判定、粉塵の仕様は変更しない。Android実機の見た目・操作・FPSは未検証。

## 2026-11-18 — SERA v452: なぎ払いの初回地上ストロークのみ被弾・踏みつけ復旧

- 実測：原本SWEEP前足は最初の地面を這う攻撃をt≈0.75–1.25で行い、その後速度が低下してt≈1.5–2.0は余韻、t≈2.04以降は足戻し。後足は初回の前→後ストロークt≈0.25–0.75、以降は戻り。v451の前t=2.14167／後t=0.975発生は**足戻し区間**に判定があった誤り。
- `scripts/bittaran_attacks.gd`: SWEEPは前t=0.75–1.25、後t=0.25–0.75の原本時間のみ当たり判定を許可。足先が実際に地面に接触していることは実戦コード側で必須。減速中、余韻、復路の足戻しでは一切ダメージを出さない。KICKの伸長開始キーt=0.25＋0.10秒の判定は維持。
- `scripts/bittaran_ai.gd`: STOMPがAIから一度も選ばれない原因を実戦再現。近距離から必須3歩の間に後退して2.85mを超えていた。これを初回STOMP射程内の接線方向の歩行に変更。同一技連続禁止を解決するためのSTOMP後の後退、最低3歩歩行、脚の戻しは維持。プレイヤーが0.90／1.65／2.40／2.75mの4ケースすべてで、最初にSTOMPが出て他技へ派生することを実戦で確認。
- `scripts/bittaran_battle.gd`: STOMP衝撃は単純に効果音/粉塵のフラグを待つのではなく、原本の下降中に**実際の足先メッシュが初めて床に接地した瞬間**に一度だけ発動。最初の接地は前足t≈1.467、後足t≈0.985。着地の床領域（実際の足先幅×1.5）内だけにダメージ判定し、広い仮想ショックウェーブにダメージを与えない。エフェクトノード不在でもゲームの接地判定は失われない。
- `scripts/bittaran_dirt_fx.gd`: SWEEPの土埃は初回の接地攻撃ストローク中だけ再放出。余韻と足戻しでは新規粉塵を発生させず、残留粒子だけ自然に消える。
- `tools/bittaran_keyframe_hit_sector_runtime_check.gd`: 前後左右なぎ払いの攻撃時間、実接地、早すぎる被弾と**余韻中に1回限り被弾ラッチを検証用に解除しても再び被弾しない**ことをGodotで照合。 `tools/bittaran_sweep_stomp_timeline_runtime_check.gd`: STOMPの初着地パルス・多重発動防止・4つの近距離からの実AI踏みつけ選択と後続攻撃を60Hzで検査。単発モーション確認のみの従来のテストから改善。
- モーション原本のBlockbenchキー、ボーン/メッシュ/Pivot、および他の攻撃の仕様は変更しない。Android実機の描画、被弾の体感とFPSは未確認。

## 2026-11-18 — SERA v451: 攻撃の当たり判定を原本キーフレームと接地へ同期、プレイヤー相対位置で技選択を最適化

- `scripts/bittaran_attacks.gd`: KICK(前左右)はキー`t=0.25`から伸長が始まるため、判定開始を`t=0.35`、有効な伸長の終端キー`t=0.75`で終了。新しい前SWEEP(左右)は接地・復路の初キー`t=2.04167`から0.10秒後の`t=2.14167`に開始し`t=2.50`まで。後SWEEP(左右)は復路の初キー`t=0.875`から0.10秒後の`t=0.975`に開始し`t=1.25`まで。時刻は追加のWait/攻撃導入時間を除く**Blockbench原本の再生時間**であり、原本キーは変更しない。
- `scripts/bittaran_battle.gd`: 実際の下肢＋足先メッシュのAABBがプレイヤーカプセルと重なる場合に限ってダメージを与える既存設計を維持。なぎ払いは判定時間中でも**攻撃脚の実メッシュが床Y=0に接地**していない場合はダメージ無し。上肢・頭・体・土埃で当てない。踏みつけは従来の足着地1回判定。
- 攻撃種別と脚はプレイヤーのボス相対XZ距離・方角を使用。踏みつけ: 2.85m以内・全方位（最も近い実脚）、弾き: 2.65–5.15m・正面±38度（前脚のみ）、なぎ払い: 2.70–7.10m・正面/側面±115度、後方は±165度まで後脚を使用（最後方15度は旋回）。脚選択は実足位置との距離を優先し、正面／背面の腕脚を軽く優先する。最終的な被弾は実メッシュ判定のみ。
- `scripts/bittaran_ai.gd`: 旧停止距離7.8mは新なぎ払い射程7.1mの外で攻撃不可デッドゾーンを作るため、停止5.85m・再追尾6.4m、近距離後退3.35m・周回範囲5.95mへ調整。最低3歩・同じ攻撃を連続しない・2対角脚の復帰・実移動で距離変更する仕様は維持。
- `tools/bittaran_keyframe_hit_sector_runtime_check.gd`: Godot実戦シーンと原本骨格キー6種を照合。判定時刻前に実メッシュへ重なってもダメージ無し、開始後に重なると実際にダメージ処理が走ることを確認（前後左右SWEEP／前左右KICK）。なぎ払いの地面接地も検査。位置11種・攻撃脚4ケース、実戦AIによる複数回攻撃検査も維持。
- v345/v347のPython静的チェックは旧・停止距離7.8m固定値を要求せず、現在の射程とAI停止/再追尾の整合性を検証するよう更新。
- Android実機のアニメーション表示・当たり判定の体感・FPSは未検証。

## 2026-11-18 — SERA v450: 攻撃モーションが初回で止まる実戦AIデッドロックを修正

- 実際の自動戦闘を60Hzで4,500フレーム観測。プレイヤーが約6.8mで静止すると初回SWEEP後に歩数が131回まで進むにもかかわらず、二度目の攻撃が一度も始まらないことを再現。歩行ゲートは既にクリアしており、原因は同一攻撃禁止＋距離一定の周回移動が別の合法攻撃の射程へ到達できない点だった。
- `scripts/bittaran_ai.gd`: 最後の攻撃がSWEEPなら距離を詰めてKICK/STOMPへ、最後がKICK/STOMPなら距離を広げてSWEEP/KICKへ。強制再生や攻撃判定範囲の緩和ではなく、現実の歩行で別の合法攻撃範囲を作る。攻撃前3歩、視野外での旋回、同一攻撃禁止を維持。
- `scripts/bittaran_foot_ik.gd`: 全工程原本なぎ払いの終了で`source_ik_leg_return_at_home`を通知し、中断扱いで失われていた攻撃後の2対角脚の足戻しを復旧。`scripts/bittaran_battle.gd`: ソースモーションの終端→IK返却の1フレームを明示して、接地中の胴体位置を固定。
- `tools/bittaran_repeat_live_battle_runtime_check.gd`: `force_start()`を呼ばず、プレイヤー静止で60Hzの実戦AI・原本再生・IK足戻し・再攻撃を連続検証。6.8m固定では修正後に SWEEP→KICK→SWEEP→KICK→SWEEP→KICK の6回連続を確認。1.65mからの追加ケースも含めてCIで検証。
- Android実機でのプレイフィール、描画・FPSは未確認。Godotの重点・全体CIを基準に統合する。

## 2026-11-18 — SERA v449: 20件のBittaran回帰テスト失敗と実ゲームの起き上がり・接地制御を修復

- Godot 126/126・Python 182/182の全件合格に向け、現行v448 source-ground IKの実装とlegacy検証前提を比較。単にテストを除外せず、物理的な不具合はゲーム側で修正した。
- `scripts/bittaran_foot_ik.gd`: source-IK経路で欠けていた脚破壊後の転倒・起き上がり時刻の更新を復元。視覚胴体の転倒・復帰、立ち上がり完了からの2対角脚の追従歩行、歩行中の実接地位置の再目標化を追加。初期Wait時は全4脚を二ボーンIKで骨格接地。骨長・元メッシュ・親Pivotは不変。弾き/踏みつけ/なぎ払いの全攻撃後、支え脚をWait補間の後に再拘束して地面への沈み込みを防止。
- `scripts/bittaran_battle.gd`: 実際に使用中のsource-IK経路でもHeadの常時プレイヤー追従・脚との干渉制限を動かす。`scripts/bittaran_ai.gd`: 3歩歩行が未達でも視野外へ無理に歩かず、その場旋回してから進む。ただし同一攻撃の再選択を避ける回り込みは継続。
- `tools/v346/v347/v352/v366/v367/v368/v376/v393/v399/v418/v435/v436/v440` 等のテストを更新。旧版の固定しゃがみ0.34m、攻撃の逐次復帰・0.5倍速なぎ払い、存在しない後足KICK、旧IK状態変数を要求せず、現行の解剖学的骨長・接地・原本1倍速・実戦攻撃の継続動作を検査。v436は全10種の合法攻撃を916回の関節姿勢で検査。v435は各攻撃に実際のリスポーン初期化を適用。
- `tools/codex_project_check.py`: `project.godot`の正本起動シーン（ビットタラン戦またはメニュー）の実在確認へ修正。
- Android実機でのプレイフィール・描画・FPSは未確認。Godot headlessの成功は実機の目視品質を保証しない。

## 2026-11-18 — SERA v448: ユーザー作成の前後なぎ払い全工程を四脚へ統合

- ユーザーアップロードの `ビットタラン (1) (1) (1).bbmodel` を編集しない原本 `models/storage/ビットタラン_20261118_新なぎ払い.bbmodel` に保存し、前左 `なぎ払い_L` 2.625秒/73キー、後左 `後足なぎ払い_L` 1.54167秒/36キーを正本 `models/bosses/Bittaran.bbmodel` に移植。右前・右後は左右のボーンIDを交換し、回転Euler y/z反転・位置x反転で生成。原本に既存のWaitや弾き等と重複するキーUUIDが11個あるため、ゲーム統合側だけ新しいIDへ振り直し、原本そのものと回転/位置/時刻値は保持。
- `assets/bittaran_data.gd` を新正本と一致させて更新。なぎ払いは従来の前半0.5倍速、別足戻しIKを通さず、振りかぶり・掃き・足戻しを原本時刻1倍速で全再生、終了後のWait/Idle接続のみ短い0.2秒の移行。
- `scripts/bittaran_foot_ik.gd` は新なぎ払い中の攻撃脚を旧直線足戻し制御で再上書きしない。支え脚の短い最終復帰フェードは実接地点へIKで再拘束し、床を突き抜ける現象を抑止。
- 追加テスト `tools/bittaran_uploaded_full_sweep_runtime_check.gd`：4脚の合計218キー、秒数・1倍速・Android埋め込み一致を実測。 `tools/bittaran_uploaded_sweep_battle_runtime_check.gd`：Godot戦闘シーン4脚310フレーム、支え脚接地誤差最大0.00121m、攻撃脚の足先地面貫通最大0.000002mで合格。
- 既存のGodot全体テスト126件のうち20件は旧仕様・先行未解決項目のため不合格。Python182件は全合格。Android実機での画面確認は未実施。全体CIが合格するまで改善が必要。

## 2026-11-17 — SERA v423: leg aim yaw no longer somersaults across the +-180-degree seam

- Device feedback on v422: the KICK angles of the front-right and rear-left legs still did not line up. A full-circle bearing sweep of played kicks (reflected comparison against played leg_fl, no aim compensation) found the catastrophic cells on the rear legs: leg_rl at player bearing 330 and leg_rr at bearing 30 deviated 6.43m at the sole with a 170-degree foot orientation error at hold; leg_rl at 300 and leg_rr at 60 showed 33-54-degree strike transients. All other bearings and the front legs matched their mirrors (front-right within ~1 degree everywhere).
- Cause: in `bittaran_rig.gd` `aim_authored_attack_leg`, the aim demand sat at ~+-175 degrees in those geometries (rear leg, player in the front-opposite sector — reachable when Sera dashes across the boss during the stance/windup). The extending clip keeps rotating the reference direction across the +-180 seam, so the wrapped demand flipped sign between ticks and the clamped target jumped from -85 to +85 degrees; the 300deg/s slew then dragged the whole kick 170 degrees around during the strike and hold (aim yaw log: -85 at strike start, +85 by hold on leg_rl/330; mirrored on leg_rr/30).
- Fix: unwrap the demand against the CURRENT attack_leg_aim_yaw before clamping, so the slew stays continuous and on one side of the seam. Clamp values (kick 85 / sweep 75 degrees) and slew rate are unchanged; away from the seam the computation is identical to before (verified: the full-circle sweep is bit-identical outside the four seam cells). In that unreachable geometry the residual miss is ~90 degrees on either side, but the kick no longer flips mid-strike.
- New regression check `tools/v423_bittaran_aim_seam_runtime_check.gd` plays the three seam geometries and asserts sole deviation <= 1.0m and foot angle error <= 30 degrees against the played leg_fl mirror; it fails on all cases with the pre-fix code (6.43m / 170 degrees) and passes with the fix (0.64m / 0 degrees, the ordinary rear-leg fitted-sole level).
- Android device visuals are not verified. The v422 known remainders are unchanged: rear mesh sole ~1.29m fitted-point offset at full extension, and the windup fold hanging from the reversed Body pitch (~0.94m fold float).

## 2026-11-16 — SERA v422: rear attacks align the attacking hip to the source hip height

- Device feedback on the v419/v421 build: motion still looked wrong; the user localized it to the diagonal pair (front-right / rear-left) and proposed aligning the body's rear to the source leg's hip height for rear attacks instead of lowering the whole body evenly.
- `bittaran_foot_ik.gd` `_apply_attack_chassis_pose`: for rear-leg (leg_rl/leg_rr) KICK/SWEEP, the constant clip-0 sole calibration (about -1.45m of uniform Y for the whole attack) is replaced by a per-tick alignment: the actor Y offset places the attacking hip at the height the SOURCE (leg_fl) hip has at the same clip time, sampled via the existing source sampler and enveloped with the same into/fade curves. Front legs and STOMP keep the previous calibration.
- Measured in the symmetric corner-bearing geometry (played, aim-compensated, hip-relative sole vs the played leg_fl mirror): rear KICK windup deviation 2.84m -> 1.90m, strike 2.20m -> 1.39m, worst strike joint step 104deg/tick -> within 65deg/tick. New regression check `tools/v422_bittaran_rear_hip_alignment_runtime_check.gd` guards those bounds plus the front legs' exactness.
- Deliberately unchanged, documented in README_v422_ja.md: at full extension the rear MESH sole still lands ~1.29m from the mirrored point (the fitted gameplay sole is exact); the rear feet's local frames are not mirror images of the front pair's, so ankle, foot orientation and mesh sole cannot all be exact at once — bending the foot to the fitted point was measured to cost a 33.7-degree extension tilt (source ~9 degrees) and is left as a design decision. The chain-played windup fold still hangs from the front-back reversed Body pitch (fold sole floats ~0.94m).
- Android device visuals are not verified.

## 2026-11-16 — SERA v419: one Blockbench BODY+leg attack mirrored to all quadrants

- Device request: mirror authored BODY + all three attack-leg joints by X/right and Z/rear for all KICK, SWEEP and STOMP, with all four positions exact at the FIRST attack frame; remove independently manufactured front/rear BODY leaning and unify ground corrections across limbs.
- Runtime `bittaran_rig.gd` applies source leg_fl's full BODY and 3-joint world rotations, spatially mirrored by X and Z depending on target quadrant; inverse local-parent transforms preserve the true reflected toe quaternion under each leg's different bind frame. BODY's Wait-relative source delta is mirrored with exactly the same X/Z selection for all three attacks; source BODY tilt/roll are not damped or clamped by a new auxiliary pitch. All attack rotations come from original Blockbench keys from frame zero, not a delayed KICK shoulder/world mirror interpolation. Fades to Wait happen only on recovery.
- `bittaran_foot_ik.gd` no longer applies v414 extra +/-25deg rear pitch, v418 rear-only corner-height inverse tilt, or different front/rear contact-height policies. All quadrants derive author playback from source world-mirrored animation and share mirrored KICK/SWEEP floor contact and whole-limb mesh safety. STOMP impact/end-effector and recovery likewise share front/rear IK treatment. Root/torso user-authored BODY rotation retains yaw tracking from combat. `rear_corner_pitch_delta` remains zero for backward diagnostic compatibility.
- v419 new strict Godot regression tests 4 legs ×3 moves ×8 source times ×3 authored leg joints=288 WORLD quaternion comparisons, including attack time 0 and 1/60sec; whole BODY source mirrored quaternion validated, plus no synthesized IK BODY pitch. Preexisting v414, v413, v397, v385, v386 and others are checked under new source mirror constraints instead of obsolete rear-only 25-degree/Wait-preview/damped-Body contracts.
- Existing reach-independent full KICK (v418), world foot contacts, STOMP toe-perpendicular impact, 8-repeat toe twist and 16-repeat kick axial twist remain regression checked. Blockbench original file and asset data are untouched. Physical Android visuals are not verified.

## 2026-11-16 — SERA v418: full-distance-independent KICK and foot-contact inverse rear torso corners

- User requested: replay KICK without considering the player's distance, and for all rear-leg attack types derive the actual BODY rear corner/attachment elevation backwards from ground contact. v404/v406 previously scaled KICK reach by distance between the hip and an aim point; this squeezed even the original fully keyed source clip near the player. `bittaran_rig.apply_authored_attack_pose` now fixes `kick_reach_factor=1.0` at every time and distance; `bittaran_foot_ik` no longer reads this value or applies reach truncation. Angular guidance and hit windows are unchanged; a close player can legitimately be overshot. Only the anatomical two-bone max length and floor collision guards remain.
- New per-tick `_adjust_rear_chassis_corner_to_contact`: after applying the authored BODY pitch and live attack yaw, compute the foot's desired floor-contact ankle target. KICK samples the original mirrored hip-relative source ankle/sole/rotation at current clip phase, SWEEP uses its current authored foot/mesh lowest point, and STOMP uses the aimed floor point minus the real vertical toe's local contact offset. Compute the actual upper/lower limb lengths and floor-reachable maximum rear hip height `ankle_y + sqrt(max(reach² - XZ_delta², 0))`. Only the positive height deficit is used; contact weight is a smooth envelope per attack.
- To move the actual **torso corner**, rather than detaching the attacking shoulder or vertically shifting the actor/root, pitch the articulated `Body` itself around the WORLD-height-fixed average of both FRONT shoulder sockets. Each candidate changes the Body local X rotation and translates the Body pivot by the minimum front-height compensation; the front edge Y is invariant, the rear BODY corners follow its physical rotation. Search both signs and binary-search the limited pitch (`REAR_CORNER_MAX_PITCH_RADIANS=0.58`), cap sink at 1.75m and restrict mesh-floor penetration. Preserve the attacking shoulder's fresh authored world rotation after Body pitch to avoid reintroducing v417's axial roll; all support legs still IK-solve to world-anchored soles after the Body change. Attack interruption/recovery clears temporary pitch and socket flags. v414's original 25° rear-to-front BASE pitch remains, with only the new measured foot-contact compensation added.
- New real-scene regression `tools/v418_bittaran_full_kick_and_rear_contact_corner_runtime_check.gd` checks all four legs at two player distances each (eight full KICKs) with invariant `kick_reach_factor=1.0`; checks 2 rear legs × 3 attack kinds (six attack clips) for fixed rig/root Y, finite measured socket height, and required contact-derived rear BODY corner response during KICK and STOMP.
- v404's obsolete close-range anti-overshoot assertion was replaced with an assertion that the FULL strike can legitimately pass a near player. v414 now subtracts `rear_corner_pitch_delta` from the final BODY pitch before checking that the original opposite 25° baseline and return are still reproduced within the original tolerance, and separately checks the extra pitch bound. v415 world source pose, v416 rear floor crawl, v417 axial-roll regressions remain unchanged.
- Unit/headless tests and embedded model files are unchanged except test scripts; no user source Blockbench `.bbmodel` modified. Android-device visual animation remains unverified.

## 2026-11-16 — SERA v417: rear KICK axial-roll from repeated IK passes

- Device report: the attacking rear leg visibly rotates about its own axis during KICK. This arose after v416's grounded-crawl correction, which repeatedly calls `_solve` for the same rear leg within one physics frame (mirrored trajectory; reach; whole-shin floor guard; rear crawl; final shin clearance).
- Old `_align` uses shortest-arc quaternion on the joint's CURRENT world basis. After several correction passes with different knee and ankle axes, repeated swings inherit noncommuting axial roll, causing the thigh and shin to rotate about their length even if the toe's world rotation remains correct.
- During `advance_ik`, immediately after torso pitch / attack aiming are applied and before the first IK, capture the attacking rear KICK leg's original upper/lower bone directions and world quaternions into a per-tick `rear_kick_axis_source` dictionary. Clear this and the `rear_kick_axis_solved` flag every tick and during cancellation. For each KICK `_solve`, use `_align_from_authored_axis` to place thigh/shin at the new IK bone direction by minimal swing from that SAME current-frame original reference; do not compound rotations from the previous solve. All other legs and motions still use the original `_align`.
- New full-scene `tools/v417_bittaran_rear_kick_axial_roll_runtime_check.gd`: 2 rear legs x 2 player bearings x 4 repeat KICKs; compares actual upper/lower world rotations to theoretical minimal-swing-transferred current-frame authored rotations at every source clip frame 0.32–0.62, tolerance 0.35deg, and also checks >=80% of those frames crawl within 20cm of arena floor. This supplements v416's repeat toes and crawl test and v415's original bone pose checks. The mirrored chassis pitch, fixed body/root height, original toe rotation, support-foot anchoring and leg lengths remain unchanged.
- Initial CI on implementation commit: all registered Godot regressions and all dedicated Bittaran focused regressions passed. Android device visuals remain to be inspected.

## 2026-11-16 — SERA v416: rear KICK grounded crawl and repeat front-right toe stability

- Device report: both rear-leg KICKs hover well above the ground and leg_fr toe bends from the second KICK onward, progressing with repeats. New real-scene `v416_bittaran_rear_ground_right_toe_runtime_check.gd` initially measured the rear-attack mesh lowest bounds at source clip 0.35–0.60: leg_rl 0.84–2.51m, leg_rr 1.14–2.81m above floor. leg_fr toe LOCAL angle drifted ~0.26° by repeat 8 at unchanged target/root while the WORLD toe orientation stayed stable. The previous v408 only required the extension to be near floor at SOME sample and v415 allowed 3–4° angular drift, so neither caught this visibly bad behaviour.
- Root cause of rear hovering: v415's counter-rotation of the chosen shoulder under the independently v414-reversed BODY pitch kept its authored WORLD rotation but moved its pivot upward when the BODY rotated. Source kick trajectories are hip-relative, so the strike lifted with the rear hip. Store the current frame's source shoulder WORLD position before replacing BODY pitch, restore it after counter-rotation, then apply the independent chest aiming yaw. The source joint positions and rotations now remain invariant under only the chassis posture substitution (expanded v415 test). The BODY/root position remains untouched.
- Even with exact restored source shoulder, the rear toe still floated 0.94m (left)/1.19m (right) at some clip frames: the transferred front-left kick's original XZ reach at floor height exceeds the rear two-bone anatomy. New `_ground_rear_kick_foot` corrects only the rear KICK's clip 0.18–0.85 and is fully weighted through 0.32–0.62. It lowers the IK goal to the actual foot MESH floor clearance, then clamps XZ radius to the minimum anatomically reachable distance at that Y (never rotating the toe or changing its bearing). It re-solves for the authored knee pole, then raises the goal just enough to avoid visible shin-floor intersection, without translating the BODY or shoulder. The existing per-frame authored rendering and poststrike recovery remain; old v410 and v412 whole-limb floor penetration tests pass.
- Root cause of repeat toe curl: `start_authored_attack` had cached the last IK-shaped LOCAL rotations from the previous clip as the next KICK's entry. The target limb's 3 entry rotations are now the original immutable Blockbench Wait keys; the planted windup and transition still use IK and the original source leg animation. This breaks historical axial-twist feedback in the 2nd and subsequent strikes; STOMP/SWEEP retain their prior live transitions.
- The new eight-consecutive-attack v416 Godot test checks both rear legs at >=80% of the mid-extension source frames within 20cm of the floor and front-right near-range local/world toe angle deviation <=0.12/0.20 degrees at matched source and whole-attack phases. v408 keeps front leg source profile within 0.50m while the rear profile ceiling is 1.20m as necessary for floor-reachable IK under fixed inverse-body pitch. Old v415 source rotation and complete source position are still checked; source `.bbmodel` and embedded model are unchanged.
- Both dedicated Bittaran and all-model Godot CI passed after these runtime/criterion changes. Android physical-device visual quality remains unverified.

## 2026-11-16 — SERA v415: preserve rear authored leg motion and prevent cumulative kick torsion
- Blockbench source `models/bosses/Bittaran.bbmodel` / Android embedded payload are unchanged. Original source attack `弾き`, `踏みつけ`, `なぎ払い` animates the front-left leg; the engine mirrors/reanchors those source keys to the other three legs.
- v414 introduced an independent 25° backward-to-forward torso pitch for rear-leg attacks; previously it also inherited into the already retargeted attacking leg's world orientation. v415 applies a freshly calculated BODY-relative inverse correction only to the chosen rear shoulder, conserving the animation's original world upper/lower/foot rotations under the fixed-height new chassis pitch. Head tracking and support-foot IK remain independent.
- The source kick sampler previously saved/restored only the left-front source leg's rotations. If left-front was IK-solved as an earlier support in the same tick, its joint positions had moved, so sampling used mutated limb geometry. Snapshot full local transforms, temporarily restore immutable Blockbench bind positions for source trajectory evaluation, then restore full transforms. The sweep pose sampler uses the same procedure.
- The KICK trajectory's author-source sole was previously read from mutable `sole_local`, whose fitted values differ for each target leg/time; this allowed sampled contact points to feed their own previous IK output back into source evaluation. Add immutable `source_sole_local` captured at IK setup, use it for all source kick/contact probes, and restore it unconditionally when clearing an attack.
- New v415 tests validate all 3 rear attack source rotations across the torso pitch substitution and 6 consecutive real kicks for each of 4 legs. The repeated-kick fixture isolates actual history-dependent angular drift from expected AI root yaw between attacks by restoring the same initial scene transform for every repeat.

## 2026-11-16 — SERA v414: rear-leg attacks mirror default backward pitch with fixed torso height
- New request supersedes v413's +8° rear-tail lift: for all rear STOMP/KICK/SWEEP poses, use the current authored Wait BODY local-X angle as the baseline and interpolate to its exact negative in the attack windup. Keep the opposite angle during strike/hold, and restore the original through authored recovery. BODY keyed yaw/roll, live head aim and foot clips keep their owners. Front-leg attacks are unchanged.
- Stop translating the visual root while any rear attack is active. Disable per-attack contact-height shift, STOMP chassis reach dip, and chassis floor clamp for rear only; keep the normal root baseline, collision-independent individual striking-leg clearance, planted foot IK and ongoing head tracking. This may alter geometric ground clearance at a more pronounced forward pitch; inspect in actual Android playback.
- The obsolete v397 rear-up-at-least-8° expectation and v413 incremental-offset test are superseded by the neutral-equal-opposite-pitch contract. A new v414 live full-scene test asserts all six rear strike types follow the pitch envelope and never change visual-root Y.
- Model, Blockbench keyframes and Android generated source data remain unchanged.

## 2026-11-16 — SERA v413: rear-high posture on all Bittaran attacks and no attack-state leakage
- Kept authored forward-leaning front-leg STOMP/KICK/SWEEP untouched. Extended the established rear SWEEP local-X 8° tail-lift across rear KICK (弾き) and STOMP, with the existing per-kind windup/recovery envelope; no Blockbench keyframes altered.
- Root-cause fix for intermittent displaced KICK anticipation: normal `set_attack_pose({})` cleared only the contact-height offset, retaining per-leg exit-lift, fitted soles, source trajectory, plant goals and pole markers from the prior attack. It now calls `clear_attack_pose()`; forced restarts also call this full teardown. Also reset transient spiral/sway, and rig kick mirror/reach coefficients after completion. Keep independent world-floor/locomotion grounding correction intact.
- Regression diagnosis: v391's right-rear KICK knee-fold invariant failed by ~19° despite removing the extra rear pitch if the respawn handler properly restored the old attack's fitted source sole. That proved the existing source-trajectory clearance had implicitly relied on a stale toe offset from an earlier attack. The correction now applies rear-leg positive toe-floor clearance to the shoulder and ankle goal together (exactly once), and during the folded entry constrains excessive ankle reach to the geometric radius matching the authored knee angle for the actual two-bone leg lengths. The guard fades out ahead of the fully extended strike, preserving contact reach. The complete teardown at normal end/restart/respawn is retained. v391, v412, v413 and both complete CI workflows pass on the pre-documentation code commit `80664b2`.
- Regression: `tools/v413_bittaran_rear_attack_reset_runtime_check.gd` checks every attack/limb windup tilt and teardown for natural end and a forced leg switch. Existing v397/v410-v412 tests remain registered.
- Android visual/interaction verification remains a separate device step.

## 2026-11-16 — SERA v412: kick windup direction and leg twist, front-back-reversed rear torso tilt, no head-dodging on front legs (four device reports on v411)
- Device reports on v411: (1) "the KICK windup faces an abnormal direction on every leg", (2) "the leg model twists", (3) "for rear-leg attacks, implement the torso tilt as the front-back reverse of the front-leg attacks", (4) "during front-leg attacks, make the leg not avoid the head". (1) and (2) share one root: two pre-plant mechanisms kept acting on the leg the v410 windup plant pins at the basic stance.
- Diagnosis (1)(2) (measured, diag traces of leg_fl/leg_rr kicks): the IK's KICK inward pole wind (pole slerped 0.70 toward the body midline over the windup) dragged the pinned leg's knee at up to ~7 m/s with the sole fixed, and on leg_fl the slerped pole crossed the hip->sole axis mid-windup and flipped the bend plane (knee snap ~1.6m, twist dump 35 degrees in one tick). The rig's shoulder aim, applied all through the windup, rotated the planted shoulder every tick, and _solve's shortest-arc roll inheritance accumulated it as mesh twist: leg_rr's shin rotated +105 degrees about its own axis in one windup (thigh on leg_fl ~43 degrees, dumped in one tick at the flip). Fixes: the inward wind now starts with the strike (its recovery fade from v402 is unchanged), and aim_authored_attack_leg applies no shoulder rotation while planted -- the yaw VALUE keeps slewing so the strike starts aimed, and the application ramps in over the strike entry (0.25s kick / 0.36s sweep, matching the IK entry blends). Post-fix: windup knee speed ~3 m/s (the hip's own travel under chest tracking), leg_rr shin twist change 19 degrees, max per-tick twist step 2.2 degrees.
- Diagnosis/fix (3): _mirror_body_delta_for_attack now takes the reflection planes from the caller by quadrant. SWEEP: left-right for right legs, front-back for rear legs. KICK/STOMP: front legs unmirrored (the v411 leg_fr finding stands), rear legs front-back only. The v411 rejection of the front-back reflection (entry pole crossing, -0.214m) is fixed at its root: the sweep entry now blends its pole point by DIRECTION around the hip (slerp of the normalized hip->knee direction, distance lerped) instead of by position, so the projected pole can no longer cross the hip->sole axis mid-blend. For KICK, the trajectory sampler and the contact probe keep sampling under the front-form Body (_authored_body_rotation_for_kick_sampling): sampling under the reversed pose routes the reversal through _body_damp_compensation, which rotated the extracted chain at the shoulder (measured on leg_rl: ankle profile off 1.68m, extension foot tilt 41 degrees, trajectory goals past the IK reach clamp, v385/v400/v408 failures). The played chassis reversal still tilts the re-anchored leg assembly; the calibrated trajectory is untouched. Knock-on: the reversed tilt drops the rear hip mid-strike and leg_rl's shin corner dipped -0.054m with the foot clear, so the post-solve clip guard's KICK-freeze measurement now covers the WHOLE limb (hip+goal lift strategy, as the sweep entry already did) instead of the foot only.
- Diagnosis/fix (4): steer_knees_for_head folded planted front knees up to the 0.70 rad cap to dodge the tracking head during attacks (measured: leg_fl at the cap during leg_rl/leg_rr kicks). The scan now holds every front leg's bend target at zero while an attack is running, stance preparation included, so locomotion folds ease out over the preparation and none remains by the windup; locomotion and knockdown avoidance are unchanged. The gate covers all attacks, a superset of the requested front-leg attacks (rear attacks point the head away from the front knees anyway); the release notes flag this for the user.
- Check amendments (disclosed): v410 Part 2 and v411 Part 1 now expect the quadrant mirror form for SWEEP, and build the wanted rotation in the rig's own frame (conjugate the local delta by the rig rotation, reflect, conjugate back) -- reflecting the world delta errs ~7 degrees on the front-back plane because the Wait pose's own tilt does not commute with that reflection (the left-right plane happened to commute, which is why the world form passed in v411). v395 is superseded in part by the user's explicit instruction: its scenario IS a front-leg attack (leg_fr sweep) whose front-left support knee was required to fold; phase 1 now asserts the knee stays unfolded during the authored front-leg attack, phase 2 asserts it still folds proactively once no attack is running, and the untouched-striker/head/planted-sole/no-head-lift invariants are unchanged.
- Checks: new tools/v412_bittaran_windup_twist_rear_tilt_runtime_check.gd asserts, per leg in natural geometry, windup knee steps <= 0.09m/tick, shin twist steps <= 8 degrees and <= 75 degrees total, rear KICK/STOMP Body deltas equal to leg_fl's reflected front-to-back with equal magnitudes, front-leg head_knee_bend <= 0.05 once the attack runs, and rear-KICK whole-limb clearance >= -0.02m. It fails on the v411 tree (rear kick Body form) and passes here. Full local suites: static 182/182, Godot 148/148. The focused workflow's v412 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v411); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v411: mirror the SWEEP body MOTION (Wait-relative delta, left-right only) — rear-leg torso twist (device report on v410)
- Device report on v410: "when attacking with a rear leg the torso twists abnormally" and "the attack windup is not normal." The accompanying video's recording predates the v410 sync (the fight was already in progress ~90 seconds after the merge), but both complaints reproduced on the v410 tree, so they were treated as current.
- Diagnosis (measured: natural geometries, chassis rotation vs rest decomposed per phase): the twist is the SWEEP Body mirror v410 introduced. Mirroring the ABSOLUTE pose is exact as a mirror image, but the boss's rest pose is not front-back symmetric (front hips sit higher than rear hips), so the Wait-relative motion each leg actually played differed: leg_rl's Body target delta measured 30.2 degrees (world, clip 0) against leg_fl's 22.5, and composed with the 51-degree chest tracking yaw the chassis reached 94 degrees total in-scene on leg_rl sweeps — already ~90 degrees by the end of the windup, which is why the windup itself read as broken. On the v409 tree the same case measured 63 degrees: v410 regressed it.
- Fix (scripts/bittaran_rig.gd): _mirror_body_delta_for_attack replaces _mirror_body_rotation_for_sweep. It takes the damped track's Wait-relative delta into world space, reflects THAT across the rig's left-right plane only, and re-anchors it on the Wait pose. Reflection conjugation preserves the rotation angle, so every leg plays leg_fl's tilt at exactly leg_fl's magnitude — the same treatment the leg chains get from their delta map. leg_rl shares leg_fl's delta verbatim; leg_fr/leg_rr play the left-right reflection. _body_damp_compensation's damped side reads the same function as before, so the attacking leg's world trajectory is unchanged; the v405 probe path is untouched.
- Rejected alternatives (measured): (a) Reflecting the delta front-back as well (the geometrically complete mirror): the inverted crouch pitch dropped leg_rl's hip ~0.6m, the sampled sweep pose sat ~2.2m under the floor, and mid-entry the blended knee pole crossed the hip->sole axis, snapping the knee through the floor for one tick (-0.214m). The torso's sweep motion is a side-driven weight shift, so rear legs share their own side's motion instead. (b) Mirroring KICK's delta the same way: leg_fr's calibrated trajectory/reach/aim stack broke (v400/v406/v408/v409 failed); KICK's in-scene totals (30-70 degrees on all legs) show no abnormality, so KICK keeps its unmirrored track and a KICK mirror remains a separate dedicated retune if ever wanted.
- Measured post-fix: in-scene SWEEP torso totals leg_fl 56 / leg_fr 60 / leg_rl 52 / leg_rr 33 degrees (leg_rl was 94), with windup peaks equal to strike peaks (the twist no longer forms during the preparation); whole-limb mesh lowest -0.000m on rear sweeps; side-camera screenshots of leg_rl/leg_rr sweeps show the low ground-hugging arc with a level torso. The v410 windup plant is unchanged.
- Check amendments (disclosed): v410 Part 2 now asserts the delta form (magnitude-preserving left-right reflection of leg_fl's Wait-relative delta; rear-left shares it verbatim) instead of the absolute-pose reflection; Part 1 (windup plant) is unchanged. v385's BODY prepose reference is now the rig's played target _authored_body_rotation_for_attack instead of the raw clip rotation: the raw key is leg_fl's unmirrored source and a correctly mirrored rear leg plays more than the 1.15 rad tolerance away from it; the invariant (the Body moves >0.12 rad into the attack's intended opening pose) is unchanged.
- Checks: new tools/v411_bittaran_sweep_body_delta_mirror_runtime_check.gd asserts the delta form and magnitude equality at sampled clip times, in-scene SWEEP torso rotation <= 70 degrees from rest and attacking-limb clearance >= -0.02m on all four legs in natural geometries. It fails on the v410 tree (leg_rl delta magnitude 30.2 vs leg_fl 22.5 degrees) and passes here. All prior focused checks pass (v383/v385/v386/v389/v391/v392/v396-v410). Full local suites: static 182/182, Godot 147/147. The focused workflow's v411 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v410); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v410: plant the attacking leg at the basic stance through the windup; mirror the SWEEP body tilt exactly (two device requests on v409)
- Request 1: "when Bittaran returns to the basic stance before an attack, return the attacking leg to the basic stance position too." Diagnosis (measured): the v398 stance preparation already lands the attacking sole exactly on its home contact (ready error 0.0 for all 12 combos, in displaced-anchor, natural and AI-flow setups). The visible gap was the 0.70s windup after the replant: the attacking leg left home toward the clip's first pose (sole travel 2.2-3.5m KICK, 2.9-5.4m SWEEP), so it was the only leg not settled at the basic stance when the strike began. The fix therefore covers the windup, not the replant.
- Fix (scripts/bittaran_foot_ik.gd): during the windup the attacking leg is solved to its basic-stance home contact exactly like a support (new plant block in the authored branch). The plant target is captured once per attack from _home/_rotation_home, not the anchor: a force-started attack can inherit a mid-step anchor rotation (leg_rr's planted foot sat ~14 degrees pitched, the clip guard added a 0.49m lift every windup tick, the recovery fallthrough re-applied it to the hip, and the hip snapped ~0.98m at the strike boundary — the v386 regression this uncovered). In real play the stance preparation already sets anchor == home, so nothing changes there. The plant also zeroes the recorded exit lift per tick, which the fallthrough re-applies.
- Fix (scripts/bittaran_rig.gd): the attacking leg's blend-in moved from the windup into the first part of the strike (KICK 0.25s, inside the source clip's fold-hold; SWEEP 0.36s, over the outbound lead-in). The Body keeps its original windup timing (the crouch IS the preparation); STOMP is unchanged.
- KICK entry: the trajectory now blends from the planted stance over the strike's first 0.25s. Its entry knee/ankle are captured from the last SOLVED joint positions (new leg["last_knee"]/leg["last_foot"], recorded at the end of _solve): reading the live joints at that moment returns the rig's entry snapshot under the turned Body, which threw leg_fl's captured knee 2.4m sideways. The old windup aim-yaw scaling was removed (the trajectory starts at the strike, where the aim factor is already 1).
- SWEEP entry (new): the strike's first 0.36s is a solved blend from the planted stance to the authored pose, sampled per tick by the new rig sampler sample_authored_sweep_pose (the leg's own retargeted pose under the track-only Body, returning sole/foot/knee/rotation/hip plus the pose's own leg-mesh lowest point). Sole, ankle and knee all blend and the sole point is fitted per tick like the KICK trajectory's (blending sole+rotation alone swings the ankle on the sole offset's ~2m arc and trips the reach clamp). The sampled pose's floor deficit is applied with the freeze branch's whole-limb lift formula, scaled by the blend weight and carried by the goals (the hip translation itself is applied once by the recovery fallthrough, which re-applies the recorded exit lift at recover_t == 0; translating in the branch as well hoisted the hip ~1.4m). A mid-blend margin (0.06m, enveloped 4*bw*(1-bw)) covers the slerped toe corner's arc, and the post-solve clip guard now watches the WHOLE limb mesh during the entry window with the hip+goal lift strategy (leg_fr's shin corner still dipped 0.13m past the sampled deficit). At the window's end the solved pose meets the pure authored pose and the freeze branch takes over (its lift re-measures the same deficit, so the hip is continuous).
- Request 2: "re-mirror the SWEEP body tilt cleanly onto all legs with leg_fl's motion as the source." Diagnosis (measured): the sweep Body rotation was mirrored by a local component flip of the bind-composed quaternion (_mirror_author_delta); the Body bind frame is tilted against the rig planes, so the played tilt deviated from the geometric mirror of leg_fl's by up to 34.0 degrees (leg_fr and leg_rl, worst at clip 0). Fix (scripts/bittaran_rig.gd): _authored_body_rotation_for_attack's sweep branch now reflects the rotation across the rig planes in world space (_mirror_body_rotation_for_sweep, the same _reflect_world_rotation the leg chains have used since v400). Mirror error is 0.0 degrees at every sampled clip time on every leg. _body_damp_compensation's damped side now reads the same function, so the compensation absorbs the new Body mirror at the shoulder and the attacking leg's world trajectory is unchanged; the v405 contact-probe path is untouched (compensation is IDENTITY while the probe is active).
- Also fixed (found by the amended v391): an attack interrupted before its recovery leaked its fitted KICK sole point into the next attack — the contact probe and the trajectory's clearance reference both read the source leg's sole point (measured: leg_rr's played fold shifted 0.12 rad across an interrupted sequence). set_attack_pose now detects a restart (identity change or a rewound attack clock) and restores every fitted sole point first. Real-play interruptions (leg break, boss death) already went through clear_attack_pose; this covers director force-restarts.
- Measured post-fix: windup sole deviation from home 0.0m on all 8 KICK/SWEEP variants (was 2.2-5.4m); strikes still reach in natural geometries; whole-limb mesh never below the floor (leg_fl sweep entry worst was -0.58m in the first entry-blend draft, -0.04 after the sampled lift, clean with the margin + guard); sweep Body mirror error 0.0 degrees everywhere.
- Check amendments (disclosed): v391's fold comparison moves from the windup's end to just after the strike's 0.25s entry blend, against the trajectory sample at the same clip time — since v410 the windup holds the planted stance and the prepose fold forms over the entry blend; the assertion (no folding beyond the authored pose) and its 0.09 rad threshold are unchanged. v396's authored-rotation equality window now starts after the sweep's 0.36s entry blend (during the blend the knee/toe locals are the solver's by design); its floor-penetration assertion still covers every tick, blend included.
- Checks: new tools/v410_bittaran_windup_plant_sweep_mirror_runtime_check.gd asserts the windup plant (sole within 0.05m of home, all 8 variants), natural-geometry reach (<= 2.2m), whole-limb floor clearance (>= -0.02m) and the sweep Body mirror (<= 1 degree vs the plane reflection of leg_fl). It fails on the v409 tree (windup drift 2.24m on leg_fl/kick) and passes here. All prior focused checks pass (v383/v385/v386/v389/v391/v392/v396-v409). Full local suites: static 182/182, Godot 146/146. The focused workflow's v410 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v409); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v409: aim attacks by the leg's hip corner, with natural guidance caps (device report: body over-rotates and twists, front legs attack behind the rear legs, rear-leg aims twist grotesquely)
- Device report on v408, with the design directed by the user: during attacks the body rotates too much and twists strangely; front legs attack to behind the rear legs; rear-leg aims twist abnormally, apparently because the chest tracking points its front diagonal at the player. Directed design: point each attacking leg's hip corner at the player, give that angle a natural limit, and apply the same to the arm (shoulder) aim.
- Diagnosis (measured: boss facing fixed, player on a 5m circle at 8 bearings, all legs x kinds): chest yaw peaked at 70 deg on KICK/SWEEP (slew-capped; the desired value ran to the 140 deg cap) and 125 deg on STOMP, with the chassis bone's yaw delta vs rest reaching 127 deg — the visible corkscrew. Front-leg KICKs forced at a player behind landed the foot at boss-local z -2.30/-2.22, well behind the rear hip line (-1.24). The rest hip corners measure +34.4/-33.8 deg (front) and +145.8/-146.0 deg (rear) in boss-local space, so turning the rear corner toward a player behind needs only ~34 deg of chest yaw; the shared 45-deg-across formula demanded ~135 deg there.
- Fix (scripts/bittaran_battle.gd): the chest's desired yaw is now the player bearing minus the attacking leg's hip-corner bearing (ATTACK_CHEST_CORNER_DEGREES, per-leg constants from the measured hip positions), and ATTACK_CHEST_MAX_YAW_DEGREES drops 140 -> 60. The 100 deg/s slew is unchanged.
- Fix (scripts/bittaran_rig.gd): the shoulder aim caps drop to measured natural demand: ATTACK_LEG_AIM_MAX_DEGREES_KICK 130 -> 85 (same-side natural demand peaks at ~71 deg: rear leg, player dead behind; the v403-geometry cross-side demand of ~96 deg now saturates and lands ~23 deg off instead of wrapping the leg around the body) and ATTACK_LEG_AIM_MAX_DEGREES 100 -> 75 (SWEEP front-leg demand is ~53 deg once the chest turns the hip corner in; the rear-side cases that demanded ~88 deg were compensating for the chest twisting the wrong way and now sit at ~34 deg).
- Measured post-fix (same grid): chest yaw <= 60 deg everywhere; chassis twist yaw STOMP 127 -> 62 max; rear-leg KICK at a player behind: twist 63 -> 30 deg and the foot still reaches (min distance 1.16m); rear SWEEP at a side player: aim 87.7 -> 34.4 deg, min distance 1.29 -> 0.78m; front KICK forced behind: foot local z -2.30 -> -1.67. Every geometry the director actually selects (nearest foot, same-side hemisphere) still reaches the player.
- Check amendments (disclosed): v392's chest expectation now computes the clamped corner bearing per leg instead of the fixed -side x 45 deg; its HEAD no-roll and STOMP toe assertions are unchanged, and the file keeps its historical chest_45 name. v403's rear-leg lateral offset is placed on the attacking leg's own side: with the boss rotated PI, world +X is boss-local -X, so the original +2.5 put the player on leg_rr's side while leg_rl attacked across the body — a selection the director never makes; under the 85 deg cap that forced case lands 23.4 deg off, over the check's 20 deg threshold. Assertions and thresholds are unchanged.
- Checks: new tools/v409_bittaran_guidance_limits_runtime_check.gd asserts the caps (chest 60, aim 85/75) for every leg/kind/bearing, corner tracking at windup end in the natural geometries, front-foot local z >= -1.85 on a behind-forced KICK, and natural-geometry reach <= 2.2m. It fails on the v408 tree (aim 130 deg, chest 70+ deg) and passes here. All prior focused checks pass (v383/v385/v386/v389/v391/v392/v396/v397/v399-v408). Full local suites: static 182/182, Godot 145/145. The focused workflow's v409 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v408); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v408: play the KICK as the source leg's foot trajectory on every leg (device report: leg_fr kick not a true mirror, foot floats, aim wrong; user direction: reproduce the original ground-crawling motion on all legs)
- Device report on v407: the front-right KICK is not an accurate mirror — the foot floats and the aim looks wrong. The user then directed the fix: reproduce the ORIGINAL motion (the foot extending low, crawling along the ground) on every leg, instead of patching the retargets further. A per-leg blend-path choice (joint slerp vs foot-space lerp) was implemented and verified locally first, then superseded by this trajectory design before shipping; it is not in this version.
- Diagnosis (measured): every joint-space retarget of the authored leg_fl clip distorts its foot trajectory on the other legs' bind geometry — leg_fr deviated up to 1.75m mid-strike / 0.36m at hold from the mirrored source trajectory, and the v407 foot-space ramp lifted leg_fr's sole to 1.11-1.28m. Two deeper defects compounded it: (1) the plane-reflected foot rotation does not act on a leg's own sole point like it acts on the source's (each foot's local frame differs by a constant rotation: fr 49.2 deg, rl 41.2 deg, rr 36.7 deg), so IK's ankle target landed metres off the transferred joint and tripped the reach clamp; (2) the aim's reference and the played trajectory were composed under the battle's chest yaw (up to +-140 deg on rear legs), spinning the trajectory and pushing leg_rl's aim demand past even a 130 deg clamp (56 deg travel error).
- Fix (scripts/bittaran_rig.gd): new sample_authored_kick_source(id, at, source_sole_local) samples leg_fl's authored chain under the attack's damped Body track WITHOUT the chest yaw, and transfers sole/ankle/knee hip-relatively in the rig frame (x-flip for right legs, z-flip for rear legs) with the foot rotation plane-reflected. The aim's KICK reference direction now comes from this trajectory, and the KICK aim clamp widens to 130 deg (the trajectory is re-solved by IK, so no physical shoulder stop applies; SWEEP keeps 100 deg). New kick_source_contact_height calibrates the actor offset to the trajectory's clip-0 fold (the IK passes leg_fl's sole point into it — passing the attacker's own read a point up to 3.0m off and sank the whole trajectory).
- Fix (scripts/bittaran_foot_ik.gd): for KICK, every windup/strike/hold tick solves the attacking leg to the reflected trajectory (entry blend over the windup from the planted sole), composing with the v406 reach shortening. Because the reflected rotation and each foot's sole point disagree (above), _solve is handed a per-tick sole point fitted so the rotation maps it exactly onto the transferred ankle->sole offset; the original point is blended back over the recovery (a one-tick restore would jump the ankle up to 1.7m). The goal is shifted vertically by the mesh-clearance difference vs the source leg (raise when this leg's mesh hangs lower, lower toward the floor — fold-weighted — when it reaches less, e.g. leg_rl's fold mesh floating 0.93m), and the post-solve clip guard now lifts hip+goal together for KICK so the source's toe-scrape along the floor does not bend the hip-relative profile. The v400 whole-limb lift and the foot-node clamps stay neutralized for KICK (they correct the joint retarget's pose, which is no longer played).
- Measured: ankle height profile vs the source leg in the game's own geometries — leg_fr deviation 0.00-0.13m (was 1.47m on the v407 tree), leg_rr 0.11m, leg_rl 0.17-0.45m (its v406 reach factor 0.59 vs the source's 0.42 rescales the path). All four folds plant their mesh on the floor (was: fr +0.39m, rl +0.93m floating in the diagonal geometry), the extension stays ground-low with no floor penetration, and v403 direction errors are gone (leg_rl aim yaw 100 deg saturated -> ~9-94 deg working range).
- Check amendments (disclosed): v391's prepose assertion now compares the knee FOLD ANGLE (hip-knee-ankle, world) against the trajectory sample instead of the knee's local quaternion (the solver's local roll is inherited through the shoulder; the fold angle is the protected quantity). v400's windup assertion now measures the foot MESH's lowest point (the rear legs' sole marker is not their contact point under the trajectory: mesh -0.001..0.003 while the marker reads 0.47), its fold bound is 0.20m, and its setup parks the player and resets the boss per leg (the free-AI settle measured wandering state, boss root y=1.53). v404's toe-tip overshoot limit rises 3.2 -> 3.6m (the trajectory's toe points straight along the aim like the source; the ankle overshoot limit 1.8m is unchanged and met at 1.57m). v405 Part B: KICK cases get their own chassis band [0.75, 1.16] plus a front-pair divergence limit 0.25 (the offset now calibrates to the played trajectory's fold under the damped Body: measured fl 1.07 / fr 0.87; SWEEP keeps [0.45, 0.75] and Part A's canonical samples are untouched).
- Checks: new tools/v408_bittaran_kick_source_trajectory_runtime_check.gd (folds planted, ankle profile bands by segment, no burial, ground-low extension, all four legs in natural geometries) — fails on the v407 tree (fr 1.47m / rl 2.12m / rr 2.47m profile deviation), passes here. All prior focused checks pass (v389/v396/v399/v400/v401/v402/v403/v404/v405/v406/v407). The focused workflow's v408 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v407); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v407: blend the KICK mirror chains in foot space (device report: kick sometimes whips over the top)
- Device report on v406: occasionally the KICK rotates and comes down from overhead like a whip. Grid measurement (4 legs x 8 angles x 2 ranges, boss facing the player) localized it to rear legs at saturated aim yaw; the worst case (leg_rl, player 5.0m on the front-right diagonal) peaked with the foot 1.96m ABOVE the hip during strike/hold.
- Cause: the v400 KICK fix slerps the shoulder/knee local rotations between the delta-mapped chain and the world-mirrored chain over the strike's first 0.30s. For rear legs the two chains are near-opposite poses (fold soles 4.2m apart on leg_rl, 5.8m on leg_fr), so the shortest-path joint slerp arcs the foot over the top of the body. Dead ends measured and rejected: fading the mirror weight by aim yaw (a partial blend parks the foot at the arc's peak, over 1.91), retiming the blend into the windup (same arc, over 1.68, just earlier), slot-1-only mirror (leg inverts, over 3.6), pure delta for rear legs (extension points up-back, over 2.83).
- Fix: during the ramp window only, the foot IK blends the two chains in FOOT space. A new rig sampler (sample_authored_kick_sole) returns each pure chain's sole position, foot rotation and knee position at the current clip time; the IK lerps the soles, slerps the rotations, re-applies the current aim yaw around the hip (the samples are unaimed), and solves the leg with the blended knee as the pole point (leg["authored_pole_point"], consumed by _solve's authored-pole override). At weight 0 and 1 the solved pose equals the pure authored pose (verified: the post-window hold trajectory is bit-identical to the v406 build), so both window ends are continuous. The v406 reach shortening composes on top (its ray now starts from the blended foot). SWEEP and STOMP are untouched.
- Measured post-fix: worst case peak 1.96 -> 1.11m above the hip (the remainder is the authored rear fold's own height at strike start, continuous with the windup); full grid shows no over-the-top case left (rear-leg values ~1.1-1.2 are the fold height, present in the windup already). All prior focused checks pass unchanged (v389/v396/v399/v400/v401/v402/v403/v404/v405/v406). Note: the aim-yaw oscillation at saturated sideways geometries (yaw travel ~460-500 degrees on forced leg_fr side kicks) is pre-existing v403 behaviour, unchanged by this fix and outside the reported symptom.
- Checks: new tools/v407_bittaran_kick_whip_runtime_check.gd asserts strike/hold foot height above the hip <= 1.35m in the reproduced case; fails pre-fix at 1.96. Full local suites pass: static 182/182, Godot 143/143. The focused workflow's v407 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v406); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v406: replace the v404 KICK reach slerp with a geometric IK shortening (device feedback on v405)
- Device video on v405: the KICK still looks wrong. Reproduced and measured locally (leg_fr kick, player 4.6m in front): during strike/hold the IK's whole-limb floor lift reads 2.49m and the attacking hip sits at y=4.35 (rest 2.66), the leg dangling from above with the foot sailing at y=1.84. leg_fl is the same shape (lift 1.95, hip 4.75).
- Cause: the v404 reach shortening slerped the authored joint rotations toward Wait. Rotating a fully extended leg toward the standing pose swings it DOWN through the floor: sampling the authored pose at reach factor 0.5 puts the leg-mesh lowest point at -1.65 (fr) / -2.49 (fl), -2.42/-3.02 at factor 0.12, versus +1.21/+0.41 at factor 1.0. The v400 whole-limb floor lift (built for the SWEEP shin) then hoists the whole limb by that deficit for the entire strike/hold. The v404 regression check measured only horizontal overshoot, so this passed.
- Fix: the rig no longer blends the pose (kick_reach_factor is still computed from the locked aim exactly as v404, but the pose is always the full authored one). In bittaran_foot_ik's authored branch, once a KICK's authored extension passes the target XZ length (2.30 + factor x 3.2, the v404 calibration), the sole goal is pulled back along the hip->foot ray and the leg goes through _solve with a new authored-pole override (pole = current knee, the stomp trick; the kick inward-pole block is skipped on those ticks via leg["authored_pole_active"]). Direction, trajectory, foot orientation and the bend plane stay authored; only the length changes. The constraint never engages at full reach (verified: full-reach closest approach 1.61m on both builds) and the recovery blend starts from the solved pose via the existing exit-goal capture.
- Measured post-fix at the reported geometry: hold lift 0.0, hip y 1.86 (the authored crouch), foot holds at y=0.77 near the player. All prior focused checks still pass unchanged (v396/v399/v400/v401/v402/v403/v404/v405/v389).
- Checks: new tools/v406_bittaran_kick_reach_solve_runtime_check.gd asserts, for fr/fl kicks at 4.6m, hold lift <= 0.30, hip rise <= 0.35 and (fr only; fl holds higher by authored design) foot y <= 1.30, plus a full-reach arrival guard (min foot-player <= 2.0; natural value 1.61). Fails pre-fix at lift 2.49. Full local suites pass: static 182/182, Godot 142/142. The focused workflow's v406 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v405); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v405: fix the v404 regression that dragged the chassis to the floor during attacks (device feedback on v404)
- Device video on v404: during KICK/SWEEP the boss sprawls to the ground. Reproduced and measured locally: the chassis bone's minimum height during stance/attack fell to 0.057m (SWEEP) versus the authored ~0.57m crouch of v403; KICK leg_fr 0.227 vs 0.576. The v404 twist damping and reach scaling themselves measured intact — the defect was in the attack's vertical placement.
- Cause: the IK captures its actor offset once per attack from the rig's canonical contact sample (initial_authored_sole_height: the author's keyframe-zero pose, FLOOR_Y - sole height). v404 implemented the Body damping and the leg compensation inside the shared pose functions (_authored_body_rotation_for_attack / _authored_rotation_for_leg), so the probe — which calls those same functions — silently started sampling the DAMPED pose. The sample drifted by up to +0.65m (leg_fl/kick: -0.5803 -> +0.0745), and the offset moved the actor down by exactly that drift (the in-scene chassis dip grew by the same amounts: fr kick +0.35, fr sweep +0.51, fl sweep +0.54). The compensation restores leg ORIENTATION exactly, but the damped Body also translates the hip pivot, which no joint rotation can cancel — that translation is what the probe absorbed.
- Fix (bittaran_rig.gd): initial_authored_sole_height now samples the author's original pose explicitly — Body via _authored_body_full_rotation and the leg compensation disabled via authored_contact_probe_active — restoring all eight canonical sample values bit-for-bit (4 legs x KICK/SWEEP). In-scene chassis dips are back to the v403 values exactly (fr kick 0.604, fr sweep 0.613, fl sweep 0.561, fl kick 0.0, stomp 0.035), with the v404 damping and reach scaling fully in effect (v400/v403/v404 checks all still pass, including the v400 windup-sole grounding, so the attacking fold still plants).
- Checks: new tools/v405_bittaran_contact_probe_runtime_check.gd pins the eight canonical sample values (tolerance 0.01) and asserts the close-range chassis crouch band (0.45-0.75m) for fr kick, fr sweep and fl sweep; fails pre-fix at the drifted sample (0.0745 vs -0.5803). Full local suites pass: static 182/182, Godot 141/141. The focused workflow's v405 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v404); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v404: stop the attack torso corkscrew and the close-range KICK overshoot (device feedback on v403)
- Device feedback on v403: the same defect was still visible. The user later pinned it down: the KICK itself, worst with the front-right leg while the player is in front of the boss. Decomposition in the live scene found two separate remaining defects, both in the attack posing (the v403 direction fix measures 0.0 degrees of error in these geometries and stays in place).
- Torso corkscrew: the shared KICK/SWEEP Body track itself pitches 34.4 degrees and rolls 19.7 degrees from Wait at its peak, the clips END at that peak, and the KICK then holds the fully twisted pose for its whole 1.50s hold, stacked with the 45-degree chest tracking yaw (in-scene chassis delta at close range: pitch 33.5 / roll 21.1 degrees). Fix (bittaran_rig.gd): for KICK/SWEEP, damp the Body track's pitch/roll delta from Wait — KICK pitch/roll to 45 percent, SWEEP pitch to 60 (measured: at 45 percent the sweeping ankle rises above hip height mid-arc, breaking v396's low-arc invariant; at 60 it stays ~0.19m below) and roll to 45 — keeping timing, direction and yaw; damping is applied to the source pose BEFORE the sweep mirror so mirrored legs stay exact mirrors (v396). In-scene result: pitch ~16 (kick) / ~21 (sweep), roll ~7 degrees; STOMP untouched (its track is flat and its 45-degree chest yaw is the pinned design).
- The leg chain was authored against the FULL Body pose, so damping alone tilted its world orientation by the removed pitch (v400's extension foot tilt 9 -> 31 degrees, windup fold sole floated at 0.1055). Compensation (same file): _authored_rotation_for_leg premultiplies the chain-root local of the delta-mapped (KICK) and absolute-mirrored (SWEEP) families with B_damped^-1 * B_full, and the KICK world-mirror family anchors its target worlds to the full Body pose while converting back through the actual damped parent — both restore the chain's authored world orientation (v400 tilt/sole and v396 symmetry back to their pre-v404 values) while the torso stays damped. The shoulder aim samples the same rotations, so v403's direction result is unchanged (all direction cases still pass at <=1.3 degrees in their check tolerances).
- Close-range KICK overshoot: the authored kick always extends to the leg's full length (hip-to-foot ~4.7m), so with the player ~1.8m from the hip the foot speared 3.5m past the player and the toe tip 5.2m past, and held there. Fix: apply_authored_attack_pose derives kick_reach_factor from the horizontal hip-to-aim distance, and _authored_rotation_for_leg blends the kick pose toward the leg's Wait stance by that factor, so the foot lands near the aim point (plus a 0.4m margin). The factor-to-reach line was calibrated in-scene (factor 0 -> ~2.30m, ~3.2m of reach per factor, flattening near full extension); the shoulder aim samples the same shortened pose, so v403's direction correction is unaffected. Residual: at point-blank (hip-to-player ~1.1m) the leg's minimum practical reach (~2.3m) still carries the foot about 1.4m past the player; unavoidable with a 4.7m leg and no new animation.
- Checks: new tools/v404_bittaran_body_twist_runtime_check.gd asserts bounded chassis pitch (<=22) / roll (<=14) with the crouch retained (>=8) for close-range KICK/SWEEP, and the fr KICK's aim-axis overshoot at close range (joint <=1.8m, toe <=3.2m incl. the foot's own ~1.9m length) plus mid-range reach; fails pre-fix with the measured 33.5/21.1 degrees. tools/v389 amended to pin player_hp during its case loops: hits legitimately accumulate across its 12 sequential cases (the boss closes in and connects, more so with the corrected sweep arc), and a player KO cancels the attack mid-play — an interaction that check (BODY floor clearance / down interrupt, driven by boss part damage) never intended to depend on; no assertion changed. tools/v400 amended to present its KICK cases at full-reach distance (player on the hip ray at 7.2m from the boss centre, hip-to-aim beyond the ~5.1m full-reach threshold): the check asserts foot orientation at FULL extension, which the new reach scaling makes a mid-range property; close-range reach is covered by the v404 check. No v400 assertion or threshold changed. Full local suites pass: static 182/182, Godot 140/140. The focused workflow's v404 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v403); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v403: KICK direction — cancel the retargeted clips' intra-strike direction rotation (device feedback)
- Device feedback on v402 (with video): the KICK still fires in a weird direction; the user suspected rotation. Confirmed by measurement: at strike start every leg's hip->foot direction is on the player (errors -19..+8 degrees), but while the leg extends, the direction rotates away on every leg except the authored leg_fl — at full extension: fr -47.5, rl -91.3, rr +37.7 degrees (fl -9.1); travel-direction error up to ~102 degrees. The retargeted clips (delta map + world-mirror blend) preserve joint orientations at sampled instants but not the extension path direction.
- The shoulder aim (bittaran_rig.gd aim_authored_attack_leg) fitted attack_leg_aim_yaw during the windup against a fixed extended-pose reference (t=0.625) and froze it at release, so it could not follow the intra-strike rotation. Fix, KICK only: (1) during strike/hold the reference sample is taken at the CURRENT authored clip time, so the measured direction is the pose the leg actually has; (2) the yaw keeps updating through strike/hold (may_aim = tracking or kick-in-strike/hold) against the windup-locked aim point — drift cancellation, not homing, the aim point still freezes at release; (3) the windup's predictive reference sample is taken with the strike's world-mirror weight (1.0) instead of the live weight 0, removing a fixed per-leg offset of up to 18 degrees (fr/rr) that was already present at strike start. SWEEP keeps the fixed reference and windup-only tracking (its arc is intentional).
- Result, in the geometries the selector actually produces (front legs vs a player in front with the boss facing them; rear legs vs a player behind with the boss facing away), travel-direction error is now <=1.3 degrees for every leg and lateral offset (was up to ~102). Known limit: a rear-leg KICK forced at a player in front (the selector never picks it: the leg is chosen nearest-first and KICK is chosen for players beyond the foot) still ends ~49 degrees off, because cancelling its ~97 degrees of drift on top of the windup fit exceeds the +/-100 degree shoulder-yaw clamp.
- Checks: new tools/v403_bittaran_kick_direction_runtime_check.gd asserts per-leg travel and extension direction errors <=20 degrees in the natural geometries; it fails on the pre-fix tree with the measured values (rl travel 90.7, fr 68.1 at lateral 2.5, rr 40.2). Full local suites pass: static 182/182, Godot 139/139. The focused workflow's v403 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v402); the full manifest registration is included. Android visual inspection still required.

## 2026-11-16 — SERA v402: fix KICK/SWEEP recovery snaps and recalibrate impact shake (device feedback)
- Device feedback on v401: the impact camera shake was not felt, and KICKs with legs other than leg_fl still looked wrong. Both reproduced and measured in the live scene.
- Shake: it did fire, but unprojecting a probe point through the real process loop showed a maximum image displacement of only 5.3px on the 720x1280 viewport (~105px per frustum-offset unit at the battle camera). Strengths recalibrated about 4-6x (STOMP lerp 0.34->0.10 by camera distance, KICK 0.16, SWEEP 0.19, gait footfall 0.030); the same measurement now reads ~22px at fight distance. Zero-settle behaviour unchanged.
- KICK recovery snap (rear legs, 56 degrees in one tick on the lower joint): during recovery the goal, hip and desired rotation all move smoothly, but _solve's knee-inward wind for the kicking leg kept following _attack_weight()'s long outgoing tail through the whole recovery blend; mid-blend the slerped pole crossed the bend-plane singularity and the solved knee flipped sides in one tick. Fix (bittaran_foot_ik.gd): the inward factor now also fades out over the first 0.12s after freeze_end. Post-fix worst per-tick joint delta in KICK recovery: 8.8 degrees (all legs).
- SWEEP/KICK handover snap (all legs for SWEEP, 49 degrees at the rear shoulder): the v400 whole-limb floor lift translates the attacking leg's shoulder every authored tick, but apply_pose restores the bind pivot each tick, so at the authored->IK handover the lift vanished in one tick (measured hip teleport 0.74m) while the blend goal still started from the lifted exit pose. Fix: the authored branch records the applied lift per leg (attack_exit_lift_world) and the recovery branch re-applies it decayed by (1 - recover_t) before _solve. Post-fix worst per-tick joint delta in SWEEP recovery: 18.1 degrees, uniform across legs (the remainder is the sweep's own fast authored return).
- Checks: new tools/v402_bittaran_recovery_smoothness_runtime_check.gd asserts per-leg recovery smoothness for KICK (<=15 deg/tick) and SWEEP (<=25 deg/tick) plus >=12px stomp shake displacement with exact zero settle; it fails on the pre-fix tree with exactly the measured values (kick rl/rr 55.9/56.4, sweep fl/fr 29.9, rl/rr 48.9). Full local suites pass: static 182/182, Godot 138/138. The focused workflow's v402 glob line could not be pushed (the GitHub App has no workflows permission, same as v399-v401); the full manifest registration is included. Android visual/feel inspection still required.

## 2026-11-16 — SERA v401: Bittaran weight feel and technique identity
- Audit (measured in the live scene): during Approach the chassis height was perfectly constant (bob range 0.0) and body roll stayed under 0.45 degrees — the legs stepped while the body glided. Planted-sole skating was already negligible (mean 0.02cm/tick), and there was no camera shake and no boss sound anywhere. Technique choice was a pure kind rotation plus nearest leg, although damage (22/28/34), timings and dirt FX already differed per kind. Locomotion constants are pinned by v345/v370 and were not touched.
- Gait weight shift (bittaran_foot_ik.gd): while a diagonal pair is airborne, the chassis leans over the planted pair's front foot (roll alternating to about +/-2 degrees with the pairs, slight forward pitch) and sinks about 4cm with a small extra pulse per touchdown (_apply_gait_sway, applied on top of the sampled rig pose before the floor clamp and foot IK, like the attack chassis pose). Planted soles stay locked (measured error ~0.000003m), and all terms decay to exactly zero outside Approach/Turn.
- Impact feedback (bittaran_battle.gd): STOMP ground slams add a distance-scaled camera shake via the otherwise unused Camera3D frustum offsets plus a synthesized heavy thud (procedural 16-bit WAV, same pattern as main.gd's mechanical footstep); KICK/SWEEP connects add a smaller shake and a sharper thud; gait touchdowns add quiet footfall thuds and a trace of shake. The shake always decays back to exactly zero offset.
- Technique selection (bittaran_attacks.gd): _choose_kind reads the situation for the selected leg — player within 3.6m of the foot: STOMP; beyond the foot along its radial line (dot >= 0.50): KICK; off to the foot's side: SWEEP. The historical rotation remains as the fallback and the situational path never repeats the previous kind, preserving fight variety.
- Checks: new tools/v401_bittaran_weight_feel_runtime_check.gd covers the four selection cases, the alternating sway with planted soles and rest decay, and shake trigger/settle (fails pre-change at the KICK selection case). v399 now settles the IK (AI frozen) before sampling rig height, separating the intentional gait dip from the persistent attack-induced error it exists to catch; its ground-correction assertion is unchanged. v382 now presents the KICK situation (player beyond the broken foot) to the real selector instead of standing on the sole; its broken-leg kick assertion is unchanged. Full local suites pass: static 182/182, Godot 137/137. The focused workflow's v401 glob line could not be pushed (the GitHub App has no workflows permission, same as v399/v400); the full manifest registration is included. Android visual/audio inspection still required.

## 2026-11-15 — SERA v400: fix KICK foot angles, SWEEP leg burial and STOMP toe orientation
- KICK: only the source leg (leg_fl) kicked with the authored foot orientation; at full extension the foot tilt measured 9 degrees (fl) versus 41/87/107 degrees (fr/rl/rr). The Wait-delta component-flip retarget conjugates LOCAL quaternions as if every parent frame's axes were the anatomical planes, but the shoulder/knee parent frames are themselves rotated (crouched Body, folded binds), so the error concentrates in the upper joints while positions still land. Fix (bittaran_rig.gd): the KICK shoulder and knee blend from the delta map to a world-space mirror of the source chain (reflect each joint's world rotation across the anatomical planes through the rig, convert back against the frame's own Body target) across the first 0.30s of the strike, hold, and blend back across recovery (kick_mirror_weight, set from the frame's phases). The delta fold is kept through the windup because mirrored folds float ~1m on the rear legs' different bind geometry and the chassis floor clamp cannot follow; the keyframe-zero contact sample is forced to the pure delta map. Result: extension tilt 9/9/12/9 degrees, windup soles planted on all legs.
- SWEEP: the strike carried the upper/lower leg meshes to -1.22m (front) / -1.57m (rear) below the floor while only the foot was translationally clamped. Fix (bittaran_foot_ik.gd): in the authored KICK/SWEEP branch, lift the whole attacking limb at its shoulder by the leg's lowest-mesh deficit (new _leg_mesh_lowest_y), the same purely translational, pivot-restored correction the foot already received; authored rotations untouched. Result: minimum leg clearance 0.0 on all legs.
- STOMP: the contact frame assumed the long toe runs along local -Y, but the imported model carries it along local +/-X (measured from the foot mesh), so the toe landed ~63 degrees off vertical with its end face tilted. Fix: store the measured toe axis per leg (_toe_axis_local_point) and build the contact frame by pitching the level frame about the forward axis until that axis points straight down (_stomp_contact_rotation). Also _stomp_tip_local_point averaged the lowest joint-local-Y corners, landing mid-toe; it now returns the true end-face centre (mesh centre plus half the box extent along the toe axis), which removes a 0.94m one-tick sole teleport at recovery start that the corrected frame exposed (v387). Result: toe axis exactly vertical at impact, end face centred on the aim.
- Regression: new tools/v400_bittaran_attack_motion_runtime_check.gd asserts per leg: KICK extension foot tilt <= 20 degrees with the windup fold planted, SWEEP leg-mesh clearance >= -0.01m throughout, STOMP toe within 12 degrees of vertical and resting on the floor at impact (fails pre-fix at the SWEEP burial, -1.22m). The four checks written against the old +Y-up proxy (v384, v385, v387, v392) now measure the toe axis from the real foot mesh instead; their intents are unchanged. Full local suites pass: static 182/182, Godot 136/136. The focused workflow's v400 glob line could not be pushed (the GitHub App has no workflows permission, same as v399); the full manifest registration is included, so the check runs in the model-policy suite. Android visual inspection still required.

## 2026-11-15 — SERA v399: stop attack-stance preparation from ratcheting the chassis downward
- Bug: Bittaran's chassis sank a little with every attack and never recovered. Reproduced in the live boss scene (Godot 4.7): a STOMP that froze a diagonal pair mid gait-step, followed by the next attack's stance preparation, accumulated a persistent -1.337m ground correction; every later attack added the same error again until the chassis floor clamp was the only thing holding the visible body up.
- Cause: the v398 stance preparation runs with an empty attack pose, so the end-of-tick ground reconciliation in advance_ik() stayed active. Preparation intentionally lifts one diagonal pair while the other diagonal can still sit at its interrupted gait-step height (begin_attack_stance clears the stepping flags and adopts the last rendered goals as anchors), so all four soles can read above the floor at once. The reconciliation treated the lowest airborne sole as chassis hover and dragged the body toward it, storing the error in ground_correction_world.
- Fix: skip the ground reconciliation while attack_stance_active, exactly as while an authored attack owns the feet. The preparation lands all four soles on exact Wait contacts itself, so reconciliation resumes from a grounded state at handoff. No stance timing, anchors, authored keys, IK solve or locomotion values changed.
- Regression: tools/v399_bittaran_body_height_stability_runtime_check.gd drives all 12 attacks twice back to back in the live scene and asserts rig height, persistent ground correction and planted soles return to neutral after every attack (fails pre-fix with the measured -1.337m correction, passes after). Registered in tools/sera_ci_manifest.txt and the focused Bittaran workflow. Android visual inspection still required.

## 2026-11-15 — SERA v398: pre-attack Wait-stance reorientation using foot IK
- On every AI-selected Bittaran STOMP/KICK/SWEEP, insert a separate IK leg-placement phase before authored motion starts. Replant the two existing diagonal foot pairs sequentially, 0.32s per pair (0.64s total), returning all four sole targets to the current neutral Wait home and matching the neutral world-foot quaternion. Only the moving pair lifts up to 12cm according to actual horizontal/rotational mismatch; the other diagonal remains planted. Maintain the same boss root position/yaw and real two-bone foot IK.
- The attack director holds its clock at 0 until both diagonal pairs reach their stance positions/orientations; then it plays all existing authored keys from their actual first frame and preserves the original stomp/kick/sweep windup, strike, hold, slow-sweep outbound and recovery timings. No collision/damage/hitboxes/FX or authored rig/body turn during stance. Freeze AI movement during the preparation and keep HEAD look independent with its +/-30deg hard limit. Only AI attacks are gated; force_start retains the original direct-start contract for legacy Godot clip tests.
- A dedicated force_start_with_stance regression tests 12 variants in the live boss scene, checks neutral replant goal and quaternion, ensures opposite planted diagonal remains fixed, verifies timer zero, harmless preparation, authored animation starts after completion, and cancellation clears state; registered in full and focused CI.
- Original authored .bbmodel, rig pivot hierarchy, existing locomotion step timings and part-break response unchanged. Android visual inspection still required.

## 2026-11-15 — SERA v397: HEAD tracking capped at +/-30deg and rear SWEEP chest-back lift
- All HEAD tracking yaw (including look target, filtered yaw, persistent state, final bone quaternion, during all attacks, interrupted attacks, physical down, stand-up) is clamped to +/-30deg about the level forward reference. Head pitch, 20cm leg-first collision avoidance, damped tracking and the front-arm return mechanical envelope remain.
- v396 established exact source-pose X/Z reflections for all four SWEEPs and preserved authored knee/toe keys. Rather than corrupt those reflected curves, raise only the BACK of the articulated BODY on rear-left/rear-right SWEEP: add 8deg local negative-X pitch, ease in across original 0.70s anticipation, hold through strike, release over original 1.40s recovery. FRONT SWEEP, KICK, STOMP, root heading, source Blockbench keyframes and world-planted support toe targets unchanged.
- Update v394 HEAD arm-return and v363 recovery tests to the superseding 30deg cap; add v397 real-Godot checks of both local extreme yaw directions, all four attacks and down recovery, front-vs-rear pitch activation and its precise 0/peak/release, then register in full CI and focused Bittaran PR suite.
- Android actual visual / play feel remains separately unverified. Do not merge without full green PR CI.

## 2026-11-15 — SERA v396: four-limb SWEEP spatial retargeting and authored toe stability
- Diagnosed an actual mirrored SWEEP pose error from the canonical Bittaran.bbmodel: only FrontLeg_L has animated SWEEP keys; the prior shoulder/knee/toe retarget applied mirrored deltas relative to each other leg's unrelated WAIT rotations. BODY's source +17.48 degree roll was also reused unmirrored for all four attacks. This raises front-right and both rear sweeps and rotates their feet to wrong angles. The source-author animation is unchanged.
- Retarget only SWEEP with exact spatial reflections of the source FRONT LEFT absolute joint quaternions (X for left/right, Z for fore/aft); also mirror the complete source BODY attack rotation on the same axes. Smooth entry/exit into each destination WAIT remains, and STOMP/KICK keep their previous retargeting.
- Align the one-time KICK/SWEEP entry-sole calibration with the actual mirrored SWEEP BODY rotation, so the opening grounded pose uses the right limb.
- Keep the authored SWEEP shoulder/knee/foot quaternions through the strike. The late prepose/floor collision correction now moves only the final visible foot end effector in world Y instead of rerunning the 2-bone knee IK, with the parent-local joint origin restored on the next authored sample. KICK's existing no-resolve contact rule is retained.
- Add v396 runtime regression to check all four SWEEP limbs at nine authored timestamps for reflected world ankle vectors and toe orientation, then exercise every attack in the live scene to check real original knee/toe keys and nonpenetrating soles. Register in shared CI and focused Bittaran workflow.
- Require a successful full PR CI run and an independent Android visual review; no Godot or Android test outcome claimed without logs.

## 2026-11-15 — SERA v395: leg-first HEAD clearance, 20cm hard overlap
- HEAD versus leg penetration is now allowed up to 20cm oriented mesh depth, replacing the 10cm limit. HEAD collision braking begins at 14cm, with a 17cm hysteresis release and hard inward stop at 20cm; moving away remains free.
- Make articulated supporting KNEES the primary avoidance mechanism: begin folding at a preferred 13cm depth, fold outward and downward with maximum blend 0.70 (previously 0.45), increase bend-in speed to 3.0/s, and preserve all planted sole goals and bone lengths. Scan actual current head pose plus relative future yaw, rather than double-applying current yaw.
- Fold support legs even while an attack plays; never IK-fold the authored striking leg. Stop raising the HEAD for minor visual AABB overlap. Keep upward head clearance as a last resort when actual depth exceeds 20cm. Arm-return yaw envelope, authored attacks, physical down/stand-up and head pitch follow remain intact.
- Update legacy Godot collision tests v373-v380 and v393; add v395 live-scene attack/support knee regression and register in full and Bittaran-focused manifests. Headless Godot CI and Android visuals are pending confirmation.

## 2026-11-15 — SERA v394: spiral supporting legs, neutral arm-return head stop, 0.60s interrupted attack STOMP windup
- When a planted support foot's horizontal bearing lags its current BODY neutral sole bearing by more than 8 degrees, twist the two-bone IK knee pole around the hip-to-ankle axis up to 70 degrees (75 degrees of lag for full effect). Limit twist update speed to 220 degrees/s, preserve exact bone lengths and world-planted sole, unwind on catchup. No spiral blend for down/author-animated attacking leg.
- Constrain both live HEAD desired yaw and filtered yaw to the original front-shoulder RETURN envelope in chest-local coordinates: measure neutral left/right shoulder bearing from the HEAD pivot, retain a 45-degree mechanical safety margin. This guard is independent of real-time collision and retains the existing 10cm OBB depth solver.
- On part break during an ACTIVE authored attack, first capture live BODY/striking-leg local quaternions; cancel old attack and crossfade to the authored STOMP windup key at 1.25s for the entire separate 0.60s pre-down transition, then enter unchanged physical knockdown. Do not overwrite HEAD Yaw/Pitch tracking or add standard head-throw/forelimb extension in this attack-only interruption. Other supports retain planted IK.
- v389 is updated for the new interruption contract, v394 adds Godot lagged-foot/head return/three-attack transition regression. Unrelated Blockbench source remains unchanged. Full CI required; Android visual check remains separate.

## 2026-11-15 — SERA v393: Bittaran attack bone-local pivot restoration and head depth safety
- Cache immutable parent-local Blockbench joint positions on rig creation. IK previously translated an attacking or supporting toe in world-space to seat a hit, changing its parent-local joint origin. Reset every non-Head joint local position before each apply_pose rotation sample; preserve source pivots, attack timings, keyframes, retargeting and independent Head controller.
- Treat independently live HEAD pitch as a second collision-relevant axis: reject/bisect a pitch step before oriented HEAD/shin penetration crosses 10cm, allowing escape when already obstructed. Continue the existing YAW mesh solver afterward.
- Dynamic knees can move into a stationary HEAD even with no new head rotation. At final pose, compare actual OBB mesh depths, search limited positive world-up displacement only if depth improves, including down-pose tracking suspension; never accumulate local neck-pivot offsets.
- Add v393 Godot test: repeat all 12 attacks twice, assert restored local anchors and independent pitch-shin stop/roll freedom. Android visual confirmation outstanding.

## 2026-11-15 — SERA v392: Bittaran head look pitch, diagonal 45deg chest aim, authored STOMP toe
- HEAD follows SERA by world-level yaw followed by a local pitch (no roll), replacing the v390 normal player-elevation neck translation. Down anticipation and mesh/leg clearance lifts remain.
- On each attacking leg, the BODY tracks with a mirrored ±45deg offset from the player bearing during windup, freezes during the authored strike, and releases smoothly without rotating the root or moving planted support soles.
- STOMP preserves authentic ankle/foot keys through its complete authored 1.25s windup. Only during the 0.25s strike does the toe gradually align local +Y to world-up so its short tip face meets the floor horizontally. At impact/hold the visible lowest toe vertex is clamped to the arena floor without distorting the source windup animation.
- Superseded v384/v387/v390 regressions now verify source-foot windup, short-tip contact, no-roll HEAD pitch; add v392 real-Godot combo test and register in PR-focused/full CI. Blockbench source unchanged; Android visual confirmation outstanding.

## 2026-11-15 — SERA v391: Bittaran attack aim, kick prepose and short-front head tracking
- STOMP, KICK and SWEEP track the moving player during windup and freeze torso/leg aim for the authored strike. Root translation, root yaw and three support-foot world anchors remain fixed.
- KICK/SWEEP aim their actual authored extended-foot reference by turning the entire attacking leg about its shoulder; source knee, ankle and animation keyframes remain unchanged. KICK windup no longer re-solves the planted knee for floor correction.
- The Head uses its true local -Z short front edge to aim, with an 85-degree yaw cap, near-field filtering and the existing oriented-mesh collision constraint.
- Superseded v383/v386/v387 sweep-no-tracking expectations updated; v391 added to the complete Godot CI manifest. Model data unchanged. Android visual/play-feel verification remains outstanding.

# SERA v390 — 頭部水平姿勢とプレイヤー上下追尾／なぎ払い往路終盤0.2倍速（2026-11-15）

- **HEAD水平・上下追尾**：胴体BODYの原本低姿勢／回転を継承するため頭部が傾く問題を解決。頭部の向きは、毎フレーム実WORLD軸上でBODY前方のXZ方向のみを取り出した水平クォータニオンを生成して、親BODYのpitch/rollを打ち消し、従来の独立した頭部プレイヤーヨー追尾を重ねる。頭のアニメーションキー再生やブレンドの上書きは再開しない。プレイヤーの初期立ち位置Yからの差を±0.65mに制限し、実WORLD UP方向への平行移動として頭の上下に反映。秒速1.4mの上限と8/sの指数補間でガタつきを抑える。BODY低姿勢中も頭のYと水平角度は独立して追尾。
- 物理ダウン中の頭部中立姿勢、起き上がり70％での緩やかな追尾再開、接近時の頭と脚の10cm重なり許容・減速・反転防止は維持。ダウン前の頭反り予備動作は頭を傾けず、頭のWORLD-UP平行移動で上昇させる。
- **なぎ払い**：往路終了は原本クリップt=0.50sのまま。そこから**実時間0.70sを逆算し、原本t=0.36→0.50sの0.14s分を0.20倍速で0.70実秒間**再生する。時間対応は「原本0.00→0.36s＝等倍、原本0.36→0.50s＝0.20倍速(実0.70s)、原本0.50→1.50s＝等倍」。往路終了の実時刻は1.06s、攻撃打撃尺は1.50s→2.06s。従来のt=0.50以後を0.6倍速にする処理は削除し、復路は最初から等倍で再生。予備動作0.70s・通常モーションへの復帰1.40s・硬直なし・胴体プレイヤー追尾なし・頭は追尾を維持。Blockbenchのクリップ／関節キーに変更なし。
- `tools/v388_bittaran_head_sweep_tempo_runtime_check.gd`の古い仕様期待値を新仕様に更新、`tools/v390_bittaran_level_head_vertical_follow_outbound_windup_runtime_check.gd`でWORLD水平姿勢・上下±0.45m追尾・元位置復帰・BODY原本低姿勢中の独立追尾、時間曲線境界・2.06s尺を実Godotで検証。Android表示の実際の挙動は未確認。

---

# SERA v389 — ビットタランの胴体地面貫通防止／攻撃中ダウン時の脚モーション解除（2026-11-15）

- **胴体埋まり**：`bittaran_foot_ik.gd` では弾き／なぎ払いの原本初期ポーズに合わせた胴体Y移動量と、部位破壊時の頭接地用BODYピッチ／胴体下降を別々に管理していた。いずれも胴体メッシュ自体の床貫通判定がなかった。BODY直下の本物のメッシュを使用し、毎フレームの実姿勢（BODY回転・ルートスケールを含む）でAABBの8頂点をワールド変換、最下端が床0+20mm未満の場合だけ、床上まで俯瞰補正する。HEADや4脚などBODYボーン配下の可動子ボーンは胴体の床判定へ含めない。**姿勢計算／ダウン制御の後、脚IKの前に実行**し、支持脚は従来どおりワールド接地点を保持する。
- **攻撃中のダウン割り込み**：`_apply_target_part_damage`での脚破壊判定から、攻撃管理・IKフレーム／接地初期高さ補正を即時キャンセル。まず脚の実足先座標から物理ダウン側の接地アンカーを保存し、**その後**リグの攻撃モーションを終了させ、BODY＋4脚（肩／膝／足）全関節をBlockbench `Wait` キーフレーム0の基本姿勢へ一度戻す。次フレームのダウン動作は通常の接地IKが担当し、攻撃中の振りかぶり角度が残らない。HEADは引き続き独立追尾管理（ダウン中の段階的な中立姿勢復帰を維持）。致死時に攻撃中なら同様に打撃モーションを解除。
- 攻撃再生／脚破壊仕様・ダウン時間・脚のワールド接地・ストンプ1.5秒硬直・なぎ払い0.6倍速の復路は不変更。ユーザー正本`Bittaran.bbmodel`とそのモーションキーには変更なし。
- 実Godotの12パターン（4脚×踏みつけ・弾き・なぎ払い）全モーションと中途ダウン割り込みで、胴体の可視メッシュ最下端20mm以上、割り込み時のBODY＋12脚関節のWait姿勢復帰、頭の回転維持、攻撃再開なしを検査する`tools/v389_bittaran_body_floor_down_interrupt_runtime_check.gd`を追加。Android実機映像による評価は別検証。

---

# SERA v388 — 頭部追尾の完全独立・なぎ払い復路の減速（2026-11-15）

- **HEAD（頭部）** は「実際にダウンしている間」を除き常にセラを追尾。Idle／Turn／Approach／踏みつけ／弾き／なぎ払い／硬直／復帰の各フレームで、**モーションリグはHEAD.quaternionを一切書き換えない**。正本のWaitポーズはリグ初期化時の1回だけ。追尾は `bittaran_battle.gd` が最終IK後に絶対クォータニオンとして毎フレーム適用し、アニメーションの切替・ブレンドで直前の視線を打ち消さない。近距離の頭と膝の衝突抑制、ダウン中の中立頭姿勢、起き上がり後70％からの穏やかな追尾復帰は従来通り。
- 部位破壊の0.6秒**ダウン前の振りかぶり**も、すでにダウンしているわけではないため頭を止めず追尾する。従来の頭の上向き・下向きの予備動作はIKから `head_windup_pitch_degrees` として角度だけ伝え、常時追尾する頭のヨーと1回だけ合成する。リグ再生処理はこの角度も勝手に上書きしない。
- **なぎ払い**は制作者の正本クリップ `なぎ払い` の左前脚の回転キー（0.00、0.25、0.41667、**0.50**、0.75、1.00秒）を確認し、**往路終点のクリップ時刻0.50秒**から実時間0.70秒間0.60倍速にする。その後1.00倍速に戻す。実時間の追加0.28秒に合わせて、攻撃判定の時間帯／土埃の追従／復帰開始時刻を統一し、打撃部分は1.50→**1.78秒**。原本のキーフレーム・モデル・完成後の1.40秒の緩慢復帰・硬直なしは不変更。
- `bittaran_attacks.gd` に実時間→原本クリップ時刻変換 `sweep_clip_time_at()` を設け、`frame.authored_time` と `frame.authored_playback_speed` をリグへ伝える。時間曲線は「0.50秒まで等倍→0.70秒間0.60倍→以後等倍」で連続し、正本1.50秒分が実時間1.78秒で再生される。リグは渡された`authored_time`だけで本物の関節キーをサンプルする。
- `tools/v387_bittaran_poststrike_hold_grounded_head_runtime_check.gd`を頭回転維持の確認に更新し、`tools/v388_bittaran_head_sweep_tempo_runtime_check.gd`を追加。Godot実シーンで頭のアニメーション上書き防止・ダウン時のみ追尾解除・SWEEPの速度／時刻対応と実リグ関節モーションを実行検証する。Android実機での見た目は別途確認。

---

# SERA v387 — 踏みつけ垂直長辺・攻撃後硬直・なぎ払いの緩慢復帰・脚の地面貫通防止・頭追尾固定（2026-11-15）

- **踏みつけ**の脚先メッシュはLOCAL -Y軸が長辺。振りかぶり・振り下ろし・着地・1.5秒間の硬直中を通してlocal Yをworld UPへ向け、長辺を地面へ垂直に保つ。v386の着地直前に足先を水平化する処理を廃止。原本の肩・膝振りかぶり、胴体の追尾、接地衝撃波と上向き土塊は維持。
- **踏みつけ・弾き**は打撃終了直後、その姿勢のまま**1.5秒間硬直**する。硬直が完全に終わった後で、踏みつけは0.55秒、弾きは0.60秒かけてsmoothstep補間で通常姿勢・脚IK・胴体高さに復帰。硬直中はルート接近／旋回を停止、攻撃判定は再発生しない。脚の支持点固定を維持。
- **なぎ払い**は硬直を設けない。制作された1.5秒の攻撃終了直後から、1.40秒間のなめらかな補間でIdleの通常姿勢・脚位置へ復帰する。なぎ払い時の胴体プレイヤー追尾は引き続き無効だが、頭だけは常時追尾。
- **弾き・なぎ払いの埋まり対策**：原本の攻撃脚関節キーを維持し、毎フレーム足メッシュAABBの全8頂点をワールド変換して最低Yを確認。床を貫通しそうなフレームだけ二骨IKで実足裏を上方へ接地補正する。硬直・復帰は最後の実際に接地補正された足先位置から開始し、復帰開始時の座標ワープを抑止する。v386の「開始姿勢の胴体高さを最初だけ計算」は継続。
- **頭はアニメーションを再生しない**：Waitで決められた頭の首角を基準とし、Idle/Turn/ApproachなどのHEADキーフレームや攻撃HEADモーションは適用しない。v386で固定されていたSWEEP中の頭部追尾も再開し、頭のみ独立してプレイヤーを追い続ける（ダウン中の既存安全制御は維持）。
- Godotの実シーンで12組合せの攻撃全時間を通し、1.5秒間の脚の保持・SWEEPの1.40秒回復・踏みつけ長辺垂直・攻撃脚メッシュ最低Y・支持脚固定・HEADのキー無効／常時追尾を確認する`tools/v387_bittaran_poststrike_hold_grounded_head_runtime_check.gd`を追加。旧v383-v386の変更済み仕様のみ更新。既存アセット正本は変更しない。

---

# SERA v386 — 踏みつけ原本振りかぶり復元／弾き・なぎ払い開始接地調整／なぎ払い追尾解除（2026-11-15）

- 動画`1000036272.mp4`でビットタランの振りかぶり破綻を確認。v385では原本`踏みつけ`のキーを評価した直後、IK`_solve()`が肩・膝の角度を上書きして、制作モーションが見えなくなっていた。修正後は**実モデルの原本キーによる踏みつけの1.25秒の振りかぶり中、攻撃脚の肩・膝をIKで上書きせず**、実足先を保存してから0.25秒の着地IKへ滑らかに引き継ぐ。振りかぶり中はBODYのみプレイヤー追尾を継続し、足先垂直と接地時水平化を維持。非攻撃脚3本の接地位置は従来どおり固定。
- 弾き・なぎ払いは、攻撃開始時に原本のキーフレーム0「低いBODY＋選択攻撃脚」の**実足裏高さを一度だけ試算**し、接地する高さだけBODY視覚モデルを0.7秒間で滑らかに調整。初回に決めたワールドY補正を打撃中は固定し、戻りモーションで滑らかに解除する。攻撃中に変化する脚位置で高さを毎フレーム再計算しないため、上下チラつき・急な浮き沈みが発生しない。原本キー・攻撃の全体尺・衝撃／土埃FXは変更なし。
- なぎ払いだけは**予備動作を含む全時間でプレイヤーの位置を取得しない**。`bittaran_attacks.gd`の`tracking=false`・`aim=INF`、BODY旋回0、頭の独立したプレイヤー追尾も攻撃中だけ固定。通常の旋回・接近はもともと停止する仕様を保持。踏みつけ／弾きの追尾は従来どおり。
- `tools/v386_bittaran_windup_ground_no_sweep_follow_runtime_check.gd`で、4本の踏みつけ原本肩膝キー維持、弾き／なぎ払い4本×2種の予備動作終了時の実足裏接地・開始時1回補正・滑らかなY補間、なぎ払い完全追尾無効、3支持脚のワールド接地固定をGodot実シーンで検査。v383/v385の旧仕様期待値（なぎ払いも追尾）を更新。全CIおよびAndroidでの見た目は別に確認。

---

# SERA v385 — ビットタランのユーザー制作3モーションと地面エフェクト統合（2026-11-15）

- 受け渡し原本 `models/storage/ボステスト (2) (2).bbmodel` の「踏みつけ」（1.75秒）、「弾き」（1.0秒）、「なぎ払い」（1.5秒）を、既存のWait・Idle・Turn・Approachを維持して `models/bosses/Bittaran.bbmodel` に追加。制作されたキーフレームの内容・UUID・ボーンを保持し、収録順が乱れた鍵だけ時間順に整列。正式Android埋込 `assets/bittaran_data.gd` も再生成。受け渡し元は削除しない。
- 原本の攻撃モーションは左前脚にキーがあるため、他3脚ではWait姿勢に対する関節クォータニオン差分を左右(X)・前後(Z)で鏡映して同じキーを再利用。アニメーションが作用するのはBODYと攻撃脚であり、支持脚の3つのworld接地点には既存の二骨IKを継続適用。攻撃中root旋回/接近は停止。BODYは振りかぶり終了までプレイヤー追尾、攻撃開始時に追尾停止、HEADは独立追尾。
- 「弾き」「なぎ払い」は0.70秒間かけて、現在のTurn/Approachから原本の低いBODYのt=0ポーズへ滑らかに補間し、その後に原本キー全長（1.0秒/1.5秒）をそのまま再生。従来の手続き的な膝伸ばし・体幹強制67°ロールはこの2攻撃の本番再生から解除する。帰還は元の攻撃後recoveryで滑らかにIdleへ戻す。
- 「踏みつけ」は原本の1.25秒振りかぶり・0.25秒振り下ろし・0.25秒復帰に合わせ、脚をプレイヤー頭上へIKで追尾（原本の膝の曲がり方向をポールに採用）。足先は高所で垂直下向き、地面に近づいた時に水平となり、実足裏位置から衝撃波を発生させる。
- 衝撃波は脛の実XZ断面幅1.5倍に合わせた地面固定の**欠けがある灰色の円形**へ変更。中心から広がらず、元のサイズのまま消える。上向きのグレー土埃と茶灰色の土塊が跳ね上がる。なぎ払いは実足先を追う連続土埃と跳ねる土粒の軌跡、弾きは足が動いた地面から蹴り方向へ飛ぶ土埃と土塊を追加。共通描画優先度と深度テストを維持し、効果自体に攻撃判定は付けない。
- 実際のGodotで12組合せのキーフレーム・プレブレンド・支持脚固定・足先姿勢・3種FXを確認する`tools/v385_bittaran_authored_attacks_dirt_runtime_check.gd`を追加。旧テストは変更された仕様に限り更新し、全CIで検証。Android実機上の最終的な視覚・フレームレートは未検証。

---

# SERA v384 — 踏みつけの頭上追尾と足先垂直姿勢を復元（2026-11-15）

- ユーザー指示によりビットタランの**踏みつけだけ**を修正。弾き・なぎ払いの新規モーションはユーザーが制作する予定のため、既存の2つの攻撃モーション・原本・キーフレームはこの変更で触れない。
- 踏みつけの予備動作1.00秒間は、プレイヤーの足元ではなく実キャラクター衝突カプセルの頭頂（`PLAYER_COLLISION_HEIGHT` = 1.85m）を追尾。目標は頭上35cm以上かつ初期接地点より1.05m以上の高所で、振りかぶりの最終フレームまで上昇し続ける。目標位置は16/sの指数補間で滑らかに更新し、振り下ろし開始で固定。打撃0.20秒間で頭上から地表へ振り下ろし、復帰0.48秒で元の接地点へ戻す。
- 元Blockbenchの足先メッシュはローカル-Y方向に伸びるため、踏みつけでは**ローカル+Yをワールド上向き**に整列し、足先が地面方向へ垂直に向く姿勢を上昇・下降とも維持。前版の『すべての攻撃で水平化する足先補間』は踏みつけに限り廃止し、弾き・なぎ払いには適用変更なし。接地後の姿勢復帰は滑らか。
- IKの実上限を超える頭上の狙点は実際の二骨長と足裏オフセットに従い、到達可能な位置へ制限する。踏みつけ時の衝撃波・接触判定は要求座標ではなく**実モデルの足裏**に合わせる。3本の支持脚の接地固定、BODY追尾と打撃開始での追尾停止、ダウン・部位破壊後の再攻撃は継続。
- 新規`tools/v384_bittaran_stomp_overhead_runtime_check.gd`で4脚の足先垂直・頭上までの上昇・移動する頭部への予備動作追尾・打撃開始のロック・実接地の衝撃点・支持脚保持をGodotで検査。旧回帰も全件実行。Android実機の視覚的な最終確認は未検証。

---

# SERA v383 — ビットタラン攻撃中の追尾旋回・足先水平・滑らかな振りかぶり（2026-11-15）

- 添付動画で確認した弾き時の足先の不自然なひねりを修正。攻撃する脚だけ、足先の元の方位を保持してワールド上方向に水平化する回転へ滑らかに補間し、打撃中は水平、復帰で元の向きへ戻す。二骨IKが伸び切る座標計算にも水平化した足先のソールオフセットを反映。元モデル・キーフレームは変更しない。
- Turn/Approachの既存クリップから、0.24秒のクロスフェードでIdleベースの攻撃予備動作へ連続移行。歩行ステップの最中なら、支持脚のXZ接地点を記憶し、高さだけ段階的に着地させる。攻撃中に新たな歩行・旋回ステップを発生させない。
- 予備動作の最終フレームまでセラの現在位置へ攻撃狙点を更新し、胴体のBODYボーンのみを毎秒100°以内、正面から±60°の範囲で滑らかに追尾旋回。振り出した時点で攻撃の狙点・胴体Yawを固定し、復帰中は体幹Yawを滑らかに0へ。頭部は既存のメッシュ干渉制御付きで攻撃中も独立追従。
- 攻撃開始から終了までAIのTurn/Approachルート移動・旋回は完全停止し、target rootのXZ・Yawは固定。攻撃しない残り3脚のIK接地点はワールド座標で固定し、膝・肩のみ本体の動きに合わせて伸縮させる。破壊済み部位の攻撃許可とv382の脚の完全伸展を保持。
- Godot回帰 `tools/v383_bittaran_attack_aim_body_support_runtime_check.gd`で、四脚×3攻撃×Turn/Approachからのクロスフェード、支持脚接地、振り始めでの追尾停止、攻撃中の本体移動停止、水平足先、頭部追従を検証。v381/v382と全履歴CIを維持。Android実機での視覚確認は未検証。

---

# SERA v382 — 破壊脚の攻撃継続／蹴り・横薙ぎで脚を伸ばし切る（2026-11-15）

- 破壊済みの脛も物理的な脚モデルとIKが残っているため、4脚とも引き続き踏みつけ・弾き・なぎ払いの攻撃候補に含める。従来の部位破壊時の攻撃中断、予備動作、転倒、起き上がり、死亡時停止は維持し、起立後に再び攻撃できるようにする。
- 弾き（KICK）は1秒間の足裏接地・内側への膝折りを保ち、打撃中には股関節から膝・足首まで2ボーンIKの実際の到達長まで外側へ伸ばす。これまでの外側1.65mの位置目標を廃止し、脚が直線になることを優先。足先は地面に固定せず、攻撃終了時に滑らかに元位置へ戻す。
- なぎ払い（SWEEP）は攻撃側の肩を地表付近まで落とす従来の胴体ロールを維持し、予備動作中に脚を伸ばして、長さを保ったまま水平方向の弧で振り抜く。足裏の地面Y固定を廃止して、脚が伸び切れるようにする。
- 新規`tools/v382_bittaran_broken_leg_straight_attacks_runtime_check.gd`で4脚×弾き/なぎ払いの物理膝直線性・地面固定解除・復帰と、4脚の実際の部位破壊/起き上がり後にAIが攻撃を選択する挙動をチェック。既存v381全12通り・歴代回帰テストも継続。Blockbench原本・アニメーションクリップ・既存の踏みつけ/HP/ロック仕様は変更しない。Android実機での見た目は未検証。

---

# SERA v381 — ビットタラン四脚×3種攻撃（2026-11-15）

- 四脚（前左/前右/後左/後右）すべてから、1秒持ち上げ→踏みつけ＋同時に脛XZ断面の1.5倍の衝撃波、1秒の接地固定内曲げ→外向き蹴り出し、攻撃側へ胴体を傾けて肩を地面へ下ろす低姿勢の鞭状横薙ぎを選択できるようにした。
- 既存の14ボーンと二骨IK・実ソール座標を使い、予備動作・打撃・復帰を滑らかに補間。攻撃中は通常歩行の脚スイングを停止し、ダウン・部位破壊・死亡・再出現の状態遷移と排他的にする。元Blockbenchのキーフレームは変更しない。
- 踏みつけFXは衝突フレームに発生、地面固定・深度テストONのリングで表示。実際の脛AABBの水平縦横寸法×1.5だけダメージ範囲を広げ、脚本体の攻撃判定を同時に評価。蹴り・横薙ぎは実メッシュ各パーツのAABBで判定し、1回の攻撃につき最大1ヒット。ガード・HP・ノックバック・KO処理は共通系を流用。
- v381の実Godotランタイム回帰で全12組合せ、接地した予備動作、踏みつけの単発衝撃波、攻撃後のIK復帰と遷移を検査する。Android上の見た目・音・操作感は未検証。

---

# SERA v305 — ロック部位へ水平に正対・AUTOの0.22秒遅延廃止（2026-11-13）

- `main.gd` のAUTOロックはセラ起点の左右2本線＆各部位115%専用ボックスの選択を**同じ物理ティック内でそのまま確定**。候補待機／0.22sタイマーを一切使わず、破壊時も即選択。互換用`AUTO_LOCK_SWITCH_CONFIRM_SECONDS`は0.0、旧pending変数は常に0へ初期化。MANUALやコンボ保持の分岐は従来どおり。
- `_locked_target_facing_direction`を追加。HEAD／脚の`get_part_aim_world`を参照し、BODY（空ID）は敵中心。水平面XZでyawのみ制御し、頭や足の高さで機体が上下に傾かないよう保護。部位が壊れてもコンボ中固定なら同じ部位を向く。
- 元のBODY向きだった`player.look_at`と、RUN`local_run_direction`算出のターゲット向きを統一。RUN／BOOST／STEPのアニメーション原本・ヒット判定・カメラ・移動・ステップ距離は変更せず。
- v290〜v303の関連静的／Godotテストの遅延前提を更新。新規v305テストでAUTO即切替・MANUAL全部位正対・コンボ保持・壊れた頭・カメラ非依存を確認。Android実機未検証。

---

# SERA v304 — カメラ専用当たり判定を各部位の115%で新設（2026-11-13）

- `target_parts.gd`で頭・四脚・BODYに独立した不可視`Area3D/CollisionShape3D/BoxShape3D`を付与。元のAABB寸法から全方向115%とし、頭は既存の上方1m・前方0.85mのロック補助範囲を含めて拡大。各領域は部位のpivotまたはBODYのMeshInstanceの子として追従。
- `_parallel_lock_part_distance`が新しい`_camera_lock_part_volume_distance`/`_camera_lock_body_volume_distance`の左右2本分をAND評価。単線の実メッシュ交差検査は履歴回帰用として残す。
- 専用Areaは`collision_layer=0`、`collision_mask=0`、`monitoring=false`、`monitorable=false`。物理当たり判定・攻撃Hit AABB・頭の可視メッシュ・移動連携・ダメージ計算の拡大なし。
- 旧v303片線交差のランタイム回帰はカメラ用ボックスを細くして片線だけに交差させる検査へ変更。新v304静的/Godot検査追加。Android実機未検証。

---

# SERA v303 — AUTOロックを左右2本の平行レイへ・可視化ON/OFF（2026-11-13）

- `target_parts.gd`でセラ→敵本体中心の水平垂直面を基準に左右±0.25m、計0.50m間隔で平行な有限線分を生成。BODY/HEAD/四脚の各実BoxMesh（HEADは従来ロック補助領域）との**両線共通交差**だけをAUTO候補とし、2線の最初の交点距離のうち遠い側を採用して最前部位を選択。
- `main.gd` AUTOは両線APIのみ使用。境界で片線が外れるたびの即時変更は廃止し、次の両線候補が0.22秒連続したら切替。破損時の即時再取得・コンボ中ロック固定・MANUAL左右のカメラ投影切替は維持。
- LOCK MODE直下に`LINES OFF/ON`ボタン。既存Touch/Mouse入力を独立に消費。可視化はOFF初期、ON時のみ細い水色の深度テスト3D円柱2本を同じ線分位置に描き、物理当たり判定には関与しない。`render_order_policy.gd`の`DEPTH_TESTED_EMISSIVE`パスを使用。
- 旧1本線のAPIは歴史回帰互換、AUTOのみ2本へ移行。新しい静的/実Godotテストを登録。Android実機未検証。

---

# SERA v302 — 四脚ロック狙点中央化・部位別命中FX完全分離（2026-11-13）

- `target_parts.gd` の4脚`aim`オフセットを`Vector3(0.0, 0.0, 0.0)`に変更。各脚pivotが全体メカフレームの中心なので、`get_part_aim_world`・`get_part_local_aim`経由のHUD、近接追尾、Kick_l/r回転中心が中央へ移る。AABB／実メッシュ／敵接触判定は不変。
- 従来の`hit_flash_remaining`がどの部位命中でもBODYを点滅させていた問題を修正。中枢ダメージ・HEAD/脚ダメージ分離は維持し、選択中のロック部位IDが空ならBODYの素材のみ、非空ならその部位の`trigger_part_hit_fx`のみを起動。破壊部位を保持中もBODYへ波及させない。
- BODYの`target_mesh`は全部位の親なので、親メッシュの揺れは全四脚/HEADの位置を動かしてしまう。BODY色フラッシュは残し、親位置・回転を固定。部位個別の揺れは従来どおり。
- `hit_burst.gd`のスパーク投影に敵中心距離を使っていたため、実際の着弾が脚であっても本体中心寄りの深度に描かれていた。着弾のworld座標から深度・縮尺を算出して部位面で表示。
- 新規v302静的／Godot実行回帰を登録、旧v238レイアウト検査はaimのみ更新、v301版数検査は>=301へ。原本モデル、キーフレーム、入力操作、部位選択順、攻撃ダメージは変更なし。Android実機未検証。

---

# SERA v301 — ロック線分をカメラ→敵からセラ→敵へ変更（2026-11-13）

- AUTOの選択だけ、`player.global_position`から`target.global_position`へ伸ばした線分と各部位実BoxMesh・HEAD不可視補助領域・BODY実BoxMeshとの交点を評価。セラに近い実交点が選ばれ、カメラ移動に依存しない。
- BODY・頭・四脚を同列比較、0.22sヒステリシス、既選択部位が線分から外れた際の即時再取得、コンボ中ロック固定、MANUAL画面左右の切替、HUDカメラ投影は維持。
- 対象関数 `_acquire_stable_camera_part` の歴史的関数名は互換性のため維持、内部はセラ起点の`select_actor_center_line_part`/`actor_center_line_hits_part`を呼び出す。カメラ起点のAPIはレガシー形状検査のみ。
- `v301`新規Python＋Godot実行回帰を追加。歴史的v293/v296/v297/v298の統合チェックはカメラとセラを同じ線分始点へ配置して旧交差・安定化条件を検証。ゲーム挙動はカメラ非依存を検証。
- Android実機は未検証。

---

# SERA v300 — 3/3/5m固定STEP、左右蹴りのロック部位円弧→直線、Kick_b 5m（2026-11-13）

- 通常の360°STEPは前3m・左右3m・後5m。後ろ側の角度だけsmoothstepを用いて3〜5mに補間し、敵の距離による移動距離・速度の変動を停止（基本10m/s、装備倍率は継続）。
- 左右Kick_l/rは最初の追尾・2つの著作キーフレームと2倍モーション時間を維持。2段目開始時に現在ロック中の部位狙点を軸とした水平円弧を開始し、2段目の命中時刻で接線方向を確定。残りの3mから円弧走行分を引いた距離を直線ブースト、以後の敵・ロック部位の移動には追従しない。半径ゼロなどは安全な最大120°制限と残余距離の再配分で対応。
- Kick_bは後方5m。元の1.5m最高点／0.8秒滞空／0.2秒着地／0.20833命中の配置を維持。すべて衝突解決はswept移動。
- Model・原本アニメ・HUD／ロック選択・脚接地・敵AIは不変更。静的/Godot実行の新v300検査を追加し、旧テストを実仕様に合わせ更新。Xperia実機未確認。

---

# SERA v299 — HEADロック再取得・足裏最下点によるWAIT/RUN接地（2026-11-13）

- v298ではBODYを実メッシュとして候補に入れたが、v297の頭部上方だけの仮想AABBが低い正面カメラ線分と交差しないと、BODYがHEADより手前の候補になる。0.22秒のBODY→HEAD確認もHEADの短時間交差を取り逃がしやすかった。
- HEADの補助ロック判定を本来の頭部高さ全体＋上1mに広げ、正面+Z方向へ0.85m追加。BODYを含む全対象は従来どおり交点距離で比較、特別な優先度変更なし。物理・格闘命中AABB・HUDに変更なし。
- WAITの最下頂点によるリグY補正は維持。RUNでは足音イベント発生時に限り、左右の表示足メッシュの最も低い頂点を計測して表示用リグYを補正し、次の接地まで保持する。単一足メッシュの瞬間移動から共通root補正へ変更し、鳥脚Cにも適用。
- RUN/WAIT以外ではすべて装備のバインド高さへ戻し、鳥脚Cの過去の動的接地補正が格闘/STEPへ持ち越されるのを防ぐ。既存重量脚部SLIDE IKは例外として保持。物理キャラYや原本キーフレームは変更しない。
- v299静的/Godot実行回帰を追加し、歴史的v199・v297の旧コメントや形状前提のみ現行契約へ更新。Android実機未検証。

---

# SERA v298 — BODYも部位と同じ線分交差距離によるAUTO選択に統一（2026-11-13）

- v297までの「頭・四脚に交差がなければBODY」という自動デフォルトを廃止。BODY自体の赤いFloatingBox（2×2×3.4m）をローカルAABBへ変換して、他部位と同じ線分交差位置のカメラ距離で比較する。
- BODYの内部ロックIDは従来どおり空文字とし、GUI・攻撃判定・保存データは互換性維持。BODYが無効／非交差時は優先対象にならない。
- AUTO安定化はBODYにも同一適用。BODY→HEAD等も両方の交差が維持されるときは0.22秒確定、現在の対象が線分から外れる／破壊されたときのみ即時再取得。
- v297頭上1m判定、頭・脚実メッシュ、コンボ固定、MANUAL、近接追尾・部位破壊、カメラ/HUDに変更なし。
- 新しいv298静的・Godot実行テストを追加。v296の「BODY→HEAD即時」履歴期待を更新。Android実機未検証。

---

# SERA v297 — 頭部AUTOロックの上方1m専用判定を追加（2026-11-13）

- v296のカメラ→敵本体中心の線分は低い頭部のメッシュを外れやすいため、頭部の実メッシュ交差に加え、頭部外接サイズの上端から上1.0mの不可視AABBとの交差を認める。対象はHEADのみ、ローカル空間で回転追従。
- `scripts/target_parts.gd` の既存距離計算で、カメラからの最初の交点を同一尺度で比較する。追加負荷は頭に対するAABB/線分の交差判定1回だけ。脚に仮想判定は作らない。
- `get_part_aabb`、頭部の表示・配置、物理衝突、既存攻撃追尾/命中判定、HUD狙点は不変。破壊・ロック継続/解除とMANUAL切替、コンボ中の固定は既存の共通処理を維持。
- 新規静的/Godot回帰を追加し、v296の脚の「外接空洞に当たってもBODY」検査でHEADの仮想領域を一時除外して検証する。Android実機未検証。

---

# SERA v296 — カメラ中心線と部位メッシュの交差でのみAUTO部位ロック（2026-11-13）

- v295までのAUTOはカメラとボスの相対方位を10分割し、頭／BODY／四脚／BODYを順送りしていた。部位が画面中心線になくても選ばれる問題を修正。
- カメラ→ターゲット本体中心の有限線分を、各部位の可視BoxMeshローカルAABBで判定。最前面の未破壊メッシュにのみ部位ロックし、交差なし／破壊済みならBODY。大きな部位外接箱の空白は部位と判定しない。
- いまの部位が線分から外れた場合はAUTOを即再取得する。両方が交差する部位間の変更に限り0.22秒の切替確認を維持。
- 攻撃・入力受付中のロック保持、攻撃補正と近接当たり判定、MANUAL左右切替、カメラ本体追従とHUDを変更しない。旧v293角度関数は過去検査互換のため残すがAUTOには接続しない。
- v296新規静的／Godot回帰を追加。v292/v293の変更前AUTO呼び出し前提だけ更新。Android実機未検証。

---

# SERA v263 — 接敵時STEPの入力方位と移動方位の不一致（2026-11-12）

- 添付8.867秒動画では接敵後のステップと方向転換を確認。v262コードの「X＝カメラ右、Y＝セラ前」を合成する式は、接敵時にセラがロック先へ向き直ると非直交になり、方向の打消しや回転を生じた。
- STEP物理軌道を一貫して`_screen_drag_to_ground(direction)`で決定し、画面フリックと同一の角度へ移動。セラの局所正面/右は**ポーズ方向変換専用**に限定。接敵中の体の向き直りに対して0.08秒平滑化でモーションを追従。
- STEP実行中はcamera_yawを保持し、既存の距離によるズーム・画面フィットは維持。STEP FX後退補正は実ワールド軌道の機体後方ドットで算出（旧画面Y成分だけの補正を廃止）。RUN/BOOST、衝突スライド、各距離／ENとバッシュ・ロックは不変。
- v263数値・静的テスト、およびv200/210/252/254/260/262等の過去契約検査をCIで実施。Android実機未検証。

---

# SERA v262 — 360°ステップ移動と4原本モーションの滑らかな補間（2026-11-12）
- 従来v260ではフリックを4方向へ量子化していたため、既存の`_start_omni_step`と`_blended_directional_step_pose`の斜め方向対応が実用されなかった。
- `screen_step_direction`を生の角度ベクトル正規化に変更。既存の前後・横方向補間と連続衝突判定を使い、純横付近の3m／4m係数だけsmoothstepで繋ぐ。
- 4原本姿勢の角度補間係数に三次イーズを追加。モデル/ボーン/原本アニメは不変更。Bash4方位／EN／RUN・BOOST／v259ロック／v261スラスターは保護。
- 現行仕様に合わせた旧静的テスト修正、v262数値回帰追加。Godot Android実機は未検証。

---

# SERA v261 — 斜め後退時の背部スラスター方向矛盾を修正（2026-11-12）

- 添付ゲームプレイ動画（13.4秒）および `main.gd` / `back_thruster_fx.gd` の2経路を調査。左入力の `left_sector_world` が優先分岐に入ると後退時 `backstroke_weight` の通常ピッチ補正を使用しないため、特に左斜め後退でノズルが横方向へ過剰に向いていた。
- 左移動用の画面下→右下（最大45°）セクターに、同じ `backstroke_weight` を適用し `Vector3.DOWN` へ球面補間。純左＝以前の方向、逆斜め＝下向きへ連続遷移、完全後退＝真下。右/左とも後退成分が下向きノズルへ働くよう統一。
- 噴射FXの経路は既存 `left_sector_world` のままとし、Blockbench実ノズルのピボット、世界下向き浮力補正、帯状軌跡、格闘中の回転制限／胴体衝突補正、入力・RUN/BOOST/STEP・EN・カメラ・ロックは不変。
- `tools/v261_rear_diagonal_thruster_self_check.py` で後退強度ごとの方向単調性、カメラ角度、不変条件を静的／数値で検証、Androidでの実操作は未検証。

---

# SERA v260 — 下/横フリックのステップ誤分類修正（2026-11-12）

- v259のSTEPはセラ投影正面基準で4方向へ分類していたため、カメラ斜め構図で画面下フリックが横STEP、横フリックがバックステップに解釈され得る。実際のSIDE STEP移動計算は画面横ベクトルだったため、方向の基準も混在。
- `flick_direction_policy.gd` の既存 `four_way_direction` を使う `screen_step_direction(displacement)` を追加し、STEPのみに画面上/右/下/左の基準を使用。Bashはセラ正面基準を維持。90°×4方向の区画幅は変更なし。
- ステップの世界移動方向（前後＝セラ前後、横＝画面横）と速度・EN・モーション・距離、Guard/Combo Bash、v259のロック保留/キャンセル、通常RUN/BOOST、ジャンプ/カメラ/ボス衝突は不変更。
- 既存のv200・v254〜258静的検査を更新、v260数値回帰で全360°のセラ方向に対して下＝後・横＝横、斜め45°境界、Bashだけキャラ相対を検証。Android/Godot実機未検証。

---

# SERA v259 — 格闘3段／バッシュの追加入力受付中は自動ロックを維持（2026-11-12）

- AUTOロックは現状 `combat_state == IDLE` で直ちに再開するため、Melee3終了後のBashフリック受付0.65秒とBash後の次の格闘タップ受付0.65秒にロック部位が変わる可能性があった。
- `_combo_followup_input_window_open()` で両方の受付タイマーを検出し、AUTOの `select_front_part` 呼出を抑制。初回格闘接近・Melee1〜3・Bash中（非IDLE）の既存停止は保持。
- `_cancel_combo_followup_windows_for_movement()` でRUN/BOOSTの操作成立時、またはEN消費成功後のSTEP開始時に受付タイマーを解除。モーション途中の移動キャンセルには従来の `_cancel_attack()` が対応。0.65秒自然経過でもAUTOは再開する。
- MANUAL／AUTOの切替と手動ロック保持、部位破壊時のロック解除、Bash/格闘の受付時間・速度・追尾/当たり判定、カメラ・HP・ENは不変。
- 静的・数値モデルでのv259回帰をCIへ追加、Godot/Android実機は未検証。

---

# SERA v258 — セラの正面基準に復帰し、フリックを90°×4方向へ（2026-11-12）

- v257のコントローラ原点→ロックマーカー方向から、セラ `-player.global_transform.basis.z` の画面投影方向へ「前」を戻す。指の位置やマーカー座標は方向分類から除外。
- 4つの非重複90°区画（前・右・後・左、±45°）を共通入力ポリシーに設定。STEPは斜めを近い方向へスナップし、Guard/コンボBashの前方も90°区画全体へ拡大。従来の横比0.42による狭い二重判定を除去。
- v256のBash 0.42秒／30px／200px/s、GUARD末尾フリック再判定、前STEP3m・後4m・横2–4m、モーション/EN/追尾、RUN/BOOST、ロック表示/カメラ/衝突は変更しない。
- v200/v253–257の過去のテスト期待値を現行4方向契約へ更新し、v258専用の回転角・方向境界・前方Bash/STEP整合性を追加検査。Android実機/Godotランタイムは未検証。

---

# SERA v257 — コントローラ開始位置からロックマーカーへの方向を前方とする（2026-11-12）

- STEPとGUARD/コンボBashの共通0°方向を、セラ機体の前方スクリーン投影から「最初のタッチ位置 `pointer_origin` → HUDの可視ロックマーカー `target_marker_position`」へ変更。既存HUDが描く座標をそのまま参照し、カメラ投影の重複計算・描画側仕様変更は行わない。
- `flick_direction_policy.gd` に `toward_lock_marker` を追加。マーカー画面外・不可視／重複時のみ旧キャラ正面投影にフォールバック。指を置く座標で向きが変わる一方、操作中は軸を固定する。GUARDの末尾フリック開始時とドラッグ省略時の離指で方向を更新。
- 45°×8区画／Bash前方±22.5°／v256の入力緩和／ステップ距離・速度・EN／通常RUN/BOOST／カメラ・UI描画・ロック選択・部位衝突・攻撃追尾は維持。
- 過去のv253/v255静的検査の「前方を機体投影で算出」期待値を更新し、v257の画面座標・方向区画・フォールバック・入力経路の回帰検査を既存CIへ追加。実機未検証。

---

# SERA v256 — バッシュのフリックを短く・ゆっくり入力可能に調整（2026-11-12）

- v255のBashは45°前方区画に加え、0.24秒/50px/500px毎秒、18px超の軌道逸脱即キャンセルと厳しい条件が重複。Bashのみ時間0.42秒、正面移動30px、正面速度200px/sへ緩和。候補維持38px、逆転比1.35へ拡大。
- GUARD中の最後のフリック履歴を0.20秒→0.42秒に拡張し、長押しからのゆっくりした派生に対応。デバッグ用Jumpサンプル0.20秒は変更しない。
- STEP/攻撃/ガード優先順位は維持。45°×8区画（Bashは前方セクター0）、画面に投影したセラの正面、位置・アニメ・攻撃ダメージ/追尾、RUN/BOOST、衝突、HP/UIは不変更。
- 既存のv253静的テストをBash新定数へ更新し、v256専用の数値・コード回帰チェックをCIに追加。Android/Godot未検証。

---

# SERA v255 — BashとSTEPの前方向不一致の修正（2026-11-12）

- v254の `_classify_step_flick` は画面絶対 `Vector2.UP` を0°とし、Bashは `gesture_screen_forward` を0°としていた。画面でセラが斜めを向くと前判定が食い違うため、STEPの区画分類もセラの投影正面で統一した。
- GUARD長押し中の画面回転により初回タッチの方向が古くなる問題には、最後のフリック開始時に投影方向を再取得し、離指のみ取得された場合も再取得する対応を追加。
- 45°×8区画とガード/コンボBashの前方向±22.5°は維持。前STEP 3m／後4m、モーション、Bash追尾、速度/EN、RUN/BOOST、ロック、v251衝突・v249専用命中は維持。
- v200/v254の旧方向基準期待値を修正し、新規v255静的・数値検証をGitHub Actionsへ追加。Godot/Android実機は未実施。

---

# SERA v254 — フリック8方向・45°区画判定（2026-11-12）

- 360°を中心角45°刻みの8方向へ分類、各方向は±22.5°。STEPは画面上を0°にして離指フリックを区画中心の正規化ベクトルに変換し、従来のv252直線移動・方向別モーションへ適用。
- GUARD/コンボ後Bashはセラのスクリーン投影正面を0°として前方区画(0)のみ受け付け、v253のタッチ開始時方向固定、時間・速度・距離・候補保持を維持。Bashの角度分類は同じ8方向ヘルパーへ統合。
- `scripts/flick_direction_policy.gd` の `sector_index` / `eight_way_direction` に責任を集約。AGENTSと操作仕様へ今後追加するフリックにも8区画を義務付け。
- RUN/BOOST連続アナログ、STEP距離・速度・EN、ガード/攻撃優先順位、ロック部位限定命中、v251部位衝突、デバッグJumpは変更しない。
- v200歴史的静的チェックを更新し、v254静的・数値検査をCIへ追加。Android/Godot実機未検証。

---

# SERA v253 — バッシュの画面上セラ前方入力／将来のフリック方向規約（2026-11-12）

- 3段コンボ後とガードからのBash入力を固定画面上フリックから、カメラに投影したセラの前方向へのフリックへ変更。タッチ開始時に方向を保存し、`_change_drag`・`_end_drag`・GUARD最後の短いフリック判定を共通化。
- `scripts/flick_direction_policy.gd` に投影／角度セクター／短時間高速フリックの判定を抽出。今後追加する方向フリックもこの共通規則を適用するようAGENTS.mdと入力仕様に恒久明記。
- 旧Bashの0.24秒／50px／500px/s／横方向0.42、既存コンボ/ガード優先順、v252 STEP方向、RUN/BOOST、デバッグJump、v249/v251命中・衝突は維持。
- v253静的・数値回帰チェック追加。実機未検証。

---

# SERA v252 — 操作方向とフリックステップの画面対応（2026-11-11）

- 画面基準RUN/BOOST/空中移動とロック左右切替はそのまま維持。唯一ターゲット中心の円弧移動だった360°フリックの位置計算を、スクリーン左右＋プレイヤーの前後方向の直線合成へ変更。
- 上方向フリックはプレイヤーの現在の正面に3m、下方向は後方4m、左右はカメラの画面左右へ2〜4m。斜めも連続合成、出発時に方向を確定してカメラ回転による途中の軌道変更を防止。
- 距離2〜4mとステップ速度、装備倍率、EN消費、ステップアニメーション、前フリックバッシュ/ガード、カメラ近距離保護、v251部位衝突、攻撃ロック判定を維持。特異点で画面移動方向へフォールバック。
- v200旧円弧静的検査を更新、v252の連続方向/各象限/距離/統合動作の静的テストをCIへ追加。Godot/Android実機の触感は未検証。

---

# SERA v251 — ターゲットの頭・脚・付け根への移動衝突判定（2026-11-11）

- 本体だけに存在した移動用衝突判定を拡張。既存の頭部/四脚BoxMeshの位置・大きさと一致するBoxShape3DをTargetSolidBodyへ接続。4つの脚付け根には隙間を塞ぐ細長い接続判定を追加し、外側フレーム全体を大きなAABBで閉塞しない。
- RUN/BOOST/全方向STEP/ダメージノックバック/デバッグジャンプは従来のPlayerカプセルと物理レイヤーで共通衝突。格闘/BASH追尾のスイープには水平スライドを有効化。
- 前脚破壊で見た目とその付け根を含む衝突判定を無効化。頭と後脚は破壊後も見た目が残るため判定維持。頭部の破損メッシュは表示に同期して判定を有効化。訓練リセットと復活で元に戻す。物理中の変更はset_deferredを使用。
- v249のロック部位限定攻撃命中AABB、v250の本体500/各部位100HP、各部位防御、操作・UI・アニメーション・モデル原本・描画処理は変更なし。
- v251専用の静的/幾何テストをCIへ追加。実機の壁すべり、接続判定の触感、動くターゲットとの干渉、Android性能は未検証。

---

# SERA v250 — ターゲット本体500HP・各部位100HPへ変更（2026-11-11）

- 共通の本体HP定数を100→500へ変更。頭部38→100、左右前脚各30→100、左右後脚各32→100。通常攻撃力と部位破壊力を分ける従来の仕組みを維持。
- 本体HPバーの低残量色変更を固定40HPから最大HPの40%に変更して従来の警告割合を維持。HP表示は最大値参照のため本体500、各部位100へ連動。
- 部位破壊防御率、2脚破壊ダウン、頭部破壊効果、敵コライダー、AUTO/MANUALロック、プレイヤー側の攻撃・操作とカメラは変更なし。リセット・復活時の最大HP復元を維持。
- v237、v238の旧部位HP固定値に依存した検査を更新、v250専用テストをCIへ追加。Godot/Android実機は未検証。

---

# SERA v249 — ロック中の部位以外への攻撃誘導を防止（2026-11-11）

- 剣の部位AABBを外した場合、胴体AABBへフォールバックする命中を禁止。ロック先以外ではヒットしない。
- 攻撃接近・追尾・コンボ各段・シールドバッシュ・ヒット補助・射程表示をすべてロック先の水平AABB距離へ統一。別の部位や胴体の近さでは攻撃を確定しない。
- ロックなしは従来の胴体判定を維持。部位HP/破壊・物理当たり判定、ステップ、カメラ、AUTO/MANUAL、アニメーション、攻撃時間は不変更。
- 静的回帰チェックを追加して既存CIで実行。Godot/Android実行時の動作は未検証。

---

# SERA v248 — コントローラーを1.5倍へ拡大（2026-11-11）

- v247からコントローラーのRUN円（70→105px）、デッドゾーン（11.25→16.875px）、BOOST基準（105→157.5px）を1.5倍。BOOST開始／解除倍率は110%／90%を維持するため、距離は173.25／141.75px。
- カスタムHUDの円弧線幅、シェル、矢印、モード表示ラベルの高さ・幅・マージン・フォントを連動拡大。指位置の相対強度と描画基準が一致するよう維持。
- 背景透明化・全画面操作・ボタン除外・フリック/ガード/格闘の判定、BOOST確定時間、機体速度・カメラ・アニメーション等は不変更。
- v244〜v247のサイズ固定期待値を改訂し、v248専用回帰テストとCIを登録。Android実機での視認性とGodot実行時のタッチ挙動は未検証。

---

# SERA v247 — 右下操作枠の明るい背景を削除（2026-11-11）

- v246で枠線を削除した後に残っていた右下四角形の灰色グラデーション（四隅の描画多角形）と最下部の単色塗りつぶしを撤去。不要な背景専用定数も削除。操作UIのキャンバスに恒常的な矩形背景は描画しない。
- 入力経路・コントローラーの開始可能範囲、RUN／BOOST各半径と操作判定、ロックONおよびAUTO/MANUAL切替、既存HUDとエフェクトは変更なし。
- v243〜v246の回帰検査を最新の透明背景仕様に更新し、v247チェックとCI登録を追加。Godotエンジン・Android実機による画面表示と入力は未検証。

---

# SERA v245 — コントローラーとRUN／BOOST判定をv244比125%へ（2026-11-11）

- **v244の現在値から25%拡大**。RUN入力半径56→70px、RUNデッドゾーン9→11.25px、BOOST基準半径84→105px。RUNのアナログ強度補間を同一倍率で拡大することで指の入力距離と移動の対応割合は維持する。
- BOOST開始割合110%・解除割合90%・確定0.10秒は据え置き。開始距離92.4→115.5px、解除距離75.6→94.5pxで新しい基準半径に整合。
- 描画コントローラーのRUN円・BOOST円弧・外装のリングと矢印の太さ、方向インジケータ、中央HUDの状態ラベル（寸法とフォントサイズ）を約1.25倍へ調整。実際の入力半径と表示ガイドを一致させる。文字フォントサイズはGodotの整数ピクセル制約で9→11pxに丸める。
- 右下1/4の操作開始枠、枠から外へ出られるドラッグ、操作枠上辺のAUTO/MANUALと左右ロックボタン、STEPフリック最低78px、ガード判定、RUN/BOOST速度・EN・カメラ・アニメーション・格闘は不変更。
- v244既存の静的検査を次期バージョンに追随させ、v245専用の比率・RUN入力曲線・BOOSTヒステリシス・UI描画倍率・既存操作維持検査をCI追加。Godotエンジン構文確認とAndroid実機の操作・表示は未検証。

---

# SERA v244 — RUN／BOOSTコントローラーの半径・判定を50%に縮小（2026-11-11）

- v243の右下4分の1の操作開始枠とAUTO/MANUALロックボタンを維持したまま、実行時のアナログRUN最大操作半径を**112→56px**、中央デッドゾーンを**18→9px**、BOOST基準半径を**168→84px**へ均等に縮小。
- 既存のBOOST開始110%・解除90%・確定0.10秒は変更せず、開始距離を**184.8→92.4px**、解除距離を**151.2→75.6px**に縮小。RUNへのアナログ出力強度（デッドゾーンから半径最大までの線形補間）も半分の操作距離に整合。
- `scripts/touch_overlay.gd`のRUN円、BOOSTガイド円、外装円弧、外向き矢印、中心インジケーター、RUN/BOOST文字ラベル等も**50%のサイズ**へ。指の初期位置を中心として動的に描く既存仕様、トレーニング枠全体（画面右下X50〜100%・Y50〜100%）、新規ロックモードボタンは不変更。
- STEP判定の最低78px・フリック時間/速度、ガードのタップ/ホールドしきい値、攻撃キャンセル、RUN/BOOSTの移動速度やEN消費、カメラ・モーション・部位破壊は変更しない。
- `tools/v244_half_size_run_boost_controller_self_check.py`に入力半径と描画半径の一致、50%比率、残存するBOOSTヒステリシス/移行時間、既存フリック・ガード判定・右下領域の維持を確認する静的回帰検査を追加。GodotパーサーとAndroid実機の操作・視認性は未検証。

---

# SERA v243 — 右下1/4コントローラー枠／ロック切替とAUTO/MANUALモード（2026-11-11）

- 720×1280の縦画面上で、操作開始領域を**画面右下1/4（X≥50%／Y≥50%）**へ限定。右下領域に明確な長方形フレーム（暗色半透明の内部グラデーションと青緑の枠線・下角マーカー）を描画。既存下部全面の操作背景は右下フレーム内へ移す。
- **操作の開始点だけ**領域内とする。指を一度置き移動/格闘タップ/ホールドガード/フリック/BOOSTを開始したら、ドラッグ先と離す位置は画面全域で受け付ける。既存のポインター原点・RUN/BOOSTスティック強度・方向判定・ステップ・ガード・コンボの数値やモーションには変更なし。Android ScreenTouchとエディタマウス左ボタンの両方へ同じ開始判定を適用する。
- フレーム上辺の**左上**に`◀ LOCK`、**右上**に`LOCK ▶`、**中央**に`AUTO`／`MANUAL`モード切替ボタンを配置。位置は画面相対アンカーで常時枠に追従、タッチ領域は左右各104×58px、中央128×58px、上側8px、両端8px。GUIは入力を重複処理せず、既存のHUD専用タッチIDで指の移動・離しを隔離。
- **AUTO**（デフォルト）では従来の自動部位選択を使用、左右の手動切替ボタンは無効表示。**MANUAL**では切替前の現在ロックを保持し、左右ボタンだけで画面投影座標順に変更する。AUTOに戻すと自動選択を再開。部位破壊、敵の再出現、セラKOでロックIDを解除しても現在のモード自体は保持し、MANUAL中に勝手な自動ロック復帰は行わない。
- 既存のv242のロック先カメラ視点判定・遮蔽・生存判定・端の非循環、v237部位破壊・格闘追尾・セラのモーション・カメラ追従は保持。モード切替はゲーム内のセッション状態（永続保存はなし）。
- `tools/v242_screen_lock_buttons_self_check.py`の旧画面下から40%の配置契約を最新版に更新し、`tools/v243_controller_quadrant_lock_mode_self_check.py`で矩形入力域、指の保持、3ボタンの当たり判定、AUTO/MANUALのモード保持をCI検査。Godot/Androidでの実際のタップ操作は未検証。

---

# SERA v242 — 画面左右ロック切替ボタン（2026-11-11）

- 戦闘画面の左右端に`◀ LOCK`／`LOCK ▶`を追加。中心Yは画面下端から高さ40%（画面上から60%）を画面サイズに対するアンカーで固定。左右端余白18px、タッチ領域108×68px。スマホの縦画面に合わせて位置を自動調整する。操作ゾーン下端75%より上に設置。
- 現在ロックしている部位のCamera3D.unproject_positionによる**画面X座標**を基準に、押した方向へ最も近い部位を選ぶ。部位のワールドXや「前脚L/前脚R」という名前による固定順位は使わず、視点が回り込んでもタップ方向と画面方向が一致。破壊済み・カメラ背面・画面外・本体や他部位で遮蔽された部位は候補外。方向側に候補がない場合は据え置き、反対端への循環なし。
- **手動選択を優先**：切替成功後は停止/移動中の既存自動部位選択に上書きされない。攻撃・追尾・コンボ・Bash中は既存のターゲット固定を守り、切替操作は無効。部位破壊・KO/再出現時は手動ラッチ解除、これまでの自動ロック選択に復帰。
- AndroidネイティブScreenTouchとデスクトップ左クリックの両方を`main.gd::_input`で処理し、専用タッチIDを既存`step_hud_touch`で隔離。ボタン起点の長押し・ドラッグ・離しは攻撃/移動/フリックを起こさず、別指がすでに行う操作には影響しない。ボタン自体の`mouse_filter=IGNORE`でGUIとの二重処理を防止。
- 既存のターゲットへの射影リング、部位破壊、オートロックの角度・遮蔽・ヒステリシス・セラのモーション、ENとカメラ追従は不変更。新たな視線候補API `target_parts.get_visible_part_ids` で既存と同じ遮蔽判定を利用。
- `tools/v242_screen_lock_buttons_self_check.py`をCIに追加して位置・左右選択・遮蔽/破壊除外・保持・マルチタッチ隔離を静的検査。Godot構文解析とAndroid実機のタップ挙動は未検証。

---

# SERA v241 — スラスター全方向に下向き推力成分を加算（2026-11-11）

- 背部左右スラスターの実ノズル操舵 `scripts/back_thruster_fx.gd` に、ワールド下向き成分を加える定数 `LIFT_DOWNWASH_WEIGHT=0.40` を追加。水平基準では約21.8°の下向き成分を付加して「機体を持ち上げる推力」を視覚化。
- Blockbenchのノズル休止基準座標（回転前の`rest_basis`）にワールド重力方向を変換し、噴射方向ベクトルとの合成後に正規化。標準のBOOST/STEP/攻撃追尾/通常格闘と、左移動専用の画面右下扇形操舵の双方に同じ補正を適用。胸や腰のアニメーション姿勢・左右ピボットが動いても世界下向きを維持する。
- 既存の左右ヨー±80°、ピッチ上1°・下90°、後退時ピッチ90°、通常格闘中のヨー±20°・下35°、胴体への噴射侵入回避と返り補間0.075秒は保持。補正は有効な噴射コマンドにのみ適用し、非噴射時の既存の下90°戻りは変更なし。
- ノズル自身を回すため噴射エフェクト／リボン追跡は最終姿勢に従う。既存の描画優先度127・深度テストON・斬撃前面オーバーレイ126との合成契約は不変。元Blockbenchメッシュ・モーション・セラの位置/移動速度には変更なし。
- `tools/v241_thruster_lift_downwash_self_check.py`で両経路の実装、世界座標変換の方向、標準移動時の約22°補正・後退90°飽和・左画面右下扇形・格闘可動域・安全補正・表示契約の維持を数値チェック。
- Android実機の姿勢・火炎方向の最終確認とGodot構文検証は別途必要。

---

# SERA v240 — ターゲットの腕状フレーム・四脚大型化（2026-11-11）

- 訓練ボスの左右前後四つの側面部位を太く大型化。各脚の外接判定を1.38×2.00×1.02mから**2.24×2.00×1.36m**に変更。横幅・前後奥行は大きくしつつ、先行指示の縦2.0mは維持。
- 上側の腕に見えるアウトリガー・肩装甲、外側装甲、前腕ガード、突き出た腕先端を箱メッシュで形成。膝・支柱・足先も厚く広げ、前後の装甲・ピストン・足先はZ方向で反転。左右X方向も鏡映し、ローポリの直方体・立方体表現に統一。
- ロック照準を増大した外装の先端（ローカルX±0.78、Z前後±0.52）へ移動。AABBは13個の構成ボックスをすべて内包し、頭部のロック・近接判定と中央胴体2×2×3.4mは不変更。
- カメラのターゲット外周フレーミング半幅を1.85→**2.35m**へ拡大し、前後・上下フィット、追従速度、攻撃モーション、各部位HP/破壊演出は維持。
- `tools/v238_target_mecha_frame_self_check.py`と`tools/v239_target_rectangular_body_self_check.py`を寸法変更に追随、`tools/v240_target_large_limb_self_check.py`にソース抽出・幾何AABB・足底・腕先端ロック・左右前後対称性を追加。静的CIは実機描画ではない。

---

# SERA v239 — 前後長胴体・同高四脚・低位置頭部の直方体化（2026-11-11）

- 訓練敵本体を幅2.0m・高さ2.0m・前後3.4mの**前後に長い直方体**へ変更。表示用BoxMesh、実体のBoxShape3D、通常剣撃AABB、近接距離の計算を同じ寸法で統一し、見えている胴体の内側へすり抜けないようにした。
- 四脚は本体左右の前後へ移設（X=±1.23、Z=±1.27）。脚の最大Y寸法を本体と同じ**2.0m**にし、側面接続ジョイント→上下支柱→矩形フットへ連結。基準姿勢で脚の足裏はY=0mを維持。各構成部品は不透明BoxMeshの直方体／立方体のみ。
- 頭部は前面Z=1.85へ移動しY=-0.44（世界中心高さ1.09m）まで下げ、ヒット用AABBは高さ0.68–1.50m、ロック点は約1.06mの攻撃可能域へ。胴体前面Z=1.7への接続を維持し、メカフレームを保持。
- 画面端・全体フィットは胴体の長さと外部フレーム（X±1.85、Z±2.35、Y±1.53）を包含する角座標に調整。移動するダミーのプレイヤー押し込み防止と弾発射の面判定も胴体のXZ長方形へ揃えた。カメラのターゲット中心・追従速度は不変更。
- 頭部と四脚の独立HP、防御・破壊防御、破壊表示、怯み/ダウン、自動ロック/バッシュ、プレイヤーの武器とモーションは変更なし。旧v237/v238の専用検査は寸法更新を反映し、新v239幾何・攻撃域・描画形状検査をCIに追加。
- MODEL_PART_WORKFLOWとRENDER_PIPELINE_POLICY参照済。Godot構文解析／Android実機の表示・攻撃命中・ターゲット変更の実動作は別途確認が必要。

---

# SERA v238 — 外周側面接続型メカフレームターゲット（2026-11-11）

- v237の5部位ターゲットの外観を、2m胴体の外周に沿う増設メカフレームへ変更。HEADは胴体前面（+Z）から接続するセンサーハウジング、FRONT/REARの左右4脚は胴体の側面（X=±1.0m付近）から外へ伸びる外骨格ユニット。
- HEAD：前面接続ネック、センサーハウジング、両サイドレール、上下クロスメンバー、バイザー、破壊後の露出フレーム。脚：コアと重なる接続マウント、股関節ジョイント、側方アウトリガー、上部支柱、膝、下部支柱、ピストン、外装プレート、踵、接地フット。すべて不透明な軽量BoxMesh（既存の深度描画）。
- 正負Xで左右の内部部品座標を鏡映し、前後はZ=±0.78m。脚のフット下端を基準ターゲット中心高さ1.53mにおいてY=0へ揃える。胴体の物理コライダー、カメラ中心、浮遊アニメーションは不変更。
- 部位のローカル中心／サイズ／ロック照準オフセットを外周構造へ合わせ、各外接AABBが全メッシュを内包するよう調整。v237の部位HP、防御、破壊モード（前脚消失・後脚残留・頭部変形）、怯み/ダウン、頭部破壊による攻撃制限、自動切替・メレー・バッシュは現行のまま。
- ユーザー提供のBlockbenchデータやセラ装備・骨格・アニメーションは編集しない。MODEL_PART_WORKFLOWとRENDER_PIPELINE_POLICYを参照し、半透明材質・独自描画優先度は追加しない。
- `tools/v238_target_mecha_frame_self_check.py`を追加し、四脚の左右対称配置・床接地・中央コア外側への張り出し・フレーム外接範囲・破壊契約をCI検証。Godot実機の見た目・当たり判定は未検証。

---

# SERA v237 — 五部位破壊と部位ターゲット自動変更（2026-11-11）

- ユーザーの部位破壊仕様に沿い、独立スクリプト`scripts/target_parts.gd`で訓練ボスへ頭＋4脚の立体モデル、独立HP・防御/破壊防御・破壊モード・攻撃判定AABBを追加。中央の赤2mキューブと物理衝突、ターゲット移動、カメラフレーミングは維持。
- 通常攻撃（3段）とバッシュで**本体への攻撃ダメージ**、選択した部位への**破壊ダメージ**を同時かつ別途処理。共通STAGGERを維持して旧ダミーCORE75の一括破壊処理を部位独立処理に置換。部位破壊は大怯み1.0秒、脚2本破壊で3.5秒ダウン、頭破壊でSHOCK/ARCをAIMへ代替。
- 部位の選択はセラ正面からの角度を基準に、遮蔽と破壊状態を判別し0.13radヒステリシスで安定化。攻撃中のロック固定、部位への追尾方向・照準表示、復活時の全リセット、全五部位の残耐久HUDを接続。元の入力・フリック・カメラ中心・装備/アニメーション/ENを変えない。
- 3Dモデルは不透明BoxMeshの試作で、Blockbench原本や既存A装備モデルを編集しない。MODEL_PART_WORKFLOWおよびRENDER_PIPELINE_POLICY参照済。データ定数CORE 50%・頭/脚各10%を記録しつつ、試作では既存の本体HP100を共有・部位耐久は別管理。
- `tools/v237_target_parts_break_lock_self_check.py`をCIへ追加。Godotパーサ・Android実機での描画、操作体感、部位当たり判定は未検証。

---

# SERA v236 — 左右STEPのターゲット距離に応じた速度補正を廃止（2026-11-11）

- ユーザー指示：左右STEPにのみ適用されていた敵との距離5m→2mでの10→8m/s減速を除去する。
- 通常の左右フリック（`direction.y=0`）は距離に関係なく`STEP_SPEED=10.0m/s`（脚部装備の既存`step_speed_mult`のみ適用）。旧専用`_start_side_step()`も同じ固定速度へ変更する。
- 前方（v235の3.0m）と後方（4.0m）の距離による速度補正は残し、斜め入力では`absf(direction.x)`に比例して補正ありの前後速度と固定横速度を連続補間。全方向の入力は360°維持する。
- 移動距離そのもの（左右の35°公転、最短2.0m・最長4.0m・最大0.4秒、衝突による停止）、`step_speed_mult`/`step_time_mult`、カメラ・モーション・EN・他アクションは不変更。距離に応じた公転角の計算は軌道の幾何処理として残す。
- 待機中の速度HUDは左右STEPの固定速度を表示し、実行中は開始時のスナップショット速度を表示。専用v236回帰検査をCIに追加。Android/Xperia実機は未検証。

---

# SERA v235 — 前方ステップ距離を1.5倍に（2026-11-11）

- ユーザー指定により、上フリックの前方STEP（Frontstep）の予定移動距離を従来の2.0mから**3.0m（1.5倍）**へ変更。 `STEP_FORWARD_DISTANCE=3.0`を独立定数とし、`_start_omni_step()`で前方成分（`direction.y<0`）だけへ適用。
- 速度8〜10m/sは変えず、純前方の継続時間は0.300〜0.375秒に比例延長。左右STEPの軌道（2〜4m）、後方STEPの4m、斜めの方向入力と既存全体4m上限、足IK/Frontstep姿勢、ステップ衝突スイープ、EN消費、カメラ制御を維持。
- 敵や壁と衝突した場合は3mに到達する前に止まることがあり、実移動距離の増加は衝突可能空間に依存する。近距離の挙動はAndroid実機未検証。
- `tools/v235_forward_step_distance_self_check.py`を追加し、`v200_contact_omni_step_self_check.py`の旧2m前進前提を3mへ更新。PRのワークフローへ両回帰検査を登録。

---

# SERA v234 — 近距離ズームイン速度を接近速度に追従させる（2026-11-11）

- ユーザー要望：プレイヤーがターゲットへ近づくとき、カメラの接近はプレイヤーの接近速度より「少し遅い」程度にし、速度の揺れ・停止直前のカクつき・画面端の安全ズームへの影響を避ける。
- v233以前のカメラ目標半径はターゲットとの距離でsmoothstep補間した後、`camera_follow_radius = lerpf(..., easing * 0.9)`だけで更新される。目標距離との差で速度が変わり、プレイヤーの実際の接近速度とは無関係だった。
- v234では描画位置補間済みのプレイヤー・ターゲット間距離を前描画フレームと比較し、`(previous_separation-current_separation)/delta`から**距離短縮速度**（0〜12m/s）を取得。10/sの指数平滑化を通し、目標カメラ接近速度をその**88%**とする。距離5m以下は完全適用、5〜8mはsmoothstepで遠距離の旧追従速度と連続補間、8m以上は従来どおり。
- 接近速度の上下は最大24m/s²で追従し、カメラ残差へ指数減速率6/sを掛けて目標位置手前で急停止しない。実接近が停止しても残差があれば最大0.70m/sを基準に徐々に構図を合わせ、移動時の停止/方向転換で残差が振動しない設計。画角の安全半径と最小8.8m/最大16.0m設定、カメラYaw、BOOST入力・速度・モーション・足IKに変更なし。
- 強制ズームを保持する`camera_fit_radius_floor`は旧1.25m/s固定解除だと、新しい近距離カメラが高速接近しても追いつけないため、距離5〜8mで平滑化した接近速度に応じ解除速度を最大`camera_dolly_in_speed * camera_near_dolly_weight`まで増加（最低1.25m/s）。BOOSTの安全半径と通常の`_full_frame_safe()`による画面内判定は絶対条件として維持。
- KO後の初期位置へワープしたとき、前位置との差分を誤って高速接近と認識しないよう、距離微分履歴と速度フィルタを初期化。
- `tools/v234_near_camera_dolly_self_check.py`に遠距離の旧式一致、30/60/90/120Hzの単調接近、88%付近の速度収束、画角の安全半径下限テストを追加。実機体感は未確認。

---

# SERA v233 — カメラ最接近位置を少し後方へ調整（2026-11-11）

- ユーザー要望により最接近のカメラ半径`CAMERA_CLOSE_RADIUS`を7.8mから8.8mに変更（約12.8％後方）。
- 接近判定開始1.5m、遠距離側のカメラ半径16.0m、遠距離境界12.0m、既存smoothstepズーム補間とfollow率は変更しない。
- v232の画面左右端BOOSTカメラ安全距離計算、v231の描画/物理補間、v230の安全フィット半径保持は従来どおり。計算上必要な場合は8.8mを超えてズームアウトする。
- `tools/v233_close_camera_radius_self_check.py`で最小/最大半径、ズーム曲線、画面端BOOST保護、移動速度無変更の回帰検査を追加。
- Android実機での見え方は未確認。

---

# SERA v232 — 画面左右端の外向きBOOSTでカメラが微振動する不具合（2026-11-10）

- 参考動画`1000034531.mp4`（約9.35秒、1096×2560、約118fps）で、ターゲットを画面に捉えたまま機体が左画面端へ外向きBOOSTし、背景格子とターゲットの見え方に細かな揺れが残る症状を確認。
- v230の`close_boost_camera_active`はターゲット距離6m以内のみ画面端のYaw強制二分探索を抑止したが、離れると再び強制Yawとカメラ相対移動が競合。加えて`_fit_full_frame()`は画面内に収まらないフレームで、最大22段階の半径拡大と16段階の二分探索・全頂点の投影を実行していたため、左右端付近でフレーム単位の処理量も増減する。
- v232は確認済みBOOSTとその既存姿勢維持（ジェスチャー継続・戦闘でない場合）を近距離/遠距離共通`boost_edge_frame_guard`にまとめ、通常の緩やかなターゲット方位追従を残しながら画面端強制Yaw補正を迂回する。STEP固有の保護は優先。
- BOOSTのフレームフィットは縦FOVと画面縦横比、現在のYaw・Pitch・注視点から、機体の体幹/上下端5点とターゲット立方体8頂点に必要な最小カメラ半径を透視投影の不等式から**直接計算**。各描画フレームに固定回数のベクトル演算のみを行う。旧多段階二分探索は通常RUN・STEP用に保存。
- BOOST中は必要半径+従来の0.12m予備量より小さくフィット保持値を下げない。通常ズームとの`max`適用は継続し、安全側からの縮小は最大1.25m/秒。毎フレームの縮小・再拡大往復を止める。
- `tools/v232_boost_edge_camera_self_check.py`でBOOST時の分岐/一定計算量、透視投影が画面枠を守るかを独立の数式で350ケース（左右、至近/遠距離）検査。数値・静的テストは実機フレーム時間を保証せず、Android実機確認が必要。
- 変更は`scripts/main.gd`のカメラ分岐と新しい専用数式関数のみ。操作、移動速度、EN、画面端以外のRUN/STEPカメラ、モデル/モーション、IK、スラスター描画処理は維持。

---

# セラ v231 — 参考動画のBOOST時カメラ微振動：物理/描画の時刻同期（2026-11-10）

- 参考動画（10.58秒、1096×2560、約113fps）では4秒以降のBOOSTで機体が高速移動し、カメラと地面に細かなカクつきが認められた。v229/v230の画面端Yaw制限とズーム保持だけでは物理・描画クロック差（既定60物理Hzに対して約113描画fps）を解消できなかった。
- `scripts/main.gd`のトレーニング画面に限り、`SceneTree.physics_interpolation`を有効にして、終了時には従来設定へ復元。ルートと描画更新するカメラ・SERA関節リグは非補間。物理移動するPlayer、VirtualTarget、両者の床影マーカーのみ物理補間ON。親Playerの補間済みワールド位置はリグに反映し、元の関節キーフレームとIKは画面ごとのまま。
- カメラが使用する距離・方位とフレーム内判定（画面端、ターゲット8頂点、胸/頭/足）は、描画フレーム内に1回取得した両者の`get_global_transform_interpolated().origin`を共通で参照。HUDのターゲットマーカーも同じレンダー位置へ投影。カメラ本体は物理補間せず、既存のカメラ遅延追従・ズーム保護を毎描画フレーム実行する。
- ターゲットの上下の周期運動を`_process`から`_physics_process`へ移動し、物理補間するターゲットへの描画タイミングの直接操作をなくす。再スタートによるPlayer/Targetのワープ時は`reset_physics_interpolation()`で残像移動を防止する。
- BOOST入力・移動量・操作応答、画面端保護、STEPカメラ、HP/EN、衝突、音、装備・モーション原本・スラスターは保持。拠点/NEXUSへの影響を避けるため補間はトレーニング画面の存続期間のみに限定。
- `tools/v231_camera_physics_interpolation_self_check.py`で制御分離・描画位置の一致・ワープ履歴消去・約113fpsと60Hzの数値比較をテスト。GitHub Actionsの静的検査はAndroid実機の改善保証ではない。

---

# セラ v230 — 近距離・左後方BOOST時のカメラ振動対策（2026-11-10）

- カメラ近距離で左後方へBOOSTすると、通常の追従Yaw＋画面端の強制Yaw補正と、カメラ半径のフレームフィット補正が同一描画フレーム内で競合しうる。v229は回転速度制限を入れたが、近距離BOOSTに特化した遷移条件がなかった。
- ターゲット距離6.0m以内の移動BOOSTで`close_boost_camera_active`へ移行し、画面端での角度強制補正を一時停止。ターゲット中心への通常の滑らかなYaw追従は継続し、ターゲット・自機のフレーム保護を従来のズームフィットに委ねる。終了条件は7.5m以上（ヒステリシス）またはBOOST入力・維持の終了。
- 強制ズーム量と通常の追従ズームを分離するため`camera_follow_radius`と`camera_fit_radius_floor`を導入。安全フレームに必要だった半径を保持し、画面に収まることを再検証しながら最大1.25m/秒で縮小する。以前の「強制拡大→次フレームに通常カメラの縮小補間→再拡大」を抑える。
- 近距離STEPの独立した相対角制限、通常RUNや遠距離BOOSTの画面端補正、BOOST入力・加速度・消費EN、SLIDE/BOOST姿勢・IK、敵のフレーミング、カメラ上下角は変更しない。
- `tools/v230_close_boost_camera_self_check.py`に近距離BOOST専用分岐、ヒステリシス、強制ズームの記憶・安全な減衰と数値シミュレーションを追加。Android実機のフレーム表示検証は未実施。

---

# セラ v229 — SLIDE/BOOSTの滑らかな姿勢推移と画面端カメラ補正（2026-11-10）

- v228までの重量脚部B/Dは、同じBoost_*クリップのSLIDE/BOOST切替で姿勢混合率が50%と100%を一瞬で切替していた。v229では0.18秒smoothstepで姿勢を連続補間し、途中で反転しても現在の重みから継続。
- 靴底水平化、左右二骨IK、表示用腰の下降もSLIDE重みで同時にフェードする。実BOOST中の0.50秒保持、4方向Boost_*、移動速度、操作判定とスラスター発動条件は維持。
- 左右画面端のカメラは、画面端に到達してから二分探索したYawへ即補正する処理が追従Yawと競合しうるため、画面幅0.8%の予備マージンで早めに補正。強制Yaw補正を最大240度/秒とし、フィット用ズームにも0.12mの余裕を残して境界付近での再補正を緩和。
- Godot Androidでの左移動、BOOSTへの再突入、ターゲット近距離、画面端の動作は未検証。v212/v227/v228旧回帰検査を連続重みに合わせて更新、新規v229静的・数式検査を追加。

---

# セラ v228 — SLIDEの靴底全面接地と腰の沈み込み（2026-11-10）

- v227では両足の最下点のみを接地させ、BOOST元ポーズの足首ピッチ・ロールを保っていた。B/Dの靴メッシュは底面が平面（ローカルXZ）なので、SLIDE中はまず左右の足首ワールド姿勢を補正して足底法線を鉛直上向きにする。両足の踵・つま先の底面を床と平行にする。
- 水平化後の実頂点から左右それぞれの床面目標位置を計測して、v227のThigh/LowerLeg二骨IKに引き渡す。IK後も水平化済みの靴の向きを維持し、足首をメッシュだけずらさない。
- 腰の表示用リグをSLIDE中だけ常時0.07m下げ、IK到達限界がある場合は必要な分を追加で下げる（合計最大0.30m）。股関節・膝に屈曲余裕を与え、床面までの到達を優先する。プレイヤーの物理座標・コライダーは不変。
- 対象外：LOWER BODY A/C、実BOOST、STEP、攻撃、ガード、ジャンプ、ダメージ、NEXUS。Blockbench素材と靴メッシュ、元アニメーション、移動・ステータス・エフェクトの変更は行わない。
- v227回帰テストを新しい腰補正式へ更新し、v228の靴底平面形状・足首回転・適用順を検査するテストを追加。CIの静的テストはAndroid実機の表示検証を代替しない。

---

# セラ v227 — 重量脚部SLIDEの両足接地IK（2026-11-10）

- LOWER BODY B/Dの通常移動SLIDE（Boost_*静止ポーズを50%使用）に限り、左右の標準Thigh→LowerLeg→Footを二骨IKで補正。足首のXZはスライド移動に追従し、各靴メッシュの実三角形最低Yを床面Y=-0.0335へ合わせる。
- 毎フレーム、元モーション適用→足裏接地の基準位置復帰→RUN一時補正の復帰→SLIDEの両足IKの順で処理。腰・膝・足首の元キーフレームは編集せず、膝方向は補正前の関節平面を優先し、伸び切り特異点を回避する。
- 両脚が床へ届かない場合のみ表示用リグを最大0.24mまで下げ、足首ターゲットは到達可能範囲へ制限。足メッシュのみを引き伸ばさず、元の靴向きを保つ。極端な高さ・骨格変形は到達限界により完全接地が保証できない。
- IK対象外: LOWER BODY A/C、実BOOST、BOOST猶予、STEP、格闘・バッシュ、ガード、ダメージ、ジャンプ、NEXUS展示。移動・HP/EN・当たり判定・スラスター・足音・3D原本は変更なし。
- `tools/v227_slide_leg_ik_self_check.py`でIK経路、数式の到達範囲、従来の隔離条件を検査。GitHub Actionsへ登録。Godot Android実機での両足接地、膝の向きと切替時表示は未検証。

---

# セラ v226 — 3D描画順・深度・座標系の共通契約（2026-11-10）

- スラスター固有のv225不具合を一般化し、全3Dエフェクトへ使える描画ロールを`scripts/render_order_policy.gd`に集約。残像-20、斬撃100/105/110、命中火花120、本体斬撃前面126、深度ON発光127。
- `scripts/sera_rig.gd`、`scripts/sword_trail.gd`、`scripts/back_thruster_fx.gd`に散在していた優先度値を共通定数に置換。数値と深度/合成設定はそのまま維持し、表示を変更しないことを目的とするリファクタリング。
- `shaders/back_thruster.gdshader`、`shaders/back_thruster_trail.gdshader`、`shaders/sera_foreground.gdshader`に深度契約コメントを追加。
- `docs/RENDER_PIPELINE_POLICY_ja.md`を新設。機体に追従する座標と履歴、ON/OFF、深度遮蔽、透明描画順、補正適用順を独立して設計するチェックリストと、攻撃段間の遷移検証表を記載。`AGENTS.md`とモデル制作規約から必須参照。
- `tools/render_policy_self_check.py`をCIに組み込み。描画優先度の直書き、参照漏れ、深度契約不一致、追加半透明shaderの申告漏れを検出。従来のv225回帰テストも共通定数参照に更新。
- プロジェクト名のみv226へ変更。モデル・モーション・当たり判定・ゲーム操作・描画結果の意図した変更はない。Godot/Android実機での表示は未検証。

---

# セラ v225 — 格闘中のスラスター描画順と可動域補正（2026-11-10）

- `scripts/sera_rig.gd`の斬撃中の本体オーバーレイは描画優先度126、深度テスト無効。噴射と帯状軌跡のマテリアルは従来優先度0で、機体手前の噴射もオーバーレイに消されていた。
- `scripts/back_thruster_fx.gd`の噴射外側・内側・帯状軌跡の優先度を127へ変更。各シェーダーの通常深度テストはそのままのため、実際に胴体より奥の噴射は表示しない。
- v224の格闘専用可動制限（ヨー±20°、下降ピッチ35°）を補間後のノズル角度にも適用。BOOST専用の前フレームの特殊方向姿勢を格闘開始時に持ち込まない。
- v222の胴体干渉対策では、まずBlockbench元ノズル向きへ戻し、原点が内向きの場合のみ従来の安全円錐への投影を使用。旧補正がv224の可動制限を上書きする問題を防止。
- 通常BOOST・STEPの動作、元モデルとモーション、連続噴射と15倍フレア・v223軌跡は変更なし。
- 静的および幾何セルフチェックはGitHub Actionsで実施。Godot/Android描画は未検証。

---

# セラ v224 — Melee2移行時のスラスターノズル異常角度を制限（2026-11-10）

- `scripts/back_thruster_fx.gd`: 格闘中に限りノズルの相対ヨーを±20°、下降ピッチを35°へ制限。Melee2の胸部大回転を打ち消すようにノズル本体が横向きになり、リムと噴射が機体に潜る問題を抑制する。
- ブースト・ステップの80°/90°可動域、追尾時の方向制御、加速バースト、通常格闘中の連続噴射、v222身体干渉防止、v223帯状残光、Blockbench原本は変更なし。
- `project.godot`: v224。モデル上の左右ノズルと可動限界が胸部外側への最低安全角を維持することをセルフチェック。Godot/Androidの実機描画は未検証。

---

# 2026-11-09 — 3Dモデル制作・GitHub統合の運用文書と参照チェック（ドキュメントのみ）

- 基準コミット: `036a1b689f0bbedf7ce2c3cd4a2a0038f9ff235c`（SERA v183）。ゲームのバージョン・コード・3Dモデル本体は変更しない。
- `docs/MODEL_PART_WORKFLOW_ja.md`: ユーザーは単体Blockbenchパーツ・骨格・部位・希望サイズを指定。フォルダ構造/Pivotが適切ならメッシュ名/個数は自由。ChatGPT/Codexが名前変更、グループコピー、UUID/位置/倍率/骨格の接続、ゲーム内登録、GitHub反映を担当。見た目の最終整合はユーザーが確認。
- 異骨格モーション共有などは**将来実装する対象**と明記。現行実装のA骨格と追加装備の読込元、独立スロットの制約を記録。
- ルート `AGENTS.md` と `models/`、`blockbench/`、`assets/`、`scripts/` の `AGENTS.md` に参照義務を追加。
- `tools/model_policy_check.py` と `.github/workflows/sera-model-policy.yml` を追加。モデル関連PRでは文書リンクと `MODEL_GUIDE_READ: YES` の確認を行う。これは**運用の検査であり、モデル自動取込やAndroid実機テストではない**。

---

# セラ v113 — RUN頭部の周期的な回転揺れを65%抑制（2026-11-07）

- 基準：GitHub `main` コミット `1d41f42f2a002031ce52e7593e0b2ee416e47e79`。前進RUNの上半身から頭までの合成回転は4位相平均に対して最大約29.8°変動、後退RUNでは約3.4°（元キーフレームに基づくQuaternion計算）。
- `scripts/sera_rig.gd`：前方・後方RUNを元の位相で混合した後、腹・胸・首・頭の合成向きについて0/0.25/0.5/0.75秒の4位相平均を基準とし、周期回転成分の35%のみを残す。参照姿勢にも既存のターゲット追従関節ヨーを適用し、親ボーン回転の逆変換で頭のローカル回転へ反映。位置・スケールは未変更。
- 腰の移動方向追従、最大15°バンク、前後RUN判定・利き手切替、0.18秒クロスフェード、実際の移動・カメラ・攻撃・Guard・Boost・Step・Jump、モデルJSON/Blockbenchキーフレーム・音源を維持。RUNから他動作への遷移も既存の姿勢ブレンドを使用。
- `project.godot` のプロジェクト名を同期試験用 `4g_test` から `SERA v113 - RUN Head Stabilization` へ戻し、`README_v113_ja.md` と `tools/v113_run_head_stabilization_self_check.py` を追加。既存v112のプロジェクト名検査のみ、後継版に対応する形式に変更。
- GitHub連携経由でソースの整合性・回転計算モデル・変更範囲を検査。**Godot本体の実行、Pythonチェックコマンドの実行、Android実機の見た目確認は未実施**。特に前RUN/後ずさり、急旋回、RUN解除/再開と目線の自然さを実機で確認すること。

---

# v105（2026-11-06）訓練ステージBGMの読み込み修正

- 基準：v104。ユーザーから「BGMが流れない」と報告。未実機調査のため原因は確定していない。
- `scripts/stage_bgm.gd`：`ResourceLoader.exists()` とインポート済みリソース `load()` に依存せず、`AudioStreamOggVorbis.load_from_file()` で `BGM/*.ogg` を直接読み込む。シーン準備後に再生し、失敗時の診断情報と開始ログを追加。
- 音源、イントロ→ループ仕様、音量-9dB、シーン構造、戦闘・カメラ・入力・モデルは不変。`project.godot` の表示名のみ v105 に更新。
- 音源原本のSHA-256およびGit blobの一致を確認。単体静的チェック、Python構文チェック合格。`tools/v105_stage_bgm_self_check.py` を追加。
- Godotエディタ起動・Android実機音声出力は未検証。ユーザー端末で動作確認が必要。

---

# v104（2026-11-06）トレーニングステージBGM

- 基準：GitHub `main` v103。訓練ステージにユーザー提供OGGのイントロ（7.74秒）→ループ本編（61.94秒）を再生する独立ノードを追加。
- `scenes/main.tscn`、`scripts/stage_bgm.gd`、`project.godot` を変更。新規 `README_v104_ja.md`、`tools/v104_stage_bgm_self_check.py`。
- 元の `scripts/main.gd`、戦闘音／被弾音、AI、操作、カメラ、Blockbenchモデルを保持。
- ユーザーがOGG音源2件を `BGM/` にGitHub登録。原本添付とGit blob SHAが双方一致。スクリプト・検査ファイルは `res://BGM/` を参照する。
- ローカルのBGM込み差分で `v104_stage_bgm_self_check.py` を実行し、OGG先頭識別子・SHA256・シーン接続・ループ設定チェック合格。Python構文検査合格。GitHub上で変更ファイル一覧、パス、音源Git blob SHA確認。Godot本体・Android実機音声再生の検証は未実施。

---

# v103（2026-11-06）ターゲット本体の赤色化

- 基準：GitHub `main` のv102。変更は訓練ターゲットの色のみ。
- `scripts/main.gd`：`FloatingBox` の基本色を `#E53935`、発光色を `#A92724` に変更。命中フラッシュ復帰時も同じ赤系へ戻す。
- 命中時の暗赤色と既存の陰影・ヒット演出、ターゲットの形状・当たり判定・HP、カメラ・入力・ガード・敵AI・音声・モデルは変更しない。
- `project.godot`：v103の表示名だけを変更。`README_v103_ja.md` と `tools/v103_target_red_self_check.py` を追加。
- GitHub上の差分と色コードの静的確認を実施。Godot本体・Xperia 1 Vでの実機描画テストは未実施。`main` への統合は実機確認後。

---

# v102（2026-11-06）Guardポーズ修正版への差し替え

- 基準：v101 `sera_portrait_godot_melee_v101_hold_guard.zip`。
- 提供 `SERA_Guardfix.bbmodel` の `Guard` クリップだけ抽出し、`assets/sera_source.json` の旧Guardを置換。ほかのアニメーション・モデル・全操作／被弾ロジックは不変。
- 22ボーンUUID一致、13ボーンのキーフレーム変更、0秒固定ポーズ形式維持。`tools/rebuild_model_data.py` で `assets/sera_data.gd` を更新。
- 追加：ユーザー修正版原本、統合モデル、README_v102_ja.md、tools/v102_guardfix_self_check.py。元のv101統合モデルや原本も履歴として保持。
- `project.godot`：表示名をv102へ更新。Godot本体・Android実機の実行確認なし。

---

# v101（2026-11-06）静止ホールドガード／Guardキー追加

- 基準：ユーザー提供 `sera_portrait_godot_melee_v100_jump_debug_only.zip`（v100）。
- ユーザー提供 `SERA_Guard.bbmodel` から `Guard` のゼロ秒ポーズを既存モデルに追加。22ボーンUUID完全一致。元モデル・全既存アニメ・テクスチャを保持。
- `main.gd`：静止ホールド0.32秒（最大軌跡18px）でガード開始、指を離すと終了。ガード中は移動・ブースト・回避・格闘・ジャンプを抑制。ガード中の敵弾・範囲攻撃は被弾リアクション／ノックバック／被弾フラッシュを行わず既存命中音のみ再生。PCのGキーでもガードテスト可。
- `sera_rig.gd`：ガード姿勢の開始・終了・補間、移動／攻撃系クリップへの遷移制限。
- 既存のシールド数値・消費量・ガード崩れ・バッシュ機能はv100に未実装。今回新規設計しない。
- 変更：`scripts/main.gd`、`scripts/sera_rig.gd`、`assets/sera_source.json`、`assets/sera_data.gd`、`project.godot`、`DEVELOPMENT.md`。
- 追加：`blockbench/SERA_Guard_user_input.bbmodel`、`blockbench/SERA_v101_guard_integrated.bbmodel`、`README_v101_ja.md`、`tools/v101_guard_self_check.py`。
- 検証：モデルの構造・既存機能との差分・ZIP-CRC・静的動作条件のセルフチェック。Godot実行／Android実機テストは実施した場合のみ別途記録。

---

# セラ v100 — ジャンプを通常操作から除外（2026-11-06）

**基準版**：v99 `sera_portrait_godot_melee_v99_landing_hold_06s.zip`。

## 変更点

- 上フリックのジャンプ発動を**既定で無効化**。短い上フリック／走行・ブースト中の末尾上フリックとも、ジャンプにはなりません。
- 左右フリックのステップ、下フリックの4mバックステップ、通常移動・ブースト、ガード相当の既存処理、格闘3段、敵4攻撃、被弾音、カメラ等を維持。
- ジャンプと空中制御・空中ステップ・空中格闘・0.6秒着地硬直の**コード、Blockbench原本、統合モデル・キーフレームは削除せず保管**。
- スマートフォンで必要時に動作確認できるよう、既存のデバッグパネルに **JUMP TEST** ボタンを追加しました。タップすると地上からジャンプします（離地時の水平速度80％継承などv99仕様を使用）。パネル内操作は通常のタップ攻撃・フリックと区別します。
- PC版デバッグでは引き続き **Jキー** でジャンプテストできます。
- 上フリックを復活させる場合、`scripts/main.gd` の `JUMP_TOUCH_INPUT_ENABLED` を `true` にすることでv99の入力経路を復旧できます（今後の正式採用は未決定）。

## 変更範囲

- `scripts/main.gd`：上フリック経路を既定OFFにし、明示的なデバッグジャンプ入口を追加。
- `scripts/enemy_debug_ui.gd`：既存の敵攻撃デバッグUIに小型のJUMP TESTボタンを追加。敵攻撃用ボタンは維持。
- `project.godot`：v100表記。
- `DEVELOPMENT.md`、`README_v100_ja.md`、`tools/v100_jump_debug_self_check.py`：開発履歴・検査。

**検証**：静的コード・モデル／音源のバイト一致、既存機能差分、ZIP CRC検査を実施。Godot本体／Android実機での操作・描画確認は未実施。

---

## v98（2026-11-06） ジャンプ80%慣性・上フリック50px・空中ステップ/格闘・30%空中姿勢制御

# セラ v98 — ジャンプ中の姿勢制御・空中ステップ・空中格闘（2026-11-06）

**基準**：`sera_portrait_godot_melee_v97_jump_inertia.zip`（v97）。

## 変更仕様

- ジャンプ初速の**水平方向への継承率65％→80％**。固定高度1.5m、通常飛行0.80秒は据え置き。
- 上フリックの必要距離**78px→50px**（720px仮想画面、速度500px/s以上、左右の混入制限42％は維持）。左右・下フリックの必要距離78pxは変更しません。
- 空中でも**左右ステップと4mバックステップ**が使用可能。既存のStep_L/Step_R/Backstepモーション・移動量・速度をそのまま使用します。
- 空中でも**既存の3連打格闘**が使用可能。従来の接近・斬撃・キャンセル・命中判定・音・ダメージ12/12/26はそのままです。
- 空中アクション中はそのアクションのモーションを優先し、高さを一時保持します。アクションが終了／中断すると、**ジャンプモーションの落下キーフレーム（0.20833～0.375秒）へ移り、現在の高度から重力で着地**します。上昇動作の再再生やY座標の瞬間移動を防止します。
- ジャンプ中の新しいドラッグでは、**通常RUN速度の30％（3.25×0.30＝0.975m/s）まで**の水平操作ベクトルを、離地時の慣性速度へ加算します。空中ではブースト倍率は適用せず、方向操作だけでポーズ／モーションは切り替えません。
- 空中ステップ・格闘中は慣性移動と空中姿勢制御を一時停止してアクションの固有移動を使用します。アクション後の落下では、過去の慣性を復活させず、30％の姿勢制御のみを受付けます。
- 2段ジャンプは不可。被弾中も落下継続し、被弾が終了した場合は落下ポーズに復帰します。試作環境はY=0地面、段差・足場にはまだ対応しません。

## 変更ファイル

- `scripts/main.gd`：ジャンプ判定距離、空中移動、空中のステップ／格闘解禁、動作終了後の落下遷移、被弾時の復帰を変更。
- `scripts/sera_rig.gd`：空中アクションの後、Jumpの下降区間へ切替。**モデル・アニメーションのキーフレーム・メッシュは変更なし。**
- `project.godot`：v98表記。
- `README_v98_ja.md`／`DEVELOPMENT.md`／`tools/v98_air_action_self_check.py`：仕様・検証を追加。

**維持**：敵4攻撃・デバッグUI、格闘3段のダメージ/音、敵弾被弾音、ブースト閾値、ステップ距離、カメラ追従・残像、既存モデル全データ。

**検証**：静的検査、モデル／音源同一性、差分／ZIP-CRC検査を実施。Godotのプロジェクト起動／Android実機確認は未実施。

---

# SERA v97 — 上フリック固定ジャンプ（2026-11-06）

- 基準ZIP：`sera_portrait_godot_melee_v96_player_bullet_hit_sound.zip`。
- 提供 `SERA_jumpmotion.bbmodel` の無名アニメーションを `Jump` として統合。0.375秒の全トラックを0.80秒の滞空に同期して再生。
- 上フリック（短時間、または長いドラッグの終端0.20秒）でジャンプ開始。通常ステップ判定やブースト125/110%閾値を変更しない。
- 固定高度1.50m、滞空0.80秒、離地時の水平速度65％継承、空中操作による方向変更なし。空中攻撃と重複ジャンプ抑制。
- 被弾しても飛行時間経過・落下を継続。ジャンプ用地面マークは床Y=0に維持。
- 修正：`scripts/main.gd`, `scripts/sera_rig.gd`, `assets/sera_source.json`, `assets/sera_data.gd`, `project.godot`, `DEVELOPMENT.md`。
- 追加：統合bbmodel、ユーザー原本bbmodel、README_v97_ja.md、検証スクリプト。その他v96ファイルのバイト列は維持。
- Pythonによる静的・算術・アセット一致・ZIP整合性チェック実施。Godot／Android実機未検証。

---

# SERA v96 — 自機の弾被弾音の変更（2026-11-06）

- 基準版：v95 `sera_portrait_godot_melee_v95_unified_melee_hit_sfx.zip`。
- 自機のAIM／LEAD弾被弾時の音のみユーザー提供「ロボットを殴る3.mp3」に差し替え。
- `assets/sera_player_bullet_hit_v96.wav` は48kHz／16bit／ステレオ。原本MP3も同梱。
- `scripts/main.gd` の弾被弾AudioStream参照を1行変更、音量-5dB・最大多重再生3を維持。
- SHOCK／ARC被弾音、3段格闘命中音、戦闘・移動・カメラ・UI・アニメーションに変更なし。
- 修正：`scripts/main.gd`, `project.godot`, `DEVELOPMENT.md`。追加：音源2点、`README_v96_ja.md`, `tools/v96_player_bullet_sfx_self_check.py`。
- 静的・音声・ZIP整合性検査を実施。Godot／Android実機未検証。

---

# SERA v95 — 格闘ヒット音統一（2026-11-06）

- 基準版：v94 `sera_portrait_godot_melee_v94_hit_sounds_by_attack.zip`。
- 1・2・3段目の命中音をユーザー提供「ロボットを強く殴る2.mp3」に統一。Godot向け48kHz/16bit/stereoの `assets/sera_melee_hit_all.wav` に変換、元MP3も保管。
- `_register_strike_hit` の命中判定・`strike_did_hit`・段別ダメージ12/12/26・段別ノード選択・最大同時再生数・音量-5dBは変更なし。
- 弾被弾音・敵の範囲攻撃被弾音、ブースト、ステップ、カメラ、敵AI、モーション等の変更なし。
- 変更：`scripts/main.gd`, `project.godot`, `DEVELOPMENT.md`。追加：音声2点、`README_v95_ja.md`, `tools/v95_melee_sfx_self_check.py`。
- 静的検査・ZIP整合性検査実施。Godot/Android実行は未実施。

---

# SERA v86 — 格闘3段コンボの段別ダメージ

- ベース：v85 `sera_portrait_godot_melee_v85_volume_particles.zip`。
- 1段目 `melee1`：12、2段目 `Melee2`：12、3段目 `Melee3`：26。全段命中で合計50。
- ダメージ処理とポップアップ表示に同じ `strike_damage` を使用。HPは0で下限固定、1段1命中・既存のリスポーン処理を維持。
- キャンセルポイント、先行入力、自動接近、命中判定、ヒットストップ、3D剣閃・粒子、カメラ、移動、敵AIなどの既存処理は変更しない。
- 機能変更対象：`scripts/main.gd`。表示版名：`project.godot`。検証用スクリプト：`tools/v86_combo_damage_self_check.py`。
- 旧 `tools/hit_self_check.py` はv14時代の固定20ダメージおよび旧カメラの検査を含むため、履歴資産としてそのまま維持。今回の仕様は新規v86検証で確認。
- GodotエディターおよびAndroid実機での実行・描画確認は未実施。

---

# SERA v85 — 剣閃立体化 + 周囲粒子（制作メソッド完全版）

## ベース／原則
- `sera_portrait_godot_melee_v84_authored_sword_fx.zip` から更新。
- ユーザー配置の `Swordeffect` 板の親ボーン、平行移動、角度、拡縮を**そのまま維持**。0.55m補正、カメラ正対、追尾位置補正は追加しない。
- v84で更新した `melee1` / `Melee2` / `Melee3` の板アニメーション、24fps基準のキャンセルポイントとコンボ入力は変更しない。

## 表示工程
1. 元のBlockbench板は非表示、トランスフォーム参照として使用。
2. 透過剣閃テクスチャ8フレームを、描画領域のみ残したカットアウトメッシュへ貼付。透明な四角形を描かない。
3. v35から残っていた各フレーム専用の立体形状データ（`slash_C_volume_geometry.json`）で、表裏に膨らむ薄い凸レンズ状メッシュを構成。主剣閃の白い輪郭と薄い立体層を重ねる。
4. 同じデータの発生候補点から、白（Cで赤へ切替）の微粒子をランダム生成。速度、方向、サイズ、寿命を独立に変え、徐々にフェード。最大32個。命中時の `hit_burst.gd` 火花とは別。
5. 各段の開始時にフレームと粒子をリセット。第3段は既存の0.210秒の描画遅延を維持。ヒットストップ中は粒子時間を進めない。
6. 自キャラクター前景描画と敵への重なり減光機能を以前のv35方式から復元。立体層と粒子に影は付けない。

## ファイル変更
- 変更: `scripts/sword_trail.gd`（v35の立体カットアウト＋粒子を復活してv84座標に統合）、`project.godot`（版名）、`DEVELOPMENT.md`（履歴）
- 追加: `README_v85_ja.md`, `tools/v85_sword_fx_self_check.py`, `blockbench/SERA_melee_combo_3_v85.bbmodel`（v84内容をそのまま複製、ボーン／アニメは不変）
- 既存の `assets/v35_cutout_frames`、`v35_cutout_tiles.json`、`slash_C_volume_geometry.json` を再使用。新規3D素材は生成せず、既にある各フレームのジオメトリを再適用するため表示内容はv35の表現に近い。
- v84の`assets/sword_fx_*_4x2_mobile.png`も削除せず維持するが、v85立体描画では透明領域の板状表示を防ぐためカットアウト用の個別PNGフレームを描画する。

## 確認範囲
- 静的検査は必要事項・参照先・元ファイル保持を対象とする。Godot 4.7.2エディター／Android実機の起動および描画品質は未確認。

---

# SERA v83 — 格闘3段コンボ（24fps基準キャンセル点）

- 基準：添付v82 `sera_portrait_godot_melee_v82_target_angle_camera_final.zip`。Godot 4.7.2安定版の公開状況とGDScript標準を確認。
- ユーザーの `セラ･格闘連打.bbmodel` から `melee1`、`Melee2`、`Melee3` の3アニメーションのみ取り込み。ほかのv82アニメーション（通常移動・ステップ左右・0.22s被弾等）とモデル形状は保持。
- 各段の「振り抜き終了+2フレーム（24fps）」をゲートに設定：1段目0.291667s、2段目0.291667s、3段目0.625s。3段目には次段なし。
- タップは1回分バッファし、ゲート到達で次段に遷移。未入力時はその段の末尾まで再生。剣命中・ヒットストップ・トレイルを段ごとにリセット。3段目の剣軌跡だけ原本の長いモーションに合わせて遅延。
- 既存の敵AI、移動、ブースト、ステップ、接近、カメラ、当たり判定方式（各段のアクティブ時間以外）は変更なし。
- 変更：`project.godot`、`scripts/main.gd`、`scripts/sera_rig.gd`、`scripts/sword_trail.gd`、`assets/sera_source.json`、`assets/sera_data.gd`、`DEVELOPMENT.md`。追加：`blockbench/SERA_melee_combo_3_v83.bbmodel`、`README_v83_ja.md`、`tools/v83_combo_self_check.py`。
- 検証：静的55件PASS、v82カメラテストは版名1件除き29/30 PASS、変更対象外差分検査。Godot・Android実機での実行・表示・入力検証は未実施。

---

# SERA v74 — ステップ最低速度8m/s

- 基準：v73 `sera_portrait_godot_melee_v73_outside_circle_boost.zip`。
- ステップ最低速度のみ変更：`STEP_CLOSE_SPEED` 6.0→8.0m/s。ステップ最高速度10.0m/sを維持。
- 敵キューブ表面との水平距離が2m以下で8m/s、5m以上で10m/s、その間は従来どおりsmoothstep補間（中心距離ではなく箱表面基準）。ステップ開始時の速度固定も維持。
- ステップ軌道・移動距離（2.0〜4.0m）・最大所要時間（0.4s）・HUD・走行/ブースト・既存戦闘/カメラ/敵AI等は変更なし。
- 変更：`scripts/main.gd`, `project.godot`, `DEVELOPMENT.md`。追加：`README_v74_ja.md`, `tools/v74_step_min_speed_self_check.py`。
- 検査：v73との差分、速度境界/滑らかな補間、移動距離/時間を静的・数値確認。Godot/Android実機は未検証。

---

# SERA v73 — 単一半透明円 / 円外ブースト / 外側二重矢印

- 基準：v72 `sera_portrait_godot_melee_v72_run_boost_ring.zip`。
- v72の外周直径はそのまま。円内全域でRUN（半径168pxでアナログ入力上限）、円の外側に出るとBOOST（x1.5）。境界点はRUN。
- v70の中心-指先の線＋先端円を復活。二重矢印は円の外側4方向に移動。中央円と分離帯は撤去。
- UIのシアン系RGBAを保ちつつ、モード切替で外縁・矢印が明るくなりRUN/BOOSTラベルも連動。
- 変更：`scripts/main.gd`, `scripts/touch_overlay.gd`, `project.godot`, `DEVELOPMENT.md`。v73説明文と静的検査を追加。
- 他のコード／モデル／戦闘／敵AI／被弾・ノックバック／画面グラデーションは保持。
- 検証：差分ハッシュ・入力境界条件・描画と既存処理の静的検査。Godot/Android実機は未検証。

---

# SERA v72 — 大型リングコントローラ / RUN と BOOST の2段階走行

- 基準版：v71 `sera_portrait_godot_melee_v71_vector_touch_controller.zip`。
- リング半径112→168px、透明帯との境界（半径62%）から走行ブースト、MOVE_SPEEDの1.5倍（MAX 4.875m/s）、中心へ戻すと即時RUN。走行のアナログ強度は内側62%で最大になるよう調整。
- UI：外周リングのアクティブ色、上部モードピル、および画面上のステータス行でモード可視化。v71の透明ギャップ/シアン系RGBA保持。
- 維持：タップ、フリック、ステップ、ダメージ/ノックバック、敵AI、カメラ、モデル・アニメーション、画面下グラデーション。
- 変更対象：scripts/main.gd, scripts/touch_overlay.gd, project.godot, DEVELOPMENT.md。README_v72_ja.md と検査スクリプトを追加。
- 検査：静的・差分検査。Godot/Android実行未検証。

---

# SERA v71 — コントローラのベクター描画

- 基準：v70 `sera_portrait_godot_melee_v70_damage_knockback_1_2m.zip`。
- 変更：`scripts/touch_overlay.gd` のドラッグ時ガイドだけを直接描画でリデザイン。幅広円環と四方向二重矢印、空白帯、中心円＋四方向矢印。既存の色・アルファ値を使用。
- 操作：元のタップ・ドラッグ・フリック・ステップ・攻撃を維持。ロックオン表示と下部操作エリアのグラデーションも維持。
- 検証：v71専用静的検査。GodotおよびAndroid実機での動作は未検証。
- 変更ファイル：`scripts/touch_overlay.gd`、`project.godot`、`README_v71_ja.md`、`DEVELOPMENT.md`、`tools/v71_controller_self_check.py`。

---

# SERA v70 — ノックバック距離・被弾モーション再生時間の調整

## 基準
- v69 `sera_portrait_godot_melee_v69_damage_knockback.zip` を直接の基準にしています。

## 調整内容
- 被弾ノックバック距離：0.80m → **1.20m**（最大値。衝突時は短縮）。
- 被弾モーション `Damageknock`：0.16667秒 → **0.22秒**。各キーフレーム時刻を同じ比率（約1.32倍）で伸ばし、ポーズ・補間の順番・骨の回転値は変更していません。
- ノックバック移動時間：**0.24秒のまま**。移動には二次ease-outと `CharacterBody3D.move_and_collide` を引き続き利用します。
- 入力ロックはモーションとノックバックの双方が完了するまで。今回も0.24秒で復帰する想定です（実際のフレーム刻みで前後）。
- 予兆0.65秒、射撃間隔2秒、弾速12m/s、カメラ・近接攻撃・移動・操作UIは維持します。
- プレイヤーHP・ガード崩れ・ダウンは未実装のままです。

## 修正対象
- `scripts/main.gd`：ノックバック距離の定数のみ（機能面）。
- `assets/sera_source.json`：`Damageknock` の時刻のみ。
- `assets/sera_data.gd`：APK用の組み込みデータを更新。
- `blockbench/*.bbmodel`：8モーション収録済み3ファイルの `Damageknock` を同様に更新。5モーションだけの旧モデルはそのまま保持。
- `project.godot`：表示版名v70に変更。
- `README_v70_ja.md`, `DEVELOPMENT.md`, `tools/v70_damage_knockback_self_check.py` を追加・更新。従来の `tools/v68_damage_self_check.py` の許容モーション時間に0.22秒を追加（検査内容は同等）。

## 検証
- v69との差分、骨・メッシュ・既存7モーションの完全一致、被弾モーションキーフレームの姿勢データ、組み込み用JSONの一致、移動・射撃コードの不変を静的に検査します。
- Godotエディターでの起動とAndroid実機検証は未実施です。

---

# SERA v69 — ダメージモーション短縮・ノックバック

## ベース
- v68 `sera_portrait_godot_melee_v68_damage_reaction.zip` を基準とし、v67までの射撃間隔2秒・弾速12m/sや操作・カメラ・攻撃等を維持します。
- ユーザー提供 `セラ･カラーエフェクト付き (4).bbmodel` 内の `Damageknock`（0.16667秒、once）を採用し、以前の `Damage_motion`（0.5秒）を置き換えます。
- v68の他の7モーション・モデル要素・階層・骨をそのまま保持します。

## 新しい被弾・ノックバック
- プレイヤーのカプセルに敵弾が命中したとき `Damageknock` を再生します。入射した弾の進行方向を信号で引き継ぎ、XZ水平面上で同じ方向へ押し出します（弾が飛んできた側とは反対方向）。
- ノックバック移動：最大0.80m／0.24秒、二次ease-outで徐々に減速。実際の移動量は対象の障害物との衝突状況で短くなることがあります。
- `CharacterBody3D.move_and_collide` による連続衝突判定を使います。壁／敵キューブのすり抜けや速度のフレームレート依存を防ぎます。
- 入力ロックは短いモーションとノックバックの両方が終了するまで継続。途中の攻撃・ステップを中断し、被弾中のフリック／タップ予約は破棄します。ドラッグを継続している場合は終了後に移動へ復帰。
- 被弾中の追加命中ではフラッシュのみ更新し、ノックバック距離や方向、モーションを再設定しません。
- HP、シールド、ガード崩れ、ダウンは今回追加しません。

## 変更ファイル
- `assets/sera_source.json`, `assets/sera_data.gd`（再埋め込み）、`scripts/sera_rig.gd`, `scripts/main.gd`, `scripts/enemy_shooter.gd`, `scripts/enemy_projectile.gd`, `project.godot`。
- v68の統合済み `.bbmodel` 2ファイルを更新。`blockbench/セラ_ダメージノックバック統合.bbmodel` も同梱。
- `README_v69_ja.md`, `DEVELOPMENT.md`, `tools/v69_damage_knockback_self_check.py`。
- 旧版テスト `tools/v68_damage_self_check.py` はv69で通るよう後方互換チェックに修正します。

## 検査
- 変更前後でオリジナル7モーション、骨・メッシュ・アウトライナーを厳密比較。
- Android向けデータの埋め込み一致、攻撃・移動の衝突処理、射撃パラメータ、変更差分、弾方向シグナルを静的検査。
- Godot本体実行／Android実機テストは未実施。実機でノックバックの体感値を確認してください。

---

# SERA v68 — 被弾モーション統合

## 基準
- v67 `sera_portrait_godot_melee_v67_enemy_shooter_2s_12ms.zip`。
- 提供されたBlockbench `セラ･カラーエフェクト付き (2).bbmodel` の追加クリップ `animation` （0.5秒、once）を `Damage_motion` として追加。

## 挙動
- 敵弾がプレイヤーのカプセルに命中した時だけ、提供された0.5秒のダメージアニメーションを再生。
- 再生中は移動・ステップ・攻撃開始を禁止。被弾中に始めた・中断されたフリックやタップは、終了後に予約発動しない。実行中の攻撃/ステップを中断し、ヒットストップや剣軌跡も終了。
- アニメーション終了で待機に復帰。ドラッグが継続中なら走行に復帰（指を離していたら待機）。
- 被弾中の追加命中では再生を最初からやり直さず、従来の赤いフラッシュのみ更新。
- プレイヤーHP、シールド値、ガード崩れ、ノックバック、ダウンは未実装。既存の敵HP・攻撃処理は維持。

## リソース
- `assets/sera_source.json` はv67のモデル・既存7モーションを維持し、今回の1モーションだけを追加。
- `assets/sera_data.gd` に統合モデルデータを再埋め込み。Android APKでJSONが利用不能でもモーションを利用可能。
- Blockbench編集用統合モデル：`blockbench/セラ_被弾モーション統合.bbmodel`（既存のステップモーションも含む）。

## 変更ファイル
- `scripts/main.gd`, `scripts/sera_rig.gd`, `assets/sera_source.json`, `assets/sera_data.gd`, `project.godot`。
- 既存のBlockbenchモデル（7クリップ）を更新、統合モデルの日本語名コピーを追加。
- `README_v68_ja.md`, `DEVELOPMENT.md`, `tools/v68_damage_self_check.py`。

## 確認
- 元モデルと今回のモデルで骨UUID22件・要素25件・アウトライナーが一致することを確認。
- 元のモデルの既存7モーションはそのまま維持。
- JSON/埋め込み一致、遷移と入力ガード、既存ファイル差分を静的に検査。
- Godot/Android実行は未実施。モーションの見え方は実機で確認が必要。

---

# SERA 開発履歴（基準版と追加機能）

## v67 — 敵射撃間隔2秒・弾速12m/s
- 基準: `sera_portrait_godot_melee_v66_enemy_shooter.zip`。
- 変更: 実際の弾発射から次の弾発射までを約2.0秒に固定。予兆0.65秒はこの2秒に含める（射撃後の待機1.35秒）。
- 変更: 初弾は開始約2.0秒後（最初の予兆開始は約1.35秒後）。
- 変更: 弾速を7.5m/s → 12.0m/sに変更。
- 変更ファイル: `scripts/enemy_shooter.gd`, `scripts/enemy_projectile.gd`, `project.godot`, `DEVELOPMENT.md`。
- 追加ファイル: `README_v67_ja.md`, `tools/v67_enemy_ai_self_check.py`。
- 維持: 照準固定、予兆0.65秒、直進弾、被弾時の赤点滅、敵HP0で射撃停止、カメラ、プレイヤー操作、攻撃、エフェクト等。
- 検証: 数値設定、インターバル算式、同一ファイル保持、ZIP差分、リソース参照の静的検査。Godot実行・Android実機検証は未実施。

## v66 — Enemy Ranged AI
- 基準: ユーザー提供 `sera_portrait_godot_melee_v65_recommended_gray_operation_gradient.zip`。
- 追加: 固定ターゲットからの低頻度単発弾（初回2.2秒、予兆0.65秒、待機4.5〜6.5秒、弾速7.5m/s）。
- 追加: 固定方向への射撃、射撃予兆の発光球、プレイヤー衝突検知、命中フラッシュ。
- 追加: 敵HPが0の場合は新規射撃停止。
- 変更: `scripts/main.gd`, `project.godot`。
- 新規: `scripts/enemy_shooter.gd`, `scripts/enemy_projectile.gd`, `README_v66_ja.md`, `tools/v66_enemy_ai_self_check.py`。
- 維持: v65までの操作、ロックオン、カメラ、近接攻撃、HP、剣エフェクト、操作領域。
- 未実装: プレイヤーHP・シールド・ガード・被弾モーション・吹き飛び等。命中時は表示のみ。
- 検証: ZIP差分、リソース参照、関数定義重複・インデントの静的点検、発射位置算定。Godot実行/Android実機未検証。

## v65（提供された基準版）
- 推奨グレーの操作領域と下端8%の均一色、上部へのグラデーション（原本README参照）。


## v75 — Selective low-cost motion blur (2026-11-06)
- Baseline: v74 step min 8m/s.
- Changes: `scripts/main.gd`, `scripts/sera_rig.gd`, `project.godot`; new `shaders/sera_motion_ghost.gdshader`, `shaders/selective_far_blur.gdshader`, `README_v75_ja.md`, `tools/v75_motion_blur_self_check.py`.
- Only step and outward-ring movement boost get blur: one animated mesh overlay for Sera, 3-tap ground pass masked by player distance (7-11m); scene objects in `motion_blur_far_environment` opt in.
- Preserved: input, movement and step speeds and paths, animation data, camera, targeting, attacks, enemy AI, damage and knockback, HUD.
- Performance approach: no history framebuffer, no extra Viewport, off-state extra passes disabled; static validation only, Godot/Android execution not available in this environment.


## v76
- Removed far/background motion blur after it felt excessive during movement.
- Replaced the single player ghost pass with three lightweight afterimage layers.
- Each afterimage uses a different alpha and offset, enabled only during step and boost movement.


## v77 — 時間差残像・スナップショット化
- 基準：v76 `sera_portrait_godot_melee_v76_player_triple_afterimage.zip`。
- v76の現在姿勢に追従する3重メッシュを撤去し、発生時刻の全身ポーズ・座標をワールド固定のMultiMeshに記録する方式へ変更。
- 0.055秒ごとに発生、0.22秒の寿命、二次の透明度減衰、最大3層。新規発生はステップ／ブースト中だけ、停止後は自然消滅。
- 各パーツの元メッシュを共有するGPU instancing、24パーツ×3インスタンスで処理。
- 背景ブラーなし。射撃、カメラ、入力、ステップ速度、被弾、ノックバック、モデルとモーションは変更なし。
- 変更：scripts/main.gd、scripts/sera_rig.gd、shaders/sera_motion_ghost.gdshader、project.godot、DEVELOPMENT.md。追加：README_v77_ja.md、tools/v77_temporal_afterimage_self_check.py。
- Godot本体とAndroid実機での動作・描画性能は未検証。


## v78 — ブースト残像フェード短縮（2026-11-06）
- 基準：v77 `sera_portrait_godot_melee_v77_temporal_afterimage.zip`。
- ステップの残像寿命0.22秒、初期不透明度34%、発生間隔0.055秒、二次減衰は維持。
- ブースト残像寿命を0.22秒から0.14秒へ短縮。初期不透明度28%、発生間隔0.055秒を維持。
- 発生時の残像種別ごとに寿命をスロットへ格納し、モード移行後も元の消滅時間でフェード。
- 変更：scripts/sera_rig.gd、project.godot、DEVELOPMENT.md。追加：README_v78_ja.md、tools/v78_boost_afterimage_self_check.py。
- 既存移動、カメラ、攻撃、敵AI、被弾、モデル、ブラー除外対象、3枚MultiMesh処理は維持。
- 静的・差分検査実施。Godot/Android実機実行は未検証。


## v79 — 格闘ブーストキャンセル時のカメラ追従修正
- 基準: v78
- 変更: scripts/main.gd, project.godot, README_v79_ja.md, tools/v79_camera_follow_self_check.py, DEVELOPMENT.md
- カメラの移動判定で格闘のBOOST/STRIKE状態が停止判定となりリセンタリングを開始していた点を修正。
- DASHだけでなく全ての格闘フェーズで移動追従を継続。ブースト移動では高速なヨー・ズーム補間を適用。
- 走行/ステップの従来レート、カメラの構図・視野制約・当たり判定・戦闘挙動、残像、敵AIは維持。
- 静的・数値検証のみ。Godot/Android動作確認は未実施。


## v80 - point-blank side-step camera correction
- Base: v79. Reverted v79's accelerated melee/boost camera-follow changes to the exact v78 camera behavior.
- Camera-specific changes in scripts/main.gd: snapshot near-step flag and starting yaw, cap yaw travel at +/-18 degrees for steps beginning <=1.0m from target cube surface, bypass forced screen-edge yaw during those steps. Standard full-frame zoom protection stays.
- Existing gameplay/motion/AI/assets unchanged. Runtime not verified.


## v81 - scope error repair for close-step camera flag
- Base: v80; only `scripts/main.gd` changes gameplay code.
- Root cause: `_physics_process` declared `close_step_camera_this_frame` locally, while `_process` referenced it.
- Fix: promote flag to a typed class member; assign it at the same physics-tick snapshot point; preserve camera yaw logic and all v80 behavior.
- Updated project title and added README_v81_ja.md and v81 scope regression test.
- No runtime validation claimed; source and archive static checks performed.


## v82: target-relative close step camera
- Baseline: v81 close-step camera scope fix.
- Removed v80 start-yaw +/-18 degree clamp; constrain target-centered camera/player bearing separation instead (+/-65 degrees), with 300 degrees/sec slew.
- Added 0.18s transition after point-blank step ends; new touch cancels transition.
- Left normal movement/boost, distant step, damage, AI, rendering, and movement untouched.
- Changes: scripts/main.gd, project.godot, README_v82_ja.md, DEVELOPMENT.md, tools/v82_close_step_camera_self_check.py.
- Runtime/Android device verification pending.

## v84 (2026-11-06) — Blockbench板基準の8フレーム剣閃
- 基準版: v83。ユーザー添付SERA_melee_combo_3.bbmodelのSwordeffectキーのみ反映。Damageknock、Melee2の体モーション、モデル形状を保持。
- 変更: sword_trail.gdを単一板＋4x2 UVアニメへ置換、sera_rig.gd旧0.55m前方補正撤去。白/赤モバイルシート新設。元のヒットエフェクトとカメラ等は維持。
- 変更ファイル/検査方法はREADME_v84_ja.md、tools/v84_sword_fx_self_check.pyを参照。Godot実行およびAndroid実機確認は未実施。

## v87（2026-11-06） — 下フリックのバックステップ／ブーストとステップの区別
- 基準：ユーザー添付 `sera_portrait_godot_melee_v86_combo_damage_12_12_26.zip`。
- ユーザー提供 `SERA_backstep.bbmodel` の `Backstep`（1ポーズ・18キーフレーム・時刻0）を、v86モデルの既存10クリップを保持して追加。編集可能な統合 `bbmodel` と原本コピーを同梱。
- 下方向のリリース・フリックでロックオン対象から2.0m後退、8〜10m/s、専用姿勢を再生。既存の側方ステップと同じ衝突判定、残像、ブレンドを利用。
- 分類を明確化：BOOST＝円外への長距離ドラッグ時の加速移動、STEP＝フリック高速回避、MELEE APPROACH＝タップ格闘時の自動接近（従来の `meleeboost` モーション）。内部の格闘接近状態・アニメーション呼び出しも`MELEE_APPROACH`系へ改称し、加速移動BOOSTとの混同を解消。
- 変更：`scripts/main.gd`, `scripts/sera_rig.gd`, `assets/sera_source.json`, `assets/sera_data.gd`, `project.godot`, `DEVELOPMENT.md`。追加：`blockbench/SERA_backstep_user_input.bbmodel`, `blockbench/SERA_v87_backstep_integrated.bbmodel`, `README_v87_ja.md`, `tools/v87_backstep_self_check.py`。
- 維持：v86の12/12/26コンボ、左右ステップ軌道、ブースト速度、視点制御、残像／エフェクト、敵AI／被弾／HP表示。
- 検証：JSON・埋め込み・キーフレーム、入力分岐、計算式／既存要素を静的検査。GodotおよびAndroidの実行テストは未実施。


## v88（2026-11-06） — バックステップ距離4m
- 基準版：v87。変更：`BACK_STEP_DISTANCE` を2.0mから4.0mへ。
- 既存8〜10m/sの速度を保持するため所要時間は0.40〜0.50秒。側方ステップの最大0.40秒制約は維持。
- HUD待機時の表示は左右ステップとバックステップの違いを明示。
- その他の入力・格闘・カメラ・モーション・アセット・AIは変更なし。検証範囲と制限は`README_v88_ja.md`に記載。


## v89 — Boost_front モーション実装（2026-11-06）
- 基準：v88。
- ユーザー提出 `SERA_backstep.bbmodel (1)` を正しい .bbmodel 拡張子に直して `SERA_boost_front_user_input.bbmodel` に保管。
- 新規 `Boost_front`（時刻0の21キーフレームの静止ポーズ）だけをv88の既存モデルに統合。従来の11クリップ・25要素・22グループは保持。
- 通常ドラッグ `run_front_original`、外周超ロングドラッグ `Boost_front`、フリックステップは従来どおり各専用モーション。
- ブースト倍率1.5、4mバックステップ、既存攻撃・残像・カメラ処理は保持。
- 修正：scripts/sera_rig.gd, scripts/main.gd, assets/sera_source.json, assets/sera_data.gd, blockbench/SERA_boost_front_user_input.bbmodel, blockbench/SERA_v89_boost_integrated.bbmodel, project.godot, README_v89_ja.md, tools/v87_backstep_self_check.py, tools/v89_boost_self_check.py, DEVELOPMENT.md。
- 静的検査で統合・旧機能を点検。Godot実行およびAndroid実機は未検証。


## v90（2026-11-06） — RUN/BOOST入力しきい値・スナップ・ヒステリシス
- 基準v89。通常走行の最大入力半径100%と、実指125%連続0.10秒のBOOST開始、110%未満のBOOST解除を分離。
- BOOST倍率1.0→1.5を0.15秒で加速・減速。リグの0.16秒ポーズブレンドとフリックステップは独立。
- RUN/BOOST UIに、外周超過時のみ125%地点の薄いガイド弧を表示。外周スナップは従来のノブの丸い位置制限を維持。
- v89モデル・AI・戦闘・カメラ・4mバックステップは変更なし。差分：scripts/main.gd、scripts/touch_overlay.gd、project.godot、README_v90_ja.md、tools/v90_boost_threshold_self_check.py、DEVELOPMENT.md。
- 静的検査実施。Godot/Android実機実行未検証。

## v91（2026-11-06） — 敵攻撃4種と選択用デバッグUI
- 基準：v90。初期選択AIM、AUTO ON（約2秒周期）を保持。
- 追加：AIM（固定自機狙い）、LEAD（警告開始時の速度から偏差位置を計算し固定）、SHOCK（全周・前進リング）、ARC（前方145°・地上円弧状範囲）。すべて予告後に攻撃。被弾は既存Damageknockへ接続。
- HUDの直下に「AIM / LEAD / SHOCK / ARC / FIRE / AUTO」バー。攻撃切替時は旧弾と旧範囲を消去。バー上のタッチをプレイヤー操作から隔離。
- 新しいエリア攻撃は軽量ImmediateMeshと水平距離・角度判定、パーティクルなし。衝撃波は前フレームからのリング拡大区間を判定し高速すり抜けを抑制。
- 変更：scripts/main.gd, scripts/enemy_shooter.gd, scripts/enemy_projectile.gd, project.godot, DEVELOPMENT.md。追加：scripts/enemy_area_attack.gd, scripts/enemy_debug_ui.gd, README_v91_ja.md, tools/v91_enemy_attacks_self_check.py。
- 維持：RUN/BOOST、左右/後方STEP、4mバックステップ、3段格闘(12/12/26)、モデル/モーション、カメラ、残像、従来の被弾処理。詳細はREADME_v91_ja.md。
- 静的・数値チェックのみ。Godot/Android実機検証未実施。

## v92（2026-11-06） — 被弾後のブースト入力復帰
- 基準：v91 `sera_portrait_godot_melee_v91_enemy_attack_debug.zip`。
- 不具合：被弾時にONとなるジェスチャー抑制フラグが、ダメージリアクション終了後も指を離すまで残るため、同じドラッグでブースト再発動できない。
- 対応：`_update_boost_gesture` のブースト禁止条件を `damage_reaction_active` に限定。被弾中は停止し、被弾終了後は同じ指のまま125%以上/0.10秒でブーストへ復帰。
- 維持：`gesture_suppressed_from_damage` は指離し時のステップ／タップ誤発動防止にのみ使用。v91の戦闘、敵4種、カメラ、モーション、ブースト／ステップ、ダメージ演出を維持。
- 変更：scripts/main.gd、project.godot、DEVELOPMENT.md。追加：README_v92_ja.md、tools/v92_boost_damage_regression.py。
- 検証：静的・数値検査、差分比較、ZIP整合性。Godot・Android実動作は未検証。


## v93（2026-11-06） — 敵・自機の金属ダメージ効果音
- v92を基準に、ユーザー提供 `金属叩き.mp3` を効果音の共通ソースに採用。
- WAV化した `assets/metal_damage_hit.wav` を敵への格闘ヒット音と自機への敵攻撃ヒット音へ設定。元MP3も同梱。
- 2つのAudioStreamPlayerで同時／連続ヒットを再生、原音を変えるピッチランダム化は撤廃。音量-5dB。
- 戦闘処理・被弾処理・操作・カメラ・モデル・既存アセットは維持。変更点と検証はREADME_v93_ja.md、tools/v93_audio_self_check.pyを参照。
- Godot/Android実機再生は未検証。


## v94（2026-11-06） — 直線弾／格闘段別のユーザー提供ダメージ音
- v93基準。敵の狙い弾・偏差弾が自機に命中した際、`sera_bullet_hit_short.wav` を再生。
- 自機の格闘1・2段目が敵へ命中した際、`sera_melee1_short.wav` を再生。3段目のみ `sera_melee2_long.wav` を再生。空振り時の音はなし。
- 衝撃波・円弧面攻撃はv93の `metal_damage_hit.wav` を維持。敵シューターの命中シグナルに攻撃インスタンス確定の `is_bullet` を伝搬。
- WAVはユーザー提供の48kHz/16bit/ステレオを無加工同梱し、-5dBで再生。既存機能・ダメージ数値・モーション・カメラ変更なし。
- 追加・変更ファイルと検証は `README_v94_ja.md`、`tools/v94_sfx_self_check.py` 参照。Godot・Android実機は未検証。


## v99 (2026-11-06)
- v98基準。Jumpのみに0.5s最終着地キーフレームを統合、空中0..0.375sと着地0.375..0.500sを分割。
- 接地後0.125sの着地移行、最終姿勢で0.60s硬直後に立ち上がり。入力ロック/被弾割り込み、空中ステップ格闘後の落下も対応。
- 変更ファイル・検証はREADME_v99_ja.md参照。

## 2026-11-06 — ガード中の弾被弾効果音

- v102を基準に、ガード中のAIM／LEAD弾命中だけを既存の `assets/sera_bullet_hit_short.wav` に切替。音源はユーザーが指定ファイルと同じと確認済み。
- `scripts/main.gd` に専用プレイヤーを追加（-5dB／多重再生3）。通常被弾、範囲攻撃、ガード反応抑止、その他のゲーム機能は維持。
- 検証：既存Pythonチェック3本、Godot headless import・短時間起動・命中音分岐テスト。Android実機の音声確認は未実施。

## v106（2026-11-07） — RUN 4方向アニメーション適用
- 基準：GitHub main v105。ユーザーが追加した `bbmodel/SERA_back.bbmodel` の前後左右4クリップを採用（前進は更新版）。
- 既存22グループ・25要素・他13クリップ・Jump英語名・Swordeffectモデル・音源・BGMは維持。モデルを丸ごと置き換えず、アニメーションだけを `assets/sera_source.json` へマージし、埋め込みと編集用モデルを同期。
- 画面基準移動ベクトルをターゲット基準のローカル方向へ投影し、RUN時だけ優勢な前後左右へ切替。近接する斜め方向の入力にはヒステリシスを適用し、RUN間で位相保持。全RUNに従来倍率1.5を適用。
- 変更：`scripts/sera_rig.gd`、`scripts/main.gd`、`assets/sera_source.json`、`assets/sera_data.gd`、`project.godot`、`tools/v102_guardfix_self_check.py`、`DEVELOPMENT.md`。追加：`blockbench/SERA_v106_four_way_run_integrated.bbmodel`、`README_v106_ja.md`、`tools/v106_four_way_run_self_check.py`。
- 可能な静的構造チェックのみ実行。Godotヘッドレス、Python実行、Android実機は未検証。詳細は `README_v106_ja.md`。

## v107（2026-11-07） — RUNモーション90度方向ずれ修正
- v106（GitHub main `d34f2a6ef3c6549b522f3f0a15797997dda8dc01`）を基準。実機で「左を正面として4方向モーションが再生される」と報告。
- 原因：提供RUN 4クリップの最上位 `Waist` の回転は、`Wait_motion` の約-20度に対し、前／後約+75度、右約0度、左約+177度で、全方向の軸が90度ずれていた。
- `scripts/sera_rig.gd` 内のRUN 4クリップだけを対象に `Waist` の回転と相対位置をワールドY軸基準-90度のQuaternionで補正。ブレンド前に適用し、180度オイラー姿勢を含む左右クリップも正しく補正。入力方向選択・プレイヤーの向き・通常の移動位置・カメラ・格闘・ブースト・ステップ・その他のモーションとモデルデータは変更しない。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`。追加：`README_v107_ja.md`、`tools/v107_run_facing_self_check.py`。
- JSONアニメーションの数値・補正後の4方向の軸向き・変更範囲をGitHubコネクタ経由で確認。Godot/Android実機の動作テストは未実施。

## v108（2026-11-07） — 4方向RUNの連続ポーズブレンド
- 基準：GitHub main v107（`65d8e874bf49f8d7c2192416d578564830956047`）。4方向走行の切替を滑らかにするため、前/後/右/左の離散的クリップ選択を廃止。
- ターゲット基準の移動入力から前後左右4方向の重みを計算し、1秒の同期した各RUNクリップを毎フレームQuaternion slerp＋位置/スケールlerpで合成。45度は2方向各50%、方向転換では重みを時定数0.12秒で指数平滑化。RUN中のクリップ切替による位相リセット/都度0.16秒スナップショットを廃止。
- v107腰ルートの-90度Quaternion補正は各RUNクリップへ合成前に適用。WAIT/BOOST/STEP/攻撃/Guardなどへの遷移は従来のポーズスナップショットを用いる。
- 変更：`scripts/sera_rig.gd`、`scripts/main.gd`（デバッグHUD表示のみ）、`project.godot`、`tools/v107_run_facing_self_check.py`、`DEVELOPMENT.md`。追加：`README_v108_ja.md`、`tools/v108_run_blend_self_check.py`。音声/カメラ/移動/当たり判定/アセットと元キーフレームは不変。
- Python/モデル参照/ブレンド重みの静的検査、差分の確認を実施。Godotランタイム/Android実機のモーション確認は未実施。

## v109（2026-11-07） — 方向転換時の軽い左右バンク
- 基準：GitHub `main` v108（`83eb19cec5dbc1e5b79e9bd04df1ea67927a86b0`）。4方向RUNの連続ブレンドを保ちながら、転換方向へ最大5度だけ視覚上の腰ルートを傾ける。
- v108で指数平滑化した移動方向の前フレームとの差から左右符号付き旋回速度を求める。7rad/sで最大傾斜とし、立ち上がり時定数0.06秒、方向確定後の復元時定数0.20秒で連続追従。直接180度反転して左右の旋回方向が定義できない場合は新規バンクを掛けず、移動方向ベクトルのゼロ付近も安全に処理する。
- `scripts/sera_rig.gd` のRUN 4クリップ合成後に限り、既存のv107ルートYaw補正の後で腰（Waist）ルートへ局所Z軸のQuaternionを左乗算する。ワールド位置、衝突、移動入力・カメラ、非RUNアニメには適用しない。状態遷移時は従来ポーズブレンドの中で自然に傾きを解消する。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`。追加：`README_v109_ja.md`、`tools/v109_run_turn_bank_self_check.py`。
- GitHubコネクタ経由でコードと変更範囲を静的点検。Godot/Android実機での動作確認は未実施。

## v110（2026-11-07） — RUN方向転換の最大傾斜角を15度へ
- 基準：GitHub main `fbf714088a3edf1e788ec0b1d71103d9b76ad8ee`（v109）。ユーザー指定によりRUN方向転換の最大バンク角 `RUN_TURN_MAX_LEAN_DEGREES` のみ5.0→15.0度へ変更。
- 旋回角速度からの換算・立ち上がり0.06秒・復元0.20秒、v108の連続4方向RUNブレンド、v107の腰ルート向き補正、戦闘/入力/カメラ/移動/当たり判定/アセットは変更しない。
- 変更：`scripts/sera_rig.gd`、`tools/v109_run_turn_bank_self_check.py`（現行角度への追従）、`project.godot`、`DEVELOPMENT.md`。追加：`README_v110_ja.md`、`tools/v110_run_max_lean_self_check.py`。
- GitHub上の差分・計算式の静的点検を実施。Godot/Android実機動作は未検証。

## v111（2026-11-07） — 前方RUN／後方後ずさり2モード＋段階的ターゲット追従
- v110（`48929713dc59a1454ae1199f7ce7d292c932770e`）基準。走行中の4方向同時ブレンドを廃止し、前方走り `run_front_original` と後退 `run_back` の2モードへ変更（左右モーションはモデルデータに保持）。前方200°、後方160°を名目判定とし、ヒステリシス95°／105°を導入。
- ルートWaistを前進では進行方向、後退では逆方向へ向け、最大450°/sで短い角度経路を追従し、腰位置の揺れも同角度で回転。前後歩行は同期位相・0.18秒ブレンド。Torso20%、Chest累積50%、Neck累積75%、Head累積100%までターゲット追従を増やし、関節ごとの回転上限で過度なねじれを抑制。関節補正角の境界反転は時定数0.10秒で平滑化。
- v107の前後ソース90°補正と、v109/v110の最大15°旋回バンクを維持。バンク軸は新たなルートの向きに追従。プレイヤー本体・移動速度・カメラ・衝突・攻撃・ガード・ブースト・ステップ・ジャンプ・モデル・BGM・SEは変更しない。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`、`tools/v108_run_blend_self_check.py`、`tools/v109_run_turn_bank_self_check.py`、`tools/v110_run_max_lean_self_check.py`。追加：`README_v111_ja.md`、`tools/v111_two_mode_run_self_check.py`。静的・数値検査はコネクタ経由、Godot/Android実機未検証。

## v112（2026-11-07） — 左後方のRUN範囲拡大と左右利き手切替
- 基準：GitHub `main` v111（`9f5e6e846b56c7c65a2a5a96e15dcbef5fdc55de`）。右利き設定の左側のみ前方RUN判定を20°拡張（中心100→120°、切替105→125°／復帰95→115°）。反対側は従来95/105°を維持。左利き設定時は右側だけ同じ20°拡張。
- `scripts/sera_rig.gd` に利き手別前方セクタ中心計算と既存±5°ヒステリシスを組み合わせ、前後2モーションの自然な切替を維持。プレイヤー実移動・STEP・BOOST・カメラ・ガード・格闘・アセットは変更しない。
- `scripts/main.gd` の上部HUDに `HAND: RIGHT/LEFT` ボタンを追加し、`ConfigFile` で `user://sera_settings.cfg` へ保存。次回起動時に復元、走行中でも変更可能。HUD内タッチは従来どおりプレイヤー操作として扱わない。
- 変更：`scripts/sera_rig.gd`、`scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`、`docs/SERA_INPUT_MOVEMENT_CAMERA.md`、`tools/v111_two_mode_run_self_check.py`。追加：`README_v112_ja.md`、`tools/v112_handed_run_mode_self_check.py`。
- コード構造・数値遷移を静的点検。Godot/Android実機での操作は未検証。

## 2026-11-07 — GitSync同期トリガーをGitHub Actionsへ追加（ゲームバージョン変更なし）
- `main` pushでntfyへ固定本文 `SERA_SYNC_MAIN` を送る `.github/workflows/sera-gitsync-notify.yml` を追加。 `workflow_dispatch` による手動試験も可能。リポジトリのコードは取得せず、Secretsの `SERA_NTFY_TOPIC` を利用。
- Secret未設定では送信せず通知ログだけ。トピックは24～64文字・英数字/ハイフン/下線に制限。通知本文にコミット・プライベートファイル名を含めず、サーバーへの送信成功のみを報告。
- `docs/GITSYNC_AUTO_SYNC_SETUP_JA.md` にntfy購読、Taskerの `MESSAGE_RECEIVED` → GitSync `INTENT_SYNC`、Godot稼働中の同期待機・旧アプリ起動同期OFF・E2E検証の手順を記載。
- Godot `project.godot` とコード・アセットは無変更。ゲームv112維持（Godot表示名「スキャンテスト」も維持）。Android側Tasker設定・GitHub Secret登録はユーザー操作が必要で、実機E2Eは未確認。
 
## v114（2026-11-07） — BOOSTERALLの4方向ブースト姿勢と連続補間
- 基準：GitHub main `f205c9f49cd1470ec1a2e931d8a456063a7d5f72`（v113）。`models/SERA_BOOSTER_all.bbmodel` から前／後／左／右の単一ポーズ計4クリップを原本キーそのままで取り込み、旧 `Boost_front` をユーザー版に更新。旧17→20クリップ。
- `scripts/sera_rig.gd` のBOOST描画だけ、進行方向に隣接する前後・左右の2姿勢を角度重みとQuaternion SLERP／位置・スケールLERPで合成。方向変化は最短角・時定数0.12秒で追従し、既存の状態遷移0.16秒を維持。
- `scripts/main.gd` の既存のターゲット相対入力は無変更で利用し、BOOSTのHUD表示を優勢クリップ名に更新。新統合モデル、埋め込みモデル、v114検査、v114 READMEを追加。過去の一部回帰テストの17クリップ／固定バージョン名前提だけ追従。
- 既存のRUN 2モード、頭部安定化、利き手判定、格闘、ガード、ステップ、ダメージ、ジャンプデバッグ、カメラ、当たり判定、速度、残像、BGM/SEと非BOOSTクリップ／元モデルを維持。
- GitHub上の原本一致、アニメーション数・キー時刻、旧データ保全、Base64バイト一致等を静的検証。Pythonテストコマンド、Godotエディター、Android実機の実行検証は未実施。

## v115（2026-11-07） — BOOST中のコントローラ操作点を境界線外側へ移動
- 基準：GitHub main `20fc714b305e0bde84dd1ce7447aaffbfe054882`（v114）。`scripts/touch_overlay.gd` の描画のみ修正し、RUN中は従来の半径100%（168px）で操作点を表示。
- BOOST確定中は方向に沿って操作点の中心を半径148%（248.64px）に表示し、操作点の半径29px全体が起動ガイド半径125%（210px）の外側に残るようにする。BOOST終了時はRUN位置へ戻す。
- 125%のガイド短弧はBOOST確定後も非表示にせず明るく太く描画。確定前に実際の指がRUN円を越えた場合は以前どおり薄いガイドを表示。
- BOOSTの入力判定125%・保持0.10秒・解除110%未満・加減速0.15秒・移動1.5倍は不変更。v114の4方向モーション補間、カメラ、残像、格闘、ガード、ステップ、音声、モデル・リソースに変更なし。
- 変更：`scripts/touch_overlay.gd`、`project.godot`、`DEVELOPMENT.md`、`docs/SERA_INPUT_MOVEMENT_CAMERA.md`。追加：`README_v115_ja.md`、`tools/v115_boost_controller_visual_self_check.py`。
- GitHub差分と描画用半径の静的計算を点検。GodotエディターとAndroid実機の描画・入力体感は未検証。

## v116（2026-11-08） — BOOST姿勢の応答高速化・RUN再生速度1.25倍
- 基準：GitHub main `126cc74e5b3fe823d929199a24d5f73e2727d6bb`（v115＋Android側モデル同期コミット）。同期済みの`models/`ファイルは変更せず継承。
- RUNモーションの`RUN_ANIMATION_SPEED`は既存1.5に1.25を乗じて**1.875**に更新。全RUN方向は共通の時刻`clip_time`を使用し、方向・前後走行切替・頭部スタビライズの構造は維持。移動速度は不変更。
- BOOSTの4方向姿勢追従の時定数を0.12→0.06秒に短縮。RUN/WAIT⇄BOOSTの遷移だけ`BOOST_STATE_BLEND_SECONDS=0.08`を採用（従来0.16秒）。その他の状態遷移は既定0.16秒、戦闘・ステップ等の既存専用遷移時間を維持。
- BOOSTを確定させる入力距離125%、0.10秒ホールド、解除110%未満、速度加減速0.15秒、移動倍率1.5を維持。モーションアセット、モデル、ガード・格闘・カメラ・残像・コントローラUIには変更なし。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`、`docs/SERA_INPUT_MOVEMENT_CAMERA.md`、既存テスト`v108`/`v114`/`v115`。新規：`README_v116_ja.md`、`tools/v116_animation_timing_self_check.py`。
- ソース構造・遷移対象・数値モデルの静的検証を実施。Pythonスクリプトの実行、Godot実行、Android実機での操作確認は未実施。


## v117 — 2026-11-08 Command Nexus blockout
- Added a two-button startup selector: TRAINING ROOM (existing scenes/main.tscn) and SERA COMMAND NEXUS (new static hangar).
- Added Blockbench editable simplified hangar blockout under blockbench/SERA_Command_Nexus_LowPoly.bbmodel.
- Added lightweight procedural hangar and reused existing Sera rig; terminal signs are static and noninteractive.
- Existing training combat scripts unchanged. Android/Godot runtime not tested; verify scene import, model appearance, and selector on device.

## v118 — 2026-11-08 startup selector layout correction
- Replaced hard-coded position and 600px width with CenterContainer and viewport-responsive width.
- Both buttons use direct scene change with error logging. Base scene loading still requires Android runtime verification.
- Training scene and combat untouched.

## v119 — 2026-11-08 起動メニュー・拠点読込の再修正
- 基準：main `9f15d273cebdcb197e2f2364aaf2704407fef731`（v118）。別ブランチ `fix/v119-nexus-startup-layout` で修正。
- 原因1：拠点 `scripts/command_nexus.gd` の `Environment.AMBIENT_COLOR` はGodot 4に存在せず、拠点シーンのスクリプト読込に失敗する。 `Environment.AMBIENT_SOURCE_COLOR` へ変更し、環境光色を有効化。
- 原因2：`project.godot` の `input_devices/pointing/emulate_mouse_from_touch=false` では通常のGodot GUI `Button` がAndroidタップに反応しない。起動メニュー表示中のみ変換をON、シーン終了で元に戻す。
- レイアウト：プログラムによる固定座標配置を廃止し、`scenes/launch_menu.tscn` のFull Rect＋MarginContainer＋CenterContainer＋VBoxContainerで画面中央に配置。幅は上限500px、画面に応じて縮小。
- 既存汎用検査の起動シーンパスを更新、v116の機能検査は後継版名でも有効に。新規 `tools/v119_command_nexus_self_check.py` と `README_v119_ja.md`。
- 訓練シーン・戦闘処理・モデル・アニメーション・レンダラー・表示解像度は変更なし。基地内設備の操作は未実装。
- 静的検査はGodot本体およびXperia 1 V実機でのタップ/描画確認を代替しない。

## v120（2026-11-08） — Command Nexus表示をBlockbench設備で再構築
- 基準：GitHub main `0341eb1dfe07f799a1df643ed79d305741f19dc3`（v119）。ユーザーのスクリーンショットで、セラが小さく屈み、ゲートが切れ、UIと設備デザインが参考画像と大幅に異なることを確認。
- v117/v119の `command_nexus.gd` ではBlockbenchモデルが未使用だった。6種類の独立したシンプルなBlockbenchモデル（ハンガー内装・整備台・上部リング・出撃ゲート・汎用端末・データ端末）を作成して、対応したGodot部品データへ埋め込み、色別MultiMeshで実際に配置する方式へ差し替え。
- 基地内のセラは既存 `SeraRig` のバインドポーズ（腕の角度のみ調整）にし、戦闘用Wait_motionを停止。戦闘シーンでは従来どおりモーションを使用。
- カメラ位置/視野角、ゲートサイズ/配置、端末位置を縦画面で見える位置に調整。5つの読み取り専用メニューパネルと軽量ベクターアイコンを追加。基地内メニューのタップ機能は未実装。
- `scripts/main.gd`、`scripts/sera_rig.gd`、既存モデル・音声・訓練シーン・起動2択・プロジェクト表示解像度・GL Compatibilityは変更なし。
- 新規 `tools/v120_command_nexus_self_check.py`、`README_v120_ja.md`。v119の検査は後継版対応に更新。Godot実行/Android実機テストは未実施。

## v121（2026-11-08） — Command Nexus のレイアウトと遠近調整
- 基準：main `5e0482ad6431eaed884ee8ad9e01fd7e93e6b5b0`（v120）。ユーザーの参考画像と実機スクリーンショットを再確認。
- 基地の左上にある `SERA SYSTEM / COMMAND NEXUS` 文字と横罫線を削除。表示領域を遮る不要なHUDを撤去。
- DATA ARCHIVEとDEPLOYMENTの見出しは画面高さの27.2%→20.5%へ上げる。TRAININGとSYSTEMは54.2%→50.5%へ調整。CUSTOMIZEは維持。
- 設備は前景（TRAINING・SYSTEM）、中景（セラ・整備台）、遠景（DATA ARCHIVE・DEPLOYMENT）の3段構成へ配置変更。前景をカメラへ近付け、中景を約0.55m、遠景を約0.7〜0.8m後方へ移動。出撃ゲートのスケールを0.70に調整。
- カメラを(0,3.8,7.4)、注視点を(0,2.5,-4.7)、FOVを56°へ変更。前景・中景・遠景のサイズ差を強調。モデルを変更せずGodot上の配置のみ変更。
- v120の静的検査を新バージョンに対応させ、`tools/v121_nexus_layout_self_check.py` と `README_v121_ja.md` を追加。既存の戦闘・起動2択・Blockbenchモデル・音声等には変更なし。Godot実行/Android実機の確認は未実施。

## v122（2026-11-08） — 手前コンソールの向きを斜めに変更
- 前景のTRAINING／SYSTEM共通コンソールのGodot配置角度のみ変更。左右±10.3°から±18.0°へ増加。
- 中景／遠景の配置、カメラ、HUD、Blockbench原本、メインゲーム・訓練ステージ、各種操作は変更なし。
- `tools/v122_nexus_console_angle_self_check.py` と `README_v122_ja.md`を追加し、v121検査のバージョン条件を後継版対応に更新。
- Android/Godot実行確認は未実施。実機表示の被りや角度は再確認が必要。

## v123（2026-11-08） — 段差のある基地と大型出撃ゲート
- 基準：GitHub main v122。ユーザー指示で、データアーカイブ/デプロイメントの3Dモデルと手前のメニュー表示の重なりを解消し、前景・高台・最奥ゲートの遠近構成を作成。
- 手前の共通端末2台をz=-0.65からz=+0.75へ、角度±18°から±34°へ変更。2台以外の端末モデル原本は変更なし。
- Blockbenchで`SERA_archive_mezzanine.bbmodel`を新規作成し、昇段する6段の階段・高台・支柱・手すりを追加。データアーカイブを(-4.00, 2.19, -8.95)に配置。
- DEPLOYMENTを(4.05,0.02,-10.48)へ移動、1.20倍かつ高さ1.25倍の追加伸長（全高約6.6m）。既存後壁がゲートを遮るため`SERA_hangar_shell.bbmodel`の奥壁を開口部つきに変更。埋め込み`assets/base_command_modules.gd`を原本から再生成。
- カメラを(0,4.10,10.20)、注視点(0,3.0,-5.5)、縦FOV63°に変更。DATA ARCHIVE/DEPLOYMENTのラベルを上側に、TRAINING/SYSTEMをさらに下側に置き、投影した3Dモデルを遮る領域から避ける。CUSTOMIZEも画面下部へ移動。
- 既存の戦闘・操作・セラモデル、起動2択、モーション、音源、マテリアル別MultiMeshと基地内UIの非操作仕様は維持。`README_v123_ja.md`と`tools/v123_nexus_terraced_depth_self_check.py`を追加し、v120〜v122の既存検査期待値も更新。
- 静的幾何/投影検査はGodot実行やXperia 1 Vでの描画実測を代替しません。Android実機は未確認。

## v124（2026-11-08） — ゲートの向きと奥からの漏光、前景コンソールの手前移動
- 基準：GitHub main v123。スマートフォン実機画像でゲートが正面向きのままになっており、奥から光が漏れる表現がない点、前景コンソールをもっとカメラへ近づけたい点を確認。
- DEPLOYMENTゲートを(4.00,0.02,-10.48)へ微調整し、ローカル+Z方向の開口が中央セラ(0,0,-4.75)を向く角度をatan2で計算（約-34.9°）。ゲート形状・高さ・Blockbench資産は維持。
- ゲートと同一座標・回転の新規軽量VFX：Unshaded+Emissionの青白いQuadMesh4枚（内部2・床2）、影なしOmniLight3D1基。ボリュームライト・フォグ・パーティクルなし。
- 手前TRAINING/SYSTEMコンソールをx=±1.95,z=1.30へ移動、角度を±34°→±36°に更新。
- 720×1280前提の投影範囲、既存メニューとの非重複を静的に確認。`tools/v124_gate_lightspill_self_check.py`と`README_v124_ja.md`を追加し、v121〜123既存回帰テストも現在の値に更新。
- 既存の戦闘/操作/起動2択/モデル・アニメーション原本/Blockbench原本/音声、他設備の配置、描画レンダラーは変更しない。Godot/Android実機の描画と性能は未検証。

## v125（2026-11-08） — 拠点メニューの文字廃止と高速カメラフォーカス
- 基準：GitHub main v124（47b140b164c98576e6c6ab9efae0f6df2d880daf）。拠点全景の5つの固定タグ／サブ説明を撤去し、施設やセラ本体の輪郭をカメラ投影に沿って暗く明滅するCanvasItemの選択枠へ変更。壁面の「S E R A」は3D環境装飾として維持。
- TRAINING/SYSTEM/CUSTOMIZE/DATA ARCHIVE/DEPLOYMENTの各設備に独立した目標カメラ位置・角度・FOVを設定。ワンタップで選択時、0.18秒 Cubic Ease Out で高速に接近し、選択枠を明るく固定。他対象の選択枠は非表示。フラッシュ、残像、パーティクルなし。
- 選択後は対象名＋機能を示す最小パネルと左上戻るUIを表示。戻る操作/Android戻る/Escでは0.18秒で全景に復帰。トレーニングは既存訓練シーンへのアクションを維持。他4項目は専用画面未実装を明示する仮パネル。
- Androidの画面タップをraw InputEventScreenTouchで処理し、戦闘操作の設定Input.emulate_mouse_from_touch=falseは変更しない。PCクリックにも対応。
- 変更：scripts/command_nexus.gd、project.godot、既存静的テストv120/v121/v123/v124。追加：scripts/nexus_selection_outline.gd、tools/v125_nexus_focus_self_check.py、README_v125_ja.md。モデル・演出光源・戦闘シーン・既存アニメーション・ブロックベンチ資産・音声等は変更なし。
- Godot CLI、Android実機での動作確認は行えていないため、拠点の投影タッチ領域・各寄り構図・戻る操作は実機で追加検証が必要。

## v126（2026-11-08） — モデル形状に沿った選択枠・明滅・右下戻るUI
- 基準：GitHub main v125。手動で指定していた5つの6点ハルを廃止。Blockbench端末・ゲートの実モデル部品とセラ展示用Rigの表示メッシュを投影し、2D形状の結合によって選択用外周を生成する。3D複製モデルは描画せず、CanvasItem輪郭線のみ追加（余分なドローコールなし）。
- 各輪郭は通常画面でキャッシュし、カメラの0.18秒Tween中と画面サイズ変更時にだけ再計算。ベースの簡易ポリゴンオフセット2pxと境界結合で部品の隙間・内側線を軽減。凸包近似のため厳密なピクセルシルエットではない。
- 暗い枠の点滅を透明度15〜62%、角速度3.6rad/秒に強化。選択対象のみ透明度98%・線幅3px固定表示。
- 接近画面の「戻る」UIを左上から画面右下に移し、接近メニューパネルを必要に応じて上方へ配置して重なりを防ぐ。通常の戻る操作とトレーニングへの遷移も継続。
- 変更：scripts/command_nexus.gd、scripts/nexus_selection_outline.gd、project.godot、v121/123/125静的検査、DEVELOPMENT.md。追加：README_v126_ja.md、tools/v126_nexus_model_outline_self_check.py。v125からの既存機能・v124ゲート演出、セラのモデルとBash/Guard_REACTIONモーション、他ブロックベンチ資産には変更なし。
- 静的な形状・コード検証のみ。GodotパーサーとAndroid実機での枠表示・タップ判定・パフォーマンスは未検証。

## v127（2026-11-08） — 手前コンソール割当の左右反転・ゲート外周のセラ遮蔽・線幅増加
- 基準：GitHub main v126（65a497bfff1219f4852af6c54148a58f9415151b）。手前の左端末をSYSTEM、右端末をTRAININGとし、選択領域の割当と接近カメラ位置を交換。端末の3D座標・Blockbench原本は変更なし。トレーニングの既存シーン遷移は右側端末から可能。
- 2D選択枠で遠景ゲートのラインがセラの手前に出ていたため、ゲートの閉じた外周線をセラの実モデルに基づく投影輪郭で折れ線クリッピング（Geometry2D.clip_polyline_with_polygon）。セラ部分のゲート枠だけを不可視化し、セラ形状に沿った余計なクリップ端辺を描かない。元の閉じたポリゴンは選択判定用に維持。
- 輪郭の線幅を通常時2.5→4.5px、選択時3→5px。点滅の透明度・周期、0.18秒カメラ移動、右下戻る、システム設定・デプロイメント・カスタマイズの仮メニューは維持。
- 変更：scripts/command_nexus.gd、scripts/nexus_selection_outline.gd、project.godot、旧静的テストv125/v126、DEVELOPMENT.md。追加：tools/v127_nexus_gate_occlusion_self_check.py、README_v127_ja.md。
- Bash/Guard_REACTIONを含むセラ本体、Blockbench元モデル、戦闘処理、効果音/BGM等には変更なし。静的ソース検査のみ。Godot/Android実機でのクリップ外周、選択判定、見え方は未検証。

## v128（2026-11-08） — 片側構図の専用カメラと半透明メニューパネル
- 基準：GitHub main v127（c5e1f5f1a4da7154bfbb392760675bf699c10326）。SYSTEMとDATA ARCHIVEはモデルを画面左、TRAININGは右、DEPLOYMENTは右斜めから小さめに見せる。CUSTOMIZEはセラの左前方から斜めに映し、全身・剣・台座が画面右に入るFOV67°のアングルへ変更。モデルの位置やサイズは不変更。
- 各接近画面の空間側に、ボーダー・角丸なし単色半透明サイバー青（α=0.52）で大きな四角い仮メニューパネルを追加。上部帯のみ不透明青（α=1.0）にして英語のメニュー名を表示。空欄が基本、TRAININGのみ既存シーンに入るボタンを維持。
- SYSTEM／DATA ARCHIVE右パネル、TRAINING／DEPLOYMENT／CUSTOMIZE左パネル。設備とパネルは画面投影上2～6%程度重ねるが、CUSTOMIZEのセラだけは実モデル由来輪郭（剣を含む）の最左端から16pxの隙間を確保し、パネル幅を動的制限。
- 全景からの0.18秒Cubic Ease Out、右下戻る、ゲート枠のセラ遮蔽、既存明滅輪郭、ブロックベンチ設備原本、Bash／Guard_REACTION、戦闘、BGM/SEに変更なし。
- 変更：scripts/command_nexus.gd、project.godot、既存v125/v126/v127静的検査、DEVELOPMENT.md。追加：README_v128_ja.md、tools/v128_nexus_focus_panel_self_check.py。
- 720×1280の静的投影計算とソース確認を実施。Godotでの実行・Android実機表示は未実施。

## v129（2026-11-08） — カメラ平行のセラ浮遊プレビュー・左右ドラッグ回転
- 基準：GitHub main v128（0651db6a79f770689e0cb912dea3705dd1c39dee）。既存のCUSTOMIZE背景、台座、建造物、カメラ構図、左半透明メニューをそのまま使用。接近後は展示用SeraRig本体だけをカメラに対して正面・平行な手前の位置へ移動して少し拡大表示する。モデルは複製せず、保存した元のローカル変換を戻る時に復元。
- SeraRigの残像ノード解放を誘発するreparentを避け、常に元のスタンドの子として維持したままcamera.global_transformを基準にワールド変換を再設定する。カメラ・背景・ステージには変更なし。
- モデルの全身・剣・盾の投影を360°/16サンプルで一度確認し、パネル右端+18pxから画面右97%、縦28〜76.5%の範囲内へ自動フィット。左右ドラッグ中もメニューと重なりにくい全周エンベロープを確保。
- CUSTOMIZE右側領域のAndroidタッチドラッグ／PC左ボタンドラッグでモデルのY軸回転のみ変更。カメラ固定、パネル・右下戻るUIのドラッグ誤作動なし。指離しで回転停止、再選択時は正面向きへ復帰。元の選択輪郭も追従。
- 変更：scripts/command_nexus.gd、project.godot、既存の静的検査v125〜v128、DEVELOPMENT.md。追加：README_v129_ja.md、tools/v129_customize_floating_preview_self_check.py。Bash／Guard_REACTION、Blockbench原本、戦闘シーンとBGM/SEは不変更。
- 静的ソース確認のみ。Godotのパーサー検証・Android端末実機のドラッグ判定やプレビュー見え方の確認は未実施。

## v130（2026-11-08） — カスタマイズ拡大の上限緩和とNEXUSpose読込
- 基準：GitHub main v129（d9572ec82c90f6d82a55f8101f6436d47fca683b）。背景・5機能のカメラ・半透明パネル・タッチ回転・右下戻るを維持し、CUSTOMIZEでセラのサイズのみ調整。
- v129のプレビュースケール倍率上限1.55/1.05が実サイズを抑制していたため撤去。プレビュー距離4.60→3.25、初期スケール0.80→1.40、縦フィット範囲画面15%〜86%に拡大。モデルの剣・盾を含む16方向で計算した全周外形を、左パネル右端+18px〜画面右97%の安全領域内にフィットするよう更新。
- NEXUSposeがユーザーのモデルに存在する場合、同期済みBlockbenchモデルJSONを探して展示用SeraRigの既存ZYX回転・アニメーションサンプラーで最初のポーズを適用。戦闘モーションへの変更なし。GitHub mainのモデルには現時点でNEXUSposeが見つからないため、未同期の場合は従来の中立展示姿勢を維持し、同期された後の次回起動時に自動検出。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、v125-v129の静的検査。新規：tools/v130_nexus_pose_enlarge_self_check.py、README_v130_ja.md。Bash／Guard_REACTION、Blockbench元モデル、既存背景・入力・BGM/SEなど変更なし。
- 静的なコード/資産整合性検査のみ。Godotでの構文解析・Android実機の拡大／姿勢適用確認は未実施。APKでのbbmodel同梱にも別途確認が必要。

## v131（2026-11-08） — Blockbenchのポーズ実名NEXUS_poseに対応
- ユーザー提供のBlockbench画面に表示されているポーズ名は「NEXUS_pose」（アンダースコアあり）。従来v130では「NEXUSpose」（アンダースコアなし）を完全一致検索していたため、この命名差が原因でポーズ適用できなかった。
- scripts/command_nexus.gd の検索対象を「NEXUS_pose、NEXUSpose」に変更し、検出した実名のままSeraRigのアニメーション登録・0秒サンプル・展示用適用を行う。後方互換のため旧名も受理。戦闘用SeraRigやBlockbenchモデルは変更しない。
- モデルの同期は別件。ユーザー端末の GAME/Git/models/SERA_BOOSTER_allテスト.bbmodel は2026-11-08 15:32更新・約334KB、GitHubのmain上の同ファイルは13:22最終更新・約328KB。端末側でポーズを確認できてもmain上のモデルには未反映。以前のgrep NEXUSposeは検索文字列が誤っていたため「なし」と判定されていた。
- 既存のカスタマイズ拡大、左右スワイプ回転、背景、パネル、戻る操作およびBash・Guard_REACTION等の戦闘資産は維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、v125〜v130ソース検査。新規：tools/v131_nexus_pose_name_self_check.py。ソース検査のみ。Godot構文/Android実機の検証は未実施。

## Termux auto-upload safe v2（2026-11-08） — GitHub先行時に安全な自動push
- ユーザー環境で従来の ~/sera_push.sh が「CONFLICT: upload cancelled」となり、NEXUS_pose入りの端末上のmodelがGitHubへ送信されなかったことへの再発防止。スクリプトは端末上に存在しGitHubへは保存されていなかったため、tools/termux/ に安全なv2の正式ソースとインストーラを追加。
- 共有ディレクトリGAME/Gitの前回成功時のファイルSHA256＋メタデータをTermuxに保存し、それ以降に実際に追加・更新したファイルのみを列挙。GitHubの最新mainをクローンして該当ファイルだけを反映し、他の変更を上書きしない。削除自動化は引き続き対象外。
- 同一ファイルが端末とGitHubの両方で編集され内容が異なる場合は安全停止。それ以外のGitHub先行は最新main上に変更を適用。push中の他者更新は3回まで再取得し、force pushは使用しない。
- 新しいTermuxコミットは固定の安全なauthor識別子を使用し、以前起きたAuthor identity unknownを回避。inotify監視がAndroidで保存イベントを取り逃しても最大120秒ごとに内容変化を確認（無変更時は通信しない）。
- fl​​ockによる多重起動防止・端末への上書きインストール前の時刻付きバックアップ・アップロード失敗状態表示を追加。初回は安全のため既存ファイルを送らずハッシュ基準点のみ作成する。
- 追加：tools/termux/sera_push_safe.py、sera_push_launcher.sh、sera_watch_safe.sh、install_safe_sync.sh、test_safe_sync.py、docs/TERMUX_SAFE_AUTO_UPLOAD_JA.md。既存のGodotコード・Blockbench素材・プロジェクト名・戦闘モーションは変更しない。
- 本環境からAndroid端末の ~/sera_push.sh / ~/sera_watch.sh を直接編集できない。Termuxにインストールコマンドを手動で実行する必要があり、それまでは従来の監視設定のまま。Python構文やAndroid/Termux実機の動作は未検証。オフライン疑似Gitリポジトリ検査を同梱。

## Termux private repo installer fix（2026-11-08） — raw URL 404対応
- 16:35ごろ端末の導入時にcurl HTTP 404と「install_sera_safe_sync.sh: No such file or directory」が発生。GitHub shejklgaia-png/- はPrivateであり、未認証のraw.githubusercontent.comへ直接アクセスするとファイルが存在しても404となる。以前の導入コマンドが誤っていた。既存のTermux監視は旧版のままで、モデル・プロジェクトデータの破損は確認されていない。
- tools/termux/install_safe_sync.shは公開raw URLを使わず、認証済みgit cloneで取得したtools/termuxディレクトリ内のスクリプトを直接インストールする方式に修正。対象ファイル不在では旧設定を触らず停止し、従来どおり時刻付きバックアップ・構文検査・監視再起動を行う。
- docs/TERMUX_SAFE_AUTO_UPLOAD_JA.md をgit clone（Private認証対応）→ローカルインストールに修正。tools/termux/test_safe_sync.pyで未認証rawへの依存再混入を検出する検査を追加。
- GitHub側の修正のみ。端末は修正後にユーザーのTermuxで実行する必要がある。Android実機でのインストール検証は未実施。

## v132（2026-11-08） — CUSTOMIZE表示の正面拡大とDEPLOYMENTゲート遮蔽解消
- 基準：GitHub main 8a3c0e55e1e8c0d17ca715fd8355b0ebae65e682（v131表示＋NEXUS_pose同期＋Termux安全同期）。ユーザー実機画像でCUSTOMIZEのセラが小さく、DEPLOYMENTは輪郭しか表示されない症状を確認。
- DEPLOYMENT旧カメラx=8.00mは、格納庫の右壁（x=7.15〜7.75m）の外側にあり、壁がゲート本体を遮っていた。カメラを右壁・外周リブ内側のx=6.20mへ移動し、視線x=1.80m／FOV76°でゲートを左メニューの右側に映す。壁・ゲート本体・材質・ギミックは変更しない。
- CUSTOMIZEの従来の360°最大シルエットでの初期フィットを、正面姿勢の外形基準に変更。画面幅の39%を目標にし、既存の左メニュー幅に近づける。左右ドラッグでは元の拡大倍率を維持しつつ、盾や剣が左右に広がり安全領域を超える角度だけ一時的に縮小・再センタリングする。左メニューパネルとの18pxの余白、右端97%以内、縦15〜86%以内を目標とする。
- NEXUS_pose読込、同一展示Rigの再利用、元の背景／展示台、5機能選択、左右ドラッグ、右下戻る、訓練シーン遷移、戦闘シーン、Blockbench元データ、BGM／SEは維持。
- 変更：scripts/command_nexus.gd、project.godot、旧検査v125〜v131、DEVELOPMENT.md。追加：README_v132_ja.md、tools/v132_nexus_visibility_self_check.py。
- コード・ジオメトリの静的確認のみ。Godotの実行／パーサー、Xperia 1 Vでの表示・タッチ挙動は未検証。実機ではセラ正面サイズ、左右90°回転時の盾／剣クリップ、ゲートの3D表示およびメニュー重複を確認すること。

## v133（2026-11-08） — 施設選択枠のタップ即時点灯・戻る時の即時解除
- 基準：GitHub main `29ab854b2ec8f28fd9ee49b2f4e8291de72edf0e`（端末側の最新自動同期を含む）。対象：Command Nexusの選択輪郭の表示タイミング。
- 設備タップ／PCクリックを受けた `_select_target` の中で、カメラの0.18秒Tweenを開始する前に `active_target` を設定し、選択対象だけの輪郭再投影・`queue_redraw` を即時に行う。選択枠はカメラ到着を待たない。
- 右下の戻るUI、Android戻る、Escの `_return_to_overview` では、全景への移動を開始する前に `active_target` を空にして `queue_redraw` する。0.18秒後の全景到着時に解除する旧処理を廃止。
- 5種類の選択対象、v132の拡大／カメラ構図、NEXUS_pose、カメラ移動時間とイージング、通常の明滅枠、タッチ操作、Blockbenchモデル、戦闘や音声などは維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、関連検査v125〜v132。追加：README_v133_ja.md、tools/v133_nexus_selection_timing_self_check.py。
- 入力ハンドラ内の処理順序と既存参照の静的検証のみ。Godot／Android実機の描画タイミングは未検証。

## v134（2026-11-08） — 拡大セラの輪郭線を放射状シアングラデーションに置換
- 基準：GitHub main `019ec1ebc54162437a921f29f1767d544d4a9a9c`（v133＋端末自動同期）。CUSTOMIZEの拡大プレビュー中だけ、2Dの強調輪郭を非表示にする。通常のガレージ一覧にあるセラ選択枠と、他4設備の輪郭は維持する。
- カメラ子ノードの単一QuadMeshに、既存輪郭線のRGB(0.35, 0.85, 0.98)を用いたunshaded・alpha透明Spatial Shaderを適用し、セラの背後1.80mに放射状の淡い発光グラデーションを表示。画面幅60%、高さ56%程度を中心へフェードさせ、3D背景を隠さない。GPUパーティクルや外部画像は使用しない。
- セラ拡大が完了したタイミングでグラデーションの表示・輪郭非表示に切り替える。ドラッグ回転と画面サイズ変更でセラ実投影の中心を再計算して追随。戻る入力ではグラデーションを即非表示、全景到着後に通常輪郭描画を復元。v133の選択／戻る即時反応と0.18秒Tweenを保持。
- 変更：scripts/command_nexus.gd、scripts/nexus_selection_outline.gd、project.godot、DEVELOPMENT.md、旧静的検査v125〜v133。追加：shaders/nexus_customize_radial_glow.gdshader、tools/v134_customize_radial_glow_self_check.py、README_v134_ja.md。
- Godot 4.7.2安定版のQuadMesh・Spatial Shader文法を参照。コード・ファイル・状態遷移の静的確認のみで、Godotパーサ／Android描画・透過ソート・負荷測定は未実施。

## v135（2026-11-08） — CUSTOMIZE背景グラデーションの胴体中心を高濃度単色化
- 基準：GitHub main `b35780a31358d507e4c23079f247e0668e18d6fa`（v134）。ユーザー実機画像でセラ背後の放射グラデーションが薄く見えるため、中心を約胴体幅の均一なシアン色に強化し、外周の滑らかなフェードを維持する。
- 既存`shaders/nexus_customize_radial_glow.gdshader`の1枚のQuadMesh／GL Compatibility用Spatial Shaderのみを変更。中心`core_radius=0.24`、不透明度`core_opacity=0.72`、境界±0.03にし、`outer_radius=0.95`へ`outer_opacity=0.30`を滑らかに減衰させる。色RGB(0.35,0.85,0.98)とセラ背後表示位置、発光板のサイズはそのまま。
- CUSTOMIZE拡大中の輪郭非表示・回転追従、戻る時の切り替え、他の端末・戦闘・NEXUS_pose・カメラ・モデル・入力・BGM／SEには変更なし。
- 変更：シェーダー、版名、v125〜v134検査の版名とv134のシェーダー検査、DEVELOPMENT.md。追加：tools/v135_customize_glow_core_self_check.py、README_v135_ja.md。
- シェーダーの不透明度プロファイルと変更範囲を静的検証。Godotパーサ／Android端末の実描画は未検証。

## v136（2026-11-08） — CUSTOMIZEグラデーションの広域化・段差解消・胴体基準化
- 基準：GitHub main `f448aa980c8945b689cb53b76203aa36678d48b4`（v135）。端末スクリーンショットでは発光円が小さく、中心と外周の2系統の不透明度カーブをmaxで合成する設計が境界の段差を生んでいた。加えて剣を含むモデル外接矩形の中央を光の中心としていたため、胴体から左右へずれていた。
- 新シェーダーは中心半径0.34まで不透明度0.91で均一、そこから外周半径1.0まで1-smoothstepにより連続減衰（指数1.15）。従来の2曲線maxを廃止。
- QuadMeshの投影幅を画面の70%、高さ46%（720x1280では約504x589px）に設定。Chest/Torso/Waistのボーン投影平均を光の中心とし、剣・盾の向きによる偏心を解消する。背後1.80m、メニュー・カメラ・回転追従、CUSTOMIZE拡大中の輪郭非表示は維持。
- 独立した画像シミュレーションで、セラを表示しない720x1280の光分布4案を比較した後、元のスクリーンショットにセラの概略マスクを残した参考合成3案を確認。選択案の滑らかさ・広がりを目視および数値で確認した。**Godotの実描画やAndroid実機確認ではない**。
- 修正：scripts/command_nexus.gd、shaders/nexus_customize_radial_glow.gdshader、project.godot、DEVELOPMENT.md、旧検査v125〜v135。追加：README_v136_ja.md、tools/v136_customize_glow_visual_self_check.py。戦闘・モデル・音声・既存4施設は変更なし。

## v137（2026-11-08） — CUSTOMIZE静止グリッド背景・定点回転・広域ドラッグ
- 基準：GitHub main `1ddf7e99d3629479b6794474bf9c2ee280bfd585`（v136）。セラ拡大時に初期の拡大位置・倍率を確定し、ドラッグ中はY軸姿勢だけを変更。従来の回転方向ごとのスケール制限／位置補正、およびグラデーション再計算をドラッグ経路から外した。剣が横方向に広がると画面外へ一部出る可能性はあるが、定位置回転を優先。
- グラデーションは拡大時の胸・胴・腰ボーン平均位置に1度だけ固定し、回転中は背景Quadの位置・サイズ・UVやグリッドピッチを再設定しない。端末画面のサイズ変更時は確定済み正規化位置を用いた再描画のみ。背景自体はカメラの子として固定。
- shaderに暗いサイバー青（RGB 0.025,0.083,0.160）と細い青系グリッドを追加。中心へ柔らかいシアンの照りを混合し、線はfwidthでアンチエイリアス。背景と線に同一のsmoothstep放射アルファを適用し、縁ではどちらも透明。画像・Particle追加なし。
- グリッド1マスはプレビュー確定時のHead_Meshの投影幅の1/2を目安として算出し、シェーダーのgrid_cellsパラメータに設定。head_mesh未検出時のみビューポート高さ3%にフォールバック。回転時はグリッド固定。
- 操作開始／移動中の有効範囲は画面全体から左メニューパネルと右下戻るボタンだけを除外（従来の20〜80%縦制限や左側以外の余白制限を廃止）。戻るはクリック／タップ直後に従来どおり処理。
- 変更：scripts/command_nexus.gd、shaders/nexus_customize_radial_glow.gdshader、project.godot、DEVELOPMENT.md、既存静的検査の版名および旧操作仕様チェック。追加：README_v137_ja.md、tools/v137_customize_fixed_grid_self_check.py。ほかの施設・モデル・NEXUS_pose・戦闘・SE/BGMは変更なし。Godot/Android描画・入力は未検証。

## v138（2026-11-08） — CUSTOMIZEの3区画レイアウト
- 基準：GitHub main `48c3e428300c0ea0f2c33d1b5e0ca443813d91d2`（v137）。CUSTOMIZE拡大画面だけを、左上のセラ表示、左下の正方形メニュー、右端の縦長メニューの3区画へ変更。他4施設は従来のレイアウトを維持。
- HUD基準720×1280では、左下メニューをx=25〜338、y≈794〜1107pxの313px四方とし、右縦長メニューをx≈378〜695、y≈173〜1107px（約317×934px）とする。右下戻るボタンは右メニューの下に独立。左上セラ表示領域はx≈25〜338、y≈128〜691px。実際の寸法は画面比率に応じて相対計算。
- 既存のCUSTOMIZE用`focus_panel`を左下へ移し、右端に新たな`CustomizeTallRightMenu`と装飾用ヘッダーを追加。新たな設定項目は未定のため、右メニューは空のプレースホルダーとする。既存CUSTOMIZEの見出しは左下で維持。
- セラの正面初期フィットおよび固定回転の領域を左上に移し、胴体ボーン基準のグラデーション位置をその範囲内に修正。発光板は左上の表示領域に収まるよう画面幅46%×高さ42%へ変更。暗いサイバー青、頭部幅の半分程度のグリッド、回転に追従しない背景の仕様は維持。
- ドラッグ操作は両メニューと戻るボタン上を無効とし、残りの領域ではv137と同様に回転可能。戻るで右メニューを即時非表示にする。v137の0.18秒カメラ移動、NEXUS_pose、既存操作・戦闘・音声・モデルを変更しない。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、関連静的検査のバージョンおよび旧配置期待値。追加：README_v138_ja.md、tools/v138_customization_layout_self_check.py。静的・座標検査のみ、Godot/Androidの実描画は未検証。

## v139（2026-11-08） — 展示用セラの滑らかな拡大・左上への移動と下寄せ
- 基準：GitHub main `ac736335fc7a0f743ea25016cf96e6bd796a0d44`（v138）。CAMERA焦点移動0.18秒の終了後、展示台にいる同一SeraRigを左上の拡大プレビュー位置まで0.46秒のCubic EASE_IN_OUT Tweenで補間。原始展示世界変換から最終のカメラ相対世界変換へTransform3D.interpolate_withを使い、複製モデルや新シーンは生成しない。
- 初期フレームでは目的地姿勢でフィットおよび固定背景グリッド位置を計算したのち、モデルだけ展示位置に戻してTween開始。途中は再フィット・再中心合わせ・再描画用幾何計算を行わず、終了時に目標姿勢を確定してシルエットを再取得。拡大中はin_transitionで入力を一時停止し、戻る際はTweenをkill可能。
- 左上のセラ初期表示幅の目標を画面幅39.0%→43.5%、左上区画の上限を左右のメニューに干渉しない範囲で横幅97%まで使う。表示領域の下端を画面高54%→61.5%（左下正方形メニュー上端から15px程度上）へ延ばし、描画外形の最下点が追加で約10px上になるようフィットと安全領域調整を下端揃えに変更。720×1280換算で左下メニューとの距離は約25px。
- 回転中の展示モデルの固定位置・倍率、背景の非追従、グリッドの色と大きさ、左下正方形メニュー、右縦長メニュー、戻る、ほか4設備、NEXUS_pose、戦闘と音声は維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧ソース検査の版名と領域期待値。追加：README_v139_ja.md、tools/v139_customize_entrance_self_check.py。ソース順序・座標計算・補間数学のみ静的検証。Godot／Android実機によるTweenの描画確認は未検証。

## v140（2026-11-08） — 展示セラの高速移動と戻るボタンでの滑らかな格納
- 基準：GitHub main `1de7c4a09ce807e4c62bc587b82393512257f8e2`（v139）。CUSTOMIZEへの移動・拡大Tweenを0.46秒から0.28秒へ高速化。Cubic Ease In Outを維持し、急なスケール変化・瞬間移動を防ぐ。カメラの0.18秒遷移は従来どおり。
- 右下UI戻る（Android戻る／Escも同一経路）では、現在のセラの全世界Transformから展示台上の正規ローカルTransform（`sera_display_stand.global_transform * sera_original_transform`）まで0.28秒の逆補間Tweenで収納。セラが格納された後、既存の0.18秒カメラ帰還を開始する。これにより戻る入力時の即時座標リセットを廃止。
- 同一SeraRig・既存Transform3D.interpolate_with・既存Tween変数を再利用。戻る入力直後に選択枠を解除、メニューパネル/戻るボタンを非表示、`in_transition`中は別操作を受け付けない。固定のグラデーション／グリッドは移動中も追従せず、格納完了後に非表示となる。Tween終了時に`_restore_customization_preview`で表示元へ正規復帰。
- 他4設備は従来どおりカメラ帰還のみ。v139の左上レイアウト、メニュー、回転、NEXUS_pose、Blockbenchデータ、戦闘・BGM/SEは変更なし。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、既存v125〜v139静的検査のバージョンおよび所要時間期待値。追加：README_v140_ja.md、tools/v140_customize_retraction_self_check.py。
- ソース順序・関数連結・移動時間の静的確認のみ。Godot起動／Android実機でのアニメーション品質・操作・描画は未検証。

## v141（2026-11-08） — CUSTOMIZE選択直後と戻る時のセラ／カメラ同時移動
- 基準：GitHub main `a119aa7339c9125823d1b084f28e4f8838f6281d`（v140）。CUSTOMIZEをタップした瞬間、カメラの最終姿勢を一時適用してセラの拡大位置と固定背景の初期位置を計算。実カメラ姿勢とセラ展示姿勢を元に戻してから、元のSeraRigの0.28秒Tweenとカメラ0.18秒Tweenを同じタップ入力処理内で開始。旧仕様の「0.18秒のカメラ移動完了後にセラの移動を開始する」遅延を撤廃。
- `_focus_arrived`ではCUSTOMIZE用セラTweenを重複開始せず、カメラが先に着いた場合はメニューを表示するが回転や戻るの入力ロックを保持し、モデルの0.28秒Tweenが終わってから解除する。ほか4設備は従来の動作。
- CUSTOMIZEのUI戻る・Android戻る・Escでは、元展示台への格納Tween0.28秒とカメラ帰還Tween0.18秒を同一イベントで開始。カメラが先に着いた時は復帰確定を待ち、モデル格納が終わったら背景を消して全景状態を確定する。選択枠と両メニューの即時解除は維持。
- レイアウト（左上セラ・左下四角メニュー・右縦メニュー）、表示倍率、固定サイバー青グリッド・放射グラデーション、初期NEXUS_pose、ドラッグ回転、戦闘・BGM・SEは変更なし。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧テストv125〜v140の版名と旧シーケンス期待値。追加：README_v141_ja.md、tools/v141_concurrent_nexus_motion_self_check.py。ソース構造・Tweenとカメラの開始順序など静的検証のみで、Godot/Android実行テストは未実施。

## v142（2026-11-08） — カメラ後退時にセラが画面外から展示台へ出現する現象を修正
- 基準：GitHub main `ba18f3c44c28d86c2990eabc782edad18e54e830`（v141）。カメラ帰還0.18秒、セラ格納0.28秒を同時開始した状態で、セラのワールド直線補間経路と移動カメラの視野が一致せず、セラが画面外から展示スペースへ再出現していた。
- 既存`Transform3D.interpolate_with`を世界座標間の補間ではなく、遷移開始時のカメラ座標と到達先カメラ座標の間の補間に変更。開始時と終了時に`Camera3D.global_transform.affine_inverse() * rig.global_transform`からカメラ相対Transformを求め、Tween各フレームでそのカメラ相対姿勢を補間し、動いている`cam.global_transform`に掛け戻す。投影位置が開始画面と終了画面の間を推移するようにし、移動中のカメラがセラを置き去りにする経路を解消。
- CUSTOMIZE選択時は全景カメラのglobal_transformを記録し、目的カメラでのフィット計算と併せて両端のカメラ相対Transformを確定。戻る時は現在のカメラ姿勢と元展示台の世界Transform、および全景カメラ姿勢から両端を計算。場面切替・モデル複製・新規素材なし。
- セラ0.28秒、カメラ0.18秒の同時開始、格納完了時のみ全景への状態確定、既存の右下戻る操作・選択枠即時解除・3区画メニュー・固定サイバー青グリッド・NEXUS_pose・戦闘・音声は維持する。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、関連テストv125〜v141の版名と旧世界座標補間期待値。追加：README_v142_ja.md、tools/v142_camera_relative_transfer_self_check.py。
- Godot 4.7公式Transform3D.affine_inverseおよびinterpolate_withを参照。コード構造・カメラ空間での補間投影の幾何検証を実施。Godot/Android端末での実描画と壁遮蔽は未検証。

## v143（2026-11-08） — 戻る操作時の背景即時消去と画面内直線移動
- 基準：GitHub main `e7a1018005bc88508f5b36ef17599ff4fd849686`（v142）。CUSTOMIZEの戻るボタン・Android戻る・Escを受けた同じイベント処理内で、放射グラデーションとグリッドの共通MeshInstance3D `customize_glow_quad.visible=false` を設定する。従来のセラ格納Tween完了時まで背景が残る仕様を廃止。選択線解除と両メニュー非表示は維持する。
- 入場と格納の経路を画面投影座標で直線化。ワールド／カメラローカル3D点の線形補間では遠近法によって表示上の経路が曲がるため、開始時と最終のカメラFOVで各モデル原点を正規化画面（NDC）へ投影し、その2点間をVector2.lerpで直線補間する。補間した奥行きと実際の移動中カメラFOVからカメラ空間のモデル位置を復元し、cam.global_transformでワールドへ変換する。回転とモデル倍率は従来のTransform3D.interpolate_withによる補間を維持する。
- 入場は従来のカメラ開始FOVと到達FOVを使用。戻るは現在のFOVと全景FOVを使用。セラ0.28秒、カメラ0.18秒のタップ同時開始、両完了後に状態確定、通常の展示状態、左上セラと3区画メニュー、固定サイバー青背景、NEXUS_pose、戦闘・音声は維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧テストの版名と相対補間式期待値。追加：README_v143_ja.md、tools/v143_straight_motion_self_check.py。
- 静的な関数順序／投影算術検証は実施。Godot実行・Androidでの実描画・3D遮蔽の検証は未実施。直線性はモデル原点の画面上経路を指し、剣先や四肢が全区間で画面内に収まることまでは保証しない。

## v144（2026-11-08） — 添付動画を踏まえた胴体基準の直線補間
- 基準：main `8485901bc0fb4c0219da1d0e7fae32160941423f`（v143）。添付MP4（1096×2560、約6.83秒）の拡大／格納動作を確認。足元のSeraRig原点が直線移動しても、回転・倍率変化により画面上の胸／胴体が弧を描く問題を修正。
- Chest/Torso/Waistボーンのモデルローカル位置の平均を一度保存。始終点のカメラ相対TransformとFOVでその胴体点を投影し、2D座標を直線補間。奥行きと実カメラFOVから復元した胴体座標から、補間Basis×ローカル胴体位置を差し引き、SeraRig原点を補正。回転・倍率補間はそのまま維持。
- カメラとモデルは別Tweenで更新順による視覚ズレが起こり得るため、モデルの進行率／端点を保持し、カメラ更新直後にモデル位置を再計算。戻る操作時の背景即時非表示、カメラ0.18秒／セラ0.28秒同時開始、3区画メニュー、NEXUS_pose、戦闘・音声は維持。
- README_v144_ja.md・tools/v144_torso_linear_transfer_self_check.py追加、従来ソース検査の版名更新。数値的な仮想アンカー投影検証のみ、Godot／Android実機実行は未検証。

## v145（2026-11-08） — 見た目の中心を一定速度で直線移動／グラデーションは拡大完了後に表示
- 基準：GitHub main `6198ae093f7e617aea31f119d1931af58af55e9a`（v144）。動画`1000034283.mp4`（約8.14秒）をコマ分解して比較。足元原点→胸・胴体中心に変更しても、ヨー回転と倍率補間でロボットの実際の画面外接形状が変化し、見た目の中心は曲線状に移動し得る。v144では`Tween.TRANS_CUBIC`によりスクリーン座標の進行率も加減速していた。
- Head/Neck/Chest/Torso/Waist/両肩/両上腕/両前腕/両手/両腿/両脛/両足の元モデルローカルボーン位置（最大19点）を開始時に保存。剣・盾は外して、投影された胴体＋四肢の画面外接範囲の中心を算出。開始と終了の見た目の中心をスクリーン（NDC）座標で直線補間する。
- 拡大・格納の位置進行率は`Tween.TRANS_LINEAR`による一定速度、モデルの向きと倍率の補間だけは別のsmoothstep進行率を使用。投影中心の位置合わせに4回の軽い透視補正を入れ、回転中の体形変化によるセンターの横振れを取り除く。移動中のカメラ更新後も同じ補正を実行。
- 共有の背景Quad（シアン放射グラデーション＋サイバー青グリッド）はプレビュー開始時・移動中は`visible=false`。0.28秒セラ移動Tweenの終了ハンドラで最終モデル位置確定後に`visible=true`。帰還操作時はこれまでどおりボタン押下直後に`visible=false`。
- セラ移動0.28秒・カメラ移動0.18秒の同時開始、3区画レイアウト、モデルの最終位置・倍率・NEXUS_pose・既存ゲーム機能は維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、既存静的検査v125〜v144。追加：README_v145_ja.md、tools/v145_visual_center_glow_delay_self_check.py。ソース順序・モデル点集合による数値投影検証のみ。Godot/Android実機の再生は未実施。

## v146（2026-11-08） — 動画による膨張を抑止する投影サイズ上限制御
- 基準：main `aee51b16a78e42525d27ebb62e2d1fee39f6ed8a`（v145）。ユーザー提供動画`1000034285.mp4`（1096×2560、約5.4秒）で、展示⇄CUSTOMIZEの途中にセラが一時的に大きく膨らむように見える問題を確認。v145は19個のモデル骨位置の画面外接矩形中心を直線で移すが、カメラFOV・モデル倍率・奥行きが別の曲線で変わるため、矩形の幅・高さの変化を拘束していなかった。
- v146ではモデル本体の投影外接矩形`_customize_body_bounds_ndc`を開始・終了カメラFOVで求める。画面上の中心に加え、見かけの幅・高さも進行率に対して始終点の値を直線補間する。中間姿勢の投影矩形を再計測し、縦横の許容比の小さい方の倍率をSeraRigのBasisへ一様に適用することで**どちらの方向も指定した補間サイズを超えない**ように制限。重複する位置だけの4回補正を廃止し、サイズ制御→中心合わせを2回だけ実施。
- セラの画面上移動は一定速度の直線を維持。回転補間のみsmoothstepを維持し、カメラの別Tween更新後にも同じモデル調整を再実行。開始と最終モデルTransformの決定、バック時の瞬時エフェクト非表示、拡大Tween到着後のエフェクト表示を変更しない。
- セラ移動0.28秒、カメラ0.18秒の同時開始、左上モデル・3区画メニュー・固定グリッド・NEXUS_pose・ほか4施設・音声と戦闘は変更なし。
- 対象：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧テストの版名／補間期待値。追加：README_v146_ja.md、tools/v146_bounded_body_motion_self_check.py。
- 静的確認と19点の代表的な骨位置による独立投影シミュレーションで、往復の中間時刻の表示幅・高さが始点／終点間の補間包絡を上回らないことを確認。**実際のGodot/Android映像・高負荷動作は未検証**。

## 表示用プロジェクト名の統一（2026-11-08、v146維持）
- 基準：GitHub `main` `9f32c84ee90679d323522f74e850155b614dd4c7`。Godotのプロジェクト名の長さが毎回変わり、Androidエディターの実行ボタンの表示位置が動く問題への対処。
- `project.godot` の `[application]` `config/name` を `SERA v146 - Bounded visual transfer` から **`SERA v146`** に短縮。
- 今後は **`SERA v<連番>` のみ**とし、英語の変更内容や任意の副題は付けない。変更内容は各バージョンREADME、DEVELOPMENT.md、PRに記録。ルールを`AGENTS.md`へ明文化。
- 既存の名前文字列を検証するソース回帰テスト（v125〜v146）も新表示名へ更新し、将来の命名規則を検査する`tools/project_name_self_check.py`を追加。ゲーム画面・アセット・ゲームロジック・モデル・カメラ・アニメーションは無変更。**ゲームバージョンはv146のまま**。
- ソース文字列・変更範囲の確認のみ。AndroidでのGodotエディター表示位置は未検証。

## v147（2026-11-08） — セラの拡大・格納アニメーションを2倍速に変更
- 基準：GitHub `main` `11c788003c99401abfe91e42f7f4cdcb26bd6959`（v146）。ユーザー指示により、展示セラからCUSTOMIZE左上プレビューへの移動・拡大、戻る時の展示台格納・縮小のTween時間を**それぞれ0.28秒から0.14秒へ短縮**。速度を2倍にし、位置・スケール・角度の従来の補間方式／軌道／到達時の倍率は変更しない。
- カメラTween0.18秒は据え置き。新たにセラ移動がカメラより先に完了するため、移動Tweenの終了時に世界位置を早期確定すると画面上で跳ぶ問題を防止する。セラは0.14秒以降もカメラ相対の到着座標をカメラ更新時に維持し、カメラ0.18秒完了後に最終世界Transformを確定。拡大エフェクトも両動作完了後に表示する。
- 戻る側も同じく0.14秒で格納目標の画面座標へ到達させ、カメラ帰還0.18秒が終わるまでモデルのカメラ相対位置を保つ。最終的に元展示Transformへ戻して全景操作を解除する。戻る操作時のエフェクト即時消去は維持。
- `config/name`は命名規則どおり**`SERA v147`のみ**とし副題なし。README_v147_ja.md追加、DEVELOPMENT.mdと静的回帰テスト・命名規則テストの整合性を更新。
- 変更対象：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、関連テストの旧版名／旧秒数期待値。追加：README_v147_ja.md、tools/v147_customize_double_speed_self_check.py。Godot／Androidの実機タイミングと映像は未検証。

## v148（2026-11-08） — RUN・BOOSTの地上移動速度を1.25倍
- 基準：GitHub `main` `97a9cc63d232b215bcd88dad529af0b67b08b5cd`（v147）。ユーザー指示により通常歩行（RUN）とBOOSTの実際の地上移動速度をそれぞれ1.25倍へ増加。
- `scripts/main.gd` の基準 `MOVE_SPEED=3.25m/s` とBOOST相対倍率`1.5`を維持し、地上RUN/BOOSTの物理速度式に `GROUND_MOVE_SPEED_SCALE=1.25` を追加。RUN最大速度は3.25→4.0625m/s、BOOST最大速度は4.875→6.09375m/s。入力アナログ強度に応じた増減も同倍率。
- BOOST開始125%／解除110%・0.10秒保持・0.15秒加減速、STEP／BACKSTEP、格闘接近、カメラ、ガード、走行・BOOSTモーションの再生速度、デバッグジャンプの空中ステアリング速度は変更しない。状態表示のx1.0／x1.5は新しいRUN基準との相対倍率を示すため据え置き。
- `config/name`は命名規則どおり`SERA v148`。`README_v148_ja.md`・`tools/v148_ground_movement_speed_self_check.py`を追加。従来のCUSTOMIZE系静的検査が最新プロジェクト名を認識できるよう期待タイトルのみ追従。
- 変更は速度係数と地上移動式の限定的差分。ソース上の数値・操作条件・対象範囲の確認は可能ですが、Godot/Android端末での実走行速度・衝突時挙動は未検証。

## v149（2026-11-09） — 360°フリースワイプ移動と進行方向ロングドラッグBOOST
- 基準：GitHub main `1d217ce94687fa7743f94c01e3403b952b026dc4`（v148）。従来の固定起点アナログ式（タッチ起点との差分／168px円盤／125% BOOST境界／0.10秒確定／0.15秒加速）を廃止し、直近の指の移動差分を約6px単位でサンプリングして、360度の移動方向を即時指定。指を止めた場合は最後の方向を維持、離した時に停止。移動速度はRUN 4.0625m/s・BOOST 6.09375m/sの二段固定（v148速度設定）で、指の移動量には比例させない。
- 同じ方向へ約140pxの実ドラッグ距離が蓄積するとBOOSTに切り替え、大きく方向転換（内積<0.65、約49.5°以上）するとRUNへ戻す。新しい方向で再び約140pxドラッグするとBOOST再起動。長時間保持だけではBOOSTしない。ダメージ・ガード・空中はBOOST無効、反応終了後は新しい長ドラッグで再有効。ブースト済みジェスチャーのリリースは従来どおり回避／格闘誤爆を防止する。
- モデルの方向転換の見かけの遅延対策としてRUN方向補間0.12→0.035秒、RUN退避モード0.18→0.075秒、上体追従0.10→0.05秒、ルート回転450→1440deg/s、BOOST方向補間0.06→0.025秒に短縮。移動方向の実速度ベクトルは既存どおり即時反映、モーションのみキビキビ表示。
- `touch_overlay.gd`の168px円盤・固定矢印・ノブ・外周の125%境界を廃止し、指の少し上に追従する小型のシアン方向矢印、ブーストまでの進行円弧、BOOST時の二重シェブロンとラベルを描画。ロックオンのターゲットリング・下部操作領域のグラデーションは維持。追加画像や外部依存なし。
- タップ格闘、長押しガード、リリース時の左右／後方ステップ、空中デバッグ、トレーニング敵、BGM、カメラレイアウト、NEXUS画面、元モデル・音声は維持。プロジェクト名は命名規則に従い `SERA v149` のみ。
- 変更：scripts/main.gd、scripts/touch_overlay.gd、scripts/sera_rig.gd、project.godot、DEVELOPMENT.md、関連既存テスト。追加：README_v149_ja.md、tools/v149_free_swipe_control_self_check.py。Godot/Androidの実機入力と表示、リグとカメラの追従については未検証。

## v150（2026-11-09） — フリースワイプコントローラ表示の滑らかな追従
- 基準：GitHub main `293c9aa6e7e4e3811248512bcba1763d1a344adf`（v149）。矢印の座標・向き・BOOSTチャージ表示をタッチイベントが届くたびに直接更新していたため、イベント間隔・6px方向サンプリングによってカクカク動く問題を修正。
- コントローラの表示専用データ（指位置・矢印角度・蓄積円弧）を追加。タッチイベントでは入力目標のみ更新し、`touch_overlay.gd`の`_process(delta)`でフレームレート非依存の指数補間を使用。表示追従時定数は位置0.040秒、矢印角度0.052秒、BOOST円弧0.070秒。角度は`lerp_angle`で0°/360°を跨ぐ場合も最短方向に回す。最初の方向は即座に表示し、それ以後の変化を補間。
- コントローラを三角ポリゴンから、アンチエイリアス付きストロークと丸い端点で描く細身の方向矢印に変更。固定168px円形スティックは復活させない。指の少し上に追従する小型の円・BOOST円弧・2連シェブロン・RUN/BOOST表記・下部操作領域・ロックオン表示は維持。
- 描画ループはドラッグ中またはロックオンリングの0.20秒回転アニメーション中のみ有効にして省電力を保つ。ロックオンリングのアニメーション進行は従来どおり。
- **セラ本体の移動方向／RUN固定速度／進行方向140pxドラッグBOOST／約50°方向変更で解除／攻撃・ガード・ステップの実入力は変更しない。** 滑らかにするのは表示だけで、操作応答はv149どおり。
- 変更：scripts/touch_overlay.gd、project.godot、DEVELOPMENT.md、旧テストのタイトル検査と描画方式の期待値。追加：README_v150_ja.md、tools/v150_smooth_swipe_hud_self_check.py。Godot/Androidの実画面・実機での60fps描画は未検証。

## v151（2026-11-09） — セラ本体の方向転換を連続角度で補間しRUNモーションを同期
- 基準：GitHub `main` `f67087330220583c2f2cfe33d856af2560e0a0fb`（v150）。指の約6pxごとの指示・RUN/BOOST固定速度を維持しながら、見た目の回転・RUN/後退姿勢・上半身追従が一致せずカクつく問題を修正する。
- RUNベクトル補間`Vector2.lerp`を廃止。180°の方向転換で中間ベクトルがゼロになり、正規化時に急反転する問題を避けるため、`atan2`・`wrapf`・指数補間を使う角度ベースの連続回転に変更。方向は単位円上`Vector2(sin, cos)`で常に正規化。反対方向±180°近傍（12°幅）は過去の回転方向の符号を保持し、指の微細なゆれで回転向きが交互反転するのを抑制。見た目のみ3°デッドバンドを採用。
- RUN姿勢の補間時定数0.035→0.055秒、BOOST0.025→0.045秒、前進／後退モードのクロスフェード0.075→0.085秒。実際の移動ベクトルは`main.gd`の即時更新のまま、コントローラUIもv150の0.052秒表示補間を維持。モデルの動作と表示を近い応答時間にする。
- RUN/後退のしきい値判定を生の入力方向から**補間後の方向**に移し、前進/後退モード・クリップ混合・Waist向きの目標が単一の視覚方向に従うよう変更。RUNルート回転では退避フラグの0/1の瞬時180°切替を廃止し、連続する`run_retreat_blend`で目標角度を補間する。既存の左右利き偏り（100°/120°）、±5°ヒステリシス、1440°/秒上限、腰のバンク、顔と上半身の視線追従、4方向の著作モーションを維持。
- BOOST姿勢にも同じ最短角補間を適用する。RUN→BOOST・BOOST→RUN 0.08秒ブレンド、RUN→Wait 0.16秒、攻撃・ステップ・ジャンプ・ガード・ダメージ中のモーション禁止は変更しない。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`と静的検査。追加：`README_v151_ja.md`、`tools/v151_turn_smoothing_self_check.py`。動作の視覚検証・Godot/Androidエンジン実行は未実施。

## v152（2026-11-09） — 指の生理的な揺れを想定したフリースワイプ感度の調整
- 基準：GitHub main `c6666532c09aa718eef97c414d5d57003429aacf`（v151）。v149以降の入力が各約6pxの直近の接触差分を進行方向に直接使うため、自然な指の細かな往復や斜めのぶれを瞬間的な方向転換・BOOST解除として扱っていた。
- タッチ方向は最新の単一イベントではなく**直近80msの指位置差分**を計測。通常12px以上の実移動と12°以上の角度差で方向候補を更新。40°を超える急旋回は意図確認のため20px以上の正味移動を必要とする。小さな指の揺れ（数px程度）では進行方向を更新しない。
- 入力方向のターゲットだけをイベントから更新し、物理更新中に方向角をフレームレート非依存で補間。通常の追従時定数0.055秒、65°以上の大きな方向変化には0.020秒、140°以上の明確な反転は同物理フレームで即時反映。RUN／BOOSTは固定速度のまま、方向を変えるために元の指位置まで戻す必要はない。コントローラはこの実際に反映した方向を表示し、v150の独立した滑らかな描画は維持。
- BOOSTの140px条件は維持するが、旧方式のイベントごとの移動距離の単純加算を廃止し、進行方向の開始地点からの**正味前進距離**で判定。小さな往復やノイズだけではBOOSTが溜まらない。約50°以上の明確な方向変更、被ダメージ、ガード、空中では従来どおりBOOSTを解除して基準点をリセット。
- タップ攻撃と18px判定、0.32秒ガード、リリース時のフリック回避、BOOST終了後の誤爆防止、セラ本体v151モーション、RUN/BOOST速度・視覚エフェクト、NEXUS画面は変更しない。
- 変更：`scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`、関連静的検査。追加：`README_v152_ja.md`、`tools/v152_thumb_steering_self_check.py`。コード差分と方向フィルター／BOOSTの独立計算のみ。実際のGodotエディター・Xperiaタッチ感度は未検証。

## v153（2026-11-09） — コントローラ操作をv148の固定式アナログスティックへ復元
- 基準：GitHub main `4542e2956abc7d604459835d2952fa7218bf5677`（v152）。ユーザーの指定によりv149〜v152のフリースワイプ操作、ロングドラッグBOOST、指の軌跡フィルター、および専用HUDを取り消す。
- `scripts/main.gd`と`scripts/touch_overlay.gd`のみv148 main `1d217ce94687fa7743f94c01e3403b952b026dc4`の内容へ復元。指を置いた地点を中心にした半径168pxのアナログスティックを使用。移動方向・入力強度は起点から指へのベクトル、100%半径でRUN最大速度、125%以上を0.10秒維持してBOOST開始、110%未満で即解除。BOOST速度は0.15秒で補間。ブースト時ノブ表示148%。
- v148で適用済みの地上RUN・BOOST移動速度1.25倍（RUN最大4.0625m/s、BOOST最大6.09375m/s）は維持。セラ本体のv151滑らかな角度補間は`scripts/sera_rig.gd`を変更せず保持。NEXUSメニュー、カメラ、モーションデータ、BGM、攻撃・ガード・フリック回避・デバッグジャンプは変更しない。
- プロジェクト名は`SERA v153`に更新。v149〜v152のスワイプ専用静的検査は過去バージョン向け資料として残すが、v153の受け入れ検査対象から除外。
- 確認：v148と同一の操作コード／表示コードへの復元、GitHubの変更ファイル検査、および`tools/v153_restore_analog_controller_self_check.py`の静的期待値。Godotエンジン・Android実機検証は未実施。

## v154（2026-11-09） — アナログスティックの高速反転入力
- 基準：GitHub main `e236c05b5473dfe26946f9ec1b95e8bed8ac5547`（v153）。通常の固定起点アナログスティックに、素早い反転のみ相対ストロークからの入力を追加する。
- 半径25%以上倒した状態で、現在の方向から約143°以上反対へ120ms以内・32px以上・平均520px/秒以上動かした場合、逆方向ストローク開始位置へスティック中心を付け替える。元の中心を指が跨ぐ前に即時方向反転。複数タッチイベントを積算して微小なノイズやゆっくりした指戻しは無視する。
- 反転時はスティックの表示中心・入力方向・BOOST境界を同時に更新。BOOST距離の判定は従来どおり125%で0.10秒、110%未満で解除、速度補間0.15秒。RUN入力強度・地上速度1.25倍は変更しない。
- タップ・ガード・リリース回避は初回のタッチ位置で判定し、反転済みジェスチャーのリリースをSTEPに誤判定しない。v151のセラ本体モーションと円形UIは変更しない。
- 修正：`scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`、v153回帰検査のタイトル。追加：`README_v154_ja.md`、`tools/v154_fast_reverse_self_check.py`。Godot実行およびAndroid実機の操作感は未検証。

## v155（2026-11-09） — 高速反転の速度しきい値引き上げ
- 基準：GitHub main `2201e80f7d5fa6a84e5e3bee397370e48fd7a5da`（v154）。ユーザーの指示どおり高速反転の速度判定のみ厳格化し、`FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC` を520.0→800.0 px/秒に変更。
- 反転角度の内積 `FAST_REVERSE_OPPOSITE_DOT=-0.80`（約143°以上）は変更しない。判定時間120ms、移動距離32px、スティック半径25%条件もすべて維持。v153のアナログスティック、BOOST判定・ガード・STEP・格闘とv151の本体モーションも変更しない。
- 既存のv154回帰テストの期待バージョン・速度定数・独立計算条件をv155へ更新し、`tools/v155_reverse_speed_self_check.py`で520〜799px/秒相当の移動を拒否、800px/秒以上を許可する数値シナリオと反転角度固定を検査する。Android実機とGodotエンジンでの動作は未検証。

## v156（2026-11-09） — 高速反転後もBOOST判定領域を元の範囲へ固定
- 基準：main `49db990fc9fd3eb778ae2d9a90440efb2858bd40`（v155）。反転時に方向指定スティックの起点を移動しても、BOOSTの判定用起点`boost_pointer_origin`は初回タッチ位置を保持する。
- BOOSTは元の円の125%（210px）で0.10秒確定、110%（184.8px）未満で解除。反転時にBOOSTを解除し確認時間をリセット、元の110%内に戻るまでBOOST再発動を禁止する。誤って反転直後にBOOSTへ移行しない。
- 描画も方向指定円盤は反転後の起点、BOOST開始ガイド弧は元の起点へ分離する。角度約143°・反転速度800px/秒・32px/120msは維持し、攻撃、ガード、回避、セラ本体モーション、RUN・BOOST速度と0.15秒加減速は変更しない。
- `scripts/main.gd`、`scripts/touch_overlay.gd`、`project.godot`、履歴、回帰テストの期待バージョンを更新し、v156シナリオ検査を追加。Godot/Android実機は未検証。

## v157（2026-11-09） — 指に追従しない固定式8方向デジタルスティック
- 基準：main `7b7cd7339eec0d82df0c65bf80274fbb4275800a`（v156）。タッチ開始地点に円形パッドを1回だけ表示し、指を動かしてもパッドの中心・ボタンは動かない。各8方向（45度刻み）の矢印を固定位置に配置し、選択方向のみハイライトする。BOOSTの125%ガイドは固定円として表示。
- 8方向のデジタル入力は移動開始34px／停止22pxの距離ヒステリシス。方向境界では6°の角度ヒステリシスで指ブレによる点滅を抑える。移動開始後は常に等速のRUN入力（対角も正規化）。指を反対側へ動かした場合の特別な反転操作や中心の付け替えは廃止し、通常の8方向操作で指定する。
- ガード長押しは元の18px以下の静止判定、タップ攻撃・指離しフリックによる回避、ジャンプのデバッグ設定を維持。RUN速度の既存の1.25倍、BOOST開始125%で0.10秒・解除110%未満、0.15秒加減速と各種アニメーション・カメラは維持。
- v154～156の高速反転とブースト再アーム処理を撤去。過去バージョン専用テストは現行バージョンではSKIPさせ、v157用の静的・独立数値シナリオ検査を追加。実機およびGodot実行は未検証。

## v158（2026-11-09） — 固定位置の短縮RUN円と連続360°方向入力
- 基準：GitHub main `0aba7064e115a5cabf92c98dc5c5b6de9609611b`（v157）。8方向（45°刻み）のデジタル判定を廃止し、タッチ開始位置に固定したスティックから連続した360°のアナログ方向ベクトルへ変更。
- RUN用の最大半径を168→112pxへ短縮し、18pxデッドゾーンから112pxの間で入力強度0→1へ連続変化。対角を含む任意角度で方向の飛びをなくし、RUN最高速度は従来の1.25倍スケールを維持。
- BOOSTは距離判定の基準半径`DRAG_RADIUS=168px`を維持。開始125%（絶対距離210px）・終了110%（184.8px未満）・確定0.10秒・加減速0.15秒を一切変更せず、表示側も210px固定ガイドとして保持。
- HUDの中心はタッチ開始位置に固定して指を追尾せず、RUN円のみ112pxへ縮小。8方向の矢印を消して360°回転する方向マーカーに変更。中央ハブとBOOSTリングは固定、指を追うノブは採用しない。モード表示の位置は元のBOOSTガイドに合わせて調整。
- 既存の攻撃・ガード・リリース回避・デバッグジャンプ、セラ本体モーション、カメラとNEXUSは維持。旧v157専用テストは現行版ではSKIPし、新しいv158静的検査と独立数値検証を追加。Godot・Android実機では未検証。

## v159（2026-11-09） — ブースト→RUN後も0.30秒間BOOSTモーションを保持
- 基準：main `dc4f177803fa4533a7e871d8bf49f9e6ac61184e`（v158）。方向転換時に親指がBOOST境界125%→110%内や中心18pxのデッドゾーンを通過しても、姿勢がBOOST→RUN／WAIT→BOOSTと短時間に切り替わる問題を解消。
- 地上移動処理`scripts/main.gd`でBOOSTモーション保持タイマー`BOOST_POSE_GRACE_SECONDS=0.30`を追加。実BOOST中は残時間を0.30秒へ更新、BOOST解除後はフレーム時間で減らし、その間のみrigへBOOST姿勢を指定する。ニュートラルを跨ぐ間も姿勢保持、方向入力が戻れば最新の局所方向へBOOST姿勢の補間を継続。
- BOOST入力判定・HUD・加減速および位置・速度計算は実`movement_boost_active`で判定する。タイマーは描画側のみ適用し、RUN/BOOSTの速度やBOOST再発動条件、残像判定を変更しない。
- 指を離す、ガード・攻撃・STEP・ダメージ・ジャンプ・着地中はタイマーをリセットし、通常アクションのモーションを優先。既存`sera_rig.gd`は無変更でv151の方向補間を維持。UIとサウンドも変更なし。
- 回帰テストはコード検査・独立状態遷移計算によりBOOST→RUN／中心→再BOOST／保持時間満了／操作中断を確認。GodotエンジンとAndroid実機での動作は未検証。

## v160（2026-11-09） — BOOSTコントローラ外周の推進デザイン
- 基準：GitHub main `f9ccc52abe14aba2545621ff5bb48f15daa025e7`（v159）。操作判定は変えず、`scripts/touch_overlay.gd`の見た目のみ変更。
- 既存のRUN円112px、BOOST開始210px（168×1.25）・解除184.8px（168×1.10）、入力の360°連続、BOOST速度・姿勢保持0.30秒をすべて維持。
- BOOSTリングの外に8分割の装甲風アーク（168×1.34＝225.12px）と外向き推進矢印8個（168×1.40〜1.50＝235.2〜252px）を追加。常時表示し、非BOOST時は薄く、BOOST中だけ明るく強調。指を追尾する新要素はない。
- モード表示を最外周矢印より16px上へ移動し、装飾との重なりを防ぐ。HUDのコントローラ以外のターゲット表示・背景・動作は変更せず。
- `project.godot`の表示名をSERA v160に更新、開発履歴・README・独立静的/幾何テストを追加。v159専用テストを履歴扱いとしてv160ではスキップ。
- GodotエンジンやAndroid実機での表示確認は未実施。

## v161（2026-11-09） — BOOST開始距離を中心へ25.2px近付ける
- 基準：main `78ce56e0329fe9d14089a16de5dc01668589ea7a`（v160）。固定スティックのBOOST開始判定半径を210px（168×125%）から184.8px（168×110%）へ短縮。
- 旧解除位置184.8pxと新しい開始位置が一致するとON/OFFが揺れるため、解除位置も159.6px（168×95%）へ内側に変更。従来同様15%（25.2px）のヒステリシス差を維持。
- RUN入力用の112px円、18pxデッドゾーン、360°連続方向、開始の0.10秒保持、BOOST速度補間0.15秒、解除後BOOSTモーション猶予0.30秒は維持。
- BOOST境界の円を184.8pxに合わせ、v160の8分割外殻と8方向の推進矢印も半径225.12→199.92px、235.2〜252→210〜226.8pxへ中心側に移動。RUN/BOOSTラベルも新しい外端に合わせて移動し重なりを防止。
- 攻撃・ガード・回避・カメラ・セラ本体モーションのコードは変更しない。v160専用検査には版不一致スキップを追加、v161用の静的・幾何・ON/OFF数値検査を追加。Godot実行／Android実機での操作検証は未実施。

## v162（2026-11-09） — BOOST解除後0.50秒モーション維持＋0.20秒RUN遷移
- 基準：main `2b203d7597b120371419c210059368dcadf53cdb`（v161）。`scripts/main.gd`のBOOST姿勢保持`BOOST_POSE_GRACE_SECONDS`を0.30秒から0.50秒へ変更。
- `scripts/sera_rig.gd`に`BOOST_TO_RUN_BLEND_SECONDS=0.20`を追加。姿勢保持が切れたあと`BOOST_CLIP`から`RUN_CLIP`へ移行する場合に限り0.20秒のクロスフェードを実施。既存の`prior_rotations/offsets/scales`を元に球面補間/線形補間を行い、遷移中の重みをsmoothstep型の3t²-2t³でイーズイン・アウト。
- ブースト再開時は保持時間を0.50秒へ更新してRUN遷移をキャンセル。クロスフェード中に再ブーストした場合も今の表示姿勢から既存の0.08秒BOOST入場遷移へ移る。
- ガード・被弾・攻撃・回避・ジャンプ・着地・指離し時は保持を即解除。BOOST開始184.8px／解除159.6px、速度減速0.15秒、RUN112px、360°方向指定、外周装飾、残像、HUDと他のアクションのフェードは維持。
- v161専用検査に版不一致スキップ追加。v162用の静的検査と0.50秒保持・0.20秒smoothstep遷移・再ブースト中断の独立数値検査を追加。Godot/Android実機での実行は未検証。

## v163（2026-11-09） — RUN⇄BOOSTの速度移行を両方向0.20秒で滑らかにする
- 基準：main `f3647d76830270d5c1222f6a18ab178b1b86f833`（v162）。旧`move_toward`による一定傾斜0.15秒の速度推移を廃止。
- RUN倍率1.0とBOOST倍率1.5の間を双方0.20秒、smoothstep（`3t²−2t³`）のイーズイン・アウトで補間する`_update_boost_speed(delta)`を追加。切替時点の倍率を新たな補間開始値に引き継ぐので、加速中・減速中に逆向きへ切り替えても倍率が跳ねない。
- タッチ終了・再開始・ガード・ジャンプ時は`_reset_boost_speed_transition()`で倍率・補間開始／目標／経過時間を1.0／1.0／1.0／完了にまとめて初期化し、次のタッチに古い補間状態を持ち越さない。
- 実移動速度の式、RUN112px・BOOST開始184.8px／解除159.6px、360°方向入力、BOOST確定0.10秒、BOOST姿勢0.50秒保持＋0.20秒RUNクロスフェード、他のアクション・HUD・外装は変更なし。
- v162専用テストを新バージョンではスキップ。v163静的・数値検査で補間端点、減速／加速の単調性、加速中の減速反転および減速中の再加速、入力終了時の初期化を確認。Godot/Android実機では未検証。

## v164（2026-11-09） — A/B全身セットを6部位へ分解して交換する機能
- 基準：main `be1db12a79d77ee45440c448664910343dfd92d8`（v163）。現行`models/SERA_BOOSTER_allテスト.bbmodel`に`Waist`（A）と`Waist2`（B）の2全身ルートが存在し、Bの`Head2`には`sphere`メッシュがあることを確認。
- `scripts/sera_equipment.gd`を追加。現行Aリグのアニメーション／UUIDは保持し、同一`.bbmodel`内のB以降の各メッシュを対応する既存ボーンへ取り付ける。セットごとの6スロット（頭／胴／下半身／腕／右手武器／左手武器）を個別に切り替え。名前が多少変わっても階層とピボットを参照し、曖昧な候補はスキップ。
- `scripts/sera_rig.gd`に元ピボットメタデータ、部位選択API、自動復元を追加。非選択メッシュの表示を抑え、残像側の表示も対応させる。剣閃専用メッシュは対象外。
- `scripts/command_nexus.gd`の既存CUSTOMIZE右パネル内に6部位のセット切替行を実装。既存プレビュー回転／拡大／縮小／画面遷移のUI領域は維持。設定は`user://sera_equipment.cfg`へ保存し、TRAININGのリグにも適用。
- Androidの`.bbmodel`直読みと単独配布時の埋め込みフォールバックを実装し、`tools/rebuild_equipment_data.py`と`assets/sera_equipment_data.gd`を追加。セットを編集した後は再埋め込みが必要。
- `project.godot`の表示名を`SERA v164`に更新。新規`README_v164_ja.md`、`tools/v164_equipment_self_check.py`を追加し、v163専用バージョン検査は履歴用にSKIPへ変更。
- 既存戦闘・ブースト・RUN・カメラ・攻撃・ガード・BGM等の動作コードは変更なし。Godot実行／Android実機での検証は未実施。

## v165（2026-11-09） — Bセットの全身を赤色に変更
- 基準：main `6ca7782562979ca0b73ab38e3ba48a365dc5dabc`（v164）。カスタマイズBセットのみ赤色補正を適用。Aおよび将来のC以降は元のテクスチャ色を維持。
- `scripts/sera_equipment.gd`ではB用マテリアルを複製して赤色`Color(1.0, 0.18, 0.18, 1.0)`を乗算し、既存テクスチャの陰影・UVを残す。頭・胴・下半身・腕・左右武器の6部位全てに適用。
- `scripts/sera_rig.gd`でB専用の剣閃前面パスおよび残像用マテリアルを複製し、描画シェーダーの`set_tint`に同じ値を指定する。A側は既定値の白で従来表示を維持し、攻撃・モーション・移動・残像のタイミングやアルファ値を変更しない。
- `shaders/sera_foreground.gdshader`と`shaders/sera_motion_ghost.gdshader`に既定白の色補正を追加。Blockbench原本・共通アニメーションJSON・カメラ・UI操作は編集しない。
- `project.godot`を`SERA v165`へ更新し、READMEおよび静的チェックを追加。GodotおよびAndroid実機での表示確認は未実施。

## v166（2026-11-09） — トレーニングルームから拠点メニューへ戻る
- 基準：main `4e48a0bd9d3620a2829b27b273bc386a98a2449d`（v165）。TRAININGの上部HUDに`BACK TO NEXUS`ボタンを追加し、既存`scenes/command_nexus.tscn`へ直接遷移。
- Androidのraw touchを座標で拾い、HUDタップが格闘・移動と重複しないよう抑止。PCのマウス／EscおよびAndroidのシステム戻る通知を補助導線にし、トレーニング中だけ自動終了設定を一時解除、離脱時に復旧。
- 遷移は重複を防ぎ、deferredで処理。失敗時はエラー表示（ログ）して再試行可能。NEXUS→TRAININGの既存ルート、入力・攻撃・ブースト・BGM・カスタマイズA/B・描画は変更しない。
- `scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`、旧v165チェックの版スキップを更新。`README_v166_ja.md`と`tools/v166_return_to_nexus_self_check.py`を追加。Godot/Android実機は未検証。

## v167（2026-11-09） — ガード成功リアクションと3段→バッシュ→3段ループ
- 基準main `e7b14ff65cd00c9569e33e5368da4543c99ad1b8`（v166）。最新`models/SERA_BOOSTER_allテスト.bbmodel`の既存AボーンUUID互換アニメ`Guard_REACTION`（0.20833秒）、`Bash`（0.5秒）を抽出し、従来のソースJSONと埋込スナップショットへ追加。A/B外観、他アニメ、テクスチャ/ボーン構成は保持。
- ガード中に被弾すると`Guard_REACTION`を1回再生し、保持中は`Guard`に復帰。既存ガード被弾音とDamageknock抑止を維持。ガード中の前方リリースフリックもBashへ遷移。
- 3段目の前フリック（離指）でBashを予約し、3段目キャンセル可能時刻0.625秒以降で実行。3段目終了後0.65秒まで受付。Bash中のタップを1件バッファし、終了後は`melee1`を開始。Bash終了後0.65秒のタップでも再始動し、ループ可能。
- Bash仮実装ダメージ12、接触時刻0.25秒、近接判定0.95m。単発ヒットと共通ヒットストップ/演出、敵HPと撃破再生を継承。盾値消費、攻撃突破/アーマーは未定のため実装しない。通常の左右・下フリック、RUN/BOOST、ジャンプデバッグ、画面遷移は維持。
- `project.godot`を`SERA v167`に更新。検査`tools/v167_guard_bash_loop_self_check.py`、READMEを追加。Godot/Android実機は未検証。

## v168（2026-11-09） — カスタマイズ後のセラ輪郭線を現在の装備形状へ追従
- 基準：main `60596ffb7e438732b89afe1765b1e6c041ee569f`（v167）。CUSTOMIZE画面の部位選択では従来からシルエットの再取得自体は実行していたが、ボーンごとの外接箱の合成により、Bの球体頭部や離れた装甲の輪郭を過大に囲む状態だった。
- `scripts/command_nexus.gd`のシルエット取得を、可視状態の各メッシュの頂点をグローバル座標へ変換する方式へ変更。非選択パーツとSwordeffectを除外し、切替直後・回転・展示復帰の既存再取得経路へ反映。既存2D凸包・輪郭結合・ゲートの手前遮蔽処理は保持。
- 頂点はMeshのinstance ID単位でローカル座標の重複を除いてキャッシュし、回転やフィット時には頂点CPU配列を再読込しない。実頂点を取得できないメッシュのみ旧外接箱へフォールバック。サブビュー、追加3D描画なし。
- `project.godot`の名前を`SERA v168`へ更新、v167専用検査は新バージョンでSKIPする履歴用へ変更。READMEと専用静的検査を追加。A/B保存、NEXUS操作、トレーニング、戦闘アニメ、BGM、グローは変更なし。
- Godotランタイム／Android実機の表示確認は未実施。

## v169（2026-11-09） — タップ攻撃成立後のシアン波紋と新規タッチ時の即時復帰
- 基準：main `77afeaa6ff359fa64c57ccfb3b15b6c28b105b16`（v168）。`scripts/main.gd`のタップ攻撃受付`_start_attack`をbool返却にし、ガード・被弾・着地・ステップ・接近中・無効コンボ操作はfalse、開始/許可された先行入力はtrueとする。入力/戦闘状態そのものは変更なし。
- 短いタップを離した後、`_start_attack()`がtrueのときのみ`touch_overlay.show_attack_ripple(release_pos)`を開始。波紋は同じHUD上で3本のシアン円弧を0.075秒差で0.46秒展開しフェード（半径12→86px）。発光や追加アセットなし。
- 波紋中の新規タッチ（HUD上を含む）・PCマウス左押下で`cancel_attack_ripple`を即時実行。操作位置へのタッチなら従来`show_drag`が通常コントローラーを表示し、そこで再度キャンセルも保障する。
- 既存ロックオンの0.20秒アニメ終了が波紋を途中停止しないよう、`touch_overlay._process`のset_process停止を両アニメが完了したときだけ行う。ロックオン/背景/コントローラー/ダメージ/Guard/Bash/走行等は維持。
- `project.godot`を`SERA v169`に変更し、README/新規静的・数値テストを追加。v168専用検査は新バージョンでSKIPする履歴用へ変更。Godot本体とAndroid実機は未検証。

## v170（2026-11-09） — 全フリック操作のボート型V字波跡
- 基準：main `2e66145804bf5781dda48e515464a70283599e38`（v169）。左右・下フリックによるサイド/バックステップ、ガード中の上フリックBash、3段目からの上フリックBashが受理された場合に限って画面上に波跡を表示。
- `scripts/touch_overlay.gd`に船の後方で左右へ広がるようなシアン曲線3組を実装（0.06秒ずつ遅延、寿命0.43秒）。指の動いた方向の反対側へ伸び、幅・距離を増やしながら減衰。新規タッチでは瞬時停止してRUN/BOOSTコントローラー復帰。新たなテクスチャや3Dモデルなし。
- `scripts/main.gd`の入力分類は維持。STEP開始メソッドは成否をboolで返し、未成立ではエフェクトを出さない。上フリックの通常ジャンプは引き続き無効（将来有効化された際の開始成功時に同じ波跡を利用可能）。
- タップ攻撃の円形波紋、3段格闘・Bash動作、ガード、フリックの閾値、RUN/BOOST、ロックオン、背景と既存SEは変更しない。
- `project.godot`は`SERA v170`、READMEと静的/幾何検査を追加。v169専用検査は履歴として新バージョンでSKIP。GodotとAndroid実機の描画/入力動作は未検証。


## v171（2026-11-09） — DATA ARCHIVEの3スロットセーブ／ロード／新規作成
- 基準：GitHub main `77c9954d88327b9f49a7db47e478c34d21a6b790`（v170）。既存DATA ARCHIVEの3D設置位置・カメラ・選択シルエットを保持し、フォーカスパネル内に3スロットとSAVE/LOAD/NEW DATA/DELETEを実装。
- `scripts/sera_save.gd`をAutoloadし、`user://sera_archive/slot_01.json`～`slot_03.json`と`index.json`へ保存。バージョン付きJSON、スロット検証、一時ファイルからの置換、ローカル保存。既存スロットを上書き・再作成・削除する際は同じ操作を二度タップして確認。
- 保存対象：頭・胴・下半身・腕・右武器・左武器の外装、トレーニング累積秒、最終利用エリア、タイムスタンプ、将来用のtutorial_completed初期フラグ。ロードでは装備をNEXUSモデルに即時適用し、次のTRAININGリグにも引継ぎ。装備変更の作業コピーと保存スロットの確定値を区別し、SAVEでのみスロットへ確定。従来の`sera_equipment.cfg`も維持。
- まだ正式なステージ進行・チュートリアル進行処理がないため、ロードは戦闘途中の座標・敵HPの復元やチュートリアルへの自動遷移を行わない。旧モデルやアニメ、BGM、ブースト・格闘、訓練の移動速度・カメラは変更なし。
- 変更：`project.godot`、`scripts/command_nexus.gd`、`scripts/main.gd`、`scripts/sera_equipment.gd`、`DEVELOPMENT.md`、v170履歴検査の版依存を緩和。追加：`scripts/sera_save.gd`、`README_v171_ja.md`、`tools/v171_data_archive_self_check.py`。Godot/Android実行・実ファイルIOは未検証。


## v172（2026-11-09） — SYSTEMとDATA ARCHIVEの役割分離、実測戦闘統計
- 基準：main `53a17afc76e2e551ad579d0f5d22422832cd4ef0` (v171)。ユーザー指示により、3スロットSAVE/LOAD/NEW DATA/DELETEをSYSTEMの前方コンソールへ移動。アーカイブは操作を移さず閲覧専用のSUMMARY/COMBAT/PROGRESS/PROFILEの4タブとする。
- `scripts/sera_save.gd`の既存JSON保存スキーマを維持したまま、新規`play_seconds`、`training_visited`と戦闘統計辞書を追加。v171の既存セーブを読み込む際は不足キーを初期化し、プレイ時間の初期値は既存トレーニング時間以上とする。
- `scripts/main.gd`で剣の命中確定、バッシュ命中確定、HPが正から0へ遷移したダミー破壊、受けた攻撃のガード/非ガードをそれぞれ1度だけ計上。ダミー破壊を正式な敵撃破と誤称しない。ダメージ量はHP実減少値で計上。NEXUS/TRAININGの稼働時間を累積してSYSTEM SAVEで確定。
- アーカイブ進捗タブのトレーニング訪問は実際の訪問データに基づき、未実装のストーリー/ミッション/チュートリアルはNOT IMPLEMENTED表記とする。ガレージの3Dカメラ/モジュール、装備選択、入力/移動/格闘ロジック、BGMは維持。
- 変更：`scripts/command_nexus.gd`、`scripts/sera_save.gd`、`scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`。追加：`README_v172_ja.md`、`tools/v172_system_archive_self_check.py`。既存v171検査は過去バージョン向けとして残す。Godot/Android実機未検証。


## v173（2026-11-09） — SYSTEMのCONFIRM待機時に選択スロット枠を点滅
- 基準：main `7bb1fa3e391e87cb52b4767d1609b2856aaafc8a`（v172）。SYSTEMの既存スロット上書きSAVE・NEW DATA・DELETE確認時のみ選択中のカード枠線を明シアン／透明（0.38秒ごと）で点滅。文字と背景は固定表示し、視認性を維持。
- クリック確定・キャンセル・戻る・別スロット選択・画面退出で点滅タイマーと枠を初期化。別スロットやDATA ARCHIVEには影響させない。既存StyleBoxFlatのみ更新、点滅位相が変わったフレーム以外は追加描画処理なし。
- プロジェクト名は`SERA v173`、README/専用静的テストを追加、v172専用静的テストを履歴扱いでSKIP。既存のセーブ処理、外装、戦闘ロジック、表示カメラ/アニメ/音声は変更しない。Godot/Androidの実機検証は未実施。


## v174（2026-11-09） — 点滅対象をSYSTEMのCONFIRMボタンに訂正
- 基準：main `39e4848468c57e8adba0bb8b88764697049c05e0`（v173）。v173のスロット選択枠点滅はユーザー指定と異なったため取り消し、確認待ちの「CONFIRM SAVE / CONFIRM NEW / CONFIRM DELETE」アクションボタン自身の枠線と背景を0.38秒ごとに明／暗切替。
- 選択スロット枠は常時の青い枠線とし、CONFIRMボタン以外のアクションボタンも固定。色変更は既存StyleBoxFlatで実現し、位相切替時だけqueue_redraw。確定・取消・画面退出などの停止経路はv173のまま。
- `project.godot`を`SERA v174`へ更新、READMEと専用静的検査を追加。v173専用テストは履歴用SKIPに変更。ゲームロジック、保存データ、装備、戦闘、カメラやBGMは変更しない。Godot/Android実機動作は未検証。


## v175（2026-11-09） — CONFIRMボタン以外のタップで確認解除、LOADにも確認操作を追加
- 基準：main `41d3a5048b86b8bf861be9a8ed3f02d8f5ff4844`（v174）。SYSTEMの確認待ちで、対象のCONFIRMアクションボタン以外の座標へのタップは、スロット行・別ボタン・余白・パネル外を問わずキャンセルする。対象外のタップは消費して別操作を同時に発動しない。既存のBack/戻るによるキャンセルは維持。
- 存在するスロットへのLOADを常に二段階確認とし、初回操作で`CONFIRM LOAD`に変化してv174の点滅処理を共有、同じボタンの2度目のタップでのみロード／装備反映。空のLOADは確認に入らずエラーメッセージ。SAVE/NEWの既存上書き、DELETEの確認および空スロットの即時SAVE/NEWは変更なし。
- UIは`scripts/command_nexus.gd`に限定し、`project.godot`を`SERA v175`に更新。READMEおよび専用静的テストを追加、v174の当時のUI検査は履歴用SKIP。保存スキーマ・戦闘シーン・モデルなどには変更しない。Godot/Android実機動作は未検証。


## v176（2026-11-09） — CONFIRM点滅両色を通常ボタンより明るく
- 基準：main `a14ab0d712d339a3d393cf69377739ba34e4bb77`（v175）。確認状態解除の即時視認性向上：これまで点滅の暗い位相が通常時の背景色と同じで解除の識別が困難だったため、明位相RGB(0.14, 0.39, 0.50)と暗位相RGB(0.075, 0.21, 0.30)へ変更。両色とも通常時RGB(0.018, 0.035, 0.060)より各RGBチャネルが明るく、枠線もそれぞれ明シアンと青シアンへ変更。周期0.76秒を維持。
- 確認待ち解除時は既存`_cancel_system_confirmation()`の`_refresh_system_controls()`が直ちに`_menu_style()`の暗い通常色へ戻す。初回描画/位相更新の色指定を定数で統一しズレ防止。LOAD含む確認操作、対象ボタン以外のタップキャンセル、3スロット・アーカイブ、戦闘・モデルは従来どおり。
- 変更：`scripts/command_nexus.gd`、`project.godot`（`SERA v176`）、`DEVELOPMENT.md`、v175版固有テストの履歴SKIP化。追加：`README_v176_ja.md`、`tools/v176_confirm_colors_self_check.py`。色チャネル比較と操作導線の静的検査、Godot/Android描画は未検証。


## v177（2026-11-09） — A中量/B重量の部位性能とTRAINING実動作試作
- 基準main v176、GitHub作業ブランチ feat/ab-equipment-stats-v177。ユーザー合意のHP合算/5部位防御平均と7枠（頭・胴・両腕・下半身・ブースター・左右武器）をA/B試験数値として実装。
- 新規 scripts/sera_part_stats.gd。胴体が総HP半分、残りの部位が合計半分となるA/B標準一式を設定。A=中量800HP/防御16%、B=重量1040HP/防御29.4%、混合装備可。
- CUSTOMIZEに物理モデル未分離のBOOSTER仮スロットを追加（性能のみA/B切替）、保存とトレーニングへ反映。既存A/Bモデルとアニメーションを保持。
- scripts/main.gdで脚・ブースターの走行/BOOST/STEP/接近速度・エネルギー消費、腕・右武器・左武器の火力/ガード性能、頭部のロック距離/命中補正、脚の被弾モーション・ノックバック補正を接続。現行訓練キューブには仮のCORE部位破壊値と弱怯み値を持たせ、武器ごとの蓄積と命中密度による延長を試験可能にした。
- EN/SH自然回復、EN不足時行動制限、SH0での即ガードブレイク、脚別追加被弾回数で無敵ダウン、復帰時EN/SH全快を試作。HUDで確認できる。HP0でのゲームオーバーと実ボス外周部位・素材システム・チャージ突進は未実装。
- scripts/sera_rig.gdはA既存動作を維持し、被弾再生/ガード移行/ガードリアクション速度だけ試験補正。v176の版固有テストはv177時SKIPに移行。
- 新規README_v177_ja.mdとtools/v177_equipment_stats_self_check.py。Godot実行・Android端末の入力/描画検証は未実施。次工程で端末確認、操作修正と数値再調整が必要。

- 追加検証導線：AndroidでSH0からダウンまでを手動確認できるよう、訓練HUDにTEST HIT / TEST BREAK（画面タッチの移動・攻撃への非伝播）を追加。ブレイク大怯みは試験値2.25秒。通常のボス仕様として固定した数値ではない。


## v178（2026-11-09） — 訓練ターゲットの移動と4攻撃ごとのHPダメージ
- 基準: v177 main。TRAININGの赤いキューブが横移動し、セラとの距離で接近・後退するよう `scripts/training_target_motion.gd` を追加。位置はXZ平面に制限、初期位置を中心に10m圏内、移動速度1.55m/s。攻撃予告中（ロック時の発射位置/向きを維持）、敵の弱怯み/部位破壊・撃破中は停止。
- 移動キューブのコライダーをAnimatableBody3Dに変更し、グラフィック・判定・床影の位置を同期。既存のプレイヤー接敵/カメラ追従/近距離ステップロジックを流用。新しい移動位置がプレイヤーとの衝突を新規に生じさせる場合は移動を抑止。
- `scripts/enemy_shooter.gd` の命中通知に発射時点の攻撃種別を追加。AIM/LEAD/SHOCK/ARCの基礎HPダメージを18/22/28/34、ガード時SH消費を23/28/36/42へ分離。防御率は既定どおり全身5部位平均、ガードSHは左武器/両腕補正を適用。ガードブレイク後の追加被弾にも攻撃別HPダメージを適用。
- HUDに被弾量の短い数字表示、ターゲット移動ON/OFFテストボタンを追加。HP0時は訓練専用に2.5秒でHP/EN/SH・配置を回復して再試験できるようにし、正式な敗北仕様にはしない。
- 既存A/B装備データ、攻撃4種・予告、効果音、ロックオン、セーブ、ガード/バッシュ/ステップ操作は維持。追加 README_v178_ja.md、tools/v178_target_motion_damage_self_check.py。旧v177専用検査はv178でSKIP。Godot構文実行/Android実機は未検証。


## v179（2026-11-09） — プレイヤーHPバー・HP0暗色化・最終ダメージポーズ固定
- 基準v178 main。訓練HUDの既存敵HPバーを残したまま、SERAのHPバー（装備5部位の合計最大HPに追従）を並べて追加。被弾時にバー長・閾値色（50%で橙、25%で赤、0でDOWN表記）を更新。EN/SH/防御率表示は維持、文字列操作ヒントを省きHPバーと干渉しないようにした。
- HP0の訓練KOでは `scripts/sera_rig.gd` に `set_training_ko(true)` を導入し、現在のクリップ/各種割り込み操作に関係なく `Damageknock` の `last_key_time` を使った姿勢を即時適用してプロセス停止。ループ指定のクリップでも最終キーフレームへ留める。通常ダウンは対象外。
- 新規 `shaders/sera_ko_dark.gdshader` はオリジナルA/B材質やテクスチャを変更せず、材質オーバーレイ優先度で一時的に暗色化。復帰時は暗色を解除して元のカラー/剣閃オーバーレイを復元し、待機アニメーションへ戻る。
- HP0から既存2.5秒の訓練復帰でKO解除、HP/EN/SHを全回復、HPバー満タン。対象変更: `scripts/main.gd`, `scripts/sera_rig.gd`, `shaders/sera_ko_dark.gdshader`, `project.godot`。追加: `README_v179_ja.md`, `tools/v179_ko_visual_hp_bar_self_check.py`。歴史的v178専用検査はv179でSKIP。**Godot実行およびAndroid実機確認は未実施**。
- KO中の残像保持を防ぐため、`sera_rig.gd` に `_clear_motion_afterimages()` を追加。KO開始時に既存3枚を消去し、KO中は新しい残像を生成しない。


## v180（2026-11-09） — プレイヤー最大HPを全パーツで1/5へ調整
- A/Bの5ボディパーツにある`hp`寄与値のみ0.2倍化：Aは頭/腕/脚/ブースター各20・胴体80（合計160）、Bは頭/腕/脚/ブースター各26・胴体104（合計208）。混合装備でも5部位のHP合算方式と胴体50%の設計を維持。
- 防御率・武器/移動・EN/SH・敵HP/攻撃ダメージの各パラメータは不変。TRAININGのHPバー・HP0 KO・復帰HPは`part_stats.max_hp`から動的取得するためそのまま新しい数値へ追従。
- 更新：`scripts/sera_part_stats.gd`, `project.godot`, `tools/v179_ko_visual_hp_bar_self_check.py`, `DEVELOPMENT.md`。追加：`README_v180_ja.md`, `tools/v180_player_hp_self_check.py`。Godot/Android実機動作未確認。


## v181（2026-11-09） — 近接ブースト性能の装備参照とバッシュの0.6秒追尾
- `scripts/sera_part_stats.gd` のbooster各セットに `melee_boost_speed` と `melee_boost_duration` を追加。A=11.5m/s（旧近接接近速度を維持）・1.0s、B=9.5m/s・1.2s。旧 `approach_speed` 項目を置換。
- 通常攻撃：既存 `meleeboost` 準備クリップが最終キーフレームに達した後、`DASH` 追尾移動中の速度/最長持続時間をブースターの新規ステータスから取得。毎フレーム移動ターゲットの現在地を追い、射程内に到達した場合のみ`melee1`へ。時間切れ・EN消費失敗なら追尾終了、射程外ヒットは発生しない。
- バッシュ：ガード前フリックと3段コンボ後の前フリック共通で`BASH_TRACK`へ移行。従来の`meleeboost`姿勢を使い、装備別近接ブースト速度でターゲットを0.6秒追尾。接敵しても0.6秒待ち、経過後に本来の`Bash`を発動。敵が射程外なら空振り。追尾移動のみ従来のEN消費補正を適用、EN不足でも固定時間後バッシュ自体は発動。
- BASH_TRACK中のタップは従来と同様バッシュ後の格闘1段目へ一回だけバッファ。ガードやコンボ入力、カメラ、手持ちのモデル/SE等は維持。HUDで移動速度・残り時間/バッシュ追尾時間を表示。
- 変更：`scripts/main.gd`, `scripts/sera_part_stats.gd`, `project.godot`。追加：`README_v181_ja.md`, `tools/v181_bash_homing_melee_boost_self_check.py`。v180のバージョン固有チェックはv181でSKIP。Godot/Android実機テスト未実施。


## v182（2026-11-09） — 近接追尾時間短縮・バッシュ/格闘2・3段の振りかぶりキーループ・攻撃中追尾
- ブースター：近接ブースト速度A11.5/B9.5m/sは維持し、`melee_boost_duration`をA0.4/B0.6秒へ変更。通常1段目は従来の`meleeboost`準備後に最大時間だけ移動追尾して射程到達後`melee1`開始。
- バッシュ：追尾最大0.2秒。ガードからの前方フリック・格闘3段目からの前方フリック双方で`BASH_TRACK`。追尾中は実Blockbench`Bash`の0〜0.20833秒を折り返しループし、射程到達時に即ループを解除・打撃へ移る。範囲外で0.2秒経過したら攻撃せずキャンセル。
- 格闘2・3段目：`STRIKE_TRACK`状態で各0.2秒の追尾。2段目`Melee2`の0〜0.08333秒、3段目`Melee3`の0〜0.20833秒をループし、射程到達で即ループ解除・打撃。追尾タイムアウトはキャンセル。
- 全格闘段/バッシュ：**攻撃モーションが始まった後も、命中が確定するかモーションが終了するまでターゲットの最新位置を追う**。EN不足は移動停止、ヒット判定は従来の刃スイープ/距離補助やバッシュ接触判定を維持。バッシュ接触判定は攻撃キー0.25秒以降、打撃モーション終了まで複数フレームで再確認し、移動ターゲットに対応。
- リグに`start_attack_windup`/`release_attack_windup`と折り返しループを追加。元モデル・キーフレームを変更せず、ループ解除時は0.025秒補間。既存コンボ、ヒットストップ、ガード入力、SE、HP、装備ステは維持。
- 更新`scripts/main.gd`, `scripts/sera_rig.gd`, `scripts/sera_part_stats.gd`, `project.godot`、新規`README_v182_ja.md`、`tools/v182_homing_keyframe_self_check.py`。旧v181版固有検査はSKIP。**Godot実行/Android端末での体感確認は未実施**。


## v183（2026-11-09） — 追尾解除時に振りかぶりモーションをスキップしない
- v182の`release_attack_windup()`が`clip_time`を予備動作の最終キーへ飛ばしていたため、射程到達が早い場合に`Bash`/`Melee2`/`Melee3`の予備動作が省略されていた問題を修正。
- 往復ループ解除時に`attack_windup_active=false`とするだけで、現在の`clip_time`から同じモーションを通常再生。途中のキーフレームを飛ばさず振りかぶりを最後まで表示。即射程内で追尾終了する場合も0秒から再生する。
- 追尾時間（A初段0.4秒/B初段0.6秒、バッシュ/2段/3段各0.2秒）、追尾終了条件、攻撃中の命中まで追尾、EN消費、ヒット判定、モデル原本はv182のまま。
- 変更`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`、旧版専用検査`tools/v182_homing_keyframe_self_check.py`をv183でSKIP。追加`README_v183_ja.md`と`tools/v183_windup_release_self_check.py`。Godot/Android実行は未検証。


## v184（2026-11-09） — 通常攻撃の発動距離を敵表面から1.0mへ変更
- `scripts/main.gd` の `MELEE_SURFACE_REACH` を0.75mから1.0mへ変更。通常格闘1～3段目の追尾終了・攻撃モーション開始・未命中の攻撃中追尾停止・近接UI射程に適用。
- 意図しない変更を避けるため、元は`MELEE_SURFACE_REACH + 0.20`だったバッシュ専用射程を定数0.95mに固定。距離命中補助も独立定数`MELEE_HIT_ASSIST_BASE_REACH=0.75`とし、旧A=0.83m/B≈0.82mを維持。剣3D判定・既存タイミングは変更しない。
- A/B格闘1段目追尾時間0.4/0.6秒、2・3段目とバッシュの追尾時間各0.2秒、追尾速度・モーション・EN消費を維持。
- 更新`scripts/main.gd`,`project.godot`,`DEVELOPMENT.md`,旧v183バージョン固有チェックSKIP。追加`README_v184_ja.md`,`tools/v184_melee_start_range_self_check.py`。Godot/Android実機未検証。


## v185（2026-11-09） — 通常格闘の発動距離を敵表面から2.0mへ
- `scripts/main.gd` の `MELEE_SURFACE_REACH` を1.0から2.0mへ変更。通常格闘1/2/3段目の追尾終了、攻撃モーション開始、攻撃中の追尾停止、近接射程UIのみに反映。
- バッシュ射程0.95m、格闘の距離命中補助基準0.75m（A頭部0.83m、B約0.82m）、剣の3D当たり判定と攻撃判定時刻は維持。2.0mは命中確定距離ではない。
- A/B追尾時間0.4/0.6秒、格闘2/3段・バッシュ追尾各0.2秒、EN、装備ステータス、モデルは維持。
- `project.godot` をSERA v185へ更新、`README_v185_ja.md` と `tools/v185_melee_start_range_self_check.py` を追加。v184固有テストはv185でSKIP。Godot/Android実機テスト未実施。


## 2026-11-09 — SERA v186: standard-rig Head C (source: storage/頭C (2).bbmodel)
- Integrated head-only set C under a new `Waist3/Torso3/Chest3/Neck3/Head3` group chain in `models/SERA_BOOSTER_allテスト.bbmodel`, preserving A/B and all 23 source animations. Original head source retained in `models/storage/`.
- Retargeted original Japanese `首` / `頭` parent groups from common pivot Y=11.5 to base Neck Y=23 / Head Y=25. Retained relative mesh offsets and authored sizes. Baked source element X-rotations into the imported mesh vertices to compensate for the current mesh loader's position-only handling of element transforms.
- Regenerated `assets/sera_equipment_data.gd`; new C candidate appears only in the `head` slot. Project title is `SERA v186`; dedicated static regression test `tools/v186_head_c_self_check.py` added.
- Static JS checks: original A/B group/mesh/animation JSON unchanged; C mesh hierarchy, face/UV preservation, UUID uniqueness and embedded snapshot JSON round-trip passed. Godot runtime and Android editor/device rendering not executed. See `README_v186_ja.md`.


## 2026-11-09 — SERA v187: Head C model proportions and C-only tint
- Screenshot showed C head oversized (width 20 vs A head 6) and pale. Rescaled only C head and neck to 0.32 about local mesh bounding centers, preserving their shape and using absolute target centers [0,27.4,0] for head and [0,24.4,0] for neck.
- Kept all A/B geometry, 23 animations, standard skeleton, original user .bbmodel, group hierarchy, UUIDs and original C UV/face data. Applied only C's material override (neutral steel gray); B red untouched.
- Rebuilt embedded equipment snapshot. Bumped project title to v187, updated dedicated test and made v186 historical snapshot test skip on newer releases.
- JavaScript static checks passed for dimensions, head-neck overlap, A/B and animation preservation, UV/face preservation, and generated embedded JSON consistency. Python and Godot/Android runtime checks not executed.


## 2026-11-09 — SERA v188: Head C enlarged 1.5x
- Increased only C head (`HeadC_Head_torus`) and neck (`HeadC_Neck_tube`) vertex positions by 1.5 relative to v187; resulting widths 9.6 and 5.952 Blockbench units. Local mesh origins, group pivots, UUIDs, faces/UVs, material, A/B parts and 23 animations unchanged.
- Updated `assets/sera_equipment_data.gd`, Godot project name to `SERA v188`, versioned README and static check. v187 fixed-proportion test is now historical and skips on newer versions.
- JS data validation: each mesh axis scales exactly 1.5, original A/B and group/animation data identical, embedded JSON roundtrip. Godot/Android runtime NOT TESTED.


## 2026-11-10 — SERA v189: bird-leg D lower body and corrected Head C pivots
- Registered the user's latest `models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel` as the bird-leg source. The A rig and its source/animation data are preserved; six new bird bones are built below the existing Waist at runtime, and 10 bird meshes form LOWER BODY = D. A/B legs still exist, and selecting another set hides bird meshes. D initially inherits A mobility/combat stats.
- In Godot, import the dedicated bird keyframe tracks onto the same clip timeline as A's upper body. The latest six-key bird `NEXUS_pose` is used in the exhibition preview. For un-authored `run_back`, `run_right` and `Jump`, use existing bird front/left/neutral keys as explicit temporary fallbacks; do not claim those are custom animations.
- Updated C head from `models/storage/頭C (2) (1).bbmodel`: corrected source neck/head pivots ([0,1.3,-0.2], [0,7.5,2]) are mapped to the A Neck anchor using 0.48 uniform scaling, maintaining v188 widths 9.6 and 5.952. Preserve source-authored mesh local rotations (-15°/20°), and use C-only head pivot tracking so A/B heads remain unchanged.
- Rebuilt `assets/sera_equipment_data.gd` and generated `assets/sera_bird_data.gd`; included reproducible `tools/rebuild_bird_data.py`. Changed `scripts/sera_rig.gd`, `scripts/sera_equipment.gd`, `scripts/command_nexus.gd`. Project title is `SERA v189`.
- Static JSON verification and consistency checks only; no Godot editor/headless/Android runtime test performed. Check model attachment, pose, mirror legs/ground contact, custom head pivot and afterimages on Xperia 1 V.

## 2026-11-10 — SERA v190: directional back-run yaw, geometry contact footfalls and tall-sole ground matching
- Fixed backpedal-root yaw for right-side retreat by making the 180-degree yaw branch depend on signed target-relative travel X. Previously the unconditional -PI branch could take right-back through the long arc. Keep run direction, controller, smoothing constant, retreat hysteresis, target camera, movement and existing clip samples unchanged.
- Added model foot contact events from the actual left/right sole meshes. Each foot must rise at least 5.5 cm then touch at most 2.0 cm relative to its rendered ground reference to play a brief 0.14-second synthesized original metal step sound. Disabled footfalls for stationary, BOOST, air/other actions and limited to at most one per 0.13 sec. No copyrighted sound recordings used.
- When a lower-body set is selected, measure the original bind-pose sole height of its meshes and shift the visual Sera rig so the selected foot bottom matches A's. For soles extending below A, the model becomes taller; extend only the capsule's height, preserving its original ground-side point and radius. Recompute only on equipment changes, not every animation frame. All three A/B/D sets supported.
- Preserve authored bird-foot mesh tilt (-22.5°), which the v189 model builder previously dropped; A/C and original data preserved.
- `scripts/sera_rig.gd`, `scripts/sera_equipment.gd`, `scripts/main.gd`; static/geometry regression `tools/v190_foot_contact_grounding_self_check.py`; `README_v190_ja.md`. Project title `SERA v190`.
- Limitations: The gameplay floor is still virtual XZ and feet use visual detection rather than physics contacts. Animated per-frame foot IK, sloped terrain and a guaranteed grounded pose are NOT implemented. Xperia 1 V sound timing/audio and graphical rendering remain unverified.


## 2026-11-10 — SERA v191: normalized Foot C standard-skeleton boots
- Integrated user-provided `models/storage/足C.bbmodel` into the established `models/SERA_BOOSTER_allテスト.bbmodel` as the **C lower-body option** (alongside independent C head; D bird legs kept). Source original retained verbatim.
- Determined source mirrored left/right feet from ±14.1 Blockbench X pivots despite "右足2" group name. Used ONLY the four sole meshes inside "右足" and "右足2": other source waist/thigh/knee meshes are NOT imported. Each sole has two independent convex mesh sections.
- Converted original source feet from 16-wide / 8-tall / 30.9-long to target dimensions 4.64 x 4.56 x 8.961 Blockbench units, compared with standard A sole 4 x 4 x 8 (width +16%, height +14%, length +12%). X/Z source scales 0.29, Y 0.57; resampled source pivot at ±14.1/13.7/0 into A Foot_L/Foot_R pivots at ±2/4/0. Bottom sole Y=0 unchanged.
- Appended six C groups `Thigh_L3/LowerLeg_L3/Foot_L3` and mirrored right side to existing C Waist root; duplicated only six standard A hip/thigh/shin meshes with fresh UUIDs so C option has a **complete lower-body set** and selecting C does not hide those areas. The standard A/ B sets, C head meshes and all 23 animations were unchanged.
- Rebuilt `assets/sera_equipment_data.gd`. Limited C's neutral gray tint specifically to `HeadC_*` meshes so new C feet and copied A legs preserve the original palette. No new animation tracks or bone type required: the existing A leg pivots and motion drive the new feet.
- Gameplay title `SERA v191`; dedicated test `tools/v191_standard_foot_c_self_check.py` and documentation `README_v191_ja.md`. Android/Godot runtime appearance and gait/sole-grounding need phone verification.


## 2026-11-10 — SERA v192: Foot C is independent FEET equipment; fix NEXUS preview displacement
- **Root cause**: v191 imported four real Foot C meshes but exposed them only as whole LOWER BODY C, so no selectable FOOT/FEET row appeared. v190 foot-grounding code also moved the **entire exhibition rig root** when loading a saved D bird leg selection or changing legs in NEXUS, invalidating the camera-relative preview fit and pushing SERA off-screen.
- Introduced independent FEET slot A (standard shoe for selected human legs A/B) and C (user's Foot C); lower-body selection now A/B/D. While D bird skeleton is chosen, its own foot meshes win; the saved human FEET choice remains available when switching back to A/B. All six original standard leg bones and their clips remain intact, Foot C meshes are attached to A's Foot_L/R animation pivots.
- Registered `C_FootC_L_1/2` and `C_FootC_R_1/2` under the feet slot by source-derived name, not the generic C full-body leg clone. Existing C-only underbody duplicate authoring meshes are retained but do not appear as a lower-body choice. Head C remains independent.
- Centralized equipment visibility so selecting FEET C hides only standard A/B shoe meshes, never thighs/shins/torso, and D bird feet are never hidden by FEET toggles.
- Exposed `SeraRig.set_exhibition_mode(true)`; NEXUS invokes it immediately after instantiating display SERA and **before** recording the original transform or fitting the screen. It disables all sole-height-driven root offsets in NEXUS; training keeps the v190 height adjustment, collision and foot-contact audio.
- Expanded NEXUS PARTS/SETS panel to 8 rows with FEET A STD / C BOOT and extended `SeraSave` profile persistence to FEET. Legacy v191 `legs=C` choices migrate automatically to `legs=A, feet=C` without deleting saves.
- Project title `SERA v192`, dedicated static validation `tools/v192_foot_slot_preview_self_check.py`. No original .bbmodel/animation/audio/texture changed. Godot/Android display acceptance pending.


## 2026-11-10 — SERA v193: lower-body D is the complete new human leg, remove FEET
- The user clarified that `足C.bbmodel` was a **complete LOWER BODY** equipment set, not separate shoes. v192's FEET row was an incorrect design interpretation; remove it and restore the original seven equipment slots (HEAD, TORSO, LOWER BODY, ARMS, BOOSTER and two weapons).
- LOWER BODY **D** now contains **all 12 user-authored source meshes** from `足C.bbmodel`: two pelvis, four thigh, two shin and four boot meshes. The six v191 baseline A clone meshes have been replaced by user geometry, and two additional thigh meshes added. Each section is normalized to corresponding A skeleton pivots and a 10% larger volume; boots remain 16% wider, 14% taller and 12% longer. Preserves standard A skeleton and shared motions; C Head stays independent.
- To prevent overwriting the bird-leg asset previously assigned D, reassign bird LOWER BODY to **C** (same six bird bones, same animation clips and mesh source). `scripts/sera_equipment.gd` routes the existing authoring Waist3 C head meshes to HEAD=C, and human lower-body geometry to LOWER BODY=D. Original user storage .bbmodel and canonical A animations stay untouched; the combined authoring model and embedded equipment snapshot were regenerated.
- Preserve Nexus screen-space preview height isolation introduced in v192. TRAINING keeps the v190 foot-grounding, foot sound and capsule adjustment, now selected exclusively via LOWER BODY A/B/C/D.
- New save schema version 2 migrates version 1 saved preferences exactly once: old bird LOWER BODY D→C, old v191 human LOWER BODY C or v192 FEET C→D, and all other equipment (including HEAD C) unchanged. Global cfg has the same one-time migration with an explicit schema marker; repeated loading or saving v193 IDs cannot swap C/D again.
- Update `scripts/command_nexus.gd` to remove FEET and distinguish C BIRD / D NEW; *only the D replacement model's source geometry was normalized*, with source face/UV identity preserved. Movement, combat, camera, audio and touch input remain unchanged. README_v193_ja.md and static migration/slot validation test added.
- **GitHub static verification only; Godot Android runtime behavior to verify after GitSync.**


## 2026-11-10 — 標準骨格「脚C」更新単体ファイルの正規化（ゲーム版はv193のまま）
- 更新された models/storage/足C (1).bbmodel を調査。従来原本と同じ12メッシュ/面/UVを持ち、右側のPivotと片側のメッシュ原点（ローカル頂点の相殺移動）が変更されたことを確認。
- 右の関節階層に左側メッシュが混在し、左足のPivotも反対側へ移動していたため、SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel に腰・左右の腿/膝下/足の7関節を作成し、12メッシュを独立して命名。元のメッシュ形状・原点・UVを変えず正規化。
- 現行v193の標準骨格下半身Dだけを SERA_LOWER_BODY_D_STANDARD_READY.bbmodel へ切り出し、元の統合ファイルとAのモーションを維持。
- docs/LEG_C_STANDARD_SOURCE_ja.md と tools/legs_c_standard_source_self_check.py を追加。**素材の準備のみ**のためゲーム版・保存形式・ゲーム表示は変更なし。Androidでの従来の表示問題は引き続き要検証。


## 2026-11-10 — SERA v194: LOWER BODY D is loaded explicitly from the dedicated standard-leg asset
- Previous v193 used the combined Blockbench Waist3 root for both HEAD C and the new human LOWER BODY D; D was inferred indirectly from set C's root index. The user reported that the new lower-body appeared like the default foot despite the D selection.
- Runtime now reads models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel directly in scripts/sera_equipment.gd, with a separate export fallback embedded at assets/sera_lower_body_d_data.gd. The source is the canonical normalized A-rig geometry previously prepared from the updated 足C (1).bbmodel.
- Prevent the generic C head traversal from also registering duplicate D leg meshes. Require exactly 12 dedicated D meshes (pelvis 2, thighs 4, shins 2, feet 4) attached to A's existing animated joint pivots before exposing LOWER BODY D as an equipment option; fail closed on incomplete imports.
- Retain C bird legs, C head, A/B meshes, seven customization slots, one-time v2 save migration, footstep/grounding, animations and all gameplay logic. No modification of the authored geometry or existing combined source. Godot project display name SERA v194.
- Added tools/rebuild_lower_body_d_data.py and tools/v194_lower_body_d_customization_self_check.py, plus README_v194_ja.md and CI. Static checks do not verify Android display or movement.


## 2026-11-10 — SERA v195: restore authored lower-body D silhouette
- The v193/v194 D model retained 12 meshes and correct names but had independently compressed the waist, thighs, shins and boots to approximate A segment bounds, giving an A-like silhouette. Comparing Blockbench with Xperia customization exposed the visual mismatch.
- Generate both runtime-ready D and combined authoring D geometry from the exact updated author source, using one uniform scale (0.36) and a single source sole offset (0.2), preserving each mesh's geometry, cross-segment proportions and UVs. Both snapshots are regenerated.
- Render D using the authoring color indices: rose waist/leg armor (1/3), blue boots (5), rather than sampling the unrelated SERA base 96x32 atlas with 16x16 UVs. A/B/C meshes and colors are unchanged.
- Add tools/rebuild_lower_body_d_from_author.py, v195 geometry/color test, README_v195_ja.md and CI verification. Keep the original user Blockbench files and all animation tracks. Android Godot visual and animated knee/ankle alignment are pending device verification.


## 2026-11-10 — SERA v196: adaptive NEXUSpose arm clearance for current lower body
- Only in the NEXUS display rig: capture the user's actual NEXUS_pose shoulder and upper-arm quaternions as immutable rest angles after sampling authored animation. The combat rig and the original animation files stay untouched.
- On startup, after lower-body/arms customization changes, or after loading another system profile, first restore both arms to the precise NEXUSpose angles. Read the equipment handler's *currently visible* meshes for selected LOWER BODY and ARMS; compute their rig-space rotated AABBs from actual mesh bounds and exclude hidden variants.
- Check collisions independently for L/R. If an arm is not intersecting, leave both its joints at exact original rotations. If intersecting, raise outward with ±Z rotation in 1.5-degree increments for upper arms (up to 90°) and 0.3-degree steps for shoulders (capped at 8°), and stop at the earliest collision-free geometry with 0.018 game-unit margin. No permanent or per-frame rotations.
- Trigger silhouette refresh after arm fit; preview camera transforms and grounding remain untouched. Preserve all 7 equipment slots, bird C, standard D, base animation tracks, player controls, and saved selections.
- Static v196 checker/CI. Conservative oriented-mesh AABB clearance can overestimate narrow concave contours and maximum lift may not clear every future model; warn rather than falsely asserting clearance. Xperia Android NEXUS pose and appearance unverified.

## 2026-11-10 — SERA v197: stop over-lifting NEXUSpose arms
- User screenshot shows v196 raised arms near horizontal; angled mesh AABBs included excessive empty space and kept reporting collisions.
- AABB is now broadphase only, with a rig-local oriented-box (SAT, 3+3+9 separating axes) narrowphase for actual arm/leg meshes.
- Maximum additional lift is 24° upper arm (16 × 1.5°) and 3.2° shoulder (16 × 0.2°). Begin at original NEXUSpose, choose first collision-free result, else earliest angle with fewest overlaps, or exact original if nothing improves.
- NEXUS-only behavior; no change to authored clips, model geometry, save schema or combat motions. New v197 regression and CI; Android visual check remains outstanding.


## 2026-11-10 — SERA v198: show version on selector, training and NEXUS
- Added a single `scripts/version_indicator.gd` RefCounted helper. The label reads `ProjectSettings.get_setting("application/config/name")` and shows exactly the current Godot project version without a duplicated numeric constant.
- `scripts/launch_menu.gd` adds it to the full-rect startup Control; `scripts/main.gd` adds it to the existing combat CanvasLayer; `scripts/command_nexus.gd` adds it to the full-rect NEXUS HUD.
- The label is 14px, top-right (right margin 14, y=3..25) and ignores all touch/mouse events; training HUD begins below it at y26. No scene navigation or combat input changes.
- Updated `project.godot` name from `SERA v197` to `SERA v198`. Older v197 regression version assertion is now forward-compatible. New `tools/v198_version_indicator_self_check.py`, README_v198_ja.md and CI step. Godot Android UI is not yet device-tested.


## 2026-11-10 — SERA v199: animated-foot grounding on the visual training floor
- User screenshots showed LOWER BODY D feet floating above the training floor during Wait_motion and motion changes.
- Prior `scripts/sera_equipment.gd` computed a bind-only Y offset when switching a leg set, with the sole measured from rotated AABB corners. It failed to follow animated hip/root motion and could select imaginary low corners for tilted feet.
- New `_mesh_lowest_y()` caches actual triangle vertices from each visible foot mesh via Mesh.surface_get_arrays and transforms them to rig-local coordinates per frame. New `snap_grounded_sole_to_floor()` aligns the lower of left and right soles to the top of the visible training grid Y=-0.0335 after the current animation pose, including initial idle frame.
- Applies only in grounded training (skips jump playback, player above plane, and NEXUS preview/exhibition). Only visual rig translation; no changes to Player physics, floor collision, movement speed, camera, equipment selection, saved preferences, A/B/C/D mesh geometry, animation tracks or footfall event logic.
- Keep the old static bind correction for the collision-height extension (separate from per-frame render correction). New v199 static+numeric regression, CI, README. Android rendering/foot contact must be checked on Xperia.

## 2026-11-10 — SERA v200: RUN audible-contact grounding only; full-circle step
- v199 snapped every animated pose to the visual floor. v200 restores the previous bind-based rig Y after each animation update; only Wait_motion snaps every frame and RUN snaps on the exact foot_contact sound signal frame. Attack, shield bash, guard, steps, boost, damage and airborne clips are not dynamically grounded. NEXUS exhibition still disables foot correction.
- Release flick now returns a normalized vector for all screen angles, including UP and diagonals, with original short/fast/reversal/boost/guard precedence. Target-relative polar path retains original side orbit, four-meter backward step, adds a provisional two-meter forward step, and continuously blends diagonals. Gameplay collision sweep and 8–10m/s step velocity remain unchanged.
- Four authored poses Step_L / Step_R / Backstep / Boost_front are directionally blended. Start fade is 0.12s; end fade is 0.16s; avoid looping the step timeline at long durations. No authored mesh, animation asset, save or input ring changes.
- SERA v200, new CI regression and README. Android real-time behavior unverified.

## 2026-11-10 — SERA v201: prevent BOOST/RUN flicker during a held EN-depleted gesture
- When BOOST EN ran low, _spend_energy could refuse a frame while energy_exhausted was still false. After energy regenerated, the static finger outside the BOOST entry radius would automatically re-confirm BOOST, producing repeated BOOST/RUN state changes without a new gesture.
- A new boost_rearm_required latch is set when BOOST is interrupted by insufficient EN or EN exhaustion (including a successful final expenditure to exactly zero). Keeping the same held finger outside the existing 159.6px exit boundary never restarts BOOST during EN regeneration.
- The latch clears only when that finger moves inward below the existing exit radius, or on a new touch. Outward movement again requires the existing 184.8px entry radius and 0.10s confirmation. Normal 1.10/0.95 hysteresis is unchanged.
- Leave RUN/BOOST 0.20s speed interpolation, 0.50s BOOST pose grace, EN drain and recovery, gameplay moves, camera, equipment, models and UI unchanged. The old v200 regression now accepts subsequent project versions.
- Added README_v201_ja.md and tools/v201_boost_hold_rearm_self_check.py. Static/source checks and a numeric state model do not verify Godot runtime or Android touch behavior.

## 2026-11-10 — SERA v202: small upper-left HP/EN meters and 60% post-depletion lock
- Replace the wide right-side player HP bar with a narrow, two-row, non-interactive HP/EN Control (scripts/combat_vitals.gd) in the left side of the existing compact header. Preserve the upper input controls. Shift target HP status/bar to the right and DEF/SH telemetry under center buttons, removing duplicate numeric EN text.
- Both meters use animated border opacity, not blinking fill or visibility. HP positive <=25% shows a smooth 1.25Hz warning border; HP=0 is static dark. EN positive <=25% when usable shows a 1.25Hz warning border; EN=0 gives a 4Hz empty warning border; recovering EN between 0 and <60% is dim until normal colors return upon unlock.
- EN costs are globally blocked once energy_exhausted is set (except true zero-cost actions). The lock clears at 60% of TEST_EN_MAX instead of v177's historical 16 EN; EN regeneration amount and pause are unchanged. When the final BOOST drain cannot be paid with tiny remaining EN, the remaining EN is exhausted (zeroed) so recharge lock cannot be bypassed. v201 thumb-return BOOST rearm remains independent.
- Add README_v202_ja.md, tools/v202_combat_vitals_self_check.py. Keep enemy debug row, target HP, damage effects, existing equipment/animations/movement. Source checks and numeric state simulation do not replace Godot/Android acceptance.
- For equipment whose guard drains EN, disallow guard entry during the recovery lock and end an already held guard if EN becomes unavailable; ordinary non-energy guards are unchanged.

## 2026-11-10 — SERA v203: NEXUS training target defaults and highlighted training start
- The TRAINING focus panel now has three independent tap-to-cycle defaults: target motion MOVE/HOLD, automatic attacks ON/OFF, and attack type AIM/LEAD/SHOCK/ARC. Values are stored in `user://sera_training_defaults.cfg` (global device preference, independent of profile equipment).
- `scripts/main.gd` loads these defaults before the target/AI/UI are built. Default motion sets the existing MOVE debug control, and the AI attack mode/auto-fire are initialized before `add_child()`, retaining its original opening cadence. The debug selector displays those same initial states without emitting callbacks. Existing in-training controls still work and do not overwrite the saved starting defaults.
- The existing TRAINING START action stays in the same bottom panel hit zone, now a high-contrast cyan bordered call-to-action with a slow 1.8s breathing glow. Other NEXUS destinations, training combat behavior, equipment, save slots, and raw touch routing are unchanged.
- `README_v203_ja.md` and `tools/v203_training_defaults_self_check.py` document/check this contract. JS-level source checks performed before GitHub commit; Godot/Android runtime acceptance pending.


## 2026-11-10 — SERA v204: heavy-leg SLIDE motion and D weight class
- LOWER BODY B (already heavy) and D (newly designated heavy) use the same existing Boost_front/back/Left/right poses for ordinary ground RUN. This non-boost locomotion is named SLIDE in a separate rig state; A and C retain their ordinary RUN gait.
- D now has an explicit heavy stat profile equal to B pending future balancing (HP26, defense0.30, run_speed3.35, boost multiplier0.82, damage duration1.1, damage push0.60, down hits5). No independent D balance is inferred. C still falls back to A.
- Confirmed BOOST input and the heavy SLIDE are distinguished from the displayed Boost_* animation; BOOST pose grace is preserved but is not propulsion. Future thruster intent has two channels: SLIDE -> legs on/back off, confirmed BOOST -> legs and back on; actual particles/meshes are not yet created.
- BOOST/STEP temporal afterimages continue to originate solely from real BOOST input/STEP, never from SLIDE. Movement physics, EN, boost thresholds/pose grace, directional blend, contacts, camera, touch controls, all source .bbmodel assets and saved slots remain unchanged.
- Update SERA v204, README_v204_ja.md, tools/v204_heavy_leg_slide_self_check.py and model policy CI check. Structural checks do not replace Godot Android playback or effect inspection.


## 2026-11-10 — SERA v205: Chest-mounted Blockbench back-booster mockup
- Extend only the canonical combined Blockbench authoring file `models/SERA_BOOSTER_allテスト.bbmodel` with `Chest/BOOSTER`, a rectangular shell and two symmetrical 8-sided hollow jet tubes under `Thruster_L` and `Thruster_R`, each with a dark inner disk. Point exhaust toward +Z (rear) and mount to the lower part of the box. Keep all original 63 elements, 54 groups and 23 animations byte-equivalent in structure; five new mesh elements, three new groups and unique UUIDs.
- In `scripts/sera_equipment.gd`, import this group from the authoring A Chest explicitly, as meshes under an independent `booster` slot attached to the unchanged original animated A Chest. Booster A and B temporarily use duplicate instances of the same grey placeholder so either customizer setting works. This is independent of TORSO=A/B selection, and uses existing mesh/afterimage infrastructure.
- Rebuild `assets/sera_equipment_data.gd` from the new authoring geometry (JSON-equivalent to the model's groups/elements/outliner) for fallback exports. No new animations, thrust effects, energy consumption, collision, movement input or booster activation behavior. v204 SLIDE/BOOST intent and FX separation are not modified.
- Add v205 static geometry/import/snapshot regression and README; Godot engine/Android/Blockbench rendering acceptance remains to be performed.


## 2026-11-10 — SERA v206: pivot-correct booster and directional rectangle exhaust
- Follow the user-edited `models/storage/SERA_BOOSTER_allテスト (4).bbmodel`: copy ONLY BOOSTER/Thruster_L/Thruster_R pivot data and five booster meshes (including mirrored right nozzle winding) to the canonical combined model, preserving its 4-root rig and all 23 animations. Do not import the storage model's detached Hand_L and other unrelated authoring changes.
- Fix incorrect `parent.add_child(piece)` in the v205 booster importer: attach meshes to their own pivot, honor nested absolute Blockbench pivot deltas and quaternion rotations. Locate each exhaust root using the imported outer nozzle's authored origin and actual positive-Z lip vertices, so future pivot edits do not require magic numeric shifts. Regenerate embedded equipment JSON data.
- Add two-layer rectangular hollow exhaust tube with transparent glowing GL-compatible shader. Vertex distortion and opacity modulation make the tubes flicker and wobble; inexpensive 4-side geometry. No texture, particles, or gameplay modification.
- Use actual post-collision player displacement, invert the travel direction, transform into each nozzle's animated local frame, clamp yaw ±38° and pitch ±24°, and ease steering over 0.075s. Avoid abrupt 180° yaw on reverse steps. A/B booster selections have separate effect instances; only the selected set renders.
- Activate in genuine BOOST, all STEP directions, and real movement during melee stage 1/2/3 and Bash approach/homing. Never trigger from heavy-leg SLIDE, BOOST pose grace, ordinary RUN, inactive states or blocked-in-place pursuit. Preserve movement speed, EN rules, controls, target tracking, melee clips and afterimages.
- v206 README, static validator and CI step; Godot Android graphics/interaction remain untested.

## 2026-11-10 — SERA v207: held BOOST recovery, rear nozzle orientation and EN-empty red flash
- User video showed unexpected RUN dropouts during sustained movement and exhaust steering looking wrong. Retain the authored Blockbench back nozzle, pivots, ray origins, FX timing and mechanical ±38° yaw/±24° pitch limits; project impossible forward-pointing requests smoothly toward rear-center to eliminate atan2's left/right 180° discontinuity.
- Keep 110% (184.8px) hold-entry radius and 0.10s confirmation; lower BOOST exit threshold from 95% to 90% of 168px for stable touch hysteresis. Remove the v201 inward-touch rearm latch. After EN lockout ends at 60%, automatically re-evaluate the same held outer-ring gesture without new input. Release and standard guard/damage/step restrictions still stop BOOST; original 0.20s speed blend and 0.50s pose grace remain intact.
- Centralize the moment of EN exhaustion for exact-zero and per-frame insufficient BOOST spending; flash the player meshes red for 0.60 seconds at 7Hz with a dedicated overlay shader and retain original authored materials. KO overlay takes precedence, slash foreground overlay is restored afterwards. No new EN costs or change to resource recovery.
- Add README_v207_ja.md, v207 static check, workflow entry. Update the historical v206 test's project-version assertion to permit later SERA versions while preserving its v206 structural checks. Godot/Android visual + touch runtime verification remains outstanding.

## 2026-11-10 — SERA v208: asymmetric rear-thruster articulation limits
- At user request, change directional back exhaust angular limits relative to the authored local +Z rear axis: yaw left/right ±80°, pitch downward +90° and upward -1° (Godot rotation.x sign convention). Do not modify Blockbench pivots, meshes, animations or nozzle origin.
- Reduce reverse-direction yaw projection offset from 0.25 to 0.02 so full ±80° lateral articulation can actually be reached without introducing the reverse-movement yaw snap. Maintain independent yaw/pitch clamping, smooth 0.075-second steering, FX enablement and movement/EN/drag behavior.
- Add dedicated v208 static regression, revise v206/v207 compatibility tests to reflect the latest limits without erasing original pivot/EN checks, bump Godot project name and update model-policy CI. Godot/Android rendering unverified.

## 2026-11-10 — SERA v209: actual thruster nozzle pivot and RUN flicker stabilization
- User video shows run pose jolts while changing direction, and specified the physical 3D nozzle as the intended rotation pivot. v208 steered only the FX child while leaving both Thruster_L/R mesh groups fixed. v209 rotates the imported real Thruster_L/R group Node3D (which owns Outer/Inner meshes and the exhaust child), preserving authored pivots, rest quaternions, nozzle lip offsets and independent A/B equipment set visibility. Solve directional steering in the unrotated parent/rest basis so nozzle rotation cannot feed into the next target estimate. Keep yaw ±80°, pitch down +90° / up -1°, 0.075s damping, anti-180° steering and exhaust action gating; idle slowly returns physical nozzles to the authored orientation.
- RUN: retain the chosen retreat-side sign through the transient front/back blended gait, instead of recomputing its sign whenever the drag direction crosses rear center. This avoids the near-180° Waist visual snap without changing actual 360° input, attack states or movement velocity.
- RUN audible foot contacts no longer move the entire rig to the floor for one frame (and instantly return next frame). Keep the unchanged WAIT full sole snap and RUN foot-contact signal timing; on RUN footfalls move only the contacting boot meshes to the visible floor for that sound frame and restore their bind-local offsets before the next sample. This removes whole-body vertical flashes while retaining authored gait, selected leg geometry and world collider.
- Update v200/v206/v207/v208 historical structural tests to reference current behavior, add v209 regression and project version. Android Godot rendering/touch observation remains a separate acceptance check.

## 2026-11-10 — SERA v210: reverse BOOST and STEP use downward backstroke nozzle posture
- For backward BOOST and omnidirectional STEP away from the target, blend each physical Thruster_L/R pivot's yaw to neutral and its downward X pitch toward +90° (backstroke/swimming-backward appearance). Pure backward requests reach yaw 0° / down 90°; backward diagonals interpolate based on rearward input component. Forward/lateral inputs stay on the original projected world-exhaust vector.
- Explicitly pass a 0–1 backstroke weight from the existing combat controller through the rig/equipment to the nozzle FX steering. BOOST derives rearwardness from intended camera-ground movement dotted with the target-facing player's +Z (back) axis, rather than wall-clamped displacement; STEP uses the snapshotted positive target-relative Y flick and supports dedicated legacy STEP_BACK. Attack homing/tracking gets no new backstroke override.
- Retain v209 real Blockbench nozzle pivots/meshes/exhaust alignment, v208 independent ±80° yaw and down90°/up1° limits, 0.075s steering damping, unchanged authored motion and all resource, attack, touch and leg SLIDE mechanics.
- Add v210 static/numeric regression, update historical version/rig API tests, and maintain model policy CI. Godot Android visuals remain unverified.

## 2026-11-10 — SERA v211: authored Frontstep replaces provisional forward STEP pose
- Imported the newly synced user's `models/storage/SERA_BOOSTER_allテスト (5).bbmodel` animation `Frontstep` (static, 0.0-second single-pose authoring clip) by appending only the new animation; preserved all prior motions. The authored clip contains 57 potential animators across additional equipment groups; filter to the canonical A rig's 22 bone UUIDs for `assets/sera_source.json` (18 active keyed bones). Preserve the full authored clip in `models/SERA_BOOSTER_allテスト.bbmodel`. Do not import unrelated source mesh/pivot changes.
- Rebuilt `assets/sera_data.gd` from the exact canonical JSON bytes using the same 120-character base64 chunk format as `tools/rebuild_model_data.py`, so Android export has the new pose even without external files.
- Add `STEP_FORWARD_CLIP = Frontstep`, require it during rig load, and replace forward's provisional `Boost_front` cardinal in the omnidirectional STEP sampler with `Frontstep`. Forward+side diagonals continue spherical quaternion and position interpolation. Existing sideways/back steps, RUN, all four BOOST poses, heavy-leg SLIDE, fade times, travel distance/collisions, EN and camera behaviors remain unchanged.
- STEP FORWARD diagnostic label now names `Frontstep`. Historical v200 test updated for the newly authored forward pose; v194/v195/v205/v206 model-count/legacy-clip tests allow appended animations while verifying existing lower-body geometry, equipment and original clips are intact. New v211 authoring/embedded-data regression runs in CI. Android/Godot visual runtime remains unverified.

## 2026-11-10 — SERA v212: heavy SLIDE half-strength and downward/left-input exhaust
- Heavy legs B/D keep their existing 4-way Boost_* directional SLIDE selection when RUN is requested without an actual BOOST input, but the displayed SLIDE posture is now the per-bone quaternion/translation/scale blend of the authored Wait_motion at t=0 (50%) and its current directional Boost_* pose (50% maximum). Actual held BOOST, independent of leg class, retains the unmodified full 100% authored BOOST pose. Keep the existing transition fade and separate FX activation intent.
- Both physical Blockbench Thruster_L/R nozzle pivots initialize with the local exhaust axis pitched down 90° even before first frame. With no active rear FX, nozzles ease back toward the same down90° default, rather than horizontal rest orientation. No Blockbench model or pivot-origin edit.
- During screen-left BOOST or left STEP, mix actual exhaust travel vector toward the camera-derived screen-right ground vector plus world DOWN (equal components): aim the physical nozzles and their attached rectangular jet FX toward screen bottom-right, consistent with a backstroke/swimming movement. Compute leftward factor from STEP snapshot flick X (or legacy side step) and BOOST joystick X, with diagonal fading; sample SCREEN right after the current camera/target facing update. Existing v210 rearward down90° override applies afterward for rear-left combinations.
- Keep nozzle yaw ±80°, pitch down90°/up1°, 0.075s damping, backward STEP override, original 360° STEP behavior, EN cost, movement speed, source animations and meshes. Add static/numeric tests and v212 README. Android rendered result is not verified.

## 2026-11-10 — SERA v213: screen-space 90-degree left nozzle sector
- LEFT BOOST/LEFT STEP steering now explicitly targets a quarter-circle in **screen coordinates** from straight DOWN (0°) to screen RIGHT (90°), with pure-left intent aiming halfway (45° bottom-right). Partial screen-left diagonal intents move smoothly from down toward 45°; the mechanical sector itself supports a full 0–90° interval.
- v212's blended world-exhaust vector was passed through the normal rotating-chest local yaw ±80° and pitch constraints, which could skew the actual 3D nozzle away from the desired on-screen direction. Instead, main.gd passes a dedicated camera-aligned left-sector world target through sera_rig.gd and sera_equipment.gd to back_thruster_fx.gd; the latter converts that direction using the **unrotated Blockbench nozzle rest basis** and rotates the actual physical Thruster_L/R node (with its rectangular exhaust FX) using Quaternion(Vector3.BACK, target_local). Preserve a 0.075-second smooth entry/exit to prevent a snap when switching to/from the ordinary yaw/pitch servo.
- Other directions keep the v208 signed ±80° yaw/up1°/down90° mechanical constraints; pure backward keeps the v210 down90° override and v212 default is down90°. Heavy-leg SLIDE remains 50% Wait_motion + 50% Boost_* with no rear FX; no gameplay input/camera/movement/EN/animation or model source changes.
- Add v213 static and geometry/numeric regression and adapt historical v206/v210/v212 tests to the explicitly extended API. Android Godot rendering unverified.

## 2026-11-10 — SERA v214: continuous nozzle exhaust while BOOST turn animation is visible
- Previously, v206-v213 gated rear-nozzle flames on confirmed BOOST physical movement input; v159/v162 kept the directional Boost_* animation visible for a 0.50-second thumb-turn grace and an additional 0.20-second BOOST→RUN crossfade, but shut off the exhaust when the BOOST movement flag cleared. The nozzle effect therefore flickered while SERA continued the BOOST turn motion.
- scripts/sera_rig.gd now exposes is_boost_exhaust_pose_visible(): true only during true Boost_* locomotion, its held BOOST visual pose, or the incomplete 0.20-second BOOST→RUN blend. Explicitly return false for heavyweight ordinary SLIDE (which reuses Boost_* clips), and action/step/guard/damage/airborne/training KO.
- scripts/main.gd activates rear FX when the existing gesture actually triggered BOOST and remains held while the rig's BOOST pose is visible. Preserve the original BOOST speed, EN expense and UI indicator rules: the extra flame is VISUAL only. During a neutral-thumb crossing, retain the last requested exhaust vector, backward weight and screen-left/right-down jet target so no direction snap or single-frame flash occurs; update immediately when new heading arrives.
- For heavy legs, priority of the existing half-strength SLIDE pose is deferred until the BOOST pose hold expires: a genuine BOOST's 100% authored animation survives its grace rather than being prematurely replaced by the heavy-leg 50% idle/BOOST mix. Ordinary SLIDE still has no nozzle flames, no new consumption of EN or afterimages.
- Keep v213 screen-space down-to-right steering quadrant, backward pitch-down, idle down90°, authored pivots, step and melee tracking, prior animation durations and equipment geometry unchanged. Update legacy v204/v210/v212 source assertions, add v214 regression to CI. Android rendering remains unverified.

## 2026-11-10 — SERA v215: bird leg C grounding and motion stability
- The reverse-jointed LOWER BODY C has a large authored gait envelope. The older v209 RUN contact correction snapped only the current bird-foot mesh to the training floor on one audible footfall frame and reverted its mesh position the next frame; this produces a visible one-frame leg/ankle pop. Keep per-foot audio contact events but skip this shoe-only teleport for C (A/B/D are unchanged).
- Introduce a C-only persistent smoothed visual rig Y support offset in sera_equipment.gd. In both WAIT and RUN, after the authored animated pose is applied, measure the actual visible triangles of both bird sole meshes, choose the lower support foot, and exponentially approach the visible grid floor (0.10 s time constant), rather than resetting its bind height each frame. The existing exact initial ground snap seeds the persistent offset. NEXUS exhibition, jump/air, actual Player position and collider are unaffected.
- Bird animation source contains only 3–5 of its 6 articulated reverse-leg keys in several STEP/BOOST animations; the newly imported Frontstep also has no bird keys. Missing bird rotation tracks previously went straight to raw bind orientation, causing abrupt unkeyed-joint jumps. After merging authored tracks, fill only missing bird joints' rotation with their authored Wait_motion first key. Do not overwrite any authored keyed rotations, root A animations or original Blockbench files. The fallback Jump now takes Wait_motion rather than empty Wait_Pose, including all six bird bones.
- Bird WAIT's left ankle has keys only at t=0 and t≈0.21667 while the clip loops at 3.6s. Smooth its *runtime* rotation from the final key back to the first over the last 0.20s; preserve the authored file and unrelated clips. Keep prior RUN/BOOST/STEP speed and control behavior unchanged.
- Add v215 regression/test gate; Android rendering and perceptual gait quality remain unverified.

## 2026-11-10 — SERA v216: high-acceleration thruster flare
- At the onset of STEP and the onset/change of a physically moving homing attack mode (DASH, STRIKE_TRACK, BASH_TRACK, active STRIKE/BASH chase), issue a one-shot acceleration_burst visual event. Do not continuously retrigger while the same state remains active. STEP is detected using the existing step_this_frame snapshot, not player.velocity, because it uses move_and_collide(); homing needs measured movement to suppress a flare while blocked.
- Forward the burst bool through main.gd -> sera_rig.gd -> sera_equipment.gd -> both selected physical back_thruster_fx.gd instances; other booster set instances stay inactive. No changes to the 3D nozzle pivots, left down/right screen quadrant, backward down rotation or v214 post-BOOST turn emission.
- Existing 4-sided inner/outer jet ShaderMaterials now have a burst uniform. On the event, the shader expands toward its free tip (up to 2.8x width, preserving nozzle-mouth width) and extends the tip at up to 28% while brightening briefly. CPU-side envelope ramps 0.035s then eases to its original shader baseline over 0.18s, total 0.215s. End event resets completely; no new particles, geometry assets, animation clips or EN cost.
- v216 README and added static + numeric regression in model-policy CI; updated v206/v212/v213 historical routing assertions to allow the new optional event parameter without weakening other checks. Godot/Android rendered result unverified.

## 2026-11-10 — SERA v217: fivefold thruster flare tip over 100 ms
- User specified the acceleration jet's far-end expansion to 5.0 times baseline width and the expansion phase to cover the first 0.10 second.
- In shaders/back_thruster.gdshader increase the existing tip fan multiplier from (1 + 1.8 * burst * along²) to (1 + 4.0 * burst * along²); keep nozzle-mouth width, original four-sided tube, flutter, 28% tip length and brightness unchanged. For burst = 1 and along = 1 the visual cross-section is exactly 5x its previous unexpanded size.
- In scripts/back_thruster_fx.gd change only BURST_RISE_SECONDS from 0.035s to 0.10s; preserve the 0.18s cubic fall, now totalling 0.28s before normal exhaust. Leave activation for STEP and melee/bash chase, nozzle direction, timing/animation, gameplay physics and EN unchanged.
- Update v216 numeric checks to support the newer tuned envelope and add v217 parameter/timing regression in model-policy CI. SERA v217 title and README. Godot/Xperia real graphics not tested.

## 2026-11-10 — SERA v218: rapid short-distance 15x thruster acceleration flare
- Requested: make the acceleration jet spread dramatically within a much shorter distance, and grow to **15x baseline width**. Keep its v217 temporal envelope (0.10s rise and 0.18s smooth return), v216 STEP and melee/bash chase triggers, and normal narrow exhaust between bursts.
- The prior rectangular exhaust was only a four-wall tube with vertices at its start/end: per-vertex shader deformation could not control a spatial transition within the tube. Divide each wall into **12 axial segments** (12 x 4 walls x 2 triangles; 288 vertices per tube), preserving the source lip at z=0 and the geometry's rectangular four-sided cross section. CPU-side creation only; no new assets/particles/textures and no changes to authored Blockbench nozzle pivot or camera-relative aiming.
- In shaders/back_thruster.gdshader, switch fan from burst * along² (maximum 5x only at the far tip) to burst * smoothstep(0, 0.25, along) and multiply cross section by 1 + 14 * fan. At full flare the shader reaches **15x cross-sectional width by 25% of the jet length**, and maintains it through the remainder; at the nozzle lip, width stays 1x. With burst 0 the original narrow tube and flutter return. Tip-length elongation (+28% max) and brightness remain unchanged.
- Update v206/v216/v217 compatibility regressions for new mesh subdivision and fan profile; add v218 spatial-geometry/numeric guard in CI. Bump project title to v218, add README_v218_ja.md. Real Godot Android rendering remains unverified.

## 2026-11-10 — SERA v219: 10-sided exhaust jet and 50ms flare rise
- User specified 0.05 seconds of acceleration-burst expansion instead of 0.10 seconds, and a slightly smoother 10-sided jet model instead of the current square four-sided effect. This changes the **procedural jet FX model only**, not the authored octagonal Blockbench nozzle body/pivots.
- In scripts/back_thruster_fx.gd generate a closed **regular decagon** radial cross section around the existing local +Z jet axis, using TAU * side/10 polar angles and the same half_width radius for outer and inner core. Preserve 12 axial segments and existing UV/profile shader controls. Geometry per inner/outer tube becomes 10 x 12 x 6 = 720 triangle vertices instead of 288; no new draw calls, textures, or particle emitters. The circular profile softens silhouettes without requiring high-poly models.
- Change BURST_RISE_SECONDS from 0.10 to **0.05**. The existing BURST_FALL_SECONDS = 0.18 is unchanged, so total flare time is **0.23 seconds**. The v218 maximum **15x** cross-section expansion by the first **25%** of jet length, minimum lip width 1x, emission brightening and subtle flutter remain.
- Existing STEP/strike/bash pursuit edge-triggering, camera-relative nozzle aiming, down90° resting direction, v214 BOOST-turn jet persistence, heavy-leg slide behavior, physical movement speed, collision and EN are unchanged.
- Updated v206/v216/v217/v218 regression scripts to remain accurate for later versioned tuning and added the v219 decagon/timing test to model-policy CI. New README_v219_ja.md, project v219. Godot/Xperia Android visuals still require on-device checking.

## 2026-11-10 — SERA v220: normal melee thruster remains active through the full airborne strike
- User clarified that the entire normal-melee action (approach, tracked movement and blade follow-through) takes place off the ground. Before this update, the nozzle effect was gated by actual measured movement for melee chase. It shut off as soon as SERA reached contact/hit-stop or was swinging without displacement, even though the authored strike animation continued.
- In scripts/main.gd add a separately named normal_melee_exhaust bool covering only MELEE_APPROACH, DASH, STRIKE_TRACK and STRIKE (all 3 normal combo hits). Include this boolean in the existing nozzle-exhaust activation while preserving its guard/damage/jump/landing/EN-empty exclusion conditions. This keeps ordinary narrow 10-sided blue/white exhaust visible even after strike_did_hit and while stationary, including during hit-stop; cease when combat_state returns to IDLE or attack is canceled/interrupted.
- Importantly, the previous tracking_exhaust remains motion-gated (measured displacement), and tracking_accel_state continues to derive from that gate exclusively. The one-shot v219 15x/50ms acceleration flare **does not** retrigger for a stationary follow-through; only the normal thruster remains. Bash is explicitly NOT added to sustained normal melee and retains its prior tracking rules. Also unchanged: BOOST/STEP behavior, 3D nozzle pivot and camera-relative steering, physics/hitbox/energy drains, model files and heavy-leg slide.
- Adapt v206/v214 source assertions to the extended exhaust boolean; add v220 state-coverage/idle-stop/accelerating-burst regression and register it in model policy CI. Bump Godot project title to v220 and add README_v220_ja.md. Godot/Xperia Android rendering remains unverified.

## 2026-11-10 — SERA v221: repair visual gaps in the normal melee thruster
- User-provided 4.53s Xperia screen recording of SERA v220 shows missing or barely visible blue plume during the full authored normal strike even with EN shown at 100%; one captured frame at about 0.55s shows STRIKE 3/3 while exhaust is visually occluded. v220's state-based exhaust_on is not sufficient to guarantee a perceptually continuous visible jet.
- When normal_melee_exhaust is active but actual homing is not, use the player's stable rear-facing world axis as the desired exhaust direction instead of normalizing minuscule displacement caused by hit-stop/collisions. Do not change STEP, real BOOST, homing movement, rear/down, LEFT quadrant steering or authored physical pivot restrictions.
- Forward a dedicated bool melee_sustain through main -> sera_rig -> sera_equipment -> both selected back_thruster_fx instances. This is separate from acceleration_burst. During normal melee sustained emission, gently smooth its weight using a 0.06s exponential response; increase the **ordinary**, thin ten-sided jet's effective tail length by up to 65% (1.65x original, from the same nozzle opening) and boost relative visual alpha by up to 65% and emission by 30%. The longer plume can extend clear of nearby moving shoulder/arm meshes and remain visible through non-moving 3-hit swings and hit-stop. No new 15x flare is triggered without homing.
- Reset sustain uniform and state when FX is inactive. Existing 15x near-nozzle 0.05s burst + 0.18s decline, active mesh count, equipment source models, hitboxes, attacks, physics, EN and cancel logic remain unchanged.
- Update routing assertions in v206/v212/v213/v216/v217/v218/v219/v220 tests, add dedicated v221 source/numeric assertion in CI. SERA v221/readme. Android Godot rendering still not directly verified by CI; subjective visibility improvement needs Xperia inspection.

## 2026-11-10 — SERA v222: prevent real nozzle aiming into animated torso
- User-provided Xperia screen recording `1000034525.mp4` shows frames during the airborne normal attack where the physical 3D nozzle points back into SERA's body despite v221's stable rear exhaust and boosted visibility. This is a pivot/steering issue, not merely flame length.
- Authored Blockbench hierarchy confirmed in `models/SERA_BOOSTER_allテスト.bbmodel`: Chest at [0,20,0] -> BOOSTER at [0,20,4] -> Thruster_L [-2.35,17.65,4.25] and Thruster_R [2.35,17.65,4.25]. During normal melee Chest rotates in 3D, while v221 world-rearward steering and per-nozzle local yaw/pitch can aim one or both nozzle tubes into the torso.
- Introduce a normal-melee-only safety cone in `scripts/back_thruster_fx.gd`. After all previous normal and screen-sector physical nozzle steering, compute the actual current 3D jet axis from nozzle.global_transform.basis * Vector3.BACK and radial exterior direction from animated Chest.global_position to each nozzle hinge. If dot(outward, jet) < 0.55, project the final world vector onto the closest exterior cone at dot=0.55 (or exactly outward for a perfectly inward jet), convert to the authored nozzle rest basis and apply a physical Node3D quaternion. This is enforced on every emitting melee frame and cannot transiently point into the torso when the Chest rolls; normal input steering continues unchanged for BOOST, STEP, bash and idle.
- No alterations to the authored metal model, body/animation clips, general nozzle yaw/pitch limits, v219 decagonal flare burst profile, v221 longer/clearer sustained jet, hitboxes, movement, EN or heavy SLIDE. Small positive safety-margin clearance is intentional; out-of-body projection has precedence over the old authored yaw/pitch servo only in actual melee.
- Added independent v222 regression using real authored Chest/Thruster pivots with multiple synthetic yaw/pitch/roll combinations and static routing checks; CI model-policy registration, README v222, project title v222. Actual Xperia/Godot rendering has not yet been validated.


## 2026-11-10 — SERA v223: world-space ribbon wakes for both back thrusters
- Added a lightweight camera-facing blue/white two-layer ribbon driven by historical world-space exhaust-tip positions. Per-nozzle 0.34s history, 26ms/3.5cm sampling, 32-point cap, discontinuity at >1.35m and on emission restart; age-based alpha/width taper allows short afterglow with emission off.
- The ribbon MeshInstance3D is a top-level sibling of the nozzle-attached ExhaustFX, so hiding the current flame cannot hide fading history and authored Chest/nozzle rotation cannot move old vertices. Camera-aligned quads are rebuilt from world points without particles or textures.
- The selected-equipment switching, v222 melee torso guard, v221 normal melee sustained jet, v219 ten-sided tube and 15x 50ms burst, STEPs/BOOST/SLIDE, combat controls, EN and Blockbench assets remain unchanged. Shader is an additive unshaded vertex-color material with depth testing retained.
- Bumped project name to SERA v223; added standalone static/numeric regression in the model-policy CI and README_v223_ja.md. Actual Godot Android rendering and performance remain to be verified.

## 2026-11-11 — 安全な開発高速化ツールの追加（ゲーム本体の変更なし）

- `docs/SERA_DEVELOPMENT_FASTPATH_ja.md` に現行コード優先の調査手順と機能別の参照先を明記。
- `tools/sera_code_map.py` に、実際のGDScriptから関数/定数の位置を抽出する読み取り専用索引を追加。
- `tools/sera_quick_check.py` に、既存の基本静的検査をまとめて実行する入口を追加。描画契約は `--render`。
- `tools/sera_dev_tools_self_check.py` に索引の回帰テストを追加。
- `AGENTS.md` および `docs/SERA_TECH_AND_WORKFLOW.md` の旧版固定記述を「当時の記録」と明確化。最新の統合版は `project.godot` を参照するルールに変更。
- `project.godot`、ランタイムコード、モデル、音源、シーン、従来の検査内容は変更しない。既存のGitHub Actionsに新ツール検査を統合し、別のワークフロー・ジョブは新設しない。
- ツールのPython検証はPRの実行環境で確認し、Godot/Android実機テストは未実施として区別する。

## 2026-11-11 — SERA v246: 全画面フローティングコントローラーと操作枠線の削除
- v243の右下1/4操作開始制限を解除し、戦闘画面のどこからでもコントローラーを出せるようにしました。画面内判定のみを維持し、開始後のドラッグ・離指は従来どおり位置制限なしです。
- 実際のUIボタン（左右LOCK、AUTO/MANUAL、HAND、NEXUS、TEST HIT/BREAK/MOVE、敵DEBUG内ボタン）の押下位置は操作開始から除外。情報表示だけのHUD領域からは操作を開始可能にしました。マルチタッチ時の指の所有・ボタン優先処理は維持しています。
- コントローラー操作枠の外周線・下部の四隅装飾を削除し、既存の右下グレーグラデーションはそのまま保持。RUN/BOOSTの円、表示半径、閾値、波紋/STEPエフェクトは不変です。
- v243〜245の回帰テストを現行仕様と整合させ、v246専用の静的チェックを追加して既存のCIへ組み込みました。Androidの実画面/入力/Godot実行は未検証です。

## 2026-11-11 — ChatGPT単独開発用の保守監査（ゲーム挙動変更なし）

- RUN/BOOSTの入力判定・HUDサイズの定数一致と、実際の使用箇所を検査する `tools/sera_parameter_audit.py` を追加。
- GDScriptの静的依存と既存回帰テストの候補を調査する `tools/sera_change_impact.py` を追加。動的呼び出し・実機動作の正当性は保証しない。
- `tools/sera_agent_audits_self_check.py` に、不一致検出と依存グラフの自己検査を追加。
- 既存 `sera-model-policy.yml` に新監査を接続し、既存の検査はそのまま保持。開発ガイドとエージェント規約を更新。
- 変更対象は文書・Pythonツール・既存CIのみ。ランタイムコード、バージョン、Godot設定、モデルは変更しない。

## 2026-11-12 — SERA v264: 3連撃完走後の左右フリック蹴り

- Melee3 の最終フレーム終了後、既存の0.65秒派生受付中に画面左／右フリックを入力すると、それぞれ対応する蹴りクリップが登録済みの場合のみ発動するようにした。前方のBash派生、3段中の既存STEPキャンセルは維持。
- 通常STEPの _start_omni_step を直接共有し、同じ画面基準の移動方向・距離2〜4m・最大0.4秒・装備別速度／EN・連続スイープ衝突・ステップ噴射／カメラを使用。蹴りのアニメーション再生時間はSTEP移動時間に同期。
- 蹴り1回あたり1ヒット、移動50%以降の射程2mで判定。攻撃・破壊・怯みは暫定的に通常格闘1段目の装備パラメータを使用。蹴り中は自動ロック再選択しない。
- モーションは実在する assets/sera_source.json を優先し、未登録の場合は models/storage/SERA_BOOSTER_allテスト (9).bbmodel の Kick/蹴り名称クリップに含まれる既存骨格UUIDのトラックだけをロード。既存のモデルやモーションは変更しない。クリップ欠損・データ不正なら派生を発動せず通常STEPで安全に処理。
- 新しいAndroid同期コミット 6c22ffc（2026-11-12）で models/storage/SERA_BOOSTER_allテスト (9).bbmodel の Kick_l/Kick_r（各1秒）を確認した。両クリップのうち標準骨格22 UUIDが一致し、キーフレームを保持。これを実際のアニメーション読み込み先に指定した。tools/v264_side_kick_followup_self_check.py を既存CIへ登録。Godot/Androidのゲーム再生は未検証。

## 2026-11-12 — SERA v265: 3段コンボ後の左右蹴りを確実に再生
- v264では `Kick_l`/`Kick_r` を追加Blockbench原本から実行時に読み込む構成だったため、Android実行環境で原本を参照できない場合 `has_side_kick` が偽になり、通常STEPにフォールバックする可能性があった。
- 原本 `models/storage/SERA_BOOSTER_allテスト (9).bbmodel` の左右1秒アニメーションから、現行標準22骨格UUIDのキーフレームのみを `assets/sera_source.json` に統合。 `tools/rebuild_model_data.py` と同一形式で `assets/sera_data.gd` を生成し、Android埋込データでも確実に存在するようにした。既存モーションとユーザーの原本は無変更。
- 3段目完走後0.65秒以内に入力**開始**したフリックは、指を離すまでの間に時間窓が失効しても蹴りの入力権を維持する。受付時間の二重チェックによる通常STEPへのフォールバックを解消。開始後の他方向や時間超過などは従来STEP入力ルールのまま。
- 通常の2〜4mステップ距離・衝突スイープ・EN、バッシュ、3連撃、カメラ・描画・装備・保存は維持。新規 `tools/v265_kick_embedded_input_self_check.py` とCI回帰検査を追加。実際のAndroidゲーム実行は未検証。

## 2026-11-12 — SERA v266: 3段完走後の左右蹴りと通常STEPの排他制御
- 現行v265を確認したところ、左右蹴り用 `_request_combo_side_kick` が失敗すると、`_end_drag` の通常 `_start_omni_step` にフォールスルーしていた。また、指が途中で左右45°外へ移動すると `side_kick_flick_candidate` が解除され、離指時に左右でも通常STEPへ流れることがあった。
- 派生受付中に開始した0.24秒以内のフリックは、途中の角度変動では蹴り候補を外さず、最終的な離指方向が画面左右45°内なら**蹴り専用**とする。蹴りが起動できない場合も通常STEPへ変換せず入力を消費する。前後/斜めの従来STEPとBash・RUN/BOOST・完走前キャンセルは維持する。
- `tools/v266_exclusive_side_kick_self_check.py` をCIへ追加。v264/v265チェックは新バージョンの仕様に追従するよう更新。Android実機の動作確認は未実施。

## 2026-11-12 — SERA v267: 蹴りの左右90°セクターをセラ正面基準へ修正
- 実機では左右蹴りのつもりでもSTEPが出ると報告あり。v266コードを確認すると、蹴りは画面上方向 `Vector2.UP` を正面として判定していた。ユーザー指定の「セラ正面を0°とし、左右それぞれ中心±45°の90°幅」と一致していなかった。
- `_end_drag` と `_request_combo_side_kick` の左右蹴り判定を、タッチ開始時に取得済みの `gesture_screen_forward`（セラの正面を画面に投影）に統一。右＝正面から時計回り45°～135°、左＝反時計回り45°～135°。従来の前方Bashも同じセラ投影軸を使用し、STEP移動とRUN/BOOST・コントローラーは引き続き画面方向で処理。
- モーション `Kick_l` / `Kick_r`、STEP距離2〜4m、EN・衝突・カメラ・三連撃・通常STEPの連続角度・蹴り専用入力の排他処理は維持。
- `tools/v267_actor_facing_side_kick_self_check.py` とCIを追加し、既存v264/v266テストの期待セクターを現行仕様へ更新。Godot Android実機での表示・操作は未確認。

## 2026-11-12 — SERA v268: 添付動画で確認した3段目振り抜き中の蹴り入力消失を修正
- 動画 `1000034689.mp4`（SERA v267）では約9.60→9.76秒および14.24→14.40秒に `STRIKE 3/3` → `STEP DIAGONAL`、4.48秒・11.52秒頃に `STRIKE 3/3` → `RUN` の遷移を確認。モーション終了後にのみ `side_kick_flick_candidate` を作る実装だったため、3段目振り抜き中に入力された蹴り候補を認識できず、途中キャンセルや通常STEPへ流れていた。
- 3段目のSTRIKE/STRIKE_TRACKでも左右蹴りフリックを予約。セラ正面の画面投影軸による左右各90°で左右を決定し、元のスクリーン入力方向を保存。動作は3段目`Melee3`の**完全終了後**に起動し、通常STEP同等の衝突付き2～4m移動とユーザー制作`Kick_l`/`Kick_r`キーフレームを使用。途中の格闘カットなし。
- 蹴りだけのフリック識別は既存バッシュと同じ最大0.42秒・30px・200px/s・反転比1.35へ変更。STEPの0.24秒／78px閾値は維持。短い蹴りジェスチャー中のRUN/格闘キャンセルを抑制し、被弾・コンボ切替・バッシュ時には予約を破棄。
- HUDは予約中`STRIKE 3/3 | KICK QUEUED`、発動時`KICK LEFT|RIGHT | Kick_l|Kick_r`を表示。旧STEP DIAGONALとの混同を防ぎ実機動画から分岐を識別可能にした。
- `tools/v268_melee3_kick_buffer_self_check.py` を既存CIに追加。旧v264～v267の回帰テストは新しい入力候補のタイミングに対応。Androidの実機操作・再生は未確認。

## 2026-11-12 — SERA v269: 実機動画で確認した画面横フリックとセラ後方セクターの食い違い
- 新動画 `1000034692.mp4` (SERA v268、14.98秒) をHUD+操作系で照合。約1.3秒にSTEP RIGHT、5.6秒にSTEP DIAGONAL、10.3秒にSTEP RIGHTが確認でき、蹴り予約・発動表示は現れない。横側から敵を追うセラの向きは画面左になるため、**画面右フリックがセラ後方180°方向**に分類されてしまう。3段完走前後の受付拡張だけでは、左右セクターと認識されない入力を救えないことが原因。
- `_combo_kick_side_for_flick` へ蹴り判定を集約。従来のセラ正面から左右各90°セクターを優先しつつ、**セラ後方セクターと判定される画面左右フリック**も対応する `Kick_r`/`Kick_l` として受付。セラ正面の前方バッシュ、コンボ受付外の画面360°STEPは維持する。
- 既存の同一コントローラー画面方向を移動ベクトルへ使い、`_end_drag` と `_request_combo_side_kick` の左右判定を共通化。蹴り候補中のBOOST開始も明示的に禁止し、フリック期限終了後のみ従来BOOSTへ戻す。Melee3完走後の予約キック、2～4m移動、キーフレーム、カメラ、EN／衝突計算は維持。
- 回帰検査 `tools/v269_screen_kick_video_self_check.py` を既存CIへ追加し、動画と同じ「セラ正面が画面左、右方向へフリック、従来は後方STEP」という条件を数値で再現。旧テストは新しい互換受付を踏まえ修正。v269のAndroid実機動作は未確認。

## 2026-11-12 — SERA v270: 画面横フリックと前方Bashの優先競合・入力拒否の可視化
- ユーザーからv269でも蹴り不発との追加報告。v269の `_combo_kick_side_for_flick` を再検証すると、セラが画面左右を向いている際に、画面横入力がセラの**前方90°**に該当したケースを救済していなかった。従来の救済条件は「セラ後方」だけで、左右フリックが前方バッシュへ流れる入力競合が残っていた。前々回のv268録画でも3段目直後にBashへ切り替わる例が複数あった。ただしv269自体の実機映像は未確認であり、不発原因の全件特定ではない。
- 3段目中または完走直後の入力受付に限り、セラ相対の左右各90°を優先し、それ以外の**画面左右各90°フリックも横蹴り**に分類する。セラ前方と画面左右が重なる場合には横蹴りを優先、画面左右以外のセラ前方方向は従来Bash。通常STEP・RUN/BOOST・カメラ・2〜4m移動・モデルとモーションは無変更。
- 根本原因切り分けのため、`kick_touch_started_in_window` をタッチ開始時に保存。既存`step_detail_label`に蹴りの予約／開始／角度拒否／受付時間外／0.42秒超／距離速度不足／モーション不在／状態・EN制限を2秒表示。Melee3完走後約1.6秒以内の画面左右フリックでは、入力時間窓が閉じたことも明示。通常プレイの新規UIは追加せず、時間経過で元の表示に戻す。
- `tools/v270_kick_input_priority_diagnostic_self_check.py`をCIへ追加。セラの向き720パターン×左右横入力を数値検査、入力分岐の優先順位とデバッグメッセージの配線を検査。v269の旧テストも前方被りケースを追加。Android実機の新ビルドは未検証。

## 2026-11-12 — SERA v271：実機の KICK: CLIP MISSING から実行時クリップを復元
- ユーザーがv270の追加診断HUDで **`KICK: CLIP MISSING`** を確認。蹴り入力は `_request_combo_side_kick` まで届くが、実行中リグの `has_side_kick` がfalseを返すことが確定。これまで繰り返した操作角度・STEP競合の修正だけでは解決しなかった。
- GitHubの `assets/sera_source.json` / `assets/sera_data.gd` は `Kick_l`（109キーフレーム）と `Kick_r`（72キーフレーム）を保持。旧リグは `SOURCE_PATH` が存在するだけで埋込データを一切参照しない構造だったため、端末側のJSONが古い／空なら、正常な生成済み埋込クリップがあっても復元しない。端末上で実際にどちらが原因だったかは未確定。
- `sera_rig.gd` に再生可能性判定（実際に組み立てたボーンUUID上のrotation/position/scaleのキーフレームの存在）を追加。起動時に不足した左右キック**だけ**を生成済み `EMBEDDED.get_json()` から補完。蹴り実行時のチェックも一度だけ自己復元可能とし、既存の有効なクリップ・モデル・Pivot・他モーションを上書きしない。
- `main.gd` はCLIP MISSING時に左右と埋込復元の失敗状態をHUDへ表示。リグが蹴り開始を拒否したときは誤ってKICK成功／STEP移動状態へ移行しないように修正。入力・コンボ時刻・通常STEP・Bash仕様は維持。
- `tools/v271_embedded_kick_runtime_recovery_self_check.py` に実際のbase64埋込とモデル関節の検証、JSONのKick欠落とキー空の模擬復元、モデル・他アニメの不変、リグ/ゲーム接続を追加。既存v264〜v270検査は新仕様と一致するよう明示的に更新。Android実機のv271動作は未確認。

## 2026-11-12 — SERA v272：実機で埋込復元も失敗した左右蹴りへ独立モーション資源を追加
- ユーザー提供スクリーンショット（SERA v271）のHUDに **`KICK: CLIP MISSING R EMBEDDED FAILED`** が明示された。右フリックは蹴り受付まで到達したが、旧`EMBEDDED.get_json()`復元後も実行時クリップが有効にならないことを確認。元データのGitHub版は正常なので、単に入力の角度を変更する対応は誤り。Android端末側での大きな埋込資源の復号・ファイル同期状態または実行中骨格のUUID相違は直接観測できず、失敗の詳細原因は未確定。
- 新規`assets/sera_kick_clips.gd`にGitHub正本`assets/sera_source.json`の`Kick_l`/`Kick_r`だけ（22骨・109/72キー）を改変せず独立収録。約46KBの新しいGodotスクリプトで、旧`sera_source.json`／旧`sera_data.gd`が端末に残っていても新規資源を優先して読む。
- `scripts/sera_rig.gd`の起動時、通常JSON/Blockbenchモーションロード後に新規資源から欠落した左右クリップのみを復元する。元UUIDが現在の骨格と合わなければ、**重複のない関節名を一致させて**アニメーションの参照UUIDだけを修正。最低8個のキーフレーム入りボーンが対応しなければ補完せず、元メッシュ・Pivot・キーフレームを保護。既存の大きな埋込復元も最後の保険として維持。
- 成功・失敗をGodotログと短いHUD診断（専用資源復号エラー／対応関節数不足）で判別できるようにした。v271の「再生失敗時にSTEP/KICK成功と誤認しない」処理と、既存のSTEP/3連撃/Bash/EN/カメラ仕様は維持。
- `tools/v272_dedicated_kick_pack_self_check.py`に専用GDScriptの復号、正本との全キーフレーム一致、旧JSON/旧丸ごと埋込が両方古い場合の補完、完全UUID不一致時の名前対応、不適合な骨格への誤適用拒否、リグへの呼出しとHUD接続を追加。CIへ統合し旧v271テストの固定バージョン表記も解消。Android実機のv272再生は未確認。

## 2026-11-12 — SERA v273: CLIP MISSING R ALREADY READYの矛盾を固定名検索と実機相当Godotランタイム検査で修正
- v272の実機スクリーンショットで`KICK: CLIP MISSING R ALREADY READY`を確認。起動時の`_usable_side_kick_clip("Kick_r")`は成功していた一方、蹴り要求時の`_side_kick_clip_for(1)`が空を返していた。つまり以前の`EMBEDDED FAILED`とは状況が変わり、追加データの有無ではなく**起動時判定と名前解決経路の食い違い**が問題。以前の静的テストではこれを見つけられなかった。
- `sera_rig.gd`で蹴りだけに導入されていた`var preferred: Array[String] = [...] if side > 0 else [...]`に、Godotの型付き配列と条件式の既知の実行時互換性問題（godotengine/godot#110628・#83026）を確認。確定エラーログはまだないが症状と整合。既存Melee3/Bashと同じ`"Kick_r"`/`"Kick_l"`の固定名をまず直接検索し、互換名称は型なし配列・明示if/elseで補完する簡素な処理へ変更。
- `start_side_kick`の「`has_side_kick`で遅延復元する前にchosenを選ぶ」潜在不整合を解消。利用可否・復元の確認後に実際の再生名を取得し、空の場合は安全にfalse。HUD診断は状態フラグだけでなく、現時点のキー有無と名前検索結果を確認。
- 新規`tools/v273_kick_lookup_runtime_check.gd`で、Godot 4.7.2をLinux headless起動して実際の`SeraRig`を生成し、右/左の`has_side_kick`・`_side_kick_clip_for`・`start_side_kick`および`current_clip`を検査。既存CIに実Godot導入・プロジェクトimport・上記runtimeテストを追加。旧v271静的検査も固定名方式に合わせて更新。元データ/キーフレーム/他操作仕様は無変更。
- 実GodotチェックはAndroid実機ではなくLinux実行のため、タッチ入力・Android固有の読み込み挙動まで保証しない。動作確認は別途必要。

## 2026-11-12 — SERA v273：左右蹴り不具合の再発防止を全モーションへ拡張（ゲーム仕様変更なし）
- Androidで`Kick_l`/`Kick_r`の再生成功が報告されたため、v264〜v272で静的検査を通しても再生できなかった教訓を開発規約へ反映。
- `tools/sera_animation_runtime_smoke.gd`を追加。実Godotに`SeraRig`を初期化し、`assets/sera_source.json`の**全アニメーション**について、現在のリグ上の有効なアニメーショントラック・固定名クリップ選択・中間時刻の姿勢計算を検査。最後に左右蹴りの公開API`has_side_kick()`/`start_side_kick()`も実行して結果を検査。
- `.github/workflows/sera-model-policy.yml`に同ランタイム検証を追加。成功メッセージとGodotスクリプトエラーの有無を確認するCIチェックを、既存v273の左右蹴り単体ランタイムチェックの後に設定。
- `docs/SERA_ANIMATION_RUNTIME_POLICY_ja.md`を作成し、`AGENTS.md`と`docs/MODEL_PART_WORKFLOW_ja.md`へ必須参照を明記。モーションの固定名・型付き配列の使用制約・読込/復元/実行の順序・実機とCIの区別・原因切り分けを標準化。
- 本変更は**テストと開発規約のみ**で、`project.godot`はSERA v273のまま、モデル・キーフレーム・ゲーム挙動は全て保持する。Linux GodotのCIはAndroid画面操作の代わりではない。

## 2026-11-12 — SERA v274：3段目後の画面下フリックで後方サマーソルト`Kick_b`派生
- ユーザー指示：`Kick_b`はサマーソルトキック。格闘3連打のあとに後ろフリック、後方へ弧を描く跳躍、着地モーション0.2秒で着地。
- GitHub`main`の`assets/sera_source.json`と最新の`models/storage/SERA_BOOSTER_allテスト (9).bbmodel`などを調査すると、`Kick_l`/`Kick_r`は存在するが**`Kick_b`の元キーフレームは未収録**。架空のBlockbench原本を作らず、`SeraRig`に`has_back_somersault_clip`/`start_back_somersault`/`set_back_somersault_progress`を設け、正規モーションが将来統合されたら優先し、現状は`Jump`の原本飛行ポーズ＋セラ表示モデルの360°回転で暫定動作。HUDに`Jump FALLBACK`と明示。
- フリックは入力自体は画面基準：3段目（STRIKE/STRIKE_TRACK）または完走後0.65秒のコンボ受付中、画面下90°セクターを左右各90°より先に`side=2`として確定。`Melee3`完走まで派生を予約し、実行時はセラ→ロック対象への水平ベクトルを反転し、4.0mの連続衝突付き移動と高さ`1.5sin(πp)`の弧で0.80秒跳躍。既存の横蹴りと同じ消費EN15と1ヒット方式を暫定使用。通常バックSTEPとは別アクション。
- 着地ではユーザーの`Jump`の0.375～0.500秒区間を使い**0.20秒、ホールドなし**で立ちへ復帰。旧Jumpの0.125秒＋0.60秒ホールドは変更しない。ガード・ラン・BOOST・攻撃とジャンプの割込みは無効、被弾/KOでは回転と高度をクリアしてダメージ処理を優先。
- `tools/v274_back_somersault_self_check.py`（制御分岐/距離/高さ/時間/キャンセル）と`tools/v274_back_somersault_runtime_check.gd`（実Godot本体で物理移動・ジャンプ最高点・着地）を追加し、CIのGodot 4.7.2実行検査に追加。v273テストの固定バージョン表記を将来互換に更新。Android実機／原本`Kick_b`キーフレームは未確認。


## 2026-11-12 — SERA v275：Blockbench原本 Kick_b（サマーソルト）の正式統合
- `models/storage/SERA_BOOSTER_allテスト (9) (2).bbmodel` の新規ユーザー制作モーションを確認。0.79167秒、既存標準Aと一致する16関節・71キーを変えずに `assets/sera_source.json` へ追加。既存の25モーション、メッシュ、Pivot、装備には変更なし。
- `tools/rebuild_model_data.py` と同一方式で `assets/sera_data.gd` を再生成し、Godot実行時に正規 `Kick_b` を利用。既存の3段目→画面下フリック、後方弧4m、最高1.5m、0.8秒飛行、0.2秒着地、EN15等の操作・物理処理を維持。正式クリップ使用時は暫定リグ回転を加算しない。
- CIへ原本とコピーのキーフレーム一致、16骨UUID、埋込復号のバイト一致を追加。v274の実Godotシーンテストと全モーションの実Godotテストで正規Kick_bの発動を必須化。Android実機検証は未実施。

## 2026-11-12 — SERA v276 Katana integration
- Integrate exactly 5 Katana groups, 7 meshes, and authored `Melee_katana` into canonical/embedded data from synced source (9) (2) (2); all old animation/data preserved.
- RIGHT WEAPON set K, left sheath/rest and right drawn/frame-4, revert after strike. Preserve customizations and saves.
- Playback Katana clip with existing 3-hit attack flow, switch hit segment to new blade; static + Godot CI. Android device unverified.

## 2026-11-12 — SERA v277: foot-extension kick contacts and Bash pursuit
- Kick_l and Kick_r: two independent impact checks per clip at 0.25s and 0.58333s in the original 1s animation, scaled to active STEP duration. Kick_b: one check at 0.20833s in 0.79167s clip. The key is disarmed after the attempt, hit or miss.
- Share the existing Bash lock-on/EN/collision homing for up to 0.2s during lateral kicks, and prior to the Kick_b rear arc when out of range. Bash-like timeout cancels if unreachable. Original 4m backward arc, 1.5m peak, 0.8s flight, 0.2s landing retained.
- Shared back thruster FX during kicks, homing and backflip, including acceleration flare, continuous exhaust and reverse pitch. Add static/real Godot regression tests; Xperia device unverified.

## 2026-11-12 — SERA v278 slower side-kick animation
- Kick_l/Kick_r action timeline is 2x, halving actual authored clip playback rate without source edits. Two hit keys remain at normalized 0.25 and 0.58333.
- Distinguish action progress from travel progress, which saturates at old STEP duration. Kick continues posing in place for the second half; standard STEP speed, arc and distance are unchanged. Bash homing still capped at 0.2s actual time. Kick_b unchanged.
- Add v278 static and real Godot checks, including normal-STEP baseline, mid-clip progress, movement completion and full kick follow-through. Android input/rendering still unverified.

## 2026-11-12 — SERA v279: Kick_b full authored frame is rendered before landing
- Existing 0.8s swept 4m/1.5m physical arc remains unchanged; stop at ground on time but defer transition while Kick_b's exact final time has not yet been sampled with full blend weight. Acknowledgement occurs only after `_apply_animation` really applied the authored final bone poses, not simply at the end of the physics timer. Extra physics ticks before the next render keep the terminal pose without additional movement.
- Once sampled, blend the final Kick_b to Jump landing over 0.055s; retain full 0.20s landing, single hit, Bash homing, EN and all other moves. Clear acknowledgment on start/cancel/landing. Source Blockbench keys untouched. New static/runtime tests cover no premature interruption and low-FPS no-double-travel.


## 2026-11-12 — SERA v293：AUTO部位ロックの周回順と本体ロック
- Android動画約10.9秒でAUTO動作を確認。旧v292のスクリーン中央への近さによる頭/脚選択はBODYを候補に含まず、周回順と一致しなかった。
- AUTO専用にカメラ相対方位の36度×10区間を追加。頭→本体→左前脚→本体→左後脚→本体→右後脚→本体→右前脚→本体を循環し、逆回りでは逆順。破壊済み部位は本体へ退避。
- 空IDの本体ロックと「まだロックしていない」状態を新フラグで区別し、0.22秒の遷移確定を本体↔部位の両方向へ適用。初回取得/破壊回復は即時。HUDはBODYのHPを表示。
- MANUALの既存左右スクリーン投影切り替え、戦闘ロック維持、攻撃判定・カメラ移動・3Dモデルは無変更。
- 静的/Godot実行のv293回帰チェックをCIへ追加し、v291/v292のAUTOに関する検査を本体選択可能な仕様へ更新。Android Xperia 1 V実機の操作確認は未実施。


## 2026-11-12 — SERA v294：原本カタナ2段目・戦闘カメラ距離調整
- 先行PR #196 の追加実装を、先にmainへ統合したv293 AUTOロックに競合しない形で移植。刀の新規 `Melee_katana2`（0.58333秒、19ボーン/70キーフレーム）を保存済Blockbench原本 `models/storage/SERA_BOOSTER_allテスト.bbmodel` からリグへ取り込み、原本未収録時のみ従来の2段目自動生成を使う。原本モデル・キーフレームは非破壊。
- 通常・接近・攻撃中の戦闘カメラ希望半径に0.60倍を適用。プレイヤーから後方2m以上の安全距離を先に保護し、その後の画面フィット処理も残すため、40%接近できない場合は安全側を優先。背面追従、画面基準入力、AUTO/MANUAL部位ロック、武器の鞘/抜き身の表示制御を変更しない。
- v294静的チェックと実Godotシーンの刀モーション・カメラ半径チェックをCIへ追加。v293ロック・旧モデル・キック等すべての回帰を保持。Android/Xperia 1 V実機検証は未実施。

## 2026-11-12 — SERA v295：格闘後RUNの姿勢復帰・ラン方向修正
- RUNの方位は画面ではなく `main.gd` が渡す「現在のターゲットへの方向を基準とする実移動ベクトル」から計算する。ただし、`_run_yaw_for_direction()` は従来 ±25°で腰の方向を制限していたため、横方向のランや斜め移動でも脚が進行方向を向かなかった。
- さらに `_apply_animation()` のv292全身ロック補正がRUNの腰角を毎フレーム0°へ戻していたため、RUN方向補正が完全に無効になっていた。RUNは腰・脚を実移動方向へ向け、前進走・後ずさりモード／利き手補正／上半身のボスターゲット追従を維持。STEP・BOOST・格闘は従来のボス方向制約を維持。キャラクター物理コライダーも常にボスへ向く。
- `_switch_clip()` でRUN以外へ遷移した時点でRUN方向キャッシュを破棄。格闘開始→終了が描画フレーム間で完結した場合も前回の歩行方向を持ち越さず、移動再開時に現在入力から前後モード・腰角・上半身追従を初期化する。既存のRUN/BOOST速度・入力・ヒット判定・モーションキーは変更しない。
- v290/v292の旧静的テストを新仕様へ更新し、正面・左右・後退・斜めRUN、格闘後の左右切り替えと非RUNスイッチ、ロック向きの保持を確認するv295静的/Godot実行テストを追加。Android実機は未検証。

## 2026-11-13 — SERA v306 カタナ初段の構えと接近を分離
- カタナ装備時、初段タップから`Melee_katana`の0フレームポーズへ0.20秒でクロスフェード。その間は追尾移動を行わず、達成後に既存のDASH追尾を開始。
- 接近中は0フレーム姿勢を維持し、射程到達で同一アニメーションの時刻0から攻撃を継続。通常の`meleeboost`と格闘2段目、既存の射程・追尾パラメータ・カメラを保全。
- 新規v306静的・Godot実行回帰テストをCIマニフェストに追加。Xperia 1 Vの実機タッチ/描画は未確認。

## 2026-11-13 — SERA v307 4方向STEPのポーズ基準統一
- STEPフリックを受けた直後、前フレームの`player`表示向きが現在のロック対象とずれていると、右入力に左/後ろポーズが一瞬選ばれていました。STEP姿勢基準をv305の`_locked_target_facing_direction`へ統一して、ロック更新時の初期モーション反転を防止。
- Step_R/Step_L/Frontstep/BackstepのBlockbench原本、4方向360°補間、ステップ3m/5m移動、カメラ、コンボ受付を保持。v307の静的/Godot実行テストで全方向・初期向き不一致を検査します。
- Android実機での映像、タッチ反応は未確認。

## 2026-11-13 — SERA v308 Step_Rを右前傾へ修正
- GitHub現行・過去のBlockbenchモーションを比較。別の姿勢を持つ同名Step_Rがないため、既存の名前とUUIDのまま時刻0の腰と頭の回転を調整。
- 腰を前30°・右18°に傾け、頭の大きなねじれを緩和。元の脚・腕モーション、他3方向、移動距離とロック追従は保持。
- `assets/sera_source.json`と`models/SERA_BOOSTER_allテスト.bbmodel`を同期し、`assets/sera_data.gd`を再生成。旧原本は非破壊。新しいPython/GodotテストをCIへ追加。
- Android実機の描画とタッチ動作は未確認。

## 2026-11-13 — SERA v309 9.2.2原本の右ステップを指定適用
- ユーザーがBlockbench画像で指定した`models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel`内の`Step_R`を、原本のすべてのキーフレーム/UUID/名前ごと`assets/sera_source.json`へ正確に適用。
- v308で独自変更されたWaist/Headの2回転キーだけが原本と異なっていたため、この2キーを復元。`models/SERA_BOOSTER_allテスト.bbmodel`も同じStep_Rに同期し、`assets/sera_data.gd`を正規のbase64形式で再生成。
- 他の原本モーション/3Dモデル/スクリプト/360°STEP補間・移動距離・カメラ・ロック/攻撃仕様は保持。9.2.2元ファイルは変更しない。
- 旧v308の独自ポーズ期待テストをバージョン条件付きにし、v309では指定原本一致を検査。専用のPython静的・Godot実行テストをCIに追加。Android実機上の見た目は未検証。

## 2026-11-13 — SERA v310 右ステップが前ステップに見える不具合修正
- Android実機動画の右フリックで、`Step_R`の原本が存在するのに画面上でFrontstepのような姿勢になる症状を調査。通常STEPの画面入力をv307のactor相対座標へ再投影しているため、ターゲット側面では右入力に前/後姿勢が混ざっていた。更にv292のWaist Yaw強制相殺で9.2.2原本の腰-70°回転が消え、前向きのポーズになっていた。
- 通常STEPの姿勢方向を開始から終了まで`step_flick_direction`（画面基準）で固定。実移動は既存`_screen_drag_to_ground`による3m/5mのワールド直線を維持。Side kick独自モーション/周回処理は維持。
- `Step_R`原本の腰Yawはそのまま再生する。斜め右は既存の角度イーズと同じ比率でYaw保持を0〜100%補間。他の前・左・後方とBOOSTの腰ロック補正、機体の物理ルートのターゲット向き、被弾/格闘/カメラ仕様は維持。Blockbenchデータは無変更。
- v310静的/Godot実行テストで画面右入力の位置非依存・ロック旋回中の姿勢維持・原本Yawの保存・斜め連続補間・移動距離を検査。旧versioned検査の期待値をv310仕様へ更新し、過去版の検査対象を維持。
- GitHub ActionsのGodot 4.7.2 headlessは実機映像に代わりません。Android実機での修正後画面は未確認。

## 2026-11-13 — SERA v311 ロック対象を前方とするSTEPポーズ選定
- ユーザー指定に従い、ロック中は現在選択中の部位/本体に向かう世界方向をセラの前方として、通常STEPの前後左右/斜めアニメーションを決定。既存の`_step_local_pose_direction`をロック時に使用し、ターゲット側面では画面右フリックが前方/後方の姿勢になることも許容。
- 無ロック時はv310の画面方向基準へフォールバック。物理的な実移動は常にフリック方向の画面基準3m/5m直線を維持。移動中のロック部位変更/旋回では姿勢だけ0.08秒の既存平滑補間で追従する。
- 9.2.2の`Step_R`原本回転と、既存の右側Yaw保持/斜め補間、キック派生、EN、カメラ、当たり判定、攻撃などは変更なし。実機での修正後の視覚確認は未実施。
- v311のロック基準/無ロック/切替/移動経路の静的・Godot実行検査を追加し、旧v310の絶対画面モーション前提のテストを現行仕様に更新。

## 2026-11-13 — SERA v312 全方向7m・15m/sと低姿勢回避リーン
- 通常フリック回避`_start_omni_step`の7m固定距離を全360°に適用し、`STEP_SPEED`を10→15m/sへ更新。装備の速度・時間補正を維持し、標準状態の所要時間は7/15≒0.467秒。前・後・左右と斜めの実移動経路は既存の画面基準・衝突安全な直線を保持。
- 既存4方向のBlockbench原本・ロック方向基準の姿勢ブレンドを保持しつつ、リグWaistに回避方向への22°の追加リーンと中心重心14cm引下げを適用。開始0.12秒フェードで自然に入れ、終了0.16秒の通常クロスフェードで原姿勢へ戻す。キャラクター衝突ルートと攻撃/盾判定は下げない。
- 右`Step_R`の9.2.2原本Waist Yaw保持と、斜め姿勢の角度補間は変更なし。格闘後の左右蹴りは独立の3m／10m/sと既存2倍モーション時間を明示的に保持。Kick_bの後方5mジャンプも別アクションとして不変更。
- 新規v312静的/Godot実行回帰テストで8方向の距離・速度・実移動、傾斜方向、14cm低姿勢、終了時復帰、蹴り派生が通常回避の処理から独立していることを確認。Android実機映像は未検証。

## 2026-11-13 — SERA v313 通常BOOSTを全方向5mに制限
- 長押しドラッグで確定する手動BOOSTに、1回の発動あたり5.0mの水平移動距離上限を追加。前後左右・斜めを問わず、途中の方向変更も実移動距離に加算する。衝突で停止した分は計上せず、最後の物理フレームは残距離を超えない速度へ制限する。
- 5m到達でBOOSTを終了しRUNへ戻す。外周ホールド中は無限再発動しない。指を内側の解除リングへ戻すか、新しいタッチで再武装。既存0.20秒のRUN/BOOST速度補間、0.50秒のポーズ維持、EN、当たり判定、装備速度補正を保持。
- 通常STEPの7m・15m/sとリーン、左右蹴り3m、サマーソルト5m、格闘追尾、カメラ、Blockbench原本は無変更。v313静的/Godot実行回帰テストをCIへ追加。Android実機確認は未実施。


## 2026-11-13 — SERA v314 訂正：5mは通常フリックステップ、通常BOOSTの上限は撤回
- v313で「ブースト距離5m」の依頼を継続ドラッグ型の通常BOOSTとして解釈して距離上限・再武装判定を導入したが、ユーザーの訂正により対象は「各ステップ距離」と確定。
- v313で追加した通常BOOSTの5m打ち切り・積算・再武装ロジックを撤回し、v312の継続RUN/BOOST操作へ戻す。0.20秒の速度補間、0.50秒のモーション保持、入力半径・EN・スラスターを維持。
- 通常の全方向フリックステップは前後左右・斜めすべて7mから一律5mへ変更。速度15m/sと装備補正を維持し、標準の移動時間は5/15≒0.333秒。画面フリック基準の直線移動、衝突掃引、ロック方向のモーション選定、22°/14cm回避リーンは無変更。
- 別アクションである左右蹴り派生3m/10m/sとKick_bの後方5mは無変更。既存距離検証を現行仕様へ更新し、v314回帰検査をCIに追加。Android実機は未検証。


## 2026-11-13 — SERA v315 通常STEP始動1mワープと発動地点の50ms残像/加速噴射
- 360°通常フリックステップを発動した瞬間、画面入力を地面に投影した進行方向へ最大1mの衝突掃引を行い、`reset_physics_interpolation()`で補間移動の見た目を排除。5m総移動距離と15m/s（装備補正）を維持するため、実際に進んだワープ距離を`step_traveled_distance`とステップ経過時間へ先に計上し、残りだけを通常の直線ステップで移動する。
- 発動前のセラ全身を既存のワールド固定残像プールへ0.05秒のスナップショットとして確保。選択装備のバックノズルに属する十角形噴射メッシュ/ShaderMaterialを独立複製し、元ノズルの世界座標へ固定した加速バースト（burst=1）を0.05秒間表示後に破棄。
- 描画優先度/深度テストは従来のAFTERIMAGEとDEPTH_TESTED_EMISSIVEを継承。通常ステップ中の従来の残像・ノズル挙動、RUN/BOOST、コンボ左右蹴り、Kick_b、攻撃/ロック/カメラ、原本キーフレームは変更なし。
- v315専用の静的/実Godot 8方向・移動/FXテスト追加、v300の距離比較を発動前の位置基準へ更新。Xperia 1 V実機描画・操作感は未検証。


## 2026-11-13 — AI開発高速化とCIの現行仕様分離（ゲーム挙動変更なし）

- GitHub Actionsの失敗履歴を確認。旧STEP距離や向きを固定するv200/v211/v278/v285/v308/v310/v311等のテストが、意図された現行仕様変更と衝突していた。
- 現行仕様ファイルと独立した値検査を新設。旧テストの数値期待値を共通化し、モーション・衝突・方向・旧機能の実行検査は維持する。
- 関数/アセット/登録済テストの索引、CI対象パスの包括化、重複したv293 PRワークフローの手動化を実施。
- エディタキャッシュのGit追跡を外す。Godot/Androidのランタイム仕様は変更していない。実機検証は未実施。
- モデル/モーションの正本統一や巨大なmain.gdの責務分割はこのPRでは行わない。


## 2026-11-13 — v316 モデル・モーション正本整理

- models/manifest.json に正本を統合。通常・鳥脚・カタナ・装備A/B・頭C・下半身Dを別々に管理。
- 鳥脚不要な上半身・他セットを除去、装備モデルから過去のC頭/D脚と全アニメーションを除去。元の骨格・キーフレーム・UV・Pivotは維持。
- sera_rig、sera_equipment、command_nexusの読込先を正本へ変更し、Android用埋込データを再生成。
- v316専用の静的・Godot実行検査を追加。旧モデルは回帰検査の履歴として保護し、実機は未検証。
- APK用にカタナ原本二段の専用埋込パックを生成し、原本.bbmodelが見つからない場合に使用するよう修正。
- カタナ初段・二段目の両方をKatana.bbmodelから優先して実行時に取り込み、Standard側の同名初段は互換フォールバックのみに限定。


## 2026-11-13 — 開発高速化：モデル自動再生成・CI計測（ゲーム挙動変更なし）

- manifestの正本から6種類のBlockbench派生データを一時ディレクトリで生成し、バイト照合。全工程成功後のみ更新できる `sera_model_build.py` を追加。
- 更新漏れをCIテストで検出。既存生成スクリプトは変更せず、単一の実行入口を作成。
- 実測時間に基づき遅い回帰テストを先に並列投入、全件の個別プロセス検査を維持。JSONレポートをCIから取得可能にする。
- 変更なし：Godot本体、Blockbench正本、生成アセット内容、ゲームバージョン v316。


## 2026-11-13 — v316開発基盤：関数範囲索引とカメラ数学の段階分割

- main.gdの3つのカメラ追従計算を純粋関数 `scripts/sera_camera_math.gd` に抽出。ラッパーの呼出順、旧係数、補間済み位置、視点安全処理は維持。
- 関数索引でスクリプト内の正確な開始/終了行、呼出候補とリソース参照を表示。開発計画にも終了行を付与。
- 既存v288静的テストを分割後の実配置へ更新。新しいGodot数学実行検査と静的検査を登録。
- Androidのカメラ体感は実機検証待ち。ゲーム版v316を維持。


## 2026-11-13 — v317 Android診断オーバーレイとCI検査棚卸し

- トレーニング画面の既存デバッグ列にDIAG ON/OFF、ON時のみCOPY LOGを追加。サンプルは0.12秒間隔・最大500行で、FPS、ゲーム状態、再生モーション、ロック、操作入力、EN、カメラYaw/距離/追従誤差、STEP実測距離を収集。ログはコピー操作時に限りクリップボードへ渡し、ネット通信・ファイル保存をしない。
- タッチは既存のテストボタン用UIヒット判定で消費するため、診断操作から通常攻撃・STEP・移動を発動しない。診断は初期OFF・再起動時に記録しない。
- 登録済テストの内容ハッシュ重複候補、未登録の歴史的テスト候補、実測時間を一覧化する読み取り専用 `sera_ci_inventory.py` を追加。重複の自動削除は行わず全件CIを継続。
- v317新テストを追加。クラウドheadlessの成功はAndroid実機でのタッチ・表示確認を代替しない。


## 2026-11-13 — v317 main.gd第1回分割（動作仕様変更なし）

- `sera_input_gestures.gd` にRUNアナログ入力、左右・全方向STEP、コンボ蹴り判定、ジャンプの入力判定、タッチ画面範囲を切り出し、main.gdから定数とジェスチャ状態を渡す設計に変更。
- `sera_movement_math.gd` にカメラX/Zスクリーン投影とロック相対のSTEPモーション方向変換を移動。main.gdに既存の関数名/順序と状態管理を維持。
- 専用Python静的チェックと、実際のGodotシーンで閾値・360°方向・ロック姿勢・カメラ投影を確認するランタイム検査を追加。全件CIで検証後に統合。


## 2026-11-13 — v317 main.gd 第2回分割：ロック計算
- `sera_lock_management.gd` を追加。AUTOはセラとターゲットを結ぶ平行2本線で即座に部位取得、MANUALは画面X順・折返し、ターゲットへの水平向き、マーカー端表示を独立化。
- `main.gd` に既存のメソッド名、攻撃中のロック保持、AUTO/MANUAL状態、UI操作を維持。定数・距離・カメラ仕様・モデルは変更なし。
- 既存ロック静的/Godot回帰テストに加え新モジュールの直接実行検査を導入。すべて通過時のみmainへ統合。


## 2026-11-13 — v317 main.gd第3回分割：戦闘状態の判定ポリシー

- `sera_combat_flow.gd` を追加し、ガード開始可否、Bash/コンボ継続ウィンドウ、コンボ全体のロック保持、2段Katana/3段通常攻撃の段数・クリップ・キャンセル時刻、4種の追尾時間クランプを純粋関数化。
- `main.gd` にすべての状態変数と更新処理、音声・移動・当たり判定・リグ処理を残し、旧関数は薄い互換ラッパーとして保持。
- 各ルールを実トレーニングシーンで呼ぶGodotテストとPython静的テストを追加。全件CI成功後に統合する。
- v317は据え置き。ユーザー確認済みの操作・ロック・カメラ挙動を基準として保持。


## 2026-11-13 — v317 main.gd第4回分割：カメラ射影・旋回角の純粋計算

- `sera_camera_framing.gd` に必要カメラ半径とSTEP相対Yaw角の制約計算を移設。近クリップ+0.005、画面マージン、旋回速度制限などを維持。
- `main.gd` に元のメソッド、カメラ状態、安全フレーム判定とズーム更新を維持し、入力操作やモデルには変更なし。
- v232/v285静的回帰を修正し新規静的/Godot実シーン検査を登録。CI186件全成功のみマージ可能。ゲーム版v317据置。


## 2026-11-13 — v317 main.gd第5回分割：RUN/BOOST状態更新の純粋計算

- `scripts/sera_boost_state.gd` を追加し、指位置に基づくBOOSTヒステリシス・開始確認と、RUN/BOOST切替の0.20秒smoothstep・途中反転・リセットを純粋関数に移設。
- `main.gd` にエネルギー制御、入力受付可否、現在値、Touch UI更新・実移動・装備依存の希望倍率を残す。既存のメソッド名と数値、挙動を変更しない。
- `tools/v317_boost_state_self_check.py` とGodot実シーン回帰をCIへ追加（総登録188件）。旧ゲーム仕様を変更せずv317を維持。全件成功を統合条件とする。


## 2026-11-13 — v317 main.gd第6回分割：EN・SH回復規則

- EN消費の可否・枯渇判定、回復待機タイマー、EN/SH再生値、60％解禁の純粋演算を `scripts/sera_resource_rules.gd` に移設。現存の `main.gd` ラッパー・HUD・EN枯渇時演出・装備消費・BOOST最終消費処理・KOとガードブレイクの副作用はそのまま。
- 24EN/s、16SH/s、消費後0.25秒停止、判定誤差0.0001、解禁60％を維持。回復待機がちょうど0になるフレームも従来通り回復。
- Godot実シーンで消費可否・EN 60％解除・SH回復抑止・数値上限、Python静的テストで依存境界を確認。登録190件の全CIを統合条件とする。ゲーム版v317据置。


## 2026-11-13 — v317 main.gd第7回分割：戦闘タイマー整理

- `scripts/sera_combat_timers.gd` に純粋なカウントダウンと、スタン解除フレームから開始する8/sゲージ自然減衰を抽出。追加メモリ割当を避ける単一float返却の関数として分離。
- `main.gd` の `_tick_combo_window_timers` と `_tick_target_recovery_timers` に複数タイマーの更新順序を集中。KO中停止、入力受付前のコンボウィンドウ更新、EN/SH回復後のスタン・ブレイク処理、敵攻撃再開条件、ダウン終了・ガードブレイク解除の副作用は移動せず従来通り。
- 全192件CIにPython静的順序テストとGodot実シーンの期限・状態更新テストを登録。ゲーム仕様変更なし、v317据置。


## 2026-11-13 — v317 main.gd第8回分割：ヒットFXの寿命と表示更新

- `scripts/sera_hit_fx_presentation.gd` を追加。投射物着弾オーバーレイ、BODY打撃フラッシュ、与ダメージ数字の2D位置・フェード、被ダメージ表示のフェードを、ノードを明示的に渡すヘルパーへ移しました。色・秒数・原点・画面座標演算は旧式のまま。
- メインの各残時間カウントダウンには `COMBAT_TIMERS.remaining_after_delta` を使用。実際の残時間と投影原点、描画順、partごとのFX再生、HitBurst、敵のコンボ保持中の再出現延期およびロック解除とパーツ初期化は `main.gd` が管理。
- 部位個別エフェクトがBODYへ漏れない既存v302テストを新ファイルの数式参照へ更新。新しい静的テストとGodot実シーン回帰を登録し、合計194件を全CIで検証。ゲーム仕様・モデルは変更なし。


## 2026-11-13 — v317 main.gd 第9回分割：敵のライフサイクル整理

- `scripts/sera_target_lifecycle.gd` を追加。移動停止（攻撃予兆、HPゼロ、スタン、部位ブレイク、ダウン、KO）、射撃許可（HP・スタン・部位ブレイクのみ）、再出現の待機／コンボ保持中の0.01秒再試行／復旧判定を副作用なしで独立化。
- `main.gd` は実シーンの移動・射撃状態・コンボ保持・部位・ロック・HUDを所有。`_tick_target_respawn` を旧 ` _advance_hit_fx` の末尾タイミングで実行し、KO後復旧とBOSS再出現に重複していた13行のリセットを `_reset_target_after_respawn` に集約。シーン所有の副作用・更新順は変更せず、同時に消えてしまう部位や先走った再出現を防ぐ従来ゲートを保存。
- `tools/v250_target_hp_self_check.py` と第8段階のFX順序テストを移設先に追従させ、既存条件を維持。新規の静的/Godotテストを2件登録し、合計196件の全PR CIで検証。ゲームv317据置。


## 2026-11-13 — v317 main.gd 第10回分割：物理フレーム状態判定

- `scripts/sera_physics_frame_rules.gd` を追加。RUN/BOOST速度・EN消費と独立した0.50秒のBOOST姿勢継続、ジャンプ／着地／Kick_bの移動権、STEP・突進後の実変位速度、通常・加速スラスターの発火判定を純粋関数へ委譲。
- `main.gd` は`_tick_boost_pose_grace`の状態更新入口と、実際の移動・衝突・当たり判定・ターゲットロック・入力・リグ・加速スラスターの描画と状態変数を所有。通常攻撃の予備動作から振り抜き・ヒットストップ中まで噴射が途切れない条件は従来と同一。
- 方向転換時の姿勢継続と各種割込み、飛行の開始/終了境界、壁接触後の実移動量、通常噴射と加速バーストのトリガー条件を新規Python・Godotテストで検査。既存v220検査を同じ実ロジック参照へ更新。全198件CIを統合条件とし、ゲームv317据置。


## 2026-11-13 — v317 main.gd 第11回分割：モーションとスラスターの向き

- `scripts/sera_motion_direction.gd` を追加。ロック先に正対するSERAのランポーズ相対方向（入力アナログ量は変更せず）、BOOST入力の即応・無入力時のキャッシュ・サマーソルト噴射反転・格闘追尾/振り抜き時の後方安定・壁衝突で移動0時の代替向きという計算を独立化。
- `main.gd` はカメラ相対のworld_move変換、ロックやCharacterBody3Dの実際の移動/衝突、保持方向と背泳ぎ/左斜め後退のノズル制約、噴射アニメーションと入力処理を所有する構造を維持。方向計算ヘルパーは状態変数・シーン参照なし、毎フレームの辞書割当なし。
- v214 BOOST向き保持、v221格闘スラスター持続、v295 RUN正面の検査を新たな単一実装参照へ追従し、新規Python/Godot実行テストを追加。200件のCIと描画/モデル監査を統合条件とし、ゲームv317据置。


## 2026-11-13 — v317 main.gd 第12回分割：後退・画面左ノズル補正

- `scripts/sera_nozzle_steering.gd` を追加し、STEP(実移動方向→フリック→専用BACK)、Kick_b、BOOST(入力→保持状態)の後退重み、左方向入力重み、画面下↔画面右扇形と後退量に応じた世界下方への再補間を純粋関数へ分割。0.000001判定、legacy BACK/LEFT、0.50左右重みを維持。
- `main.gd` にはカメラ方向射影、BOOST中の方向・ノズル重み・左扇形キャッシュ、メカノズル本体の可動範囲(左右80度、上1度、下90度)、シェーダー・時間表現・リグ更新を保持。補間順序は`DOWN.slerp(right,w*0.5).normalized().slerp(DOWN,back).normalized()`のまま。
- 既存v210/v212/v213/v214/v261/v262とStage11の境界検証を移設先の実数式参照に更新。Godot実シーンでSTEP・専用後退・BOOSTキャッシュ・Kick_b・方向別扇形・斜め後退重みを確認し、全202件のCI成功を統合条件に設定。ゲームv317据置。


## 2026-11-13 — v317 main.gd 第13回分割：スラスター状態・最終FX更新

- `scripts/sera_thruster_presentation.gd` に最後のBOOST噴射方向・後退重み・画面左扇形の3値を集約し、最終的な `rig.call("update_back_thruster_fx",...)` を委譲。`main.gd` はこのシーンごとの1インスタンスを所有し、入力・カメラ・STEP・加速スラスターの発火判定と戦闘状態、実際のノズルモデルと描画を引き続き管理します。
- ニュートラル指移動では3値を保持し、方向反転時は即時更新。表示BOOSTがなくても実BOOST中は保持をクリアしない点、両方が終わって初めてクリアする点、噴射OFFでも毎物理フレーム更新する点を維持。毎フレーム辞書生成なし。
- v206/v212/v213/v214/v216/v221/v261/Stage11/Stage12テストは新しい責務境界の実処理を参照させる形に移行。新規静的1件・実Godot1件を登録した全204件CIを統合条件とし、ゲームv317据置。


## 2026-11-14 — v317 main.gd 第14回分割：戦闘状態HUDの独立化

- `scripts/sera_combat_hud_text.gd` に、ガード反応、Kick_b/Jump着地・フォールバック、STEPの前後左右/斜め/蹴り方向、格闘中の予約/再生中クリップ、BASH/追尾残り時間、RUN/BOOST/姿勢継続の表示文言とフォーマットを純粋関数へ分離。
- `main.gd` は`_refresh_combat_state_hud`へ状態優先度・ラベル更新を集約、`_physics_process`末尾に元どおり床位置追従後の一呼出しを残す。DOWN > GUARD BREAK > DAMAGE > GUARD > KICK BACK > LAND > JUMP > STEP > COMBAT > RUN/BOOST の分岐と数値は保存。`_active_strike_clip`・リグクリップ名は必要な枝でだけ呼び出す。
- Python静的契約・Godot実シーンの状態表示テスト計2件を追加して総206件の全CIへ登録。ゲームv317据置。


## 2026-11-14 — v317 main.gd 第15回分割：HP/EN、ロック、STEPの数値HUD

- `scripts/sera_numeric_hud.gd` を追加。プレイヤーHP/ENバーの`CombatVitals.set_vitals`呼び出し、敵HPバー幅（300×HP/500）と残HP40%色判定、DEF%/SH切上げ、ロック部位残HPとDOWN/BREAK/STUN/MOVE/HOLD、STEP速度とKick_b/蹴り/デバッグ/衝突後の実走距離を副作用を限定した表示専用関数に分離。
- `main.gd` は`_tick_resources`のEN/SH回復・解禁と更新順序、対象部位名・部位HPと最大HPの取得、`_refresh_numeric_status_hud`の主導、UIラベル/部品の所有を維持。`_refresh_step_status_ui`も入口のみ残して、固定閾値・表示条件は移設。物理フレームのSTEP SPEED変更検知も同一関数に委譲。
- v250・v268・Stage6リソース静的テストを新モジュール参照に更新し、実際のGodotシーンでHP/EN、40%閾値、DEF/SH、BODYと部位ロック、STEP/蹴り/履歴の表示を確認する新規2テストを登録（総208件）。モデル・操作・ゲームバージョンv317据置。


## 2026-11-14 — v317 main.gd 第16回分割：戦闘HUD生成・配置

- `scripts/sera_hud_layout.gd` を追加し、コンパクトHUDの上部パネル、HP/EN・敵HP表示、アクション状態、STEP速度と詳細の生成・色・フォント・アンカー・レイアウトを分離。
- `main.gd`の`_build_overlay`は、フルスクリーンタッチUI→ロックボタン→HUDパネル→持ち替え/拠点ボタン→アクションとHP/EN→その他HUD/診断パネル→STEP速度/詳細→被弾演出→敵攻撃UIの旧順序を厳守。持ち替えと拠点帰還ボタンのPressedコールバック、手動タッチ除外、ノード参照、物理更新と情報HUD書換えは`main.gd`所有。毎フレームの新規辞書割当なし。
- 新規Python1件とGodot実シーン1件で従来の親子階層、描画順、背景の範囲、HP/EN/STEPのアンカー、ボタンの入力対象・イベント配線を検査。総210件のCIを統合条件とし、ゲームv317・モデル・モーション・操作仕様は据置。


## 2026-11-14 — v318 STEP短距離化と追従カメラの連続応答

- 通常360°STEPを総距離5→4m、開始スイープワープ1→0.3mに変更。15m/s、0.05秒の開始残像・スラスター、衝突スイープ、ワープ済み距離のタイムライン控除を維持。横蹴り派生3m/10m/sと後方サマーソルト5mは変更しない。
- STEP開始時は0.07秒でカメラYawの追従を減衰。終了後0.06秒の静止区間を挟み、合計0.30秒内で滑らかに元の追従感度へ戻す。ズーム・当たり判定・画面端保護は従来のまま。
- 通常移動の水平Yawに22°の左右余白を追加し、余白を越えた角度には従来の追従レート10/sで反応。前後移動・ズーム・フォーカスの通常感度は維持。
- 近接追尾の連打（通常3段／Katana／Bash／左右・後方フリック／ループ再入力待ち）をひとつのカメラ状態として保持。フォーカスは15→27/s、Yawは10→20/sへ0.65秒で段階的に加速し、連打終了から0.18秒で連続的に通常モードへ復帰。衝突スイープ・スラスター・モーションは変更なし。
- 現行STEP契約をv318仕様へ更新し、旧版の履歴テストは新仕様参照へ改める。Android実機での見た目と操作感は別途確認が必要。


## 2026-11-14 — v318 リポジトリ最終整理（実行時ファイルは不変）

- `README_v318_ja.md` だけをルートに残し、旧バージョン `README_vNNN_ja.md` 288件を `docs/history/release_notes/` へ移動。旧版 `README_ja.md` を同フォルダの `README_legacy_ja.md` に保存。すべてGitのblob SHAは同一で、歴史的な内容を編集していません。
- `README.md` と `README_ja.md` は現行v318、開発ルール、モデル原本、リリースノートへの入口に更新。
- 完了済みのGitSync確認マーカー `SERA_AUTOSYNC_TEST.txt`、`SERA_SAFE_SYNC_TEST.txt`、`SYNC_PROBE_20261107_STAMINA.txt` を削除。 `models/storage/.trashed-1796821878-頭C.bbmodel` は `models/storage/頭C (2)_20261109_222329_691.bbmodel` とGit blobが同じため削除。6つのモデル正本、生成埋込資産、歴史的な異内容モデル、Godot `*.import` メタデータ、既存CIテストを保持。
- `docs/SERA_REPOSITORY_LAYOUT_ja.md` を作成し、今後の開発ファイル・モデル・リリースノートの置き場所と削除判定を明文化。 `AGENTS.md`、`docs/SERA_DEVELOPMENT_FASTPATH_ja.md`、`docs/SERA_MEMORY_INDEX.md`、`.gitignore` を新配置へ追従。
- `tools/sera_repository_layout_self_check.py` をCIに登録。現行版READMEのルート正本、履歴保存、旧プローブ排除、モデル正本保護、開発案内を検査。ゲーム名称SERA v318、入力、衝突、モデル・モーション原本の内容、エフェクト、エンジン設定、実行スクリプトは変更しません。
- 旧版READMEへのGitHub URLは移動後の新しいパスに変わります。Android端末に古い版のREADMEを手元に保持している場合はGit同期で新旧の配置差が発生します。CIの成功だけで端末内GitSync状態まで検証したとは扱いません。

## 2026-11-14 — v319 立ち→RUNの部分着地ブレンド／破壊後・KO後も攻撃命中

- `sera_rig.gd`: WAIT→通常RUNの開始時のみ、既存Jumpの着地区間（0.375～0.500秒）を45%進めた部分姿勢を0.11秒の正弦ベル形（最大62%）で重ねる。通常RUNの再生時計はこの0.11秒だけ停止し、着地完了を経ずにRUNへ移行。移動速度、BOOST/STEP、実際のジャンプ着地には影響させない。移行中の誤った足音・接地補正も防止。
- `target_parts.gd`: 5部位の`broken`は機能停止と見た目だけに適用し、ロック候補・当たり判定・衝突・防御・被弾エフェクトを保持。耐久0の部位も通常攻撃を受けられるが、破壊ゲージと再破壊イベントは増減しない。
- `main.gd`: 共通HP0で近接・Bash・左右蹴り・サマーソルトの命中・追尾とダメージ計算を遮断しない。敵HPは0で固定のまま、ダメージ数字は攻撃力×防御率から算出した実ダメージを表示（残HP分への切詰めや0表示なし）。撃破時だけリスポーンタイマーを始動し、撃破後の追撃で再起動しない。敵側の行動・発砲停止は維持。
- v319新規Python・Godotシーン検査をCI登録。旧版の「破壊後はロック対象外」検査は新仕様へ更新。Android実機の最終確認は別途必要。


## 2026-11-14 — SERA v320: 電脳セクター導入準備・待機→歩行の姿勢修正
- 再生制御: `scripts/stage_bgm.gd` は `BGM/dennou_sector_seamless.ogg` が存在すれば初回全体再生＋18.46153846秒へのシングルストリーム・ループに切り替える。BGMファイルはGitHubのテキスト用APIからアップロードできないため、Ogg別納品後にGitへ追加する。未配置時は従来v08のイントロ/ループを維持。
- `scripts/sera_rig.gd`: v319の通常WAIT→RUN限定の着地モーション中間ポーズ重畳および110ms RUN停止を削除。原本Jumpキーフレーム、実着地、RUN以外の攻撃・BOOST・STEPは保持。
- `tools/v319_idle_run_persistent_hits_*` を新仕様に更新（永続当たり判定のチェックは維持）。`tools/v320_training_bgm_idle_run_self_check.py` をCIマニフェストに登録。
- Android端末で実際の音のループ継ぎ目・姿勢の最終確認が必要。

## 2026-11-14 — SERA v321：歩行腰高さ・近接カメラ・刀鞘・材質描画
- 添付1000035171.mp4／1000035172.mp4を参照。原本モデル・原本モーションのキーフレームは変更せずランタイム姿勢の上下補正のみ実施。
- `sera_rig.gd`: 通常RUNのWaist上昇を防止。原本RUN根元のY=+1.5 BB units（約+0.0975m）は待機-3 BB units（約-0.195m）より約0.29m高く、待機→歩行で不自然な直立化を作っていた。RUN系の根元Yを-0.235m中心に変換、上下動は0.25倍に制限。前進／後退・360°で共通。
- `sera_camera_math.gd`／`main.gd`: 追従フォーカスが0.65mの遅延上限へ一挙にスナップする旧動作を、レンダーフレーム内の移動距離制限へ変更。ボス中心と近接・交差する時の相対bearingを0.4〜2.2mで角度平滑化し、視点の急反転を緩和。STEPカメラ0.3秒回復／通常感度・上下角は保護。
- `sera_equipment.gd`: Katana_l/l2/l3の鞘本体3メッシュを表示維持。Katana_r_sayaの納刀刀身2メッシュ／Katana_r_nukimiの抜き身2メッシュだけを第4フレーム以降に排他切替。連撃中も鞘本体は消さず、刀装備を外した時だけ全Kメッシュを非表示。
- `sera_rig.gd` と `docs/RENDER_PIPELINE_POLICY_ja.md`: 斬撃時の深度無視半透明全身オーバーレイが、A/Bアトラスのみを参照してC/D装甲等の固有材質を覆う不具合を修正。機体全パーツの`material_override`を攻撃中も維持し、KO／EN個別オーバーレイのみ使用。
- v276/v290刀、v288カメラ、共通カメラ数式テストの旧期待値を更新。v321静的とGodot実シーンの新テストを登録。実機のGL Compatibility描画とカメラの操作感はヘッドレス検査対象外。

## 2026-11-14 — SERA v322: Katana Swordeffect authored import / safe staging cleanup
- Incoming: `models/storage/Katana.bbmodel`; exact edits compared with canonical `models/core/Katana.bbmodel`. Non-animation geometry, hierarchy, UUIDs and UVs were unchanged. Editor-only selection flags differ. In `Melee_katana2` the `Foot_L` first-frame rotation changed from -2.5° to 0°; the other two Foot_L keys are reordered but identical. No right-arm movement key changes were detected.
- Replace both `Melee_katana` / `Melee_katana2` animation entries in the core model, retaining their exact authored keyframes. `Swordeffect` UUID `cd682f33-b5f1-debc-4bcf-ce5d0e588753` now contains new position/rotation/scale keys at 0.33333s (first) and 0s (second); the same Standard rig pivot drives the original v85 arc/convex-volume/particle generator (`scripts/sword_trail.gd`). No duplicate effect geometry, full-screen plate or extra model runtime path is added.
- Regenerate `assets/sera_katana_data.gd` via `tools/rebuild_katana_data.py`, maintaining the export fallback. New Python/Godot verification checks canonical and embedded animation, exact authored pose and FX parent/mesh behavior; full CI required before merge.
- Add permanent incoming-file workflow to `AGENTS.md`: inspect strage/storage, map to manifest canonical sources, replace clips, rebuild, test, then audit/delete only unreferenced temporary input. Historical validation fixtures remain.

## 2026-11-13 SERA v323
刀2段目専用の剣閃方向補正と0.20833秒の振り始め同期。原本キーは保持。ローカルGodot 4.6.3で検査、Android外観未確認。

## 2026-11-13 SERA v324 — カメラ復帰・浮遊揺れ
距離差に応じた近距離ズーム復帰とフレーム収容半径の解放速度を追加。攻撃中の拡大距離ラッチを解除。敵フレーム判定を基準高さ＋浮遊±0.07mの包絡に固定し、位置・ロックは実座標を保持。STEP/yaw/入力/モデルを維持。30/60/120Hz復帰、combat hold、浮遊周期の実シーンテストを全CIへ登録。旧CIの浮遊位相／攻撃中ズーム保持の期待値を現仕様へ更新。Android実機未確認。

## 2026-11-13 SERA v325
提供動画2本を確認。横移動の横余裕解除を8/sで補間し、2.2m境界のbearing即時復帰を除去。刀2段目はローカルX反転ではなくY軸180度（面内2軸反転、法線保持）に修正。原本キー・タイミングは保持。Android修正版未確認。

## 2026-11-14 — SERA v326：カメラのフレーム収容振動とKatana剣閃の向き

- 添付1000035180.mp4／1000035181.mp4を参考に、通常移動でもBOOSTで実績のある解析的な透視投影フレーム最小半径を採用。ピクセル境界での全画面二分探索と縮小解除の行き来を抑え、実際に収容できない場合のみ従来の投影判定を予備的に使用。プレイヤーと敵の表示領域を維持し、既存の移動感度・STEP回復・カメラYawを変更しない。
- `sword_trail.gd` の刀2段目だけに入っていた追加のY軸180度回転を撤去。`models/core/Katana.bbmodel` の `Swordeffect` に既に設定された各クリップ固有の位置・角度・スケールをそのまま反映し、描画面の法線・UV・パーティクル・発生タイミングを保持。
- v323の実行時チェックを現行の原本追従仕様に変更し、v326のPythonとGodot実シーン検査をCI登録。原本モデル・生成データ・刀モーションのキーフレームは変更しない。Android実機の映像確認が必要。

## 2026-11-14 — SERA v327：敵の体に乗らない接触／受動落下／サマーソルト接地

- 敵の縦バウンドは視覚演出として残し、物理`TargetSolidBody`のY位置のみ基準高さに固定。敵の脚・胴体に接触しても移動用の実コライダーが上下方向にセラを運ばないようにする。
- `move_and_collide`の通常／ステップ／格闘XZスイープ後は衝突分離で生じたY成分を破棄。通常の`move_and_slide`後は衝突前の高度へ戻し、`STEP`・ジャンプ・攻撃・サマーソルト・着地モーション中は高度の所有権をそのアクションに残す。物理床がないため受動落下は基準Y=0へ向けて`JUMP_GRAVITY`で独立計算。敵の上面は着地床にならない。
- 既存JumpおよびKick_b後方アークでは水平方向だけが敵コライダーに遮られ、Yは原本モーションの飛行高度に従う。サマーソルトが元々浮いた位置から始まった場合も、完走位置はY=0まで滑らかに補間する。
- Kick_bは終端キーフレームがリグに実描画されたことを確認する既存ゲートを保持。確定後のみ0.055秒の姿勢クロスフェードを経て0.20秒の着地へ移り、各着地キーフレームで選択装備の実足裏最下点を地表へ合わせる。原本モーション・RootのXZ移動と攻撃判定は保持。
- 新規Python・Godot物理とアニメーションの回帰検査を追加。Android/実機での接地の視覚結果は別途検証。

- CI継承検査更新：v199/v200/v299の「待機時のみ接地」「着地補正呼出数」契約へサマーソルト着地分岐を明示的に追加。v274/v279/v281の旧鉛直衝突と着地高さ固定期待を、Y=0接地と水平衝突に置換。v326刀・カメラは最新版v327以降でも維持する版数の下限検査に修正。静的検査は削除せず継続。

## 2026-11-14 — SERA v328：利き手対応ロックUI・SYSTEMロックモード・着地STEPキャンセル・ターゲット中心カメラ

- SYSTEMに保存式AUTO/MANUAL設定を追加（user://sera_settings.cfg / controls / auto_lock_enabled）。訓練起動時に読み込み、既存パーツ手動切替の判定と連動。
- 戦闘中ロックは左矢印・サイト絵柄・右矢印のみ。中央サイトを押してもモードが切り替わらない。右利きは左側、左利きは右側に3つを連動配置。LINES診断を別の表示域へ分離。
- 着地モーションの任意フレームでフリックSTEPを許可。EN消費成功時だけ着地フラグ／Jump再生を終了し、ステップへ直接移行。失敗時は着地続行。非STEP入力は引き続き無効。
- カメラXZ注視点をボス中心に変更、Player方向へ43°のショルダー構図を使ってセラを左右に分離。カメラの表示側反転は画面14%を超える反対側への移動が0.28秒継続した場合だけ。ズームは単一の解析的フレームフィットを使用、ピクセル端再投影によるYaw制御とズームの競合を除去。安全範囲を外れた場合のみ既存の投影検査をフォールバック。
- 歴史テストを現行仕様と照合し、フルCIでGodot/Androidの旧挙動を保護。実機の画面構図・操作感は未検証。

- v328初回CIにて旧来の左右固定ボタン/ゲーム中AUTO切替/プレイヤー中心追従/端Yaw補正を固定した歴史テスト12件を現在の仕様へ更新。歴史回帰そのものは全件維持し、v287/v288の実Godot追従試験は移動対象をプレイヤーからボスへ切替。

- v328実Godot回帰は従来の画面右側固定LOCKアンカー順の1件のみNG。v286の実行検査を右/左それぞれのアンカー+オフセットへ更新。併せて被弾時だけ旧12°ハードリーシュ角へ瞬間復帰する分岐を撤去し、通常・格闘・被弾時の同一43°角度プロファイルでカメラYawを滑らかに追跡。

- 旧CI（v263/v285）の被弾時12°ショルダー参照を新規の一貫した43°補間へ更新。カメラ角度のモード間スナップが復活しないよう静的保護を維持。

## 2026-11-14 — SERA v329：画面上のセラ正面基準フリックと20%安全域

- 検証：v328は画面投影正面をタッチ開始時に取得する一方、Bash／右左蹴り／Kick_bの分類と候補保持は固定 `Vector2.UP` だった。今回コンボ全方向とガード中Bashで`gesture_screen_forward`を唯一の基準に変更し、指の最中のYaw変化では再サンプルしない。通常STEPの移動は画面上の360度入力を保持する。
- `sera_input_gestures.gd` に投影前方軸を渡し、フリックセクターを回転。モーションの原本・格闘コンボタイミング／ダメージ／画面相対STEPは維持。
- カメラ：2%だったプレイヤーの水平方向保護域を20%へ拡大。解析的フィットは22%の余裕で解く（胴体外郭±0.38mを含む）。静的とGodot実行検査を追加。Androidでの外観確認は別途。

- v329全CI初回では旧版SCREEN-UP固定分類の契約検査13件が新仕様と衝突。関係する旧テストすべてを削除せずに投影セラ正面の優先判定へ更新。v284 Godotテストでは基準を4方向回転させて各方向蹴りとバッシュを再検証。

- v274の補助アサーションでも固定DOWNを残していたため、サマーソルトは投影セラの後方とする仕様へ修正。単独の不変条件は保持。

- v324旧実Godot回復検査は旧2%画面外郭に依存し半径16mを上限固定していた。新規20%画角では必要距離17m以上が妥当なため、一律16mではなく解析的な安全半径+0.6mまでに収束することを検証。30/60/120Hz比較・0.01m以下のホバー揺れ検査は保持。

## 2026-11-14 — SERA v330：v327以前のカメラワークを復元

- ユーザー指示により、セラを意図的にボスの左右へ配置するv328のカメラ構図を撤回。v327（commit `deef5fe7213a50f983011b1b8e7d8b01f2ddfbed`）のカメラ関数を原本から復元（`_build_camera`, `_process`, `_desired_camera_follow_focus_xz`, `_adaptive_camera_yaw`, `_minimum_boost_camera_radius`, `_horizontal_safe`）。
- 43°構図と自動左右切替の状態、v329のプレイヤー端20〜80%制限を廃止。従来の焦点=セラ＋ターゲット方向への最大2mリード、12°ショルダー、2%横端フレーム安全判定、通常/BOOST別のフィットを復元。
- カメラ以外のv328/v329のUI・フリック・着地キャンセル・v327の衝突処理は維持。v330固有の契約・Godot実シーン検査を導入。Android実機確認は未実施。

- 継承CI更新：v229/v230/v232/v287/v288のカメラ専用Python/Godot検査はv327実施当時のファイルへ復元。v328のロックUI・着地STEP、v329の画面投影正面フリックの検査はそのまま保ち、カメラ構図のアサーションだけをv327の2%/12°/セラ追従へ変更。コードのカメラとテストの両方で旧挙動の正確な一致を保証する。

## 2026-11-14 — SERA v331：回転フリック90°ガイド／WAITからRUN前の0.2秒着地

- `touch_overlay.gd`: コントローラーのRUN円内を4×90°のリング状扇区に色分け。前=赤、左右=黄、後=低輝度青灰。既存HUD入力/レティクル・RUN/BOOST表示は変更せず描画専用。フリック判定と同じ投影セラ正面を使用し、通常移動中は24/sの最短角・指数補間。コンボ/ガード受付中はタッチ時に凍結した前方軸をそのまま使って表示と判定の一致を保証。
- `main.gd`: タッチ時ガイド初期化、GUARDの18px動作で前方更新、毎レンダー後にセラ正面を描画ガイドへ同期。カメラ変更なし、STEP物理方向変更なし。
- `sera_rig.gd`: WAIT→通常RUNのときだけJumpの0.375..0.500着地区間を0.20s再生。冒頭補間0、最終フレーム確定後に0.11sクロスフェードでRUNへ。運動中の見せかけ着地でありメインコントローラーの物理`landing_active`/`jump_active`は変更しない。中断時は即時解除。原本Blockbench・生成モーションには一切手を加えない。
- 旧CIを維持したまま、新規Python静的／Godot実行チェックを追加。Android視覚は未確認。

- v331初回静的CIは161件中159件成功。v200/v299足裏補正の旧アサーションが新しい「通常着地またはWAIT→RUN先行着地」条件に非対応だったので、動作上の接地保護を維持したまま検査対象を拡張。

- Godot旧検査v295/v319は従来の「WAIT→RUN即時切替」を前提にしていたため、v331の0.20s着地完走→RUNの0.11s出口ブレンドを実際のリグで評価する内容に更新。v295の後半（格闘からRUN復帰時に古いYawを残さない検査）も維持。

## 2026-11-14 — SERA v332：画面上のセラ正面フリック方向の修正

- v331のコントローラー色ガイドがセラのモデルの見た目と一致しない実機画像を受領。原因は`flick_direction_policy.projected_forward`が衝突用`CharacterBody3D`の進行/敵ロック方向を見ていた一方、表示中のHead/Chest/Waistに独立したアニメーションYaw（RUN時Waist yawと頭部ターゲット追跡）が適用されていたこと。
- `sera_rig.get_visible_facing_pivot`で、実表示Headのグローバル前方向を基本とし、ほぼ垂直になった場合のみChest→Waistへフォールバック。UIと実際のバッシュ/蹴り判断が`main._projected_sera_facing`を共通利用するため、表示・判定が別の基準へずれることを防ぐ。
- カメラ/移動/着地/キーを変更せず、タッチ時軸は凍結・通常RUNのガイドのみ毎描画更新。新規実Godot回帰で実アニメーション中の投影を比較、CIを維持。

- CI互換性：v255/v257/v264/v329/v331の静的検査は過去の「直接CharacterBody3Dを投影する」という実装詳細を期待していた。視覚ピボットを使う新しい単一ヘルパーへ期待値を更新。v332 Godot試験ではタッチ開始の`gesture_screen_forward`と赤いセクターの一致も確認。

- v332初回静的CI（162件中158件成功）で旧テストv253/v258/v260/v268が直結の`projected_forward(camera, player)`呼出を必須としていた。見た目を無視する旧経路を復活させず、新`_projected_sera_facing`と3D可視ピボットの照合を条件に修正。

## 2026-11-14 — SERA v333：ロック線基準フリック／コンボ状態に連動する常駐コントローラー

- `flick_direction_policy.projected_lock_forward`が、プレイヤーXZと選択部位の照準点（`_locked_target_facing_direction`）を結ぶ水平ベクトルをカメラで投影。頭/腰の見た目のYawは一切使わない。現行の90°セクターと通常360°STEPは維持。
- `main._projected_sera_facing`をロック対象方向へ変更。タッチ開始時に軸を固定して攻撃入力と色分けUIがずれないようにし、非タッチのコンボ継続中はロック方向へ平滑回転。
- `_combo_normal_attack_ready`はSTRIKE非最終段、BASH/BASH_TRACKタップバッファ、IDLEの連携ウインドウでの実受付を反映。`_combo_flick_attack_ready`は最終段中やその後0.65秒の入力窓だけ真。未キューの使用可能入力のみ明示。
- `touch_overlay`はコンボ継続中にタッチが離れても最後の操作円を残し、タップ中に区画を明るくして有効タップは0.18秒のフラッシュ。前=拳、左右=ブーツ、後=反転アイコン、中央=剣。入力領域、当たり判定、描画レイヤーに変更なし。
- Python静的/実Godot回帰をCI登録、旧v332の頭部姿勢基準テストを新ロック契約へ更新。Android実機での表示・操作は未検証。

- v332の実可視頭部ベクトルを前方とする旧回帰はv333のユーザー指定によって上書きされたため、同じテストをロックBODY/各部位の方向・頭部モーション非依存・4セクター判定一致の不変条件へ更新。v331の色扇区描画・回転・WAIT→RUN着地検査を保持。

- v247履歴UI検査の「タッチ中だけコントローラー表示」を、現在承認の「タッチ中または継続中のコンボ」に更新。無操作時に全面操作背景を描かない旧v247契約は維持。

## 2026-11-14 — SERA v334：敵中心横断時カメラ左右補正鏡像・コントローラー投影整合

- 不具合分析：`_update_side_from_screen`はセラを画面の中心Xと比較するだけでショルダー方向に未接続。v333コントローラーは水平な1m線を投影するため高さがある頭/脚ロックサイトと違う角度を表示、タッチ中は常に初期方向で止まり、コンボ表示時には別途UI補間で視覚的に遅れていた。
- `sera_camera_math.screen_side_after_crossing`でセラ表示胴体とターゲット表示中心Xを比較。画面幅2.5%の境界幅を越えた時のみ符号を反転、毎描画`smooth_shoulder_mirror`で補正ショルダー12°を滑らかに左右切替。反転中は旧Yawエッジ強制補正を休止し、安全ズームを継続。STEP／格闘追従プロファイルは維持。
- 3Dロックサイト世界座標`_current_lock_aim_world`をreticleとフリック共通にし、プレイヤー胸位置と部位照準点の画面投影差をフリック基準へ。コンボ受付中は開始時に凍結、それ以外のUIガイドは現在の投影線へ即時同期。例外時は従来水平線をフォールバックに使用。
- Python/Godot回帰追加、旧v333の水平線固定テストを新しい3D照準点条件へ更新。Androidでの操作・描画最終確認は別途。

- 実カメラ横断Godot検査を追加：SERAが敵の右→左→右を越えた場合のサイド状態と12°Yawの符号反転を検証。KOから初期配置へのテレポート時は鏡像状態を+1へ戻す。v330/v331/v332/v333引継ぎ検査を新3Dロック線へ更新。

- v334初回CI: 164 Python中160件合格、4件は旧実装のソース文字列（画面端条件のコロン、投影された部位の加算変数、1フレーム補間取得回数）を固定。描画フレームの`camera_player_render_position`/`camera_target_render_position`をロックサイトとHUDにも共有して余分な補間取得を排除し、コード/ガイドの方位の評価時刻を統一。旧テストは新しい同一キャッシュ・照準点の契約へ改訂。

- v334 Godot統合CIが長時間実行中となったため、追加した`_process`のカメラエッジ条件2箇所に改行継続バックスラッシュが不足していたことを検出。GDScript構文を正して再実行。以前のPR検証結果ではなく修正後HEADのCIのみマージ判断に使用。

- 追加した改行継続を修正後のGodot 4.7.2実行検査では、旧v332の「水平1m射影が常にフリック基準」アサーションのみ失敗。実機3Dロック照準点を使うv334契約へ変更し、頭部姿勢の独立性・コントローラー扇区とフリック判定の一致も検証対象のまま保持。

## 2026-11-14 — SERA v345：ビットタラン / 出撃ゲート初戦闘

- 出撃ゲートのボス選択に「ビットタラン」を追加。専用 `scenes/bittaran_battle.tscn` は既存戦闘コントローラーを継承しつつ、訓練用射撃・自動復活を無効化。
- 元制作物 `models/storage/ボステスト (2).bbmodel` を保護。新正本 `models/bosses/Bittaran.bbmodel` は14グループ・14メッシュ・4足先と `Wait` 初期10キーを保持。新規 `Idle/Turn/Approach` は2.4/1.8/2.8秒のループモーション。UUIDは元ボーンを保持し、新キーは一意に割当て。
- モデル描画 `scripts/bittaran_rig.gd`、思考 `scripts/bittaran_ai.gd`。視野角100°、低速0.72m/s、加速度0.60m/s²、停止旋回34°/s、接近中22°/s、接近停止3.9m・再接近4.3mでハンチング防止。
- Android埋込生成器 `tools/rebuild_bittaran_data.py` を正本パイプラインに組込。Python静的とGodotシーンロード/行動実行チェックを共通CIに登録。Android実機の接地・音・動きの最終確認は未実施。

## 2026-11-14 — SERA v346：ビットタランの4脚接地IK

- `scripts/bittaran_foot_ik.gd`を追加。四足の2ボーン解析IKと足先ワールド座標固定、足先水平姿勢維持を実装。モデル正本は変更しない。
- 右前/左後、左前/右後の対角ペア交互歩行。移動・旋回中も2脚以上を接地。踏み替え0.52秒、リフト0.19m、閾値0.38m、前方リード0.14m。
- 実Godot 4.7.2で220フレームの歩行/旋回/足裏固定/初期位置リセット、既存ビットタラン戦闘シーンの読み込みを確認。計算最大足先誤差約0.000002m。初回検査で検出したテレポート再固定の距離閾値を0.75mへ修正して合格。
- `tools/v346_bittaran_ik_runtime_check.gd`をビットタラン専用CI・共通CI登録。Android実機の描画/足先滑り感/重さ調整は次回の確認対象。

## 2026-11-14 — SERA v347：ビットタラン2倍化・低重心・膝屈曲強化

- `scripts/bittaran_battle.gd`: ボス全体のtargetルートを2倍（衝突形状・部位ロックを含む）。
- `scripts/bittaran_foot_ik.gd`: 2倍親スケールを保持した関節回転・足先変換、胴体0.34m下げ、接地点0.42m内寄せ。踏み替え0.58s・足上げ0.34m・開始偏差0.76m・前方リード0.28m。
- `scripts/bittaran_ai.gd`: 距離判定を停止7.8m/再接近8.6mに。速度・視野角・旋回速度は維持。
- 実Godot 4.7.2: 初期姿勢基準の関節到達率平均0.674→0.557（4脚とも深屈曲）、胴体高低差0.340m、通常IK歩行接地最大誤差0.000003m。v345/v346/v347ビットタラン専用Godotシーン実行検証成功。
- Blockbenchの正本とユーザーが作成した元ファイルは保持。Android実機の視覚確認は未実施。

## 2026-11-14 — SERA v348：ビットタラン6部位・脚破壊時の滑走ダウン

- `scripts/bittaran_parts.gd`: 頭、胴体、前後左右の脛4か所を実Blockbench関節へ追従させ、従来の汎用訓練用部位をビットタラン専用に置換。部位攻撃判定、物理当たり判定、カメラ用ロックボリュームを実メッシュへ同期。
- 被弾した脛は腿/脛/足先全体に局所フラッシュ、頭と胴体は各メッシュだけにフラッシュ。素材を独立させるため別の部位の点滅が漏れない。
- `scripts/bittaran_foot_ik.gd`：脚破壊時に該当の足先が床を約1.05m滑走し、胴体を沈めて頭部の実測Yを1.35mへ調整する前傾姿勢を自動算出。0.17s下降、0.67sから復帰、全1.15s。モデルのWait基準BODY25°姿勢は保存しリセット時も維持。
- Godot 4.7.2 v345/v346/v347/v348専用CI通過。全4脛の破壊/滑走/復帰成功。頭部中心4.018m→1.350m→4.006m、IK足裏最大誤差約0.000003m。オリジナルBlockbenchモデルは変更しない。
- Androidの視認性・演出・頭への実機格闘判定は次回の動作確認対象。

## 2026-11-14 — SERA v349：ビットタランの弱点はダウン中のみロック

- `scripts/bittaran_parts.gd`：通常時のAUTO/MANUAL候補を4脛に制限。立位のAUTO二線ロックが全脛を外してもBODYへフォールバックせず、近い脛を補完。汎用BODY空IDとは別に手動BODY選択専用の`body` IDを作り、被弾は共通HPへ変換。
- `scripts/bittaran_battle.gd`：実IKの脚破壊による姿勢崩し`break_reaction_active()`（約1.15s）だけ頭/胴体解放。通常のよろけや汎用部位破壊フリーズでは解放しない。回復と同じ物理フレームで不適格なロックを脛へ切替、起動・再出撃時も正常化。
- Godot 4.7.2で24方向の立位AUTO、手動候補4/6部位、ダウン・復帰遷移、手動胴体への共通HPダメージを検査。v345〜v348の既存ビットタラン回帰テストも通過。Android上の操作映像は未確認。

## 2026-11-14 — SERA v350：ビットタラン4脛のロック専用2倍判定・上下固定

- scripts/bittaran_parts.gd：LowerLeg骨直下の脛メッシュだけを基準に選択専用Area3Dを寸法2倍化。初期立位のYと大きさを保持し、歩行/旋回はX/Zだけ追従。歩行bobやIK足上げでもボックスの高さは変えない。
- 攻撃用のget_part_aabbと物理combat_shapesは従来の実寸を維持。頭/胴体の1.15倍選択ボックスや通常時4脛・ダウン中6部位制限も変更しない。
- Godot 4.7.2で185フレームの歩行/旋回/IKと強制上下動試験を実施し、4脛の選定領域2倍・Y固定・XZ追従・物理/攻撃判定の不変を確認。v345〜v349の専用回帰も成功。Android実機は未確認。

## 2026-11-14 — SERA v351：ビットタラン2本ロック線のセラ基準水平化

- scripts/bittaran_parts.gd の get_actor_parallel_lock_segments を専用上書き。セラのYを始点・終点とも維持し、ビットタランのX/Zへ水平方向に伸ばす2本線（間隔0.50m）。ボスの高さ・IK脚上げ・脚破壊ダウンで線が傾かない。
- 共通 target_parts.gd は修正せず、訓練室の従来ロック計算は維持。main.gdの任意2線描画は同じ仮想関数を呼ぶためビットタラン戦闘中は同じ水平2線を表示。
- v350の脛2倍・Y固定ロック専用ボックス、部位ロック制限・ダメージ判定は変更しない。
- Godot 4.7.2にてボスYを6パターン変化させた検査、ロック線水平/Y固定・間隔0.50m・線の可視化・訓練室への非影響を確認。v345〜v350専用CI回帰も通過。Android実機確認は未実施。

## 2026-11-14 — SERA v352：ビットタラン実胴体中心への水平2線ロック

- scripts/bittaran_parts.gd：ロック線終点を敵rootではなく、BODYメッシュ単体から算出した実ワールドAABB中心のX/Zへ変更。終点Yは従来のセラ原点Yを維持し、間隔0.50mで水平・平行。
- 同スクリプトの2線ミス時の脛フォールバック選択もBODYメッシュ中心へ統一。
- 既存v351検査を実BODY中心基準に更新し、v352新規Godot 4.7.2検査で敵ルート座標を偽装しても不変、実胴体移動・旋回・脚破壊ダウンへの追従、共通2本線表示との一致、訓練ルームへの影響なしを確認。
- v350の脛2倍選定領域/Y固定・v349のダウン時弱点ロック・通常の攻撃/物理当たり判定は変更なし。Android実機確認は未実施。

## 2026-11-14 — SERA v353：前後脚自動ロック切替の左右対称化

- ユーザーのAndroid動画（1000035196.mp4）で前脚→後脚と後脚→前脚の切替速度差を確認。根本原因はBODY中心への水平2線とは別に、候補4脛を線の手前側の交差距離で優先していたため、前後境界が偏ること。
- scripts/bittaran_parts.gd：初期立位の前脚2脛の中点と後脚2脛の中点から正確な中間面を算出してモデルローカルに保存。セラが面の前側なら前脚ペア、後側なら後脚ペアだけをAUTO候補とし、そのペア内で2線選択。未交差のフォールバックも同じペア内に限定。
- 前↔後は方向による待ち時間や選択深さの違いをなくし、同一境界で即時切替。BODYメッシュ中心を目標とする水平0.5m間隔のロック線・4脛2倍/Y固定ボックス・ダウン中弱点/物理判定・訓練ルームは維持。
- Godot 4.7.2で左右2側の角度掃引を前後両方向に実行し、切替境界一致、90フレームの歩行/旋回でも中間面が安定すること、過去v345〜v352の専用回帰が成功することを検証。Android実機のユーザー確認は別途必要。


## 2026-11-14 — SERA v354：接地IK後の実脛でロック境界を決定
- 動画1000035198.mp4で前後切替の差が継続。v353の保存姿勢を胴体と回す方式と、床へ接地を保って遅れて旋回する実脛の向きが不一致。30度の旋回時に約20度の差を再現。
- 現在の前2脛/後2脛のXZ中点間の中間面で共通選定。BODY中心2線・選定ボックスY固定/2倍・MANUAL・ダウン・コンボ保持は維持。
- mainの敵移動/上下揺れ直後に専用の`_finalize_target_pose`フックを配置し、Bittaranの接地IK/部位同期をAUTO・接触判定より前に完了。訓練室のフックは何もしない。
- 新規Godot検査で実Area由来の左右往復・旋回/歩行・main選定・実物理180フレームを検査。修正前の旋回直後に失敗すること、およびIKをAUTO後へ戻すと実物理102フレーム目で失敗することを確認。v353テストの自己参照した期待値も修正。
- Android実機未確認。全件検査の旧仕様との不一致は下記のCI整備で解消。


## 2026-11-14 — 現行仕様に基づくCI期待値の修正と再実行の隔離
- 特定リリース番号の完全一致を最低対応版検査へ変更。`sera_active_specs.json`は変更せず、既存の承認済みSTEP発動0.1m・蹴り4m/0.65秒を数値期待値に使用。
- v337/v339の指開始点→ロック投影方向、ガード/フリックの方向固定、RUN/BOOST時のみ方向更新、v340の2段目ヒット後直線移動、v341の着地速度連続曲線、v338の旧HUD非表示/NEXUS独立を旧回帰にも反映。
- 旧HUD数値/戦闘表示の関数検査はテスト内で旧パネルを明示表示して実行。隠れた診断ボタンは入力を奪わないことと、明示表示時に動作することを確認。テストの削除/スキップ・ゲーム数値の変更なし。
- `sera_ci_suite.py`が同名Godot検査の実行間で保存設定を共有していた問題を修正。実行ごとに新しい一時XDG領域を生成・終了時削除。装備保存による再実行汚染を、実子プロセスを2回起動する新規回帰で再現後修正。
- ローカル全件：Python182件/Godot90件成功。GitHubの既存Godot4.7.2全件CI確認後にmainへ反映。詳細な未解決失敗リストは解消済みとしてPRから除去。


## 2026-11-14 — SERA v355：ビットタラン カメラ・格闘入力・破壊/復活
- レンダリングカメラに対して60Hzの脚IKが断続的に更新される状態を避けるため、Bittaranルートおよび14関節のPhysics InterpolationをON。ロック対象は従来どおり最終IK位置を使用。
- ボスより画面奥側に入ると格闘フリックの「前」を画面上へ切り替える。0.65mで移行、-0.25mで解除するヒステリシスを使い、タッチ開始時の格闘方向は固定。通常RUN/BOOST/STEPの移動はそのまま。
- 頭/脚の破壊部位を暗い装甲/橙発光で保持。ヒット時の一時フラッシュと別管理。全身の深度テストを破壊しない死亡時3D破片と焼損暗転を追加。
- 死亡3秒後、コンボ保持を終了した時点でBODY500HP・全ての部位HPを同時に全回復する。死亡中は部位HPの早期回復なし。
- 頭下がりダウンを各脚破壊2.5秒、全4脚破壊で6秒。頭/BODYのロック解禁は実際のダウンに連動。
- 廃止されたv345/v348/v349時間・復活期待値を更新し、v355専用シーン検証を追加。CIおよびAndroid実機のGL描画・フリック操作確認は別途。


## 2026-11-14 — SERA v356 ビットタラン中央左右ロックちらつき修正
- 原因：正面/背面で左右の巨大脛ロック体積が共通の2本線に重複し、各脚への最初の交差距離が接地IKで微変動して毎フレーム勝者が入れ替わる。
- Bittaran専用の立脚AUTO取得に限り、現行の前後ペア境界を維持しながら、各ペアの現在の左右脛中心から左右優先度を確定。現在ロック中の脚を中心線から0.65mの範囲で保持し、反対側を明確に横切ったら同じphysics tickで切り替える。未取得時は左右の決定的な規則を使用。
- 既存の二本水平レイ、パーツ判定体積、前後同速境界、MANUAL操作、ダウン中HEAD/BODY許可、破壊後のロック維持は変更しない。訓練室の共通AUTO処理も変更なし。
- 回帰テスト：v356 Bittaran lateral lock (正面/背面中央120サンプル、左右双方向切替、IK動作中90フレーム) をfocused CIと全CIマニフェストに登録。Godot headlessとAndroid実機での描画確認は別々に扱う。


## 2026-11-14 — SERA v357 奥側方向入力・ダウン時押し出し・首追尾・地面埋まり修正
- カメラ奥側にセラが回り込んだ場合、従来の固定画面UPを廃止。セラのカプセル中心→ロック部位の3Dワールド位置を同一カメラで投影し、その画面角度をコントローラ表示とフリック分類に共通使用。閾値のヒステリシスと既存の攻撃中軸固定を保持。
- 脚破壊によるビットタランダウン中、胴体の実メッシュAABB下にいるセラを水平に退避。脚の実物理脛AABBをプレイヤーカプセル半径分だけ広げて接触/進路を判定し、最短の開いた方向へ押し出し、足の側面に接したときは横方向へ迂回する。共通訓練室には適用しない。
- 上下方向の衝突解決でセラを視覚床Y=0未満へ押し込んだ場合は、飛行・攻撃の行動状態にかかわらずビットタラン専用physics末尾でYを0に補正。胴体下からの退避も地面に平行に限定。
- Headの元のアニメーション回転に対し、現在のプレイヤー位置へローカルYawを最大±48度・140度/秒で追従。途中12分割の頭メッシュ対全脚可視メッシュAABBテストで衝突しない可動上限まで制限し、ダウン時の胴体ピッチと脚IKを維持。
- v357 Godot回帰テストをfocused・full CIに追加。既存v355の旧「奥側は画面UP固定」仕様テストを新仕様へ更新。Android実機の視覚・触覚確認はheadless CIとは別。


## 2026-11-14 — SERA v358 ビットタランの0.6秒予備動作・ダウン頭部初期化・浮き対策
- 脚破壊時、実際のダウン前に独立0.60秒の重い予備動作を追加。頭は少し沈んでから最大26°まで加速しつつ上を向き、終端で滑らかに基準回転へ戻す。前脚2本は地面への接地を維持したままそれぞれ0.24mほど外側へ伸ばし、ダウン開始直後0.17秒で元の支持位置へブレンドする。既存の2.5秒/全脚破壊6.0秒ダウン時間は、予備動作の後に開始する。
- ダウン姿勢が開始すると頭部の追尾Yawをゼロにし、Blockbench元姿勢のHead関節Quaternionへ復帰。ダウン継続中はプレイヤー追尾を停止し、復帰後に再開する。
- 脚IKの可動限界で胴体が一瞬浮く場合、足裏の実ワールドYと視覚床Y=0との差を検出して全身の高さを限定補正し、解析IKをもう一度解き直す。脚の上下振り中はその脚を接地参照から除外し、接地済みの脚を維持する。急激なY補正と浮き上がりを防ぐ。
- 新規Godot実機準拠headless回帰 `tools/v358_bittaran_windup_grounding_runtime_check.gd` を追加。重い頭上げ・前脚伸長・途中の無浮遊接地・頭のニュートラル復帰・2.5秒/6秒維持を検証。歴史的v348/v349/v352/v355テストも予備動作分だけ回復待ちを延長。Android実機の視覚的な重さと接地の確認は別途。

- **追加CI整備：** 作業中にAndroid同期から独立の`turbo-loop-3d-portrait-fixed-2-godot/`が同リポジトリへ追加された。SERAの資源整合性検査がその独立`project.godot`以下の`res://`もSERAルート相対で解釈して偽陽性失敗したため、別`project.godot`を持つ子ディレクトリはそのまま保持してSERA資源参照検査から除外。ゲーム本体/別ゲームを改変せずに責務境界だけを修正した。


## 2026-11-14 — SERA v359 ダウン時HEAD AUTOロック／コントローラの方向基準統一
- ダウンの実モーション（0.6秒予備動作後）に入ると、ビットタランのAUTOロックはHEADを優先選択する。従来の胴体中心へ向かうY固定の平行ロック線は、頭の高さのためHEADを通過できず、BODY/脚にAUTOが吸われていた。ダウン中の頭部狙いを確実にしつつ、MANUALの頭/胴/脚切り替えは維持する。
- ビットタラン専用の方向コントローラおよびバッシュ／蹴りの方向判定を、常に**セラのカプセル中心→現在のロック部位の3D中心**を同じカメラで画面投影した角度に統一。従来の通常時「指の初期位置→対象」と奥側「セラの中心→対象」で別方向になる問題を解消。タッチ開始位置は方向の基準ではなく操作入力の原点としてのみ扱う。
- 訓練ルーム・360度STEPの画面方向・移動量は変更しない。コンボ入力中の捕捉軸保持、カメラ越え判定のヒステリシス、頭ダウン時のニュートラル角と頭上げ予備モーションも維持する。
- 新規`tools/v359_bittaran_head_lock_controller_runtime_check.gd`で、立脚/ダウン時の複数位置・異なる指位置・HUD同一角度・フリック分類・HEAD AUTO/ MANUALへの到達を実Godotで検証。


## 2026-11-14 — SERA v360 ビットタランの奥側コントローラが上180°へ反転する不具合を修正
- 原因は、ビットタランのHEADなど上下位置が異なるロック部位をプレイヤー中心から3D画面投影したとき、カメラの俯角・遠近法で見かけのスクリーンYがXZの前後関係と逆転する場合があったこと。さらにカメラを跨いで投影できないときに方位フォールバックが固定`Vector2.UP`だった。
- 新規`scripts/bittaran_controller_axis.gd`が、プレイヤーカプセル中心→ロック部位の3D投影を保持しつつ、同じ高さに平面化したロックXZ方向との角度差が大きい場合に滑らかに平面方向へ補正。XZ方位の投影自体がカメラ近面外で不可能な場合、カメラ基底から安定方位を求める。大きな高度差でも180°反転しない。
- ビットタラン`_touch_to_lock_forward`の唯一の結果をUIとフリック判定で共有。入力中の自由操作はターゲット・カメラの移動に伴い毎フレーム更新し、ガード・確定したコンボフリックは従来どおり方向固定。前後の境界診断状態は維持。
- 新規`tools/v360_bittaran_controller_depth_runtime_check.gd`が、合成高い頭部でスクリーン生ベクトルの逆向きを再現した上で修正後の下向きを検査。多数の高さ・前後左右位置・カメラ背面・実ボスロック・ドラッグ固定・コンボの軸保持をGodot headlessで検証。Android実機の体感は別途。


## 2026-11-14 — SERA v361 旋回中の頭下の腕を横倒し＋頭部／脚の物理判定による接触
- ダウン予備動作0.6秒の完了時、実ポーズの頭部前半AABB中心と各足裏の水平座標(XZ)距離を測り、頭と脚の実寸から算出した閾値(0.65〜1.75m)内の最寄り脚だけを下敷き候補にする。上下差・頭の高さを判定には使わず、遠い脚は倒さない。旋回中にワールド固定の脚が頭の下へ入り込んだ姿勢を認識する。
- 該当脚のIK足先を体側へ約0.62m滑らせ、72度を最大とする接地足首の横倒しを0.17秒で合成。回復では逆動作し、既存の4脚IK・カメラ・プレイヤー挙動を維持。脚のモデル原本・アニメーションデータは変更しない。
- 頭と脚は同一AnimatableBody3Dの子コリジョン形状なのでGodotが自己接触を解決しない。実衝突箱から頭下端と脚上端のXZ重なりとY接触を計測し、頭のめり込みが生じる前に胴体前傾を二分探索して頭を脚の上へ止める。IKを再解決して足を床へ戻す。
- 下敷きになった脚のAUTO二本線ロック得点に5mペナルティを加え、既存のダウン中HEAD優先ロックを維持。脚の当たり判定・ダメージ・MANUAL選択は無効化しない。回復時にペナルティを解除。
- 新規`tools/v361_bittaran_head_on_leg_runtime_check.gd`はターン後の足の頭下配置、横倒し姿勢、HEAD/脚の衝突箱の貫通抑制、AUTO低優先度、復帰を実Godotで検査。Android実機での接触見た目は別途確認。


## 2026-11-14 — SERA v362 ダウンから完全復帰するまで旋回・接近モーション禁止
- 問題は`bittaran_battle.gd::_advance_target_motion`のAI凍結判定に、ビットタラン専用`bittaran_foot_ik.gd`の予備動作・ダウン・起き上がり状態が入っていなかったこと。脚がダウン中でもAIが`Turn`/`Approach`を再生し、回転・接近できていた。
- `bittaran_foot_ik.gd::locomotion_ready()`で、0.6秒予備動作と2.5/6秒のダウンを完了し、脚の下敷き支持を解除したあと、0.24秒間の正常なIdle・接地姿勢を終えるまでは移動可能としない。復帰時の胴体高さ（持続する接地補正を考慮）と通常IK処理の完了を判定に利用する。新しい部位破壊/リセット時は残留ゲートを解除・再初期化。
- AI凍結中は`BittaranAI.advance(..., frozen=true)`からIdleを選び、ボスのXY移動・Yaw回転・`Turn`/`Approach`クリップの再生を禁止。凍結が終われば距離／視野判定により従来どおり旋回・接近を自動再開する。
- `tools/v362_bittaran_standup_motion_gate_runtime_check.gd`で、1脚破壊・4脚破壊の両方について、倒れる前にTurn/Approachが有効であること、倒れている間と復帰直後のIdle維持、胴体正常姿勢での0.24秒静止、復帰後のAIアニメーションと移動の再開をGodot本体で確認する。
- 脚の横倒し頭接触、頭部優先ロック、モデル元データ、コンボ操作・カメラ・2.5/6秒の倒れ時間は変更しない。


## 2026-11-14 — SERA v363 起き上がり開始から滑らかに旋回／70％姿勢復帰で頭部追従
- `bittaran_foot_ik.gd::standup_pose_fraction()`を復帰時間の三次イージング（立ち上がり姿勢・脚の戻りと同一）から算出し、頭部・旋回の共通進捗とする。予備動作0.60秒、ダウン保持、2.5秒／6秒全時間と、終了後0.24秒Idle保持は変更しない。
- ダウン中の頭部関節は原則デフォルト角度固定。姿勢復帰率70％到達から残り30％で追尾重みを0→1のsmoothstepで増加させ、既存の頭部角速度・脚装甲貫通チェックを適用したままゆっくり追従へ遷移する。
- `bittaran_ai.gd::advance_recovery_turn()`を追加。実際の起き上がり開始から旋回Yawのみを最大34°/s×姿勢復帰率で滑らかに増大。倒れている間と予備動作中は0、復帰後0.24秒Idle保持中は通常の旋回速度。復帰完了まで`Turn`/`Approach`アニメーションと前進移動は引き続き停止。AI通常復帰後は従来の旋回／接近選択を適用する。
- `tools/v362_bittaran_standup_motion_gate_runtime_check.gd`を更新し、前進禁止・Idleアニメーションの不変条件は維持しつつ、仕様変更された復帰Yawの速度上限を確認。`tools/v363_bittaran_rise_turn_head_runtime_check.gd`で1脚・4脚ダウン、頭部70％以前の固定／以降の滑らかな追従、初期からのYaw漸増、復帰後通常Turn再開をGodot runtimeで確認。Android実機の描画・操作は未検証。


## 2026-11-14 — SERA v364 頭部の追従を緩速・腕との干渉回避／起き上がり前から旋回
- 頭の追従開始は従来の「実姿勢復帰率70%」のまま、追従重みをsmoothstepの2乗に変更。起き上がり中～0.24秒のIdle安定時間は最高角速度を140°/秒から48°/秒へ抑制し、開始直後の急角度変化を防止。通常立ち状態の最大角速度は140°/秒のまま。
- 頭の回転は実際の頭前半のAABBと全脚の上腕・脛・足を24段階で掃引。起き上がり中の追加重なり許容を既存0.035m3から0.008m3へ厳格化し、脚が動いて前フレームの角度が危険になった場合も最も近い安全角へ戻す。標準姿勢で元々重なる首／肩部分は基準重なり量として許容し、モーション起因の新しい貫通を防ぐ。
- ビットタランのYaw旋回を、起き上がりの胴体上昇開始から0.30秒前に開始。事前回転率を0→100%のsmoothstepで緩やかに加速。前進・Turn／Approach脚クリップは完全な起立＋0.24秒Idle安定時間まで停止したまま。頭部の70%追従開始閾値は変更しない。
- Godot実シーン検証`tools/v364_bittaran_head_clear_early_turn_runtime_check.gd`を追加。1脚・4脚ダウンで立ち上がり前のYaw発生、スロースタート頭追従、脚の追加干渉増大なし、Idle維持と前進停止を確認。Blockbench原本・生成データは変更なし、Android実機は未検証。


## 2026-11-14 — SERA v365 起き上がり開始と同時に等速旋回（補間なし）
- v364の「起き上がり0.30秒前から旋回開始＋smoothstep加速」は廃止。旋回開始を`break_elapsed`が`break_recover_start`に到達する**起き上がり最初の物理フレーム**に一致させ、回転開始直後から34°/秒（その時点での対象との角度差を上限）を適用する。起き上がり以前のダウン予備動作・保持期間はYawを変更しない。
- Main側からIK側の次の`delta`経過による復帰開始をプレビューする`standup_turn_enabled(delta)`に変更し、AI更新がIK更新より前に実行されるフレーム順序による1フレーム遅れを抑止。AI側の従来`pose_weight`倍率補間は削除。
- 起き上がり中～0.24秒の正常姿勢安定期間は従来どおり`Idle`クリップと接近移動停止を維持し、その後は通常のTurn／Approachへ戻す。頭部70%追従開始、48°/秒上限、個別メッシュに基づく腕への干渉防止、脚IK、2.5/6秒ダウン時間は変更しない。
- 旧v362/v363/v364の自動検証を新仕様に更新。新規`tools/v365_bittaran_immediate_standup_yaw_runtime_check.gd`では1脚と4脚ダウンの両方で、ダウン保持中のYaw静止と最初の復帰物理フレームでの即時34°/秒適用、復帰中の速度補間なし、接近・Turn/Approachアニメーション停止をGodotで検証する。


## 2026-11-14 — SERA v366 起き上がり開始時の旋回・接近モーション/移動解禁
- 旧v362〜v365で、ダウンの起き上がり中も`bittaran_battle.gd::_advance_target_motion`がAIの`Turn`／`Approach`クリップと接近を`Idle`へ固定し、`bittaran_foot_ik.gd::advance_ik`も立ち上がり中の脚ステップを禁止していた。結果、root Yawしか動かず、起き上がるまで脚が微動だにしなかった。
- 起き上がり最初の物理フレーム（`break_elapsed + delta >= break_recover_start`）から通常の`BittaranAI.advance`へ戻し、視野角と距離に応じた`Turn`／`Approach`クリップと本体Yaw／前進の再開を許可。予備動作とダウン保持中は`Idle`と完全静止のまま。元のAI距離ヒステリシス・加速・旋回速度を維持。
- 復帰開始のIKは、頭部を支える脚を避けた対角の脚ペアで初回ステップを強制開始し、上下動を伴う起き上がりアニメと通常歩行IKを重ねる。頭を支える脚は復帰するまで持ち上げず、頭部・脚の衝突と上向き復帰の連続性を保持。
- 頭部は姿勢復帰率70%以上で48°/秒上限の低速追従、各メッシュの干渉判定を継続。元の2.5秒／6秒ダウン時間と0.24秒の姿勢安定タイマーも維持するが、タイマーは動作禁止の条件としない。
- `tools/v366_bittaran_live_rise_motion_runtime_check.gd`で1脚／4脚×Turn／Approachの4条件、起き上がり最初のフレームでのクリップ・IK初動・Yawまたは前進、頭支持脚の保護、ダウン中の完全静止、完了までの連続再生をGodot実シーンで検証。旧v362〜v365の禁止前提テストは新仕様に更新。


## 2026-11-14 — SERA v367 起き上がり時は胴体を旋回速度で向け、起立後に脚着地位置を追従
- 起き上がり中は胴体がプレイヤーへ**通常旋回速度34°/秒**で向く。`Approach`選択中も従来の移動旋回速度22°/秒ではなく胴体に34°/秒を適用し、接近距離は維持して前進方向を新しい胴体Yawへ合わせる。Turn／Approachクリップの再生開始はv366どおり起き上がり最初の物理フレーム。
- 起き上がり中、脚IKは実世界の地面の接地位置を維持し、回復開始と同時に脚を振り上げない。頭を支える脚・横倒し脚の復帰と接触演出を妨げない。立ち終わり（`break_reaction_active()==false`）の最初のフレームから、誤差が大きい対角ペアのステップを開始。続けてもう一組も追従させる。
- 動作速度は変更せず、`STEP_DURATION_SECONDS=0.58`、脚の動作曲線と足の高さは維持。ステップ中の`swing_to`・`rotation_to`を、胴体の**現在の位置と向きから毎フレーム再計算**し、着地点を動く胴体に間に合わせる。接地済み脚はworld空間のanchorを維持。接近時の踏み出しオフセットを含む同じ着地目標で誤差判定し、無限歩行を防止。
- 旧v366テストはダウン中の脚接地／起立時の追従開始を新仕様へ更新。`tools/v367_bittaran_body_turn_foot_catchup_runtime_check.gd`で1脚・4脚×Turn・Approachの4条件、起立前の脚振り禁止、34°/秒胴体回転、最初の起立時ステップ、2対角ペアの追従、ライブ着地点、同一ステップ時間をGodot実シーンで検証。頭部70%追従と腕干渉判定、2.5/6秒ダウンは変更なし。Android実機未検証。


## 2026-11-14 — SERA v368 2回目以降の脚破壊でも復帰動作を再現し、起き上がり1.25倍速
- 原因: 2脚目以降の破壊で`main.gd`が共有の`part_break_remaining`を3.5秒に設定。ビットタラン専用ダウン復帰の胴体が上がる時点（破壊+0.6秒予備動作+2.1秒保持）より長く、`bittaran_battle._advance_target_motion`が`Idle`に固定されるため、2回目以降だけTurn/Approach・胴体の旋回・接近が止まる。1脚目は硬直が1秒で先に終わるため再現されなかった。
- 脚破壊の硬直はBittaranFootIKの風圧予備動作・ダウン・起き上がり専用ゲートに統一。脚破壊で発生した重複`part_break_remaining`と`stagger_remaining`をクリアし、復帰を開始した脚IK状態では残っている部位被弾硬直によって再び動作停止しないようにする。頭・胴体の部位破壊、HP等の本来の判定は変更しない。
- **起き上がりだけ1.25倍速**。単脚ダウン時は`break_recover_start=2.10s`を維持し、起き上がり所要時間0.40→0.32秒、ダウン全体2.50→2.42秒。全脚破壊後は`break_recover_start=5.40s`を維持し、起き上がり0.60→0.48秒、ダウン全体6.00→5.88秒。予備動作0.60秒・倒れる0.17秒・倒れたままの待機・上昇smoothstepは変更せず、復帰の区間時間だけ短縮する。
- Godot実シーンの`tools/v368_bittaran_repeat_break_fast_rise_runtime_check.gd`で同一戦闘内4本の脚を順に破壊し（リスポーンなし、通常の破壊状態累積）、毎回のダウン/起き上がり/TurnとApproach/脚接地と動的着地点/70%頭部追従を検証。v358のダウン長検査を新しい時間へ更新。Android実機視覚確認は別。


## 2026-11-17 — SERA v424 ビットタラン新モデル・左右前脚攻撃テスト
- `models/storage/ビットタラン.bbmodel` から胴体・4脚・砲台・眼球メッシュ、左右前脚6つの攻撃クリップを正本 `models/bosses/Bittaran.bbmodel` に取り込む。砲台と眼球メッシュを頭部に集約し、`Head` の旧Pivotと計14ボーンを維持する（Rail/Railgun/Eyeの元モデルの回転しない中間グループのみ統合）。
- 旧正本の `Idle` / `Turn` / `Approach` を移植し、既存の歩き・旋回AIと接地IKを維持する。
- 攻撃対象は左右前脚だけ。`なぎ払い` / `弾き` / `踏みつけ_L` と各 `_R` の6クリップを実際に使い、攻撃側3関節とBodyの原本キーを直接サンプルする。テスト中は旧4脚ミラー・追加のプレイヤー距離補正・攻撃方向への胸の再旋回を使用しない。支持脚は既存IKで接地する。
- 頭部は毎フレーム、上下左右各±90°までプレイヤーへ追尾。頭と脚の衝突回避・膝折り回避による追尾制限なし。
- `assets/bittaran_data.gd` を新正本から再生成し、Godot用v424フロント攻撃スモーク検査を追加。Android実機の再生・描画は未確認。


## 2026-11-17 — SERA v425 ビットタラン前脚3攻撃の地面接地
- 左右前脚のなぎ払い・弾き・踏みつけに対し、原本キーフレーム再生後の攻撃側の足先接地を既存2関節IKで処理。接地対象はSWEEP：脛と足先、STOMP/KICK：足先。
- なぎ払いは膝ポールを探索し、下肢と足先の接地を優先。踏みつけの振り上げ中は着地を強制せず、接地時のみ修正。
- 移動中の通常4脚IK、旋回AI、頭の90°追尾、モデル正本・Android埋込、攻撃判定は不変更。
- v425の実Godot接地テストをモデルCIと専用CIへ追加。実機表示は未確認。

- v391とv422の履歴テストは、v425のIK接地と前脚限定仕様に適用できないためアクティブな回帰対象から除外。削除せず退役一覧へ移動。新しい6攻撃メッシュ接地検査を正本とします。


## 2026-11-17 — SERA v426 ビットタラン胴体降下・復帰順序とゼロドリフト
- Blockbench攻撃原本は保持しつつ、攻撃中のBodyをWait姿勢へ最大68%水平寄せ。実メッシュの足先とBody床安全域から降下量を決定（最大1.10m）。毎フレーム基準のactor Yから再計算し前回のIK補正を入力しない。
- 攻撃終了後、0.42sで攻撃脚を基本姿勢へ戻してから0.62sで胴体の高さを戻す専用リターン区間を新設。この間は次の攻撃・通常の歩行旋回を停止し、終了時に高さ/ポール/足先キャッシュをクリア。
- なぎ払いの下肢は床面へ接地強制しない。脛が床を貫通する場合のみ回避。足先は攻撃フレーム中のみ接地を強制し、終了後は通常IKに復帰。
- v425接地テストを脛の「接地」ではなく「貫通しない」判定へ修正し、v426で6攻撃x2連続の復帰順・補正リセットを検証。Android実機表示は未確認。

- v426旧仕様競合（v384, v405, v414, v415, v416）は履歴テストに移し、原本スクリプトは削除しない。新v426反復・胴体/足先検査で動作と非累積性を保証。


## 2026-11-17 — SERA v427 なぎ払い導入・接地タイミング・胴体追従
- 左右前脚なぎ払いのBody+3関節をWait基本姿勢から原本キー0へ0.32秒smoothstep/slerp補間。キーフレーム0を攻撃開始1フレーム目で直接適用しない。
- 足先はメッシュが床面3.5cm以内に達し、かつ導入補間後に接地IKへ切り替える。空中時は床に無理に引き下げず、脛は侵入したときだけ回避。終了と中断で接地ラッチ削除。
- 胴体降下を加速0.4秒→最大2.0m/sの速度制限方式にし、胴体に連結する肩／上肢と通常の支持脚IKが連動して追従。後半の足先・胴体復帰と補正のゼロクリアはv426を維持。
- v427実Godotテストを追加。Android実機でのモーション映像は未確認。

- なぎ払いキー0の足先が床から数m浮くケースに対し、0.32秒の基本姿勢→キー0補間が完了した後、打撃開始までに肩・膝を既存2リンクIKで連続的に伸ばして足先を下げる到達フェーズを追加。足先メッシュの床近接が実際に成立した瞬間に接地モードへ切り替え、時間だけで着地を強制しない。


## 2026-11-17 — SERA v428 ビットタランなぎ払い低姿勢・足先の水平化
- 左右なぎ払いのみ胴体降下限界を1.10→1.70mへ拡大。Bodyメッシュ下面20mmの床安全域と速度上限2m/sを維持。接地した後も低姿勢を保持。
- 足先メッシュのローカル長軸を実際のメッシュ位置から導き、0.32〜0.70秒のなぎ払い打撃前に長軸を水平にする回転補正をslerpで適用。頭部・他3脚・原本の攻撃クリップは変更しない。
- 水平化された足先の実メッシュ最下点を使って従来の接地IKと脛の床回避を再解決。攻撃終了・再開始時に補正角度の蓄積なし。
- v427の胴体最大降下検査とv426の6攻撃復帰検査を攻撃別降下限度へ更新し、新しいv428水平角度・低姿勢・再攻撃のGodotテストを追加。


## 2026-11-17 — SERA v429 ビットタラン下肢水平化と踏みつけ型足の持ち上げ復帰
- 左右前脚のなぎ払い・踏みつけ・弾き終了後、0.42秒の脚復帰へ最大0.65mのsin軌道の高さを追加。0.75秒の踏みつけ振りかぶりの足首キーとWaitの回転差を参照し、空中では徐々に足先を振り上げてから基本位置へ着地。従来の脚→胴体の復帰順序、体の0.62秒復帰は維持。
- なぎ払い中の下肢の実メッシュの最長軸をワールド水平へ補正。脚のIKボーンや足首Pivotを変更しないメッシュ専用補正とし、毎フレーム・攻撃終了時に必ず原本メッシュ回転へ戻す。
- v429で左右3種類×2回の持ち上げ高さ・水平度・原本姿勢復元・残留値ゼロを実Godot検証。全体CIと合わせて確認。


## 2026-11-17 — SERA v430 ビットタラン攻撃を原本再生のみにリセット
- 原本の左右前脚3攻撃×2（なぎ払い1.5s、弾き1.0s、踏みつけ1.75s）をクリップ時刻の1xで、全原本ボーントラック直接再生。攻撃脚以外の原本の待機キーフレームも保持。
- 攻撃中の補正IK、床接地、胴体降下、水平化、回転補正、スロー再生、姿勢合わせ、後戻り弧、攻撃ダメージ/衝撃波を一時的に無効化。頭部追従と非攻撃時の移動・旋回IKは維持。
- 攻撃開始と終了の一時キャッシュをクリアし、原本関節Pivotに復元。新v430実Godotテストで6クリップを2回ずつ全関節回転/原本時刻/元Pivotを検証。

- v430実Godotテスト成功（6原本クリップ×2回）。旧仕様の前脚/後脚攻撃・床補正・スロー・原本外復帰・ダメージ演出を要求する16件は退役一覧 `tools/bittaran_v430_superseded_attack_tests.txt` に記録。元検査は削除せず、非攻撃回帰検査を維持。

## v463 — ビットタラン独立レールガン（2026-11-19）

- 背部の正本2レール（UUID: `2ce4b10f…` / `3e2ee103…`）を14ボーンのBody配下で独立Yaw/Pitch Pivotに再接続。形状・元Blockbench・足IK・頭追従・脚攻撃は変更なし。新しいランタイム親に対するメッシュ基準位置を更新して診断との整合を維持。
- 10秒ごとに発射、照射2秒。照射中は滑らかな角速度制限付き追尾。終了後0.4秒保持→0.8秒滑らかに原角復帰→次のチャージで追尾再開。
- 銃口の青白い球状発光を0.2秒で縮小、完全消灯してから0.2秒間隔を置いてレーザーを発射。左右側面箱にそれぞれ3本の短い点灯式チャージバーを実装。
- 太いレーザーは既存のGL Compatibilityに合わせた深度テストON・`RENDER_ORDER.DEPTH_TESTED_EMISSIVE`。中心軸からのプレイヤー距離で衝突を判定し、0.5秒ごとの既存ガード／HP／KOロジックへルーティング。ボス死亡・KO・再出現では完全リセット。
- `tools/bittaran_railgun_runtime_check.gd` をフルCIマニフェストへ登録。実機での視覚・幅・接触の最終確認は別途必要。


## v464 — ビットタラン全身撮影／背部砲台水平拘束（2026-11-19）

- 通常の標的用カメラ外接箱を使わず、ビットタランの動く18メッシュとレールガン側面箱をワールドで包むAABBをサンプリング。前後左右、脚攻撃・頭追従・砲台旋回にも適用し、レーザーの長距離部分はフレーミング対象外。既存プレイヤー画面内保持と視点追従は不変。
- 砲台の世界姿勢はリグの水平Yaw＋独立した照準Yawで再構成し、横傾斜・前後傾斜したBodyの回転を相殺。Pitchは砲身ノード専用軸のみ。位置はBodyに追従、原本と14ボーン・脚IKは保全。
- `tools/bittaran_full_frame_level_gun_runtime_check.gd` を全件CIへ登録し、全身画角と傾いた胴体上でのRollゼロを検査。


## v465 — 充填完了まで砲台静止／ブーストで回避可能なレーザー（2026-11-19）

- 砲台の左右追尾最大速度を120°/s→24°/s、上下追尾を100°/s→18°/sに低速化。近接8mでの基準ブースト約6.09m/sの横移動（約43.6°/s）に追いつかずレーザーは回避可能。照射中も同じ速度制限。
- 充填中（フェーズCHARGE、3.2～9.6s）は基本姿勢のYaw=0/Pitch=0を厳密に維持。3段階バー充填完了時のFLASH開始（9.6s）からのみ追尾を開始する。球状フラッシュ、0.2s暗転、10秒周期と2秒の照射を維持。照射終了後0.4秒保持＋0.8秒緩和復帰も維持。
- 既存`tools/bittaran_railgun_runtime_check.gd`に未充填静止、満充填からの追尾、8mブースト逃走角速度、ピッチ上限を検査追加。全身カメラ・傾斜時水平保持の`tools/bittaran_full_frame_level_gun_runtime_check.gd`も充填後の検査タイミングに整合。


## v466 — 充填球体＋発射前高速捕捉・発射後のみ低速照準（2026-11-19）

- 満充填（9.6秒）で球状チャージ演出と高速プレイヤー追尾を同時開始。最初の0.2秒の青白い球体縮小後、0.2秒の暗転中も追尾。0.4秒の発射準備中はYaw最大900°/s、Pitch最大720°/s、24Hz指数平滑化によりブースト移動も高速で捕捉。
- 発射開始瞬間のプレイヤー実座標へ照準を正確に合わせ、初弾のずれを解消。ビーム開始後2秒間のみYaw最大24°/s・Pitch最大18°/s、基準8mブーストの横移動で追尾を振り切れる。
- 充填未完了は元角静止、10秒周期、2秒レーザー、終了後0.4秒保持＋0.8秒復帰、Rollなし2軸ワールド制御、元モデル／カメラ／脚IKは不変。
- 回帰テストに球体と高速追尾同時開始、BOOST直後の正確な初弾照準、ビーム中の追尾速度のみ低下する境界検査を追加。


## v467 — 青い球体と砲台追尾の2秒間イーズイン（2026-11-19）

- 発射周期の8.0～10.0秒を、青白い銃口球体が常時見える2秒間の満充填演出へ変更。球体は開始0.2秒で膨張、中間保持、終了0.2秒で縮小。その後暗転なしでレーザーへ移行。
- 砲台の追尾は球体出現と同時に開始し、2秒間smoothstepで追尾速度の立ち上がりを徐々に増加。発射時完全捕捉を維持し、発射後のみYaw24°/s・Pitch18°/sの回避可能な低速追尾。
- 10秒間隔・2秒間照射、3本の充填バー、基本姿勢待機・発射後0.4秒保持＋0.8秒復帰、2軸独立の水平保持、全身カメラとモデル原本は不変。
- レールガン回帰テストに2秒の球体表示、2秒の追尾立ち上がり、満充填／発射の境界を追加。統合後はmainで全件CIを実行。


## v468 — 青い球体の発射前1秒収縮（2026-11-19）

- `scripts/bittaran_railgun.gd` の球体収縮期間を最後の0.2秒から最後の1.0秒へ変更。青い球体全体の2.0秒表示、先頭0.2秒の膨張、発射10秒周期、2秒追尾イーズイン、発射時捕捉、発射後低速ビーム、既存の戦闘処理は維持。
- 全件CI登録済みの`tools/bittaran_railgun_runtime_check.gd`へ9.0秒の収縮開始、9.5秒の約半分、9.9秒の終盤収縮、10.0秒のレーザー移行の動作テストを追加。


## v469 — 照準完全捕捉後に0.5秒発射待機（2026-11-19）

- ビットタランレールガンに新しい`LOCK_HOLD`フェーズを追加。全身・モデル原本に手を加えず、青白い銃口球体の2秒表示と追尾smoothstepの2秒を発射前7.5～9.5秒へ移し、球体消失後9.5～10.0秒の**0.5秒完全捕捉待機**を作った。
- 待機開始瞬間に現プレイヤー位置へ照準を確定、待機中も高速追尾を続ける。3本のバーは満充填のまま保持し、発射時点で現在位置へ再照準。レーザー2秒・発射間隔10秒・発射後低速回避可能追尾・元角戻しを維持。
- 回帰テストを更新し、球体2秒、収縮1秒、追尾の2秒イーズイン、完全捕捉待機0.5秒、遅延中の移動目標追従、10秒周期を確認。


## v470 — レールガンの青縁・稲妻・流動プラズマと追尾速度倍率（2026-11-19）

- 青白い球体の外縁にカメラ視線基準フレネル青発光＋時間変動チラつき。表面の分岐電撃12本を追加。発射中は白芯・青ハローにUV移動型プラズマ層と短い分岐電撃18本、幅の脈動を追加。電撃形状は決定的計算に基づき20Hz弱で更新し、ゲーム進行用乱数に影響しない。
- 新ファイル`scripts/bittaran_railgun_fx.gd`、`shaders/bittaran_railgun_rim.gdshader`、`shaders/bittaran_railgun_flow.gdshader`。共通の深度テスト付き描画優先度を使用し、砲台Pitch空間に付着させることで独立2軸・モデル原本を保持。
- 事前追尾Yaw 900→720°/s・Pitch 720→576°/s（0.8倍）、照射時Yaw 24→21.6°/s・Pitch 18→16.2°/s（0.9倍）。10秒周期、2秒球体と1秒収縮、2秒イーズイン、完全捕捉後0.5秒発射待機、2秒レーザーとブースト回避は維持。
- `tools/bittaran_railgun_runtime_check.gd`で効果表示・稲妻メッシュ・GPU shader/描画ルール・追尾速度・リセット時の消灯を検証。視覚表現の最終判断はAndroid実機。


## v471 — 発射前・発射中の追尾角速度を両方0.7倍に（2026-11-19）

- ビットタランのレールガン発射前の角速度をYaw720→504°/秒、Pitch576→403.2°/秒、レーザー照射中をYaw21.6→15.12°/秒、Pitch16.2→11.34°/秒へ変更。
- 2秒イーズイン・0.5秒完全追尾待機・発射時点のプレイヤー完全捕捉・10秒周期・2秒照射・ブースト回避、青縁球体と稲妻のv470視覚処理およびモデル原本・IKは維持。
- `tools/bittaran_railgun_runtime_check.gd`の数値契約に旧v470の70%を明示し、現行環境で全件CIを検証。


## v472 — レーザー発射フレームの必中ダメージを除去（2026-11-19）

- v471のYaw/Pitch追尾速度は指定どおり（発射前504/403.2°/秒、照射中15.12/11.34°/秒）。一方、発射フレームで現プレイヤー位置へ正確に向けるのと同時に当たり判定を走らせており、即被弾でダメージリアクションが走ってBOOST/STEPが中断されることを確認。
- `scripts/bittaran_railgun.gd` のレーザー照射開始後**0.4秒間は照射を可視のままダメージ判定だけ無効**に変更。発射時完全追尾・照射後の角速度上限・ビーム幅/射程/繰り返しダメージ周期は維持。
- `tools/bittaran_railgun_runtime_check.gd` に、発射直後は当たらないが0.4秒後に静止SERAには当たること、実際の6.09375m/秒横BOOSTが発射後1.92秒間回避できることを追加。既存の電撃やモデル・IK・カメラは不変。


## v473 — チャージ開始〜レーザー照射終了まで連続低速追尾・被弾後もBOOST継続（2026-11-19）

- 問題：v472は発射前後で追尾方式を切替、球体消失後と発射開始フレームで現在SERA位置へ照準瞬間一致、被弾時は通常`_begin_damage_reaction`でBOOST停止、SERA KO時は砲台ごとリセット。さらにボス旋回が相対Yaw制限を迂回し、遠距離では固定15.12°/sがBOOSTの見かけの角速度を超える問題を確認。
- `scripts/bittaran_railgun.gd`：CHARGE開始からFLASH→LOCK_HOLD→BEAMを統一した追尾で接続し、追尾開始2秒smoothstep以外に速度変化・瞬間スナップ無し。ワールドYawを保持し根元回転を含む実際の照準角速度を制限。Yaw15.12°/s・Pitch11.34°/s上限に加え、装備の実BOOST速度/距離から算出する見かけ角速度の35%以下へ制限。
- `scripts/main.gd`：通常敵弾には変更を与えず、レールガン用の非怯みフラグでHP/シールド被弾は残し、BOOST/STEPを止める被弾ダメージリアクションを抑止。 `scripts/bittaran_battle.gd`：砲台追尾に装備の実BOOST速度を渡し、SERA KO時も照射終了まで演出を継続。照射開始の当たり判定猶予は0.40秒→0.65秒へ調整。
- `tools/bittaran_railgun_runtime_check.gd`：連続追尾・速さ・発射時のスナップ防止・ボス旋回・遠距離適応角速度、8m/30m RUN→BOOST回避、実命中のBOOST維持、命中/KO時のビーム継続を追加。モデル正本・モーション・脚IK・カメラ・VFX・10秒周期は保持。


## v474 — 10秒は追尾禁止→10秒で追尾付き球体2秒→即照射2秒→即0.7秒帰還（2026-11-19）

- 添付の実機動画を確認。v473の「3.2秒から追尾→球体→待機→照射→保持→戻り」が意図に反していたため、明示的な時間軸に再設計：**WAIT 0〜10秒で追尾ゼロ／充填バー進行、FLASH 10〜12秒で球体と同時に追尾開始、BEAM 12〜14秒は同じ速度で連続追尾・即照射、RETURN 14〜14.7秒で0.7秒smoothstepにより基本姿勢復帰**。1周14.7秒。
- 追尾の入りは0.7秒smoothstep、抜けも0.7秒。発射前0.5秒待機、発射後0.65秒無判定、終了後0.4秒保持は撤廃。プレイヤー位置への瞬間照準補正もなし。
- RUN(4.0625m/s)とBOOST(6.09375m/s)の間の追尾換算速度5.3828125m/s（65%地点）を、プレイヤー距離に応じてYaw/Pitch合成角速度へ変換。装備速度を反映し、通常RUNでは追尾可能、BOOSTなら振り切れる目標とする。レーザーの被弾時にBOOSTを止めないv473処理は維持。
- `tools/bittaran_railgun_runtime_check.gd`を時間軸・描画・即判定・移動速度別の回避へ更新、`tools/bittaran_full_frame_level_gun_runtime_check.gd`の復帰時刻を修正。モデル正本、14ボーンとIK、既存の球体/レーザーVFXは保持。


## v475 — レーザー初回命中のノックバック→照射終了までフルヒット（2026-11-19）

- ビットタランのレーザー初回命中で`_on_enemy_projectile_hit`の通常ダメージリアクション・1.2m/0.24秒の物理ノックバックを起動。従来の非怯みフラグを使わず、初回命中時にBOOST・STEPを中断。
- `scripts/bittaran_railgun.gd`にビームごとのラッチを導入。初回は厳密な幾何命中判定、成立後はノックバックで判定外へ移動しても残りの照射中、0.5秒間隔で継続ヒット。最大4パルス／2秒、照射終了・reset・次回発射でラッチ解除。
- `scripts/main.gd`にレールガン限定のDamageknock保持フラグ、`scripts/bittaran_battle.gd`に最初の被弾から照射終了までの保持・終了時解除を追加。追撃でリアクションを再起動しない。ガード・シールド・KO条件は従来どおり、通常の敵攻撃には影響しない。
- `tools/bittaran_railgun_runtime_check.gd`で初回命中→射線外で3連続追撃／実ノックバック／ダメージ・被弾保持／終了解放／ガード／未命中BOOST・次回発射の非ラッチを検査。v474の充填10秒・球体2秒・照射2秒・復帰0.7秒と追尾速度・VFXの仕様は維持。


## v476 — レールガン追撃ゼロ、1照射で最大1回だけノックバック（2026-11-19）

- v475で追加した、初回命中後0.5秒ごとの強制追撃（最大4回）と照射終了までの被弾姿勢保持はユーザー指示「追撃はなし」により完全撤廃。
- `scripts/bittaran_railgun.gd`で**初回のビーム実接触1回のみ当たり**を受け付ける`beam_hit_registered`へ変更。継続照射中に再び接触してもダメージ無し、ビーム終了／次回で状態リセット。2秒照射は中断しない。
- `scripts/bittaran_battle.gd`の強制被弾保持削除、初回命中時の通常HP・ガード・物理ノックバックは保持。`scripts/main.gd`のレーザー専用ロックを撤去しDamageknockの通常回復を復元。
- `tools/bittaran_railgun_runtime_check.gd`で初回実接触・照射中の追撃0・射線外から再接触しても追撃0・次回発射のリセット・ガード・ノックバックを検査。10秒充填・球体2秒・照射2秒・戻り0.7秒・追尾および電撃VFXは不変。


## SERA v502 — 俯瞰拠点LABO・資源設備（2026-11-19）
- 最新mainのSERA v501砲台・描画変更を維持した上で、NEXUSの重複なしでLABOと資源・生産・建築設備6つを拠点3Dフィールド上に追加。
- NEXUSを右へ移設し、CRATE巡回路と中央通路を確保。カメラ投影でのタップ、画面内の閉じられる設備パネル、研究項目説明、発電機ローター、施設ラベルを追加。
- 報酬量/レシピ/コストは未確定のため資源収支は未実装。NEXUS画面遷移、全画面グリッド、セラとコントローラの一時非表示は保持。
- 既存CIを事前確認。先行追加の検査：base_facilities_self_check.pyとbase_facilities_runtime_check.gdをCIマニフェストに登録。既存の拠点CIは変更しない。


## SERA v504 — 俯瞰拠点施設を画面全体へ再配置（2026-11-19）
- LABOを画面左上、NEXUSを右上へ移動。回収機・精製炉・リサイクラー・発電機・資材保管庫を左右へ分散、建設端末を下部中央へ配置。中心通路とCRATEの巡回を保持。
- Android縦画面の既存カメラ/FOVを維持しつつ、施設の投影位置を上下左右へ拡張。端の施設ラベルが画面外に欠けないよう画面内へ収める。
- 実装前にbase_facilities_runtime_check.gdの画面占有率・各施設の画面内タップ位置・施設同士の実寸離隔・タグ表示を検査する期待値を追加。旧NEXUS座標前提のbase_exploration_runtime_check.gdを現物入口判定に修正。
- LABO機能・資源の収支（未確定）・戦闘・NEXUSメニュー・セラ/コントローラの非表示は変更しない。全CIはmainマージ後に実行。


## SERA v505 — NEXUS上部中央・LABO中央・資源設備周囲の配置（2026-11-19）
- NEXUSを画面上部中央（x=0,z=-13.1）、LABOを中央（x=0,z=-2.2）に配置。回収機・精製炉・保管庫・リサイクラー・発電機・建設端末は外周の左右と下部を維持。
- LABOが中央に移ったため、CRATEの巡回ルートを中央建物の外周に変更。建物・機械の基礎と交差しない経路へ。
- **先行CI変更**: base_facilities_runtime_check.gdに、NEXUS上部中央、LABO中央、6施設の周辺分散、NEXUS/LABOのタップ領域非干渉、CRATEの全経路が歩行可能であることを追加。既存の7施設表示・ラベル・3D選択・グリッド床・NEXUS往復検査は維持。
- LABO研究UI・資源操作パネル・出撃・セラ非表示など既存機能は変更しない。全CIはmainマージ後に検証。Android実機で視認性・タップ感を別途確認。


## 2026-11-20 — SERA v508: 4系統・3ランク素材と精製/分解設備の実稼働
- **ユーザー確定仕様**：低/中/高の4系統12基本素材。製作の必要素材は指定品質を固定で要求し、他ランクの素材で直接代替不可。ランクの上げ下げは拠点の専用設備でのみ行う。
- **事前CI確認と先行テスト**：v507 main、AGENTS.md、sera_ci_manifest.txt、base_facilities_self_check.py/runtime_check.gd、sera_save.gd、旧v171/v172データアーカイブ回帰、SERA_ACTIVE_CI_POLICYとpost-mergeモデルワークフローを確認。実装前にbase_material_conversion_runtime_check.gdとbase_material_conversion_self_check.pyを作成してCI登録。固定レシピ・12ID・同一系統のみ・原資不足拒否・双方向変換・保存再読込・設備パネルを検査。
- **実装**：scripts/sera_base_materials.gdに12素材のID/日本語表示/確定したランク階層を登録し、固定品質の製作要求判定と精製・分解プランを追加。仮の変換比率は2低→1中、2中→1高（逆方向は1→2）で、往復時の増殖/損失を防止。比率は調整用定数に分離、今後のバランス確定で変更可能。
- **保存**：sera_save.gdの既存スキーマv2を保持し、旧セーブに存在しないmaterialsは12項目0として読み込む。変換は残高・ID・バッチを検証し、ファイルへの保存成功後にのみメモリを更新。セーブスロット別所持数、将来の戦闘報酬を安全に記録するための明示的award_materials APIを追加（自動採集や無料配布なし）。
- **設備**：既設の精製炉/リサイクラーをそれぞれ専用「精製装置」「分解装置」に更新し、素材系統選択・変換回数・必要数・所持数・実行のUIを接続。資材保管庫から12種の在庫も確認可能。NEXUS/LABO、拠点の建物位置・CRATE巡回・バトル/モデルは変更なし。
- **未接続**：ボス撃破報酬への素材追加、LABOの実際の製作レシピ、電力消費と製作時間は未確定のため追加せず。新規プレイヤーは初期所持数0。
- **検証**：全Python/Godot CIはmainマージ後に実行。Android実機で画面表示とタップ感の確認が必要。


## 2026-11-20 — SERA v509: 素材プルダウン廃止と統一戻る操作
- **依頼**：精製・分解の素材選択をプルダウンではなく別ページの一覧とし、拠点施設・NEXUS共通で戻るボタン、画面外タップ、Androidのシステム戻るを階層移動として扱う。戻る矢印は見た目のみでもよい。
- **CI事前確認**：v508 main・AGENTS・sera_ci_manifest・base_material_conversion_runtime_check・base_nexus_navigation_runtime_check・command_nexusの_existing_入力・SERA_ACTIVE_CI_POLICYを確認。GoogleではなくGodot公式4.7ドキュメントでAndroidのQuit On Go Back既定ONとWindow.go_back_requestedを確認。
- **先行テスト**：本体修正前にbase_page_navigation_self_check.pyとbase_page_navigation_runtime_check.gdを作成・manifestへ登録。プルダウン廃止、4系統の一覧ページ、変換詳細、施設外側タップとKEY_BACK/Window.go_back_requested各一段階移動、LABOの詳細戻り、NEXUSのSYSTEM集中表示→概要→拠点を検証。
- **実装**：base_facility_systemのOptionButtonを廃止して素材選択画面（4つの大きなタップボタン）と選択素材のランク変換画面に分離。施設の詳細説明も独立したページにし、下部戻るボタン・画面外タップ・PC Escape/Android Backを同じnavigate_backへ統合。施設メニューはスクロール可能なアクション領域を配置、戻る矢印は装飾でタップ判定を必要としない。
- **NEXUS**：以前のBackとEXIT TO BASE、各端末の機能は保持。フォーカスメニューの外をタップすると概要へ、概要画面の端末外をタップすると拠点へ戻る。SYSTEMで保存/削除の確認中は一段戻って確認を解除する。Android Window.go_back_requestedでも同じ操作。
- **Android設定**：project.godotのapplication/config/quit_on_go_back=false。Androidデバイスが戻る操作でアプリを即時終了する既定動作を無効化。
- **不変条件**：基本素材12種、同系統のランク変換比率、セーブ/資源収支、LABO/NEXUS/CRATE配置、戦闘・モデル/モーションには変更なし。
- **検証**：mainマージ後に既存全Python/Godot CI、実機ではAndroidジェスチャー・タップの可読性・挙動を確認。


## 2026-11-20 — SERA v513：マット調アイコン19種・LABO試作装備7種類・倉庫/カスタマイズ連携
- マット質感の既存生成画像をRGBA WebPの288×360px（72px×19セル）に統合しGodotへ実装。全12素材アイコンと7装備アイコンを明示的IDで割り当て、欠損時はCI失敗。
- LABOの試作7品目を個別アイコンと設計IDで一覧表示。仮製作は素材消費なし。製作物を素材とは別の倉庫個体`crafted_items`にセーブし、NEXUSカスタマイズで個体ごとに選択・アイコン表示、既存実3DモデルAを装備スロットとして反映。
- 命名規則：固定設計ID（H01等）＋通算4桁以上の連番（H01-0001等）。個体ごとのUIDとシリアルカウンタはスロット別保存し重複を拒否。旧セーブは素材・装備の互換性を保持。
- 静的テスト`v511_matte_icons_self_check.py`およびGodot実行時テスト`v511_matte_icons_runtime_check.gd`を**実装前**にCI登録。実画像の非空、素材12/試作7の全カバー、倉庫・変換画面、セーブ永続化、連番・誤装着防止を確認。
- 本タスクはv512予測シールド新実装とは独立。最新main v512を起点に実装を移植して、シールドの調整と旧CIを維持。完成後main全CIを検査する。


## 2026-11-20 — SERA v525：予測シールドの八角形・破片を調整
- 六層八角形の内外縁の頂点を共有し、空白の帯を除去。塗りつぶした中心・横幅1.15倍・展開/保持/消滅0.20秒ずつの規約は保持。
- 通常防御、亀裂、破片の画面上の寸法・飛散距離を一律30%へ縮小。描画の深度オフセット0.14m・優先度115・SP・当たり判定には変更なし。
- 14枚の破片は同一の単色にし、初期位置・角度・速度・大きさ・ポリゴン形状を命中時に一度だけランダム化。外側へ減速・透明化する。
- 先にv510/v516期待値を更新し、新規v525静的/実Godotチェックにて隣接頂点一致・縮小率・減速・単色を検査。v524の拠点UI修正を保持。

## SERA v527 / Android Godot エディターのLABOリスト表示修正（2026-11-20）
- 実機v526診断：Android Godot 4.7.2、アクティブslot=3、`atlas: MISSING`。装備製作 `created 0/7 / starting craft`、素材変換・倉庫 `created 0/12 / scrap_low icon`。APKでは表示するため、単純なButtonレイアウト崩れではなく最初の画像取得前後でカード作成が中断する事象として調査（GDScriptエラー原文は未取得）。
- `sera_item_icons.gd`：Androidエディターでimported画像が存在しない状態を想定し、静的preloadを避け、ResourceLoader→ソースWebP直接復号の順に遅延ロード。AtlasTexture領域は既存の19枠を保持。
- `base_facility_system.gd`：カードを先に生成し、アイコンと動的StyleBoxTextureの適用はdeferredへ。画像がなくても文字・枠・操作を確保。診断欄に `icon source` を追加。保存/素材/装備仕様は不変。
- 事前確認：`sera_ci_manifest.txt`, `docs/SERA_ACTIVE_CI_POLICY_ja.md`, v511, v522〜v524, v526診断、`.github/workflows/sera-model-policy.yml`。旧期待値の変更なし。新規 `v527_android_icon_resilience_self_check.py` / `v527_android_icon_resilience_runtime_check.gd` を**本体改修前に登録**し、Raw WebP復号とテクスチャ不在での7/12/12枠を回帰検査。
- 検証：マージ後mainの全登録Python/Godot CIとLinux実描画検査を実施。Android実機のエディター表示は別途確認が必要。


## SERA v527軽量LABO UI整理（2026-11-20）
- 実機v527でWebPソース直接読み込みの成功（`icon source: source-webp`）、素材・倉庫各12枚の描画を確認。今後の低負荷化では正常表示を優先し、カード・WebP・装備保存コードに変更を加えない。
- LABOホームを「装備製作」選択扱いにしない。試作製作画面と詳細でのみ製作タブを選択し、戻るとホームはタブ未選択にする。これにより新しいタブや画面を増やさず、既存研究アクセスを残す。
- 「診断」は初期非表示、ヘッダー5回タップ（1.7秒以内）でトグル。ゲーム開始時は診断の定期更新・描画を行わない。新しいTimer/スクロールノードは無し。表示済み12件と所持品の9件ページ分割をそのまま使う。
- CI事前確認：`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`v524_layout_tabs_runtime_check.gd`、`android_editor_card_diagnostic_* `、`base_page_navigation_*`、`v527_android_icon_resilience_*`。旧テストの期待値変更は不要。新しい静的/Godot UI回帰を本体更新前にCI登録済。
- mainへマージ後全登録Python/Godotと実描画・リポジトリ整合性を検査。Android実機は別途確認。


## SERA v527 — LABO表示の割当最小化（2026-11-20）
- 最新mainの `tools/sera_ci_manifest.txt`・`docs/SERA_ACTIVE_CI_POLICY_ja.md` とv511/v517/v519/v521/v522/v523/v524/v527のカード・画像・タップ・画面描画の回帰、開発者診断のテストを**実装前**に確認。新しい `labo_minimal_allocation_self_check.py`、`labo_minimal_allocation_runtime_check.gd` を実装前に追加しCI登録。旧期待値は変更していない。
- `_switch_section("craft")` は一旦生成したLABOホームのアクション4つを破棄せず、直接製作カタログを構築する。戻る遷移、研究施設入口は変更しない。
- `_new_slot` は3個の仮Controlを全行に作って置換する方式を廃止し、ネイティブButtonを直接行へ追加する。完成した一覧の**最後の不足列のみ** `_finish_grid` で空白のControlを必要数追加。7件なら2個、12件なら0個。最終列幅・欠けた四隅・タップ範囲を維持し、GridContainer/ScrollContainerへの置換や永続カードプールはしない。
- 通常時には `_diag_step` の記録と呼び出し元の文字列連結を実行しない。タイトル5連打で診断モードを表示すればチェックポイントは引き続き使用できる。表示件数の診断カウンタは引き続き保持。
- WebPのソース復号フォールバック、AtlasTexture、画像・Skinキャッシュ、セーブ・素材交換・製作品個体IDは変更しない。実メモリ/CPU負荷の最小値はAndroid端末上でのプロファイラー比較を必要とする。
- mainへのマージ後は既存全Python/Godot CI・Linux実描画・モデル整合性を必ず確認し、Android端末の見た目/操作は別に評価する。


## SERA v528（2026-11-20）— LABO共通3Dヒーローと角丸青灰UI
- 依頼：LABO上30%は常時3Dの煽り視点研究室。3Dプリンターが稼働し、クレートが自走で端末の内容をチェックする。素材変換・倉庫にも共通適用、全選択UIは角丸ブルーグレー。
- 現行main・project.godot・AGENTS・登録済CI（v519/v521/v522/v523/v524/v527/軽量LABO/Android診断）とrender policyを事前確認。既存の四隅欠けフレームテストだけ新規仕様に沿って先に更新し、7/12件・画像/タップ/保存は維持。新規3D/UIテスト2件を実装前に登録。
- 新規シーン `scenes/labo_hero_stage.tscn` と `scripts/labo_hero_stage.gd` に軽量ローポリ研究室・造形機・端末・キャタピラ式クレートを配置し、移動・端末チェック・印刷機観察のFSM、プリンター可動パーツを実装。
- UIを共通の低解像度3D SubViewport（初回のみ生成、共有、閉じると停止）＋下段の既存NativeButton UIとし、上部の高さを表示領域の30%に固定。LABO/精製装置/分解装置/倉庫の全画面で同じ研究室を維持。
- `scripts/sera_labo_round_skin.gd` の StyleBoxFlat 共通Themeを全Button/カードに適用。四隅欠けは角丸へ変更。Androidで表示実績のあるVBox/HBox/native ButtonとWebPソース画像復号を変更しない。
- mainにマージ後、全CI・画面ピクセル検証を実施。実機描画の品質/操作感/負荷はAndroidで別途確認。

## 2026-11-20 — LABO縦スクロールの指ドラッグ修正
- **対象**：装備製作、素材変換、倉庫（素材・装備）の縦スクロール。Androidでスクロール領域内のカードから指をドラッグしても移動しない問題。
- **事前CI確認**：`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`.github/workflows/sera-model-policy.yml`、v519/v521/v529/v531〜v535および旧LABO検査。全体CIは現行ルールどおりmainマージ後。
- **テスト**：v537のPython静的検査・Godot実行検査を先行作成しmanifestへ登録。旧テストの`ScrollContainer.new()`固定文字列だけを、新しい派生スクロールの生成条件へ修正。操作仕様や素材列数の期待値は変更しない。
- **実装**：新しい`sera_labo_touch_scroll.gd`で、`emulate_mouse_from_touch=false`のままスクロール領域内のScreenTouch/ScreenDragを受け、10pxを超える縦ジェスチャーからスクロールする。Buttonタップとドラッグを分離し、ドラッグ解放で製作・倉庫操作が誤発火しないようにした。確認ダイアログ表示中は背後のスクロールを停止。製作カタログの下段プレビューをスクロール内容へ移動。
- **不変条件**：タブ・戻る・確認操作、倉庫999個の可視セルプール、素材/装備レイアウト、戦闘のタッチ設定・モデル・保存データは維持。
- **残る確認**：Godot実行/全CIの結果とAndroid実機でのドラッグ追従・タップ誤発火の目視確認を別々に報告。


## v530：キャラクター／敵の80°視点依存輪郭線（2026-11-21）
- SERA・訓練ターゲット・ビットタランに共通の独立した輪郭線メッシュとGPU描画を追加。
- 隣接面の角度80°以上でハードエッジ、画面上の外周はカメラ角度に従って表示。緩やかな内部境界と不可視エッジは非描画。
- 画面ピクセル基準の線幅1.6px、暗いブルーグレー。GL Compatibilityで元材質を変えず、深度テスト有効の透明パスで描画。
- CPUでの面隣接検査は初回/装備変更時のみ。定期的に新規装備メッシュを検知してキャッシュを利用。
- 仕様・限界・Android検証事項：`docs/SERA_VIEW_DEPENDENT_EDGES_ja.md`。
- 新規CI：`tools/sera_view_edges_self_check.py`、`tools/sera_view_edges_runtime_check.gd` を実装に先行して登録。既存テストの数値・期待値は変更不要。


## 2026-11-21：SERA 3px外周／視点上の段差のみに輪郭線を限定
- **現象**：正面から見える四角形の手前角にも3px線が描かれていた。角度80°以上という幾何学的な条件と、カメラ視点からの輪郭（手前／背面の切り替わり）が混同されていた。
- **修正**：`shaders/sera_view_edges.gdshader` の「両面がカメラを向いていてもhard_creaseなら描画する」条件を廃止。面の表裏が視点から切り替わるシルエットと、他の部品を隠す独立部品の外周のみを深度テストつきで表示する。
- **維持**：3px線、#17212f、80°分類メタデータ、アクターへの共通接続、元材質、モデル、モーション、当たり判定、Android GL Compatibility、および全既存CI。
- **テスト先行**：`sera_view_edges_self_check.py` および `sera_view_edges_runtime_check.gd` に、両面カメラ向きの90°角は非描画・前面/背面で分かれる外周のみ描画という新しい仕様を追加。角度分類79°/81°と3pxは維持。
- **限界**：別MeshInstance3D同士の「接合部が実際につながったか」の判定は未実装。Android実機での角、段差、近接した部品の遮蔽を目視確認。


## 2026-11-21：斬撃・噴射などFXに誤って付く3px輪郭線を除外
- **原因**：輪郭線管理 `sera_view_edges.gd` の対象判定がMeshInstance3D自身の名前だけを調べていた。v85ソードエフェクトは親が `V85_3DSlash_AuthoredBoard_3Stage`、子は `AlphaClippedMainArc`／`ConvexTwoSided3DArc` であるため、ソードのエフェクトに輪郭線を誤適用していた。
- **修正**：親階層すべてのエフェクト名、`sera_no_view_edges` の明示メタデータ／グループ、各メッシュの透過・加算合成・深度無効マテリアル（標準／透過シェーダー）を判定し、輪郭線付与から除外。旧版で誤追加した`SeraEdgeInk`子は次の走査で削除。斬撃rootとブースター炎rootにも明示的な除外を付与。
- **保護する仕様**：SERA本体・刀身・装甲・ビットタラン・標的には3px輪郭線を継続、80°分類と視点依存外周判定は不変。斬撃・ブースターの本来のシェーダー、発光、アルファ、残光寿命、描画優先度、当たり判定は変更しない。
- **テスト先行**：`sera_view_edges_self_check.py` に祖先／マテリアル／メタデータ契約、`sera_view_edges_runtime_check.gd` に通常の剣・実体・斬撃弧・透過FX・ALPHAシェーダー・誤った既存線の除去検査、`v322_katana_swordeffect_import_runtime_check.gd` に実シーンでの輪郭線混入防止を追加。登録済みCIの元の79°/81°・3px・描画・ソード運動テストは保持。
- **実機確認**：ソード斬撃の弧／レンズとBOOST／STEP噴射・残光・その他FXに輪郭線が出ないこと、剣そのものの輪郭は消えないことをAndroid実機で目視検査。


## 2026-11-21：LABO 3D看板の文字視認性・名称下線統一
- 3D風景の「3D PRINTER」「SERA」等の看板に英数字用同梱 Rajdhani フォントと暗色2pxアウトラインを使用。LABO上部3D表示の stretch_shrink を2→1にし、低解像度描画による文字崩れを抑制。画面上部30%のレイアウト、背景3D配置・操作は変更しない。
- LABO/NEXUS共通スタイルにブルーグレー `#55798a`、1pxの名称下線を追加。画面名、装備名、素材名、ボス名、装着中装備名に適用。名称の長さ・配置に追従し、空欄・LOCKED SLOT・操作タブ・技術情報は対象外。倉庫は既存プール内の1本のColorRectを再利用し、フレーム単位の再生成やポーリングを行わない。
- CIに `tools/labo_name_underlines_sign_legibility_self_check.py` / `tools/labo_name_underlines_sign_legibility_runtime_check.gd` を先行登録。旧フォント・3列素材・999枠・ボタン操作・スクロール等のテスト条件は維持。
- 実機確認事項：Androidで3D看板の視認性、名称下線の高さ・細さ、2行素材名の最終行、機種別のGPU負荷を確認。静的なソース契約とheadless CIは実際のAndroid表示を代替しない。


## 2026-11-21：名称下線3px化・倉庫詳細の欠字2文字を修正
- 名称下線（`LaboSkin.NAME_UNDERLINE_HEIGHT`）を従来1px→3pxに増やし、下線のY座標を文字の下に2px移動。色 `#55798a`、名称の文字幅に追従する既存ルール、空欄や操作ボタンの除外、倉庫プール再利用は維持。
- 倉庫装備の基礎/追加特性説明で四角の欠字として描かれていた U+FF0B（全角＋）をASCII `+`、U+203B（※）を「注:」へ変更。情報の意味・計算式・保存仕様は変更しない。表記を `基礎 + 特性（装備単体の表示値）` / `注: 追加特性は戦闘計算へ未接続の試作値です。` に統一。
- 前回のマージ後 CI（GitHub Actions `44852580026`）は既存の新規Godotテストで `const Skin` が Godot のネイティブクラス `Skin` と衝突して失敗。予約クラス名を避け `LaboSkin` に訂正。テスト期待値3pxおよび欠字対策の表示・glyph検査を実装に先立って更新済み。既存のその他全件CIを維持。
- Android実機では3px下線の表示、倉庫の2箇所の文字、および画面サイズごとの折返し有無を最終目視確認する。

## 2026-11-21 BASE reference industrial architecture
- Reference-driven rebuild of all eight separate overworld buildings (NEXUS and seven machine stations) with material-batched procedural steel geometry, varied functional machinery, tarpaulins, cargo, signage, and local lighting meshes.
- Armored steel deck now includes instanced panel seams, fasteners, repair hatches, drain grates, hazard stripes, floor stencil and cable routes. Camera/positions/picking/CRATE path and existing model masters remain unchanged.
- Added base_reference_architecture self-check and headless runtime check to the CI manifest before implementation; preserved previous layout/navigation tests. Detailed design: docs/BASE_REFERENCE_INDUSTRIAL_2026_11_21_ja.md.
- Final Android GL Compatibility screenshot and GPU workload require physical-device confirmation.

## 2026-11-21：倉庫装備詳細のステータスを3列テーブル化・装備カードの欠字修正
- 装備製作カードの「基礎：」で全角コロン U+FF1A が縦長四角として表示される問題を、同梱フォントでも表示できる半角 `基礎: ` に変更。
- 倉庫の装備個体詳細は文字列を1枚のLabelで描く方式を廃止し、`WarehouseStatsTable` の3列GridContainer（項目・計算式・合計）へ変更。各行は独立したPanelで1pxの低コントラスト格子。列幅は項目19%・式59%・結果22%、計算式を横長にし、合計数値は右揃え、項目名と合計はフォントサイズと明度で強調する。
- ステータスの計算は `LaboStats.total_stat_rows()` に構造化し、既存の基礎値・5つのランダム特性・攻撃/HP倍率・ほかの百分率を維持。ゼロ値の項目も全8行表示する。
- 「追加特性は戦闘計算へ未接続」の画面上の注釈は削除し、表の3列ヘッダーのみ維持。技術的な試作状態は本記録で保持し、ゲームロジック接続済みと誤認しない。
- 関連CI（v549の倉庫実表示検査、Labo文字欠け検査）を新仕様へ先行更新し、新規 `warehouse_stats_table_self_check.py` と `warehouse_stats_table_runtime_check.gd` をマニフェストに追加。既存のフォント・倉庫999件仮想化・ボタン操作・保存・スロットの検査は維持。
- Androidで表の視認性・列の収まり・数値整列・上下スクロール、製作カード「基礎: 」の欠字消失を実機確認する。


## 2026-11-21：LABO製作ステータスと倉庫5特性・7タブ表示の改善
- 装備作成カードのステータスから「基礎:」を削除し、製作可能な装備だけ情報文字を17→20px、色を `#e0f4f6` に変更。LOCKED SLOTの17px・灰色表示と素材カードの書体は保持。
- 倉庫の全7部位ボタンは `Button.text` による最小幅押し出しを回避し、文字はマウス透過の中央揃え `HangerCaption` に移動。既存のButtonGroup、選択マーク、タップ遷移、縦スクロールを保持し、横スクロール不要のまますべて表示する。
- 装備カード内の製作時追加効果5件を左3行・右2行に分配。中央は `#55798a` / 2pxの縦線で区切り、横仕切りと底枠から各10px以上離す。空枠・素材カード・旧装備では2列目と中央線を非表示。既存の32枚以下の仮想カードプール内に再利用ラベルを一度だけ作成し、スクロール中のノード確保を防ぐ。
- 装備詳細の8ステータス表は全セルをマット単色 `#152e3a` に統一（1pxの薄い格子は維持）。合計のフォントを通常19→23px、コンパクト16→21pxに拡大。項目・計算・合計の3列幅、計算式および保存値は変更しない。
- 新規 `warehouse_affix_grid_visual_self_check.py` / `warehouse_affix_grid_visual_runtime_check.gd` をCIに先行登録。v540/v543/v544などの旧17px期待値と `warehouse_stats_table_self_check.py` の「基礎:」期待値を新仕様に合わせて変更。999スロット仮想化・スクロール・保存・戦闘処理の既存検査は維持。
- Android実機で7タブの右端、5特性の左右の見切れ・中央縦線の上下余白、ステータス表の数値拡大、ステータス行と装備名の読みやすさを確認する。


## 2026-11-21：倉庫の操作タブ固定と追加特性の内側余白
- 倉庫の「装備/素材」2分類と装備7部位の操作タブを、非スクロール領域 `FacilityActionScroll` に収まるよう整理。タブ領域の高さは装備140px・素材80pxに固定し、倉庫画面中だけ縦スクロール無効とする。
- 「PURGE / 不用品一括削除」は操作タブ領域から外し、`FacilityItemLayer` 内の仮想倉庫カード一覧の直前へ配置。PURGE操作は従来の確認ダイアログと保存ロジックを維持。装備カード自体の999件縦スクロールは残し、その他LABOページへの切替時にはアクションスクロールを自動で戻す。
- 倉庫カード内の2列追加特性を左右とも6px内側へ移動。左列の開始位置16→22px、右列は中央+8→中央+14px。列幅もその分だけ調整し、2pxブルーグレー中央線・上下の間隔、5特性の左3/右2、空欄の非表示、最大32カードプールは変えない。
- 新しい静的/Godotテストで7タブ・固定領域・PURGE位置・2列文字・表示後のプール再利用・別ページへの戻りを検証し、旧v540の16px期待値を更新。実機で異なる縦横解像度の文字切れとタブ表示を確認する。


## 2026-11-21 BASE floor props — facility-specific industrial assortment
- Added 52 static accessory clusters across all 8 BASE sites (8 NEXUS, 8 LABO, 6 per remaining site): tools, spare parts, scrap, energy modules, crates, cables, forged components, calibration and construction gear.
- 40 authored object IDs and multiple physical silhouettes use `scripts/sera_base_clutter.gd`, emitted into the existing `sera_base_architecture.gd` material-batched MultiMeshes without new independent object draws. Decorative geometry includes no new physics/collisions, shaders or live loops.
- Authored X/Z footprints fit within each reserved single-piece facility slab with entrance and CRATE traffic lanes kept open. Existing 8 building positions, floor panels, Android portrait camera, UI, equipment and resource mechanics remain unchanged.
- Required static+Godot runtime checks added in `tools/base_site_prop_variety_*.{py,gd}` before implementation. End-to-end CI and on-device visuals must be verified separately.

## 2026-11-21 BASE storage/parts stacking visual
- Layered 19 of the existing 52 accessory groups, including six 3-tier clusters, using authored per-item `stack` values in `scripts/sera_base_clutter.gd`.
- New `LiftedBatch` forwards shifted actual mesh calls to the same existing facility material-batched MultiMesh. Style differences come from tier-specific color variations and small XZ staggering. Uses stack-specific contact pitch, only one ground skid, and no new per-frame logic.
- All eight single-slab sites retain placement, entries, floor colors, tap navigation and CRATE traversal. Nonstackable equipment remains a single item.
- Test-first `base_prop_stacks_self_check.py` / `base_prop_stacks_runtime_check.gd` registered in the full CI suite; runtime test records actual 3D crate Y coordinates and validates 2/3-tier diversity and clearance.


## 2026-11-21 — BASE facility props: balanced rhythm of density and breathing space
- Re-authored the existing 52 static prop locations for an intentional spatial beat instead of two uniformly spaced lines: 4+ closely spaced objects on one side, a wide empty interval on the opposite side, and one visually smaller accent per facility. NEXUS/LABO use 5:3, others 4:2, alternating dominant sides across the six peripheral stations.
- Preserved the 13 double stacks and 6 triple stacks, all 40 prop types, reserved single-piece site slabs, machine/entrance protection areas, renderer batching, CRATE and UI navigation.
- Added test-first tools/base_prop_density_rhythm_self_check.py and tools/base_prop_density_rhythm_runtime_check.gd to the CI manifest, checking tight runs, spacious gaps, alternating sides and preserved stack counts.

## 2026-11-21 BASE: 16 additional distinctive micro-industrial props
- Kept the 52 primary prop groups, fixed-seed 1–4 cargo stacks, material batching, rhythmic dense-vs-clear composition and eight single-piece base slabs.
- Added 16 more compact 3D prop groups (two per facility), making 68 groups and 56 unique object kinds. These are distinct per-site functional silhouettes: sealed canisters, spare aerials, micro servos, welding masks, slag, heat shields, gear pins, crusher teeth, robot joints and gripping fingers, packing wedges, folded canvas, ceramic fuses, busbars, blueprint rolls and locator beacons.
- Each is fully modeled with multiple batched box, rod and ring parts; no extra independent scene meshes, physics nodes, lights, new materials or per-frame updates. New accents are placed adjacent to the original density clusters and excluded only from primary-rhythm-count tests, not floor-panel overlap or actual render tests.
- Added `base_compact_prop_variety_self_check.py` and `base_compact_prop_variety_runtime_check.gd` to check count, actual geometry, eight-floor footprint boundaries, entrance clearance and overlap. Updated previous 52-count expectations to 68 without retiring other tests.


## 2026-11-21 — AGENTSの軽量化と作業別仕様書ルーティング

- ルートの `AGENTS.md` を短い共通入口（原則・事前CI検証・`sera_workplan.py` による参照先選択）へ整理。旧ルールを削除せず、節をそのまま `docs/agent/CI_WORKFLOW.md`、`SOURCE_POLICY.md`、`EQUIPMENT.md`、`RUNTIME_BOUNDARIES.md` に移動。全作業でCI手順を必読とし、専門ルールは関係する作業時のみ参照。
- `tools/sera_workplan.py` に `documentation.required/selected/fallback/missing` を追加。拠点、LABO、倉庫、UI、ビットタランを含む機能分類から、存在する現行仕様書と関連Python/Godotテストを選択。未知の依頼はリポジトリ規約・索引へフォールバック。マッピングはツール内を唯一の正本にし、複製を避ける。
- 変更前に `tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/sera_workplan_self_check.py`、既存の開発ルールを確認。新しいルーティング期待値・文書存在・必須ルール保存・AGENTS容量のチェックを実装前に追加。既存の全CI登録・Godotモデル・セーブ・ゲーム仕様・テストケースは変更しない。
- Godot Android画面・ゲーム挙動は今回変更なし。PR統合後のmain全CIが最終確認。ルーティング判定はヒューリスティックで、シグナルや動的参照などは手動調査を継続。


## 2026-11-21 — アイリス装備設定フォームのタブ分離とプレビュー修正
- 旧単体HTMLおよびGodotネイティブWeb版の編集UIを統一。全身はFULL BODY、単体はICON、小型単体プレビューと特殊効果はSTATS / FX、素材はRECIPEへ配置。
- HEAD D+他部位Aを初期状態とし、部位別3D切替を復元。編集対象部位だけA基準サイズ調整（比率保持初期ON）。
- 旧WebGL版の各部位単体抽出、リサイズ、非同期サムネイル撮影を修正。フォーム出力互換`SERA_EQUIPMENT_INTAKE_V1`と原本モデルを維持。
- Godot部位単体可視性・全身復元のランタイム検査、フォームのタブ所属静的検査を追加。
- HTML Raw URLの直接起動禁止は既存のSERA HTML配布規約を引き継ぐ。Androidブラウザ/Godot実機表示は別途確認対象。


## 2026-11-21 — 装備設定フォームの新規チャット引継ぎ、分布図XYラベル、安定2本指、アイコン背景・製作確認回転
- `SERA_EQUIPMENT_CHAT_HANDOFF_V1`を`SERA_EQUIPMENT_INTAKE_V1`のhandoffに含め、GitHub正本パス・SHA、設計図ID、装備スロット、サイズ、ステータス、素材、特殊効果、撮影プリセットと新規チャット実装条件を渡す。正本ガイドは`docs/SERA_EQUIPMENT_CROSS_CHAT_HANDOFF_ja.md`。
- ANALYSISの正方形分布図に上下Y/左右Xの軸名と増減方向を明示。軸選択欄も視覚的に分離。
- 装備単体3Dの2本指を中点/距離差に一本化し、指の追加・解除時に基準を再アンカー、異常な急拡大と移動を抑制。
- 共通ブルーグレーグリッド（#111e28背景、#55798A 36%格子）をGodot単体3D・旧オフラインHTML・ゲーム装備アイコンに適用。1設計図1枚の2D合成キャッシュ、倉庫999アイテムで再レンダリングなし。
- LABOの装備製作確認画面は実装済みモデルの単体3Dをタッチ回転できるようにする。1 SubViewportを遅延生成して閉じたら描画停止。製作／倉庫／セーブ本体ロジック変更なし。
- `portable_equipment_self_check.py`/Godotプレビューランタイムを強化。旧v511のAtlasTexture必須テストを、共有背景を焼き込んだ独立Texture2Dとキャッシュ検査へ更新。

## 2026-11-22：装備作成確認／NEXUSカスタマイズUI

- LABO製作確認は、従来の正方形回転3D・共通グリッド・名称下線・キャンセル／作成の同寸法アクションを保持し、#55798Aアクセントレール、BASE STATUS見出し、暗い単色ステータス領域、左揃えの数値表示へ変更。通常の廃棄・精製確認は既存の簡潔な動作を維持。
- NEXUS全身モデルは入場アニメーション完了後に同じCamera3Dを正投影へ切り替え、カメラサイズを当時の視野角・奥行きから求める。離脱時は透視投影へ戻し、拠点画面・その他メニューのカメラに影響を与えない。モデル原本と保存UIDは変更しない。
- カスタマイズ背景は#243B48の暗いブルーグレーに#142832グリッドを重ね、透過率0.87。中心に発光するエフェクトは加えず、従来の深度テストを維持する。
- PART STATUSは画面下部の全幅を用いた3列・非スクロール表示。名称と値を上下2行で配置し、実モデルの最大10基礎項目＋UID固有の追加特性5件が見切れないよう、28個の既存セルを再利用する。TOTAL STATUSは独立した上段ウィンドウとして維持する。
- 装備名称のタップは閲覧のみ、右端サムネイルボタンのみ選択ウィンドウを開く仕様を維持。新仕様のテスト期待値は本体コード変更前に先行更新。


## 2026-11-22：LABO/NEXUSステータス統一とプレビュー枠の再設計

- **共通ステータス書式：** `scripts/sera_status_column_ui.gd`を正本とし、項目名（灰青）／性能値（明色）の独立したラベル、既存の日本語対応統計用フォントを共有。数値・項目名の正本は`sera_labo_stats.gd`／`sera_nexus_stat_rows.gd`のまま。0値非表示、個体UID特性5件も維持。
- **LABO製作確認：** 「基礎ステータス」「BASE STATUS」を可視UIから廃止。項目名と値の左揃え2カラム×3行に変更し、正方形の回転可能な装備3Dに`sera_tech_preview_frame.gd`の四隅45°欠け角・左上/右下の短いアクセント付き2Dフレームを重ねる（3D描画追加・入力遮断なし）。元のモデル／背景グリッド／製作・キャンセル操作は変更しない。
- **NEXUS：** 全身/単体ステータスは各1枚の暗いパネルに文字を列挙する。セル個別背景と罫線を廃止し、3列の境界のみ#35515Fの途切れない2px縦線（上下9px余白）で区切る。TOTAL STATUS/PART STATUS/PART VIEW/EQUIPMENTの見出し文字・帯は非表示。単体装備名と幅一致の下線、右側装備名と2×2展開ボタンは維持する。
- **配置：** 単体プレビュー左枠と下段フル幅ステータス枠の辺をぴったり接続。回転プレビューに同じテックフレームを重ね、表示項目最大15件（基礎10＋特性5）を3列×5行・非スクロールで収める。統計は16/19pxを基本に可能な範囲で拡大し、全身統計は16/19pxで表示。
- **背景：** NEXUS CUSTOMIZEの正投影全身モデルの背後だけ、単色#172935／格子#0C1C27／不透明度0.96に暗色化。発光エフェクトは復活させない。拠点・他シーンのカメラは維持。
- **CI：** デザイン変更で上書きする旧見出し・文字列・パネル配置の期待値を本体編集前に先行変更した。既存NEXUS/LABO runtimeで画面非重複、15項目の全表示、連続縦線、セル無枠、プレビュー接続、名称タップ閲覧／サムネイル選択、通常確認への復帰を検査する。Android実機視認・ドラッグ品質は別途確認。


## 2026-11-22：NEXUSシーンロード失敗の緊急修正
- 原因：前回UI改修で`_customize_part_stats_rect()`が未宣言の`preview.end.y`を参照し、`command_nexus.gd`のパースに失敗。単体プレビューと下段ステータスの接続位置は`_customize_square_menu_rect(view)`で明示的に取得してから使用する。
- 再発防止：`nexus_split_inspector_self_check.py`に矩形の定義→使用順序を静的検査。既存の`base_startup_parse_runtime_check.gd`にNEXUSスクリプトおよびシーン単体のload/instantiate検証を追加し、表示前にコンパイル失敗を検知する。
- モデル・保存形式・既存の共通ステータスUI・操作方法は変更しない。


## 2026-11-22：NEXUSカスタマイズ／ステータス外観強化・全体項目名の日本語統一

- 全体ステータスの18項目を日本語ラベルへ変更（耐久力、防御率、攻撃力、ブレイク力、怯み蓄積、EN回復速度、攻撃速度、走行速度など）。重量区分は軽量・中量・重量を表示名で示す。内部パラメータ名と計算値、単位、ゼロ値非表示を変えない。
- 全体／単体ステータスは`scripts/sera_status_column_ui.gd`の共通パネル外観を使用する。#0C222Eの落ち着いた単色、#527B8Bの細い外枠、#88B6C6の控えめな上・下・右のエッジアクセントを設ける。表示名・ラベル自体を増やさない。
- 各項目の背景ボックスを復活させない。上下に余白を取った連続2pxの縦仕切り線、名称の細い下線、3列表示、フォントの自動収まり処理、単体最大15項目の非スクロール、装備閲覧・選択の操作区別は維持する。
- 静的テストで全18種類の日本語表示と共通スタイル呼び出しを、Godot実行時でA/B装備の値一致・重量区分・2枚の同一パネル色とエッジマークを検査する。NEXUSスクリプト読み込み・起動検証も引き続き必須。


## 2026-11-22：NEXUSカスタマイズの数値・項目名を拡大

- 旧表示は全体ステータスが横並び16px名／19px値、単体が上下2段16px名／19px値で、スマホ縦画面で読み取りにくかった。
- 全体ステータスを各セル内で上下2段へ変更。**上段19pxの日本語項目名／下段25pxの数値**（長い項目は最低16px／20pxまで自動調整）。3列×最大6行を720×1280の上部パネルにスクロールなしで収めるため、行高44px・行間1px・パネル上端2.5%・高さ22.5%を採用。モデル／装備一覧の開始位置との6px以上の安全間隔を維持。
- 単体ステータスは**上段19px／下段24px**（最低16px／20pxへ自動調整）、行高44px・行間3px。3列×5行＝15項目を非スクロールで保持。項目ごとの囲い枠は追加しない。
- 全体／単体の共通フォント、深いブルーグレーのマット、連続する縦仕切り線、名称下線、単体プレビューとの接続、全体日本語表記、ゼロ値非表示、保存形式・戦闘値は変更しない。
- 事前に`nexus_equipment_stats_* / nexus_split_inspector_*`のCI期待値を更新。Godotで文字階層と枠内表示、6行／15セルの画面内収まりと装備切り替えを確認。日本語化後の動的HP検証は「耐久力」をキーとして参照するよう修正し、旧英語キーによる検査不具合を解消。


## 2026-11-22：拡大ステータスの実描画行高に合わせた修正

- 先行の上下2行案は「全体19px名・25px値」の実フォント描画高が44pxセルを超え、Godotの `nexus_equipment_stats_runtime_check.gd` で失敗したため撤回。
- 承認された文字サイズと44px行高、720pxでの非スクロール表示を優先し、**大きな項目名を左、大きな数値を右**へ分離する横一列レイアウトへ変更。`sera_status_column_ui.gd`の共通関数で文字列の実測幅と割当幅を比較し、長い日本語ラベルだけ最大2行折り返し・必要な最小限のサイズ調整を実施。値領域は右寄せ、全体／単体は共通処理を用いる。
- テストを同一PRで先行変更し、フォント下限を維持したまま名称・数値間の重なり、セルからのはみ出し、全体6行／単体15項目の収まりを検査。ロード・カメラ・部品切替・戦闘性能・保存形式は不変更。


## 2026-11-22：NEXUS単体プレビュー／単体ステータスを微縮小し、全身プレビューを下方配置

- CUSTOMIZE単体プレビューパネルは、720×1280を基準に左4.0%・上50.6%・幅43.5%・高さ18.5%に変更（旧：左3.5%・上49.2%・幅45.0%・高さ19.8%）。内部のドラッグ3Dプレビューは約7%小さくなり、周囲に余白ができる。
- 単体ステータスウィンドウは左4.0%・幅92%・下端90.5%（旧：左3.5%・幅93%・下端91.5%）へ微縮小。開始位置は単体プレビュー下端と接続させる。上部に残る空白を削り、スクロール開始41px・下余白6px、行間1pxとして固定行高44px×最大5行（15項目）を維持する。
- **文字サイズ／フォントサイズ調整値は一切変更しない。** 旧19px/24pxの基準と16px/20pxの横幅適応下限、共通ステータスの表示数と3列区切りを維持する。
- セラ全身用の安全な投影領域を27.5%から始め、モデルの中心を領域中央より3px下へ誘導し、上下の10%を安全余白とする。表示範囲が拡大しても0.90倍の高さ上限に収める。正投影・回転・カメラの設定、元の3Dパーツと装備データは変更しない。
- CIは変更する幾何条件だけ先行更新し、NEXUSのロード・パネル非重複・7装備ボタン・3列×15項目の見切れ・既存の文字サイズ・カメラ正投影を確認。Android実機の画面表示・タッチ操作は別途確認する。


## 2026-11-22：単体ステータスの未使用下部余白を単体プレビュー下方移動に再利用
- Androidの添付画面では「単体ステータス4行の最後」からウィンドウ下端までが空いていたため、その空き分だけ**単体プレビューと接続済みの単体ステータス枠を同時に下げる**。固定の下端（HUD高さ×0.905）と、単体プレビューサイズ（0.435W×0.185H）は変更しない。
- `_customize_part_vertical_shift()`で実際に表示中の統計を数え、3列で必要な行数を算出する。行高44px・行間1px・統計名上部41px・下余白6px・安全余白3pxを差し引き、**余った高さだけ0〜最大4.5%H移動**。標準脚部の10項目（4行）なら1280pxのHUDで約45px下降。特性5件等で15項目（5行）なら必要高さを確保して下降量を0にする。
- 装備名タップや装備変更による`_refresh_customization_part_stats()`の表示数更新後、`_layout_hud()`で関連する2ウィンドウを再配置する。タッチイベントとドラッグ先も表示位置に追従する。単体ステータスのフォント（19px名・24px数値、必要に応じた幅適応）、全体ステータス、データ・装備・保存・戦闘への変更なし。
- セラ全身モデルの投影領域は元の開始点27.5%・下端50.6%-既存ギャップに据え置き、**単体プレビューだけを下げてセラの足元の視覚的余白を増やす**。モデルを自動拡大しない。正投影・背景を保持。
- CIは静的期待値を本体より先に追加。Godot runtimeで10/15項目をシミュレーションし、4行時の下方移動（25〜55px）、5行時のフル表示、共通下端、元のフォント・回転/装備操作・既存のNEXUS起動を検査する。Android画面の目視・タッチ感触は別途確認。


## 2026-11-22：NEXUSステータスの日本語改行を意味の切れ目で統一

- 旧`StatUI.layout_metric_pair()`は`TextServer.AUTOWRAP_ARBITRARY`に依存し、ブースト速度倍率／被弾時間倍率／部位モデル区分などの複合語の途中で1文字だけ折り返す場合があった。
- `scripts/sera_status_column_ui.gd`に表示専用`semantic_stat_lines()`を追加。単語を表示幅（既存Font・自動適応後の名称フォントサイズ）で実測し、**1行で収まる場合は改行せず**、2行が必要なら明示的な日本語の語境界（例「被弾時間｜倍率」「部位モデル｜区分」「歩行｜モーション」）を優先する。長い名称については狭幅用の第2候補を設ける。未登録の特性名は「特性｜名称」、既知の複合語末尾は「倍率・区分・回数・モーション」等で分ける。最後の代替でも行頭の長音符、閉じ括弧や1文字だけの孤立を避ける。
- **本来の名称・内部パラメータ名、数値、フォント基準・下限、列幅・44px行高・最大15項目表示・正投影・装備切替は不変更**。表示用Labelにのみ明示的改行を挿入する。再レイアウトのたびに改行を取り除いて元名称から再計算し、重複改行を防ぐ。
- 先行更新した`nexus_equipment_stats_self_check.py`・`nexus_split_inspector_self_check.py`で語境界辞書と共通関数使用を保証。`nexus_split_inspector_runtime_check.gd`では実フォント幅を使って7つの日本語複合語の2行分割と再配置の安定性を検査する。既存NEXUSロード／全体・単体UI／タッチ操作テストも維持する。


## 2026-11-22：NEXUSステータスの実数・単位・武装別区分とドラッグ改善

- 旧 NEXUS 全体表は攻撃力・破壊・怯み・攻撃EN消費を**1段目だけで表示**していた。現在の武器プロファイル3段を算術平均し、表示数値は一律小数点第1位。`PartStats.build`と実戦闘の値は不変更。
- 装備武装による全体性能の変化は`sera_nexus_stat_rows.gd`で本体（重量・耐久力・防御、移動、近接攻撃、補助）→武装（右武器ダメージ/破壊/怯み/EN、左武装バッシュダメージ/破壊、ガードEN消費/移行、実装済みシールド有効性）として構成する。`group: body/weapon`を付与し、パネル内の武装開始位置に#55798Aの横線を配置。ユーザーが決めた順序は画面見出し追加を意味しない。
- 全ての数値を`%.1f`で表示し、倍率は`×1.0`、速度は`m/s`、実時間は`s`、割合は`%`、ENコストは`EN`で表記する。ゲームにkgの実重量がないため、名称「重量」の下で現在の基準重量比`100.0%`などを表示する。単体表も`sera_labo_stats.gd`で同じ規則を適用し、配列系攻撃性能は全段平均にする。名称から「倍率・時間・秒数・（各段）」を廃止、「ダメージ・破壊・怯み・防御・重量」を使用。ブーストやシールドなどの意味のある名詞は残す。
- 左手プロファイルの`charge_damage`/`charge_break`/`charge_guard_mult`は現在の戦闘処理に参照元がなく、存在しない溜め攻撃を示していたため**表示だけ除外**（旧UID・プロファイル定数は残し互換性維持）。Kカタナ装備時に左手シールドは装備できないため、全体武装欄からも左手性能を除外。
- NEXUS CUSTOMIZE全身は初回の指またはマウス押下がモデル領域内なら入力を捕捉し、他のウィンドウ・枠へ移動しても解除まで回転を継続。Xはyaw、Yは±55°制限のpitch。既存の部品ビュー内ドラッグは独立、タップ・装備選択は不変更。
- 単体プレビューのSubViewportContainerをフレーム全面に広げ、共有の装備ビューのGRID QuadMeshとUVをビューの縦横比に追随させる。正方形アイコンのレンダリングはアスペクト比1.0で従来と同じ。
- 本体より先にNEXUS静的・実Godotのステータス/ジェスチャー期待値を更新し、実数・3段平均・左右装備切替/カタナ排他・領域外へのドラッグ・背景枠サイズを追加検査。`tools/sera_ci_manifest.txt`へ新2テスト登録。Godot初期ロード・既存装備/保存・Android実機確認を分けて報告。


## 2026-11-22 — v536 NEXUS選択部位の発光・ビットタラン開始間隔とHUD修正
- NEXUS CUSTOMIZEで閲覧中の部位（頭・胴体・脚・腕・ブースター・左右武器）の**実際に可視の装備メッシュのみ**青白い透過加算の発光を表示。選択先や装備を変えると直ちに付け替え、画面離脱で必ず消灯する。深度テストON、共通描画順定数を使用し、原本材質/戦闘モデル・入力・セーブには触れない。
- ビットタラン戦の初期中心間距離を8m→12mに延長。初期カメラ構築前にボスと床マーカーへ反映し、KO/復活後も12mに戻す。通常訓練は8mのまま。攻撃AIや戦闘バランス値は維持。
- ビットタラン名のラベルを下方186pxへ移し、HP/ロック部位メーターから分離。勝利表記を230pxへ移し、撃破時は名前を非表示にして重複しないようにする。
- 新規 static + Godot 実行時回帰検査を `tools/sera_ci_manifest.txt` に事前登録。特性/保存・スケール/攻撃・HUDの既存検査を維持。Android実機の発光視認性とタップ切替は別途確認。

## 2026-11-22 — v537 NEXUSカスタマイズの回転・点滅・選択行強調
- 全身プレビューの上下ドラッグを反転。下へ動かすとpitchを減らし、上へ動かすと増やす。水平ドラッグと±55°の角度上限は維持。
- 初回入場時のカメラフィッティングは維持。ドラッグ中の安全領域へ向けた並進位置補正と自動倍率調整を完全に廃止し、位置/スケール固定の回転だけにした。
- 選択中部位の3D発光を1.0秒周期（点灯0.60秒/消灯0.40秒）へ変更。可視メッシュの既存オーバーレイのみをON/OFFし、元のテクスチャと材質は保持。選択切替時は点灯から再開し、退出時は削除。
- カスタマイズ右メニューの閲覧対象1行を明るいブルーグレーの面/明るい縁取り・名称/展開枠で強調。名称タップ=詳細表示、右端ボタン=装備選択、保存とブロック中の2手持ち設定は変更なし。
- 既存manifest登録の静的テストとGodotランタイムテストを先行更新。方向・モデル位置/倍率不変・明確な消灯/点灯・右メニュー行切替を検証する。実機の見え方は自動CIと区別。

## 2026-11-22 — v538 NEXUS全身プレビューの胴体中心ピボット
- モデルの原点（足元）まわりの回転を廃止。既存の `_customize_torso_anchor_local()` が取得するChest/Torso/Waistの平均位置を、カスタマイズ開始時に保存し、全身プレビューの回転軸に使用する。
- 向き・倍率を適用したモデル原点を「基準正面姿勢での胴体中心（カメラローカル） − 現在の姿勢の胴体中心ローカルオフセット」として求め、回転中の胴体中心を厳密に固定。フィット後の表示位置・倍率は不変、手動ドラッグで画面領域補正をかけない。正面姿勢では従来の変換式と同じ見え方。
- 入退場Tween用の胴体中心アンカーと同じ既存マーカーを再利用し、3Dモデル原本・既存シーン・戦闘挙動に変更なし。タッチ/マウスの回転テストでは原点は軸を中心に動いてよい一方、胴体中心のワールド位置と表示基準/倍率が不変であることを確認する契約に更新。
- v537で採用した上下回転反転・発光点滅・右側行の強調は維持。回帰テストの期待値を先行変更し、後から実装。

## 2026-11-22 — v539 NEXUS全身プレビューの左右ドラッグ反転
- `_rotate_customization_preview` のyaw更新符号を反転（`-yaw_delta` → `+yaw_delta`）。画面の右方向の指移動が正のyaw、左方向が負のyawになる。タッチ・マウスの共通経路にのみ適用。
- v537上下ドラッグ反転、v538胴体中央の固定ピボット、ドラッグ中の平行移動・自動スケール補正廃止、選択部位点滅・右行強調はすべて保持。
- 先行更新した静的CIとGodotのドラッグテストは、符号つきyaw差を`wrapf`で比較して`-PI/PI`境界をまたぐ場合でも正しく検証。入力中の胴体中心位置・初期表示位置・倍率が固定であることも既存テストで保持。


## 2026-11-22 — 共通ローディング端末UI / BASEプレビュー
- 実ロード表示をブルーグレーのSFコンソールへ刷新。新規 scripts/sera_loading_console.gd に電子画面テクスチャ、走査ノイズ、角欠けフレーム、端末ログのスクロール、最新メッセージ・数値％・100分割の光る進捗レールを共通実装。
- BASE起動処理は床、NEXUS、各施設、GRID、廃材、プレイヤー、CRATE、UI、セーブ位置記録の完了後のみロード進捗を更新。所要時間に比例した架空の進捗アニメーションは使用しない。値は完了タスクに重みづけした工程進捗であってバイト単位ではない。
- BASEに「ロード演出」プレビューボタンを追加。画面遷移やセーブ操作なしで5秒を100等分し、50msごとにログを表示、100%まで到達した後BASEへ戻る。
- 変更前に既存 base_startup_first_frame と base_loading_sweep CI期待値を新UI仕様へ先行更新し、sera_loading_console 静的/実Godotランタイム検査を登録。既存スイープ本体と独立検査は保存。
- 詳細: docs/SERA_LOADING_CONSOLE_RULES_20261122_ja.md。Godot実行・Android画面とアニメ品質は未検証のためCIと実機チェックが必要。

## 2026-11-22 — ロード画面の移動ライン削除
- 共通ロードコンソールの横方向に走る青白いスイープ線、画面を横切る移動ノイズ帯を削除。
- 背景の固定走査線・粒状ノイズ、世界観ログ、実ロードの段階進捗、BASEの5秒/100段階プレビュー、フレームや数値%は維持。
- 本体修正前に登録済み静的CIの期待値を更新し、移動ラインの再混入を検出するアサーションを追加。


## 2026-11-22 — BASE 黒6px・暗灰2px線色確定／PR #708最新main統合
- 先行してmainへ統合済みのBASE最新SERA反転ハル移植およびIRIS内部黒塗り対策の深度マスクを保持し、施設8棟の6px輪郭色だけを純黒 `#000000`、前面ポリゴン角の2px線色を `#353535` に変更。
- 元のバッチ配置、2px隣接角形状、機械アニメーション追従、光・煙・炉床反射の除外、NEXUS復元モデルはそのまま。SERA本体の3px輪郭色も変更しない。
- シェーダー内の誤ってエスケープされた `\\n` を実際の改行に修正。テストはまず新色・改行が仕様であることを検査するよう先行更新。PRのBASEカメラ撮影とmainの全CI、Android実機画質はそれぞれ別検証。

## 2026-11-22 — 共通ロード画面のCORE診断アニメーション
- 中央に脈動するCOREと3層の独立回転リングを2Dキャンバスで追加。
- CORE/SHELL/OS/NEXUS/GRID/LAB/ARCHIVE/CRATEの接続ノードを追加。点灯は起動工程の既存完了マイルストーンへ連動し、装飾アニメの経過時間には連動しない。
- 左右に信号バー・波形診断パネルを追加。720×1280と狭幅縦画面向けに領域を計算し、既存ログ表示数を領域に合わせて制限。
- 従来の固定走査線・粒状ノイズ、5秒/100段階のBASEプレビュー、実工程進捗、100目盛ゲージを維持。横へ流れる光の線は復活させない。
- 静的CIおよびGodotランタイムテストで、起動段階ごとの点灯・視覚アニメと進捗の分離・縦画面の専用領域を検査する。


## 2026-11-22 — BASE黒6px線の実画面不可視回帰修正（最新mainへ統合）
- ユーザーの実Androidスクリーンショットでは施設シルエットの黒6px線が視認できない。黒線設定値の既存CIだけでは描画成立を検証できていなかった。
- BASEの時計回り元メッシュからSERA共通で作った輪郭メッシュ法線のみ、BASE専用の生成時に反転。セラ／ビットタランの共通ジェネレーター、片面装甲向け高速描画、3px輪郭の形状と色は変更しない。
- 6px輪郭の斜め方向の深度探索距離を9pxに拡張し、SERA3pxは従来どおり。幅uniformの上限は8px、施設2px角線はダークグレーのまま。
- BASE立方体の外向き法線をGodot実行時に検査。BASE標準720x1280画面で6px線あり／なしの画像差分を確認する追加CIも登録。Android実機とCI PNGの最終レビューは別途実施する。


## 2026-11-22 — BASE輪郭実機未表示の診断モード
- PR #708/#713後もAndroidスクリーンショットで黒6px線を視認できず。NEXUSの画像領域はほぼ変わらず、端末GitSyncの反映状況とシェーダーの深度マスク消失を区別できないため、完成扱いにしない。
- BASEプレビューメニューに「輪郭検査 v1」を追加。初期状態は黒6px＋暗灰2px。1回目で共通シェーダーのマゼンタ6px（深度判定あり）、2回目でマゼンタ6px（深度テクスチャ判定なし）、3回目で黒6pxに戻る。追加ボタンが端末に出るかも更新反映の目印。
- 2px角線・SERA本体3px・施設の機械アニメーションと演出は変更しない。診断時の深度判定なしシェーダーは誤描画の可能性があるため通常描画には使用しない。
- 静的・Godotテストで診断切り替えと復元を検査し、Android実画像確認後に根本対処を選択する。


## 2026-11-22 — BASE輪郭の実Android診断：反転ハル廃止・可視エッジリボンへ置換
- ユーザー提供の同一BASE画面3枚により、黒6pxの通常状態と深度ONの紫6pxはいずれも不可視、深度OFFの紫6pxは建物全体が紫色になると実証。端末の診断ボタン表示でGitSync反映も確認。色・法線のパラメータだけでの解消は不可。
- BASE施設に限り反転ハルの全三角形描画をやめ、既存の `sera_base_facility_crease_geometry.gd` が持つ隣接面情報・頂点タンジェントのエッジリボンを黒6pxの独立GPUパスで描く。2面のうち片方だけカメラを向いた稜線または可視境界線のみ選択し、両面が見える内部角へ6px線を引かない。
- 既存の暗灰`#353535`・2px前面硬角は別マテリアルのまま。BASE時計回りの法線を2px側でも補正。どちらのGPUパスも通常深度テストON、FX/煙/炎/床反射は除外し、アニメーション追従・MultiMeshバッチを維持。SERA／IRIS／ビットタランの輪郭シェーダーには手を付けない。
- 診断UIは紫6px輪郭／紫6px全エッジ表示へ更新（モデル全面の紫塗り不可）。GitHubのBASE実画面720×1280の6px表示ON/OFF画素差試験を保持し、新たにエッジリボン構造と8施設適用を確認するstatic/Godot CIを先行追加。
- 既存UI・モデル・セーブとゲーム操作は変更せず。GodotレンダリングCIとAndroid実機の最終的な黒線品質は別途確認する。


## 2026-11-22 — BASE線幅・角線色を変更（CI省略マージ）
- 施設8棟の外周輪郭を6pxから**黒4px**へ変更し、既存2pxの前面硬角線をダークグレー `#353535` から**黒 `#000000`**へ変更。輪郭エッジリボンと独立角線の2パス、カメラ向き判定・GPU深度テスト、煙/光等の除外、MultiMeshアニメーション同期は変更なし。
- 右上の「輪郭検査 v1」表示切替中も4pxを維持。ゲーム本体セラ/IRIS/ボスの3px外周は変更なし。設定値の変更に合わせて既存static/Godot CI期待値を先行更新。ユーザー指定によりCIは実行せずmainへマージし、実機表示とCI結果は確認していない。

## 2026-11-22 — ロードコンソールの描画解像度を端末内部だけ50%に変更
- 共通ロード端末の画面を SubViewport（表示寸法の0.5倍）で実ラスタライズし、TextureRectの最近傍フィルタで従来の画面いっぱいへ拡大。
- ゲーム設定の720×1280、シーンやUIサイズ、戦闘・拠点・NEXUS・GRID等の表示解像度は変更しない。
- 端末表示の既存COREアニメーション、診断パネル、ログ、100目盛ゲージ、5秒100段階プレビューを維持。端末の表示側だけが描画し、親は進捗処理を一元管理。
- 静的CIおよび実GodotランタイムCIの期待値を実装に先行更新。360×640/225×400への追従、NEARESTフィルタ、進捗同期、旧横移動スイープの不在を確認。

## 2026-11-22 — 装備プレビュー背景の枠線コントラスト統一
- 装備アイコン／LABO製作確認／倉庫詳細／NEXUS単体パーツ／装備編集用プレビューに共通する `sera_icon_background.gd` を明るいブルーグレー `#A9BBC7` に変更。グリッド色は `#8299A8`。既存の角欠けフレームと装備モデル、素材アイコンの仕様は維持。
- `equipment_intake/godot_preview.gd` の3D環境単色背景を同じ共通色から参照させ、グリッド表示の有無によって色が食い違わないようにした。戦闘・BASE・NEXUS施設本体の背景や照明は変更していない。
- 描画シェーダーのセラ外周線 `#17212f` とNEXUS角線 `#7e858e` を基準に背景とグリッドの相対輝度を保証する局所テストをCIマニフェストへ追加し、ポータブル装備テストおよびGodotプレビュー期待値を更新。
- GitHub Actions全件／Godotヘッドレス／Android実機の視認性は未検証。既存テストを削除・無効化していない。

## 2026-11-22 — NEXUS HEAD D：可視ID輪郭の幅3px均一化
- NEXUSのアイリス単体プレビューだけ、4方向ID比較を3pxユークリッド距離判定に切り替え、45°などの輪郭をつなぐ0.5px以内の半透明縁を追加。外周は内側、接合線は高ID側のみ描画して二重6px線を避ける。ゲーム共通輪郭・他装備・正本テクスチャは不変。
- IDバッファを表示Controlの画素寸法へ同期し、再描画回数・複製メッシュ数・理論上の最大ID参照回数・CPU同期時間を取得できる診断を追加。静止時のID描画は従来どおりUPDATE_ONCEで停止。
- CI/GitHub Actionsは不使用。独立Pythonの境界幅・ID片側・45°連続性数値テストPASS、コード静的確認11項目PASS。Godot 4.7シェーダーコンパイルとAndroidの見た目/FPS/GPU時間は未検証。GPUサンプル上限は最大13→37に増加し、負荷は実機で要確認。

## 2026-11-22 — HEAD D アイリス原本の装甲色をライトグレーに変更
- `models/storage/カメラアイ頭部.bbmodel` の内蔵16×16 RGBAテクスチャの茶色装甲 `#352B2B` を `#B8BEC4` に置換（146/256画素）。レンズ `#2B8DAD`、内部 `#353637`、金属 `#5D5F60` の色と各画素数、6メッシュの形状・UV・ID・面向きは維持。
- Androidフォールバックの `assets/sera_camera_eye_head_data.gd` を正本から再生成。H02撮影プリセットのモデルSHA-256を更新し、カメラ設定・輪郭3px・H02装備性能は維持。ローダーやNEXUS ID輪郭シェーダーへの色の上書きは追加しない。
- `tools/camera_eye_head_self_check.py` にPython標準ライブラリだけでPNG_RGBAを復号するパレット検査を追加。既存の `tools/iris_h02_craft_self_check.py` は新原本指紋を検査し、撮影済み旧アイコン画像の履歴メタデータは旧指紋のまま保持。
- 旧撮影済みH02 PNGは再撮影前の歴史的な成果物として保持し、ライトグレーの新たな承認済みアイコンと偽装しない。CI/Android実機の最終3D色確認は未実行。


## 2026-11-23 — NEXUS室内輪郭の発光透過・重なり修正

- NEXUSの共通可視RGB-IDによる不透明メッシュ深度解決は維持し、輪郭の最終合成だけをCanvasLayer最前面から、透明3Dの低優先度パス（`render_priority=-30`）へ移動。手前の入口漏光・半透明演出が室内輪郭線に上書きされる見え方を解消する方向へ修正。
- `shaders/sera_nexus_mesh_contact_spatial_ink.gdshader`を追加。従来のNEXUS用内側1px・外側2px・接合2px、建築2pxのRGB-ID輪郭演算、IDの深度遮蔽、色`#17212f`を保持。被覆していない画素は`discard`し、互換レンダラーの透過面着色を防止。
- `scripts/sera_scene_id_outlines.gd`ではNEXUSの描画Quadを共有3D描画方式と同じCamera3D子に設置し、カメラ移動、ID解像度、輪郭スクリーン範囲および線幅を追従更新。BASE・戦闘・GRIDの輪郭シェーダー、全身のSERAメッシュ、モデル原本、装備やUIの動作は変更しない。
- CI項目の確認・修正・適用、静的検査、Godot/実機テストの実行は行わない。Android実機での重なり・輝度・負荷は未確認。


## 2026-11-23 — NEXUS可視ID外周の室内面への上書き抑止

- 実機画像で床・台座周辺に線が残る問題に対し、NEXUS RGB-ID輪郭合成の「セラ外周2pxの近傍補完」を `!room`（可視室内メッシュIDではない画素）に制限。手前の床・壁・台座などのroom ID領域へセラ輪郭が無条件に塗られる経路を閉じる。
- 現行の透明3D合成シェーダー `sera_nexus_mesh_contact_spatial_ink.gdshader` と互換Canvasシェーダー `sera_nexus_mesh_contact_ink.gdshader` の判定を同じにした。室内構造の2px枠線とセラの内1px・外2px・接合2px、既存RGB-ID深度、光の重ね順は保持。
- 背景に部屋IDがある部分のセラ外周補完が狭くなる可能性はある。Godot/Android実機の表示確認・性能計測を実行していないため、画面上の完全な解消は未確認。ユーザー指定によりCI項目の閲覧・変更およびテスト実行を行わない。


## 2026-11-23 — NEXUS床タイル輪郭の残留線と深度遮蔽の整理

- 実機画面で足元・床パネルの黒い線が残る原因を追跡。NEXUS Blockbenchのhangar_shellは独立した15枚の「Floor steel tile」・床下基礎・排水パーツが通常の室内構造と同じパレットMultiMeshに入っており、可視IDパスが床目地にも装甲用2px輪郭を描いていた。前回のセラ外周補完制限だけではこれらの線は消せなかった。
- `scripts/command_nexus.gd`の描画バッチを床面ID遮蔽専用と通常建築で分け、床の見た目・元モデル座標・素材色・光る床トレースは変更しない。床面だけに`sera_outline_occluder_only`を設定。
- `scripts/sera_scene_id_outlines.gd`のNEXUS専用RGB深度パスでは床を青チャンネル1.0の非輪郭IDとして描画する。元の3D床は不透明のままで、輪郭だけ描かず奥の構造線を遮蔽する。床メッシュをIDの空背景と取り違えないため、両NEXUS輪郭シェーダーのセラ外周膨張も床マスク上で禁止。
- 建築物・中央台座の2px輪郭、セラ内1px・外2px・接合2px、NEXUS透明3D合成、BASE・戦闘等の共通パスは維持。追加のSubViewportは作成しない。独立タイル間に元々存在する物理的な隙間や素材面の色差は変更しない。
- ユーザー指示によりCI項目の操作とテスト実行は行わない。Android実画面での最終結果は未確認。


## 2026-11-23 — NEXUS室内輪郭の3D深度式再構築（可視IDはセラ専用）

- 既存NEXUSの建築／SERA両方をID色で塗る画面全域輪郭合成方式を廃止。建築（床タイル・排水・発光パーツを除く）にはBlockbenchの元3D立方体／中央12角台座に対する`nexus_polygon_edges.gdshader`の2px線を直接`material_overlay`として配置。色`#17212F`、通常深度テスト有効、透明エフェクト前に描画。元のメッシュ、座標、カメラ、テクスチャ、陰影、入口光を変更しない。
- セラは既存1基の`SeraVisibleIDs` SubViewportを利用。建築物・床・台座は全て同一ID深度パスで`(0,0,1)`の遮蔽物としてだけ書き込み、描画インクを出さない。ネクサス専用`sera_nexus_mesh_contact_spatial_ink.gdshader`をセラ専用へ全面整理し、内1px/外2px/独立メッシュ境界2pxのみ描画。外側の線はID背景(0,0,0)にだけ許可する。
- 建築輪郭用のSubViewport・第2カメラ・追加背景・画面全面の建築輪郭パスは作らない。NEXUSの既存WorldEnvironment背景とセラ深度ID用の黒クリア環境は、それぞれ実画面背景／ゼロIDのために維持する。旧ハル・ステンシル診断は通常の描画へ復活させない。
- NEXUSの「拠点の枠線」オプションを建築3Dのmaterial_overlayのON/OFFへ直結し、セラの輪郭オプションから独立。BASE・戦闘・GRID・単体プレビューは変更しない。
- CI項目へのアクセスおよびGodot・静的・実機テストは一切実施していない。実機での深度・線幅・パフォーマンスは未確認。


## 2026-11-24 — NEXUS床パネルを参考画像の工業デッキ構成へ刷新（未マージ）

- `scripts/sera_nexus_floor_panels.gd` を追加。中央は長方形の大判スチールパネル、両側は狭い整備用プレートと不規則な継ぎ目を採用。暗い目地と段差・二段構造、パネル四隅の留め具、控えめな金属色差と擦れ表現を用意。
- 両端に青白い埋込照明、内側に黄黒の斜線警告帯を配置。中央通路の排水グレーチング2本は深い溝、金属リブ、細いハイライトで構成。
- 従来の `hangar_shell` の床タイル・排水溝・灯具・警告帯のみ読み込み対象から除外。**床下の基礎、中央台座、NEXUS施設と全選択操作、ステージ座標、既存カメラは変更しない。**
- 床形状は材質別に `MultiMeshInstance3D` でまとめ、描画時のオブジェクト数とドローコールを抑える。すべて不透明かつ通常深度テストで描画し、`sera_outline_occluder_only` により床面から新規輪郭線を描かない。既存の可視ID方式やシェーダーは変更しない。
- ユーザー指定によりCI項目を確認・変更せず、テストは実施していない。Android端末上の実際の見え方・性能は未確認。


## 2026-11-24 — NEXUS床を実機画像に基づいてゼロから再構築（ユーザー指定マージ）

- 実機スクリーンショットでは、前回のNEXUS床が大判の均一な平板と画面幅をほぼ埋める排水格子に見えていたため、床生成スクリプト `scripts/sera_nexus_floor_panels.gd` を全面置換。
- 15.5mの室内幅と既存Blockbench基礎座標は維持し、中央通路を3列の大型長方形鋼板、左右を幅の異なるサイドパネルへ再編。パネルごとに控えめな色差、段差のある縁、暗い継ぎ目、ボルト、点検ハッチとごく細い擦れを追加。
- 黄黒警告部は中央通路の左右の細い溝に限定し、斜線バーを個別配置。青白い埋込照明は暗いソケット＋金属縁＋発光面に整理し、床面への物理光源追加はしない。
- 手前の大型排水格子を撤去し、幅2.80mと3.45mの短い排水グレーチング2基へ変更。グレーチングはいずれも中央通路内に収め、手前の視界を横断しないように配置。
- 床描画は全要素を不透明かつ材質ごとの `MultiMeshInstance3D` で集約。床の可視ID輪郭は追加せず、既存NEXUS可視ID方式の深度遮蔽物として扱う。中央台座、コンソール、カメラ、HUD、操作、セラ本体、GL Compatibility設定と保存形式は不変。
- CI項目・テスト用ファイルは一切確認・更新していない。Godot、Android、CI、静的検査のいずれも実行しておらず、実機での描画結果と処理負荷は未確認。


## 2026-11-24 — 参考画像と実機画像の比較によるNEXUS床構造の全面見直し

- **問題点（比較）:** 前回の3列の平板は室内手前を単調な一枚板に見せ、通常のBoxMeshを重ねた表面は目地が直線的で薄い。排水格子は床上に載った梯子状に見え、参考画像の鋼板の組み合わせ・四隅の切り欠き・光を受ける金属エッジ・床下設備の奥行きが欠けていた。
- **新しい基本構成:** 床を7列の異幅レーンに再設計し、行ごと・列ごとに継ぎ目位置をずらしてT字継ぎを形成。中央通路は幅3.52mの主装甲板、左右に細い補助板と整備レーンを置く。奥は比較的長い、手前は短いパネル周期として遠近の見た目に変化を持たせる。
- **装甲板の立体構造:** 床面一枚ごとに正規化した8角形の実メッシュを共有し、切り欠いた四隅・傾斜したベベル・明暗の異なる法線と頂点色で上面と縁を分離。下側の暗いスカート、鋼板ごとの色差、4点のボルト、薄い刻線や整備用蓋を合わせる。上面の金属材質は粗さとクリアコートを調整し、中央には不規則に分断された控えめな反射色を付ける。
- **排水設備:** 中央レーンの該当領域を板生成時点で切り欠き、地面より低い黒い受け皿、その上の細い金属リブ・横補強・周囲フレームを配置。平らな鋼板の上に格子を重ねる旧方式を廃止。
- **警告帯と床灯:** 幅0.54mの暗い側溝内に黄黒斜線を配置し、手前中心に表示。床灯はソケット・縁・短い青白発光面を積層。既存の室内灯、ポータル、カメラ、中央台座、操作UIおよび輪郭方式は変更しない。
- **実装負荷と描画契約:** 正規化8角板・単位立方体・8角ボルトを材質別の固定 `MultiMeshInstance3D` としてまとめ、床は通常深度有効の不透明オブジェクト。床メッシュは可視ID輪郭を出さない遮蔽物で、透過FX・追加Viewport・照明・毎フレーム更新を増やさない。
- **検証:** 指定によりCI関連の確認・修正やテスト実施は行っていない。Godot上のコンパイル、Android端末の見え方と描画負荷は未確認。


## 2026-11-24 — NEXUS床の実機画像を踏まえたV4ディテール改善

- 実機画像で、前面の排水格子が広く目立ちすぎること、中央の暗い大板が単調なこと、板同士の黒い隙間と角の欠けが太く見えること、床に短い塗装線のような不自然なハイライトがあることを確認。参考画像に対して、構造上の密度と鋼板の連続性が不足していた。
- 手前のパネルの縦ピッチを約2.2mから約1.5〜1.9mへ縮小。中央通路の板は4段に1度のみ幅広の一枚板とし、それ以外の列を左右2分割して、単調な大面積の板を減らす。列間・行間の基本目地を細くする。
- 8角形装甲の角欠けとベベルの幅を大幅に縮小し、板の外周の暗いスカートと床下の色を明るいブルーグレーにして、極端に黒い亀裂の印象を抑える。鋼板の金属色、光沢と粗さを調整。大きく途切れる中央の反射塗装線を廃止し、少数の低コントラストなブラシ跡と短い刻線のみを維持。
- 手前と奥の排水格子をそれぞれ幅2.28m/2.48mの細い設備へ縮小し、視野の中央寄りへ移動。格子の外側に装甲板のショルダーを追加し、中央通路全体が穴になる構成を解消。格子の横補強を増やし、色を暗く抑える。
- 7列レーン、暗い警告側溝、青白い埋込照明、細かなボルト、固定の材質別MultiMesh、深度テストONおよび床輪郭抑止は維持。NEXUS建築、中央台座、操作、輪郭シェーダー、カメラ、セーブに変更なし。
- CI項目の確認・更新、および静的・Godot・Android・CIテストは実施していない。実機の最終見栄えと動作負荷は未確認。


## 2026-11-24 — NEXUS床の間延び解消と前景コンソール／ゲートの分離

- 最新の実機画像を参考に、床の中景と前景の装甲板の縦ピッチを短縮。奥側は約2.56m、中景は約1.82m、ステージ付近〜手前は約1.48m、さらに手前は約1.28〜1.38m（各列の微小オフセットあり）とし、長い単調な床の空白を減らす。
- ステージ周辺の左右に低い点検ベイ／ロック部品10基、中央通路に短い床補強金具3組、補助埋込ライト左右3箇所ずつを追加。すべて既存の床と同一の不透明・静的MultiMeshへまとめ、中央台座の有効半径・施設本体・操作画面は変更しない。
- SYSTEM左前景コンソールの原点を(-2.45,0,1.45)から(-2.50,0,3.25)へ、TRAINING右前景コンソールを(2.38,0,0.55)から(2.55,0,3.10)へ移動し、縦画面で大きく手前へ配置。既存の形状・角度を保持し、俯瞰時の3Dモデルからタップ・選択用シルエットを生成する経路は継続。
- ゲートの原点を(5.10,0.02,-15.50)から(3.45,0.02,-20.35)へ移し、右コンソールと投影位置が近づきすぎないよう奥と中央寄りへ移動。ゲート本体と漏光は同じ `GATE_ORIGIN` と回転を共有するためズレを生じさせない。奥壁より手前の位置を維持。
- SYSTEM・TRAINING・DEPLOYMENTの焦点カメラ位置とlook対象を新しい配置に追従させ、選択時の表示位置が旧座標に留まらないよう変更。
- NEXUSの2D選択シルエット合成で、従来はセラ本体だけに対してクリップしていたゲート枠線を、手前2基のコンソールシルエットにもクリップ。3D深度はそのままに、ゲートの選択輪郭が手前コンソールを貫通することを抑える。選択優先順位は既存の「手前端末優先」を維持。
- CI項目は確認・変更せず、静的・Godot・Android・CIテストも実行しない。実機での実際の重なり・視認性・負荷は未確認。


## 2026-11-24 — NEXUS専用の立体生成メッシュによる工業ディテールの追加

- `scripts/nexus_generated_architecture.gd` を新規追加。既存の直方体Blockbenchモデルは原本として維持したまま、SYSTEM／TRAININGコンソール、DEPLOYMENTゲートに**実際の頂点・面・法線を持つ8角形の押出装甲メッシュ**と、6列の斜めルーバーを備えた**通気スリットメッシュ**を追加する。装甲は前面・傾斜ベベル・厚みのある側壁を別の面として作り、幅と高さを個別に変えて使う。
- SYSTEMコンソール：左右の下部鋳造装甲、画面両側の細い装甲、前面の通気設備と小さな留め具。TRAININGコンソール：非対称の前面装甲、画面両脇、下部の通気設備、右側センサー下の小型カバー。すべてモニターの発光領域とキー操作部分を覆わない寸法に限定。
- ゲート：両側の外柱の装甲フレーム、上部梁の左右に小型鋳造部品、足元装甲と通気部を追加。発光入口の開口部を残し、ゲートの共通原点とYawから変換するため、ゲート位置と漏光の移動先に追従する。
- 頭上の整備キャノピー内側へ**24角の閉じた環状ベアリングメッシュ**を追加。天井の既存12分割アーム、青白い照明、中央ステージや可動部分は変更しない。
- `scripts/sera_nexus_floor_panels.gd` の点検ハッチ・点検ベイを、平面の箱の重ね合わせから共通の**8角形面取り付き、縁が高く中央が凹んだArrayMesh**へ置換。固定ボルトと小さな操作スリットは引き続き残す。
- 立体形状はNEXUS入室時に1回だけ作り、材質と形状ごとのMultiMeshでバッチ化。床・施設の追加部分は全て通常の不透明深度テストに従い、既存のRGB可視ID描画・施設用輪郭パスへの新規登録はしない。追加の光源・透明描画・別Viewport・毎フレーム更新も不要。画面／ゲートの選択シルエットは既存Blockbench構造を用い、装備、入力、カメラ、保存データは変更しない。
- ユーザー指定により、CI項目の確認・更新およびGodot・静的・Android・CIテストは実施していない。描画と性能の実機確認は未実施。

- BASE施設消失対策：各施設を独立して生成し、モニターは施設本体・回転部・看板の完成後に追加。補助SVGはモニター生成時に読み込む。

- BASEの輪郭対象探索を0.65秒ごとの全走査から、登録・描画設定変更・拠点内メッシュの追加削除時の再探索に変更。
