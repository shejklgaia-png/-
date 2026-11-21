extends Control
## One reusable modal over STORAGE inventory. UID/affix data is never copied
## back to persistence; mark toggles use SeraSave's current canonical API.
signal closed
signal marks_changed
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const Icons = preload("res://scripts/sera_item_icons.gd")
const StatTable = preload("res://scripts/sera_warehouse_stats_table.gd")
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const ChamferSkin = preload("res://scripts/sera_chamfer_skin.gd")
const MarkIcon = preload("res://scripts/sera_mark_icon.gd")
const PartViewer = preload("res://scripts/sera_part_preview_widget.gd")

var item: Dictionary = {}
var panel: PanelContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_uid: Label
var status_mark: Control
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
    shade.color = Color(0.005, 0.014, 0.023, 0.86)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.gui_input.connect(_on_shade_input)
    add_child(shade)

    panel = PanelContainer.new()
    panel.name = "WarehouseDetailWindow"
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.anchor_left = 0.045
    panel.anchor_right = 0.955
    panel.anchor_top = 0.065
    panel.anchor_bottom = 0.895
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    # Matte, true cut corners; the large vertical LABO gradient is not a
    # suitable backdrop for the compact equipment-data hierarchy.
    panel.add_theme_stylebox_override("panel",
        ChamferSkin.style(Color("#0d1b27"), Color("#55798a")))
    add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 12)
    panel.add_child(margin)
    var content := VBoxContainer.new()
    content.name = "WarehouseDetailContents"
    content.add_theme_constant_override("separation", 8)
    margin.add_child(content)

    var eyebrow := HBoxContainer.new()
    eyebrow.name = "WarehouseDetailEyebrow"
    eyebrow.add_theme_constant_override("separation", 8)
    content.add_child(eyebrow)
    _add_tech_label(eyebrow, "03 / STORAGE", true)
    _add_tech_label(eyebrow, "EQUIPMENT DETAIL", false)
    var top_rule := ColorRect.new()
    top_rule.name = "WarehouseDetailSectionRule"
    top_rule.color = Color("#55798a")
    top_rule.custom_minimum_size.y = 2
    top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(top_rule)

    var head := HBoxContainer.new()
    head.name = "WarehouseDetailTop"
    head.add_theme_constant_override("separation", 12)
    content.add_child(head)
    detail_icon = TextureRect.new()
    detail_icon.name = "DetailIcon"
    detail_icon.custom_minimum_size = Vector2(80, 80)
    detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    head.add_child(detail_icon)
    var title_column := VBoxContainer.new()
    title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_column.alignment = BoxContainer.ALIGNMENT_CENTER
    title_column.add_theme_constant_override("separation", 5)
    head.add_child(title_column)
    detail_name = Label.new()
    detail_name.name = "DetailName"
    detail_name.add_theme_font_override("font", LaboSkin.equipment_font())
    detail_name.add_theme_font_size_override("font_size", 30)
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

    # Title-side mark is the same font-independent vector as the card and
    # disposal icon; no fallback glyphs or persistent status banners.
    status_mark = MarkIcon.new()
    status_mark.name = "WarehouseDetailMark"
    status_mark.custom_minimum_size = Vector2(34, 34)
    status_mark.visible = false
    head.add_child(status_mark)
    var close := Button.new()
    close.name = "WarehouseDetailClose"
    close.text = "×"
    close.custom_minimum_size = Vector2(48, 48)
    # HBoxContainer otherwise fills the tall icon/title row vertically.
    # Center the 48 x 48 cut-corner close key without changing its skin.
    close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    close.add_theme_font_override("font", LaboSkin.control_font())
    close.add_theme_font_size_override("font_size", 25)
    close.add_theme_color_override("font_color", Color("#deedf0"))
    _apply_tech_button(close, false, false)
    close.pressed.connect(close_item)
    head.add_child(close)

    content.add_child(_section_heading("01 / MODEL VIEW", "DRAG TO ROTATE"))
    var center := CenterContainer.new()
    center.name = "WarehouseDetailPreviewCenter"
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(center)
    var preview_frame := PanelContainer.new()
    preview_frame.name = "WarehouseDetailPreviewFrame"
    preview_frame.mouse_filter = Control.MOUSE_FILTER_PASS
    preview_frame.add_theme_stylebox_override("panel",
        ChamferSkin.style(Color("#0a1824"), Color("#375d6e")))
    center.add_child(preview_frame)
    var preview_margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        preview_margin.add_theme_constant_override("margin_" + side, 4)
    preview_frame.add_child(preview_margin)
    preview = PartViewer.new()
    preview.name = "WarehouseDetail3D"
    preview.custom_minimum_size = Vector2(320, 320)
    preview_margin.add_child(preview)

    content.add_child(_section_heading("02 / PERFORMANCE", "BASE + TRAITS"))
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
    actions.add_theme_constant_override("separation", 10)
    content.add_child(actions)
    favorite_button = Button.new()
    favorite_button.name = "WarehouseFavoriteToggle"
    favorite_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    favorite_button.custom_minimum_size.y = 60
    favorite_button.add_theme_font_override("font", LaboSkin.control_font())
    favorite_button.add_theme_font_size_override("font_size", 17)
    favorite_button.pressed.connect(_mark.bind("favorite"))
    actions.add_child(favorite_button)
    _add_action_mark(favorite_button, "favorite")
    junk_button = Button.new()
    junk_button.name = "WarehouseJunkToggle"
    junk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    junk_button.custom_minimum_size.y = 60
    junk_button.add_theme_font_override("font", LaboSkin.control_font())
    junk_button.add_theme_font_size_override("font_size", 17)
    junk_button.pressed.connect(_mark.bind("junk"))
    actions.add_child(junk_button)
    _add_action_mark(junk_button, "junk")
    resized.connect(_fit_preview)
    panel.resized.connect(_fit_preview)
    _fit_preview()

