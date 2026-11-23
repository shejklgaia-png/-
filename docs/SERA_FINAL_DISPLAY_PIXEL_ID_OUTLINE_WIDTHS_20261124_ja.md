# SERA：画面表示px基準の可視RGB-ID輪郭線幅
更新：2026-11-24／トレーニング・ビットタラン・拠点・NEXUS・単体プレビュー・クレート共通

## 調査した問題
- 従来の画面比較では**トレーニングの分離メッシュ境界3pxに対して、ビットタラン戦は1px**。同じRGB12可視IDレンダラーでも数値差でトレーニングの方が太かった。
- 既存の`main_inside_px`・`main_outside_px`・`main_seam_px`などは、**ID用SubViewportの整数テクセル単位**で円形近傍探索していた。一方Godotの`canvas_items`、`SubViewportContainer.stretch=true`と端末の実出力解像度により、最終画面ではその1テクセルが複数の表示ピクセルへ伸縮する場合がある。
- `SeraViewEdges.set_stroke_px()`のスカラー値は、共通シェーダー`sera_visible_mesh_id_outline_core.gdshaderinc`には未接続だったため、実際の設定値を変えても外周の太さに反映されなかった。

## 反映した線幅プリセット（最終表示上の**目標px**）
| 画面／可視ID役割 | 内側 | 外側 | 分離メッシュ境界 | 最大理論外周合計 |
| --- | ---: | ---: | ---: | ---: |
| ビットタラン戦：セラ＋ボス（profile 1） | 0 | 3 | 1 | 3 |
| **トレーニング：セラ＋ターゲット（profile 3、新設）** | **1** | **3** | **1（旧3）** | **4** |
| NEXUS全身：セラ＋装備（profile 2） | 1 | 2 | 2 | 3 |
| NEXUS建築物（role 2 / profile 2） | 0 | 2 | 2 | 2 |
| 拠点建築物（role 2） | 0 | 3 | 2 | 3 |
| 小物・電源装置・ケーブル（role 3） | 0 | 1 | 1 | 1 |
| クレート（role 5） | 1 | 1 | 1 | 2 |
| 単体プレビュー（role 6） | 1 | 2 | 2 | 3 |
| その他キャラクターの既定値（profile 0） | 1 | 3 | 3 | 4 |

※外周合計は「内側幅＋外側幅」という幾何学的な目標値。ピクセル格子・アンチエイリアス・斜め線・リサンプリングによって実際の見た目は変化する。

## 共通表示px換算
- `scripts/sera_scene_id_outlines.gd`で、各フレームの`source_viewport.get_screen_transform().get_scale().abs()`を取得。これはAndroid/デスクトップの**最終画面までの表示変換**であり、ルートWindowのcanvas_items伸縮とネストしたSubViewportContainerも反映する。
- この値を共通シェーダーの`output_px_per_id_pixel`へ渡す。IDのピクセルサイズ自体は`source_viewport`と**1:1**で変えず、RGB12深度IDの画素一致を守る。
- `sera_in_disk(dx,dy,desired_display_px)`が、ID画素差分の最終表示上の距離を計算し、**pxは最終表示上の目標幅として解釈**する。X/Yの表示倍率が異なる場合は二軸距離で判定し、半径に合わせて探索範囲を自動計算。画面サイズ変更・端末回転時も毎フレーム倍率更新する。
- 共通シェーダーの外周、内側輪郭、異なるRGB12 ID間の片側境界、発光保護は全要素で同一ロジック。幅と色以外の独立実装を増やさない。
- `set_stroke_px(width)`は**キャラクターrole 1の外側シルエット幅だけ**を共通シェーダーの`actor_outside_override_px`へ明示的に接続する。旧来の`stroke_px`だけを書いて終わることはない。
- `ViewEdges.set_outline_widths(inside, outside, seam)`と`SeraSceneIDOutlines.set_actor_outline_widths()`は、内側・外側・メッシュ境界を**独立して**上書きできる。施設・小物・単体プレビューなど別の役割の幅は影響を受けない。キャラ既定値を上書きしないため、**明示指定のない`ViewEdges`はsetterを呼ばない**。
- キャラprofile 1／2／3および施設profile 2の線幅はシェーダー内の個別uniformで独立した設定値。ハードコードした「特定のscene_profileは必ず2px」等は避ける。
- `get_outline_metrics()`に`display_px_per_id_texel`、`scene_width_profile`、`actor_inside_px`、`actor_outside_px`、`actor_seam_px`、`actor_total_silhouette_px`、各上書き値を追加。**理論値と表示倍率を区別して**確認できる。

## 物理ピクセルの限界
描画先`CompletedBattleFrame`やID SubViewportの実解像度より端末画面が高密度の場合、**描画用1pxは画面上で2px以上に拡大されうる**。この場合、共通シェーダーが正確に1物理pxを描くことはできない。例えば表示倍率が2倍で「境界1px」を指定した場合、従来どおり単一ID画素（結果として表示2px前後）に**下限量子化**する。0pxへ消すことより、見た目の連続性を優先した仕様。
この制約を完全に取り除くには表示ターゲットの最終物理解像度化・専用高解像度輪郭パス・後段の高解像度合成のいずれかが必要であり、GPU負荷や既存Android入力/UI比率への影響が大きいので**今回は導入しない**。本変更は「1px指定の絶対的な物理1px保証」ではなく、**最終表示解像度に基づく幅の換算**を行うもの。

## 維持する機能と運用
- 可視IDによる深度判定、片側ID所有、解像度1:1、最終_process同期、CompletedBattleFrame/CompletedFrame構造、輪郭のオン/オフ、物理補間姿勢を変更しない。
- 今回ユーザー指示に従い、CI項目・設定・テストファイルの確認/変更・適用、CI/Godot/Android等の動作テスト、画像生成を実施しない。実機の見た目・FPS・量子化による線幅変化は未確認。
