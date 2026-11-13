extends RefCounted
## Pure combat/debug HUD text. Main owns priority, state, rig clip queries
## and label nodes. All strings, timing and rounding match the v317 HUD.
## No scene reads, per-frame Dictionary allocation or retained state.

static func guard_label(reaction_playing: bool) -> String:
    return "GUARD HIT  |  Guard_REACTION" if reaction_playing else "GUARD  |  Guard"


static func somersault_label(authored_clip: bool) -> String:
    return "KICK BACK  |  Kick_b" if authored_clip else "KICK BACK  |  Jump FALLBACK"


static func landing_label(from_somersault: bool) -> String:
    return "KICK BACK LAND  |  0.2s" if from_somersault else "JUMP LAND  |  Jump"


static func jump_label(falling_after_action: bool) -> String:
    return "AIR FALL  |  Jump" if falling_after_action else "JUMP  |  Jump (1.5m)"


static func step_label(kick_side: int, step_flick: Vector2, step_side: int) -> String:
    if kick_side != 0:
        return "KICK RIGHT  |  Kick_r" if kick_side > 0 else "KICK LEFT  |  Kick_l"
    if step_flick.y < -0.8:
        return "STEP FORWARD  |  Frontstep"
    if step_flick.y > 0.8:
        return "STEP BACK  |  Backstep"
    if absf(step_flick.y) > 0.15:
        return "STEP DIAGONAL  |  BLENDED"
    return "STEP RIGHT  |  Step_R" if step_side > 0 else "STEP LEFT  |  Step_L"


static func strike_label(stage_index: int, stage_count: int,
        queued_kick_side: int, clip: String) -> String:
    if queued_kick_side == 2:
        return "STRIKE %d/%d  |  KICK B QUEUED" % [stage_index + 1, stage_count]
    if queued_kick_side != 0:
        return "STRIKE %d/%d  |  KICK QUEUED" % [stage_index + 1, stage_count]
    return "STRIKE %d/%d  |  %s" % [stage_index + 1, stage_count, clip]


static func dash_label(speed: float, elapsed: float, duration: float) -> String:
    return "MELEE BOOST  %.1fm/s  %.2f/%.1fs" % [speed, elapsed, duration]


static func back_kick_track_label(elapsed: float, limit: float) -> String:
    return "KICK BACK TRACK  %.2f / %.2fs" % [elapsed, limit]


static func bash_track_label(elapsed: float, limit: float) -> String:
    return "BASH WINDUP  %.2f / %.2fs" % [elapsed, limit]


static func strike_track_label(stage_index: int, elapsed: float,
        limit: float) -> String:
    return "MELEE %d WINDUP  %.2f / %.2fs" % [stage_index + 1, elapsed, limit]


static func boost_label(clip: String) -> String:
    return "BOOST  x1.5  |  %s" % clip


static func boost_hold_label(clip: String) -> String:
    return "RUN  |  BOOST POSE HOLD  |  %s" % clip


static func run_label(clip: String) -> String:
    return "RUN  x1.0  |  %s" % clip
