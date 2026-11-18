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
    var elevation: Node3D = gun.get_node("RailgunElevation")
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
    # Force an off-axis target to ensure the independent barrel actually aims.
    var side_target: Vector3 = forward_target + Vector3(4.0, 0.0, 0.0)
    gun.call("reset")
    for i in range(120):
        gun.call("advance", DT, side_target, true)
    if absf(gun.rotation.y) < deg_to_rad(5.0):
        _fail("barrel did not turn toward a lateral player")
        return
    if body.quaternion.angle_to(body_before) > 0.00001:
        _fail("aiming modified authored Body rotation")
        return
    # Time boundaries are measured relative to a FIRE at t=0,10,20...
    # Prepare the last flash quarter-second without waiting through 7s.
    gun.call("reset")
    gun.set("elapsed", 9.63)
    gun.call("advance", 0.01, player_origin, true)
    var flash: MeshInstance3D = gun.get("muzzle_flash")
    var core: MeshInstance3D = gun.get("inner_beam")
    var halo: MeshInstance3D = gun.get("outer_beam")
    if not flash.visible or core.visible or halo.visible:
        _fail("blue-white flash must precede the laser")
        return
    var first_scale: float = flash.scale.x
    gun.call("advance", 0.13, player_origin, true)
    if flash.scale.x >= first_scale:
        _fail("muzzle flash did not shrink smoothly")
        return
    gun.call("advance", 0.04, player_origin, true)
    if flash.visible or core.visible:
        _fail("the flash must be gone before a 0.2-second dark gap")
        return
    gun.call("advance", 0.19, player_origin, true)
    if core.visible:
        _fail("beam fired early during the post-flash gap")
        return
    # Exactly ten seconds modulo period begins the real two-second beam.
    gun.call("advance", 0.02, player_origin, true)
    if not core.visible or not halo.visible:
        _fail("laser failed to start on ten-second boundary")
        return
    if (core.material_override as BaseMaterial3D).no_depth_test:
        _fail("beam illegally renders through opaque armor")
        return
    gun.call("advance", 1.91, player_origin, true)
    if core.visible:
        _fail("beam exceeded the two-second duration")
        return
    var aim_at_end: float = gun.rotation.y
    gun.call("advance", 0.25, player_origin, true)
    if absf(angle_difference(aim_at_end, gun.rotation.y)) > 0.0001:
        _fail("postfire hold changed the target angle before 0.4s")
        return
    gun.call("advance", 0.78, player_origin, true)
    if absf(gun.rotation.y) > deg_to_rad(1.0) or (
            absf(elevation.rotation.x) > deg_to_rad(1.0)):
        _fail("barrel did not ease back to its neutral angle")
        return
    # New charge starts tracking once more and advances all three lamps.
    gun.call("advance", 3.2, side_target, true)
    if absf(gun.rotation.y) < deg_to_rad(3.0):
        _fail("new charge did not restart smooth target tracking")
        return
    if (bars[0] as StandardMaterial3D).emission_energy_multiplier <= 0.22:
        _fail("charge progression did not light its first segment")
        return
    gun.call("reset")
    if core.visible or halo.visible or flash.visible:
        _fail("boss respawn left the old beam visible")
        return
    print("GODOT_BITTARAN_RAILGUN_PASS 10s_interval=true 2s_beam=true ",
        "0.2s_prefire_gap=true 0.4s_postfire_hold=true ",
        "smooth_independent_yaw_pitch=true 3_charge_bars_per_side=true")
    quit(0)
