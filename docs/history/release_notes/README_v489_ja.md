# SERA v489 — 屋外拠点メニューにNEXUS建物を配置し、タップで入室

## 正しい画面階層
- ゲーム起動時は俯瞰視点の**拠点メニュー** `scenes/base_exploration.tscn`。金属の継ぎ接ぎ床、周囲の廃材、整備設備と独立したNEXUS建物が表示されます。
- **CRATE**は履帯で拠点を自律巡回し、立ち止まりを挟んでウェイポイントを繰り返します。拠点ではSERAの既存移動操作も維持します。
- **NEXUS**は拠点内の3D建物です。建物をタップ（指を大きく滑らせず離す）すると`scenes/command_nexus.tscn`の従来の設備メニューに切り替わります。建物の3D表示範囲を画面に投影して判定します。
- **NEXUS内部は歩行不可**です。従来のTRAINING/CUSTOMIZE/SYSTEM/DATA ARCHIVE/DEPLOYMENTのメニューとカメラ演出を維持します。拠点の各設備から直接NEXUSの5ページに飛ぶ仕組みは廃止しました。
- NEXUSの「EXIT TO BASE」は全体画面・設備メニュー表示中のどちらからでも有効で、タップすると屋外拠点メニューへ戻ります。全体画面でAndroid戻る/ESCでも拠点へ戻れます。
- ビットタラン戦のシーンは削除せず、NEXUSの出撃メニューからアクセスできます。Android縦画面、GL Compatibility、戦闘モデル、入力、パラメータ、セーブスキーマは不変です。

## CI検証
- 実装前に`tools/base_exploration_self_check.py`と`tools/base_exploration_runtime_check.gd`の旧「5施設直接アクセス」期待値を、今回承認された「NEXUS建物からのみ入室」仕様へ更新。
- 新規`tools/base_nexus_navigation_runtime_check.gd`で、実Godotの拠点→NEXUS→拠点遷移と退出UIを検査。共通CI manifestへ登録し、既存のテストは維持します。
- Android実機でNEXUS建物のタップ、クレートの移動、戻る操作、UI重なり、屋外描画を別途検証してください。

前バージョン：[v488](docs/history/release_notes/README_v488_ja.md)
