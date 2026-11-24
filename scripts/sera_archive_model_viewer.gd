extends Panel
## Read-only archive; one live preview at a time. Host routes raw touch exclusively.
signal close_requested
const Skin = preload("res://scripts/sera_labo_round_skin.gd")
const RotateMark = preload("res://scripts/sera_rotatable_mark.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const Equipment = preload("res://tools/equipment_intake/godot_preview.gd")
const Crate = preload("res://scripts/sera_crate_model.gd")
const Boss = preload("res://scripts/bittaran_rig.gd")
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const PreviewRim = preload("res://scripts/sera_tech_preview_frame.gd")
const CATEGORIES = ["CHARACTER", "PARTS", "FACILITY"]
const FACILITIES = ["NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL"]
const FACILITY_LABELS = ["NEXUS", "LABO", "回収機", "精製装置", "分解装置", "電力制御施設", "資材保管庫", "建設端末"]
const ROWS = 4
var category: int = 0
var page: int = 0
var selected: String = ""
var entries: Array[Dictionary] = []
var buttons: Dictionary = {}
var heading: Label
var caption: Label
var pages: Label
var host: SubViewportContainer
var frame: Control
var cue: Control
var viewport: SubViewport
var stage: Node3D
var orbit: Node3D
var center: Node3D
var camera: Camera3D
var equipment: Node3D
var model: Node3D
var generation: int = 0
var fingers: Dictionary = {}
var press_controls: Dictionary = {}
var yaw: float = 0.55
var pitch: float = -0.16
var zoom: float = 1.0
var pan := Vector2.ZERO
var fit_size: float = 2.8

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel", Skin.style("card"))
    heading = _label("MODEL ARCHIVE", 23)
    caption = _label("", 17)
    pages = _label("", 14)
    host = SubViewportContainer.new()
    host.stretch = true
    host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(host)
    frame = PreviewRim.new()
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(frame)
    cue = RotateMark.new()
    add_child(cue)
    for i in range(3):
        _button("cat%d" % i, CATEGORIES[i])
    for i in range(ROWS):
        _button("row%d" % i, "")
    _button("prev", "‹")
    _button("next", "›")
    _button("reset", "")
    _button("back", "戻る")
    var reset_panel: Panel = buttons["reset"]
    reset_panel.queue_redraw()
    resized.connect(_layout)
    _layout()

func _label(value: String, font_size: int, parent: Control = null) -> Label:
    var label := Label.new()
    label.text = value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.add_theme_font_override("font", Skin.ui_font())
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("#d7e6ed"))
    if parent == null:
        add_child(label)
    else:
        parent.add_child(label)
    return label

func _button(id: String, value: String) -> void:
    var panel := Panel.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", Skin.terminal_segment_style("normal"))
    add_child(panel)
    var label := _label(value, 16, panel)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    buttons[id] = panel
    if id == "reset":
        panel.draw.connect(_draw_camera.bind(panel))

func _draw_camera(panel: Panel) -> void:
    var c := panel.size * 0.5
    var tint := Color("#d7e6ed")
    panel.draw_rect(Rect2(c - Vector2(10, 6), Vector2(20, 14)), tint, false, 1.5)
    panel.draw_rect(Rect2(c - Vector2(4, 9), Vector2(8, 3)), tint, true)
    panel.draw_arc(c + Vector2(0, 1), 4, 0, TAU, 20, tint, 1.5, true)

func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
    control.position = Vector2(x, y)
    control.size = Vector2(maxf(w, 1), maxf(h, 1))

