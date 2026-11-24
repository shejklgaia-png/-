extends RefCounted
## Session-only GRID layout draft. No ownership, saves or resource awards.
const Board = preload("res://scripts/sera_base_power_board.gd")
const CODES = ["S1","S2","S3","A1","A2","A3","E1","E2","E3","O1","O2","O3","GEN","BAT","WIRE","AMP","YIELD","SAVE","ATK","BREAK","HP","DEF","SPD","EN"]
const NAMES = ["スクラップ・低","スクラップ・中","スクラップ・高","金属複合材・低","金属複合材・中","金属複合材・高","電子部品・低","電子部品・中","電子部品・高","有機素材・低","有機素材・中","有機素材・高","変換炉","蓄電池","送電線","容量増幅","生産補助","省電制御","出力増幅","破砕制御","耐久補強","装甲安定","駆動補助","EN循環"]
var entries: Array[Dictionary] = []
var picked: int = -1
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

func clear_selection() -> void:
    picked = -1
    _refresh()

func edit(cell: Vector2i, code: String, mode: String) -> String:
    var idx := _at(cell)
    match mode:
        "PLACE":
            picked = -1
            if not CODES.has(code):
                _refresh()
                return "設備を選択してください"
            var entry := {"cell":cell,"code":code,"rot":0}
            if not _valid(entry):
                _refresh()
                return "配置不可：盤外または重複"
            entries.append(entry)
            _refresh()
            return "配置：" + description(code)
        "MOVE":
            if picked < 0:
                if idx < 0:
                    return "移動する設備を選択"
                picked = idx
                _refresh()
                return "移動先の左上セルをタップ"
            var moved: Dictionary = entries[picked].duplicate()
            moved["cell"] = cell
            if not _valid(moved, picked):
                return "移動不可：盤外または重複"
            entries[picked] = moved
            picked = -1
            _refresh()
            return "移動完了"
        "ROTATE":
            if idx < 0:
                return "回転する設備を選択"
            var rotated: Dictionary = entries[idx].duplicate()
            rotated["rot"] = (int(rotated["rot"]) + 1) % 4
            if not _valid(rotated, idx):
                return "回転不可：盤外または重複"
            entries[idx] = rotated
            _refresh()
            return "90°回転"
        "REMOVE":
            if idx < 0:
                return "撤去する設備を選択"
            entries.remove_at(idx)
            picked = -1
            _refresh()
            return "撤去完了"
    return ""

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
