extends SceneTree
## v402 regression check, from two pieces of device feedback on v401:
## (1) KICKs with legs other than leg_fl still looked wrong. Full-
## timeline measurement found the recovery phase snapping: the
## attacking leg's joints jumped up to 56 degrees in a single tick
## mid-recovery on the rear legs (the IK knee-inward wind's weight
## tail dragged the solve pole across the bend-plane singularity),
## and at the authored->IK handover the whole-limb floor lift
## switched off in one tick (hip teleport 0.74m, SWEEP shoulder snap
## 49 degrees). Part A asserts every leg's per-tick joint rotation
## delta during KICK and SWEEP recovery stays bounded.
## (2) The v401 impact camera shake was imperceptible: measured max
## image displacement was only ~5px at fight distance. Part B runs
## the real process loop around a STOMP and asserts the recalibrated
## shake displaces the image by at least 12px and still settles to
## exactly zero offset.
const DT: float = 1.0 / 60.0
const LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const KICK_RECOVERY_MAX_STEP_DEGREES: float = 15.0
const SWEEP_RECOVERY_MAX_STEP_DEGREES: float = 25.0
const SHAKE_MIN_DISPLACEMENT_PX: float = 12.0

var failures: Array[String] = []

func _fail(message: String) -> void:
    failures.append(message)

func _part_a(battle: Node3D) -> void:
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    for kind in ["kick", "sweep"]:
        var limit: float = (KICK_RECOVERY_MAX_STEP_DEGREES
            if kind == "kick" else SWEEP_RECOVERY_MAX_STEP_DEGREES)
        for leg_id in LEGS:
            player.global_position = boss.global_position + Vector3(
                0.0, 0.0, 24.0)
            for frame in range(20):
                battle.set("player_hp", 9999.0)
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
            var feet: Dictionary = battle.call(
                "_bittaran_attack_candidates")
            var sole: Vector3 = feet[leg_id]
            var centroid := Vector3.ZERO
            for other in feet.values():
                centroid += other as Vector3
            centroid /= float(feet.size())
            var radial := Vector2(
                sole.x - centroid.x, sole.z - centroid.z)
            var outward: Vector2 = radial.normalized() * 5.0
            player.global_position = Vector3(
                sole.x + outward.x, 0.0, sole.z + outward.y)
            for frame in range(10):
                battle.set("player_hp", 9999.0)
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
            brain.call("force_start_with_stance", leg_id, kind)
            var idx: int = part_ids.find(leg_id)
            var leg: Dictionary = ik.get("legs")[idx]
            var nodes: Array = [leg["upper"], leg["lower"], leg["foot"]]
            var prev_q: Array = []
            var started: bool = false
            var worst: float = 0.0
            for frame in range(60 * 8):
                battle.set("player_hp", 9999.0)
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
                var f: Dictionary = battle.get("bittaran_attack_frame")
                if f.is_empty():
                    if started:
                        break
                    continue
                started = true
                if prev_q.is_empty():
                    for j in range(3):
                        prev_q.append((nodes[j] as Node3D).global_basis
                            .get_rotation_quaternion())
                    continue
                for j in range(3):
                    var q: Quaternion = (nodes[j] as Node3D).global_basis \
                        .get_rotation_quaternion()
                    if str(f.get("phase", "")) == "recovery":
                        worst = maxf(worst,
                            rad_to_deg(prev_q[j].angle_to(q)))
                    prev_q[j] = q
            if worst > limit:
                _fail("%s %s recovery snapped %.1f deg in one tick "
                    % [leg_id, kind, worst]
                    + "(limit %.0f)" % limit)

func _part_b(battle: Node3D) -> void:
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var camera: Camera3D = battle.get("camera")
    player.global_position = boss.global_position + Vector3(0.0, 0.0, 5.0)
    for frame in range(30):
        battle.set("player_hp", 9999.0)
        battle.call("_physics_process", DT)
        battle.call("_process", DT)
    brain.call("force_start_with_stance", "leg_fl", "stomp")
    var probe: Vector3 = boss.global_position + Vector3(0.0, 2.5, 0.0)
    var max_px: float = 0.0
    for frame in range(60 * 8):
        battle.set("player_hp", 9999.0)
        battle.call("_physics_process", DT)
        battle.call("_process", DT)
        if float(battle.get("impact_shake_strength")) > 0.0:
            var p1: Vector2 = camera.unproject_position(probe)
            var h: float = camera.h_offset
            var v: float = camera.v_offset
            camera.h_offset = 0.0
            camera.v_offset = 0.0
            var p0: Vector2 = camera.unproject_position(probe)
            camera.h_offset = h
            camera.v_offset = v
            max_px = maxf(max_px, p1.distance_to(p0))
        var f: Dictionary = battle.get("bittaran_attack_frame")
        if f.is_empty() and frame > 60:
            break
    if max_px < SHAKE_MIN_DISPLACEMENT_PX:
        _fail("stomp shake displaced the image only %.1f px " % max_px
            + "(minimum %.0f)" % SHAKE_MIN_DISPLACEMENT_PX)
    for frame in range(60 * 3):
        battle.call("_tick_impact_shake", DT)
    if float(battle.get("impact_shake_strength")) != 0.0 or (
            camera.h_offset != 0.0 or camera.v_offset != 0.0):
        _fail("impact shake did not settle to exactly zero offset")

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    _part_a(battle)
    _part_b(battle)
    if failures.is_empty():
        print("GODOT_V402_BITTARAN_RECOVERY_SMOOTHNESS_PASS")
        quit(0)
    else:
        for message in failures:
            printerr("V402_BITTARAN_RECOVERY_SMOOTHNESS_FAIL: ", message)
        quit(1)

func _initialize() -> void:
    call_deferred("_run")
