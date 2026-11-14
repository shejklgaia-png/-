extends CanvasLayer
## Portrait race interface with a single, continuous thumb gesture.
## The kart accelerates automatically: drag left/right to steer, hold a turn
## to drift, and drag downward to brake. No simultaneous button presses.

signal start_requested
signal restart_requested

const RadarScript = preload("res://scripts/minimap.gd")

var touch: Dictionary = {"accelerate": true, "brake": false, "steer": 0.0, "drift": false}
var touch_enabled := false
var _pointer_id := -1
var _pointer_start := Vector2.ZERO
var _pointer_current := Vector2.ZERO
var _pointer_hold := 0.0

var _root: Control
var _start_panel: Panel
var _finish_panel: Panel
var _lap_label: Label
var _time_label: Label
var _rank_label: Label
var _speed_label: Label
var _drift_label: Label
var _gesture_label: Label
var _message_label: Label
var _count_label: Label
var _finish_label: Label
var _progress_bar: ProgressBar
var _radar: Control
var _thumb_marker: Panel

func _ready() -> void:
	_root = Control.new()
	_root.name = "PortraitInterface"
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_construct_race_hud()
	_construct_gesture_pad()
	_construct_start_panel()
	_construct_finish_panel()

func _style(c: Color, stroke: Color, radius := 15) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.border_color = stroke
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	return s

func _panel(at: Vector2, dims: Vector2, color := Color(0.065, 0.11, 0.19, 0.82)) -> Panel:
	var p := Panel.new()
	p.position = at
	p.size = dims
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(color, Color("37546a")))
	_root.add_child(p)
	return p

func _label(parent: Control, txt: String, pos: Vector2, dims: Vector2, pt: int, col: Color, centered := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.size = dims
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", pt)
	l.add_theme_color_override("font_color", col)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _button(parent: Control, txt: String, pos: Vector2, dims: Vector2, col: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = dims
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_color_override("font_color", Color("fcffff"))
	b.add_theme_stylebox_override("normal", _style(col, Color("c8f5f3"), 18))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.12), Color("ffffff"), 18))
	b.add_theme_stylebox_override("pressed", _style(col.lightened(0.30), Color("ffffff"), 18))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	return b

func _pin_right(node: Control, width: float, top: float, height: float, right_margin := 14.0) -> void:
	node.anchor_left = 1.0
	node.anchor_right = 1.0
	node.offset_left = -width - right_margin
	node.offset_right = -right_margin
	node.offset_top = top
	node.offset_bottom = top + height

func _pin_center(node: Control, width: float, y_top: float, height: float, vertical_anchor := 0.5) -> void:
	node.anchor_left = 0.5
	node.anchor_right = 0.5
	node.anchor_top = vertical_anchor
	node.anchor_bottom = vertical_anchor
	node.offset_left = -width * 0.5
	node.offset_right = width * 0.5
	node.offset_top = y_top
	node.offset_bottom = y_top + height

func _construct_race_hud() -> void:
	var stats := _panel(Vector2(14, 19), Vector2(235, 100))
	_label(stats, "TURBO LOOP", Vector2(13, 7), Vector2(205, 24), 17, Color("48f0ed"))
	_lap_label = _label(stats, "LAP 1 / 3", Vector2(12, 29), Vector2(211, 38), 28, Color("f7f7ed"))
	_time_label = _label(stats, "00:00.00", Vector2(14, 67), Vector2(206, 25), 18, Color("b9d5db"))
	var speed_panel := _panel(Vector2(14, 129), Vector2(136, 75))
	_speed_label = _label(speed_panel, "0", Vector2(13, 4), Vector2(81, 60), 47, Color("fff0ab"))
	_label(speed_panel, "km/h", Vector2(77, 45), Vector2(51, 23), 13, Color("b2cbd7"))
	var rank_panel := _panel(Vector2.ZERO, Vector2(148, 55))
	_pin_right(rank_panel, 148.0, 19.0, 55.0)
	_rank_label = _label(rank_panel, "4TH / 4", Vector2(4, 3), Vector2(140, 48), 24, Color("fff2ac"), true)
	var radar_panel := _panel(Vector2.ZERO, Vector2(158, 120))
	_pin_right(radar_panel, 158.0, 84.0, 120.0)
	_radar = RadarScript.new()
	_radar.position = Vector2(-11, -6)
	_radar.size = Vector2(180, 130)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_panel.add_child(_radar)
	var drift_panel := _panel(Vector2.ZERO, Vector2(316, 60))
	_pin_center(drift_panel, 316.0, -304.0, 60.0, 1.0)
	_drift_label = _label(drift_panel, "HOLD TURN = DRIFT", Vector2(13, 3), Vector2(288, 26), 16, Color("9bd9e6"), true)
	_progress_bar = ProgressBar.new()
	_progress_bar.position = Vector2(13, 36)
	_progress_bar.size = Vector2(289, 12)
	_progress_bar.max_value = 1.65
	_progress_bar.show_percentage = false
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.add_theme_stylebox_override("background", _style(Color("1c2d45"), Color("1c2d45"), 6))
	_progress_bar.add_theme_stylebox_override("fill", _style(Color("3de1eb"), Color("3de1eb"), 6))
	drift_panel.add_child(_progress_bar)
	_message_label = _label(_root, "", Vector2.ZERO, Vector2(440, 44), 23, Color("ffec9c"), true)
	_pin_center(_message_label, 440.0, 122.0, 44.0)
	_count_label = _label(_root, "", Vector2.ZERO, Vector2(400, 155), 94, Color("fff7b5"), true)
	_pin_center(_count_label, 400.0, -83.0, 155.0)

