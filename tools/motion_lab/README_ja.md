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

## V15: 動的支持荷重代理・部品干渉ガード・関節別制約
V14実artifact15008553327確認。強度1/平滑半径2F、床突出0.07150088→0.02405742m、支持足裏最大0.01529313→0.01245989m、水平着地点変位0.00064995m、推定重心余裕0.23610895m維持。6候補中4候補合格。
V15はV14の選択軌道を基準として追加IKを6候補比較する。モデルの関節UUID別XYZ補正幅を設定できる。追加補正は上/下脚各軸4度、足首各軸2度（暫定相対角、物理的絶対可動域ではない）。均一密度重心の中央差分加速度、Wait最低点を水平床とする点質量近似からZMP代理と摩擦比を算出。支持3点で鉛直荷重割合を連立し、負の荷重や非正法線力などを無効として記録する。実質量、角運動量、駆動力、実接触判定なし。始終端は中央差分対象外。支持期間は従来の固定仮定であり、衝撃力を再現しない。
剛体メッシュ全組合せから同一親・隣接親の意図的接合候補を除外し、フレームごとのAABB→BVH三角形重複およびAABB包含候補を記録。新規干渉候補・重複三角形対数増加、無効荷重フレーム数増加、ZMP最小余裕1mm超悪化、最大摩擦比0.01超悪化を棄却。従来の床/速度/支持/着地ガードも維持。改善なしはV14を保持。dynamic_refinement_report.jsonに全候補・全フレームの動的代理/干渉を記録。メッシュ重複は候補であって貫通体積や連続衝突ではない。隣接部の干渉、物理荷重制御、衝撃の演出は未実装。ゲーム本体・原本・既存CI定義は変更しない。参考 https://pmc.ncbi.nlm.nih.gov/articles/PMC9371053/ ; https://docs.blender.org/api/current/mathutils.bvhtree.html ; https://link.springer.com/article/10.1007/s10846-025-02335-z

## V16: フェーズ固定タイムワープと演技品質評価
V15実行45587337257は着手時in_progress、最終成果物未取得。V15までの処理を維持し、選択軌道の後段で全関節共通の時間再配置を試す。Wait/攻撃開始/頂点/溜め終了/着地/攻撃終了/復帰の7基準フレームを固定。区間内の単調写像 t+a*64*t^3*(1-t)^3 は境界値と一次・二次微分を恒等写像に一致させる。初末2フレームも固定。位置は線形、回転はQuaternion SLERP後にXYZ Eulerへ互換変換、整数フレームの元キー値は厳密保持。振りかぶり/復帰の後半減速、振り下ろしの後半加速、両者の組合せを3強度(0.025/0.05/0.10)で比較。溜めの区間尺と軌道を保持。実足裏速度の前後1/3比率、溜め平均速度、着地直後速度を評価。全体の速度/加速度/jerk/ループ、足裏、床、重心、ZMP/摩擦代理、干渉に対する従来ガードと基準フレームの位置誤差0.1mm以下を追加条件にする。改善候補なしは元軌道を保持。performance_report.jsonに9候補の時間写像・速度指標・棄却理由と選択結果を出力。強度と評価比率は暫定的な演技指標で芸術的品質の保証ではない。既存の復帰動作の緩急を変えるだけで、新規反動・副次動作・実質量衝撃は未生成。ゲーム正本・既存CI定義は未変更。参考 https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles ; https://dspace.mit.edu/entities/publication/fcd8b712-d952-4446-9429-e32413f305f9 ; https://www.dgp.toronto.edu/~lockwood/BiomechPathEditing/

## V17: 着地後の副次演技・四脚補償
V16 artifact15009421822のperformance_reportを確認。9候補全棄却、unchanged。最良演技スコア0.74901167595でも攻撃脚速度/加速度/jerk等のガードを通過せず、床0.0240574218m、支持最大0.0124598942mを維持。V17では着地フレームまでの動作を維持し、後段に新規の胴体Z並進・頭部ローカルX回転を生成。C2連続の有限区間の沈み込みと小さな反動を二つのローブで表現。軽/中/重の暫定演技設定（沈み込み5/10/20mm、頭部0.5/1/2度、遅延33/50/67ms、反動比0.20/0.25/0.30）。実質量に基づくパラメータではない。各プロファイルをV14四脚IKで補償し、元の選択軌道の各フレームの足裏中心を目標に、全補償の平滑半径0/2Fを比較（6候補）。支持脚と攻撃脚の全フレーム位置誤差2mm以下、着地以前の位置・重心誤差0.1mm以下、従来の足裏・床・重心・動的代理・干渉ガードを維持。意図した胴体・頭部・攻撃脚上中部の運動には限定的な増分許容（速度0.30m/s、加速度5m/s²、jerk200m/s³、ループ0.001m/s）、足のマーカーには従来の厳格ガードを適用。最大沈み込みを暫定選択指標とし、適格候補なしは前段保持。secondary_report.jsonへ候補、IK残差、棄却理由、選択軌道を記録。頭部の実ゲーム追従、物理的な衝撃吸収や質量別力学は未再現。既存ゲーム・モデル原本・既存CI定義は変更しない。参考 https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles ; https://www.adobe.com/creativecloud/animation/discover/principles-of-animation.html ; https://mathweb.ucsd.edu/~sbuss/ResearchWeb/ikmethods/

