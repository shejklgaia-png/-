extends Control
## BASE/GRID presentation-only controls. Interactive selections do NOT create
## simulated machines, consume resources, or persist any board occupancy.
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const Cut = preload("res://scripts/sera_base_grid_cut_control.gd")
const CODES = ["G", "H", "K", "P", "C", "D", "R", "X", "Y", "T", "O"]
const MODES = ["PLACE", "MOVE", "ROTATE"]
const MODE_LABELS = ["配置", "移動", "回転"]

signal node_chosen(code: String)
signal operation_changed(operation: String)

var base_plate: Control
var grid_plate: Control
var tray: Panel
var scroll: ScrollContainer
var modules: Dictionary = {}
var rail: Control
var tools: Dictionary = {}
var tray_title: Label
var grid_open: bool = false
var editing: bool = false
var selected_code: String = ""
var selected_operation: String = "PLACE"
var slide: Tween
var tray_slide: Tween
var view_size: Vector2 = Vector2(720, 1280)
var title_width: float = 284.0
var title_height: float = 81.0
var tray_height: float = 146.0


func _ready() -> void:
    name = "BaseGridPresentation"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    base_plate = _cut("ModePlateBASE", "title", "BASE", "拠点")
    grid_plate = _cut("ModePlateGRID", "title", "GRID", "電力制御")
    tray = Panel.new()
    tray.name = "GridModuleTray"
    tray.mouse_filter = Control.MOUSE_FILTER_STOP
    tray.add_theme_stylebox_override("panel", LaboSkin.panel_style())
    add_child(tray)
    tray_title = Label.new()
    tray_title.name = "ModuleTrayTitle"
    tray_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tray_title.text = "NODE PALETTE  /  PREVIEW"
    tray_title.add_theme_font_override("font", LaboSkin.data_font())
    tray_title.add_theme_font_size_override("font_size", 17)
    tray_title.add_theme_color_override("font_color", Color("#bacbd6"))
    tray.add_child(tray_title)
    scroll = ScrollContainer.new()
    scroll.name = "NodeListScroll"
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tray.add_child(scroll)
    var row := HBoxContainer.new()
    row.name = "NodeRow"
    row.add_theme_constant_override("separation", 7)
    scroll.add_child(row)
    for code in CODES:
        var module: Control = Cut.new()
        module.name = "Node_" + code
        module.custom_minimum_size = Vector2(74, 78)
        module.size = Vector2(74, 78)
        row.add_child(module)
        module.call("configure", "module", code, "MODULE")
        module.connect("activated", Callable(self, "_choose_node"))
        modules[code] = module
    rail = Control.new()
    rail.name = "GridOperationRail"
    rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(rail)
    for i in range(MODES.size()):
        var operation: Control = Cut.new()
        operation.name = "Operation_" + MODES[i]
        operation.position = Vector2(0, float(i) * 88.0)
        operation.size = Vector2(68.0, 76.0)
        rail.add_child(operation)
        operation.call("configure", "icon", MODES[i], MODE_LABELS[i])
        operation.connect("activated", Callable(self, "_choose_operation"))
        tools[MODES[i]] = operation
    _choose_operation("PLACE")
    tray.visible = false
    rail.visible = false
    reflow(get_viewport().get_visible_rect().size)


func _cut(identifier: String, kind: String, title: String,
        description: String) -> Control:
    var node: Control = Cut.new()
    node.name = identifier
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(node)
    node.call("configure", kind, title, description)
    return node


