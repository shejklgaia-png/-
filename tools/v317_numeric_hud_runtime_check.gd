extends SceneTree
## Real Godot scene validates HUD numeric presentation without changing combat.
const VIEW = preload("res://scripts/sera_numeric_hud.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_NUMERIC_HUD_RUNTIME_FAIL: " + message)
    quit(1)

func _near(a: float, b: float) -> bool:
    return absf(a - b) <= 0.0001

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    # v338 hides legacy telemetry; expose it only in this formatter test.
    (game.get("hud_panel") as Control).show()
    var c: Dictionary = game.get_script().get_script_constant_map()
    var vital: Control = game.get("vitals_hud")
    var hp_title: Label = game.get("hp_label")
    var hp_fill: ColorRect = game.get("hp_fill")
    var resource: Label = game.get("resources_label")
    var core: Label = game.get("core_label")
    var step: Label = game.get("step_status_label")
    var detail: Label = game.get("step_detail_label")
    var part_line: Label = game.get("target_parts_label")
    var parts: Node3D = game.get("target_parts")
    if vital == null or hp_title == null or hp_fill == null or resource == null \
            or core == null or step == null or detail == null or part_line == null \
            or parts == null:
        _fail("live numeric HUD nodes missing")
        return

    # Player HUD passes exactly the current max HP and EN lock. It does not
    # alter real EN or HP state, and the child meter keeps its 25% warning.
    game.set("player_hp", 41.0)
    game.set("energy", 24.9)
    game.set("energy_exhausted", true)
    game.call("_refresh_player_hp_bar")
    if not _near(float(vital.get("hp")), 41.0) \
            or not _near(float(vital.get("en")), 24.9) \
            or not bool(vital.get("en_locked")) \
            or not _near(float(vital.get("maximum_en")), float(c["TEST_EN_MAX"])):
        _fail("player HP/EN values or 60% recovery lock not forwarded")
        return
    if not _near(float(vital.get("maximum_hp")),
            float(game.get("part_stats").get("max_hp", 800.0))):
        _fail("equipment-dependent player max HP lost")
        return
    game.set("energy_exhausted", false)
    game.call("_refresh_player_hp_bar")
    if bool(vital.get("en_locked")):
        _fail("player EN lock display did not clear")
        return

    # Boss bar preserves the 40% color threshold and restarting label.
    game.set("target_hp", 201)
    game.call("_refresh_hp_bar")
    if hp_title.text != "TARGET   201 / 500 HP" \
            or not _near(hp_fill.size.x, float(c["TARGET_HP_BAR_WIDTH"]) * 201.0 / 500.0) \
            or hp_fill.color != Color("5de4d1"):
        _fail("target above-40% HP display changed")
        return
    game.set("target_hp", 200)
    game.call("_refresh_hp_bar")
    if hp_fill.color != Color("ffb85d") or hp_title.text != "TARGET   200 / 500 HP":
        _fail("target 40% caution transition changed")
        return
    game.set("target_hp", 0)
    game.call("_refresh_hp_bar")
    if hp_title.text != "TARGET   DOWN / RESTARTING" \
            or not _near(hp_fill.size.x, 0.0):
        _fail("boss defeated status/bar changed")
        return

    # SH uses ceil and defense uses round, including fractional values.
    if VIEW.defense_shield_text(0.164, 9.01) != "DEF 16%  SH 10" \
            or VIEW.defense_shield_text(0.199, 0.0) != "DEF 20%  SH 0":
        _fail("defense/shield rounding changed")
        return
    game.set("shield", 9.01)
    game.set("locked_target_part_id", "")
    game.set("target_hp", 123)
    game.set("stagger_value", 11.2)
    game.set("part_break_remaining", 0.0)
    game.set("stagger_remaining", 0.0)
    game.set("target_move_enabled", false)
    game.call("_refresh_numeric_status_hud")
    var expected_defense: String = VIEW.defense_shield_text(
        float(game.get("part_stats").get("defense", 0.16)), 9.01)
    if resource.text != expected_defense \
            or core.text != "LOCK BODY  123/500  STAGGER 12/50  HOLD" \
            or part_line.text != str(parts.call("status_line")):
        _fail("resource/lock/parts line diverged from real scene")
        return
    game.set("target_move_enabled", true)
    game.call("_refresh_numeric_status_hud")
    if not core.text.ends_with("MOVE"):
        _fail("moving target status missing")
        return
    game.set("stagger_remaining", 0.12)
    game.call("_refresh_numeric_status_hud")
    if not core.text.ends_with("STUN"):
        _fail("stagger status missing")
        return
    game.set("part_break_remaining", 0.5)
    game.call("_refresh_numeric_status_hud")
    if not core.text.ends_with("BREAK"):
        _fail("part break status missing")
        return
    game.set("part_break_remaining", 3.0)
    game.call("_refresh_numeric_status_hud")
    if not core.text.ends_with("DOWN"):
        _fail("3-second DOWN status priority changed")
        return

    # Locking one specific part must use its own HP not the boss HP.
    game.set("locked_target_part_id", "head")
    game.set("part_break_remaining", 0.0)
    game.set("stagger_remaining", 0.0)
    game.call("_refresh_numeric_status_hud")
    var name: String = str(parts.call("get_part_name", "head"))
    var durability: float = float(parts.call("get_part_integrity", "head"))
    var maximum: float = float(parts.call("get_part_max_integrity", "head"))
    if core.text != VIEW.target_lock_text(name, durability, maximum, 11.2, 0.0, 0.0, true):
        _fail("locked part HP or status used boss HP instead")
        return

    # STEP speed uses the live snapshot during STEP and equipment speed
    # outside STEP. Detail priority is Kick B > landing > kick > debug > last.
    game.set("step_active", false)
    game.set("back_somersault_active", false)
    game.set("landing_from_somersault", false)
    game.set("kick_debug_remaining", 0.0)
    game.set("step_has_last", false)
    game.call("_refresh_step_status_ui")
    if step.text != VIEW.step_speed_text(0.0, false, float(c["STEP_SPEED"]),
            float(game.get("part_stats").get("step_speed_mult", 1.0))) \
            or detail.text != "STEP ALL 5.0m":
        _fail("idle STEP numeric display changed")
        return
    game.set("step_active", true)
    game.set("side_kick_active", false)
    game.set("step_speed_current", 12.34)
    game.set("step_arc_length", 4.25)
    game.call("_refresh_step_status_ui")
    if step.text != "STEP SPEED 12.3m/s" \
            or detail.text != "STEP 4.25m planned":
        _fail("active STEP speed or planned arc changed")
        return
    game.set("side_kick_active", true)
    game.set("side_kick_side", -1)
    game.call("_refresh_step_status_ui")
    if detail.text != "KICK L 4.25m planned":
        _fail("side-kick indicator changed")
        return
    game.set("side_kick_active", false)
    game.set("kick_debug_remaining", 2.0)
    game.set("kick_debug_text", "KICK: CHECK")
    game.call("_refresh_step_status_ui")
    if detail.text != "KICK: CHECK":
        _fail("debug override in STEP changed")
        return
    game.set("step_active", false)
    game.set("kick_debug_remaining", 0.0)
    game.set("step_has_last", true)
    game.set("step_traveled_distance", 1.23)
    game.set("step_last_elapsed", 0.45)
    game.call("_refresh_step_status_ui")
    if detail.text != "LAST 1.23m  /  0.45s":
        _fail("collision-resolved last STEP distance/seconds changed")
        return
    game.set("landing_from_somersault", true)
    game.call("_refresh_step_status_ui")
    if detail.text != "KICK B / LAND 0.2s":
        _fail("Kick B landing priority changed")
        return
    game.set("back_somersault_active", true)
    game.call("_refresh_step_status_ui")
    if detail.text != "KICK B / BACK ARC 5.0m":
        _fail("Kick B arc priority changed")
        return
    print("SERA_NUMERIC_HUD_RUNTIME_PASS: HP/EN, DEF/SH, lock, STEP speed/history")
    quit(0)
