# SERA v275 — 制作済みサマーソルトキック Kick_b 正式導入

- 原本：`models/storage/SERA_BOOSTER_allテスト (9) (2).bbmodel` に登録された `Kick_b`。
- 長さ0.79167秒、標準A骨格と一致する16関節・71キーを**無改変**で `assets/sera_source.json` に取り込み、`assets/sera_data.gd` を正式な生成スクリプトと同一形式で更新しました。
- 既存の全25モーションとメッシュ、Pivot、装備データは維持します。
- v274の操作仕様を維持：3段目中または終了後受付中に画面下90°のフリック → 格闘3段目完走後にKick_bを発動。後方4m・高度1.5m・飛行0.8秒・着地モーション0.2秒。通常STEPと競合しません。
- `sera_rig.gd` は実際の `Kick_b` を優先再生します。暫定Jumpモーションおよび表示モデルの追加360°回転は正常な原本がある場合には使用しません。
- `tools/v275_authored_back_kick_self_check.py` でモーション原本とのキー照合・UUID整合・生成資源のバイト一致を検査。実Godotの既存サマーソルト検査と全クリップ検査も、今回から正規Kick_bを必須としました。
- Android実機での操作・アニメーションの見え方・接地は未確認です。Linux headless Godot検査の結果とは分けて記録します。
