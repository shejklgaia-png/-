extends Control
## Tiny course radar - drawn with CanvasItem, no texture assets needed.

var racers: Array = []
var track: Node3D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := Vector2(90, 63)
	var pts := PackedVector2Array()
	for i in range(97):
		var t := TAU * float(i) / 96.0
		pts.append(center + Vector2(cos(t) * 58.0, sin(t) * 38.0))
	draw_polyline(pts, Color("102941"), 15.0, true)
	draw_polyline(pts, Color("6e8697"), 9.0, true)
	draw_polyline(pts, Color("bdcacc"), 1.5, true)
	# Checkered start line and the live position of every racer.
	draw_line(center + Vector2(51, -5), center + Vector2(65, 5), Color.WHITE, 3.0, true)
	if track == null:
		return
	for k in racers:
		if not is_instance_valid(k):
			continue
		var t: float = track.parameter_at(k.position)
		var p := center + Vector2(cos(t) * 58.0, sin(t) * 38.0)
		if k.is_player:
			draw_circle(p, 7.3, Color("173447"))
			draw_circle(p, 5.8, Color("fff6b3"))
		else:
			draw_circle(p, 5.0, k.body_color)
