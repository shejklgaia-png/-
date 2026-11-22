extends SceneTree
## SERA v534: source-time velocity, four real grounded toe meshes,
## Rear fall FX at source 0.75, front FX at 1.75; both DOWN timers at 1.75.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const CONTACT: float = 1.75
const TOL: float = 0.085

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_V534_DOWN_FAIL: " + message)
    quit(1)

func _step(battle: Node3D) -> void:
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)

func _check_speeds(ik: RefCounted) -> bool:
    var at: Array[float] = [0.0, 0.25, 0.5, 0.55, 0.6, 1.0, 1.75]
    var value: Array[float] = []
    for t in at:
        value.append(float(ik.call("authored_down_speed", t)))
    if absf(value[0] - 1.0) > 0.000001 or absf(
            value[2] - 0.30) > 0.000001 or absf(
            value[3] - 0.30) > 0.000001 or absf(
            value[4] - 0.30) > 0.000001 or absf(
            value[6] - 0.55) > 0.000001:
        _fail("approved authored-source speed anchors changed: " + str(value))
        return false
    if not (value[0] > value[1] and value[1] > value[2]
            and value[4] < value[5] and value[5] < value[6]):
        _fail("0-.5 must decelerate and .6-1.75 must accelerate")
        return false
    return true

func _check_case(battle: Node3D, id: String,
        full_break: bool) -> bool:
    battle.call("_reset_target_after_respawn")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var parts: Node3D = battle.get("target_parts")
    var fx: Node3D = battle.get("bittaran_dirt_fx")
    if not _check_speeds(ik):
        return false
    if bool(ik.call("windup_active")) or bool(
            ik.call("down_pose_active")):
        _fail("new boss encounter retained previous collapse timer")
        return false
    var head: Vector3 = parts.call("get_part_aim_world", "head")
    ik.call("start_leg_break_slide", id, head.y, full_break)
    if not bool(ik.call("windup_active")) or bool(
            ik.call("down_pose_active")):
        _fail("source motion must start immediately, timer not started")
        return false
    if absf(float(ik.call("authored_down_motion_time"))) > 0.000001:
        _fail("down animation did not start from source t=0")
        return false
    var previous: float = -0.001
    var fell_frames: int = 0
    var contact_once: bool = false
    for frame in range(520):
        _step(battle)
        var t: float = float(ik.call("authored_down_motion_time"))
        if t + 0.000001 < previous or t > CONTACT + 0.000001:
            _fail("source clock rewound or overshot 1.75: " + str(t))
            return false
        previous = t
        var fx_time: float = (IK.DOWN_REAR_FX_SOURCE_SECONDS
            if id.begins_with("leg_r") else IK.DOWN_FRONT_FX_SOURCE_SECONDS)
        var expected_bursts: int = 1 if t + 0.000001 >= fx_time else 0
        if int(fx.get("body_fall_burst_count")) != expected_bursts:
            _fail("wrong source-key dust time for " + id
                + " at " + str(t) + " expected " + str(fx_time))
            return false
        if bool(ik.call("windup_active")):
            fell_frames += 1
            if bool(ik.call("down_pose_active")):
                _fail("down timer started before 1.75 authored contact")
                return false
            # Every foot tip should contact the physical floor. Never
            # bury a mesh or let a toe float during the falling animation.
            for leg in ik.get("legs"):
                var y: float = float(ik.call(
                    "_source_ik_sweep_toe_lowest_world_y", leg))
                if not is_finite(y) or absf(y) > TOL:
                    _fail("toe not on floor while falling " + id
                        + " at " + str([t, leg["upper"].name, y,
                        leg.get("last_error", -1.0),
                        (leg["upper"] as Node3D).global_position,
                        (leg["foot"] as Node3D).global_position,
                        leg["anchor"], leg["last_goal"]]))
                    return false
        else:
            if not bool(ik.call("down_pose_active")):
                _fail("down timer never began at contact")
                return false
            if absf(t - CONTACT) > 0.000001:
                _fail("contact pose must hold at exactly t=1.75")
                return false
            contact_once = true
            break
    if not contact_once or fell_frames < 140:
        _fail("1.75 source was not played at slowed speeds")
        return false
    if int(fx.get("body_fall_burst_count")) != 1:
        _fail("body impact dust must emit once at its front/rear source FX key")
        return false
    var hold: float = IK.ALL_LEGS_BREAK_REACTION_SECONDS if full_break         else IK.LEG_BREAK_REACTION_SECONDS
    if absf(float(ik.get("break_recover_start")) - hold) > 0.00001:
        _fail("approved 2.5/6.0-second DOWN hold changed")
        return false
    var body: Node3D = rig.find_child("Body", true, false)
    var saved: Transform3D = body.transform
    for frame in range(int(hold / DT) - 2):
        _step(battle)
        if float(ik.call("standup_pose_fraction")) > 0.000001:
            _fail("BODY rose before the 2.5/6s timer ended")
            return false
        if body.position.distance_to(saved.origin) > 0.008:
            _fail("BODY did not hold author's 1.75 second pose")
            return false
    var replant_started: bool = false
    var replant_both_pairs: bool = false
    var first_replant: int = -1
    var chest_held: bool = true
    for frame in range(170):
        _step(battle)
        var pair: int = int(ik.get("authored_down_replant_pair"))
        if pair >= 0:
            replant_started = true
            if first_replant < 0:
                first_replant = pair
            elif pair != first_replant:
                replant_both_pairs = true
            if float(ik.call("standup_pose_fraction")) > 0.000001:
                _fail("BODY lifted before both diagonal pairs replanted")
                return false
            if body.position.distance_to(saved.origin) > 0.008:
                chest_held = false
        if float(ik.call("standup_pose_fraction")) > 0.001:
            break
    if not replant_started or not replant_both_pairs or not chest_held:
        _fail("no two diagonal replant steps before torso lift")
        return false
    print("V534_DOWN_CONTACT_CASE_PASS ", id,
        " frames=", fell_frames, " hold=", hold)
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        if not _check_case(battle, str(id), id == "leg_rr"):
            return
    print("GODOT_V534_DOWN_PACING_GROUND_REPLANT_PASS")
    quit(0)
