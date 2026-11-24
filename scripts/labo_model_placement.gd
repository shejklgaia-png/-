extends Control
## Editor of stable equipment roots, never individual batched geometry.
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
var host
var stage: Node3D
var camera: Camera3D
var preview: Control
var active := false
var targets: Array[Node3D] = []
var selected: Node3D
var changed: Dictionary = {}
var buttons: Dictionary = {}
var gizmos: Dictionary = {}
var status: Label
var pointer := -999
var last_point := Vector2.ZERO
var was_processing := false
var crate_was_visible := true

func configure(owner_node) -> void:
    host = owner_node
    name = "LaboModelPlacement"
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := PanelContainer.new()
    panel.theme = LaboSkin.common_theme()
    panel.add_theme_stylebox_override("panel", LaboSkin.panel_style())
    add_child(panel)
    panel.anchor_left = 0.025
    panel.anchor_right = 0.975
    panel.anchor_top = 0.39
    panel.anchor_bottom = 0.975
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 12)
    panel.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    margin.add_child(column)
    status = Label.new()
    status.add_theme_font_override("font", LaboSkin.ui_font())
    status.add_theme_font_size_override("font_size", 19)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status)
    var help := Label.new()
    help.text = "3Dモデルをタップして選択・ドラッグで水平移動\n矢印で回転・高さ調整。選択切替で画面外の設備も選択可能。"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.add_theme_font_override("font", LaboSkin.ui_font())
    help.add_theme_font_size_override("font_size", 18)
    column.add_child(help)
    for pair in [["prev", "前のモデル", "next", "次のモデル"], ["left", "回転 ◀", "right", "回転 ▶"], ["up", "高さ ▲", "down", "高さ ▼"], ["exit", "編集終了", "copy", "配置コピー"]]:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        column.add_child(row)
        for i in [0, 2]:
            var id: String = pair[i]
            var button := _make_button(str(pair[i+1]))
            button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            button.custom_minimum_size.y = 58.0
            row.add_child(button)
            buttons[id] = button
            button.pressed.connect(_action.bind(id))
    var crate_button := _make_button("クレート非表示")
    crate_button.custom_minimum_size.y = 58.0
    column.add_child(crate_button)
    buttons["crate_visibility"] = crate_button
    crate_button.pressed.connect(_action.bind("crate_visibility"))
    for pair in [["left", "↶"], ["right", "↷"], ["up", "▲"], ["down", "▼"]]:
        var button := _make_button(str(pair[1]))
        add_child(button)
        button.size = Vector2(48, 48)
        gizmos[pair[0]] = button
        button.pressed.connect(_action.bind(str(pair[0])))
    hide()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(stage):
        stage.call("flush_model_placement")

func _make_button(caption: String) -> Button:
    var button := Button.new()
    button.text = caption
    button.add_theme_font_override("font", LaboSkin.ui_font())
    button.add_theme_font_size_override("font_size", 20)
    host.call("_style_terminal_segment", button)
    return button

func open_mode() -> bool:
    if active:
        return true
    stage = host.get("hero_stage") as Node3D
    preview = host.get("hero_host") as Control
    if stage == null or preview == null:
        return false
    camera = stage.get("hero_camera") as Camera3D
    if camera == null:
        return false
    targets = stage.call("placement_models")
    if targets.is_empty():
        return false
    active = true
    pointer = -999
    selected = null
    var route: Node3D = stage.get("crate_route") as Node3D
    crate_was_visible = route.visible if route != null else true
    _sync_crate_button()
    was_processing = stage.is_processing()
    stage.set_process(false)
    host.call("_set_labo_scroll_input_enabled", false)
    get_parent().move_child(self, -1)
    show()
    _refresh()
    return true

func close_mode() -> void:
    if not active:
        return
    active = false
    pointer = -999
    selected = null
    hide()
    if is_instance_valid(stage):
        stage.call("flush_model_placement")
        var route: Node3D = stage.get("crate_route") as Node3D
        if route != null:
            route.visible = crate_was_visible
        stage.set_process(was_processing)
    host.call("_set_labo_scroll_input_enabled", true)

