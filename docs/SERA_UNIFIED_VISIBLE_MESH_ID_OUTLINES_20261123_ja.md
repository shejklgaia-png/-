# SERA：全画面・全モデル 可視メッシュID輪郭の共通化
2026-11-23／実装用ブランチ（マージ未実施）

## 統一された実処理
ビットタラン戦PR #889のID輪郭方式を正本とする。見た目だけ似た別シェーダー、旧NEXUS赤ID方式、アイリス専用6-IDパス、物理メッシュ稜線・凸角リボンは使用しない。

1. 各描画Viewport内で**1つのSeraSceneIDOutlines**を使用。元の3Dモデルを保持したまま、描画対象のMeshInstance3D/MultiMeshInstance3Dを、表示カメラと同じ投影・姿勢で1つの深度付きRGB12 ID SubViewportへ描く。床や光源などの無枠要素はID 0／保護エミッションrole 7へ分類。
2. IDのR/Bは可視メッシュID、Gはモデル役割（1=キャラ、2=施設、3=小物・電源、4=GRID、5=CRATE、6=単体プレビュー、7=発光保護）。部位間の境界は**異なる可視IDの隣接ピクセルだけ**を検出し、片側オーナー判定により二重描画しない。外周はrole=0背景とrole=1..6の境界を画面投影範囲内でのみ抽出。凸角・ハードエッジ生成は一切しない。
3. **全画面でprocess_priority=10000の末尾_processから1フレーム1回、描画カメラ・表示モデル姿勢をIDコピーへ同期**。物理補間対象は従来どおり補間済みTransformを使う。旧フレーム境界シグナルや別個の専用マスクで更新しない。ID SubViewportはUPDATE_ALWAYS。
4. 本体・ID輪郭・VFX・HUDの完成画像を1つの表示用SubViewportへ合成。ビットタランは既存CompletedBattleFrame、BASE/NEXUSは同一構造のCompletedFrameContainer→CompletedFrameを利用。装備プレビューはすでに表示用SubViewport内で一括合成される。元のワールドNode3DとUI/操作・音声は保持する。
5. すべてのspatial出力は**同一実Shaderリソース** `shaders/sera_bittaran_visible_mesh_id_ink.gdshader`を使用。そのFragment演算は`shaders/sera_visible_mesh_id_outline_core.gdshaderinc`に一元化。UI SubViewportのcanvas_item出力のみGodotの必須Shader型が異なるが、同じincludeの**全く同じIDサンプリング、深度、境界所有、外周、アルファ判定**を呼び出す。shaderをコピーして似せた別アルゴリズムにはしない。

## 既存の線幅設定（数字だけ分岐）
| 対象 | 内側 | 外側 | 分離メッシュ境界 | RGB役割 |
| --- | ---: | ---: | ---: | ---: |
| ビットタラン戦（セラ含む） | 0px | 3px | 1px | 1 / scene_profile=1 |
| 拠点の施設・建築物 | 0px | 3px | 2px | 2 |
| 拠点の小物・電源装置・電源コード | 0px | 1px | 1px | 3 |
| 拠点・GRIDの従来の役割4対象 | 1px | 3px | 3px | 4 |
| NEXUSの建築物 | 0px | 2px | 2px | 2 / scene_profile=2 |
| NEXUSのセラ全身・装備 | 1px | 2px | 2px | 1 / scene_profile=2 |
| 単体プレビュー（アイリス含む） | 1px | 2px | 2px | 6 |
| クレート（拠点・LABなど） | 1px | 1px | 1px | 5 |
| 一般の戦闘/全身表示role 1 | 1px | 3px | 3px | 1 / scene_profile=0 |

- BASEの施設枠線は黒色で、実在する発光保護ID付近だけ不透明度を旧来の設定どおり抑制する。NEXUSとキャラクターはブルーグレー`#17212f`。これは色/線幅設定のみで抽出アルゴリズムを変えない。
- アイリスの専用6-ID描画の例外を削除し、すべての単体パーツにrole 6を適用。各画面のgraphics optionに従い既存のオン・オフを維持する。
- NEXUSの建築物は従来線幅2pxの対象だけをrole 2に切り替え、装飾・光・床など元から無枠の要素はID0／深度隠しのまま保持する。BASEも床等の遮蔽専用モデルを新たに枠取りしない。

## 廃止した二重輪郭・別方式
- `scripts/command_nexus.gd`：NEXUS建築物の`material_overlay`によるpolygon edges、SeraDepthHull、SeraLiveMeshEdges、SeraStencilHullの生成を廃止。展示セラはNEXUSの親ルート共有IDで取得し、rigの二重ViewEdgesはオフ。
- `scripts/sera_part_preview_widget.gd`：アイリスだけの`IrisIDContour`呼び出しを廃止。通常の単体プレビューと同じcompositorを必ず使用。
- `scripts/sera_base_architecture.gd`：建築物の旧EdgeInk/CreaseInkと小物のConvexリボン生成を廃止。アニメーション・施設と小物のMultiMeshごとの役割分類は保存。
- `scripts/base_exploration.gd`：装飾小物のConvexリボンを廃止。輪郭検査UIも旧シェーダーを切り替えず共有IDの診断だけを表示。
- `scripts/sera_base_power_distribution.gd`：電源装置のConvex1px別描画を廃止。
- 旧API`set_nexus_sera_contact_mode`は互換性のため残すが、現行ではnumeric profile=2を選ぶだけで別IDパレット/シェーダーを復活させない。

## 表示・実装上の限界
- 3D画面とUIプレビューでspatial/canvas_itemの**最終表示Shader型**は異なる。ただし双方のFragment計算を同一`gdshaderinc`からインクルードするため、可視IDの判定・外周・境界処理はコードレベルで共通。
- 同じCompletedFrame内でも子ID SubViewportのGPU描画と色描画がハードウェア上で必ず同じフレームに完成する「GPUフェンス」は設けていない。PR #888のCPU側最終_process同期だけをすべてに適用する。実機でのFPS、正確さ、入力・音声の挙動を保証するものではない。
- BASEやNEXUSはID用テクスチャと完成色フレームのオフスクリーン描画が増えるため、GPU負荷増加の可能性がある。線幅は画面ピクセルで指定し、実表示領域に合わせてID用解像度を更新する。
- **運用指示に従いCIの確認・変更・適用、CI/Godot/Android等の動作テストを実施していない。** 本変更はコード調査とソースレビューのみ。
