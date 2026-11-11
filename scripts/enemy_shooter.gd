extends Node3D
## v91: Four independently selected enemy attacks with a single 2-second
## cadence: locked aimed shot, locked velocity-leading shot, expanding 360°
## shockwave, and telegraphed forward 145° arc area.
## The debug selector may suspend the automatic cadence or force one warning.

signal projectile_hit(world_position: Vector3, travel_direction: Vector3,
    is_bullet: bool, attack_type: int)

const PROJECTILE_SCRIPT = preload("res://scripts/enemy_projectile.gd")
const AREA_SCRIPT = preload("res://scripts/enemy_area_attack.gd")
const TARGET_HALF_SIZE: float = 1.0
const TARGET_BODY_HALF_DEPTH: float = 1.70  # v239 rectangular torso along Z.
const MUZZLE_OFFSET: float = 0.30
const PLAYER_AIM_HEIGHT: float = 1.05
const SHOCKWAVE_WARNING_SECONDS: float = 0.80
const ARC_WARNING_SECONDS: float = 0.95
const MAX_LEAD_SECONDS: float = 1.75
const MAX_LEAD_DISTANCE: float = 8.0

enum FirePhase { COOLDOWN, WARNING }
enum AttackType { AIMED, LEAD, SHOCKWAVE, ARC }

@export_range(0.5, 20.0, 0.1) var fire_interval_min: float = 2.0
@export_range(0.5, 20.0, 0.1) var fire_interval_max: float = 2.0
@export_range(0.1, 3.0, 0.05) var warning_duration: float = 0.65
@export_range(1.0, 30.0, 0.5) var projectile_speed: float = 12.0
@export_range(0.1, 20.0, 0.1) var first_shot_delay: float = 2.0

var target_node: Node3D
var player_node: CharacterBody3D
var projectile_parent: Node3D
var can_fire: bool = true
var head_destroyed: bool = false  # Disable area attacks; bullet AIM remains available.
var auto_fire_enabled: bool = true
var selected_attack: int = AttackType.AIMED
var _locked_attack: int = AttackType.AIMED
var _locked_warning_duration: float = 0.65
var _phase: FirePhase = FirePhase.COOLDOWN
var _remaining: float = 2.0
var _warning_origin: Vector3 = Vector3.ZERO
var _locked_direction: Vector3 = Vector3.FORWARD
var _warning_marker: MeshInstance3D
var _warning_marker_material: StandardMaterial3D
var _pending_area: Node3D
var _last_player_position: Vector3 = Vector3.ZERO
var _measured_player_velocity: Vector3 = Vector3.ZERO
var _has_player_sample: bool = false

func _ready() -> void:
    _remaining = maxf(0.0, first_shot_delay - warning_duration)
    _build_warning_marker()

func set_head_destroyed(broken: bool) -> void:
    if head_destroyed == broken:
        return
    head_destroyed = broken
    if broken and _phase == FirePhase.WARNING             and _locked_attack >= AttackType.SHOCKWAVE:
        _cancel_warning()
        _remaining = maxf(0.0, fire_interval_min - warning_duration)

func warning_in_progress() -> bool:
    # Target movement pauses after a telegraph locks its origin and direction.
    return can_fire and _phase == FirePhase.WARNING

func set_attack_type(next_attack: int) -> void:
    if next_attack < AttackType.AIMED or next_attack > AttackType.ARC:
        return
    if selected_attack == next_attack:
        return
    selected_attack = next_attack
    _cancel_warning()
    # For an isolated debug test, discard previous attack's live hitboxes.
    if is_instance_valid(projectile_parent):
        for child in projectile_parent.get_children():
            child.queue_free()
    _remaining = 0.0  # Selecting an AUTO mode prepares its next warning promptly.

func set_auto_fire(enabled: bool) -> void:
    if auto_fire_enabled == enabled:
        return
    auto_fire_enabled = enabled
    if enabled and _phase == FirePhase.COOLDOWN:
        _remaining = 0.0

func trigger_attack() -> void:
    # FIRE performs the same telegraph as AUTO, never an unannounced instant hit.
    if not can_fire or not is_instance_valid(target_node) or not is_instance_valid(player_node):
        return
    _cancel_warning()
    _begin_warning()

