extends SceneTree
## v401: Bittaran weight and technique identity.
## 1) Technique selection is situational: STOMP right at a foot, KICK
##    beyond the foot, SWEEP off to its side, and the previous kind is
##    never repeated through the situational path.
## 2) Locomotion carries a gait weight shift: the chassis dips while a
##    diagonal pair is airborne, the roll alternates with the pairs,
##    planted soles stay on the floor, and every term decays to zero
##    when locomotion stops.
## 3) A STOMP impact raises a camera shake that decays back to
##    exactly zero frustum offset.
const Attacks = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0
const FEET: Dictionary = {
    "leg_fl": Vector3(-2.2, 0.0, 2.6),
    "leg_fr": Vector3(2.2, 0.0, 2.6),
    "leg_rl": Vector3(-2.2, 0.0, -2.6),
    "leg_rr": Vector3(2.2, 0.0, -2.6),
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V401_BITTARAN_WEIGHT_FEEL_FAIL: " + message)
    quit(1)

func _select_kind(brain: RefCounted, player_position: Vector3) -> String:
    for tick in range(60 * 3):
        brain.call("advance", DT, player_position, FEET, true,
            Vector3.INF, true)
        if bool(brain.call("is_active")):
            return str(brain.get("kind"))
    return ""

func _check_selection() -> bool:
    var brain: RefCounted = Attacks.new()
    var kind: String = _select_kind(brain, Vector3(-1.2, 0.0, 3.6))
    if kind != "stomp":
        _fail("player at a foot should draw STOMP, got " + kind)
        return false
    brain = Attacks.new()
    kind = _select_kind(brain, Vector3(5.43, 0.0, 6.42))
    if kind != "kick":
        _fail("player beyond a foot should draw KICK, got " + kind)
        return false
    brain = Attacks.new()
    kind = _select_kind(brain, Vector3(-5.8, 0.0, 0.6))
    if kind != "sweep":
        _fail("player beside a foot should draw SWEEP, got " + kind)
        return false
    # Anti-repeat: the same stomp geometry twice in a row must rotate.
    brain = Attacks.new()
    kind = _select_kind(brain, Vector3(-1.2, 0.0, 3.6))
    if kind != "stomp":
        _fail("anti-repeat setup expected STOMP, got " + kind)
        return false
    var second: String = ""
    var was_active: bool = true
    for tick in range(60 * 12):
        brain.call("advance", DT, Vector3(-1.2, 0.0, 3.6), FEET, true,
            Vector3.INF, true)
        var active: bool = bool(brain.call("is_active"))
        if was_active and not active:
            was_active = false
        elif not was_active and active:
            second = str(brain.get("kind"))
            break
    if second != "kick":
        _fail("repeated stomp geometry should rotate to KICK, got "
            + second)
        return false
    return true

func _run() -> void:
    if not _check_selection():
        return
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var actor: Node3D = ik.get("actor")
    var rest_y: float = actor.position.y
    player.global_position = boss.global_position + Vector3(0.0, 0.0, 24.0)
    var max_dip: float = 0.0
    var roll_by_pair: Array = [0.0, 0.0]
    var roll_by_pair_n: Array = [0.0, 0.0]
    var max_sole_error: float = 0.0
    var approach_frames: int = 0
    for frame in range(600):
        battle.set("player_hp", 9999.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if str(battle.get("bittaran_motion")) != "Approach" \
                or brain.call("is_active"):
            continue
        approach_frames += 1
        max_dip = maxf(max_dip, float(ik.get("gait_dip")))
        var pair: int = int(ik.get("stepping_pair"))
        if pair == 0 or pair == 1:
            roll_by_pair[pair] += float(ik.get("gait_sway_roll"))
            roll_by_pair_n[pair] += 1.0
        for leg in ik.get("legs"):
            if bool(leg["stepping"]):
                continue
            var foot: Node3D = leg["foot"]
            var sole: Vector3 = foot.to_global(leg["sole_local"])
            max_sole_error = maxf(max_sole_error, absf(sole.y))
    if approach_frames < 200:
        _fail("approach was not exercised: " + str(approach_frames))
        return
    if max_dip < 0.02:
        _fail("chassis never dipped under way: max " + str(max_dip))
        return
    var mean0: float = roll_by_pair[0] / maxf(roll_by_pair_n[0], 1.0)
    var mean1: float = roll_by_pair[1] / maxf(roll_by_pair_n[1], 1.0)
    if not (mean0 > 0.005 and mean1 < -0.005):
        _fail("gait roll does not alternate with the pairs: "
            + str([mean0, mean1]))
        return
    if max_sole_error > 0.015:
        _fail("sway lifted a planted sole by " + str(max_sole_error))
        return
    for frame in range(240):
        ik.call("advance_ik", DT, "Idle")
    if absf(float(ik.get("gait_sway_roll"))) > 0.002 \
            or absf(float(ik.get("gait_sway_pitch"))) > 0.002 \
            or float(ik.get("gait_dip")) > 0.002 \
            or absf(actor.position.y - rest_y) > 0.002:
        _fail("gait sway did not decay to zero at rest")
        return
    # Impact shake: a real STOMP slam must raise it, and it must
    # settle back to exactly zero camera offset.
    player.global_position = boss.global_position + Vector3(0.0, 0.0, 5.0)
    for frame in range(30):
        battle.set("player_hp", 9999.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
    brain.call("force_start_with_stance", "leg_fl", "stomp")
    var shook: bool = false
    for frame in range(60 * 8):
        battle.set("player_hp", 9999.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if float(battle.get("impact_shake_strength")) > 0.01:
            shook = true
            break
    if not shook:
        _fail("STOMP impact produced no camera shake")
        return
    var camera: Camera3D = battle.get("camera")
    for frame in range(120):
        battle.call("_tick_impact_shake", DT)
    if float(battle.get("impact_shake_strength")) != 0.0 \
            or camera.h_offset != 0.0 or camera.v_offset != 0.0:
        _fail("camera shake did not settle to exactly zero")
        return
    print("GODOT_V401_BITTARAN_WEIGHT_FEEL_PASS: situational technique "
        + "selection, alternating gait weight shift (max dip "
        + str(max_dip) + ", sole error " + str(max_sole_error)
        + ") and decaying stomp impact shake verified")
    quit(0)
