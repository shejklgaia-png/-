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
