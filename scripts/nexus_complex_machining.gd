extends RefCounted
const StaticBake = preload("res://scripts/sera_static_bake.gd")
## NEXUS secondary machined detail. Each profile is one reusable ArrayMesh;
## instances are batched by profile/finish, not by individual decorative part.
## Opaque depth-tested geometry only. Never participates in selection/ID edges.
##
## World-space anchors follow the eight authored NEXUS modules, without
## changing Blockbench masters or their interaction silhouettes.

static func build(room: Node3D, system_at: Vector3, training_at: Vector3,
        gate_at: Vector3, gate_yaw: float, gate_scale: float = 1.0) -> void:
    var bake_path := StaticBake.cache_path("nexusmachining", ["res://scripts/nexus_complex_machining.gd"], [system_at, training_at, gate_at, gate_yaw, gate_scale])
    var baked := StaticBake.load_scene(bake_path, "NexusComplexMachining")
    if baked != null:
        room.add_child(baked)
        return
    _build_original(room, system_at, training_at, gate_at, gate_yaw, gate_scale)
    var root := room.get_node_or_null("NexusComplexMachining") as Node3D
    if root != null:
        StaticBake.save_scene(bake_path, root)

static func _build_original(room: Node3D, system_at: Vector3, training_at: Vector3,
        gate_at: Vector3, gate_yaw: float, gate_scale: float = 1.0) -> void:
    var batches: Dictionary = {}
    # A circular maintenance mechanism with separate serrated drive race,
    # alternating fixing shoes and a shallow inlaid floating inner crown.
    _part(batches, "toothed_race", "steel", Vector3(0, 7.06, -4.75),
        Vector3(1.0, 1.0, 1.0))
    _part(batches, "inset_race", "pale", Vector3(0, 7.015, -4.75),
        Vector3(0.83, 0.80, 0.83))
    for i in range(12):
        var theta: float = TAU * float(i) / 12.0
        var r: float = 1.52
        _part(batches, "radial_brace", "steel",
            Vector3(cos(theta) * r, 7.00, -4.75 + sin(theta) * r),
            Vector3(0.26, 0.115, 0.38), -theta)
    # Retain a low recessed grille on each console, not detached pipe collars.
    for spec in [
        {"at": system_at, "yaw": deg_to_rad(18.0),
            "z": 0.42},
        {"at": training_at, "yaw": deg_to_rad(-14.0),
            "z": 0.30}
    ]:
        var anchor: Vector3 = spec["at"]
        var yaw: float = spec["yaw"]
        var depth: float = spec["z"]
        # Enclosed cabinet service trunks are authored with the console.
        # No floating gussets or cable-gland rings on the front flanks.
        _local_part(batches, "hex_grille", "steel", anchor, yaw,
            Vector3(0, 0.32, depth + 0.22),
            Vector3(0.48, 0.24, 0.10))
    # Gate side fittings are now integral to the authored pillar armor.
    # Central tower: low relief ventilation arrays on both exposed cheeks.
    # The front-facing SERA logo and archive screens are intentionally clear.
    for side in [-1.0, 1.0]:
        for level in [2.05, 3.55, 5.05]:
            _part(batches, "hex_grille", "steel",
                Vector3(side * 0.91, float(level), -12.37),
                Vector3(0.12, 0.63, 0.54), PI * 0.5)
    _flush(room, batches)


static func _local_part(batches: Dictionary, profile: String, finish: String,
        origin: Vector3, yaw: float, offset: Vector3, scale: Vector3,
        roll: float = 0.0, flip: bool = false) -> void:
    var basis := Basis(Vector3.UP, yaw)
    var at: Vector3 = origin + basis * offset
    _part(batches, profile, finish, at, scale, yaw + roll, flip)


static func _part(batches: Dictionary, profile: String, finish: String,
        at: Vector3, scale: Vector3, yaw: float = 0.0,
        flip: bool = false) -> void:
    var key: String = profile + ":" + finish
    var group: Array = batches.get(key, [])
    var rotation := Basis(Vector3.UP, yaw)
    if flip:
        rotation = rotation * Basis(Vector3.FORWARD, PI)
    group.append(Transform3D(rotation.scaled_local(scale), at))
    batches[key] = group


