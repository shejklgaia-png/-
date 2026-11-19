extends SceneTree
## Live regression: 10s stationary filling, then smooth uncapped tracking
## once during blue-sphere growth/full, then 0.7x capped tracking at
## t=11 sphere shrink and t=12 laser, with 0-1.5m tighter eased follow,
## multi-hit damage
## (no hit-count cap), doubled boss movement and 0.7s neutral return.
const GUN = preload("res://scripts/bittaran_railgun.gd")
const AI = preload("res://scripts/bittaran_ai.gd")
const BATTLE = preload("res://scripts/bittaran_battle.gd")
const DT: float = 1.0 / 120.0


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_RAILGUN_FAIL: " + message)
    quit(1)


func _near(a: float, b: float, tolerance: float = 0.008) -> bool:
    return absf(a - b) <= tolerance


func _run() -> void:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var gun: Node3D = scene.get("bittaran_railgun")
    var player: CharacterBody3D = scene.get("player")
    if rig == null or gun == null or player == null or (
            gun.get_script() != GUN) or (
            not bool(gun.get("ready_to_fire"))):
        _fail("live Bittaran battle railgun failed setup")
        return

    # 10s stationary charge-lamp fill, 2s tracking blue orb,
    # 2s speed-limited laser, 0.7s neutral return; repeat.
    if not _near(GUN.WAIT_SECONDS, 10.0) or (
            not _near(GUN.FLASH_START, 10.0)) or (
            not _near(GUN.FLASH_END, 12.0)) or (
            not _near(GUN.BEAM_START, 12.0)) or (
            not _near(GUN.BEAM_END, 14.0)) or (
            not _near(GUN.RETURN_SECONDS, 0.7)) or (
            not _near(GUN.PERIOD_SECONDS, 14.7)):
        _fail("10s wait / 2s orb / 2s beam / 0.7s return timing changed")
        return
    if not _near(GUN.TRACK_BLEND_SECONDS, 0.7) or (
            not _near(GUN.FLASH_SHRINK_SECONDS, 1.0)) or (
            not _near(GUN.FLASH_SHRINK_START, 11.0)) or (
            not _near(GUN.FLASH_GROW_SECONDS, 0.2)):
        _fail("0.7s aim entry and 1.0s sphere shrink timing changed")
        return
    if not _near(GUN.TRACK_START_SECONDS, GUN.FLASH_START) or (
            GUN.CHARGE_TRACK_FILTER_PER_SECOND < 20.0):
        _fail("fast aim must begin only when the sphere charge begins")
        return
    if not _near(GUN.BEAM_TRACK_SPEED_MULTIPLIER, 0.70) or (
            not _near(GUN.BEAM_ON_AXIS_SPEED_MULTIPLIER, 0.85)) or (
            not _near(GUN.BEAM_AIM_FILTER_PER_SECOND, 14.0)) or (
            not _near(GUN.BEAM_GROUND_GAP_METERS, 1.50)) or (
            not _near(GUN.BEAM_HIT_INTERVAL_SECONDS, 0.20)):
        _fail("beam 0.85x near-axis, 0..1.5m faster aim, cap and repeat interval changed")
        return
    if not _near(BATTLE.LASER_DAMAGE_MULTIPLIER, 0.60, 0.0001):
        _fail("only Bittaran laser must have 60% attack strength")
        return
    if not _near(AI.APPROACH_SPEED_MPS, 1.872) or (
            not _near(AI.ACCELERATION_MPS2, 1.56)) or (
            not _near(AI.STATIONARY_TURN_DEG_PER_SEC, 68.0)) or (
            not _near(AI.MOVING_TURN_DEG_PER_SEC, 44.0)) or (
            not _near(AI.TRACK_AT_REST_DEG_PER_SEC, 36.0)):
        _fail("Bittaran movement and all chassis turns must double")
        return
    if not _near(float(GUN.CHASE_SPEED_MPS), 5.3828125, 0.01):
        _fail("default chase must be strictly faster than RUN, slower than BOOST")
        return
    if not (GUN.RUN_REFERENCE_SPEED_MPS < GUN.CHASE_SPEED_MPS
            and GUN.CHASE_SPEED_MPS < GUN.BOOST_REFERENCE_SPEED_MPS):
        _fail("only BOOST should outpace the turret by speed")
        return

    # Verify full, real AI motion outcomes instead of constants alone.
    var ai: RefCounted = AI.new()
    var far_player := Vector3(0.0, 0.0, 50.0)
    var walk1: Dictionary = ai.call("advance", 1.0,
        Vector3.ZERO, 0.0, far_player, false)
    if str(walk1["motion"]) != "Approach" or (
            not _near((walk1["position"] as Vector3).z, 1.56, 0.001)):
        _fail("Bittaran acceleration or actual first-second travel not doubled")
        return
    var walk2: Dictionary = ai.call("advance", 1.0,
        walk1["position"], float(walk1["yaw"]), far_player, false)
    if not _near((walk2["position"] as Vector3).z -
            (walk1["position"] as Vector3).z, 1.872, 0.001):
        _fail("Bittaran full actual approach travel must be 1.872m/s")
        return
    ai.call("reset")
    var turn: Dictionary = ai.call("advance", 1.0,
        Vector3.ZERO, 0.0, Vector3(50.0, 0.0, 0.0), false)
    if str(turn["motion"]) != "Turn" or (
            not _near(rad_to_deg(float(turn["yaw"])), 68.0, 0.01)):
        _fail("stationary Bittaran root must physically turn 68 deg/sec")
        return
    ai.call("reset")
    var moving: Dictionary = ai.call("advance", 0.1,
        Vector3.ZERO, 0.0, Vector3(10.0, 0.0, 30.0), false)
    if str(moving["motion"]) != "Approach" or (
            not _near(rad_to_deg(float(moving["yaw"])), 4.4, 0.02)):
        _fail("Bittaran walking turn must physically use 44 deg/sec")
        return
    ai.call("reset")
    var near_turn: Dictionary = ai.call("advance", 0.1,
        Vector3.ZERO, 0.0, Vector3(2.0, 0.0, 4.0), false)
    if str(near_turn["motion"]) != "Turn" or (
            not _near(rad_to_deg(float(near_turn["yaw"])), 3.6, 0.02)):
        _fail("Bittaran near-idle yaw must physically turn 36 deg/sec")
        return

    var elevation: Node3D = gun.get_node(
        "RailgunElevation") as Node3D
    var body: Node3D = rig.find_child(
        "Body", true, false) as Node3D
    var meshes: Dictionary = rig.get("mesh_nodes_by_uuid")
    if elevation == null or body == null or (
            gun.get_parent() != body) or meshes.size() != 18 or (
            (rig.get("bones") as Dictionary).size() != 14):
        _fail("18 original meshes/14 bones/two-axis mount changed")
        return
    var base_positions: Dictionary = rig.get("mesh_base_positions_by_uuid")
    for uid in GUN.RAIL_MESH_UUIDS:
        var rail: MeshInstance3D = meshes.get(uid)
        if rail == null or rail.get_parent() != elevation or (
                rail.position.distance_to(base_positions[uid]) > 0.0001):
            _fail("original Blockbench rail mesh binding was modified")
            return
    var bars: Array = gun.get("charge_materials")
    if bars.size() != 6:
        _fail("3 charge bars on each turret side are required")
        return
    var core: MeshInstance3D = gun.get("inner_beam")
    var halo: MeshInstance3D = gun.get("outer_beam")
    var sphere: MeshInstance3D = gun.get("muzzle_flash")
    var fx: Node3D = gun.get("energy_fx")
    var rim: MeshInstance3D = fx.get_node("RailgunElectricBlueRim")
    var orb_arcs: MeshInstance3D = fx.get_node("RailgunOrbLightning")
    var plasma: MeshInstance3D = fx.get_node("RailgunTravelingPlasma")
    var beam_arcs: MeshInstance3D = fx.get_node("RailgunBeamLightning")
    if core == null or halo == null or sphere == null or (
            rim == null) or orb_arcs == null or plasma == null or (
            beam_arcs == null):
        _fail("old blue orb and electric/plasma FX must remain intact")
        return
    if (core.material_override as BaseMaterial3D).no_depth_test or (
            (orb_arcs.material_override as BaseMaterial3D).no_depth_test):
        _fail("laser/arc FX must obey armor depth occlusion")
        return

    var baseline_body: Quaternion = body.quaternion
    # WAIT may follow animated Body pitch/roll. The beam begins from a
    # stabilized world-Y turret, so use that neutral axis for contact tests
    # instead of assuming the idle barrel is already horizontally level.
    var neutral_heading: Basis = Basis(Quaternion(
        Vector3.UP, float(gun.call("_neutral_world_yaw")))).scaled(
        gun.global_basis.get_scale())
    var front: Vector3 = (
        gun.global_position + neutral_heading * Vector3(0.0, 0.0, -9.0)
        - Vector3.UP * 0.92)
    var side: Vector3 = front + Vector3(8.0, 2.0, 0.0)
    gun.call("reset")
    gun.call("advance", 5.0, side, true)
    if absf(float(gun.get("aim_yaw"))) > 0.00001 or (
            absf(elevation.rotation.x) > 0.00001) or (
            bool(gun.get("tracking_world_initialized"))) or (
            sphere.visible) or core.visible:
        _fail("gun moved during the first 10s stationary fill")
        return
    if (bars[0] as StandardMaterial3D).emission_energy_multiplier <= 0.22 or (
            (bars[2] as StandardMaterial3D).emission_energy_multiplier > 0.25):
        _fail("lamp fill must continue while gun remains neutral")
        return
    gun.call("advance", 4.999, side + Vector3(12.0, 3.0, 0.0), true)
    if absf(float(gun.get("aim_yaw"))) > 0.00001 or (
            absf(elevation.rotation.x) > 0.00001) or (
            bool(gun.get("tracking_world_initialized"))) or sphere.visible:
        _fail("gun must stay neutral through t=9.999 despite player motion")
        return
    if not _near(float(gun.call("_prefire_ease", 10.0)), 0.0) or (
            not _near(float(gun.call("_prefire_ease", 10.35)), 0.5)) or (
            not _near(float(gun.call("_prefire_ease", 10.70)), 1.0)):
        _fail("single charge entry must smoothstep from t=10 to t=10.7")
        return
    gun.call("advance", 0.002, side, true)
    var first_step_yaw: float = absf(float(gun.get("aim_yaw")))
    if first_step_yaw >= deg_to_rad(1.0) or (
            not bool(gun.get("tracking_world_initialized"))):
        _fail("sphere charge must start tracking smoothly without snapping")
        return
    if not sphere.visible or core.visible or halo.visible or (
            not rim.visible) or (not orb_arcs.visible) or (
            plasma.visible) or (
            (orb_arcs.mesh as ImmediateMesh).get_surface_count() < 1):
        _fail("at t=10 the blue electric sphere must start WITHOUT a beam")
        return
    if (bars[2] as StandardMaterial3D).emission_energy_multiplier < 4.0:
        _fail("all three charge bars must be full as sphere starts")
        return
    var initial_scale: float = sphere.scale.x
    gun.call("advance", 0.24, side, true)
    if not sphere.visible or sphere.scale.x <= initial_scale:
        _fail("sphere must grow over its initial 0.2s")
        return
    var full_scale: float = sphere.scale.x
    gun.call("advance", 0.758, side, true)
    if not sphere.visible or not _near(sphere.scale.x, full_scale, 0.03):
        _fail("sphere must stay full until 1s before firing")
        return
    var charge_target: Vector2 = gun.call("_desired_player_angles", side)
    if absf(angle_difference(float(gun.get("aim_yaw")),
            charge_target.x)) > deg_to_rad(0.05) or (
            absf(elevation.rotation.x - charge_target.y) > deg_to_rad(0.05)):
        _fail("charge must acquire player before sphere begins shrinking")
        return
    # Just BEFORE t=11, an abrupt player sidestep must be chased by
    # high-response ACQUISITION, not snapped in one sub-frame. The old
    # weight>=1.0 shortcut bypassed the smoothing filter and made the
    # turret accelerate 4.5x on exactly the 0.7s boundary at 120Hz.
    var shrink_target: Vector3 = front + Vector3(25.0, 4.0, 0.0)
    var jump_before: float = float(gun.get("tracked_world_yaw"))
    var pre_shrink_angles: Vector2 = gun.call(
        "_desired_player_world_angles", shrink_target)
    gun.call("advance", 0.0004, shrink_target, true)
    var pre_shrink_yaw: float = float(gun.get("tracked_world_yaw"))
    var jumped_radians: float = absf(angle_difference(
        jump_before, pre_shrink_yaw))
    var error_radians: float = absf(angle_difference(
        jump_before, pre_shrink_angles.x))
    var filtered_fraction: float = 1.0 - exp(
        -GUN.CHARGE_TRACK_FILTER_PER_SECOND * 0.0004)
    if error_radians < 0.1 or (
            jumped_radians > error_radians * filtered_fraction * 1.1) or (
            jumped_radians < error_radians * filtered_fraction * 0.9):
        _fail("uncapped charge chase must retain finite frame-rate-independent smoothing")
        return
    # Cross t=11 with a suddenly different target: the first shrink frame
    # must start the 0.7x limit, with no extra unbounded acquisition tick.
    gun.call("advance", 0.0008, side, true)
    var shrink_start_limit: float = float(gun.call(
        "_tracking_turn_rate", side)) * GUN.BEAM_TRACK_SPEED_MULTIPLIER
    var shrink_start_step: float = absf(rad_to_deg(angle_difference(
        pre_shrink_yaw, float(gun.get("tracked_world_yaw")))))
    if shrink_start_step > shrink_start_limit * 0.0008 + 0.01 or (
            not sphere.visible):
        _fail("shrinking sphere did not immediately lower tracking to 0.7x")
        return
    var shrink_mid_start_yaw: float = float(gun.get("tracked_world_yaw"))
    gun.call("advance", 0.5, side, true)
    if not sphere.visible or not _near(
            sphere.scale.x, full_scale * 0.5, 0.04):
        _fail("sphere must shrink over its last entire second")
        return
    var shrink_mid_change: float = absf(rad_to_deg(angle_difference(
        shrink_mid_start_yaw, float(gun.get("tracked_world_yaw")))))
    if shrink_mid_change > shrink_start_limit * 0.5 + 0.06 or (
            float(gun.get("beam_turn_rate_deg_per_sec")) > 0.0001):
        _fail("shrinking sphere bypassed 0.7x or activated beam-only catch-up")
        return
    # Large late target movement still cannot restore pre-shrink unlimited
    # tracking. The outgoing beam picks up the same capped yaw seamlessly.
    var before_last_shrink: float = float(gun.get("tracked_world_yaw"))
    gun.call("advance", 0.498, shrink_target, true)
    var last_shrink_limit: float = float(gun.call(
        "_tracking_turn_rate", shrink_target)) * GUN.BEAM_TRACK_SPEED_MULTIPLIER
    var last_shrink_step: float = absf(rad_to_deg(angle_difference(
        before_last_shrink, float(gun.get("tracked_world_yaw")))))
    if not sphere.visible or (
            last_shrink_step > last_shrink_limit * 0.498 + 0.07):
        _fail("blue sphere shrink must stay capped until laser emission")
        return
    var beam_target: Vector3 = side + Vector3(5.0, 0, 0)
    var before_beam: float = float(gun.get("tracked_world_yaw"))
    gun.call("advance", 0.003, beam_target, true)
    if sphere.visible or not core.visible or not halo.visible or (
            not plasma.visible) or (not beam_arcs.visible):
        _fail("laser must fire at t=12 without any targeting hold")
        return
    var turn_at_launch: float = absf(rad_to_deg(angle_difference(
        before_beam, float(gun.get("tracked_world_yaw")))))
    var rate: float = float(gun.call(
        "_tracking_turn_rate", beam_target))
    if turn_at_launch > rate * 0.003 + 0.3:
        _fail("beam onset must immediately restore capped pursuit")
        return

    # Exactly 2s of firing; no 0.4s postfire hold. The first return
    # frame must already begin the 0.7s interpolation to neutral.
    gun.call("advance", 1.983, side, true)
    if not core.visible:
        _fail("laser switched off before the two seconds finished")
        return
    var last_fire_yaw: float = float(gun.get("aim_yaw"))
    gun.call("advance", 0.016, side, true)
    if core.visible or halo.visible or (
            int(gun.call("_phase_at",
            float(gun.get("elapsed")))) != GUN.Phase.RETURN):
        _fail("immediate return must begin at 14s without holding the gun")
        return
    var return_origin: float = float(gun.get("return_yaw_origin"))
    if absf(angle_difference(last_fire_yaw, return_origin)) > 0.001:
        _fail("return blend must start at the actual final firing angle")
        return
    gun.call("advance", 0.35, side, true)
    var midpoint_yaw: float = float(gun.get("aim_yaw"))
    if absf(midpoint_yaw) > absf(return_origin) + 0.001 or (
            absf(midpoint_yaw) < absf(return_origin) * 0.35):
        _fail("0.7s release must interpolate smoothly toward neutral")
        return
    gun.call("advance", 0.34, side, true)
    if absf(float(gun.get("aim_yaw"))) > deg_to_rad(0.6) or (
            absf(elevation.rotation.x) > deg_to_rad(0.6)):
        _fail("turret did not return to neutral after 0.7s")
        return
    gun.call("advance", 1.0, side, true)
    if bool(gun.get("tracking_world_initialized")) or (
            absf(float(gun.get("aim_yaw"))) > 0.00001) or (
            absf(elevation.rotation.x) > 0.00001):
        _fail("gun must remain parked during the next ten-second fill")
        return
    if body.quaternion.angle_to(baseline_body) > 0.00001:
        _fail("new turret implementation modified original Body pose")
        return

    # The beam begins at 0.85x chase rate and smoothly ramps to 1.0x
    # over 0..1.5m. The 1.5m boundary is a HARD SPEED PLATEAU, not
    # unlimited distance/velocity catch-up: RUN must be caught, BOOST
    # must always outrun the turret in lateral motion.
    if not _near(GUN.CHASE_SPEED_BLEND, 0.65, 0.0001):
        _fail("approved chase rate must remain between RUN and BOOST")
        return
    if not _near(float(gun.call("_beam_catchup_weight", 0.0)),
            0.0, 0.0001) or (
            not _near(float(gun.call("_beam_catchup_weight", 0.375)),
                0.15625, 0.0001)) or (
            not _near(float(gun.call("_beam_catchup_weight", 0.75)),
                0.5, 0.0001)) or (
            not _near(float(gun.call("_beam_catchup_weight", 1.125)),
                0.84375, 0.0001)) or (
            not _near(float(gun.call("_beam_catchup_weight", 1.5)),
                1.0, 0.0001)):
        _fail("0..1.5m smoothstep tracking blend changed")
        return
    var baseline_test: float = 20.0
    var full_test: float = baseline_test / 0.85
    var samples := [
        Vector2(0.0, 0.0), Vector2(0.375, 0.15625),
        Vector2(0.75, 0.5), Vector2(1.125, 0.84375),
        Vector2(1.5, 1.0), Vector2(4.0, 1.0),
        Vector2(10.0, 1.0), Vector2(100.0, 1.0)]
    for sample in samples:
        var actual_rate: float = float(gun.call("_beam_target_turn_rate",
            sample.x, baseline_test, full_test))
        var expected_rate: float = lerpf(baseline_test,
            full_test, sample.y)
        if not _near(actual_rate, expected_rate, 0.0001):
            _fail("laser turn rate is not a capped 0..1.5m smoothstep")
            return
        if actual_rate > full_test + 0.0001:
            _fail("beam rate exceeded the chase plateau beyond 1.5m")
            return
    for distance in [5.0, 8.0, 30.0]:
        var run_rate: float = rad_to_deg(
            GUN.RUN_REFERENCE_SPEED_MPS / distance)
        var boost_rate: float = rad_to_deg(
            GUN.BOOST_REFERENCE_SPEED_MPS / distance)
        var full_rate: float = rad_to_deg(
            GUN.CHASE_SPEED_MPS / distance)
        var allowed: float = float(gun.call("_beam_target_turn_rate",
            8.0, full_rate * 0.85, full_rate))
        if not (run_rate < allowed and allowed < boost_rate):
            _fail("RUN must lose ground but BOOST must escape the beam at " +
                str(distance) + "m")
            return
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START + 0.10)
    var beam_origin: Vector3 = elevation.to_global(
        Vector3(0.0, 0.0, GUN.MUZZLE_LOCAL_Z))
    var beam_ahead: Vector3 = -elevation.global_basis.z.normalized()
    var on_axis: Vector3 = beam_origin + beam_ahead * 10.0
    on_axis.y = 0.0
    gun.call("advance", DT, on_axis, true)
    var normal_rate: float = float(gun.call("_tracking_turn_rate", on_axis))
    var slowed_rate: float = float(gun.get("beam_turn_rate_deg_per_sec"))
    if float(gun.get("beam_ground_gap_meters")) > 0.05 or (
            not _near(slowed_rate, normal_rate * 0.85, 0.05)):
        _fail("laser on-axis follow speed must start at 0.85x baseline")
        return
    # A fast 1m sidestep enables stronger PARTIAL capped chase, with a
    # smooth transition to the 1.5m plateau. It is not a flat 0.85x interval.
    var near_gap_target: Vector3 = on_axis + Vector3(1.0, 0.0, 0.0)
    gun.call("advance", DT, near_gap_target, true)
    var near_gap: float = float(gun.get("beam_ground_gap_meters"))
    if near_gap >= GUN.BEAM_GROUND_GAP_METERS or (
            float(gun.get("beam_turn_rate_deg_per_sec")) <=
                slowed_rate + 0.05):
        _fail("laser must partially accelerate at 1m instead of step at 1.5m")
        return
    var lateral: Vector3 = near_gap_target
    for frame in range(12):
        lateral.x += 0.30
        gun.call("advance", DT, lateral, true)
    var lateral_max_rate: float = float(gun.call(
        "_tracking_turn_rate", lateral))
    var lateral_command: float = float(gun.get("beam_turn_rate_deg_per_sec"))
    # The permitted angular rate is SPEED / CURRENT DISTANCE. As the player
    # sidesteps from 10m to ~11m away the full angular cap decreases; it
    # cannot exceed the *earlier* on-axis command by a fixed +5deg/s.
    # Preserve the independent 1.5m plateau, real overshoot and BOOST bounds:
    # after twelve 120Hz frames at the larger gap, motor response 16/s
    # must approach at least 95% of the contemporaneous full cap.
    if float(gun.get("beam_ground_gap_meters")) <= GUN.BEAM_GROUND_GAP_METERS or (
            lateral_command < lateral_max_rate * 0.95) or (
            lateral_command > lateral_max_rate + 0.0001):
        _fail("laser did not approach its current-distance capped chase rate after 1.5m gap")
        return
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START + 0.10)
    gun.call("advance", DT, on_axis, true)
    gun.call("advance", DT, on_axis + Vector3(2, 0, 0), true)
    if float(gun.get("beam_turn_rate_deg_per_sec")) <= slowed_rate:
        _fail("laser did not adapt smoothly to actual player displacement")
        return

    # Every genuine overlap may hit again after the time-based interval.
    # Collision still starts on the first firing frame; max count is NONE.
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START - DT * 0.5)
    if not bool(gun.call("advance", DT, front, true)) or not core.visible:
        _fail("laser first contact must be active immediately")
        return
    if bool(gun.call("advance", 0.10, front, true)):
        _fail("laser repeat overlap bypassed the 0.2s pulse interval")
        return
    var hit_count: int = 1
    for pulse in range(5):
        if bool(gun.call("advance", 0.21, front, true)):
            hit_count += 1
    if hit_count < 5:
        _fail("continuous laser contact must register multiple hits per shot")
        return
    var no_contact: Vector3 = front + Vector3(25.0, 0.0, 0.0)
    if bool(gun.call("advance", 0.21, no_contact, true)):
        _fail("a missed laser must not deal any contact damage")
        return
    # Returning to the PREVIOUS world coordinate is not re-entering a
    # tracking beam; move onto the CURRENT live laser axis instead.
    var current_beam_contact: Vector3 = elevation.to_global(
        Vector3(0.0, 0.0, -9.0)) - Vector3.UP * 0.92
    if not bool(gun.call("advance", 0.21, current_beam_contact, true)):
        _fail("live-beam reentry must allow another hit in the SAME shot")
        return
    gun.call("advance", 0.50, front, true)
    if core.visible or float(gun.get("beam_hit_cooldown")) > 0.0:
        _fail("end of beam must clear contact timer")
        return
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START - DT * 0.5)
    if not bool(gun.call("advance", DT, front, true)):
        _fail("next shot must again hit on the first real overlap")
        return

    # Even a 90-degree boss root turn cannot instantly drag the
    # world-space gun toward a target while the laser is tracking.
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START + 0.9)
    gun.call("advance", DT, side, true)
    var before_world_yaw: float = float(
        gun.get("tracked_world_yaw"))
    var saved_root_yaw: float = rig.rotation.y
    rig.rotation.y += PI * 0.5
    gun.call("advance", DT, side, true)
    var after_world_yaw: float = float(
        gun.get("tracked_world_yaw"))
    rig.rotation.y = saved_root_yaw
    # Firing uses the live 0.85x / 0..1.5m catch-up blend, not the old
    # unscaled constant. World-root rotation may NEVER add extra yaw.
    var cap: float = float(gun.get("beam_turn_rate_deg_per_sec"))
    if absf(rad_to_deg(angle_difference(
            before_world_yaw, after_world_yaw))) > (cap * DT + 0.08):
        _fail("boss body rotation bypassed the live laser turn-rate cap")
        return

    # Equipped SERA stats govern the capped pursuit rate; 30m still sits
    # strictly between RUN and BOOST in angular space.
    var far: Vector3 = gun.global_position + (
        -gun.global_basis.z.normalized() * 30.0) - Vector3.UP * 0.92
    var far_rate: float = float(gun.call(
        "_tracking_turn_rate", far, 8.0, 5.0))
    if far_rate <= rad_to_deg(5.0 / 30.0) or (
            far_rate >= rad_to_deg(8.0 / 30.0)):
        _fail("equipment-adjusted tracking rate is not RUN < aim < BOOST")
        return

    # Live pursuit, not constants alone: move a player tangentially around
    # the turret for 1.5s at equipped RUN and BOOST speeds. RUN should
    # remain tightly under the beam (under 0.8m); BOOST still opens a
    # clear lateral gap. This is a tighter condition than v493.
    var lateral_run_gap: float = 0.0
    var lateral_boost_gap: float = 0.0
    for player_speed in [GUN.RUN_REFERENCE_SPEED_MPS,
            GUN.BOOST_REFERENCE_SPEED_MPS]:
        gun.call("reset")
        var neutral_axis: Basis = Basis(Quaternion(Vector3.UP,
            float(gun.call("_neutral_world_yaw"))))
        var initial_heading: Vector3 = -neutral_axis.z.normalized()
        var center: Vector3 = gun.global_position
        # The live firing beam is preceded by 2s of acquisition and sphere
        # shrink. Starting directly at BEAM skips that 0.7s world-aim entry,
        # leaving an artificial initial angular error even for a player
        # standing on the neutral axis. Simulate the real prefire to isolate
        # how well RUN/BOOST escape *during* the laser.
        var initial_player: Vector3 = center + initial_heading * 10.0
        initial_player.y = 0.0
        gun.set("elapsed", GUN.FLASH_START)
        for prefire_frame in range(int(round(GUN.FLASH_SECONDS / DT))):
            gun.call("advance", DT, initial_player, true)
        for frame in range(180):
            var theta: float = player_speed * float(frame) * DT / 10.0
            var player_at: Vector3 = center + (
                initial_heading.rotated(Vector3.UP, theta) * 10.0)
            player_at.y = 0.0
            gun.call("advance", DT, player_at, true)
        var final_gap: float = float(gun.get("beam_ground_gap_meters"))
        if player_speed == GUN.RUN_REFERENCE_SPEED_MPS:
            lateral_run_gap = final_gap
        else:
            lateral_boost_gap = final_gap
    if lateral_run_gap >= 0.8 or (
            lateral_boost_gap <= lateral_run_gap + 0.5) or (
            lateral_boost_gap <= GUN.BEAM_RADIUS_METERS +
                GUN.PLAYER_HIT_RADIUS_METERS):
        _fail("1.5s live lateral pursuit must closely track RUN but lose BOOST: " +
            str(lateral_run_gap) + "m vs " +
            str(lateral_boost_gap) + "m")
        return

    # In the real battle, a second overlap damages HP again. Ongoing
    # Damageknock animation and knockback vector are NOT restarted.
    scene.set("player_hp", 800.0)
    scene.set("training_ko_remaining", 0.0)
    scene.set("guard_active", false)
    scene.set("guard_break_remaining", 0.0)
    scene.set("down_remaining", 0.0)
    scene.set("damage_reaction_active", false)
    scene.set("movement_boost_active", true)
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START - DT * 0.5)
    # The first beam frame is world-stabilized, while WAIT can be
    # tilted along with Body. Place the player on the FIRING axis.
    player.global_position = gun.global_position + Basis(Quaternion(
        Vector3.UP, float(gun.call("_neutral_world_yaw")))).scaled(
        gun.global_basis.get_scale()) * Vector3(0.0, 0.0, -9.0) - Vector3.UP * 0.92
    var first_hp: float = float(scene.get("player_hp"))
    scene.call("_tick_bittaran_railgun", DT)
    var hp_after_first: float = float(scene.get("player_hp"))
    var parts: Dictionary = scene.get("part_stats")
    var defense: float = clampf(float(parts.get("defense", 0.16)), 0.0, 0.90)
    var expected_laser_hp: float = (
        18.0 *
        BATTLE.LASER_DAMAGE_MULTIPLIER * (1.0 - defense))
    if not _near(first_hp - hp_after_first, expected_laser_hp, 0.005) or (
            not bool(scene.get("damage_reaction_active"))):
        _fail("laser must deal precisely 60% of old HP damage, keeping recoil")
        return
    var recoil_start: Vector3 = player.global_position
    scene.call("_advance_damage_knockback", 0.12)
    if player.global_position.distance_to(recoil_start) < 0.03 or (
            float(scene.get("damage_knockback_elapsed")) < 0.10):
        _fail("laser contact must preserve physical knockback")
        return
    var recoil_elapsed: float = float(scene.get("damage_knockback_elapsed"))
    player.global_position = elevation.to_global(
        Vector3(0.0, 0.0, -9.0)) - Vector3.UP * 0.92
    scene.call("_tick_bittaran_railgun", 0.21)
    if float(scene.get("player_hp")) >= hp_after_first or (
            float(scene.get("damage_knockback_elapsed")) <
                recoil_elapsed - 0.001):
        _fail("second overlap must damage without restarting knockback")
        return
    var hp_after_second: float = float(scene.get("player_hp"))
    player.global_position += Vector3(25.0, 0.0, 0.0)
    scene.call("_tick_bittaran_railgun", 0.21)
    if not _near(float(scene.get("player_hp")), hp_after_second):
        _fail("laser repeat pulse damaged a player off its beam")
        return
    # Re-enter the live beam's MOVING axis, not the original launch
    # bearing from before the boss chased the off-axis target.
    player.global_position = elevation.to_global(
        Vector3(0.0, 0.0, -9.0)) - Vector3.UP * 0.92
    scene.call("_tick_bittaran_railgun", 0.21)
    if float(scene.get("player_hp")) >= hp_after_second:
        _fail("player reentry must damage within the same shot")
        return
    scene.call("_tick_bittaran_railgun", 1.40)
    if core.visible or float(gun.get("beam_hit_cooldown")) > 0.0:
        _fail("beam end must clear repeated-hit interval")
        return

    # Guard still consumes shield before HP; blocking laser does not
    # apply unguarded physical knockback until shield breaks.
    scene.set("player_hp", 800.0)
    scene.set("shield", 100.0)
    scene.set("guard_active", true)
    scene.set("damage_reaction_active", false)
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START - DT * 0.5)
    # The first beam frame is world-stabilized, while WAIT can be
    # tilted along with Body. Place the player on the FIRING axis.
    player.global_position = gun.global_position + Basis(Quaternion(
        Vector3.UP, float(gun.call("_neutral_world_yaw")))).scaled(
        gun.global_basis.get_scale()) * Vector3(0.0, 0.0, -9.0) - Vector3.UP * 0.92
    scene.call("_tick_bittaran_railgun", DT)
    var expected_laser_guard_cost: float = (
        23.0 *
        BATTLE.LASER_DAMAGE_MULTIPLIER *
        float(parts.get("guard_cost_mult", 1.0)) /
        maxf(0.2, float(parts.get("guard_defense_mult", 1.0))))
    if not _near(100.0 - float(scene.get("shield")),
            expected_laser_guard_cost, 0.005) or (
            float(scene.get("player_hp")) < 800.0) or (
            bool(scene.get("damage_reaction_active"))):
        _fail("guarded laser must cost exactly 60%, preserve HP and recoil")
        return

    # Normal bullets still use their original 100% power. This proves
    # v481 changes only the laser, NOT global attack-type 0 gameplay.
    scene.set("guard_active", false)
    scene.set("player_hp", 800.0)
    scene.set("training_ko_remaining", 0.0)
    scene.call("_on_enemy_projectile_hit",
        player.global_position, Vector3.FORWARD, true, 0, true)
    var expected_unscaled_hp: float = (
        18.0 * (1.0 - defense))
    if not _near(800.0 - float(scene.get("player_hp")),
            expected_unscaled_hp, 0.005):
        _fail("non-laser projectile damage was incorrectly reduced")
        return

    # On player KO the beam keeps its full authored firing duration.
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START + 0.8)
    scene.set("player_hp", 0.0)
    scene.set("training_ko_remaining", 1.0)
    scene.call("_tick_bittaran_railgun", DT)
    if not core.visible or not halo.visible:
        _fail("player KO incorrectly stopped the current laser")
        return
    gun.call("reset")
    if core.visible or halo.visible or sphere.visible or (
            rim.visible) or orb_arcs.visible or (
            plasma.visible) or beam_arcs.visible:
        _fail("boss/encounter reset did not clear old energy VFX")
        return

    # v505: animated Body becomes upright during targeting. The return
    # from WAIT's tilted pose MUST NOT add a second aiming rotation on
    # top of the motor. The outgoing barrel stays on the same world ray
    # when the player holds perfectly still on its original axis.
    var stored_body_transform: Transform3D = body.transform
    body.quaternion = (baseline_body
        * Quaternion(Vector3.RIGHT, 0.63)
        * Quaternion(Vector3.BACK, 0.41)).normalized()
    gun.call("reset")
    var original_forward: Vector3 = -elevation.global_basis.z.normalized()
    var original_target: Vector3 = (
        gun.global_position + original_forward * 25.0 - Vector3.UP * 0.92)
    gun.call("advance", GUN.WAIT_SECONDS - 0.001, original_target, true)
    var wait_forward: Vector3 = -elevation.global_basis.z.normalized()
    gun.call("advance", 0.002, original_target, true)
    var charge_start_forward: Vector3 = -elevation.global_basis.z.normalized()
    if rad_to_deg(acos(clampf(wait_forward.dot(charge_start_forward),
            -1.0, 1.0))) > 1.0:
        _fail("entering sphere charge snapped the tilted Body gun's world aim")
        return
    gun.call("advance", 0.35, original_target, true)
    var charge_middle_forward: Vector3 = -elevation.global_basis.z.normalized()
    if rad_to_deg(acos(clampf(wait_forward.dot(charge_middle_forward),
            -1.0, 1.0))) > 1.0:
        _fail("tilted-to-upright pose blend added uncommanded tracking velocity")
        return
    gun.call("advance", 0.35, original_target, true)
    var charge_end_forward: Vector3 = -elevation.global_basis.z.normalized()
    if rad_to_deg(acos(clampf(wait_forward.dot(charge_end_forward),
            -1.0, 1.0))) > 1.0:
        _fail("pose completion accelerated aiming even without target motion")
        return

    # During the live beam, the approved 0..1.5m gap and RUN<rate<BOOST
    # speed law depend on player distance and the MOTOR world ray only.
    # Pose-induced translation of the animated Body cannot increase them.
    body.transform = stored_body_transform
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START + 0.35)
    var stable_target: Vector3 = (
        gun.global_position + Vector3(4.0, -0.92, -22.0))
    gun.call("advance", 0.0, stable_target, true)
    var speed_before_tilt: float = float(gun.call(
        "_tracking_turn_rate", stable_target))
    var gap_before_tilt: float = float(gun.call(
        "_ground_ray_gap", stable_target))
    var yaw_before_tilt: float = float(gun.get("tracked_world_yaw"))
    var forward_before_tilt: Vector3 = -elevation.global_basis.z.normalized()
    var mount_before_tilt: Vector3 = gun.global_position
    body.quaternion = (baseline_body
        * Quaternion(Vector3.RIGHT, 0.87)
        * Quaternion(Vector3.BACK, -0.57)).normalized()
    gun.call("advance", 0.0, stable_target, true)
    var speed_after_tilt: float = float(gun.call(
        "_tracking_turn_rate", stable_target))
    var gap_after_tilt: float = float(gun.call(
        "_ground_ray_gap", stable_target))
    var forward_after_tilt: Vector3 = -elevation.global_basis.z.normalized()
    if gun.global_position.distance_to(mount_before_tilt) < 0.02:
        _fail("tilt test did not move the actual animated mount")
        return
    if not _near(speed_before_tilt, speed_after_tilt, 0.0005) or (
            not _near(gap_before_tilt, gap_after_tilt, 0.0005)):
        _fail("animated Body tilt changed the railgun motor tracking speed")
        return
    if rad_to_deg(acos(clampf(forward_before_tilt.dot(forward_after_tilt),
            -1.0, 1.0))) > 0.02 or (
            absf(angle_difference(
                yaw_before_tilt, float(gun.get("tracked_world_yaw")))) > 0.0001):
        _fail("zero-delta Body tilt rotated the live world-space railgun")
        return
    gun.call("advance", DT, stable_target, true)
    var motor_deg: float = absf(rad_to_deg(angle_difference(
        yaw_before_tilt, float(gun.get("tracked_world_yaw")))))
    var turn_cap: float = float(gun.get("beam_turn_rate_deg_per_sec"))
    if motor_deg > turn_cap * DT + 0.08:
        _fail("upright Body posture bypassed the capped motor turn budget")
        return
    # Pure barrel ELEVATION must not silently increase the ground-ray
    # catch-up command. Ray gap is measured in yaw-only horizontal space,
    # not along a shrinking projection of an almost vertical barrel.
    var original_test_pitch: float = elevation.rotation.x
    var horizontal_gap: float = float(gun.call(
        "_ground_ray_gap", stable_target))
    elevation.rotation.x = deg_to_rad(78.0)
    var high_pitch_gap: float = float(gun.call(
        "_ground_ray_gap", stable_target))
    elevation.rotation.x = original_test_pitch
    if not _near(horizontal_gap, high_pitch_gap, 0.0005):
        _fail("railgun elevation/vertical tilt incorrectly accelerates gap catch-up")
        return
    body.transform = stored_body_transform
    gun.call("reset")

    # v507 independent discontinuity regression: crossing the original
    # acquisition-weight=1 threshold may NOT jump from a 30/s filter to
    # full instantaneous tracking. This must hold at 60Hz and 120Hz.
    for frame_dt in [1.0 / 60.0, 1.0 / 120.0]:
        gun.call("reset")
        var base_heading: float = float(gun.call("_neutral_world_yaw"))
        var off_axis_target: Vector3 = (
            gun.global_position +
            Basis(Quaternion(Vector3.UP, base_heading +
                deg_to_rad(35.0))) * Vector3(0.0, -0.92, -14.0))
        var target_heading: Vector2 = gun.call(
            "_desired_player_world_angles", off_axis_target)
        var whole_error: float = absf(angle_difference(
            base_heading, target_heading.x))
        gun.call("_track_player", frame_dt, off_axis_target,
            0.999999, GUN.BOOST_REFERENCE_SPEED_MPS,
            GUN.RUN_REFERENCE_SPEED_MPS, true, false)
        var below_full: float = absf(angle_difference(
            base_heading, float(gun.get("tracked_world_yaw"))))
        gun.call("reset")
        gun.call("_track_player", frame_dt, off_axis_target,
            1.0, GUN.BOOST_REFERENCE_SPEED_MPS,
            GUN.RUN_REFERENCE_SPEED_MPS, true, false)
        var at_full: float = absf(angle_difference(
            base_heading, float(gun.get("tracked_world_yaw"))))
        var expected_frac: float = 1.0 - exp(
            -GUN.CHARGE_TRACK_FILTER_PER_SECOND * frame_dt)
        if whole_error < deg_to_rad(20.0) or (
                absf(at_full - whole_error * expected_frac) >
                deg_to_rad(0.02)) or (
                at_full > below_full * 1.02) or (
                at_full < below_full * 0.98):
            _fail("charge gain=1 frame must remain smooth at " +
                str(roundf(1.0 / frame_dt)) + "Hz; no 0.7s speed spike")
            return
    gun.call("reset")

    print("GODOT_BITTARAN_RAILGUN_PASS 10s_stationary_fill=true ",
        "fast_charge_only_before_shrink=true shrink_t11_slow_0_7x=true ",
        "direct_2s_beam_from_t12=true ",
        "0.7s_smooth_sphere_entry=true 0.7s_immediate_return=true ",
        "zero_prefire_hold=true zero_damage_arm_delay=true ",
        "beam_0_85x_baseline=true ground_gap_1_5m_tight_follow=true ",
         "run_close_boost_escapes=true plateau_1_5m=true laser_60pct_power=true ",
        "normal_projectiles_unchanged=true unlimited_repeat_hits=true ",
        "repeat_hit_0_2s=true physical_knockback_preserved=true ",
        "double_boss_move_and_turn=true guard_still_blocks=true ",
        "laser_persists_after_hit=true ",
        "blue_rim_lightning_plasma_preserved=true source_rig_unchanged=true")
    quit(0)
