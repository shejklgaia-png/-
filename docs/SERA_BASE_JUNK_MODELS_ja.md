# SERA BASE：金属パネル束・雑多な回収スクラップの3D造形刷新（2026-11-21）

## 参照・狙い
拠点スクリーンショットの「厚い青い箱を重ねたもの」と「箱と黄色い棒だけの機械のような塊」が何なのか分からないという指摘への修正。正本は `scripts/sera_base_clutter.gd` の `panel_stack` と `scripts/base_exploration.gd` の `ScrapPile_00〜15`。

## 金属パネル束（同一の薄板の繰り返しを廃止）
- `scripts/sera_base_junk_geometry.gd::panel_stack` に6種類の実形状を追加：`notched`（片側欠け）、`bent`（折れ）、`trapezoid`（台形状）、`ribbed`（補強リブ付き）、`short`（小板）、`long`（長板）。**サイズも幅・奥行きがそれぞれ異なる**。
- ピッチ/ロール±4〜13°＋弱いヨー変化、中心位置の前後左右ずらしを1枚ずつ独立設定。床板の上に薄いスチール板が重なり、支え/リブ/スペーサーが見える。二段組には各6枚ずつ計12枚、上下の組み合わせも異なる造形を使用。
- 新たな `BaseArchitecture.Batch.box_tilt` は実際の `Basis.from_euler` でX/Z軸回転を生成し、従来の立方体用MultiMesh材質バッチへ入れるため新しいシェーダー・メッシュ種類・透明描画パスは増えない。
- 既存の `LiftedBatch` は傾き角・高度を引き継ぎ、旧レコーダー・テストでは安全に通常ボックスへフォールバック。既存のコンテナ2+1積みや別の `armored_bundle` 等の造形はそのまま。

## スクラップ山（機械ブロックのような規則形状を廃止）
- 世界座標16か所の `ScrapPile_%02d` 位置と固定Yawは変更しない。
- `JunkGeometry.scrap_heap` に5種類の不規則なシルエットを実装。大小3〜5枚の破損・傾斜装甲板、歯車外周（8分割リング）とスポーク・車軸、折れた配管、曲がった骨組み、モーターハウジング、ピストン、ケーブル片、散らばった小ボルトを組み合わせる。密度・高さ・金属色の偏りを形状ごとに変える。
- 従来は16か所×3個別MeshInstance3Dで箱2＋棒1。今後は**1個の `SalvageMeshes` に全16か所の形状を共通バッチ登録**し、色/形状ごとに一つの不透明MultiMeshで描く。位置の目印である16個の `ScrapPile_%02d` ノードは互換用に存続し、各ノードに造形プロファイル番号を保持する。
- プロシージャル造形を毎フレーム計算しない。乱数再抽選なし。非透明、常時3D深度テストON、影パス追加なし。

## CIとスクリーンショット
- 実装前に `base_junk_models_self_check.py` と `base_junk_models_runtime_check.gd` を追加。6種・5種・実回転、床上の材質バッチ、16の安定アンカー、混合ジオメトリが230インスタンス以上、描画バッチが最大11以内という独立した性能検査をマニフェストへ登録。
- 既存の `base_prop_stacks_runtime_check.gd`、`base_compact_prop_variety_runtime_check.gd`、`base_natural_yaw_runtime_check.gd`、`base_site_prop_variety_runtime_check.gd`、`base_soft_center_space_runtime_check.gd`、NEXUS/LABOの画面配置・CRATE動線検査を削除・緩和しない。
- `tools/base_junk_visual_capture.gd` を追加し、CIの既存720×1280のGL実描画工程で `sera_base_junk_detail.png`（パネル束2タイプ＋スクラップ4タイプ拡大）を取得。全景 `sera_base_orthographic.png` も従来通り撮影し、同じGitHub Actionsアーティファクトに保存。
- 720×1280のGodotスクショとAndroid実機確認は別検査です。

## 変更しない領域
施設位置・入口角度・中心のほどよい余白・専用床パネル8枚・CRATEの巡回、ゲーム保存や素材名称・倉庫UI・装備・外部モデル原本・ゲームプレイ・フォントは変更しません。
