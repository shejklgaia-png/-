extends SceneTree
## One body-wide collapse pulse (not a toe stomp) and C2 stand-up easing.
const IK_SCRIPT = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("BITTARAN_BODY_FALL_FAIL " + reason)
    quit(1)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var fx: Node3D = battle.get("bittaran_dirt_fx")
    var parts: Node3D = battle.get("target_parts")
    if ik == null or fx == null or parts == null:
        _fail("missing real battle IK / dirt / body adapter")
        return
    if (absf(IK_SCRIPT.LEG_BREAK_REACTION_SECONDS - 2.5) > 0.001
            or absf(IK_SCRIPT.ALL_LEGS_BREAK_REACTION_SECONDS - 6.0) > 0.001
            or absf(IK_SCRIPT.SINGLE_LEG_RISE_SECONDS - 1.0) > 0.001
            or absf(IK_SCRIPT.FOUR_LEG_RISE_SECONDS - 1.3) > 0.001):
        _fail("original knockdown and standup durations changed")
        return
    var head: Vector3 = parts.call("get_part_aim_world", "head")
    ik.call("start_leg_break_slide", "leg_fl", head.y, false)
    if absf(float(ik.get("break_duration")) - 4.66) > 0.001:
        _fail("normal down timing changed")
        return
    battle.call("_tick_bittaran_body_fall_fx")
    if int(fx.get("body_fall_burst_count")) != 0:
        _fail("dust emitted before authored 1.75 second contact")
        return
    ik.set("authored_down_source_seconds", 1.749)
    battle.call("_tick_bittaran_body_fall_fx")
    if int(fx.get("body_fall_burst_count")) != 0:
        _fail("dust emitted before final keyed frame")
        return
    ik.set("authored_down_source_seconds", 1.75)
    ik.set("windup_elapsed", -1.0)
    ik.set("break_elapsed", 0.0)
    battle.call("_tick_bittaran_body_fall_fx")
    if int(fx.get("body_fall_burst_count")) != 1:
        _fail("contact failed to emit exactly one dust burst")
        return
    var box: AABB = parts.call("get_body_hit_aabb")
    var layers: Array = fx.get("body_fall_emitters")
    if layers.size() != 6:
        _fail("expected six stomp-inspired independent layers")
        return
    var cloud: CPUParticles3D = layers[2]
    if not cloud.emitting or cloud.local_coords:
        _fail("collapse cloud is not a world-space one-shot")
        return
    if (cloud.emission_box_extents.x <= box.size.x * 0.5
            or cloud.emission_box_extents.z <= box.size.z * 0.5):
        _fail("collapse dust does not exceed the true body footprint")
        return
    battle.call("_tick_bittaran_body_fall_fx")
    if int(fx.get("body_fall_burst_count")) != 1:
        _fail("single collapse re-emitted dust")
        return
    for p in [0.0, 0.05, 0.50, 0.95, 1.0]:
        var t: float = float(p)
        ik.set("break_elapsed", float(ik.get("break_recover_start"))
            + IK_SCRIPT.DOWN_REPLANT_SECONDS
            + IK_SCRIPT.SINGLE_LEG_RISE_SECONDS * t)
        var actual: float = float(ik.call("standup_pose_fraction"))
        var expected: float = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
        if absf(actual - expected) > 0.001:
            _fail("stand-up is not continuous C2 eased at " + str(t))
            return
    # Rear BODY impact must occur at authored 0.75, independently of
    # the 1.75 down-hold timer and regardless of which rear side broke.
    for rear_id in ["leg_rl", "leg_rr"]:
        battle.call("_reset_target_after_respawn")
        ik = battle.get("bittaran_foot_ik")
        fx = battle.get("bittaran_dirt_fx")
        head = parts.call("get_part_aim_world", "head")
        ik.call("start_leg_break_slide", rear_id, head.y, false)
        ik.set("authored_down_source_seconds", 0.749)
        battle.call("_tick_bittaran_body_fall_fx")
        if int(fx.get("body_fall_burst_count")) != 0:
            _fail("rear dust emitted before source 0.75 " + rear_id)
            return
        ik.set("authored_down_source_seconds", 0.75)
        battle.call("_tick_bittaran_body_fall_fx")
        if int(fx.get("body_fall_burst_count")) != 1:
            _fail("rear dust missing at source 0.75 " + rear_id)
            return
        if float(ik.get("break_elapsed")) >= 0.0:
            _fail("rear down timer started before 1.75")
            return
        if float(battle.get("fall_vertical_shake_strength")) < 1.0:
            _fail("rear dust did not trigger a large vertical camera impulse")
            return
        battle.call("_tick_bittaran_body_fall_fx")
        ik.set("authored_down_source_seconds", 1.75)
        battle.call("_tick_bittaran_body_fall_fx")
        if int(fx.get("body_fall_burst_count")) != 1:
            _fail("rear FX repeated at source 1.75")
            return
    battle.call("_reset_target_after_respawn")
    ik = battle.get("bittaran_foot_ik")
    fx = battle.get("bittaran_dirt_fx")
        # The four-shin case keeps 6.0s down and 1.3s upright transition.
    ik.call("start_leg_break_slide", "leg_fr", head.y, true)
    if (absf(float(ik.get("break_recover_start")) - 6.0) > 0.001
            or absf(float(ik.get("break_duration")) - 8.46) > 0.001):
        _fail("all-leg recovery clock changed")
        return
    fx.call("reset")
    if int(fx.get("body_fall_burst_count")) != 0:
        _fail("reset leaked collapse effect")
        return
    print("GODOT_BITTARAN_BODY_FALL_PASS one_shot=true wide_body_dust=true rise_C2=true timings_unchanged=true")
    quit(0)
