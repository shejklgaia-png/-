extends Control
## NEXUS placement editor: persistent developer previews and official defaults.
## The hosting command_nexus.gd routes ALL raw input here before normal tap UI.
## Separate developer data, no player-save mutation or new viewport.
const PlacementStore = preload("res://scripts/sera_placement_store.gd")


const SCENE_ID := "res://scenes/command_nexus.tscn"
const TARGET_ORDER := ["TRAINING", "SYSTEM", "DATA ARCHIVE", "DEPLOYMENT"]
const TURN_STEP := 5.0
const HEIGHT_STEP := 0.10
const TRANSLATE_STEP := 0.10  # 10cm per tap, same precision as height edits.
const SAFE_MARGIN := 10.0

var host
# Remains false if configure() aborts before its final binding stage.
# The NEXUS launcher checks this instead of only is_inside_tree().
var initialized := false
# Short setup phase is exposed in the launcher when initialization fails.
var initialization_stage := "NEW"
var active := false
var selected := ""
var entries: Dictionary = {}
# Do not bind thousands of generated MultiMesh instances while opening the
# placement editor. Each selected facility is bound only when it first moves.
var _source_refs: Dictionary = {}
var _render_batches: Dictionary = {}
var _bound_entries: Dictionary = {}
var original_outline_visible := true
var pointer_id := -999
var pointer_mouse := false
var drag_ground := Vector3.ZERO
var drag_origin := Vector3.ZERO
var _buttons: Dictionary = {}
var _status_label: Label
var _hint_label: Label
var _ui_signature := ""


func configure(scene: Node3D, placements: Dictionary,
        source_refs: Dictionary, batches: Dictionary) -> void:
    if initialized:
        return
    initialization_stage = "HUD"
    host = scene
    name = "NexusCanonicalPlacement"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    if not resized.is_connected(_sync_ui):
        resized.connect(_sync_ui)
    if _buttons.is_empty():
        _create_visible_controls()
    set_process(true)
    initialization_stage = "MODELS"
    entries.clear()
    _source_refs = source_refs
    _render_batches = batches
    _bound_entries.clear()
    for key_value in placements.keys():
        var key: String = str(key_value)
        var spec: Dictionary = placements[key]
        var position: Vector3 = spec["position"]
        var yaw: float = float(spec["yaw"])
        var base_pose := Transform3D(Basis(Vector3.UP, yaw), position)
        var entry: Dictionary = {
            "id": key, "module": str(spec["module"]),
            "base": base_pose, "position": position, "yaw": yaw,
            "bindings": [], "silhouettes": [],
            "focus": {}
        }
        if host.target_parts.has(key):
            entry["silhouettes"] = host.target_parts[key].duplicate(true)
        if host.focus_views.has(key):
            entry["focus"] = host.focus_views[key].duplicate(true)
        entries[key] = entry

    # At this point all four authoritative positions and projected outlines
    # exist. Heavy mesh discovery does not belong on the critical start path.
    initialized = entries.size() == placements.size() and not entries.is_empty()
    if initialized:
        initialization_stage = "READY"
        _sync_ui()
        # Persisted developer placement previews are restored after the UI
        # becomes available; their visual mesh bindings remain on-demand.
        call_deferred("_restore_saved_placements")
    else:
        initialization_stage = "NO MODELS"
        push_warning("NEXUS canonical placement: missing placement definitions")


