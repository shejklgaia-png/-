# PARTS FACTORY（パーファク）V6.1 — 全工程AI監修・再構築
2026-11-25 Vesper V1失敗への是正。V1/V2/V3/V4/V5のジョブは互換なし。旧データを破壊せず、新規V6作業ディレクトリに再登録する。単なる箱・円柱の組立を完成扱いしない。設計画が視覚的な正本。全身セットは先にセット全体のデザインを比較・確定し、その後6部位を独立制作する。ゲーム本体/既存モデル/無関係CIを変更しない。

## V3追加：設定画解析ブリッジ（必須）
- `python -m pip install numpy opencv-python-headless` は解析専用環境に導入。ゲーム依存には追加しない。
- blueprint受理後、各方向の独立二値マスクを手作業/画像解析で用意。`calibration.json` は format=SERA_PF_CALIBRATION_V3,resolution=512等(256..1024),scale_m,target_m=[x,y,z],views（10方向→{mask,mask_sha256,origin_px:[x,y],pixels_per_m,reason}）,landmarks（識別点名→{pixels:{view:[x,y]}}、3点以上、各2非平行視点以上）。origin_pxは共通world targetの投影点。画像は正投影・同姿勢を原則とし、不整合は作者判断で修正。マスクは0/255、元画像と同じ寸法。切抜き・寸法根拠を明記。モデルへの後合わせは禁止。
- `python tools/parts_factory/reference_bridge.py analyze <accepted_blueprint_dir> <calibration.json> <out>` → analysis.json、10方向正規化マスク/画像/既存モデスタstructure_analysisの領域・内部線・隣接・候補画像、multiview_partsの対応候補、断面包絡、対応ランドマークの3D最小二乗推定と残差。`factory.py accept <work> analysis <out> --producer ...`。曖昧な関連は候補のまま。矩形断面包絡は奥行きの上限の概算であり、正確な断面/凹部の復元ではない。
- planにはanalysis.jsonの完全コピーをanalysis_snapshot.jsonとして同梱し、structure_plan.jsonへreference_sha256、ambiguity_resolution、section_strategy、componentsごとのanalysis_evidence（view,kind=region/line/landmark/section/inferred,reference,interpretation）を追加。design.jsonはreview_resolutionを一致させ、review_camerasのfront/right/back/left/top/bottomを共通target/ortho_scaleと固定directionで設定（それぞれ[0,-1,0],[1,0,0],[0,1,0],[-1,0,0],[0,0,1],[0,0,-1]）。roll/quaternion/カメラfit禁止。landmarksに解析点名を既存モデスタの{node,local}形式で割り当てる。
- model許可にreference_sha256を付与。実制作ZIPのprojections.jsonも必ず保存。`reference_bridge.py compare <accepted_analysis_dir> <actual_model_dir> <out>` は実カメラとモデルの解析ハッシュを確認し6方向の輪郭IoU、不足/過剰ピクセル、最大距離、色分け重ね画像、ランドマーク投影残差、低IoU優先順位を出す。自動造形変更・自動審美評価はしない。
- geometry受理フォルダにcomparison.jsonと6方向overlayをコピーし、geometry_review.jsonのoverlaysをそのパスと一致させ、reference_limits（各方向→{min_iou:0.5..1,reason}）、landmark_disposition、correction_priorityを追加。閾値は対象別の設計意図に基づき明記。不合格ならplanへ戻る（元図面不整合ならblueprint/analysisへ）。閾値の後付け緩和を合格理由にしない。V6ストックのみ新規セットに採用可。
- 参考: Blender orthographic cameras https://docs.blender.org/manual/en/3.5/render/cameras.html ; Laurentini visual hull https://ieeexplore.ieee.org/abstract/document/273735/ 。輪郭一致と見栄えを分けて評価する。

