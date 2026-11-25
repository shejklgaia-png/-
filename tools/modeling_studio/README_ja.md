# SERA Modeling Studio（モデスタ） V1

ChatGPTが設計データを編集して機械形状を制作するオフラインCLI。Godotのゲーム実行時には使わない。既存のBlockbench正本、アニメーション、CI設定は変更しない。Blender 4.5 LTSのインストール済み環境を想定する。

## モデリングの必須制作経路（2026-11-25 ユーザー指示）
- SERAの新規3Dモデル制作・造形改修・設定画準拠モデル制作は、GitHub Actions上のモデスタ（`tools/modeling_studio/`、`.github/workflows/modeling_studio_render.yml`）とBlenderを標準かつ必須の制作経路とする。開始時に最新の制作手順と対象設計を確認する。
- ローカルPython等は設定画の解析・マスク作成・数値計算・設計データ作成・成果物の検査などの補助に使用できるが、Blender未導入を理由にローカル直接メッシュ生成へ独断で置き換えない。
- 専用Actionsを実行し、BLEND/GLB・実レンダリング画像・検査報告を取得して評価し、必要な修正を反復する。設計コードのマージのみでモデル制作完了としない。成果物の未取得・未評価・未確認事項を明示する。
- 接続障害・配布元障害・実行不可の場合は、再検索・再試行・復旧を優先し、原因と対処・再発予防を台帳に記録する。代替制作経路の使用はユーザーの明示許可を得る。
- 既存ゲームの無関係なCI・テスト禁止およびAI画像生成禁止は維持する。ゲーム内統合時は既存階層、アニメーション、描画方式との互換性を確認し、モデル制作完了とゲーム内反映完了を区別する。

## 制作

リポジトリルートから実行。出力先は既存ファイルの破壊を防ぐため、新規ディレクトリを指定する（Godotプロジェクト外を推奨）。

```sh
blender --background --factory-startup --python-exit-code 1 --python tools/modeling_studio/build.py -- tools/modeling_studio/example.json /tmp/sera-model-v1
```

2026-11-25のユーザー指示により、モデリングに必要な制作・実行・専用Actions・検査・反復改善を許可する。無関係なゲームCI・テストは禁止のまま。V1の実際の生成・レンダリング結果はまだ未確認。

## 入力

- format: SERA_MODELING_STUDIO_V1
- materials: 名前→rgb（線形RGB 0〜1）、metallic、roughness
- parts: 名前が一意なノードの配列。親は子より先に定義する。
- shape: pivot / box / prism / loft / cylinder / tube / mesh
- box: size、prism: profile（XY座標の輪郭）、depth、loft: rings（対応点順のXYZ断面列）、cylinder: radius/depth/sides、tube: path/radius/sides、mesh: vertices/faces（0始まり）
- 各部品: material、location、rotation_deg、parent、bevel、bevel_segments、weighted_normals、uv、cuts
- cuts: 部品ローカル座標の切削形状。operation は DIFFERENCE（既定）/ UNION / INTERSECT。
- 単位はm、Z上、正面-Y。GLBはY上へ変換。既存Godotモデルに接続する前に軸・原点・名前を確認する。
- loftの断面は同じ頂点数で対応順をそろえ、自己交差させない。tubeは急な折返し・過大半径を避ける。
- UVは部品単位のSmart Projectによる初期値。テクスタへの受け渡し・全体アトラス・ピクセル精度は未実装。

## 出力

model.blend（編集元）、model.glb（ゲーム向け形状・階層、アニメーションなし）、mesh_report.json（頂点、三角形、非多様体辺、ゼロ面積、符号付き体積の情報）、8方向の透過PNG、complete.json（すべての生成工程終了時に出力）。途中で失敗した出力ディレクトリは成功扱いしない。レポートは制作情報であり、テスト結果や貫通検査の代わりではない。

## ChatGPTの制作手順

1. 設定画と既存モデルの原点・可動部を参照し、主要比率を決定する。
2. JSONで主要形状を設計する。細部より輪郭・空洞・主要面を優先。
3. 制作環境でCLIを実行し、8方向画像を取得する。正投影・同一スケールで比較。設定画の視点が異なる場合は別途合わせる。
4. 比率・断面・部位位置を修正し、新しい出力先で再生成する。
5. 形状が確定してから面取り・細部・材質を追加。出力レポートを参照し、必要なら形状やセグメント数を調整する。
6. GLBは既存ゲームの原本やモデルを自動置換しない。ゲームへの統合は別作業。

## 未実装

ChatGPT側での画像回収の実証、設定画の自動輪郭抽出・IoU比較、CAD連携、テクスタ等との自動連携、LOD・ノーマルマップベイク、アニメーション移植、既存モデル更新。V1はこれらに先立つ制作基盤。

## 技術資料

- Blender 4.5 LTS CLI: https://docs.blender.org/manual/en/4.5/advanced/command_line/arguments.html
- glTF API: https://docs.blender.org/api/current/bpy.ops.export_scene.html

## GitHub Actions制作経路 V2

