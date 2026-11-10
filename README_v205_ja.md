# SERA v205 — 背面ブースター仮モデル

## Blockbenchの構成
対象：`models/SERA_BOOSTER_allテスト.bbmodel`、標準A骨格の`Chest`直下。

```text
Chest
└─ BOOSTER
   ├─ BoosterBody
   ├─ Thruster_L
   │  ├─ Thruster_L_Outer
   │  └─ Thruster_L_Inner
   └─ Thruster_R
      ├─ Thruster_R_Outer
      └─ Thruster_R_Inner
```

- `BoosterBody`：幅8.1 × 高さ5.5 × 奥行1.84（Blockbench単位）の四角い本体。
- `Thruster_L/R_Outer`：本体の下部左右に取り付けた外径約2.56、奥行3.25の八角形中空筒。背面（+Z）へ向けています。
- `Thruster_L/R_Inner`：ノズル内側の暗色面です。仮モデルのため装飾・フィンはありません。

## ゲーム内登録
`scripts/sera_equipment.gd` が`Chest/BOOSTER`から形状を読み取り、アニメーションに追従する元のA胸部骨格に接続します。BOOSTER装備スロットではA・Bのどちらを選択しても当面同じ仮モデルを表示します。胴体のA/B切替とは独立です。

エクスポート用の`assets/sera_equipment_data.gd`も更新済みです。既存のブーストとスライド、残像、EN消費、速度、操作、戦闘モーションは変更しません。**噴射エフェクト自体は未実装**です。

## 確認
`python3 tools/v205_back_booster_stub_self_check.py` でグループ階層、左右の形状・位置、既存モーション非破壊、スナップショット一致、ゲーム側の読み込み経路を静的検査します。Godot Android実機の表示確認は未実施です。
