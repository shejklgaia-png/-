# SERA v309 — 9.2.2のStep_Rをそのまま右ステップへ適用

## 使用したモデル
- 画像で指定されたBlockbenchファイル: `models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel`
- 選択されたアニメーション: `Step_R` (UUID `89d9039b-e40c-6cce-f680-aac585192be8`)
- 原本の22関節分のアニメータ情報と19個の時刻0キーフレームを、回転角・位置・補間・UUIDごと**一切変更せず**取り込みました。

## 更新範囲
- `assets/sera_source.json`と`models/SERA_BOOSTER_allテスト.bbmodel`の`Step_R`だけを差し替え。`tools/rebuild_model_data.py`と同じ形式で`assets/sera_data.gd`を再生成しました。
- 9.2.2の原本自体は変更していません。v308が独自に編集したWaist/Headの2回転キーのみ、9.2.2の値に戻っています。
- モーション名・UUID・開始APIは維持し、ゲーム側の右ステップはそのまま`Step_R`を呼び出します。
- 前・左・後の3モーション、斜めの360°ポーズ補間、右3mの移動、ロックオンの腰Yaw補正、エフェクト、攻撃、カメラは維持しています。

## 検査
- `tools/v309_step_r_922_self_check.py`は正本・統合モデル・9.2.2の`Step_R`内容の完全一致、キーフレーム数とUUID、埋込データ一致を確認します。
- `tools/v309_step_r_922_runtime_check.gd`は実Godotリグから原本の腰・頭の姿勢をサンプルし、右フリック後に`Step_R`が再生されること、4方向補間でポーズが変化しないこと、3mの移動設定とロック向きを確認します。
- Android実機での見た目は未確認です。
