# 精製炉の火炎：実測資料に基づく移流連番 V2

## 調査
- NIST, Cup-Burner Flame Extinguishment in Low Gravity, Fig.1（実験映像・温度/すす計算の対照） https://www.nist.gov/system/files/documents/el/fire_research/R0601278.pdf : 燃焼器に付着する青い根元、下流でのすす発光、浮力不安定性による渦と輪郭変形。
- NIST, Laser-Induced Incandescence Measurements of Soot Production in Steady and Flickering Methane, Propane, and Ethylene Diffusion Flames https://www.nist.gov/publications/laser-induced-incandescence-measurements-soot-production-steady-and-flickering-methane : 燃料別のすす生成・酸化と渦/火炎面相互作用。
- Frequency jump of a flickering buoyant jet diffusion flame influenced by ambient coflow https://www.sciencedirect.com/science/article/pii/S1540748924001317 : 外周渦の形成・成長・剥離、火炎のくびれの移流（公開要旨）。
- IFRF, Laser Sheet Visualisation in industrial flames https://ifrf.net/research/handbook/how-do-i-apply-laser-sheet-visualisation-in-industrial-flames/ : 実炉ガス火炎・混合の画像。燃料や空気条件により外観は異なる。本作の発光すすを伴う炉は演出設定。
- NVIDIA GPU Gems Ch.6 https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-6-fire-vulcan-demo : アニメーションテクスチャ、位相差、アルファ合成による彩度維持・軽量化。

## 実装
従来のノイズで面を変形するシェーダーに代え、オフラインの2D速度場（上昇流、周囲空気の巻き込み、浮上する渦）で熱/すすのスカラーを半ラグランジュ移流。MacCormack型補正と近傍極値制限、発光すすの生成・減衰を近似。5か所の根元を固定し、青色反応域を局所化、温度/すすの代理値で赤橙・黄・白黄と透明度を決める。実測資料そのものの転載や定量CFDではない。96コマ・24fps・4秒、16コマの重複区間でループを接続。1コマ80×88、960×704の透過PNG、RGBA8展開で約2.58MiB、BASE/近景で静的共有。BASE 2枚、近景3枚の固定奥行き・異位相のSprite3D。深度テストを維持し、炉壁/格子に隠れる。既存の正規配置ID、炉の形状、煙突、資源処理は変更なし。発光の積分値を平滑化した96コマの表を用いて炉光を連動。実行時の流体計算なし。旧BASE埋込PNGは削除、近景旧シェーダーは未使用。

## 確認
生成したPNGの全チャンクCRC、DEFLATE展開、Adler32、サイズ960×704、96フレーム、各フレーム境界の透明性を確認。フレーム単体のプレビューを確認。発光積分の変動を確認。Android実機、Godotコンパイル、FPSおよび炉内での最終合成は未確認。CI・画像生成ツールは使用しない。生成器 tools/bake_furnace_flame.js を保存。今後の外観調整は実測画像と各燃焼条件を照合し、規則的な波形や青い一律帯を再導入しない。
