extends RefCounted
## Procedural NEXUS architectural hardware: a small, shared library of true
## extruded armor and open-look louver meshes. All vertices are created once
## when the NEXUS room is entered, then batched by finish in MultiMeshes.
##
## The original Blockbench parts remain authoritative for interaction
## silhouettes, controls, placement and their outline pipeline. Generated
## overlays sit inside those existing silhouettes and are depth occluders only.

static func build(room: Node3D, system_at: Vector3,
        training_at: Vector3, gate_at: Vector3, gate_yaw: float, gate_scale: float = 1.0) -> void:
    var pieces: Dictionary = {}

    # SYSTEM: press-formed ribs along the lower cabinet and deliberately
    # narrow caps alongside (not over) its original panoramic display.
    _plate(pieces, "outer", system_at, deg_to_rad(18.0),
        Vector3(-0.65, 0.48, 0.58), Vector2(0.20, 0.64))
    _plate(pieces, "outer", system_at, deg_to_rad(18.0),
        Vector3(0.65, 0.48, 0.58), Vector2(0.20, 0.64))
    # Monitor-side plates now belong to the fitted monitor assembly.
    _plate(pieces, "dark", system_at, deg_to_rad(18.0),
        Vector3(0.24, 0.57, 0.58), Vector2(0.43, 0.34))
    _vent(pieces, system_at, deg_to_rad(18.0),
        Vector3(0.24, 0.57, 0.639), Vector2(0.32, 0.23))
    _bar(pieces, "metal", system_at, deg_to_rad(18.0),
        Vector3(0.0, 0.20, 0.586), Vector3(1.03, 0.052, 0.034))
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        for height in [0.25, 0.74]:
            _bar(pieces, "pin", system_at, deg_to_rad(18.0),
                Vector3(side * 0.65, float(height), 0.647),
                Vector3(0.042, 0.042, 0.022))

    # TRAINING: asymmetric brackets preserve the side-mounted diagnostic
    # sensor and the screen area. The louver is below the inclined keyboard.
    _plate(pieces, "outer", training_at, deg_to_rad(-14.0),
        Vector3(-0.48, 0.72, 0.34), Vector2(0.15, 0.72))
    _plate(pieces, "outer", training_at, deg_to_rad(-14.0),
        Vector3(0.48, 0.70, 0.34), Vector2(0.13, 0.65))
    # Old detached monitor trim removed; sensor pods attach to housing.
    _plate(pieces, "dark", training_at, deg_to_rad(-14.0),
        Vector3(-0.17, 0.55, 0.61), Vector2(0.41, 0.36))
    _vent(pieces, training_at, deg_to_rad(-14.0),
        Vector3(-0.17, 0.55, 0.669), Vector2(0.31, 0.235))
    _bar(pieces, "metal", training_at, deg_to_rad(-14.0),
        Vector3(0.0, 0.20, 0.614), Vector3(0.85, 0.052, 0.035))
    _plate(pieces, "trim", training_at, deg_to_rad(-14.0),
        Vector3(0.80, 1.13, 0.16), Vector2(0.23, 0.18))
    for side_value in [-1, 1]:
        _bar(pieces, "pin", training_at, deg_to_rad(-14.0),
            Vector3(-0.17 + float(side_value) * 0.16, 0.55, 0.725),
            Vector3(0.037, 0.037, 0.018))

    # Portal drive covers are now fitted directly to the authored pillars;
    # do not add independent plates and pins in front of their silhouette.

    # The existing twelve-piece canopy gets one low-poly annular bearing
    # inside its luminous rim. It adds a readable circular machine layer
    # without another light or a second full-size overlapping canopy.
    _append(pieces, "canopy_ring",
        Transform3D(Basis(), Vector3(0.0, 7.09, -4.75)))

    _flush(room, pieces)


static func _plate(pieces: Dictionary, finish: String,
        origin: Vector3, yaw: float, at: Vector3, size: Vector2) -> void:
    var basis := Basis(Vector3.UP, yaw)
    _append(pieces, "plate_" + finish,
        Transform3D(basis.scaled_local(Vector3(size.x, size.y, 1.0)),
        origin + basis * at))


static func _vent(pieces: Dictionary, origin: Vector3,
        yaw: float, at: Vector3, size: Vector2) -> void:
    var basis := Basis(Vector3.UP, yaw)
    _append(pieces, "louver",
        Transform3D(basis.scaled_local(Vector3(size.x, size.y, 1.0)),
        origin + basis * at))


static func _bar(pieces: Dictionary, kind: String, origin: Vector3,
        yaw: float, at: Vector3, size: Vector3) -> void:
    var basis := Basis(Vector3.UP, yaw)
    _append(pieces, kind, Transform3D(basis.scaled_local(size),
        origin + basis * at))


