extends Node3D
## One substantial underbelly cannon: seated half-dome and independent
## swiveling barrel. Authored model, animations, IK and railgun are untouched.
## A luminous, short-lived cross and an actual muzzle light fire once with each laser bolt.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const TURRET_IDS: Array[String] = ["belly_main"]
const BODY_BONE: String = "Body"
const BELLY_MESH: String = "body_mesh"
const SHOT_INTERVAL_SECONDS: float = 4.0
const FLASH_DURATION_SECONDS: float = 0.12
const FLASH_LENGTH_METERS: float = 3.10
const FLASH_FORWARD_METERS: float = 0.20
const SHOT_SPEED_MPS: float = 17.0
const PROJECTILE_LENGTH_METERS: float = 1.50
const BURST_LIGHT_ENERGY: float = 10.0
const PROJECTILE_LIFETIME_SECONDS: float = 3.0
const PROJECTILE_HIT_RADIUS_METERS: float = 0.62
const MUZZLE_LOCAL: Vector3 = Vector3(0.0, 0.0, -0.81)

var mounts: Dictionary = {}
# The hemisphere's flat base is fixed to the belly; only its barrel swivels.
var aim_pivots: Dictionary = {}
var mount_rest_bases: Dictionary = {}
var anchors: Dictionary = {}
# One centered attachment measured from the original torso mesh.
var mount_offsets: Dictionary = {}
var belly_bounds: AABB = AABB()
var projectiles: Array[Dictionary] = []
var idle_bolts: Array[MeshInstance3D] = []
var volley_order: Array[String] = []
var volley_index: int = 0
var time_until_shot: float = 0.0
var shots_fired: int = 0
var last_fired_turret: String = ""
var last_aimed_turret: String = ""
var projectile_mesh: CapsuleMesh
var projectile_halo_mesh: CapsuleMesh
var projectile_material: StandardMaterial3D
var projectile_halo_material: StandardMaterial3D
var muzzle_cross_flash: Node3D
var muzzle_burst_light: OmniLight3D
var flash_time_remaining: float = 0.0

