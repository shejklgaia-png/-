extends RefCounted
## Session-only GRID layout draft. No ownership, saves or resource awards.
const Board = preload("res://scripts/sera_base_power_board.gd")
const CODES = ["S1","S2","S3","A1","A2","A3","E1","E2","E3","O1","O2","O3","GEN","BAT","WIRE","AMP","YIELD","SAVE","ATK","BREAK","HP","DEF","SPD","EN"]
const NAMES = ["スクラップ・低","スクラップ・中","スクラップ・高","金属複合材・低","金属複合材・中","金属複合材・高","電子部品・低","電子部品・中","電子部品・高","有機素材・低","有機素材・中","有機素材・高","変換炉","蓄電池","送電線","容量増幅","生産補助","省電制御","出力増幅","破砕制御","耐久補強","装甲安定","駆動補助","EN循環"]
var entries: Array[Dictionary] = []
var picked: int = -1
var drag_origin := Vector2i.ZERO
var grab_offset := Vector2i.ZERO
var dragging := false
var bodies: MultiMeshInstance3D
var marks: MultiMeshInstance3D

static func footprint(code: String) -> Vector2i:
    if code in ["S1","A1","E1","O1","BAT","AMP","YIELD","SAVE"]:
        return Vector2i(1,2)
    if code in ["S2","A2","E2","O2","GEN"]:
        return Vector2i(2,2)
    if code in ["S3","A3","E3","O3","DEF"]:
        return Vector2i(2,4)
    if code == "WIRE":
        return Vector2i(1,1)
    return Vector2i(2,3)

static func description(code: String) -> String:
    var idx: int = CODES.find(code)
    if idx < 0:
        return ""
    var f := footprint(code)
    return "%s / %dマス" % [NAMES[idx], f.x * f.y]

func setup(parent: Node3D) -> void:
    bodies = _batch(parent, "GridDraftBodies")
    marks = _batch(parent, "GridDraftDirectionMarks")
    _refresh()

func _batch(parent: Node3D, label: String) -> MultiMeshInstance3D:
    var node := MultiMeshInstance3D.new()
    node.name = label
    var mult := MultiMesh.new()
    mult.transform_format = MultiMesh.TRANSFORM_3D
    mult.use_colors = true
    mult.mesh = BoxMesh.new()
    mult.instance_count = Board.GRID_SIDE * Board.GRID_SIDE
    mult.visible_instance_count = 0
    node.multimesh = mult
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 0.8
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    return node

func _size(entry: Dictionary) -> Vector2i:
    var f := footprint(str(entry["code"]))
    return Vector2i(f.y, f.x) if int(entry["rot"]) % 2 == 1 else f

func _area(entry: Dictionary) -> Rect2i:
    return Rect2i(Vector2i(entry["cell"]), _size(entry))

func _at(cell: Vector2i) -> int:
    for i in range(entries.size()):
        if _area(entries[i]).has_point(cell):
            return i
    return -1

func _valid(entry: Dictionary, skip: int = -1) -> bool:
    var rect := _area(entry)
    if not Rect2i(Vector2i.ZERO, Vector2i(Board.GRID_SIDE, Board.GRID_SIDE)).encloses(rect):
        return false
    for i in range(entries.size()):
        if i != skip and rect.intersects(_area(entries[i])):
            return false
    return true

static func detail(code: String) -> String:
    if code in CODES.slice(0,12):
        match code.right(1):
            "1": return "低品質素材を生産 / 原料10まで・最大10個 / 0.6EP/原料"
            "2": return "中品質素材を生産 / 原料20まで・最大7個 / 1EP/原料"
            "3": return "高品質素材を生産 / 原料40まで・最大5個 / 1.4EP/原料"
    match code:
        "GEN": return "帰還時に外部エネルギーを最大140EP変換"
        "BAT": return "蓄電容量を500EP拡張"
        "WIRE": return "設備を給電網に接続 / 維持費0.25EP/出撃"
        "AMP": return "隣接する変換炉1基の容量＋15%"
        "YIELD": return "隣接する生産設備1基の収率＋5%"
        "SAVE": return "隣接する生産設備1基の加工電力−10%"
        "ATK": return "近接ダメージ＋6% / 出撃前25EP（暫定）"
        "BREAK": return "部位破壊ダメージ＋10% / 出撃前20EP（暫定）"
        "HP": return "最大HP＋8% / 出撃前15EP（暫定）"
        "DEF": return "最終被ダメージ−6% / 出撃前20EP（暫定）"
        "SPD": return "移動・ブースト速度＋5% / 出撃前18EP（暫定）"
        "EN": return "EN自然回復速度＋10% / 出撃前18EP（暫定）"
    return ""