## V18: 階層解析と四脚設定の自動解決
V17実artifact15010185986を取得。6候補中3候補合格、heavy/平滑0を採用。沈み込み19.7804mm、反動5.9593mm、頭部1.98018度、元軌道からの支持足裏最大変化0.1273mm・攻撃足裏0.0672mm、非隣接干渉候補0。床最大突出24.0574mm、動的代理無効23/152は残存。
任意の対応済み剛体モデルに対し opt-in の `rig_discovery.mode=inventory` でID・表示名・親子階層・深さ・世界ピボット・終端メッシュ候補と最低Zを出力。低い終端は候補であり足と断定しない。
`mode=quadruped` では Body/Head/FrontFoot_L/FrontFoot_R/RearFoot_L/RearFoot_R の役割に対する名前、別名またはIDを明示指定し、末端からBodyへ親を辿ってIKチェーンを生成。曖昧な名前、共有関節、非対応階層、複数足裏メッシュはエラー。必要に応じ sole_mesh_selectors で名前/IDを指定する。関節列は2〜8関節で、Bodyはルート、Headはその直下に限定。 `apply=verify` は既存の明示設定と比較して維持、`apply=generate` は競合設定なしの場合にマーカー・支持脚・IK・関節別補正幅を生成。両前後脚の左右ピボット間距離平均を参照機体幅と比較し、0.25〜2.5倍の範囲で移動量・足裏幅・着地許容値を初期設定する。scale_secondary を明示有効化した場合のみ副次動作の沈み込みと軌道許容値を比例調整（沈み込み上限50mm）。参照幅未指定は1倍。
正規モデルの既存アニメーションを利用する汎用クリップ経路では、bb_clip.explicit_phase_frames に攻撃開始からの apex/hold_end/impact_authored の整数フレームオフセットを明示する。wait_name、freeze_headを設定可能。独立した正本階層検査でBittaranの四脚12関節・足裏4メッシュが既存設定と一致することを確認し、既存候補はverifyに設定。参照幅5.539m、scale_secondary=false、既存イベント85/100/115Fを維持。rig_discovery_report.jsonへ候補、解決結果、実効設定を出力。任意機体の完全自動リギング、二足・多脚ソルバー、歩行/格闘専用の演技生成、ゼロからの新規モーション生成は未対応。既存ゲーム・モデル原本・CI定義未変更。参考 https://docs.godotengine.org/ja/4.x/classes/class_skeleton3d.html ; https://docs.blender.org/api/current/bpy.types.Object.html ; https://docs.omniverse.nvidia.com/extensions/latest/ext_animation-retargeting.html

## V19: 既存アニメーション非参照の四脚キーポーズ生成
`bittaran_procedural_v19.json` は既存クリップ、明示トラック、ポーズライブラリを入力とせず、V18 generateによる役割指定→階層解決→形状由来の静止姿勢→目的別のワールド足裏目標→二リンク解析IK→局所キーポーズへ変換する。既存クリップ等との混用は禁止。対応チェーンは上脚・下脚・足先の3関節、Body直下の脚/Head、単位スケールの剛体XYZモデル。足先ピボットからの実メッシュ重心方向を下向きに揃え、最低帯の素材点を足裏目標とする（自動推定、実機の接地面定義ではない）。初期胴体高さ=足幅0.24倍、足幅収縮=0.70倍、膝曲げ方向は上向き＋外向きの幾何代理。物理的関節限界ではない。
動作の選択は idle / walk_forward / walk_backward / turn_left / turn_right / stomp / sweep / hit / down_recover。各3秒・60fps/181サンプルの暫定検査尺。前後歩行は1歩行周期で幅0.08倍を移動、旋回は12度。1脚ずつ移動するcrawlの足運び、支持3脚側に胴体を寄せる簡易目標。旋回では支持脚の足裏向きを維持し、遊脚だけ旋回方向に向ける。stomp/sweepは予備、頂点、溜め、接地、復帰のキーポーズを生成。hitは胴体傾き・反動、down_recoverは支持脚を保った沈み込みからの復帰（実転倒・横倒し・動的衝突なし）。
`blender -b -t 2 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_procedural_v19.json /tmp/mlab_v19_stomp --action stomp` のように出力先を新規ディレクトリに指定。--actionで上記9種を個別実行。procedural_pose_report.json、pose_candidates.json（V1ポーズライブラリ互換）、motion.glb等の既存出力を使用。各キーポーズで足裏到達誤差、実メッシュ最低Z、支持多角形と均一密度重心の静的余裕、非隣接メッシュ干渉候補を測定。足裏目標固定区間のサンプル接地診断、全メッシュのサンプル床診断も追加。フラグが出ても候補を保存し人間レビュー必須。区間内は暫定線形補間でV20以降の接地軌道最適化対象。既存ガード付きクリップ経路とは独立し、V15の動的代理最適化は新規動作には未統合。
正本BBの階層/頂点から独立再計算したBittaranの足幅5.539m、リンク長1.295703/1.0585m、足先からの接地点0.9715m。9動作の全84キーポーズについて時刻重複なし、4脚の目標距離が2リンクの到達域内（クランプ0m）を確認。これは到達域の独立計算でありBlender実行・実メッシュ干渉・関節制約・連続接地・視覚的品質を確認したものではない。既存ゲーム内モーション、モデル原本、既存CI定義未変更。
参考: https://pmc.ncbi.nlm.nih.gov/articles/PMC7805836/ ; https://journals.sagepub.com/doi/10.5772/58733 ; https://github.khronos.org/Vulkan-Site/tutorial/latest/Advanced_glTF/Procedural_Animation_IK/01_introduction.html ; https://docs.blender.org/api/current/mathutils.html

