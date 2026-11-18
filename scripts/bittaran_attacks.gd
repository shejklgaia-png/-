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
const SOURCE_ENTRY_SECONDS: float = 0.32
# The new authored sweep contains its own windup and complete toe return.
# Keep only a short neutral-to-first-key transition before playback.
const SWEEP_ENTRY_SECONDS: float = 0.32
# Following BODY recovery, return the striking leg directly to Wait.
# No stomp windup, lift waypoint, or artificial bounce.
const SOURCE_LEG_RETURN_SECONDS: float = 1.20
const SOURCE_BODY_RETURN_SECONDS: float = 0.62
const SOURCE_KICK_STOMP_RETURN_SECONDS: float = (
    SOURCE_LEG_RETURN_SECONDS + SOURCE_BODY_RETURN_SECONDS)
const ORIGINAL_CLIP_LENGTHS: Dictionary = {
    "stomp": 1.75, "kick": 1.0, "sweep": 2.625
}
## The 22:13 source only has rear STOMP and SWEEP (not rear KICK).
const REAR_CLIP_LENGTHS: Dictionary = {
    "stomp": 1.0, "sweep": 1.54167
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
# The source file already finishes the foot and chest recovery.
# This short handoff only bridges the displayed Wait/Idle contact pose.
const SWEEP_RECOVERY_SECONDS: float = 0.25
const BETWEEN_ATTACKS_SECONDS: float = 1.35
# v451: body-relative source clip reach sectors. Use the player's
# horizontal distance and bearing, not a generic 9m square hitbox.
# The STOMP is a close, all-side toe slam, KICK is a frontal thrust;
# the four-leg SWEEP covers mid/far and lateral/rear flanks. Every
# selection is also validated against the actual available foot.
const STOMP_RANGE_METERS: float = 2.85
const KICK_MIN_RANGE_METERS: float = 2.65
const KICK_RANGE_METERS: float = 5.15
const KICK_HALF_ANGLE_DEGREES: float = 38.0
const SWEEP_MIN_RANGE_METERS: float = 2.70
const SWEEP_RANGE_METERS: float = 7.10
const SWEEP_HALF_ANGLE_DEGREES: float = 115.0
const REAR_SWEEP_HALF_ANGLE_DEGREES: float = 165.0
# v452: Source-authoritative impact intervals, verified against the
# visible toe's world XZ path and floor contact in the REAL battle.
# KICK still starts 0.10s AFTER the extension begins at t=.25.
# SWEEP must damage on the FIRST front-to-back planted stroke, NOT
# on the later return: front toe reaches floor ~.78 and travels from
# +Z=3.7 to 1.7 until 1.25; rear moves from +Z~0 to -2.6
# between .25 and .75. Both slow/turn after these keys. During that
# slow aftermath and the complete reset there is NO damage.
const SOURCE_HIT_DELAY_SECONDS: float = 0.10
const KICK_EXTENSION_START_KEY_SECONDS: float = 0.25
const KICK_EXTENSION_END_KEY_SECONDS: float = 0.75
const SWEEP_FRONT_FIRST_STROKE_START_KEY_SECONDS: float = 0.75
const SWEEP_REAR_FIRST_STROKE_START_KEY_SECONDS: float = 0.25
const SWEEP_FRONT_FIRST_STROKE_END_KEY_SECONDS: float = 1.25
const SWEEP_REAR_FIRST_STROKE_END_KEY_SECONDS: float = 0.75

## The rendered LOWER-LEG and FOOT are still the only damage
## geometry. These are motion-time gates, not substitute hitboxes.
static func source_hit_start_seconds(attack_kind: String,
        attack_id: String) -> float:
    if attack_kind == "kick" and attack_id.begins_with("leg_f"):
        return KICK_EXTENSION_START_KEY_SECONDS + SOURCE_HIT_DELAY_SECONDS
    if attack_kind == "sweep":
        # The visual contact test is applied AFTER sampling the real
        # skeletal mesh; no artificial extra .10s on this first scrape.
        return (SWEEP_REAR_FIRST_STROKE_START_KEY_SECONDS
            if attack_id.begins_with("leg_r")
            else SWEEP_FRONT_FIRST_STROKE_START_KEY_SECONDS)
    return INF


static func source_hit_window(attack_kind: String, attack_id: String,
        clip_time: float) -> bool:
    var begin: float = source_hit_start_seconds(
        attack_kind, attack_id)
    if begin == INF or clip_time + 0.000001 < begin:
        return false
    var end: float = 0.0
    match attack_kind:
        "kick":
            end = KICK_EXTENSION_END_KEY_SECONDS
        "sweep":
            end = (SWEEP_REAR_FIRST_STROKE_END_KEY_SECONDS
                if attack_id.begins_with("leg_r")
                else SWEEP_FRONT_FIRST_STROKE_END_KEY_SECONDS)
        _:
            return false
    return clip_time <= end + 0.000001

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

func cancel() -> void:
    kind = ""
    leg_id = ""
    elapsed = 0.0
    cooldown = (TEST_NO_STOP_SECONDS
        if TIMING_TEST_ENABLED else BETWEEN_ATTACKS_SECONDS)
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

## A front KICK must use an authored front leg. Rear legs have
## STOMP/SWEEP assets only. For other attacks choose the closest real
## foot, retaining the small round-robin tie bias.
func _choose_leg(player_position: Vector3, feet: Dictionary,
        attack_kind: String, boss_position: Vector3 = Vector3.ZERO,
        boss_yaw: float = 0.0) -> String:
    var offset: Vector3 = player_position - boss_position
    var bearing: float = wrapf(
        atan2(offset.x, offset.z) - boss_yaw, -PI, PI)
    var behind: bool = absf(rad_to_deg(bearing)) > 90.0
    var rear_only: bool = (
        attack_kind == "sweep" and absf(
        rad_to_deg(bearing)) > SWEEP_HALF_ANGLE_DEGREES)
    var best: String = ""
    var best_score: float = INF
    for n in range(LEG_IDS.size()):
        var index: int = (next_leg_index + n) % LEG_IDS.size()
        var id: String = LEG_IDS[index]
        if not feet.has(id):
            continue
        var rear_leg: bool = id.begins_with("leg_r")
        if attack_kind == "kick" and rear_leg:
            continue
        # A target outside the frontal 230-degree arc is attacked
        # only by an authored REAR SWEEP. Never fake forward-leg
        # reach behind the chest just to satisfy the AI selector.
        if rear_only and not rear_leg:
            continue
        var foot: Vector3 = feet[id]
        var horizontal: Vector2 = Vector2(
            foot.x - player_position.x, foot.z - player_position.z)
        var distance: float = horizontal.length()
        if distance > START_RANGE_METERS:
            continue
        # Anatomical proximity remains the dominant factor, with a
        # modest front/rear bias that matches the player's actual
        # bearing. Side preference naturally follows live foot XZ.
        var score: float = distance + float(n) * 0.12
        if rear_leg != behind:
            score += 1.0
        if score < best_score:
            best_score = score
            best = id
    return best


## Attack choice is fixed once the pre-attack/clip starts; a moving
## player cannot flip it midway through a windup.
## Boss +Z is forward (the same yaw convention used by BittaranAI).
func _choose_kind(player_position: Vector3, boss_position: Vector3,
        boss_yaw: float) -> String:
    var offset: Vector2 = Vector2(
        player_position.x - boss_position.x,
        player_position.z - boss_position.z)
    var distance: float = offset.length()
    if distance > SWEEP_RANGE_METERS:
        return ""
    # No broad lateral collision is invented by the sector selector.
    # STOMP hits very close targets with the closest physical leg,
    # including the rear; the real toe mesh still decides damage.
    if distance <= STOMP_RANGE_METERS:
        return "stomp"
    var angle_degrees: float = absf(rad_to_deg(wrapf(
        atan2(offset.x, offset.y) - boss_yaw, -PI, PI)))
    if distance >= KICK_MIN_RANGE_METERS and (
            distance <= KICK_RANGE_METERS) and (
            angle_degrees <= KICK_HALF_ANGLE_DEGREES):
        return "kick"
    # Side/diagonal/behind targets cannot trigger frontal KICK.
    # The authored rear SWEEP permits larger rearward bearings,
    # but the 15-degree blind spot directly behind requires TURN.
    if distance >= SWEEP_MIN_RANGE_METERS:
        if angle_degrees <= SWEEP_HALF_ANGLE_DEGREES:
            return "sweep"
        if angle_degrees <= REAR_SWEEP_HALF_ANGLE_DEGREES:
            return "sweep"
    return ""


## Never repeat the same attack TYPE twice in a row, even with another
## leg. Do not force a physically invalid alternative: the movement AI
## must change the range/bearing until a different authored move is legal.
## Retain last_kind through normal completion and interruption; reset()
## alone clears the combat history on a new boss encounter.
func repeat_kind_blocked(player_position: Vector3,
        boss_position: Vector3, boss_yaw: float) -> bool:
    if is_active() or last_kind.is_empty():
        return false
    var candidate: String = _choose_kind(
        player_position, boss_position, boss_yaw)
    return not candidate.is_empty() and candidate == last_kind


func _choose_nonrepeating_kind(player_position: Vector3,
        boss_position: Vector3, boss_yaw: float) -> String:
    var candidate: String = _choose_kind(
        player_position, boss_position, boss_yaw)
    if not candidate.is_empty() and candidate == last_kind:
        return ""
    return candidate


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
    # The new sweep is sampled at EXACT Blockbench time, not 0.5x.
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


static func source_play_seconds(attack_kind: String,
        attack_id: String = "") -> float:
    var length: float = source_clip_length(attack_kind, attack_id)
    var original: float = length
    if attack_kind == "sweep":
        return length
    return original - source_anticipation_saved_seconds(
        attack_kind, attack_id)


static func source_hold_seconds(attack_kind: String) -> float:
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


static func source_leg_return_seconds(attack_kind: String = "") -> float:
    if attack_kind == "sweep":
        return SWEEP_RECOVERY_SECONDS / source_return_speed()
    return SOURCE_LEG_RETURN_SECONDS / source_return_speed()


static func source_return_seconds(attack_kind: String) -> float:
    if TEST_PARALLEL_BODY_LEG_RETURN:
        # Start both motions together. Continue until BOTH finish.
        return maxf(source_body_return_seconds(attack_kind),
            source_leg_return_seconds(attack_kind))
    return (source_body_return_seconds(attack_kind)
        + source_leg_return_seconds(attack_kind))


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
    # Do not remap internal windup, swing, or toe-return key timestamps.
    if attack_kind == "sweep":
        return minf(play_t, length)
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
    if attack_kind == "sweep":
        return 1.0
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
        available_feet: Dictionary, permitted: bool,
        boss_position: Vector3, boss_yaw: float) -> Dictionary:
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
        var selected_kind: String = _choose_nonrepeating_kind(
            player_position, boss_position, boss_yaw)
        if selected_kind.is_empty():
            return {}
        var selected: String = _choose_leg(
            player_position, authored_feet, selected_kind,
            boss_position, boss_yaw)
        if selected.is_empty():
            return {}
        _start(selected, selected_kind, false)
        last_kind = selected_kind
        next_kind_index = (ATTACK_KINDS.find(selected_kind) + 1) % ATTACK_KINDS.size()
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
        "leg_return_seconds": source_leg_return_seconds(kind),
        "authored_full_sweep": kind == "sweep",
        "body_return_seconds": source_body_return_seconds(kind),
        "stance_prepare": false,
        "tracking": false,
        "hit_window": phase == "strike" and source_hit_window(
            kind, leg_id, clip_time),
        "hit_start_seconds": source_hit_start_seconds(kind, leg_id),
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
        stance_ready: bool = false,
        boss_position: Vector3 = Vector3.ZERO,
        boss_yaw: float = 0.0) -> Dictionary:
    if ORIGINAL_ATTACK_ONLY:
        return _advance_original_only(delta, player_position,
            available_feet, permitted, boss_position, boss_yaw)
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
        var selected_kind: String = _choose_nonrepeating_kind(
            player_position, boss_position, boss_yaw)
        if selected_kind.is_empty():
            return {}
        var selected: String = _choose_leg(
            player_position, available_feet, selected_kind,
            boss_position, boss_yaw)
        if selected.is_empty():
            return {}
        _start(selected, selected_kind, true)
        last_kind = selected_kind
        next_kind_index = (ATTACK_KINDS.find(selected_kind) + 1) % ATTACK_KINDS.size()
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
