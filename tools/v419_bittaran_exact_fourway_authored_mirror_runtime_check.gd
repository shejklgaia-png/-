extends SceneTree
## v419: From the FIRST authored attack frame (not just peak strike)
## BODY and each of the three attacking pivots must be spatial
## reflections of the original Blockbench FRONT LEFT source pose.
## Mirroring is X for right, Z for rear, X+Z for rear-right;
## KICK/STOMP/SWEEP share the same algorithm with no extra lean.
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const KINDS: Array[String] = ["kick", "sweep", "stomp"]
const MAX_ROT_ERROR_DEG: float = 0.12


func _initialize() -> void:
    call_deferred("_run")


func _fail(msg: String) -> void:
    push_error("V419_EXACT_FOURWAY_MIRROR_FAIL: " + msg)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var body: Node3D = rig.find_child("Body", true, false)
    if rig == null or ik == null or body == null:
        _fail("source model missing")
        return
    var world: Basis = rig.global_basis.orthonormalized()
    var root_q: Quaternion = world.get_rotation_quaternion()
    var wait_body: Quaternion = rig.call(
        "_authored_key_rotation", "Wait", "Body", 0.0)
    var actual_count: int = 0
    for kind in KINDS:
        var windup: float = 1.25 if kind == "stomp" else 0.70
        var strike: float = (0.25 if kind == "stomp"
            else (1.0 if kind == "kick" else 2.06))
        var hold: float = 0.0 if kind == "sweep" else 1.5
        var recovery: float = (
            0.55 if kind == "stomp" else
            (0.60 if kind == "kick" else 1.40))
        # First frame, windup, strike and hold source keys. We
        # intentionally do NOT enter recovery because that phase
        # blends back to Wait by design, not to a source attack key.
        var times: Array[float] = [
            0.0, 1.0 / 60.0, windup * 0.50,
            windup, windup + strike * 0.15,
            windup + strike * 0.55,
            windup + strike * 0.92,
            windup + strike + minf(hold * 0.45, 0.50)]
        for id in IDS:
            var names: Array = rig.ATTACK_LEG_BONES[id]
            var nodes: Array[Node3D] = []
            for n in names:
                var joint: Node3D = rig.find_child(
                    str(n), true, false)
                if joint == null:
                    _fail(id + " joint absent " + str(n))
                    return
                nodes.append(joint)
            for seconds in times:
                rig.call("end_authored_attack")
                rig.call("apply_pose", "Wait", 0.0)
                rig.call("start_authored_attack", kind, id)
                var clip_t: float = (
                    seconds if kind == "stomp"
                    else maxf(seconds - windup, 0.0))
                if kind == "stomp":
                    clip_t = minf(clip_t, windup + strike)
                var frame: Dictionary = {
                    "kind": kind,
                    "id": id,
                    "time": seconds,
                    "windup": windup, "strike": strike,
                    "hold": hold, "recovery": recovery,
                    "authored_time": clip_t,
                    "body_yaw": 0.0,
                    "aim": Vector3.INF,
                    "stomp_aim": Vector3.INF,
                    "tracking": false, "authored": true,
                }
                rig.call("apply_authored_attack_pose", frame)
                var source_body: Quaternion = rig.call(
                    "_authored_key_rotation",
                    rig.ATTACK_NAMES[kind], "Body", clip_t)
                var delta_local: Quaternion = (
                    wait_body.inverse() * source_body).normalized()
                var delta_world: Quaternion = (
                    root_q * delta_local
                    * root_q.inverse()).normalized()
                if id.ends_with("r"):
                    delta_world = rig.call(
                        "_reflect_world_rotation",
                        delta_world, world.x.normalized())
                if id.begins_with("leg_r"):
                    delta_world = rig.call(
                        "_reflect_world_rotation",
                        delta_world, world.z.normalized())
                var body_expected: Quaternion = (
                    wait_body * root_q.inverse()
                    * delta_world * root_q).normalized()
                var body_error: float = rad_to_deg(
                    body.quaternion.angle_to(body_expected))
                if body_error > MAX_ROT_ERROR_DEG:
                    _fail(id + "/" + kind + " source=" + str(clip_t)
                        + " BODY mirror differs "
                        + str(body_error) + "deg")
                    return

                var source_world: Quaternion = (
                    root_q * source_body).normalized()
                for slot in range(3):
                    var source_local: Quaternion = rig.call(
                        "_authored_key_rotation",
                        rig.ATTACK_NAMES[kind],
                        rig.ATTACK_LEG_BONES["leg_fl"][slot],
                        clip_t)
                    source_world = (
                        source_world * source_local).normalized()
                    var wanted: Quaternion = source_world
                    if id.ends_with("r"):
                        wanted = rig.call(
                            "_reflect_world_rotation",
                            wanted, world.x.normalized())
                    if id.begins_with("leg_r"):
                        wanted = rig.call(
                            "_reflect_world_rotation",
                            wanted, world.z.normalized())
                    var got: Quaternion = (
                        nodes[slot].global_basis
                        .get_rotation_quaternion())
                    var err: float = rad_to_deg(
                        got.angle_to(wanted))
                    if err > MAX_ROT_ERROR_DEG:
                        _fail(id + "/" + kind + " source="
                            + str(clip_t) + " joint=" + str(slot)
                            + " not source quadrant reflection: "
                            + str(err) + "deg")
                        return
                    actual_count += 1
                # Separate IK entrance must NOT replace the
                # mirrored BODY with a manufactured 25-degree
                # forward/backward lean; no independent tilt.
                var old_body: Quaternion = body.quaternion
                ik.call("set_attack_pose", frame)
                ik.call("_apply_attack_chassis_pose")
                var post_error: float = rad_to_deg(
                    old_body.angle_to(body.quaternion))
                if post_error > MAX_ROT_ERROR_DEG:
                    _fail(id + "/" + kind
                        + " procedural BODY pitch "
                        + "changed source attack entry: "
                        + str(post_error) + "deg")
                    return
                ik.call("clear_attack_pose")
    if actual_count != 288:
        _fail("not enough mirrored source joints: "
            + str(actual_count))
        return
    print("GODOT_V419_EXACT_FOURWAY_MIRROR_PASS: "
        + str(actual_count) + " source joint poses, "
        + "first frame + 7 clip points for KICK/SWEEP/STOMP")
    quit(0)
