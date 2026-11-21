# SERA v533 — ビットタランの作者制作ダウン動作

Android縦画面・1対1ボス戦メレーアクション SERA の開発版です。

## 2026年11月21日の更新
- 前脚ダウン L/R・後足ダウン L/R の4アニメーションをBlockbench正本から組み込み。
- 破壊部位に合わせて、前脚・後足・左右のダウンを原本の1倍速で再生。
- ダウン持続（2.5秒／全脚6.0秒）と立ち上がり時間（1.0秒／1.3秒）は維持。
- 立ち上がりは5次補間で自然にWaitへ復帰。頭の独立追尾は維持。
- 実際の作者接地キーに合わせて、ボディ全体に広がる土埃を1回発生。
- Source: `models/bosses/Bittaran.bbmodel`; Android: `assets/bittaran_data.gd`; tests: `tools/bittaran_authored_down_runtime_check.gd`.

詳細: `DEVELOPMENT.md` と `docs/agent/CI_WORKFLOW.md` を参照してください。
