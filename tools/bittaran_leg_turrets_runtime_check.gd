extends SceneTree
## v500: one ornate belly cannon, a visible muzzle-cross pulse on each shot,
## preserved attack/downtime gates, and an intact independent railgun.
const TURRETS = preload("res://scripts/bittaran_leg_turrets.gd")
const RAILGUN = preload("res://scripts/bittaran_railgun.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_BELLY_CANNON_FAIL: " + message)
    quit(1)

func _run() -> void:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var gun: Node3D = scene.get("bittaran_railgun")
    var turret: Node3D = scene.get("bittaran_leg_turrets")
    var player: CharacterBody3D = scene.get("player")
    if rig == null or gun == null or turret == null or player == null:
        _fail("live scene must contain the original boss, railgun and ONE belly cannon")
        return
    if turret.get_script() != TURRETS or gun.get_script() != RAILGUN:
        _fail("unexpected boss weapon controller")
        return
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    var shell: MeshInstance3D = null
    if body != null:
        shell = body.get_node_or_null("body_mesh") as MeshInstance3D
    var mounts: Dictionary = turret.get("mounts")
    var anchors: Dictionary = turret.get("anchors")
    var offsets: Dictionary = turret.get("mount_offsets")
    var pivots: Dictionary = turret.get("aim_pivots")
    var belly: AABB = turret.get("belly_bounds")
    if body == null or shell == null or (
            TURRETS.TURRET_IDS.size() != 1 or
            str(TURRETS.TURRET_IDS[0]) != "belly_main" or
            mounts.size() != 1 or anchors.size() != 1 or
            offsets.size() != 1 or pivots.size() != 1 or
            not belly.has_volume() or
            absf(TURRETS.SHOT_INTERVAL_SECONDS - 1.2) > 0.001):
        _fail("exactly ONE central belly cannon and unchanged 1.2s cadence required")
        return
    var id: String = TURRETS.TURRET_IDS[0]
    var mount: Node3D = mounts[id]
    var aim_pivot: Node3D = pivots[id]
    var offset: Vector3 = offsets[id]
    var center: Vector3 = belly.get_center()
    if anchors[id] != body or mount.get_parent() != turret or (
            mount.name != "BellyCannon_belly_main" or
            absf(offset.x - center.x) > 0.025 or
            absf(offset.z - center.z) > belly.size.z * 0.12 or
            offset.y < belly.position.y or
            offset.y - belly.position.y > 0.026):
        _fail("central turret must attach at the underside BODY, never any leg")
        return
    var dome: MeshInstance3D = mount.get_node_or_null(
        "TurretHemisphere") as MeshInstance3D
    var barrel: MeshInstance3D = mount.get_node_or_null(
        "TurretAim/TurretBarrel") as MeshInstance3D
    var collar: MeshInstance3D = mount.get_node_or_null(
        "TurretBaseCollar") as MeshInstance3D
    var sleeve: MeshInstance3D = mount.get_node_or_null(
        "TurretAim/BarrelSleeve") as MeshInstance3D
    var muzzle: MeshInstance3D = mount.get_node_or_null(
        "TurretAim/TurretMuzzle") as MeshInstance3D
    if dome == null or barrel == null or collar == null or (
            sleeve == null or muzzle == null or
            not dome.mesh is SphereMesh or
            not (dome.mesh as SphereMesh).is_hemisphere or
            not barrel.mesh is CylinderMesh or
            not collar.mesh is CylinderMesh or
            not sleeve.mesh is CylinderMesh):
        _fail("one ornate gun needs hemisphere, base collar, barrel and barrel sleeve")
        return
    var hemi: SphereMesh = dome.mesh as SphereMesh
    var barrel_mesh: CylinderMesh = barrel.mesh as CylinderMesh
    if hemi.radius < 0.33 or barrel_mesh.height < 0.60 or (
            absf(hemi.height - hemi.radius) > 0.001 or
            absf(dome.position.y + hemi.get_aabb().position.y) > 0.001 or
            absf(offset.x - center.x) + hemi.radius > belly.size.x * 0.5 + 0.005):
        _fail("larger hemisphere must still attach its flat base under the belly")
        return
    if aim_pivot != barrel.get_parent() or (
            mount.global_basis.y.normalized().dot(
                -body.global_basis.y.normalized()) < 0.995):
        _fail("barrel has its own swivel and the dome must face down from the torso")
        return
    var flash: Node3D = mount.get_node_or_null(
        "TurretAim/MuzzleCrossFlash") as Node3D
    var fx_h: MeshInstance3D = mount.get_node_or_null(
        "TurretAim/MuzzleCrossFlash/CrossHorizontal") as MeshInstance3D
    var fx_v: MeshInstance3D = mount.get_node_or_null(
        "TurretAim/MuzzleCrossFlash/CrossVertical") as MeshInstance3D
    if flash == null or fx_h == null or fx_v == null or (
            not fx_h.mesh is BoxMesh or not fx_v.mesh is BoxMesh or
            (fx_h.mesh as BoxMesh).size.x < 0.40 or
            (fx_v.mesh as BoxMesh).size.y < 0.40 or
            flash.visible or TURRETS.FLASH_DURATION_SECONDS <= 0.0 or
            TURRETS.FLASH_DURATION_SECONDS > 0.15 or
            flash.position.distance_to(TURRETS.MUZZLE_LOCAL) > 0.0001):
        _fail("cross-shaped muzzle flash must be hidden, centered and brief")
        return
    var glow: StandardMaterial3D = fx_h.material_override as StandardMaterial3D
    if glow == null or not glow.emission_enabled or (
            glow.emission_energy_multiplier < 2.0 or
            fx_v.material_override != glow):
        _fail("both arms of the cross must actually emit light")
        return
    var old_body: Transform3D = body.transform
    body.position += Vector3(0.10, 0.12, -0.07)
    body.rotate_x(0.09)
    turret.call("advance", 0.0, player.global_position, false)
    if mount.global_position.distance_to(body.to_global(offset)) > 0.001 or (
            mount.global_basis.y.normalized().dot(
                -body.global_basis.y.normalized()) < 0.995):
        _fail("cannon must continue following body movement while shooting is blocked")
        return
    body.transform = old_body
    turret.call("advance", 0.0, player.global_position, false)
    if flash.visible:
        _fail("knockdown/disabled must hide flash")
        return
    # Active single turret follows the player, not a four-way ranking.
    var target: Vector3 = player.global_position + Vector3(1.3, 0.0, 0.6)
    turret.call("advance", DT, target, true)
    if str(turret.get("last_aimed_turret")) != id or (
            int(turret.get("shots_fired")) != 1 or
            str(turret.get("last_fired_turret")) != id or
            not flash.visible):
        _fail("single turret must aim, fire immediately and show cross pulse")
        return
    var first_shot: Dictionary = (turret.get("projectiles") as Array)[0]
    var direction: Vector3 = first_shot["direction"]
    if direction.normalized().dot(
            -aim_pivot.global_basis.z.normalized()) < 0.999 or (
            flash.global_position.distance_to(
                aim_pivot.to_global(TURRETS.MUZZLE_LOCAL)) > 0.001):
        _fail("cross flash must be attached to the actual firing muzzle")
        return
    turret.call("advance", TURRETS.FLASH_DURATION_SECONDS + 0.025, target, true)
    if flash.visible or int(turret.get("shots_fired")) != 1:
        _fail("cross pulse must disappear quickly without an extra shot")
        return
    turret.call("advance", 0.70, target, true)
    if int(turret.get("shots_fired")) != 1:
        _fail("single cannon shot too early")
        return
    turret.call("advance", 0.42, target, true)
    if int(turret.get("shots_fired")) != 2 or not flash.visible:
        _fail("second shot must recreate its own cross pulse after the interval")
        return
    # Active attack cancels projectiles, new fire, aim and flash.
    scene.set("bittaran_attack_frame", {"kind": "stomp", "phase": "strike"})
    scene.call("_tick_bittaran_leg_turrets", DT)
    if flash.visible or not (turret.get("projectiles") as Array).is_empty() or (
            str(turret.get("last_aimed_turret")) != ""):
        _fail("attack must immediately cancel flash/aim/projectiles")
        return
    scene.set("bittaran_attack_frame", {})
    var ik: RefCounted = scene.get("bittaran_foot_ik")
    ik.set("windup_elapsed", 0.0)
    gun.call("reset")
    gun.set("elapsed", RAILGUN.BEAM_START + 0.1)
    scene.call("_tick_bittaran_leg_turrets", DT)
    scene.call("_tick_bittaran_railgun", DT)
    if flash.visible or not (turret.get("projectiles") as Array).is_empty() or (
            str(turret.get("last_aimed_turret")) != "") or (
            float(gun.get("elapsed")) != 0.0) or (
            (gun.get("inner_beam") as MeshInstance3D).visible):
        _fail("knockdown must cancel turret cross/aim and dorsal railgun beam")
        return
    ik.set("windup_elapsed", -1.0)
    ik.set("break_elapsed", 1.0)
    scene.call("_tick_bittaran_leg_turrets", DT)
    scene.call("_tick_bittaran_railgun", DT)
    if flash.visible or int(turret.get("shots_fired")) != 0 or (
            float(gun.get("elapsed")) != 0.0):
        _fail("fallen pose must keep turret and dorsal laser off")
        return
    quit(0)