func _ensure_visual_bindings(key: String) -> void:
    if _bound_entries.has(key) or not entries.has(key):
        return
    # The source ref arrays contain exact MultiMesh indices, so no adjacent
    # structure is moved along with the selected terminal.
    var items: Array = _source_refs.get(key, [])
    for item_value in items:
        var item: Dictionary = item_value
        var batch_key: int = int(item.get("batch_key", -1))
        var multi: MultiMesh = _render_batches.get(batch_key) as MultiMesh
        var index: int = int(item.get("index", -1))
        if multi == null or index < 0 or index >= multi.instance_count:
            continue
        _bind_instance(key, multi, index, item["transform"])

    if key in ["SYSTEM", "TRAINING"]:
        for root_name in ["NexusProceduralArchitecture",
                "NexusComplexMachining", "NexusSculptedFittings"]:
            var root := host.get_node_or_null(root_name)
            if root == null:
                continue
            for node in root.get_children():
                if not (node is MultiMeshInstance3D):
                    continue
                var multi: MultiMesh = node.multimesh
                if multi == null:
                    continue
                for index in range(multi.instance_count):
                    var base: Transform3D = multi.get_instance_transform(index)
                    var center: Vector3 = entries[key]["position"]
                    if Vector2(base.origin.x - center.x,
                            base.origin.z - center.z).length() > 1.58:
                        continue
                    if absf(base.origin.y - center.y) > 3.10:
                        continue
                    _bind_instance(key, multi, index, base)

    var monitors: Array = []
    match key:
        "SYSTEM":
            monitors = ["MON_N01", "MON_N02"]
        "TRAINING":
            monitors = ["MON_N03", "MON_N04"]
        "DATA ARCHIVE":
            monitors = ["MON_N05", "MON_N06"]
    for monitor_name in monitors:
        _bind_node(key, host.get_node_or_null(str(monitor_name)))
    match key:
        "SYSTEM":
            _bind_node(key, host.get_node_or_null(
                "NexusRoomWorkingHardware/SystemCabinetMotion"))
        "TRAINING":
            _bind_node(key, host.get_node_or_null("TrainingServiceAssembly"))
            _bind_node(key, host.get_node_or_null(
                "NexusRoomWorkingHardware/TrainingSensorMotion"))
        "DEPLOYMENT":
            # Do not move the gate, hull, support pylons or ramp.
            _bind_node(key, host.get_node_or_null(
                "DeploymentWallDock/DeploymentConsolePlacementAnchor"))
    _bound_entries[key] = true


func _bind_instance(key: String, multi: MultiMesh,
        index: int, original: Transform3D) -> void:
    var entry: Dictionary = entries[key]
    var bindings: Array = entry["bindings"]
    bindings.append({"kind": "multi", "mesh": multi,
        "index": index, "base": original})
    entry["bindings"] = bindings


func _bind_node(key: String, obj: Node) -> void:
    if not (obj is Node3D):
        return
    var entry: Dictionary = entries[key]
    var bindings: Array = entry["bindings"]
    bindings.append({"kind": "node", "node": obj,
        "base": (obj as Node3D).global_transform})
    entry["bindings"] = bindings


# Also called by the real NEXUS HUD Button.pressed signal.
# The old raw-input-only activation was unreliable in the SubViewport.
func open_mode() -> bool:
    if active:
        return true
    if not initialized or not _can_open():
        return false
    active = true
    selected = ""
    pointer_id = -999
    pointer_mouse = false
    var ink: Control = host.get("outline") as Control
    if ink != null:
        original_outline_visible = ink.visible
        ink.visible = false
    _sync_ui()
    queue_redraw()
    return true


func route_input(event: InputEvent) -> bool:
    if not active:
        var press: Variant = _press_position(event)
        if press != null and _toggle_rect().has_point(press):
            return open_mode()
        return false

    # Editing is the only allowed raw input consumer until it ends.
    # This also suspends EXIT, camera focusing, menus and other model taps.
    if event.is_action_pressed("ui_cancel") or (
            event is InputEventKey and event.pressed and not event.echo
            and event.keycode in [KEY_BACK, KEY_ESCAPE]):
        close_mode()
        return true
    if event is InputEventScreenTouch:
        if event.pressed:
            _press(event.position, event.index, false)
        elif event.index == pointer_id:
            pointer_id = -999
            PlacementStore.flush()
        return true
    if event is InputEventScreenDrag:
        if event.index == pointer_id:
            _drag_to(event.position)
        return true
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _press(event.position, -100, true)
            else:
                pointer_mouse = false
                pointer_id = -999
                PlacementStore.flush()
        return true
    if event is InputEventMouseMotion:
        if pointer_mouse and pointer_id == -100:
            _drag_to(event.position)
        return true
    return true


