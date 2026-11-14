extends SceneTree
## v373: slight head/arm mesh overlap is allowed; knee side-fold is
## capped at 30% of the old full fold, with no movement of planted soles.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V373_BITTARAN_MINIMAL_KNEE_FAIL: " + message)
    quit(1)

func _run() -> void:
    if absf(IK.HEAD_KNEE_MAX_BEND - 0.30) > 0.0001:
        _fail("head avoidance must not exceed 30% lateral knee bend")
        return
    if absf(IK.HEAD_KNEE_ALLOWED_PENETRATION_METERS - 0.30) > 0.00001:
        _fail("knee must permit 30cm of head/leg penetration")
        return
    if IK.HEAD_KNEE_MIN_BENEFIT_METERS < 0.025 or (
            IK.HEAD_KNEE_BEND_PENALTY_METERS < 0.080):
        _fail("knee movement must be discouraged for minor depth gains")
        return
    if absf(IK.STEP_DURATION_SECONDS - 0.58) > 0.00001:
        _fail("original swing duration changed")
        return
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if ik == null or boss == null or player == null:
        _fail("missing boss scene components")
        return
    var part: Dictionary = ik.get("legs")[0]
    var goal: Vector3 = part["last_goal"]
    var rotation: Quaternion = part["last_rotation"]
    var initial: float = float(part["head_knee_bend"])
    var root_before: Vector3 = boss.global_position
    part["head_knee_bend"] = 0.0
    var neutral_error: float = float(ik.call("_solve", part, goal, rotation))
    var neutral: Vector3 = (part["lower"] as Node3D).global_position
    part["head_knee_bend"] = IK.HEAD_KNEE_MAX_BEND
    var modest_error: float = float(ik.call("_solve", part, goal, rotation))
    var modest: Vector3 = (part["lower"] as Node3D).global_position
    part["head_knee_bend"] = 1.0
    var over_error: float = float(ik.call("_solve", part, goal, rotation))
    var over: Vector3 = (part["lower"] as Node3D).global_position
    if modest.distance_to(neutral) <= 0.010:
        _fail("bounded lateral knee fold had no visible influence")
        return
    if modest.distance_to(over) > 0.0015:
        _fail("even an excessive bend request exceeded the 30% clamp")
        return
    if modest_error > maxf(0.20, neutral_error + 0.015) or (
            over_error > maxf(0.20, neutral_error + 0.015)):
        _fail("minimal knee bend broke the planted toe contact")
        return
    if boss.global_position.distance_to(root_before) > 0.00001:
        _fail("minimal knee bend moved the torso root")
        return
    part["head_knee_bend"] = initial
    ik.call("_solve", part, goal, rotation)
    # Full recovery-to-turn path: the auto selector may ask for any bend,
    # but it must remain tiny even when the player moves across both sides.
    battle.set("locked_target_part_id", "leg_fl")
    var hit: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(hit.get("broken", false)):
        _fail("could not trigger boss fall")
        return
    var saw_recovered: bool = false
    for frame in range(540):
        player.global_position = boss.global_position + (
            boss.global_basis.x * 24.0 if frame % 120 < 60
            else -boss.global_basis.x * 24.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if bool(ik.call("locomotion_ready")):
            saw_recovered = true
        for leg in ik.get("legs"):
            var bend: float = float(leg["head_knee_bend"])
            var target: float = float(leg["head_knee_target"])
            if bend > IK.HEAD_KNEE_MAX_BEND + 0.0001 or (
                    target > IK.HEAD_KNEE_MAX_BEND + 0.0001):
                _fail("auto knee fold exceeded the subtle bending cap")
                return
    if not saw_recovered:
        _fail("never finished standing to exercise head turning")
        return
    print("GODOT_V373_BITTARAN_MINIMAL_KNEE_PASS: knee bend <= 30%, "
        + "mild overlap accepted, stable sole/root, head tracking tested")
    quit(0)
