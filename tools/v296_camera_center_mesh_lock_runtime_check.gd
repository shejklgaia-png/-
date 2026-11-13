extends SceneTree
## v296: tests actual BoxMesh intersection rather than angular sectors or
## coarse part bounding boxes. AUTO changes never leave a stale off-line limb.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V296_CAMERA_CENTER_MESH_LOCK_FAILED: " + reason)
    quit(1)


func _point_camera(camera: Camera3D, center: Vector3, offset: Vector3) -> void:
    camera.global_position = center + offset
    camera.look_at(center, Vector3.UP)


func _pick(parts: Node3D, camera: Camera3D, center: Vector3) -> String:
    return str(parts.call("select_camera_center_line_part", camera, center))


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("combat scene not found")
        return
    var game: Node3D = packed.instantiate()
    # Historic geometry test: place SERA at the sampled synthetic ray origin.
    # The camera may still aim the test ray, but AUTO reads only SERA.
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var camera: Camera3D = game.get("camera")
    var target: Node3D = game.get("target")
    var parts: Node3D = game.get("target_parts")
    if camera == null or target == null or parts == null:
        _fail("missing camera, boss or part meshes")
        return
    var center: Vector3 = target.global_position

    # The core-center line from the rear runs between the legs.
    _point_camera(camera, center, Vector3(0.0,0.0,-12.0))
    if _pick(parts,camera,center) != "":
        _fail("empty rear centerline selected a limb instead of BODY")
        return

    # The frontal, slightly low line physically hits the head's meshes.
    _point_camera(camera, center, Vector3(0.0,-2.0,10.0))
    if _pick(parts,camera,center) != "head":
        _fail("head mesh on segment was not selected")
        return

    # A leg's coarse bounding box must NOT count in the absence of metal.
    # Temporarily REMOVE HEAD from this isolated fixture: broken HEAD stays
    # attackable in v319, so toggling its broken flag cannot hide it.
    var parts_for_gap: Dictionary = parts.get("parts")
    var gap_head: Dictionary = parts_for_gap["head"]
    parts_for_gap.erase("head")
    _point_camera(camera, center, Vector3(-3.0,0.0,10.0))
    var gap_pick: String = _pick(parts,camera,center)
    parts_for_gap["head"] = gap_head
    if gap_pick != "":
        _fail("empty space inside leg bounding box selected a limb")
        return

    # Aim through each real leg's authored metal tip, not just its pivot.
    for id in ["leg_fl","leg_fr","leg_rl","leg_rr"]:
        var aim: Vector3 = parts.call("get_part_aim_world",id)
        _point_camera(camera, center, (aim-center)*5.0)
        if _pick(parts,camera,center) != id:
            _fail("mesh line did not select " + id)
            return

    # World-space target rotation must not break local mesh intersections.
    target.rotation.y = PI * 0.5
    center = target.global_position
    var rotated_head: Vector3 = parts.call("get_part_aim_world","head")
    _point_camera(camera,center,(rotated_head-center)*5.0)
    if _pick(parts,camera,center) != "head":
        _fail("rotated head local box was not intersected")
        return
    target.rotation.y = 0.0
    center = target.global_position

    # Broken geometry is not lockable even though its mesh remains visible.
    _point_camera(camera, center, Vector3(0.0,-2.0,10.0))
    var dictionary: Dictionary = parts.get("parts")
    var head: Dictionary = dictionary["head"]
    head["broken"] = true
    if _pick(parts,camera,center) != "":
        _fail("broken head was still eligible")
        return
    head["broken"] = false

    game.set("auto_lock_enabled",true)
    game.set("manual_part_lock_active",false)
    game.set("auto_lock_initialized",false)
    game.set("locked_target_part_id","")
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("BODY-to-HEAD acquisition was not immediate")
        return

    _point_camera(camera,center,Vector3(0.0,0.0,-12.0))
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "":
        _fail("BODY did not take over immediately after dual-ray loss")
        return
    if not bool(game.get("auto_lock_initialized")):
        _fail("BODY lock was mistaken for uninitialized selection")
        return

    # v305: BODY is a genuine intersecting candidate, but switching
    # from BODY to HEAD now happens in the first dual-ray sample.
    _point_camera(camera,center,Vector3(0.0,-2.0,10.0))
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("BODY->HEAD did not switch on the first paired-ray hit")
        return

    # Existing MANUAL and attack retention are separate from AUTO sampling.
    if not game.has_method("_combo_lock_retention_active") or not game.has_method(
            "_switch_lock_screen_direction"):
        _fail("attack lock retention or manual cycling was lost")
        return
    print("GODOT_V296_CAMERA_CENTER_MESH_LOCK_PASS")
    quit(0)
