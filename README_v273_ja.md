# SERA v273 — 既存モーションと同じ固定名参照で左右蹴りを実行

## 実機の新しい証拠
v272実機スクリーンショットには **`KICK: CLIP MISSING R ALREADY READY`** と表示されています。v271の`EMBEDDED FAILED`から変化したことを示しますが、これは正確には以下の異なる二つの判定が衝突しています。

1. 起動中に`_restore_dedicated_side_kicks()`が、左右両方の再生可能なクリップ・キーの存在を検知し、`dedicated_side_kick_status = "ALREADY READY"`と記録した。
2. 指のフリック時に`has_side_kick(1)`が`_side_kick_clip_for(1)`を呼び、右蹴りのクリップ名を取得できず**false**を返した。

起動時に有効な`Kick_r`があったにもかかわらず、発動時の**名前検索が失敗**しています。データを増やすだけでは解決しない状態でした。ユーザーの指摘どおり、通常の`Melee3`や`Bash`などは既知の固定名を直接使うため、この新設検索処理は通っていません。

## 原因箇所
v272の`_side_kick_clip_for(side)`は以下の構文を使っていました。

```gdscript
var preferred: Array[String] = ["Kick_r", ...] if side > 0 else ["Kick_l", ...]
```

Godotには**条件式の結果を型付き配列へ直接代入すると実行時の型エラーとなり得る**既知の問題があります（godotengine/godot#110628、#83026）。スクリプトがコンパイルされたり静的テストを通過したりしても、実機のこの関数だけが失敗します。今回の症状と高い整合性がありますが、端末のGodotエラーログを直接取得してはいないため、これが単独の直接原因だったかの最終確認はこれからです。

## 対処
- `_side_kick_clip_for(1)`はまず**`"Kick_r"`を直接**確認、`_side_kick_clip_for(-1)`はまず**`"Kick_l"`を直接**確認します。既存のMelee・Bashのように`animations`辞書へ固定名でアクセスし、原因となる`Array[String]`への条件式代入を完全に廃止します。
- 既存の改名したクリップへの互換検索は、明示的な`if/else`と**型指定のない配列**で維持します。
- `start_side_kick`の別の潜在バグを修正。従来は`has_side_kick`が不足クリップを復元する**前**に選択名を取得していたため、復元成功でも空文字のまま再生開始を試みる可能性がありました。復元確認**後**に取得するよう変更しました。
- `get_side_kick_diagnostic`は起動時の過去の`ALREADY READY`状態だけではなく、現在のキー存在・クリップ名の実際の検索結果を再検査します。
- 既存のモデル本体、元Blockbenchアニメーション・キーフレーム、装備、STEP、格闘・Bash、受付方向・タイミング、EN・カメラは変更しません。

## 今回からの実行時検証
`tools/v273_kick_lookup_self_check.py`で固定名・入力範囲・クリップ名取得後の復元順序を検証します。**さらにGodot 4.7.2をGitHub Actions上で起動**し、実際の`SeraRig`を初期化して`has_side_kick(+1/-1)`、`start_side_kick(+1/-1)`と`current_clip`が`Kick_r`・`Kick_l`になることを`tools/v273_kick_lookup_runtime_check.gd`で検証します。過去の検査はソーステキストとデータ構造が中心で、Godot実行時に型不一致で関数が停止する問題を検出できませんでした。

GitHub Actions上でのGodot 4.7.2検査はLinux headlessです。Androidのタッチ操作・実機描画まで同じと保証するものではありません。
