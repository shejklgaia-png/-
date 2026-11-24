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
