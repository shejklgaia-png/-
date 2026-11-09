# 脚C（標準骨格）単体ファイルの正規化 — 2026-11-10

## 入力ファイルと位置づけ
- 更新されたユーザー原本: models/storage/足C (1).bbmodel（GitHub同期コミット 5aa796e）。
- 旧原本: models/storage/足C.bbmodel。いずれも削除・上書きしていません。
- 原本の「C」は**制作素材の名前**です。現行ゲーム内 LOWER BODY C は鳥脚で、標準骨格の新しい下半身は LOWER BODY D です。既存セーブの装備IDは変更しません。

## 変換後のファイル
### SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel
- パス: models/storage/SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel
- 最新のユーザー原本の12メッシュの頂点・面・UV・原点・回転を**変更せず**コピー。
- 元の「腰 / 右腿 / 右膝 / 右足 / 右足2」を標準的な Waist、左右 Thigh、LowerLeg、Foot に整理。
- 右の親階層に混在した左腿・左膝下・左足を独立させて正しい左右の親子階層へ移動。
- 右の関節Pivotは最新原本の値に合わせ、左は負X側の実際のメッシュ位置と反対側のPivotから対称に設定。元ファイルの「右足2」Pivotは正X側でしたが、左足メッシュは負X側にあるため、左足Pivotを(-14.1, 13.7, 0)へ正規化。
- 腰・腿・膝下・足・左右を区別できる12個のMesh名へ変更。元のMesh UUIDを維持し、追加する左側骨グループに新規UUIDを使用。

### SERA_LOWER_BODY_D_STANDARD_READY.bbmodel
- パス: models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel
- 現行v193統合モデルから標準A骨格に既に正規化された下半身Dのみを非破壊で抽出した実装向けの単体ファイル。
- 階層: Waist3 → Thigh_L3/R3 → LowerLeg_L3/R3 → Foot_L3/R3。合計7グループ、12メッシュ（腰2・腿4・膝下2・足4）。
- 元統合モデルのDメッシュUUID、面、UV、A互換のPivotとジオメトリは保持。共有の標準骨格アニメーションを利用し、別アニメーションは持ちません。
- **最新版のユーザー原本の更新は主にPivot調整と、外観位置が変わらないようにする1メッシュの原点/ローカル頂点の相殺移動**です。画面上のシルエットが変わるものではありません。

## 運用上の区別・制限
- AUTHOR_NORMALIZED はユーザー編集用のモデル原寸と最新Pivotを尊重した制作用原本です。STANDARD_READY はゲームで使うA骨格の縮尺・関節に変換済みの下半身モデルです。
- 今回はリネーム、制作用ファイルの階層修正、実装可能形式への切り出しのみです。ゲーム側の装備登録、統合ファイル、読込器、セーブ、project.godot は**変更していません**。
- そのため、直前に報告された「デフォルト足のように見える」表示問題が解消したという意味ではありません。表示実機確認と必要なデザイン差・描画修正は残っています。
- 入力および変換の整合性: python3 tools/legs_c_standard_source_self_check.py
- Godot Android / Xperia 1 Vでの描画・モーション・接地は未検証です。
