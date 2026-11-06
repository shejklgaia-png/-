# Codexへセラの記憶を引き継ぐ手順（Android）

このZIPは **7個のMarkdownファイルだけ**の追加・更新パッチです。v102のゲーム本体・モデルは含めておらず、変更しません。

1. ZIPを展開してください。
2. 展開した `AGENTS.md` と `docs/` 内6ファイルを、GitSyncで接続済みの `/storage/emulated/0/GAME/Git/` へコピーしてください。既存 `AGENTS.md` は上書きし、既存 `docs/ORIGINAL_v102_SHA256.json` は残してください。
3. `GAME/Git/project.godot` と `GAME/Git/docs/SERA_MEMORY_INDEX.md` が存在することを確認してください。
4. GitSyncでコミット・プッシュしてください。**マージ・競合が表示された場合は無理に上書きせず確認してください。**
5. GitHubの `main` で `docs/SERA_MEMORY_INDEX.md` が表示されたら、Codexは `AGENTS.md` の指示から各仕様を参照できます。

Codexへの初回確認依頼例: 「AGENTS.md と docs/SERA_MEMORY_INDEX.md の索引に従ってセラの仕様書を読んでください。実装済み・未実装・検討中を区別し、コードは変更せず、v102と矛盾する箇所だけ報告してください。」
