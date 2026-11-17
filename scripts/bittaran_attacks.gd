extends RefCounted
## Bittaran's twelve combinations: each real leg can STOMP, KICK or SWEEP.
## Timings are in physics seconds, independent of the authored locomotion clip.
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const ATTACK_KINDS: Array[String] = ["stomp", "kick", "sweep"]
# v438: preserve the six original Blockbench source CLIPS and let only
# a real-time attack director control entry, clip-speed warp, holding,
# and post-attack return. No procedural attack aiming/rewriting.
const ORIGINAL_ATTACK_ONLY: bool = true
const SOURCE_ENTRY_SECONDS: float = 0.32
const SOURCE_LEG_RETURN_SECONDS: float = 0.42
const SOURCE_BODY_RETURN_SECONDS: float = 0.62
const SOURCE_KICK_STOMP_RETURN_SECONDS: float = (
    SOURCE_LEG_RETURN_SECONDS + SOURCE_BODY_RETURN_SECONDS)
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
# v437: neutral Wait -> original outward sweep end (source t=0.50)
# MUST consume 2.00 real seconds including the 0.32s entry.
# Preserve the final 0.70s at 0.20x, but stretch the earlier .00-.36
# of source animation to 0.98s with a monotonic cubic Hermite warp.
# Start at zero source speed to meet the entry smoothstep; finish with
# source speed exactly 0.20 to meet the slow block without a snap.
# Source keys, attacking joints, return direction and post recovery
# remain untouched.
# Overall playback rate for the full authored sweep (outward and return).
# This multiplies the existing v437 time-warp rather than discarding it.
# Entry (Wait -> attack), recovery, and support-leg IK retain their times.
const SWEEP_PLAYBACK_RATE: float = 0.60
const SWEEP_SOURCE_STRIKE_SECONDS: float = 1.50
const SWEEP_OUTBOUND_END_CLIP_SECONDS: float = 0.50
const SWEEP_OUTBOUND_TARGET_TOTAL_SECONDS: float = 2.00
const SWEEP_SLOW_SPEED: float = 0.20
const SWEEP_SLOW_REAL_SECONDS: float = 0.70
const SWEEP_SLOW_SOURCE_SECONDS: float = (
    SWEEP_SLOW_REAL_SECONDS * SWEEP_SLOW_SPEED)
const SWEEP_SLOW_START_CLIP_SECONDS: float = (
    SWEEP_OUTBOUND_END_CLIP_SECONDS - SWEEP_SLOW_SOURCE_SECONDS)
const SWEEP_EARLY_REAL_SECONDS: float = (
    SWEEP_OUTBOUND_TARGET_TOTAL_SECONDS
    - SOURCE_ENTRY_SECONDS - SWEEP_SLOW_REAL_SECONDS)
const SWEEP_OUTBOUND_END_REAL_SECONDS: float = (
    SWEEP_EARLY_REAL_SECONDS + SWEEP_SLOW_REAL_SECONDS)
const SWEEP_STRIKE_SECONDS: float = (
    SWEEP_OUTBOUND_END_REAL_SECONDS
    + SWEEP_SOURCE_STRIKE_SECONDS - SWEEP_OUTBOUND_END_CLIP_SECONDS)
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

## BASE sweep source timeline in seconds from end of the 0.32s entry.
## v438 executes this time-warp at SWEEP_PLAYBACK_RATE=0.60,
## so every authored movement is 0.60x its prior speed:
## 0.00..0.98 = cubic time-warp original clip 0.00..0.36;
## 0.98..1.68 = constant 0.20x source 0.36..0.50;
## 1.68..2.68 = 1.00x source return 0.50..1.50.
## Total from neutral Wait to the OUTWARD turnaround = 2.00 seconds.
static func _sweep_early_source_time(play_seconds: float) -> float:
    var u: float = clampf(
        play_seconds / SWEEP_EARLY_REAL_SECONDS, 0.0, 1.0)
    # Cubic Hermite: p(0)=0, p'(0)=0; p(1)=.36,
    # p'(1)=.20 * .98. Evaluating the source timeline (not Euler
    # angles) preserves every original Blockbench key and its geometry.
    var h01: float = -2.0 * u * u * u + 3.0 * u * u
    var h11: float = u * u * u - u * u
    return (SWEEP_SLOW_START_CLIP_SECONDS * h01
        + SWEEP_EARLY_REAL_SECONDS * SWEEP_SLOW_SPEED * h11)


static func _sweep_early_source_speed(play_seconds: float) -> float:
    var u: float = clampf(
        play_seconds / SWEEP_EARLY_REAL_SECONDS, 0.0, 1.0)
    var slope: float = (
        SWEEP_SLOW_START_CLIP_SECONDS * (6.0 * u - 6.0 * u * u)
        + SWEEP_EARLY_REAL_SECONDS * SWEEP_SLOW_SPEED
        * (3.0 * u * u - 2.0 * u))
    return maxf(0.0, slope / SWEEP_EARLY_REAL_SECONDS)


static func sweep_clip_time_at(real_strike_seconds: float) -> float:
    var t: float = maxf(real_strike_seconds, 0.0)
    if t <= SWEEP_EARLY_REAL_SECONDS:
        return _sweep_early_source_time(t)
    if t <= SWEEP_OUTBOUND_END_REAL_SECONDS:
        return SWEEP_SLOW_START_CLIP_SECONDS + (
            t - SWEEP_EARLY_REAL_SECONDS) * SWEEP_SLOW_SPEED
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