func _viewport_point(point: Vector2) -> Vector2:
    var rect := preview.get_global_rect()
    var viewport_size: Vector2 = Vector2(camera.get_viewport().get_visible_rect().size)
    return (point - rect.position) * viewport_size / rect.size

func _screen_point(world: Vector3) -> Vector2:
    var rect := preview.get_global_rect()
    var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
    return rect.position + camera.unproject_position(world) * rect.size / viewport_size

func _pivot() -> Vector3:
    if selected == stage.get("crate_route"):
        var crate: Node3D = stage.get("crate")
        return crate.global_position
    return selected.global_position

func _refresh() -> void:
    if selected == null:
        status.text = "モデルを選択してください / " + str(stage.call("camera_section_id"))
        for button in gizmos.values():
            button.hide()
        return
    var p: Vector3 = selected.position
    status.text = "%s\nX %.2f / Y %.2f / Z %.2f / Yaw %.1f°" % [selected.name, p.x, p.y, p.z, selected.rotation_degrees.y]
    var pivot := _pivot()
    var rect := preview.get_global_rect()
    var point := _screen_point(pivot)
    var visible_on_screen: bool = not camera.is_position_behind(pivot) and rect.has_point(point)
    if visible_on_screen:
        var origin := get_global_transform_with_canvas().affine_inverse() * Vector2(clampf(point.x, rect.position.x+100, rect.end.x-100), clampf(point.y+12, rect.position.y+4, rect.end.y-52))
        var index := 0
        for id in ["left", "right", "up", "down"]:
            var button: Button = gizmos[id]
            button.position = origin + Vector2(-98+index*49, 0)
            index += 1
    for button in gizmos.values():
        button.visible = visible_on_screen

func _hit_box(box: AABB, pose: Transform3D, origin: Vector3, direction: Vector3) -> float:
    var inv := pose.affine_inverse()
    var local_origin := inv * origin
    var local_direction := inv.basis * direction
    var hit: Variant = box.intersects_ray(local_origin, local_direction)
    if hit == null:
        return INF
    return origin.distance_to(pose * hit)

func _hit_tree(node: Node3D, origin: Vector3, direction: Vector3) -> float:
    if not node.is_visible_in_tree():
        return INF
    var best: float = INF
    if node is MeshInstance3D and node.mesh != null:
        best = _hit_box(node.mesh.get_aabb(), node.global_transform, origin, direction)
    elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
        var pack: MultiMesh = node.multimesh
        if _hit_box(pack.get_aabb(), node.global_transform, origin, direction) < INF:
            var box := pack.mesh.get_aabb()
            for i in range(pack.instance_count):
                best = minf(best, _hit_box(box, node.global_transform * pack.get_instance_transform(i), origin, direction))
    for child in node.get_children():
        if child is Node3D:
            best = minf(best, _hit_tree(child, origin, direction))
    return best

func _pick(point: Vector2) -> Node3D:
    var pixel := _viewport_point(point)
    var origin := camera.project_ray_origin(pixel)
    var direction := camera.project_ray_normal(pixel)
    var best: float = INF
    var result: Node3D
    for target in targets:
        var distance := _hit_tree(target, origin, direction)
        if distance < best:
            best = distance
            result = target
    return result

func _plane_point(point: Vector2, height: float) -> Variant:
    var pixel := _viewport_point(point)
    var origin := camera.project_ray_origin(pixel)
    var direction := camera.project_ray_normal(pixel)
    if absf(direction.y) < 0.035:
        return null
    var distance := (height-origin.y)/direction.y
    if distance <= 0.0:
        return null
    return origin + direction * distance