## V20: 演技優先 / 実行時接地IKの分離
既存ゲームの `scripts/bittaran_battle.gd` にある BLOCKBENCH_GAIT_SUPPORT_IK=true、source pose適用後の `advance_source_ground_ik`、`scripts/bittaran_foot_ik.gd` の既存二リンク解析 `_source_ik_solve_striker` を確認。既存の戦闘・歩行・攻撃・ダウンの処理は変更しない。新しい候補専用のオプトイン契約を追加する。
- `bittaran_procedural_v20.json` の `profile=performance_v20` に限って演技目標を拡張。Bittaran足幅5.539mを基準に前後移動1.1078m、旋回45度（22.5度ずつ2周の足運び）、stomp上昇2.65872m・遊脚足裏80度ピッチ、sweep上昇1.21858m・大きな弧/胴体20度旋回と支持側の中間姿勢、hit胴体15度。時間は待機3s、歩行1.8s、旋回1.6s、踏みつけ2s、なぎ払い1.8s、被弾0.85s、ダウン復帰3.5s。これらは暫定演技値。V19の小動作設定は互換性のため保持。down_recoverは依然として支持脚を維持した沈み込み型。
- runtime_contact_ik.json（SERA_MOTION_CONTACT_V1）は4脚の leg_fl/leg_fr/leg_rl/leg_rr、1始まりフレーム範囲、接地ID、最大4Fのsmoothstep強度、補正最大0.30mを出力。支持位置と向きが等しい連続区間のみ固定し、遊脚・攻撃脚は自由。planned_anchor_mはZ-up検査用で、実ゲームへ絶対座標を流用しない。
- runtime_contact.pyは各フレームの生FKと独立した実行時類似の二リンクIKを比較し、実足裏の固定区間開始のワールド位置・回転とメッシュ最低高から接地点を取得。支持脚のみ補正、胴体/頭部/遊脚の元演技を維持。上限超過・到達不能は記録し、演技を自動縮小しない。runtime_ik_preview_report.jsonとruntime_ik_preview_tracks.jsonを出力。通常GLBは演技原本。--preview-ikで明示して補正後の検査用GLBを別出力（元トラックはprocedural_pose_report.jsonのtracksにも保持）。線形補間の接地移行中の誤差や床貫通、関節限界、力学、実機性能は別検査が必要。
- Godot側は既存FootIKインスタンスの configure_motion_lab_contact_layer(packet) / apply_motion_lab_contact_layer(frame_index, enabled) / clear_motion_lab_contact_layer() を追加。**新規候補のプレビュー呼び出し専用**。毎回新鮮な原本姿勢を適用してから、通常のadvance_source_ground_ikの代わりに呼ぶ。既存ソルバーと二重適用しない。区間開始の実ゲーム座標を記憶、巻戻し/飛び越し/テレポートでリセット。既存のsource_sole_localと最低メッシュ高を使用し、足位置・向きのみを補正。OFFでは姿勢を変えない。実ゲームの通常戦闘からこのAPIは呼び出さない。ゲーム内新規クリップの再生・時間軸・ルートモーションとの接続は未承認のため別工程。
- コマンド例: `blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_procedural_v20.json /tmp/mlab_v20_stomp --action stomp`。別出力ディレクトリで `--preview-ik` を追加すると補正後プレビュー。専用既存Actionsのworkflow_dispatch design入力でも原本とsidecarを生成可能（当該新規デザインのActions実行は未確認、既存ゲームCI変更なし）。
- V18実成果物の形状・バインドから独立SciPy再計算した1086サンプル（9動作）。踏みつけ上昇2.6587mをOFF/ONとも維持。全9動作の完全固定区間では補正前最大0.23296m、補正後数値誤差範囲。上限超過/到達不能0。キーポーズ到達誤差最大0.00215m。全体の床突出は補正後も最大0.03383m（後退）。ON/OFFのHTML独立プレビューをChromiumモバイル幅Canvas2Dで操作確認（9動作、同一フレーム切替、速度/再生/視点、JS例外/外部通信0）。これは実Blender出力やGodot本体の実行検証ではない。既存ゲームモーション・AI・既存ゲームCIは変更なし。
参考: https://dev.epicgames.com/documentation/unreal-engine/fix-foot-sliding-with-ik-retargeter-in-unreal-engine ; https://dev.epicgames.com/documentation/unreal-engine/game-animation-sample-project-in-unreal-engine ; https://docs.godotengine.org/en/stable/classes/class_node3d.html

