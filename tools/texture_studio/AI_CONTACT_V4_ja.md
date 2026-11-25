# AI制作基盤 V4
V3の仮想メッシュと高さマップを用い、低ポリUVテクセルから16本のコサイン分布半球レイをBVHで追跡する。距離はモデル境界箱対角の9.5%、始点バイアス0.065%。最近接距離で遮蔽を重み付け。原面共有辺の二面角と凸凹推定で明暗を加える。発光材質保護。UV島境界2pxを保護し次の3pxを減衰、旧パディングを保持。V3色に差分を加える弱・中・強の3候補を生成する。
実行: python ai_contact_bake.py mesh.json plan.json V3_albedo.png virtual_mesh.npz relief_height.png output_dir
依存: V1に加えてnumba。入力は同一モデル・プランのV3出力を手動指定。出力はsubtle/balanced/strong.png、ao.png、curvature.png、report.json。AOは距離重み付き遮蔽近似であり物理照明ではない。曲率は原面エッジの近似である。
H02: 396低ポリ・311438仮想三角、1024px、368065被覆テクセル中発光1389変更0。中候補124115被覆テクセル変更。境界保護前220同材質境界色差RMS 1.479→3.075（中）、保護後全3候補1.479065。7方向比較と3強度候補を視覚確認、TOPLIGHTを置換しない。
制約: 仮想メッシュ・PNGの由来は自動照合しない。レイ16本、固定強度、2px保護・3px減衰は暫定。UV境界直近の曲率表現も弱まる。低ポリ法線による半球、二面角符号は法線の向きに依存。Godot/Android、他パーツ、ミップマップ未検証。ゲーム/CI変更なし。
参考: Adobe Ambient Occlusion from Mesh https://experienceleague.adobe.com/en/docs/substance-3d/bakers/bakers-settings/ambient-occlusion-from-mesh ; Blender Render Baking https://docs.blender.org/manual/en/latest/render/cycles/baking.html
