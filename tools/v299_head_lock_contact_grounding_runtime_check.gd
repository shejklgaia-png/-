extends SceneTree
## v299: real boss geometry lock selection and true foot-vertex height,
## with contact-only RUN correction and non-WAIT/RUN isolation.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V299_HEAD_LOCK_CONTACT_GROUNDING_FAILED: " + reason)
    quit(1)


func _look_at_center(camera: Camera3D, center: Vector3,
        offset: Vector3) -> void:
    camera.global_position = center + offset
    camera.look_at(center, Vector3.UP)


func _get_lock(parts: Node3D, camera: Camera3D, center: Vector3) -> String:
    return str(parts.call("select_camera_center_line_part", camera, center))


func _check_grounded(rig: Node3D, eq: RefCounted, floor_y: float,
        label: String) -> bool:
    var heights: Dictionary = eq.call("get_active_foot_heights")
    if not heights.has("L") or not heights.has("R"):
        _fail(label + ": missing actual footwear mesh vertices")
        return false
    var lowest: float = minf(float(heights["L"]), float(heights["R"]))
    var sole_y: float = rig.to_global(Vector3(0.0,lowest,0.0)).y
    if absf(sole_y - floor_y) > 0.002:
        _fail("%s: lowest sole Y=%.4f instead of floor Y=%.4f" % [
            label,sole_y,floor_y])
        return false
    return true


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("combat scene not found")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var camera: Camera3D = game.get("camera")
    var target: Node3D = game.get("target")
    var parts: Node3D = game.get("target_parts")
    var rig: Node3D = game.get("rig")
    var player: Node3D = game.get("player")
    if camera == null or target == null or parts == null or rig == null or player == null:
        _fail("required runtime nodes unavailable")
        return
    var eq: RefCounted = rig.get("equipment_handler")
    if eq == null or not bool(rig.get("loading_ok")):
        _fail("animated equipment missing")
        return

    var center: Vector3 = target.global_position
    # Regression: a level FRONT camera ray at Y=body-center used to pass
    # above the actual low head but below v297's upper-only cap. The BODY
    # would win despite HEAD being in front of it.
    _look_at_center(camera,center,Vector3(0.0,0.0,7.0))
    var body_d: float = float(parts.call("_camera_center_line_body_distance",
        camera.global_position,center))
    var head_d: float = float(parts.call("_camera_center_line_part_distance",
        camera.global_position,center,"head"))
    if head_d == INF or body_d == INF or head_d >= body_d:
        _fail("level frontal ray is still lost to BODY")
        return
    if _get_lock(parts,camera,center) != "head":
        _fail("HEAD cannot be selected from a level frontal view")
        return
    _look_at_center(camera,center,Vector3(0.0,0.45,8.0))
    if _get_lock(parts,camera,center) != "head":
        _fail("HEAD was lost under a normal elevated view")
        return
    _look_at_center(camera,center,Vector3(0.0,0.0,-9.0))
    if _get_lock(parts,camera,center) != "":
        _fail("head's forward virtual cap leaked into the rear BODY view")
        return

    # BODY remains a genuine nearest-intersection candidate.
    var core_mesh: MeshInstance3D = parts.get_parent() as MeshInstance3D
    if core_mesh == null or not core_mesh.mesh is BoxMesh:
        _fail("BODY authoring mesh missing")
        return
    var core_size: Vector3 = (core_mesh.mesh as BoxMesh).size
    _look_at_center(camera,center,Vector3(0.0,0.0,8.0))
    (core_mesh.mesh as BoxMesh).size = Vector3(
        core_size.x,core_size.y,12.0)
    if _get_lock(parts,camera,center) != "":
        (core_mesh.mesh as BoxMesh).size = core_size
        _fail("HEAD was given priority over a genuinely nearer BODY surface")
        return
    (core_mesh.mesh as BoxMesh).size = core_size

    # WAIT: sample actual lowest triangles at final authored pose.
    var floor_y: float = -0.0335
    rig.call("finish_attack",false,false)
    rig.call("_switch_clip","Wait_motion",0.0)
    rig.call("_process",0.016)
    if not _check_grounded(rig,eq,floor_y,"WAIT A"):
        return

    # RUN: no per-frame grounding, but one actual toe-down signal must
    # sample the lower of both feet and move only the visual rig root.
    rig.call("_switch_clip","run_front_original",0.0)
    # v319: finish the stand->RUN accent before sampling normal foot support.
    rig.call("_process",0.11)
    rig.call("_process",0.04)
    var run_base: float = rig.position.y
    var heights: Dictionary = eq.call("get_active_foot_heights")
    var side: String = "L" if float(heights["L"]) <= float(heights["R"]) else "R"
    rig.set("foot_contact_initialized",true)
    var lifted: Dictionary = rig.get("foot_lifted")
    lifted["L"] = side == "L"
    lifted["R"] = side == "R"
    rig.set("foot_contact_elapsed",1.0)
    rig.call("_update_foot_contacts",0.016)
    if not _check_grounded(rig,eq,floor_y,"RUN A footfall"):
        return
    var held_y: float = rig.position.y
    rig.set("foot_contact_initialized",false)
    rig.call("_process",0.016)
    if absf(rig.position.y - held_y) > 0.002:
        _fail("RUN contact correction was lost on the next non-contact frame")
        return

    # STRIKE restores static baseline and clears RUN-only support state.
    rig.call("start_strike","melee1")
    rig.call("_process",0.016)
    var baseline_y: float = float(eq.get("rig_original_y")) + float(
        eq.call("get_grounding_height_offset"))
    if absf(rig.position.y - baseline_y) > 0.002:
        _fail("combat inherited RUN/WAIT dynamic height correction")
        return
    if not is_nan(float(eq.get("run_contact_visual_y"))):
        _fail("combat did not clear the RUN-only cached height")
        return

    # BIRD C must use exactly the same WAIT/footfall contract; no
    # per-frame smooth tracking in RUN or attack states.
    rig.call("finish_attack",false,false)
    if not bool(eq.call("select_part","legs","C",false)):
        _fail("bird lower body C was not available")
        return
    rig.call("_switch_clip","Wait_motion",0.0)
    rig.call("_process",0.016)
    if not _check_grounded(rig,eq,floor_y,"WAIT bird C"):
        return
    rig.call("_switch_clip","run_front_original",0.0)
    rig.call("_process",0.04)
    var bird_heights: Dictionary = eq.call("get_active_foot_heights")
    var bird_side: String = "L" if float(bird_heights["L"]) <= float(bird_heights["R"]) else "R"
    rig.set("foot_contact_initialized",true)
    var bird_lifted: Dictionary = rig.get("foot_lifted")
    bird_lifted["L"] = bird_side == "L"
    bird_lifted["R"] = bird_side == "R"
    rig.set("foot_contact_elapsed",1.0)
    rig.call("_update_foot_contacts",0.016)
    if not _check_grounded(rig,eq,floor_y,"RUN bird C footfall"):
        return

    if absf(run_base) > 1000.0:
        _fail("impossible RUN baseline")
        return
    print("GODOT_V299_HEAD_LOCK_CONTACT_GROUNDING_PASS")
    quit(0)
