extends Node3D
## Arcade vehicle motion: no physics-engine wheel simulation is required.

const BASE_SPEED := 30.0
const BOOST_SPEED := 43.0
const ACCELERATION := 26.0
const TURN_RATE := 1.75
const ROAD_HALF_WIDTH := 6.1

var track: Node3D
var body_color := Color("ff647d")
var helmet_color := Color("f6f3e4")
var is_player := false
var ai_difficulty := 0.5
var lane_offset := 0.0
var heading := 0.0
var speed := 0.0
var steer_input := 0.0
var throttle_input := false
var brake_input := false
var drift_input := false
var active := false
var drift_charge := 0.0
var drifting := false
var boost_time := 0.0
var track_progress := 0.0
var lap_count := 0
var finished := false
var _last_parameter := 0.0
var _time := 0.0
var _chassis: Node3D
var _wheel_mounts: Array[Node3D] = []
var _exhausts: Array[MeshInstance3D] = []
var _spark_parts: Array[MeshInstance3D] = []
var _bounce := 0.0

func configure_spawn(t: float, side: float) -> void:
	position = track.point_at(t) + track.right_at(t) * side
	heading = track.heading_at(t)
	rotation.y = -heading
	track_progress = t
	_last_parameter = track.parameter_at(position)

func _ready() -> void:
	_build_kart()

