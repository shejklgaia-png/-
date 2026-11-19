extends SceneTree
## Live regression: 10s stationary filling, then smooth uncapped tracking
## once during the 2s blue sphere (including shrink), then capped beam
## tracking at 0.7x plus ground-distance catch-up, multi-hit damage
## (no hit-count cap), doubled boss movement and 0.7s neutral return.
const GUN = preload("res://scripts/bittaran_railgun.gd")
const AI = preload("res://scripts/bittaran_ai.gd")
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
            not _near(GUN.FLASH_GROW_SECONDS, 0.2)):
        _fail("0.7s aim entry and 1.0s sphere shrink timing changed")
        return
    if not _near(GUN.TRACK_START_SECONDS, GUN.FLASH_START) or (
            GUN.CHARGE_TRACK_FILTER_PER_SECOND < 20.0):
        _fail("fast aim must begin only when the sphere charge begins")
        return
    if not _near(GUN.BEAM_TRACK_SPEED_MULTIPLIER, 0.70) or (
            not _near(GUN.BEAM_GROUND_GAP_METERS, 0.50)) or (
            not _near(GUN.BEAM_HIT_INTERVAL_SECONDS, 0.20)):
        _fail("beam 0.7x, 0.5m ground catch-up and repeat pulse interval changed")
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
    var front: Vector3 = elevation.to_global(
        Vector3(0.0, 0.0, -9.0)) - Vector3.UP * 0.92
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
    var shrink_target: Vector3 = front + Vector3(25.0, 4.0, 0.0)
    gun.call("advance", 0.5, shrink_target, true)
    if not sphere.visible or not _near(
            sphere.scale.x, full_scale * 0.5, 0.04):
        _fail("sphere must shrink over its last entire second")
        return
    var shrink_angles: Vector2 = gun.call(
        "_desired_player_angles", shrink_target)
    if absf(angle_difference(float(gun.get("aim_yaw")),
            shrink_angles.x)) > deg_to_rad(0.05) or (
            absf(elevation.rotation.x - shrink_angles.y) > deg_to_rad(0.05)):
        _fail("uncapped tracking must continue through sphere shrink")
        return
    var before_beam: float = float(gun.get("tracked_world_yaw"))
    # Keep the target fixed through the last sphere frame, then move
    # abruptly at the first beam frame. Only beam-time turning is allowed.
    gun.call("advance", 0.499, shrink_target, true)
    var last_sphere_angles: Vector2 = gun.call(
        "_desired_player_angles", shrink_target)
    if not sphere.visible or (
            absf(angle_difference(float(gun.get("aim_yaw")),
                last_sphere_angles.x)) > deg_to_rad(0.05)):
        _fail("uncapped tracking ended before the sphere disappeared")
        return
    var beam_target: Vector3 = side + Vector3(5.0, 0, 0)
    before_beam = float(gun.get("tracked_world_yaw"))
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

    # At the beam start, on-axis tracking is 70% of the old speed.
    # When the projected ground-ray gap exceeds 0.5m, accelerate
    # toward the measured player travel speed (without a hard cap).
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
    if float(gun.get("beam_ground_gap_meters")) > 0.50 or (
            not _near(slowed_rate, normal_rate * 0.7, 0.05)):
        _fail("laser normal follow speed must be 0.7x within the 0.5m trace")
        return
    var lateral: Vector3 = on_axis
    for frame in range(12):
        lateral.x += 0.30
        gun.call("advance", DT, lateral, true)
    if float(gun.get("beam_ground_gap_meters")) <= 0.50 or (
            float(gun.get("beam_turn_rate_deg_per_sec")) <=
                slowed_rate + 5.0):
        _fail("laser did not accelerate to follow a moving target >0.5m away")
        return
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START + 0.10)
    gun.call("advance", DT, on_axis, true)
    gun.call("advance", DT, on_axis + Vector3(2, 0, 0), true)
    if float(gun.get("beam_turn_rate_deg_per_sec")) <= slowed_rate:
        _fail("laser did not adapt to faster actual player displacement")
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
    if not bool(gun.call("advance", 0.21, front, true)):
        _fail("laser reentry must cause another contact in the SAME shot")
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
    var cap: float = float(gun.call("_tracking_turn_rate", side))
    if absf(rad_to_deg(angle_difference(
            before_world_yaw, after_world_yaw))) > (cap * DT + 0.08):
        _fail("boss body rotation bypassed the absolute yaw cap")
        return

    # Equipped SERA stats govern the actual pursuit rate; 30m still sits
    # strictly between RUN and BOOST in angular space.
    var far: Vector3 = gun.global_position + (
        -gun.global_basis.z.normalized() * 30.0) - Vector3.UP * 0.92
    var far_rate: float = float(gun.call(
        "_tracking_turn_rate", far, 8.0, 5.0))
    if far_rate <= rad_to_deg(5.0 / 30.0) or (
            far_rate >= rad_to_deg(8.0 / 30.0)):
        _fail("equipment-adjusted tracking rate is not RUN < aim < BOOST")
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
    player.global_position = elevation.to_global(
        Vector3(0.0, 0.0, -9.0)) - Vector3.UP * 0.92
    var first_hp: float = float(scene.get("player_hp"))
    scene.call("_tick_bittaran_railgun", DT)
    var hp_after_first: float = float(scene.get("player_hp"))
    if hp_after_first >= first_hp or (
            not bool(scene.get("damage_reaction_active"))):
        _fail("initial laser contact must damage and cause normal recoil")
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
    player.global_position = elevation.to_global(
        Vector3(0.0, 0.0, -9.0)) - Vector3.UP * 0.92
    scene.call("_tick_bittaran_railgun", DT)
    if float(scene.get("shield")) >= 100.0 or (
            float(scene.get("player_hp")) < 800.0) or (
            bool(scene.get("damage_reaction_active"))):
        _fail("guarded laser must drain shield before applying knockback")
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

    print("GODOT_BITTARAN_RAILGUN_PASS 10s_stationary_fill=true ",
        "unrestricted_sphere_charge_aim=true direct_2s_beam_from_t12=true ",
        "0.7s_smooth_sphere_entry=true 0.7s_immediate_return=true ",
        "zero_prefire_hold=true zero_damage_arm_delay=true ",
        "beam_0_7x_baseline=true ground_gap_0_5m_follow=true ",
        "player_velocity_catchup=true unlimited_repeat_hits=true ",
        "repeat_hit_0_2s=true physical_knockback_preserved=true ",
        "double_boss_move_and_turn=true guard_still_blocks=true ",
        "laser_persists_after_hit=true ",
        "blue_rim_lightning_plasma_preserved=true source_rig_unchanged=true")
    quit(0)