func _drag(point: Vector2) -> void:
    if selected == null:
        return
    var height := _pivot().y
    var a: Variant = _plane_point(last_point, height)
    var b: Variant = _plane_point(point, height)
    var delta: Vector3
    if a != null and b != null and (b-a).length() < 2.0:
        delta = b-a
    else:
        var d := point-last_point
        var right := camera.global_basis.x
        right.y = 0.0
        right = right.normalized()
        var forward := -camera.global_basis.z
        forward.y = 0.0
        forward = forward.normalized()
        var meters_per_pixel := 2.0 * camera.global_position.distance_to(_pivot()) * tan(deg_to_rad(camera.fov*0.5)) / maxf(1.0, preview.size.y)
        delta = (right*d.x-forward*d.y)*meters_per_pixel
    last_point = point
    delta.y = 0.0
    selected.global_position += delta
    _remember()

func _remember() -> void:
    stage.call("remember_model_placement", selected)
    var section: String = stage.call("camera_section_id")
    if not changed.has(section):
        changed[section] = {}
    var p: Vector3 = selected.position
    var r: Vector3 = selected.rotation_degrees
    changed[section][str(stage.get_path_to(selected))] = {"position": [p.x,p.y,p.z], "rotation_degrees": [r.x,r.y,r.z]}
    _refresh()

func _sync_crate_button() -> void:
    var route: Node3D = stage.get("crate_route") as Node3D
    var button: Button = buttons["crate_visibility"]
    button.disabled = route == null
    button.text = "クレート非表示" if route == null or route.visible else "クレート表示"


func _action(id: String) -> void:
    if not active:
        return
    if id == "exit":
        close_mode()
        return
    if id == "crate_visibility":
        var route: Node3D = stage.get("crate_route") as Node3D
        if route == null:
            return
        route.visible = not route.visible
        if not route.visible and selected == route:
            selected = null
        _sync_crate_button()
        _refresh()
        return
    if id == "copy":
        var section: String = stage.call("camera_section_id")
        if not changed.has(section):
            status.text = "変更されたモデルはありません"
            return
        var payload := {"scene":"res://scenes/labo_hero_stage.tscn", "section":section, "space":"parent_local", "status":"preview_not_committed", "models":changed[section]}
        DisplayServer.clipboard_set("LABO_MODEL_CANONICAL_PLACEMENT\n"+JSON.stringify(payload, "  "))
        status.text = "配置コピー完了 / ChatGPTに貼り付けて確定"
        return
    if id in ["prev", "next"]:
        var available: Array[Node3D] = []
        for target in targets:
            if target.is_visible_in_tree():
                available.append(target)
        if available.is_empty():
            return
        var index := available.find(selected)
        if index < 0:
            index = 0 if id == "next" else available.size()-1
        else:
            index = posmod(index+(1 if id == "next" else -1), available.size())
        selected = available[index]
        _refresh()
        return
    if selected == null:
        return
    match id:
        "left":
            selected.rotation_degrees.y -= 5.0
        "right":
            selected.rotation_degrees.y += 5.0
        "up":
            selected.position.y += 0.10
        "down":
            selected.position.y -= 0.10
    _remember()
    stage.call("flush_model_placement")

func _press(point: Vector2, id: int) -> void:
    if pointer != -999:
        return
    for key in gizmos:
        var button: Button = gizmos[key]
        if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
            _action(str(key))
            return
    for key in buttons:
        var button: Button = buttons[key]
        if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
            _action(str(key))
            return
    if preview.get_global_rect().has_point(point):
        selected = _pick(point)
        _refresh()
        if selected != null:
            pointer = id
            last_point = point

func route_input(event: InputEvent) -> bool:
    if not active:
        return false
    if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_BACK, KEY_ESCAPE]):
        close_mode()
    elif event is InputEventScreenTouch:
        if event.pressed:
            _press(event.position, event.index)
        elif event.index == pointer:
            pointer = -999
            stage.call("flush_model_placement")
    elif event is InputEventScreenDrag and event.index == pointer:
        _drag(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _press(event.position, -100)
        elif pointer == -100:
            pointer = -999
            stage.call("flush_model_placement")
    elif event is InputEventMouseMotion and pointer == -100:
        _drag(event.position)
    return true
