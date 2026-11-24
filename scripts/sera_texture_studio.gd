extends Control
signal closed
const UV = preload("res://scripts/sera_texture_uv.gd")
const PartSource = preload("res://scripts/sera_texture_part_source.gd")
const PartCatalog = preload("res://scripts/sera_prototype_catalog.gd")
const PartIcons = preload("res://scripts/sera_item_icons.gd")
const SAVE_DIR := "user://texture_studio"
var candidates: Array[MeshInstance3D] = []
var external_root: Node3D
# PopupMenu is a separate Window and does not reliably receive native
# Android touch when the game disables mouse emulation. Keep choices
# in the same canvas as the editor instead.
class StudioChoice:
    extends Button
    signal item_selected(index: int)
    var labels: Array[String] = []
    var ids: Array[int] = []
    var selected: int = -1
    var caption: String = ""

    func add_item(label: String, id: int = -1) -> void:
        labels.append(label)
        ids.append(labels.size()-1 if id == -1 else id)
        if selected < 0:
            select(0)

    func clear() -> void:
        labels.clear()
        ids.clear()
        select(-1)

    func select(index: int) -> void:
        selected = index if index >= 0 and index < labels.size() else -1
        text = (labels[selected] if selected >= 0 else "未選択")+"  ▾"

    func get_selected_id() -> int:
        return get_item_id(selected)

    func get_item_id(index: int) -> int:
        return ids[index] if index >= 0 and index < ids.size() else -1

    func choose(index: int) -> void:
        if index < 0 or index >= labels.size():
            return
        select(index)
        item_selected.emit(index)

var picker: StudioChoice
var choice_buttons: Array[StudioChoice] = []
var choice_overlay: Control
var choice_panel: PanelContainer
var choice_scroll: ScrollContainer
var choice_rows: Array[Button] = []
var choice_cancel: Button
var active_choice: StudioChoice
var pending_choice: StudioChoice
var choice_touch: int = -1
var choice_origin: Vector2 = Vector2.ZERO
var choice_scroll_start: int = 0
var choice_dragged: bool = false
var choice_started_in_list: bool = false
var choice_pressed_row: int = -1
var choice_pressed_cancel: bool = false
var choice_pressed_outside: bool = false
var selected_model_label: Label
var mesh_picker_row: HBoxContainer
var density_picker: StudioChoice
var tool_picker: StudioChoice
var color_picker: ColorPickerButton
var status: Label
var host: SubViewportContainer
var view: SubViewport
var pivot: Node3D
var camera: Camera3D
var preview: MeshInstance3D
var atlas_preview: TextureRect
var img: Image
var original: Image
var tex: ImageTexture
var triangles: Array = []
var undo_stack: Array[Image] = []
var redo_stack: Array[Image] = []
var points: Dictionary = {}
var last_point := Vector2.ZERO
var last_hit := Vector2i(-1,-1)
var last_chart := -1
var previous_mirror := Vector2i(-1,-1)
var previous_mirror_chart := -1
var stroke := false
var rotation_mode := false
var multi_gesture := false
var yaw := 0.65
var pitch := -0.25
var zoom := 3.0
var radius := 1.0
var center := Vector3.ZERO
var source: MeshInstance3D
var file_dialog: FileDialog
var paint_tools: Array[String] = ["ペン","消しゴム","スポイト","面塗り","明るく","暗く","ノイズ","直線","矩形","摩耗","傷","番号01","警告"]
var shape_start := Vector2i(-1,-1)
var shape_chart := -1
var shape_base: Image
var layers: Array[Image] = []
var layer_visible: Array[bool] = []
var layer_picker: StudioChoice
var diameter_picker: StudioChoice
var symmetric: CheckButton
var layer_toggle: Button
var layer_index := 0
var brush_size := 1
var atlas_density := 32
const MAX_LAYERS := 4
var part_rig: Node3D
var part_source: MeshInstance3D
var part_panel: PanelContainer
var part_scroll: ScrollContainer
var part_cards: Dictionary = {}
var part_loading := false
var catalog_touch := -1
var catalog_start := Vector2.ZERO
var catalog_scroll_start := 0
var catalog_dragged := false

func configure(roots: Array) -> void:
    for root in roots:
        if is_instance_valid(root):
            _collect(root)
    _build_ui()
    _refresh_picker()
    picker.select(-1)
    _open_part_catalog()

func _collect(node: Node) -> void:
    if node is MeshInstance3D and node.mesh != null and node.skin == null and not candidates.has(node):
        candidates.append(node)
    for child in node.get_children():
        if not child is SubViewport:
            _collect(child)

func _button(parent: Container, label: String, callback: Callable) -> Button:
    var btn := Button.new()
    btn.text = label
    btn.custom_minimum_size = Vector2(0,54)
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.add_theme_font_size_override("font_size",20)
    btn.pressed.connect(callback)
    parent.add_child(btn)
    return btn

func _row(parent: Container) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",6)
    parent.add_child(row)
    return row