func setup(rig: Node3D) -> bool:
    if rig == null:
        return false
    var armor := StandardMaterial3D.new()
    armor.albedo_color = Color("#5b728a")
    armor.metallic = 0.65
    armor.roughness = 0.31
    var barrel_metal := StandardMaterial3D.new()
    barrel_metal.albedo_color = Color("#283847")
    barrel_metal.metallic = 0.75
    barrel_metal.roughness = 0.26
    var muzzle_glow := StandardMaterial3D.new()
    muzzle_glow.albedo_color = Color("#72d8fb")
    muzzle_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    muzzle_glow.emission_enabled = true
    muzzle_glow.emission = Color("#51baff")
    muzzle_glow.emission_energy_multiplier = 2.0
    # Single moving 1.5m laser dart, NOT a sustained beam or round orb.
    # A bright slender capsule has a larger additive, depth-tested halo.
    projectile_material = StandardMaterial3D.new()
    projectile_material.albedo_color = Color("#e2fcff")
    projectile_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    projectile_material.emission_enabled = true
    projectile_material.emission = Color("#90e9ff")
    projectile_material.emission_energy_multiplier = 5.5
    projectile_mesh = CapsuleMesh.new()
    projectile_mesh.radius = 0.065
    projectile_mesh.height = PROJECTILE_LENGTH_METERS
    projectile_mesh.radial_segments = 12
    projectile_mesh.rings = 4
    projectile_halo_material = StandardMaterial3D.new()
    projectile_halo_material.albedo_color = Color(0.2, 0.68, 1.0, 0.23)
    projectile_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    projectile_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    projectile_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    projectile_halo_material.no_depth_test = false
    projectile_halo_material.emission_enabled = true
    projectile_halo_material.emission = Color("#66caff")
    projectile_halo_material.emission_energy_multiplier = 3.2
    projectile_halo_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
    projectile_halo_mesh = CapsuleMesh.new()
    projectile_halo_mesh.radius = 0.16
    projectile_halo_mesh.height = PROJECTILE_LENGTH_METERS + 0.20
    projectile_halo_mesh.radial_segments = 12
    projectile_halo_mesh.rings = 4
    var body: Node3D = rig.find_child(BODY_BONE, true, false) as Node3D
    if body == null:
        push_error("Bittaran belly turret missing Body joint")
        return false
    # Only the authored torso shell (NOT legs/head/other descendants)
    # determines the flat underside. Rebuilding from the imported mesh
    # means the base follows the actual body shape and pivot.
    belly_bounds = _measure_belly_armor(body)
    if not belly_bounds.has_volume():
        push_error("Bittaran belly turret missing original body_mesh")
        return false
    var belly_center: Vector3 = belly_bounds.get_center()
    var belly_inset: float = minf(0.018, belly_bounds.size.y * 0.04)
    for id in TURRET_IDS:
        # One larger cannon, at the TRUE BODY-local underside center.
        # The hemisphere's flat base sinks just inside the original armor.
        mount_offsets[id] = Vector3(
            belly_center.x,
            belly_bounds.position.y + belly_inset,
            belly_center.z)
        # Local +Y hemisphere axis = body DOWN, normal to belly.
        mount_rest_bases[id] = Basis.looking_at(Vector3.FORWARD, Vector3.DOWN)
        var mount := Node3D.new()
        mount.name = "BellyCannon_" + id
        # Keep cosmetic geometry outside ALL authored model bones. IK
        # measures descendant meshes and must never include a turret.
        mount.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
        add_child(mount)
        anchors[id] = body
        var hemisphere := SphereMesh.new()
        hemisphere.radius = 0.36
        # A regular hemisphere needs height == radius (Godot SphereMesh).
        hemisphere.height = hemisphere.radius
        hemisphere.is_hemisphere = true
        hemisphere.radial_segments = 12
        hemisphere.rings = 6
        var dome := MeshInstance3D.new()
        dome.name = "TurretHemisphere"
        dome.mesh = hemisphere
        # Godot's primitive origin may be centered differently from the
        # flat equator; align its lowest/flat ring exactly with mount Y=0.
        dome.position.y = -hemisphere.get_aabb().position.y
        dome.material_override = armor
        mount.add_child(dome)
        # Layered armor skirt around the hemisphere's fixed base makes
        # the SINGLE cannon look heavier; it never swivels off the belly.
        var base_collar_mesh := CylinderMesh.new()
        base_collar_mesh.top_radius = 0.43
        base_collar_mesh.bottom_radius = 0.43
        base_collar_mesh.height = 0.10
        base_collar_mesh.radial_segments = 16
        var base_collar := MeshInstance3D.new()
        base_collar.name = "TurretBaseCollar"
        base_collar.mesh = base_collar_mesh
        base_collar.position.y = 0.045
        base_collar.material_override = barrel_metal
        mount.add_child(base_collar)
        # The connected dome is FIXED to the belly armor. Only the
        # main barrel assembly below rotates toward the player.
        var aim_pivot := Node3D.new()
        aim_pivot.name = "TurretAim"
        aim_pivot.position.y = hemisphere.radius * 0.68
        mount.add_child(aim_pivot)
        aim_pivots[id] = aim_pivot
        var tube := CylinderMesh.new()
        tube.top_radius = 0.12
        tube.bottom_radius = 0.15
        tube.height = 0.68
        tube.radial_segments = 16
        var barrel := MeshInstance3D.new()
        barrel.name = "TurretBarrel"
        barrel.mesh = tube
        barrel.rotation.x = -PI * 0.5
        barrel.position.z = -0.45
        barrel.material_override = barrel_metal
        aim_pivot.add_child(barrel)
        # Thick armored sleeve behind the muzzle gives the single
        # cannon a substantial silhouette without extra firing points.
        var sleeve_mesh := CylinderMesh.new()
        sleeve_mesh.top_radius = 0.205
        sleeve_mesh.bottom_radius = 0.225
        sleeve_mesh.height = 0.31
        sleeve_mesh.radial_segments = 16
        var sleeve := MeshInstance3D.new()
        sleeve.name = "BarrelSleeve"
        sleeve.mesh = sleeve_mesh
        sleeve.rotation.x = -PI * 0.5
        sleeve.position.z = -0.27
        sleeve.material_override = armor
        aim_pivot.add_child(sleeve)
        var ring_mesh := CylinderMesh.new()
        ring_mesh.top_radius = 0.17
        ring_mesh.bottom_radius = 0.17
        ring_mesh.height = 0.085
        ring_mesh.radial_segments = 16
        var ring := MeshInstance3D.new()
        ring.name = "TurretMuzzle"
        ring.mesh = ring_mesh
        ring.rotation.x = -PI * 0.5
        ring.position.z = -0.785
        ring.material_override = muzzle_glow
        aim_pivot.add_child(ring)
        # Render fivefold-length CROSS in the foreground, 20cm IN FRONT
        # of the actual muzzle. Transparent add + no_depth_test means
        # Bittaran's belly / legs cannot unexpectedly hide the flash.
        # Billboard-facing bars stay a legible + from the player's camera.
        var cross := Node3D.new()
        cross.name = "MuzzleCrossFlash"
        cross.position = MUZZLE_LOCAL + Vector3(0.0, 0.0, -FLASH_FORWARD_METERS)
        cross.visible = false
        aim_pivot.add_child(cross)
        muzzle_cross_flash = cross
        var cross_material := StandardMaterial3D.new()
        cross_material.albedo_color = Color(0.94, 0.99, 1.0, 0.92)
        cross_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        cross_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        cross_material.no_depth_test = true
        cross_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
        cross_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        cross_material.emission_enabled = true
        cross_material.emission = Color("#9deaff")
        cross_material.emission_energy_multiplier = 8.0
        # Explicit foreground pass, not the depth-tested thruster pass.
        cross_material.render_priority = RENDER_ORDER.CHARACTER_FOREGROUND
        var halo_material := StandardMaterial3D.new()
        halo_material.albedo_color = Color(0.21, 0.73, 1.0, 0.38)
        halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        halo_material.no_depth_test = true
        halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
        halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        halo_material.emission_enabled = true
        halo_material.emission = Color("#51baff")
        halo_material.emission_energy_multiplier = 3.5
        halo_material.render_priority = RENDER_ORDER.CHARACTER_FOREGROUND
        for horizontal in [true, false]:
            var bar_shape := BoxMesh.new()
            bar_shape.size = (
                Vector3(FLASH_LENGTH_METERS, 0.135, 0.026) if horizontal
                else Vector3(0.135, FLASH_LENGTH_METERS, 0.026))
            var bar := MeshInstance3D.new()
            bar.name = "CrossHorizontal" if horizontal else "CrossVertical"
            bar.mesh = bar_shape
            bar.material_override = cross_material
            bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            cross.add_child(bar)
            var halo_shape := BoxMesh.new()
            halo_shape.size = (
                Vector3(FLASH_LENGTH_METERS, 0.42, 0.016) if horizontal
                else Vector3(0.42, FLASH_LENGTH_METERS, 0.016))
            var halo := MeshInstance3D.new()
            halo.name = "GlowHorizontal" if horizontal else "GlowVertical"
            halo.mesh = halo_shape
            halo.material_override = halo_material
            halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            # Core draws in front of the wide glow even for coincident
            # parts; each pass is emissive and screen-facing.
            halo.position.z = 0.025
            cross.add_child(halo)
        var center_shape := SphereMesh.new()
        center_shape.radius = 0.17
        center_shape.height = 0.34
        center_shape.radial_segments = 12
        center_shape.rings = 6
        var center_glint := MeshInstance3D.new()
        center_glint.name = "CrossCore"
        center_glint.mesh = center_shape
        center_glint.material_override = cross_material
        center_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        cross.add_child(center_glint)
        # A radial alpha gradient actually looks like a luminous bloom,
        # instead of merely drawing a flat opaque cross shape. This is
        # procedurally generated (no texture asset / external download).
        var radiance_gradient := Gradient.new()
        radiance_gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.98))
        radiance_gradient.set_color(1, Color(0.05, 0.32, 1.0, 0.0))
        radiance_gradient.add_point(0.16, Color(0.68, 0.90, 1.0, 0.74))
        radiance_gradient.add_point(0.50, Color(0.18, 0.52, 1.0, 0.16))
        var radiance_texture := GradientTexture2D.new()
        radiance_texture.width = 128
        radiance_texture.height = 128
        radiance_texture.fill = GradientTexture2D.FILL_RADIAL
        radiance_texture.fill_from = Vector2(0.5, 0.5)
        radiance_texture.fill_to = Vector2(1.0, 0.5)
        radiance_texture.gradient = radiance_gradient
        var radiance_material := StandardMaterial3D.new()
        radiance_material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
        radiance_material.albedo_texture = radiance_texture
        radiance_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        radiance_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        radiance_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        radiance_material.no_depth_test = true
        radiance_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
        radiance_material.emission_enabled = true
        radiance_material.emission = Color("#8de8ff")
        radiance_material.emission_energy_multiplier = 4.5
        radiance_material.render_priority = RENDER_ORDER.CHARACTER_FOREGROUND
        var radiance_mesh := QuadMesh.new()
        radiance_mesh.size = Vector2(4.8, 4.8)
        var radiance := MeshInstance3D.new()
        radiance.name = "RadialRadiance"
        radiance.mesh = radiance_mesh
        radiance.material_override = radiance_material
        radiance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # Slightly behind the crossing rods to avoid hiding the white core.
        radiance.position.z = 0.04
        cross.add_child(radiance)
        # Actual dynamic light reaching nearby Bittaran armor and floor.
        # No shadows for the Android GL Compatibility lighting budget.
        var burst_light := OmniLight3D.new()
        burst_light.name = "MuzzleBurstLight"
        burst_light.light_color = Color("#9be6ff")
        burst_light.omni_range = 4.5
        burst_light.light_energy = 0.0
        burst_light.shadow_enabled = false
        burst_light.visible = false
        cross.add_child(burst_light)
        muzzle_burst_light = burst_light
        mounts[id] = mount
    _sync_mounts()
    reset()
    while idle_bolts.size() < 3:
        idle_bolts.append(_make_bolt())
    return mounts.size() == TURRET_IDS.size()