func _mat(c: Color, metal := 0.12, bright := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.38
	if bright:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.4
	return m

func _shape(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.position = pos
	o.material_override = material
	parent.add_child(o)
	return o

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, bright := false) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _shape(parent, b, pos, _mat(color, 0.15, bright))

func _ball(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = 2.0 * radius
	m.radial_segments = 12
	m.rings = 7
	return _shape(parent, m, pos, _mat(color))

func _build_kart() -> void:
	_chassis = Node3D.new()
	_chassis.name = "SuspensionVisual"
	add_child(_chassis)
	# Kart faces local -Z; the driver wears an oversized cartoon helmet.
	_box(_chassis, Vector3(0, 0.61, 0), Vector3(1.64, 0.34, 2.70), Color("1a2740"))
	_box(_chassis, Vector3(0, 0.83, -0.41), Vector3(1.65, 0.50, 1.55), body_color)
	_box(_chassis, Vector3(0, 1.06, -0.65), Vector3(1.40, 0.14, 1.05), body_color.lightened(0.12))
	_box(_chassis, Vector3(0, 0.92, 0.66), Vector3(1.22, 0.65, 0.91), body_color.darkened(0.25))
	_box(_chassis, Vector3(0, 0.43, 1.26), Vector3(1.80, 0.19, 0.30), Color("26334d"))
	_box(_chassis, Vector3(0, 1.53, 1.22), Vector3(2.15, 0.19, 0.38), body_color)
	_box(_chassis, Vector3(0, 1.35, 1.22), Vector3(0.20, 0.38, 0.20), Color("202a46"))
	# Rim accent and pair of headlights.
	_box(_chassis, Vector3(0, 0.63, -1.38), Vector3(1.42, 0.13, 0.15), Color("ffdf8f"), true)
	for x in [-0.63, 0.63]:
		_box(_chassis, Vector3(x, 0.89, -1.29), Vector3(0.30, 0.18, 0.16), Color("f6f4db"), true)
		_box(_chassis, Vector3(x * 1.63, 0.59, 0), Vector3(0.12, 0.16, 0.34), Color("40ecf0"), true)
	# Steering column, seat and driver.
	_box(_chassis, Vector3(0, 1.15, 0.36), Vector3(0.94, 0.48, 0.79), Color("27354e"))
	_ball(_chassis, Vector3(0, 1.93, 0.36), 0.54, helmet_color)
	_box(_chassis, Vector3(0, 1.99, -0.102), Vector3(0.79, 0.23, 0.10), Color("19354b"))
	_box(_chassis, Vector3(0, 2.28, 0.21), Vector3(0.58, 0.11, 0.42), body_color)
	# Four chunky tires, each on a separate mount for steering/spinning.
	for side in [-1.0, 1.0]:
		for front in [-0.95, 0.93]:
			var mount := Node3D.new()
			mount.position = Vector3(side * 1.05, 0.49, front)
			_chassis.add_child(mount)
			var tire := CylinderMesh.new()
			tire.top_radius = 0.44
			tire.bottom_radius = 0.44
			tire.height = 0.37
			tire.radial_segments = 12
			var wheel := _shape(mount, tire, Vector3.ZERO, _mat(Color("192239"), 0.2))
			wheel.rotation.z = PI / 2.0
			var cap := CylinderMesh.new()
			cap.top_radius = 0.22
			cap.bottom_radius = 0.22
			cap.height = 0.405
			cap.radial_segments = 12
			var hub := _shape(mount, cap, Vector3.ZERO, _mat(Color("d6eaf0"), 0.75))
			hub.rotation.z = PI / 2.0
			_wheel_mounts.append(mount)
	# Neon cyan rear exhaust flames are shown only during boost.
	for x in [-0.55, 0.55]:
		_box(_chassis, Vector3(x, 0.72, 1.34), Vector3(0.36, 0.34, 0.29), Color("2b3452"))
		var flame := _box(_chassis, Vector3(x, 0.72, 1.67), Vector3(0.21, 0.20, 0.62), Color("36e9fa"), true)
		_exhausts.append(flame)
		flame.visible = false
	for x in [-0.85, 0.85]:
		var spark := _box(_chassis, Vector3(x, 0.19, 0.75), Vector3(0.16, 0.12, 0.55), Color("f8cb68"), true)
		_spark_parts.append(spark)
		spark.visible = false

func _physics_process(delta: float) -> void:
	_time += delta
	if active and not finished:
		if is_player:
			_move_player(delta)
		else:
			_move_cpu(delta)
		_apply_track_limits(delta)
		_update_progress()
	_animate(delta)

func _move_player(delta: float) -> void:
	var boosted := boost_time > 0.0
	if throttle_input:
		speed = move_toward(speed, BOOST_SPEED if boosted else BASE_SPEED, (46.0 if boosted else ACCELERATION) * delta)
	elif brake_input:
		speed = move_toward(speed, 0.0, 42.0 * delta)
	else:
		speed = move_toward(speed, 0.0, 12.0 * delta)
	if throttle_input and brake_input:
		speed = move_toward(speed, 0.0, 43.0 * delta)
	var forward_speed := clampf(absf(speed) / 13.0, 0.20, 1.0)
	var sign_value := 1.0 if speed >= 0.0 else -1.0
	var turn := TURN_RATE * (1.32 if drifting else 1.0)
	# A little road-follow assist lets the car continue through curves when the
	# player lifts their only thumb. Steering input still overrides the assist.
	var road_t: float = track.parameter_at(position)
	var aim_t := road_t + 0.14
	var aim: Vector3 = track.point_at(aim_t)
	var aim_vector := aim - position
	var road_heading := atan2(aim_vector.x, -aim_vector.z)
	var assist := 2.25 if absf(steer_input) < 0.12 else 0.65
	heading = lerp_angle(heading, road_heading, clampf(delta * assist, 0.0, 1.0))
	heading += steer_input * turn * forward_speed * sign_value * delta
	if drift_input and absf(speed) > 9.0:
		if not drifting:
			drifting = true
			drift_charge = 0.0
		drift_charge += delta * (1.0 if absf(steer_input) > 0.12 else 0.45)
	elif drifting:
		if drift_charge >= 0.65:
			add_boost(1.65 if drift_charge >= 1.65 else 0.93)
		drifting = false
		drift_charge = 0.0
	_move_forward(delta)
	boost_time = maxf(0.0, boost_time - delta)

func _move_cpu(delta: float) -> void:
	var t: float = track.parameter_at(position)
	var target: Vector3 = track.point_at(t + 0.17) + track.right_at(t + 0.17) * lane_offset
	var to_target := target - position
	var target_heading := atan2(to_target.x, -to_target.z)
	heading = lerp_angle(heading, target_heading, clampf(delta * (2.7 + ai_difficulty * 0.4), 0.0, 1.0))
	var target_speed := 22.7 + 6.5 * ai_difficulty
	if boost_time > 0.0:
		target_speed += 12.0
	speed = move_toward(speed, target_speed, 19.0 * delta)
	_move_forward(delta)
	boost_time = maxf(0.0, boost_time - delta)

func _move_forward(delta: float) -> void:
	rotation.y = -heading
	position += -global_transform.basis.z * speed * delta

func _apply_track_limits(delta: float) -> void:
	var info: Dictionary = track.road_info(position)
	var dis: float = info["distance"]
	if dis > ROAD_HALF_WIDTH:
		speed = move_toward(speed, minf(speed, 12.0), (dis - ROAD_HALF_WIDTH + 1.0) * 19.0 * delta)
	if dis > ROAD_HALF_WIDTH + 3.0:
		var target: Vector3 = info["point"]
		var to_center := Vector3(target.x - position.x, 0.0, target.z - position.z).normalized()
		position += to_center * (dis - ROAD_HALF_WIDTH - 2.8) * minf(1.0, 5.0 * delta)
		speed *= 0.95
	position.y = 0.10

func _update_progress() -> void:
	var t: float = track.parameter_at(position)
	var delta_t := wrapf(t - _last_parameter, -PI, PI)
	if absf(delta_t) < 0.5:
		track_progress = maxf(-0.2, track_progress + delta_t)
	_last_parameter = t
	lap_count = maxi(0, int(floor(track_progress / TAU)))

func add_boost(duration: float) -> void:
	boost_time = maxf(boost_time, duration)
	speed = maxf(speed, 34.5)

func _animate(delta: float) -> void:
	_bounce += absf(speed) * delta * 0.5
	_chassis.position.y = (sin(_bounce) * 0.033 if absf(speed) > 1.0 else 0.0)
	_chassis.rotation.z = lerpf(_chassis.rotation.z, -steer_input * (0.10 if drifting else 0.045), minf(1.0, delta * 8.0))
	_chassis.rotation.x = lerpf(_chassis.rotation.x, -0.05 if boost_time > 0.0 else 0.0, minf(1.0, delta * 6.0))
	for wheel in _wheel_mounts:
		wheel.rotation.x += speed * delta * 0.21
	for flame in _exhausts:
		flame.visible = boost_time > 0.0
		if flame.visible:
			flame.scale.z = 0.8 + 0.3 * sin(_time * 38.0)
	for spark in _spark_parts:
		spark.visible = drifting
		if spark.visible:
			spark.scale.z = 0.65 + 0.2 * sin(_time * 28.0)
