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

## 再生成
1. python3 tools/rebuild_model_data.py
2. python3 tools/rebuild_bird_data.py
3. python3 tools/rebuild_equipment_data.py
4. python3 tools/rebuild_head_c_data.py
5. python3 tools/rebuild_lower_body_d_data.py

各関数の対象ファイルは models/manifest.json で確認します。1パーツ=1正本ファイル、同一骨格はモーション共有、実行時は旧ファイルを探索しない方針です。元のPivot、UUID、UV、キーフレームは保持し、変更時はPython検査だけでなくGodot実行検査を行います。

カタナ二段目はGodotエクスポート時にmodels/core/Katana.bbmodelを含められなくてもassets/sera_katana_data.gdから本来のキーフレームを復元します。旧初段からの推定補完は正規データが壊れている場合に限ります。
