extends SceneTree
## v496: independent four-leg cannons fire nearest-first at a shared
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
    if mounts.size() != 4 or absf(TURRETS.SHOT_INTERVAL_SECONDS - 1.2) > 0.001:
        _fail("four independent mounts and shared 1.2s cadence required")
        return
    for id in TURRETS.LEG_IDS:
        var mount: Node3D = mounts.get(id) as Node3D
        if mount == null or mount.get_parent() != rig.find_child(
                str(TURRETS.LEG_BONES[id]), true, false):
            _fail("turret must be bound to its own animated upper leg: " + id)
            return
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