func _build_warning_marker() -> void:
    _warning_marker = MeshInstance3D.new()
    _warning_marker.name = "EnemyFireWarning"
    var sphere := SphereMesh.new()
    sphere.radius = 0.27
    sphere.height = 0.54
    sphere.radial_segments = 10
    sphere.rings = 5
    _warning_marker_material = StandardMaterial3D.new()
    _warning_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _warning_marker_material.albedo_color = Color("ffb36d")
    _warning_marker_material.emission_enabled = true
    _warning_marker_material.emission = Color("f8633c")
    _warning_marker_material.emission_energy_multiplier = 1.8
    _warning_marker.mesh = sphere
    _warning_marker.material_override = _warning_marker_material
    _warning_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _warning_marker.visible = false
    add_child(_warning_marker)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(target_node) or not is_instance_valid(player_node):
        return
    _sample_player_velocity(delta)
    if not can_fire:
        _cancel_warning()
        _remaining = maxf(0.0, first_shot_delay - warning_duration)
        return
    if _phase == FirePhase.COOLDOWN and not auto_fire_enabled:
        return
    _remaining -= delta
    if _phase == FirePhase.COOLDOWN:
        if _remaining <= 0.0:
            _begin_warning()
    else:
        var progress: float = clampf(1.0 - _remaining / _locked_warning_duration, 0.0, 1.0)
        if _locked_attack <= AttackType.LEAD:
            _warning_marker.scale = Vector3.ONE * lerpf(0.68, 1.25, progress)
        elif is_instance_valid(_pending_area):
            _pending_area.call("set_warning_progress", progress)
        if _remaining <= 0.0:
            _fire_selected_attack()
            _phase = FirePhase.COOLDOWN
            _remaining = maxf(0.0, randf_range(fire_interval_min,
                maxf(fire_interval_min, fire_interval_max)) - _locked_warning_duration)
            _warning_marker.visible = false

func _sample_player_velocity(delta: float) -> void:
    var pos: Vector3 = player_node.global_position
    if _has_player_sample and delta > 0.00001:
        _measured_player_velocity = (pos - _last_player_position) / delta
        _measured_player_velocity.y = 0.0
        # A teleport or scene reset must not create implausible lead points.
        _measured_player_velocity = _measured_player_velocity.limit_length(16.0)
    else:
        _measured_player_velocity = Vector3.ZERO
    _last_player_position = pos
    _has_player_sample = true

func _warning_seconds_for(attack: int) -> float:
    if attack == AttackType.SHOCKWAVE:
        return SHOCKWAVE_WARNING_SECONDS
    if attack == AttackType.ARC:
        return ARC_WARNING_SECONDS
    return warning_duration

func _begin_warning() -> void:
    if not can_fire or not is_instance_valid(projectile_parent):
        return
    _phase = FirePhase.WARNING
    # A destroyed head cannot issue SHOCK/ARC; preserve attack cadence
    # using the existing telegraphed AIM shot instead.
    _locked_attack = AttackType.AIMED if head_destroyed and (
        selected_attack >= AttackType.SHOCKWAVE) else selected_attack
    _locked_warning_duration = _warning_seconds_for(_locked_attack)
    _remaining = _locked_warning_duration
    # Every attack's orientation is acquired at warning start and locked.
    var target_center: Vector3 = target_node.global_position
    var toward_player: Vector3 = player_node.global_position - target_center
    toward_player.y = 0.0
    if toward_player.length_squared() < 0.000001:
        toward_player = Vector3.BACK
    var facing: Vector3 = toward_player.normalized()
    # Ray/rectangle intersection: the shot originates outside whichever face
    # the warning points through, not from inside the extended body.
    var to_face: float = minf(
        TARGET_HALF_SIZE / maxf(absf(facing.x), 0.00001),
        TARGET_BODY_HALF_DEPTH / maxf(absf(facing.z), 0.00001))
    _warning_origin = target_center + facing * (to_face + MUZZLE_OFFSET)
    _warning_origin.y = player_node.global_position.y + PLAYER_AIM_HEIGHT
    var aim_point: Vector3 = player_node.global_position + Vector3.UP * PLAYER_AIM_HEIGHT
    if _locked_attack == AttackType.LEAD:
        aim_point = _calculate_lead_point(_warning_origin, aim_point, _measured_player_velocity, _locked_warning_duration)
    _locked_direction = (aim_point - _warning_origin).normalized()
    if _locked_direction.length_squared() < 0.000001:
        _locked_direction = facing
    if _locked_attack <= AttackType.LEAD:
        _warning_marker_material.albedo_color = Color("93f0ff") if _locked_attack == AttackType.LEAD else Color("ffb36d")
        _warning_marker_material.emission = Color("38bde9") if _locked_attack == AttackType.LEAD else Color("f8633c")
        _warning_marker.global_position = _warning_origin
        _warning_marker.scale = Vector3.ONE * 0.68
        _warning_marker.visible = true
    else:
        _warning_marker.visible = false
        _pending_area = AREA_SCRIPT.new()
        var area_kind: int = 0 if _locked_attack == AttackType.SHOCKWAVE else 1
        _pending_area.call("configure", area_kind, player_node, target_center, facing)
        projectile_parent.add_child(_pending_area)
        # Area attacks keep the existing impact, never the bullet sound.
        _pending_area.connect("player_hit", Callable(self, "_on_projectile_hit").bind(false, _locked_attack))