## V21: FK演技先行・踏みつけ比較
V20の視覚評価不合格を受け、足先目標の逆算ではなく各リンクのBody相対仰角・方位角を明示した新規キーポーズを先に設計する。Bittaran前左脚専用の試作。旧モーションを読まず、V18由来の実形状と正本BBの剛体階層を使用。2案とも2.05秒・60fps・124サンプル、11ポーズ。形状保持の区分三次Hermite（PCHIP）で時間曲線を生成。脚3リンクの方向をFKで設定、後段の既存runtime_contactは支持3脚に限り適用し、攻撃脚の演技を変更しない。
- `blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_fk_v21.json /tmp/mlab_v21_a --variant extended`。別ディレクトリで `--variant spear` または `--preview-ik`。FK原本・sidecar・独立IK評価出力を維持。
- V18実GLBの静的メッシュ形状から独立SciPy評価を実施（アニメーションチャネル未読）。A足先上昇3.30385m、水平変位1.58615m、B上昇2.88602m、水平変位2.51015m。支持脚最大誤差0.23222m→数値誤差、補正上限超過0。最大床突出OFF0.13797m、ON A0.03514m/B0.03754m。暫定角度/尺であり関節機構・干渉・動力学未検証。
- HTMLビューワーで初期案を正面/側面/斜めから確認、支持脚補正上限超過と貫通を発見。胴体移動・角度と着地キーを再設計。最終2案の主要6フレーム×3方向を実際のChromium Canvas描画で再確認し、1倍/0.5倍再生とIK切替も実行（JS例外0）。Aは正面、Bは側面で攻撃脚の輪郭が明瞭になったが、斜めでは機体と重なる、着地・支持脚の重量感が不足。**ゲーム採用としては視覚不合格**。実Blender/Godot直接出力・Android未検証。HTMLは独立プレビューで、実行時APIの実測ではない。
- 今後は実3D HTML作成・再生・複数方向の描画確認・修正後再確認を必須とし、数値/操作確認だけで視覚合格にしない。既存ゲームモーションを置換しない。
参考: https://www.gameanim.com/2019/05/15/the-12-principles-of-animation-in-video-games/ ; https://www.gamedeveloper.com/game-platforms/12-principles-for-game-animation

## V22: 全身連動・荷重移動・着地後の反動
V21に対し、前左脚の踏みつけ1案を追加。21キー・2.20秒・60fps/133サンプル。演技を先に設計し、胴体を支持側へ移動、ロール最大14度、ピッチ+12/-12度、頭部遅延反応最大15度、着地後胴体沈み込み0.13m（impact→compression）。支持3脚のローカル回転をキーごとに明示し、姿勢間のPCHIP補間でFK原本を作成、後段IKは固定誤差のみ補正する。支持キーは中立姿勢の接地基準に合わせてオフライン作成。攻撃脚には接地IKを適用しない。
`blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_fk_v22.json /tmp/mlab_v22 --variant chain`、別出力で `--preview-ik`。V21既存デザイン互換。
V18 GLBの実メッシュ形状を用いた独立SciPyプレビューを生成し、初回正面/側面/斜め描画で過大な振りかぶりと約9cmの貫通を発見。振りかぶり角度・着地・圧縮・復帰キーを再設計。最終133F: 攻撃脚上昇4.10760m、水平変位2.00127m、支持3脚最大誤差OFF0.04979m→ON数値誤差、床最大突出OFF0.04401m→ON0.003109m、胴体上下幅0.28489m。V21 A案との同一ビューワー比較で等倍・半速再生・IK切替・3方向主要6フレーム×2案の実描画を確認、JSエラー0。斜め（攻撃脚側）で振りかぶり輪郭、胴体傾き、支持脚屈伸が改善。残課題: 振り上げがまだ大きく、打撃の重さと着地後の攻撃脚接触位置の固定が十分ではない。ゲーム採用未承認。Blender/Godot実出力、Android、関節制約・干渉・動力学は未確認。既存ゲームモーション・CI定義変更なし。
参考: https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games ; https://www.animationmentor.com/blog/animation-tips-tricks-what-makes-or-breaks-a-good-body-mechanics-shot/

## V23: 成功事例の標準化と着地固定
標準制作フロー・考え方・資料・V22評価とV23実験は [SUCCESS_WORKFLOW_V22_ja.md](SUCCESS_WORKFLOW_V22_ja.md) を参照。`bittaran_fk_v23.json` はV22のFKキーを保持し、`contact_policy=post_impact_v23` で75〜92Fのみ攻撃脚の接地を追加。別出力で `--preview-ik`。独立ビューワーで比較済み。ゲーム原本・既存CI未変更。

## V24: 重量級踏みつけ・着地後の跳ね返り禁止
重い機械生命体では着地時の衝撃を攻撃脚の跳ね返りではなく、胴体・支持脚の圧縮と遅延反動で表現する。V22のFK、振りかぶり、胴体、頭部、支持3脚の原本を維持。V23の着地IK解除で攻撃脚が浮く問題に対し、heavy_landing.pyで攻撃脚の着地以降の回転のみを独立ベイクする。着地75F→意図的戻し開始102Fまで27区間・0.45秒固定、102→124Fは単一の低い戻し（暫定最大7.5cm、2.2秒/133Fの尺維持）、124→133Fは基本接地を維持。実足裏最低頂点を基準にし、水平移動は五次smoothstep、垂直は64u^3(1-u)^3、足向きはSLERP。両端速度・加速度0の目標軌道。既存の解析二リンクIKをオフラインの接地/戻し軌道作成だけに使用、実行時支持IKは三脚のみ。到達残差または固定誤差5mm超は出力拒否。heavy_landing_report.jsonに全サンプルを記録。既存ゲームモーション未置換。
`blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_fk_v24.json /tmp/mlab_v24 --variant chain`、別出力で `--preview-ik`。
実形状を用いる独立SciPy比較で戻し高さ4.5/7.5/10cmを検査。7.5cm案では接地固定中の高さ・水平移動は数値誤差、戻し水平距離0.57946m、足上昇4.10760m維持、最大床突出IK後0.0005972m、終端メッシュ差は数値誤差。戻し高さ・尺は暫定。V23との実HTML比較で3方向×6主要フレーム×2案=36枚、通常/半速再生、IK切替、JSエラー0を確認。圧縮と回復中の攻撃脚浮きを解消、胴体の反動は維持。独立プレビューでありBlender/Godot直接出力、Android、連続衝突・物理可動限界は未確認。参考: https://research.cs.wisc.edu/graphics/Gallery/kovar.vol/Cleanup/ ; https://github.khronos.org/Vulkan-Site/tutorial/latest/Advanced_glTF/Procedural_Animation_IK/04_foot_placement.html

