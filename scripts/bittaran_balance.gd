extends RefCounted
## SERA v535: Bittaran A-build ten-minute combat balance (2026-11-22).
## Canonical accepted values; the 2026-11-21 proposal is retained as history.
## Only Bittaran uses these boss modifiers. Standard training attacks remain
## unchanged. The 10-minute objective is a performance target, not a timer.

const BOSS_MAX_HP: int = 2550
const FRONT_LEG_INTEGRITY: float = 720.0
const REAR_LEG_INTEGRITY: float = 620.0
const HEAD_INTEGRITY: float = 150.0

# Applied to the already shield-mitigated and part-armored HP damage.
# Do not apply these multipliers to the independent part-break gauge.
const LEG_HP_MULTIPLIER: float = 0.75
const HEAD_HP_MULTIPLIER: float = 2.50
const BODY_HP_MULTIPLIER: float = 1.0

# The shared attack table is AIM=18, LEAD=22, SHOCK=28, ARC=34.
# Each Bittaran attack uses its original index (and matching guard cost)
# but its own scalar, without altering training-room behavior.
const STOMP_DAMAGE: float = 30.0
const KICK_DAMAGE: float = 22.0
const SWEEP_DAMAGE: float = 28.0
const BELLY_DAMAGE_MULTIPLIER: float = 0.28
const RAILGUN_DAMAGE_MULTIPLIER: float = 0.45

static func part_integrity(id: String) -> float:
    match id:
        "head":
            return HEAD_INTEGRITY
        "leg_fl", "leg_fr":
            return FRONT_LEG_INTEGRITY
        "leg_rl", "leg_rr":
            return REAR_LEG_INTEGRITY
    return 0.0

static func hp_multiplier(id: String) -> float:
    if id == "head":
        return HEAD_HP_MULTIPLIER
    if id.begins_with("leg_"):
        return LEG_HP_MULTIPLIER
    return BODY_HP_MULTIPLIER

static func incoming_damage_multiplier(kind: String) -> float:
    match kind:
        "stomp":
            return STOMP_DAMAGE / 28.0
        "kick":
            return KICK_DAMAGE / 22.0
        "sweep":
            return SWEEP_DAMAGE / 34.0
    return 1.0
