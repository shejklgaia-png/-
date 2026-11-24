# 2026-11-24 LABO近景 大規模化・材質・燃焼表現

- #1155の独立生成モデルを維持。専用設備の寸法と設備間距離を1.30倍。CRATEと操作端末は等倍、端末位置のみ移動。製造セル幅13m、高さ約10.7m、炉上部約13.9m、倉庫棚約12m。建屋は約42m幅、36m奥行き、16m高さ、背面サービスギャラリー、梁・天井・柱・配管・追加原料ラック、倉庫の後列2棚を追加。全設備の親ローカル正規配置、CRATE作業動作、UIを維持。初期カメラはINDUSTRIAL_V4、旧座標を混入させない。
- 黒潰れ原因候補: BASE Batchの近景材質が全身機体パレットに渡されていた。近景専用シェーダーに分離。MODEL_MATRIXから軸寸法を取得してメートル単位（2m周期）で局所三方向投影、材質色×既存鋼/装甲/酸化テクスチャ、頂点色を二重乗算しない。移動する部品にも局所座標が追従。暗色塗装の最低明度を調整、発光/ガラスの既存挙動を維持（ガラスは近景の不透明色材として扱う）。共通機体材質はCRATEのみに適用、屋外BASE/NEXUSは変更しない。
- 燃焼: EPA Combustion Evaluation in Air Pollution Control https://nepis.epa.gov/Exe/ZyPURL.cgi?Dockey=9100INDA.TXT および LPG diffusion flame https://journal.ump.edu.my/index.php/jmes/article/view/2999?articlesBySimilarityPage=20 を参考に青色の反応根元と発光すすの黄橙色領域を描写。物理CFDではなく外観近似。周期サインの三角形を廃止、上昇する多周波ノイズ・不規則な火炎舌・透過減衰・炉内の3層固定深度テスト付きクアッド、耐火内壁とバーナー床、局所橙色ライト1灯。Godot空間シェーダーのblend_mixとdepth_draw_neverを利用 https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html 。レイマーチ・追加Viewportなし、表示中の炉だけ時間更新。
- ソース差分、正規配置キー、親子座標、材質バッチ呼び出し、炉口の奥行き位置を確認。Android描画・シェーダーコンパイル・実機FPS未確認。CI/画像生成なし。初回更新スクリプトのJavaScript文字列区切り構文エラーは変更未送信、テンプレート文字列に修正して再実行成功。今後は長いコード置換にバッククォートを使用する。
