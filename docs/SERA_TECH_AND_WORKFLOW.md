# SERA — Android制作・Godot技術・Git運用
この文書の初版は v103（2026-11-06）の時点の記録です。**最新の統合版は `project.godot` で確認**し、`docs/SERA_DEVELOPMENT_FASTPATH_ja.md` と現行コードを優先してください。過去版の実機検証履歴を現在版の検証状況と混同しないでください。

## [実装・運用決定] 全スマホ制作
- Xperia 1 V上に**モデル、Godotプロジェクト、動作確認環境**がすべてある。Godot Android版とBlockbenchを使用。Blender/PCが必須であるかのような工程を提案しない。無料の手段を優先。
- Godot 4.x GDScript、現行はGodot **4.3+互換**, GL Compatibility、縦画面720×1280。最新安定版と公式ドキュメントを確認して実装する方針だが、**自動でGodot本体やレンダラーを移行しない**。互換性・バックアップ優先。
- 60Hz/60fpsが理想。クラウドのヘッドレステストはタッチ操作・映像品質・実機FPSを保証しない。
- `project.godot` → `scenes/main.tscn`、`scripts/main.gd`。リグは `scripts/sera_rig.gd`、操作描画 `scripts/touch_overlay.gd`、敵 `scripts/enemy_*.gd`、VFXは `scripts/sword_trail.gd`, `scripts/hit_burst.gd` 等。

## [運用] ChatGPT ↔ Codex ↔ GitHub ↔ GitSync
- 非公開リポジトリ: `shejklgaia-png/-`、通常の同期先は `main`。スマホのGitSyncローカルクローンは `/storage/emulated/0/GAME/Git/`。
- ChatGPTは仕様整理、開発指示書、コードレビュー等、Codexは実装・ソース調査・実行できる範囲の自動テストを担える。**双方が同じユーザーメモリを自動共有するわけではない**。GitHub上の文書を共有基準とする。
- **2026-11-06の継続指示：今後のセラ開発は、作業ブランチ作成→実装→可能なテスト・差分確認→PR作成→`main`へマージまでを、追加の「マージして」指示を待たずに実施します。** マージ後、GitSyncで取り込み→Godotで再読み込み→Xperiaで実機確認します。
- 実機未検証でも、実施できた静的検査等が合格し差分が適切ならマージ可能とします。ただし実機未検証を明記し、検査失敗・競合・意図しない変更は無理にマージせず報告します。
- Godot/Blockbench編集中のファイルを無警告で同期して上書きしない。ローカル変更・競合を確認。

## [必須] 開発ルール
1. 指示のない既存機能・操作・挙動・モーション・音・アセット・シーンを維持。
2. 修正は最小差分、無関係なコード再構築を避ける。
3. 前後で可能な範囲のGDScript構文、scene/resource、影響範囲、既存テスト、変更対象外の差分を点検。
4. 実際にGodotやAndroidで実行した場合にのみ「実機検証済み」と報告。実行できない項目は明記。
5. ゲーム本体を改修した時のみ版番号を進めます。**記憶/文書追加だけではゲーム本体の版番号を進めません**。
6. 既定の`DEVELOPMENT.md`等に基準版、変更点、変更ファイル、維持事項、検証結果、未検証事項を残す。
7. Blockbench原本、`assets/sera_source.json`、生成される`assets/sera_data.gd`とボーン/アニメーションの整合性を保つ。元データを削除しない。
8. 高負荷な粒子や背景ブラーを安易に追加しない。ユーザーが別に実機で評価した方針を優先。

## [実装] 主な静的検査
```
python3 tools/codex_project_check.py
python3 tools/self_check.py
python3 tools/v102_guardfix_self_check.py
python3 -m compileall -q tools
# 使用可能なGodotバイナリがある場合のみ:
godot --headless --path . --import
```
旧版の検査には過去のZIP等を要求するものがある。実行前に前提を確認する。headlessで成功してもAndroidのタッチ/映像/音/性能を検証したとは言えない。