## V25: 地表なぎ払い・地表を弾くデコピン
対象は地上を歩く小型のSERA。空中の相手を蹴る演技ではない。前左脚のFK演技として、なぎ払いは地表を這う水平の弧、弾きは地面に向けて脚先を畳んでから瞬間的に低く前へ伸ばすデコピン型に修正。着地後の跳ね返りは禁止。元のV25高い攻撃候補は採用しない。
- なぎ払い100F/1.65秒・21キー、弾き109F/1.80秒・23キー。V22の支持脚局所角キーとPCHIPを活用。足先方位・関節の演技を先に定義し、主要キーおよび途中サンプルの最低メッシュ高を基準に上脚仰角を調整。支持脚の接地IKのみを別段で補正。
- 独立実メッシュプレビュー（V18静的GLB形状、SciPy、60fps）ではapex→follow区間の攻撃脚最低メッシュ高がなぎ払い3.03〜6.50cm、弾き1.44〜6.50cm。区間水平変位4.341m/1.879m、最大速度21.416m/s/13.135m/s、支持脚補正前最大誤差1.634cm/2.316cm、補正後数値誤差。床突出は数値誤差、最終接地後跳ね返り・滑り0。保存キーは角度0.005度/位置0.01mmに丸めており上記は丸め前の独立検査値。
- HTML MotionLab_V25_Ground_Attacks.htmlで正面・側面・斜め・真上の6主要姿勢×2動作＝48枚を描画確認。通常/半速再生・IK切替・JSエラー0。低い軌道を確認したが、実SERAモデルと当たり判定、地形への追従、部品干渉、Blender/Godot直接出力・Android実機は未検証。既存ゲームモーションは未置換。寸法・タイミングは暫定値。
- 再現: blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_sweep_v25.json /tmp/mlab_v25_sweep --variant sweep （kickはbittaran_kick_v25.jsonと--variant kick）。別出力で--preview-ik。
参考: https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games ; https://docs.scipy.org/doc/scipy/reference/generated/scipy.interpolate.PchipInterpolator.html

## V25再改: 足裏全面を地表に揃える高速攻撃
ユーザー指摘「もっと派手に、なぎ払いが地面を這ってない」に対応。V25の最低頂点のみの高さ基準では足裏が傾いて見えるため、ground_drag.pyで足裏の接触面全体を水平に揃え、攻撃脚だけをオフラインで新しい極座標軌道へベイク。胴体と支持脚のFK原本は維持。支持脚IKは別段、滑走させる攻撃脚を実行時固定しない。なぎ払いは股関節基準-35〜108度、弾きは深い折り畳みから0.10秒で伸展、主要攻撃期間の足裏高さ1mm、復帰時のみ最大7.5cmの持ち上げ。半径・方位・高さをPCHIPで補間、到達境界では半径だけ縮小。実メッシュ接触面全頂点の高さ、終端の固定、到達残差を出力拒否条件に追加。
独立SciPy実形状プレビューの100/109F検査: なぎ払い32〜54（0始まり）、弾き41〜53で全足裏頂点1mm、面内高低差数値誤差。攻撃軌道長5.8961m/1.8632m、最大水平速度33.1677/27.7608m/s、IK後床突出数値誤差、最終姿勢差・終端滑り数値誤差。なぎ払い半径縮小最大3.64cm、後脚メッシュとの最小頂点間距離12.60cmは衝突なしの証明ではない。4方向×6姿勢×2動作48枚をChromium Canvas 2Dの実3D投影で描画確認、通常/半速再生・IK切替・JSエラー0。HTML MotionLab_V25_Ground_Drag.html。足裏接地の見え方・振り幅・速さ改善。ゲーム内当たり判定・干渉・地形対応・Blender/Godot直接出力・Android未検証。既存ゲーム戦闘モーションは未置換。既存V25原本キーは維持、contact_policy=support_onlyで旧方式を選択可。
参考: https://research.cs.wisc.edu/graphics/Gallery/kovar.vol/Cleanup/ ; https://github.khronos.org/Vulkan-Site/tutorial/latest/Advanced_glTF/Procedural_Animation_IK/04_foot_placement.html

