extends Node3D
## Procedurally generated low-poly island circuit. All geometry is native Godot Mesh3D.

const RX := 43.0
const RZ := 31.0
const ROAD_HALF_WIDTH := 6.1
const SEGMENTS := 360

var boost_pads: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 193724
	_build_land()
	_build_road()
	_build_direction_arrows()
	_build_guardrails()
	_build_start_gate()
	_build_scenery()
	_build_boost_pads()

func point_at(t: float) -> Vector3:
	return Vector3(RX * cos(t), 0.07, RZ * sin(t))

func tangent_at(t: float) -> Vector3:
	return Vector3(-RX * sin(t), 0.0, RZ * cos(t)).normalized()

func right_at(t: float) -> Vector3:
	var v := tangent_at(t)
	return Vector3(v.z, 0.0, -v.x)

func heading_at(t: float) -> float:
	var v := tangent_at(t)
	return atan2(v.x, -v.z)

func parameter_at(p: Vector3) -> float:
	var a := atan2(p.z / RZ, p.x / RX)
	for i in range(5):
		var px := RX * cos(a)
		var pz := RZ * sin(a)
		var vx := -RX * sin(a)
		var vz := RZ * cos(a)
		var ax := -RX * cos(a)
		var az := -RZ * sin(a)
		var f := (px - p.x) * vx + (pz - p.z) * vz
		var df := vx * vx + vz * vz + (px - p.x) * ax + (pz - p.z) * az
		if absf(df) > 0.001:
			a -= clampf(f / df, -0.24, 0.24)
	return fposmod(a, TAU)

func road_info(p: Vector3) -> Dictionary:
	var t := parameter_at(p)
	var closest := point_at(t)
	return {"t": t, "point": closest, "distance": Vector2(p.x - closest.x, p.z - closest.z).length()}

