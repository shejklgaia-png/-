extends Node3D
## v91: Lightweight ground-plane enemy areas. Visuals are authored as a small
## procedural triangle strip, not GPU particles. Collisions are checked against
## the swept radial interval (shockwave) or locked sector (arc) once per attack.

signal player_hit(world_position: Vector3, travel_direction: Vector3)

enum Kind { SHOCKWAVE, ARC }

const SHOCKWAVE_SPEED: float = 8.0
const SHOCKWAVE_START_RADIUS: float = 1.35
const SHOCKWAVE_MAX_RADIUS: float = 12.0
const SHOCKWAVE_HALF_WIDTH: float = 0.32
const ARC_INNER_RADIUS: float = 1.0
const ARC_OUTER_RADIUS: float = 5.5
const ARC_DEGREES: float = 145.0
const ARC_HIT_DURATION: float = 0.19
const ARC_FADE_DURATION: float = 0.26
const PLAYER_RADIUS: float = 0.40
const SEGMENTS: int = 64

var kind: Kind = Kind.SHOCKWAVE
var player_node: CharacterBody3D
var facing: Vector3 = Vector3.BACK
var warning_progress: float = 0.0
var active: bool = false
var elapsed: float = 0.0
var current_radius: float = SHOCKWAVE_START_RADIUS
var hit_sent: bool = false
var _has_last_player: bool = false
var _last_player_position: Vector3 = Vector3.ZERO
var _mesh: ImmediateMesh
var _visual: MeshInstance3D
var _material: StandardMaterial3D

func configure(attack_kind: int, player: CharacterBody3D, center: Vector3, direction: Vector3) -> void:
    kind = Kind.ARC if attack_kind == Kind.ARC else Kind.SHOCKWAVE
    player_node = player
    global_position = Vector3(center.x, 0.075, center.z)
    facing = Vector3(direction.x, 0.0, direction.z).normalized()
    if facing.length_squared() < 0.000001:
        facing = Vector3.BACK

func _ready() -> void:
    _material = StandardMaterial3D.new()
    _material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _material.no_depth_test = false
    _material.albedo_color = (Color(1.0, 0.26, 0.20, 0.30) if kind == Kind.ARC
        else Color(1.0, 0.59, 0.19, 0.30))
    _material.emission_enabled = true
    _material.emission = (Color(0.90, 0.16, 0.09) if kind == Kind.ARC
        else Color(0.95, 0.40, 0.09))
    _material.emission_energy_multiplier = 0.35
    _mesh = ImmediateMesh.new()
    _visual = MeshInstance3D.new()
    _visual.name = "TelegraphAndArea"
    _visual.mesh = _mesh
    _visual.material_override = _material
    _visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_visual)
    if is_instance_valid(player_node):
        _last_player_position = player_node.global_position
        _has_last_player = true
    _update_visual()

func set_warning_progress(progress: float) -> void:
    if active:
        return
    warning_progress = clampf(progress, 0.0, 1.0)
    if _material != null:
        var warning_color: Color = _material.albedo_color
        warning_color.a = lerpf(0.24, 0.48, warning_progress)
        _material.albedo_color = warning_color
        _material.emission_energy_multiplier = lerpf(0.25, 0.65, warning_progress)

func activate() -> void:
    if active:
        return
    active = true
    elapsed = 0.0
    current_radius = SHOCKWAVE_START_RADIUS
    _has_last_player = false  # Never sweep a player's pre-activation movement.
    if is_instance_valid(player_node):
        _last_player_position = player_node.global_position
        _has_last_player = true
    var active_color: Color = _material.albedo_color
    active_color.a = 0.82
    _material.albedo_color = active_color
    _material.emission_energy_multiplier = 1.5
    _update_visual()
    if kind == Kind.ARC:
        _check_arc_collision()
    else:
        _check_shockwave_collision(current_radius, current_radius)

func _physics_process(delta: float) -> void:
    if not active:
        return
    elapsed += maxf(0.0, delta)
    if kind == Kind.SHOCKWAVE:
        var previous_radius: float = current_radius
        current_radius = minf(SHOCKWAVE_MAX_RADIUS, current_radius + SHOCKWAVE_SPEED * delta)
        _check_shockwave_collision(previous_radius, current_radius)
        if current_radius >= SHOCKWAVE_MAX_RADIUS:
            queue_free()
            return
    else:
        if elapsed <= ARC_HIT_DURATION:
            _check_arc_collision()
        if elapsed >= ARC_FADE_DURATION:
            queue_free()
            return
        var fade_color: Color = _material.albedo_color
        fade_color.a = 0.82 * clampf((ARC_FADE_DURATION - elapsed) / ARC_FADE_DURATION, 0.0, 1.0)
        _material.albedo_color = fade_color
    _update_visual()

