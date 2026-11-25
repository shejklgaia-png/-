extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var folder := args[0]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(folder.path_join("crate_candidate.glb"),state) != OK:
		quit(3)
		return
	var scene := doc.generate_scene(state)
	if scene == null:
		quit(4)
		return
	root.add_child(scene)
	var crate := scene as Node3D
	if scene.name != &"CRATE":
		crate = scene.find_child("CRATE",true,false) as Node3D
	if crate == null:
		scene.free()
		quit(5)
		return
	var results := []
	for name in ["HeadPivot","LeftArmPivot","RightArmPivot","LeftTrack","RightTrack"]:
		var pivot := crate.get_node_or_null(NodePath(name)) as Node3D
		if pivot == null:
			push_error("Missing direct CRATE node "+name)
			scene.free()
			quit(6)
			return
		results.append(check_pivot(pivot))
		if name.ends_with("ArmPivot"):
			var wrist: Node3D = null
			for child in pivot.get_children():
				if str(child.name).begins_with("WristPivot") and child is Node3D:
					wrist = child as Node3D
					break
			if wrist == null:
				scene.free()
				quit(7)
				return
			results.append(check_pivot(wrist))
	var counts := {"meshes":0,"triangles":0}
	count_meshes(crate,counts)
	for row in results:
		if not row["rotation_changed"] or not row["restored"]:
			scene.free()
			quit(9)
			return
	if counts["meshes"] <= 0 or counts["triangles"] <= 0:
		scene.free()
		quit(10)
		return
	var file := FileAccess.open(folder.path_join("crate_godot_review.json"),FileAccess.WRITE)
	if file == null:
		scene.free()
		quit(8)
		return
	file.store_string(JSON.stringify({"format":"SERA_CRATE_GODOT_REVIEW_V1","engine":Engine.get_version_info()["string"],"pivots":results,"counts":counts,"limits":"Hierarchy and local rotation checks only. Nonuniform scale, renamed wrist, game animation scripts and actual rendering require review."},"\t"))
	file.close()
	scene.free()
	print("CRATE GLB hierarchy and joint rotation inspection PASS")
	quit(0)

func check_pivot(pivot: Node3D) -> Dictionary:
	var base := pivot.transform
	var before := pivot.rotation
	pivot.rotation = before + Vector3(0.15,0.0,0.0)
	var changed := not pivot.transform.is_equal_approx(base)
	pivot.transform = base
	return {"path":str(pivot.get_path()),"scale":[pivot.scale.x,pivot.scale.y,pivot.scale.z],"rotation_changed":changed,"restored":pivot.transform.is_equal_approx(base),"wrist_name_exact":not str(pivot.name).begins_with("WristPivot") or pivot.name==&"WristPivot"}

func count_meshes(node: Node, counts: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			counts["meshes"] += 1
			for i in range(mesh.get_surface_count()):
				if mesh.surface_get_primitive_type(i) == Mesh.PRIMITIVE_TRIANGLES:
					var arr := mesh.surface_get_arrays(i)
					var indices: Variant = arr[Mesh.ARRAY_INDEX]
					var vertices: Variant = arr[Mesh.ARRAY_VERTEX]
					counts["triangles"] += int(indices.size()/3) if indices != null and indices.size() > 0 else int(vertices.size()/3)
	for child in node.get_children():
		count_meshes(child,counts)
