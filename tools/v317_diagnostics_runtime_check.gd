extends SceneTree
## Real game-scene diagnostic isolation: OFF by default, touch button owns
## its hit rect, ON samples state, and OFF stops collecting.
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_DIAGNOSTICS_RUNTIME_FAILED: " + message)
    quit(1)
func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var toggle: Button = game.get("diagnostic_button")
    var copy_button: Button = game.get("diagnostic_copy_button")
    var overlay: Control = game.get("diagnostic_overlay")
    if toggle == null or copy_button == null or overlay == null:
        _fail("diagnostic controls missing")
        return
    if bool(game.get("diagnostic_enabled")) or overlay.visible or copy_button.visible:
        _fail("diagnostics are not OFF by default")
        return
    # v338 keeps the opt-in diagnostic controls hidden in ordinary play.
    if bool(game.call("_pointer_on_training_test_button", toggle.get_global_rect().get_center())):
        _fail("hidden diagnostic controls captured gameplay input")
        return
    toggle.show()  # Exercise the diagnostic tool independently of its visibility default.
    var player: Node3D = game.get("player")
    var player_before: Vector3 = player.position
    var touch: Vector2 = toggle.get_global_rect().get_center()
    if not bool(game.call("_pointer_on_training_test_button", touch)):
        _fail("diagnostic button outside reserved UI input area")
        return
    game.call("_press_training_test_button", touch)
    if not bool(game.get("diagnostic_enabled")) or not overlay.visible or not copy_button.visible:
        _fail("diagnostics failed to enable")
        return
    game.call("_sample_diagnostics", 0.20)
    var samples: Array = overlay.get("samples")
    if samples.is_empty():
        _fail("no captured sample while ON")
        return
    var count: int = samples.size()
    game.call("_press_training_test_button", touch)
    if bool(game.get("diagnostic_enabled")) or overlay.visible or copy_button.visible:
        _fail("diagnostics failed to disable")
        return
    game.call("_sample_diagnostics", 0.20)
    if (overlay.get("samples") as Array).size() != count:
        _fail("sampling continued while OFF")
        return
    if player.position.distance_to(player_before) > 0.000001:
        _fail("diagnostic toggle moved the player")
        return
    print("SERA_DIAGNOSTICS_RUNTIME_PASS")
    quit(0)
