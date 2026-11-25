# AI制作基盤 V6
V5の下地PNGとモデルJSONをハッシュ照合して維持。原面ローカル座標で折れ線配管・両端継手・共通支持軸の放熱フィンを生成する。Shapelyで有限分割の輪郭を作り、原面三角ポリゴンの和集合と余白に対して包含・別機構との重複・支持軸との接続を検査する。ラスタ段階でも輝度マスクによる部品消失、支持軸との接続、単一島の場合は連結成分数を検査。材質4種（steel/dark_alloy/rubber/paint）、上方光を意識した疑似陰影。
実行: python ai_mechanism.py iris_v6_mesh.json iris_mechanism_v6.json base_v5.png output
依存: numpy scipy Pillow shapely>=2。入力モデルとV5の80%下地は配布ZIPに収録。3候補とreport.json、plan.json、overlay_mask/metallic/roughness.pngを生成。材質マップは100%候補の追加領域だけの値であり、全体PBRマップではない。マスクと併用する。元のPNGは変更しない。
H02: 396三角、118島、1024px。4組の初回候補から正面下部の浮いた取っ手状の配管を視覚検査で無効化。最終3組15構成部品、各組の連結成分1、80%候補845画素変更、範囲外変更0。全306独立島境界の各19点双線形色差ベクトル変化0。7方向と3候補をChromiumで実描画、JSエラー0。TOPLIGHT/V5は保持。
制約: 単一平面内での接続検査であり面をまたぐ機構や装置全体の機能・配管先は保証しない。輪郭は有限分割近似、輝度マスクは意味認識でない。材質値・余白・強度は暫定。動的反射やGodot/Android、他パーツは未検証。ゲーム/CI変更なし。参考: Adobe Geometry Mask / PBR Metal Rough、Blender Curve Geometry。
