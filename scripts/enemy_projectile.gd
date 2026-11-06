extends Area3D
## v67: Lightweight, straight-line enemy projectile. No homing or gravity.
## Hit detection uses both a physical overlap and a swept ray, so fast frames
## cannot skip straight through the player's existing capsule collider.

signal player_hit(world_position: Vector3, travel_direction: Vector3)

const PLAYER_LAYER: int = 1
const PROJECTILE_RADIUS: float = 0.23
const MAX_LIFETIME: float = 5.0
const MAX_TRAVEL_DISTANCE: float = 36.0

var player_node: CharacterBody3D
var travel_direction: Vector3 = Vector3.FORWARD
var travel_speed: float = 12.0
var visual_variant: int = 0  # v91: 0=aimed/orange, 1=lead/cyan
var _lifetime: float = 0.0
var _travel_distance: float = 0.0
var _hit_reported: bool = false

func configure(player: CharacterBody3D, direction: Vector3, speed: float, variant: int = 0) -> void:
    player_node = player
    travel_direction = direction.normalized() if direction.length_squared() > 0.000001 else Vector3.FORWARD
    travel_speed = maxf(0.1, speed)
    visual_variant = variant

func _ready() -> void:
    collision_layer = 0  # Does not block movement or other bullets.
    collision_mask = PLAYER_LAYER
    monitoring = true
    monitorable = false

    var collision_shape := CollisionShape3D.new()
    collision_shape.name = "ProjectileCollision"
    var sphere_shape := SphereShape3D.new()
    sphere_shape.radius = PROJECTILE_RADIUS
    collision_shape.shape = sphere_shape
    add_child(collision_shape)

    var main_sphere := SphereMesh.new()
    main_sphere.radius = 0.22
    main_sphere.height = 0.44
    main_sphere.radial_segments = 10
    main_sphere.rings = 5
    var main_material := StandardMaterial3D.new()
    main_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    main_material.albedo_color = Color("70e4ff") if visual_variant == 1 else Color("ff7951")
    main_material.emission_enabled = true
    main_material.emission = Color("26a9e5") if visual_variant == 1 else Color("ff4c27")
    main_material.emission_energy_multiplier = 1.6
    var visible_sphere := MeshInstance3D.new()
    visible_sphere.name = "ProjectileCore"
    visible_sphere.mesh = main_sphere
    visible_sphere.material_override = main_material
    visible_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(visible_sphere)

    # One short, low-poly trailing ember indicates the firing direction.
    var tail_mesh := SphereMesh.new()
    tail_mesh.radius = 0.115
    tail_mesh.height = 0.23
    tail_mesh.radial_segments = 8
    tail_mesh.rings = 4
    var tail := MeshInstance3D.new()
    tail.name = "ProjectileTail"
    tail.mesh = tail_mesh
    tail.material_override = main_material
    tail.position = -travel_direction * 0.29
    tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(tail)

    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    if _hit_reported:
        return
    _lifetime += delta
    var movement: Vector3 = travel_direction * (travel_speed * delta)
    # The projectile is an Area3D: use the existing layer-1 player body as
    # the only ray target. Area collision catches near-misses of the center ray.
    var query := PhysicsRayQueryParameters3D.create(global_position, global_position + movement)
    query.collision_mask = PLAYER_LAYER
    query.collide_with_bodies = true
    query.collide_with_areas = false
    var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not result.is_empty() and result.get("collider") == player_node:
        var hit_position: Vector3 = result["position"]
        _report_hit(hit_position)
        return
    global_position += movement
    _travel_distance += movement.length()
    if _lifetime >= MAX_LIFETIME or _travel_distance >= MAX_TRAVEL_DISTANCE:
        queue_free()

func _on_body_entered(body: Node3D) -> void:
    if body == player_node:
        _report_hit(global_position)

func _report_hit(hit_position: Vector3) -> void:
    if _hit_reported:
        return  # Area callback + swept ray must not double-count a hit.
    _hit_reported = true
    player_hit.emit(hit_position, travel_direction)
    queue_free()
