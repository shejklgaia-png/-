extends RefCounted
## Stateless enemy lifecycle gates. The training scene owns all live state,
## target motion, lock/part/shooter resets, effects, UI and KO teleporting.
## These policies intentionally preserve the original tick's ordering.

const RESPAWN_WAIT: int = 0
const RESPAWN_RETRY: int = 1
const RESPAWN_RESET: int = 2


static func movement_frozen(movement_enabled: bool, warning_active: bool,
        boss_hp: int, stagger_remaining: float, part_break_remaining: float,
        down_remaining: float, training_ko_remaining: float) -> bool:
    # The warning keeps the firing telegraph's origin stable until launch.
    return (not movement_enabled or warning_active or boss_hp <= 0
        or stagger_remaining > 0.0 or part_break_remaining > 0.0
        or down_remaining > 0.0 or training_ko_remaining > 0.0)


static func fire_allowed(boss_hp: int, player_hp: float,
        stagger_remaining: float, part_break_remaining: float) -> bool:
    # Preserve the distinct shooting gate: down/telegraph do not independently
    # disallow fire here. EnemyRangedAI owns its own attack cooldowns.
    return (boss_hp > 0 and player_hp > 0.0
        and stagger_remaining <= 0.0 and part_break_remaining <= 0.0)


static func respawn_action(remaining_after_tick: float,
        combo_retains_lock: bool) -> int:
    if remaining_after_tick > 0.0:
        return RESPAWN_WAIT
    if combo_retains_lock:
        return RESPAWN_RETRY
    return RESPAWN_RESET
