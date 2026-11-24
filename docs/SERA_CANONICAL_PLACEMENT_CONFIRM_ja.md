# 正規配置確定
- Godotエディターから実行中の位置・カメラ編集は操作終了・ドラッグ終了時にプロジェクト内の .sera-placement/preview.json に保存。通常のプレイヤーセーブや製品ビルドとは別管理。
- 既存のTermux安全同期ワーカーに専用ブランチ送信を統合。端末側で一度 `git -C "$HOME/sera_repo" pull --ff-only && bash "$HOME/sera_repo/tools/termux/install_safe_sync.sh"` を実行して更新する。以後は既存の監視・120秒ポーリングにより送信。同期先は専用ブランチ sera-placement-preview、ファイル preview.json と source-head.txt のみ。通常のmainアップロードから除外する。source-headは同期時のローカルGit基準なので、正確な編集元と同一かも確認する。
- ChatGPTに「正規配置確定」と指示された場合、専用ブランチの最新の2ファイルを読み、source-head と main の関連コード差分、schema、対象ID、座標系、数値、updated_atを確認する。公式データ scripts/sera_canonical_placement_defaults.gd の RECORDS に新しいレコードだけ統合してmainへマージする。以前に確定したレコードを再適用しない。同期なし・競合・不明IDなら推測で反映しない。
- NEXUSの位置はglobal座標・yaw_rad。NEXUSのカメラは元の設備基準の座標（元の設備位置からの変換を適用するため、設備移動と独立して維持される）。DEPLOYMENTのカメラはglobal固定。LABO/REFINERY/STORAGEはstage_local、FOVは垂直角。NEXUSのFOVは端末補正前の基準値。
- 公式値は製品ビルドでも適用。未確定値はエディター実行時のみ、公式の更新時刻より新しい場合に適用。元のコピー操作は同期不能時の予備手段。
- 端末の既存スクリプトをChatGPTから直接変更できないため、上記インストールを一度実行する。SERA_startのrsyncに --delete がある場合は `--exclude=/.sera-placement/` を追加し、プレビューを削除しない。旧同期ワーカーのまま編集を開始しない。
