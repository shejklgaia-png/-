extends Node3D
## Four lightweight leg-mounted cannons. Authored Bittaran meshes, bones,
## attack clips and the independent dorsal railgun remain untouched.
## All four share ONE firing clock and shoot nearest leg first per volley.
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const LOWER_LEG_BONES: Dictionary = {
    "leg_fl": "FrontLowerLeg_L",
    "leg_fr": "FrontLowerLeg_R",
    "leg_rl": "RearLowerLeg_L",
    "leg_rr": "RearLowerLeg_R",
}
const SHOT_INTERVAL_SECONDS: float = 1.2
const SHOT_SPEED_MPS: float = 17.0
const PROJECTILE_LIFETIME_SECONDS: float = 3.0
const PROJECTILE_HIT_RADIUS_METERS: float = 0.62
const MUZZLE_LOCAL: Vector3 = Vector3(0.0, 0.0, -0.56)

var mounts: Dictionary = {}
var anchors: Dictionary = {}
# One bind-local point computed from each authored lower-leg armor AABB.
var mount_offsets: Dictionary = {}
var lower_bounds: Dictionary = {}
var projectiles: Array[Dictionary] = []
var volley_order: Array[String] = []
var volley_index: int = 0
var time_until_shot: float = 0.0
var shots_fired: int = 0
var last_fired_leg: String = ""
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
    for id in LEG_IDS:
        var shin: Node3D = rig.find_child(
            str(LOWER_LEG_BONES[id]), true, false) as Node3D
        if shin == null:
            push_error("Bittaran lower leg turret missing joint: " + id)
            return false
        # Scan only the ORIGINAL mesh immediately under this shin.
        # Nothing from the added cosmetic turret enters the IK AABB scan.
        var armor_bounds: AABB = _measure_shin_armor(shin)
        if not armor_bounds.has_volume():
            push_error("Bittaran lower leg turret missing armor: " + id)
            return false
        lower_bounds[id] = armor_bounds
        var center: Vector3 = armor_bounds.get_center()
        var left_right: float = -1.0 if id.ends_with("l") else 1.0
        var front_back: float = -1.0 if id.begins_with("leg_f") else 1.0
        # Sink the dome center INSIDE the upper-outer shin shell.
        # A hemisphere and barrel project from the armor; the pivot does
        # not float in space or sit on the high upper-leg joint.
        mount_offsets[id] = center + Vector3(
            left_right * armor_bounds.size.x * 0.23,
            armor_bounds.size.y * 0.32,
            front_back * armor_bounds.size.z * 0.36)
        var mount := Node3D.new()
        mount.name = "LegCannon_" + id
        # Keep the visual mount outside the authored shin subtree.
        # Existing IK measures descendant meshes, so an extra mesh as a
        # shin child would corrupt ground contact and collision data.
        mount.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
        add_child(mount)
        anchors[id] = shin
        var hemisphere := SphereMesh.new()
        hemisphere.radius = 0.29
        hemisphere.height = 0.58
        hemisphere.is_hemisphere = true
        hemisphere.radial_segments = 12
        hemisphere.rings = 6
        var dome := MeshInstance3D.new()
        dome.name = "TurretHemisphere"
        dome.mesh = hemisphere
        dome.material_override = armor
        mount.add_child(dome)
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
        mount.add_child(barrel)
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
        mount.add_child(ring)
        mounts[id] = mount
    _sync_mounts()
    reset()
    return mounts.size() == LEG_IDS.size()

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
    last_fired_leg = ""

func _sort_volley_by_distance(player_world: Vector3) -> void:
    volley_order = LEG_IDS.duplicate()
    for i in range(volley_order.size()):
        for j in range(i + 1, volley_order.size()):
            var first: Node3D = mounts[volley_order[i]]
            var second: Node3D = mounts[volley_order[j]]
            if second.global_position.distance_squared_to(player_world) < (
                    first.global_position.distance_squared_to(player_world)):
                var swap: String = volley_order[i]
                volley_order[i] = volley_order[j]
                volley_order[j] = swap

## Read real imported mesh points in shin-local coordinates. AABB centers
## remain invariant through IK/animations because vertices are bind-local.
func _measure_shin_armor(shin: Node3D) -> AABB:
    var bounds := AABB()
    var found: bool = false
    for child in shin.get_children():
        if not child is MeshInstance3D:
            continue
        var part: MeshInstance3D = child as MeshInstance3D
        if part.mesh == null:
            continue
        var box: AABB = part.mesh.get_aabb()
        for i in range(8):
            var point: Vector3 = part.transform * box.get_endpoint(i)
            if not found:
                bounds = AABB(point, Vector3.ZERO)
                found = true
            else:
                bounds = bounds.expand(point)
    return bounds

func _sync_mounts() -> void:
    for id in LEG_IDS:
        var shin: Node3D = anchors[id]
        var mount: Node3D = mounts[id]
        mount.global_position = shin.to_global(mount_offsets[id])
        # While idle/disabled, the cannon rests with the rotating shin.
        # Active aim rotates the turret in world space after the skin
        # attachment point has been refreshed.
        mount.global_basis = shin.global_basis.orthonormalized()

func _aim_cannons(player_world: Vector3) -> void:
    _sync_mounts()
    var aim: Vector3 = player_world + Vector3.UP * 0.90
    for id in LEG_IDS:
        var mount: Node3D = mounts[id]
        var to_target: Vector3 = aim - mount.global_position
        if to_target.length_squared() < 0.001:
            continue
        var up: Vector3 = (
            Vector3.FORWARD if absf(to_target.normalized().dot(Vector3.UP)) > 0.98
            else Vector3.UP)
        mount.look_at(aim, up)

func _fire_next(player_world: Vector3) -> void:
    if volley_index == 0:
        _sort_volley_by_distance(player_world)
    var id: String = volley_order[volley_index]
    var mount: Node3D = mounts[id]
    var origin: Vector3 = mount.to_global(MUZZLE_LOCAL)
    var toward: Vector3 = player_world + Vector3.UP * 0.90 - origin
    var direction: Vector3 = (
        toward.normalized() if toward.length_squared() > 0.00001
        else -mount.global_basis.z.normalized())
    var bolt := MeshInstance3D.new()
    bolt.name = "LegCannonShot_" + id
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
    last_fired_leg = id
    shots_fired += 1
    volley_index = (volley_index + 1) % LEG_IDS.size()

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
    if mounts.size() != LEG_IDS.size():
        return impacts
    # Pose update MUST continue during stomp/sweep/kick and down, even
    # though all firing and in-flight bullets are cancelled then.
    _sync_mounts()
    if not active:
        reset()
        return impacts
    var step: float = maxf(delta, 0.0)
    _aim_cannons(player_world)
    impacts = _advance_projectiles(step, player_world)
    time_until_shot -= step
    if time_until_shot <= 0.0:
        _fire_next(player_world)
        # No catch-up burst after a long frame or an interrupted attack.
        time_until_shot = SHOT_INTERVAL_SECONDS
    return impacts
