extends RefCounted
## Bittaran's twelve combinations: each real leg can STOMP, KICK or SWEEP.
## Timings are in physics seconds, independent of the authored locomotion clip.
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const ATTACK_KINDS: Array[String] = ["stomp", "kick", "sweep"]
# v430: the user has restarted animation testing from the six Blockbench
# clips only. This mode has NO pre-stance, no time stretch, hold, blend,
# procedural aim, hit or impact. Clip seconds equal real seconds.
const ORIGINAL_ATTACK_ONLY: bool = true
const ORIGINAL_CLIP_LENGTHS: Dictionary = {
    "stomp": 1.75, "kick": 1.0, "sweep": 1.50
}
const START_RANGE_METERS: float = 9.0
const STOMP_WINDUP_SECONDS: float = 1.25
# Head height is passed by the live combat controller. Standalone motion
# probes use the same 1.85m player capsule as main.gd.
const STOMP_PLAYER_HEAD_HEIGHT_METERS: float = 1.85
const STOMP_TRACK_FILTER_PER_SECOND: float = 16.0
const KICK_WINDUP_SECONDS: float = 0.70
const SWEEP_WINDUP_SECONDS: float = 0.70
const STOMP_STRIKE_SECONDS: float = 0.25
const KICK_STRIKE_SECONDS: float = 1.0
# The authored outward swing ends at source t=0.50. Slow the FINAL
# 0.70 real seconds BEFORE that endpoint to 0.20x so the outgoing
# motion visibly winds up. Return at normal speed immediately after
# the turnaround. Original source keys are never changed.
const SWEEP_SOURCE_STRIKE_SECONDS: float = 1.50
const SWEEP_OUTBOUND_END_CLIP_SECONDS: float = 0.50
const SWEEP_SLOW_SPEED: float = 0.20
const SWEEP_SLOW_REAL_SECONDS: float = 0.70
const SWEEP_SLOW_SOURCE_SECONDS: float = (
    SWEEP_SLOW_REAL_SECONDS * SWEEP_SLOW_SPEED)
const SWEEP_SLOW_START_CLIP_SECONDS: float = (
    SWEEP_OUTBOUND_END_CLIP_SECONDS - SWEEP_SLOW_SOURCE_SECONDS)
const SWEEP_OUTBOUND_END_REAL_SECONDS: float = (
    SWEEP_SLOW_START_CLIP_SECONDS + SWEEP_SLOW_REAL_SECONDS)
const SWEEP_EXTRA_REAL_SECONDS: float = (
    1.0 - SWEEP_SLOW_SPEED) * SWEEP_SLOW_REAL_SECONDS
const SWEEP_STRIKE_SECONDS: float = (
    SWEEP_SOURCE_STRIKE_SECONDS + SWEEP_EXTRA_REAL_SECONDS)
const STOMP_RECOVERY_SECONDS: float = 0.55
const KICK_RECOVERY_SECONDS: float = 0.60
const SWEEP_RECOVERY_SECONDS: float = 1.40
const BETWEEN_ATTACKS_SECONDS: float = 1.35
# Situational technique selection (v401). Each kind has a clear job:
# STOMP punishes a player standing right at a foot, KICK strikes a
# player out beyond the foot along its radial line, SWEEP covers a
# player off to the foot's side, where only a sideways arc reaches.
# When no situation applies (or the situational kind would repeat the
# previous attack), the historical rotation decides, so the fight
# keeps its variety and never spams one kind.
const STOMP_RANGE_METERS: float = 3.6
const KICK_FRONT_DOT: float = 0.50
# The leg-placement phase is outside every authored attack timeline.
# Its actual duration is owned by the four-foot IK controller.
# STOMP/KICK hold the final strike pose completely still for 1.5s.
# SWEEP has no hold and instead eases gently back over 1.4s.
const STOMP_POST_HIT_HOLD_SECONDS: float = 1.50
const KICK_POST_HIT_HOLD_SECONDS: float = 1.50
const SWEEP_POST_HIT_HOLD_SECONDS: float = 0.0

var kind: String = ""
var leg_id: String = ""
var elapsed: float = 0.0
var cooldown: float = 1.0
var next_kind_index: int = 0
var last_kind: String = ""
var next_leg_index: int = 0
var hit_consumed: bool = false
var preparing_stance: bool = false
var stomp_aim: Vector3 = Vector3.ZERO
var stomp_aim_valid: bool = false

func reset() -> void:
    kind = ""
    leg_id = ""
    elapsed = 0.0
    cooldown = 1.0
    next_kind_index = 0
    last_kind = ""
    next_leg_index = 0
    hit_consumed = false
    preparing_stance = false
    stomp_aim_valid = false

