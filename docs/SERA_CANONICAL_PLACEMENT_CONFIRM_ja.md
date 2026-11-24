# 正規配置確定
- Godotエディターから実行中の位置・カメラ編集は操作終了・ドラッグ終了時にプロジェクト内の .sera-placement/preview.json に保存。通常のプレイヤーセーブや製品ビルドとは別管理。
- 既存のTermux安全同期ワーカーに専用ブランチ送信を統合。端末側で一度 `git -C "$HOME/sera_repo" pull --ff-only && bash "$HOME/sera_repo/tools/termux/install_safe_sync.sh"` を実行して更新する。以後は既存の監視・120秒ポーリングにより送信。同期先は専用ブランチ sera-placement-preview、ファイル preview.json と source-head.txt のみ。通常のmainアップロードから除外する。source-headは同期時のローカルGit基準なので、正確な編集元と同一かも確認する。
- ChatGPTに「正規配置確定」と指示された場合、専用ブランチの最新の2ファイルを読み、source-head と main の関連コード差分、schema、対象ID、座標系、数値、updated_atを確認する。公式データ scripts/sera_canonical_placement_defaults.gd の RECORDS に新しいレコードだけ統合してmainへマージする。以前に確定したレコードを再適用しない。同期なし・競合・不明IDなら推測で反映しない。
- NEXUSの位置はglobal座標・yaw_rad。NEXUSのカメラは元の設備基準の座標（元の設備位置からの変換を適用するため、設備移動と独立して維持される）。DEPLOYMENTのカメラはglobal固定。LABO/REFINERY/STORAGEはstage_local、FOVは垂直角。NEXUSのFOVは端末補正前の基準値。
- 公式値は製品ビルドでも適用。未確定値はエディター・APKとも、公式の更新時刻より新しい場合に適用。元のコピー操作は同期不能時の予備手段。
- 端末の既存スクリプトをChatGPTから直接変更できないため、上記インストールを一度実行する。SERA_startのrsyncに --delete がある場合は `--exclude=/.sera-placement/` を追加し、プレビューを削除しない。旧同期ワーカーのまま編集を開始しない。

- BASE屋外施設は `base/facility/<ID>`（NEXUS, LABO, SCRAP_COLLECTOR, SMELTER, RECYCLER, GENERATOR, STORAGE, BUILD_TERMINAL）、`space: base_local`、`position: [x,0,z]`、`yaw_rad`（既存モデルの向きからの追加Y回転）。確定時はこのキーと座標系を検証して共通 RECORDS に統合する。編集はXZ各0.25mとYaw各5度のみ。小物・スクラップの再配置制限は保存済み施設位置と回転に追従する。物流・電源配線・踏み台・経路は既存の固定座標を保持する。床板自体は再生成しない。

## APK対応とLABOモデル（2026-11-24）
- APKの `user://.sera-placement/preview.json` を消さず、起動後に既存の記録を含め、ローカルHTTP受信機 (127.0.0.1:18743) に非同期送信。Termux未起動時は保存を維持し30秒後再試行。変更確認は5秒周期、ドラッグ中の書き込みなし。APK更新は同じ署名・パッケージで上書きし、アンインストールしない。
- Termuxは一度上記インストーラー更新が必要。監視ワーカーの子プロセスとして受信機を起動し、Termuxの非公開ホームに `.sera_apk_placement.json` を原子的に保持する。受信機は端末内限定・配置JSON専用でGit操作や認証情報を扱わない。端末上の他アプリからの偽造を暗号学的には認証しないため、正式確定前に対象・数値・更新時刻を確認すること。
- 既存の120秒監視でエディター・APK・専用ブランチの記録をキー別updated_atで統合し、mainには送信しない。source-headは同期時のローカルGit基準で、APKのビルド元や各レコードの正確な編集元を保証しない。
- ローカル受信とGitHub送信成功は別。APKログには受信状態、Termuxの `~/sera_auto_push.log` には `Placement preview synced:` またはエラーを記録。最終確認は専用ブランチのpreview.jsonを取得して行う。
- LABO/REFINERY/STORAGEのモデルは `labo/model/<section>/<stage-relative-node-path>`、space=parent_local、positionとrotation_degreesの3要素配列。操作完了・退出・一時停止時に保存し、部屋表示時に復元する。クレートは施設別の経路親ノードを対象とする。旧バージョンのセッションだけに存在したモデル調整は、終了済みなら復元できない。
