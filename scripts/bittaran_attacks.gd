extends RefCounted
## Bittaran's twelve combinations: each real leg can STOMP, KICK or SWEEP.
## Timings are in physics seconds, independent of the authored locomotion clip.
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const ATTACK_KINDS: Array[String] = ["stomp", "kick", "sweep"]
# v450: preserve authored front and rear Blockbench source clips and let only
# a real-time attack director control entry, clip-speed warp, holding,
# and post-attack return. No procedural attack aiming/rewriting.
const ORIGINAL_ATTACK_ONLY: bool = true
# v462 TIMING EXPERIMENT: toggle ONE bool off to restore v461 timing.
# All original durations and source animation keys remain unchanged.
const TIMING_TEST_ENABLED: bool = true
# v463: Independent, reversible experiment. true = chest and striker
# recover simultaneously; false = the original body-then-leg order.
# This does not change TIMING_TEST_ENABLED or its speed multipliers.
const TEST_PARALLEL_BODY_LEG_RETURN: bool = true
const TEST_ANTICIPATION_SPEED: float = 1.10
const TEST_HOME_RETURN_SPEED: float = 1.25
const TEST_NO_STOP_SECONDS: float = 0.0
# v448: retime the original STOMP keys separately for front and rear legs.
# The actual first apex is t=1.00(front) / t=.50(rear).
# Identical held keys continue to 1.25/.83333; skip that inert plateau.
const STOMP_FRONT_APEX_SOURCE_SECONDS: float = 1.00
const STOMP_REAR_APEX_SOURCE_SECONDS: float = 0.50
const STOMP_FRONT_DROP_START_SOURCE_SECONDS: float = 1.25
const STOMP_REAR_DROP_START_SOURCE_SECONDS: float = 0.83333
const STOMP_FRONT_LANDING_SOURCE_SECONDS: float = 1.50
const STOMP_REAR_LANDING_SOURCE_SECONDS: float = 1.00
const STOMP_FRONT_RAISE_SECONDS: float = 0.80
const STOMP_REAR_RAISE_SECONDS: float = 0.50
const STOMP_FRONT_DROP_SECONDS: float = 0.23
const STOMP_REAR_DROP_SECONDS: float = 0.18
# Keep the grounded contact pose completely motionless for a readable beat.
const STOMP_CONTACT_STOP_SECONDS: float = 0.09
const SOURCE_ENTRY_SECONDS: float = 0.32
# Sweep-only windup: wait pose -> original outward stroke begins at t=1s.
const SWEEP_ENTRY_SECONDS: float = 1.00
# Following BODY recovery, return the striking leg directly to Wait.
# No stomp windup, lift waypoint, or artificial bounce.
const SOURCE_LEG_RETURN_SECONDS: float = 1.20
const SOURCE_BODY_RETURN_SECONDS: float = 0.62
const SOURCE_KICK_STOMP_RETURN_SECONDS: float = (
    SOURCE_LEG_RETURN_SECONDS + SOURCE_BODY_RETURN_SECONDS)
