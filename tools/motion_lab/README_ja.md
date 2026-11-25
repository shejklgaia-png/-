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

## V6: 保護付き床補正
V5の3ケース成功、IK成果物121フレームで床・干渉候補・接地・静的余裕違反0、最小余裕0.453286mを確認。`optimize` は明示root（親なし、制約/NLAなし）、max_lift_m、require_improvementを指定。評価済みメッシュの床貫通深さから0/4/8フレームの持ち上げ包絡候補を生成し、床損失・接触誤差・新規干渉候補・接地・静的重心余裕を比較。候補評価中は元キー不変。改善し、指定保護指標を悪化させない候補の中で床損失を優先、近似同等なら滑らかさ/変位コストで選択する。採用時のみ位置を毎フレームベイクし再評価、不一致は書き出し拒否。候補なしは元モーションを維持（require_improvementなら未達を失敗扱い）。spatial_before/candidate/after_bake.json と optimization_report.json を保存。床を12cm貫通する設計の独立payloadデモを追加。ルート上下移動のみで、部品同士の自動回避、全身IK、連続衝突、動的重心、演技評価には非対応。既存ゲーム・正本モデルは変更しない。

## V7: 全フレーム動画レビュー
V6四ケース成功、補正成果物で床120mm→0、違反29→0、8フレーム包絡選択、ベイク再評価合格を確認。V7ではGodot GLBの各制作フレームに正確にseekし描画後PNG保存、全フレーム連番/保存実数を確認する。従来の疎な3視点Blender/Godot静止画も維持。FFmpegでH.264/yuv420p MP4、通常は制作FPS、半速は半分のFPSで同一の実画像を再生（補間なし）。終端姿勢を1フレーム保持するため動画長はN/FPS、モーションクリップ長は(N-1)/FPS。ffprobeで全フレームPTS・実フレーム数・FPS・長さを照合。video_report.json に両動画のSHA256、撮影元フレームのハッシュ、イベント時刻を記録。成功時のみフルPNG列を削除、失敗時はpartialに残す。動画は孤立Godot GLBの斜め固定視点、Androidや実ゲーム描画ではない。重量感・演技の自動合格は行わない。
参考: https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html ; https://ffmpeg.org/ffmpeg-formats.html ; https://ffmpeg.org/ffprobe.html

## V8: 剛体ポーズ資産・フェーズ合成
V7全4ケース成功、IK MP4 121フレーム・60fps 2.016667秒／30fps 4.033333秒、640x640、全時刻照合合格を確認。V8はBlenderのアーマチュア専用Pose Libraryに直接依存せず、剛体Node用のSERA_MOTION_POSES_V1 JSONを `tools/motion_lab/poses/` に置く。rigはprocedural全parts、BB正本パス/SHA256/単位、またはGLB SHA256を厳密照合。`pose_sequence.library` と `phases` (frame/event/pose/interpolation) を指定すると、同じチャンネル集合の絶対ローカル位置(m)・XYZ回転角(deg)を明示キーフレームへ展開し、イベント・ライブラリハッシュ・展開トラックをpose_compile_report.jsonへ記録。1/終端フレーム必須、重複イベント/不一致/明示トラック衝突は拒否。位相の時間・補間を変更して再使用可能。IK・床補正後の評価姿勢は export_poses と pose_export_channels で pose_candidates.jsonへ保存。候補は未承認、原本・採用済みライブラリへ自動登録しない。必要なレビュー後に明示的に登録する。同一rig厳密一致のみ、別骨格へのリターゲット、既存BBアニメーションの直接読込、ゲーム内ポーズ・全身戦闘ライブラリは未対応。初期ライブラリarm_demoは独立アームの試作用5姿勢、6フェーズ・IK接触保持・候補3件出力。専用5ケースで従来回帰と新経路を分離。
参考: https://docs.blender.org/manual/en/4.5/animation/armatures/posing/editing/pose_library.html ; https://docs.blender.org/manual/en/4.5/editors/graph_editor/fcurves/introduction.html