static func _toothed_race() -> ArrayMesh:
    var faces: Array = []
    var teeth: int = 32
    var inner: float = 0.78
    var outer: float = 1.0
    var y0: float = -0.045
    var y1: float = 0.048
    for i in range(teeth):
        var a: float = TAU * float(i) / float(teeth)
        var b: float = TAU * float(i + 1) / float(teeth)
        # Every fourth tooth is machined down, creating visible relief.
        var raised: bool = i % 4 != 3
        var outer_a: float = outer if raised else 0.91
        var outer_b: float = outer if raised else 0.91
        var tint: Color = Color("#9eb7c5") if i % 4 == 0 else Color("#587386")
        var ai := Vector3(cos(a) * inner, y1, sin(a) * inner)
        var bi := Vector3(cos(b) * inner, y1, sin(b) * inner)
        var ao := Vector3(cos(a) * outer_a, y1, sin(a) * outer_a)
        var bo := Vector3(cos(b) * outer_b, y1, sin(b) * outer_b)
        _quad(faces, ai, bi, bo, ao, tint)
        _quad(faces, ao, bo, Vector3(bo.x, y0, bo.z),
            Vector3(ao.x, y0, ao.z), Color("#394f61"))
        _quad(faces, Vector3(ai.x, y0, ai.z),
            Vector3(bi.x, y0, bi.z), bi, ai, Color("#263b4c"))
        # Segmented raised rib is geometry, not a stripe texture.
        if i % 4 == 0:
            var mid: float = (a + b) * 0.5
            var u := Vector3(cos(mid), 0, sin(mid))
            var center := u * 0.88
            _box(faces, Vector3(center.x, y1 + 0.014, center.z),
                Vector3(0.045, 0.024, 0.050), Color("#b5cbd7"))
    return _mesh(faces)


static func _inset_race() -> ArrayMesh:
    var faces: Array = []
    for i in range(24):
        var a: float = TAU * float(i) / 24.0
        var b: float = TAU * float(i + 1) / 24.0
        var ia := Vector3(cos(a) * 0.78, 0.023, sin(a) * 0.78)
        var ib := Vector3(cos(b) * 0.78, 0.023, sin(b) * 0.78)
        var oa := Vector3(cos(a) * 0.99, 0.004, sin(a) * 0.99)
        var ob := Vector3(cos(b) * 0.99, 0.004, sin(b) * 0.99)
        _quad(faces, ia, ib, ob, oa,
            Color("#b4ceda") if i % 3 == 0 else Color("#7899ab"))
    return _mesh(faces)


static func _gusset() -> ArrayMesh:
    # Ten-sided rib with a real angled, thick web and punched-open center.
    # Local X/Z carry width/depth and local Y is vertical.
    var faces: Array = []
    var outline: Array[Vector2] = [
        Vector2(-0.50, -0.48), Vector2(-0.28, -0.50),
        Vector2(0.45, -0.28), Vector2(0.50, -0.16),
        Vector2(0.40, 0.34), Vector2(0.15, 0.50),
        Vector2(-0.29, 0.50), Vector2(-0.50, 0.24)
    ]
    for i in range(outline.size()):
        var j: int = (i + 1) % outline.size()
        var a: Vector2 = outline[i]
        var b: Vector2 = outline[j]
        var inner_a: Vector2 = a * 0.61
        var inner_b: Vector2 = b * 0.61
        var outer0 := Vector3(a.x, a.y, 0.10)
        var outer1 := Vector3(b.x, b.y, 0.10)
        var inner0 := Vector3(inner_a.x, inner_a.y, 0.035)
        var inner1 := Vector3(inner_b.x, inner_b.y, 0.035)
        _quad(faces, outer0, outer1, inner1, inner0,
            Color("#899fac") if i % 2 == 0 else Color("#4e697b"))
        _quad(faces, Vector3(a.x, a.y, -0.095),
            Vector3(b.x, b.y, -0.095), outer1, outer0,
            Color("#324b5d"))
    # Deliberately open hole: no central plane.
    return _mesh(faces)


static func _radial_brace() -> ArrayMesh:
    # Stepped cast shoe, with a raised center rail and six visible chamfers.
    var faces: Array = []
    _box(faces, Vector3(0, -0.10, 0),
        Vector3(0.92, 0.12, 0.78), Color("#31495c"))
    var corners: Array[Vector2] = [
        Vector2(-0.44, -0.34), Vector2(-0.30, -0.45),
        Vector2(0.30, -0.45), Vector2(0.44, -0.34),
        Vector2(0.44, 0.34), Vector2(0.30, 0.45),
        Vector2(-0.30, 0.45), Vector2(-0.44, 0.34)
    ]
    for i in range(8):
        var a: Vector2 = corners[i]
        var b: Vector2 = corners[(i + 1) % 8]
        _tri(faces, Vector3(0, 0.09, 0),
            Vector3(a.x, 0.055, a.y), Vector3(b.x, 0.055, b.y),
            Color("#93abb9") if i % 3 == 0 else Color("#5d788b"))
    _box(faces, Vector3(0, 0.115, 0), Vector3(0.12, 0.046, 0.52),
        Color("#adc3d0"))
    return _mesh(faces)