func _add_tech_label(parent: HBoxContainer, caption: String,
        expand: bool) -> void:
    var label := Label.new()
    label.text = caption
    label.add_theme_font_override("font", LaboSkin.tracked_data_font())
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color("#85b1be"))
    label.size_flags_horizontal = (
        Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_END)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)

func _section_heading(left: String, right: String) -> HBoxContainer:
    var bar := HBoxContainer.new()
    bar.add_theme_constant_override("separation", 8)
    _add_tech_label(bar, left, true)
    _add_tech_label(bar, right, false)
    return bar

func _add_action_mark(button: Button, kind: String) -> void:
    var icon: Control = MarkIcon.new()
    icon.name = "ActionVectorMark"
    icon.set("kind", kind)
    icon.position = Vector2(12, 17)
    icon.size = Vector2(26, 26)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(icon)

func _apply_tech_button(button: Button, active: bool,
        is_junk: bool) -> void:
    var accent: Color = (
        Color("#fa6570") if is_junk else Color("#f6cd4f"))
    var rim: Color = accent if active else Color("#466b7a")
    var fill: Color = (
        Color("#30202b") if active and is_junk else
        Color("#302c22") if active else Color("#142936"))
    button.add_theme_stylebox_override("normal",
        ChamferSkin.style(fill, rim))
    button.add_theme_stylebox_override("hover",
        ChamferSkin.style(Color("#244251"), accent if active else Color("#78a6b5")))
    button.add_theme_stylebox_override("pressed",
        ChamferSkin.style(Color("#233d49"), accent))
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.add_theme_color_override("font_color",
        accent if active else Color("#dce9ec"))
    button.add_theme_color_override("font_hover_color", Color("#f3f7f8"))
    button.add_theme_color_override("font_pressed_color", Color("#f3f7f8"))

func _fit_preview() -> void:
    if preview == null or panel == null:
        return
    # Keep all eight statistics readable at the standard portrait size.
    # Smaller windows retain a vertical stats scroll rather than losing the
    # controls below the model. The reusable renderer stays exactly square.
    var edge: float = minf(panel.size.x * 0.70, panel.size.y * 0.37)
    edge = clampf(edge, 220.0, 404.0)
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
    var favorite_active: bool = bool(item.get("favorite", false))
    var junk_active: bool = bool(item.get("junk", false))
    favorite_button.text = (
        "お気に入り解除" if favorite_active else "お気に入り")
    junk_button.text = (
        "不用品指定解除" if junk_active else "不用品に指定")
    _apply_tech_button(favorite_button, favorite_active, false)
    _apply_tech_button(junk_button, junk_active, true)
    status_mark.visible = favorite_active or junk_active
    if status_mark.visible:
        status_mark.set("kind", "favorite" if favorite_active else "junk")

func _mark(kind: String) -> void:
    var next: bool = not bool(item.get(kind, false))
    var profile: Node = get_tree().root.get_node_or_null("SeraSave")
    if profile != null and bool(profile.call(
            "set_prototype_mark", str(item.get("uid", "")), kind, next)):
        item[kind] = next
        # The save layer enforces mutual exclusion; refresh against persisted
        # UID data instead of leaving a stale badge when changing category.
        if next:
            item["junk" if kind == "favorite" else "favorite"] = false
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
