# SERA v236 — 左右STEPの距離別減速を削除

## 変更内容
- 左右STEPは、ターゲットまでの距離にかかわらず基本速度**10m/s**で移動します（選択した脚部の速度倍率は引き続き反映）。
- 従来の「ターゲット表面から5m以内で減速し、2m以下で8m/s」の補正は**純左右方向では使いません**。
- 前方・後方の補正は維持し、斜めSTEPはその両方の速度を連続的に混合します。
- 左右の公転軌道、予定距離2〜4m、前方3m、後方4m、衝突・カメラ・EN・モーションは維持します。
- ステップの移動距離を固定する変更ではなく、**移動速度の距離依存を除去する変更**です。

## 自動検査
- `tools/v200_contact_omni_step_self_check.py`
- `tools/v235_forward_step_distance_self_check.py`
- `tools/v236_lateral_step_no_proximity_slowdown_self_check.py`
- Android/Xperia 1 Vの操作感は未確認です。