func _construct_gesture_pad() -> void:
	var zone := _panel(Vector2.ZERO, Vector2(470, 156), Color(0.07, 0.16, 0.25, 0.53))
	_pin_center(zone, 470.0, -186.0, 156.0, 1.0)
	_label(zone, "◀", Vector2(21, 48), Vector2(70, 66), 45, Color("c7f7ff"), true)
	_label(zone, "▶", Vector2(379, 48), Vector2(70, 66), 45, Color("c7f7ff"), true)
	_label(zone, "AUTO DRIVE", Vector2(97, 11), Vector2(273, 31), 19, Color("ffe6a4"), true)
	_gesture_label = _label(zone, "DRAG LEFT / RIGHT", Vector2(100, 46), Vector2(270, 28), 19, Color("ffffff"), true)
	_label(zone, "HOLD TO DRIFT  •  PULL DOWN TO BRAKE", Vector2(49, 114), Vector2(372, 27), 12, Color("d0e3ed"), true)
	_thumb_marker = Panel.new()
	_thumb_marker.size = Vector2(54, 18)
	_thumb_marker.position = Vector2(208, 83)
	_thumb_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb_marker.add_theme_stylebox_override("panel", _style(Color("50e7ef"), Color("f0ffff"), 9))
	zone.add_child(_thumb_marker)

func _construct_start_panel() -> void:
	_start_panel = _panel(Vector2.ZERO, Vector2(450, 342), Color(0.065, 0.11, 0.19, 0.97))
	_pin_center(_start_panel, 450.0, -171.0, 342.0)
	_label(_start_panel, "T U R B O", Vector2(13, 24), Vector2(424, 64), 51, Color("42e8ee"), true)
	_label(_start_panel, "L O O P   3 D", Vector2(18, 86), Vector2(414, 52), 31, Color("ffd27b"), true)
	_label(_start_panel, "3 LAPS  /  4 RACERS", Vector2(30, 145), Vector2(390, 30), 20, Color("c1d9e6"), true)
	_label(_start_panel, "AUTO ACCEL  •  ONE-FINGER STEERING", Vector2(22, 190), Vector2(406, 28), 15, Color("b7e7ec"), true)
	var b := _button(_start_panel, "RACE START", Vector2(67, 241), Vector2(316, 76), Color("176d87"))
	b.pressed.connect(func(): start_requested.emit())

func _construct_finish_panel() -> void:
	_finish_panel = _panel(Vector2.ZERO, Vector2(450, 292), Color(0.065, 0.11, 0.19, 0.97))
	_pin_center(_finish_panel, 450.0, -146.0, 292.0)
	_finish_label = _label(_finish_panel, "FINISH!", Vector2(20, 29), Vector2(410, 141), 42, Color("fff1a2"), true)
	var b := _button(_finish_panel, "RACE AGAIN", Vector2(65, 195), Vector2(320, 71), Color("176d87"))
	b.pressed.connect(func(): restart_requested.emit())
	_finish_panel.visible = false