func cancel() -> void:
    kind = ""
    leg_id = ""
    elapsed = 0.0
    cooldown = BETWEEN_ATTACKS_SECONDS
    hit_consumed = false
    preparing_stance = false
    stomp_aim_valid = false

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

## SOURCE timeline: 0.00..0.36 at 1x -> 0.36..0.50 at 0.20x
## over 0.70 REAL seconds -> 0.50..1.50 at 1x (return).
## Keyframe t=0.50 is reached at REAL t=1.06, so the last 0.70s
## of the OUTBOUND action plays slowly instead of slowing its return.
static func sweep_clip_time_at(real_strike_seconds: float) -> float:
    var t: float = maxf(real_strike_seconds, 0.0)
    if t <= SWEEP_SLOW_START_CLIP_SECONDS:
        return t
    if t <= SWEEP_OUTBOUND_END_REAL_SECONDS:
        return SWEEP_SLOW_START_CLIP_SECONDS + (
            t - SWEEP_SLOW_START_CLIP_SECONDS) * SWEEP_SLOW_SPEED
    return minf(SWEEP_SOURCE_STRIKE_SECONDS,
        SWEEP_OUTBOUND_END_CLIP_SECONDS
        + (t - SWEEP_OUTBOUND_END_REAL_SECONDS))


func _hold() -> float:
    match kind:
        "stomp": return STOMP_POST_HIT_HOLD_SECONDS
        "kick": return KICK_POST_HIT_HOLD_SECONDS
        _: return SWEEP_POST_HIT_HOLD_SECONDS

func _recovery() -> float:
    match kind:
        "stomp": return STOMP_RECOVERY_SECONDS
        "kick": return KICK_RECOVERY_SECONDS
        _: return SWEEP_RECOVERY_SECONDS

func _start(id: String, attack_kind: String,
        with_stance_preparation: bool = false) -> void:
    leg_id = id
    kind = attack_kind
    elapsed = 0.0
    hit_consumed = false
    stomp_aim_valid = false
    preparing_stance = with_stance_preparation


func force_start(id: String, attack_kind: String) -> bool:
    # Legacy deterministic clip tests start straight at authored t=0.
    # Actual AI selections always use _start(..., true) below.
    if not LEG_IDS.has(id) or not ATTACK_KINDS.has(attack_kind):
        return false
    _start(id, attack_kind, false)
    return true


func force_start_with_stance(id: String, attack_kind: String) -> bool:
    # Deterministic entry into the *actual* pre-attack IK stage.
    if not LEG_IDS.has(id) or not ATTACK_KINDS.has(attack_kind):
        return false
    _start(id, attack_kind, true)
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

## Pick the technique for a newly selected leg (v401). See the
## STOMP_RANGE_METERS constants: the situation decides first, the
## rotation breaks ties and prevents immediate repeats.
func _choose_kind(for_leg: String, player_position: Vector3,
        feet: Dictionary) -> String:
    var chosen: String = ATTACK_KINDS[next_kind_index]
    if feet.has(for_leg):
        var foot: Vector3 = feet[for_leg]
        var centroid := Vector3.ZERO
        var count: int = 0
        for id in feet.keys():
            centroid += feet[id] as Vector3
            count += 1
        if count > 0:
            centroid /= float(count)
            var radial := Vector2(
                foot.x - centroid.x, foot.z - centroid.z)
            var to_player := Vector2(
                player_position.x - foot.x,
                player_position.z - foot.z)
            var distance: float = to_player.length()
            var situational: String = ""
            if distance <= STOMP_RANGE_METERS:
                situational = "stomp"
            elif radial.length() > 0.01 and distance > 0.01:
                var dot: float = radial.normalized().dot(
                    to_player / distance)
                if dot >= KICK_FRONT_DOT:
                    situational = "kick"
                elif dot > -KICK_FRONT_DOT:
                    situational = "sweep"
            if not situational.is_empty() and situational != last_kind:
                chosen = situational
    last_kind = chosen
    next_kind_index = (ATTACK_KINDS.find(chosen) + 1) % ATTACK_KINDS.size()
    return chosen


