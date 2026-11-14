extends SceneTree
## v344: stack visible hit numbers without changing old fade/projection.
const SPACING = preload("res://scripts/sera_damage_popup_spacing.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V344_DAMAGE_POPUP_FAIL: " + why)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("training scene not found")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var camera: Camera3D = game.get("camera")
    var latest: Label = game.get("damage_label")
    if camera == null or latest == null:
        _fail("HUD or camera unavailable")
        return
    var origin: Vector3 = Vector3(0.0, 2.0, 0.0)
    var empty: Array[Vector2] = []
    if SPACING.choose_offset(Vector2(400.0, 300.0), empty) != Vector2.ZERO:
        _fail("single popup moved unnecessarily")
        return
    var near: Array[Vector2] = [Vector2(400.0, 300.0)]
    var offset: Vector2 = SPACING.choose_offset(Vector2(400.0, 300.0), near)
    if offset == Vector2.ZERO or offset.length() > 72.0:
        _fail("overlapping popups not gently spaced")
        return
    if SPACING.choose_offset(Vector2(620.0, 550.0), near) != Vector2.ZERO:
        _fail("far-away popup was moved")
        return

    game.call("_show_target_damage_popup", 12, origin)
    game.call("_advance_hit_fx", 0.02)
    if latest.text != "12" or not latest.visible:
        _fail("first popup missing")
        return
    var original_pos: Vector2 = latest.position
    game.call("_show_target_damage_popup", 26, origin)
    if latest.text != "26":
        _fail("latest popup did not update")
        return
    var older: Array = game.get("damage_popup_history")
    var old_label: Label = older[0]["label"]
    if old_label.text != "12" or not old_label.visible:
        _fail("older number overwritten")
        return
    if old_label.position.distance_to(original_pos) > 0.001:
        _fail("older number jumped when duplicated")
        return
    game.call("_advance_hit_fx", 0.02)
    if latest.position.distance_to(old_label.position) < 20.0:
        _fail("overlapping numbers not spaced")
        return
    if latest.position.distance_to(old_label.position) > 85.0:
        _fail("spread is much too wide")
        return
    for i in range(3):
        game.call("_show_target_damage_popup", 30+i, origin)
    game.call("_advance_hit_fx", 0.02)
    var visible_count: int = 1
    for entry in game.get("damage_popup_history"):
        if (entry["label"] as Label).visible:
            visible_count += 1
    if visible_count < 5:
        _fail("rapid combo popups were lost")
        return
    game.call("_advance_hit_fx", 1.0)
    game.call("_advance_hit_fx", 0.0)
    if latest.visible:
        _fail("latest damage popup did not expire")
        return
    for entry in game.get("damage_popup_history"):
        if (entry["label"] as Label).visible:
            _fail("history popup did not expire")
            return
    print("GODOT_V344_DAMAGE_POPUP_PASS: gentle offsets, all hits, old fades")
    quit(0)