## 作業順（強制ゲート）
各段階は実ファイルを別ディレクトリに置き、`python tools/parts_factory/factory.py accept <work> <stage> <source> --producer "<tool/version; provenance>"` で登録。新規ジョブは `init <work> PF-H003 head`。status / handoff で次の作業・入力ハッシュ確認。各工程のJSON契約は quality_gates.py / factory.py が正本。レビューは自己評価であり、画像/美観の自動認識ではない。

1. concept: V5のdesign_brief.jsonも必須（下記）。concept.json に id, slot, name, lore, mechanism, references, rig_target, proposed_stats。セット所属時は共通コンセプトの set_art_sha256 を追加。外部資料は公式・技術者・企業・実例から調査。正式性能値・新規効果は既存装備承認規約に従う。
2. art: 別台帳の明示画像生成作業で最低3つの異なるコンセプト画像。art_review.json に image_task_id, reviewer, selected, selection_reason, candidates（id/file/sha256/design_direction/rubric）。各rubricは appeal, identity, silhouette, mechanism, cohesion, readability の {score:1..5,reason:具体的記述}。選定画像は全項目4以上。selected.png は選定候補と完全一致。合格なしなら画像を再制作。スコアだけで審美性を保証しない。
3. blueprint: blueprint.png と独立PNG10方向（水平45度8方向＋上下）。blueprint_review.json に selected_art_sha256, image_task_id, reviewer, views（front/front_right/right/back_right/back/back_left/left/front_left/top/bottom → {file,sha256,notes}）, scale_and_axes, resolved_inconsistencies, rubric（projection_consistency, proportions, palette, mechanism, assembly_interface）。別画像生成工程として明示された依頼のみ行う。多方向の構造不整合は修正してから進む。
3a. analysis: 上記V3解析ゲートを受理。
4. plan: V5のdesign_brief_snapshot.jsonと知識適用判断も必須（下記）。design.json はモデスタ形式。structure_plan.json に blueprint_key, reviewer, rig_interface, silhouette_targets, detail_budget, components（feature, method_reason, mechanical_role, reference_coordinates, views, nodes）。各造形ノードを2方向以上の参照へ関連付ける。輪郭・内部構造線・断面・可動部・装甲分割の順。wireframe/loft/mechanism graphなどから対象に適した手法を選び、使用しない方式の理由も記録。部品数を品質の指標にしない。
5. model: `authorize-model <work> tools/modeling_studio/pf_<id-lower>.json` を実行し許可付き入力を生成。既存モデスタの専用PRブランチ `modeling/parts-factory/<id-lower>` へそのJSONをコミットしてPR作成、または既存専用workflow_dispatchで指定。CRATE特化反復禁止。モデスタbuild.pyはpf_ファイルまたはparts_factoryマーカーの許可・入力整合を検査。実成果物ZIPを回収し、BLEND/GLB/設計/mesh_report/complete/review/godot_import/interference/8方向PNGと、provenance.json（tool="Modeling Studio - authoring render", commit, run_id, artifact_id, glb_sha256）を受け入れる。証跡は実runから記録する。
6. geometry: 実モデルと正投影設計図の重ね合わせ（前後左右上下）と全8実レンダーを確認。geometry_review.json: model_glb_sha256, blueprint_key, reviewer, views（front/front_3q/right/back_3q/back/left/top/bottom → {file,sha256,notes}）, overlays（前後左右上下のview名→比較画像パス）, rubric（appeal/silhouette/proportions/armor_language/mechanism/rig_clearance/detail_balance）, blocking_issues=[], comparison_notes, iteration_notes, unresolved_interference=0, interference_notes。意図的接合と問題干渉を分類し、寸法/可動域/武器接地等を実評価する。すべて4以上かつ阻害要因なしが必要。
7. uv: テクスタAI手動の実成果物。uv.json（method=AI_MANUAL_FACE, source_glb_sha256, reviewer, rubric=quad_orientation/shared_edges/texel_density/padding）、uv_model.glb。面基準と境界整合を確認。
8. paint: 512/1024/2048 PNGと埋込テクスチャ付きmodel.glb、paint.json（source_uv_glb_sha256, painted_glb_sha256, reviewer, rubric=panel_language/mechanical_detail/light_direction/readability）。上方光源・面を跨ぐパネル・暗色機構を意識し、全解像度と継ぎ目を確認。
9. review: 塗装済GLBそのものの全8実画像と review.json（painted_glb_sha256, blueprint_key, reviewer, views, rubric=appeal/identity/cohesion/silhouette/mechanism/uv_seams/texture/rig/performance, blocking_issues=[], comparison_notes, iteration_notes, notes, checks=旧V1の6項目accepted）。形状・質感・機構・実ゲーム予算の整合を評価。未確認は合格にしない。
10. viewer: `python tools/parts_factory/painted_viewer.py <work> <out>` で塗装済HTML生成。viewer_review.jsonに対象ハッシュ・reviewer・texture_display/touch_controls=acceptedを実確認後に記録。WebGL簡易照明・Godotと非同等。実機未確認は明示。
11. stock: `factory.py stock <work>` 後 `factory.py deliver <work> <output.html>` の順。全段階の受理とストックの完全性がなければ正式HTML配布不可。ストックは `parts_stock/<slot>/<id>/<revision>/`。GitHubへ永続保存した時点で永続ストック完了、Actionsの期限付き成果物だけでは不可。ゲーム登録は別手順。

