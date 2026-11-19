# SERA v483 — ビットタランのレールガン接続軸を本体旋回へ同期

## 変更
- 背中のレールガンへつながる**上側の縦軸**（Blockbench原本UUID `4b184c7d-480e-cd99-3dca-596928ffd5cd`）を、ビットタランの**本体水平旋回（ワールドY軸）**へ同期させます。
- 接続軸の取付位置は胴体に追従させつつ、胴体の前後左右の傾きは軸の向きへ伝播させません。
- 砲身2本は従来どおり独立した照準Yawと上下Pitchを使用します。照準Yawでは接続軸を回しません。
- 下側の台座・脚・HEAD・14関節・原本Blockbench形状とアニメーションキーは変えません。

## 変更しない仕様
- レールガンの10秒充填・10〜12秒の球体追尾・12〜14秒の照射・14〜14.7秒の復帰。
- 球体縮小からの0.7倍追尾、地表射線との差1.5m超での追尾加速、0.2秒ごとの実接触再ヒットと威力60%。
- なぎ払いの前足0.67〜1.38秒／後足0.17〜0.63秒の判定。

## CIと実機確認
- 既存の `tools/bittaran_railgun_runtime_check.gd`、`tools/bittaran_full_frame_level_gun_runtime_check.gd` の不変条件は保持します。
- `tools/bittaran_chassis_axis_runtime_check.gd` で、実モデルの軸メッシュを使い、複数の旋回角・胴体Pitch/Roll・砲身の独立照準・復帰を検査します。CI一覧へ実装前に登録済みです。
- Godot headlessで骨格・数学的姿勢を確認し、Android実機では接続軸の見え方、砲身と軸のつながり、旋回中の表示を確認してください。

前バージョン：[v482](docs/history/release_notes/README_v482_ja.md)
