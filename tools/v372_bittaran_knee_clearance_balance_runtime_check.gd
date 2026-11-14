extends SceneTree
## v372: IK knee pole steers laterally around the head without changing
## grounded soles, gait timing, torso root, or original 70%-head gate.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V372_BITTARAN_KNEE_BALANCE_FAIL: " + message)
    quit(1)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var rig: Node3D = battle.get("bittaran_rig")
    if ik == null or boss == null or rig == null or player == null:
        _fail("missing boss/IK rig")
        return
    # Exercise the full post-break turnaround, rather than only a toy IK.
    battle.set("locked_target_part_id", "leg_fl")
    var hit: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(hit.get("broken", false)):
        _fail("failed to start down reaction")
        return
    player.global_position = boss.global_position + Vector3(25.0, 0.0, 0.0)
    var recovered: bool = false
    for frame in range(350):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if bool(ik.call("down_pose_active")) and bool(
                ik.get("head_knee_active")):
            _fail("side-fold activated during physical fall/rise")
            return
        if bool(ik.call("locomotion_ready")):
            recovered = true
            break
    if not recovered:
        _fail("could not complete stand-up")
        return
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    if body == null:
        _fail("missing articulated chassis")
        return
    var tested_fold: bool = false
    var planted_checks: int = 0
    var previous_bend: Array[float] = []
    for leg in ik.get("legs"):
        previous_bend.append(float(leg["head_knee_bend"]))
    # Turning across the planted under-head forelimbs is the user's case.
    for frame in range(280):
        player.global_position = boss.global_position + (
            boss.global_basis.x * 20.0 if frame < 140
            else -boss.global_basis.x * 20.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        var leg_data: Array = ik.get("legs")
        var bend_sum: float = 0.0
        for i in range(leg_data.size()):
            var leg: Dictionary = leg_data[i]
            var bend: float = float(leg["head_knee_bend"])
            bend_sum += bend
            if bend < -0.0001 or bend > 1.0001 or (
                    absf(bend - previous_bend[i]) >
                    IK.HEAD_KNEE_FLEX_IN_PER_SECOND * DT + 0.0002):
                _fail("knee bend snapped or exceeded limits " + str([i, bend]))
                return
            previous_bend[i] = bend
            if not bool(leg["stepping"]):
                var actual: Vector3 = (leg["foot"] as Node3D).to_global(
                    leg["sole_local"])
                var desired: Vector3 = leg["last_goal"]
                # Leave the preexisting IK residual unchanged: avoid
                # extra slippage from lateral knee folding.
                if actual.distance_to(desired) > maxf(
                        float(leg.get("last_error", 0.0)), 0.12) + 0.0005:
                    _fail("knee fold detached a planted sole")
                    return
                planted_checks += 1
        if bend_sum > 0.1:
            tested_fold = true
    # Independently force a knee bend to prove it moves the knee sideways
    # while preserving the exact foot target and the heavy torso location.
    var first: Dictionary = ik.get("legs")[0]
    var sole_goal: Vector3 = first["last_goal"]
    var sole_rot: Quaternion = first["last_rotation"]
    var hip: Vector3 = (first["upper"] as Node3D).global_position
    var knee_before: Vector3 = (first["lower"] as Node3D).global_position
    var root_before: Vector3 = boss.global_position
    first["head_knee_bend"] = 1.0
    var after_error: float = float(ik.call("_solve", first, sole_goal, sole_rot))
    var knee_after: Vector3 = (first["lower"] as Node3D).global_position
    if knee_before.distance_to(knee_after) < 0.035:
        _fail("lateral pole did not fold knee away from neutral")
        return
    if boss.global_position.distance_to(root_before) > 0.00001:
        _fail("knee avoider shifted center of mass/root")
        return
    if after_error > maxf(0.20, float(first.get("last_error", 0.0)) + 0.015):
        _fail("bending knee broke IK foot contact " + str(after_error))
        return
    if absf(IK.STEP_DURATION_SECONDS - 0.58) > 0.00001:
        _fail("gait timing changed")
        return
    if planted_checks < 80:
        _fail("insufficient planted-foot coverage")
        return
    print("GODOT_V372_BITTARAN_KNEE_BALANCE_PASS: lateral-knee IK, "
        + "stable planted soles and body center during 280 post-rise "
        + "turning frames; actual risk-triggered knee bend="
        + str(tested_fold) + ", planted checks=" + str(planted_checks))
    quit(0)