## 不合格・再制作
`factory.py reject <work> <stage> --reason "具体的な欠陥・修正案"` で該当段階以降を失効、旧ファイルはobjects、不合格理由はrejectionsに保存。例えば造形不合格ならmodelだけでなくplanから修正する。選定画像/設計図/設計JSON/モデルGLB/塗装GLBの同一バイト成果物は再承認不可。修正は外形、構造、ディテール、塗装の優先順。未達を点数操作で通さない。初回候補を完成品として提出禁止。ユーザーが途中経過を明示要求した場合のみ「未完成」として候補を区別して共有。作業時間や権限等の制約で中断したら、最後に通過したゲート、具体的な阻害要因、残り工程を明記。非同期の完了約束をしない。

## セット制作
全身候補3案以上から選定（artと同じ契約）。共通art SHAを各部位のconceptへ設定し、頭、胴、両腕、下半身、右武器、左武器の6独立IDで上記工程を完了する。各部位は独立で反復可能。セット完成時に `python tools/parts_factory/set_release.py <source> <output.html>` を使用。sourceには art/（上記art一式）、set.json（format=SERA_PF_SET_V2,id,set_art_sha256,parts={head/body/arms/legs/weapon_r/weapon_l:{id,revision}}）、実assembly.glb、assembly_review.json（part_glb_sha256:各roleの塗装GLBハッシュ、assembly_sha256, views, rubric=appeal/cohesion/proportions/joint_clearance/weapon_clearance/texture_consistency/performance, notes, reviewer, blocking_issues=[]）、8方向実画像、viewer.html、viewer_review.json（assembly_sha256,viewer_sha256,reviewer,texture_display/touch_controls=accepted）。各部位のストック整合、セット配色、全身バランス、武器干渉を確認してからセット保管・配布。組立GLBの生成そのものはモデスタ/既存リグに従う別制作操作。

## 技術境界
ゲートは登録経路・許可付きモデル入力・正式出力を制御するが、任意の別名JSONで従来モデスタを直接使う行為を全体禁止するものではない。許可は署名付き認証ではなく、受理済みローカル記録と入力を結ぶ整合性メタデータ。ChatGPTが全工程の実行・証跡採取・審美評価を誠実に行う必要がある。画像生成API、GitHub dispatch、テクスタAI手動、自動組立/ゲーム登録のAPIは未接続。専用PR経路は追加済み。V3実データ通し制作・ブラウザ検証は未実施。既存CI/テスト禁止維持。
参考: Pixar concept→model https://sciencebehindpixar.org/pipeline/modeling ; Disney visual development→model https://www.disneyanimation.com/process/modeling/ ; Blender Studio review/approval https://studio.blender.org/tools/overview/design-principles ; task layers https://studio.blender.org/tools/addons/asset_pipeline

