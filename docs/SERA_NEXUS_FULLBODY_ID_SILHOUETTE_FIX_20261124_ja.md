# NEXUS全身プレビュー：外周シルエットが消える問題の修正
更新日：2026-11-24

## 現象と原因
PR #891でNEXUS全身プレビューの輪郭も、ビットタラン戦と同じ深度付きRGB12可視IDに統一済み。しかしNEXUSの装備カスタマイズ画面では、SERAの分離メッシュ間の線が見えても外周2pxの線が消える現象があった。

原因は**輪郭の抽出ではなく、3D透明物の描画順**。
- RGB-ID輪郭の合成用シェーダー`sera_bittaran_visible_mesh_id_ink.gdshader`は、`scripts/sera_scene_id_outlines.gd`で`render_priority=-30`に設定されている。
- カスタマイズ画面のグリッド背景`nexus_customize_radial_glow.gdshader`は`ALPHA=base_opacity`（表示時1.0）、かつ`depth_draw_never`を使用。**不透明色に見えてもGodotの透明描画順**で描かれる。
- 背景マテリアルは`render_priority`未指定だったため既定値0で、ID輪郭（-30）の**後**に描かれた。SERAの外側に広がる黒い輪郭ピクセルは、背後に見えるグリッド背景の不透明な描画で上書きされていた。SERA本体の上にある内側・メッシュ境界線は本体の深度判定で背景が描かれないため残り、外周だけ消えた。

## 修正
- `scripts/render_order_policy.gd`に`NEXUS_CUSTOMIZE_BACKDROP=-40`を追加。
- `scripts/command_nexus.gd`の`_create_customization_glow()`で、グリッド背景のShaderMaterialに`render_priority=-40`を設定する。
- 描画順を**グリッド背景(-40) → 共通ID輪郭(-30) → 前景の透過エフェクト(既存優先度)**へ統一。グリッド背景の3D位置・深度テストは維持するためSERA本体より手前へは出ない。
- 現行のRGB12可視ID生成、親子同期、シェーダー、キャラ線幅（NEXUS全身：内1px／外2px／分離メッシュ境界2px）、単体プレビュー・BASE・CRATE・ビットタラン戦の描画設定は変更しない。
- **描画順のみの修正**なので、CPU/GPUの別輪郭バッファ、追加QuadMesh、輪郭拡大処理等を作らない。負荷増加を避ける。

## 未確認
- ユーザー指定どおりCI項目やテスト設定は確認・変更せず、CI/Godot/Android等の動作テストは実施していない。
- 修正後のAndroid実機の外周表示は未確認。透明描画の予期しない別素材との順序干渉があれば、その素材を個別に確認する。