## V25 revision 3: 全脚横倒し・ムチ状薙ぎ払い・低姿勢デコピン
ユーザー指摘: 足裏を平行にするだけでは不足、上脚・下脚・足先全体を横倒しにして地表を這わせ、胴体も大きく下げる。デコピンは低い構えから伸び切った余韻を保持。whip_flick.pyで全3リンクの世界方位・仰角を個別に設計し、FK局所回転へ変換。上脚→下脚→足先の遅れと追い越しを明示した12キー、PCHIP補間。攻撃脚全体の床高と胴体の最低頂点を守る微小ルート調整、支持3脚はオフラインで床干渉の少ない膝曲げ平面を36候補から選択しFKへベイク。後段支持IKは別系統の残差補正。旧V25設計は維持し独立designで選択可能。
初回独立実メッシュ生成では支持脚の床貫通30.7/28.4cmを発見。攻撃側へ胴体を傾け、支持脚の膝平面を変更して再生成。最終独立プレビュー60fps: なぎ払い109F/1.80秒、胴体沈み1.13771m、攻撃区間各リンクの最低部0.008〜0.07282m、上脚/下脚/足先全体の最大頂点高さ0.61876m、足先軌道長8.71922m、最大速度29.01878m/s。デコピン117F/1.933秒、胴体沈み1.08542m、攻撃区間各リンク最低部0.008〜0.07282m、最大速度56.09949m/s、50〜63サンプルの伸展保持0.21667秒。両方とも床突出/支持接地点誤差/終端姿勢差は数値誤差、独立プレビューの補正前から支持脚固定済みのためON/OFF実質同じ。50〜63Fは0始まり。最大1F関節回転差は薙ぎ払い7.54度、弾き55.52度（爆発的伸展、速度・可動限界は要検討）。48枚の実描画を正面・側面・斜め・真上で確認、通常/半速再生とIK切替、JS例外0。視覚上は低い胴体と横倒しの脚全体、弾きの直線伸展が明確。接近する部位の干渉、実ゲーム当たり判定、Blender/Godot直接実行、Android未確認。ゲーム戦闘原本・既存CIは未変更。数値は独立SciPy実メッシュ生成値で、今回のBlenderコードと同一アルゴリズムだが実出力一致は未検証。HTML: MotionLab_V25_Whip_Flick.html。
再現: `blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_sweep_whip_v25.json /tmp/mlab_whip --variant sweep` （弾きはbittaran_kick_whip_v25.jsonと--variant kick）。別出力で--preview-ik。
参考: https://www.animationmentor.com/blog/tutorial-overlap-pendulum-motion-animation/ ; https://blog.animschool.edu/2024/04/19/follow-through-and-overlap-animation-tips/ ; https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games

## V25 revision 4: 逆方向なぎ払いと縦丸めデコピン
前左脚の正方向なぎ払いを維持し、同じ脚の逆方向を追加（sweep_reverse）。方位キーを25度を中心に反転、胴体ヨーも反転。再生時間は反転せず、付け根先行・末端遅れと復帰順序を保持する。kickは構え中の3リンク方位を揃え、仰角で縦に丸める。頂点は上脚65度、下脚-137度、先端155度。38〜50の12サンプル間隔で順に展開し、50〜63の13間隔（約0.217秒）は伸展保持。旧revision 3候補は維持。ユーザー指定によりゲーム演技の迫力を優先し軽微な部品干渉を許容する。著しい形状破綻・床貫通・接地滑りは別に検査する。接触や干渉の程度が未計測のものを軽微と断定しない。
- 正方向109F/1.80s、逆方向109F/1.80s、縦丸め弾き117F/1.933s。独立SciPy実GLBメッシュの検査: 正/逆/弾きの胴体最大沈み1.138/1.071/1.098m、足先最大速度29.019/30.031/43.282m/s。なぎ払い攻撃区間水平軌道長8.719/8.790m、各リンク最低地上高0.008〜0.07282m。床突出、支持脚接地誤差、終端差は数値誤差。弾きの初回4F伸展案は最大122.55m/sとなったため棄却し、時間差と12F伸展へ修正。 
- HTML MotionLab_V25_Reverse_Vertical_Flick.html に3候補収録。正・逆の各24枚、弾き32枚、合計80枚を4方向の主要姿勢でChromium描画、接触シートを視認。3候補の通常/半速全尺再生が終端到達することとIK切替を実際に確認、JS例外0。縦の折り畳み→伸展、逆の弧、低い姿勢を確認。一部上面の先端は画面端に近く、カメラ拡縮が必要。部品同士の干渉は厳密な連続衝突検査を行っておらず、後脚に近づく姿勢がある。演技優先の候補。実ゲーム戦闘・既存CIは変更なし。Blender/Godot直接実行、Android、当たり判定は未確認。 
- 逆方向: `blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_sweep_reverse_v25.json /tmp/mlab_reverse --variant sweep_reverse`
- 縦丸め: `blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_kick_vertical_v25.json /tmp/mlab_vertical --variant kick`
参考: https://www.animationmentor.com/blog/tutorial-overlap-pendulum-motion-animation/ ; https://www.animationmentor.com/blog/anticipation-the-12-basic-principles-of-animation/

