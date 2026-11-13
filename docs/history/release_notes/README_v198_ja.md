# SERA v198 — 3画面共通のバージョン表記

選択画面・トレーニングルーム・拠点メニュー（SERA COMMAND NEXUS）の右上に、同じバージョン文字列「SERA v198」を小さく表示します。

バージョンは `scripts/version_indicator.gd` が `project.godot` の `application/config/name` から読み取ります。今後バージョンを更新した際は、従来どおり `project.godot` の `config/name="SERA vNNN"` を更新するだけで3画面とも連動します。画面ごとに数字を埋め込む必要はありません。

文字サイズ14、画面上端3px、右端14pxの余白、右寄せです。選択画面はタイトルとは独立、トレーニングルームはHUDの上、拠点メニューは既存の3D/カスタマイズUIと別のレイヤーで描画します。タップやマウス操作は `MOUSE_FILTER_IGNORE` により遮りません。

変更対象：`scripts/version_indicator.gd`、`scripts/launch_menu.gd`、`scripts/main.gd`、`scripts/command_nexus.gd`、`project.godot`。アニメーション・モデル・ゲーム操作・保存形式は変更しません。

回帰検査：`python3 tools/v198_version_indicator_self_check.py`。Androidの実画面表示・読みやすさは未確認です。
