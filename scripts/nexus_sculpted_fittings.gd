extends RefCounted
const StaticBake = preload("res://scripts/sera_static_bake.gd")
## Sculpted NEXUS fittings. Three actual ArrayMesh profiles (not boxes):
## annular fan intakes, bent hydraulic actuators and hollow swept fairings.
## Profile geometry is shared by all instances, with opaque, depth-tested
## MultiMesh batches and no extra lights, canvases or runtime updates.
##
## Original Blockbench modules own touch targets, mesh IDs and contours.
## These details are visual occluders only and must not enter the ID pass.

const STEEL: Color = Color("#536e80")
const LIP: Color = Color("#a5bdcc")
const RECESS: Color = Color("#283f51")
const HIGHLIGHT: Color = Color("#d4e2e9")


static func build(room: Node3D, system_at: Vector3,
        training_at: Vector3, gate_at: Vector3, gate_yaw: float, gate_scale: float = 1.0) -> void:
    var bake_path := StaticBake.cache_path("nexusfittings", ["res://scripts/nexus_sculpted_fittings.gd"], [system_at, training_at, gate_at, gate_yaw, gate_scale])
    var baked := StaticBake.load_scene(bake_path, "NexusSculptedFittings")
    if baked != null:
        room.add_child(baked)
        return
    _build_original(room, system_at, training_at, gate_at, gate_yaw, gate_scale)
    var root := room.get_node_or_null("NexusSculptedFittings") as Node3D
    if root != null:
        StaticBake.save_scene(bake_path, root)

static func _build_original(room: Node3D, system_at: Vector3,
        training_at: Vector3, gate_at: Vector3, gate_yaw: float, gate_scale: float = 1.0) -> void:
    var batches: Dictionary = {}
    # SYSTEM already has an animated cooling rotor and housing. Keep only
    # the TRAINING lower impeller; remove the overlapping open side fairings
    # that read as broken loose cables across the front of both consoles.
    _place(batches, "impeller", "steel", training_at, deg_to_rad(-14.0),
        Vector3(0.25, 0.63, 0.710), Vector3(0.43, 0.43, 0.43))

    # Gate side fittings are now integral to the authored pillar armor.
    # Archive tower's side-mounted thermal spines are swept, hollow
    # castings; they do not cover the data displays or SERA wordmark.
    for side in [-1.0, 1.0]:
        for level in [2.35, 3.61, 4.87]:
            _place(batches, "fairing", "steel",
                Vector3(side * 1.075, float(level), -12.45),
                0.0, Vector3.ZERO, Vector3(0.34, 0.94, 0.44),
                side < 0.0)
    _flush(room, batches)


static func _place(batches: Dictionary, profile: String, finish: String,
        origin: Vector3, yaw: float, offset: Vector3, size: Vector3,
        flip: bool = false) -> void:
    var basis := Basis(Vector3.UP, yaw)
    var rotation := basis
    if flip:
        rotation = rotation * Basis(Vector3.FORWARD, PI)
    var transform := Transform3D(rotation.scaled_local(size),
        origin + basis * offset)
    var key: String = profile + ":" + finish
    var group: Array = batches.get(key, [])
    group.append(transform)
    batches[key] = group


static func _impeller_mesh() -> ArrayMesh:
    # 16-sided deep annular casting with two real bevels and an open throat.
    # Seven pitched rotor blades sit recessed INSIDE the metal rim.
    var faces: Array = []
    var count: int = 16
    for i in range(count):
        var a: float = TAU * float(i) / float(count)
        var b: float = TAU * float(i + 1) / float(count)
        var u := Vector2(cos(a), sin(a))
        var v := Vector2(cos(b), sin(b))
        var back_a := Vector3(u.x * 0.49, u.y * 0.49, -0.11)
        var back_b := Vector3(v.x * 0.49, v.y * 0.49, -0.11)
        var shoulder_a := Vector3(u.x * 0.52, u.y * 0.52, 0.075)
        var shoulder_b := Vector3(v.x * 0.52, v.y * 0.52, 0.075)
        var lip_a := Vector3(u.x * 0.43, u.y * 0.43, 0.169)
        var lip_b := Vector3(v.x * 0.43, v.y * 0.43, 0.169)
        var throat_a := Vector3(u.x * 0.31, u.y * 0.31, 0.155)
        var throat_b := Vector3(v.x * 0.31, v.y * 0.31, 0.155)
        var inlet_a := Vector3(u.x * 0.29, u.y * 0.29, -0.15)
        var inlet_b := Vector3(v.x * 0.29, v.y * 0.29, -0.15)
        _quad(faces, back_a, back_b, shoulder_b, shoulder_a, RECESS)
        _quad(faces, shoulder_a, shoulder_b, lip_b, lip_a,
            LIP if i % 4 == 0 else STEEL)
        _quad(faces, lip_a, lip_b, throat_b, throat_a, HIGHLIGHT)
        _quad(faces, throat_a, throat_b, inlet_b, inlet_a, RECESS)
    for i in range(7):
        var a: float = TAU * float(i) / 7.0
        var b: float = a + 0.51
        var p := Vector3(cos(a) * 0.088, sin(a) * 0.088, -0.085)
        var q := Vector3(cos(a + 0.18) * 0.258,
            sin(a + 0.18) * 0.258, -0.12)
        var r := Vector3(cos(b) * 0.27, sin(b) * 0.27, -0.019)
        var s := Vector3(cos(b - 0.17) * 0.095,
            sin(b - 0.17) * 0.095, -0.010)
        _quad(faces, p, q, r, s, LIP if i % 2 == 0 else STEEL)
    # Small faceted hub rather than a flat disc decal.
    for i in range(10):
        var a: float = TAU * float(i) / 10.0
        var b: float = TAU * float(i + 1) / 10.0
        _tri(faces, Vector3(0, 0, 0.058),
            Vector3(cos(a) * 0.103, sin(a) * 0.103, 0.006),
            Vector3(cos(b) * 0.103, sin(b) * 0.103, 0.006),
            HIGHLIGHT)
    return _mesh(faces)