func reset() -> void:
    for projectile in projectiles:
        _return_bolt(projectile["node"] as MeshInstance3D)
    projectiles.clear()
    volley_order.clear()
    volley_index = 0
    time_until_shot = 0.0
    shots_fired = 0
    last_fired_turret = ""
    last_aimed_turret = ""
    flash_time_remaining = 0.0
    if muzzle_cross_flash != null:
        muzzle_cross_flash.visible = false
        muzzle_cross_flash.scale = Vector3.ONE
    if muzzle_burst_light != null:
        muzzle_burst_light.light_energy = 0.0
        muzzle_burst_light.visible = false

func _advance_muzzle_cross(delta: float) -> void:
    if muzzle_cross_flash == null or flash_time_remaining <= 0.0:
        return
    flash_time_remaining = maxf(flash_time_remaining - maxf(delta, 0.0), 0.0)
    var fraction: float = flash_time_remaining / FLASH_DURATION_SECONDS
    muzzle_cross_flash.visible = flash_time_remaining > 0.0
    if muzzle_burst_light != null:
        muzzle_burst_light.light_energy = (
            BURST_LIGHT_ENERGY * fraction * fraction)
        muzzle_burst_light.visible = flash_time_remaining > 0.0
    if flash_time_remaining > 0.0:
        # A very fast, physically visible contraction after the ignition.
        muzzle_cross_flash.scale = Vector3.ONE * (0.45 + fraction * 0.55)

