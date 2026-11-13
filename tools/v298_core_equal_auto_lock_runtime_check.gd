extends SceneTree
## v298: BODY must be a scored candidate, not the failure fallback.
func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V298_CORE_EQUAL_AUTO_LOCK_FAILED: " + why)
    quit(1)


func _place(camera: Camera3D, center: Vector3, offset: Vector3) -> void:
    camera.global_position = center + offset
    camera.look_at(center, Vector3.UP)


func _select(parts: Node3D, camera: Camera3D, center: Vector3) -> String:
    return str(parts.call("select_camera_center_line_part",camera,center))


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("missing combat scene")
        return
    var game: Node3D = scene.instantiate()
    # Historic geometry test: SERA is positioned at the synthetic ray origin.
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var camera: Camera3D = game.get("camera")
    var target: Node3D = game.get("target")
    var parts: Node3D = game.get("target_parts")
    if camera == null or target == null or parts == null:
        _fail("combat nodes unavailable")
        return
    var center: Vector3 = target.global_position
    var mesh_node: MeshInstance3D = parts.get_parent() as MeshInstance3D
    if mesh_node == null or not mesh_node.mesh is BoxMesh:
        _fail("authoritative core BoxMesh unavailable")
        return
    var body_mesh: BoxMesh = mesh_node.mesh as BoxMesh
    var original_size: Vector3 = body_mesh.size

    # Looking from rear along the BODY centerline must produce a measurable
    # real core intersection (not just an empty-part-ID fallback).
    _place(camera,center,Vector3(0.0,0.0,-12.0))
    if _select(parts,camera,center) != "":
        _fail("rear core centerline should select BODY")
        return
    if not bool(parts.call("camera_center_line_hits_part",camera,center,"")):
        _fail("BODY was selected without a real mesh intersection")
        return
    var body_distance: float = float(parts.call("_camera_center_line_body_distance",
        camera.global_position,center))
    if body_distance == INF:
        _fail("BODY segment intersection had no distance")
        return

    # A genuine HEAD hit nearer the camera wins, not BODY by default.
    _place(camera,center,Vector3(0.0,-2.0,10.0))
    var head_distance: float = float(parts.call("_camera_center_line_part_distance",
        camera.global_position,center,"head"))
    body_distance = float(parts.call("_camera_center_line_body_distance",
        camera.global_position,center))
    if head_distance == INF or body_distance == INF or head_distance >= body_distance:
        _fail("setup: expected visible HEAD before the real BODY")
        return
    if _select(parts,camera,center) != "head":
        _fail("HEAD intersection lost against farther BODY")
        return

    # Deliberately grow the *visible core mesh* temporarily toward camera.
    # Both BODY and HEAD still intersect. BODY must now win because its
    # actual mesh surface is nearest. Restore mesh dimensions immediately.
    body_mesh.size = Vector3(original_size.x,original_size.y,12.0)
    body_distance = float(parts.call("_camera_center_line_body_distance",
        camera.global_position,center))
    head_distance = float(parts.call("_camera_center_line_part_distance",
        camera.global_position,center,"head"))
    if body_distance >= head_distance:
        body_mesh.size = original_size
        _fail("setup: enlarged BODY did not reach in front of HEAD")
        return
    if _select(parts,camera,center) != "":
        body_mesh.size = original_size
        _fail("BODY was not selected despite the nearest physical mesh hit")
        return
    body_mesh.size = original_size
    if _select(parts,camera,center) != "head":
        _fail("original BODY geometry was not restored")
        return

    # BODY->HEAD is now a normal intersecting-target change and must obey
    # the exact same 0.22s stable confirmation as limb-to-limb changes.
    _place(camera,center,Vector3(0.0,0.0,-12.0))
    game.set("auto_lock_enabled",true)
    game.set("manual_part_lock_active",false)
    game.set("auto_lock_initialized",false)
    game.set("locked_target_part_id","")
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if not bool(game.get("auto_lock_initialized")) or str(game.get(
            "locked_target_part_id")) != "":
        _fail("initial BODY was not acquired as a real lock")
        return
    _place(camera,center,Vector3(0.0,-2.0,10.0))
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "":
        _fail("BODY->HEAD skipped uniform switch confirmation")
        return
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.10,false)
    if str(game.get("locked_target_part_id")) != "":
        _fail("BODY->HEAD changed during early hysteresis")
        return
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.13,false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("BODY->HEAD did not switch after sustained better intersection")
        return

    # The active HEAD still intersects, but expanding the core makes
    # BODY the closer candidate; do not skip the shared hysteresis.
    body_mesh.size = Vector3(original_size.x,original_size.y,12.0)
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "head":
        body_mesh.size = original_size
        _fail("HEAD->BODY bypassed stable overlap selection")
        return
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.23,false)
    if str(game.get("locked_target_part_id")) != "":
        body_mesh.size = original_size
        _fail("HEAD->BODY did not confirm the nearer BODY")
        return
    body_mesh.size = original_size

    # If HEAD loses pair intersection, require a stable 0.22s replacement.
    game.set("locked_target_part_id","head")
    _place(camera,center,Vector3(0.0,0.0,-12.0))
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("transient off-segment HEAD lost stable-lock hold")
        return
    game.call("_acquire_stable_camera_part",0.23,false)
    if str(game.get("locked_target_part_id")) != "":
        _fail("HEAD did not release for stable paired-ray BODY")
        return

    # Do not affect weapon hitboxes or part lock/followup compatibility.
    if not game.has_method("_combo_lock_retention_active") or not game.has_method(
            "_switch_lock_screen_direction"):
        _fail("existing combo/manual lock methods absent")
        return
    print("GODOT_V298_CORE_EQUAL_AUTO_LOCK_PASS")
    quit(0)
