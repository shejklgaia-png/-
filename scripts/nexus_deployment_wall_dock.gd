extends RefCounted
## Deployment wall dock: a fixed-cost, authored-scale access apron and bulkhead.
## The gate itself still comes from the original Blockbench module; this
## supplies large cast side wings, a machined lintel, an inclined entry deck,
## and a visible auxiliary launch console without per-frame updates.

static func build(room: Node3D, gate_at: Vector3,
        gate_yaw: float, _gate_scale: float) -> void:
    var root := Node3D.new()
    root.name = "DeploymentWallDock"
    root.position = gate_at
    root.rotation.y = gate_yaw
    room.add_child(root)

    var steel := _material(Color("#344b5e"))
    var iron := _material(Color("#202f3e"))
    var trim := _material(Color("#758b9b"))
    var cyan := _material(Color("#6bd5ff"), true)
    var amber := _material(Color("#e9b644"), true)

    # Two continuous flared castings join the rear wall plane (z=-27.4)
    # and the enlarged gate cheeks. They never enter the central aperture.
    var wing_profile := PackedVector2Array([
        Vector2(-2.65, -0.78), Vector2(-2.65, 7.75),
        Vector2(0.28, 7.75), Vector2(1.50, 6.92),
        Vector2(2.12, -0.78)
    ])
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _prism(root, "WallButtress%d" % side_value,
            wing_profile, 0.34, side * 2.81, 0.0, steel)
        _prism(root, "GateToWallGusset%d" % side_value,
            PackedVector2Array([
                Vector2(-2.45, 0.42), Vector2(-2.45, 6.85),
                Vector2(-0.92, 7.20), Vector2(1.16, 5.72),
                Vector2(1.16, 0.42)]),
            0.12, side * 3.12, 0.0, iron)

    # Wedge-ramp raises the forward approach smoothly to the new 0.8 m
    # threshold. Its near edge meets the gate rather than floating above it.
    _prism(root, "DeploymentInclinedApproach",
        PackedVector2Array([
            Vector2(1.28, 0.04), Vector2(7.02, -0.73),
            Vector2(7.02, -0.91), Vector2(1.28, -0.14)]),
        1.72, 0.0, 0.0, steel)
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _prism(root, "ApproachLightRail%d" % side_value,
            PackedVector2Array([
                Vector2(1.25, 0.14), Vector2(6.95, -0.62),
                Vector2(6.95, -0.68), Vector2(1.25, 0.08)]),
            0.049, side * 1.67, 0.0, cyan)

    # Additional precision-machined parts share three MultiMesh draw batches.
    var boxes: Dictionary = {}
    _box(boxes, "iron", Vector3(0.0, 7.55, -1.55),
        Vector3(6.18, 0.86, 2.55))
    _box(boxes, "steel", Vector3(0.0, 8.13, -0.63),
        Vector3(6.38, 0.42, 1.12))
    _box(boxes, "trim", Vector3(0.0, 8.41, 0.20),
        Vector3(5.67, 0.22, 0.30))
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        # Rear tie blocks pierce the rear-wall facing, closing the gap on
        # the angled right cheek without spreading toward the center pillar.
        _box(boxes, "iron", Vector3(side * 2.42, 3.23, -3.04),
            Vector3(0.62, 8.0, 1.72))
        _box(boxes, "iron", Vector3(side * 2.86, 4.38, -1.95),
            Vector3(0.56, 6.96, 2.50))
        _box(boxes, "trim", Vector3(side * 2.77, 4.12, 1.27),
            Vector3(0.16, 4.40, 0.18))
        _box(boxes, "cyan", Vector3(side * 2.58, 4.33, 1.43),
            Vector3(0.065, 2.68, 0.062))
        _box(boxes, "amber", Vector3(side * 1.75, -0.60, 6.72),
            Vector3(0.20, 0.055, 0.13))
    for x in [-2.10, -1.05, 0.0, 1.05, 2.10]:
        _box(boxes, "trim", Vector3(float(x), 7.76, 0.78),
            Vector3(0.68, 0.16, 0.12))
    for z in [2.15, 3.46, 4.77, 6.05]:
        var center_y: float = 0.04 - (float(z) - 1.28) * (
            0.77 / 5.74) - 0.027
        _box(boxes, "trim", Vector3(0.0, center_y, float(z)),
            Vector3(3.12, 0.037, 0.067))

    # Side auxiliary launch terminal; the touch footprint is registered as
    # DEPLOYMENT, so it triggers the existing menu instead of a duplicate UI.
    _prism(root, "LaunchConsoleCasting",
        PackedVector2Array([
            Vector2(-0.60, -0.78), Vector2(-0.58, 0.62),
            Vector2(-0.22, 1.12), Vector2(0.54, 0.91),
            Vector2(0.65, -0.78)]),
        0.50, 2.82, 5.30, iron)
    _box(boxes, "steel", Vector3(2.82, 0.64, 5.57),
        Vector3(0.93, 0.22, 0.42))
    _box(boxes, "cyan", Vector3(2.82, 0.49, 5.80),
        Vector3(0.75, 0.49, 0.055))
    _box(boxes, "trim", Vector3(2.82, -0.04, 5.83),
        Vector3(0.79, 0.09, 0.12))
    _flush_boxes(root, boxes, {
        "steel": steel, "iron": iron, "trim": trim,
        "cyan": cyan, "amber": amber
    })


