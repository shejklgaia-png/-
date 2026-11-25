extends SceneTree
const CrateModel = preload("res://sera_crate_model.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var folder := args[0]
	var robot: Node3D = CrateModel.create_model()
	root.add_child(robot)
	var report := {"meshes":0,"surfaces":0,"triangles":0,"nodes":[]}
	collect(robot, "", report)
	if report["meshes"] == 0 or report["triangles"] == 0:
		robot.free()
		quit(3)
		return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(robot, state)
	if err == OK:
		err = doc.write_to_filesystem(state, folder.path_join("crate_current.glb"))
	robot.free()
	if err != OK:
		push_error("CRATE GLB export error: " + str(err))
		quit(4)
		return
	var file := FileAccess.open(folder.path_join("godot_source.json"),FileAccess.WRITE)
	if file == null:
		quit(5)
		return
	file.store_string(JSON.stringify({"format":"SERA_CRATE_BASELINE_V1","engine":Engine.get_version_info()["string"],"source":"scripts/sera_crate_model.gd:create_model","model":report}, "\t"))
	file.close()
	print("CRATE production geometry export PASS")
	quit(0)

func collect(node: Node, parent: String, report: Dictionary) -> void:
	var path := parent + "/" + str(node.name)
	report["nodes"].append(path)
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			report["meshes"] += 1
			# Only the detached export instance is changed. Ensure GLTF sees the
			# production override even on exporters that ignore material_override.
			var mesh: Mesh = instance.mesh.duplicate() as Mesh
			for i in range(mesh.get_surface_count()):
				report["surfaces"] += 1
				if instance.material_override != null:
					mesh.surface_set_material(i, instance.material_override)
				if mesh.surface_get_primitive_type(i) == Mesh.PRIMITIVE_TRIANGLES:
					var arr := mesh.surface_get_arrays(i)
					var indices: Variant = arr[Mesh.ARRAY_INDEX]
					var vertices: Variant = arr[Mesh.ARRAY_VERTEX]
					report["triangles"] += int(indices.size()/3) if indices != null and indices.size() > 0 else int(vertices.size()/3)
			instance.mesh = mesh
			instance.material_override = null
	for child in node.get_children():
		collect(child,path,report)