func _layout() -> void:
    if host == null:
        return
    var w: float = size.x
    var h: float = size.y
    var m := 12.0
    var tab_h := 44.0
    _place(heading, m, 0, w - 2*m, 49)
    for i in range(3):
        var tw: float = (w - 2*m - 12)/3.0
        _place(buttons["cat%d" % i], m + i*(tw+6), 52, tw, tab_h)
    var row_h: float = clampf(h * 0.075, 36.0, 55.0)
    var view_top := 104.0
    var list_top: float = h - ROWS*(row_h+4) - 100.0
    var view_h: float = maxf(80.0, list_top-view_top-39)
    _place(host, m, view_top, w-2*m, view_h)
    _place(frame, m, view_top, w-2*m, view_h)
    _place(cue, m+7, view_top+7, 28, 28)
    _place(buttons["reset"], w-m-38, view_top+6, 32, 32)
    _place(caption, m, view_top+view_h, w-2*m, 32)
    for i in range(ROWS):
        _place(buttons["row%d" % i], m, list_top+i*(row_h+4), w-2*m, row_h)
    _place(buttons["prev"], m, h-98, 48, 40)
    _place(buttons["next"], w-m-48, h-98, 48, 40)
    _place(pages, m+52, h-98, w-2*m-104, 40)
    _place(buttons["back"], w-m-100, h-52, 100, 40)
    if is_instance_valid(viewport) and equipment == null:
        _apply_transform()

func open_archive() -> void:
    # Display the independent UI immediately; do not tie visibility to
    # rig initialization or the first SubViewport render.
    show()
    _layout()
    _set_category(0)

func close_archive() -> void:
    generation += 1
    _drop_view()
    hide()

func _set_category(value: int) -> void:
    category = value
    page = 0
    entries.clear()
    match value:
        0:
            entries.append({"id":"SERA", "name":"セラ / SERA"})
            entries.append({"id":"CRATE", "name":"クレート / CRATE"})
            entries.append({"id":"BITTARAN", "name":"ビットタラン / BITTARAN"})
        1:
            for id in Catalog.ORDER:
                var spec: Dictionary = Catalog.spec(str(id))
                entries.append({"id":str(id), "name":str(id)+"  "+str(spec.get("name", id))})
        2:
            for i in range(FACILITIES.size()):
                entries.append({"id":FACILITIES[i], "name":FACILITY_LABELS[i]})
    for i in range(3):
        _style_button("cat%d" % i, i == category)
    if not entries.is_empty():
        _select(0)

func _style_button(id: String, active: bool) -> void:
    var p: Panel = buttons[id]
    p.add_theme_stylebox_override("panel", Skin.terminal_segment_style("selected" if active else "normal"))

func _refresh_rows() -> void:
    for i in range(ROWS):
        var p: Panel = buttons["row%d" % i]
        var index: int = page * ROWS + i
        p.visible = index < entries.size()
        if p.visible:
            (p.get_child(0) as Label).text = str(entries[index]["name"])
            _style_button("row%d" % i, selected == str(entries[index]["id"]))
    var count: int = maxi(1, ceili(float(entries.size()) / ROWS))
    pages.text = "%02d / %02d" % [page+1, count]
    (buttons["prev"] as Panel).visible = page > 0
    (buttons["next"] as Panel).visible = page+1 < count

func _drop_view() -> void:
    fingers.clear()
    press_controls.clear()
    if is_instance_valid(viewport):
        viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        host.remove_child(viewport)
        viewport.queue_free()
    viewport = null
    equipment = null
    stage = null
    model = null
    camera = null

func _select(index: int) -> void:
    if index < 0 or index >= entries.size():
        return
    selected = str(entries[index]["id"])
    caption.text = str(entries[index]["name"])
    _refresh_rows()
    generation += 1
    _drop_view()
    caption.text += "  /  LOADING"
    _load_selected.call_deferred(generation, category, selected)

