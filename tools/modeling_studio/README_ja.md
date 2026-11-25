# SERA Modeling Studio（モデスタ） V1

ChatGPTが設計データを編集して機械形状を制作するオフラインCLI。Godotのゲーム実行時には使わない。既存のBlockbench正本、アニメーション、CI設定は変更しない。Blender 4.5 LTSのインストール済み環境を想定する。

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