func _sort_volley_by_distance(player_world: Vector3) -> void:
    volley_order = TURRET_IDS.duplicate()
    for i in range(volley_order.size()):
        for j in range(i + 1, volley_order.size()):
            var first: Node3D = mounts[volley_order[i]]
            var second: Node3D = mounts[volley_order[j]]
            if second.global_position.distance_squared_to(player_world) < (
                    first.global_position.distance_squared_to(player_world)):
                var swap: String = volley_order[i]
                volley_order[i] = volley_order[j]
                volley_order[j] = swap

## Measure ONLY the primary torso shell in BODY-local coordinates.
## This excludes feet, legs, internal attachments, antenna and gun meshes.
func _measure_belly_armor(body: Node3D) -> AABB:
    var shell: MeshInstance3D = body.get_node_or_null(
        BELLY_MESH) as MeshInstance3D
    if shell == null or shell.mesh == null:
        return AABB()
    var box: AABB = shell.mesh.get_aabb()
    var bounds := AABB()
    for i in range(8):
        var point: Vector3 = shell.transform * box.get_endpoint(i)
        if i == 0:
            bounds = AABB(point, Vector3.ZERO)
        else:
            bounds = bounds.expand(point)
    return bounds

func _sync_mounts() -> void:
    # The body is the SINGLE physical anchor for the main belly cannon.
    # It follows the final body pose even when
    # attack/KO/down has suspended aiming and firing.
    for id in TURRET_IDS:
        var body: Node3D = anchors[id]
        var mount: Node3D = mounts[id]
        mount.global_position = body.to_global(mount_offsets[id])
        var rest_basis: Basis = mount_rest_bases[id]
        mount.global_basis = (
            body.global_basis * rest_basis).orthonormalized()
        (aim_pivots[id] as Node3D).basis = Basis.IDENTITY

