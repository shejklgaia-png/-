extends SceneTree
## v386: regression for restored authored stomp windup, measured INITIAL
## kick/sweep floor contact, and fully locked-off sweep player following.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V386_BITTARAN_WINDUP_GROUND_FAIL: " + message)
    quit(1)

func _case(battle: Node3D, id: String, kind: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var i: int = IK.LEG_PART_IDS.find(id)
    var leg: Dictionary = ik.get("legs")[i]
    var entry_body_y: float = (rig as Node3D).position.y
    if not bool(brain.call("force_start", id, kind)):
        _fail("cannot force " + id + "/" + kind)
        return false
    var first_offset: float = NAN
    var reference_offset: float = NAN
    var initial_chest: float = 0.0
    var initial_head: float = 0.0
    var recorded_initial_head: bool = false
    var mirrored_hip: bool = false
    var mirrored_knee: bool = false
    var near_floor: bool = false
    var smooth_drop: bool = false
    var authored_height: float = -INF
    var prior_body_y: float = entry_body_y
    var saw_original_stomp: bool = false
    var body_track: float = 0.0
    var support_anchors: Dictionary = {}
    var active_timing: float = 0.7 if kind != "stomp" else 1.25
    for tick in range(205):
        var x: float = 0.75 if tick < 14 else (
            -0.95 if tick < 30 else 1.60)
        # All three attacks track the moving player through windup.
        player.global_position = boss.global_position + Vector3(
            x, 0.0, 7.7)
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            break
        var t: float = float(frame.get("time", 0.0))
        if t < active_timing - 0.02 and not bool(
                frame.get("tracking", false)):
            _fail(id + "/" + kind + ": lost live windup target")
            return false
        battle.call("_finalize_target_pose", DT)
        if tick == 0:
            for j in range(4):
                if j != i:
                    support_anchors[IK.LEG_PART_IDS[j]] = (
                        ik.get("legs")[j]["anchor"])
            first_offset = float(ik.get(
                "initial_attack_contact_height_world"))
            reference_offset = first_offset
            initial_chest = float(battle.get("bittaran_attack_body_yaw"))
            initial_head = float(battle.get("boss_head_yaw"))
            recorded_initial_head = true
            if kind != "stomp" and not is_finite(first_offset):
                _fail("non-finite initial height offset")
                return false
        for key in support_anchors:
            var leg_support: Dictionary = ik.get("legs")[
                IK.LEG_PART_IDS.find(key)]
            var goal: Vector3 = leg_support["last_goal"]
            var anchored: Vector3 = support_anchors[key]
            if Vector2(goal.x - anchored.x,
                    goal.z - anchored.z).length() > 0.0001:
                _fail(kind + ": support world anchor moved " + key)
                return false
        if kind != "stomp":
            var current_offset: float = float(
                ik.get("initial_attack_contact_height_world"))
            if absf(current_offset - reference_offset) > 0.00001:
                _fail(kind + ": recalculated height mid-motion")
                return false
            var real_sole: Vector3 = (
                leg["foot"] as Node3D).to_global(
                leg["sole_local"] as Vector3)
            if t >= active_timing - 0.009 and t <= active_timing + 0.009:
                # In v387 the rotated *mesh* corner that actually
                # touches the floor may differ from the v386 cached
                # sole-local point by nearly a metre. Check real mesh.
                var bottom: float = float(ik.call(
                    "_foot_mesh_lowest_y", leg["foot"]))
                near_floor = absf(bottom - IK.FLOOR_Y) < 0.11
                if not near_floor:
                    _fail(id + "/" + kind + ": initial mesh missed floor "
                        + str([bottom, real_sole.y, reference_offset]))
                    return false
            if t <= active_timing:
                var step_y: float = (rig as Node3D).position.y
                if absf(step_y - prior_body_y) > 0.24:
                    _fail(id + "/" + kind + ": prepose height jumped")
                    return false
                smooth_drop = true
                prior_body_y = step_y
        elif t >= 0.70 and t <= 0.76:
            # v419: compare the actual LIVE BODY-yawed limb to
            # the world reflection of the original front-left
            # Blockbench STOMP shoulder/knee. Calling the source
            # local helper AFTER IK incorrectly uses the already
            # yawed parent as its local reference and reports a
            # false mismatch even when the original WORLD pose
            # has been preserved.
            var body_src: Quaternion = rig.call(
                "_authored_key_rotation", rig.ATTACK_NAMES[kind],
                "Body", t)
            var world: Basis = rig.global_basis.orthonormalized()
            var root_q: Quaternion = world.get_rotation_quaternion()
            var source_world: Quaternion = (
                root_q * body_src).normalized()
            var authored_worlds: Array[Quaternion] = []
            for slot in range(2):
                var source_bone: String = str(
                    rig.ATTACK_LEG_BONES["leg_fl"][slot])
                var source_local: Quaternion = rig.call(
                    "_authored_key_rotation",
                    rig.ATTACK_NAMES[kind], source_bone, t)
                source_world = (
                    source_world * source_local).normalized()
                var reflected: Quaternion = source_world
                if id.ends_with("r"):
                    reflected = rig.call(
                        "_reflect_world_rotation",
                        reflected, world.x.normalized())
                if id.begins_with("leg_r"):
                    reflected = rig.call(
                        "_reflect_world_rotation",
                        reflected, world.z.normalized())
                var yaw_q: Quaternion = Quaternion(Vector3.UP,
                    float(frame.get("body_yaw", 0.0)))
                authored_worlds.append(
                    (yaw_q * reflected).normalized())
            var upper: Node3D = leg["upper"]
            var lower: Node3D = leg["lower"]
            mirrored_hip = (upper.global_basis
                .get_rotation_quaternion()).angle_to(
                    authored_worlds[0]) < 0.045
            mirrored_knee = (lower.global_basis
                .get_rotation_quaternion()).angle_to(
                    authored_worlds[1]) < 0.045
            saw_original_stomp = mirrored_hip and mirrored_knee
            authored_height = (
                leg["foot"] as Node3D).to_global(
                leg["sole_local"] as Vector3).y
    if not recorded_initial_head:
        _fail(id + ": attack did not initialize")
        return false
    if kind == "stomp" and not saw_original_stomp:
        _fail(id + ": authored stomp keys overwritten during windup "
            + str([mirrored_hip, mirrored_knee, authored_height]))
        return false
    if kind != "stomp" and (not near_floor or not smooth_drop):
        _fail(id + "/" + kind + ": failed starting sole floor alignment")
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var done: int = 0
    for kind in BRAIN.ATTACK_KINDS:
        for id in BRAIN.LEG_IDS:
            if not _case(battle, id, kind):
                return
            done += 1
    if done != 12:
        _fail("did not verify all 12 combinations")
        return
    print("GODOT_V386_BITTARAN_WINDUP_GROUND_PASS: 4 STOMP authored "
        + "windups retain real shoulder/knee keys, 8 KICK/SWEEP "
        + "first-frame soles touch ground with one-time height offset, "
        + "all attacks track SERA during windup; supports anchored")
    quit(0)
