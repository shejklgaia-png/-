# SERA v173 — SYSTEMのCONFIRM選択枠点滅

## 挙動
SYSTEMの既存3スロットメニューで、SAVE（既存スロットの上書き）・
NEW DATA（既存スロットの再作成）・DELETE（保存済みスロットの削除）
の確認待ち（CONFIRM）に入ると、**対象スロットの選択枠線だけ**
明るいシアンと透明を0.38秒ごとに交互に切り替えて点滅させます。
1周期0.76秒です。テキストと選択行の背景は常に表示します。

確認ボタンを押して操作が終了したとき、キャンセル・戻る操作、
別のスロット選択、SYSTEM画面から離れたときは、点滅を停止して
通常の青い選択枠へ戻します。確認開始時は必ず明るい状態から
点滅を開始し、別スロットの枠は変化させません。

## 変更範囲
`scripts/command_nexus.gd`の選択行のStyleBoxFlat.border_colorを
既存の`_process(delta)`から必要な点滅状態の切替時のみ更新します。
新しい描画ノードやシェーダー、外部リソースは追加しません。
既存SYSTEMのSAVE/LOAD/NEW DATA/DELETE処理、DATA ARCHIVEの4タブ、
カスタマイズ、トレーニング・戦闘操作・カメラは無変更です。

## 検証
`tools/v173_confirm_blink_self_check.py`は静的テストです。
Godot起動とAndroid実機での点滅表示・タップ反応は未検証です。
