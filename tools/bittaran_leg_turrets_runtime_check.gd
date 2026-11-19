extends SceneTree
## v503: four-second single laser-streak shots and genuinely illuminating
## preserved attack/downtime gates, and an intact independent railgun.
const TURRETS = preload("res://scripts/bittaran_leg_turrets.gd")
const RAILGUN = preload("res://scripts/bittaran_railgun.gd")
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
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
            absf(TURRETS.SHOT_INTERVAL_SECONDS - 4.0) > 0.001):
        _fail("exactly ONE central belly cannon and 4-second cadence required")
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
    var glow_h: MeshInstance3D = mount.get_node_or_null(
        "TurretAim/MuzzleCrossFlash/GlowHorizontal") as MeshInstance3D
    var glow_v: MeshInstance3D = mount.get_node_or_null(
        "TurretAim/MuzzleCrossFlash/GlowVertical") as MeshInstance3D
    if flash == null or fx_h == null or fx_v == null or (
            glow_h == null or glow_v == null or
            not fx_h.mesh is BoxMesh or not fx_v.mesh is BoxMesh or
            not glow_h.mesh is BoxMesh or not glow_v.mesh is BoxMesh):
        _fail("large cross needs solid horizontal/vertical bars AND soft glow bars")
        return
    # The approved v500 bar was 0.62m long; the v501 request is ~5x
    # (3.10m) in BOTH axes. A narrow hairline is not visually sufficient.
    var horizontal: Vector3 = (fx_h.mesh as BoxMesh).size
    var vertical: Vector3 = (fx_v.mesh as BoxMesh).size
    var halo_horizontal: Vector3 = (glow_h.mesh as BoxMesh).size
    var halo_vertical: Vector3 = (glow_v.mesh as BoxMesh).size
    if absf(horizontal.x - 3.10) > 0.06 or (
            absf(vertical.y - 3.10) > 0.06 or
            horizontal.y < 0.11 or vertical.x < 0.11 or
            halo_horizontal.x < horizontal.x or
            halo_vertical.y < vertical.y or
            halo_horizontal.y < horizontal.y * 2.0 or
            halo_vertical.x < vertical.x * 2.0):
        _fail("v501 muzzle cross must be fivefold longer, thicker and haloed")
        return
    # The flash is placed visibly in front of the PHYSICAL muzzle.
    # The separate no-depth-test transparent pass draws over 3D occluders
    # even when Bittaran's body would otherwise hide it.
    if flash.visible or (
            absf(flash.position.x - TURRETS.MUZZLE_LOCAL.x) > 0.0001 or
            absf(flash.position.y - TURRETS.MUZZLE_LOCAL.y) > 0.0001 or
            flash.position.z > TURRETS.MUZZLE_LOCAL.z - 0.15 or
            flash.position.z < TURRETS.MUZZLE_LOCAL.z - 0.30 or
            TURRETS.FLASH_DURATION_SECONDS < 0.11 or
            TURRETS.FLASH_DURATION_SECONDS > 0.15):
        _fail("large cross must glow ahead of muzzle for a readable brief pulse")
        return
    var core_mat: StandardMaterial3D = fx_h.material_override as StandardMaterial3D
    var halo_mat: StandardMaterial3D = glow_h.material_override as StandardMaterial3D
    if core_mat == null or halo_mat == null:
        _fail("both bright core and soft aura need materials")
        return
    if fx_v.material_override != core_mat or (
            glow_v.material_override != halo_mat or
            not core_mat.emission_enabled or
            core_mat.emission_energy_multiplier < 7.0 or
            not halo_mat.emission_enabled or
            core_mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA or
            halo_mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA or
            not core_mat.no_depth_test or not halo_mat.no_depth_test or
            core_mat.blend_mode != BaseMaterial3D.BLEND_MODE_ADD or
            halo_mat.blend_mode != BaseMaterial3D.BLEND_MODE_ADD or
            core_mat.billboard_mode != BaseMaterial3D.BILLBOARD_ENABLED or
            halo_mat.billboard_mode != BaseMaterial3D.BILLBOARD_ENABLED):
        _fail("foreground cross needs bright additive billboard materials without depth testing")
        return
    if core_mat.render_priority != RENDER_ORDER.CHARACTER_FOREGROUND or (
            halo_mat.render_priority != RENDER_ORDER.CHARACTER_FOREGROUND):
        _fail("foreground cross must reuse the registered depthless overlay pass")
        return
    # A visible cross alone is insufficient: require a real dynamic
    # OmniLight, plus a soft radial flare texture that fades to transparent.
    var burst_light: OmniLight3D = mount.get_node_or_null(
        "TurretAim/MuzzleCrossFlash/MuzzleBurstLight") as OmniLight3D
    var radiance: MeshInstance3D = mount.get_node_or_null(
        "TurretAim/MuzzleCrossFlash/RadialRadiance") as MeshInstance3D
    if burst_light == null or radiance == null or (
            burst_light.visible or burst_light.light_energy > 0.001 or
            burst_light.omni_range < 3.0 or burst_light.shadow_enabled or
            not radiance.mesh is QuadMesh):
        _fail("flash needs a hidden real light and a radial luminous gradient")
        return
    var radiance_material: StandardMaterial3D = (
        radiance.material_override as StandardMaterial3D)
    if radiance_material == null or (
            not radiance_material.albedo_texture is GradientTexture2D or
            not radiance_material.emission_enabled or
            radiance_material.no_depth_test == false or
            radiance_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA or
            radiance_material.billboard_mode != BaseMaterial3D.BILLBOARD_ENABLED):
        _fail("radial light must fade softly and remain camera-facing")
        return
    var radial_texture: GradientTexture2D = (
        radiance_material.albedo_texture as GradientTexture2D)
    if radial_texture.fill != GradientTexture2D.FILL_RADIAL or (
            radial_texture.width < 64 or radial_texture.height < 64 or
            radial_texture.gradient == null):
        _fail("a radial gradient, not an opaque sheet, must create the glow")
        return
    # New single laser-like shot: visibly longer than its narrow radius.
    var shot_core: CapsuleMesh = turret.get("projectile_mesh")
    var shot_halo: CapsuleMesh = turret.get("projectile_halo_mesh")
    if shot_core == null or shot_halo == null or (
            shot_core.height < 1.35 or shot_core.radius > 0.09 or
            shot_halo.height <= shot_core.height or
            shot_halo.radius <= shot_core.radius or
            shot_core.height / shot_core.radius < 15.0):
        _fail("ball projectile must become one long, slim glowing laser bolt")
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
    if flash.visible or burst_light.visible:
        _fail("knockdown/disabled must hide flash and real illumination")
        return
    # Active single turret follows the player, not a four-way ranking.
    var target: Vector3 = player.global_position + Vector3(1.3, 0.0, 0.6)
    turret.call("advance", DT, target, true)
    if str(turret.get("last_aimed_turret")) != id or (
            int(turret.get("shots_fired")) != 1 or
            str(turret.get("last_fired_turret")) != id or
            not flash.visible or not burst_light.visible or
            burst_light.light_energy < 5.0):
        _fail("single turret must fire immediately with a real light pulse")
        return
    var first_shot: Dictionary = (turret.get("projectiles") as Array)[0]
    var direction: Vector3 = first_shot["direction"]
    var bolt_node: MeshInstance3D = first_shot["node"] as MeshInstance3D
    var bolt_glow: MeshInstance3D = bolt_node.get_node_or_null(
        "LaserStreakHalo") as MeshInstance3D
    if bolt_node == null or not bolt_node.mesh is CapsuleMesh or (
            bolt_glow == null or not bolt_glow.mesh is CapsuleMesh or
            not bolt_glow.material_override is StandardMaterial3D or
            (bolt_glow.material_override as StandardMaterial3D).no_depth_test):
        _fail("laser projectile needs one narrow core and depth-tested glow")
        return
    if bolt_node.global_basis.y.normalized().dot(
            direction.normalized()) < 0.995:
        _fail("long projectile MUST point in its actual shot velocity direction")
        return
    if direction.normalized().dot(
            -aim_pivot.global_basis.z.normalized()) < 0.999 or (
            flash.global_position.distance_to(
                aim_pivot.to_global(flash.position)) > 0.001):
        _fail("cross flash must be attached to the actual firing muzzle")
        return
    # Illumination must dynamically decay instead of merely toggling
    # one static cross mesh on/off.
    var initial_energy: float = burst_light.light_energy
    turret.call("advance", TURRETS.FLASH_DURATION_SECONDS * 0.5, target, true)
    if not flash.visible or not burst_light.visible or (
            burst_light.light_energy >= initial_energy or
            burst_light.light_energy < 0.05):
        _fail("real muzzle light should fade continuously while the cross shrinks")
        return
    turret.call("advance", TURRETS.FLASH_DURATION_SECONDS * 0.5 + 0.02, target, true)
    if flash.visible or burst_light.visible or (
            burst_light.light_energy > 0.001 or
            int(turret.get("shots_fired")) != 1):
        _fail("cross and actual illumination must disappear after a brief pulse")
        return
    turret.call("advance", 3.50, target, true)
    if int(turret.get("shots_fired")) != 1:
        _fail("4-second laser cannon fired too early at 3.64 seconds")
        return
    turret.call("advance", 0.34, target, true)
    if int(turret.get("shots_fired")) != 1:
        _fail("4-second cannon emitted an early second shot")
        return
    turret.call("advance", 0.03, target, true)
    if int(turret.get("shots_fired")) != 2 or (
            not flash.visible or not burst_light.visible):
        _fail("second laser shot must pulse the cross and scene lighting at 4 seconds")
        return
    # Active attack cancels projectiles, new fire, aim and flash.
    scene.set("bittaran_attack_frame", {"kind": "stomp", "phase": "strike"})
    scene.call("_tick_bittaran_leg_turrets", DT)
    if flash.visible or burst_light.visible or (
            not (turret.get("projectiles") as Array).is_empty() or
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
    if flash.visible or burst_light.visible or (
            not (turret.get("projectiles") as Array).is_empty() or
            str(turret.get("last_aimed_turret")) != "") or (
            float(gun.get("elapsed")) != 0.0) or (
            (gun.get("inner_beam") as MeshInstance3D).visible):
        _fail("knockdown must cancel turret cross/aim and dorsal railgun beam")
        return
    ik.set("windup_elapsed", -1.0)
    ik.set("break_elapsed", 1.0)
    scene.call("_tick_bittaran_leg_turrets", DT)
    scene.call("_tick_bittaran_railgun", DT)
    if flash.visible or burst_light.visible or (
            int(turret.get("shots_fired")) != 0) or (
            float(gun.get("elapsed")) != 0.0):
        _fail("fallen pose must keep turret and dorsal laser off")
        return
    quit(0)