static func _hex_grille() -> ArrayMesh:
    # Six connected hexagonal cells. Each is an extruded six-sided rim:
    # no translucent quad hides the actual open voids behind the grille.
    var faces: Array = []
    for row in range(3):
        for col in range(2):
            var cx: float = (float(col) - 0.5) * 0.47 + (0.09 if row % 2 else 0.0)
            var cy: float = (float(row) - 1.0) * 0.31
            var radial: Array[Vector2] = []
            for i in range(6):
                var a: float = TAU * float(i) / 6.0 + PI / 6.0
                radial.append(Vector2(cos(a), sin(a)))
            for i in range(6):
                var j: int = (i + 1) % 6
                var oa := Vector3(cx + radial[i].x * 0.238,
                    cy + radial[i].y * 0.18, 0.04)
                var ob := Vector3(cx + radial[j].x * 0.238,
                    cy + radial[j].y * 0.18, 0.04)
                var ia := Vector3(cx + radial[i].x * 0.172,
                    cy + radial[i].y * 0.13, 0.06)
                var ib := Vector3(cx + radial[j].x * 0.172,
                    cy + radial[j].y * 0.13, 0.06)
                _quad(faces, oa, ob, ib, ia,
                    Color("#829eaf") if row % 2 else Color("#526f81"))
                _quad(faces, Vector3(oa.x, oa.y, -0.035),
                    Vector3(ob.x, ob.y, -0.035), ob, oa,
                    Color("#324b5d"))
    return _mesh(faces)


static func _box(faces: Array, center: Vector3, size: Vector3,
        tint: Color) -> void:
    var x: float = size.x * 0.5
    var y: float = size.y * 0.5
    var z: float = size.z * 0.5
    var pts: Array[Vector3] = [
        center + Vector3(-x, -y, -z), center + Vector3(x, -y, -z),
        center + Vector3(x, y, -z), center + Vector3(-x, y, -z),
        center + Vector3(-x, -y, z), center + Vector3(x, -y, z),
        center + Vector3(x, y, z), center + Vector3(-x, y, z)
    ]
    for ix in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3],
            [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]:
        _quad(faces, pts[ix[0]], pts[ix[1]], pts[ix[2]], pts[ix[3]], tint)


static func _quad(faces: Array, a: Vector3, b: Vector3,
        c: Vector3, d: Vector3, tint: Color) -> void:
    _tri(faces, a, b, c, tint)
    _tri(faces, a, c, d, tint)


static func _tri(faces: Array, a: Vector3, b: Vector3,
        c: Vector3, tint: Color) -> void:
    faces.append([a, b, c, tint])


static func _mesh(faces: Array) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    for face in faces:
        var n: Vector3 = (face[1] - face[0]).cross(
            face[2] - face[0]).normalized()
        for i in range(3):
            vertices.append(face[i])
            normals.append(n)
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
    var root := Node3D.new()
    root.name = "NexusComplexMachining"
    room.add_child(root)
    var meshes: Dictionary = {
        "toothed_race": _toothed_race(),
        "inset_race": _inset_race(),
        "gusset": _gusset(),
        "radial_brace": _radial_brace(),
        "hex_grille": _hex_grille()
    }
    var materials: Dictionary = {}
    for key_value in batches.keys():
        var key: String = key_value
        var fields: PackedStringArray = key.split(":")
        var profile: String = fields[0]
        var finish: String = fields[1]
        if not materials.has(finish):
            var mat := StandardMaterial3D.new()
            mat.albedo_color = (Color("#d0dee8") if finish == "pale"
                else Color("#b4c6d0"))
            mat.vertex_color_use_as_albedo = true
            mat.metallic = 0.46
            mat.roughness = 0.44
            mat.cull_mode = BaseMaterial3D.CULL_DISABLED
            materials[finish] = mat
        var transforms: Array = batches[key]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = meshes[profile]
        mm.instance_count = transforms.size()
        for i in range(transforms.size()):
            mm.set_instance_transform(i, transforms[i])
        var instance := MultiMeshInstance3D.new()
        instance.name = "Machining_" + profile + "_" + finish
        instance.multimesh = mm
        instance.material_override = materials[finish]
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        instance.set_meta("sera_outline_occluder_only", true)
        instance.set_meta("FX_NO_OUTLINE", true)
        root.add_child(instance)
