extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for child in n.get_children():
		var p := find_player(child)
		if p != null:
			return p
	return null

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var dir := args[0]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(dir.path_join("motion.glb"), state) != OK:
		quit(3)
		return
	var model := doc.generate_scene(state)
	if model == null:
		quit(4)
		return
	root.add_child(model)
	var p := find_player(model)
	if p == null or p.get_animation_list().is_empty():
		quit(5)
		return
	var names := p.get_animation_list()
	var clip := String(names[0])
	for n in names:
		if n != "RESET":
			clip = n
			break
	if clip == "RESET":
		quit(6)
		return
	var length := p.get_animation(clip).length
	var camera := Camera3D.new()
	root.add_child(camera)
	var spec = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("design.json")))
	if not spec is Dictionary:
		quit(9)
		return
	var review: Dictionary = spec.get("review", {})
	var xyz: Array = review.get("target", [0, 0, 1.25])
	var target := Vector3(float(xyz[0]), float(xyz[2]), -float(xyz[1]))
	var size := float(review.get("scale", 5.0))
	camera.position = target + Vector3(1, 0.6, 1.2) * size
	camera.look_at(target)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.make_current()
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-45, -35, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12,0.15,0.20)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	p.play(clip)
	p.pause()
	for i in range(9):
		var t := length * float(i) / 8.0
		p.seek(t, true)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img == null or img.is_empty() or img.save_png(dir.path_join("godot_%02d.png" % i)) != OK:
			quit(7)
			return
	var f := FileAccess.open(dir.path_join("godot_review.json"), FileAccess.WRITE)
	if f == null:
		quit(8)
		return
	f.store_string(JSON.stringify({"animations":Array(names),"clip":clip,"length_seconds":length,"frames":9,"renderer":"gl_compatibility","scope":"isolated GLB preview; not game or Android"}, "\t"))
	f.close()
	quit(0)
