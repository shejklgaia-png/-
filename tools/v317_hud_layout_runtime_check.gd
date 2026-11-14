extends SceneTree
## Stage16: exact hierarchy and interactive exclusions in a live Godot scene.
const LAYOUT = preload("res://scripts/sera_hud_layout.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_HUD_LAYOUT_RUNTIME_FAIL: " + reason)
    quit(1)

func _near(a: float, b: float) -> bool:
    return absf(a - b) < 0.00001

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var hud: CanvasLayer = game.get_node_or_null("HUD") as CanvasLayer
    var panel: Panel = game.get("hud_panel")
    var drag: Control = game.get("touch_ui")
    var handed: Button = game.get("handedness_button")
    var nexus: Button = game.get("nexus_button")
    var state: Label = game.get("state_label")
    var hp: Label = game.get("hp_label")
    var fill: ColorRect = game.get("hp_fill")
    var vitals: Control = game.get("vitals_hud")
    var step: Label = game.get("step_status_label")
    var detail: Label = game.get("step_detail_label")
    var resources: Label = game.get("resources_label")
    var lock_left: Button = game.get("lock_switch_left_button")
    var lock_right: Button = game.get("lock_switch_right_button")
    if hud == null or panel == null or drag == null \
            or nexus == null or state == null or hp == null or fill == null \
            or vitals == null or step == null or detail == null \
            or resources == null or lock_left == null or lock_right == null:
        _fail("one of the original HUD nodes is missing")
        return
    if panel != hud.get_node_or_null("CompactCombatHUD") \
            or state != panel.get_node_or_null("ActionState") \
            or hp != panel.get_node_or_null("TargetHpLabel") \
            or fill != panel.get_node_or_null("TargetHpFill") \
            or vitals != panel.get_node_or_null("CombatVitals") \
            or step != panel.get_node_or_null("StepStatusLabel") \
            or detail != panel.get_node_or_null("StepModeDetails"):
        _fail("HUD hierarchy or node reference changed")
        return
    if panel.mouse_filter != Control.MOUSE_FILTER_IGNORE \
            or vitals.mouse_filter != Control.MOUSE_FILTER_IGNORE \
            or step.mouse_filter != Control.MOUSE_FILTER_IGNORE \
            or detail.mouse_filter != Control.MOUSE_FILTER_IGNORE \
            or nexus.mouse_filter != Control.MOUSE_FILTER_IGNORE \
            or lock_left.mouse_filter != Control.MOUSE_FILTER_IGNORE \
            or lock_right.mouse_filter != Control.MOUSE_FILTER_IGNORE:
        _fail("read-only/controller or interactive button mouse filtering changed")
        return
    if handed != null or not nexus.pressed.is_connected(Callable(game, "_request_return_to_nexus")):
        _fail("in-game settings and Nexus callbacks no longer owned by main")
        return

    # Verify the original draw order, including both clickable buttons
    # BETWEEN title and state, and read-only resources BEFORE STEP telemetry.
    if panel.visible or not (game.get("clean_training_hud") as Control).visible \
            or nexus.get_parent() != hud:
        _fail("v338 active HUD or standalone navigation changed")
        return
    panel.show()  # Validate legacy formatters only while explicitly visible.
    game.call("_refresh_step_status_ui")
    var children: Array[Node] = panel.get_children()
    var names: Array[String] = []
    for child in children:
        names.append(child.name)
    var correct: Array[String] = [
        "Accent", "CombatTitle",
        "ActionState", "TargetHpLabel", "TargetHpBackground", "TargetHpFill",
        "CombatVitals",
    ]
    for i in range(correct.size()):
        if names.size() <= i or names[i] != correct[i]:
            _fail("primary HUD creation order changed at " + str(i) + ": " + str(names))
            return
    if not (resources.get_index() < step.get_index()
            and step.get_index() < detail.get_index()
            and detail.get_index() < panel.get_node("InputHint").get_index()):
        _fail("STEP telemetry / resources child draw order changed")
        return
    if panel.get_node("InputHint").text != "" \
            or state.text != "WAIT  |  Wait_motion":
        _fail("read-only hint/idle status unexpectedly changed")
        return

    if not _near(panel.offset_left, 18.0) \
            or not _near(panel.offset_right, -18.0) \
            or not _near(panel.offset_top, 26.0) \
            or not _near(panel.offset_bottom, 150.0) \
            or panel.get_node("CombatTitle").position != Vector2(27.0, 10.0) \
            or vitals.position != Vector2(27.0, 62.0) \
            or vitals.size != Vector2(190.0, 61.0) \
            or hp.position != Vector2(414.0, 80.0) \
            or not _near(step.offset_left, -224.0) \
            or not _near(detail.offset_left, -250.0):
        _fail("combat HUD pixel geometry changed")
        return
    var bg: ColorRect = panel.get_node("TargetHpBackground")
    var constants: Dictionary = game.get_script().get_script_constant_map()
    if bg.position != Vector2(414.0, 105.0) \
            or bg.size != Vector2(float(constants["TARGET_HP_BAR_WIDTH"]), 7.0) \
            or fill.position != bg.position \
            or hp.text.is_empty():
        _fail("boss HP bar geometry or startup label changed")
        return
    if vitals.get("hp") == null or vitals.get("en") == null \
            or detail.text.is_empty() or step.text.is_empty():
        _fail("meter initialization or STEP telemetry refresh was skipped")
        return

    # Full-screen gestures remain unaffected by read-only surfaces; only
    # intended controls are interactive, and raw lock buttons retain their
    # manual-screen switching entry points.
    if game.call("_pointer_on_step_hud", Vector2(1.0, 1.0)) \
            or not game.call("_pointer_on_nexus_button",
                nexus.get_global_rect().get_center()):
        _fail("HUD touch exclusion changed")
        return
    print("SERA_HUD_LAYOUT_RUNTIME_PASS: hierarchy, pixel geometry, callbacks, touch")
    quit(0)
