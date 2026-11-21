extends Control
## One reusable modal over STORAGE inventory. UID/affix data is never copied
## back to persistence; mark toggles use SeraSave's current canonical API.
signal closed
signal marks_changed
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const Icons = preload("res://scripts/sera_item_icons.gd")
const StatTable = preload("res://scripts/sera_warehouse_stats_table.gd")
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const PartViewer = preload("res://scripts/sera_part_preview_widget.gd")

var item: Dictionary = {}
var panel: PanelContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_uid: Label
var preview: Control
var stats_scroll: ScrollContainer
var stats_container: VBoxContainer
var favorite_button: Button
var junk_button: Button

func _ready() -> void:
    name = "WarehouseEquipmentDetailPopup"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    var shade := ColorRect.new()
    shade.name = "WarehouseDetailBackdrop"
    shade.color = Color(0.005, 0.014, 0.023, 0.91)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.gui_input.connect(_on_shade_input)
    add_child(shade)
    panel = PanelContainer.new()
    panel.name = "WarehouseDetailWindow"
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.anchor_left = 0.045
    panel.anchor_right = 0.955
    panel.anchor_top = 0.082
    panel.anchor_bottom = 0.925
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", LaboSkin.panel_style())
    add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 13)
    panel.add_child(margin)
    var content := VBoxContainer.new()
    content.name = "WarehouseDetailContents"
    content.add_theme_constant_override("separation", 10)
    margin.add_child(content)

    var head := HBoxContainer.new()
    head.name = "WarehouseDetailTop"
    head.add_theme_constant_override("separation", 15)
    content.add_child(head)
    detail_icon = TextureRect.new()
    detail_icon.name = "DetailIcon"
    detail_icon.custom_minimum_size = Vector2(86, 86)
    detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    head.add_child(detail_icon)
    var title_column := VBoxContainer.new()
    title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_column.alignment = BoxContainer.ALIGNMENT_CENTER
    head.add_child(title_column)
    detail_name = Label.new()
    detail_name.name = "DetailName"
    detail_name.add_theme_font_override("font", LaboSkin.equipment_font())
    detail_name.add_theme_font_size_override("font_size", 28)
    detail_name.add_theme_color_override("font_color", Color("#e3eff3"))
    detail_name.clip_text = true
    detail_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    title_column.add_child(detail_name)
    LaboSkin.attach_name_underline(detail_name)
    detail_uid = Label.new()
    detail_uid.name = "DetailUID"
    detail_uid.add_theme_font_override("font", LaboSkin.tracked_data_font())
    detail_uid.add_theme_font_size_override("font_size", 15)
    detail_uid.add_theme_color_override("font_color", Color("#93b8c5"))
    title_column.add_child(detail_uid)
    var close := Button.new()
    close.name = "WarehouseDetailClose"
    close.text = "×"
    close.custom_minimum_size = Vector2(46, 47)
    close.add_theme_font_size_override("font_size", 26)
    close.add_theme_stylebox_override("normal", LaboSkin.terminal_segment_style("normal"))
    close.pressed.connect(close_item)
    head.add_child(close)

    var center := CenterContainer.new()
    center.name = "WarehouseDetailPreviewCenter"
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(center)
    preview = PartViewer.new()
    preview.name = "WarehouseDetail3D"
    preview.custom_minimum_size = Vector2(300, 300)
    center.add_child(preview)

    stats_scroll = ScrollContainer.new()
    stats_scroll.name = "WarehouseDetailStatsScroll"
    stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stats_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    content.add_child(stats_scroll)
    stats_container = VBoxContainer.new()
    stats_container.name = "WarehouseDetailStatsBody"
    stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stats_scroll.add_child(stats_container)

    var actions := HBoxContainer.new()
    actions.name = "WarehouseDetailControls"
    actions.add_theme_constant_override("separation", 8)
    content.add_child(actions)
    favorite_button = Button.new()
    favorite_button.name = "WarehouseFavoriteToggle"
    favorite_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    favorite_button.custom_minimum_size.y = 60
    favorite_button.add_theme_font_override("font", LaboSkin.ui_font())
    favorite_button.pressed.connect(_mark.bind("favorite"))
    actions.add_child(favorite_button)
    junk_button = Button.new()
    junk_button.name = "WarehouseJunkToggle"
    junk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    junk_button.custom_minimum_size.y = 60
    junk_button.add_theme_font_override("font", LaboSkin.ui_font())
    junk_button.pressed.connect(_mark.bind("junk"))
    actions.add_child(junk_button)
    resized.connect(_fit_preview)

func _fit_preview() -> void:
    if preview == null:
        return
    # Leave header, complete statistic viewport and action buttons visible.
    var edge: float = minf(size.x * 0.67, size.y * 0.30)
    edge = clampf(edge, 150.0, 410.0)
    preview.custom_minimum_size = Vector2(edge, edge)

func open_item(new_item: Dictionary) -> void:
    var blueprint: String = str(new_item.get("blueprint", ""))
    var spec: Dictionary = Catalog.spec(blueprint)
    if spec.is_empty():
        return
    item = new_item.duplicate(true)
    visible = true
    move_to_front()
    detail_name.text = str(spec.get("name", ""))
    detail_uid.text = str(item.get("uid", ""))
    detail_icon.texture = Icons.equipment_icon(blueprint)
    _refresh_actions()
    for node in stats_container.get_children():
        stats_container.remove_child(node)
        node.queue_free()
    var table: GridContainer = StatTable.build(blueprint, item.get("affixes", []),
        maxf(320.0, size.x * 0.86))
    table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stats_container.add_child(table)
    _fit_preview()
    preview.call("show_part", blueprint)

func _refresh_actions() -> void:
    favorite_button.text = ("★ お気に入り解除" if bool(item.get("favorite", false))
        else "☆ お気に入り")
    junk_button.text = ("不用品指定解除" if bool(item.get("junk", false))
        else "不用品に指定")
    favorite_button.add_theme_stylebox_override("normal",
        LaboSkin.terminal_segment_style("selected" if bool(item.get("favorite", false)) else "normal"))
    junk_button.add_theme_stylebox_override("normal",
        LaboSkin.terminal_segment_style("selected" if bool(item.get("junk", false)) else "normal"))

func _mark(kind: String) -> void:
    var next: bool = not bool(item.get(kind, false))
    var profile: Node = get_tree().root.get_node_or_null("SeraSave")
    if profile != null and bool(profile.call(
            "set_prototype_mark", str(item.get("uid", "")), kind, next)):
        item[kind] = next
        _refresh_actions()
        marks_changed.emit()

func is_open() -> bool:
    return visible

func close_item() -> void:
    if not visible:
        return
    visible = false
    if preview != null:
        preview.call("set_preview_active", false)
    closed.emit()

func _on_shade_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        close_item()
    elif event is InputEventMouseButton and event.pressed and (
            event.button_index == MOUSE_BUTTON_LEFT):
        close_item()
