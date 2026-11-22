extends SceneTree
## Independent activation envelope, edge conditions, and legal selection
## on real Godot attack director. Do not enlarge physical hit colliders.
const A = preload("res://scripts/bittaran_attacks.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("BITTARAN_KICK_SELECTION_V541_FAIL " + reason)
    quit(1)

func _pos(distance: float, angle: float) -> Vector3:
    var radians: float = deg_to_rad(angle)
    return Vector3(sin(radians) * distance, 0.0,
        cos(radians) * distance)

func _check_one(id: String, distance: float, angle: float,
        kick_allowed: bool) -> bool:
    var player: Vector3 = _pos(distance, angle)
    var foot: Vector3 = Vector3.ZERO
    var got: bool = A._leg_can_reach("kick", id, player, foot, 0.0)
    if got != kick_allowed:
        _fail("kick envelope " + str([id, distance, angle, got,
            kick_allowed]))
        return false
    return true

func _run() -> void:
    if absf(A.KICK_MIN_RANGE_METERS - 3.10) > 0.00001 or (
            absf(A.KICK_RANGE_METERS - 6.30) > 0.00001) or (
            absf(A.KICK_HALF_ANGLE_DEGREES - 60.0) > 0.00001):
        _fail("expanded activation specification changed")
        return
    for leg in ["leg_fl", "leg_fr"]:
        for distance in [3.11, 3.25, 4.50, 5.15, 6.29]:
            for angle in [-59.5, -40.0, 0.0, 40.0, 59.5]:
                if not _check_one(leg, distance, angle, true):
                    return
        for outside in [
                [3.09, 0.0], [6.31, 0.0],
                [4.50, -60.5], [4.50, 60.5]]:
            if not _check_one(
                    leg, float(outside[0]), float(outside[1]), false):
                return
        # Both near and far edge are physically reachable by the live
        # selector, but outside them SWEEP (or STOMP if close) is legal.
        var one: Dictionary = {}
        one[leg] = Vector3.ZERO
        var director: RefCounted = A.new()
        # KICK remains eligible inside the new front STOMP range,
        # but STOMP has always been prioritized there.
        for pair in [[3.71, -59.0], [6.29, 59.0], [4.50, 0.0]]:
            var kind: String = str(director.call(
                "_choose_kind", _pos(float(pair[0]), float(pair[1])),
                one, 0.0))
            if kind != "kick":
                _fail("expanded kick not preferred over sweep "
                    + str([leg, pair, kind]))
                return
        var close_kind: String = str(director.call(
            "_choose_kind", _pos(3.5, 0.0), one, 0.0))
        if close_kind != "stomp":
            _fail("new front STOMP priority did not override kick")
            return
        for last in ["stomp", "sweep"]:
            director.set("last_kind", last)
            var picked: String = str(director.call(
                "_choose_nonrepeating_kind", _pos(4.5, 45.0),
                one, 0.0))
            if picked != "kick":
                _fail("kick not selected after " + last)
                return
        director.set("last_kind", "kick")
        if str(director.call("_choose_nonrepeating_kind",
                _pos(4.5, 45.0), one, 0.0)) != "sweep":
            _fail("same-kind alternation invariant broken")
            return
    for leg in ["leg_rl", "leg_rr"]:
        if not _check_one(leg, 4.50, 0.0, false):
            return
    # Compare the fixed independent v540 envelope with the requested
    # widened v541 envelope over the same uniform polar sample.
    var before: int = 0
    var after: int = 0
    for di in range(31):
        var d: float = 3.0 + 0.1 * float(di)
        for ai in range(-18, 19):
            var angle: float = 5.0 * float(ai)
            if d >= 3.75 and d <= 5.15 and absf(angle) <= 38.0:
                before += 1
            if A._leg_can_reach("kick", "leg_fl",
                    _pos(d, angle), Vector3.ZERO, 0.0):
                after += 1
    if float(after) < float(before) * 2.5:
        _fail("kick eligible polar sector did not expand enough "
            + str([before, after]))
        return
    # Actual contact gates remain sourced from the same Blockbench keys:
    # this change is AI decision-only and cannot introduce phantom hits.
    for t in [0.34, 0.35, 0.75, 0.76]:
        var expected: bool = t >= 0.35 and t <= 0.75
        if A.source_hit_window("kick", "leg_fl", t) != expected:
            _fail("kick hit timing changed at " + str(t))
            return
    print("GODOT_BITTARAN_KICK_SELECTION_V541_PASS old_samples=",
        before, " new_samples=", after,
        " front_only=true source_hitbox_preserved=true")
    quit(0)
