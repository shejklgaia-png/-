extends SceneTree
## v499: four belly-mounted bases, ONE nearest tracker, same shared fire
## interval, and both weapon systems stop during attacks and knockdown.
const TURRETS = preload("res://scripts/bittaran_leg_turrets.gd")
const RAILGUN = preload("res://scripts/bittaran_railgun.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_LEG_TURRETS_FAIL: " + message)
    quit(1)

func _run() -> void:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var gun: Node3D = scene.get("bittaran_railgun")
    var turrets: Node3D = scene.get("bittaran_leg_turrets")
    var player: CharacterBody3D = scene.get("player")
    if rig == null or gun == null or turrets == null or player == null:
        _fail("live scene must build the four leg turrets and railgun")
        return
    if turrets.get_script() != TURRETS or gun.get_script() != RAILGUN:
        _fail("unexpected weapon controller")
        return
    # New location: underside of the BODY, NOT any lower or upper leg.
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    var body_mesh: MeshInstance3D = null
    if body != null:
        body_mesh = body.get_node_or_null("body_mesh") as MeshInstance3D
    var mounts: Dictionary = turrets.get("mounts")
    var anchors: Dictionary = turrets.get("anchors")
    var mount_offsets: Dictionary = turrets.get("mount_offsets")
    var belly_bounds: AABB = turrets.get("belly_bounds")
    var aim_pivots: Dictionary = turrets.get("aim_pivots")
    if body == null or body_mesh == null or mounts.size() != 4 or (
            anchors.size() != 4 or mount_offsets.size() != 4
            or aim_pivots.size() != 4 or not belly_bounds.has_volume()
            or absf(TURRETS.SHOT_INTERVAL_SECONDS - 1.2) > 0.001):
        _fail("four complete belly-mounted cannons and 1.2s cadence required")
        return
    var original_body: Transform3D = body.transform
    for id in TURRETS.TURRET_IDS:
        var mount: Node3D = mounts.get(id) as Node3D
        if mount == null or not mount.name.begins_with("BellyCannon_") or (
                mount.get_parent() != turrets or anchors[id] != body):
            _fail("remove ALL old leg-mounted cannons and anchor only to Body: " + id)
            return
        var offset: Vector3 = mount_offsets[id]
        var side: float = -1.0 if id.ends_with("l") else 1.0
        var front: float = -1.0 if id.begins_with("belly_f") else 1.0
        var center: Vector3 = belly_bounds.get_center()
        var bottom: float = belly_bounds.position.y
        # This is the flat base, which is INSIDE the original belly
        # surface at <= 2.5 cm, facing DOWN. No guns on leg outer faces.
        if not belly_bounds.has_point(offset) or (
                offset.y - bottom < -0.001 or
                offset.y - bottom > 0.0251 or
                (offset.x - center.x) * side < belly_bounds.size.x * 0.18 or
                (offset.z - center.z) * front < belly_bounds.size.z * 0.15):
            _fail("base must connect to the belly underside in a 2x2 layout: " + id)
            return
        var dome: MeshInstance3D = mount.get_node_or_null(
            "TurretHemisphere") as MeshInstance3D
        var barrel: MeshInstance3D = mount.get_node_or_null(
            "TurretAim/TurretBarrel") as MeshInstance3D
        if dome == null or barrel == null or not (
                dome.mesh is SphereMesh) or not (
                dome.mesh as SphereMesh).is_hemisphere or (
                not barrel.mesh is CylinderMesh):
            _fail("keep a dome and barrel on each belly cannon: " + id)
            return
        var hemi: SphereMesh = dome.mesh as SphereMesh
        if absf(hemi.height - hemi.radius) > 0.001 or (
                absf(dome.position.y + hemi.get_aabb().position.y) > 0.001):
            _fail("hemisphere flat base must touch belly attachment plane: " + id)
            return
        # All four circles must fit beneath the torso, not at the flank.
        if absf(offset.x - center.x) + hemi.radius > (
                belly_bounds.size.x * 0.5 + 0.012) or (
                absf(offset.z - center.z) + hemi.radius >
                    belly_bounds.size.z * 0.5 + 0.012):
            _fail("belly cannon projects past the outer torso footprint: " + id)
            return
        if mount.global_basis.y.normalized().dot(
                -body.global_basis.y.normalized()) < 0.995:
            _fail("flat base normal must point DOWN from torso: " + id)
            return
        if mount.global_position.distance_to(body.to_global(offset)) > 0.001:
            _fail("belly cannon does not track exact body-local point: " + id)
            return
        var pivot: Node3D = aim_pivots[id]
        if pivot == null or pivot.get_parent() != mount or (
                barrel.get_parent() != pivot):
            _fail("only barrel may swivel, belly dome must stay attached: " + id)
            return
    # Attacks and knockdown cancel firing/aiming but NOT attachment.
    body.position += Vector3(0.13, 0.08, -0.12)
    body.rotate_x(0.07)
    turrets.call("advance", 0.0, player.global_position, false)
    for id in TURRETS.TURRET_IDS:
        var mount: Node3D = mounts[id]
        if mount.global_position.distance_to(
                body.to_global(mount_offsets[id])) > 0.001 or (
                mount.global_basis.y.normalized().dot(
                    -body.global_basis.y.normalized()) < 0.995):
            _fail("belly turret must follow torso translation and pitch when down: " + id)
            return
    body.transform = original_body
    turrets.call("advance", 0.0, player.global_position, false)
    # Only whichever turret is currently nearest can continuously aim.
    # On nearest change the old turret must return to its fixed resting
    # orientation and the hemisphere's seated transform must not rotate.
    for chosen in ["belly_fl", "belly_rr"]:
        var probe: Vector3 = (mounts[chosen] as Node3D).global_position
        turrets.call("advance", 0.0, probe, true)
        if str(turrets.get("last_aimed_turret")) != chosen:
            _fail("only the dynamically closest cannon may track: " + chosen)
            return
        var active_pivot: Node3D = aim_pivots[chosen]
        var target: Vector3 = probe + Vector3.UP * 0.90
        var delta_to_target: Vector3 = target - active_pivot.global_position
        if delta_to_target.length_squared() > 0.0001 and (
                (-active_pivot.global_basis.z).normalized().dot(
                    delta_to_target.normalized()) < 0.99):
            _fail("nearest barrel is not aimed at the player: " + chosen)
            return
        for other in TURRETS.TURRET_IDS:
            if other == chosen:
                continue
            var idle_pivot: Node3D = aim_pivots[other]
            if not idle_pivot.basis.is_equal_approx(Basis.IDENTITY):
                _fail("non-nearest cannon must not aim at the player: " + other)
                return
    var down_probe: Vector3 = (mounts["belly_rr"] as Node3D).global_position
    turrets.call("advance", 0.0, down_probe + Vector3(3.0, 0.0, 0.0), false)
    if str(turrets.get("last_aimed_turret")) != "":
        _fail("knockdown must disable all active target tracking")
        return
    for other in TURRETS.TURRET_IDS:
        if not (aim_pivots[other] as Node3D).basis.is_equal_approx(Basis.IDENTITY):
            _fail("downed cannon must be parked without tracking: " + other)
            return
    var ordered: Array[String] = TURRETS.TURRET_IDS.duplicate()
    for i in range(ordered.size()):
        for j in range(i + 1, ordered.size()):
            var a: Node3D = mounts[ordered[i]]
            var b: Node3D = mounts[ordered[j]]
            if b.global_position.distance_squared_to(player.global_position) < (
                    a.global_position.distance_squared_to(player.global_position)):
                var temp: String = ordered[i]
                ordered[i] = ordered[j]
                ordered[j] = temp
    turrets.call("reset")
    turrets.call("advance", DT, player.global_position, true)
    if int(turrets.get("shots_fired")) != 1 or str(
            turrets.get("last_fired_turret")) != ordered[0]:
        _fail("first projectile must leave the nearest belly turret")
        return
    var first_shot: Dictionary = (turrets.get("projectiles") as Array)[0]
    var fired_aim: Node3D = aim_pivots[ordered[0]]
    var shot_direction: Vector3 = first_shot["direction"]
    if shot_direction.normalized().dot(
            (-fired_aim.global_basis.z).normalized()) < 0.999:
        _fail("each projectile must leave ALONG the visible gun barrel")
        return
    turrets.call("advance", 1.0, player.global_position, true)
    if int(turrets.get("shots_fired")) != 1:
        _fail("shared cadence fired too early")
        return
    turrets.call("advance", 0.25, player.global_position, true)
    if int(turrets.get("shots_fired")) != 2 or str(
            turrets.get("last_fired_turret")) != ordered[1]:
        _fail("second shot must come from next-nearest belly turret")
        return
    for index in range(2, 5):
        turrets.call("advance", TURRETS.SHOT_INTERVAL_SECONDS,
            player.global_position, true)
        if int(turrets.get("shots_fired")) != index + 1 or str(
                turrets.get("last_fired_turret")) != ordered[index % 4]:
            _fail("all four belly turrets must fire once in nearest-first order, then restart")
            return
    scene.set("bittaran_attack_frame", {"kind": "stomp", "phase": "strike"})
    scene.call("_tick_bittaran_leg_turrets", DT)
    if not (turrets.get("projectiles") as Array).is_empty():
        _fail("attack animation must cancel all shots")
        return
    scene.set("bittaran_attack_frame", {})
    var ik: RefCounted = scene.get("bittaran_foot_ik")
    ik.set("windup_elapsed", 0.0)
    gun.call("reset")
    gun.set("elapsed", RAILGUN.BEAM_START + 0.1)
    scene.call("_tick_bittaran_leg_turrets", DT)
    scene.call("_tick_bittaran_railgun", DT)
    if not (turrets.get("projectiles") as Array).is_empty() or (
            int(turrets.get("shots_fired")) != 0):
        _fail("knockdown anticipation must cancel belly turret fire")
        return
    if float(gun.get("elapsed")) != 0.0 or (
            gun.get("inner_beam") as MeshInstance3D).visible or (
            gun.get("muzzle_flash") as MeshInstance3D).visible:
        _fail("laser and charge visuals must stop on knockdown")
        return
    ik.set("windup_elapsed", -1.0)
    ik.set("break_elapsed", 1.0)
    scene.call("_tick_bittaran_leg_turrets", DT)
    scene.call("_tick_bittaran_railgun", DT)
    if int(turrets.get("shots_fired")) != 0 or (
            float(gun.get("elapsed")) != 0.0):
        _fail("both weapon systems must remain off during fallen pose")
        return
    quit(0)
