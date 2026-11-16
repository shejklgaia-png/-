extends SceneTree
## v415: The independently inverted rear chassis pitch must not rotate
## the original Blockbench attacking leg a second time. Compare the
## world-space rotations of all 3 attack joints before/after chassis
## tilt at four times, for both rear legs and all three attack types.
## This checks the ACTUAL loaded keys + retargeter, not mocked rotations.
const KINDS: Array[String] = ["kick", "sweep", "stomp"]
const IDS: Array[String] = ["leg_rl", "leg_rr"]
const MAX_WORLD_ROTATION_ERROR: float = 0.002
const MAX_ROOT_HEIGHT_CHANGE: float = 0.00001


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V415_REAR_AUTHORED_MOTION_FAIL: " + why)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var chassis: Node3D = rig.find_child("Body", true, false)
    if chassis == null or not bool(rig.get("loading_ok")):
        _fail("Blockbench source rig absent")
        return
    var checked: int = 0
    for kind in KINDS:
        for id in IDS:
            var names: Array = rig.ATTACK_LEG_BONES[id]
            var nodes: Array[Node3D] = []
            for name in names:
                var node: Node3D = rig.find_child(str(name), true, false)
                if node == null:
                    _fail(id + " missing joint " + str(name))
                    return
                nodes.append(node)
            var windup: float = 1.25 if kind == "stomp" else 0.70
            var strike: float = 0.25 if kind == "stomp" else (
                1.0 if kind == "kick" else 2.06)
            var hold: float = 0.0 if kind == "sweep" else 1.5
            var recovery: float = 0.55 if kind == "stomp" else (
                0.60 if kind == "kick" else 1.40)
            for t in [windup * 0.15, windup * 0.85,
                    windup + strike * 0.5,
                    windup + strike + hold + recovery * 0.6]:
                rig.call("end_authored_attack")
                rig.call("apply_pose", "Wait", 0.0)
                rig.call("start_authored_attack", kind, id)
                var frame: Dictionary = {
                    "kind": kind, "id": id, "time": t,
                    "windup": windup, "strike": strike, "hold": hold,
                    "recovery": recovery, "body_yaw": 0.0,
                    "authored": true, "stomp_aim": Vector3.INF,
                    "authored_time": clampf(
                        t - (0.0 if kind == "stomp" else windup),
                        0.0, float(rig.call("authored_clip_length", kind)))
                }
                rig.call("apply_authored_attack_pose", frame)
                var world_before: Array[Quaternion] = []
                var socket_before: Array[Vector3] = []
                for node in nodes:
                    world_before.append(
                        node.global_basis.get_rotation_quaternion())
                    socket_before.append(node.global_position)
                var root_y_before: float = rig.position.y
                var root_world_before: Vector3 = rig.global_position
                ik.call("set_attack_pose", frame)
                ik.call("_apply_attack_chassis_pose")
                for i in range(nodes.size()):
                    var err: float = (
                        nodes[i].global_basis.get_rotation_quaternion()
                        ).angle_to(world_before[i])
                    if err > MAX_WORLD_ROTATION_ERROR:
                        _fail(id + "/" + kind + " t=" + str(t)
                            + " joint=" + str(names[i])
                            + " world rotation changed "
                            + str(rad_to_deg(err)) + " degrees")
                        return
                    # v419: the shared SOURCE floor calibration
                    # can translate the whole actor/root by one
                    # measured contact-height offset, but cannot
                    # translate a shoulder or joint RELATIVE to it.
                    var translation: float = (
                        (nodes[i].global_position - rig.global_position)
                        .distance_to(
                            socket_before[i] - root_world_before))
                    if translation > 0.001:
                        _fail(id + "/" + kind + " t=" + str(t)
                            + " joint=" + str(names[i])
                            + " original joint position moved "
                            + str(translation) + "m")
                        return
                if absf(rig.position.y - root_y_before) >                         MAX_ROOT_HEIGHT_CHANGE:
                    _fail(id + "/" + kind
                        + " changed torso-root height")
                    return
                ik.call("clear_attack_pose")
                rig.call("end_authored_attack")
                checked += 1
    if checked != 24:
        _fail("only " + str(checked) + " samples")
        return
    print("GODOT_V415_REAR_AUTHORED_MOTION_PASS: "
        + "24 real source-clip samples and all attacking joints")
    quit(0)
