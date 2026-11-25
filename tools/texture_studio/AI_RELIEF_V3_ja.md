# AI制作基盤 V3: 仮想凹凸メッシュ
既存V2のゲーム用形状・UVを変更しない。制作時のみレイヤーのcylinder・relief dot・hatch/vent/brow_surfaceを高さ場へ変換し、原面境界で減衰させ、三角格子を最大96分割する。面積加重法線を同じ低ポリ面の重心座標で転写する。上方3方向の768px深度マップを低/高密度メッシュの同一投影枠で比較し、V2の既存焼き込み色に差分照明を掛ける。発光材質は補正対象外。
実行: python ai_relief_bake.py iris_v6_mesh.json iris_plan.json V2_albedo.png output_dir
入力はV2と同じモデル/レイヤー契約。同一プラン・同一UVのV2 PNGを指定（PNGの由来は自動照合しない）。依存 numpy scipy Pillow。出力 albedo.png / relief_normal_world.png / relief_height.png (16bit、0.5が高さ0、全レンジ0.02モデル単位) / relief_shadow.png (追加遮蔽差) / virtual_mesh.npz / report.json。ワールド法線・高さは制作専用。ゲームには仮想メッシュを入れない。
H02 396三角→311438仮想三角、34三角加工、7223変位テクセル、4520被覆テクセルのRGB変更、1024px。220同材質境界の色差RMS 1.481515→1.479065。7方向比較では外観差は小さく、TOPLIGHTより精密感が不足。V3は基盤検証で完成資産を置換しない。
限界: 任意ハイポリのケージ転写・物理AOではない。原面境界の高さ減衰、分割数上限、近似遮蔽、最近傍による差分余白、固定光源・既存陰影との重複の可能性。別モデル、Godot/Android未検証。ゲーム・CI変更なし。
参考: Blender Render Baking https://docs.blender.org/manual/en/latest/render/cycles/baking.html ; Adobe mesh map settings https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/baking/mesh-map-settings
