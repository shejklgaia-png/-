# AI制作基盤 V8
V7のPNGと同一UVをハッシュ照合し、不要な中央ディテールの局所的な下地復元と原面縁に沿うスリット・締結点の描画を追加する。元PNGを変更しない。AIが原面を拡大し、撤去範囲・縁の両端・内側距離・長さ・間隔を指定する。左右ペアは局所X反転。下地復元は近傍のロバスト平面色フィット。輪郭はShapelyで包含・重複確認、境界保護と+Y上方光に沿う疑似陰影。
実行: python ai_edge_finish.py iris_v6_mesh.json iris_edge_v8.json base_v7.png output
依存 numpy scipy Pillow shapely。入力モデルとV7下地は独立配布ZIPに収録。出力albedo.png/edit_mask.png/report.json。
H02 396三角/118島/1024px、8原面、10撤去領域、20縁配置、3983変更画素、指定マスク外0。全306独立島共有辺の19点双線形色差ベクトルの変化0。斜め・側面拡大と7方向描画を確認、JS例外0。初回の消し残しを見て撤去範囲を修正し再生成。
見栄えを優先する。縁に情報を寄せる一方、大型点検パネル、センサー等の役割ある中央部は維持。余白を残し、既存装甲の方向・配置・陰影と揃える。数値のみで合格にしない。
制約: 選択面と縁座標は手動、原面の局所平面近似、既存テクスチャの完全な原レイヤー復元ではない。幅・間隔はモデル単位で暫定、他パーツ・Godot/Android未検証。既存資産とゲーム/CIは変更しない。
参考: Adobe Geometry Mask https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/interface/layer-stack/geometry-mask