static func _append(pieces: Dictionary,
        finish: String, transform: Transform3D) -> void:
    var elements: Array = pieces.get(finish, [])
    elements.append(transform)
    pieces[finish] = elements


static func _cast_panel_mesh() -> ArrayMesh:
    # Eight cut corners, wide polygon face, chamfered outline and physically
    # extruded side walls. Shared normalized XY dimensions and fixed Z-depth.
    var perimeter: Array = [
        Vector2(-0.50, -0.43), Vector2(-0.43, -0.50),
        Vector2(0.43, -0.50), Vector2(0.50, -0.43),
        Vector2(0.50, 0.43), Vector2(0.43, 0.50),
        Vector2(-0.43, 0.50), Vector2(-0.50, 0.43)
    ]
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    for i in range(8):
        var j: int = (i + 1) % 8
        var a: Vector2 = perimeter[i]
        var b: Vector2 = perimeter[j]
        var inner_a: Vector2 = a * 0.88
        var inner_b: Vector2 = b * 0.88
        var fa := Vector3(inner_a.x, inner_a.y, 0.049)
        var fb := Vector3(inner_b.x, inner_b.y, 0.049)
        var oa := Vector3(a.x, a.y, -0.012)
        var ob := Vector3(b.x, b.y, -0.012)
        var ba := Vector3(a.x, a.y, -0.051)
        var bb := Vector3(b.x, b.y, -0.051)

        # The central armor and beveled lip are distinct shaded triangles,
        # unlike a flat quad or an enlarged screen-space outline.
        _tri(vertices, normals, colors, Vector3(0, 0, 0.049),
            fa, fb, Color(0.97, 0.99, 1.0), true)
        _tri(vertices, normals, colors, oa, ob, fb,
            Color(0.68, 0.77, 0.84))
        _tri(vertices, normals, colors, oa, fb, fa,
            Color(0.76, 0.83, 0.89))
        _tri(vertices, normals, colors, ba, oa, ob,
            Color(0.47, 0.58, 0.68))
        _tri(vertices, normals, colors, ba, ob, bb,
            Color(0.47, 0.58, 0.68))

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return result


static func _louver_mesh() -> ArrayMesh:
    # One physical grille rather than an opaque dark box with painted lines.
    # The solid back pocket recedes; six tilted trapezoidal fins carry their
    # own normals and highlight strips.
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    _quad(vertices, normals, colors,
        Vector3(-0.50, -0.50, 0), Vector3(0.50, -0.50, 0),
        Vector3(0.50, 0.50, 0), Vector3(-0.50, 0.50, 0),
        Color("#12212c"))
    for i in range(6):
        var cy: float = -0.37 + float(i) * 0.146
        _quad(vertices, normals, colors,
            Vector3(-0.405, cy - 0.046, 0.023),
            Vector3(0.405, cy - 0.046, 0.023),
            Vector3(0.405, cy + 0.012, 0.061),
            Vector3(-0.405, cy + 0.012, 0.061),
            Color("#567586"))
        _quad(vertices, normals, colors,
            Vector3(-0.408, cy + 0.009, 0.063),
            Vector3(0.408, cy + 0.009, 0.063),
            Vector3(0.408, cy + 0.031, 0.050),
            Vector3(-0.408, cy + 0.031, 0.050),
            Color("#839fb0"))
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _quad(vertices, normals, colors,
            Vector3(side * 0.46 - 0.017, -0.49, 0.057),
            Vector3(side * 0.46 + 0.017, -0.49, 0.057),
            Vector3(side * 0.46 + 0.017, 0.49, 0.057),
            Vector3(side * 0.46 - 0.017, 0.49, 0.057),
            Color("#7c96a6"))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return result


