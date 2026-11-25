# SERA Motion Lab V1
モーション制作・品質確認の独立基盤。2026-11-25のユーザー許可を根拠に、モーション制作に必要な専用Actions・Blender/Godotの実行・描画・成果物回収・診断・反復改善に限定する。既存ゲームCI・テスト・ゲームファイルは変更しない。実レンダリングは画像生成AIではない。
## 実行
Blender 4.5.3 LTS、Godot 4.7.2、Xvfb、Pillowを使用。専用 workflow の手動実行または同一リポジトリ motion-lab/* PR を使用。ゲーム実行やAndroidを保証しない。
```sh
blender --background --factory-startup --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/example.json /tmp/new-motion-output
```
出力先は未作成ディレクトリ。GLBソースは静的な剛体ノード階層に限定。元モデル・既存アニメーションは変更しない。スキン付きボーン、Blockbench直接変換、IK・衝突解法は次段階。
## 設計
SERA_MOTION_LAB_V1、単位m、Blender Z上、正面-Y、ローカル座標。GLBはY上変換。fpsは30/60。フレーム1開始、各トラック独立、位置・XYZオイラー角（度）、各トラックの初末キー必須。中間キーのBezier自動クランプ。角度は連続な値で設計し、360度折返しは作者が管理。source_glbは設計JSON相対パス。対象名はインポート後の正確な一意名。未対応リグは拒否する。
markersは部位ローカル点、contactsはフレーム範囲と目標点/別マーカー、許容距離。毎フレーム評価。全身貫通・重心・床滑り・姿勢評価を保証しない。
review.target と scale で固定正投影。Godotもreview.target/scaleを読み、Blender Z上からGodot Y上へ変換して斜め固定視点で描画する。
## 出力
motion.blend、motion.glb、motion_report.json、Blender 3視点の複数フレーム、Godot 9枚、godot_review.json、視点別コンタクトシート、ハッシュ一覧。成果物未取得のときは目視確認済みとしない。成功と品質合格を区別する。専用runのhead SHA、artifact ID、結果を台帳に記録。初回は架空の剛体腕による環境制作、ゲームのモーション品質の実証ではない。
## 参考
https://docs.blender.org/manual/en/4.5/advanced/command_line/arguments.html
https://docs.blender.org/manual/en/4.5/addons/import_export/scene_gltf2.html
https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html

## V2: 再現性と品質診断
V1 run 45512877274 は工程成功だが、Godotが肘クリップのみを再生していた。Blender 4.5のSCENE分割既定値を無効化し、開始時刻0、全動的チャンネルを含む単一GLBクリップを必須にする。GLBのJSONを調べ、Godot側も単一クリップ以外を拒否。マーカーを実際のノードとして書き出し、Blender Z上からGodot Y上へ変換した全フレームの世界座標を比較する。既定許容2mm、長さ差0.2ms。マーカー1個以上必須。これは指定点の再現性であり全関節完全一致の保証ではない。各キーのinterpolationはBEZIER/LINEAR/CONSTANT。eventsの名前→フレーム番号、および接触の開始終了フレームを共通撮影時刻に追加。速度・加速度・ジャーク・ループ継ぎ目の有限差分を記録する（自動的な芸術品質合格ではない）。画像と数値を併用する。失敗時はpartial artifactを確認する。
参考: https://docs.blender.org/api/4.5/bpy.ops.export_scene.html

## V3: 正本モデルの読み取りとFPS整合
V2の出力は単一clip・121サンプル・2秒で正しかったがGodot指定点最大13.10mmで不合格。Godot GLTFDocument.generate_scene の既定30fpsを制作fps明示に変更し、2mm閾値維持。PRの専用制作は従来腕demoとBittaran正本の二ケースを独立実行。
`source_bbmodel` は models/manifest.json に登録された正本のみ、`bb_unit_m` を明示する。Blockbench 5 free-model mesh/outliner/groupsの剛体階層に限定。グループUUIDでトラック・マーカー指定、重複や未参照UUIDは拒否。Blender Z上の軸とローカル絶対値を使用（BBのキーフレーム値そのままではない）。rig_report.jsonで原本SHA、UUID、親、Pivot、回転・変換位置を記録。Bittaranの試験は頭のヨー運動。0.065m/単位はプレビュー用仮設定、ゲームの倍率・接地オフセット・装備差・既存クリップ・テクスチャ・ゲームシェーダーは再現しない。原本、ゲーム実装を変更しない。BB mesh頂点の基準と回転整合性は実画像と既存ゲーム描画を比較するまで確定扱いしない。
参考: https://docs.godotengine.org/en/latest/classes/class_gltfdocument.html

## V4: 撮影実数・制限付きIK
V3成果物の全121フレーム指定点照合は腕0.000506mm、Bittaran 0.000065mmで合格。しかしGodot PNGが0枚。JSON数値の型差を考慮して整数フレーム辞書へ変換し、撮影実数・フレーム一覧を記録、期待数との一致を成功条件にする。
`ik` は独立剛体チェーンのオフライン位置IK。各項目に marker、target_marker または world target、frames、blend_frames、joints（node、limits_deg の XYZ軸別範囲）を指定。FKを毎フレーム初期値とし、減衰最小二乗法・有限差分Jacobian・軸制限・短い線探索で補正し、全フレーム回転キーへベイク。指定区間外はFK。共有関節・向き制約・衝突・全身IKは未対応、局所解であり到達保証なし。ik_report.json に初期/最終残差・角度・重みを保存。require_contacts=true で指定接触の誤差超過を失敗扱いにする。PR専用ケースはdemo、bittaran、ikの3種。Bittaranは原本の展開バインド姿勢でありゲーム内立ち姿・材質は未再現。
参考: https://mathweb.ucsd.edu/~sbuss/ResearchWeb/ikmethods/ ; https://motion.cs.illinois.edu/RoboticSystems/InverseKinematics.html ; https://docs.godotengine.org/en/latest/classes/class_json.html

## V5: 空間診断
V4の専用3ジョブが成功、IK実成果物で接触誤差8.35e-7m、Godot誤差6.08e-7m、撮影15/15枚を確認。`spatial` はベイク後全フレームの診断。floor.z/tolerance_m/meshes は水平床に対する評価済みメッシュ最低点。pairs は明示メッシュID二つ、intentional=trueで意図的な接合を候補から分離（記録は残す）。世界座標AABB→BVH三角形交差、AABB包含候補。接触・貫通体積の厳密区別はしない。support.contacts はマーカーと固定接地フレーム区間、masses は node/local/mass_kg で明示した仮想質量点。接地高さ・区間開始からの水平滑り・重心投影・支持点凸包・静的余裕距離（外側負）を計測。支持点3点未満/共線はnull、動的安定性・実質量推定・摩擦・連続衝突・自動回避は未対応。診断候補の先頭/末尾を撮影に追加。spatial_report.json の指標は自動合格ではなく判断材料。IKデモの質量は仮値、Bittaranゲーム姿勢は未再現。参考: https://docs.blender.org/api/current/mathutils.bvhtree.html ; https://motion.cs.illinois.edu/RoboticSystems/AdvancedTopicsInPlanning.html