## V25 revision 5: 過大な埋まりを抑制
ユーザー指摘「さすがに埋まりすぎ」に対応。正逆なぎ払いの後方方位を-9度以上に制限、正方向は上脚の前方方位82度以下。縦丸め弾きは胴体側ではなく外側の垂直平面に構え、上脚30度・下脚-60度・先端-135度の頂点姿勢から順に伸展。伸展方位55/57/59度、50〜63の13サンプル間隔の保持と元の時間構成を維持。大きな低姿勢と脚の横倒しは保持。
- 各フレームで攻撃脚に関係する異なる親のメッシュ組をOBB（メッシュ局所AABBを世界姿勢へ変換、SAT15軸）で検査。隣接関節と非隣接部品の重なり指標を区別し、非隣接5cm超を要確認、10cm超を大きな重なりとして出力停止。暫定ガードであり、厳密な表面衝突・貫通深さ・連続衝突ではない。隣接ジョイントは元から重なる構造があり一律棄却しない。独立SciPy比較（全335サンプル）：非隣接最大OBB重なりは正薙ぎ34.64→3.83cm、逆43.80→3.68cm、弾き54.48→3.88cm。弾き隣接最大37.96→20.49cm（基本姿勢の攻撃脚隣接最大14.26cm、接合部のボックス重なりも含む）。深い埋まりの指標は改善、完全非干渉ではない。
- 正/逆/弾きの胴体沈み1.138/1.071/1.085m、最大足先速度26.17/30.59/28.56m/s。正逆の水平攻撃軌道長6.61/6.28m（前案より短縮）、各リンク最低地上高0.8〜7.3cm。弾きの伸展保持0.217秒、床/支持接地/終端差は数値誤差。弾きの溜め中は脚を外側に出すため胴体が前案より高くなる区間があり、最大沈みは維持。モーション時間109/109/117F。
- 実GLB形状の独立HTML MotionLab_V25_Clearance.html、4方向80枚を実描画し接触シートを視認。通常・半速再生のフレーム進行とIK切替、JSエラー0を確認。再生の全尺到達はログから確認できない。縦丸めが胴体の外に出てシルエットが改善、正逆の振り抜きの後脚貫通を大きく抑えた。Blender/Godot直接出力、Android、実ゲーム当たり判定、厳密な部品干渉は未確認。旧候補および既存戦闘原本、CI未変更。
- 再現: bittaran_sweep_clearance_v25.json、bittaran_sweep_reverse_clearance_v25.json、bittaran_kick_clearance_v25.json を build.py に指定（variant sweep/sweep_reverse/kick）。既存の設計ファイルは維持。
参考: https://www.sciencedirect.com/topics/computer-science/oriented-bounding-box ; https://www.animationmentor.com/blog/tutorial-use-character-staging-to-guide-viewer-focus/

## V25 revision 6: 深い縦丸め・伸展後の跳ね上げ
デコピンのみ変更し、正逆なぎ払いはrevision 5と同一。縦丸め頂点の上脚/下脚/先端仰角を36/-67/-143度へ変更。50サンプルで水平伸展、53で仰角2/5.2/8度の一回の上方オーバーシュート、57で収束中間、63で元の伸展へ戻る。足を踏みつけた後の跳ね返り禁止とは区別し、デコピンのフォロースルーとして意図した動作。旧候補と既存戦闘原本は維持。
- 独立実メッシュ60fps/117サンプル検査：溜め時の脚先から付け根距離約136→105cm、伸展後3サンプル間隔で約30.9cm上昇、最大足先速度33.23m/s、非隣接最大OBB重なり4.21cm。OBBは表面の貫通深さではない。5cm要確認・10cm超出力停止の暫定ガードを維持。
- MotionLab_V25_Flick_Snap.html の実描画で深い丸め、伸展、上方フォロースルー、回復の姿勢を視認。通常/半速再生のフレーム進行を確認。Blender/Godot直接出力、Android、厳密な連続衝突・ゲーム当たり判定は未確認。
- 再現：bittaran_kick_snap_v25.json を build.py に指定。既存ゲームCIは変更しない。

