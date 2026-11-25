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
	var report = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("motion_report.json")))
	if not report is Dictionary:
		quit(10)
		return
	var fps := float(report["fps"])
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(dir.path_join("motion.glb"), state) != OK:
		quit(3)
		return
	var model := doc.generate_scene(state, fps, false, false)
	if model == null:
		quit(4)
		return
	root.add_child(model)
	var p := find_player(model)
	if p == null or p.get_animation_list().is_empty():
		quit(5)
		return
	var names := p.get_animation_list()
	var clips: Array[String] = []
	for n in names:
		if n != "RESET":
			clips.append(String(n))
	if clips.size() != 1:
		push_error("Expected one complete clip, found " + str(clips))
		quit(6)
		return
	var clip := clips[0]
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
	var expected_length := (float(report["end_frame"]) - 1.0) / fps
	var markers: Dictionary = {}
	for name in report["marker_nodes"]:
		var node := model.find_child(String(report["marker_nodes"][name]), true, false) as Node3D
		if node == null:
			push_error("Missing exported marker: " + String(name))
			quit(11)
			return
		markers[name] = node
	var max_error := 0.0
	var marker_errors: Dictionary = {}
	var worst_frame := 1
	var capture: Dictionary = {}
	for raw_frame in report["capture_frames"]:
		capture[int(raw_frame)] = true
	var saved: Array[int] = []
	var movie_saved: Array[int] = []
	var movie_dir := dir.path_join("movie_frames")
	if DirAccess.make_dir_recursive_absolute(movie_dir) != OK:
		quit(13)
		return
	p.play(clip)
	p.pause()
	for sample in report["samples"]:
		var frame := int(sample["frame"])
		var t := (float(frame) - 1.0) / fps
		p.seek(t, true)
		for name in markers:
			var v: Array = sample["markers"][name]
			var expected := Vector3(float(v[0]), float(v[2]), -float(v[1]))
			var marker: Node3D = markers[name]
			var error := marker.global_position.distance_to(expected)
			marker_errors[name] = maxf(float(marker_errors.get(name, 0.0)), error)
			if error > max_error:
				max_error = error
				worst_frame = frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img == null or img.is_empty() or img.save_png(movie_dir.path_join("frame_%04d.png" % frame)) != OK:
			quit(7)
			return
		movie_saved.append(frame)
		if capture.has(frame):
			if img.save_png(dir.path_join("godot_%04d.png" % frame)) != OK:
				quit(7)
				return
			saved.append(frame)
	var f := FileAccess.open(dir.path_join("godot_review.json"), FileAccess.WRITE)
	if f == null:
		quit(8)
		return
	var duration_error := absf(length - expected_length)
	var tolerance := float(spec.get("roundtrip_tolerance_m", 0.002))
	var movie_pass := movie_saved.size() == int(report["end_frame"])
	var image_pass := saved.size() == capture.size() and not saved.is_empty()
	var passed := duration_error <= 0.0002 and max_error <= tolerance and not markers.is_empty()
	f.store_string(JSON.stringify({"animations":Array(names),"clip":clip,"length_seconds":length,"expected_length_seconds":expected_length,"duration_error_s":duration_error,"frames":saved.size(),"expected_frames":capture.size(),"saved_frames":saved,"capture_pass":image_pass,"movie_capture_pass":movie_pass,"movie_frames":movie_saved,"import_bake_fps":fps,"evaluated_frames":report["samples"].size(),"marker_max_errors_m":marker_errors,"max_error_m":max_error,"worst_frame":worst_frame,"tolerance_m":tolerance,"roundtrip_pass":passed,"renderer":"gl_compatibility","scope":"isolated GLB preview; not game or Android"}, "\t"))
	f.close()
	quit(0 if passed and image_pass and movie_pass else 12)
