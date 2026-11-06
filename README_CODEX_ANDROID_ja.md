# SERA v102 — GitHub / Codex / Android運用ガイド

## このZIPについて
- 2026-11-06の**v102**を基準にした、GitHub登録用の**リポジトリ構成**です。`project.godot` がZIP直下にあります。
- 元のゲーム本体・モデル・音・アニメ・操作コード・README群は**バイト単位で未変更**です。Codex用のルール・Git設定・自動静的検査だけ追加しています。
- 別添の `SERA_Guardfix.bbmodel` は、元ZIP内の `blockbench/SERA_Guardfix_user_input.bbmodel` と完全一致していたため、重複保存しませんでした。v102でGuardポーズは既に組込済みです。
- Godotの動作実行やAndroid実機の動作確認は**まだ実施していません**。

## スマホだけで最初にGitHubへ登録する方法
1. GitHubで空の**Private**リポジトリを用意します（可能であればREADMEを1つ付け、GitSyncでクローン可能にします）。
2. AndroidにGitSyncを導入し、GitHubアカウントと接続。リポジトリをスマホ上のアクセス可能なフォルダ（例：`Documents/SERA`）へクローンします。
3. このZIPをスマホで**展開**し、内部の `project.godot`、`assets/`、`scripts/`、`scenes/`、`blockbench/`、`.gitignore`、`AGENTS.md` など**全ファイルを**クローン先フォルダへコピーします。外側にさらにフォルダを作らないでください。`.git` フォルダがすでに存在していれば削除しないでください。
4. GitSyncの状態を確認して最初の **commit / push (同期)** を行います。アプリによって画面表示や追加の承認操作が異なります。ZIPそのものだけをGitHubに置いてもCodexは中のソースを直接編集するリポジトリにはなりません。
5. Android版Godotで、その同期先フォルダの **`project.godot`** をインポートして開きます。現行プロジェクトが別フォルダにある場合はバックアップとして保持してください。
6. [Codex Cloud](https://chatgpt.com/codex/) でGitHubリポジトリを接続し、環境を作成・公開してから作業を依頼します。環境作成はWeb/デスクトップ画面で行う仕様です（スマホのブラウザでアクセス可能な場合があります）。

## 2回目以降の更新
- Codexで変更を作成 → diff/テスト結果確認 → GitHub上でPRを**mainにマージ** → GitSyncで **pull / 同期** → Godotを再読込・実機で動作確認。
- 新しいCodexタスクで作業しただけでは、勝手にスマホのファイルが更新されるわけではありません。更新はコミット・マージ・同期して初めてローカルに届きます。
- GodotやBlockbenchでファイルを編集中の同期は避けてください。スマホ側で変更した場合もGitSyncが **push** する設定なので、競合内容を確認してから同期します。
- Godotの `.godot/` は自動生成キャッシュなのでGitには保存しません。実際のアセット、GDScript、`.bbmodel` は保存します。

## Codexに最初に指示する例
> `AGENTS.md`、`README_v102_ja.md`、`DEVELOPMENT.md` を読み、まず v102 の構成とガード、格闘、ステップ、カメラの仕様を要約してください。機能変更はせず、`python3 tools/codex_project_check.py`、`python3 tools/self_check.py`、`python3 tools/v102_guardfix_self_check.py` を実行してください。Godotが使えればheadless importも検証し、実行した検証と未検証を区別して報告してください。

## CIについて
`.github/workflows/static-check.yml` がGitHub Actionsで **Pythonの静的チェック** を実行します。Godotのヘッドレス起動やAndroid実機の描画・タッチ・音の動作確認ではありません。

## 参照
- Godot Androidエディター: https://docs.godotengine.org/en/stable/tutorials/editor/using_the_android_editor.html
- GodotのGit管理対象: https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html
- Codex Cloud: https://help.openai.com/en/articles/20001545-using-codex-cloud
- GitSync: https://github.com/ViscousPot/GitSync