func _can_open() -> bool:
    return host != null and host.get("focused_target") == "" and (
        not bool(host.get("in_transition")))


func _press_position(event: InputEvent) -> Variant:
    if event is InputEventScreenTouch and event.pressed:
        return event.position
    if event is InputEventMouseButton and event.pressed and (
            event.button_index == MOUSE_BUTTON_LEFT):
        return event.position
    return null


func _press(where: Vector2, finger: int, mouse: bool) -> void:
    pointer_id = -999
    pointer_mouse = false
    if _close_rect().has_point(where):
        close_mode()
        return
    if _copy_rect().has_point(where):
        _copy_selected(false)
        return
    if _copy_all_rect().has_point(where):
        _copy_selected(true)
        return
    if not selected.is_empty():
        var keys: Dictionary = _gizmo_boxes()
        for operation in keys.keys():
            var button_rect: Rect2 = keys[operation]
            if button_rect.has_point(where):
                var pose: Dictionary = entries[selected]
                if operation == "rot_l" or operation == "rot_r":
                    var step: float = -TURN_STEP if operation == "rot_l" else TURN_STEP
                    _set_pose(selected, pose["position"],
                        float(pose["yaw"]) + deg_to_rad(step))
                elif operation == "up" or operation == "down":
                    var rise: float = HEIGHT_STEP if operation == "up" else -HEIGHT_STEP
                    var at: Vector3 = pose["position"]
                    at.y = clampf(at.y + rise, -1.0, 8.0)
                    _set_pose(selected, at, float(pose["yaw"]))
                elif operation in ["move_f", "move_b", "move_l", "move_r"]:
                    # Match the overview camera's world axes: forward is -Z,
                    # right is +X. Do not change the selected model's Y/yaw.
                    var at: Vector3 = pose["position"]
                    match operation:
                        "move_f": at.z -= TRANSLATE_STEP
                        "move_b": at.z += TRANSLATE_STEP
                        "move_l": at.x -= TRANSLATE_STEP
                        "move_r": at.x += TRANSLATE_STEP
                    at.x = clampf(at.x, -10.0, 10.0)
                    at.z = clampf(at.z, -30.0, 11.0)
                    _set_pose(selected, at, float(pose["yaw"]))
                return

    var picked: String = _hit_console(where)
    selected = picked
    _sync_ui()
    queue_redraw()
    if picked.is_empty():
        return
    var state: Dictionary = entries[picked]
    var picked_position: Vector3 = state["position"]
    var floor_point: Variant = _ray_plane(where, picked_position.y)
    if floor_point != null:
        drag_ground = floor_point
        drag_origin = state["position"]
        pointer_id = finger
        pointer_mouse = mouse


func _drag_to(where: Vector2) -> void:
    if selected.is_empty():
        return
    var floor_point: Variant = _ray_plane(where, drag_origin.y)
    if floor_point == null:
        return
    var delta: Vector3 = floor_point - drag_ground
    var new_origin := drag_origin + Vector3(delta.x, 0.0, delta.z)
    new_origin.x = clampf(new_origin.x, -10.0, 10.0)
    new_origin.z = clampf(new_origin.z, -30.0, 11.0)
    _set_pose(selected, new_origin, float(entries[selected]["yaw"]))


func _ray_plane(where: Vector2, floor_y: float) -> Variant:
    var camera: Camera3D = host.get("cam") as Camera3D
    if camera == null:
        return null
    var origin: Vector3 = camera.project_ray_origin(where)
    var ray: Vector3 = camera.project_ray_normal(where)
    if absf(ray.y) < 0.001:
        return null
    var distance: float = (floor_y - origin.y) / ray.y
    if distance <= 0.0:
        return null
    return origin + ray * distance