## V4：モデスタ→テクスタ原面連携（必須）
画像生成AIによる塗装ではなく、AIが原面UV・材質・モデル座標レイヤーを手動設計し、既存Texture Studio AI pipelineが描画する。元BLENDのポリゴン/ループID、三角化対応、部品名・親・行列・材質を保持。Z上からY上への座標変換は(X,Z,-Y)、UVはV下。既存ゲーム、モデル正本、Godot内テクスタUIは変更しない。制作済みBLENDに対するオフライン処理のみ。Blender 4.5とPython 3.10+（numpy scipy Pillow shapely>=2）を使用。ライブモディファイア、シェイプキー、共有メッシュ、負スケールは拒否。必要ならモデスタ側で承認済モデルを修正し再取得する。パーツ254、原面65534のID上限。モデル正本を変更しない。

1. `python tools/parts_factory/texture_bridge.py prepare WORK HANDOFF --blender blender` — geometry受理済みBLENDを開き、face_geometry.json/handoff.jsonを出力。元ファイルのハッシュと受理済みgeometry revisionを固定。新規フォルダのみ。
2. AIがface_geometry.jsonを読み、全原面の手動UVを設計。uv_layout.json は {"format":"SERA_PF_MANUAL_UV_V4","method":"AI_MANUAL_FACE","geometry_sha256":"...","faces":{"0":{"uv":[[u,v],...],"chart":0,"reason":"配置・向き・境界の具体的根拠"}}}。各原面の全ループ順を厳守、三角対角線を切断しない。対称/方位、面積、接続、パネルライン継続性を考慮。UV島内連結は同一コーナー座標、島間は十分な余白を確保。自動レイアウトによる代替は禁止。
3. `texture_bridge.py validate HANDOFF uv_layout.json UV_DATA` — UV三角の退化/原面内反転/正面積重複（Shapely 2 STRtree、許容1e-10）と同一島共有辺の座標を検査。島間共有辺の長さ比、面積ベース密度を記録。元面グループ付きmesh.json、uv_metrics.json出力。余白の適否・島間位相・意図した左右反転・美観は手動確認が必要。エラー時はレイアウト修正。 
4. `texture_bridge.py export WORK HANDOFF UV_DATA UV_ACCEPT --blender blender` — 元BLENDを読み、同じコーナーへUVを適用してuv_model.glb・uv.blendを別出力。ハッシュ連携と階層保持。生成uv.jsonのreviewer/rubricを実UV確認後に記録し `factory.py accept WORK uv UV_ACCEPT --producer ...`。自動合格しない。
5. AIが既存ai_pipeline.pyのplan仕様でsurface_plan.jsonを作成。geometry_sha256はuv_metrics.jsonのpainter_geometry_sha256。face_materialは原面順、paletteはRGB、layersはparts/faces/materialsで範囲を明示する。位置/法線と原面を基準に装甲パネル、凹凸・機構・締結点、上方照明を描く。元モデルの形状・接続部を保持。既存ai_surface_toolsのinspect等も補助利用可。
6. `texture_bridge.py bake UV_ACCEPT surface_plan.json BAKED` — 同一の設計レイヤーから512/1024/2048を個別ベイク。上限4096サンプル辺、同材質の3D隣接パディング、既存テクスタの色差比較・IDマップ。V4 bridgeは基礎ai_pipelineの直接接続であり、仮想凹凸V3/接触遮蔽V4の追加ベイクは未統合。3解像度の成果物と各reportをbake_manifestで束ねる。
7. `texture_bridge.py export WORK HANDOFF UV_ACCEPT PAINT_ACCEPT --baked BAKED --size 1024 --blender blender` — 元BLENDへ受理済UVを再適用し、元材質のコピーにテクスチャを結線、GLBへ内蔵。実GLB全プリミティブのbaseColorTexture/TEXCOORD_0を確認し、埋込画像をデコードして採用PNGとRGB画素完全一致を要求する。painted.blendと3解像度PNG、報告を出力。paint.jsonのreviewer/rubricは実塗装確認後に記録。factory.py accept paint へ。その後も実8方向レビュー、正式HTML、ストックを省略不可。動的光とベイク光の重複、ミップ、性能は別評価。
8. 画像やモデルが未取得・工程が未承認の場合は停止。不合格時はUVまたは塗装へ戻る。正式リリースと候補共有を混同しない。
参考：Blender Mesh loops https://docs.blender.org/api/current/bpy.types.Mesh.html ; Substance 3D Painter 3D Space Neighbor https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/interface/texture-set/texture-set-settings ; Shapely STRtree https://shapely.readthedocs.io/en/stable/strtree.html 。V4通し制作未確認、外部アプリの自動操作ではなくCLI連携。

