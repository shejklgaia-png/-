extends SceneTree
## v377: shared 30cm depth tolerance, including mesh rotation/scale.
## Retain the existing 70%-standup HEAD gate and <=30% knee folding.
const PARTS = preload("res://scripts/bittaran_parts.gd")
const BOSS = preload("res://scripts/bittaran_battle.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V377_BITTARAN_DEPTH_30CM_FAIL: " + message)
    quit(1)

func _box() -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    m.mesh = cube
    root.add_child(m)
    return m

func _depth_is(parts: Node3D, a: MeshInstance3D,
        b: MeshInstance3D, offset: Vector3,
        expected: float, label: String) -> bool:
    b.position = offset
    var got: float = float(parts.call(
        "_oriented_mesh_penetration_depth", a, b))
    if absf(got - expected) > 0.001:
        _fail(label + " depth " + str(got) + " expected " + str(expected))
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var parts: Node3D = battle.get("target_parts")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if parts == null or ik == null:
        _fail("boss collision parts or IK missing")
        return
    if absf(PARTS.HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.30) > 0.00001 \
            or absf(BOSS.HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.30) > 0.00001 \
            or absf(IK.HEAD_KNEE_ALLOWED_PENETRATION_METERS - 0.30) > 0.00001:
        _fail("knee and HEAD do not share exactly 30cm")
        return
    var a: MeshInstance3D = _box()
    var b: MeshInstance3D = _box()
    for sample in [
            [1.20, 0.0], [0.80, 0.20], [0.70, 0.30],
            [0.69, 0.31], [0.50, 0.50]]:
        if not _depth_is(parts, a, b,
                Vector3(float(sample[0]), 0.0, 0.0),
                float(sample[1]), "unrotated pair"):
            return
    # Orientation-aware SAT: world-axis AABB overlap is NOT allowed
    # to determine the depth of two rotated parts.
    a.rotation.y = deg_to_rad(35.0)
    b.rotation.y = a.rotation.y
    if not _depth_is(parts, a, b,
            a.global_basis.x.normalized() * 0.70,
            0.30, "rotated pair"):
        return
    # Even at boss scale 2, the threshold stays 0.30 WORLD metres.
    a.rotation.y = 0.0
    b.rotation.y = 0.0
    a.scale = Vector3.ONE * 2.0
    if not _depth_is(parts, a, b,
            Vector3(1.20, 0.0, 0.0), 0.30, "2x scale"):
        return
    a.queue_free()
    b.queue_free()
    var head: Node3D = battle.get("bittaran_head")
    if head == null:
        _fail("actual head bone missing")
        return
    var original: Quaternion = head.quaternion
    for yaw in [-0.6, -0.3, 0.0, 0.3, 0.6]:
        head.quaternion = (original *
            Quaternion(Vector3.UP, float(yaw))).normalized()
        var measured: Dictionary = parts.call(
            "get_head_leg_penetration_depths")
        if measured.size() != 4:
            _fail("missing one of four articulated leg depths")
            return
        for depth in measured.values():
            if not is_finite(float(depth)) or float(depth) < 0.0:
                _fail("invalid head/leg mesh penetration depth")
                return
    head.quaternion = original
    # At zero overlap the head moves freely; at 30cm an inward
    # proposed turn stops, and an outward turn is always allowed.
    battle.set("head_collision_filtered_depth", 0.0)
    battle.set("head_collision_blocked", false)
    var free: float = float(battle.call(
        "_head_collision_motion_scale", 0.0, 0.0, DT))
    if absf(free - 1.0) > 0.00001:
        _fail("head slowed without any overlap")
        return
    var stop: float = float(battle.call(
        "_head_collision_motion_scale", 0.30, 0.32, DT))
    if stop != 0.0:
        _fail("head failed to stop at 30cm penetration")
        return
    var reverse: float = float(battle.call(
        "_head_collision_motion_scale", 0.34, 0.30, DT))
    if reverse < 0.39 or reverse > 1.00001:
        _fail("head cannot smoothly escape from >30cm penetration")
        return
    if absf(BOSS.HEAD_TRACK_STANDUP_START_FRACTION - 0.70) > 0.00001 \
            or absf(IK.HEAD_KNEE_MAX_BEND - 0.30) > 0.00001 \
            or absf(IK.STEP_DURATION_SECONDS - 0.58) > 0.00001 \
            or absf(IK.SINGLE_LEG_RISE_SECONDS - 1.0) > 0.00001 \
            or absf(IK.FOUR_LEG_RISE_SECONDS - 1.3) > 0.00001:
        _fail("head/leg movement behavior changed unexpectedly")
        return
    print("GODOT_V377_BITTARAN_DEPTH_30CM_PASS: 30cm world-space "
        + "oriented mesh depth under rotation and scale, common HEAD/IK "
        + "threshold, hard stop at >=30cm, free escape direction")
    quit(0)
