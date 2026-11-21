extends SceneTree
## Live-scene regression of real combo hit registration, stats and boss defenses.
## Current implemented values only; no draft 10-minute balance values.
const STATS = preload("res://scripts/sera_part_stats.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_COMBO_DAMAGE_RUNTIME_FAIL: " + why)
    quit(1)

func _near(a: float, b: float, tolerance: float = 0.001) -> bool:
    return absf(a - b) <= tolerance

func _all_b() -> Dictionary:
    return {"head": "B", "torso": "B", "arms": "B", "legs": "B",
        "booster": "B", "weapon_r": "B", "weapon_l": "B"}

func _case(game: Node3D, name: String, selected: Dictionary,
        part: String, expected_damage: Array, expected_break: float,
        expected_sp: float, kick: bool = false) -> bool:
    game.call("_reset_target_after_respawn")
    var parts: Node3D = game.get("target_parts")
    var shield: RefCounted = game.get("enemy_predictive_shield")
    var rig: Node3D = game.get("rig")
    if parts == null or shield == null or rig == null:
        _fail("scene missing parts/shield/rig: " + name)
        return false
    parts.call("set_down_lock_enabled", part == "head" or part == "")
    game.set("locked_target_part_id", part)
    game.set("part_stats", STATS.build(selected))
    var hp_before: int = int(game.get("target_hp"))
    var integrity_before: float = 0.0 if part.is_empty() else float(
        parts.call("get_part_integrity", part))
    var actual_damage: Array[int] = []
    for stage in range(expected_damage.size()):
        game.set("strike_index", stage)
        game.set("strike_did_hit", false)
        game.set("hit_stop_remaining", 0.0)
        rig.call("set_combat_paused", false)
        if kick:
            game.call("_register_side_kick_hit")
        else:
            game.call("_register_strike_hit", Vector3.ZERO)
        var hp_after: int = int(game.get("target_hp"))
        actual_damage.append(hp_before - hp_after)
        hp_before = hp_after
    if actual_damage != expected_damage:
        _fail(name + " damage expected=" + str(expected_damage)
            + " actual=" + str(actual_damage))
        return false
    if not part.is_empty():
        var actual_break: float = integrity_before - float(
            parts.call("get_part_integrity", part))
        if not _near(actual_break, expected_break):
            _fail(name + " break expected=" + str(expected_break)
                + " actual=" + str(actual_break))
            return false
    var actual_sp: float = float(shield.get("sp"))
    if not _near(actual_sp, expected_sp):
        _fail(name + " SP expected=" + str(expected_sp)
            + " actual=" + str(actual_sp))
        return false
    print("SERA_COMBO_DAMAGE_CASE_PASS " + name + " damage="
        + str(actual_damage) + " SP=" + str(actual_sp))
    return true

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("Bittaran scene not loadable")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    var rig: Node3D = game.get("rig")
    if rig == null or not bool(rig.get("loading_ok")):
        _fail("actual SERA rig not loaded")
        return
    if not _near(float(STATS.build({}).get("weight_pct")), 100.0) or (
            not _near(float(STATS.build(_all_b()).get("weight_pct")), 156.9)) or (
            not _near(float(STATS.build(_all_b()).get("attack_mult")), 1.4)):
        _fail("equipment weight and attack multiplier")
        return
    if not _case(game, "A front", {}, "leg_fl", [8, 8, 18], 60.0, 68.0):
        return
    if not _case(game, "A rear", {}, "leg_rl", [8, 8, 18], 52.8, 68.0):
        return
    if not _case(game, "A head", {}, "head", [7, 7, 17], 54.0, 68.0):
        return
    if not _case(game, "A body", {}, "", [8, 8, 18], 0.0, 68.0):
        return
    if not _case(game, "B front", _all_b(), "leg_fl", [16, 17, 35], 90.0, 60.32):
        return
    if not _case(game, "B rear", _all_b(), "leg_rl", [15, 16, 34], 79.2, 60.32):
        return
    if not _case(game, "B head", _all_b(), "head", [14, 15, 32], 81.0, 60.32):
        return
    if not _case(game, "B body", _all_b(), "", [15, 16, 34], 0.0, 60.32):
        return
    if not _case(game, "A side kick x2", {}, "leg_fl", [8, 8], 28.0, 80.16, true):
        return
    if not bool(rig.call("set_equipment_selection", "weapon_r", "K")):
        _fail("Katana K not selectable")
        return
    if int(game.call("_strike_stage_count")) != 2:
        _fail("Katana 2-stage combo is not active")
        return
    if not _case(game, "A plus K katana", {"weapon_r": "K"},
            "leg_fl", [8, 8], 28.0, 80.16):
        return
    print("SERA_COMBO_DAMAGE_GODOT_PASS: 10 live Bittaran combo cases")
    quit(0)