func selected_code() -> String:
    return str(entries[picked]["code"]) if picked >= 0 and picked < entries.size() else ""

func selected_rect() -> Rect2i:
    return _area(entries[picked]) if not selected_code().is_empty() else Rect2i()

func clear_selection() -> void:
    cancel_drag()
    picked = -1
    _refresh()

func select_at(cell: Vector2i) -> bool:
    picked = _at(cell)
    _refresh()
    return picked >= 0

func begin_drag(cell: Vector2i) -> bool:
    if not select_at(cell):
        return false
    drag_origin = Vector2i(entries[picked]["cell"])
    grab_offset = cell - drag_origin
    dragging = true
    return true

func move_drag(cell: Vector2i) -> bool:
    if not dragging or picked < 0:
        return false
    var moved: Dictionary = entries[picked].duplicate()
    moved["cell"] = cell - grab_offset
    if not _valid(moved, picked):
        return false
    if moved["cell"] != entries[picked]["cell"]:
        entries[picked] = moved
        _refresh()
    return true

func cancel_drag() -> void:
    if dragging and picked >= 0:
        entries[picked]["cell"] = drag_origin
        dragging = false
        _refresh()
    dragging = false

func finish_drag(cell: Vector2i, valid_target: bool) -> bool:
    if not dragging:
        return false
    if not valid_target or not move_drag(cell):
        cancel_drag()
        return false
    dragging = false
    return true

func rotate_selected(direction: int) -> String:
    if picked < 0:
        return "設備を選択してください"
    var rotated: Dictionary = entries[picked].duplicate()
    rotated["rot"] = posmod(int(rotated["rot"]) + direction, 4)
    if not _valid(rotated, picked):
        return "回転不可：盤外または重複"
    entries[picked] = rotated
    _refresh()
    return "90°回転"

func edit(cell: Vector2i, code: String, mode: String) -> String:
    var idx := _at(cell)
    if mode == "REMOVE":
        if idx < 0:
            return "撤去する設備を選択"
        entries.remove_at(idx)
        picked = -1
        _refresh()
        return "撤去完了"
    if idx >= 0:
        select_at(cell)
        return "選択：ドラッグで移動 / 矢印で回転"
    if not CODES.has(code):
        clear_selection()
        return "設備を選択してください"
    var entry := {"cell":cell,"code":code,"rot":0}
    if not _valid(entry):
        return "配置不可：盤外または重複"
    entries.append(entry)
    picked = entries.size()-1
    _refresh()
    return "配置完了：ドラッグで移動 / 矢印で回転"

func _color(code: String) -> Color:
    if code in ["S1","S2","S3"]:
        return Color("#a58971")
    if code in ["A1","A2","A3"]:
        return Color("#849eb4")
    if code in ["E1","E2","E3"]:
        return Color("#59a8ba")
    if code in ["O1","O2","O3"]:
        return Color("#78a68a")
    if code in ["GEN","BAT","WIRE"]:
        return Color("#c2a96b")
    return Color("#a28eb8")

func _refresh() -> void:
    if not is_instance_valid(bodies) or not is_instance_valid(marks):
        return
    var pitch: float = Board.CELL_PITCH
    var half: float = (Board.GRID_SIDE - 1) * 0.5
    for i in range(entries.size()):
        var e: Dictionary = entries[i]
        var rect := _area(e)
        var center := Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) * 0.5
        var pos := Board.BOARD_CENTER + Vector3((center.x-half)*pitch, 0.61, (center.y-half)*pitch)
        var code: String = str(e["code"])
        var height: float = 0.10 if code == "WIRE" else 0.34
        pos.y = 0.423 + height * 0.5
        var scale := Vector3(rect.size.x*pitch-0.13,height,rect.size.y*pitch-0.13)
        bodies.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(scale),pos))
        bodies.multimesh.set_instance_color(i, Color("#d1f1ff") if i == picked else _color(code))
        var direction: Vector3 = [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT][int(e["rot"])]
        var reach: float = (scale.x if absf(direction.x) > 0.5 else scale.z) * 0.5 - 0.16
        var marker := pos + direction * maxf(0.0, reach) + Vector3.UP * (height*0.5+0.025)
        marks.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.19,0.045,0.19)),marker))
        marks.multimesh.set_instance_color(i, Color("#d5f4ff"))
    bodies.multimesh.visible_instance_count = entries.size()
    marks.multimesh.visible_instance_count = entries.size()
