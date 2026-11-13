extends RefCounted
## SERA combat flow decisions and timeline arithmetic extracted from main.gd.
## Stateless: main.gd still owns combat_state, queued inputs, timers, resources
## and every effect/animation side effect. This file must not access the scene.

static func guard_can_start(guard_active: bool, damage_reaction_active: bool,
        down_remaining: float, energy_shield_blocked: bool,
        guard_break_remaining: float, landing_active: bool, jump_active: bool,
        step_active: bool, back_somersault_active: bool, combat_idle: bool,
        rig_ready: bool) -> bool:
    return (not guard_active and not damage_reaction_active
        and down_remaining <= 0.0 and not energy_shield_blocked
        and guard_break_remaining <= 0.0 and not landing_active
        and not jump_active and not step_active and not back_somersault_active
        and combat_idle and rig_ready)


static func followup_window_open(bash_followup_seconds: float,
        bash_loop_seconds: float) -> bool:
    return (bash_followup_seconds > 0.0 or bash_loop_seconds > 0.0)


static func combo_retains_lock(combat_busy: bool, side_kick_active: bool,
        back_somersault_active: bool, somersault_landing_active: bool,
        followup_open: bool) -> bool:
    # Broken parts remain locked during every strike, Bash, side/back Kick,
    # somersault landing, and both idle follow-up windows.
    return (combat_busy or side_kick_active or back_somersault_active
        or somersault_landing_active or followup_open)


static func strike_stage_count(katana: bool, regular_clip_count: int) -> int:
    return 2 if katana else regular_clip_count


static func strike_is_finisher(stage: int, total_stages: int) -> bool:
    return stage == total_stages - 1


static func active_strike_clip(stage: int, katana: bool,
        katana_first_clip: String, katana_second_clip: String,
        regular_clips: Array) -> String:
    if katana:
        return katana_second_clip if stage >= 1 else katana_first_clip
    return str(regular_clips[clampi(stage, 0, regular_clips.size() - 1)])


static func strike_cancel_time(stage: int, katana: bool,
        cancel_times: Array) -> float:
    if katana:
        return minf(float(cancel_times[stage]), 0.5)
    return float(cancel_times[stage])


static func melee3_flick_cancel_time(katana: bool, cancel_times: Array,
        regular_clip_count: int, delay: float) -> float:
    # For Katana's second clip, cancel at authored frame 7 + existing 0.05s.
    # Normal Melee3 uses the original last-stage 15/24 swing-through key.
    if katana:
        return 7.0 / 24.0 + delay
    return float(cancel_times[regular_clip_count - 1]) + delay


static func tracking_slice(delta: float, elapsed: float, limit_seconds: float) -> float:
    # Time remaining in a pursuit state is capped each physics tick;
    # never move for negative delta or after the window expires.
    return minf(maxf(0.0, delta),
        maxf(0.0, limit_seconds - elapsed))
