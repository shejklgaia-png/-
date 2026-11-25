# AI制作基盤 V5
V1〜V4を維持。TOPLIGHTの高品質な既存PNGをUV固定の下地として取り込み、上から独立した仕上げレイヤーを合成する。過去の全描画命令の復元ではない。下地とモデルJSON全体のSHA256を照合するためUVを変更する場合は別工程が必要。元PNGは変更しない。
実行: python ai_finish.py iris_v6_mesh.json iris_finish_v5.json approved_toplight.png output
入力モデルと下地は配布ZIPに格納。Python/numpy/scipy/Pillowを使用。レイヤーのface、axis、offset（面内2方向）、length、width、opacity、luma_range、enabledを編集。ventはcount指定でスリット群、railは円筒状支持部の疑似陰影。+Y上方光を意識した明暗、元輝度範囲のマスク、原面端0.006モデル単位を保護し0.004で減衰。非平面または17×7点の包含検査に失敗した場合は拒否。55/80/100%の3候補を生成。report.jsonは自動承認せずpending。
H02: 396三角・118島・1024px。14配置のうち7適用、4非平面拒否、3視覚検査後に無効化。80%候補2060画素変更、マスク外変更0。全306独立島共有辺の19点バイリニア色差を独立計算、全辺の差分ベクトル不変（意図的な材質差も含む）。Chromium 7方向と3候補比較、JS例外0。側面スリットと額裏支持部の加筆を確認。完成資産は置換しない。
制限: 輝度範囲は材質意味認識ではない。サンプル包含検査。真のPBR反射、UV再展開、TOPLIGHT原レイヤー復元、別パーツ、Godot/Android未対応。固定の幅・マスクは暫定、モデル単位に依存する。ゲーム・CI変更なし。
参考: Adobe Painter Geometry Mask / Layer Stack、Blender Render Baking。
