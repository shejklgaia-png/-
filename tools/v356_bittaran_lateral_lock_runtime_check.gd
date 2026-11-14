extends SceneTree
## v356: standing Bittaran chooses ONE shin, even when two oversized lock
## volumes intersect the same horizontal beams directly ahead of the boss.
## Front/rear midpoint reciprocity remains covered by v353/v354.
const DT: float = 1.0 / 60.0
const NOISE: Array[float] = [0.0, 0.13, -0.20, 0.24, -0.08, 0.19, -0.23, 0.0]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V356_BITTARAN_LATERAL_FAIL: " + message)
    quit(1)

func _pair_center(parts: Node3D, ids: Array[String]) -> Vector3:
    return ((parts.call("get_shin_selection_box", ids[0]) as AABB).get_center()
        + (parts.call("get_shin_selection_box", ids[1]) as AABB).get_center()) * 0.5

func _lateral(parts: Node3D, ids: Array[String]) -> Vector3:
    var side: Vector3 = (
        (parts.call("get_shin_selection_box", ids[0]) as AABB).get_center()
        - (parts.call("get_shin_selection_box", ids[1]) as AABB).get_center())
    side.y = 0.0
    return side.normalized()

func _actor_origin(parts: Node3D, ids: Array[String], outward: Vector3,
        offset: float) -> Vector3:
    var point: Vector3 = _pair_center(parts, ids) + outward * 12.0
    point += _lateral(parts, ids) * offset
    point.y = 0.0
    return point

func _check_pair(battle: Node3D, ids: Array[String],
        outward: Vector3, label: String) -> bool:
    var parts: Node3D = battle.get("target_parts")
    var player: Node3D = battle.get("player")
    battle.set("locked_target_part_id", "")
    player.global_position = _actor_origin(parts, ids, outward, 0.0)
    battle.call("_acquire_stable_camera_part", DT, false)
    var initial: String = str(battle.get("locked_target_part_id"))
    if not ids.has(initial):
        _fail(label + ": initial lock not on expected pair: " + initial)
        return false
    var new_target: String = ids[1] if initial == ids[0] else ids[0]
    var opposite_sign: float = -1.0 if initial == ids[0] else 1.0
    # The lock must NOT chase tiny ankle/IK/ray-entry differences each tick.
    for n in range(120):
        var offset: float = NOISE[n % NOISE.size()]
        player.global_position = _actor_origin(parts, ids, outward, offset)
        battle.call("_acquire_stable_camera_part", DT, false)
        if str(battle.get("locked_target_part_id")) != initial:
            _fail(label + ": lock jitter near center at frame " + str(n))
            return false
    # An intentional side traversal still switches in the SAME acquisition,
    # with no 0.22s timer and no gap to an unselected BODY lock.
    player.global_position = _actor_origin(parts, ids, outward, 2.5 * opposite_sign)
    battle.call("_acquire_stable_camera_part", DT, false)
    if str(battle.get("locked_target_part_id")) != new_target:
        _fail(label + ": deliberate left/right crossing did not switch")
        return false
    # Returning to center should not immediately flip back.
    player.global_position = _actor_origin(parts, ids, outward, 0.0)
    battle.call("_acquire_stable_camera_part", DT, false)
    if str(battle.get("locked_target_part_id")) != new_target:
        _fail(label + ": hysteresis lost the newly selected leg")
        return false
    player.global_position = _actor_origin(parts, ids, outward, -2.5 * opposite_sign)
    battle.call("_acquire_stable_camera_part", DT, false)
    if str(battle.get("locked_target_part_id")) != initial:
        _fail(label + ": reciprocal lateral crossing did not switch")
        return false
    return true

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("battle scene unavailable")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    var parts: Node3D = battle.get("target_parts")
    var model: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if parts == null or model == null or ik == null:
        _fail("boss setup incomplete")
        return
    var centers: PackedVector3Array = parts.call("_current_front_rear_lock_mids")
    var front: Vector3 = centers[0] - centers[1]
    front.y = 0.0
    if front.length_squared() < 1.0:
        _fail("degenerate front/rear direction")
        return
    front = front.normalized()
    var forward: Array[String] = ["leg_fl", "leg_fr"]
    var rear: Array[String] = ["leg_rl", "leg_rr"]
    if not _check_pair(battle, forward, front, "front"):
        return
    if not _check_pair(battle, rear, -front, "rear"):
        return

    # Walking/turning changes the real shin lock volumes. Keep an acquired
    # leg when the player remains on its projected central axis.
    var player: Node3D = battle.get("player")
    battle.set("locked_target_part_id", "leg_fl")
    var target: Node3D = battle.get("target")
    for n in range(90):
        target.rotation.y += deg_to_rad(18.0) * DT
        model.call("set_motion", "Turn", DT)
        ik.call("advance_ik", DT, "Turn")
        parts.call("sync_bittaran_parts")
        centers = parts.call("_current_front_rear_lock_mids")
        front = centers[0] - centers[1]
        front.y = 0.0
        front = front.normalized()
        player.global_position = _actor_origin(
            parts, forward, front, NOISE[n % NOISE.size()])
        battle.call("_acquire_stable_camera_part", DT, false)
        if str(battle.get("locked_target_part_id")) != "leg_fl":
            _fail("IK motion caused front left/right lock flicker at frame " + str(n))
            return
    print("GODOT_V356_BITTARAN_LATERAL_PASS: one stable shin at front/rear center, "
        + "instant reciprocal side switching, 90 animated IK frames")
    quit(0)
