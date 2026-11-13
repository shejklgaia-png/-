extends SceneTree
## Real Godot scene check: direct idle-to-RUN and continuous hits
## on broken modules and a shared boss HP already clamped to zero.
func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("SERA_V319_RUNTIME_FAILED: " + why)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main scene is missing")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var parts: Node3D = game.get("target_parts")
    var target: Node3D = game.get("target")
    var player: CharacterBody3D = game.get("player")
    if rig == null or parts == null or target == null or player == null:
        _fail("scene rig or target objects missing")
        return
    if not bool(rig.get("loading_ok")):
        _fail("authored animation rig failed to load")
        return

    # WAIT -> RUN must start the authored gait immediately; no Jump landing
    # pose may contribute. Actual jump/somersault landing remains separate.
    rig.call("set_moving", false)
    rig.call("set_moving", true, false, Vector2.UP, false)
    if str(rig.get("current_clip")) != "run_front_original" \
            or absf(float(rig.get("clip_time"))) > 0.00001:
        _fail("ordinary stand->RUN failed to choose the RUN clip")
        return
    rig.call("_process", 0.05)
    if float(rig.get("clip_time")) < 0.08:
        _fail("stand->RUN gait was held back by an extra landing phase")
        return
    var elapsed_after_first: float = float(rig.get("clip_time"))
    rig.call("_process", 0.06)
    if float(rig.get("clip_time")) <= elapsed_after_first:
        _fail("stand->RUN gait did not continue normally")
        return
    rig.call("set_moving", false)
    rig.call("set_moving", true, true, Vector2.UP, true)
    if str(rig.get("current_clip")) != "Boost_front":
        _fail("direct idle->RUN transition changed actual BOOST")
        return

    # The first strike should show full mitigated damage even when only
    # a few shared HP remain. Break HEAD in the very same hit.
    game.set("target_hp", 8)
    game.set("locked_target_part_id", "head")
    var first: Dictionary = game.call("_apply_target_part_damage",
        "melee", 26, 160.0, 0.0, 0.0)
    var damage: int = int(first["body_damage"])
    if damage <= 8 or int(first["applied_damage"]) != damage \
            or int(game.get("target_hp")) != 0 or not bool(first["broken"]):
        _fail("lethal strike damage was truncated or failed to break HEAD")
        return
    if not bool(parts.call("is_targetable", "head")) \
            or bool(parts.call("is_intact", "head")):
        _fail("broken HEAD cannot be selected for another hit")
        return

    # Its collision AABB and combat FX remain live even after both gauges
    # have reached zero. The active melee/Bash damage popup reads applied_damage.
    if not bool(game.call("_locked_part_hit_volume_available")):
        _fail("broken HEAD collision volume disappeared")
        return
    var box: AABB = parts.call("get_part_aabb", "head")
    var center: Vector3 = box.get_center()
    var blade_contact: Variant = game.call(
        "_blade_contact", center + Vector3.UP * 2.0,
        center - Vector3.UP * 2.0)
    if blade_contact == null:
        _fail("broken HEAD rejects physical sword contact")
        return
    var before_respawn: float = float(game.get("target_respawn_remaining"))
    var second: Dictionary = game.call("_apply_target_part_damage",
        "bash", 26, 90.0, 0.0, 0.0)
    if int(second["applied_damage"]) != damage \
            or int(game.get("target_hp")) != 0 \
            or float(parts.call("get_part_integrity", "head")) != 0.0 \
            or bool(second["broken"]):
        _fail("subsequent attack on KO/broken HEAD lost its damage")
        return
    if absf(float(game.get("target_respawn_remaining")) - before_respawn) > 0.00001:
        _fail("subsequent KO hit incorrectly rearmed respawn")
        return
    game.set("locked_target_part_id", "")
    var body: Dictionary = game.call("_apply_target_part_damage",
        "melee", 26, 0.0, 0.0, 0.0)
    if int(body["applied_damage"]) <= 0:
        _fail("BODY cannot take a contact hit after shared HP reaches zero")
        return
    print("SERA_V319_IDLE_RUN_PERSISTENT_HITS_RUNTIME_PASS")
    quit(0)