func _process(delta: float) -> void:
	if touch_enabled and _pointer_id != -1:
		_pointer_hold += delta
		touch["drift"] = (not touch["brake"] and absf(float(touch["steer"])) > 0.52 and _pointer_hold >= 0.34)
	elif _pointer_id == -1:
		touch["drift"] = false
	var v := float(touch["steer"])
	_thumb_marker.position.x = 208.0 + v * 155.0
	if touch["brake"]:
		_gesture_label.text = "BRAKING"
	elif touch["drift"]:
		_gesture_label.text = "DRIFT — RELEASE TO BOOST"
	else:
		_gesture_label.text = "DRAG LEFT / RIGHT"

func _input(event: InputEvent) -> void:
	if not touch_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _pointer_id == -1:
			_begin_touch(event.position, event.index)
		elif not event.pressed and _pointer_id == event.index:
			_end_touch()
	elif event is InputEventScreenDrag:
		if _pointer_id == event.index:
			_update_touch(event.position)
	# Mouse support is useful when testing the portrait project on a desktop.
	elif event is InputEventMouseButton:
		if not OS.has_feature("mobile") and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _pointer_id == -1:
				_begin_touch(event.position, -2)
			elif not event.pressed and _pointer_id == -2:
				_end_touch()
	elif event is InputEventMouseMotion:
		if not OS.has_feature("mobile") and _pointer_id == -2:
			_update_touch(event.position)

func _begin_touch(pos: Vector2, id: int) -> void:
	var screen_height := get_viewport().get_visible_rect().size.y
	if pos.y < screen_height * 0.52:
		return
	_pointer_id = id
	_pointer_start = pos
	_pointer_current = pos
	_pointer_hold = 0.0
	touch["steer"] = 0.0
	touch["brake"] = false
	touch["drift"] = false

func _update_touch(pos: Vector2) -> void:
	_pointer_current = pos
	var extent := get_viewport().get_visible_rect().size
	var movement := _pointer_current - _pointer_start
	var steer_range := maxf(72.0, extent.x * 0.19)
	touch["steer"] = clampf(movement.x / steer_range, -1.0, 1.0)
	if absf(movement.x) < 7.0:
		touch["steer"] = 0.0
	touch["brake"] = movement.y > maxf(70.0, extent.y * 0.085)
	if touch["brake"]:
		touch["drift"] = false

func _end_touch() -> void:
	_pointer_id = -1
	_pointer_hold = 0.0
	touch["steer"] = 0.0
	touch["brake"] = false
	touch["drift"] = false

func assign_racers(karts: Array, race_track: Node3D) -> void:
	_radar.racers = karts
	_radar.track = race_track

func show_start() -> void:
	touch_enabled = false
	_end_touch()
	_start_panel.visible = true
	_finish_panel.visible = false
	_count_label.text = ""

func hide_start() -> void:
	_start_panel.visible = false

func set_countdown(value: String) -> void:
	_count_label.text = value

func show_finish(place: int, seconds: float) -> void:
	touch_enabled = false
	_end_touch()
	_finish_panel.visible = true
	var rank := "1ST" if place == 1 else ("2ND" if place == 2 else ("3RD" if place == 3 else "4TH"))
	_finish_label.text = "FINISH!\n" + rank + " PLACE\n" + _time_format(seconds)
	_count_label.text = ""

func show_toast(msg: String) -> void:
	_message_label.text = msg

func set_values(lap: int, elapsed: float, rank: int, velocity: float, charge: float, boost: float) -> void:
	_lap_label.text = "LAP  %d / 3" % mini(3, maxi(1, lap))
	_time_label.text = _time_format(elapsed)
	_rank_label.text = ["1ST", "2ND", "3RD", "4TH"][clampi(rank - 1, 0, 3)] + "  /  4"
	_speed_label.text = "%d" % roundi(absf(velocity) * 3.6)
	_drift_label.text = "TURBO ACTIVE" if boost > 0.0 else ("DRIFT CHARGING" if charge > 0.0 else "HOLD TURN = DRIFT")
	_progress_bar.value = 1.65 if boost > 0.0 else clampf(charge, 0.0, 1.65)

func _time_format(v: float) -> String:
	return "%02d:%05.2f" % [int(v / 60.0), fmod(v, 60.0)]
