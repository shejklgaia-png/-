# SERA — 新規チャットへ装備設定を引き継ぐ実装契約
<!-- SERA_EQUIPMENT_CHAT_HANDOFF_V1 / 2026-11-21 -->

## ユーザーが新規チャットで渡すもの
1. https://shejklgaia-png.github.io/-/ のアイリス等の装備設定フォームで設定し、EXPORT → **設定全文をコピー**する。
2. 新しいChatGPT会話で「次のSERA装備設定をGitHubのmainへ実装してください」と依頼し、`SERA_EQUIPMENT_INTAKE_V1`を先頭に含む全文を貼る。原本bbmodelやPNGの再アップロードは不要。
3. GitHubが接続されている場合、フォームの`handoff.repository`、`source.repository_path`、`source.sha256`、`equipment.blueprint_id`、`equipment.slot`を使って直接実装する。編集用の`selected[slot]`はモデル制作ID（A/B/C/D/K）であり、ゲーム内のセット装備ではない。

## エージェントが行う検査と変更の順番
- JSON形式`SERA_EQUIPMENT_INTAKE_V1` / `SERA_EQUIPMENT_CHAT_HANDOFF_V1`を解析する。`source.base_commit`はフォーム出力時の参考情報であり、常にGitHub `main`と実際の原本のsha256を照合してから進める。更新によるSHA変更があれば混ぜずに衝突を報告する。
- モデルはGitHub正本の`models/...`と、それに埋め込まれたテクスチャを使い、`models/manifest.json`や最終更新履歴を確認。英数字は制作識別のみ。NEXUSの全身ポーズ`NEXUS_pose`を勝手に変更しない。
- `equipment.blueprint_id` と `equipment.slot`を検証し、`scripts/sera_prototype_catalog.gd`、`sera_part_stats.gd`、LABO製作、必要素材、倉庫（各ハンガー999個上限）、NEXUSの独立した個別パーツ換装、UID・5追加効果・セーブに接続する。既存IDを別IDへ置換しない。
- `stats.absolute`、`stats.a_relative_percent`、`recipe`、`model.size_delta_percent`、`model.keep_aspect`を使い、表示サイズと戦闘値を具体的に検証する。未承認の`special_effects.description`または`unapproved_classifications`はそのまま暫定として記録し、合意なしに戦闘処理へ確定反映しない。入力にない数値・素材を推測追加しない。
- `render_preset_text`に`SERA_ICON_PRESET_V1`があればモデル原本・撮影設定を照合してGodot GL Compatibilityで撮影する。SERAの正式なアイコンは実際のモデル／材質／輪郭線から取得し、AI画像生成で代替しない。静止PNGは透明な原本として保存しても、ゲーム内表示は`scripts/sera_icon_background.gd`で **#111e28単色＋#55798Aブルーグレーの格子**を合成し、同じ背景をLABO/倉庫/NEXUSで表示する。
- フォームの`ICON`は単体、`FULL BODY`は`NEXUS_pose`、`STATS / FX`は小型単体＋特殊効果、`RECIPE`は必要素材、`ANALYSIS`はX横・Y縦、`EXPORT`は新規チャット引継ぎデータ。2本指のパン/ピンチは2接点の重心・間隔で計算し、接点数変更の瞬間に前回基準を破棄する。
- LABOの製作確認は実際のパーツを単体表示し、ドラッグで回転可能。ゲーム内で倉庫アイコンごとに3Dレンダラーを起動しない。確認UIが開く時に1個だけプレビューを用意し、閉じたら描画を停止する。
- `tools/sera_ci_manifest.txt`の静的/実Godotランタイム検証、Web版ビルド（WASM/PCK）、Android/実機での見え方を区別して検査し、PR経由でmainへ統合する。Github Raw HTML URLはブラウザ起動リンクとして使わない。公開リンクはPages URLを確認して案内する。

## 出力フィールドの見方
- `source.repository_path`: 原本の所在。ギャラリー用の生成画像ではない。
- `equipment.rig_set`: **互換性保持の制作用モデルID**（例: head:D）。同文字の別部位を一括装着する意図はない。
- `equipment.rig_selection`: 全身確認用の個別部位参照マップ。ゲーム内の装備品は別々のUIDで管理。
- `special_effects.approval_required`: 会話で仕様合意する必要がある場合にtrue。
- `handoff.background`: 見た目の正本とゲーム/ツール間の共通契約。
- `render_preset_text`: 撮影設定がユーザー確定でない場合は確定アイコンとして上書きしない。

## 関連
`docs/agent/EQUIPMENT.md`
`docs/SERA_EQUIPMENT_MODEL_LAB_INTAKE_ja.md`
`docs/SERA_HTML_ARTIFACT_DELIVERY_POLICY_ja.md`
`tools/equipment_intake/preview_runtime_check.gd`
`tools/equipment_intake/preview_tabs_contract_self_check.py`
