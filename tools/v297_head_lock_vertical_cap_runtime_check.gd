extends SceneTree
## v297: verify an overhead-only sightline can lock the low head.
## The additional box affects AUTO only, not the visible mesh or attack AABB.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V297_HEAD_LOCK_VERTICAL_CAP_FAILED: " + reason)
    quit(1)


func _place_along(camera: Camera3D, center: Vector3, point: Vector3) -> void:
    camera.global_position = center + (point - center) * 5.0
    camera.look_at(center, Vector3.UP)


func _pick(parts: Node3D, camera: Camera3D, center: Vector3) -> String:
    return str(parts.call("select_camera_center_line_part", camera, center))


func _touches_real_head_mesh(pivot: Node3D,
        origin: Vector3, center: Vector3) -> bool:
    for child in pivot.get_children():
        if not child is MeshInstance3D:
            continue
        var mesh_node: MeshInstance3D = child as MeshInstance3D
        if not mesh_node.visible or not mesh_node.mesh is BoxMesh:
            continue
        var size: Vector3 = (mesh_node.mesh as BoxMesh).size
        var contact: Variant = AABB(-size * 0.5, size).intersects_segment(
            mesh_node.to_local(origin), mesh_node.to_local(center))
        if contact != null:
            return true
    return false


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("missing combat scene")
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
        _fail("combat nodes unavailable")
        return
    var all_parts: Dictionary = parts.get("parts")
    var head: Dictionary = all_parts["head"]
    var pivot: Node3D = head["node"]
    var dimensions: Vector3 = head["size"]
    var body_center: Vector3 = target.global_position
    var original_box: AABB = parts.call("get_part_aabb", "head")
    var original_aim: Vector3 = parts.call("get_part_aim_world", "head")

    # Pass 0.6 m above the original head bounds. This ray must NOT hit
    # an authored BoxMesh; selection therefore comes from the virtual cap.
    var overhead_point: Vector3 = pivot.to_global(Vector3(
        0.0, dimensions.y * 0.5 + 0.6, 0.0))
    _place_along(camera, body_center, overhead_point)
    if _touches_real_head_mesh(pivot,camera.global_position,body_center):
        _fail("overhead test ray accidentally intersected visible head mesh")
        return
    if _pick(parts,camera,body_center) != "head":
        _fail("AUTO did not select low head through its virtual upper cap")
        return
    if not bool(parts.call("camera_center_line_hits_part",
            camera,body_center,"head")):
        _fail("existing-lock hysteresis path cannot recognize upper cap")
        return

    # The virtual volume has an exact upper limit; no infinite-height aiming.
    var too_high: Vector3 = pivot.to_global(Vector3(
        0.0, dimensions.y * 0.5 + 2.2, 0.0))
    _place_along(camera,body_center,too_high)
    if _pick(parts,camera,body_center) != "":
        _fail("far above the one-meter cap should select BODY")
        return

    # The original attack AABB, marker world aim and part model are unchanged.
    var still_box: AABB = parts.call("get_part_aabb", "head")
    if still_box.size != original_box.size or still_box.position != original_box.position:
        _fail("lock cap modified combat hit volume")
        return
    var still_aim: Vector3 = parts.call("get_part_aim_world", "head")
    if still_aim.distance_squared_to(original_aim) > 0.000001:
        _fail("lock cap moved the HUD/attack aim")
        return

    # Rotated boss should keep its head-only cap in the correct local frame.
    target.rotation.y = PI * 0.5
    body_center = target.global_position
    overhead_point = pivot.to_global(Vector3(
        0.0, dimensions.y * 0.5 + 0.6, 0.0))
    _place_along(camera, body_center, overhead_point)
    if _pick(parts,camera,body_center) != "head":
        _fail("head cap did not follow boss rotation")
        return
    target.rotation.y = 0.0
    body_center = target.global_position

    # v319: the same head geometry is attackable after its break.
    overhead_point = pivot.to_global(Vector3(
        0.0, dimensions.y * 0.5 + 0.6, 0.0))
    _place_along(camera,body_center,overhead_point)
    head["broken"] = true
    if _pick(parts,camera,body_center) != "head":
        _fail("broken overhead head lost its retained lock volume")
        return
    head["broken"] = false

    # Other parts are still selected by their actual visible metal only.
    for leg_id in ["leg_fl","leg_fr","leg_rl","leg_rr"]:
        var leg_aim: Vector3 = parts.call("get_part_aim_world",leg_id)
        _place_along(camera,body_center,leg_aim)
        if _pick(parts,camera,body_center) != leg_id:
            _fail("unchanged leg AUTO lock regressed: " + leg_id)
            return

    # Integrated AUTO acquires the cap; it also drops it immediately if
    # the camera line no longer intersects, respecting BODY fallback.
    _place_along(camera,body_center,overhead_point)
    game.set("auto_lock_enabled", true)
    game.set("manual_part_lock_active", false)
    game.set("auto_lock_initialized", false)
    game.set("locked_target_part_id", "")
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("integrated AUTO did not lock head via virtual cap")
        return
    camera.global_position = body_center + Vector3(0.0, 0.0, -12.0)
    camera.look_at(body_center,Vector3.UP)
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part",0.016,false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("HEAD did not switch to BODY instantly after leaving cap")
        return

    print("GODOT_V297_HEAD_LOCK_VERTICAL_CAP_PASS")
    quit(0)
