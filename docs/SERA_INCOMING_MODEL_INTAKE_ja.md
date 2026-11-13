# SERA 新規Blockbench取り込み（strage / storage）

ユーザーからの取り込み依頼を契機に実行します。単なるアップロードでは自動的に統合作業を開始しません。

## 必須作業フロー

When the user asks to integrate a newly uploaded Blockbench file, first inspect GitHub `strage/`, `models/strage/`, and **`models/storage/`** (the current real directory), including recently added named `.bbmodel` files. Treat these as temporary *incoming* sources, not canonical runtime paths. Match the user's named target and inspect the file's actual diff and Git history rather than blindly selecting an old similarly named model. Never modify or delete other incoming files.

For an incoming **Katana** file:
1. Compare it with `models/core/Katana.bbmodel` using JSON group/mesh/outliner/UUID/animation diffs. Retain the canonical geometry, UVs, pivots and untouched clips; for user-edited `Melee_katana` and `Melee_katana2`, **replace the same-named entire animation entries**, preserving the author's keyframe times, position/rotation/**scale**, UUID references and Swordeffect tracks. Do not merge old and new keys by concatenation.
2. Use the existing **v85 Swordeffect creation method** in `scripts/sword_trail.gd`: the authored `Swordeffect` plate is a hidden moving reference; the alpha-cutout main arc, convex 3D volume and particles are created on its original animated parent and transform. Verify `Swordeffect` UUID maps to the canonical Standard rig, both Katana clips actually drive its transform, and the Katana combo starts/stops the effect. Never display the raw rectangular plate or add an independent fixed-position sword effect.
3. Rebuild the Android embedded source with `python3 tools/sera_model_build.py --write`; run `--check`, the animation runtime smoke test, dedicated Swordeffect playback/mesh checks, render policy checks and **full** PR CI. If non-animation model changes are intentionally requested, use the general model integration guide and rebuild all affected snapshots.
4. **Only after successfully integrating and validating the canonical source**, audit runtime paths, CI, docs, history, and other references for the *specific incoming file*. Delete it from the temporary incoming folder **only if it is unreferenced and every intended authored change is preserved** in the canonical model; leave historical fixtures, other uploaded sources, canonical files, `*.import` metadata and unique unmerged content untouched. Git history remains available for recovery.
5. Update `models/manifest.json` only if the canonical role actually changes; log the source, imported clip names, Swordeffect mapping and deleted temporary file in `DEVELOPMENT.md`. Work via a PR and merge only when all checks pass. Android GL Compatibility visual validation remains separate.

This is the procedure for the next requested file import. Having these instructions does **not** mean imports run automatically upon each GitHub upload.



## 取り込みの注意点
- 実在する配置先は`models/storage/`です。`strage`表記も検索キーワードとして扱い、実在する別フォルダがあれば確認します。
- 今回のKatanaは`models/storage/Katana.bbmodel`から同名の2クリップを`models/core/Katana.bbmodel`へ置換。正本のボーン・メッシュ・Pivot・UVは不変、元の`Swordeffect` UUIDに追加された位置・回転・拡大率キーフレームを反映します。
- Godot側は既存v85`scripts/sword_trail.gd`が不可視のSwordeffect板と同一ボーンに生成するアルファ切り抜き弧・立体ボリューム・粒子を使用します。新しい生板表示や重複生成を禁止します。
- `models/manifest.json`とランタイム参照・テスト・履歴の照合を済ませ、利用されていない受け渡しファイルのみ削除します。履歴モデルや未統合の制作ファイルは保持します。
