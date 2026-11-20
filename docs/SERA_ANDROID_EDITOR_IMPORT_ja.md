# Android版Godotエディターでカード一覧が空白になる場合

## APKでは表示されるのにGodotエディターでは出ない理由
APKを作るCIだけがAndroid用テクスチャ圧縮（ETC2/ASTC）のインポート設定を有効にしていたため、GitSyncで使う元のGodotプロジェクトとは設定が違っていました。今回、その設定を元のproject.godotへ追加しました。ただし、この差が唯一の原因だと確定したわけではありません。

## APKを毎回入れ直さない復旧手順
1. GitSyncで最新のmainを同期します。
2. AndroidのGodotエディターを完全に終了して、SERAプロジェクトを開き直します。
3. ファイルのインポートが終わるまで待ってから、通常のプロジェクト実行でLABO画面を確認します。
4. まだ表示されない場合は、ファイルシステムで assets/ui/sera_matte_icon_atlas.webp を選択し、「再インポート」を実行します。
5. 改善しない場合、Godotを終了してプロジェクト内の **.godot/imported** だけを削除し、エディターを起動し直すと画像のインポートキャッシュが再作成されます。隠しフォルダーを表示する設定が必要な場合があります。

**注意：** .godot フォルダー以外の画像・scripts・scenesなどは削除しないでください。user:// にあるセーブデータを削除する必要もありません。

## 原因が残る場合
Godot Androidエディターの実行環境・バージョンやキャッシュが原因の可能性があります。実機デバッガーで最初のエラーを確認し、scripts/base_facility_system.gd、scripts/sera_item_icons.gd、scripts/sera_chamfer_skin.gd のどこで失敗するか切り分けます。

APKは独立したアプリのため、GitSync後のソースを自動反映しません。通常の開発ではGitSync→Godotエディター実行を使えます。
