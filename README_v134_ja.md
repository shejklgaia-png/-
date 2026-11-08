# SERA v134 — CUSTOMIZE拡大セラの背面放射グラデーション（2026-11-08）

- 拡大CUSTOMIZE画面ではセラの輪郭線を非表示にし、その代わりに拡大セラの背後へシアン系の放射状グラデーションを表示します。色は既存輪郭線のRGB（0.35、0.85、0.98）と共通です。
- GodotのQuadMesh + unshaded/alphaの単一ShaderMaterialで、中心が淡く発光し、外周は完全透明になります。GL Compatibilityを維持します。
- グラデーション板はカメラの子として固定し、モデルの前に被らないようセラより0.70m後方に配置。拡大・画面サイズ・回転に追随して大きさと中心を調整します。3D格納庫の背景は透けて見えます。
- 全景でのCUSTOMIZE輪郭は通常どおり表示し、選択時の移動中も従来の枠線を保持。拡大表示が成立したら線を隠し、戻るボタンではグラデーションを即座に消し、全景復帰後に通常の輪郭を再表示します。
- TRAINING、SYSTEM、DATA ARCHIVE、DEPLOYMENTの選択枠、v133のタップ即時反映、NEXUS_pose、セラの回転・拡大、カメラ、戦闘・音声・Blockbenchの元資産は維持します。
- コード構造・依存資産・表示制御の静的検査は`python3 tools/v134_customize_radial_glow_self_check.py`。Godotエンジン／Androidでの実際の描画品質と回転操作は未検証です。