static func _machined_annulus() -> ArrayMesh:
    # Closed, low-sided industrial collar with shaded upper/lower facets.
    # Dimensions are local meters; center is the authored maintenance stage.
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var segments: int = 24
    var outer_radius: float = 1.43
    var inner_radius: float = 1.18
    for i in range(segments):
        var angle_a: float = TAU * float(i) / float(segments)
        var angle_b: float = TAU * float(i + 1) / float(segments)
        var radial_a := Vector2(cos(angle_a), sin(angle_a))
        var radial_b := Vector2(cos(angle_b), sin(angle_b))
        var top_outer_a := Vector3(radial_a.x * outer_radius, 0.061,
            radial_a.y * outer_radius)
        var top_outer_b := Vector3(radial_b.x * outer_radius, 0.061,
            radial_b.y * outer_radius)
        var top_inner_a := Vector3(radial_a.x * inner_radius, 0.061,
            radial_a.y * inner_radius)
        var top_inner_b := Vector3(radial_b.x * inner_radius, 0.061,
            radial_b.y * inner_radius)
        var bottom_outer_a := Vector3(top_outer_a.x, -0.048, top_outer_a.z)
        var bottom_outer_b := Vector3(top_outer_b.x, -0.048, top_outer_b.z)
        var bottom_inner_a := Vector3(top_inner_a.x, -0.048, top_inner_a.z)
        var bottom_inner_b := Vector3(top_inner_b.x, -0.048, top_inner_b.z)
        var crown: Color = (Color("#d1e0ea")
            if i % 4 == 0 else Color("#9db7c8"))
        _quad(vertices, normals, colors, top_inner_a, top_inner_b,
            top_outer_b, top_outer_a, crown)
        _quad(vertices, normals, colors, bottom_outer_a, bottom_outer_b,
            bottom_inner_b, bottom_inner_a, Color("#667d90"))
        _quad(vertices, normals, colors, top_outer_a, top_outer_b,
            bottom_outer_b, bottom_outer_a, Color("#91aaba"))
        _quad(vertices, normals, colors, bottom_inner_a, bottom_inner_b,
            top_inner_b, top_inner_a, Color("#40586b"))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return result


static func _quad(vertices: PackedVector3Array,
        normals: PackedVector3Array, colors: PackedColorArray,
        a: Vector3, b: Vector3, c: Vector3, d: Vector3,
        tint: Color) -> void:
    _tri(vertices, normals, colors, a, b, c, tint)
    _tri(vertices, normals, colors, a, c, d, tint)


static func _tri(vertices: PackedVector3Array,
        normals: PackedVector3Array, colors: PackedColorArray,
        a: Vector3, b: Vector3, c: Vector3,
        tint: Color, front: bool = false) -> void:
    var normal: Vector3 = (b - a).cross(c - a).normalized()
    if front:
        normal = Vector3.FORWARD * -1.0
    vertices.append(a)
    vertices.append(b)
    vertices.append(c)
    for i in range(3):
        normals.append(normal)
        colors.append(tint)


static func _flush(room: Node3D, pieces: Dictionary) -> void:
    var root := Node3D.new()
    root.name = "NexusProceduralArchitecture"
    room.add_child(root)
    var plate_mesh: Mesh = _cast_panel_mesh()
    var louver_mesh: Mesh = _louver_mesh()
    var annulus_mesh: Mesh = _machined_annulus()
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    for key_value in pieces.keys():
        var finish: String = String(key_value)
        var transforms: Array = pieces[finish]
        var shared_mesh: Mesh = cube
        if finish.begins_with("plate_"):
            shared_mesh = plate_mesh
        elif finish == "louver":
            shared_mesh = louver_mesh
        elif finish == "canopy_ring":
            shared_mesh = annulus_mesh
        var batch := MultiMesh.new()
        batch.transform_format = MultiMesh.TRANSFORM_3D
        batch.mesh = shared_mesh
        batch.instance_count = transforms.size()
        for i in range(transforms.size()):
            batch.set_instance_transform(i, transforms[i])
        var instance := MultiMeshInstance3D.new()
        instance.name = "Casting_" + finish
        instance.multimesh = batch
        instance.material_override = _material(finish)
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # No new RGB-ID registration, polygon edges or selection components.
        instance.set_meta("sera_outline_occluder_only", true)
        instance.set_meta("FX_NO_OUTLINE", true)
        root.add_child(instance)


static func _material(finish: String) -> StandardMaterial3D:
    var palette: Dictionary = {
        "plate_outer": Color("#3b5267"),
        "plate_dark": Color("#263b4d"),
        "plate_trim": Color("#536c80"),
        "metal": Color("#587385"),
        "canopy_ring": Color("#41586c"),
        "pin": Color("#859cac"),
        "glow": Color("#6dcfff")
    }
    var mat := StandardMaterial3D.new()
    mat.albedo_color = palette.get(finish, Color.WHITE)
    mat.vertex_color_use_as_albedo = (
        finish.begins_with("plate_") or finish == "louver" or
        finish == "canopy_ring")
    if finish == "louver":
        mat.albedo_color = Color.WHITE
    mat.metallic = 0.48
    mat.roughness = 0.41
    mat.metallic_specular = 0.56
    if finish.begins_with("plate_") or (
            finish == "louver" or finish == "canopy_ring"):
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if finish == "glow":
        mat.emission_enabled = true
        mat.emission = Color("#6dcfff")
        mat.emission_energy_multiplier = 1.15
    return mat
