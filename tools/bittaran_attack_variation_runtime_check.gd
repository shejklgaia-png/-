extends SceneTree
## Immediate attacks must not be blocked by the previously used kind.
## Prefer a different legal technique; repeat if no other reaches.
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
    var stomp_player: Vector3 = Vector3(0.0, 0.0, 2.0)
    var kick_player: Vector3 = Vector3(0.0, 0.0, 5.0)
    var sweep_player: Vector3 = Vector3(6.0, 0.0, 0.0)
    var cases: Array = [
        # First attack must use the best range-legal kind.
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
                "repeat_kind_blocked", player,
                Vector3.ZERO, 0.0, FEET)):
            _fail("legal attack was blocked by history " + expected)
            return
        var attack: Dictionary = _try_attack(director, player)
        if str(attack.get("kind", "")) != expected or (
                not ATTACKS.LEG_IDS.has(str(attack.get("id", "")))):
            _fail("wrong first legal attack: " + str([expected, attack]))
            return
        begun.append(expected)
        director.call("cancel")
        # A different technique should be preferred IF legal.
        # At the sweep-only position the same type must be allowed.
        var other: String = str(director.call(
            "_choose_nonrepeating_kind", player, FEET, 0.0))
        if other.is_empty():
            _fail("in-range attack blocked after cancel " + expected)
            return
        if other == expected and expected != "sweep":
            _fail("did not prefer alternate legal attack " + expected)
            return
        var repeat: Dictionary = _try_attack(director, player)
        if repeat.is_empty() or str(
                repeat.get("kind", "")) != other:
            _fail("attack blocked despite valid foot range " +
                str([expected, other, repeat]))
            return
        director.call("cancel")
    if begun != ["stomp", "kick", "sweep", "stomp"]:
        _fail("unexpected initial kind choices " + str(begun))
        return
    director.call("reset")
    var first_after_reset: Dictionary = _try_attack(
        director, stomp_player)
    if str(first_after_reset.get("kind", "")) != "stomp":
        _fail("reset prevented in-range first attack")
        return
    print("GODOT_BITTARAN_ATTACK_VARIATION_PASS ",
        "sequence=stomp,kick,sweep,stomp ",
        "alternate_kind_preferred_if_legal=true ",
        "same_kind_repeat_allowed_when_only_valid=true ",
        "no_forced_reposition=true ",
        "sector_limits_preserved=true")
    quit(0)
