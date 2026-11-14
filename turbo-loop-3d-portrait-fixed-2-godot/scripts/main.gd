extends Node3D
## Main race state machine. This is an ORIGINAL kart racer, not a Nintendo game.

const TrackScript = preload("res://scripts/track.gd")
const KartScript = preload("res://scripts/kart.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const HudScript = preload("res://scripts/hud.gd")

var track: Node3D
var player: Node3D
var karts: Array = []
var pickups: Array = []
var hud: CanvasLayer
var camera: Camera3D
var phase := "ready"
var countdown := 3.0
var elapsed := 0.0
var _go_visible := 0.0
var _toast_visible := 0.0
var _previous_count := -1
var _pad_cooldowns: Dictionary = {}

func _ready() -> void:
	_register_inputs()
	_build_world()
	track = TrackScript.new()
	track.name = "Circuit"
	add_child(track)
	_build_racers()
	_build_collectibles()
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.current = true
	camera.fov = 73.0
	camera.near = 0.12
	camera.far = 350.0
	add_child(camera)
	camera.position = player.position + Vector3(0.0, 8.7, -14.0)
	hud = HudScript.new()
	hud.name = "GameHUD"
	add_child(hud)
	hud.assign_racers(karts, track)
	hud.start_requested.connect(_begin_countdown)
	hud.restart_requested.connect(_restart)
	hud.show_start()

func _bind_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = key
	InputMap.action_add_event(action, event)

func _bind_pad_button(action: String, key: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventJoypadButton.new()
	e.button_index = key
	InputMap.action_add_event(action, e)

func _bind_pad_axis(action: String, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = value
	InputMap.action_add_event(action, e)

func _register_inputs() -> void:
	_bind_key("race_accelerate", KEY_W)
	_bind_key("race_accelerate", KEY_UP)
	_bind_key("race_brake", KEY_S)
	_bind_key("race_brake", KEY_DOWN)
	_bind_key("race_left", KEY_A)
	_bind_key("race_left", KEY_LEFT)
	_bind_key("race_right", KEY_D)
	_bind_key("race_right", KEY_RIGHT)
	_bind_key("race_drift", KEY_SHIFT)
	_bind_key("race_drift", KEY_SPACE)
	_bind_key("race_start", KEY_ENTER)
	_bind_key("race_start", KEY_KP_ENTER)
	_bind_key("race_restart", KEY_R)
	_bind_pad_button("race_accelerate", JOY_BUTTON_A)
	_bind_pad_button("race_brake", JOY_BUTTON_B)
	_bind_pad_button("race_drift", JOY_BUTTON_X)
	_bind_pad_button("race_start", JOY_BUTTON_START)
	_bind_pad_axis("race_left", -1.0)
	_bind_pad_axis("race_right", 1.0)

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b8e4e4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ecf8ed")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-60.0, -45.0, 0.0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)

func _build_racers() -> void:
	var schemes := [
		[Color("fb6480"), Color("f5f0de"), -0.13, -2.4, 0.0],
		[Color("46c7f0"), Color("b7f4fd"), -0.17, 2.4, 0.93],
		[Color("ffd15d"), Color("fef2ba"), -0.27, -2.4, 0.65],
		[Color("ad91f9"), Color("e3d7fa"), -0.31, 2.4, 0.82],
	]
	for i in range(schemes.size()):
		var data: Array = schemes[i]
		var kart = KartScript.new()
		kart.name = "PLAYER" if i == 0 else "RIVAL_%d" % i
		kart.track = track
		kart.body_color = data[0]
		kart.helmet_color = data[1]
		kart.is_player = i == 0
		kart.lane_offset = data[3] if i != 0 else 0.0
		kart.ai_difficulty = data[4]
		add_child(kart)
		kart.configure_spawn(data[2], data[3])
		karts.append(kart)
	player = karts[0]

func _build_collectibles() -> void:
	for i in range(10):
		var a := 0.31 + float(i) * (TAU / 10.0)
		var orb = PickupScript.new()
		orb.name = "TurboOrb_%02d" % i
		orb.position = track.point_at(a) + track.right_at(a) * (-2.0 if i % 2 == 0 else 2.0)
		add_child(orb)
		pickups.append(orb)

func _begin_countdown() -> void:
	if phase != "ready":
		return
	phase = "countdown"
	countdown = 3.0
	_previous_count = -1
	hud.hide_start()
	hud.touch_enabled = false

func _restart() -> void:
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart()
			return
	if phase == "ready" and event.is_action_pressed("race_start"):
		_begin_countdown()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if phase != "racing":
		player.throttle_input = false
		player.brake_input = false
		player.steer_input = 0.0
		player.drift_input = false
		return
	player.throttle_input = not (Input.is_action_pressed("race_brake") or hud.touch["brake"])
	player.brake_input = Input.is_action_pressed("race_brake") or hud.touch["brake"]
	player.steer_input = clampf(
			Input.get_action_strength("race_right") + float(hud.touch["steer"])
			- Input.get_action_strength("race_left"), -1.0, 1.0)
	player.drift_input = Input.is_action_pressed("race_drift") or hud.touch["drift"]
	_check_pickups()
	_check_boost_pads(delta)
	_apply_kart_contact()

func _check_pickups() -> void:
	for item in pickups:
		for k in karts:
			if item.try_collect(k):
				if k.is_player:
					_show_toast("TURBO PICKUP!", 0.95)
					_play_sfx("pickup")
				break

func _check_boost_pads(delta: float) -> void:
	for key in _pad_cooldowns.keys():
		_pad_cooldowns[key] = maxf(0.0, _pad_cooldowns[key] - delta)
	for idx in range(track.boost_pads.size()):
		var target: Vector3 = track.boost_pads[idx]
		for k in karts:
			var id := "%d_%d" % [k.get_instance_id(), idx]
			var d := Vector2(k.position.x - target.x, k.position.z - target.z).length()
			if d < 4.4 and _pad_cooldowns.get(id, 0.0) <= 0.0:
				_pad_cooldowns[id] = 3.0
				k.add_boost(1.55)
				if k.is_player:
					_show_toast("BOOST PAD!", 0.75)
					_play_sfx("boost")

func _apply_kart_contact() -> void:
	for i in range(karts.size()):
		for j in range(i + 1, karts.size()):
			var a = karts[i]
			var b = karts[j]
			var v: Vector3 = a.position - b.position
			v.y = 0.0
			var d := v.length()
			if d > 0.01 and d < 2.15:
				var n := v / d
				var push := n * (2.15 - d) * 0.24
				a.position += push
				b.position -= push
				a.speed *= 0.992
				b.speed *= 0.992

func _show_toast(msg: String, duration: float) -> void:
	hud.show_toast(msg)
	_toast_visible = duration

func _process(delta: float) -> void:
	if phase == "countdown":
		countdown -= delta
		if countdown > 0.0:
			var value := ceili(countdown)
			hud.set_countdown(str(value))
			if value != _previous_count:
				_previous_count = value
				_play_sfx("tick")
		else:
			phase = "racing"
			for k in karts:
				k.active = true
			hud.set_countdown("GO!")
			hud.touch_enabled = true
			_go_visible = 0.8
			_play_sfx("go")
	elif phase == "racing":
		elapsed += delta
		if player.track_progress >= 3.0 * TAU:
			phase = "finished"
			for k in karts:
				k.active = false
			hud.show_finish(_player_rank(), elapsed)
			hud.touch_enabled = false
			_play_sfx("finish")
	if _go_visible > 0.0:
		_go_visible -= delta
		if _go_visible <= 0.0:
			hud.set_countdown("")
	if _toast_visible > 0.0:
		_toast_visible -= delta
		if _toast_visible <= 0.0:
			hud.show_toast("")
	hud.set_values(player.lap_count + 1, elapsed, _player_rank(), player.speed, player.drift_charge, player.boost_time)
	_update_camera(delta)

func _player_rank() -> int:
	var result := 1
	for k in karts:
		if k != player and k.track_progress > player.track_progress:
			result += 1
	return result

func _update_camera(delta: float) -> void:
	var facing := Vector3(sin(player.heading), 0.0, -cos(player.heading))
	var chase_distance := 12.4 + minf(absf(player.speed) * 0.075, 2.4)
	var desired: Vector3 = player.position - facing * chase_distance + Vector3(0, 8.7, 0)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 4.8))
	camera.look_at(player.position + facing * 7.2 + Vector3(0, 1.1, 0), Vector3.UP)
	camera.fov = lerpf(camera.fov, 79.0 if player.boost_time > 0.0 else 73.0, minf(1.0, delta * 3.4))

func _play_sfx(name: String) -> void:
	var audio := AudioStreamPlayer.new()
	audio.stream = load("res://assets/%s.wav" % name)
	audio.volume_db = -5.0
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
