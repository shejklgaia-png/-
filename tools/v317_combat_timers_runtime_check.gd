extends SceneTree
## Real Godot main-scene regression for window expiry/stagger order.
const COMBAT_TIMERS = preload("res://scripts/sera_combat_timers.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_COMBAT_TIMERS_RUNTIME_FAIL: " + message)
    quit(1)

func _near(a: float, b: float) -> bool:
    return absf(a - b) < 0.000001

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene unavailable")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)

    for case in [[0.2, 0.05, 0.15], [0.05, 0.05, 0.0],
            [0.02, 0.05, 0.0], [0.0, 0.05, 0.0]]:
        var actual: float = COMBAT_TIMERS.remaining_after_delta(
            float(case[0]), float(case[1]))
        if not _near(actual, float(case[2])):
            _fail("countdown clamping changed: " + str(case))
            return
    if not _near(COMBAT_TIMERS.stagger_after_countdown(12.0, 0.01, 0.1, 8.0), 12.0)             or not _near(COMBAT_TIMERS.stagger_after_countdown(12.0, 0.0, 0.1, 8.0), 11.2)             or not _near(COMBAT_TIMERS.stagger_after_countdown(0.1, 0.0, 0.1, 8.0), 0.0):
        _fail("stagger decay gate, rate or floor changed")
        return

    # Original main.gd callback owns the actual timers and debugging UI.
    game.set("bash_followup_window_remaining", 0.12)
    game.set("bash_loop_window_remaining", 0.04)
    game.set("kick_debug_remaining", 0.03)
    game.call("_tick_combo_window_timers", 0.05)
    if not _near(float(game.get("bash_followup_window_remaining")), 0.07)             or not _near(float(game.get("bash_loop_window_remaining")), 0.0)             or not _near(float(game.get("kick_debug_remaining")), 0.0):
        _fail("main combo/debug expiry changed")
        return
    game.call("_tick_combo_window_timers", 0.08)
    if not _near(float(game.get("bash_followup_window_remaining")), 0.0):
        _fail("main combo window did not expire")
        return

    # A stagger window finishing on this frame permits immediate 8/s decay.
    game.set("stagger_remaining", 0.05)
    game.set("part_break_remaining", 0.3)
    game.set("stagger_value", 10.0)
    game.call("_tick_target_recovery_timers", 0.05)
    if not _near(float(game.get("stagger_remaining")), 0.0)             or not _near(float(game.get("part_break_remaining")), 0.25)             or not _near(float(game.get("stagger_value")), 9.6):
        _fail("stagger expiration did not decay on the same frame")
        return
    game.set("stagger_remaining", 0.20)
    game.set("stagger_value", 9.6)
    game.call("_tick_target_recovery_timers", 0.05)
    if not _near(float(game.get("stagger_value")), 9.6):
        _fail("stagger decayed during active stun")
        return
    game.set("stagger_remaining", 0.0)
    game.set("stagger_value", 0.1)
    game.call("_tick_target_recovery_timers", 0.05)
    if not _near(float(game.get("stagger_value")), 0.0):
        _fail("stagger decay underflowed")
        return

    # The extraction must not modify scene side effects or resource semantics.
    var combo_state: Dictionary = game.get_script().get_script_constant_map()
    if not combo_state.has("TEST_EN_MAX") or not combo_state.has("EN_RECOVERY_UNLOCK_RATIO"):
        _fail("resource/boost constants lost")
        return
    print("SERA_COMBAT_TIMERS_RUNTIME_PASS: combo expiry, debug callback, stagger & zero boundaries")
    quit(0)