func _aim_nearest(player_world: Vector3) -> void:
    var closest_id: String = ""
    var closest_distance_sq: float = INF
    for id in TURRET_IDS:
        var mount: Node3D = mounts[id]
        var distance_sq: float = mount.global_position.distance_squared_to(player_world)
        if distance_sq < closest_distance_sq:
            closest_id = id
            closest_distance_sq = distance_sq
    last_aimed_turret = closest_id
    if closest_id.is_empty():
        return
    var pivot: Node3D = aim_pivots[closest_id]
    var aim: Vector3 = player_world + Vector3.UP * 0.90
    var to_target: Vector3 = aim - pivot.global_position
    if to_target.length_squared() < 0.001:
        return
    var up: Vector3 = (
        Vector3.FORWARD if absf(to_target.normalized().dot(Vector3.UP)) > 0.98
        else Vector3.UP)
    # Only one barrel exists. Its dome stays fixed to the belly.
    pivot.look_at(aim, up)

func _fire_next(player_world: Vector3) -> void:
    if volley_index == 0:
        _sort_volley_by_distance(player_world)
    var id: String = volley_order[volley_index]
    var pivot: Node3D = aim_pivots[id]
    var origin: Vector3 = pivot.to_global(MUZZLE_LOCAL)
    # Do not silently steer bullets through an un-aimed barrel. The old
    # near-to-far volley remains, but projectile travel now matches the
    # muzzle direction of each visible gun.
    var direction: Vector3 = -pivot.global_basis.z.normalized()
    # The bright cross must appear on the very same firing tick.
    flash_time_remaining = FLASH_DURATION_SECONDS
    if muzzle_cross_flash != null:
        muzzle_cross_flash.scale = Vector3.ONE
        muzzle_cross_flash.visible = true
    if muzzle_burst_light != null:
        muzzle_burst_light.light_energy = BURST_LIGHT_ENERGY
        muzzle_burst_light.visible = true
    var bolt: MeshInstance3D = idle_bolts.pop_back() if not idle_bolts.is_empty() else _make_bolt()
    bolt.visible = true
    # CapsuleMesh is along local +Y; rotate it into the shot direction.
    # The leading tip exits the muzzle first, while the trailing end
    # touches the muzzle on the emission frame.
    var shot_up: Vector3 = (
        Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98
        else Vector3.UP)
    bolt.global_basis = (
        Basis.looking_at(direction, shot_up)
        * Basis(Vector3.RIGHT, -PI * 0.5))
    var shot_center: Vector3 = (
        origin + direction * (PROJECTILE_LENGTH_METERS * 0.5))
    bolt.global_position = shot_center
    bolt.reset_physics_interpolation()
    projectiles.append({
        "node": bolt,
        "position": shot_center,
        # Preserve the old logical shot path through the physical muzzle.
        "collision_position": origin,
        "direction": direction,
        "age": 0.0
    })
    last_fired_turret = id
    shots_fired += 1
    volley_index = (volley_index + 1) % TURRET_IDS.size()