static func console_hit_corners(gate_at: Vector3,
        gate_yaw: float) -> PackedVector3Array:
    var basis := Basis(Vector3.UP, gate_yaw)
    var corners := PackedVector3Array()
    for x in [2.28, 3.36]:
        for y in [-0.78, 1.18]:
            for z in [4.62, 6.02]:
                corners.append(gate_at + basis * Vector3(x, y, z))
    return corners


static func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.40 if not glow else 0.10
    mat.roughness = 0.55
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.45
    return mat


static func _box(groups: Dictionary, kind: String,
        at: Vector3, size: Vector3) -> void:
    var transforms: Array = groups.get(kind, [])
    transforms.append(Transform3D(
        Basis().scaled_local(size), at))
    groups[kind] = transforms


static func _flush_boxes(root: Node3D, groups: Dictionary,
        mats: Dictionary) -> void:
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    for kind_value in groups.keys():
        var kind: String = String(kind_value)
        var transforms: Array = groups[kind]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = cube
        multi.instance_count = transforms.size()
        for i in range(transforms.size()):
            multi.set_instance_transform(i, transforms[i])
        var node := MultiMeshInstance3D.new()
        node.name = "DockBatch_" + kind
        node.multimesh = multi
        node.material_override = mats[kind]
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.set_meta("sera_outline_occluder_only", true)
        node.set_meta("FX_NO_OUTLINE", true)
        root.add_child(node)


static func _prism(root: Node3D, label: String,
        profile: PackedVector2Array, half_width: float,
        offset_x: float, offset_z: float,
        mat: Material) -> void:
    # Extrude a real sloping/angled Z-Y polygon along X; no stacked flat boxes
    # or per-frame transformations are needed for the ramp or wall wings.
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var count: int = profile.size()
    for i in range(1, count - 1):
        _tri(tool, _v(profile[0], -half_width),
            _v(profile[i], -half_width),
            _v(profile[i + 1], -half_width))
        _tri(tool, _v(profile[0], half_width),
            _v(profile[i + 1], half_width),
            _v(profile[i], half_width))
    for i in range(count):
        var next_i: int = (i + 1) % count
        var a := _v(profile[i], -half_width)
        var b := _v(profile[next_i], -half_width)
        var c := _v(profile[next_i], half_width)
        var d := _v(profile[i], half_width)
        _tri(tool, a, b, c)
        _tri(tool, a, c, d)
    tool.generate_normals()
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = tool.commit()
    node.position = Vector3(offset_x, 0.0, offset_z)
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("sera_outline_occluder_only", true)
    node.set_meta("FX_NO_OUTLINE", true)
    root.add_child(node)


static func _v(point: Vector2, x: float) -> Vector3:
    return Vector3(x, point.y, point.x)


static func _tri(tool: SurfaceTool, a: Vector3,
        b: Vector3, c: Vector3) -> void:
    tool.add_vertex(a)
    tool.add_vertex(b)
    tool.add_vertex(c)
