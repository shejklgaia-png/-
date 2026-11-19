extends SceneTree
## Live Godot regression: Bittaran laser/charge timing, model pivots and
## guard integration without changing the 14-bone authored attack skeleton.
const BATTLE = preload("res://scripts/bittaran_battle.gd")
const GUN = preload("res://scripts/bittaran_railgun.gd")
const DT: float = 1.0 / 120.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_RAILGUN_FAIL: " + message)
    quit(1)

func _near(value: float, expected: float, tolerance: float = 0.005) -> bool:
    return absf(value - expected) <= tolerance

func _run() -> void:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var gun: Node3D = scene.get("bittaran_railgun")
    var player: CharacterBody3D = scene.get("player")
    if rig == null or gun == null or player == null:
        _fail("battle did not attach an independent railgun")
        return
    if gun.get_script() != GUN or not bool(gun.get("ready_to_fire")):
        _fail("wrong railgun controller or setup failed")
        return
    if not _near(GUN.PERIOD_SECONDS, 10.0) or (
            not _near(GUN.BEAM_SECONDS, 2.0)):
        _fail("ten-second launch/two-second beam contract changed")
        return
    # One speed cap is shared by charge, blue orb, lock-hold and beam.
    if not _near(GUN.PRE_FIRE_YAW_SPEED, GUN.TRACK_YAW_SPEED) or (
            not _near(GUN.PRE_FIRE_PITCH_SPEED, GUN.TRACK_PITCH_SPEED)) or (
            not _near(GUN.TRACK_YAW_SPEED, 15.12)) or (
            not _near(GUN.TRACK_PITCH_SPEED, 11.34)) or (
            not _near(GUN.PRE_FIRE_FILTER_PER_SECOND,
                GUN.TRACK_FILTER_PER_SECOND)) or (
            GUN.BOOST_TURN_FRACTION > 0.35):
        _fail("charge/beam must share slow world-space boost-safe turn caps")
        return
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    var elevation: Node3D = gun.get_node("RailgunElevation") as Node3D
    if gun.get_parent() != body or elevation == null:
        _fail("railgun is not an independent Body-mounted yaw/pitch pair")
        return
    var meshes: Dictionary = rig.get("mesh_nodes_by_uuid")
    var originals: Dictionary = rig.get("mesh_base_positions_by_uuid")
    for uid in GUN.RAIL_MESH_UUIDS:
        var rail: MeshInstance3D = meshes.get(uid)
        if rail == null or rail.get_parent() != elevation or (
                rail.position.distance_to(originals[uid]) > 0.0001):
            _fail("authored rail/neutral mesh location lost " + uid)
            return
    if meshes.size() != 18 or (rig.get("bones") as Dictionary).size() != 14:
        _fail("skeleton/model topology was modified")
        return
    if gun.find_child("ChargeBar_L_1", true, false) == null or (
            gun.find_child("ChargeBar_R_3", true, false) == null):
        _fail("six visible three-stage charge bars are missing")
        return
    var bars: Array = gun.get("charge_materials")
    if bars.size() != 6:
        _fail("expected three emissive charge bars on each flank")
        return
    var fx: Node3D = gun.get("energy_fx") as Node3D
    if fx == null or fx.get_parent() != elevation:
        _fail("railgun energy FX must follow the independent pitch axis")
        return
    var rim: MeshInstance3D = fx.get_node(
        "RailgunElectricBlueRim") as MeshInstance3D
    var orb_arcs: MeshInstance3D = fx.get_node(
        "RailgunOrbLightning") as MeshInstance3D
    var plasma: MeshInstance3D = fx.get_node(
        "RailgunTravelingPlasma") as MeshInstance3D
    var beam_arcs: MeshInstance3D = fx.get_node(
        "RailgunBeamLightning") as MeshInstance3D
    if rim == null or orb_arcs == null or plasma == null or (
            beam_arcs == null):
        _fail("blue sphere rim / electric arcs / flowing beam layers missing")
        return
    if not (rim.material_override is ShaderMaterial) or (
            not (plasma.material_override is ShaderMaterial)):
        _fail("sphere rim and beam must have procedural shader materials")
        return
    var rim_shader: Shader = (
        rim.material_override as ShaderMaterial).shader
    var plasma_shader: Shader = (
        plasma.material_override as ShaderMaterial).shader
    if not rim_shader.code.contains("NORMAL") or (
            not rim_shader.code.contains("VIEW")) or (
            not rim_shader.code.contains("TIME")) or (
            not plasma_shader.code.contains("UV.y")) or (
            not plasma_shader.code.contains("TIME")):
        _fail("Fresnel blue flicker or travelling plasma shader is missing")
        return
    if rim_shader.code.contains("depth_test_disabled") or (
            plasma_shader.code.contains("depth_test_disabled")) or (
            (orb_arcs.material_override as BaseMaterial3D).no_depth_test) or (
            (beam_arcs.material_override as BaseMaterial3D).no_depth_test):
        _fail("energy effect must obey armor and player depth occlusion")
        return
    var body_before: Quaternion = body.quaternion
    # A PLAYER in the gun's forward cone should be hit, while legs and
    # Body must remain at their original local animation pose.
    var forward_target: Vector3 = elevation.to_global(Vector3(0.0, 0.0, -9.0))
    var player_origin: Vector3 = forward_target - Vector3.UP * 0.92
    # v473: CHARGE ITSELF must follow SERA, before any blue sphere.
    var side_target: Vector3 = forward_target + Vector3(4.0, 0.0, 0.0)
    gun.call("reset")
    for i in range(120):
        var player_target: Vector3 = (
            side_target if i % 2 == 0 else side_target + Vector3(0, 4, 0))
        gun.call("advance", DT, player_target, true)
    if absf(float(gun.get("aim_yaw"))) < deg_to_rad(0.5):
        _fail("turret must already track throughout early charge")
        return
    if body.quaternion.angle_to(body_before) > 0.00001:
        _fail("charging modified authored Body rotation")
        return
    if not _near(GUN.FLASH_SECONDS, 2.0) or not _near(
            GUN.FLASH_SHRINK_SECONDS, 1.0) or not _near(
            GUN.TRACK_EASE_IN_SECONDS, 2.0) or not _near(
            GUN.FINAL_LOCK_HOLD_SECONDS, 0.5) or not _near(
            GUN.TRACK_START_SECONDS, GUN.CHARGE_START) or not _near(
            GUN.FLASH_END, 9.5):
        _fail("continuous charge tracking / 2s orb / 0.5s hold changed")
        return
    if absf(float(gun.call("_prefire_ease", GUN.CHARGE_START))) > 0.00001 or (
            not _near(float(gun.call("_prefire_ease",
                GUN.CHARGE_START + 1.0)), 0.5)) or (
            not _near(float(gun.call("_prefire_ease",
                GUN.CHARGE_START + 2.0)), 1.0)):
        _fail("2s smoothstep from first CHARGE must remain continuous")
        return
    # Original two-second sphere timing remains 7.5 -> 9.5s.
    gun.call("reset")
    gun.set("elapsed", GUN.FLASH_START - 0.02)
    gun.call("advance", 0.01, side_target, true)
    var flash: MeshInstance3D = gun.get("muzzle_flash")
    var core: MeshInstance3D = gun.get("inner_beam")
    var halo: MeshInstance3D = gun.get("outer_beam")
    if flash.visible or core.visible or halo.visible:
        _fail("sphere appeared before the charge reached three full bars")
        return
    gun.call("advance", 0.011, side_target, true)
    if not flash.visible or core.visible or halo.visible:
        _fail("sphere must appear exactly at t=7.5s before laser")
        return
    if not rim.visible or not orb_arcs.visible or (
            plasma.visible or beam_arcs.visible) or (
            (orb_arcs.mesh as ImmediateMesh).get_surface_count() == 0):
        _fail("blue rim and crackling sphere arcs must accompany charge")
        return
    var initial_scale: float = flash.scale.x
    gun.call("advance", 0.24, side_target, true)
    if not flash.visible or flash.scale.x <= initial_scale:
        _fail("muzzle sphere must grow smoothly at the beginning")
        return
    var grown_scale: float = flash.scale.x
    # Sphere stays full until 8.5s: one second before sphere finishes.
    gun.call("advance", 0.759, side_target, true)
    if not flash.visible or absf(flash.scale.x - grown_scale) > 0.02:
        _fail("blue sphere must remain full-sized until final 1s shrink")
        return
    # One second of smoothstep shrink: at the midpoint (9.5s)
    # its diameter/scale is one half the starting value.
    gun.call("advance", 0.5, side_target, true)
    if not flash.visible or absf(flash.scale.x - grown_scale * 0.5) > 0.04:
        _fail("sphere must be half-sized after 0.5s of 1s shrink")
        return
    var midpoint_scale: float = flash.scale.x
    gun.call("advance", 0.4, side_target, true)
    if not flash.visible or flash.scale.x >= midpoint_scale * 0.25:
        _fail("sphere must shrink smoothly over full final second")
        return
    # Sphere finishes at 9.5s; the next 0.5s is a FULLY ACQUIRED
    # firing delay, with neither blue sphere nor active laser.
    gun.call("advance", 0.089, side_target, true)
    if not flash.visible or core.visible:
        _fail("sphere must remain visible for its full 2s duration")
        return
    gun.call("advance", 0.022, side_target, true)
    if flash.visible or core.visible or halo.visible:
        _fail("fully acquired 0.5s pause must begin before beam")
        return
    if rim.visible or orb_arcs.visible or plasma.visible or beam_arcs.visible:
        _fail("all blue energy effects must stop during acquired firing hold")
        return
    # The 0.5s delay is for readable targeting, not an illegal instant
    # lock: measured yaw must remain within the SAME boost-safe limit.
    var hold_yaw: float = float(gun.get("tracked_world_yaw"))
    if not bool(gun.get("tracking_world_initialized")):
        _fail("tracking unexpectedly reset on blue orb -> hold boundary")
        return
    if (bars[2] as StandardMaterial3D).emission_energy_multiplier < 4.0:
        _fail("third charge bar must remain lit during full-lock delay")
        return
    # Keep following even when the target moves during the 0.5s hold,
    # but do not ever jump to a moved target's exact position.
    var delayed_target: Vector3 = side_target + Vector3(3.0, 0.0, 1.0)
    gun.call("advance", 0.45, delayed_target, true)
    var mid_hold_yaw: float = float(gun.get("tracked_world_yaw"))
    var changed: float = absf(rad_to_deg(
        angle_difference(hold_yaw, mid_hold_yaw)))
    if core.visible or flash.visible or changed < 0.1 or (
            changed > GUN.TRACK_YAW_SPEED * 0.45 + 0.05):
        _fail("hold must keep moving at bounded, continuous speed")
        return
    # 10s period boundary starts BEAM, without any snap to the player.
    gun.call("advance", 0.055, delayed_target, true)
    if not core.visible or not halo.visible:
        _fail("laser started before/after the 0.5s targeting hold")
        return
    var launch_turn: float = absf(rad_to_deg(angle_difference(
        mid_hold_yaw, float(gun.get("tracked_world_yaw")))))
    if launch_turn > GUN.TRACK_YAW_SPEED * 0.055 + 0.1 or (
            not bool(gun.get("tracking_world_initialized"))):
        _fail("beam launch snapped turret or reset continuous chase")
        return
    if rim.visible or orb_arcs.visible or (
            not plasma.visible) or (not beam_arcs.visible) or (
            (beam_arcs.mesh as ImmediateMesh).get_surface_count() == 0):
        _fail("laser must add streaming blue plasma and jagged electricity")
        return
    if plasma.scale.y < 1.0 or (beam_arcs.get_parent() != fx):
        _fail("beam flow geometry must cover the authored 45m laser axis")
        return
    if (core.material_override as BaseMaterial3D).no_depth_test:
        _fail("beam illegally renders through opaque armor")
        return
    gun.call("advance", 2.01, player_origin, true)
    if core.visible:
        _fail("beam exceeded the two-second duration")
        return
    var aim_at_end: float = float(gun.get("aim_yaw"))
    gun.call("advance", 0.25, player_origin, true)
    if absf(angle_difference(aim_at_end, float(gun.get("aim_yaw")))) > 0.0001:
        _fail("postfire hold changed the target angle before 0.4s")
        return
    # Sample BEFORE the return->CHARGE boundary at 3.2s: after 3.2s
    # the NEW requirement is continuous slow tracking, not neutral.
    # A t=3.206s sample (old +0.93s) wrongly asserted a parked gun
    # AFTER charge has already started.
    gun.call("advance", 0.92, player_origin, true)
    if absf(float(gun.get("aim_yaw"))) > deg_to_rad(1.0) or (
            absf(elevation.rotation.x) > deg_to_rad(1.0)):
        _fail("barrel did not ease back to neutral BEFORE charge begins")
        return
    # On the next cycle the cannon follows the player during CHARGE,
    # and the light bars still progress independently of the tracking.
    gun.call("advance", 3.6, side_target, true)
    if absf(float(gun.get("aim_yaw"))) < deg_to_rad(0.1):
        _fail("turret stopped tracking during the next charge")
        return
    if (bars[0] as StandardMaterial3D).emission_energy_multiplier <= 0.22:
        _fail("charge progression did not light its first segment")
        return
    # Follow actual 6.09375m/s SERA around the boss throughout the
    # CHARGE -> FLASH -> LOCK_HOLD -> BEAM timeline. At no transition may
    # the cannon turn faster than its v471 slow angular cap.
    var boost_speed: float = GUN.BOOST_REFERENCE_SPEED_MPS
    var boost_radius: float = 8.0
    var reference_forward: Vector3 = -gun.global_basis.z.normalized()
    var reference_right: Vector3 = gun.global_basis.x.normalized()
    var pivot_world: Vector3 = gun.global_position
    gun.call("reset")
    var tracked_beam_frames: int = 0
    var saw_flash: bool = false
    var saw_hold: bool = false
    var saw_charge: bool = false
    for i in range(1040):
        var t: float = float(i + 1) * DT
        var travel_angle: float = boost_speed / boost_radius * t
        var orbit_target: Vector3 = pivot_world + (
            reference_forward * cos(travel_angle)
            + reference_right * sin(travel_angle)) * boost_radius
        var last_angle: float = float(gun.get("tracked_world_yaw"))
        var already_tracking: bool = bool(
            gun.get("tracking_world_initialized"))
        gun.call("advance", DT, orbit_target - Vector3.UP * 0.92,
            true, boost_speed)
        var current_angle: float = float(gun.get("tracked_world_yaw"))
        if already_tracking:
            var yaw_change: float = absf(rad_to_deg(angle_difference(
                last_angle, current_angle)))
            if yaw_change > GUN.TRACK_YAW_SPEED * DT + 0.08:
                _fail("continuous charge-to-beam slew snapped at t="
                    + str(t) + " by " + str(yaw_change) + "deg")
                return
        var phase_id: int = int(gun.call(
            "_phase_at", float(gun.get("elapsed"))))
        if phase_id == GUN.Phase.CHARGE:
            saw_charge = true
        elif phase_id == GUN.Phase.FLASH:
            saw_flash = true
        elif phase_id == GUN.Phase.LOCK_HOLD:
            saw_hold = true
        elif phase_id == GUN.Phase.BEAM:
            tracked_beam_frames += 1
            if not bool(gun.get("tracking_world_initialized")):
                _fail("charge-to-fire tracking state was cleared")
                return
    if not saw_charge or not saw_flash or not saw_hold or (
            tracked_beam_frames < 100):
        _fail("one uninterrupted 10s cycle skipped charge/flash/hold/beam")
        return

    # With a wide last-moment target change the gun must NOT snap to
    # SERA on either the 9.5s hold boundary or the 10.0s beam boundary.
    gun.call("reset")
    gun.set("elapsed", GUN.PERIOD_SECONDS - 0.010)
    var wide_target: Vector3 = pivot_world + (
        reference_right * boost_radius) - Vector3.UP * 0.92
    gun.call("advance", 0.005, wide_target, true)
    var yaw_before_launch: float = float(gun.get("tracked_world_yaw"))
    gun.call("advance", 0.010, wide_target, true)
    var yaw_after_launch: float = float(gun.get("tracked_world_yaw"))
    if not core.visible or absf(rad_to_deg(angle_difference(
            yaw_before_launch, yaw_after_launch))) > (
            GUN.TRACK_YAW_SPEED * 0.010 + 0.08):
        _fail("beam launch must keep aim without a perfect-lock snap")
        return

    # The same WORLD angular cap also applies when Bittaran rotates.
    gun.call("reset")
    gun.set("elapsed", GUN.FLASH_START)
    gun.call("advance", DT, wide_target, true)
    var world_before_body_turn: float = float(gun.get("tracked_world_yaw"))
    var rig_old_yaw: float = rig.rotation.y
    rig.rotation.y += deg_to_rad(70.0)
    gun.call("advance", DT, wide_target, true)
    var world_after_body_turn: float = float(gun.get("tracked_world_yaw"))
    rig.rotation.y = rig_old_yaw
    if absf(rad_to_deg(angle_difference(world_before_body_turn,
            world_after_body_turn))) > (GUN.TRACK_YAW_SPEED * DT + 0.08):
        _fail("boss body rotation bypassed the slow world-space aim cap")
        return

    # At long distances the fixed 15.12deg/s cap is too fast against
    # a BOOST's small apparent angular rate. Distance-adaptive tracking
    # must stay at <=35% of actual BOOST angular speed.
    gun.call("reset")
    var far_target: Vector3 = gun.global_position + (
        -gun.global_basis.z.normalized() * 30.0) - Vector3.UP * 0.92
    var far_rate: float = float(gun.call(
        "_boost_safe_turn_rate", far_target, boost_speed))
    if far_rate > rad_to_deg(boost_speed / 30.0) * 0.36 or (
            far_rate >= GUN.TRACK_YAW_SPEED):
        _fail("long-range aim is too fast for a real BOOST dodge")
        return
    # The laser is visible immediately but cannot damage in the first
    # 0.65s, giving time for actual BOOST input confirmation/acceleration.
    if not _near(GUN.BEAM_DAMAGE_ARM_SECONDS, 0.65):
        _fail("laser must allow 0.65s for a real input-triggered BOOST")
        return
    gun.call("reset")
    var neutral_forward: Vector3 = -gun.global_basis.z.normalized()
    var neutral_right: Vector3 = gun.global_basis.x.normalized()
    var muzzle_world: Vector3 = elevation.to_global(
        Vector3(0.0, 0.0, GUN.MUZZLE_LOCAL_Z))
    var center_target: Vector3 = muzzle_world + (
        neutral_forward * 8.0) - Vector3.UP * 0.92
    gun.set("elapsed", GUN.PERIOD_SECONDS - DT * 0.5)
    var hit_on_launch: bool = bool(gun.call(
        "advance", DT, center_target, true))
    if hit_on_launch or not core.visible or (
            not bool(gun.call("_beam_overlaps_player", center_target))):
        _fail("visible launch must start without immediate damage")
        return
    var premature_hit: bool = bool(gun.call(
        "advance", GUN.BEAM_DAMAGE_ARM_SECONDS - 0.04,
        center_target, true))
    if premature_hit or not core.visible:
        _fail("laser cannot damage during startup grace")
        return
    var stationary_hit: bool = bool(gun.call(
        "advance", 0.055, center_target, true))
    if not stationary_hit or not core.visible:
        _fail("armed beam must still damage stationary SERA and stay visible")
        return
    gun.call("advance", 0.12, center_target, true)
    if not core.visible:
        _fail("an actual damage pulse stopped the laser before 2s")
        return

    # Test real base RUN->BOOST input/acceleration (0.10s confirm,
    # 0.20s smoothstep ramp). At both 8m and 30m, starting lateral
    # movement at the actual BEAM first frame must avoid EVERY damage
    # pulse until the 2-second beam finishes, not only the first sample.
    for radius in [8.0, 30.0]:
        gun.call("reset")
        var origin: Vector3 = (
            elevation.to_global(Vector3(0.0, 0.0, GUN.MUZZLE_LOCAL_Z))
            + -gun.global_basis.z.normalized() * float(radius)
            - Vector3.UP * 0.92)
        var right: Vector3 = gun.global_basis.x.normalized()
        gun.set("elapsed", GUN.PERIOD_SECONDS - DT * 0.5)
        if bool(gun.call("advance", DT, origin, true)):
            _fail("startup beam caused immediate unavoidable hit")
            return
        var displacement: float = 0.0
        for frame in range(230):
            var time: float = float(frame + 1) * DT
            var ramp: float = clampf(
                (time - 0.10) / 0.20, 0.0, 1.0)
            var eased: float = ramp * ramp * (3.0 - 2.0 * ramp)
            var speed: float = lerpf(
                4.0625, boost_speed, eased)
            displacement += speed * DT
            var boosted_player: Vector3 = origin + right * displacement
            if bool(gun.call("advance", DT, boosted_player, true)):
                _fail("actual RUN->BOOST could not escape at radius="
                    + str(radius) + " time=" + str(time))
                return

    # Laser hits retain HP/shield effects without initiating the inherited
    # DAMAGEKNOCK state that previously canceled ongoing BOOST/STEP.
    scene.set("player_hp", 800.0)
    scene.set("movement_boost_active", true)
    scene.set("damage_reaction_active", false)
    var hp_before: float = float(scene.get("player_hp"))
    scene.call("_on_enemy_projectile_hit",
        player.global_position, Vector3.FORWARD, true, 0, true)
    if float(scene.get("player_hp")) >= hp_before or (
            bool(scene.get("damage_reaction_active"))) or (
            not bool(scene.get("movement_boost_active"))):
        _fail("a laser hit must damage HP without stopping active BOOST")
        return

    # SERA KO must not turn the whole visible BEAM off: its natural
    # remaining exposure time belongs to the boss's attack cycle.
    gun.call("reset")
    gun.set("elapsed", 0.80)
    scene.set("player_hp", 0.0)
    scene.set("training_ko_remaining", 1.0)
    scene.call("_tick_bittaran_railgun", DT)
    if not core.visible or not halo.visible:
        _fail("player KO interrupted a laser that was still firing")
        return

    gun.call("reset")
    if core.visible or halo.visible or flash.visible or rim.visible or (
            orb_arcs.visible) or plasma.visible or beam_arcs.visible:
        _fail("boss respawn left old beam or electric FX visible")
        return
    print("GODOT_BITTARAN_RAILGUN_PASS 10s_interval=true 2s_beam=true ",
        "2s_blue_sphere=true 1s_orb_shrink=true 2s_charge_ease=true ",
        "0.5s_targeting_hold=true 0.4s_postfire_hold=true ",
        "no_aim_snap_on_launch=true charge_to_beam_world_tracking=true ",
        "moving_boss_cannot_bypass_turn_cap=true ",
        "blue_fresnel_flicker=true branching_electric_arcs=true ",
        "travelling_plasma_beam=true 35pct_real_boost_angular_cap=true ",
        "0.65s_arming_grace=true 8m_and_30m_boost_evasion=true ",
        "laser_hit_does_not_interrupt_boost=true beam_survives_player_KO=true ",
        "smooth_independent_yaw_pitch=true 3_charge_bars_per_side=true")
    quit(0)