## V9: 連続IK・反復候補選択
V8全5ケース成功、pose成果物15004940418を取得。接触は0.000834mmだがtip速度35.17m/s、加速度1557.88m/s²、jerk177318.17m/s³、45/46f残差0.241/0.350m→47f急減。フレーム独立DLSの解の不連続が原因候補。V9は `ik_refinement.markers` で監視点を明示し、`require_improvement` で改善必須を指定。従来独立解、前向き/後向きのCartesian目標追従、前向き/後向きの全IK角度→FK角度ブレンド、計5方式を元曲線不変で比較。前回解とFKを初期候補とし必要時に軸別決定的restart、残差近似同等なら連続性優先。全クリップの速度/加速度/jerk、関節角速度/加速度、全重み残差・ブレンド残差、接触、V5空間診断の悪化拒否。静的支持内の移動は許容。正規化した3指標平均が改善した候補だけ採用。候補なしは元方式維持、改善必須の場合は書き出し拒否。採用ベイク後に再評価し差異が閾値超過なら停止。ik_refinement_report.jsonと各候補空間レポートを保存。従来デモは従来経路、pose_previewだけ改善必須で同一設計を比較。後続床補正の最終全指標はmotion_report/spatial_reportを参照。独立剛体チェーンの位置IKであり大域最適性、全身IK、物理動力学、演技品質を保証しない。参考: https://motion.cs.illinois.edu/RoboticSystems/InverseKinematics.html ; https://mathweb.ucsd.edu/~sbuss/ResearchWeb/ikmethods/ ; https://jorgedelossantos.github.io/moro/examples/cartesian-trajectory-ik.html

## V10: Bittaran実モデル・前左脚踏みつけ候補（未採用）
`bb_clip` はBittaran原本のWait/踏みつけ_Lを読み、runtimeのUNIT=0.145m、ローカルPivot差、ZYX回転、bind quaternion×アニメーション回転を再現する。既存ゲームの戦闘IK/頭追従/接地補正/ヒット判定は実行しない。原本clipの各チャンネルを時刻順に並べ、baselineは線形補間、candidateは単調3次Hermite補間（キー値とタイミングを保持、端点接線0）、Waitとの24フレーム入退場を候補のみsmoothstepにする。60fps154サンプル、原本1.75秒+前後0.4秒。候補はゲームに採用しない。2ケースの実GLB・動画・数値を比較。プレビュー材質は簡易、ゲーム内表現とは異なる。参考: https://docs.blender.org/api/4.5/mathutils.html ; https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games

## V11: 速度・床突出保護付き補間探索
Bittaran候補の `bb_clip.mode=guarded` は線形と単調Hermiteの混合率0〜1を0.125刻みで比較する。既存キー時刻・値と入退場時間を保持。各候補の全制作フレームで全指定マーカーの世界速度・加速度・jerk・ループ速度差、および全剛体メッシュ頂点のWait最低点からの下方突出最大/平均を評価する。線形基準に対し各指標の増加を許容誤差（速度0.001m/s、加速度0.05m/s²、jerk3m/s³、ループ速度差0.001m/s、突出0.1mm）以内に制限し、基準比平均が改善した候補だけ選択する。該当なしは線形へ戻す。選択トラック再評価と全候補の棄却理由をclip_guard_report.jsonへ保存。既存baseline/candidateモードも使用可能。床はWait相対の幾何診断であり実ゲーム接地IKではない。補正で原本キーを変えないため既存突出を解消する保証はない。ゲーム内モーションは置換しない。参考: https://docs.scipy.org/doc/scipy/reference/generated/scipy.interpolate.PchipInterpolator.html ; https://docs.blender.org/api/4.5/bpy.types.Depsgraph.html

## V12: 三脚接地アンカーとルート移動補正
V11 run 45584452920 成功、artifact 15008182065 の実レポートで blend=0、支持3脚のWaitからの最大変位0.2175m（共通Z下降）、床相対突出0.28900086mを確認。候補の `support_lock` は明示した3脚ピボットのWait座標との差の平均を、親なしBodyルートの補正量とする。補正強度0/.25/.5/.75/1、最大0.25m、初末姿勢固定、全154フレーム評価。V11の速度/加速度/jerk/床ガードに加え支持点変位・Bodyピボットの支持三角形に対する外側余裕を保護し、最大変位改善の候補のみ採用。全候補・世界座標の踏みつけ着弾点移動をsupport_lock_report.jsonへ記録。足裏接触点や質量分布は未確定なので足ピボット/Bodyピボットの代理指標。全身IKではなく共通移動のみ、相対攻撃軌道を保持する一方で世界座標の着弾位置は変化しうる。実ゲームの衝突・接地・物理安定性を保証しない。既存ゲームや正本未変更。参考 https://research.cs.wisc.edu/graphics/Gallery/kovar.vol/Cleanup/ ; https://mathweb.ucsd.edu/~sbuss/ResearchWeb/ikmethods/