func reflow(dims: Vector2) -> void:
    view_size = Vector2(maxf(1.0, dims.x), maxf(1.0, dims.y))
    size = view_size
    title_width = minf(284.0, maxf(224.0, view_size.x * 0.66))
    title_height = 81.0
    tray_height = 146.0
    base_plate.size = Vector2(title_width, title_height)
    grid_plate.size = Vector2(title_width, title_height)
    base_plate.queue_redraw()
    grid_plate.queue_redraw()
    base_plate.position = Vector2(-title_width - 14, 14) if grid_open else (
        Vector2(10, 14))
    grid_plate.position = Vector2(10, 14) if grid_open else (
        Vector2(view_size.x + 24, 14))
    tray.size = Vector2(view_size.x - 24.0, tray_height)
    tray.position = Vector2(12.0,
        view_size.y - tray_height - 10.0 if editing else view_size.y + 12.0)
    tray_title.position = Vector2(18, 11)
    tray_title.size = Vector2(tray.size.x - 36, 28)
    scroll.position = Vector2(12, 46)
    scroll.size = Vector2(tray.size.x - 24, 86)
    rail.size = Vector2(68, 252)
    rail.position = Vector2(view_size.x - 77.0 if editing else
        view_size.x + 18.0, maxf(120.0, view_size.y * 0.41 - 50.0))


func set_grid(show: bool, animate: bool = true) -> void:
    if slide != null and slide.is_running():
        slide.kill()
    grid_open = show
    var base_target: Vector2 = Vector2(-title_width - 14, 14) if show else (
        Vector2(10, 14))
    var grid_target: Vector2 = Vector2(10, 14) if show else (
        Vector2(view_size.x + 24, 14))
    if not animate:
        base_plate.position = base_target
        grid_plate.position = grid_target
        return
    # Directional lateral trade: BASE leaves left / GRID comes from right;
    # the return animates the same lane in reverse.
    if show:
        grid_plate.position = Vector2(view_size.x + 24, 14)
    else:
        base_plate.position = Vector2(-title_width - 14, 14)
    slide = create_tween()
    slide.set_parallel(true)
    slide.set_trans(Tween.TRANS_CUBIC)
    slide.set_ease(Tween.EASE_OUT)
    slide.tween_property(base_plate, "position", base_target, 0.20)
    slide.tween_property(grid_plate, "position", grid_target, 0.20)


func set_edit(show: bool, animate: bool = true) -> void:
    if tray_slide != null and tray_slide.is_running():
        tray_slide.kill()
    editing = show
    if show:
        tray.visible = true
        rail.visible = true
    var tray_target := Vector2(12.0,
        view_size.y - tray_height - 10.0 if show else view_size.y + 12.0)
    var rail_target := Vector2(view_size.x - 77.0 if show else
        view_size.x + 18.0, maxf(120.0, view_size.y * 0.41 - 50.0))
    if not animate:
        tray.position = tray_target
        rail.position = rail_target
        tray.visible = show
        rail.visible = show
        return
    tray_slide = create_tween()
    tray_slide.set_parallel(true)
    tray_slide.set_trans(Tween.TRANS_CUBIC)
    tray_slide.set_ease(Tween.EASE_OUT)
    tray_slide.tween_property(tray, "position", tray_target, 0.30)
    tray_slide.tween_property(rail, "position", rail_target, 0.25)
    if not show:
        tray_slide.finished.connect(_hide_tools_after_exit)


func _hide_tools_after_exit() -> void:
    if not editing:
        tray.visible = false
        rail.visible = false


func _choose_node(value: String) -> void:
    if not modules.has(value):
        return
    selected_code = value
    for code in modules:
        var item: Control = modules[code]
        item.set("selected", code == value)
        item.queue_redraw()
    tray_title.text = "NODE / " + value + "    PREVIEW ONLY"
    _choose_operation("PLACE")
    node_chosen.emit(value)


func _choose_operation(value: String) -> void:
    if not tools.has(value):
        return
    selected_operation = value
    for key in tools:
        var item: Control = tools[key]
        item.set("selected", key == value)
        item.queue_redraw()
    operation_changed.emit(value)


func is_interface_hit(pixel: Vector2) -> bool:
    # Used by BASE's raw _input, which precedes Control._gui_input.
    if Rect2(grid_plate.position, grid_plate.size).has_point(pixel):
        return true
    if editing:
        if Rect2(tray.position, tray.size).has_point(pixel):
            return true
        if Rect2(rail.position, rail.size).has_point(pixel):
            return true
    return false