## V26: 全時間軸の回転最適化と候補比較（オフライン、明示的に有効化）
V25再改5/6の成功演技は保持する。--trajectory-review heavy を指定した別出力のみ、trajectory_refine.py / trajectory_review.py を使用。主要イベント・開始終端・settle以降を固定し、符号連続な単位クォータニオン（XYZW）の埋め込み空間で参照誤差、二階・三階差分を含む全時間軸の正則化最小二乗問題を解き、正規化する。物理力学や厳密なSO(3)非線形制約解法ではない。NumPyのみで3強度と原本を生成。SciPyがBlender環境に存在する場合はRotationSplineの別候補も比較（未導入環境はスキップ）。heavy/medium/lightは攻撃期間の参照忠実度5/3/2の初期設定であり、重量・慣性・予備動作自体の生成は未実装。
- 攻撃脚の候補選択後、支持3脚を別の全時間軸候補として生成し、非固定フレームで解析二リンク接地を再適用。元の膝平面を維持する方向。角ジャークRMSと元形状からの最大変位で順位付け。床2mm（60Hz）、支持点5mm、非隣接OBB5cm以内かつ原本+5mm以内、姿勢変位12cm/10cm、攻撃速度±10%、軌道長±5%、終端姿勢、詳細交差ペアの非増加をゲートにする。120Hz中間床は2mmまたは原本+1mmを上限とする回帰抑制。原本を超える候補がなければ原本維持。原本は合格保証ではない。
- 詳細検査は非隣接メッシュのAABB→BVHTree三角形overlap。60Hzの各フレームと中間を検査（Blender側はEulerキー線形補間、独立プレビューはクォータニオン中間補間）。隣接接合部除外。表面交差のサンプリングであり完全包含、厳密な貫通深さ、連続衝突、物理可動限界は未保証。独立検査ではAABB→三角形SAT（交差/非交差/同一面の合成ケース確認）。
- 独立SciPy実GLB形状比較: 各動作で攻撃5候補、支持4候補（段階別、原本含む）。正薙ぎ/逆薙ぎ/弾きの攻撃脚離散角ジャークRMS 900.16→631.05 / 613.89→432.93 / 1482.89→1070.93 rad/s^3、29.90/29.48/27.78%減。選択λ2.4/2.4/0.6。強い弾きλ2.4案とRotationSpline案は床基準で棄却。支持脚は全3動作で原本維持。支持脚の接地誤差は数値誤差。60Hz最大床突出0.138/0/0.638mm、120Hz中間を含む最大0.326/0.153/8.047mm（弾き原本8.532mm。2mm未達、改善継続が必要）。弾きの上向き余韻30.87cm維持。非隣接表面交差三角形ペアは全3動作で原本/選択とも0（217/217/233サンプル）。OBBは最大3.83/3.69/4.21cm。原本の主要ポーズは固定、攻撃区間最大速度25.50/30.04/32.26m/s。
- HTML MotionLab_V26_Trajectory_Compare.html: 3動作×原本/候補×4方向×5姿勢=120枚の実描画を視認。原本/候補・通常/半速の12再生がループOFFで最終フレーム到達、JS例外0。主要姿勢・振り抜き・跳ね上げの見た目を維持する微調整。独立プレビューであり、Blenderの新アダプタの実行結果との一致、Godot/Android、実機当たり判定、完全包含・連続衝突は未検証。V25以前のゲーム原本、CI、デフォルトビルドを変更しない。
- 再現: `blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_kick_snap_v25.json /tmp/mlab_v26_kick --trajectory-review heavy`。正逆はbittaran_sweep_clearance_v25.json/bittaran_sweep_reverse_clearance_v25.json。出力trajectory_source_tracks.json（原本）/trajectory_review.json（候補とゲート）。次は120Hz中間床、支持膝平面の動的計画法、重量演技パラメータ・別リグ適用の検証。
参考: https://publications.ri.cmu.edu/spacetime-constraints ; https://docs.scipy.org/doc/scipy/reference/generated/scipy.spatial.transform.RotationSpline.html ; https://docs.blender.org/api/current/mathutils.bvhtree.html

## V27: 240Hz床補正と支持膝方向の時間軸探索
V26の候補選択は120Hzのまま維持し、その後 --subframe-guard で240Hzの詳細検査を実施する。出力は60Hzのまま。攻撃脚全体の最低メッシュ頂点を測り、床突出が2mmを超える時点に隣接する未固定Eulerキーだけを数値微分・最小ノルム方向への投影で調整する。主要イベント・始終端・settle以降を固定、各Euler成分の変化を最大2度、最大8反復に制限。補正後は全身床、支持接地、OBB、非隣接BVH表面交差、原本形状変位6cm、速度±10%、軌道長±5%、角ジャーク増加5%以下を再検査。許容外は原本に戻し、最終目標達否を明示する。120/240Hzの標本検査であり連続衝突保証ではない。
支持脚は元の膝平面の周り0/±1/±2度の5候補、解析二リンクで接地点を再構成し、動的計画法で全時間軸を選ぶ。中間点足裏誤差、膝位置の変化、状態変更量と原本忠実度をコストにし、固定キーは原本のみ。全身検査と角ジャーク増加5%以下、サブフレーム支持誤差改善を満たす場合のみ採用。従来の支持脚候補は維持。
独立実GLB形状検査: Blenderと同じEuler線形補間を近似し、Eulerの等価表現2候補から直前姿勢に近い側を選んだ。V26の独立クォータニオン中間補間とは異なる比較基準。正薙ぎ/逆薙ぎ/弾きの433/433/465サンプルで最大床突出1.035/1.485/7.444mm→1.035/1.485/1.721mm。弾きの未固定0始まり43,44,45Fのみ変更、最大成分角度0.23049度、最大頂点変位13.27mm、角ジャーク1070.93→1079.56 rad/s^3（+0.81%）、最大攻撃区間速度32.260→32.136m/s、上方オーバーシュート30.871cm不変。表面交差三角形対は3動作とも0、完全包含や実際の貫通深さは未検証。支持脚240Hz最大変位23.687/13.012/10.160mmは未解決。支持膝の±5/10度案は棄却、小角度案では正23.687→15.486mm、逆13.012→8.143mmの改善を得たが角ジャークが539→771、622→828と増加。弾きは最大支持誤差不変。全3動作の支持候補棄却、V26原本維持。DPを小規模全列挙と比較一致、床補正の合成例と固定キーでのフォールバック確認。
HTML MotionLab_V27_Subframe_Repair.html: デコピン原本/候補を4方向×主要5姿勢と修正3姿勢=64枚描画して視認。通常・半速の全尺再生4回成功、JS例外0。動作の見た目は維持。比較の他2動作は変更なし。独立SciPy実形状プレビューの結果であり、新Blenderアダプタの直接実行結果との一致、Godot/Android、連続衝突、実当たり判定は未確認。
再現: build.py -- の後に design out --trajectory-review heavy --subframe-guard を指定。trajectory_review.json に候補・修正量・240Hz最終床/支持目標達否を記録。既存ゲーム戦闘原本、CI、従来デフォルト未変更。参考: https://projects.staging.blender.org/blender/blender-manual/src/branch/main/manual/animation/keyframes/introduction.rst ; https://www.sciencedirect.com/science/article/pii/S009784931200146X