## Real-time attack state with NON-DESTRUCTIVE source clip time warp.
## Entry: Wait -> authored t=0. Strike: authored clip keys only; the
## entire v437 sweep clock now runs at 0.60x, including its slow window.
## Kick/Stomp hold: freeze original last key 1.50 seconds.
## Return: KICK/STOMP limb 0.42 then Body 0.62; SWEEP no hold and
## all-body gradual return 1.40 seconds. The source keys never change.
static func source_play_seconds(attack_kind: String) -> float:
    if attack_kind == "sweep":
        return SWEEP_STRIKE_SECONDS / SWEEP_PLAYBACK_RATE
    return float(ORIGINAL_CLIP_LENGTHS.get(attack_kind, 0.0))


static func source_hold_seconds(attack_kind: String) -> float:
    if attack_kind == "sweep":
        return 0.0
    return 1.50


static func source_return_seconds(attack_kind: String) -> float:
    if attack_kind == "sweep":
        return SWEEP_RECOVERY_SECONDS
    return SOURCE_KICK_STOMP_RETURN_SECONDS


static func source_total_seconds(attack_kind: String) -> float:
    return (SOURCE_ENTRY_SECONDS + source_play_seconds(attack_kind)
        + source_hold_seconds(attack_kind)
        + source_return_seconds(attack_kind))


static func source_clip_time(attack_kind: String,
        real_attack_seconds: float) -> float:
    var play_t: float = clampf(real_attack_seconds, 0.0,
        source_play_seconds(attack_kind))
    if attack_kind == "sweep":
        return sweep_clip_time_at(play_t * SWEEP_PLAYBACK_RATE)
    return minf(play_t,
        float(ORIGINAL_CLIP_LENGTHS.get(attack_kind, 0.0)))


static func source_playback_speed(attack_kind: String,
        play_t: float) -> float:
    if attack_kind == "sweep":
        var warped_t: float = play_t * SWEEP_PLAYBACK_RATE
        if warped_t <= SWEEP_EARLY_REAL_SECONDS:
            return (SWEEP_PLAYBACK_RATE *
                _sweep_early_source_speed(warped_t))
        if warped_t < SWEEP_OUTBOUND_END_REAL_SECONDS:
            return SWEEP_PLAYBACK_RATE * SWEEP_SLOW_SPEED
        return SWEEP_PLAYBACK_RATE
    return 1.0


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
        # The 17:21 source includes six attacks on FRONT legs only.
        var authored_feet: Dictionary = {}
        for front_id in ["leg_fl", "leg_fr"]:
            if available_feet.has(front_id):
                authored_feet[front_id] = available_feet[front_id]
        var selected: String = _choose_leg(player_position, authored_feet)
        if selected.is_empty():
            return {}
        _start(selected, _choose_kind(
            selected, player_position, authored_feet), false)
        next_leg_index = (LEG_IDS.find(selected) + 1) % LEG_IDS.size()
    preparing_stance = false
    var length: float = float(ORIGINAL_CLIP_LENGTHS.get(kind, 0.0))
    if length <= 0.0:
        cancel()
        return {}
    var entry_end: float = SOURCE_ENTRY_SECONDS
    var play_end: float = entry_end + source_play_seconds(kind)
    var hold_end: float = play_end + source_hold_seconds(kind)
    var total: float = hold_end + source_return_seconds(kind)
    elapsed = minf(total, elapsed + maxf(delta, 0.0))
    var phase: String = "entry"
    var clip_time: float = 0.0
    var speed: float = 0.0
    var phase_elapsed: float = elapsed
    if elapsed >= hold_end:
        phase = "recovery"
        phase_elapsed = elapsed - hold_end
        clip_time = length
    elif elapsed >= play_end:
        phase = "hold"
        phase_elapsed = elapsed - play_end
        clip_time = length
    elif elapsed >= entry_end:
        phase = "strike"
        phase_elapsed = elapsed - entry_end
        clip_time = source_clip_time(kind, phase_elapsed)
        speed = source_playback_speed(kind, phase_elapsed)
    var frame: Dictionary = {
        "id": leg_id, "kind": kind,
        "original_attack_only": true,
        "source_timed_attack": true,
        "direct_front_test": true,
        "time": elapsed,
        "authored_time": clip_time,
        "authored_playback_speed": speed,
        "entry_seconds": SOURCE_ENTRY_SECONDS,
        "phase_elapsed": phase_elapsed,
        "phase": phase,
        "windup": SOURCE_ENTRY_SECONDS,
        "strike": source_play_seconds(kind),
        "hold": source_hold_seconds(kind),
        "recovery": source_return_seconds(kind),
        "leg_return_seconds": SOURCE_LEG_RETURN_SECONDS,
        "body_return_seconds": SOURCE_BODY_RETURN_SECONDS,
        "stance_prepare": false,
        "tracking": false,
        "hit_window": false,
        "impact": false
    }
    # Return the exact terminal frame once (source->Wait at weight 1),
    # then begin cooldown. No premature gait resampling at the boundary.
    if elapsed >= total - 0.000001:
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
