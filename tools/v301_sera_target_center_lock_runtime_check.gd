extends SceneTree
## v301: the same SERA position produces the same AUTO choice regardless
## of camera; repositioning SERA changes the chosen mesh. BODY competes
## equally and retains the 0.22s switch confirmation and broken handling.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V301_SERA_TARGET_LOCK_FAILED: " + reason)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("missing combat scene")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var camera: Camera3D = game.get("camera")
    var target: Node3D = game.get("target")
    var parts: Node3D = game.get("target_parts")
    if player == null or camera == null or target == null or parts == null:
        _fail("missing player, camera, boss or part meshes")
        return
    var center: Vector3 = target.global_position
    var front: Vector3 = Vector3(center.x,0.0,center.z + 9.0)
    var rear: Vector3 = Vector3(center.x,0.0,center.z - 9.0)
    player.global_position = front
    camera.global_position = center + Vector3(0.0,5.0,-12.0)
    camera.look_at(center,Vector3.UP)
    if str(parts.call("select_actor_center_line_part",front,center)) != "head":
        _fail("normal floor-level SERA cannot lock forward low HEAD")
        return
    var d_head: float = float(parts.call("_camera_center_line_part_distance",
        front,center,"head"))
    var d_body: float = float(parts.call("_camera_center_line_body_distance",
        front,center))
    if d_head == INF or d_body == INF or d_head >= d_body:
        _fail("visible HEAD did not beat BODY by nearest SERA intersection")
        return
    game.set("auto_lock_enabled",true)
    game.set("manual_part_lock_active",false)
    game.set("auto_lock_initialized",false)
    game.set("locked_target_part_id","")
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("AUTO still aims from the rear camera, not SERA")
        return

    # Rotate/move the camera freely without moving the player. Neither a
    # direct selector nor the integrated AUTO may react to the viewpoint.
    for offset in [Vector3(0.0,-2.0,12.0),Vector3(12.0,9.0,0.0),
            Vector3(-12.0,1.0,0.0),Vector3(0.0,4.0,-14.0)]:
        camera.global_position = center + offset
        camera.look_at(center,Vector3.UP)
        if str(parts.call("select_actor_center_line_part",
                player.global_position,center)) != "head":
            _fail("lock changed when only camera moved")
            return
        game.call("_acquire_stable_camera_part",0.30,false)
        if str(game.get("locked_target_part_id")) != "head":
            _fail("integrated AUTO still reacts to camera motion")
            return

    # Change SERA position while keeping the camera exactly unchanged.
    player.global_position = rear
    if str(parts.call("select_actor_center_line_part",
            player.global_position,center)) != "":
        _fail("rear SERA ray should hit BODY, not front HEAD")
        return
    if not bool(parts.call("actor_center_line_hits_part",
            player.global_position,center,"")):
        _fail("BODY should be a real mesh intersection, never a fallback")
        return
    game.call("_acquire_stable_camera_part",0.016,false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("off-segment HEAD was retained despite SERA moving behind boss")
        return

    # BODY and HEAD both intersect the front ray, so BODY->HEAD must
    # obey the same 0.22-second hysteresis as the old algorithm.
    player.global_position = front
    game.call("_acquire_stable_camera_part",0.016,false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("BODY->HEAD skipped confirmation")
        return
    game.call("_acquire_stable_camera_part",0.10,false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("BODY->HEAD confirmation finished prematurely")
        return
    game.call("_acquire_stable_camera_part",0.13,false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("sustained SERA-origin HEAD did not become active")
        return

    # Both HEAD and enlarged BODY remain intersectable. BODY wins only
    # when its actual mesh first contact is nearer to SERA.
    var core: MeshInstance3D = parts.get_parent() as MeshInstance3D
    if core == null or not core.mesh is BoxMesh:
        _fail("BODY mesh unavailable")
        return
    var core_box: BoxMesh = core.mesh as BoxMesh
    var original_size: Vector3 = core_box.size
    core_box.size = Vector3(original_size.x,original_size.y,12.0)
    if str(parts.call("select_actor_center_line_part",
            player.global_position,center)) != "":
        core_box.size = original_size
        _fail("head received artificial priority over nearer BODY")
        return
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "head":
        core_box.size = original_size
        _fail("HEAD->BODY overlap bypassed shared hysteresis")
        return
    game.call("_acquire_stable_camera_part",0.23,false)
    if not str(game.get("locked_target_part_id")).is_empty():
        core_box.size = original_size
        _fail("nearest BODY could not acquire after confirmation")
        return
    core_box.size = original_size

    # Broken HEAD is not eligible. No change to hitboxes, boss
    # rotation or left/right MANUAL button selection is required.
    var head: Dictionary = (parts.get("parts") as Dictionary)["head"]
    head["broken"] = true
    if str(parts.call("select_actor_center_line_part",front,center)) != "":
        _fail("broken HEAD remained selectable through virtual cap")
        return
    head["broken"] = false
    if not game.has_method("_combo_lock_retention_active") or not game.has_method(
            "_switch_lock_screen_direction"):
        _fail("manual or combo lock method missing")
        return
    print("GODOT_V301_SERA_TARGET_LOCK_PASS")
    quit(0)
