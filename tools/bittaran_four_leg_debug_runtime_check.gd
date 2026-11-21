extends SceneTree
## Bittaran: four independent, tap-safe debug leg-break controls.
## One-press fracture must trigger the same authored IK down as real combat;
## it must NEVER damage common boss HP or SP / fake a normal sword strike.

const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const EXPECTED_LABELS: Array[String] = [
    "前左 / BREAK", "前右 / BREAK", "後左 / BREAK", "後右 / BREAK"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("BITTARAN_FOUR_LEG_DEBUG_FAIL: " + reason)
    quit(1)

func _tap(scene: Node3D, position: Vector2) -> void:
    var press := InputEventScreenTouch.new()
    press.index = 7
    press.position = position
    press.pressed = true
    scene.call("_input", press)
    var release := InputEventScreenTouch.new()
    release.index = 7
    release.position = position
    release.pressed = false
    scene.call("_input", release)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("boss battle scene missing")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var legs: Node3D = battle.get("target_parts") as Node3D
    var ik: RefCounted = battle.get("bittaran_foot_ik") as RefCounted
    var panel: Panel = battle.get("debug_leg_panel") as Panel
    var buttons: Dictionary = battle.get("debug_leg_buttons")
    if legs == null or ik == null or panel == null or (
            not panel.visible or buttons.size() != 4):
        _fail("one visible debug panel with exactly four buttons required")
        return
    if panel.position.y < 260 or panel.position.y > 700 or (
            panel.size.x > 360 or panel.size.y > 220):
        _fail("portrait overlay too large or outside expected HUD-safe space")
        return
    for i in range(4):
        var id: String = IDS[i]
        var button: Button = buttons.get(id) as Button
        if button == null or button.text != EXPECTED_LABELS[i] or (
                not button.visible or button.disabled or button.size.y < 40.0):
            _fail("leg mapping/accessible touch target invalid: " + id)
            return
        var expected_top: float = 366.0 + float(floori(float(i) / 2.0)) * 50.0
        var expected_left: float = 24.0 + float(i % 2) * 160.0
        if not is_equal_approx(button.get_global_rect().position.x,
                expected_left) or not is_equal_approx(
                button.get_global_rect().position.y, expected_top):
            _fail("front/rear and left/right buttons must occupy a real 2x2 grid")
            return
        for j in range(i):
            var other: Button = buttons.get(IDS[j]) as Button
            if button.get_global_rect().intersects(other.get_global_rect()):
                _fail("four leg buttons must not overlap")
                return
    var original_hp: int = int(battle.get("target_hp"))
    var original_guard: float = float(battle.get("shield"))
    var original_sp: float = float((battle.get("enemy_predictive_shield") as RefCounted).get("sp"))
    for i in range(4):
        var id: String = IDS[i]
        var button: Button = buttons[id] as Button
        _tap(battle, button.get_global_rect().get_center())
        if legs.call("is_intact", id) or (
                int(legs.call("broken_leg_count")) != i + 1):
            _fail("touch failed to fracture the selected leg exactly once: " + id)
            return
        if not bool(ik.call("break_reaction_active")):
            _fail("debug break did not start the actual authored fall: " + id)
            return
        if not button.disabled or (
                int(battle.get("target_hp")) != original_hp) or (
                not is_equal_approx(float(battle.get("shield")), original_guard)):
            _fail("debug fracture altered boss HP/player guard or button state: " + id)
            return
        if not is_equal_approx(float(
                (battle.get("enemy_predictive_shield") as RefCounted).get("sp")), original_sp):
            _fail("debug fracture altered predictive shield SP")
            return
        # Tapping the already-broken leg must be consumed, never cause a
        # player attack / duplicated break / another fall.
        _tap(battle, button.get_global_rect().get_center())
        if int(legs.call("broken_leg_count")) != i + 1 or (
                bool(battle.get("gesture_active"))):
            _fail("repeat tap was not safe and idempotent: " + id)
            return
    legs.call("set_down_lock_enabled", false)
    if not bool(legs.call("can_lock_boss_part", "body")):
        _fail("all four debug breaks did not unlock standing BODY")
        return
    battle.call("_reset_target_after_respawn")
    if int(legs.call("broken_leg_count")) != 0 or (
            int(battle.get("target_hp")) != original_hp):
        _fail("respawn did not restore normal part state and boss HP")
        return
    for id in IDS:
        if (buttons[id] as Button).disabled or not bool(legs.call("is_intact", id)):
            _fail("button did not reset after boss revival: " + id)
            return
    # Normal combat must still trigger identical down and update the panel.
    battle.set("locked_target_part_id", "leg_fr")
    var result: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 12, 800.0, 0.0, 0.0)
    if not bool(result.get("broken", false)) or (
            not (buttons["leg_fr"] as Button).disabled) or (
            not bool(ik.call("break_reaction_active"))):
        _fail("ordinary sword break bypassed the shared down/UI path")
        return
    print("BITTARAN_FOUR_LEG_DEBUG_GODOT_PASS: four taps, fall, "
        + "once-only, no HP/SP loss, reset, ordinary sword break")
    battle.queue_free()
    quit(0)
