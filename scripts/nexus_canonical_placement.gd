extends Control
## NEXUS canonical placement editor. Runtime previews only: permanent placements
## are written to the source scene after the copied transform is sent to ChatGPT.
## The hosting command_nexus.gd routes ALL raw input here before normal tap UI.
## No save mutation, new viewport, mesh generation or physics dependency.

const SCENE_ID := "res://scenes/command_nexus.tscn"
const TARGET_ORDER := ["TRAINING", "SYSTEM", "DATA ARCHIVE", "DEPLOYMENT"]
const TURN_STEP := 5.0
const HEIGHT_STEP := 0.10
const SAFE_MARGIN := 10.0

var host
var active := false
var selected := ""
var entries: Dictionary = {}
var original_outline_visible := true
var pointer_id := -999
var pointer_mouse := false
var drag_ground := Vector3.ZERO
var drag_origin := Vector3.ZERO


func configure(scene: Node3D, placements: Dictionary,
        source_refs: Dictionary, batches: Dictionary) -> void:
    host = scene
    name = "NexusCanonicalPlacement"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    resized.connect(queue_redraw)
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

    # Exact module instance indices prevent room architecture from moving with
    # a nearby terminal. The procedural accessory groups below are filtered.
    for key_value in source_refs.keys():
        var key: String = str(key_value)
        if not entries.has(key):
            continue
        var items: Array = source_refs[key]
        for item in items:
            var batch_key: int = int(item["batch_key"])
            var multi: MultiMesh = batches.get(batch_key) as MultiMesh
            if multi == null:
                continue
            _bind_instance(key, multi, int(item["index"]), item["transform"])

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
                for key in ["SYSTEM", "TRAINING"]:
                    var center: Vector3 = entries[key]["position"]
                    if Vector2(base.origin.x - center.x,
                            base.origin.z - center.z).length() > 1.58:
                        continue
                    if absf(base.origin.y - center.y) > 3.10:
                        continue
                    _bind_instance(key, multi, index, base)
                    break

    # The 24 fps animated monitor nodes must move as intact subtrees: driver,
    # atlas, shader and per-screen cadence continue working unchanged.
    for key in ["SYSTEM", "TRAINING", "DATA ARCHIVE"]:
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
    _bind_node("TRAINING", host.get_node_or_null("TrainingServiceAssembly"))
    _bind_node("SYSTEM", host.get_node_or_null(
        "NexusRoomWorkingHardware/SystemCabinetMotion"))
    _bind_node("TRAINING", host.get_node_or_null(
        "NexusRoomWorkingHardware/TrainingSensorMotion"))
    # Only the launch KIOSK is movable. The huge gate itself, wall supports,
    # ramp and animated shutters deliberately remain fixed.
    _bind_node("DEPLOYMENT", host.get_node_or_null(
        "DeploymentWallDock/DeploymentConsolePlacementAnchor"))
    queue_redraw()


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


func route_input(event: InputEvent) -> bool:
    if not active:
        if not _can_open():
            return false
        if _press_position(event) != null and (
                _toggle_rect().has_point(_press_position(event))):
            active = true
            selected = ""
            var ink: Control = host.get("outline") as Control
            if ink != null:
                original_outline_visible = ink.visible
                ink.visible = false
            queue_redraw()
            return true
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
                return

    var picked: String = _hit_console(where)
    selected = picked
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


func _set_pose(key: String, at: Vector3, yaw: float) -> void:
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
    # The view contours are hidden during edit; only recalculate on exit.
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
    queue_redraw()


func _toggle_rect() -> Rect2:
    return Rect2(Vector2(14.0, 18.0), Vector2(132.0, 45.0))


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
    center.x = clampf(center.x, 110.0, size.x - 135.0)
    center.y = clampf(center.y + 86.0, 145.0, size.y - 134.0)
    return {
        "rot_l": Rect2(center + Vector2(-99.0, 0.0),
            Vector2(49.0, 47.0)),
        "rot_r": Rect2(center + Vector2(-45.0, 0.0),
            Vector2(49.0, 47.0)),
        "up": Rect2(center + Vector2(32.0, -24.0),
            Vector2(47.0, 43.0)),
        "down": Rect2(center + Vector2(32.0, 24.0),
            Vector2(47.0, 43.0))
    }


func _draw() -> void:
    if host == null:
        return
    if not active:
        if _can_open():
            _button(_toggle_rect(), "正規配置")
        return
    _button(_close_rect(), "編集終了")
    _button(_copy_rect(), "コピー")
    _button(_copy_all_rect(), "全件コピー")
    var font: Font = get_theme_default_font()
    var caption := ("端末を選択・ドラッグで移動"
        if selected.is_empty() else "%s / 水平移動・回転・高さ" % selected)
    draw_string(font, Vector2(19.0, 96.0), caption,
        HORIZONTAL_ALIGNMENT_LEFT, size.x - 38.0,
        17, Color("#cbe9f2"))
    if not selected.is_empty():
        var state: Dictionary = entries[selected]
        var at: Vector3 = state["position"]
        var summary := "X %.2f  Y %.2f  Z %.2f  Yaw %.0f°" % [
            at.x, at.y, at.z, rad_to_deg(float(state["yaw"]))]
        draw_string(font, Vector2(19.0, 121.0), summary,
            HORIZONTAL_ALIGNMENT_LEFT, size.x - 38.0,
            15, Color("#91c9da"))
        var boxes: Dictionary = _gizmo_boxes()
        _button(boxes["rot_l"], "回転◀")
        _button(boxes["rot_r"], "回転▶")
        _button(boxes["up"], "▲高さ")
        _button(boxes["down"], "▼高さ")
    draw_string(font, Vector2(18.0, size.y - 20.0),
        "配置は仮設定です。コピー内容をChatGPTへ送って確定してください。",
        HORIZONTAL_ALIGNMENT_LEFT, size.x - 36.0,
        14, Color("#9bc5d5"))


func _button(rect: Rect2, title: String) -> void:
    draw_rect(rect, Color("#1b3446", 0.95), true)
    draw_rect(rect, Color("#6e9eb5"), false, 1.5)
    var font: Font = get_theme_default_font()
    draw_string(font, rect.position + Vector2(9.0, rect.size.y * 0.65),
        title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16.0,
        16, Color("#e0f5ff"))