func _check_shockwave_collision(previous_radius: float, next_radius: float) -> void:
    if hit_sent or not is_instance_valid(player_node):
        return
    # Compare the player's current and last horizontal radii to the COMPLETE
    # ring sweep on this physics frame. An 8m/s ring cannot skip a moving body.
    var now: Vector3 = player_node.global_position
    var from_center: Vector3 = now - global_position
    from_center.y = 0.0
    var now_distance: float = from_center.length()
    var last_distance: float = now_distance
    if _has_last_player:
        var last_delta: Vector3 = _last_player_position - global_position
        last_delta.y = 0.0
        last_distance = last_delta.length()
    _last_player_position = now
    _has_last_player = true
    var low: float = maxf(0.0, previous_radius - SHOCKWAVE_HALF_WIDTH - PLAYER_RADIUS)
    var high: float = next_radius + SHOCKWAVE_HALF_WIDTH + PLAYER_RADIUS
    if minf(now_distance, last_distance) <= high and maxf(now_distance, last_distance) >= low:
        _report_hit(now, from_center)

func _check_arc_collision() -> void:
    if hit_sent or not is_instance_valid(player_node):
        return
    var offset: Vector3 = player_node.global_position - global_position
    offset.y = 0.0
    var dist: float = offset.length()
    if dist > ARC_OUTER_RADIUS + PLAYER_RADIUS or dist < ARC_INNER_RADIUS - PLAYER_RADIUS:
        return
    if dist > 0.000001:
        # A little angular tolerance matches the player's 0.4m-wide capsule.
        var angular_margin: float = asin(clampf(PLAYER_RADIUS / maxf(1.0, dist), 0.0, 1.0))
        var threshold: float = cos(deg_to_rad(ARC_DEGREES * 0.5) + angular_margin)
        if offset.normalized().dot(facing) < threshold:
            return
    _report_hit(player_node.global_position, offset)

func _report_hit(pos: Vector3, direction: Vector3) -> void:
    if hit_sent:
        return
    hit_sent = true
    direction.y = 0.0
    if direction.length_squared() < 0.000001:
        direction = facing
    player_hit.emit(pos, direction.normalized())

func _update_visual() -> void:
    if _mesh == null:
        return
    if kind == Kind.SHOCKWAVE:
        if active:
            _draw_band(maxf(0.01, current_radius - SHOCKWAVE_HALF_WIDTH), current_radius + SHOCKWAVE_HALF_WIDTH, 0.0, TAU)
        else:
            var r: float = lerpf(1.75, 2.10, warning_progress)
            _draw_band(r - 0.19, r + 0.19, 0.0, TAU)
    else:
        _draw_band(ARC_INNER_RADIUS, ARC_OUTER_RADIUS, atan2(facing.x, facing.z), deg_to_rad(ARC_DEGREES))

func _draw_band(inner_radius: float, outer_radius: float, heading: float, sweep: float) -> void:
    _mesh.clear_surfaces()
    _mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(SEGMENTS):
        var angle_a: float = heading - sweep * 0.5 + sweep * float(i) / float(SEGMENTS)
        var angle_b: float = heading - sweep * 0.5 + sweep * float(i + 1) / float(SEGMENTS)
        var inner_a := Vector3(sin(angle_a) * inner_radius, 0.0, cos(angle_a) * inner_radius)
        var outer_a := Vector3(sin(angle_a) * outer_radius, 0.0, cos(angle_a) * outer_radius)
        var inner_b := Vector3(sin(angle_b) * inner_radius, 0.0, cos(angle_b) * inner_radius)
        var outer_b := Vector3(sin(angle_b) * outer_radius, 0.0, cos(angle_b) * outer_radius)
        _mesh.surface_add_vertex(inner_a)
        _mesh.surface_add_vertex(outer_b)
        _mesh.surface_add_vertex(outer_a)
        _mesh.surface_add_vertex(inner_a)
        _mesh.surface_add_vertex(inner_b)
        _mesh.surface_add_vertex(outer_b)
    _mesh.surface_end()
