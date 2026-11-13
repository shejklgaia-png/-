extends RefCounted
## Pure EN/SH resource rules. The owning scene keeps actual state, effects,
## HUD refreshes, guard-break/down gating, and all timer advancement order.
## The caller passes current gameplay rates, limits and epsilon thresholds.

static func energy_spend(current_energy: float, exhausted: bool,
        amount: float, epsilon: float) -> Dictionary:
    # An action with no positive EN cost stays available during exhaustion.
    if amount <= 0.0:
        return {"allowed": true, "remaining": current_energy,
            "paid": false, "trigger_exhaustion": false}
    if exhausted:
        return {"allowed": false, "remaining": current_energy,
            "paid": false, "trigger_exhaustion": false}
    if current_energy + epsilon < amount:
        # Insufficient nonzero EN is not exhausted until the BOOST caller
        # explicitly consumes that last unusable sliver.
        return {"allowed": false, "remaining": current_energy,
            "paid": false, "trigger_exhaustion": current_energy <= epsilon}
    var remaining: float = maxf(0.0, current_energy - amount)
    return {"allowed": true, "remaining": remaining,
        "paid": true, "trigger_exhaustion": remaining <= epsilon}


static func next_recovery_pause(pause: float, delta: float) -> float:
    return maxf(0.0, pause - delta)


static func recovered_energy(current_energy: float, recovery_pause: float,
        delta: float, maximum: float, per_second: float) -> float:
    if recovery_pause <= 0.0:
        return minf(maximum, current_energy + per_second * delta)
    return current_energy


static func recovered_shield(current_shield: float, recovery_pause: float,
        guard_break_remaining: float, down_remaining: float,
        delta: float, maximum: float, per_second: float) -> float:
    if recovery_pause <= 0.0 and guard_break_remaining <= 0.0 and down_remaining <= 0.0:
        return minf(maximum, current_shield + per_second * delta)
    return current_shield


static func exhaustion_unlocked(exhausted: bool, current_energy: float,
        maximum: float, unlock_ratio: float) -> bool:
    return exhausted and current_energy >= maximum * unlock_ratio
