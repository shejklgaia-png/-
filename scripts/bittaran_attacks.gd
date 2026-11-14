extends RefCounted
## Bittaran's twelve combinations: each real leg can STOMP, KICK or SWEEP.
## Timings are in physics seconds, independent of the authored locomotion clip.
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const ATTACK_KINDS: Array[String] = ["stomp", "kick", "sweep"]
const START_RANGE_METERS: float = 6.0
const STOMP_WINDUP_SECONDS: float = 1.0
const KICK_WINDUP_SECONDS: float = 1.0
const SWEEP_WINDUP_SECONDS: float = 0.72
const STOMP_STRIKE_SECONDS: float = 0.20
const KICK_STRIKE_SECONDS: float = 0.19
const SWEEP_STRIKE_SECONDS: float = 0.35
const STOMP_RECOVERY_SECONDS: float = 0.48
const KICK_RECOVERY_SECONDS: float = 0.45
const SWEEP_RECOVERY_SECONDS: float = 0.65
const BETWEEN_ATTACKS_SECONDS: float = 1.35

var kind: String = ""
var leg_id: String = ""
var elapsed: float = 0.0
var cooldown: float = 1.0
var next_kind_index: int = 0
var next_leg_index: int = 0
var hit_consumed: bool = false

func reset() -> void:
    kind = ""
    leg_id = ""
    elapsed = 0.0
    cooldown = 1.0
    next_kind_index = 0
    next_leg_index = 0
    hit_consumed = false

func cancel() -> void:
    kind = ""
    leg_id = ""
    elapsed = 0.0
    cooldown = BETWEEN_ATTACKS_SECONDS
    hit_consumed = false

func is_active() -> bool:
    return not kind.is_empty()

func _windup() -> float:
    match kind:
        "stomp": return STOMP_WINDUP_SECONDS
        "kick": return KICK_WINDUP_SECONDS
        _: return SWEEP_WINDUP_SECONDS

func _strike() -> float:
    match kind:
        "stomp": return STOMP_STRIKE_SECONDS
        "kick": return KICK_STRIKE_SECONDS
        _: return SWEEP_STRIKE_SECONDS

func _recovery() -> float:
    match kind:
        "stomp": return STOMP_RECOVERY_SECONDS
        "kick": return KICK_RECOVERY_SECONDS
        _: return SWEEP_RECOVERY_SECONDS

func _start(id: String, attack_kind: String) -> void:
    leg_id = id
    kind = attack_kind
    elapsed = 0.0
    hit_consumed = false

func force_start(id: String, attack_kind: String) -> bool:
    # Public deterministic entry point for the full twelve-variant CI test.
    if not LEG_IDS.has(id) or not ATTACK_KINDS.has(attack_kind):
        return false
    _start(id, attack_kind)
    return true

func _choose_leg(player_position: Vector3, feet: Dictionary) -> String:
    var best: String = ""
    var best_score: float = INF
    for n in range(LEG_IDS.size()):
        var index: int = (next_leg_index + n) % LEG_IDS.size()
        var id: String = LEG_IDS[index]
        if not feet.has(id):
            continue
        var foot: Vector3 = feet[id]
        var horizontal: Vector2 = Vector2(
            foot.x - player_position.x, foot.z - player_position.z)
        var distance: float = horizontal.length()
        if distance > START_RANGE_METERS:
            continue
        # Spatial relevance first, with a slight cyclic bias so the same
        # limb does not monopolize the fight near the chassis midpoint.
        var score: float = distance + float(n) * 0.18
        if score < best_score:
            best_score = score
            best = id
    return best

func advance(delta: float, player_position: Vector3,
        available_feet: Dictionary, permitted: bool) -> Dictionary:
    if not permitted:
        if is_active():
            cancel()
        else:
            cooldown = maxf(cooldown, BETWEEN_ATTACKS_SECONDS)
        return {}
    if not is_active():
        cooldown = maxf(0.0, cooldown - maxf(delta, 0.0))
        if cooldown > 0.0:
            return {}
        var selected: String = _choose_leg(player_position, available_feet)
        if selected.is_empty():
            return {}
        _start(selected, ATTACK_KINDS[next_kind_index])
        next_kind_index = (next_kind_index + 1) % ATTACK_KINDS.size()
        next_leg_index = (LEG_IDS.find(selected) + 1) % LEG_IDS.size()
    var previous: float = elapsed
    var windup: float = _windup()
    var strike: float = _strike()
    var recovery: float = _recovery()
    var total: float = windup + strike + recovery
    elapsed = minf(total, elapsed + maxf(delta, 0.0))
    var result: Dictionary = {
        "kind": kind, "id": leg_id, "time": elapsed,
        "windup": windup, "strike": strike, "recovery": recovery,
        "impact": kind == "stomp" and previous < windup + strike
            and elapsed >= windup + strike,
        "hit_window": kind != "stomp" and elapsed >= windup
            and elapsed <= windup + strike and not hit_consumed
    }
    if elapsed >= total:
        cancel()
    return result
