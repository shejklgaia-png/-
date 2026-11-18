extends SceneTree
## Live combat-director regression: consecutive attack TYPES must differ.
## Preserve sector limits and require purposeful repositioning rather
## than swapping to an attack that is illegal at the current bearing.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const AI = preload("res://scripts/bittaran_ai.gd")
const FEET: Dictionary = {
    "leg_fl": Vector3(-1.0, 0.0, 1.0),
    "leg_fr": Vector3(1.0, 0.0, 1.0),
    "leg_rl": Vector3(-1.0, 0.0, -1.0),
    "leg_rr": Vector3(1.0, 0.0, -1.0)
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_ATTACK_VARIATION_FAIL " + message)
    quit(1)

func _try_attack(director: RefCounted, player: Vector3) -> Dictionary:
    return director.call(
        "advance", 0.05, player, FEET, true, Vector3.INF,
        false, Vector3.ZERO, 0.0)

func _run() -> void:
    var director: RefCounted = ATTACKS.new()
    var movement: RefCounted = AI.new()
    var stomp_player: Vector3 = Vector3(0.0, 0.0, 2.0)
    var kick_player: Vector3 = Vector3(0.0, 0.0, 4.0)
    var sweep_player: Vector3 = Vector3(6.0, 0.0, 0.0)
    var cases: Array = [
        [stomp_player, "stomp"],
        [kick_player, "kick"],
        [sweep_player, "sweep"],
        [stomp_player, "stomp"]
    ]
    var begun: Array[String] = []
    for item in cases:
        var player: Vector3 = item[0]
        var expected: String = str(item[1])
        if bool(director.call(
                "repeat_kind_blocked", player, Vector3.ZERO, 0.0)):
            _fail("new sector must be available " + expected)
            return
        var attack: Dictionary = _try_attack(director, player)
        if str(attack.get("kind", "")) != expected or (
                not ATTACKS.LEG_IDS.has(str(attack.get("id", "")))):
            _fail("wrong legal attack: " + str([expected, attack]))
            return
        begun.append(expected)
        # Canceled hits must still count as the most recent selected kind:
        # different feet cannot bypass the anti-repeat guarantee.
        director.call("cancel")
        if not bool(director.call(
                "repeat_kind_blocked", player, Vector3.ZERO, 0.0)):
            _fail("repeated kind was not blocked " + expected)
            return
        var repeat: Dictionary = _try_attack(director, player)
        if not repeat.is_empty() or bool(director.call("is_active")):
            _fail("same kind repeated " + str([expected, repeat]))
            return
        var forced_walk: Dictionary = movement.call(
            "advance", 0.10, Vector3.ZERO, 0.0, player, false, true)
        if str(forced_walk.get("motion", "")) != "Approach" or (
                (forced_walk["position"] as Vector3)
                .distance_to(Vector3.ZERO) <= 0.000001):
            _fail("blocked attack did not reposition " + expected)
            return
    if begun != ["stomp", "kick", "sweep", "stomp"]:
        _fail("unexpected alternation " + str(begun))
        return
    director.call("reset")
    if bool(director.call("repeat_kind_blocked",
            stomp_player, Vector3.ZERO, 0.0)):
        _fail("new encounter retained previous attack history")
        return
    var first_after_reset: Dictionary = _try_attack(
        director, stomp_player)
    if str(first_after_reset.get("kind", "")) != "stomp":
        _fail("reset prevented first attack")
        return
    print("GODOT_BITTARAN_ATTACK_VARIATION_PASS ",
        "sequence=stomp,kick,sweep,stomp ",
        "same_type_consecutive=false ",
        "sector_limits_preserved=true ",
        "blocked_move_repositions=true ",
        "cancel_remembers_last=true reset_clears_last=true")
    quit(0)