func _make_bolt() -> MeshInstance3D:
    var bolt := MeshInstance3D.new()
    bolt.name = "BellyCannonShot_Pooled"
    bolt.set_meta("sera_no_view_edges", true)
    bolt.mesh = projectile_mesh
    bolt.material_override = projectile_material
    bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var halo := MeshInstance3D.new()
    halo.name = "LaserStreakHalo"
    halo.mesh = projectile_halo_mesh
    halo.material_override = projectile_halo_material
    halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    bolt.add_child(halo)
    add_child(bolt)
    bolt.hide()
    return bolt

func _return_bolt(bolt: MeshInstance3D) -> void:
    if is_instance_valid(bolt):
        bolt.hide()
        idle_bolts.append(bolt)

func _advance_projectiles(delta: float, player_world: Vector3) -> Array[Vector3]:
    var impacts: Array[Vector3] = []
    var player_center: Vector3 = player_world + Vector3.UP * 0.90
    for i in range(projectiles.size() - 1, -1, -1):
        var bullet: Dictionary = projectiles[i]
        var old_position: Vector3 = bullet["position"]
        var collision_position: Vector3 = bullet["collision_position"]
        var direction: Vector3 = bullet["direction"]
        var travel: Vector3 = direction * (SHOT_SPEED_MPS * delta)
        var destination: Vector3 = old_position + travel
        # The long visual streak is half a length ahead of its muzzle.
        # Its swept damage segment uses the original muzzle-origin path,
        # preserving the existing hit/knockback behavior independently.
        var closest: Vector3 = collision_position + travel * clampf(
            (player_center - collision_position).dot(travel) / maxf(
                travel.length_squared(), 0.000001), 0.0, 1.0)
        var hit: bool = closest.distance_squared_to(player_center) <= (
            PROJECTILE_HIT_RADIUS_METERS * PROJECTILE_HIT_RADIUS_METERS)
        var age: float = float(bullet["age"]) + delta
        if hit or age >= PROJECTILE_LIFETIME_SECONDS:
            _return_bolt(bullet["node"] as MeshInstance3D)
            projectiles.remove_at(i)
            if hit:
                impacts.append(direction)
        else:
            bullet["position"] = destination
            bullet["collision_position"] = collision_position + travel
            bullet["age"] = age
            (bullet["node"] as Node3D).global_position = destination
            projectiles[i] = bullet
    return impacts

## Disabled means neither an in-flight hit nor a fresh shot may persist.
## Called after authored animation and IK have settled for this physics tick.
func advance(delta: float, player_world: Vector3, active: bool) -> Array[Vector3]:
    var impacts: Array[Vector3] = []
    if mounts.size() != TURRET_IDS.size():
        return impacts
    # Belly attachment MUST continue during stomp/sweep/kick and down, even
    # though all firing and in-flight bullets are cancelled then.
    _sync_mounts()
    if not active:
        reset()
        return impacts
    var step: float = maxf(delta, 0.0)
    _aim_nearest(player_world)
    _advance_muzzle_cross(step)
    impacts = _advance_projectiles(step, player_world)
    time_until_shot -= step
    if time_until_shot <= 0.0:
        _fire_next(player_world)
        # No catch-up burst after a long frame or an interrupted attack.
        time_until_shot = SHOT_INTERVAL_SECONDS
    return impacts