- `.github/workflows/modeling_studio_render.yml` はモデル制作専用。手動実行または同一リポジトリの feat/modeling-studio-* / modeling/* ブランチの関連PRだけで実行。既存CIは変更しない。
- Blender 4.5.3を公式配布元から取得し、配布チェックサム照合後、CPUで8方向描画。初回PRではexample.json、別設計は手動入力で指定する。
- Artifactsの sera-modeling-review にBLEND、GLB、8画像、contact_sheet.jpg、review.json、元設計を保存。失敗時はpartialの可能性がある。画像合格を自動判定しない。
- ChatGPTはPRのhead SHAから該当制作runのみを探し、run IDでartifact一覧を取得し、ZIPをダウンロードする。実ファイルが取得できたときのみ画像確認済みとする。コネクタのZIP取得後の展開・画像認識は実行結果で確かめる。

## V3 設定画比較

独立した正投影の設定画を透過PNG（mode: alpha）または白前景・黒背景の分離済みマスク（mode: white）にし、同じディレクトリにJSONマニフェストを置く。写真・透視図・角度不明画像はこの方式で評価しない。自動背景分離は未対応。

```json
{"format":"SERA_REFERENCE_REVIEW_V1","views":{"front":{"mask":"front_mask.png","mode":"alpha","projection":"orthographic","alignment":"bbox","landmarks":{"indicator_center":[384,380]}}}}
```

数値は形式説明用であり実設定画の測定値ではない。design側の landmarks は名前ごとに node と local XYZを記述する。固定比較では同じ画角・位置・画像寸法の画像を使う。bbox比較は平行移動・等方拡縮を除いて比較するため絶対寸法の評価ではない。赤＝不足、青＝過剰、白＝一致。誤差は参照bbox対角長で正規化。特徴点の可視性は設定画側で判断して登録する。

Actions手動起動時に reference_manifest を指定するか、成果物を展開して `python tools/modeling_studio/reference_review.py <render_dir> <manifest.json> <new_output_dir>` を実行する。Pillowが必要。projections.json に全方向の投影座標が含まれる。自動合否判定なし。実設定画を入手するまでは再現性未評価。

## V4 背景分離・撮影条件調整

- 既存のalpha/whiteに加え、mode: uniform_background と background_tolerance（既定20）を使用可能。画像四辺がほぼ均一の場合のみ境界連結した近似色領域を除去する。内部の同色ディテールは保持する。複雑な背景、接地影、輪郭に触れる同色部位には手動マスクを使用する。抽出結果のPNGを出力し、目視確認必須とする。
- 設計JSONの review_cameras に8方向の既存名をキーとして、direction（対象からカメラへのXYZ方向）、target（注視点XYZ）、ortho_scale（正投影幅）、roll_degrees を個別指定できる。省略時は従来値。projections.jsonに撮影位置・回転・注視点を保存する。カメラはまだ自動推定しない。
- 公式配布のHTTP 403対策として公式ミラーを予備経路とし、各経路でSHA256を照合する。Blender導入前に比較演算の独立チェックを行う。既存ゲームCIは変更しない。

## V5 カメラ推定・部品干渉候補

- design JSONの camera_fits に既存ビュー名をキーとして {"projection":"orthographic","resolution":768,"landmarks":{"点名":[x,y], ...}} を指定する。既存 landmarks の対応する3D座標を使う。最低4点かつ非共面、同じ正方形画像寸法が必要。手動カメラ指定と同じビューには併用不可。SVDで正投影の向き・倍率・画面内移動を推定し camera_fit.json に残差を保存。奥行き位置は正投影から決まらない。透視図、誤対応、平面点、隠れた点には注意。自動特徴点認識や合否判定ではない。
- interference.json は静止姿勢で世界座標AABBとBlender BVHによる表面交差候補、AABB包含候補を記録する。接触と貫通を厳密に区別しない。自己交差、可動範囲、貫通体積は未評価。intentional_overlaps に {"parts":["部品A","部品B"],"reason":"理由"} を指定すると意図的な接合として区別し、候補自体は削除しない。
- 専用Actionsで既知カメラの投影再現・平面点の拒否・交差/包含/離隔ケースを独立確認する。
- API: https://docs.blender.org/api/current/mathutils.bvhtree.html

## V6 可動範囲・軽量化・Godot検査

- motion_sweeps: [{"node":"hinge","axis":[0,0,1],"degrees":[-45,45],"samples":7}] のように明示したpivotのローカル軸で離散姿勢を検査する。元の姿勢に復帰する。複数関節の同時運動・連続衝突・正確な貫通体積は未対応。
- lod: {"shaft":{"ratio":0.6,"max_bounds_error":0.03}} のように選択した部品だけDecimate Collapseを適用した別GLBを生成。三角形削減、境界箱の変化、非多様体・ゼロ面積・UV層数を確認し不適合部品を元に戻す。元BLEND/GLBは保持。輪郭・UV・陰影の品質は別途目視確認が必要。自動LOD切替は行わない。
- 専用ActionsでGodot 4.7.2の独立プロジェクトを使い、GLTFDocumentで元GLBと軽量版GLBの読み込み・シーン生成・メッシュ/三角形/階層情報を記録する。ゲーム本体の描画やAndroid性能を保証するものではない。
- 成果物: motion_review.json、lod_report.json、model_lod.glb（LOD指定時）、godot_import.json。

## V7 現行CRATEの比較基準

専用Actionsのcrate_baselineを有効化、またはmodeling/crate-baseline-*のPRを作成すると、現行のscripts/sera_crate_model.gdを独立Godotにコピーしcreate_model()を実行、材質・階層を含むGLBへ書き出す。Blenderへ読み込み、元三角形数と一致することを確認し、編集用BLENDと8方向画像、一覧画像、メッシュ情報、ソースコミット/ブロブをcrate_baselineフォルダに保存する。Blenderレビュー用にZ軸180度回転するが、元のGodot出力GLBは変更しない。既存ゲームのモデル・モーション・シェーダーは変更しない。ゲームの枠線や実機描画、設定画一致はこの基準画像では保証しない。材質バッチのメッシュは独立した機械部品とは限らず、法線分割を含む非多様体数の評価には注意する。

## CRATE 比率候補 V1

modeling/crate-baseline-proportion-*のPRでは現行モデルの基準BLENDから独立した候補を作り、頭/胴/履帯/腕（手を含む）の各グループを三面図に合わせて幅・高さ・奥行きと位置を調整する。既存ノード名・親子関係・三角形数を保持するが、グループ変形により関節位置と倍率が変わるため既存アニメーションへの接続は未保証。比較用BLEND/GLB/8方向画像/一覧/変換情報をcrate_candidateに出力する。設定画はユーザーのライブラリにある2026-11-25 JSTの三面図を使用。簡易投影による候補IoU推定は実レンダリングの評価値ではない。ゲーム本体には反映しない。

## CRATE 局所造形候補 V2

最新三面図に合わせ、V1比率に加えてバイザー・アンテナ・胸部・背面カートリッジ・履帯・爪・腕装甲の局所形状を調整する。元GDScriptは変更せず、厳密な23個の文字列アンカーで検査用コピーを生成し、別GLB/BLEND/8方向画像に出力。V1も同時に生成する。V2のGLBはゲームの前方-Zへ戻す。以前の簡易IoU推定は引き継がない。
5関節の各4姿勢をBlender BVHで検査し、ニュートラルにない部位間交差候補を記録。Godot 4.7.2で実候補GLBを読込、ピボット階層・回転と復元・三角形数の一致を検査する。非等方スケールとWristPivotの名前変化は記録し、ゲームのモーション互換性や接触/貫通の合否は別途判断する。現行モデル・ゲームCIは変更しない。
参考: https://docs.blender.org/manual/en/5.1/modeling/modifiers/generate/bevel.html / https://docs.godotengine.org/en/stable/tutorials/3d/using_transforms.html / https://docs.godotengine.org/en/latest/classes/class_gltfdocument.html

## 候補間の実レンダリング比較

現行CRATEと比率候補・局所造形候補を同じ制作runで出力した場合、review_bundle.pyは各8方向の透過レンダリングをアルファ128で二値化し、bbox等方正規化後のIoU・不足/過剰画素・縦横比と重ね合わせ画像を candidate_comparison/ に生成する。赤は現行のみ、青は候補のみ、白は共通。comparison.json に方向別数値、平均、最も差が大きい方向を記録。候補は同名のカメラ方向を前提とする。これは現行からの変化量であり、設定画への一致度や改善の合否ではない。絶対寸法・位置・材質・可動互換は別途確認する。成果物ハッシュは1MiBずつ読み込んで計算する。比較画像もreview.jsonのハッシュ対象とする。
参考: https://pillow.readthedocs.io/en/stable/reference/ImageChops.html / https://docs.blender.org/manual/en/4.5/render/cameras.html

## 多方向輪郭・構造線先行モデリング V1
shape: wireframe を部品に指定。wireframe_example.json が動作確認用の合成四面図座標例（クレート実設定画ではない）。既存shapeと混用可。
- wireframe.views: front/back/right/left の origin_px（部品ローカル原点の画像座標）、px_per_m、任意の正の weight。画像Yは下向き、水平軸は正面+X・背面-X・右+Y・左-Y。単位m。部品ローカルの正投影で校正し、回転・透視のある資料は事前に補正する。
- wireframe.points: 対応する頂点IDごとに観測できるビュー名と[x,y]ピクセル座標を記述。幅と奥行きを拘束する最低2方向が必要。背面や左面のない三面図でも可。隠れた点は推測値と実観測を混同しない。
- 加重最小二乗でXYZを復元し各観測への再投影誤差が max_error_px（既定3）を超えれば拒否。対応点の自動認識はしない。
- strips: [{rings:[[頂点ID...],[頂点ID...]],cap_start:true,cap_end:true}]。同一対応順の閉ループを接続。faces に明示面を追加可能。lines に外周・装甲境界などの連続頂点IDを指定し、実エッジとして存在することを確認。閉じた2面共有エッジ、重複面・潰れ辺を検査し、Blenderで辺のみのメッシュから面を生成、法線再計算、面取り・UV・既存レンダリングへ接続。
- wireframe_guides.obj は仕上げ前のワールド座標線のみ、wireframe_guides.json は部品ローカルXYZ、各方向の観測・再投影・誤差、辺・面を記録。両方を成果物ハッシュに追加。OBJの線はGLB本体に混入しない。
- 自動輪郭抽出・対応点同定・凹部推定・自己交差の完全検出・画像GUIは未実装。実設定画への再現性は別途測定する。輪郭だけでは凹部が決定できないため内部構造線を明示する。
参考: https://docs.blender.org/manual/en/4.5/modeling/meshes/editing/edge/bridge_edge_loops.html / https://homepages.inf.ed.ac.uk/rbf/CVonline/LOCAL_COPIES/MANESSIS/liter/node7.html

## 輪郭線先行 V2：平面拘束・矛盾管理・投影確認
- planes: [{"axis":"z","points":["a","b","c"]}] で指定頂点が共有する軸座標を加重最小二乗で同時に解く。複数グループの推移的共有に対応。任意方向の平面ではない。fixed: {"a":{"y":0.12}} で隠れ点などの明示設計値を拘束する。観測不足を無断で補完しない。
- ビューごとに weight と max_error_px を設定。低信頼ビューの重みを下げられるが観測残差は別々に記録・上限検査。固定値・共有平面の矛盾を拒否し、xyzごとの由来を記録する。
- 各面のNewell法による代表平面からの最大ずれをm単位で記録し、max_face_warp_m を指定した場合は超過面を拒否する。任意の曲面や自己交差の完全検出ではない。
- silhouettes: {"front":{"outline":[[u,v],...],"min_iou":0.97}} に外周ポリゴンを独立に入力。仕上げ前の投影面の和集合を共通座標でラスタ比較し、輪郭IoU・不足/過剰画素・目標達成状態を記録。目標未達は診断であり自動修正・合格ではない。
- wireframe_projection/ に各部品・方向の線重ね合わせ画像とreport.jsonを出力。シアンは復元線、橙は観測点同士の接続、マゼンタは点残差、白/赤/青は投影輪郭の一致/不足/過剰。隠れ線消去・透視補正・実レンダリング評価とは別。すべて成果物ハッシュに追加。
- wireframe_example.json は意図的に3pxの設定画矛盾と隠れ頂点を持つ合成資料。クレート設定画・ゲーム本体には未適用。
参考: https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.lsq_linear.html / https://docs.blender.org/manual/en/4.5/modeling/meshes/structure.html

## 汎用ハードサーフェス制作パイプライン V1（2026-11-25）
正式方針: 部品分解→外周/内部構造線の意味付け→部品別レシピ→正投影・斜め投影→段階評価→局所修正。クレート限定にしない。
- hard_surface.level (1..5) で比率・基本装甲・凹凸/関節・細部・材質/発光の段階を指定。各partのlevelで登場段階、refinementsの段階別辞書で既存部品の形状/面取り/切り抜き/材質等を更新。名前・親・関節階層は固定。省略したランドマークを用いるカメラfitは拒否。motion_sweepsは段階別の入力が必要。
- role と method で部品構造と造形方法を明示。outline=wireframe、section=loft、solid=box、extrusion=prism、joint=cylinder、revolution=revolve（非ゼロ半径の閉断面）、variable_section=sweep（pathとsectionsの楕円半径ペア）、repeat=repeat_path（xy/yzの閉じた折線を等弧長間隔でブロック配置）、explicit=mesh、fixed_tube=tube、pivot=pivot。既存shapeと共存。履帯の角部干渉は別途確認。
- lines のkind: silhouette/panel_boundary/chamfer/recess/circular/curve/scratch/pattern/shadow/unknown。処理先の記録（形状、分割、面取り、切削、回転体、掃引、テクスチャ、無視、要確認）。自動意味認識・線からの直接造形・傷のテクスチャベイクではない。
- reference_lines.py image.png mask.png output_directory は OpenCV の輪郭抽出・近似、Canny/Houghで候補線を出す独立CLI。別途 opencv-python-headless が必要。マスクは独立作成の前景二値画像、内部線はunknownとする。斜め図の透視補正・遮蔽・意味分類・多方向対応は人またはChatGPTが明示する。
- dimension_fit はboxのx/y/z・cylinderのdiameter/depthだけに適用できる局所パラメータ調整。target_mとbounds_mを指定し、許容範囲内で最も近い値を採用、前後誤差を記録。実レンダリング最適化ではない。
- part_targets: 部品名→ビュー→{resolution,bounds_px,min_iou}。実Blender仕上げ済みメッシュの各頂点を実レンダリングカメラで投影、矩形IoU・各辺誤差・修正優先順位を出す。遮蔽前の全頂点範囲で、シルエットや線・材質一致率とは区別。45度方向にはfront_3qを使い、review_cameras / camera_fitsで視点を固定・推定する。独立した参照目標と同じ姿勢・投影が必要。
- hard_surface_plan.json / compiled_design.json / hard_surface_review.json を成果物に追加。hard_surface_example.jsonは合成の機械部品組立例、クレートではない。外周25・内部線25・配置20・斜め20・材質10の総合評価は独立した各評価が揃うまで算出しない。品質/可動/負荷の採否は別途。
- 未実装: 自動部品分割・線の意味認識・多方向対応付け・輪郭/構造線/材質の自動反復最適化・実機負荷計測。既存LOD・メッシュ/関節検査と連携し、未計測項目を合格扱いしない。
参考: https://studio.blender.org/tools/pipeline-overview/asset-creation/modeling / https://docs.opencv.org/4.x/df/d0d/tutorial_find_contours.html / https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html

## 設定画解析 V1：部品領域と構造線候補
- OpenCV 4.12.0.88 のオフラインCLI: python structure_analysis.py image.png mask.png output_directory --clusters 8 --min-area 40
- 画像は1方向にクロップした資料、maskは独立前景マスク(128以上を前景)。bilateralFilterとLabの色クラスタリング、連結成分で領域候補を抽出。小領域は無断統合せず未割当に記録。labels.png は16bitの領域IDマップ、regions.png は目視用。実部品の確定ではない。
- 隣接領域グラフを4近傍から作り、接触画素数・平均Lab色差を記録。マスク外周/穴、円形候補、Canny/Hough線分の両側に異なる領域がある割合と境界強度で装甲境界候補を抽出。その他はunknown。信頼度は根拠指標であり正解確率ではない。影や塗装境界も候補になり得る。凹凸・関節・影・傷の意味は自動確定しない。
- structure.json / labels.png / regions.png / structures.png / internal_edges.png を出力。全候補geometry_approved=false、実部品IDや意味は未確定。
- structure_handoff.py structure.json selection.json design.json output.json は {view:"front",lines:[{id:"segment_0",part:"Armor",kind:"panel_boundary",approved:true,reason:"..." }]} の明示レビューを検査し、hard_surface.linesに転記可能な配列を別ファイルへ出力。元設計やメッシュを自動変更しない。既存の手入力設計も継続可。
- modeling/structure-analysis-* の専用制作では合成機械モデルの実Blender正面・右・背面・斜め画像とα由来マスクから解析し、成果物ハッシュに追加。実設定画の部品分割精度や分類精度は独立正解ラベルで別途確認が必要。ゲーム本体・CIは変更しない。
参考: https://docs.opencv.org/4.x/d2/dbd/tutorial_distance_transform.html / https://scikit-image.org/docs/stable/auto_examples/segmentation/plot_rag_merge.html

## 設定画解析 V2：過剰分割抑制・円楕円弧・正解ラベル評価
- structure_analysis_v2.py image.png mask.png v1_directory output_directory でV1の候補を保持したまま比較可能。4近傍接触が6px以上、境界Lab差9以下、統合グループ全体の色度範囲12以下、明度範囲48以下の候補のみ弱い境界から統合。円形領域候補は保護。数値は初期経験則であり一般的な部品判定閾値ではない。未割当画素は埋めない。
- Cannyエッジ輪郭をfitEllipseで近似し、正規化半径誤差、軸比、実エッジ2px以内の支持率で候補を絞る。支持率48%以上で候補、85%以上かつ軸比85%以上で円、85%以上で楕円、それ以外は円弧候補。支持のない線は出力せず、支持された連続線分だけ保持。中心・径・角度は推定値。遮蔽や影・傷由来の誤認識は残り得る。
- structure_metrics.py output_directory は既知の3部品ラベルと照明勾配を持つ合成評価図でV1/V2を比較。任意の独立16bitラベルマップは structure_metrics.py evaluation.json --truth truth.png --prediction labels.png で評価。ペア適合率（誤統合）、ペア再現率（過分割・未割当）、F1、部品別best IoU、背景誤検出を出力。best IoUは1対1対応ではない。実設定画の正解ラベルは別途必要。
- 専用制作経路で正面/右/背面/斜めの実Blender画像についてV1/V2を同一入力で比較し、合成正解ラベル評価も成果物に含める。全候補は未承認のまま。V2も明示レビューhandoffに対応。ゲームモデルは変更しない。
参考: https://docs.opencv.org/4.x/d3/dc0/group__imgproc__shape.html / https://scikit-image.org/docs/stable/auto_examples/segmentation/plot_metrics.html

## 設定画解析 V3：実モデル部品IDと保護付き閾値探索
- part_id_review.py は保存済みmodel.blendの実メッシュからBVHを構築し、projections.jsonの正投影カメラの各画素中心光線で最前面オブジェクトIDを求める。正面・右・背面・斜めの独立正解マスクとID対応表を出力。アンチエイリアスや透過は再現せず、メッシュ単位を正解とする。
- structure_calibration.py は実レンダリングのαマスクとIDマスクのIoUが0.97以上であることを確認。正面・右のみでV2既定値を含む17候補を探索し、適合率・部品IoU・F1の悪化許容範囲を制限して選択。背面と斜めは選択後に評価。結果は同一モデル内の別視点であり別モデルへの汎化評価ではない。
- 選択値・全候補の比較・V1/V2/候補の実モデル評価・ID画像・領域画像・曲線候補を出力。V1円候補を保持するが機械的意味は未承認。ホールドアウト悪化時はV2既定値維持と記録。既定値は自動変更しない。反復構造の認識は未実装。
- modeling/structure-analysis-v3-* の専用制作経路で実行し、既存成果物ハッシュに含める。Android実機負荷・クレート設定画への適用は別途。
参考: https://docs.blender.org/api/current/mathutils.bvhtree.html / https://scikit-image.org/docs/stable/auto_examples/segmentation/plot_metrics.html

## V4：反復構造候補・デザイン意図優先
- 設定画は正解CADではない。明示仕様・機能、識別特徴、意図、立体の見栄え・機構整合を優先し、寸法や図面間の一致は参考とする。見えない箇所は作者判断で補完し、その根拠を記録する。厳密図面の再提出を前提にしない。
- repeat_recognition.py はV3の候補領域から色・サイズ・面積・中心点間隔の近い3個以上の連続直線列を抽出。離れた領域も同じ機構の候補にできる。元のマップは保持し、別の仮グループマップを作る。空白を埋めず、重複グループは除外する。曲線・不規則な繰返し・透視・遮蔽・意味認識は未解決。
- repeat_review.py は実メッシュIDに対する各部品best IoUの悪化（1ポイント超）とペア適合率/F1悪化を検査。全方向の保護条件と少なくとも一方向の部品平均IoU改善を満たした場合のみレビュー候補とする。真値は候補生成に使用しない。V3既定値や形状は自動変更しない。
- box/cylinderの既存dimension_fitに任意のobservationsを指定可能。target_mを造形意図としてreason、intent_weight、tolerance_mを記述し、各参考値はsource/value_m/weight(0..1)/任意tolerance_mで指定。明示bounds_mは厳守。Huber損失で外れた参考値の影響を制限し、意図の二次損失と合算した凸目的を二分法で解く。各観測の残差と外れ値フラグ、意図の根拠、目的値を記録。従来設定は動作不変。
- modeling/structure-analysis-v4-* の専用制作でV3の実モデル評価に反復候補の比較と合成矛盾寸法のコンパイル評価を追加する。審美的完成度や意図の自動推定を数値で保証する機能ではない。独立モデル、実設定画、曲線反復、多方向対応は次段階。
参考: https://docs.opencv.org/3.4.6/d9/d61/tutorial_py_morphological_ops.html / https://docs.scipy.org/doc/scipy/reference/generated/scipy.special.huber.html

## V5：多方向部品対応・曲線反復候補
- multiview_parts.py: 校正済み正投影の2カメラの視線に直交する共有軸へ領域画素を投影し、位置区間、色度、明度、見かけ面積を柔らかい手掛かりとして候補を比較する。相互最良・次点との余裕・コスト上限を満たす場合のみ強い候補。平行/対向視点はこの方法の直接比較対象外。同じ視点内の重複や複数方向で支持されない連鎖を拒否する。欠落視点を残す。中心点の光線最小二乗は概算位置仮説であり真の対応頂点ではない。実設定画のカメラ校正や視点間の姿勢差は別途推定が必要。
- curved_repeats.py: 色、面積、サイズが近い領域について近似等間隔で緩やかに曲がる4個以上の列を候補化。折返し・ジグザグを抑制し、端点間隔と接線方向、累積回転から閉ループ候補を区別する。128領域・32要素の上限。真の履帯曲線や機構の確定はしない。
- multiview_review.py: V4の保護条件を満たしたマップ（満たさなければV3候補）を固定入力にし、曲線グループ別の部品IoUと保護判定を出す。対応候補は曲線処理前の固定入力から生成し、後で独立部品IDに対する優勢IDの一致を評価（純度70%以上、曖昧は別集計）。一致率は未対応領域を除くため再現率ではない。合成12個の円列fixtureも報告。すべて候補であり形状自動変更なし。
- modeling/structure-analysis-v5-* 専用制作に追加。正確でない設定画は設計意図の参考資料として柔らかく扱い、無理に対応させず作者判断で補完する。CRATE資料適用、意味推定・レシピ自動選択・実モデル造形は後続。
参考: https://docs.opencv.org/4.x/da/de9/tutorial_py_epipolar_geometry.html / https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.linear_sum_assignment.html

## V6：機構設計グラフと意図に基づく補完
- mechanism.nodes は部品名・role・親子・親ローカル位置・形状パラメータ・reason・provenance・evidenceを記述。referenceは資料由来の特徴であり寸法の正解ではない。inferredは作者の補完、explicitは明示仕様。画像由来の候補領域は直接自動確定しない。
- roleと利用可能な形状パラメータから既存のwireframe/loft/box/cylinder/revolve/sweep/repeat/pivotレシピを決定する。methodによる明示上書きも互換性を検査。親の欠落や循環は拒否。従来parts方式とは排他で既存設計は変更しない。
- mirror_xは指定部品を親ローカルXで反転し、親も指定されていれば反対側の親に接続。共有親は中心・軸整列が必要。box/cylinder/revolve/YZ repeat/pivot/sweepのみ対応、切削・段階refinementの反転は拒否。形状や役割の自動認識ではなく作者が対称関係を判断する。
- pivotのjointはrevolute、axis_local、range_deg。対称部品の軸は軸性ベクトルとして反転。joint_review_samplesを指定すると既存の離散姿勢干渉レビューを生成する。実行時関節制約・連続衝突検出ではない。
- mechanism_graph.jsonに選択レシピ候補、推定/参照の由来、親子・軸、反転元、造形理由を出力して成果物ハッシュへ追加。
- mechanism_crate_study.json は2026-11-25のユーザー提供CRATE回転図面から作者が共通特徴を読み取った独立した機構造形例。広い頭部、青色ライン、側面円形ユニット、二本アンテナ、三本爪、左右履帯、背面収納を参照し、内部フレーム・関節位置/範囲・寸法を推定。設定画の画像認識結果からの自動変換ではない。既存ゲーム内CRATEや確定デザインを置換しない。
- modeling/structure-analysis-v6-* 専用制作でこの例をレンダリング、GLB/Godot読込、干渉候補、V1/V2画像解析を出力する。見栄え、可動、描画負荷の採否は実成果物レビュー後。複数領域の機構単位への自動統合・未知機構の意味推定・参考図の自動対応は残課題。
参考: https://studio.blender.org/tools/pipeline-overview/asset-creation/modeling / https://docs.blender.org/manual/en/4.5/modeling/modifiers/generate/mirror.html

## V7：外形先行ブロックアウト
- crate_blockout_v7.json は参考図の正面・右側面を共通の接地線と高さで手動トレースし、主要断面と側面輪郭を直接立体化した独立試作。細部や可動機構の詳細化より外形を優先する。
- blockout_review.py は正面・右側面の実レンダーを固定カメラ・共通スケールで参考輪郭と比較し、IoU、外接矩形、欠落/過剰領域の画像を記録する。参考線は作者の概略トレースであり、精密CADや独立した正解ではない。数値のみで造形を承認しない。45度は実画像の目視確認を必要とする。
- 既存ゲーム内クレートは変更しない。現段階では主要形状の確認が目的であり、詳細な履帯片・関節可動・テクスチャは後工程。形状不合格の場合は詳細化しない。

## V8：外形を維持した機械造形
- crate_blockout_v8.json はV7を保持した独立候補。アンテナ支持軸・頭部の実切削バイザー・多断面腕・三本爪の先端・連続ベルトと閉経路反復の履帯片・転輪ハブ・収納部を改良。既存の造形レシピを使用。
- V7と同じ正面/右カメラ・概略トレースを維持。IoU差分と暫定下限（正面0.87、右0.92）を報告する。下限は作者判断であり合格保証ではない。形状と斜め方向の目視・接続・干渉は独立評価。可動とゲーム置換は保留。
- 参考: https://studio.blender.org/tools/pipeline-overview/asset-creation/modeling

## CRATE V9：機構分解・可動階層
- V8を保持した独立候補。肩固定台と軸、上腕内部リンクと外装、肘固定フォーク・軸受・軸・カバー、前腕側回転ハブとフレーム・外装、手首固定軸受と回転軸・ハンド基部、三本の独立爪とパッドを分離。中立姿勢の親ローカル座標を使用。首旋回/傾斜・アンテナヒンジも追加。履帯と背面収納はV8維持。
- joint_checks はnode/axis/range_deg/probe_deg/fixed/movingを指定。実Blenderの各代表メッシュの親子所属、固定側行列不変、回転側の期待行列との差、軸中心の移動を確認しjoint_hierarchy_review.jsonに記録。失敗時は制作を停止する。既存motion_sweepsによる離散干渉候補とは別。関節範囲は設定画から確定できないため作者推定で、ゲーム内制約を自動設定しない。
- V8の固定カメラ・参考輪郭で外形比較。前面発光の位置と切削深さも変更した。見栄え・物理干渉・実機負荷は成果物確認後に判定。ゲーム内CRATEは未置換。
参考: https://docs.blender.org/manual/en/4.0/scene_layout/object/editing/parent.html / https://docs.blender.org/manual/ja/4.5/modeling/modifiers/generate/booleans.html

## CRATE V10：関節とバイザーの是正
- V9実GLB正面光線でHeadの前面がLightBarより手前に残ることを確認。切削を廃止し、頭部外周と開口、傾斜縁、凹部壁、奥面を連続した閉メッシュで構築。発光ラインと黒背景を開口内に配置。
- visibility_checks は実組立メッシュに光線を当てて最前面が指定部品か確認する。正面・斜めの各3点を記録し、失敗も成果物に残す。有限点の幾何検査であり色・発光・全角度の合格ではない。
- 肩/肘の軸受と固定フォークを小型化し、外装の端を短縮、内部リンクと手首ハブを調整。16関節の階層と範囲は維持。外観・干渉は実成果物で別確認、ゲーム本体未置換。

## 10回反復制作（CRATE V10 起点）
- Modeling Studio - authoring render の workflow_dispatch で iteration_mode=true を選択、または modeling/crate-blockout-loop-* のPRから開始。ゲームCIとは独立。基準V10を通常の制作経路で生成してから10候補を順に制作する。
- 各回は現在の数値上の最良候補を起点に、肩/肘/手首/爪/首/発光部等の10種類の事前定義された形状仮説から未試行のものを選ぶ。実干渉候補の関節別件数で試行順を調整。失敗や悪化時は前候補を維持し次へ進む。関節範囲を縮めず、干渉を許可リストに追加しない。
- 各候補で実Blenderメッシュ、8方向レンダー、実GLB、16関節の階層検査、離散姿勢干渉候補、輪郭、露出、HTMLを生成。輪郭・三角形数・トポロジー・可視性・階層・干渉候補の悪化を保護。干渉候補は物理衝突の確定ではない。全候補を保存し、数値上の選択結果をbest_viewer.html/best_model.glbに複製。外観の採否は別途実画像を人間/ChatGPTが確認する。候補ごとのGodot読込は未実装（基準のみ既存経路）。
- 失敗回も設計・ログ・失敗理由を残す。10回は試行数であり10成功を保証しない。各Blender試行は最大480秒、ジョブ上限120分。全成果物は14日間のActions artifactに保存。既存ゲームモデルを置換しない。
- offline_viewer.pyは実GLBと8枚の実画像を埋め込む。WebGL2非対応時は実画像切替。表示用簡易照明。関節操作は検証用で干渉未承認。

## 10回反復制作 V2：部品単位の造形変更
- iteration_mode=true / structural_mode=true、または modeling/crate-blockout-loop-v2-* で選択。前回採用された4変更をV10から再現して基準を作成する。structural_mode=falseで旧方式。
- 実穴付き軸受/回転ハブ、固定フォークの掃引、リンク軸に沿う可変断面装甲、曲がった三本爪、手首/肩の環状部品、別の前腕断面、接触パッド等10レシピを試す。形状変更は作者が定めた仮説、未知の形状の自動理解ではない。
- 関節ごとにその子孫と非子孫の間に発生する表面干渉候補を数え、同じ剛体階層内で一緒に動く部品同士の候補を別扱いにする。中立姿勢にない候補の増加、関節別悪化、輪郭・可視性・階層・トポロジー・ポリゴン上限を検査。元の全干渉候補数も保存し、許可リスト追加や可動範囲縮小はしない。これは実衝突の確定や意図接合の認定ではない。
- 実45度画像の前回/基準との画素変化率、全試行の比較シート comparison_45.jpg を保存。画素変化は外観変化の有無を示すだけで審美品質ではない。数値で不採用になったモデルも保存し、実画像による作者の選択に残す。
- 三角形上限は基準+18%、輪郭下限は正面0.87/右0.92、基準から最大1.8ポイント低下まで。これは本試行の暫定値であり正式採用条件ではない。既存ゲームモデルを変更しない。

## 10回反復制作 V3：部位別の形状比較と面構成
- iteration_mode=true / structural_mode=true / reference_design_mode=true、または modeling/crate-blockout-loop-v3-* で選択。前回の採用4+6変更を再現して基準を作る。V2以前の方式も選択可能。
- 頭部・胸部（背面収納を含む）・腕・履帯を実メッシュIDから分類。既存の概略手動トレースを同じ4グループに分け、正面と右面の固定カメラで可視部IoUを比較。複数グループが重なる参考画素は評価から除外し、赤/青/白の差分を出力。参考トレースは実設定画の近似であり、正確なCAD・真の部品領域ではない。対象形状の意味は作者が指定し、機械学習による自動認識ではない。
- 部位別評価の低いグループから未試行レシピを優先。三本爪の断面、爪先、肘フォーク、頭頂面、頭部側面、胸部主装甲・上装甲、二列履帯片、側面ハブ、背面収納を試す。装甲は既存四角面に連続したリム・凹部・床面を構築し、別体のインサートを配置。凹部と部品の接続は実画像・メッシュで別評価する。
- V2の関節跨ぎ候補・可視性・階層・全体輪郭・ポリゴン保護に加え、部位別IoUの悪化を基準比3.5ポイント/直前比2ポイント以内に制限。これらは試行用の作者判断。数値優位候補に加え、ガード合格で平均部位IoUの低下0.1ポイント以内の装甲/履帯等の作者提案を探索候補として引き継ぐ。これは審美的承認ではない。既存ゲームCRATEは未置換。
- 調査資料: Blender Studio Modeling https://studio.blender.org/tools/pipeline-overview/asset-creation/modeling ; Blender Inset Faces https://docs.blender.org/manual/en/5.0/modeling/meshes/editing/face/inset_faces.html ; Bevel Modifier https://docs.blender.org/manual/en/4.0/modeling/modifiers/generate/bevel.html ; gripper mechanism https://www.mdpi.com/2218-6581/11/6/155 ; https://www.mdpi.com/2076-3417/9/24/5266 。研究の機構をそのまま再現せず、関節と外装の分離、輪郭・面構成の段階化を採用する。

## 恒久制作原則：部品単位の実物資料調査
新規・改修モデルは造形前に設定画の意図と部品構成を分解し、各部品の役割に応じたメーカー公式写真、製品図、公開断面・分解図、技術資料を調査する。参考URL、確認できた特徴、採用する構造・形状・材質、原画との矛盾と作者の補完を記録し、メッシュ設計へ対応付ける。資料不足は推定として明示し、設定画のキャラクター性とゲーム性能を優先する。産業機械および軍用機械の汎用機構、非武装車体、整備性を参考にし、実製品の寸法や機構の完全再現を前提としない。資料調査は作者が行い、コードが自動でWeb調査する機能ではない。
## 10回反復制作 V4：外部部品資料に基づく造形
- iteration_mode=true / structural_mode=true / reference_design_mode=true / industrial_design_mode=true、または modeling/crate-blockout-loop-v4-* を選択。V3の採用7変更を再現した基準を使う。
- industrial_design_variants.py の SOURCES に外部資料URL、確認特徴、採用範囲を記録。各候補の design.json に research_sources と research_adaptations を保存し、変更レシピと根拠を追跡可能にする。
- Harmonic Driveの同軸アクチュエーターを肩・肘・手首、ABB公開特許の機構分離を腕、Robotiqの独立指と接触部を爪、Catの転輪・履帯を中空ベルトと支持ローラー、Milrem THeMIS Cargoのモジュール性を収納支持部、Rittalのカバー構造を整備用外装、Baslerの保護筐体をバイザー内周の形状に反映。寸法と形状は作者のフィクション設計で、機械としての実用性は保証しない。
- 10仮説の全候補を保存し、従来の部位別輪郭、関節跨ぎ干渉候補、可視性、階層、トポロジー、ポリゴン上限を維持。外観承認とは分離し、16関節・可動範囲を変えず、既存ゲームモデルを置換しない。

## 恒久制作原則：概形確定後は機構と立体美を優先
- ブロックアウト段階のみ参考輪郭を主要拘束として使う。概形確定後は全体・局所IoUを計測するが、採否条件や順位指標にしない。設定画との差は多方向の実画像で意図と見栄えを確認する。
- V4産業造形モードは外形確定後の工程と定義し、輪郭ガードを除去、機構・可動・トポロジー・発光部露出・三角形数の保護を残す。IoU低下のみで候補を排除しない。V1〜V3は過去比較用の旧方式。
- 腕全体の再設計を最初に試行し、肘の横方向の偏りを減らして手首との連続性を改善する。固定側の軸受・フォーク・軸と回転側を同時に移動し、コアと外装を新しい関節位置から再構築。可動範囲は維持する。配置は架空設計上の仮説であり正解寸法ではない。
- 参考: Blender Studio Modeling https://studio.blender.org/tools/pipeline-overview/asset-creation/modeling 。機械設計資料は前回登録のメーカー資料を継承。数値採用は外観承認ではない。