## V5：SERA設計知識ライブラリ（必須）
design_library/seed.json は初期12件。設計原則4、構造・塗装参考6、失敗1、技術改善証拠1。装甲/関節/機構/センサー/推進器/塗装/接続/制作原則/失敗のカテゴリを持つ。完成品モデルの自動複製ではなく、機能・適用方法・検査項目・禁止事項・資料・限界・確認水準を保存する。referenceは参考、technical_evidenceは特定事例の技術的観測、failureは不採用知見、guidelineは制作ルール、candidateは未採用の知識候補。参考や技術改善を完成品承認と混同しない。

- `python tools/parts_factory/design_knowledge.py list --slot head` で現行知識を表示。
- `python tools/parts_factory/design_knowledge.py brief head "角張った 装甲 バイザー 関節" CONCEPT/design_brief.json` で部位適用可能な最新リビジョンを検索。スペース/読点で検索語を区切る。全必須ルール・失敗知見を常に含め、タグ/名称/説明への部分一致で参考を上位にする。候補知識は除外。参考件数は--limit（既定8）。意味検索や類似画像検索ではない。
- concept受理時は、必須項目の欠落、旧版/不明な参照、内容ハッシュの改変を拒否。ライブラリの全文スナップショットを工程ハッシュに含める。受理後にライブラリが更新されても、進行中ジョブの過去の判断は勝手に変えない。最新規約の取り込みが必要ならconceptから再受理する。
- planでは受理済みdesign_brief.jsonをバイト一致でdesign_brief_snapshot.jsonへコピー。structure_plan.jsonのknowledge_dispositionに全参照キー（例 JOINT-HOLLOW@1）を `{"decision":"applied|not_applicable|avoid","reason":"具体的理由"}` で記録。必須guidelineはapplied、failureはavoidまたは根拠付きnot_applicable。各componentへknowledge_refs（適用したID@revision配列）とoriginal_design_reasonを記載。少なくとも一つの参考を実部品へ対応させる。原画と知識が矛盾する場合は原画・最新ユーザー仕様を優先し理由を記録。失敗の形状を流用しない。
- 既存モデスタのレシピ/テクスタのレイヤー関数を適切に選ぶための資料。自動形状注入、既存モデルの無断コピー、未検証の寸法・性能値の転用は行わない。部品別の設計図、実形状/塗装レビューは従来通り必要。
- 学習候補: `design_knowledge.py learn WORK failure NEW-ID armor lesson.json --source WORK/rejections/<hash>.json --reason "具体的な再発防止理由"` または `learn WORK success NEW-ID paint lesson.json --reason "再利用できる技術と適用条件"`。成功は全承認かつストック整合を要求、失敗は実ジョブの拒否記録を要求。候補には元制作ID・成果物revision/レビューSHAまたは拒否SHA/内容を記録する。生成先はライブラリ外。自動昇格禁止。
- キュレーション: 作者が候補の証拠・適用範囲・限界を確認し、design_library配下へ新しいJSON（format=SERA_DESIGN_LIBRARY_V5, entries=[...]）を追加してGitHubへコミット。seedと同じスキーマ（id,revision,category,state,slots,mandatory,title,tags,intent,application,checks,avoid,sources,limitations,review）。修正は同一IDのrevisionを増やし旧記録を保存。ID@revision重複は禁止。採用技術と作品承認は別。自動学習・自動承認・自動メッシュ生成は未実装。
- 参考: Blender Studio modeling https://studio.blender.org/tools/artist-guide/asset-creation/modeling ; Adobe Texture Set settings https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/interface/texture-set/texture-set-settings ; HONPINE hollow shaft actuator公式資料（seed内）。V5実ジョブ通し制作未実施。ゲーム・正本・無関係CI無変更。

