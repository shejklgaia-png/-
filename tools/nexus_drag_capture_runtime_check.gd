extends SceneTree
## Raw pointer capture must outlive every status/equipment rectangle.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("NEXUS_DRAG_CAPTURE_RUNTIME_FAIL: " + message)
    quit(1)

func _touch(point: Vector2, pressed: bool, id: int) -> InputEventScreenTouch:
    var event := InputEventScreenTouch.new()
    event.index = id
    event.position = point
    event.pressed = pressed
    return event

func _drag(point: Vector2, prev: Vector2, id: int) -> InputEventScreenDrag:
    var event := InputEventScreenDrag.new()
    event.index = id
    event.position = point
    event.relative = point - prev
    return event

func _run() -> void:
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    nexus.set("focused_target", "CUSTOMIZE")
    nexus.call("_focus_arrived", "CUSTOMIZE")
    await process_frame
    nexus.set("customize_preview_active", true)
    nexus.set("in_transition", false)
    var hud: Control = nexus.get("hud") as Control
    var model_area: Rect2 = nexus.call("_customize_model_area", hud.size)
    var total: Panel = nexus.get("customize_stats_panel") as Panel
    var single: Control = nexus.get("customize_single_part_preview") as Control
    var panel: Panel = nexus.get("focus_panel") as Panel
    var host: SubViewportContainer = single.get("preview_host") as SubViewportContainer
    if host == null or not single.visible or (
            single.position.distance_to(Vector2.ZERO) > 1.0) or (
            single.size.distance_to(panel.size) > 1.0):
        _fail("single-preview grid backdrop does not align to the whole chamfer frame")
        return
    await process_frame
    if host.size.distance_to(single.size) > 1.0:
        _fail("grid viewport host must fill part-preview container")
        return
    var scene: Node3D = single.get("preview_scene") as Node3D
    var viewport: SubViewport = single.get("render_viewport") as SubViewport
    if scene == null or viewport == null:
        _fail("part preview render world missing")
        return
    scene.call("_sync_preview_backdrop_aspect")
    var bg: MeshInstance3D = scene.get("background_quad") as MeshInstance3D
    var mesh: QuadMesh = bg.mesh as QuadMesh
    var expected: float = 2.0 * float(viewport.size.x) / (
        maxf(1.0, float(viewport.size.y)))
    if absf(mesh.size.x - expected) > 0.03 or (
            absf(mesh.size.y - 2.0) > 0.01):
        _fail("NEXUS GRID image and frame have incompatible aspect ratios")
        return

    var origin: Vector2 = model_area.get_center()
    var cross: Vector2 = total.get_global_rect().get_center()
    var before_yaw: float = float(nexus.get("customize_preview_yaw"))
    var before_pitch: float = float(nexus.get("customize_preview_pitch"))
    var before_position: Vector3 = nexus.get("customize_preview_position") as Vector3
    var before_scale: float = float(nexus.get("customize_preview_scale"))
    var display_rig: Node3D = nexus.get("sera_display_rig") as Node3D
    # The root is at the feet: cache the actual Chest/Torso/Waist center.
    # _focus_arrived() can be called without entering via the motion tween.
    var pivot_local: Vector3 = nexus.call("_customize_torso_anchor_local") as Vector3
    if pivot_local.length() < 0.10:
        _fail("live body pivot is missing or still at the feet/root")
        return
    nexus.set("customize_motion_torso_local", pivot_local)
    nexus.call("_apply_customization_preview_transform")
    var before_world_origin: Vector3 = display_rig.global_position
    var before_world_pivot: Vector3 = display_rig.to_global(pivot_local)
    nexus.call("_input", _touch(origin, true, 2))
    if int(nexus.get("customize_touch_id")) != 2:
        _fail("full-body touch was not captured in original model area")
        return
    nexus.call("_input", _drag(cross, origin, 2))
    if is_equal_approx(before_yaw, float(nexus.get("customize_preview_yaw"))) or (
            is_equal_approx(before_pitch, float(nexus.get("customize_preview_pitch")))):
        _fail("drag must rotate yaw and pitch even after crossing the top stats")
        return
    var dragged_pitch: float = float(nexus.get("customize_preview_pitch"))
    if (dragged_pitch - before_pitch) * (cross.y - origin.y) >= 0.0:
        _fail("vertical drag pitch must be reversed: dragging upward tilts positive")
        return
    if (nexus.get("customize_preview_position") as Vector3).distance_to(
            before_position) > 0.000001 or (
            absf(float(nexus.get("customize_preview_scale")) - before_scale) > 0.000001) or (
            display_rig.to_global(pivot_local).distance_to(before_world_pivot) > 0.0001):
        _fail("touch rotation must hold SERA's torso-center pivot fixed in place")
        return
    if display_rig.global_position.distance_to(before_world_origin) < 0.001:
        _fail("root must orbit the center pivot instead of rotating around its feet")
        return
    nexus.call("_input", _touch(cross, false, 2))
    if int(nexus.get("customize_touch_id")) != -1:
        _fail("finger release outside body preview did not end capture")
        return
    if absf(float(nexus.get("customize_preview_pitch"))) > deg_to_rad(55.0):
        _fail("body pitch should be bounded")
        return

    var left: InputEventMouseButton = InputEventMouseButton.new()
    left.button_index = MOUSE_BUTTON_LEFT
    left.pressed = true
    left.position = origin
    nexus.call("_input", left)
    if not bool(nexus.get("customize_mouse_drag")):
        _fail("mouse drag was not captured on the body")
        return
    var mouse_motion: InputEventMouseMotion = InputEventMouseMotion.new()
    mouse_motion.position = cross
    mouse_motion.relative = cross - origin
    var yaw2: float = float(nexus.get("customize_preview_yaw"))
    nexus.call("_input", mouse_motion)
    if is_equal_approx(yaw2, float(nexus.get("customize_preview_yaw"))):
        _fail("mouse rotation stopped across a different UI rectangle")
        return
    if (nexus.get("customize_preview_position") as Vector3).distance_to(
            before_position) > 0.000001 or (
            absf(float(nexus.get("customize_preview_scale")) - before_scale) > 0.000001) or (
            display_rig.to_global(pivot_local).distance_to(before_world_pivot) > 0.0001):
        _fail("mouse rotation must keep the torso pivot, anchor and scale fixed")
        return
    left.pressed = false
    left.position = cross
    nexus.call("_input", left)
    if bool(nexus.get("customize_mouse_drag")):
        _fail("mouse release outside body did not end capture")
        return
    print("NEXUS_DRAG_CAPTURE_RUNTIME_PASS")
    quit(0)