## V13: 実メッシュ足裏・推定重心・遷移保護
V12 candidate artifact15008836330を取得。strength=0、最大補正候補は支持ピボット変位0.2175→0m、床突出0.289→0.0715mだが前左脚の2点のloop_velocity悪化で棄却。V13では補正強度4段階とsmoothstep遷移長0/4/8/12/24フレーム（無補正を含む21候補）。遷移ありは初末各2サンプルの位置を保持する。Bittaranの実モデルUUIDで4脚の足メッシュを指定。初回Waitの最低点+5mm以内の頂点を固定素材点として追跡し、支持3脚の足裏中心の平均誤差をルート補正へ使用。毎フレームの最低点、足裏中心変位、支持足裏頂点の凸包、均一密度の推定重心投影を評価。各メッシュが閉じた整合面なら符号付き四面体体積と重心、そうでなければ明示AABB体積・中心代理（ゼロ体積除外）を用い、方式数を記録。着地フレームの足裏中心XYの変化1cm以下、Wait相対最低点の高さ誤差を悪化させない。V11/12ガードも保持。V12実サンプル上で遷移補正のマーカー速度・加速度・jerk・loop_velocityを再計算したところ遷移あり16候補すべて悪化なし（V13実メッシュ・描画は別確認）。
足裏は静的Wait姿勢からの推定で実接触力・実質量・動的安定性ではない。支持3脚の接地期間は明示仮定。接地補正はルート並進だけで全身IK・荷重制御は未実装。水平着地点保持は代理点の許容差でありゲームのヒット判定を保証しない。ゲームと正本は変更しない。参考 https://research.cs.wisc.edu/graphics/Gallery/kovar.vol/Cleanup/ ; https://motion.cs.illinois.edu/RoboticSystems/AdvancedTopicsInPlanning.html ; https://projects.blender.org/blender/blender/src/branch/main/source/blender/blenkernel/intern/mesh_evaluate.cc

## V14: 四脚同時位置・姿勢IK
V13候補artifact15007988787実取得、補正強度1/遷移4F、足裏最大変位0.2175001→0.0152931m、平均0.1821916→0.0005664m、床突出0.2890009→0.0715009m、推定重心最小支持余裕0.236109m維持。18メッシュ全て閉鎖体積代理、各足裏はWaitで最低帯に1頂点。残存突出は攻撃脚の着地以降に集中。V14はV13選択軌道を基準に、明示12関節（各脚3関節、各XYZ軸）の回転補正を四脚足裏中心位置＋2方向の向きベクトルの同時重み付きDLSで解く。支持3脚のWaitアンカー、攻撃脚は原水平座標・向きを維持しつつWait相対床より下の量だけ上昇目標。原FKから各軸±12度の暫定補正上限、最大12反復、減衰・姿勢正則化、線探索、初末各2サンプル保持。強度0.5/1×角度補正平滑半径0/2/4Fの6候補を実メッシュ上で再計測し、従来速度・加速度・jerk・床・支持変位・重心余裕・着地XY/高さを悪化させない候補のみ採用。改善候補なしはV13を維持。multifoot_ik_report.jsonに全候補・棄却理由・ソルバー残差・選択軌道を保存。ルート固定の四脚同時関節IKであり、物理関節限界・動的荷重・連続衝突・全身の物理最適化は未対応。既存ゲーム、原本、既存CI定義変更なし。参考 https://mathweb.ucsd.edu/~sbuss/ResearchWeb/ikmethods/ ; https://motion.cs.illinois.edu/RoboticSystems/InverseKinematics.html