func _hit_console(where: Vector2) -> String:
    for key in TARGET_ORDER:
        if key == "DEPLOYMENT":
            var corners: Array = entries[key]["silhouettes"]
            if corners.is_empty():
                continue
            var base_points: PackedVector3Array = corners[corners.size() - 1]
            var base_pose: Transform3D = entries[key]["base"]
            var delta: Transform3D = _current_delta(entries[key])
            var points := PackedVector2Array()
            for original in base_points:
                var world: Vector3 = delta * original
                var camera: Camera3D = host.get("cam") as Camera3D
                if camera.is_position_behind(world):
                    continue
                points.append(camera.unproject_position(world))
            if points.size() >= 3 and _contains_hull(where, points):
                return key
        else:
            var polys: Array = host.call("_project_model_contour", key)
            for polygon in polys:
                if polygon.size() >= 3 and (
                        Geometry2D.is_point_in_polygon(where, polygon) or
                        _bounds(polygon).grow(11.0).has_point(where)):
                    return key
    return ""


func _contains_hull(where: Vector2, vertices: PackedVector2Array) -> bool:
    var hull: PackedVector2Array = Geometry2D.convex_hull(vertices)
    return hull.size() >= 3 and (
        Geometry2D.is_point_in_polygon(where, hull) or
        _bounds(hull).grow(13.0).has_point(where))


func _bounds(vertices: PackedVector2Array) -> Rect2:
    var min_v := Vector2(INF, INF)
    var max_v := Vector2(-INF, -INF)
    for value in vertices:
        min_v = min_v.min(value)
        max_v = max_v.max(value)
    return Rect2(min_v, max_v - min_v)


func _current_delta(entry: Dictionary) -> Transform3D:
    var pose := Transform3D(
        Basis(Vector3.UP, float(entry["yaw"])), entry["position"])
    var base_pose: Transform3D = entry["base"]
    return pose * base_pose.affine_inverse()


func _restore_saved_placements() -> void:
    for key_value in entries.keys():
        var key: String = str(key_value)
        var entry: Dictionary = entries[key]
        var angle: Dictionary = PlacementStore.read("nexus/camera/" + key)
        if angle.has("eye") and angle.has("look") and angle.has("fov") and host.focus_views.has(key):
            var focus: Dictionary = entry["focus"]
            focus["eye"] = PlacementStore.vec(angle["eye"])
            focus["look"] = PlacementStore.vec(angle["look"])
            focus["fov"] = float(angle["fov"])
            entry["focus"] = focus
            entries[key] = entry
            var view: Dictionary = host.focus_views[key]
            view["eye"] = focus["eye"]
            view["look"] = focus["look"]
            view["fov"] = focus["fov"]
            host.focus_views[key] = view
        var record: Dictionary = PlacementStore.read("nexus/model/" + key)
        if record.has("position") and record.has("yaw_rad"):
            # A real model move must restore the 3D bindings once.
            _set_pose(key, PlacementStore.vec(record["position"]), float(record["yaw_rad"]), false)
        # If ONLY a camera angle was saved, the focus was restored above.
        # Do NOT call _set_pose with an identity transform here: that would
        # eagerly scan/bind every procedural mesh and stall the NEXUS GUI.
    host.call("_update_projected_silhouettes")


