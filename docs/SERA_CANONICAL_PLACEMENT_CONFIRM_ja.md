# 正規配置確定
- Godotエディターから実行中の位置・カメラ編集は操作終了・ドラッグ終了時にプロジェクト内の .sera-placement/preview.json に保存。通常のプレイヤーセーブや製品ビルドとは別管理。
- Termuxの既存Git同期操作の pull より前に、SERAリポジトリ内で `bash tools/sync_placement_preview.sh` を実行する（初回はTermuxの既存Git認証とGitコミット作者設定を利用）。同期先は専用ブランチ sera-placement-preview、ファイル preview.json と source-head.txt のみ。main・作業ツリー・インデックスは変更しない。
- ChatGPTに「正規配置確定」と指示された場合、専用ブランチの最新の2ファイルを読み、source-head と main の関連コード差分、schema、対象ID、座標系、数値、updated_atを確認する。公式データ scripts/sera_canonical_placement_defaults.gd の RECORDS に新しいレコードだけ統合してmainへマージする。以前に確定したレコードを再適用しない。同期なし・競合・不明IDなら推測で反映しない。
- NEXUSの位置はglobal座標・yaw_rad。NEXUSのカメラは元の設備基準の座標（元の設備位置からの変換を適用するため、設備移動と独立して維持される）。DEPLOYMENTのカメラはglobal固定。LABO/REFINERY/STORAGEはstage_local、FOVは垂直角。NEXUSのFOVは端末補正前の基準値。
- 公式値は製品ビルドでも適用。未確定値はエディター実行時のみ、公式の更新時刻より新しい場合に適用。元のコピー操作は同期不能時の予備手段。
- 端末上のAutomate/Termux設定をChatGPTから直接変更することはできない。既存の同期コマンドに上記1行を追加すると自動連携する。
