extends Control
# Independent, minimal editor used only when the full model-placement script
# cannot instantiate. Camera-angle editor and normal NEXUS input are untouched.
const Store = preload("res://scripts/sera_placement_store.gd")
const ORDER = ["TRAINING", "SYSTEM", "DATA ARCHIVE", "DEPLOYMENT"]
const TRANSLATE_STEP := 0.10  # world X/Z, 10cm per button tap
var initialized := false
var initialization_stage := "NEW"
var active := false
var host
var selected := ""
var entries: Dictionary = {}
var refs: Dictionary = {}
var batches: Dictionary = {}
var bindings: Dictionary = {}
var panels: Dictionary = {}
var touch_id := -999
var last_world := Vector3.ZERO
var drag_origin := Vector3.ZERO
var was_outline_visible := true

func configure(scene: Node3D, specs: Dictionary, source_refs: Dictionary, render_batches: Dictionary) -> void:
    if initialized:
        return
    initialization_stage = "SETUP"
    host = scene
    refs = source_refs
    batches = render_batches
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    for key_value in specs.keys():
        var key := str(key_value)
        var spec: Dictionary = specs[key]
        var pos: Vector3 = spec["position"]
        var yaw: float = float(spec["yaw"])
        entries[key] = {
            "position": pos, "yaw": yaw, "module": str(spec["module"]),
            "base": Transform3D(Basis(Vector3.UP, yaw), pos),
            "silhouettes": host.target_parts.get(key, []).duplicate(true),
            "focus": host.focus_views.get(key, {}).duplicate(true)
        }
    if entries.size() != specs.size() or entries.is_empty():
        initialization_stage = "NO MODELS"
        return
    _make_panels()
    initialized = true
    initialization_stage = "READY"
    _layout()
    call_deferred("_restore_saved")

func _make_panels() -> void:
    for key in ["close", "copy", "copy_all", "rot_l", "rot_r", "up", "down",
            "move_f", "move_b", "move_l", "move_r"]:
        var panel := Panel.new()
        panel.name = "Recover_" + key
        panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var style := StyleBoxFlat.new()
        style.bg_color = Color("#173548")
        style.border_color = Color("#72b4ce")
        style.set_border_width_all(2)
        panel.add_theme_stylebox_override("panel", style)
        add_child(panel)
        var label := Label.new()
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 16)
        var captions: Dictionary = {
            "close":"編集終了", "copy":"コピー", "copy_all":"全件コピー",
            "rot_l":"回転◀", "rot_r":"回転▶", "up":"▲高さ", "down":"▼高さ",
            "move_f":"前▲", "move_b":"後▼", "move_l":"左◀", "move_r":"右▶"
        }
        label.text = str(captions.get(key, key))
        panel.add_child(label)
        label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        panel.visible = false
        panels[key] = panel

func _layout() -> void:
    size = get_viewport_rect().size
    var w := size.x
    var h := size.y
    var rects := {
        "close": Rect2(14, 18, 105, 48),
        "copy": Rect2(w - 229, 18, 103, 48),
        "copy_all": Rect2(w - 120, 18, 108, 48),
        "rot_l": Rect2(w * 0.5 - 128, h - 164, 54, 52),
        "rot_r": Rect2(w * 0.5 - 69, h - 164, 54, 52),
        "up": Rect2(w * 0.5 + 27, h - 164, 65, 52),
        "down": Rect2(w * 0.5 + 97, h - 164, 65, 52),
        # Separate cross-pad above the rotation/height row.
        "move_f": Rect2(w * 0.5 - 25, h - 292, 50, 47),
        "move_b": Rect2(w * 0.5 - 25, h - 236, 50, 47),
        "move_l": Rect2(w * 0.5 - 84, h - 264, 50, 47),
        "move_r": Rect2(w * 0.5 + 34, h - 264, 50, 47)
    }
    for key in panels.keys():
        var panel: Panel = panels[key]
        panel.visible = active and (key in ["close", "copy", "copy_all"] or not selected.is_empty())
        panel.position = rects[key].position
        panel.size = rects[key].size

func open_mode() -> bool:
    if active:
        return true
    if not initialized or host == null or str(host.get("focused_target")) != "" or bool(host.get("in_transition")):
        return false
    active = true
    selected = ""
    touch_id = -999
    var ink: Control = host.get("outline") as Control
    if ink != null:
        was_outline_visible = ink.visible
        ink.visible = false
    _layout()
    return true

func close_mode() -> void:
    if not active:
        return
    Store.flush()
    active = false
    selected = ""
    touch_id = -999
    var ink: Control = host.get("outline") as Control
    if ink != null:
        ink.visible = was_outline_visible
        host.call("_update_projected_silhouettes")
        ink.queue_redraw()
    _layout()

