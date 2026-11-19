extends SceneTree
## Walking footsteps: two independent clouds per diagonal touchdown, actual
## post-IK sole anchor, ground-aware grit, no airborne/attack duplicates.
const IDS: Array[String] = ["leg_fr", "leg_rl", "leg_fl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_FOOTSTEP_FX_FAIL " + message)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    var fx: Node3D = battle.get("bittaran_dirt_fx")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if fx == null or ik == null:
        _fail("battle/IK/FX not ready")
        return
    var legs: Array = ik.get("legs")
    if legs.size() != 4 or (fx.get("walk_cloud_slots") as Array).size() != 8:
        _fail("missing four feet or pooled walking clouds")
        return
    battle.set("target_hp", 500.0)
    battle.set("player_hp", 100.0)
    battle.set("bittaran_motion", "Approach")
    battle.set("bittaran_attack_frame", {})
    fx.call("reset")

    # A new swing starts in the AIR, with no visual particles.
    for i in [0, 1]:
        legs[i]["stepping"] = true
    battle.call("_tick_bittaran_footfalls")
    if int(fx.get("walk_burst_count")) != 0:
        _fail("dust emitted while legs were raised")
        return
    # Both feet of the diagonal touch down on the same frame.
    for i in [0, 1]:
        legs[i]["stepping"] = false
    battle.call("_tick_bittaran_footfalls")
    if int(fx.get("walk_burst_count")) != 2:
        _fail("diagonal landing did not emit both footsteps")
        return
    if (fx.get("grit_debris") as Array).size() != 10:
        _fail("five grounded grit pieces per foot are missing")
        return
    var last: Vector3 = fx.get("last_walk_fx_origin")
    var foot_bounds: AABB = battle.call(
        "_bittaran_attack_foot_bounds", IDS[1])
    if (not foot_bounds.has_volume()
            or last.y < 0.0 or last.y > 0.05
            or last.x < foot_bounds.position.x - 0.01
            or last.x > foot_bounds.end.x + 0.01
            or last.z < foot_bounds.position.z - 0.01
            or last.z > foot_bounds.end.z + 0.01):
        _fail("walking dust is not on the actual grounded toe")
        return
    var world_clouds: int = 0
    for slot in fx.get("walk_cloud_slots"):
        var core: CPUParticles3D = slot["core"]
        var fines: CPUParticles3D = slot["fines"]
        if (core.emitting and fines.emitting
                and not core.local_coords and not fines.local_coords):
            world_clouds += 1
    if world_clouds != 2:
        _fail("footfall cloud positions were reused or made boss-local")
        return
    battle.call("_tick_bittaran_footfalls")
    if int(fx.get("walk_burst_count")) != 2:
        _fail("planted feet repeatedly emitted walking dirt")
        return

    # Normal attack and idle transitions are NOT walking footsteps.
    legs[2]["stepping"] = true
    battle.call("_tick_bittaran_footfalls")
    battle.set("bittaran_attack_frame", {"kind": "kick", "phase": "entry"})
    legs[2]["stepping"] = false
    battle.call("_tick_bittaran_footfalls")
    if int(fx.get("walk_burst_count")) != 2:
        _fail("attack cancellation manufactured walking dust")
        return
    battle.set("bittaran_attack_frame", {})
    legs[3]["stepping"] = true
    battle.call("_tick_bittaran_footfalls")
    battle.set("bittaran_motion", "Idle")
    legs[3]["stepping"] = false
    battle.call("_tick_bittaran_footfalls")
    if int(fx.get("walk_burst_count")) != 2:
        _fail("idle/canceled transition manufactured walking dust")
        return

    # Each slot must retain its own WORLD position after the emitter
    # parent is moved; resetting must clean up all live one-shots.
    fx.call("reset")
    fx.position = Vector3(-4, 0, 7)
    var sole: Vector3 = Vector3(13, 0, -9)
    if not bool(fx.call("emit_footstep", sole, Vector2(0.2, 0.2))):
        _fail("direct footstep burst unavailable")
        return
    var found: bool = false
    for slot in fx.get("walk_cloud_slots"):
        var core: CPUParticles3D = slot["core"]
        if core.emitting:
            found = core.global_position.distance_to(
                sole + Vector3(0, 0.22, 0)) < 0.001
            break
    if not found:
        _fail("walking plume followed parent instead of world contact")
        return
    fx.call("reset")
    if (int(fx.get("walk_burst_count")) != 0
            or not (fx.get("grit_debris") as Array).is_empty()):
        _fail("reset leaked footstep effect")
        return

    print("GODOT_BITTARAN_FOOTSTEP_FX_PASS four_feet=true grounded_only=true world_space=true low_density=true")
    quit(0)
