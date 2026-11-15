extends SceneTree
## v380: moving KNEE enters a stationary HEAD's clearance, not only
## the reverse. The actual yaw (already clamped by collision) must be
## scanned, the swinging leg must not be skipped, and a 20cm rule is
## shared by the head stop and leg pole. Sole target must be unchanged.
const PARTS = preload("res://scripts/bittaran_parts.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

class KneeInvadesHeadProbe extends Node3D:
    var moving_leg: Dictionary = {}

    func get_head_swing_aabb() -> AABB:
        return AABB(Vector3(-1, -1, -1), Vector3.ONE * 2.0)

    func get_leg_visual_aabb(_id: String) -> AABB:
        return AABB(Vector3(-50, -50, -50), Vector3.ONE * 100.0)

    func get_head_leg_penetration_depth(id: String) -> float:
        if id != "leg_fl":
            return 0.0
        # The moving knee initially penetrates 30cm. Its 13cm preferred
        # clearance activates outward/downward folding ahead of 20cm.
        return maxf(0.0, 0.30 - 0.31 *
            float(moving_leg.get("head_knee_bend", 0.0)))


func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V380_BITTARAN_KNEE_HEAD_FAIL: " + message)
    quit(1)

func _run() -> void:
    # SceneTree scripts are compiled before project autoload singletons
    # become available; avoid eager battle-script preloads at file scope.
    var boss_constants: Dictionary = (load(
        "res://scripts/bittaran_battle.gd") as GDScript).get_script_constant_map()
    if absf(PARTS.HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.20) > 0.00001 \
            or absf(boss_constants["HEAD_LEG_ALLOWED_PENETRATION_METERS"] - 0.20) > 0.00001 \
            or absf(IK.HEAD_KNEE_ALLOWED_PENETRATION_METERS - 0.20) > 0.00001:
        _fail("HEAD and moving knee must share exactly 20cm")
        return
    if IK.HEAD_KNEE_MAX_BEND < 0.69 or (
            IK.HEAD_KNEE_MAX_BEND > 0.71):
        _fail("knee should flex moderately more than the old 30%")
        return
    if IK.HEAD_KNEE_SCAN_SECONDS > 0.051:
        _fail("knee did not react promptly to moving-leg intrusion")
        return
    if boss_constants["HEAD_TRACK_COLLISION_RELEASE_DEPTH_METERS"] > 0.20:
        _fail("head stop did not scale to 20cm")
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
    # The contact probe measures leg_fl, not the default leg_fr at index 0.
    # Match the actual IK ID ordering instead of exercising a different leg.
    var selected_index: int = IK.LEG_PART_IDS.find("leg_fl")
    if selected_index < 0:
        _fail("leg_fl is missing from IK leg ordering")
        return
    var selected: Dictionary = legs[selected_index]
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
        _fail("70% pole did not move the knee")
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
    var original_collision: Node3D = ik.get("collision_parts")
    var probe := KneeInvadesHeadProbe.new()
    probe.moving_leg = selected
    root.add_child(probe)
    ik.set("collision_parts", probe)
    selected["stepping"] = true
    selected["head_knee_target"] = 0.0
    ik.set("head_knee_scan_elapsed", IK.HEAD_KNEE_SCAN_SECONDS)
    ik.call("steer_knees_for_head", DT, 0.0, 0.20)
    # During SWING, the knee must choose an actual bend, even though
    # the HEAD's desired yaw is zero and did not cause the contact.
    var chosen: float = float(selected["head_knee_target"])
    if chosen < 0.40 or chosen > IK.HEAD_KNEE_MAX_BEND + 0.00001:
        _fail("swinging knee failed to fold around a stationary head: "
            + str(chosen))
        return
    ik.set("collision_parts", original_collision)
    probe.queue_free()
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
    # A 20cm inward depth must stop HEAD turning without a snap,
    # and an outward motion must remain available.
    battle.set("head_collision_filtered_depth", 0.0)
    battle.set("head_collision_blocked", false)
    var stopped: float = float(battle.call(
        "_head_collision_motion_scale", 0.20, 0.22, DT))
    if stopped != 0.0:
        _fail("head still turns deeper at 20cm")
        return
    var escape: float = float(battle.call(
        "_head_collision_motion_scale", 0.25, 0.18, DT))
    if escape < 0.39:
        _fail("head cannot retreat smoothly")
        return
    if absf(boss_constants["HEAD_TRACK_STANDUP_START_FRACTION"] - 0.70) > 0.00001 \
            or absf(IK.STEP_DURATION_SECONDS - 0.58) > 0.00001:
        _fail("unrelated stand-up or gait timing changed")
        return
    print("GODOT_V380_BITTARAN_KNEE_HEAD_PASS: 20cm tolerance, "
        + "70% knee bend, swinging-leg scan, same planted toe and "
        + "20cm smooth head stop")
    quit(0)
