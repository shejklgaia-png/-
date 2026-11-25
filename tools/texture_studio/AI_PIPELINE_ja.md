# AI制作基盤 V1（オフライン）
既存テクスタのGodot実行時処理は変更しない。作者（AI）が材質割当と表面座標の描画レイヤーを設計し、Pythonがベイクと検査を担当する。アイリスTOPLIGHTは基準として維持し、V1の試験塗装で置換しない。

## 実行
Python 3.10+、numpy、scipy、Pillow。
```sh
python -m pip install numpy scipy Pillow
python tools/texture_studio/ai_pipeline.py mesh.json plan.json output_dir
```

入力 mesh.json: positions (三角形コーナーXYZを平坦化、Y上、モデル座標単位)、uvs (対応する正規化UV、V下)、chart (三角形ごとの島ID)、source_faces (原面ごとの三角形インデックス)、parts (三角形ごとの明示部品ID)。既存V6レビューJSONに部品IDを追加可能。BBModel/Godotの直接インポートは未対応。元四角面を保存し、三角対角線を原面境界とみなさない。UVは事前に制作・検査した非重複のものを使用する。

plan.json: geometry_sha256 (geometry(mesh)の末尾の値)、resolution 256/512/1024/2048、supersample 1/2/4（積4096以下）、padding（出力px）、light、ambient、direct、face_material（原面順）、palette（名前→RGB）、emissive_materials、layers（順番が合成順）。UVに依存しないモデル座標に各プリミティブを置く。kind=stroke/cylinder は points、dot は center、plane は normal/offset、全て width（半径）、color。enabled、opacity、faces、parts、materials、relief を指定可能。plane の offset は正規化法線での距離。投影の裏移りを防ぐため対象面を明示する。cylinder は疑似凹凸で実形状を増やさない。

出力 albedo.png、position.png、normal_world.png、face_part_id.png、plan.json、report.json。IDマップはR/Gに原面ID+1の下位/上位8bit、Bに部品ID+1。IDマップは制作専用。非圧縮メモリ、ミップ、ASTCは別途実機検証する。固定上方光のベイクを含むため動的光との二重陰影に注意。

## 採用ルール
- geometry fingerprintで誤ったモデルへの適用を拒否。UVの再展開は別工程。
- 2D余白と3D隣接面参照を同じ塗装で比較。同材質の原面共有辺に限定、被覆サンプルは変更しない。色差RMSが悪化する場合は2D余白に戻す。
- reportのraster_collision_samplesは画素サンプル検査であり厳密なポリゴン重複ではない。独立したUV検査を省略しない。材質が異なる意図的境界は色差最適化の対象外。
- visual_approval=pendingを数値だけで承認しない。旧版と同じカメラで斜め・前後・左右・上下、戦闘相当の縮小を比較し、問題箇所・修正・採用理由を記録する。元の承認資産は保持。
- 本実装は初期基盤。汎用自動構造認識、厳密な測地線描画、仮想ハイポリの実メッシュレイベイク、物理AO、全レイヤー専用UI、Godot入出力、Android、他パーツ検証は未実装。CIは変更しない。

## 参考
- Adobe Substance 3D Painter mesh maps / 3D Space Neighbor
  https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/interface/texture-set/texture-set-settings
- Blender Render Baking https://docs.blender.org/manual/en/latest/render/cycles/baking.html
- Godot texture importer https://docs.godotengine.org/en/stable/classes/class_resourceimportertexture.html
