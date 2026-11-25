extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var folder := args[0]
	var reports := {}
	for filename in ["model.glb", "model_lod.glb", "model_grouped.glb"]:
		var path: String = folder.path_join(filename)
		if not FileAccess.file_exists(path):
			if filename == "model.glb":
				quit(3)
				return
			continue
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var err := document.append_from_file(path, state)
		if err != OK:
			push_error("GLB import failed: " + path + " " + str(err))
			quit(4)
			return
		var node := document.generate_scene(state)
		if node == null:
			quit(5)
			return
		var report := {"meshes":0,"triangles":0,"surfaces":0,"nodes":[]}
		collect(node, "", report)
		node.free()
		if report["meshes"] <= 0 or report["triangles"] <= 0:
			quit(6)
			return
		reports[filename] = report
	var file := FileAccess.open(folder.path_join("godot_import.json"),FileAccess.WRITE)
	if file == null:
		quit(7)
		return
	file.store_string(JSON.stringify({"format":"SERA_GODOT_IMPORT_V1","engine":Engine.get_version_info()["string"],"files":reports}, "\t"))
	file.close()
	print("Godot GLB scene generation PASS")
	quit(0)

func collect(node: Node, parent: String, report: Dictionary) -> void:
	var path := parent + "/" + str(node.name)
	report["nodes"].append(path)
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			report["meshes"] += 1
			for i in range(mesh.get_surface_count()):
				report["surfaces"] += 1
				if mesh.surface_get_primitive_type(i) == Mesh.PRIMITIVE_TRIANGLES:
					var arr := mesh.surface_get_arrays(i)
					var indices: Variant = arr[Mesh.ARRAY_INDEX]
					var vertices: Variant = arr[Mesh.ARRAY_VERTEX]
					if indices != null and indices.size() > 0:
						report["triangles"] += int(indices.size() / 3)
					elif vertices != null:
						report["triangles"] += int(vertices.size() / 3)
	for child in node.get_children():
		collect(child, path, report)