func _load_selected(request: int, kind: int, id: String) -> void:
    # Allow the visible menu to render before construction of a heavy rig.
    await get_tree().process_frame
    if request != generation or not is_visible_in_tree():
        return
    var display_name: String = id
    for entry in entries:
        if str(entry["id"]) == id:
            display_name = str(entry["name"])
            break
    viewport = SubViewport.new()
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    host.add_child(viewport)
    if kind == 1 or id == "SERA":
        equipment = Equipment.new()
        equipment.set("nexus_brighter_backdrop", true)
        viewport.add_child(equipment)
        equipment.set_process_input(false)
        for i in range(80):
            if request != generation or not is_instance_valid(equipment):
                return
            if bool(equipment.get("ready_for_commands")):
                break
            await get_tree().process_frame
        if request != generation:
            return
        if not bool(equipment.get("ready_for_commands")):
            caption.text = display_name + " / MODEL UNAVAILABLE"
            return
        var spec: Dictionary = Catalog.spec(id) if kind == 1 else {}
        var gear: Dictionary = {}
        if kind == 1:
            gear[str(spec.get("slot","head"))] = str(spec.get("rig_set","A"))
        else:
            gear = SeraSave.get_working_equipment().duplicate(true)
        equipment.call("_apply_command", {"mode":"icon" if kind == 1 else "body",
            "editing_slot":str(spec.get("slot","head")), "selected":gear,
            "size":1.0, "keep_aspect":true, "background_mode":"grid",
            "camera":{"yaw":156.9,"pitch":11.87,"roll":0.0,"panX":0.0,"panY":0.0,"zoom":0.86}})
        caption.text = display_name
        return
    stage = Node3D.new()
    viewport.add_child(stage)
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#afc4d1")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#bbc9e1")
    environment.ambient_light_energy = 0.65
    var world := WorldEnvironment.new()
    world.environment = environment
    stage.add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-52,-24,0)
    light.light_energy = 1.5
    light.shadow_enabled = false
    stage.add_child(light)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.position = Vector3(0,0,8)
    camera.near = 0.01
    camera.far = 50
    stage.add_child(camera)
    camera.make_current()
    orbit = Node3D.new()
    stage.add_child(orbit)
    center = Node3D.new()
    orbit.add_child(center)
    if id == "CRATE":
        model = Crate.create_model()
        center.add_child(model)
    elif id == "BITTARAN":
        model = Boss.new()
        center.add_child(model)
    else:
        model = Node3D.new()
        center.add_child(model)
        if id == "NEXUS":
            Architecture.build_nexus(model)
        else:
            Architecture.build_facility(model,id)
    model.process_mode = Node.PROCESS_MODE_DISABLED
    var edges := model.get_node_or_null("ViewEdges")
    if is_instance_valid(edges) and edges.has_method("set_contour_enabled"):
        edges.call("set_contour_enabled",false)
    var bounds: Dictionary = {}
    _collect_bounds(model, bounds)
    if not bounds.has("box"):
        caption.text = display_name + " / MODEL UNAVAILABLE"
        return
    var box: AABB = bounds["box"]
    center.position = -box.get_center()
    center.scale = Vector3.ONE * (1.7/maxf(0.001,box.size.length()))
    center.position *= center.scale.x
    _reset_view()
    caption.text = display_name

func _collect_bounds(node: Node, data: Dictionary) -> void:
    if node is Node3D and not (node as Node3D).is_visible_in_tree():
        return
    if node is VisualInstance3D and (node is MeshInstance3D or node is MultiMeshInstance3D):
        var visual := node as VisualInstance3D
        var local_box: AABB = visual.get_aabb()
        if local_box.size.length_squared() > 0.000001:
            var box: AABB = center.global_transform.affine_inverse() * visual.global_transform * local_box
            data["box"] = (data["box"] as AABB).merge(box) if data.has("box") else box
    for child in node.get_children():
        _collect_bounds(child,data)

func _reset_view() -> void:
    if is_instance_valid(equipment):
        if bool(equipment.get("ready_for_commands")):
            equipment.set("camera_yaw",156.9)
            equipment.set("camera_pitch",11.87)
            equipment.set("camera_roll",0.0)
            equipment.set("camera_zoom",0.86)
            equipment.set("camera_pan",Vector2.ZERO)
            equipment.call("_apply_frame")
        return
    yaw = -0.55 if selected == "CRATE" else 0.55
    pitch = -0.16
    zoom = 1.0
    pan = Vector2.ZERO
    _apply_transform()

func _apply_transform() -> void:
    if not is_instance_valid(camera) or not is_instance_valid(orbit):
        return
    orbit.rotation = Vector3(pitch,yaw,0)
    orbit.position = Vector3(pan.x,pan.y,0)
    var aspect: float = host.size.x/maxf(1.0,host.size.y)
    camera.size = fit_size/maxf(0.2,minf(1.0,aspect))/zoom

