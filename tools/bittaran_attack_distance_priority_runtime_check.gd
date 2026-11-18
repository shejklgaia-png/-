extends SceneTree
## v460: source attack TYPE and STRIKING LEG use the same current
## post-IK physical sole on the XZ ground plane, never boss center.
## Validate synthetic feet and real walking-gated attacks.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const AI = preload("res://scripts/bittaran_ai.gd")
const DT: float = 1.0 / 60.0
const FEET: Dictionary = {
    "leg_fl": Vector3(-1.0, 0, 1.0),
    "leg_fr": Vector3(1.0, 0, 1.0),
    "leg_rl": Vector3(-1.0, 0, -1.0),
    "leg_rr": Vector3(1.0, 0, -1.0)
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("BITTARAN_DISTANCE_PRIORITY_FAIL " + reason)
    quit(1)


func _kind(player: Vector3, feet: Dictionary = FEET,
        yaw: float = 0.0) -> String:
    return str(ATTACKS.new().call(
        "_choose_kind", player, feet, yaw))


func _verify_synthetic() -> bool:
    # Same POSITION relative to body yields a completely different
    # attack when only the feet are moved. These checks must fail if
    # the selector accidentally measures the torso-to-player range.
    var test_cases: Array = [
        # Player / 4 sole anchors / expected kind
        [Vector3(1, 0, 2.0), FEET, "stomp"],
        [Vector3(0, 0, 0), FEET, "stomp"],
        [Vector3(1, 0, 5.0), FEET, "kick"],
        [Vector3(0, 0, 5.0), FEET, "kick"],
        [Vector3(1, 0, 4.74), {"leg_fr": Vector3(1, 0, 1)}, "sweep"],
        [Vector3(1, 0, 4.75), {"leg_fr": Vector3(1, 0, 1)}, "kick"],
        [Vector3(1, 0, 6.14), FEET, "kick"],
        [Vector3(1, 0, 6.17), FEET, "sweep"],
        [Vector3(5.6, 0, 1.0), FEET, "sweep"],
        [Vector3(-5.6, 0, 1.0), FEET, "sweep"],
        [Vector3(1.0, 0, -2.0), FEET, "stomp"],
        [Vector3(0, 0, -4.0), FEET, "sweep"],
        [Vector3(0, 0, -10.0), FEET, ""],
        [Vector3(1, 0, 2.0), {
            "leg_fl": Vector3(30, 0, 30),
            "leg_fr": Vector3(30, 0, 30),
            "leg_rl": Vector3(30, 0, 30),
            "leg_rr": Vector3(30, 0, 30)}, ""],
        [Vector3(25, 0, 0), {
            "leg_fl": Vector3(24, 0, 0),
            "leg_fr": Vector3(24, 0, 0),
            "leg_rl": Vector3(24, 0, 0),
            "leg_rr": Vector3(24, 0, 0)}, "stomp"],
        [Vector3(1, 0, 5.0), {
            "leg_fl": Vector3(30, 0, 30),
            "leg_fr": Vector3(30, 0, 30),
            "leg_rl": Vector3(30, 0, 30),
            "leg_rr": Vector3(1, 0, 1)}, "sweep"],
    ]
    for row in test_cases:
        var got: String = _kind(row[0], row[1])
        if got != str(row[2]):
            _fail("foot-local kind selection " + str([row, got]))
            return false
    # rear legs MUST NOT invent KICK from the front-leg-only source clip.
    var rear_only: Dictionary = {
        "leg_rl": Vector3(-1, 0, -1),
        "leg_rr": Vector3(1, 0, -1)
    }
    if _kind(Vector3(1, 0, 3), rear_only) == "kick":
        _fail("rear leg illegally chose nonexistent KICK")
        return false
    # Check selected leg's toe-XZ distance, not body range or goal.
    var director: RefCounted = ATTACKS.new()
    var selected: String = director.call("_choose_leg",
        Vector3(1, 0, 2), FEET, "stomp", Vector3(100, 0, 100), 0.0)
    if selected != "leg_fr":
        _fail("selected wrong physical foot " + selected)
        return false
    return true


func _verify_live_first(start_distance: float) -> bool:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    scene.set("target_move_enabled", true)
    scene.set("player_hp", 99999.0)
    var boss: Node3D = scene.get("target")
    var player: CharacterBody3D = scene.get("player")
    var ik: RefCounted = scene.get("bittaran_foot_ik")
    if boss == null or player == null or ik == null:
        _fail("live boss/IK unavailable")
        return false
    boss.rotation.y = 0.0
    player.global_position = boss.global_position + Vector3(
        0.0, 0.0, start_distance)
    var frame: Dictionary = {}
    var walked: int = 0
    var feet: Dictionary = {}
    for tick in range(1700):
        scene.set("player_hp", 99999.0)
        scene.call("_advance_target_motion", DT)
        frame = scene.get("bittaran_attack_frame")
        if not frame.is_empty() and str(frame.get("phase", "")) == "entry":
            walked = int(ik.call("source_completed_walk_steps"))
            feet = scene.call("_bittaran_attack_candidates")
            break
        scene.call("_finalize_target_pose", DT)
    if frame.is_empty():
        _fail("attack not selected after gait from " + str(start_distance))
        return false
    var id: String = str(frame.get("id", ""))
    var kind: String = str(frame.get("kind", ""))
    var foot: Vector3 = frame.get(
        "selection_foot_world", Vector3.INF)
    var legal: bool = is_finite(foot.x) and (
        ATTACKS._leg_can_reach(
            kind, id, player.global_position, foot, boss.rotation.y))
    print("DISTANCE_PRIORITY_LIVE start=", start_distance,
        " kind=", kind, " leg=", id, " walked=", walked,
        " toe_to_player=", Vector2(
            player.global_position.x - foot.x,
            player.global_position.z - foot.z).length())
    scene.queue_free()
    if walked < 3 or not legal:
        _fail("attack launched from illegal toe range " + str(
            [start_distance, kind, id, walked, foot]))
        return false
    return true


func _run() -> void:
    if absf(ATTACKS.STOMP_RANGE_METERS - 3.0) > 0.0001 or (
            absf(ATTACKS.KICK_MIN_RANGE_METERS - 3.75) > 0.0001):
        _fail("existing approved attack distances changed")
        return
    if not _verify_synthetic():
        return
    if not _verify_live_first(2.5):
        return
    if not _verify_live_first(4.35):
        return
    print("GODOT_BITTARAN_FOOT_DISTANCE_PRIORITY_PASS ",
        "attack_range_from_each_real_sole=true ",
        "3_walk_steps_before_attack=true ",
        "front_only_kick=true no_body_distance=true")
    quit(0)
