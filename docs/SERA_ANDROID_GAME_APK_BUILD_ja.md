# SERA本体のAndroid APKビルド

Godot 4.7.2で `main` のゲーム本体をARM64のDebug APKへ変換します。
**SERA Loader APKとは別物**です。

- ビルド: GitHub Actions **Build SERA Game APK**
- 初回はAndroid向け`export_presets.cfg`とワークフローのマージで自動実行します。以後はActionsから手動実行できます。
- 成果物: **SERA-Game-Android-APK**（ZIP内に`SERA-vXXX-debug-arm64.apk`）
- パッケージID: `org.shejklgaia.sera`
- 使用エンジン: Godot **4.7.2 stable**、GL Compatibility、画面縦向き
- 端末: ARM64 Android、Xperia 1 Vに対応する構成です。
- 署名: GitHub Actionsキャッシュの専用Debug keystore。一般配布・Play Store向けのリリース署名ではありません。
- バージョンはビルド時に`project.godot`の`SERA vXXX`に追随します。Androidテクスチャのインポート設定はGitSync元と同じproject.godotに固定しています。
- ビルド後はAPKのZIP整合性・署名・パッケージ名・ARM64コードを検証します。実機の描画／ゲームパッド操作／データ引継ぎは別途確認してください。
- **GitSyncとの違い**：APKはインストール時点でゲーム内容を内包した独立アプリです。Godotエディター経由のソース起動とは異なり、GitSyncでソース更新してもインストール済APKの内容は自動更新されません。
- Androidが「提供元不明アプリ」の許可を求める場合は、信頼できる自分のDebug APKだと確認してから許可してください。

セーブファイルはアプリの`user://`に保存されるため、**Godotエディター上で遊んだデータがAPKに自動移行することはありません**。既存セーブを消さないよう、作業前にバックアップしてください。
