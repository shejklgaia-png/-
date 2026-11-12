# SERA v265 — 3段コンボ後の左右蹴りがSTEPになる問題を修正

## 再現と原因
- v264では、左右蹴りモーションを実行時に `models/storage/SERA_BOOSTER_allテスト (9).bbmodel` から任意追加読込していました。GodotのAndroid配布・実行環境にこの原本が存在しない場合、`has_side_kick` が偽になり、通常STEPへ安全フォールバックします。実際の端末で原本が読めなかったかはログ未取得のため確定していません。
- また、3段目終了後0.65秒の受付中にフリックを開始しても、**指を離す時点で残り受付時間が0**だと、`_request_combo_side_kick` の再チェックで蹴りが却下され、通常STEPが発動していました。こちらはコードから確認できる確定した判定不具合です。

## 修正
- ユーザーがBlockbenchで制作した `Kick_l`／`Kick_r` を、原本 `models/storage/SERA_BOOSTER_allテスト (9).bbmodel` から **既存22関節UUIDに対応するキーフレームだけ抽出して** `assets/sera_source.json` へ追加。両方1秒で、左109・右72個のキーを保持します。
- `tools/rebuild_model_data.py` と同じ生成仕様で `assets/sera_data.gd` を再生成し、Androidの埋込フォールバックにも左右蹴りを収録しました。実行時にBlockbenchファイルが無くても標準リグの蹴りモーションを再生できます。既存アニメーション、メッシュ、Pivotは変更していません。
- `side_kick_flick_candidate` の受付可否は**タッチ開始時**に判定して確定します。有効な左右フリック（既存STEP閾値・0.24秒以内）が入力中に0.65秒受付期限を超えても、離指時は蹴りを実行します。
- 3段目が完走する前のフリックは既存どおり通常STEPキャンセルです。完走後の左右フリックだけ蹴りへ変わります。前方バッシュの受付、他ステップ、距離2〜4m、EN、衝突、カメラ、1ヒット判定は変更していません。

## 検証
- 新規 `tools/v265_kick_embedded_input_self_check.py` で元モーションのキーフレーム一致、22骨格UUID一致、埋込データとJSONの完全一致、入力開始時ラッチ・派生優先・STEP距離処理を検証します。
- GitHub Actionsの既存model-policyジョブに追加して回帰検査します。Godot／Androidでの実機描画は別途検証対象です。
