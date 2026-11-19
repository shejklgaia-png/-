extends Node3D
## Four belly-mounted cannons. No turret is attached to or inherits any
## leg bone; the original Bittaran rig/IK/attacks/railgun are untouched.
## The nearest barrel aims; all four retain one shared firing clock.
const TURRET_IDS: Array[String] = [
    "belly_fl", "belly_fr", "belly_rl", "belly_rr"]
const BODY_BONE: String = "Body"
const BELLY_MESH: String = "body_mesh"
const SHOT_INTERVAL_SECONDS: float = 1.2
const SHOT_SPEED_MPS: float = 17.0
const PROJECTILE_LIFETIME_SECONDS: float = 3.0
const PROJECTILE_HIT_RADIUS_METERS: float = 0.62
const MUZZLE_LOCAL: Vector3 = Vector3(0.0, 0.0, -0.56)

var mounts: Dictionary = {}
# The hemisphere's flat base is fixed to the belly; only its barrel swivels.
var aim_pivots: Dictionary = {}
var mount_rest_bases: Dictionary = {}
var anchors: Dictionary = {}
# Four 2x2 corners measured in the original torso mesh's own body space.
var mount_offsets: Dictionary = {}
var belly_bounds: AABB = AABB()
var projectiles: Array[Dictionary] = []
var volley_order: Array[String] = []
var volley_index: int = 0
var time_until_shot: float = 0.0
var shots_fired: int = 0
var last_fired_turret: String = ""
var last_aimed_turret: String = ""
var projectile_mesh: SphereMesh
var projectile_material: StandardMaterial3D

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
    projectile_material = muzzle_glow
    projectile_mesh = SphereMesh.new()
    projectile_mesh.radius = 0.12
    projectile_mesh.height = 0.24
    projectile_mesh.radial_segments = 10
    projectile_mesh.rings = 5
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
        var left_right: float = -1.0 if id.ends_with("l") else 1.0
        var front_back: float = -1.0 if id.begins_with("belly_f") else 1.0
        # Two rows x two columns completely beneath the belly; shrink
        # dome radius to 24cm to avoid either side poking outside torso.
        # The flat equator/base is 0..1.8cm INSIDE the underside, not
        # the dome center. This prevents a visible gap during animation.
        mount_offsets[id] = Vector3(
            belly_center.x + left_right * belly_bounds.size.x * 0.247,
            belly_bounds.position.y + belly_inset,
            belly_center.z + front_back * belly_bounds.size.z * 0.28)
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
        hemisphere.radius = 0.24
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
        # Keep the connected dome FIXED to the belly armor. Only the
        # nearest barrel assembly rotates toward the player.
        var aim_pivot := Node3D.new()
        aim_pivot.name = "TurretAim"
        aim_pivot.position.y = hemisphere.radius * 0.68
        mount.add_child(aim_pivot)
        aim_pivots[id] = aim_pivot
        var tube := CylinderMesh.new()
        tube.top_radius = 0.072
        tube.bottom_radius = 0.105
        tube.height = 0.44
        tube.radial_segments = 10
        var barrel := MeshInstance3D.new()
        barrel.name = "TurretBarrel"
        barrel.mesh = tube
        barrel.rotation.x = -PI * 0.5
        barrel.position.z = -0.31
        barrel.material_override = barrel_metal
        aim_pivot.add_child(barrel)
        var ring_mesh := CylinderMesh.new()
        ring_mesh.top_radius = 0.11
        ring_mesh.bottom_radius = 0.11
        ring_mesh.height = 0.055
        ring_mesh.radial_segments = 10
        var ring := MeshInstance3D.new()
        ring.name = "TurretMuzzle"
        ring.mesh = ring_mesh
        ring.rotation.x = -PI * 0.5
        ring.position.z = -0.55
        ring.material_override = muzzle_glow
        aim_pivot.add_child(ring)
        mounts[id] = mount
    _sync_mounts()
    reset()
    return mounts.size() == TURRET_IDS.size()

func reset() -> void:
    for projectile in projectiles:
        var node: Node3D = projectile["node"]
        if is_instance_valid(node):
            node.queue_free()
    projectiles.clear()
    volley_order.clear()
    volley_index = 0
    time_until_shot = 0.0
    shots_fired = 0
    last_fired_turret = ""
    last_aimed_turret = ""

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
    # The body is the SINGLE physical parent for all four underside
    # cannons. They must follow its final world-space pose even when
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
    # Only this barrel tracks; the other three remain aligned to their
    # animated belly, and every hemisphere base stays seated on the belly.
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
    var bolt := MeshInstance3D.new()
    bolt.name = "BellyCannonShot_" + id
    bolt.mesh = projectile_mesh
    bolt.material_override = projectile_material
    bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bolt)
    bolt.global_position = origin
    projectiles.append({
        "node": bolt,
        "position": origin,
        "direction": direction,
        "age": 0.0
    })
    last_fired_turret = id
    shots_fired += 1
    volley_index = (volley_index + 1) % TURRET_IDS.size()

func _advance_projectiles(delta: float, player_world: Vector3) -> Array[Vector3]:
    var impacts: Array[Vector3] = []
    var player_center: Vector3 = player_world + Vector3.UP * 0.90
    for i in range(projectiles.size() - 1, -1, -1):
        var bullet: Dictionary = projectiles[i]
        var old_position: Vector3 = bullet["position"]
        var direction: Vector3 = bullet["direction"]
        var destination: Vector3 = old_position + direction * (
            SHOT_SPEED_MPS * delta)
        var travel: Vector3 = destination - old_position
        var closest: Vector3 = old_position + travel * clampf(
            (player_center - old_position).dot(travel) / maxf(
                travel.length_squared(), 0.000001), 0.0, 1.0)
        var hit: bool = closest.distance_squared_to(player_center) <= (
            PROJECTILE_HIT_RADIUS_METERS * PROJECTILE_HIT_RADIUS_METERS)
        var age: float = float(bullet["age"]) + delta
        if hit or age >= PROJECTILE_LIFETIME_SECONDS:
            var node: Node3D = bullet["node"]
            if is_instance_valid(node):
                node.queue_free()
            projectiles.remove_at(i)
            if hit:
                impacts.append(direction)
        else:
            bullet["position"] = destination
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
    impacts = _advance_projectiles(step, player_world)
    time_until_shot -= step
    if time_until_shot <= 0.0:
        _fire_next(player_world)
        # No catch-up burst after a long frame or an interrupted attack.
        time_until_shot = SHOT_INTERVAL_SECONDS
    return impacts