const ORIGINAL_CLIP_LENGTHS: Dictionary = {
    "stomp": 1.75, "kick": 1.0, "sweep": 1.50
}
## The 22:13 source only has rear STOMP and SWEEP (not rear KICK).
const REAR_CLIP_LENGTHS: Dictionary = {
    "stomp": 1.0, "sweep": 0.75
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
# v445: Wait -> authored sweep start takes 1.00s; the FULL outward
# stroke is 1.00s at a uniform 0.50x. The original turning key t=0.50
# is therefore reached at 2.00s after attack start. The original
# return t=0.50..1.50 stays 1.00x, no mid-outward slowdown segment.
const SWEEP_SOURCE_STRIKE_SECONDS: float = 1.50
const SWEEP_OUTBOUND_END_CLIP_SECONDS: float = 0.50
const SWEEP_OUTBOUND_TARGET_TOTAL_SECONDS: float = 2.00
const SWEEP_OUTBOUND_REAL_SECONDS: float = (
    SWEEP_OUTBOUND_TARGET_TOTAL_SECONDS - SWEEP_ENTRY_SECONDS)
const SWEEP_OUTBOUND_SPEED: float = (
    SWEEP_OUTBOUND_END_CLIP_SECONDS / SWEEP_OUTBOUND_REAL_SECONDS)
const SWEEP_STRIKE_SECONDS: float = (
    SWEEP_OUTBOUND_REAL_SECONDS +
    SWEEP_SOURCE_STRIKE_SECONDS - SWEEP_OUTBOUND_END_CLIP_SECONDS)
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
# v464: attack selection uses the ACTUAL player-to-active-foot
# horizontal distance: close STOMP, middle KICK(front)/SWEEP(rear),
# far SWEEP. No kick clip exists for either rear leg.
const KICK_RANGE_METERS: float = 6.3
const KICK_FRONT_DOT: float = 0.15
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
var cooldown: float = 0.0 if TIMING_TEST_ENABLED else 1.0
var next_kind_index: int = 0
var last_kind: String = ""
var next_leg_index: int = 0
var hit_consumed: bool = false
var preparing_stance: bool = false
var stomp_aim: Vector3 = Vector3.ZERO
var stomp_aim_valid: bool = false
var stomp_landed_clip_time: float = -1.0

func reset() -> void:
    kind = ""
    leg_id = ""
    elapsed = 0.0
    cooldown = (TEST_NO_STOP_SECONDS
        if TIMING_TEST_ENABLED else 1.0)
    next_kind_index = 0
    last_kind = ""
    next_leg_index = 0
    hit_consumed = false
    preparing_stance = false
    stomp_aim_valid = false
    stomp_landed_clip_time = -1.0

func cancel() -> void:
    kind = ""
    leg_id = ""
    elapsed = 0.0
    cooldown = (TEST_NO_STOP_SECONDS
        if TIMING_TEST_ENABLED else BETWEEN_ATTACKS_SECONDS)
    hit_consumed = false
    preparing_stance = false
    stomp_aim_valid = false
    stomp_landed_clip_time = -1.0

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

## Piecewise affine source clock, with constant speed per whole stroke:
## outward .50x from clip t=0 to .50; return 1.00x. No localized slow.
static func sweep_clip_time_at(real_strike_seconds: float) -> float:
    var t: float = clampf(real_strike_seconds,
        0.0, SWEEP_STRIKE_SECONDS)
    if t <= SWEEP_OUTBOUND_REAL_SECONDS:
        return t * SWEEP_OUTBOUND_SPEED
    return minf(SWEEP_SOURCE_STRIKE_SECONDS,
        SWEEP_OUTBOUND_END_CLIP_SECONDS
        + (t - SWEEP_OUTBOUND_REAL_SECONDS))

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
    stomp_landed_clip_time = -1.0
    preparing_stance = with_stance_preparation


func force_start(id: String, attack_kind: String) -> bool:
    # Legacy deterministic clip tests start straight at authored t=0.
    # Actual AI selections always use _start(..., true) below.
    if not LEG_IDS.has(id) or not ATTACK_KINDS.has(attack_kind) or (
            id.begins_with("leg_r") and attack_kind == "kick"):
        return false
    _start(id, attack_kind, false)
    return true


func force_start_with_stance(id: String, attack_kind: String) -> bool:
    # Deterministic entry into the *actual* pre-attack IK stage.
    if not LEG_IDS.has(id) or not ATTACK_KINDS.has(attack_kind) or (
            id.begins_with("leg_r") and attack_kind == "kick"):
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

## Choose range-first using the ACTUAL horizontal foot-player
## separation, never the original historical technique cycle.
## Close: stomp. Medium: front-forward kick or side/rear sweep.
## Far (inside 9m leg search): sweeping reach. The automatic
## leg picker still rotates between suitable physical feet.
func _choose_kind(for_leg: String, player_position: Vector3,
        feet: Dictionary) -> String:
    var chosen: String = "sweep"
    if feet.has(for_leg):
        var foot: Vector3 = feet[for_leg]
        var radial := Vector2.ZERO
        var centroid := Vector3.ZERO
        for id in feet.keys():
            centroid += feet[id] as Vector3
        if feet.size() > 0:
            centroid /= float(feet.size())
        radial = Vector2(foot.x - centroid.x, foot.z - centroid.z)
        var to_player := Vector2(
            player_position.x - foot.x,
            player_position.z - foot.z)
        var distance: float = to_player.length()
        if distance <= STOMP_RANGE_METERS:
            chosen = "stomp"
        elif distance <= KICK_RANGE_METERS and (
                not for_leg.begins_with("leg_r")) and (
                radial.length() > 0.01 and distance > 0.01) and (
                radial.normalized().dot(to_player / distance)
                    >= KICK_FRONT_DOT):
            chosen = "kick"
        else:
            chosen = "sweep"
    # Never fabricate a rear kick; the imported rear asset only
    # contains STOMP/SWEEP. Range is authoritative even on repeats.
    last_kind = chosen
    next_kind_index = (ATTACK_KINDS.find(chosen) + 1) % ATTACK_KINDS.size()
    return chosen


## v445: BODY returns first (sweep 1.40s, others 0.62s).
## THEN the attacking chain eases directly to Wait in 1.20s, with
## quintic acceleration / deceleration applied by bittaran_rig.gd.
## The sweep outward turnaround is 2.00s from attack start; no
## localized slow-motion and no intermediate leg-lift waypoint.
## Shared with the 2-pair foot replant IK, also guarded by this switch.
static func source_return_speed() -> float:
    return TEST_HOME_RETURN_SPEED if TIMING_TEST_ENABLED else 1.0


## Blockbench authored windup ends at the first real strike frame.
## Early keys accelerate; later swing/hit source speed stays unchanged.
static func source_authored_windup_clip_seconds(
        attack_kind: String, attack_id: String = "") -> float:
    match attack_kind:
        "stomp":
            return 0.833333 if attack_id.begins_with("leg_r") else 1.375
        "kick":
            return 0.458333
        "sweep":
            return 0.25
    return 0.0


static func source_original_windup_play_seconds(
        attack_kind: String, attack_id: String = "") -> float:
    var source_t: float = source_authored_windup_clip_seconds(
        attack_kind, attack_id)
    if attack_kind == "sweep":
        return source_t / SWEEP_OUTBOUND_SPEED
    return source_t


static func source_anticipation_saved_seconds(
        attack_kind: String, attack_id: String = "") -> float:
    if not TIMING_TEST_ENABLED:
        return 0.0
    var original: float = source_original_windup_play_seconds(
        attack_kind, attack_id)
    return original * (1.0 - 1.0 / TEST_ANTICIPATION_SPEED)


static func source_entry_seconds(attack_kind: String) -> float:
    var base: float = (
        SWEEP_ENTRY_SECONDS if attack_kind == "sweep"
        else SOURCE_ENTRY_SECONDS)
    return base / TEST_ANTICIPATION_SPEED if TIMING_TEST_ENABLED else base


static func source_clip_length(attack_kind: String,
        attack_id: String = "") -> float:
    if attack_id.begins_with("leg_r"):
        return float(REAR_CLIP_LENGTHS.get(attack_kind, 0.0))
    return float(ORIGINAL_CLIP_LENGTHS.get(attack_kind, 0.0))


## A fast ease-out reaches the true authored apex with zero speed.
## A slow-start, accelerating drop reaches the last physical contact key.
## The unused front source tail (1.50..1.75) is stationary.
static func stomp_apex_source_seconds(attack_id: String) -> float:
    return (STOMP_REAR_APEX_SOURCE_SECONDS if attack_id.begins_with("leg_r")
        else STOMP_FRONT_APEX_SOURCE_SECONDS)


static func stomp_drop_start_source_seconds(attack_id: String) -> float:
    return (STOMP_REAR_DROP_START_SOURCE_SECONDS
        if attack_id.begins_with("leg_r")
        else STOMP_FRONT_DROP_START_SOURCE_SECONDS)


static func stomp_landing_source_seconds(attack_id: String) -> float:
    return (STOMP_REAR_LANDING_SOURCE_SECONDS if attack_id.begins_with("leg_r")
        else STOMP_FRONT_LANDING_SOURCE_SECONDS)


static func stomp_raise_seconds(attack_id: String) -> float:
    return (STOMP_REAR_RAISE_SECONDS if attack_id.begins_with("leg_r")
        else STOMP_FRONT_RAISE_SECONDS)


static func stomp_drop_seconds(attack_id: String) -> float:
    return (STOMP_REAR_DROP_SECONDS if attack_id.begins_with("leg_r")
        else STOMP_FRONT_DROP_SECONDS)


static func stomp_warped_clip_time(seconds: float,
        attack_id: String = "") -> float:
    var lift: float = stomp_raise_seconds(attack_id)
    var drop: float = stomp_drop_seconds(attack_id)
    var apex: float = stomp_apex_source_seconds(attack_id)
    var landing: float = stomp_landing_source_seconds(attack_id)
    var t: float = clampf(seconds, 0.0, lift + drop)
    if t <= lift:
        var u: float = t / lift
        return apex * (1.0 - (1.0 - u) * (1.0 - u))
    var u: float = clampf((t - lift) / drop, 0.0, 1.0)
    # Source keys between apex and drop-start are byte-identical;
    # skipping this static hold produces no visible pose discontinuity.
    var drop_start: float = stomp_drop_start_source_seconds(attack_id)
    return drop_start + (landing - drop_start) * pow(u, 2.4)


static func stomp_warped_playback_speed(seconds: float,
        attack_id: String = "") -> float:
    var lift: float = stomp_raise_seconds(attack_id)
    var drop: float = stomp_drop_seconds(attack_id)
    var t: float = maxf(seconds, 0.0)
    if t < lift:
        return (2.0 * stomp_apex_source_seconds(attack_id)
            / lift * (1.0 - t / lift))
    if t < lift + drop:
        var u: float = clampf((t - lift) / drop, 0.0, 1.0)
        return ((stomp_landing_source_seconds(attack_id)
            - stomp_drop_start_source_seconds(attack_id))
            * 2.4 * pow(u, 1.4) / drop)
    return 0.0


## The battle controller calls this only on actual descending foot contact.
## A latched source timestamp holds the foot perfectly still until recovery.
func register_stomp_contact(attack_id: String,
        clip_seconds: float) -> bool:
    if kind != "stomp" or leg_id != attack_id or (
            stomp_landed_clip_time >= 0.0):
        return false
    var apex: float = stomp_apex_source_seconds(attack_id)
    if clip_seconds <= apex:
        return false
    stomp_landed_clip_time = clampf(clip_seconds, apex,
        stomp_landing_source_seconds(attack_id))
    return true


static func source_play_seconds(attack_kind: String,
        attack_id: String = "") -> float:
    if attack_kind == "stomp":
        return (stomp_raise_seconds(attack_id)
            + stomp_drop_seconds(attack_id))
    var length: float = source_clip_length(attack_kind, attack_id)
    var original: float = length
    if attack_kind == "sweep":
        # Preserve 0.5x outbound apart from its first .25 source
        # seconds. Rear sweep finishes at .75, not front 1.50.
        original = SWEEP_OUTBOUND_REAL_SECONDS + maxf(
            0.0, length - SWEEP_OUTBOUND_END_CLIP_SECONDS)
    return original - source_anticipation_saved_seconds(
        attack_kind, attack_id)


static func source_hold_seconds(attack_kind: String) -> float:
    if attack_kind == "stomp":
        return STOMP_CONTACT_STOP_SECONDS
    if TIMING_TEST_ENABLED:
        return TEST_NO_STOP_SECONDS
    if attack_kind == "sweep":
        return 0.0
    return 1.50


static func source_body_return_seconds(attack_kind: String) -> float:
    var base: float = (
        SWEEP_RECOVERY_SECONDS if attack_kind == "sweep"
        else SOURCE_BODY_RETURN_SECONDS)
    return base / source_return_speed()


static func source_leg_return_seconds() -> float:
    return SOURCE_LEG_RETURN_SECONDS / source_return_speed()


static func source_return_seconds(attack_kind: String) -> float:
    if TEST_PARALLEL_BODY_LEG_RETURN:
        # Start both motions together. Continue until BOTH finish.
        return maxf(source_body_return_seconds(attack_kind),
            source_leg_return_seconds())
    return (source_body_return_seconds(attack_kind)
        + source_leg_return_seconds())


static func source_total_seconds(attack_kind: String,
        attack_id: String = "") -> float:
    return (source_entry_seconds(attack_kind)
        + source_play_seconds(attack_kind, attack_id)
        + source_hold_seconds(attack_kind)
        + source_return_seconds(attack_kind))


static func source_clip_time(attack_kind: String,
        real_attack_seconds: float, attack_id: String = "") -> float:
    var play_t: float = clampf(real_attack_seconds, 0.0,
        source_play_seconds(attack_kind, attack_id))
    var length: float = source_clip_length(attack_kind, attack_id)
    if attack_kind == "stomp":
        return stomp_warped_clip_time(play_t, attack_id)
    if TIMING_TEST_ENABLED:
        var windup: float = source_original_windup_play_seconds(
            attack_kind, attack_id)
        var faster_windup: float = windup / TEST_ANTICIPATION_SPEED
        if play_t < faster_windup:
            var base_speed: float = (
                SWEEP_OUTBOUND_SPEED if attack_kind == "sweep"
                else 1.0)
            return minf(play_t * base_speed
                * TEST_ANTICIPATION_SPEED, length)
        # Skip only the saved windup time. The authored actual
        # strike/outbound return retain their original source speeds.
        play_t += windup - faster_windup
    if attack_kind == "sweep":
        return minf(sweep_clip_time_at(play_t), length)
    return minf(play_t, length)


static func source_playback_speed(attack_kind: String,
        play_t: float, attack_id: String = "") -> float:
    if attack_kind == "stomp":
        return stomp_warped_playback_speed(play_t, attack_id)
    var source_t: float = play_t
    if TIMING_TEST_ENABLED:
        var windup: float = source_original_windup_play_seconds(
            attack_kind, attack_id)
        var faster_windup: float = windup / TEST_ANTICIPATION_SPEED
        if play_t < faster_windup:
            var base_speed: float = (
                SWEEP_OUTBOUND_SPEED if attack_kind == "sweep"
                else 1.0)
            return base_speed * TEST_ANTICIPATION_SPEED
        source_t += windup - faster_windup
    if attack_kind == "sweep" and (
            source_t < SWEEP_OUTBOUND_REAL_SECONDS):
        return SWEEP_OUTBOUND_SPEED
    return 1.0


func _advance_original_only(delta: float, player_position: Vector3,
        available_feet: Dictionary, permitted: bool) -> Dictionary:
    if not permitted:
        if is_active():
            cancel()
        else:
            cooldown = maxf(cooldown,
                TEST_NO_STOP_SECONDS if TIMING_TEST_ENABLED
                else BETWEEN_ATTACKS_SECONDS)
        return {}
    if not is_active():
        cooldown = maxf(0.0, cooldown - maxf(delta, 0.0))
        if cooldown > 0.0:
            return {}
        # All four physical legs participate. Rear attacks are limited to
        # the two newly authored techniques; there is no invented rear kick.
        var authored_feet: Dictionary = {}
        for id in LEG_IDS:
            if available_feet.has(id):
                authored_feet[id] = available_feet[id]
        var selected: String = _choose_leg(player_position, authored_feet)
        if selected.is_empty():
            return {}
        _start(selected, _choose_kind(
            selected, player_position, authored_feet), false)
        next_leg_index = (LEG_IDS.find(selected) + 1) % LEG_IDS.size()
    preparing_stance = false
    var length: float = source_clip_length(kind, leg_id)
    if length <= 0.0:
        cancel()
        return {}
    var entry_end: float = source_entry_seconds(kind)
    var play_end: float = entry_end + source_play_seconds(kind, leg_id)
    var hold_end: float = play_end + source_hold_seconds(kind)
    var total: float = hold_end + source_return_seconds(kind)
    elapsed = minf(total, elapsed + maxf(delta, 0.0))
    var phase: String = "entry"
    var clip_time: float = 0.0
    var speed: float = 0.0
    var phase_elapsed: float = elapsed
    var recovery_stage: String = ""
    if elapsed >= hold_end:
        phase = "recovery"
        phase_elapsed = elapsed - hold_end
        clip_time = length
        var body_seconds: float = source_body_return_seconds(kind)
        if TEST_PARALLEL_BODY_LEG_RETURN:
            # Both timelines use phase_elapsed starting at ZERO.
            recovery_stage = "parallel"
        else:
            # Legacy: keep the toe planted until the torso finishes,
            # then run the leg return as a separate recovery stage.
            if phase_elapsed <= body_seconds + 0.000001:
                recovery_stage = "body"
            else:
                recovery_stage = "leg"
    elif elapsed >= play_end:
        phase = "hold"
        phase_elapsed = elapsed - play_end
        clip_time = length
    elif elapsed >= entry_end:
        phase = "strike"
        phase_elapsed = elapsed - entry_end
        clip_time = source_clip_time(kind, phase_elapsed, leg_id)
        speed = source_playback_speed(kind, phase_elapsed, leg_id)
    if kind == "stomp" and stomp_landed_clip_time >= 0.0:
        clip_time = stomp_landed_clip_time
        speed = 0.0
    var frame: Dictionary = {
        "id": leg_id, "kind": kind,
        "original_attack_only": true,
        "source_timed_attack": true,
        "direct_front_test": true,
        "time": elapsed,
        "authored_time": clip_time,
        "authored_playback_speed": speed,
        "entry_seconds": entry_end,
        "phase_elapsed": phase_elapsed,
        "phase": phase,
        "recovery_stage": recovery_stage,
        "parallel_recovery": TEST_PARALLEL_BODY_LEG_RETURN,
        "windup": entry_end,
        "strike": source_play_seconds(kind, leg_id),
        "hold": source_hold_seconds(kind),
        "recovery": source_return_seconds(kind),
        "leg_return_seconds": source_leg_return_seconds(),
        "body_return_seconds": source_body_return_seconds(kind),
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
            cooldown = maxf(cooldown,
                TEST_NO_STOP_SECONDS if TIMING_TEST_ENABLED
                else BETWEEN_ATTACKS_SECONDS)
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
        source_rate = source_playback_speed("sweep", wall_strike_t)
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