## V6：制作・評価コンテキストの分離（必須）
制作担当: designer（concept/art/blueprint）、engineer（analysis/plan）、modeler（model/geometry）、texture_artist（uv/paint）、production_coordinator（review/viewer）、assembly_artist（set）。全工程の受理ディレクトリにauthor.jsonを置く。{"format":"SERA_PF_REVIEW_V6","stage":"geometry","role":"modeler","actor":"実担当ID","context_id":"実制作チャット/セッション識別子","kind":"ai"}（人ならhuman）。架空のセッションIDを発行して独立審査を装わない。

- アートディレクター(art_director)：魅力、独自性、シルエット、プロポーション、意匠の主従、塗装の視認性を評価。
- 技術監査(technical_auditor)：設計根拠、形状、接続、UV、実GLB、描画予算、実操作・配布などを評価。
- art/blueprint/plan/geometry/paint/review/setは両方の承認必須。uv/viewerは技術監査必須。concept/analysis/modelは作者記録と既存の技術ゲート、後続で独立審査。既存自己評価・数値ゲートも維持し、独立レビューで上書きしない。
- 作者は全成果物（自己レビューJSONを含む）を固定してから `python tools/parts_factory/review_roles.py packet WORK geometry SOURCE PACKET_ART --role art_director` および別ディレクトリへ `--role technical_auditor` を作る。setは `set-packet SOURCE PACKET --role ...`。allowlistに従って実画像・GLB・必要な上流資料/数値報告をコピーする。候補画はSHA順の匿名ファイル名とし、作者選定・自己採点JSONを含めない。構造計画のトップレベル自己評価情報も除去。素材自体に作者の説明等が残る可能性があるため完全匿名ではない。
- 各担当は別チャット/独立コンテキストへそれぞれのPACKETのみ渡す。request.jsonと実証拠ファイルを確認、response_template.jsonを埋める。reviewer.actor/context_id/kindは実在する担当・実際の文脈IDを記録。独立性を確認した場合だけindependent_context_attested=true。verdict=approve/reject/unverified。全criteriaのscore(1..5)、具体的reason、evidence（requestのpacket内相対パス）、blocking_issues、revision_adviceを記載。artは承認時に選んだ候補画像のSHAを記載。別の案を選んだ場合、作者選定と合わなければ再審査。承認には全項目4以上かつ阻害要因0。未確認はunverified。レビュー時に作者や他評価者の採点を見ない。
- 回収した応答をSOURCE/independent_reviews/art_director.json、technical_auditor.jsonへ置き、factory.py acceptで既存チェックと独立審査を同時適用。各応答は候補一式・上流revision・パケット証拠SHAと紐付く。作者/上流制作担当/他審査者とのactor・context ID重複を拒否する。変更後は旧応答を使えない。setも承認済6部位GLBと作者記録を参照する。
- 不合格/未確認時は `review_roles.py veto WORK STAGE SOURCE` で未受理候補の評価をreview_vetoesへ保存。両審査が必要な段階では両方の応答を揃える。明示rejectがある場合、同じ上流・同じ公開証拠の再承認を拒否する（記録済vetoのみ）。既存factory rejectと併用して根本工程へ戻る。未確認は追加確認により再評価可能。status/handoffで役割、未完了工程、veto履歴を確認できる。ストックへvetoを保存。
- 技術境界：別AIや別チャットの自動起動は未接続。名前・context ID・独立性は申告と運用に依存し、署名・認証・別モデル強制ではない。独立審査の実行が不可能なら承認を捏造せず未完了とする。評価の正しさ・審美性は自動保証しない。V6実制作・実行検証は未実施。
- 参考: Blender Studio review/approval https://studio.blender.org/blog/asset-pipeline-update-2022/ ; Kitsu role workflow https://studio.blender.org/tools/pipeline/operations/kitsu ; NASA dual-anonymous review https://science.nasa.gov/researchers/dual-anonymous-peer-review/ 。制作・承認の分離と、先入観を減らすための証拠中心の審査に応用。異分野の審査結果をゲーム品質の保証に使わない。


