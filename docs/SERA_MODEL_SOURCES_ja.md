# SERA 正本モデル管理 — v316

現在の正本と実行時参照の対応表です。過去の同名・連番付きモデルは新規編集しません。

| 編集元 | 役割 | 読込 |
| --- | --- | --- |
| models/core/Standard.bbmodel | 標準リグ、基本モデル、モーション、NEXUS | sera_rig.gd SOURCE_PATH |
| models/core/BirdLeg.bbmodel | 鳥脚専用6関節・10メッシュ・23トラック | sera_rig.gd BIRD_LIVE_SOURCE |
| models/core/Katana.bbmodel | カタナ初段/二段目と基本モデル | sera_rig.gd KATANA_SECOND_AUTHORING_SOURCE |
| models/core/Equipment.bbmodel | A/B交換セットとブースター。アニメーション無し | sera_equipment.gd LIVE_SOURCE |
| models/storage/Head_C.bbmodel | 頭Cの2メッシュとPivot | sera_equipment.gd HEAD_C_SOURCE |
| models/storage/LowerBody_D.bbmodel | 重量下半身Dの12メッシュとPivot | sera_equipment.gd LOWER_BODY_D_SOURCE |

Androidエクスポートでは各生成データにフォールバックします。assets/sera_source.json はStandard.bbmodelのコピー（編集禁止）。Katanaの初段は互換維持のため標準モデルにも含まれますが、編集時はKatanaの基本モデルと対応を照合してください。

## v322: 受け渡しKatanaモデルの取り込み

GitHub `models/storage/Katana.bbmodel` にユーザーが置いた新しい編集データを検証し、`Melee_katana` / `Melee_katana2` の**完全なアニメーション定義**を正本 `models/core/Katana.bbmodel` の同名クリップへ差し替えます（キーフレームは結合せず置換）。グループ構成・メッシュ・UV・Pivotは既存の正本を保持します。

`Swordeffect` グループのUUIDは標準リグと一致させてください。回転・位置・スケールのすべてをロードし、`scripts/sword_trail.gd` の既存v85生成メソッドが元の不可視板と同一Pivotで切り抜き弧・立体ボリューム・粒子を追従描画します。参照は正本とそこから作る`assets/sera_katana_data.gd` のみ。取り込み元ファイルは他の用途に使用されていない場合のみ、統合・検証後に削除できます。

今後は`AGENTS.md`の「New Blockbench intake from strage / storage」を適用してください。`tools/sera_model_build.py --write` / `--check`で再生成・一致検査を行います。

## 再生成
1. python3 tools/rebuild_model_data.py
2. python3 tools/rebuild_bird_data.py
3. python3 tools/rebuild_equipment_data.py
4. python3 tools/rebuild_head_c_data.py
5. python3 tools/rebuild_katana_data.py
6. python3 tools/rebuild_lower_body_d_data.py

各関数の対象ファイルは models/manifest.json で確認します。1パーツ=1正本ファイル、同一骨格はモーション共有、実行時は旧ファイルを探索しない方針です。元のPivot、UUID、UV、キーフレームは保持し、変更時はPython検査だけでなくGodot実行検査を行います。

カタナ二段目はGodotエクスポート時にmodels/core/Katana.bbmodelを含められなくてもassets/sera_katana_data.gdから本来のキーフレームを復元します。旧初段からの推定補完は正規データが壊れている場合に限ります。

Katana.bbmodelが初段・二段目の唯一の編集元です。実行時には両クリップを優先して上書きし、Standardに残した初段の古いトラックは互換フォールバック専用です。


最新の安全な一括再生成と確認方法: `docs/SERA_MODEL_PIPELINE_ja.md`。

## v345: 独立ボス骨格「ビットタラン」

- 正本：`models/bosses/Bittaran.bbmodel`（ユーザーが作成した `models/storage/ボステスト (2).bbmodel` を無改造で残して派生）。
- Head / Body / FrontLeg / FrontLowerLeg / FrontFoot / RearLeg / RearLowerLeg / RearFoot の計14グループ、右・左各6脚節＋本体・頭。
- `Wait` 初期姿勢の10本の既存キーを保持。`Idle`（2.4s）、`Turn`（1.8s）、`Approach`（2.8s）はLoop追加クリップ。
- 描画とアニメーション：`scripts/bittaran_rig.gd`。移動・旋回AI：`scripts/bittaran_ai.gd`。専用戦闘：`scenes/bittaran_battle.tscn`。
- Android向け埋め込み：`tools/rebuild_bittaran_data.py` → `assets/bittaran_data.gd`。`tools/sera_model_build.py --write/--check`で他の正本とまとめて一致検証。
- SERA標準リグや既存の訓練ターゲット用コントローラに改造を加えない。
