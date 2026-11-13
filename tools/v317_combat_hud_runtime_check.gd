extends SceneTree
## v317 Stage14: real training scene combat HUD priority and exact text.
const HUD = preload("res://scripts/sera_combat_hud_text.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_COMBAT_HUD_RUNTIME_FAIL: " + message)
    quit(1)

func _render(game: Node3D, moving: bool = false, stepping: bool = false,
        kick_side: int = 0, flick: Vector2 = Vector2.ZERO, step_side: int = 1,
        somersault: bool = false, landing: bool = false, jumping: bool = false) -> String:
    game.call("_refresh_combat_state_hud",
        moving, stepping, kick_side, flick, step_side, somersault, landing, jumping)
    var label: Label = game.get("state_label")
    return label.text


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var constants: Dictionary = game.get_script().get_script_constant_map()
    var states: Dictionary = constants.get("CombatState", {})
    var rig: Node3D = game.get("rig")
    if rig == null or game.get("state_label") == null or not states.has("IDLE"):
        _fail("scene HUD, rig or combat enum unavailable")
        return

    game.set("combat_state", int(states["IDLE"]))
    game.set("down_remaining", 0.0)
    game.set("guard_break_remaining", 0.0)
    game.set("damage_reaction_active", false)
    game.set("guard_active", false)
    game.set("back_somersault_active", false)
    game.set("landing_active", false)
    game.set("movement_boost_active", false)
    game.set("boost_pose_grace_remaining", 0.0)
    game.set("gesture_active", false)
    if _render(game) != "WAIT  |  Wait_motion":
        _fail("idle WAIT label changed")
        return

    # Priority: down overrides damage/guard/STEP and any ordinary attack.
    game.set("down_remaining", 0.25)
    game.set("guard_break_remaining", 0.25)
    game.set("damage_reaction_active", true)
    game.set("guard_active", true)
    if _render(game, false, true, 1) != "DOWN / INVULNERABLE":
        _fail("DOWN priority changed")
        return
    game.set("down_remaining", 0.0)
    if _render(game, false, true, 1).find("GUARD BREAK  ") != 0:
        _fail("guard-break priority changed")
        return
    game.set("guard_break_remaining", 0.0)
    if _render(game, false, true, 1) != "DAMAGE  |  Damageknock":
        _fail("damage priority changed")
        return
    game.set("damage_reaction_active", false)
    if _render(game, false, true, 1) != HUD.guard_label(
            bool(rig.call("guard_reaction_playing"))):
        _fail("guard reaction label or priority changed")
        return
    game.set("guard_active", false)

    # Somersault precedes landing, both precede ordinary STEP/jump.
    game.set("back_somersault_active", true)
    var authored: bool = bool(game.get("back_somersault_has_authored_clip"))
    if _render(game, false, true, 0, Vector2.ZERO, 1, true, true, true) != HUD.somersault_label(authored):
        _fail("somersault label or priority changed")
        return
    game.set("back_somersault_active", false)
    game.set("landing_active", true)
    game.set("landing_from_somersault", true)
    if _render(game, false, false, 0, Vector2.ZERO, 1, false, true, true) != "KICK BACK LAND  |  0.2s":
        _fail("somersault landing text changed")
        return
    game.set("landing_active", false)
    game.set("landing_from_somersault", false)
    game.set("jump_fall_after_action", true)
    if _render(game, false, false, 0, Vector2.ZERO, 1, false, false, true) != "AIR FALL  |  Jump":
        _fail("jump fallback text changed")
        return

    # STEP direction threshold, diagonals and buffered kick branches.
    var steps: Array = [
        [1, Vector2.ZERO, 1, "KICK RIGHT  |  Kick_r"],
        [-1, Vector2.ZERO, -1, "KICK LEFT  |  Kick_l"],
        [0, Vector2(0.0, -0.9), 1, "STEP FORWARD  |  Frontstep"],
        [0, Vector2(0.0, 0.9), 1, "STEP BACK  |  Backstep"],
        [0, Vector2(0.4, 0.3), -1, "STEP DIAGONAL  |  BLENDED"],
        [0, Vector2(1.0, 0.0), 1, "STEP RIGHT  |  Step_R"],
        [0, Vector2(-1.0, 0.0), -1, "STEP LEFT  |  Step_L"],
    ]
    for item in steps:
        if _render(game, false, true, int(item[0]), item[1], int(item[2])) != str(item[3]):
            _fail("STEP/kick label changed: " + str(item[3]))
            return
    if HUD.step_label(0, Vector2(0.0, -0.8), 1) != "STEP DIAGONAL  |  BLENDED" \
            or HUD.step_label(0, Vector2(0.0, 0.8), 1) != "STEP DIAGONAL  |  BLENDED":
        _fail("STEP strict thresholds changed")
        return

    # All combat states preserve exact formatting and queued clip priority.
    game.set("combat_state", int(states["STRIKE"]))
    game.set("strike_index", 1)
    for queued in [2, 1, 0]:
        game.set("buffered_side_kick_side", queued)
        var stages: int = int(game.call("_strike_stage_count"))
        var clip: String = str(game.call("_active_strike_clip", 1)) if queued == 0 else ""
        if _render(game) != HUD.strike_label(1, stages, queued, clip):
            _fail("STRIKE queued kick/clip formatting changed")
            return
    game.set("combat_state", int(states["DASH"]))
    game.set("melee_boost_elapsed", 0.18)
    var stats: Dictionary = game.get("part_stats")
    var expected_dash: String = HUD.dash_label(
        float(stats.get("melee_boost_speed", 11.5)), 0.18,
        float(stats.get("melee_boost_duration", 0.4)))
    if _render(game) != expected_dash:
        _fail("DASH speed/duration formatting changed")
        return
    game.set("combat_state", int(states["BACK_KICK_TRACK"]))
    game.set("back_kick_track_elapsed", 0.07)
    if _render(game) != HUD.back_kick_track_label(0.07, float(constants["BASH_TRACK_SECONDS"])):
        _fail("BACK_KICK_TRACK text changed")
        return
    game.set("combat_state", int(states["BASH_TRACK"]))
    game.set("bash_track_elapsed", 0.12)
    if _render(game) != HUD.bash_track_label(0.12, float(constants["BASH_TRACK_SECONDS"])):
        _fail("BASH_TRACK text changed")
        return
    game.set("combat_state", int(states["STRIKE_TRACK"]))
    game.set("followup_track_elapsed", 0.11)
    if _render(game) != HUD.strike_track_label(1, 0.11, float(constants["FOLLOWUP_TRACK_SECONDS"])):
        _fail("STRIKE_TRACK text changed")
        return
    game.set("combat_state", int(states["BASH"]))
    if _render(game) != "SHIELD BASH  |  Bash":
        _fail("BASH text changed")
        return
    game.set("combat_state", int(states["MELEE_APPROACH"]))
    if _render(game) != "MELEE APPROACH  |  meleeboost":
        _fail("MELEE_APPROACH text changed")
        return

    # Default RUN/BOOST/pose-hold queries are lazy and mode-specific.
    game.set("combat_state", int(states["IDLE"]))
    game.set("movement_boost_active", true)
    if _render(game, true) != HUD.boost_label(str(rig.call("get_boost_dominant_clip"))):
        _fail("BOOST clip display changed")
        return
    game.set("movement_boost_active", false)
    game.set("boost_pose_grace_remaining", 0.15)
    game.set("gesture_active", true)
    if _render(game, false) != HUD.boost_hold_label(str(rig.call("get_boost_dominant_clip"))):
        _fail("BOOST pose HOLD priority changed")
        return
    game.set("boost_pose_grace_remaining", 0.0)
    if _render(game, true) != HUD.run_label(str(rig.call("get_run_dominant_clip"))):
        _fail("RUN clip display changed")
        return
    print("SERA_COMBAT_HUD_RUNTIME_PASS: priority, STEP, strike, dash, clips")
    quit(0)