func _build_ui() -> void:
    name = "TextureStudio"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var backdrop := ColorRect.new()
    backdrop.color = Color("#101d28")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+edge,12)
    add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation",8)
    margin.add_child(box)
    var title := Label.new()
    title.text = "TEXTURE STUDIO / テクスタ"
    title.add_theme_font_size_override("font_size",25)
    box.add_child(title)
    var row := _row(box)
    selected_model_label = Label.new()
    selected_model_label.text = "パーツ未選択"
    selected_model_label.clip_text = true
    selected_model_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    selected_model_label.add_theme_font_size_override("font_size",20)
    row.add_child(selected_model_label)
    _button(row,"パーツ選択",_open_part_catalog)
    row = _row(box)
    _button(row,"個別メッシュ",_toggle_mesh_picker)
    _button(row,"読込",_open_file)
    mesh_picker_row = _row(box)
    picker = _new_choice("個別メッシュ")
    picker.custom_minimum_size.y = 54
    picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    picker.clip_text = true
    picker.item_selected.connect(_select_model)
    mesh_picker_row.add_child(picker)
    mesh_picker_row.hide()
    row = _row(box)
    density_picker = _new_choice("ピクセル密度")
    for d in [8,16,32,64]:
        density_picker.add_item("%d px/m"%d,d)
    density_picker.select(2)
    density_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(density_picker)
    _button(row,"UV再展開",_rebuild)
    host = SubViewportContainer.new()
    host.name = "TexturePaintView"
    host.stretch = true
    host.size_flags_vertical = Control.SIZE_EXPAND_FILL
    host.custom_minimum_size.y = 300
    host.mouse_filter = Control.MOUSE_FILTER_STOP
    host.gui_input.connect(_view_input)
    box.add_child(host)
    view = SubViewport.new()
    view.own_world_3d = true
    view.size = Vector2i(600,600)
    view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    view.gui_disable_input = true
    host.add_child(view)
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#263747")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    env.ambient_light_energy = 1.0
    world.environment = env
    view.add_child(world)
    env.ambient_light_energy = 0.6
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-42,-35,0)
    light.light_energy = 0.9
    view.add_child(light)
    pivot = Node3D.new()
    view.add_child(pivot)
    preview = MeshInstance3D.new()
    pivot.add_child(preview)
    camera = Camera3D.new()
    camera.current = true
    camera.near = 0.001
    view.add_child(camera)
    row = _row(box)
    tool_picker = _new_choice("描画ツール")
    tool_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for name_text in paint_tools:
        tool_picker.add_item(name_text)
    row.add_child(tool_picker)
    color_picker = ColorPickerButton.new()
    color_picker.color = Color("#8daebd")
    color_picker.edit_alpha = false
    color_picker.custom_minimum_size = Vector2(88,54)
    row.add_child(color_picker)
    var mode: Button = _button(row,"回転 / 描画",_toggle_rotation_mode)
    mode.toggle_mode = true
    row = _row(box)
    layer_picker = _new_choice("レイヤー")
    layer_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layer_picker.item_selected.connect(_select_layer)
    row.add_child(layer_picker)
    _button(row,"＋",_add_layer)
    layer_toggle = _button(row,"表示",_toggle_layer)
    _button(row,"削除",_delete_layer)
    row = _row(box)
    diameter_picker = _new_choice("ブラシサイズ")
    for d in [1,3,5]:
        diameter_picker.add_item("%d px" % d,d)
    diameter_picker.item_selected.connect(_set_brush_size)
    row.add_child(diameter_picker)
    symmetric = CheckButton.new()
    symmetric.text = "X対称"
    row.add_child(symmetric)
    _button(row,"Undo",_undo)
    _button(row,"Redo",_redo)
    row = _row(box)
    _button(row,"UV表示",_toggle_atlas)
    _button(row,"保存",_save)
    atlas_preview = TextureRect.new()
    atlas_preview.custom_minimum_size.y = 160
    atlas_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    atlas_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    atlas_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    atlas_preview.visible = false
    box.add_child(atlas_preview)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.clip_text = true
    status.custom_minimum_size.y = 46
    status.text = "モデルを選択してください"
    box.add_child(status)
    _button(box,"‹ LABOへ戻る",request_close)
    _camera_pose()

