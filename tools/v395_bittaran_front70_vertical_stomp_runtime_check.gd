extends SceneTree
## v395: FRONT 70% of the true HEAD rectangular silhouette is the only
## hit/clearance surface; each of four STOMPs keeps its actual longest
## toe axis perpendicular to the floor from raised windup to impact.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const PARTS = preload("res://scripts/bittaran_parts.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V395_FRONT70_VERTICAL_STOMP_FAIL: " + reason)
    quit(1)


func _check_head(battle: Node3D) -> bool:
    var parts: Node3D = battle.get("target_parts")
    var head: Node3D = battle.get("bittaran_head")
    var box: AABB = parts.call("get_head_front_local_box")
    if absf(PARTS.HEAD_FRONT_COLLISION_FRACTION - 0.70) > 0.00001             or not box.has_volume():
        _fail("HEAD rectangular front70 collider missing")
        return false
    var mesh: MeshInstance3D = head.find_child(
        "head_mesh", true, false) as MeshInstance3D
    if mesh == null:
        _fail("cannot identify authored head silhouette mesh")
        return false
    var points: Array[Vector3] = []
    var source: AABB = mesh.mesh.get_aabb()
    for corner in range(8):
        points.append(head.to_local(
            mesh.to_global(source.get_endpoint(corner))))
    var minz: float = INF
    var maxz: float = -INF
    for point in points:
        minz = minf(minz, point.z)
        maxz = maxf(maxz, point.z)
    if absf(box.position.z - minz) > 0.001 or absf(
            box.end.z - (minz + (maxz - minz) * 0.70)) > 0.001:
        _fail("HEAD coverage is not measured tip-first 70%")
        return false
    var center: Vector3 = box.get_center()
    var back_only: float = lerpf(box.end.z, maxz, 0.55)
    var excluded: Variant = parts.call(
        "get_head_mesh_blade_contact",
        head.to_global(Vector3(center.x - 0.05, center.y, back_only)),
        head.to_global(Vector3(center.x + 0.05, center.y, back_only)),
        0.0)
    if excluded != null:
        _fail("rear 30% still takes HEAD damage")
        return false
    var hit: Variant = parts.call("get_head_mesh_blade_contact",
        head.to_global(Vector3(center.x, center.y,
            box.position.z - 0.2)),
        head.to_global(Vector3(center.x, center.y,
            box.end.z - 0.1)), 0.0)
    if hit == null:
        _fail("front 70% HEAD misses sword intersection")
        return false
    var normal: Quaternion = head.quaternion
    for yaw in [-0.60, 0.0, 0.60]:
        head.quaternion = (normal * Quaternion(
            Vector3.UP, yaw)).normalized()
        var visual: AABB = parts.call("get_head_swing_aabb")
        var bounds: AABB = parts.call("get_part_aabb", "head")
        if visual.position.distance_to(bounds.position) > 0.001                 or visual.size.distance_to(bounds.size) > 0.001:
            _fail("HEAD rotation changed hit and clearance volumes differently")
            return false
        var depths: Dictionary = parts.call(
            "get_head_leg_penetration_depths")
        if depths.size() != 4:
            _fail("HEAD front70 does not service all four leg-avoiders")
            return false
    head.quaternion = normal
    return true


func _check_stomp(battle: Node3D, id: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var index: int = IK.LEG_PART_IDS.find(id)
    var foot: Node3D = ik.get("legs")[index]["foot"]
    if not bool(brain.call("force_start", id, "stomp")):
        _fail("could not force STOMP " + id)
        return false
    var windup_count: int = 0
    var strike_count: int = 0
    var hit_count: int = 0
    var hold_count: int = 0
    for tick in range(225):
        # Stand near the toe for the first half of anticipation, then
        # move beyond hit detection so a KO cannot truncate this test.
        player.global_position = boss.global_position + Vector3(
            1.0 if tick < 70 else 20.0, 0.0, 5.5)
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            break
        battle.call("_finalize_target_pose", DT)
        var t: float = float(frame.get("time", 0.0))
        var windup: float = float(frame.get("windup", 1.25))
        var strike: float = float(frame.get("strike", 0.25))
        var hold: float = float(frame.get("hold", 1.5))
        var long_axis: Vector3 = (
            foot.global_basis.y.normalized())
        if t >= 0.24 and t <= windup + strike + hold - 0.025:
            if long_axis.dot(Vector3.UP) < 0.985:
                _fail(id + " STOMP long toe tilted horizontal at "
                    + str([t, long_axis]))
                return false
            if t < windup:
                windup_count += 1
            elif t < windup + strike:
                strike_count += 1
            else:
                hold_count += 1
        if bool(frame.get("impact", false)):
            hit_count += 1
            var bottom: float = float(ik.call(
                "_foot_mesh_lowest_y", foot))
            if absf(bottom - IK.FLOOR_Y) > 0.075:
                _fail(id + " vertical toe failed ground impact "
                    + str(bottom))
                return false
    if windup_count < 35 or strike_count < 10             or hold_count < 70 or hit_count != 1:
        _fail(id + " incomplete vertical windup/strike/hold "
            + str([windup_count, strike_count, hold_count, hit_count]))
        return false
    return true


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _check_head(battle):
        return
    for id in BRAIN.LEG_IDS:
        if not _check_stomp(battle, id):
            return
    print("GODOT_V395_FRONT70_VERTICAL_STOMP_PASS: front 70% of "
        + "HEAD is the only blade/body/leg-clearance volume and "
        + "all four STOMP toes stay upright in windup/strike/hold")
    quit(0)