## Raw authoring mode: each original Blockbench clip starts immediately
## and finishes at its exact source length. No hitboxes until the user's
## next requested combat layer is reintroduced.
func _advance_original_only(delta: float, player_position: Vector3,
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
        _start(selected, _choose_kind(
            selected, player_position, available_feet), false)
        next_leg_index = (LEG_IDS.find(selected) + 1) % LEG_IDS.size()
    preparing_stance = false
    var length: float = float(ORIGINAL_CLIP_LENGTHS.get(kind, 0.0))
    if length <= 0.0:
        cancel()
        return {}
    elapsed = minf(length, elapsed + maxf(delta, 0.0))
    var frame: Dictionary = {
        "id": leg_id, "kind": kind,
        "original_attack_only": true,
        "direct_front_test": true,
        "time": elapsed,
        "authored_time": elapsed,
        "authored_playback_speed": 1.0,
        "windup": 0.0, "strike": length,
        "hold": 0.0, "recovery": 0.0,
        "phase": "strike",
        "stance_prepare": false,
        "tracking": false,
        "hit_window": false,
        "impact": false
    }
    if elapsed >= length:
        cancel()
    return frame


func advance(delta: float, player_position: Vector3,
        available_feet: Dictionary, permitted: bool,
        player_head_position: Vector3 = Vector3.INF,
        stance_ready: bool = false) -> Dictionary:
    if ORIGINAL_ATTACK_ONLY:
        return _advance_original_only(delta, player_position,
            available_feet, permitted)
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
        _start(selected, _choose_kind(
            selected, player_position, available_feet), true)
        stomp_aim = player_position
        stomp_aim_valid = false
        next_leg_index = (LEG_IDS.find(selected) + 1) % LEG_IDS.size()
    if preparing_stance:
        if not stance_ready:
            # No attack clock, author keys, body turn or hitboxes during
            # the two diagonal IK replanting steps. The selected strike
            # is held and cannot switch targets halfway through.
            return {
                "kind": kind, "id": leg_id, "phase": "stance",
                "stance_prepare": true, "time": 0.0,
                "tracking": false, "hit_window": false,
                "impact": false
            }
        preparing_stance = false
        # The first true attack frame is now t=delta: every attack uses
        # its original complete authored anticipation and strike timing.
        stomp_aim_valid = false
    var previous: float = elapsed
    var windup: float = _windup()
    # The raised STOMP foot follows the player's HEAD, not their
    # ground marker. Smooth the head target during the full 1.00s lift,
    # sample its last position at the swing boundary and then stop tracking.
    # All three attacks track SERA through windup, then lock their aim.
    # STOMP uses the player's head; KICK/SWEEP target the ground position.
    if previous < windup:
        var next_aim: Vector3 = player_position
        if kind == "stomp":
            next_aim = (player_head_position
                if player_head_position != Vector3.INF else
                player_position + Vector3.UP * STOMP_PLAYER_HEAD_HEIGHT_METERS)
        if not stomp_aim_valid:
            stomp_aim = next_aim
        elif kind == "stomp":
            var alpha: float = 1.0 - exp(
                -STOMP_TRACK_FILTER_PER_SECOND * maxf(delta, 0.0))
            stomp_aim = stomp_aim.lerp(next_aim, alpha)
        else:
            stomp_aim = next_aim
        stomp_aim_valid = true
    var strike: float = _strike()
    var recovery: float = _recovery()
    var hold: float = _hold()
    var total: float = windup + strike + hold + recovery
    elapsed = minf(total, elapsed + maxf(delta, 0.0))
    # STOMP's authored clip begins at attack t=0 and contains its
    # full 1.25s windup. KICK/SWEEP source clips begin AFTER the 0.70s
    # preparatory crouch. Preserve this existing timing distinction.
    var authored_time: float = (elapsed if kind == "stomp" else
        maxf(elapsed - windup, 0.0))
    var source_rate: float = 1.0
    if kind == "sweep":
        var wall_strike_t: float = clampf(
            authored_time, 0.0, SWEEP_STRIKE_SECONDS)
        authored_time = sweep_clip_time_at(wall_strike_t)
        if wall_strike_t >= SWEEP_SLOW_START_CLIP_SECONDS and (
                wall_strike_t < SWEEP_OUTBOUND_END_REAL_SECONDS):
            source_rate = SWEEP_SLOW_SPEED
    var result: Dictionary = {
        "kind": kind, "id": leg_id, "time": elapsed,
        "authored_time": authored_time,
        "authored_playback_speed": source_rate,
        "stomp_aim": stomp_aim if stomp_aim_valid else Vector3.INF,
        "aim": stomp_aim if stomp_aim_valid else Vector3.INF,
        "tracking": previous < windup,
        "strike_start": previous < windup and elapsed >= windup,
        "player_tracking_disabled": false,
        "windup": windup, "strike": strike, "hold": hold,
        "recovery": recovery,
        "phase": ("windup" if elapsed < windup else
            ("strike" if elapsed < windup + strike else
            ("hold" if elapsed < windup + strike + hold else "recovery"))),
        "impact": kind == "stomp" and previous < windup + strike
            and elapsed >= windup + strike,
        "hit_window": kind != "stomp" and elapsed >= windup
            and elapsed <= windup + strike and not hit_consumed
    }
    if elapsed >= total:
        cancel()
    return result
