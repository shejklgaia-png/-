extends SceneTree
## v510 live Godot check: enemy shield 100 SP / 25%-95% mitigation,
## delayed recovery, contact depth, state colors, fracture and both scenes.
const Shield = preload("res://scripts/enemy_predictive_shield.gd")
const FX = preload("res://scripts/enemy_shield_hit_fx.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V510_PREDICTIVE_SHIELD_FAILED: " + why)
    quit(1)

func _near(a: float, b: float, eps: float = 0.0001) -> bool:
    return absf(a - b) <= eps

func _run() -> void:
    var s: RefCounted = Shield.new()
    var first: Dictionary = s.call("apply_hit", 100.0, false)
    if not _near(float(first["damage_multiplier"]), 0.75) or (
            not _near(float(first["ratio_before"]), 1.0)) or (
            not _near(float(s.get("sp")), 76.0)):
        _fail("100 SP and 25% melee reduction / 24 SP consumed")
        return
    s.call("advance", 3.99)
    if not _near(float(s.get("sp")), 76.0):
        _fail("shield started recovering before 4 seconds")
        return
    s.call("advance", 0.51)
    if not _near(float(s.get("sp")), 86.0, 0.01):
        _fail("post-delay shield regeneration is not 20 SP/s")
        return
    s.call("reset")
    var ranged: Dictionary = s.call("apply_hit", 100.0, true)
    if not _near(float(ranged["damage_multiplier"]), 0.05) or (
            not _near(float(s.get("sp")), 93.0)):
        _fail("95% ranged mitigation / 7 SP ranged chip")
        return
    for case in [
        [1.0, Color("007aff")],
        [0.60, Color("007aff")],
        [0.59, Color("ffe100")],
        [0.30, Color("ffe100")],
        [0.29, Color("ff2140")],
    ]:
        if not FX.state_color(float(case[0])).is_equal_approx(case[1]):
            _fail("color threshold mismatched at " + str(case[0]))
            return
    # v512: full-saturation contact color, immediate strong hit and rapid
    # release (not a washed-out additive fog covering the boss).
    if FX.contact_opacity(0.0) < 0.85 or (
            FX.contact_opacity(0.06) < 0.99) or (
            FX.contact_opacity(0.40) > 0.75) or (
            FX.contact_opacity(0.80) > 0.01) or (
            FX.contact_core_flash(0.0) < 0.99) or (
            FX.contact_core_flash(0.30) > 0.01) or (
            FX.CRACK_EXTEND_SECONDS > 0.14) or (
            FX.CRACK_FADE_END_SECONDS > 0.34):
        _fail("v512 shield must have high-saturation punch and rapid cutoff")
        return
    # v511: explicit visibility contract measured at 720px reference viewport.
    # v511 reference radii remain unchanged; v524 scales the entire rendered
    # shield down to 30% of those values in the shared FX drawing path.
    if not _near(FX.VISUAL_SIZE_MULTIPLIER, 0.30) or (
            not _near(FX.contact_radius_px(0.0), 100.0)) or (
            not _near(FX.contact_radius_px(1.0), 260.0)) or (
            not _near(FX.FRACTURE_REACH_END_PX, 470.0)) or (
            not _near(FX.BURST_RADIUS_MAX_PX, 470.0)) or (
            FX.MIN_VISUAL_SCALE < 0.85) or (
            FX.SHIELD_SURFACE_OFFSET <= 0.06) or (
            FX.IMPACT_SECONDS < 0.42) or (
            FX.FRACTURE_SECONDS < 0.60):
        _fail("shield radius reference, visual scale, duration or depth layer changed")
        return
    for path in ["res://scenes/main.tscn", "res://scenes/bittaran_battle.tscn"]:
        var packed: PackedScene = load(path)
        if packed == null:
            _fail("scene missing " + path)
            return
        var game: Node3D = packed.instantiate()
        root.add_child(game)
        game.set_process(false)
        game.set_physics_process(false)
        var shield: RefCounted = game.get("enemy_predictive_shield")
        var fx: Node3D = game.get("shield_hit_fx")
        var sparks: Node3D = game.get("hit_burst")
        var camera: Camera3D = game.get("camera")
        if shield == null or fx == null or sparks == null or camera == null:
            _fail("shared enemy shield scene wiring absent " + path)
            return
        var mat: StandardMaterial3D = fx.get("material")
        if mat == null or mat.render_priority != 115 or mat.no_depth_test or (
                mat.blend_mode != BaseMaterial3D.BLEND_MODE_MIX):
            _fail("shield is not depth-tested behind the hit sparks")
            return
        var hp_before: int = int(game.get("target_hp"))
        game.set("locked_target_part_id", "")
        var result: Dictionary = game.call("_apply_target_part_damage", "melee", 40, 0.0, 0.0, 0.0)
        if int(result["applied_damage"]) <= 0 or (
                int(game.get("target_hp")) >= hp_before) or (
                float(shield.get("sp")) >= Shield.MAX_SP):
            _fail("real target HP/shield not modified " + path)
            return
        var impact: Vector3 = game.get("target").global_position
        game.call("_spawn_shield_impact", impact)
        var effects: Array = fx.get("impacts")
        if effects.is_empty() or bool(effects[-1]["broken"]):
            _fail("ordinary shield flash not spawned " + path)
            return
        shield.set("sp", 1.0)
        game.call("_apply_target_part_damage", "melee", 40, 0.0, 0.0, 0.0)
        game.call("_spawn_shield_impact", impact)
        effects = fx.get("impacts")
        if not bool(effects[-1]["broken"]) or float(shield.get("sp")) != 0.0:
            _fail("break must spawn blue-white fracture " + path)
            return
        var audio: AudioStreamPlayer = fx.get("break_audio")
        if audio == null or audio.stream == null:
            _fail("shatter sound missing " + path)
            return
        game.call("_advance_hit_fx", 0.1)
        game.call("_reset_target_after_respawn")
        if not _near(float(shield.get("sp")), Shield.MAX_SP):
            _fail("respawn shield did not reset " + path)
            return
        game.queue_free()
    print("GODOT_V510_PREDICTIVE_SHIELD_PASS")
    quit(0)
