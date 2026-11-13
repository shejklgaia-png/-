extends SceneTree
## Real Godot v317 hit presentation, part isolation, damage HUD and respawn.
const DISPLAY = preload("res://scripts/sera_hit_fx_presentation.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_HIT_FX_PRESENTATION_RUNTIME_FAIL: " + message)
    quit(1)

func _near(a: float, b: float) -> bool:
    return absf(a - b) <= 0.00003

func _color_near(a: Color, b: Color) -> bool:
    return _near(a.r, b.r) and _near(a.g, b.g) \
        and _near(a.b, b.b) and _near(a.a, b.a)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var constants: Dictionary = game.get_script().get_script_constant_map()
    var mat: StandardMaterial3D = game.get("target_material")
    var mesh: MeshInstance3D = game.get("target_mesh")
    var overlay: ColorRect = game.get("projectile_hit_overlay")
    var camera: Camera3D = game.get("camera")
    var damage: Label = game.get("damage_label")
    var incoming: Label = game.get("incoming_damage_label")
    var parts: Node3D = game.get("target_parts")
    if mat == null or mesh == null or overlay == null or camera == null \
            or damage == null or incoming == null or parts == null:
        _fail("missing live FX/scene nodes")
        return

    var projectile_length: float = float(constants["PROJECTILE_HIT_FLASH_SECONDS"])
    var body_length: float = float(constants["HIT_FLASH_SECONDS"])

    # Projectile overlay color/visibility track remaining lifetime.
    game.set("projectile_hit_flash_remaining", projectile_length)
    game.call("_advance_projectile_hit_overlay", projectile_length * 0.25)
    if not overlay.visible or not _near(float(game.get("projectile_hit_flash_remaining")), projectile_length * 0.75) \
            or not _near(overlay.color.a, 0.13 * 0.75):
        _fail("projectile overlay tint or timer changed")
        return
    game.call("_advance_projectile_hit_overlay", projectile_length)
    if overlay.visible or not _near(overlay.color.a, 0.0):
        _fail("expired projectile overlay stayed visible")
        return

    # BODY flash is material-only; parent mesh must never wobble.
    game.set("hit_flash_remaining", body_length)
    game.call("_advance_hit_fx", body_length * 0.5)
    var expected: Color = Color("e53935").lerp(Color("632535"), 0.5 * 0.78)
    if not _color_near(mat.albedo_color, expected) \
            or not _near(mat.emission_energy_multiplier, lerpf(0.08, 0.03, 0.5)) \
            or mesh.position != Vector3.ZERO or not _near(mesh.rotation_degrees.z, 0.0):
        _fail("BODY-only flash or parent stability changed")
        return
    game.call("_advance_hit_fx", body_length)
    if not _color_near(mat.albedo_color, Color("e53935")):
        _fail("expired BODY flash did not restore normal color")
        return

    # Outgoing popup keeps its original camera projection and fade.
    damage.visible = true
    game.set("impact_origin", Vector3.ZERO)
    game.set("damage_popup_remaining", 0.58)
    game.call("_advance_hit_fx", 0.10)
    var remaining: float = float(game.get("damage_popup_remaining"))
    var projected: Vector2 = camera.unproject_position(Vector3.UP * 0.28)
    var expected_pos: Vector2 = projected - Vector2(26.0, 30.0 + (0.58 - remaining) * 75.0)
    if not _near(remaining, 0.48) or damage.position.distance_to(expected_pos) > 0.001 \
            or not _near(damage.modulate.a, minf(1.0, remaining / 0.17)):
        _fail("outgoing damage projection or fade changed")
        return
    game.call("_advance_hit_fx", 1.0)
    game.call("_advance_hit_fx", 0.0)
    if damage.visible:
        _fail("finished outgoing damage label stayed visible")
        return

    # Incoming label fades and becomes hidden on the zero-time frame.
    incoming.visible = true
    game.set("incoming_damage_remaining", 0.15)
    game.call("_advance_hit_fx", 0.06)
    if not _near(float(game.get("incoming_damage_remaining")), 0.09) \
            or not _near(incoming.modulate.a, 0.5):
        _fail("incoming damage alpha changed")
        return
    game.call("_advance_hit_fx", 0.15)
    if incoming.visible:
        _fail("expired incoming damage label remained visible")
        return

    # Final boss reset is deferred while a locked combo is still active.
    var combat_state: Dictionary = constants.get("CombatState", {})
    game.set("target_hp", 0)
    game.set("target_respawn_remaining", 0.01)
    game.set("combat_state", int(combat_state["STRIKE"]))
    game.call("_advance_hit_fx", 0.02)
    if not _near(float(game.get("target_respawn_remaining")), 0.01) \
            or int(game.get("target_hp")) != 0:
        _fail("boss respawn interrupted held combo")
        return
    game.set("combat_state", int(combat_state["IDLE"]))
    game.set("bash_followup_window_remaining", 0.0)
    game.set("bash_loop_window_remaining", 0.0)
    game.set("side_kick_active", false)
    game.set("back_somersault_active", false)
    game.set("landing_active", false)
    game.call("_advance_hit_fx", 0.02)
    if int(game.get("target_hp")) != int(constants["TARGET_MAX_HP"]) \
            or not _near(float(game.get("target_respawn_remaining")), 0.0):
        _fail("boss respawn did not resume after combo ended")
        return

    print("SERA_HIT_FX_PRESENTATION_RUNTIME_PASS: projectile, BODY, HUD, boss respawn")
    quit(0)