static func _actuator_mesh() -> ArrayMesh:
    # A tapered, S-curved 10-sided piston, not a stretched cube or cylinder
    # primitive. Local Y is the axis; stepped collars use the SAME surface.
    var faces: Array = []
    var sections: int = 20
    var radial: int = 10
    for j in range(sections):
        var t0: float = float(j) / float(sections)
        var t1: float = float(j + 1) / float(sections)
        for i in range(radial):
            var a: float = TAU * float(i) / float(radial)
            var b: float = TAU * float(i + 1) / float(radial)
            var col: Color = HIGHLIGHT if j in [3, 4, 15, 16] else STEEL
            if j % 5 == 0:
                col = LIP
            _quad(faces,
                _actuator_ring(t0, a), _actuator_ring(t0, b),
                _actuator_ring(t1, b), _actuator_ring(t1, a), col)
    for side in [-1.0, 1.0]:
        var end_t: float = 0.0 if side < 0 else 1.0
        var y: float = end_t - 0.5
        for i in range(radial):
            var a: float = TAU * float(i) / float(radial)
            var b: float = TAU * float(i + 1) / float(radial)
            _tri(faces, Vector3(0, y, 0),
                _actuator_ring(end_t, a), _actuator_ring(end_t, b),
                RECESS)
    return _mesh(faces)


static func _actuator_ring(t: float, angle: float) -> Vector3:
    var x: float = 0.105 * sin(t * PI * 1.36)
    var z: float = 0.055 * cos(t * TAU)
    var collar: bool = t < 0.17 or t > 0.83
    var radius: float = 0.205 if collar else 0.137
    if t > 0.22 and t < 0.78:
        radius = 0.139 - 0.018 * sin(t * PI)
    return Vector3(x + cos(angle) * radius,
        t - 0.5, z + sin(angle) * radius)


static func _fairing_mesh() -> ArrayMesh:
    # Swept armor fins curve in BOTH width and depth. Twin physical lips
    # leave an open channel down the middle (no central face filling it).
    var faces: Array = []
    var segments: int = 12
    for i in range(segments):
        var t0: float = float(i) / float(segments)
        var t1: float = float(i + 1) / float(segments)
        for side in [-1.0, 1.0]:
            var p0: Array[Vector3] = _fairing_section(t0, side)
            var p1: Array[Vector3] = _fairing_section(t1, side)
            _quad(faces, p0[0], p1[0], p1[1], p0[1],
                LIP if i in [2, 9] else STEEL)
            _quad(faces, p0[1], p1[1], p1[2], p0[2], HIGHLIGHT)
            _quad(faces, p0[2], p1[2], p1[3], p0[3], RECESS)
            _quad(faces, p0[3], p1[3], p1[0], p0[0], RECESS)
    return _mesh(faces)


static func _fairing_section(t: float, side: float) -> Array[Vector3]:
    var y: float = t - 0.5
    var swell: float = pow(maxf(0.0, sin(t * PI)), 0.72)
    var outer: float = 0.26 + 0.25 * swell
    var inner: float = 0.115 + 0.09 * swell
    var bow: float = 0.09 + 0.16 * swell + 0.06 * sin(2.0 * PI * t)
    return [
        Vector3(side * outer, y, bow - 0.09),
        Vector3(side * outer * 0.86, y, bow + 0.09),
        Vector3(side * inner, y, bow + 0.125),
        Vector3(side * inner, y, bow - 0.085)
    ]


static func _tri(faces: Array, a: Vector3, b: Vector3,
        c: Vector3, tint: Color) -> void:
    faces.append([a, b, c, tint])


static func _quad(faces: Array, a: Vector3, b: Vector3,
        c: Vector3, d: Vector3, tint: Color) -> void:
    _tri(faces, a, b, c, tint)
    _tri(faces, a, c, d, tint)


static func _mesh(faces: Array) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    for face in faces:
        var normal: Vector3 = (face[1] - face[0]).cross(
            face[2] - face[0]).normalized()
        for i in range(3):
            vertices.append(face[i])
            normals.append(normal)
            colors.append(face[3])
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


static func _flush(room: Node3D, batches: Dictionary) -> void:
    var meshes: Dictionary = {
        "impeller": _impeller_mesh(),
        "actuator": _actuator_mesh(),
        "fairing": _fairing_mesh()
    }
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.albedo_color = Color("#cedde6")
    material.metallic = 0.58
    material.roughness = 0.37
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var pale := material.duplicate() as StandardMaterial3D
    pale.albedo_color = Color("#ecf6fa")
    var root := Node3D.new()
    root.name = "NexusSculptedFittings"
    room.add_child(root)
    for key_value in batches.keys():
        var key: String = String(key_value)
        var fields: PackedStringArray = key.split(":")
        var transforms: Array = batches[key]
        var batch := MultiMesh.new()
        batch.transform_format = MultiMesh.TRANSFORM_3D
        batch.mesh = meshes[fields[0]]
        batch.instance_count = transforms.size()
        for i in range(transforms.size()):
            batch.set_instance_transform(i, transforms[i])
        var node := MultiMeshInstance3D.new()
        node.name = "Sculpture_" + fields[0] + "_" + fields[1]
        node.multimesh = batch
        node.material_override = pale if fields[1] == "pale" else material
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.set_meta("sera_outline_occluder_only", true)
        node.set_meta("FX_NO_OUTLINE", true)
        root.add_child(node)