func _calculate_lead_point(origin: Vector3, player_aim: Vector3,
        player_velocity: Vector3, warn_seconds: float) -> Vector3:
    # Lead from the time of launch, which is warn_seconds into the future.
    # Solve |relative + velocity * t| = bullet_speed * t for flight time t.
    var launch_relative: Vector3 = player_aim + player_velocity * warn_seconds - origin
    var a: float = player_velocity.length_squared() - projectile_speed * projectile_speed
    var b: float = 2.0 * launch_relative.dot(player_velocity)
    var c: float = launch_relative.length_squared()
    var flight_time: float = launch_relative.length() / maxf(0.1, projectile_speed)
    if absf(a) > 0.00001:
        var discriminant: float = b * b - 4.0 * a * c
        if discriminant >= 0.0:
            var root: float = sqrt(discriminant)
            var first: float = (-b - root) / (2.0 * a)
            var second: float = (-b + root) / (2.0 * a)
            var positive_first: float = first if first > 0.0 else INF
            var positive_second: float = second if second > 0.0 else INF
            var best: float = minf(positive_first, positive_second)
            if best < INF:
                flight_time = best
    elif absf(b) > 0.00001:
        var linear_time: float = -c / b
        if linear_time > 0.0:
            flight_time = linear_time
    var lead_displacement: Vector3 = player_velocity * (warn_seconds + minf(MAX_LEAD_SECONDS, flight_time))
    return player_aim + lead_displacement.limit_length(MAX_LEAD_DISTANCE)

func _fire_selected_attack() -> void:
    if _locked_attack >= AttackType.SHOCKWAVE:
        if is_instance_valid(_pending_area):
            _pending_area.call("activate")
        _pending_area = null
    else:
        _fire_projectile()

func _fire_projectile() -> void:
    if not is_instance_valid(projectile_parent) or not is_instance_valid(player_node):
        return
    var projectile: Area3D = PROJECTILE_SCRIPT.new()
    projectile.call("configure", player_node, _locked_direction, projectile_speed, _locked_attack)
    projectile_parent.add_child(projectile)
    projectile.global_position = _warning_origin
    # Bind at spawn time: later debug selection cannot change this hit.
    projectile.connect("player_hit", Callable(self, "_on_projectile_hit").bind(true, _locked_attack))

func _cancel_warning() -> void:
    _phase = FirePhase.COOLDOWN
    if _warning_marker != null:
        _warning_marker.visible = false
    if is_instance_valid(_pending_area):
        _pending_area.queue_free()
    _pending_area = null

func _on_projectile_hit(world_position: Vector3, travel_direction: Vector3,
        is_bullet: bool, attack_type: int) -> void:
    # Attack type is captured at creation, never taken from the current debug UI.
    projectile_hit.emit(world_position, travel_direction, is_bullet, attack_type)