## V6.1（最優先）：全工程で初稿→AI監修→再構築→再審査
V6の記述と矛盾する場合は本節を優先。concept/art/blueprint/analysis/plan/model/geometry/uv/paint/review/viewerの全11工程とset組立に適用。concept/analysis/modelにも独立審査を追加。従来の審査担当・技術ゲートを残し、全審査担当はAIかつ実際の独立コンテキストを使用する。初回承認だけでは受理不可。未確認・審査未実施は停止する。

1. DRAFTに初稿とauthor.jsonを用意し、review_roles.py packet WORK STAGE DRAFT OUT --role ROLE（セットはset-packet）で必要な役割ごとに独立審査。初稿の良い点・欠点・改善指示・根拠を記録。実画像・実GLB・UV・HTMLは実際に開いて確認する。採点だけで合格としない。paintも塗装済GLBの8方向実画像を必須とする。
2. 初稿のindependent_reviewsに実際のAI応答を保存。評価を制作担当へ渡し、外観・構造・機能・効率の根本的改善を優先して実ファイルを再制作。必要なら元のコンセプト・図面・計画へ戻し、以降を失効させる。初稿の採点変更・再命名・形式的微修正を再構築としない。
3. FINAL/supervision/draft に初稿と初回審査の完全コピーを置く。初稿の中に別のsupervisionを入れない。FINAL直下に再構築した成果物、author.jsonを用意。review_roles.py cycle-template WORK STAGE FINAL（セットはset-cycle-template FINAL）で reconstruction.json のテンプレートを作成。各監修担当へのresponse/method/resolved_issues/evidenceを具体的に記入し、すべての阻害要因に対処した根拠を最終成果物のパスで指定する。
4. FINALに対するpacketを新たに作成し、独立AIに最終審査を依頼。前後の実資料がパケットに含まれ、初稿の採点・評価回答は原則含まれない。制作担当と審査担当のコンテキスト・担当の重複を禁止。最終審査は全基準4以上かつ阻害要因0。前回の審査JSONの流用不可。再不合格は別の候補を制作し直す。初稿・途中の不合格は別途保管する。
5. factory accept / set_release で初稿と最終審査、差分、上流、再構築記録のハッシュ整合を強制。主成果物の意味ある変更が必要。geometry/reviewのような検査工程では検査内容と根拠の再構成を対象とし、実モデルに問題があればplan/model/paint等へ戻る。モデルの決定的生成だけは、初稿が全承認で実行runとartifactのIDが異なる実再ビルド記録があるときに同一GLBを許容する。ハッシュ差分だけで改善を保証しない。
6. V6.1以前に受理した工程は新規ジョブから再制作。旧ストックを削除しないが新規セットには使えない。初稿を含むためストック容量増加に注意。全工程と組立を通過してから正式配布。ゲーム登録は別指示。

技術境界：審査応答・run IDは申告された証跡であり認証や実行の自動検証ではない。独立AIの起動、実アプリ操作は未接続。実行できない場合は未完了として報告し、架空レビュー・再制作を禁止。CI/既存ゲーム/既存モデルには手を加えない。V6.1の通し実制作は未検証。
参考：Blender Studio Kitsu https://studio.blender.org/tools/pipeline/operations/kitsu ; Asset Pipeline https://studio.blender.org/blog/asset-pipeline-update-2022/ ; Pixar制作レビュー事例 https://review.firstround.com/lessons-from-pixar-why-software-developers-should-be-storytellers/