func record_camera_pose(key: String, eye: Vector3, look: Vector3, fov: float) -> void:
    if not initialized or not entries.has(key):
        return
    var entry: Dictionary = entries[key]
    # Store the camera relative to the original model placement, so subsequent
    # model movement preserves the chosen framing instead of resetting it.
    if key != "DEPLOYMENT":
        var inverse: Transform3D = _current_delta(entry).affine_inverse()
        eye = inverse * eye
        look = inverse * look
    var focus: Dictionary = entry["focus"]
    focus["eye"] = eye
    focus["look"] = look
    focus["fov"] = fov
    entry["focus"] = focus
    entries[key] = entry
    PlacementStore.stage("nexus/camera/" + key, {
        "scene": SCENE_ID, "model_id": key,
        "space": "global" if key == "DEPLOYMENT" else "original_model_frame",
        "eye": PlacementStore.array3(eye), "look": PlacementStore.array3(look), "fov": fov})


func _set_pose(key: String, at: Vector3, yaw: float, persist: bool = true) -> void:
    # Restore and drag the exact selected instance only when necessary.
    _ensure_visual_bindings(key)
    var entry: Dictionary = entries[key]
    entry["position"] = at
    entry["yaw"] = wrapf(yaw, -PI, PI)
    entries[key] = entry
    var delta: Transform3D = _current_delta(entry)
    for binding_value in entry["bindings"]:
        var binding: Dictionary = binding_value
        var base: Transform3D = binding["base"]
        if binding["kind"] == "multi":
            var multi: MultiMesh = binding["mesh"]
            multi.set_instance_transform(int(binding["index"]), delta * base)
        else:
            var node: Node3D = binding["node"] as Node3D
            if is_instance_valid(node):
                node.global_transform = delta * base

    # Hit polygons must follow the same transforms as their visual meshes.
    var base_clusters: Array = entry["silhouettes"]
    var moved_clusters: Array = []
    for index in range(base_clusters.size()):
        var cluster: PackedVector3Array = base_clusters[index]
        var vertices := PackedVector3Array()
        var movable: bool = key != "DEPLOYMENT" or (
            index == base_clusters.size() - 1)
        for vertex in cluster:
            vertices.append(delta * vertex if movable else vertex)
        moved_clusters.append(vertices)
    host.target_parts[key] = moved_clusters
    if key != "DEPLOYMENT" and not (entry["focus"] as Dictionary).is_empty():
        var base_focus: Dictionary = entry["focus"]
        var view: Dictionary = host.focus_views[key]
        var focus_eye: Vector3 = base_focus["eye"]
        var focus_look: Vector3 = base_focus["look"]
        view["eye"] = delta * focus_eye
        view["look"] = delta * focus_look
        host.focus_views[key] = view
    if persist:
        PlacementStore.stage("nexus/model/" + key, {
            "scene": SCENE_ID, "model_id": key, "module_id": entry["module"],
            "space": "global", "position": PlacementStore.array3(at),
            "yaw_rad": float(entry["yaw"])})
        if pointer_id == -999:
            PlacementStore.flush()
    # The view contours are hidden during edit; only recalculate on exit.
    _sync_ui()
    queue_redraw()


func _copy_selected(all_items: bool) -> void:
    if not all_items and selected.is_empty():
        return
    var ids: Array = TARGET_ORDER if all_items else [selected]
    var text_content := "NEXUS_CANONICAL_PLACEMENT\n"
    text_content += "scene=%s\nspace=global\n" % SCENE_ID
    text_content += "status=preview_not_committed\n"
    for key_value in ids:
        var key: String = str(key_value)
        var entry: Dictionary = entries[key]
        var at: Vector3 = entry["position"]
        text_content += "\nmodel_id=%s\nmodule_id=%s\n" % [
            key, str(entry["module"])]
        text_content += "position=(%.3f, %.3f, %.3f)\n" % [
            at.x, at.y, at.z]
        text_content += "rotation_deg=(0.000, %.3f, 0.000)\n" % [
            rad_to_deg(float(entry["yaw"]))]
    DisplayServer.clipboard_set(text_content)
    queue_redraw()


