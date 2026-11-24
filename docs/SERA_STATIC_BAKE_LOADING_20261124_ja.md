# SERA 静的ベイク・ロード最適化（部分ベイク）
- BASE床・GRID固定盤面・NEXUS床・LABO/精製/倉庫/粉砕共通屋外床を、実描画ノードのPackedSceneとして端末内の user://sera_static_bake_v1 に保存。次回はバイナリをロード。静的ノードの所有権を一時設定して保存後復元。
- BASE施設は形状バケット・Transform3D・輪郭役割・可動部インデックスの初期データを保存。共通ポリゴンArrayMeshをバイナリ.resとして保存。大きな設備の描画専用バッチは初期姿勢のPackedSceneも保存する。読込時にバケット名・インスタンス数を検査し、可動MultiMeshへの参照を新規ノードに再接続する。小さな部品は生成のまま。
- LABO系の大型バッチも固定ローカル形状をベイクし、可動ノードの親子階層は従来コードで構築する。最初に要求された作業場だけ構築、別画面は初回遷移時に同期構築し以後同じ独立ノードを保持。搬入、クレート、プリンター、精製、倉庫の既存motion/logistics/placement処理を維持。
- 固定床のMultiMeshは公式12-float row-major一括転送。カスタムIDを持つ設備の既存インデックス処理は変更しない。
- 入力ファイルのSHA-256と正規配置・小物データ、エンジン版で無効化。取得不能・破損・未インポート時は既存生成へ戻す。headlessではレンダーキャッシュを作らない。旧キャッシュは同一スロットのみ差替え。セーブデータと別ディレクトリ。
- これは端末内初回生成型の部分ベイク。初回起動は保存コストが加わり得る。NEXUSの追加固定内装5系統もキャッシュ対象。配布時に全シーンを事前生成した成果物や、NEXUS機器・LABO各作業場の全モデルベイク、固定部のメッシュ結合、物流経路キャッシュはまだ未実施。CI・実機テスト未実施。
- 参照: https://docs.godotengine.org/en/4.7/classes/class_packedscene.html
  https://docs.godotengine.org/en/latest/classes/class_resourceloader.html
  https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html
  https://docs.godotengine.org/en/latest/classes/class_renderingserver.html

- 後続変更：ユーザー再指示でロード分散を復活。BASEの60ms協調分割、床ベイク非同期読込・未ベイク床の純データ計算ワーカー、NEXUS入場時の工程分割。キャッシュの初回保存は同期のまま。

## BASE操作開始後のLABO系先読み（2026-11-24）
- 対象はLABO・SMELTER・STORAGE。BASE起動完了後0.8秒の操作可能な通常俯瞰から開始。共通PackedSceneはResourceLoaderの非同期リクエスト。表示中メニュー・GRID・正規配置・入退出中は新規工程を停止。
- 同じ既存Hero SubViewportに共通床、遠景、コンテキストルートを個別工程で生成し、各作業場をノード初期化、機器、床/外装、機構/物流の4工程に分割して約160ms間隔で進める。描画ノード生成はメインスレッド。各工程内部は同期で上限保証なし。
- 部分構築の部屋をready扱いしない。ユーザーが先読み途中で開いた場合、その部屋の残工程を同期完了して既存set_sectionを一度実行、正規配置・カメラ・ナビゲーション・搬入開始を従来どおり処理。粉砕機は必要時構築。生成済みの部屋は再利用。
- 非表示時はHeroのprocess_mode、描画更新、ID描画ターゲットを停止。部屋単位でも非選択時は非表示/停止。初回の枠線登録・GPU描画・経路探索は実メニューで行うため、全ての初回待ちを除去するものではない。メモリ増加、実機時間・FPS未計測。CIなし。
- 参考: https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html ; https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html ; https://forum.godotengine.org/t/understanding-and-smoothing-resource-management-of-godot-4/95761

## BASE完了前の常駐ロード（2026-11-24・PR1202の後継）
- 起動後0.8秒/160ms間隔の先読みを廃止。BASEロード画面の実完了条件にLABO・SMELTER・STORAGEの全ルーム生成を追加。NEXUSからの帰還時も同じ処理。
- 既存協調ロード予算を利用。共通床、遠景、各室の構築を行い、正規配置とクレート用経路探索グリッドを各室ごとに準備。切替時は同じノードとグリッドを再利用し、正規配置変更で該当グリッドを失効。
- アニメーションは停止したまま各室を選択・描画ウォームアップ要求。実メニューだけで搬入を開始。非表示時はHero/ID描画停止。GL Compatibilityの実際の描画・シェーダーキャッシュ効果は未確認。
- 起動時間とRAMは増加し得る。単一処理や初回GPU描画・UI構築によるカクつきが完全になくなる保証はない。粉砕機は対象外。CI・実機未実施。
- 参照: https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html ; https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html ; https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html
