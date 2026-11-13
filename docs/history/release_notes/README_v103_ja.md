# セラ v103 — ターゲットの赤色化（2026-11-06）

基準：GitHub `main` 上のv102（ガード中の弾被弾音更新済み）。

- 訓練用の敵ターゲット本体 `VirtualTarget/FloatingBox` のアルベド色を青緑 `#39BDD1` から赤 `#E53935` に変更しました。
- 発光色も青緑 `#23879A` から暗めの赤 `#A92724` に変更しました。従来の発光量、金属度、粗さ、陰影は維持しています。
- 命中時に暗赤色へ変化した後、元の赤色へ戻るよう、`_advance_hit_fx()` の基準色も同じ赤系に揃えています。命中時の暗赤色、演出時間、揺れ、火花は変更していません。
- ターゲットの形状、当たり判定、HP、リスポーン、ロックオンマーカー、敵AI、攻撃・操作・カメラ・音声・Blockbenchモデルは変更していません。
- 変更対象：`scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`、本README、`tools/v103_target_red_self_check.py`。
- 検証：GitHub上のコードを対象とした差分・色コードの静的照合。`tools/v103_target_red_self_check.py` はリポジトリのローカルチェック用に追加しました。Godotの起動・Android実機での描画確認は未実施です。
