extends SceneTree
## v411 regression check, from the device report on v410:
## "rear-leg attacks twist the torso abnormally" and "the
## windup is not normal" (the twist forms during the windup).
## Root cause: v410 mirrored the SWEEP Body's ABSOLUTE pose
## across the rig planes. The boss's rest pose is not
## front-back symmetric, so leg_rl's Wait-relative tilt motion
## inflated to 48 degrees (leg_fl: 23) and stacked with the
## chest tracking yaw into a 94-degree in-scene torso rotation.
## v411 mirrors the Wait-relative MOTION (delta) instead,
## left-right only: leg_rl shares leg_fl's delta verbatim and
## leg_fr/leg_rr play its left-right reflection. (Reflecting
## the delta front-back as well inverted the crouch pitch,
## dropped the rear hip ~0.6m and snapped the strike entry's
## knee through the floor at -0.214m; see the rig comment.)
## Part 1 asserts the delta form at sampled clip times: equal
## magnitude on every leg, exact share/reflection per side.
## Part 2 asserts the in-scene torso rotation stays within
## 70 degrees of rest through whole SWEEP attacks in natural
## geometry (v410 leg_rl measured 94). Part 3 asserts the
## attacking limb's mesh never breaks the floor (the entry
## knee-snap regression).
const DT: float = 1.0 / 60.0
const LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const MIRROR_KEYS: Array[float] = [0.0, 0.125, 0.25, 0.36, 0.5,
    0.75, 1.0, 1.25, 1.5]
const MAX_MIRROR_ERROR: float = 0.0175
const MAX_MAGNITUDE_ERROR: float = 0.02
const MAX_TWIST_DEGREES: float = 70.0
const MIN_LEG_CLEARANCE: float = -0.02


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V411_BITTARAN_SWEEP_DELTA_MIRROR_FAIL: " + why)
    quit(1)


func _tick(battle: Node) -> void:
    battle.set("player_hp", 9999.0)
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)


func _leg_lowest_y(joint: Node3D) -> float:
    var lowest: float = INF
    for child in joint.get_children():
        if child is MeshInstance3D:
            var piece: MeshInstance3D = child as MeshInstance3D
            if piece.mesh == null:
                continue
            var box: AABB = piece.mesh.get_aabb()
            for corner in range(8):
                lowest = minf(lowest,
                    piece.to_global(box.get_endpoint(corner)).y)
        elif child is Node3D:
            lowest = minf(lowest, _leg_lowest_y(child as Node3D))
    return lowest


func _check_delta_form(battle: Node) -> bool:
    var rig: Node3D = battle.get("bittaran_rig")
    if rig == null:
        _fail("Bittaran rig not initialized")
        return false
    var world: Basis = rig.global_basis.orthonormalized()
    var world_q: Quaternion = world.get_rotation_quaternion()
    var wait_local: Quaternion = rig.call(
        "_authored_key_rotation", "Wait", "Body", 0.0)
    var world_rest: Quaternion = world_q * wait_local
    for t in MIRROR_KEYS:
        var source_local: Quaternion = rig.call(
            "_authored_body_rotation_for_attack",
            "sweep", "leg_fl", t)
        var source_delta: Quaternion = (
            (world_q * source_local) * world_rest.inverse()
            ).normalized()
        var source_angle: float = source_delta.get_angle()
        for id in LEGS:
            if id == "leg_fl":
                continue
            var actual_local: Quaternion = rig.call(
                "_authored_body_rotation_for_attack",
                "sweep", id, t)
            var actual_delta: Quaternion = (
                (world_q * actual_local) * world_rest.inverse()
                ).normalized()
            if absf(actual_delta.get_angle()
                    - source_angle) > MAX_MAGNITUDE_ERROR:
                _fail(id + " sweep BODY tilt motion magnitude "
                    + str(rad_to_deg(actual_delta.get_angle()))
                    + " differs from leg_fl's "
                    + str(rad_to_deg(source_angle)) + " at clip "
                    + str(t))
                return false
            var wanted: Quaternion = source_delta
            if id.ends_with("r"):
                wanted = rig.call("_reflect_world_rotation",
                    wanted, world.x.normalized())
            var err: float = actual_delta.angle_to(wanted)
            if err > MAX_MIRROR_ERROR:
                _fail(id + " sweep BODY tilt motion is not the "
                    + "clean side mirror of leg_fl at clip "
                    + str(t) + ": " + str(rad_to_deg(err))
                    + " degrees off")
                return false
    return true


func _check_scene(battle: Node) -> bool:
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    var chassis: Node3D = ik.get("chassis_bone")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    for id in LEGS:
        brain.call("cancel")
        ik.call("clear_attack_pose")
        battle.call("_reset_target_after_respawn")
        boss.global_position = Vector3.ZERO
        var rear: bool = id.begins_with("leg_r")
        player.global_position = Vector3(
            0.0, 0.0, 6.0 if rear else -6.0)
        if rear:
            boss.rotation = Vector3(0.0, PI, 0.0)
        for i in range(30):
            _tick(battle)
        var rest_q: Quaternion = Basis(
            chassis.global_transform.basis).orthonormalized(
            ).get_rotation_quaternion()
        var legs: Array = ik.get("legs")
        var leg: Dictionary = legs[part_ids.find(id)]
        var upper: Node3D = leg["upper"]
        brain.call("force_start_with_stance", id, "sweep")
        var finished: bool = false
        var max_twist: float = 0.0
        var min_clear: float = INF
        for t in range(420):
            _tick(battle)
            var frame: Dictionary = battle.get(
                "bittaran_attack_frame")
            if frame.is_empty():
                if t > 60:
                    finished = true
                    break
                continue
            var q: Quaternion = Basis(
                chassis.global_transform.basis).orthonormalized(
                ).get_rotation_quaternion()
            max_twist = maxf(max_twist,
                rad_to_deg(rest_q.angle_to(q)))
            min_clear = minf(min_clear, _leg_lowest_y(upper))
        if not finished:
            _fail(id + "/sweep: attack did not finish")
            return false
        if max_twist > MAX_TWIST_DEGREES:
            _fail(id + "/sweep: torso wound to "
                + str(max_twist) + " degrees from rest")
            return false
        if min_clear < MIN_LEG_CLEARANCE:
            _fail(id + "/sweep: leg mesh broke the floor at "
                + str(min_clear))
            return false
    return true


func _run() -> void:
    var scene: PackedScene = load(
        "res://scenes/bittaran_battle.tscn")
    var battle: Node = scene.instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    for i in range(30):
        _tick(battle)
    if not _check_delta_form(battle):
        return
    if not _check_scene(battle):
        return
    print("GODOT_V411_BITTARAN_SWEEP_DELTA_MIRROR_PASS: SWEEP "
        + "body tilt motion is leg_fl's Wait-relative delta at "
        + "equal magnitude on every leg (left-right mirror; rear "
        + "legs share their side), in-scene torso stays within "
        + "70 degrees of rest and the sweeping limb never breaks "
        + "the floor")
    quit(0)
