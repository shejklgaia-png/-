extends SceneTree
## Bittaran v355 regression: IK interpolation, far-side input, break visuals,
## 2.42/5.88-second downs (1.25x rise), broken HP and respawn.
const DT: float = 1.0 / 60.0
const LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V355_BITTARAN_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("missing scene")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var parts: Node3D = battle.get("target_parts")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var player: CharacterBody3D = battle.get("player")
    var view: Camera3D = battle.get("camera")
    var fragments: CPUParticles3D = battle.get("boss_death_particles")
    if parts == null or ik == null or rig == null or player == null or view == null or fragments == null:
        _fail("boss setup incomplete")
        return
    if rig.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_ON:
        _fail("physics interpolation off on boss rig")
        return
    for item in rig.get("bones").values():
        if (item as Node3D).physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_ON:
            _fail("IK joint interpolation off")
            return

    # Only combo-flick axis switches when the player passes the locked target.
    var view_forward: Vector3 = -view.global_transform.basis.z
    view_forward.y = 0.0
    view_forward = view_forward.normalized()
    battle.set("locked_target_part_id", "leg_fl")
    var point: Vector3 = parts.call("get_part_aim_world", "leg_fl")
    player.global_position = Vector3(point.x, player.global_position.y, point.z) + view_forward * 2.0
    var axis: Vector2 = battle.call("_touch_to_lock_forward", Vector2(80.0, 1050.0))
    var capsule_center: Vector3 = player.global_position + Vector3.UP * 0.925
    # v360: an elevated lock can project into the wrong screen hemisphere
    # behind the boss. Use the depth-safe SERA-center world-bearing oracle.
    var expected_axis: Vector2 = preload(
        "res://scripts/bittaran_controller_axis.gd").heading(
        view, capsule_center, point, Vector2.UP)
    if not bool(battle.get("boss_far_side_screen_axis")) or axis.distance_to(expected_axis) > 0.001:
        _fail("far-side combo front does not follow player center -> locked part")
        return
    player.global_position -= view_forward * 4.0
    battle.call("_touch_to_lock_forward", Vector2(80.0, 1050.0))
    if bool(battle.get("boss_far_side_screen_axis")):
        _fail("far-side hysteresis never exits")
        return

    battle.set("locked_target_part_id", "leg_fl")
    var initial: Dictionary = battle.call("_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(initial.get("broken", false)) or absf(float(ik.get("break_duration")) - 2.42) > 0.001:
        _fail("single-leg 2.42s fall missing (1.25x rise)")
        return
    parts.call("advance_part_hit_fx", 0.25)
    var record: Dictionary = parts.get("fx_meshes")["leg_fl"][0]
    if (record["material"] as StandardMaterial3D).albedo_color.is_equal_approx(record["albedo"]):
        _fail("broken shin does not retain damaged material")
        return

    for id in ["leg_fr", "leg_rl", "leg_rr"]:
        battle.set("locked_target_part_id", id)
        var result: Dictionary = battle.call("_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(result.get("broken", false)):
            _fail("leg failed to break: " + id)
            return
    if int(parts.call("broken_leg_count")) != 4 or absf(float(ik.get("break_duration")) - 5.88) > 0.001:
        _fail("four-leg 5.88s down missing (1.25x rise)")
        return
    for frame in range(350):
        rig.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
    if not bool(ik.call("break_reaction_active")):
        _fail("5.88s fall ended too early")
        return
    for frame in range(60):
        rig.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
    if bool(ik.call("break_reaction_active")):
        _fail("5.88s fall never recovers")
        return

    # Repeat damage to core with the four independent leg gauges still at 0.
    battle.set("locked_target_part_id", "body")
    parts.call("set_down_lock_enabled", true)
    battle.call("_apply_target_part_damage", "melee", 9000, 0.0, 0.0, 0.0)
    if int(battle.get("target_hp")) != 0 or not fragments.emitting:
        _fail("boss KO and metal fragments did not trigger")
        return
    if absf(float(battle.get("target_respawn_remaining")) - 3.0) > 0.001:
        _fail("boss respawn delay not 3.0s")
        return
    battle.call("_tick_target_respawn", 2.9)
    if int(battle.get("target_hp")) != 0:
        _fail("boss HP was restored early")
        return
    for id in LEGS:
        if float(parts.call("get_part_integrity", id)) > 0.0:
            _fail("part HP was restored before boss: " + id)
            return
    battle.call("_tick_target_respawn", 0.2)
    if int(battle.get("target_hp")) != 500 or int(parts.call("broken_leg_count")) != 0:
        _fail("body and limb HP did not recover together")
        return
    for id in LEGS:
        var actual: float = parts.call("get_part_integrity", id)
        var expected: float = parts.call("get_part_max_integrity", id)
        if absf(actual - expected) > 0.001:
            _fail("limb still injured: " + id)
            return
    if float(battle.get("boss_death_elapsed")) >= 0.0 or fragments.emitting:
        _fail("death effect did not reset after revival")
        return
    print("GODOT_V355_BITTARAN_PASS: interpolated IK, player-centered far-side flick, 2.42/5.88s fall, death and full revival")
    quit(0)
