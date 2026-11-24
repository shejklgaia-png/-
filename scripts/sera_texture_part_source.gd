extends RefCounted
## A read-only snapshot of one real equipment blueprint, never equips/saves.
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const SHADERS := [
    "res://shaders/sera_fullbody_material_shading.gdshader",
    "res://shaders/sera_fullbody_material_shading_closed.gdshader",
    "res://shaders/sera_fullbody_material_shading_back.gdshader"
]

static func create_rig(parent: Node3D) -> Node3D:
    var script := load("res://scripts/sera_rig.gd") as Script
    if script == null or not script.can_instantiate():
        return null
    var rig := script.new() as Node3D
    if rig == null:
        return null
    rig.name = "TextureStudioSourceRig"
    rig.visible = false
    rig.process_mode = Node.PROCESS_MODE_DISABLED
    parent.add_child(rig)
    rig.set_process(false)
    rig.set_physics_process(false)
    if not bool(rig.get("loading_ok")):
        rig.queue_free()
        return null
    # Sample the same standing pose as the equipment viewer without
    # selecting any equipment or touching its persistent selection.
    var animations: Dictionary = rig.get("animations")
    for pose in ["NEXUS_pose","NEXUSpose"]:
        if animations.has(pose) and not (animations[pose].get("tracks",{}) as Dictionary).is_empty():
            rig.set("current_clip",pose)
            rig.set("clip_time",0.0)
            rig.set("blending_for",1.0)
            rig.set("blend_duration",0.0)
            rig.call("_apply_animation",0.0)
            return rig
    return rig

static func snapshot(rig: Node3D, blueprint: String) -> Dictionary:
    if not is_instance_valid(rig) or not Catalog.valid(blueprint):
        return {"error":"パーツデータがありません"}
    var spec := Catalog.spec(blueprint)
    var handler: RefCounted = rig.get("equipment_handler")
    if handler == null:
        return {"error":"装備データを読み込めません"}
    var available: Dictionary = handler.get("available")
    var set_parts: Dictionary = available.get(str(spec.rig_set),{})
    var pieces: Array = set_parts.get(str(spec.slot),[])
    var combined := ArrayMesh.new()
    var count := 0
    var inverse := rig.global_transform.affine_inverse()
    for candidate in pieces:
        var piece := candidate as MeshInstance3D
        if not is_instance_valid(piece) or piece.mesh == null:
            continue
        # The stowed and drawn katana blades are alternative visual copies.
        # Use the physical scabbard + drawn blade, never both copies.
        if str(spec.rig_set) == "K" and (handler.get("katana_sheathed_blade_meshes") as Array).has(piece):
            continue
        if piece.skin != null:
            return {"error":"スキン付きパーツは未対応です"}
        var pose := inverse * piece.global_transform
        if absf(pose.basis.determinant()) < 0.0000001:
            return {"error":"パーツの座標変換が無効です"}
        var normal_basis := pose.basis.inverse().transposed()
        for s in range(piece.mesh.get_surface_count()):
            if piece.mesh is ArrayMesh and (piece.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
                continue
            var input: Array = piece.mesh.surface_get_arrays(s)
            var vertices: PackedVector3Array = input[Mesh.ARRAY_VERTEX]
            if vertices.is_empty():
                continue
            var material := _paint_material(piece.get_active_material(s))
            if material == null:
                return {"error":"未対応マテリアル: "+str(piece.name)}
            var normals: PackedVector3Array = input[Mesh.ARRAY_NORMAL] if input[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
            var coords: PackedVector2Array = input[Mesh.ARRAY_TEX_UV] if input[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
            var colors: PackedColorArray = input[Mesh.ARRAY_COLOR] if input[Mesh.ARRAY_COLOR] != null else PackedColorArray()
            var indices: PackedInt32Array = input[Mesh.ARRAY_INDEX] if input[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
            for i in range(vertices.size()):
                vertices[i] = pose * vertices[i]
            for i in range(normals.size()):
                normals[i] = (normal_basis * normals[i]).normalized()
            # The current shared shader uses UV scale/offset and clamp.
            # Bake those into the source UV rather than discarding them.
            for i in range(coords.size()):
                coords[i] = coords[i]*Vector2(material.uv1_scale.x,material.uv1_scale.y)+Vector2(material.uv1_offset.x,material.uv1_offset.y)
            material.uv1_scale = Vector3.ONE
            material.uv1_offset = Vector3.ZERO
            if pose.basis.determinant() < 0.0:
                if indices.is_empty():
                    for i in range(vertices.size()):
                        indices.append(i)
                for i in range(0,indices.size()-2,3):
                    var tmp := indices[i+1]
                    indices[i+1] = indices[i+2]
                    indices[i+2] = tmp
            var arrays: Array = []
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX] = vertices
            if normals.size() == vertices.size():
                arrays[Mesh.ARRAY_NORMAL] = normals
            if coords.size() == vertices.size():
                arrays[Mesh.ARRAY_TEX_UV] = coords
            if colors.size() == vertices.size():
                arrays[Mesh.ARRAY_COLOR] = colors
            if not indices.is_empty():
                arrays[Mesh.ARRAY_INDEX] = indices
            combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
            combined.surface_set_material(combined.get_surface_count()-1,material)
        count += 1
    if combined.get_surface_count() == 0:
        return {"error":"このパーツに描画可能なメッシュがありません"}
    var result := MeshInstance3D.new()
    result.name = blueprint+"_"+str(spec.name).validate_node_name()
    result.mesh = combined
    result.visible = false
    result.set_meta("texture_studio_blueprint",blueprint)
    return {"source":result,"pieces":count}

static func _paint_material(source: Material) -> StandardMaterial3D:
    if source == null:
        return StandardMaterial3D.new()
    if source is StandardMaterial3D:
        return source.duplicate() as StandardMaterial3D
    if not source is ShaderMaterial:
        return null
    var shader_material := source as ShaderMaterial
    if shader_material.shader == null or not SHADERS.has(shader_material.shader.resource_path):
        return null
    var mat := StandardMaterial3D.new()
    var texture: Variant = shader_material.get_shader_parameter("source_texture")
    if texture is Texture2D:
        mat.albedo_texture = texture
    var tint: Variant = shader_material.get_shader_parameter("source_tint")
    if tint is Color:
        mat.albedo_color = tint
    var scale_uv: Variant = shader_material.get_shader_parameter("texture_uv_scale")
    if scale_uv is Vector2:
        mat.uv1_scale = Vector3(scale_uv.x,scale_uv.y,1.0)
    var offset_uv: Variant = shader_material.get_shader_parameter("texture_uv_offset")
    if offset_uv is Vector2:
        mat.uv1_offset = Vector3(offset_uv.x,offset_uv.y,0.0)
    mat.vertex_color_use_as_albedo = bool(shader_material.get_shader_parameter("use_vertex_color"))
    mat.texture_repeat = false
    # Match the canonical game's per-mesh winding policy. Flattening all
    # pieces to two-sided exposes interior faces and changes the shading.
    match shader_material.shader.resource_path:
        "res://shaders/sera_fullbody_material_shading_closed.gdshader":
            mat.cull_mode = BaseMaterial3D.CULL_FRONT
        "res://shaders/sera_fullbody_material_shading_back.gdshader":
            mat.cull_mode = BaseMaterial3D.CULL_BACK
        _:
            mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return mat
