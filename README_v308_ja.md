# SERA v308 — Step_Rを右前傾姿勢へ

- GitHub内の現行・履歴Blockbenchモデルの同名`Step_R`を比較した結果、前傾右寄りの別版は存在しませんでした。そのため、既存`Step_R`の**名称とUUIDはそのまま**に上体のキーフレーム0を調整しました。
- `Boost_right`の右方向への傾きを参考にしつつ、従来の右ステップの腕・脚のポーズと腰の位置は維持しました。WaistをX=-30°（前傾）、Y=-15°、Z=-18°（右傾）に変更し、Headの強いねじれをY=30°、Z=12°へ軽減しました。
- `assets/sera_source.json`と現行Blockbench統合原本`models/SERA_BOOSTER_allテスト.bbmodel`を一致させ、`tools/rebuild_model_data.py`と同じ形式で`assets/sera_data.gd`を再生成しました。歴史的原本`models/motion/`、`models/storage/`は保存しています。
- 他3方向（Frontstep/Step_L/Backstep）、360°補間、ターゲットロック、移動方向・距離（前左右3m、後5m）、攻撃、カメラ、装備は維持しました。
- Python静的検査でStep_Rの2関節の回転以外が変わらないことを検証し、Godot実行検査で右フリック発動・前傾・右傾・ロック向き・3m距離を検証します。Android端末上の見た目は未確認です。