func route_input(event: InputEvent) -> bool:
    if not active:
        return false
    if event.is_action_pressed("ui_cancel"):
        close_mode()
        return true
    if event is InputEventScreenTouch:
        if event.pressed:
            _press(event.position, event.index)
        elif event.index == touch_id:
            touch_id = -999
            Store.flush()
        return true
    if event is InputEventScreenDrag:
        if event.index == touch_id:
            _move(event.position)
        return true
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _press(event.position, -100)
        else:
            touch_id = -999
            Store.flush()
        return true
    if event is InputEventMouseMotion and touch_id == -100:
        _move(event.position)
        return true
    return true

func _press(at: Vector2, pointer: int) -> void:
    touch_id = -999
    for key in panels.keys():
        var panel: Panel = panels[key]
        if panel.visible and Rect2(panel.position, panel.size).has_point(at):
            _action(key)
            return
    selected = _pick(at)
    _layout()
    if selected.is_empty():
        return
    var entry: Dictionary = entries[selected]
    var ground = _ground(at, float(entry["position"].y))
    if ground != null:
        last_world = ground
        drag_origin = entry["position"]
        touch_id = pointer

func _pick(at: Vector2) -> String:
    for key in ORDER:
        if not entries.has(key):
            continue
        var polys: Array = host.call("_project_model_contour", key)
        for polygon in polys:
            if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(at, polygon):
                return key
    return ""

func _ground(at: Vector2, y: float):
    var cam: Camera3D = host.get("cam") as Camera3D
    if cam == null:
        return null
    var ray: Vector3 = cam.project_ray_normal(at)
    if absf(ray.y) < 0.001:
        return null
    var t: float = (y - cam.project_ray_origin(at).y) / ray.y
    if t <= 0.0:
        return null
    return cam.project_ray_origin(at) + ray * t

func _move(at: Vector2) -> void:
    if selected.is_empty():
        return
    var ground = _ground(at, float(drag_origin.y))
    if ground == null:
        return
    var delta: Vector3 = ground - last_world
    var pos := drag_origin + Vector3(delta.x, 0, delta.z)
    pos.x = clampf(pos.x, -10, 10)
    pos.z = clampf(pos.z, -30, 11)
    _set_pose(selected, pos, float(entries[selected]["yaw"]))

func _action(key: String) -> void:
    if key == "close":
        close_mode()
        return
    if key == "copy" or key == "copy_all":
        var keys: Array = ORDER if key == "copy_all" else [selected]
        var output := "NEXUS_CANONICAL_PLACEMENT\nscene=res://scenes/command_nexus.tscn\nstatus=preview_not_committed\n"
        for name in keys:
            if not entries.has(name):
                continue
            var pose: Dictionary = entries[name]
            var at: Vector3 = pose["position"]
            output += "\nmodel_id=%s\nmodule_id=%s\nposition=(%.3f, %.3f, %.3f)\nrotation_deg=(0.000, %.3f, 0.000)\n" % [
                name, pose["module"], at.x, at.y, at.z, rad_to_deg(float(pose["yaw"]))]
        DisplayServer.clipboard_set(output)
        return
    if selected.is_empty():
        return
    var e: Dictionary = entries[selected]
    var at: Vector3 = e["position"]
    var yaw: float = float(e["yaw"])
    if key == "rot_l":
        yaw -= deg_to_rad(5)
    elif key == "rot_r":
        yaw += deg_to_rad(5)
    elif key == "up":
        at.y = minf(8, at.y + 0.1)
    elif key == "down":
        at.y = maxf(-1, at.y - 0.1)
    elif key == "move_f":
        at.z -= TRANSLATE_STEP
    elif key == "move_b":
        at.z += TRANSLATE_STEP
    elif key == "move_l":
        at.x -= TRANSLATE_STEP
    elif key == "move_r":
        at.x += TRANSLATE_STEP
    at.x = clampf(at.x, -10.0, 10.0)
    at.z = clampf(at.z, -30.0, 11.0)
    _set_pose(selected, at, yaw)

