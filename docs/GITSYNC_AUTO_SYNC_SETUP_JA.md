# SERA: GitHub main → ntfy → Tasker → GitSync 自動同期設定

更新日: 2026-11-07。**ゲームバージョンはv112のまま**。対象は `shejklgaia-png/-` の `main` ブランチです。

## 動作のしくみ

1. ChatGPT/Codexの変更がPRから `main` にマージされ、GitHubにpushされる。
2. `.github/workflows/sera-gitsync-notify.yml` が実行され、`ntfy.sh` に本文 `SERA_SYNC_MAIN` の通知を送る。
3. Android版ntfyが `io.heckel.ntfy.MESSAGE_RECEIVED` のブロードキャストを配信する。
4. Taskerが **トピック名と本文の両方** を検証し、GitSyncサービスへ `INTENT_SYNC` を送る。
5. GitSyncがセラのリポジトリを同期する。GitHub Actionsの完了は**スマホ側同期完了の証明ではありません**。

## 事前準備：GitHub Actions Secret

- ntfyのトピックを自分で作ります。推測困難なランダムな **24～64文字** の `A-Z a-z 0-9 - _` を使用します。簡単な `sera`、一般的な単語、リポジトリ名は不可。トピックは通知の購読・送信権限の代わりになるため、公開しないでください。
- リポジトリの **Settings → Secrets and variables → Actions → New repository secret** を開きます。
- **Name**: `SERA_NTFY_TOPIC`、**Secret**: そのランダムなトピック名。
- ワークフローコードにはトピック名を一切書きません。Secretが未設定の場合は通知を送らず、Actionsログに案内だけを出します。
- `Settings → Actions` でActionsの実行が許可されていることも確認します。ChatGPTからは現在のリポジトリSecret/Actions許可状態を取得できません。

## Android: ntfy

1. 公式のAndroid版 **ntfy** をインストールします。
2. サーバー `https://ntfy.sh` で、GitHub Secretと同一のトピックを購読します。
3. 受信通知をAndroidの自動化へ渡すため、ntfyの通知/バックグラウンド動作を許可します。バックグラウンド受信遅延が問題ならntfyの即時配信を有効にします。
4. トピックの通知音はミュートして構いません。ただしntfyの購読・バックグラウンド受信自体は無効にしないでください。

## Android: Tasker

1. **Profiles → ＋ → Event → System → Intent Received**。
2. **Action** = `io.heckel.ntfy.MESSAGE_RECEIVED`。他のフィルタ項目は未指定。
3. 新しいタスクを作成して、受信Intentのextra変数 **`%topic`** が自分の秘密トピック、かつ **`%message`** が `SERA_SYNC_MAIN` である場合のみ後続のアクションを実行します。Taskerの `If` と `Stop` またはアクション条件で厳密にフィルタしてください。
4. **＋ → System → Send Intent** を追加。
   - **Action**: `INTENT_SYNC`
   - **Package**: `com.viscouspot.gitsync`
   - **Class**: `com.viscouspot.gitsync.GitSyncService`
   - **Target**: `Service`
   - GitSyncにリポジトリが複数ある場合は、必要に応じて **Extra** `index:0`（セラが0番の場合のみ）などを指定します。
5. Taskerの必要なバックグラウンド実行権限を許可します。ntfyの公式仕様でこの受信Intentとextra `topic`/`message` が案内されています。

## Godot起動時スキャンとの競合を避ける

- GitSyncの**「Godot起動時に同期する」**設定を無効にしてください。今回の仕組みはGitHubマージ後に先回りして同期するため、Godot起動と競合させる必要がありません。
- ただし**Godotがプロジェクトを開いている最中の同期はファイル競合の恐れ**があります。TaskerでGodotが前面にあるときは `%SERA_PENDING_SYNC` 等のグローバルフラグに保留し、Godotを終了してからGitSyncへ同期Intentを送る構成を推奨します。
- TaskerのApplicationプロファイルでGodotの前面/退出を監視し、前面なら同期を保留、退出後に保留分を実行します。必要なら同一秒内の複数通知をまとめて1回にしてください。
- 初期設定時にはGodotを閉じた状態で動作を確認してください。Godotを閉じたまま、通知受信後にGitSyncで同期が完了しているかを確かめます。
- GitSyncの同期は内部的にfetch/pullだけでなく変更のstage/commit/pushを含むことがあります。プロジェクト編集中の同期や未保存データの扱いには注意してください。

## 確認手順

1. `SERA_NTFY_TOPIC` Secretを設定してから、GitHubの **Actions → SERA GitSync notification → Run workflow** を手動実行します。
2. GitHub Actionsログが `ntfy accepted the sync trigger` を出すことを確認します（これはntfyサーバーへの送信成功だけです）。
3. ntfy側で本文 `SERA_SYNC_MAIN` が届いたこと、Taskerプロフィールが発火したこと、GitSyncで対象リポジトリが同期されたことを個別に確認します。
4. その後のセラ `main` 更新で自動通知が到達するか確認します。TaskerだけでなくGitSyncの履歴から最終同期の成功を確認してください。

**制限**: ChatGPTはこのワークフローのGitHub登録を行えますが、Androidアプリのインストール/Tasker登録/Secret入力を端末上で代行できません。GitHub側のワークフロー作成だけではエンドツーエンドの自動同期はまだ有効になりません。

## 参考（公式）
- GitHub: https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow
- ntfy: https://docs.ntfy.sh/publish/
- ntfy Android Intent: https://docs.ntfy.sh/subscribe/phone/#react-to-incoming-messages
- Tasker Intent: https://tasker.joaoapps.com/userguide/en/intents.html
- GitSync Tasker Intent: https://gitsync.viscouspotenti.al/wiki/sync-options/background/app-based
