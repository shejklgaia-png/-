extends SceneTree
## v380: moving KNEE enters a stationary HEAD's clearance, not only
## the reverse. The actual yaw (already clamped by collision) must be
## scanned, the swinging leg must not be skipped, and a 10cm rule is
## shared by the head stop and leg pole. Sole target must be unchanged.
const PARTS = preload("res://scripts/bittaran_parts.gd")
const BOSS = preload("res://scripts/bittaran_battle.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V380_BITTARAN_KNEE_HEAD_FAIL: " + message)
    quit(1)

func _run() -> void:
    if absf(PARTS.HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.10) > 0.00001 \
            or absf(BOSS.HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.10) > 0.00001 \
            or absf(IK.HEAD_KNEE_ALLOWED_PENETRATION_METERS - 0.10) > 0.00001:
        _fail("HEAD and moving knee must share exactly 10cm")
        return
    if IK.HEAD_KNEE_MAX_BEND < 0.44 or (
            IK.HEAD_KNEE_MAX_BEND > 0.46):
        _fail("knee should flex moderately more than the old 30%")
        return
    if IK.HEAD_KNEE_SCAN_SECONDS > 0.051:
        _fail("knee did not react promptly to moving-leg intrusion")
        return
    if BOSS.HEAD_TRACK_COLLISION_RELEASE_DEPTH_METERS > 0.10:
        _fail("head stop did not scale to 10cm")
        return
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var parts: Node3D = battle.get("target_parts")
    var head: Node3D = battle.get("bittaran_head")
    var boss: Node3D = battle.get("target")
    if ik == null or parts == null or head == null or boss == null:
        _fail("actual boss geometry not initialized")
        return
    var legs: Array = ik.get("legs")
    var selected: Dictionary = legs[0]
    var original_goal: Vector3 = selected["last_goal"]
    var original_rotation: Quaternion = selected["last_rotation"]
    var saved_bend: float = float(selected["head_knee_bend"])
    selected["head_knee_bend"] = 0.0
    ik.call("_solve", selected, original_goal, original_rotation)
    var knee_neutral: Vector3 = (
        selected["lower"] as Node3D).global_position
    selected["head_knee_bend"] = IK.HEAD_KNEE_MAX_BEND
    var err_bent: float = float(ik.call(
        "_solve", selected, original_goal, original_rotation))
    var knee_bent: Vector3 = (
        selected["lower"] as Node3D).global_position
    if knee_neutral.distance_to(knee_bent) <= 0.012:
        _fail("45% pole did not move the knee")
        return
    if err_bent > 0.20:
        _fail("head clearance detached the foot from its contact")
        return
    selected["head_knee_bend"] = saved_bend
    ik.call("_solve", selected, original_goal, original_rotation)
    # The leg is SWINGING. The selector must still evaluate its moving
    # knee; it cannot ignore it until the toe plants.
    var saved_step: bool = bool(selected["stepping"])
    var saved_scan: float = float(ik.get("head_knee_scan_elapsed"))
    selected["stepping"] = true
    selected["head_knee_target"] = 0.0
    ik.set("head_knee_scan_elapsed", IK.HEAD_KNEE_SCAN_SECONDS)
    ik.call("steer_knees_for_head", DT, 0.0, 0.20)
    if not selected.has("head_knee_target") or (
            not is_finite(float(selected["head_knee_target"]))):
        _fail("moving knee evaluation invalid")
        return
    if (selected["last_goal"] as Vector3).distance_to(
            original_goal) > 0.00001:
        _fail("swinging foot trajectory changed")
        return
    selected["stepping"] = saved_step
    ik.set("head_knee_scan_elapsed", saved_scan)
    var depth_start: float = float(parts.call(
        "get_head_leg_penetration_depth", "leg_fl"))
    if not is_finite(depth_start):
        _fail("moving knee depth not measurable")
        return
    # A 10cm inward depth must stop HEAD turning without a snap,
    # and an outward motion must remain available.
    battle.set("head_collision_filtered_depth", 0.0)
    battle.set("head_collision_blocked", false)
    var stopped: float = float(battle.call(
        "_head_collision_motion_scale", 0.10, 0.12, DT))
    if stopped != 0.0:
        _fail("head still turns deeper at 10cm")
        return
    var escape: float = float(battle.call(
        "_head_collision_motion_scale", 0.15, 0.12, DT))
    if escape < 0.39:
        _fail("head cannot retreat smoothly")
        return
    if absf(BOSS.HEAD_TRACK_STANDUP_START_FRACTION - 0.70) > 0.00001 \
            or absf(IK.STEP_DURATION_SECONDS - 0.58) > 0.00001:
        _fail("unrelated stand-up or gait timing changed")
        return
    print("GODOT_V380_BITTARAN_KNEE_HEAD_PASS: 10cm tolerance, "
        + "45% knee bend, swinging-leg scan, same planted toe and "
        + "10cm smooth head stop")
    quit(0)