func _contains(control: Control, point: Vector2) -> bool:
    if not is_instance_valid(control) or not control.is_visible_in_tree():
        return false
    var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
    return Rect2(Vector2.ZERO, control.size).has_point(local)

func _preview_point(point: Vector2) -> Vector2:
    return host.get_global_transform_with_canvas().affine_inverse() * point

func _touch(id: int, pressed: bool, point: Vector2) -> void:
    if pressed:
        if _contains(host, point):
            var reset: Panel = buttons["reset"]
            if _contains(reset, point):
                press_controls[id] = "reset"
            else:
                fingers[id] = point
                if is_instance_valid(equipment):
                    equipment.call("_on_preview_touch",id,true,_preview_point(point))
        else:
            var hit := ""
            for key in buttons:
                var p: Panel = buttons[key]
                if _contains(p, point):
                    hit = str(key)
                    break
            if hit.is_empty() and not _contains(self, point):
                hit = "outside"
            press_controls[id] = hit
    elif fingers.has(id):
        fingers.erase(id)
        if is_instance_valid(equipment):
            equipment.call("_on_preview_touch",id,false,_preview_point(point))
    elif press_controls.has(id):
        var hit: String = press_controls[id]
        press_controls.erase(id)
        if hit == "outside" and not _contains(self, point):
            close_requested.emit()
        elif buttons.has(hit) and _contains(buttons[hit] as Panel, point):
            _activate(hit)

func _activate(id: String) -> void:
    if id == "back":
        close_requested.emit()
    elif id == "reset":
        _reset_view()
    elif id.begins_with("cat"):
        _set_category(int(id.substr(3)))
    elif id.begins_with("row"):
        _select(page*ROWS+int(id.substr(3)))
    elif id == "prev" or id == "next":
        page = clampi(page + (-1 if id == "prev" else 1),0,maxi(0,ceili(float(entries.size())/ROWS)-1))
        _refresh_rows()

func _drag(id: int, point: Vector2) -> void:
    if not fingers.has(id):
        return
    var old: Vector2 = fingers[id]
    var before: Array = fingers.values()
    fingers[id] = point
    if is_instance_valid(equipment):
        equipment.call("_on_preview_drag",id,_preview_point(point))
        return
    if fingers.size() == 1:
        var delta: Vector2 = point-old
        yaw = wrapf(yaw+delta.x*0.008,-PI,PI)
        pitch = clampf(pitch+delta.y*0.008,-1.48,1.48)
    elif fingers.size() == 2:
        var after: Array = fingers.values()
        var a: Vector2 = before[0]
        var b: Vector2 = before[1]
        var c: Vector2 = after[0]
        var d: Vector2 = after[1]
        var move: Vector2 = (c+d-a-b)*0.5
        pan += Vector2(move.x,-move.y)*fit_size/maxf(1.0,host.size.y)/zoom
        pan = pan.clamp(Vector2(-2,-2),Vector2(2,2))
        if a.distance_to(b)>12 and c.distance_to(d)>12:
            zoom = clampf(zoom*c.distance_to(d)/a.distance_to(b),0.35,4.0)
    _apply_transform()

func route_input(event: InputEvent) -> bool:
    if not visible:
        return false
    if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_BACK,KEY_ESCAPE]):
        close_requested.emit()
        return true
    if event is InputEventScreenTouch:
        _touch(event.index,event.pressed,event.position)
    elif event is InputEventScreenDrag:
        _drag(event.index,event.position)
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _touch(-10,event.pressed,event.position)
        elif event.pressed and _contains(host, event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            var factor: float = 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.1
            if is_instance_valid(equipment) and bool(equipment.get("ready_for_commands")):
                equipment.set("camera_zoom",clampf(float(equipment.get("camera_zoom"))*factor,0.25,4.0))
                equipment.call("_apply_frame")
            else:
                zoom = clampf(zoom*factor,0.35,4.0)
                _apply_transform()
    elif event is InputEventMouseMotion:
        _drag(-10,event.position)
    else:
        return false
    return true