func _material(color: Color, metallic := 0.0, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.84 if not glow else 0.33
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.9
	return m

func _box(name: String, pos: Vector3, size: Vector3, color: Color, yaw := 0.0, glow := false) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.name = name
	var b := BoxMesh.new()
	b.size = size
	o.mesh = b
	o.material_override = _material(color, 0.1, glow)
	o.position = pos
	o.rotation.y = yaw
	add_child(o)
	return o

func _build_land() -> void:
	var plane := MeshInstance3D.new()
	plane.name = "GrassField"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(260, 260)
	plane.mesh = mesh
	plane.position.y = -0.17
	plane.material_override = _material(Color("80cb81"))
	add_child(plane)
	# A raised center island makes the racecourse legible from the chase camera.
	var island := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 16.0
	sphere.height = 2.4
	sphere.radial_segments = 16
	sphere.rings = 4
	island.mesh = sphere
	island.material_override = _material(Color("68b978"))
	island.position.y = -0.75
	add_child(island)

func _vertex(st: SurfaceTool, p: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(p)

func _strip(name: String, left_edge: float, right_edge: float, height: float, color: Color, alternate := -1, step_group := 6) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS):
		if alternate >= 0 and int(i / step_group) % 2 != alternate:
			continue
		var t0 := TAU * float(i) / float(SEGMENTS)
		var t1 := TAU * float(i + 1) / float(SEGMENTS)
		var p0 := point_at(t0) + Vector3.UP * height
		var p1 := point_at(t1) + Vector3.UP * height
		var r0 := right_at(t0)
		var r1 := right_at(t1)
		var a := p0 + r0 * left_edge
		var b := p0 + r0 * right_edge
		var c := p1 + r1 * left_edge
		var d := p1 + r1 * right_edge
		# Triangle winding deliberately points upward on the XZ plane.
		_vertex(st, a)
		_vertex(st, c)
		_vertex(st, b)
		_vertex(st, b)
		_vertex(st, c)
		_vertex(st, d)
	var m := MeshInstance3D.new()
	m.name = name
	m.mesh = st.commit()
	m.material_override = _material(color)
	add_child(m)

func _build_road() -> void:
	_strip("DarkShoulder", -7.5, 7.5, 0.01, Color("5b646a"))
	_strip("WarmAsphalt", -ROAD_HALF_WIDTH, ROAD_HALF_WIDTH, 0.035, Color("323d4a"))
	_strip("PaleEdgeLeft", -6.00, -5.87, 0.052, Color("f8f2d0"))
	_strip("PaleEdgeRight", 5.87, 6.00, 0.052, Color("f8f2d0"))
	_strip("CurbLeftWhite", -6.95, -6.08, 0.065, Color("f8f7e8"), 0)
	_strip("CurbLeftCoral", -6.95, -6.08, 0.066, Color("ff687b"), 1)
	_strip("CurbRightWhite", 6.08, 6.95, 0.065, Color("f8f7e8"), 0)
	_strip("CurbRightCoral", 6.08, 6.95, 0.066, Color("ff687b"), 1)
	_strip("BrokenCenterStripe", -0.11, 0.11, 0.059, Color("f6e5a7"), 0, 9)
	_strip("LaneLeftDash", -3.18, -3.05, 0.060, Color("8ea9bd"), 0, 12)
	_strip("LaneRightDash", 3.05, 3.18, 0.060, Color("8ea9bd"), 0, 12)
	# Finish stripe sits across the track at t=0.
	for j in range(12):
		var x := -6.0 + (float(j) + 0.5)
		var t0 := 0.0
		var p := point_at(t0) + right_at(t0) * x + Vector3.UP * 0.075
		_box("StartGrid", p, Vector3(0.93, 0.02, 0.75), Color.WHITE if j % 2 == 0 else Color("253648"), -heading_at(t0))

func _build_direction_arrows() -> void:
	# Flat white arrows indicate the direction of travel along the asphalt.
	for i in range(20):
		var t := 0.2 + TAU * float(i) / 20.0
		var arrow := MeshInstance3D.new()
		arrow.name = "RoadDirectionArrow"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Forward means local -Z. All arrow surfaces face up.
		_vertex(st, Vector3(-0.27, 0.0, -0.55))
		_vertex(st, Vector3(-0.27, 0.0, 1.25))
		_vertex(st, Vector3(0.27, 0.0, -0.55))
		_vertex(st, Vector3(0.27, 0.0, -0.55))
		_vertex(st, Vector3(-0.27, 0.0, 1.25))
		_vertex(st, Vector3(0.27, 0.0, 1.25))
		_vertex(st, Vector3(-0.96, 0.0, -0.4))
		_vertex(st, Vector3(0.96, 0.0, -0.4))
		_vertex(st, Vector3(0.0, 0.0, -1.82))
		arrow.mesh = st.commit()
		arrow.material_override = _material(Color("f2f3e3"))
		arrow.position = point_at(t) + Vector3.UP * 0.09
		arrow.rotation.y = -heading_at(t)
		add_child(arrow)

func _build_guardrails() -> void:
	# Railing on both shoulders, leaving a clear, wide racing surface.
	for i in range(72):
		var t := TAU * float(i) / 72.0
		if t < 0.09 or t > TAU - 0.09:
			continue
		for side in [-1.0, 1.0]:
			var edge: Vector3 = point_at(t) + right_at(t) * float(side) * 8.55
			_box("TrackBarrier", edge + Vector3.UP * 0.37, Vector3(0.17, 0.40, 3.65), Color("d7e8ea"), -heading_at(t))
			if i % 3 == 0:
				_box("BarrierPost", edge + Vector3.UP * 0.42, Vector3(0.38, 0.84, 0.42), Color("39556b"), -heading_at(t))

func _build_start_gate() -> void:
	var t := 0.0
	var center := point_at(t)
	var sideways := right_at(t)
	for side in [-1.0, 1.0]:
		_box("GatePillar", center + sideways * side * 8.8 + Vector3(0, 2.75, 0), Vector3(0.62, 5.6, 0.72), Color("13263d"))
		_box("PillarLight", center + sideways * side * 8.8 + Vector3(0, 2.75, -0.41), Vector3(0.12, 4.7, 0.11), Color("26e7eb"), 0.0, true)
	_box("OverheadBanner", center + Vector3(0, 5.45, 0), Vector3(18.2, 1.25, 0.90), Color("182641"))
	_box("BannerGlow", center + Vector3(0, 4.85, -0.51), Vector3(17.3, 0.10, 0.08), Color("f8bf5d"), 0.0, true)
	var tag := Label3D.new()
	tag.name = "TURBO LOOP banner"
	tag.text = "T U R B O   L O O P"
	tag.font_size = 72
	tag.pixel_size = 0.008
	tag.modulate = Color("fff5e1")
	tag.outline_modulate = Color("12233e")
	tag.position = center + Vector3(0, 5.55, -0.51)
	add_child(tag)

func _tree(at: Vector3, scale_value: float, leafy_color: Color) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18 * scale_value
	trunk_mesh.bottom_radius = 0.28 * scale_value
	trunk_mesh.height = 2.0 * scale_value
	trunk.mesh = trunk_mesh
	trunk.material_override = _material(Color("885d56"))
	trunk.position = at + Vector3(0, 0.86 * scale_value, 0)
	add_child(trunk)
	for j in range(2):
		var leaves := MeshInstance3D.new()
		var crown := SphereMesh.new()
		crown.radius = (1.3 if j == 0 else 0.94) * scale_value
		crown.height = (2.7 if j == 0 else 2.2) * scale_value
		crown.radial_segments = 7
		crown.rings = 3
		leaves.mesh = crown
		leaves.material_override = _material(leafy_color)
		leaves.position = at + Vector3(0, (2.6 + j * 1.0) * scale_value, 0)
		add_child(leaves)

func _build_scenery() -> void:
	for i in range(98):
		var p := Vector3(_rng.randf_range(-109.0, 109.0), 0.0, _rng.randf_range(-109.0, 109.0))
		if road_info(p)["distance"] < 11.5 or p.length() < 8.0:
			continue
		var s := _rng.randf_range(0.95, 2.25)
		var greens := [Color("36a88a"), Color("4aaf9f"), Color("49b67e"), Color("74c39b")]
		_tree(p, s, greens[i % greens.size()])
	# Distant low-poly cliffs hide the end of the ground plane.
	for i in range(18):
		var t := TAU * float(i) / 18.0
		var cliff := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.8
		cone.bottom_radius = _rng.randf_range(12.0, 22.0)
		cone.height = _rng.randf_range(14.0, 31.0)
		cone.radial_segments = 6
		cliff.mesh = cone
		cliff.material_override = _material(Color("8ccac3") if i % 2 == 0 else Color("65b6b1"))
		cliff.position = Vector3(cos(t) * 129.0, -2.0, sin(t) * 129.0)
		add_child(cliff)
	for i in range(13):
		var cloud := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = _rng.randf_range(4.0, 8.0)
		sphere.height = _rng.randf_range(2.0, 4.0)
		sphere.radial_segments = 8
		sphere.rings = 4
		cloud.mesh = sphere
		cloud.material_override = _material(Color("f2f9f0"))
		cloud.position = Vector3(_rng.randf_range(-120, 120), _rng.randf_range(28, 43), _rng.randf_range(-120, 120))
		add_child(cloud)
	# Center island landmark: huge mascot sphere under a glowing antenna.
	var globe := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 4.0
	orb.height = 8.0
	orb.radial_segments = 12
	globe.mesh = orb
	globe.material_override = _material(Color("ffcd72"))
	globe.position = Vector3(0, 4.3, 0)
	add_child(globe)
	_box("IslandMonumentBase", Vector3(0, 0.7, 0), Vector3(8.0, 1.6, 8.0), Color("254760"))
	_box("IslandMonumentBand", Vector3(0, 1.5, 0), Vector3(8.3, 0.24, 8.3), Color("27e0ea"), 0, true)

func _build_boost_pads() -> void:
	for t in [0.85, 2.88, 4.86]:
		var p := point_at(t) + right_at(t) * 0.7
		boost_pads.append(p)
		_box("BoostPadBase", p + Vector3(0, 0.082, 0), Vector3(7.5, 0.03, 3.8), Color("143c59"), -heading_at(t))
		for offset in [-2.6, -0.85, 0.85, 2.6]:
			_box("BoostPadLight", p + right_at(t) * offset + Vector3(0, 0.114, 0), Vector3(0.40, 0.035, 2.9), Color("28e6f2"), -heading_at(t), true)
