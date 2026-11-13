extends RefCounted
## Numeric HUD formatting and passed-node updates for the training scene.
## Main owns HP/EN/SH, damage, target part selection, timeouts and update order.
## No scene lookup, global mutable state or new transient HUD nodes.

static func present_player_vitals(hud: Control, player_hp: float,
        player_max_hp: float, energy: float, energy_max: float,
        exhausted: bool) -> void:
    if hud == null:
        return
    hud.call("set_vitals", player_hp, player_max_hp, energy, energy_max, exhausted)


static func present_target_health(label: Label, fill: ColorRect,
        target_hp: int, target_max_hp: int, bar_width: float) -> void:
    if label == null:
        return
    label.text = "TARGET   %d / %d HP" % [target_hp, target_max_hp] if target_hp > 0 else "TARGET   DOWN / RESTARTING"
    fill.size = Vector2(bar_width * float(target_hp) / float(target_max_hp), 7.0)
    fill.color = Color("5de4d1") if float(target_hp) / float(target_max_hp) > 0.40 else Color("ffb85d")


static func defense_shield_text(defense: float, shield: float) -> String:
    return "DEF %d%%  SH %d" % [roundi(defense * 100.0), ceili(shield)]


static func target_lock_text(part_name: String, integrity: float,
        maximum: float, stagger: float, part_break_remaining: float,
        stagger_remaining: float, target_move_enabled: bool) -> String:
    return "LOCK %s  %d/%d  STAGGER %d/50  %s" % [
        part_name, ceili(integrity), ceili(maximum), ceili(stagger),
        "DOWN" if part_break_remaining >= 3.0 else (
            "BREAK" if part_break_remaining > 0.0 else (
                "STUN" if stagger_remaining > 0.0 else (
                    "MOVE" if target_move_enabled else "HOLD")))]


static func step_speed_text(current_speed: float, active: bool,
        default_speed: float, speed_multiplier: float) -> String:
    var display_speed: float = current_speed
    if not active:
        display_speed = default_speed * speed_multiplier
    return "STEP SPEED %.1fm/s" % display_speed


static func step_detail_text(back_somersault_active: bool,
        landing_from_somersault: bool, step_active: bool,
        side_kick_active: bool, side_kick_side: int, step_arc_length: float,
        kick_debug_remaining: float, kick_debug_text: String,
        step_has_last: bool, step_traveled_distance: float,
        step_last_elapsed: float) -> String:
    if back_somersault_active:
        return "KICK B / BACK ARC 5.0m"
    if landing_from_somersault:
        return "KICK B / LAND 0.2s"
    if step_active:
        if side_kick_active:
            return "KICK %s %.2fm planned" % [
                "R" if side_kick_side > 0 else "L", step_arc_length]
        if kick_debug_remaining > 0.0:
            return kick_debug_text
        return "STEP %.2fm planned" % step_arc_length
    if kick_debug_remaining > 0.0:
        return kick_debug_text
    if step_has_last:
        # Report collision-resolved length, never planned STEP length.
        return "LAST %.2fm  /  %.2fs" % [
            step_traveled_distance, step_last_elapsed]
    return "STEP ALL 5.0m"