func _open_part_catalog() -> void:
    if part_loading:
        return
    if not is_instance_valid(part_panel):
        _build_part_catalog()
    _end_stroke()
    points.clear()
    catalog_touch = -1
    part_panel.show()
    view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _build_part_catalog() -> void:
    part_panel = PanelContainer.new()
    part_panel.name = "EquipmentThumbnailCatalog"
    part_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    part_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var background := StyleBoxFlat.new()
    background.bg_color = Color("#101d28")
    part_panel.add_theme_stylebox_override("panel",background)
    add_child(part_panel)
    var margin := MarginContainer.new()
    for side in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+side,14)
    part_panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation",8)
    margin.add_child(box)
    var title := Label.new()
    title.text = "PARTS / パーツ選択"
    title.add_theme_font_size_override("font_size",25)
    box.add_child(title)
    var hint := Label.new()
    hint.text = "既存装備をタップして3D編集"
    box.add_child(hint)
    part_scroll = ScrollContainer.new()
    part_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    part_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    part_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    box.add_child(part_scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation",8)
    part_scroll.add_child(list)
    var groups := {"head":"頭部","torso":"胴体","arms":"腕部","legs":"脚部","booster":"ブースター","weapon_r":"右手武器","weapon_l":"左手武器"}
    for slot in groups:
        var heading := Label.new()
        heading.text = str(groups[slot])
        heading.add_theme_font_size_override("font_size",19)
        list.add_child(heading)
        var grid := GridContainer.new()
        grid.columns = 2
        grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        grid.add_theme_constant_override("h_separation",8)
        grid.add_theme_constant_override("v_separation",6)
        list.add_child(grid)
        for raw_id in PartCatalog.ORDER:
            var id := str(raw_id)
            var spec: Dictionary = PartCatalog.spec(id)
            if str(spec.get("slot","")) != slot:
                continue
            var card := Button.new()
            card.name = "Part_"+id
            card.custom_minimum_size = Vector2(0,120)
            card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            card.pressed.connect(_choose_part.bind(id))
            grid.add_child(card)
            part_cards[id] = card
            var inside := HBoxContainer.new()
            inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            inside.offset_left = 6
            inside.offset_right = -6
            inside.offset_top = 6
            inside.offset_bottom = -6
            inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
            card.add_child(inside)
            var image := TextureRect.new()
            image.texture = PartIcons.equipment_icon(id,"craft")
            image.custom_minimum_size = Vector2(96,96)
            image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            image.mouse_filter = Control.MOUSE_FILTER_IGNORE
            inside.add_child(image)
            var label := Label.new()
            label.text = id+"\n"+str(spec.get("name",""))
            label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            label.add_theme_font_size_override("font_size",18)
            label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            inside.add_child(label)
    _button(box,"‹ 編集画面へ",_close_part_catalog)

func _close_part_catalog() -> void:
    if is_instance_valid(part_panel):
        part_panel.hide()
    catalog_touch = -1
    view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

func _new_choice(caption: String) -> StudioChoice:
    var button := StudioChoice.new()
    button.caption = caption
    button.clip_text = true
    button.custom_minimum_size.y = 54
    button.add_theme_font_size_override("font_size",20)
    button.pressed.connect(_open_choice.bind(button))
    choice_buttons.append(button)
    return button

func _open_choice(button: StudioChoice) -> void:
    if not is_instance_valid(button) or button.labels.is_empty() or part_loading:
        return
    if is_instance_valid(choice_overlay):
        _close_choice()
    _end_stroke()
    points.clear()
    active_choice = button
    choice_overlay = Control.new()
    choice_overlay.name = "TouchChoiceOverlay"
    add_child(choice_overlay)
    choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    var shade := ColorRect.new()
    shade.color = Color(0.02,0.05,0.08,0.78)
    choice_overlay.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    choice_panel = PanelContainer.new()
    choice_overlay.add_child(choice_panel)
    var visible_height: float = clampf(float(button.labels.size())*58.0+150.0,250.0,maxf(250.0,size.y*0.78))
    choice_panel.set_anchor(SIDE_LEFT,0.06)
    choice_panel.set_anchor(SIDE_RIGHT,0.94)
    choice_panel.set_anchor(SIDE_TOP,0.5)
    choice_panel.set_anchor(SIDE_BOTTOM,0.5)
    choice_panel.offset_top = -visible_height*0.5
    choice_panel.offset_bottom = visible_height*0.5
    var pad := MarginContainer.new()
    for side in ["left","right","top","bottom"]:
        pad.add_theme_constant_override("margin_"+side,12)
    choice_panel.add_child(pad)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation",8)
    pad.add_child(box)
    var title := Label.new()
    title.text = button.caption
    title.add_theme_font_size_override("font_size",24)
    box.add_child(title)
    choice_scroll = ScrollContainer.new()
    choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(choice_scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choice_scroll.add_child(list)
    choice_rows.clear()
    for index in range(button.labels.size()):
        var row := _button(list,("●  " if index == button.selected else "○  ")+button.labels[index],_commit_choice.bind(index))
        row.clip_text = true
        row.alignment = HORIZONTAL_ALIGNMENT_LEFT
        choice_rows.append(row)
    choice_cancel = _button(box,"閉じる",_close_choice)
    if button.selected >= 0:
        choice_scroll.call_deferred("ensure_control_visible",choice_rows[button.selected])

func _close_choice() -> void:
    if is_instance_valid(choice_overlay):
        choice_overlay.hide()
        choice_overlay.queue_free()
    choice_overlay = null
    choice_panel = null
    choice_scroll = null
    choice_cancel = null
    choice_rows.clear()
    active_choice = null
    pending_choice = null
    choice_touch = -1
    choice_pressed_row = -1
    choice_pressed_cancel = false
    choice_pressed_outside = false

func _commit_choice(index: int) -> void:
    var button: StudioChoice = active_choice
    # Close first even when selecting the currently selected item. Any
    # callback may rebuild a UV atlas or repopulate the choice list.
    _close_choice()
    if is_instance_valid(button):
        button.choose(index)

func _choice_row_at(at: Vector2) -> int:
    if not is_instance_valid(choice_scroll) or not choice_scroll.get_global_rect().has_point(at):
        return -1
    for index in range(choice_rows.size()):
        if choice_rows[index].get_global_rect().has_point(at):
            return index
    return -1

func _route_choice_input(event: InputEvent) -> bool:
    if is_instance_valid(choice_overlay):
        if event is InputEventScreenTouch:
            var tap: InputEventScreenTouch = event as InputEventScreenTouch
            if tap.pressed and choice_touch < 0:
                choice_touch = tap.index
                choice_origin = tap.position
                choice_scroll_start = choice_scroll.scroll_vertical
                choice_dragged = false
                choice_started_in_list = choice_scroll.get_global_rect().has_point(tap.position)
                choice_pressed_row = _choice_row_at(tap.position)
                choice_pressed_cancel = choice_cancel.get_global_rect().has_point(tap.position)
                choice_pressed_outside = not choice_panel.get_global_rect().has_point(tap.position)
            elif not tap.pressed and tap.index == choice_touch:
                choice_touch = -1
                if not choice_dragged:
                    var index: int = _choice_row_at(tap.position)
                    if index >= 0 and index == choice_pressed_row:
                        _commit_choice(index)
                    elif (choice_pressed_cancel and choice_cancel.get_global_rect().has_point(tap.position)) or (choice_pressed_outside and not choice_panel.get_global_rect().has_point(tap.position)):
                        _close_choice()
            return true
        if event is InputEventScreenDrag:
            var drag: InputEventScreenDrag = event as InputEventScreenDrag
            if drag.index == choice_touch:
                var delta: Vector2 = drag.position-choice_origin
                if delta.length() > 10.0:
                    choice_dragged = true
                if choice_dragged and choice_started_in_list:
                    choice_scroll.scroll_vertical = maxi(0,choice_scroll_start-roundi(delta.y))
            return true
        if event is InputEventMouseButton:
            var mouse: InputEventMouseButton = event as InputEventMouseButton
            if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and not choice_panel.get_global_rect().has_point(mouse.position):
                _close_choice()
                return true
        return false
    if is_instance_valid(part_panel) and part_panel.is_visible_in_tree():
        return false
    if is_instance_valid(file_dialog) and file_dialog.visible:
        return false
    if event is InputEventScreenTouch:
        var tap: InputEventScreenTouch = event as InputEventScreenTouch
        if tap.pressed and choice_touch < 0:
            for button in choice_buttons:
                if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(tap.position):
                    choice_touch = tap.index
                    choice_origin = tap.position
                    choice_dragged = false
                    pending_choice = button
                    return true
        elif not tap.pressed and tap.index == choice_touch:
            var button: StudioChoice = pending_choice
            choice_touch = -1
            pending_choice = null
            if is_instance_valid(button) and not choice_dragged and button.get_global_rect().has_point(tap.position):
                _open_choice(button)
            return true
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event as InputEventScreenDrag
        if drag.index == choice_touch and is_instance_valid(pending_choice):
            if drag.position.distance_to(choice_origin) > 10.0:
                choice_dragged = true
            return true
    return false

func _input(event: InputEvent) -> void:
    if _route_choice_input(event):
        get_viewport().set_input_as_handled()
        return
    if not is_instance_valid(part_panel) or not part_panel.is_visible_in_tree():
        return
    # The game disables mouse emulation from touch. Route explicit Android
    # taps and scroll gestures here; native Button.pressed still serves PC.
    if event is InputEventScreenTouch:
        if event.pressed and catalog_touch == -1 and part_scroll.get_global_rect().has_point(event.position):
            catalog_touch = event.index
            catalog_start = event.position
            catalog_scroll_start = part_scroll.scroll_vertical
            catalog_dragged = false
            get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == catalog_touch:
            catalog_touch = -1
            get_viewport().set_input_as_handled()
            if not catalog_dragged and part_scroll.get_global_rect().has_point(event.position):
                for id in part_cards:
                    var card: Button = part_cards[id]
                    if card.get_global_rect().has_point(event.position):
                        _choose_part(str(id))
                        break
    elif event is InputEventScreenDrag and event.index == catalog_touch:
        var delta: Vector2 = (event as InputEventScreenDrag).position-catalog_start
        if delta.length() > 10.0:
            catalog_dragged = true
        if catalog_dragged:
            part_scroll.scroll_vertical = maxi(0,catalog_scroll_start-roundi(delta.y))
        get_viewport().set_input_as_handled()

func _choose_part(id: String) -> void:
    if part_loading:
        return
    part_loading = true
    _close_part_catalog()
    _show_status(PartCatalog.display_name(id)+" 読み込み中")
    await get_tree().process_frame
    if not is_inside_tree() or is_queued_for_deletion():
        return
    if not is_instance_valid(part_rig):
        part_rig = PartSource.create_rig(pivot)
    var result: Dictionary = PartSource.snapshot(part_rig,id)
    part_loading = false
    if result.has("error"):
        _show_status(str(result.error))
        return
    if is_instance_valid(part_source):
        candidates.erase(part_source)
        if source == part_source:
            source = null
        part_source.queue_free()
    part_source = result.source as MeshInstance3D
    pivot.add_child(part_source)
    candidates.append(part_source)
    _refresh_picker()
    picker.select(candidates.size()-1)
    _select_model(candidates.size()-1)
    if img != null:
        _show_status(PartCatalog.display_name(id)+" / %dメッシュ / %d×%d px" % [result.pieces,img.get_width(),img.get_height()])

func _toggle_rotation_mode() -> void:
    rotation_mode = not rotation_mode
    _show_status("回転モード" if rotation_mode else "描画モード")

func _set_brush_size(index: int) -> void:
    brush_size = diameter_picker.get_item_id(index)

func _refresh_picker() -> void:
    picker.clear()
    for item in candidates:
        picker.add_item(str(item.name)+" / "+str(item.get_parent().name if item.get_parent()!=null else "GLB"))

func _toggle_mesh_picker() -> void:
    mesh_picker_row.visible = not mesh_picker_row.visible

func _select_model(index: int) -> void:
    if index < 0 or index >= candidates.size():
        return
    source = candidates[index]
    if is_instance_valid(source):
        var blueprint: String = str(source.get_meta("texture_studio_blueprint",""))
        selected_model_label.text = PartCatalog.display_name(blueprint) if not blueprint.is_empty() else str(source.name)
    mesh_picker_row.hide()
    _rebuild()

func _rebuild() -> void:
    if not is_instance_valid(source):
        _show_status("復元プロジェクトのUVは固定です。元モデルを選択してください")
        return
    var result: Dictionary = UV.build(source,density_picker.get_selected_id())
    if result.has("error"):
        preview.mesh = null
        img = null
        original = null
        layers.clear()
        layer_visible.clear()
        undo_stack.clear()
        redo_stack.clear()
        _end_stroke()
        _refresh_layers()
        triangles.clear()
        atlas_preview.texture = null
        _show_status(str(result.error))
        return
    triangles = result.triangles
    img = result.image
    original = img.duplicate() as Image
    atlas_density = density_picker.get_selected_id()
    layers.clear()
    layer_visible.clear()
    layer_index = 0
    _add_layer()
    _install_preview(result.mesh)
    _show_status("%d×%d px / UV島 %d / %s" % [img.get_width(),img.get_height(),result.charts,source.name])

func _install_preview(mesh: ArrayMesh) -> void:
    undo_stack.clear()
    redo_stack.clear()
    _composite()
    tex = ImageTexture.create_from_image(img)
    preview.mesh = mesh
    preview.material_override = _atlas_material(tex)
    preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    atlas_preview.texture = tex
    var bounds := preview.mesh.get_aabb()
    center = bounds.get_center()
    preview.position = -center
    radius = maxf(0.01,bounds.size.length()*0.5)
    zoom = radius*3.0
    _camera_pose()
    _refresh_layers()

func _atlas_material(texture: Texture2D) -> Material:
    var shader: Shader = load("res://shaders/sera_texture_studio_preview.gdshader") as Shader
    if shader != null:
        var material := ShaderMaterial.new()
        material.shader = shader
        material.set_shader_parameter("source_texture",texture)
        return material
    var fallback := StandardMaterial3D.new()
    fallback.albedo_texture = texture
    fallback.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
    return fallback

func _camera_pose() -> void:
    if not is_instance_valid(camera):
        return
    camera.position = Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*zoom
    camera.look_at(Vector3.ZERO,Vector3.UP)
    camera.near = maxf(0.001,zoom*0.04)
    camera.far = maxf(1.0,zoom+radius*5.0)

func _rotate(delta: Vector2) -> void:
    yaw -= delta.x*0.008
    pitch = clampf(pitch+delta.y*0.008,-1.48,1.48)
    _camera_pose()

func _zoom(ratio: float) -> void:
    zoom = clampf(zoom*ratio,radius*0.4,radius*12.0)
    _camera_pose()

func _view_input(event: InputEvent) -> void:
    if is_instance_valid(choice_overlay):
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            points[event.index] = event.position
            if points.size() == 1:
                multi_gesture = false
                last_point = event.position
                # Delay the initial dot until release/drag so the first finger
                # of a two-finger orbit cannot accidentally paint.
                stroke = false
            else:
                multi_gesture = true
                _end_stroke()
        else:
            if points.size() == 1 and not multi_gesture and not rotation_mode and not stroke:
                _begin_stroke()
                _paint(event.position)
            points.erase(event.index)
            if points.is_empty():
                _end_stroke()
        accept_event()
    elif event is InputEventScreenDrag:
        if not points.has(event.index):
            return
        var before: Vector2 = points[event.index]
        if points.size() >= 2:
            for id in points:
                if id != event.index:
                    var other: Vector2 = points[id]
                    var old_distance := maxf(1.0,before.distance_to(other))
                    var new_distance := maxf(1.0,event.position.distance_to(other))
                    _zoom(old_distance/new_distance)
                    _rotate(event.relative*0.5)
                    break
        elif not multi_gesture:
            if rotation_mode:
                _rotate(event.relative)
            else:
                if not stroke:
                    _begin_stroke()
                    _paint(before)
                _paint_path(before,event.position)
        points[event.index] = event.position
        accept_event()
    elif event is InputEventMouseButton:
        if not points.is_empty():
            return
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _zoom(0.87)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _zoom(1.15)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed and not rotation_mode:
                _begin_stroke()
                _paint(event.position)
            elif not event.pressed:
                _end_stroke()
        accept_event()
    elif event is InputEventMouseMotion and points.is_empty():
        if event.button_mask & MOUSE_BUTTON_MASK_RIGHT or (rotation_mode and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
            _rotate(event.relative)
        elif stroke and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
            _paint_path(event.position-event.relative,event.position)
        accept_event()

func _begin_stroke() -> void:
    if img == null or layers.is_empty() or not layer_visible[layer_index]:
        return
    stroke = true
    last_hit = Vector2i(-1,-1)
    last_chart = -1
    previous_mirror = Vector2i(-1,-1)
    previous_mirror_chart = -1
    shape_start = Vector2i(-1,-1)
    shape_chart = -1
    shape_base = null
    if tool_picker.selected in [7,8]:
        shape_base = layers[layer_index].duplicate() as Image
    if tool_picker.selected != 2:
        undo_stack.append(layers[layer_index].duplicate() as Image)
        if undo_stack.size() > 12:
            undo_stack.pop_front()
        redo_stack.clear()

func _end_stroke() -> void:
    stroke = false
    last_hit = Vector2i(-1,-1)
    last_chart = -1
    shape_base = null

func _paint_path(start: Vector2, finish: Vector2) -> void:
    if not stroke or img == null or tex == null:
        return
    if tool_picker.selected in [2,3,7,8,11,12]:
        _paint(finish)
        return
    # Recast along the screen drag, including UV seams, with bounded work.
    var steps := clampi(ceili(start.distance_to(finish)/10.0),1,8)
    for i in range(1,steps+1):
        _paint(start.lerp(finish,float(i)/steps),false)
    _composite()
    tex.update(img)

func _paint(at: Vector2, flush: bool = true) -> void:
    if img == null or not stroke or host.size.x <= 0 or host.size.y <= 0:
        return
    var pt := at / host.size * Vector2(view.size)
    var origin := camera.project_ray_origin(pt)+center
    var direction := camera.project_ray_normal(pt)
    var hit: Dictionary = UV.hit(triangles,origin,direction)
    if hit.is_empty():
        last_hit = Vector2i(-1,-1)
        previous_mirror = Vector2i(-1,-1)
        return
    var uv: Vector2 = hit.uv
    var p := Vector2i(clampi(floori(uv.x*img.get_width()),0,img.get_width()-1),clampi(floori(uv.y*img.get_height()),0,img.get_height()-1))
    var chart: int = hit.chart
    if tool_picker.selected == 2:
        color_picker.color = img.get_pixelv(p)
    elif tool_picker.selected == 3:
        if last_chart != chart:
            _fill_chart(chart)
    elif tool_picker.selected in [7,8]:
        if shape_start.x < 0:
            shape_start = p
            shape_chart = chart
        if shape_chart == chart and shape_base != null:
            layers[layer_index] = shape_base.duplicate() as Image
            if tool_picker.selected == 7:
                _line_pixels(shape_start,p)
            else:
                var corner_a := Vector2i(shape_start.x,p.y)
                var corner_b := Vector2i(p.x,shape_start.y)
                _line_pixels(shape_start,corner_a)
                _line_pixels(corner_a,p)
                _line_pixels(p,corner_b)
                _line_pixels(corner_b,shape_start)
    elif tool_picker.selected in [11,12]:
        if last_hit != p:
            _stamp(p)
    else:
        if last_chart == chart and last_hit.x >= 0:
            var steps := maxi(absi(p.x-last_hit.x),absi(p.y-last_hit.y))
            for i in range(steps+1):
                var q := Vector2i(Vector2(last_hit).lerp(Vector2(p),float(i)/maxf(1.0,steps)).round())
                _dab(q)
        else:
            _dab(p)
    if symmetric.button_pressed and tool_picker.selected in [0,1,4,5,6,9,10]:
        var mirrored: Dictionary = UV.mirror_hit(triangles,origin,direction,hit.position,center.x,1.5/float(atlas_density))
        if not mirrored.is_empty():
            var muv: Vector2 = mirrored.uv
            var mp := Vector2i(clampi(floori(muv.x*img.get_width()),0,img.get_width()-1),clampi(floori(muv.y*img.get_height()),0,img.get_height()-1))
            if mp != p:
                if previous_mirror.x >= 0 and previous_mirror_chart == int(mirrored.chart):
                    _line_pixels(previous_mirror,mp)
                else:
                    _dab(mp)
                previous_mirror = mp
                previous_mirror_chart = int(mirrored.chart)
        else:
            previous_mirror = Vector2i(-1,-1)
    last_hit = p
    last_chart = chart
    if flush:
        _composite()
        tex.update(img)

func _line_pixels(a: Vector2i,b: Vector2i) -> void:
    var steps := maxi(absi(b.x-a.x),absi(b.y-a.y))
    for i in range(steps+1):
        _dab(Vector2i(Vector2(a).lerp(Vector2(b),float(i)/maxf(1.0,steps)).round()))

func _inside(p: Vector2i) -> bool:
    return Rect2i(Vector2i.ZERO,original.get_size()).has_point(p) and original.get_pixelv(p).a >= 0.5

func _dab(p: Vector2i) -> void:
    var reach := floori(float(brush_size)/2.0)
    for y in range(-reach,reach+1):
        for x in range(-reach,reach+1):
            if x*x+y*y > reach*reach+1:
                continue
            _dab_one(p+Vector2i(x,y))

func _dab_one(p: Vector2i) -> void:
    if not _inside(p):
        return
    var old := img.get_pixelv(p)
    var color := color_picker.color
    match tool_picker.selected:
        1:
            layers[layer_index].set_pixelv(p,Color.TRANSPARENT)
            return
        4: color = old.lightened(0.12)
        5: color = old.darkened(0.12)
        6: color = old.lightened(randf_range(0.0,0.16)) if randf() > 0.5 else old.darkened(randf_range(0.0,0.16))
        9:
            var edge := false
            for off in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                if not _inside(p+off) or not _inside(p+off*2):
                    edge = true
            if not edge:
                return
            color = old.lightened(0.38)
        10:
            color = old.darkened(0.45)
            if _inside(p+Vector2i.DOWN):
                layers[layer_index].set_pixelv(p+Vector2i.DOWN,old.lightened(0.22))
    layers[layer_index].set_pixelv(p,Color(color.r,color.g,color.b,1.0))

func _stamp(p: Vector2i) -> void:
    var rows := PackedStringArray(["111010","101110","101010","101010","111111"]) if tool_picker.selected == 11 else PackedStringArray(["00100","01110","01010","11011","11111"])
    for y in range(rows.size()):
        for x in range(rows[y].length()):
            var q := p+Vector2i(x-floori(float(rows[y].length())/2.0),y-2)
            if rows[y][x] == "1" and _inside(q):
                layers[layer_index].set_pixelv(q,color_picker.color)

func _fill_chart(chart: int) -> void:
    for t in triangles:
        if t.chart != chart:
            continue
        var filled: Dictionary = t.duplicate()
        filled.base = color_picker.color
        filled.tex = null
        filled.colors = PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE])
        UV._bake_triangle(layers[layer_index],filled)

func _composite() -> void:
    if original == null:
        return
    img = original.duplicate() as Image
    for i in range(layers.size()):
        if layer_visible[i]:
            img.blend_rect(layers[i],Rect2i(Vector2i.ZERO,img.get_size()),Vector2i.ZERO)

func _refresh_layers() -> void:
    layer_picker.clear()
    for i in range(layers.size()):
        layer_picker.add_item("L%d%s" % [i+1,"" if layer_visible[i] else " OFF"])
    if not layers.is_empty():
        layer_picker.select(layer_index)
        layer_toggle.text = "非表示" if layer_visible[layer_index] else "表示"

func _select_layer(index: int) -> void:
    if index < 0 or index >= layers.size():
        return
    _end_stroke()
    layer_index = index
    undo_stack.clear()
    redo_stack.clear()
    _refresh_layers()

func _add_layer() -> void:
    if original == null or layers.size() >= MAX_LAYERS:
        return
    var layer := Image.create(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8)
    layer.fill(Color.TRANSPARENT)
    layers.append(layer)
    layer_visible.append(true)
    _select_layer(layers.size()-1)

func _toggle_layer() -> void:
    if layers.is_empty() or img == null:
        return
    layer_visible[layer_index] = not layer_visible[layer_index]
    _end_stroke()
    _refresh_layers()
    _composite()
    tex.update(img)

func _delete_layer() -> void:
    if layers.is_empty() or img == null:
        return
    layers.remove_at(layer_index)
    layer_visible.remove_at(layer_index)
    if layers.is_empty():
        _add_layer()
    else:
        _select_layer(maxi(0,layer_index-1))
    _composite()
    tex.update(img)

func _undo() -> void:
    if undo_stack.is_empty() or layers.is_empty() or img == null or tex == null:
        return
    redo_stack.append(layers[layer_index].duplicate() as Image)
    layers[layer_index] = undo_stack.pop_back()
    _composite()
    tex.update(img)

func _redo() -> void:
    if redo_stack.is_empty() or layers.is_empty() or img == null or tex == null:
        return
    undo_stack.append(layers[layer_index].duplicate() as Image)
    layers[layer_index] = redo_stack.pop_back()
    _composite()
    tex.update(img)

func _toggle_atlas() -> void:
    atlas_preview.visible = not atlas_preview.visible

func _show_status(message: String) -> void:
    status.text = message

func _open_file() -> void:
    if not is_instance_valid(file_dialog):
        file_dialog = FileDialog.new()
        file_dialog.access = FileDialog.ACCESS_FILESYSTEM
        file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
        file_dialog.add_filter("*.glb","GLBモデル")
        file_dialog.add_filter("*.res","テクスタ保存メッシュ")
        file_dialog.add_filter("*.texture.json","テクスタ編集プロジェクト")
        file_dialog.file_selected.connect(_load_glb)
        add_child(file_dialog)
    if DirAccess.dir_exists_absolute(SAVE_DIR):
        file_dialog.current_dir = ProjectSettings.globalize_path(SAVE_DIR)
    file_dialog.popup_centered_ratio(0.9)

func _load_glb(path: String) -> void:
    if path.ends_with(".texture.json"):
        _load_project(path)
        return
    var root: Node3D
    if path.get_extension().to_lower() == "res":
        # Only restore resources exported by this tool, not arbitrary scripts.
        if not path.begins_with(ProjectSettings.globalize_path(SAVE_DIR)+"/") and not path.begins_with(SAVE_DIR+"/"):
            _show_status("テクスタ保存フォルダのメッシュのみ復元できます")
            return
        var saved := ResourceLoader.load(path,"ArrayMesh") as ArrayMesh
        if saved == null:
            _show_status("保存メッシュを読み込めません")
            return
        var instance := MeshInstance3D.new()
        instance.mesh = saved
        instance.name = path.get_file().get_basename()
        root = instance
    else:
        var doc := GLTFDocument.new()
        var state := GLTFState.new()
        if doc.append_from_file(path,state) != OK:
            _show_status("GLBを読み込めません")
            return
        root = doc.generate_scene(state) as Node3D
    if root == null:
        _show_status("モデルがありません")
        return
    if is_instance_valid(external_root):
        for i in range(candidates.size()-1,-1,-1):
            if external_root == candidates[i] or external_root.is_ancestor_of(candidates[i]):
                candidates.remove_at(i)
        external_root.free()
    external_root = root
    external_root.visible = false
    pivot.add_child(external_root)
    var first := candidates.size()
    _collect(external_root)
    _refresh_picker()
    if candidates.size() > first:
        picker.select(first)
        _select_model(first)
    else:
        _show_status("対応メッシュがありません")

func _save() -> void:
    if img == null or preview.mesh == null:
        return
    if DirAccess.make_dir_recursive_absolute(SAVE_DIR) != OK and not DirAccess.dir_exists_absolute(SAVE_DIR):
        _show_status("保存フォルダを作成できません")
        return
    var label := str(source.name) if is_instance_valid(source) else "RestoredTexture"
    var stem := label.validate_filename()+"_"+str(Time.get_unix_time_from_system()).replace(".","_")
    var png := SAVE_DIR+"/"+stem+".png"
    var mesh_path := SAVE_DIR+"/"+stem+".res"
    var baked := img.duplicate() as Image
    # Two-pixel RGB dilation into unused atlas padding prevents dark seams.
    for pass_index in range(2):
        var prior := baked.duplicate() as Image
        for y in range(baked.get_height()):
            for x in range(baked.get_width()):
                if prior.get_pixel(x,y).a > 0.0:
                    continue
                for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                    var q: Vector2i = Vector2i(x,y)+offset
                    if Rect2i(Vector2i.ZERO,baked.get_size()).has_point(q) and prior.get_pixelv(q).a > 0.0:
                        baked.set_pixel(x,y,prior.get_pixelv(q))
                        break
    if baked.save_png(png) != OK:
        _show_status("PNG保存失敗")
        return
    baked.generate_mipmaps()
    var saved_mesh := preview.mesh.duplicate() as ArrayMesh
    saved_mesh.surface_set_material(0,_atlas_material(ImageTexture.create_from_image(baked)))
    if ResourceSaver.save(saved_mesh,mesh_path) != OK:
        _show_status("PNG保存済み・メッシュ保存失敗")
        return
    var prefix := SAVE_DIR+"/"+stem
    if original.save_png(prefix+".base.png") != OK:
        _show_status("合成保存済み・ベース保存失敗")
        return
    for i in range(layers.size()):
        if layers[i].save_png(prefix+".layer%d.png"%i) != OK:
            _show_status("合成保存済み・レイヤー保存失敗")
            return
    var ids: Array[int] = []
    for t in triangles:
        ids.append(int(t.chart))
    var file := FileAccess.open(prefix+".texture.json",FileAccess.WRITE)
    if file == null:
        _show_status("合成保存済み・プロジェクト保存失敗")
        return
    file.store_string(JSON.stringify({"version":1,"density":atlas_density,"charts":ids,"visible":layer_visible}))
    file.close()
    _show_status("編集プロジェクト保存済み: "+stem)

func _load_project(path: String) -> void:
    var absolute := ProjectSettings.globalize_path(path).simplify_path()
    var directory := ProjectSettings.globalize_path(SAVE_DIR).simplify_path()
    if absolute.get_base_dir() != directory:
        _show_status("テクスタ保存フォルダのみ復元できます")
        return
    var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute))
    if not decoded is Dictionary:
        _show_status("編集プロジェクトが無効です")
        return
    var data: Dictionary = decoded
    var ids: Variant = data.get("charts")
    var vis: Variant = data.get("visible")
    if data.get("version") != 1 or not ids is Array or not vis is Array or vis.size() < 1 or vis.size() > MAX_LAYERS:
        _show_status("編集プロジェクト形式が無効です")
        return
    var prefix := absolute.trim_suffix(".texture.json")
    var mesh := ResourceLoader.load(prefix+".res","ArrayMesh") as ArrayMesh
    var restored: Array = UV.restore_triangles(mesh,ids as Array)
    var base := Image.load_from_file(prefix+".base.png")
    if restored.is_empty() or base == null or base.is_empty() or base.get_width() > 1024 or base.get_height() > 1024:
        _show_status("保存メッシュまたはベース画像が無効です")
        return
    base.convert(Image.FORMAT_RGBA8)
    var restored_layers: Array[Image] = []
    var restored_visibility: Array[bool] = []
    for i in range(vis.size()):
        var layer := Image.load_from_file(prefix+".layer%d.png"%i)
        if layer == null or layer.is_empty() or layer.get_size() != base.get_size():
            _show_status("レイヤー画像が無効です")
            return
        layer.convert(Image.FORMAT_RGBA8)
        restored_layers.append(layer)
        restored_visibility.append(bool(vis[i]))
    source = null
    picker.select(-1)
    selected_model_label.text = prefix.get_file()
    triangles = restored
    original = base
    layers = restored_layers
    layer_visible = restored_visibility
    layer_index = 0
    atlas_density = int(data.get("density",32))
    if atlas_density not in [8,16,32,64]:
        atlas_density = 32
    density_picker.select([8,16,32,64].find(atlas_density))
    _install_preview(mesh)
    _show_status("編集プロジェクト復元済み: "+prefix.get_file())

func request_close() -> void:
    if is_instance_valid(choice_overlay):
        _close_choice()
        return
    if is_instance_valid(part_panel) and part_panel.visible:
        _close_part_catalog()
        return
    if is_instance_valid(file_dialog) and file_dialog.visible:
        file_dialog.hide()
        return
    closed.emit()
    queue_free()