func close_mode() -> void:
    if not active:
        return
    PlacementStore.flush()
    active = false
    selected = ""
    pointer_id = -999
    pointer_mouse = false
    var ink: Control = host.get("outline") as Control
    if ink != null:
        ink.visible = original_outline_visible
    host.call("_update_projected_silhouettes")
    if ink != null:
        ink.queue_redraw()
    _sync_ui()
    queue_redraw()


func _toggle_rect() -> Rect2:
    # Use the same HUD button geometry that is actually visible on Android.
    if host != null:
        var entry_button: Control = host.get("placement_entry_button") as Control
        if entry_button != null:
            return Rect2(entry_button.position, entry_button.size)
    return Rect2(Vector2(20.0, 112.0), Vector2(156.0, 54.0))


func _close_rect() -> Rect2:
    return Rect2(Vector2(14.0, 18.0), Vector2(105.0, 48.0))


func _copy_rect() -> Rect2:
    return Rect2(Vector2(size.x - 229.0, 18.0),
        Vector2(103.0, 48.0))


func _copy_all_rect() -> Rect2:
    return Rect2(Vector2(size.x - 120.0, 18.0),
        Vector2(108.0, 48.0))


func _gizmo_boxes() -> Dictionary:
    if selected.is_empty():
        return {}
    var camera: Camera3D = host.get("cam") as Camera3D
    if camera == null:
        return {}
    var at: Vector3 = entries[selected]["position"]
    var center: Vector2 = camera.unproject_position(at)
    center.x = clampf(center.x, 145.0, size.x - 160.0)
    # Reserve a second gizmo tier for planar translation, above bottom HUD.
    center.y = clampf(center.y + 86.0, 145.0, size.y - 275.0)
    return {
        "rot_l": Rect2(center + Vector2(-99.0, 0.0),
            Vector2(49.0, 47.0)),
        "rot_r": Rect2(center + Vector2(-45.0, 0.0),
            Vector2(49.0, 47.0)),
        "up": Rect2(center + Vector2(32.0, -24.0),
            Vector2(47.0, 43.0)),
        "down": Rect2(center + Vector2(32.0, 24.0),
            Vector2(47.0, 43.0)),
        "move_f": Rect2(center + Vector2(-25.0, 76.0),
            Vector2(50.0, 43.0)),
        "move_b": Rect2(center + Vector2(-25.0, 165.0),
            Vector2(50.0, 43.0)),
        "move_l": Rect2(center + Vector2(-82.0, 121.0),
            Vector2(50.0, 43.0)),
        "move_r": Rect2(center + Vector2(32.0, 121.0),
            Vector2(50.0, 43.0))
    }


# The old _draw() path was dependent on the viewport's redraw timing and
# _can_open() snapshot: the button could never repaint when the focus mode
# changed. Real persistent Panel + Label children are visible as soon as the
# editor is attached; a lightweight state change poll updates their visibility.
func _create_visible_controls() -> void:
    var host_hud: Control = host.get("hud") as Control
    if host_hud != null:
        theme = host_hud.theme
    for key in ["toggle", "close", "copy", "copy_all",
            "rot_l", "rot_r", "up", "down",
            "move_f", "move_b", "move_l", "move_r"]:
        var panel := Panel.new()
        panel.name = "Placement_" + key
        panel.mouse_filter = Control.MOUSE_FILTER_STOP
        var style := StyleBoxFlat.new()
        style.bg_color = Color("#163447")
        style.border_color = Color("#72b4ce")
        style.set_border_width_all(2)
        style.set_corner_radius_all(4)
        panel.add_theme_stylebox_override("panel", style)
        add_child(panel)
        var caption := Label.new()
        caption.text = _caption(key)
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        caption.add_theme_font_size_override("font_size", 16)
        caption.add_theme_color_override("font_color", Color("#dcf5ff"))
        panel.add_child(caption)
        caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        if key != "toggle":
            panel.gui_input.connect(_on_editor_panel_input.bind(key))
        _buttons[key] = panel
        panel.visible = false

    _status_label = Label.new()
    _status_label.name = "CanonicalPlacementStatus"
    _status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _status_label.add_theme_font_size_override("font_size", 16)
    _status_label.add_theme_color_override("font_color", Color("#b8edfa"))
    add_child(_status_label)
    _hint_label = Label.new()
    _hint_label.name = "CanonicalPlacementHint"
    _hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hint_label.add_theme_font_size_override("font_size", 14)
    _hint_label.add_theme_color_override("font_color", Color("#9cc4d2"))
    add_child(_hint_label)


