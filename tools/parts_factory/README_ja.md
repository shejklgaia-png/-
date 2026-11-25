# PARTS FACTORY（パーファク）V1
制作統括CLI。新規モデルをゲームに直接上書きしない。Python 3.10+ 標準ライブラリのみ。ユーザー指示「パーファクでヘッドを3種類制作」から、ChatGPTが個別ID・設定・外部調査・設計図・制作・評価・ストック・必要ならゲーム登録を一括統括する。CLIはAIを呼び出さず、各担当工程の実成果物を受け渡す。複数IDは独立作業ディレクトリで並行可能。同一IDの作業は単一担当で直列、ストック先へのGitコミットは直列。無関係CIは実行しない。

## 運用
1. 最新main・台帳・models/manifest.json・MODEL_PART_WORKFLOW・装備規約を確認し、未使用の制作ID（例 PF-H003）を割り当てる。ゲーム設計図IDとは別管理。既存作品とのシルエット・設定重複を確認。設定には名称・背景・機構・部品別外部調査URL・骨格/接続先・仮性能を記載。性能確定は既存装備承認規約に従う。
2. python tools/parts_factory/factory.py init /tmp/pf-h003 PF-H003 head
3. 工程ごとに実ファイルを別ディレクトリへ用意し、python tools/parts_factory/factory.py accept /tmp/pf-h003 concept /tmp/concept --producer "ChatGPT; source SHA; reference URLs" のように登録。status / handoff は次工程・入力ディレクトリ・ハッシュを出す。
4. blueprint: ユーザーの制作指示に含まれる明示画像生成工程として別台帳作業に登録。水平45度刻み8方向・正投影前後左右上下、配色、構造注記。生成画の矛盾は設計意図に沿い修正可。実装作業中の無関係画像生成は禁止。設計JSONはモデスタ形式。
5. model: design.json を tools/modeling_studio/ 配下の専用入力としてコミットし、既存 Modeling Studio - authoring render の workflow_dispatch で design を指定（iteration_mode=false）。成果物 sera-modeling-review を回収し、実レンダリングと形状を確認。既存CRATE特化反復を流用しない。BLEND/GLB/レポートを登録。実行コネクタにdispatch権限がない場合は実行できる経路を確保するまで停止、架空の結果で先に進めない。
6. uv: テクスタAI手動。四角面基準、共有辺の方向・位相・長さ、面をまたぐパネルライン、隣接面パディング。uv.json に method=AI_MANUAL_FACE, source_glb_sha256 と実際のUV評価を記載、uv_model.glb と共に登録。三角化で面グループを崩さない。UVの改変は元モデルに逆流させない。
7. paint: 機構・装甲・陰影をAI手動設計、512/1024/2048の正方形PNG、埋込テクスチャ付きmodel.glb、paint.json（source_uv_glb_sha256, painted_glb_sha256）を登録。ゲーム標準の解像度・描画予算は対象別に決める。必要なら原画・編集元も同梱。
8. review: 塗装済みGLBそのものを8方向レンダリングし、review.json に painted_glb_sha256、reviewer、notes、checks（silhouette/mechanism/uv_seams/texture/rig/performance）を記録。各項目acceptedは実評価後のみ。数値基準は接続先・現行モデル・スマホ描画予算を根拠に記録。破綻時は該当工程に戻す。未確認は合格にしない。
9. viewer: 塗装済みGLBとテクスチャを含む単体HTMLを作成。モデスタ既存offline_viewer.pyは材質色だけでUVテクスチャ非対応のため最終合格に使わない。実際の塗装・タッチ回転/移動/拡縮を確認し、viewer_review.jsonに painted_glb_sha256, viewer_sha256, reviewer, texture_display=accepted, touch_controls=accepted を記録。HTML配布規約に従い実ファイルを渡す。実機未確認なら別記。
10. stock: python tools/parts_factory/factory.py stock /tmp/pf-h003。parts_stock/<slot>/<ID>/<最終工程SHA256>/ に各段階の元データを保存。GitHub Actionsの期限付きartifactだけを正本にしない。GitHubへコミットして初めて永続保管。大容量ファイルは既存リポジトリのLFS/保管方針・権限を確認し、利用できなければ保管未完了と明記。Godotから隔離。
11. ゲーム登録: stockはゲーム実装とは別状態。ユーザーの指示範囲が実装までの場合、現行Blockbench正本・関節・装備フォーム・LABO・倉庫・NEXUS・保存形式・実モデル由来アイコンを既存手順に沿って登録。GLB→bbmodelの変換は互換性未確認なので自動上書きしない。正式性能/アイコンの承認規約は維持。マージと実機確認を分けて報告。

## 技術的連携
- 工程ごとに入力・成果物・制作元のSHA256連鎖。ハッシュ一致なら登録を再利用、改変なら下流だけ失効。旧候補はobjectsに保持し再選択可能。ファイル一覧とハッシュを照合し欠損や混在を拒否。
- 受け渡し契約はfactory.pyのSTAGESを参照。paint.jsonも必須。PNGヘッダー・GLBヘッダー/埋込画像・レビュー対象ハッシュを検査。ただし画像の美観・GLB完全仕様・虚偽のレビュー記載まで機械的に保証するものではない。
- 制作物は仮ディレクトリから同一ファイルシステム内で確定。履歴を上書きしない。依存が変わらない工程は再生成不要。不要な候補の永続ストックはしない。
- V1は人間/ChatGPTオーケストレーションのCLI。画像生成API、Actions dispatch、UV自動変換、塗装済み3Dビューワー生成、ゲーム登録を自動実行するアダプターは未接続。工程を止めずに完了扱いする機能は設けない。
- 技術資料: Godot glTF https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html ; Unity依存ハッシュ https://docs.unity3d.com/en-us/engine/6000.3/script-reference/UnityEditor.AssetDatabase.GetAssetDependencyHash.html ; 増分ビルド https://docs.unity3d.com/en-us/engine/6000.3/manual/assets-and-media/assets-managing-runtime/assetbundles-section/creating/asset-bundles-building ; 既存モデスタREADME。
