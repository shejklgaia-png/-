# Termux → GitHub main: 衝突安全な自動アップロード（v2）

## 今回の再発防止の対象
2026-11-08のNEXUS_pose同期では、端末のGAME/Git/models/SERA_BOOSTER_allテスト.bbmodelには新しいポーズが含まれていたのに、Termuxの古い~/sera_repoがGitHub mainの進行を検知し「CONFLICT: upload cancelled」で止まっていた。作者名未設定も一時クローンの手動アップロードの失敗原因だった。

## 新しい仕組み
- 監視対象：/storage/emulated/0/GAME/Git。Androidで保存した追加・上書きファイルを処理し、削除は自動反映しない。
- Termux内部の状態ファイル ~/.sera_safe_upload_state.json に、**最後に成功した時点で観測した端末ファイルのハッシュとGitHub HEAD**を保存。
- イベント通知だけでなく120秒ごとに再走査。変化がなければネットワークへ接続しない。
- **端末で実際に更新されたファイルだけ**抽出する。端末フォルダ全体をGitHubへ上書きコピーしないので、ローカルが古い場合でも、GitHub側の新機能・コードを壊しにくい。
- 編集がある場合はGitHubの最新mainを取得し、一時的なクリーンなGitクローンへ変更ファイルだけを上書きしてコミットする。ローカル~/sera_repoやGAME/Gitをgit reset/clean/force-pushしない。
- 前回成功したGitHubコミットより後に**同じファイル**をGitHub上でも編集しており、現在の端末と内容が異なる場合は「SAME-FILE CONFLICT」で安全停止。どちらかを自動で採用しない。
- 同時に別のGitHub変更がpushされた場合は最大3回最新mainを再取得して再試行。失敗時は状態を進めず次回の定期確認で再挑戦する。
- 自動コミットに専用のGit author名とメールアドレスを明示し、Author identity unknownを防ぐ。メールアドレスは実在の個人メールではなくローカル識別子。
- 同期中の多重起動をflockで抑制。ログは~/sera_auto_push.logに記録・上限約1MBで縮小。失敗時は~/sera_upload_error.txtを作成し、再試行が成功したら消去する。
- **初回インストールでは既存のGAME/Gitファイルをアップロードしない**。現在の内容を基準点として記録し、それ以降に追加・上書きしたファイルのみ自動アップロードする（古いファイルでmainを上書きしないため）。
- _backup_*.bbmodel、.git、.godot、.nomedia は対象外。

## 端末へのインストール（1回だけ）
GitHub上のスクリプトを追加しただけでは、実行中のTermuxは変更されない。Termuxで以下を実行：

```bash
pkg install python git curl inotify-tools util-linux
curl --fail --location --show-error --silent \
  "https://raw.githubusercontent.com/shejklgaia-png/-/main/tools/termux/install_safe_sync.sh" \
  -o "$HOME/install_sera_safe_sync.sh"
bash "$HOME/install_sera_safe_sync.sh"
```

インストーラは元の~/sera_push.shと~/sera_watch.shを時刻付きファイルとしてバックアップし、Python・Bash構文確認後に新しい実装を配置する。最初の基準点を記録し、旧監視プロセスを停止して新しい監視を起動する。

## 動作確認
ファイルを1つ新規作成して監視経路を確認：

```bash
printf 'safe sync test\n' > /storage/emulated/0/GAME/Git/SERA_SAFE_SYNC_TEST.txt
tail -n 25 ~/sera_auto_push.log
```

ログに「PUSH SUCCESS」があれば送信成功。「NO CHANGES」は未変更、「BASELINE CREATED」は初回のみ。「SAME-FILE CONFLICT」は同一ファイルの二重編集。「UPLOAD ERROR」はネットワーク・認証・ファイル状態などのエラー。GitHubのmain上でテストファイルが出現するかも照合する。作成したテストファイルを端末で削除してもGitHubから自動削除はされない。削除には手動のGit操作が必要。

## 端末がオフラインのとき
失敗しても端末のファイルと状態記録は維持。監視が稼働しネットワークへ再接続できれば定期確認で送信を再試行する。ただしAndroidの省電力設定でTermuxが停止している場合はアプリを起動し直す必要がある。Termuxの監視プロセスはアプリ内で実行されるもので、ChatGPT側のバックグラウンド監視ではない。

## 競合・リカバリー
- 「SAME-FILE CONFLICT」のときは端末側とGitHub側の両方を残したまま停止する。ファイルを手動確認してから再保存／再試行する。強制プッシュは禁止。
- 一時的な非fast-forwardは再取得して再試行するため、従来の「mainが進んだらアップロード停止」は原則解消。
- 旧スクリプトのバックアップは~/sera_push.sh.before_safe_日時 と ~/sera_watch.sh.before_safe_日時 に保存される。
- この変更はGitHubにスクリプトを追加するもので、端末に自動配布・端末上でのテスト実施を保証しない。

## 検査
```bash
python /storage/emulated/0/GAME/Git/tools/termux/test_safe_sync.py
```
上のオフライン検査はテスト用の一時Gitリポジトリを使う。初回基準点、追加／変更の送信、GitHub先行時の独立ファイルの保持、同一ファイル二重変更の停止、削除非同期を検証する。
