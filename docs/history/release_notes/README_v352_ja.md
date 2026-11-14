# SERA v352 — ビットタランの胴体メッシュ中心へ水平ロック

## 変更点

- ビットタラン戦で、2本の平行ロック線の**終点（X/Z）をビットタランの実際のBODYメッシュのAABB中心**に変更しました。従来の敵ルートノードの原点には向けません。
- **Y座標は始点・終点ともセラの原点Yに固定**。胴体メッシュの中心が高くなったりダウンで低くなったりしても、線は水平で傾きません。
- 左右に平行な2本の線の間隔0.50mは維持します。
- 移動・旋回・脚破壊時には実際の胴体メッシュの中心X/Zを毎回取得し、ロック線の目標へ反映します。
- ロック選定で2本とも脛の選択ボックスを通らない際の補完選択も、胴体メッシュ中心の方向を基準に揃えました。
- 共通デバッグ表示も同じボス専用座標計算を利用します。
- **トレーニングルームの共通ロック線処理には変更なし**。v350の脛ロックボックス2倍・Y固定、頭と胴体がダウン中のみ選択可能な仕様、物理・攻撃当たり判定も維持しています。

## 実装

- scripts/bittaran_parts.gd：get_actor_parallel_lock_segments() を胴体メッシュ中心X/Zへ向けて上書き。_nearest_lockable_shin() の補完基準も同じ。
- tools/v351_bittaran_horizontal_lock_runtime_check.gd、tools/v351_bittaran_horizontal_lock_self_check.py：既存の水平判定テストをメッシュ中心基準に更新。
- tools/v352_bittaran_body_center_runtime_check.gd：敵ルートに無関係な座標を渡す試験、実BODYの中心一致、65フレームの移動・旋回、脚破壊ダウン、表示線、訓練室への非影響をGodot 4.7.2で検証。
- tools/v352_bittaran_body_center_self_check.py：実装差分の静的チェック。
- v345〜v351のビットタラン専用回帰テストは引き続きCIで実行しています。Android実機での表示と操作は未確認です。

[前バージョンの記録](docs/history/release_notes/README_v351_ja.md)
