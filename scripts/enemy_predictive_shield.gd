extends RefCounted
## Automatic predictive shield on a hostile Sapient. Not the player's guard SH.
## Straight, long-range projectiles are almost entirely predicted/mitigated;
## close-range articulated strikes force inefficient local protection.
const MAX_SP: float = 100.0
const MELEE_REDUCTION: float = 0.25
const RANGED_REDUCTION: float = 0.95
const REGEN_DELAY: float = 4.0
const REGEN_PER_SECOND: float = 20.0

var sp: float = MAX_SP
var recovery_pause: float = 0.0

func ratio() -> float:
    return clampf(sp / MAX_SP, 0.0, 1.0)

func reset() -> void:
    sp = MAX_SP
    recovery_pause = 0.0

func apply_hit(raw_power: float, ranged: bool = false) -> Dictionary:
    # Evaluate mitigation BEFORE consuming SP, never double-count the hit.
    var before: float = ratio()
    var reduction: float = (RANGED_REDUCTION if ranged else MELEE_REDUCTION) * before
    # The fixed per-contact portion rewards frequent hits without invalidating
    # heavy strikes. Ranged attacks can chip the barrier but are inefficient.
    var drain: float = (2.0 + maxf(0.0, raw_power) * 0.05) if ranged else (
        8.0 + maxf(0.0, raw_power) * 0.16)
    sp = maxf(0.0, sp - drain)
    recovery_pause = REGEN_DELAY
    return {
        "damage_multiplier": 1.0 - reduction,
        "ratio_before": before,
        "ratio_after": ratio(),
        "absorbed_sp": minf(before * MAX_SP, drain),
        "broken": before > 0.0 and sp <= 0.0,
    }

func advance(delta: float) -> void:
    if delta <= 0.0:
        return
    # No extra hidden recovery frame after the 4s deadline, even if a
    # frame crosses it. Every confirmed hit restarts the delay.
    var active_time: float = delta
    if recovery_pause > 0.0:
        active_time = maxf(0.0, delta - recovery_pause)
        recovery_pause = maxf(0.0, recovery_pause - delta)
    if active_time > 0.0 and sp < MAX_SP:
        sp = minf(MAX_SP, sp + REGEN_PER_SECOND * active_time)
