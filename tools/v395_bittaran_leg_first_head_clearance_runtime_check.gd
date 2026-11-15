extends SceneTree
## v395: knees yield to the tracked head even during an authored attack.
## The actively striking limb keeps its original pose, the other three
## planted soles remain fixed, and 20cm is the common hard mesh-depth cap.
const PARTS = preload("res://scripts/bittaran_parts.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

class KneeDepthProbe extends Node3D:
    var moving_leg: Dictionary = {}

    func get_head_swing_aabb() -> AABB:
        return AABB(Vector3(-100.0, -100.0, -100.0), Vector3.ONE * 200.0)

    func get_leg_visual_aabb(_id: String) -> AABB:
        return get_head_swing_aabb()

    func get_head_leg_penetration_depth(id: String) -> float:
        if id != "leg_fl":
            return 0.0
        # Folding starts above the preferred 13cm, well before 20cm.
        return maxf(0.0, 0.30 - 0.31 * float(
            moving_leg.get("head_knee_bend", 0.0)))


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V395_LEG_FIRST_HEAD_FAIL: " + why)
    quit(1)


func _run() -> void:
    if absf(PARTS.HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.20) > 0.00001 or (
            absf(IK.HEAD_KNEE_ALLOWED_PENETRATION_METERS - 0.20) > 0.00001):
        _fail("head and knee hard limit must both be 20cm")
        return
    if IK.HEAD_KNEE_PREFERRED_PENETRATION_METERS >= 0.20 or (
            IK.HEAD_KNEE_MAX_BEND < 0.65):
        _fail("leg did not get proactive outward/downward bend")
        return
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var head: Node3D = battle.get("bittaran_head")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if brain == null or ik == null or rig == null or head == null:
        _fail("bittaran components missing")
        return
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    player.global_position = boss.global_position + Vector3(3.0, 0.0, 7.0)
    if not bool(brain.call("force_start", "leg_fr", "sweep")):
        _fail("could not force authored front-right sweep")
        return
    for tick in range(12):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
    var frame: Dictionary = battle.get("bittaran_attack_frame")
    if frame.is_empty() or str(frame.get("id", "")) != "leg_fr":
        _fail("real sweep did not retain its striking leg")
        return
    var striker: Node3D = rig.find_child("FrontLeg_R", true, false)
    if striker == null:
        _fail("striker shoulder not found")
        return
    var striker_rotation: Quaternion = striker.quaternion
    var head_rotation: Quaternion = head.quaternion
    var legs: Array = ik.get("legs")
    var support_index: int = IK.LEG_PART_IDS.find("leg_fl")
    if support_index < 0:
        _fail("front-left support is missing")
        return
    var support: Dictionary = legs[support_index]
    var planted: Vector3 = support["last_goal"]
    var bend_start: Vector3 = (support["lower"] as Node3D).global_position
    var lift_before: float = float(battle.get(
        "head_visual_clearance_lift_world"))
    var original_parts: Node3D = ik.get("collision_parts")
    var probe := KneeDepthProbe.new()
    probe.moving_leg = support
    root.add_child(probe)
    ik.set("collision_parts", probe)
    ik.set("head_knee_scan_elapsed", IK.HEAD_KNEE_SCAN_SECONDS)
    for tick in range(16):
        ik.call("steer_knees_for_head", DT, 0.0,
            float(battle.get("boss_head_yaw")))
    var chosen: float = float(support["head_knee_target"])
    var actual_bend: float = float(support["head_knee_bend"])
    var folded_knee: Node3D = support["lower"] as Node3D
    var moved: float = folded_knee.global_position.distance_to(bend_start)
    ik.set("collision_parts", original_parts)
    probe.queue_free()
    if chosen < 0.35 or actual_bend < 0.25 or moved < 0.015:
        _fail("support knee did not fold during authored sweep: "
            + str([chosen, actual_bend, moved]))
        return
    if striker.quaternion.angle_to(striker_rotation) > 0.0001:
        _fail("head avoidance overwrote the active authored striker")
        return
    if head.quaternion.angle_to(head_rotation) > 0.0001:
        _fail("knee avoidance changed the head rotation")
        return
    if (support["last_goal"] as Vector3).distance_to(planted) > 0.001:
        _fail("knee clearance moved the planted sole target")
        return
    if absf(float(battle.get(
            "head_visual_clearance_lift_world")) - lift_before) > 0.00001:
        _fail("leg-first knee clearance lifted the head")
        return
    print("GODOT_V395_LEG_FIRST_HEAD_PASS: 20cm depth, proactive "
        + "support knee fold during authored attack, untouched striker, "
        + "head yaw and planted sole")
    quit(0)
