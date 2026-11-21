extends SceneTree
## Real-scene numerical acceptance for the creator-approved Bittaran ~10 minute A build.
## Uses actual SERA damage, shield, part-break, lock and player-vitals paths.
const Balance = preload("res://scripts/bittaran_balance.gd")
const Stats = preload("res://scripts/sera_part_stats.gd")
const TARGET_SECONDS: float = 600.0
const A_STRIKES: Array[int] = [12, 12, 26]
const A_BREAK: Array[float] = [14.0, 14.0, 32.0]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_10MIN_BALANCE_FAIL: " + message)
    quit(1)

func _near(actual: float, expected: float, eps: float = 0.01) -> bool:
    return absf(actual - expected) <= eps

func _combo(game: Node3D, part: String) -> int:
    game.set("locked_target_part_id", part)
    var hp_before: int = int(game.get("target_hp"))
    for stage in range(3):
        var result: Dictionary = game.call("_apply_target_part_damage",
            "melee", A_STRIKES[stage], A_BREAK[stage], 0.0, 0.0)
        if int(result["applied_damage"]) <= 0:
            return -1
    return hp_before - int(game.get("target_hp"))

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("authored Bittaran battle scene not loaded")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    var rig: Node3D = game.get("rig")
    var parts: Node3D = game.get("target_parts")
    var shield: RefCounted = game.get("enemy_predictive_shield")
    if rig == null or parts == null or shield == null or (
            not bool(rig.get("loading_ok"))):
        _fail("SERA rig/part adapter/shield missing")
        return
    if not _near(float(Stats.build({})["max_hp"]), 320.0) or (
            not _near(float(Stats.build({
                "head": "B", "torso": "B", "arms": "B", "legs": "B",
                "booster": "B", "weapon_r": "B", "weapon_l": "B"
            })["max_hp"]), 416.0)):
        _fail("A/B full-build max HP must be 320/416")
        return
    if not _near(float(game.get("player_hp")), 320.0):
        _fail("live A player HP is not 320")
        return
    if int(game.get("target_hp")) != 2550 or (
            int(game.call("_target_health_cap")) != 2550) or (
            not _near(float(parts.call("get_part_max_integrity", "body")),
            2550.0)):
        _fail("battle target HP, HUD cap, body lock integrity disagree")
        return
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr", "head"]:
        var expected: float = (
            150.0 if id == "head" else 720.0
            if id.begins_with("leg_f") else 620.0)
        if not _near(float(parts.call("get_part_max_integrity", id)),
                expected) or not _near(
                float(parts.call("get_part_integrity", id)), expected):
            _fail("part max/current durability mismatch: " + id)
            return
    if not _near(float(Balance.incoming_damage_multiplier("stomp")),
            30.0 / 28.0) or (
            not _near(float(Balance.incoming_damage_multiplier("sweep")),
            28.0 / 34.0)) or (
            not _near(float(Balance.incoming_damage_multiplier("kick")), 1.0)):
        _fail("boss physical attack scaling")
        return
    if not _near(float(Balance.RAILGUN_DAMAGE_MULTIPLIER), 0.45) or (
            not _near(float(Balance.BELLY_DAMAGE_MULTIPLIER), 0.28)):
        _fail("boss turret scaling")
        return
    # Live guard/HP path: 30 stomp, 22 kick, 28 sweep, 8.1 rail,
    # 5.04 belly, with A defense 16%; leave training attacks unaffected.
    var strike_cases: Array = [
        [2, Balance.incoming_damage_multiplier("stomp"), 25.2],
        [1, Balance.incoming_damage_multiplier("kick"), 18.48],
        [3, Balance.incoming_damage_multiplier("sweep"), 23.52],
        [0, Balance.RAILGUN_DAMAGE_MULTIPLIER, 6.804],
        [0, Balance.BELLY_DAMAGE_MULTIPLIER, 4.2336],
    ]
    for item in strike_cases:
        var before_hp: float = float(game.get("player_hp"))
        game.call("_on_enemy_projectile_hit", Vector3.ZERO, Vector3.FORWARD,
            true, int(item[0]), true, float(item[1]))
        var actual: float = before_hp - float(game.get("player_hp"))
        if not _near(actual, float(item[2]), 0.01):
            _fail("boss incoming attack damage mismatch: " + str(item)
                + " got " + str(actual))
            return
    # Reset the complete enemy and carry out the approved eight-second
    # successful-combo model through the REAL damage and part-break pipeline.
    game.call("_reset_target_after_respawn")
    var total_seconds: float = 0.0
    var parts_to_break: Array[String] = [
        "leg_fl", "leg_fr", "leg_rl", "leg_rr"]
    var head_total: int = 0
    for leg_idx in range(4):
        var id: String = parts_to_break[leg_idx]
        for combo_idx in range(12):
            var delta_hp: int = _combo(game, id)
            if delta_hp != 26:
                _fail("A leg combo expected 26 HP at full SP, " + id
                    + ": " + str(delta_hp))
                return
            total_seconds += 8.0
            if combo_idx < 11:
                shield.call("advance", 8.0)
            if combo_idx == 10 and not bool(parts.call("is_intact", id)):
                _fail("leg broke before the twelfth full A combo: " + id)
                return
        if bool(parts.call("is_intact", id)) or (
                not _near(float(parts.call("get_part_integrity", id)), 0.0)):
            _fail("leg did not break after twelve full A combos: " + id)
            return
        var heads: int = 2 if leg_idx == 3 else 1
        for n in range(heads):
            parts.call("set_down_lock_enabled", true)
            var head_hp: int = _combo(game, "head")
            if head_hp <= 0:
                _fail("head failed to take damage on knockdown")
                return
            head_total += 1
            total_seconds += 2.0 if leg_idx == 3 else 1.9
        shield.call("advance", 8.0)
        parts.call("set_down_lock_enabled", false)
    if head_total != 5 or int(parts.call("broken_leg_count")) != 4:
        _fail("five weakpoint combos/four unique break events were not reached")
        return
    if bool(parts.call("is_intact", "head")):
        _fail("three or more successful head combos must break head")
        return
    # All legs destroyed -> BODY is permanently lockable without new gauge.
    if not bool(parts.call("can_lock_boss_part", "body")) or (
            not bool(parts.call("is_targetable", "body"))):
        _fail("BODY not exposed permanently after four leg breaks")
        return
    var body_combos: int = 0
    while int(game.get("target_hp")) > 0 and body_combos < 50:
        var body_damage: int = _combo(game, "body")
        if body_damage <= 0:
            _fail("BODY cannot receive damage after four-leg break")
            return
        total_seconds += 8.0
        body_combos += 1
        shield.call("advance", 8.0)
    if body_combos != 26 or not _near(total_seconds, 601.7, 0.01) or (
            int(game.get("target_hp")) != 0):
        _fail("ten-minute A route: body combos=" + str(body_combos)
            + ", duration=" + str(total_seconds)
            + ", hp=" + str(game.get("target_hp")))
        return
    # One-time break: hitting a destroyed leg never creates another event.
    game.call("_reset_target_after_respawn")
    parts.call("set_down_lock_enabled", true)
    for _combo_idx in range(12):
        shield.call("reset")
        _combo(game, "leg_fl")
    shield.call("reset")
    var additional: Dictionary = game.call("_apply_target_part_damage",
        "melee", 26, 32.0, 0.0, 0.0)
    if bool(additional.get("broken", false)) or (
            not _near(float(parts.call("get_part_integrity", "leg_fl")), 0.0)):
        _fail("broken leg generated another break event")
        return
    game.call("_reset_target_after_respawn")
    if int(game.get("target_hp")) != 2550 or (
            not _near(float(parts.call("get_part_max_integrity", "leg_fl")),
            720.0)) or (
            not _near(float(parts.call("get_part_integrity", "leg_fl")),
            720.0)):
        _fail("boss respawn did not reset HP and limb durability")
        return
    print("BITTARAN_10MIN_BALANCE_GODOT_PASS: A route 601.7s / "
        + str(body_combos) + " body combos / 4 unique legs / 5 head combos")
    game.queue_free()
    quit(0)
