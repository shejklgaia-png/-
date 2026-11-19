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
    var body_before: Quaternion = body.quaternion
    # A PLAYER in the gun's forward cone should be hit, while legs and
    # Body must remain at their original local animation pose.
    var forward_target: Vector3 = elevation.to_global(Vector3(0.0, 0.0, -9.0))
    var player_origin: Vector3 = forward_target - Vector3.UP * 0.92
    # A changing lateral player may NEVER move the gun until all three
    # charge lamps are full. Keep the rig-relative neutral yaw AND pitch.
    var side_target: Vector3 = forward_target + Vector3(4.0, 0.0, 0.0)
    gun.call("reset")
    for i in range(120):
        var player_target: Vector3 = (
            side_target if i % 2 == 0 else side_target + Vector3(0, 4, 0))
        gun.call("advance", DT, player_target, true)
    if absf(float(gun.get("aim_yaw"))) > 0.00001 or (
            absf(elevation.rotation.x) > 0.00001):
        _fail("unfinished charge moved gun away from its neutral angle")
        return
    if body.quaternion.angle_to(body_before) > 0.00001:
        _fail("charging modified authored Body rotation")
        return
    # A full 3/3 charge begins acquisition during the flash. Only the
    # completed charge is allowed to break neutral.
    gun.set("elapsed", GUN.TRACK_START_SECONDS)
    for i in range(48):
        gun.call("advance", DT, side_target, true)
    if absf(float(gun.get("aim_yaw"))) < deg_to_rad(2.0):
        _fail("fully charged railgun did not acquire the lateral target")
        return
    # The sphere MUST be visible continuously during the complete 2s
    # prefire window. Pursuit accelerates smoothly over those SAME 2s.
    if not _near(GUN.FLASH_SECONDS, 2.0) or not _near(
            GUN.FLASH_SHRINK_SECONDS, 1.0) or not _near(
            GUN.TRACK_EASE_IN_SECONDS, 2.0) or not _near(
            GUN.FINAL_LOCK_HOLD_SECONDS, 0.5) or not _near(
            GUN.TRACK_START_SECONDS, 7.5) or not _near(
            GUN.FLASH_END, 9.5):
        _fail("2s sphere + 2s ease-in + 0.5s acquired hold must fit 10s")
        return
    if absf(float(gun.call("_prefire_ease", 7.5))) > 0.00001 or (
            not _near(float(gun.call("_prefire_ease", 8.5)), 0.5)) or (
            not _near(float(gun.call("_prefire_ease", 9.5)), 1.0)):
        _fail("2s tracking ease-in is not smoothstep 0 -> .5 -> 1")
        return
    gun.call("reset")
    gun.set("elapsed", GUN.TRACK_START_SECONDS - 0.02)
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
    var acquired: Vector2 = gun.call("_desired_player_angles", side_target)
    if absf(angle_difference(float(gun.get("aim_yaw")), acquired.x)) > (
            0.00001) or absf(elevation.rotation.x - acquired.y) > 0.00001:
        _fail("turret must already be fully locked when 0.5s delay starts")
        return
    if (bars[2] as StandardMaterial3D).emission_energy_multiplier < 4.0:
        _fail("third charge bar must remain lit during full-lock delay")
        return
    # The gun must KEEP TRACKING during the pause, including a target move.
    var delayed_target: Vector3 = side_target + Vector3(3.0, 0.0, 1.0)
    gun.call("advance", 0.45, delayed_target, true)
    var maintained: Vector2 = gun.call("_desired_player_angles", delayed_target)
    if core.visible or flash.visible or absf(rad_to_deg(
            angle_difference(float(gun.get("aim_yaw")), maintained.x))) > 1.0:
        _fail("full-lock pause must keep pace with moving player, no laser")
        return
    # Exactly ten seconds modulo period begins the real two-second beam.
    gun.call("advance", 0.055, delayed_target, true)
    if not core.visible or not halo.visible:
        _fail("laser started before/after 0.5s fully acquired delay")
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
    # Sample near the END of the existing 0.8s return: the new test
    # entered the beam with a significant off-axis aim, unlike v466.
    gun.call("advance", 0.93, player_origin, true)
    if absf(float(gun.get("aim_yaw"))) > deg_to_rad(1.0) or (
            absf(elevation.rotation.x) > deg_to_rad(1.0)):
        _fail("barrel did not ease back to its neutral angle")
        return
    # Charging light progresses while BOTH axes stay parked at rest.
    gun.call("advance", 3.2, side_target, true)
    if absf(float(gun.get("aim_yaw"))) > 0.00001 or (
            absf(elevation.rotation.x) > 0.00001):
        _fail("railgun turned before full charge in next firing cycle")
        return
    if (bars[0] as StandardMaterial3D).emission_energy_multiplier <= 0.22:
        _fail("charge progression did not light its first segment")
        return
    # A boosted SERA may turn ~43.6deg/s around the gun at 8m. The gun
    # must CATCH that motion before firing, then fall behind only AFTER
    # the laser begins. Test both transitions in a single live 10s cycle.
    var boost_speed: float = 6.09375
    var boost_radius: float = 8.0
    var reference_forward: Vector3 = -gun.global_basis.z.normalized()
    var reference_right: Vector3 = gun.global_basis.x.normalized()
    var pivot_world: Vector3 = gun.global_position
    gun.call("reset")
    # 240 prefire + 60 locked-pause frames, then 120 beam frames.
    gun.set("elapsed", GUN.TRACK_START_SECONDS + 0.0001)
    var aim_at_fire: float = 0.0
    var target_at_fire: float = 0.0
    var first_prefire_delta: float = 0.0
    var last_target: Vector3 = Vector3.ZERO
    # 2s eased pursuit + 0.5s full-lock delay + 1s dodgeable beam.
    for i in range(420):
        var t: float = float(i + 1) * DT
        var travel_angle: float = boost_speed / boost_radius * t
        var boost_target: Vector3 = pivot_world + (
            reference_forward * cos(travel_angle)
            + reference_right * sin(travel_angle)) * boost_radius
        last_target = boost_target - Vector3.UP * 0.92
        var before_step: float = float(gun.get("aim_yaw"))
        gun.call("advance", DT, last_target, true)
        if i == 0:
            first_prefire_delta = absf(rad_to_deg(angle_difference(
                before_step, float(gun.get("aim_yaw")))))
        if i == 299:
            aim_at_fire = float(gun.get("aim_yaw"))
            var target_direction: Vector2 = gun.call(
                "_desired_player_angles", last_target)
            target_at_fire = target_direction.x
            if not core.visible or absf(
                    rad_to_deg(angle_difference(aim_at_fire, target_at_fire))) > 0.01:
                _fail("first beam frame did not lock fully onto boosting SERA")
                return
    if first_prefire_delta > GUN.PRE_FIRE_YAW_SPEED * DT + 0.02:
        _fail("fast prefire pursuit violated its smooth turn speed bound")
        return
    var aim_after_beam_second: float = float(gun.get("aim_yaw"))
    var beam_turned: float = absf(rad_to_deg(
        angle_difference(aim_at_fire, aim_after_beam_second)))
    var boost_turned: float = rad_to_deg(boost_speed / boost_radius)
    if beam_turned > GUN.TRACK_YAW_SPEED + 0.15 or (
            beam_turned < 1.0) or (boost_turned - beam_turned < 14.0):
        _fail("beam chase must be slower than BOOST: beam="
            + str(beam_turned) + "deg boost=" + str(boost_turned) + "deg")
        return
    # The final fire-frame lock must work for a large off-axis aim too,
    # not only the nearly neutral motion path checked above.
    gun.call("reset")
    gun.set("elapsed", GUN.TRACK_START_SECONDS + 0.0001)
    var large_angle_target: Vector3 = pivot_world + (
        reference_forward * cos(deg_to_rad(115.0))
        + reference_right * sin(deg_to_rad(115.0))) * boost_radius
    for i in range(299):
        gun.call("advance", DT, large_angle_target - Vector3.UP * 0.92, true)
    var before_fire_angles: Vector2 = gun.call(
        "_desired_player_angles", large_angle_target - Vector3.UP * 0.92)
    if absf(rad_to_deg(angle_difference(
            float(gun.get("aim_yaw")), before_fire_angles.x))) > 2.0:
        _fail("spherical prefire acquisition cannot reach a distant heading")
        return
    # Change player heading at the actual firing instant. The first
    # laser frame must correct any remaining partial-frame target error.
    var last_motion_target: Vector3 = large_angle_target + Vector3(0, 1.0, -0.3)
    gun.call("advance", DT, last_motion_target - Vector3.UP * 0.92, true)
    var fire_angles: Vector2 = gun.call(
        "_desired_player_angles", last_motion_target - Vector3.UP * 0.92)
    if absf(angle_difference(float(gun.get("aim_yaw")), fire_angles.x)) > (
            0.00001) or absf(elevation.rotation.x - fire_angles.y) > 0.00001:
        _fail("turret must exactly track moving player when laser fires")
        return
    if not core.visible:
        _fail("laser must fire after exact prefire target lock")
        return
    # During the beam, BOTH yaw and pitch are independently restricted.
    var before_slow_pitch: float = elevation.rotation.x
    gun.call("advance", 0.1,
        pivot_world + Vector3(0.0, 10.0, 8.0), true)
    if absf(rad_to_deg(elevation.rotation.x - before_slow_pitch)) > (
            GUN.TRACK_PITCH_SPEED * 0.1 + 0.05):
        _fail("barrel pitch exceeded its 18deg/s BEAM rate cap")
        return
    gun.call("reset")
    if core.visible or halo.visible or flash.visible:
        _fail("boss respawn left the old beam visible")
        return
    print("GODOT_BITTARAN_RAILGUN_PASS 10s_interval=true 2s_beam=true ",
        "2s_blue_sphere=true 1s_orb_shrink=true 2s_ease_in=true ",
        "0.5s_locked_prefire_delay=true 0.4s_postfire_hold=true ",
        "prefire_fast_lock=true first_frame_exact_aim=true ",
        "boost_outpaces_beam=true neutral_until_fully_charged=true ",
        "smooth_independent_yaw_pitch=true 3_charge_bars_per_side=true")
    quit(0)