func _ensure_bindings(key: String) -> void:
    if bindings.has(key):
        return
    var found: Array = []
    for source in refs.get(key, []):
        var idx: int = int(source.get("index", -1))
        var multi: MultiMesh = batches.get(int(source.get("batch_key", -1))) as MultiMesh
        if multi != null and idx >= 0 and idx < multi.instance_count:
            found.append({"kind":"multi", "multi":multi, "index":idx,
                "base":source["transform"]})
    if key in ["SYSTEM", "TRAINING"]:
        for root_name in ["NexusProceduralArchitecture", "NexusComplexMachining", "NexusSculptedFittings"]:
            var root: Node = host.get_node_or_null(root_name)
            if root == null:
                continue
            for node in root.get_children():
                if not (node is MultiMeshInstance3D):
                    continue
                var multi: MultiMesh = node.multimesh
                if multi == null:
                    continue
                for i in range(multi.instance_count):
                    var base: Transform3D = multi.get_instance_transform(i)
                    var center: Vector3 = entries[key]["position"]
                    if Vector2(base.origin.x-center.x, base.origin.z-center.z).length() > 1.58:
                        continue
                    if absf(base.origin.y-center.y) <= 3.10:
                        found.append({"kind":"multi", "multi":multi, "index":i, "base":base})
    var names: Array = []
    if key == "SYSTEM":
        names = ["MON_N01", "MON_N02", "NexusRoomWorkingHardware/SystemCabinetMotion"]
    elif key == "TRAINING":
        names = ["MON_N03", "MON_N04", "TrainingServiceAssembly", "NexusRoomWorkingHardware/TrainingSensorMotion"]
    elif key == "DATA ARCHIVE":
        names = ["MON_N05", "MON_N06"]
    elif key == "DEPLOYMENT":
        names = ["DeploymentWallDock/DeploymentConsolePlacementAnchor"]
    for name in names:
        var node: Node3D = host.get_node_or_null(name) as Node3D
        if node != null:
            found.append({"kind":"node", "node":node, "base":node.global_transform})
    bindings[key] = found

func _set_pose(key: String, at: Vector3, yaw: float, persist: bool = true) -> void:
    _ensure_bindings(key)
    var e: Dictionary = entries[key]
    e["position"] = at
    e["yaw"] = wrapf(yaw, -PI, PI)
    entries[key] = e
    var base_pose: Transform3D = e["base"]
    var delta: Transform3D = Transform3D(
        Basis(Vector3.UP, float(e["yaw"])), at) * base_pose.affine_inverse()
    for binding in bindings[key]:
        var base: Transform3D = binding["base"]
        if binding["kind"] == "multi":
            var multi: MultiMesh = binding["multi"]
            multi.set_instance_transform(int(binding["index"]), delta * base)
        else:
            var node: Node3D = binding["node"]
            if is_instance_valid(node):
                node.global_transform = delta * base
    var clusters: Array = []
    for index in range(e["silhouettes"].size()):
        var old_points: PackedVector3Array = e["silhouettes"][index]
        var points := PackedVector3Array()
        for vertex in old_points:
            points.append(delta * vertex if key != "DEPLOYMENT" or index == e["silhouettes"].size()-1 else vertex)
        clusters.append(points)
    host.target_parts[key] = clusters
    if key != "DEPLOYMENT" and not (e["focus"] as Dictionary).is_empty():
        var view: Dictionary = host.focus_views[key]
        view["eye"] = delta * e["focus"]["eye"]
        view["look"] = delta * e["focus"]["look"]
        host.focus_views[key] = view
    if persist:
        Store.stage("nexus/model/" + key, {
            "scene":"res://scenes/command_nexus.tscn", "model_id":key, "module_id":e["module"],
            "space":"global", "position":Store.array3(at), "yaw_rad":float(e["yaw"])})
        if touch_id == -999:
            Store.flush()

func _restore_saved() -> void:
    if host == null:
        return
    for key in entries.keys():
        var angle: Dictionary = Store.read("nexus/camera/" + key)
        if angle.has("eye") and angle.has("look") and angle.has("fov"):
            var entry: Dictionary = entries[key]
            var base_focus: Dictionary = entry["focus"]
            base_focus["eye"] = Store.vec(angle["eye"])
            base_focus["look"] = Store.vec(angle["look"])
            base_focus["fov"] = float(angle["fov"])
            base_focus["roll_deg"] = float(angle.get("roll_deg", 0.0))
            entry["focus"] = base_focus
            entries[key] = entry
            var view: Dictionary = host.focus_views.get(key, {})
            if not view.is_empty():
                view["eye"] = base_focus["eye"]
                view["look"] = base_focus["look"]
                view["fov"] = base_focus["fov"]
                view["roll_deg"] = base_focus["roll_deg"]
                host.focus_views[key] = view
        var rec: Dictionary = Store.read("nexus/model/" + key)
        if rec.has("position") and rec.has("yaw_rad"):
            _set_pose(key, Store.vec(rec["position"]), float(rec["yaw_rad"]), false)
    host.call("_update_projected_silhouettes")
