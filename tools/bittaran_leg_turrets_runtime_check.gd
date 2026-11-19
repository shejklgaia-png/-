extends SceneTree
## v497: lower-leg-mounted cannons fire nearest-first at a shared
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
    var mounts: Dictionary = turrets.get("mounts")
    var anchors: Dictionary = turrets.get("anchors")
    var mount_offsets: Dictionary = turrets.get("mount_offsets")
    var lower_bounds: Dictionary = turrets.get("lower_bounds")
    if mounts.size() != 4 or anchors.size() != 4 or (
            mount_offsets.size() != 4 or lower_bounds.size() != 4 or
            absf(TURRETS.SHOT_INTERVAL_SECONDS - 1.2) > 0.001):
        _fail("four independent mounts and shared 1.2s cadence required")
        return
    for id in TURRETS.LEG_IDS:
        var mount: Node3D = mounts.get(id) as Node3D
        if mount == null or mount.get_parent() != turrets or (
                anchors[id] != rig.find_child(
                    str(TURRETS.LOWER_LEG_BONES[id]), true, false)):
            _fail("turret must track the animated LOWER leg, outside the IK mesh hierarchy: " + id)
            return
        var bound: AABB = lower_bounds[id]
        var offset: Vector3 = mount_offsets[id]
        var side_x: float = -1.0 if id.ends_with("l") else 1.0
        var face_z: float = -1.0 if id.begins_with("leg_f") else 1.0
        var center: Vector3 = bound.get_center()
        # The dome center must sit INSIDE the real authored shin armor,
        # toward its outward X/Z quadrant and upper face, not hover at
        # an arbitrary upper-leg pivot or outside the moving mesh.
        if not bound.has_point(offset) or (
                (offset.x - center.x) * side_x < bound.size.x * 0.10
                or offset.y - center.y < bound.size.y * 0.12
                or (offset.z - center.z) * face_z < bound.size.z * 0.10):
            _fail("dome must be seated against the outer lower-leg armor: " + id)
            return
        if mount.global_position.distance_to((
                anchors[id] as Node3D).to_global(offset)) > 0.001:
            _fail("lower-leg dome not at its actual animated armor position: " + id)
            return
        # Even when shot emission is disabled by an attack or knockdown,
        # the cosmetic mount must continue to follow the shin animation.
        var shin: Node3D = anchors[id]
        var old_position: Vector3 = shin.position
        shin.position += Vector3(0.04, 0.11, 0.03)
        turrets.call("advance", 0.0, player.global_position, false)
        if mount.global_position.distance_to(shin.to_global(offset)) > 0.001:
            _fail("inactive gun visually floats when its lower leg moves: " + id)
            return
        shin.position = old_position
        turrets.call("advance", 0.0, player.global_position, false)
        var dome: MeshInstance3D = mount.get_node_or_null(
            "TurretHemisphere") as MeshInstance3D
        var barrel: MeshInstance3D = mount.get_node_or_null(
            "TurretBarrel") as MeshInstance3D
        if dome == null or barrel == null or not (
                dome.mesh is SphereMesh) or not (
                dome.mesh as SphereMesh).is_hemisphere or (
                not barrel.mesh is CylinderMesh):
            _fail("each turret must render a hemisphere and tube: " + id)
            return
    var ordered: Array[String] = TURRETS.LEG_IDS.duplicate()
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
            turrets.get("last_fired_leg")) != ordered[0]:
        _fail("first projectile must leave the nearest leg")
        return
    turrets.call("advance", 1.0, player.global_position, true)
    if int(turrets.get("shots_fired")) != 1:
        _fail("shared cadence fired too early")
        return
    turrets.call("advance", 0.25, player.global_position, true)
    if int(turrets.get("shots_fired")) != 2 or str(
            turrets.get("last_fired_leg")) != ordered[1]:
        _fail("second shot must come from next-nearest leg")
        return
    for index in range(2, 5):
        turrets.call("advance", TURRETS.SHOT_INTERVAL_SECONDS,
            player.global_position, true)
        if int(turrets.get("shots_fired")) != index + 1 or str(
                turrets.get("last_fired_leg")) != ordered[index % 4]:
            _fail("all four legs must fire once in nearest-first order, then restart")
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
        _fail("knockdown anticipation must cancel leg fire")
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
