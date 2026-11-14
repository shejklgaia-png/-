extends SceneTree
## v347: double-sized collision + visuals, crouch measurable against same-scale
## unmodified authored pose, deeper knees and grounded toe accuracy.
const FLOOR_ERROR_LIMIT: float = 0.10

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V347_BITTARAN_SIZE_CROUCH_FAIL: " + reason)
    quit(1)

func _reach_ratio(upper: Node3D, knee: Node3D, ankle: Node3D) -> float:
    var a: float = upper.global_position.distance_to(knee.global_position)
    var b: float = knee.global_position.distance_to(ankle.global_position)
    return upper.global_position.distance_to(ankle.global_position) / maxf(a+b, 0.0001)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("battle scene load")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var target: Node3D = battle.get("target")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var collision: AnimatableBody3D = battle.get("target_collider")
    if target == null or rig == null or ik == null or collision == null:
        _fail("missing scaled target/rig/IK/collider")
        return
    if not target.scale.is_equal_approx(Vector3.ONE * 2.0):
        _fail("boss is not double-sized")
        return
    if not collision.global_basis.get_scale().is_equal_approx(Vector3.ONE * 2.0):
        _fail("movement collision did not double with the rig")
        return

    # A separate untouched rig is aligned with the floor at *the same* 2x
    # target scale, making the chassis and knee-angle comparisons meaningful.
    var rig_script: GDScript = load("res://scripts/bittaran_rig.gd") as GDScript
    var authored: Node3D = rig_script.new()
    authored.name = "AuthoredPoseReference"
    authored.rotation.y = PI
    authored.position.y = -1.12
    target.add_child(authored)
    var sum_sole_y: float = 0.0
    for name in ["FrontFoot_R", "RearFoot_L", "FrontFoot_L", "RearFoot_R"]:
        var foot: Node3D = authored.find_child(name, true, false) as Node3D
        if foot == null:
            _fail("reference foot missing: " + name)
            return
        var sole_local: Vector3 = ik.call("_sole_local_point", foot)
        sum_sole_y += foot.to_global(sole_local).y / 4.0
    authored.position.y -= sum_sole_y / maxf(target.scale.y, 0.001)
    var body_reference: Node3D = authored.find_child("Body", true, false) as Node3D
    var body_current: Node3D = rig.find_child("Body", true, false) as Node3D
    var chassis_drop: float = body_reference.global_position.y - body_current.global_position.y
    if chassis_drop < 0.32 or chassis_drop > 0.36:
        _fail("crouch height not applied in world metres: " + str(chassis_drop))
        return

    var bigger_bends: int = 0
    var ratio_before_sum: float = 0.0
    var ratio_after_sum: float = 0.0
    for region in ["Front", "Rear"]:
        for suffix in ["_R", "_L"]:
            var upper_name: String = region + "Leg" + suffix
            var knee_name: String = region + "LowerLeg" + suffix
            var ankle_name: String = region + "Foot" + suffix
            var upper: Node3D = rig.find_child(upper_name, true, false) as Node3D
            var knee: Node3D = rig.find_child(knee_name, true, false) as Node3D
            var ankle: Node3D = rig.find_child(ankle_name, true, false) as Node3D
            var old_upper: Node3D = authored.find_child(upper_name, true, false) as Node3D
            var old_knee: Node3D = authored.find_child(knee_name, true, false) as Node3D
            var old_ankle: Node3D = authored.find_child(ankle_name, true, false) as Node3D
            var previous: float = _reach_ratio(old_upper, old_knee, old_ankle)
            var actual: float = _reach_ratio(upper, knee, ankle)
            ratio_before_sum += previous
            ratio_after_sum += actual
            if actual < previous - 0.005:
                bigger_bends += 1
            var sole_world: Vector3 = Vector3.ZERO
            for leg in ik.get("legs"):
                if leg["upper"] == upper:
                    sole_world = (leg["foot"] as Node3D).to_global(leg["sole_local"])
                    break
            if absf(sole_world.y) > FLOOR_ERROR_LIMIT:
                _fail("sole detached from floor: " + upper_name + " " + str(sole_world.y))
                return
    var before_avg: float = ratio_before_sum / 4.0
    var after_avg: float = ratio_after_sum / 4.0
    print("V347_BEND_MEASURE before=" + str(before_avg)
        + " after=" + str(after_avg)
        + " increased=" + str(bigger_bends)
        + " chassis_drop=" + str(chassis_drop))
    if bigger_bends != 4 or after_avg >= before_avg - 0.005:
        _fail("new knees not measurably more folded")
        return
    if float(ik.call("maximum_ground_error")) > FLOOR_ERROR_LIMIT:
        _fail("scaled IK cannot plant toes")
        return
    print("GODOT_V347_BITTARAN_PASS: 2x boss/collision, lower center, 4 deeper knees, grounded soles")
    quit(0)
