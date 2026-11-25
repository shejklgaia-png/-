# AI制作基盤 V2
V1のオフラインベイクを変更せず、原面分析・表面交線・機構レシピを追加。TOPLIGHT完成候補は保持。
- inspect(mesh): 原面面積・中心・平均法線・部品・隣接・二面角の絶対値、X=0を仮定した相互左右対称候補。候補は意味認識ではない。中心のKD木から検索。
- plane_strokes(mesh, faces, normal, offset, width, color, name): 指定面の実三角との交線を幅付きレイヤーとして返す。厳密な測地線や全角度での線幅保証ではない。
- actuator(mesh, face, name, length, radius, direction): 平面原面に収まる機構の描画レシピ。17×7点の矩形包含検査に失敗した候補は拒否。実形状でなくV1の疑似立体描画。任意の凹面への完全な包含保証ではない。
- H02専用 refine: V1 JSONから額の交線・暗色部の左右一対の機構・締結点を作成。旧レイヤーbrowのあるH02専用。
実行: python ai_surface_tools.py iris_v6_mesh.json iris_plan.json output
V1と同じ依存ライブラリ。structure.json、refinement.json、plan.json、画像、report.jsonを出力。入力V6 meshとV1 planは別途配布ZIP。H02 396三角、230原面、422共有辺、98組の異なる左右対称面候補、34自己対応。機構候補4面は不採用、左右2面採用。数値による自動採用は境界パディングのみ。視覚レビューで孤立機構2面を撤去。7方向の比較を行い、V2試験デザインはTOPLIGHTを置換しない。
他パーツの実データ、Godot、Android、物理AO、完全な意味認識、仮想ハイポリのレイベイクは未検証または未実装。CIとゲーム本体には変更なし。
参考: Adobe Substance 3D Painter Mesh Maps、Blender Render Baking。
