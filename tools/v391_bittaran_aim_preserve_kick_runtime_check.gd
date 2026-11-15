extends SceneTree
## v391: all twelve variants follow SERA in windup, lock strike aim,
## retain the original KICK knee pose and point the head's short -Z
## nose face at the real player.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V391_BITTARAN_AIM_FAIL: " + why)
    quit(1)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var head: Node3D = battle.get("bittaran_head")
    if rig == null or brain == null or ik == null or head == null:
        _fail("live rig/brain/IK/head missing")
        return
    var combinations: int = 0
    for id in BRAIN.LEG_IDS:
        for kind in BRAIN.ATTACK_KINDS:
            battle.call("_reset_target_after_respawn")
            battle.set("target_move_enabled", true)
            if not bool(brain.call("force_start", id, kind)):
                _fail(id + "/" + kind + " did not start")
                return
            var tracked: bool = false
            var released: bool = false
            var frozen_aim: Vector3 = Vector3.INF
            var initial_aim: Vector3 = Vector3.INF
            var knee_checked: bool = false
            for n in range(125):
                player.global_position = boss.global_position + Vector3(
                    5.0 if n < 18 else -5.0, 0.0, 6.5)
                battle.call("_advance_target_motion", DT)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                if frame.is_empty():
                    break
                var t: float = float(frame.get("time", 0.0))
                var windup: float = float(frame.get("windup", 0.0))
                if t < windup - 0.02:
                    if not bool(frame.get("tracking", false)):
                        _fail(id + "/" + kind + " lost windup tracking")
                        return
                    if frame.get("aim", Vector3.INF) == Vector3.INF:
                        _fail(id + "/" + kind + " has no target")
                        return
                    if initial_aim == Vector3.INF:
                        initial_aim = frame["aim"]
                    tracked = true
                if t >= windup + 0.02 and t < windup + 0.12:
                    if bool(frame.get("tracking", false)):
                        _fail(id + "/" + kind + " retargeted the strike")
                        return
                    if frozen_aim == Vector3.INF:
                        frozen_aim = frame.get("aim", Vector3.INF)
                    elif (frame.get("aim", Vector3.INF) as Vector3).distance_to(
                            frozen_aim) > 0.00001:
                        _fail(id + "/" + kind + " changed frozen aim")
                        return
                    released = true
                battle.call("_finalize_target_pose", DT)
                if kind == "kick" and not knee_checked and t >= (
                        windup - 0.012) and t <= windup + 0.002:
                    var leg: Dictionary = ik.get("legs")[
                        IK.LEG_PART_IDS.find(id)]
                    var knee: Node3D = leg["lower"]
                    var authored: Quaternion = rig.call(
                        "_authored_rotation_for_leg", kind, id, 1, 0.0)
                    if knee.quaternion.angle_to(authored) > 0.075:
                        _fail(id + ": extra KICK knee folding in prepose")
                        return
                    knee_checked = true
                if kind != "stomp" and t > 0.36 and t < windup - 0.05:
                    if not is_finite(float(rig.get("attack_leg_aim_yaw"))):
                        _fail(id + "/" + kind + " invalid leg yaw")
                        return
            if not tracked or not released or (
                    kind == "kick" and not knee_checked):
                _fail(id + "/" + kind + " missed aim/pose phases")
                return
            combinations += 1
    battle.call("_reset_target_after_respawn")
    var parent: Node3D = head.get_parent() as Node3D
    player.global_position = parent.to_global(
        head.position + Vector3(3.2, 0.0, -2.0)) - Vector3.UP * 0.9
    for n in range(90):
        battle.call("_update_head_look_target", DT)
        battle.call("_aim_bittaran_head", DT)
    var short_edge_normal: Vector3 = -head.global_basis.z
    short_edge_normal.y = 0.0
    short_edge_normal = short_edge_normal.normalized()
    var toward: Vector3 = player.global_position - head.global_position
    toward.y = 0.0
    if toward.length_squared() > 0.001 and short_edge_normal.dot(
            toward.normalized()) < 0.25:
        _fail("HEAD short front edge did not turn toward SERA")
        return
    if combinations != 12:
        _fail("not all twelve combinations tested")
        return
    print("GODOT_V391_BITTARAN_AIM_PASS: 12 attacks track/lock correctly; "
        + "KICK knee keys and HEAD nose axis preserved")
    quit(0)