func _on_editor_panel_input(event: InputEvent, key: String) -> void:
    if not active or not _buttons.has(key):
        return
    var pressed: bool = (
        (event is InputEventScreenTouch and event.pressed)
        or (event is InputEventMouseButton and event.pressed
            and event.button_index == MOUSE_BUTTON_LEFT))
    var panel: Panel = _buttons[key]
    if pressed and panel.visible:
        _press(Rect2(panel.position, panel.size).get_center(), -999, false)
        get_viewport().set_input_as_handled()


func _caption(key: String) -> String:
    match key:
        "toggle":
            return "正規配置"
        "close":
            return "編集終了"
        "copy":
            return "コピー"
        "copy_all":
            return "全件コピー"
        "rot_l":
            return "回転◀"
        "rot_r":
            return "回転▶"
        "up":
            return "▲高さ"
        "down":
            return "▼高さ"
        "move_f":
            return "前▲"
        "move_b":
            return "後▼"
        "move_l":
            return "左◀"
        "move_r":
            return "右▶"
    return key


func _process(_delta: float) -> void:
    if host == null:
        return
    var can_open := _can_open()
    var signature := "%s/%s/%s/%sx%s" % [
        str(active), selected, str(can_open),
        str(int(get_viewport_rect().size.x)),
        str(int(get_viewport_rect().size.y))]
    if signature != _ui_signature:
        _sync_ui()


func _sync_ui() -> void:
    if host == null or _buttons.is_empty():
        return
    size = get_viewport_rect().size
    _ui_signature = "%s/%s/%s/%sx%s" % [
        str(active), selected, str(_can_open()),
        str(int(size.x)), str(int(size.y))]

    for name_value in _buttons.keys():
        var name: String = str(name_value)
        var panel: Panel = _buttons[name]
        var enabled: bool = false
        var rect: Rect2
        match name:
            "toggle":
                # The permanent entry Button is owned by command_nexus._hud,
                # not this editor. Never draw a duplicate in CanvasLayer 8.
                enabled = false
                rect = _toggle_rect()
            "close":
                enabled = active
                rect = _close_rect()
            "copy":
                enabled = active
                rect = _copy_rect()
            "copy_all":
                enabled = active
                rect = _copy_all_rect()
            _:
                enabled = active and not selected.is_empty()
                if enabled:
                    rect = _gizmo_boxes().get(name, Rect2())
        panel.visible = enabled
        if enabled:
            panel.position = rect.position
            panel.size = rect.size

    _status_label.visible = active
    _hint_label.visible = active
    if active:
        _status_label.position = Vector2(19.0, 84.0)
        _status_label.size = Vector2(maxf(80.0, size.x - 38.0), 45.0)
        if selected.is_empty():
            _status_label.text = "端末を選択・ドラッグで水平移動"
        else:
            var state: Dictionary = entries[selected]
            var at: Vector3 = state["position"]
            _status_label.text = "%s  X %.2f Y %.2f Z %.2f  Yaw %.0f°" % [
                selected, at.x, at.y, at.z,
                rad_to_deg(float(state["yaw"]))]
        _hint_label.position = Vector2(18.0, size.y - 49.0)
        _hint_label.size = Vector2(maxf(80.0, size.x - 36.0), 33.0)
        _hint_label.text = "仮配置です。コピーしてChatGPTへ送ると確定できます。"
