# SERA v507 — レールガン充填開始0.7秒の追尾速度スパイクを解消

## 追加検査で確認した問題
- `scripts/bittaran_railgun.gd` の `_track_player()` において、青い球体出現後の追尾開始補間（0.7秒）で `acquisition_weight` が **1.0に到達した瞬間だけ**、フィルター係数 `1-exp(-30*delta*weight)` を無視して角度誤差を100%即時適用していた。
- この不連続な分岐により、同じフレーム幅・同じ照準角度誤差でも追尾回転が**直前と比較して30fps約1.58倍／60fps約2.54倍／120fps約4.52倍／240fps約8.51倍**に跳ね上がる。胴体が縦に起き上がるアニメーションのタイミングと0.7秒終了が重なると、姿勢に伴って追尾が加速したように見える。
- 追加でロール補正の符号を独立した3D回転計算で検査した結果、`Quaternion(Vector3.BACK, roll_radians)`は**正しい方向**（GodotでBACK=+Z）だった。誤った符号変更をせず現行のv506補正を維持した。

## 修正
- `_track_player()` の高速充填追尾を、補間率1.0到達後も同じ**連続した指数応答** `1-exp(-30*delta*clampf(weight,0,1))` で計算する方式へ統一。`weight < 1.0` かどうかに応じた**即時100%旋回への分岐を削除**。
- 青い球体が出る10秒後から高応答追尾を開始する。0.7秒で追尾への入りを強め、11秒に球体が縮小し始めると従来の0.7x制限、12秒にレーザー照射すると0.85x〜1.0x（水平偏差0〜1.5m）へ移行する仕様は維持。
- `CHARGE_TRACK_FILTER_PER_SECOND=30`、胴体から独立したワールド照準モーター、安定した距離計算、ビットタラン原本とIK、砲台形状、レーザー射程／威力／命中、音／エフェクトは不変。**充填中も角速度に固定上限は設けず**、過剰な瞬間移動のみ排除。

## CIテストの先行更新
- 変更前に`project.godot`現行v506、`AGENTS.md`、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/bittaran_railgun_runtime_check.gd`に加え、`tools/bittaran_world_yaw_independence_runtime_check.gd`、`tools/bittaran_full_frame_level_gun_runtime_check.gd`、`tools/bittaran_chassis_axis_runtime_check.gd`を確認。
- **ゲーム本体編集より前**に既存登録の`tools/bittaran_railgun_runtime_check.gd`の「球体縮小直前なら0.0004秒で任意角度にスナップする」期待値を、新仕様の30/sフィルターが常時動作する条件に変更。高速な旋回応答は保護。
- 新たに充填開始後0.7秒の閾値を**60/120Hz**で跨ぎ、`acquisition_weight=0.999999`→`1.0`の回転量比が2%以内で連続する検査を追加。
- さらに独立したPython数理検査`tools/bittaran_railgun_charge_continuity_self_check.py`を新設。30/60/120/240Hzの応答係数、フレームレート不変性、追尾コードの即時スナップ分岐がないことを検査し、`tools/sera_ci_manifest.txt`に登録。従来の1.2秒等他武装、RUN/BOOSTの速度帯、レーザー2秒、球体縮小時0.7x、ダウン停止、ヒット判定等は変更なし。
- GitHub ActionsのフルPython/Godot CIはmainマージ後に動作する設定。数式の外部再計算を30/60/120/240Hzで実施。Android実機の視覚的なスパイク消失は別検証。
前バージョン：[v506](docs/history/release_notes/README_v506_ja.md)
