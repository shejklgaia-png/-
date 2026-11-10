# SERA v211 — Frontstep モーションの反映

## 取り込み元
2026年11月10日にAndroidからGitHubへ追加された `models/storage/SERA_BOOSTER_allテスト (5).bbmodel` の `Frontstep` アニメーションを取り込みました。

ユーザー制作の `Frontstep` は長さ0秒・時刻0の**静的ポーズ**です。標準セラの22ボーンのうち、18ボーンに実際のキーフレームが入っています。原本に含まれる別骨格・未使用装備用のボーンは、ゲームの標準Aモデルへ不適切に混入させません。

## ゲーム内への適用

| 操作 | 適用モーション |
|---|---|
| 真正面へのフリックSTEP | 新規 `Frontstep` （従来の `Boost_front` を置換） |
| 斜め前方STEP | `Frontstep` と `Step_L` / `Step_R` を操作角度に応じて補間 |
| 真横STEP | `Step_L` / `Step_R` を維持 |
| 後方・斜め後方STEP | `Backstep` と左右STEPの既存補間を維持 |
| BOOST全方向、重量脚SLIDE | 従来の `Boost_*` モーションを維持 |

スタート時は既存の0.12秒クロスフェード、終了時は既存の0.16秒クロスフェードを維持します。移動距離・速度・EN消費、連続360°フリック判定とカメラ処理は変更しません。

## データと保護対象
- `assets/sera_source.json`：`Frontstep` のうち標準骨格に属するアニメータだけを追加
- `assets/sera_data.gd`：正規の生成スクリプトと同形式で再生成、原本JSONとバイト一致
- `models/SERA_BOOSTER_allテスト.bbmodel`：`Frontstep` を制作統合モデルに追加
- 旧モーション、ノズルPivot、既存の装備・メッシュ・UV・ゲームロジックは維持

検証：`tools/v211_frontstep_self_check.py` と既存CIの静的回帰検査。Godot/Android端末での実際の見え方は未検証です。
