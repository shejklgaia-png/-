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

    # Side launch terminal. The old tall black prism reached local z=5.95,
    # but its cyan readout was only at z=5.80 (INSIDE opaque metal), so the
    # overview showed a featureless dark rectangle. Rebuild the entire console
    # as a stepped die-cast kiosk, with a forward-tilted display whose front
    # surface always clears the armored housing by at least 0.10m.
    _prism(root, "LaunchConsolePedestal",
        PackedVector2Array([
            Vector2(-0.70, -0.78), Vector2(-0.68, 0.10),
            Vector2(-0.49, 0.38), Vector2(0.15, 0.41),
            Vector2(0.38, 0.15), Vector2(0.45, -0.78)]),
        0.42, 2.82, 5.15, iron)
    _prism(root, "LaunchConsoleBeveledMonitor",
        PackedVector2Array([
            Vector2(5.08, 0.49), Vector2(5.10, 1.44),
            Vector2(5.33, 1.79), Vector2(6.04, 1.80),
            Vector2(6.44, 0.92), Vector2(6.17, 0.55)]),
        0.66, 2.82, 0.0, steel)
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _prism(root, "MonitorCastSideArm%d" % side_value,
            PackedVector2Array([
                Vector2(5.18, 0.60), Vector2(5.17, 1.45),
                Vector2(5.39, 1.73), Vector2(5.72, 1.69),
                Vector2(5.46, 0.71)]),
            0.077, 2.82 + side * 0.72, 0.0, trim)

    # The front is a physically tilted planar LCD; no broad solid cyan block,
    # fake floating hologram or black face can hide behind the pedestal.
    var bezel := _material(Color("#718b9b"))
    var dark_glass := _material(Color("#103447"))
    dark_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dark_glass.metallic = 0.0
    dark_glass.roughness = 1.0
    _display_face(root, "ForwardAngledScreenBezel",
        2.82, 1.19, 0.83, 1.68, 0.00, bezel)
    _display_face(root, "IlluminatedInstrumentGlass",
        2.82, 1.04, 0.94, 1.58, 0.035, dark_glass)
    _display_instruments(root)

    # Real support, hinge, keyboard, raised tactile buttons, side LEDs, and
    # floor-level armored foot. Shared box batches keep draw calls bounded.
    _box(boxes, "steel", Vector3(2.82, -0.67, 5.21),
        Vector3(1.15, 0.17, 0.95))
    _box(boxes, "trim", Vector3(2.82, -0.58, 5.64),
        Vector3(1.18, 0.058, 0.07))
    _box(boxes, "steel", Vector3(2.82, 0.29, 5.28),
        Vector3(0.52, 0.44, 0.38))
    _box(boxes, "trim", Vector3(2.82, 0.48, 5.39),
        Vector3(0.64, 0.16, 0.47))
    _box(boxes, "iron", Vector3(2.82, 0.67, 6.28),
        Vector3(1.19, 0.16, 0.41))
    _box(boxes, "trim", Vector3(2.82, 0.77, 6.45),
        Vector3(1.06, 0.045, 0.19))
    for i in range(5):
        var key_x: float = 2.43 + float(i) * 0.195
        _box(boxes, "iron", Vector3(key_x, 0.805, 6.46),
            Vector3(0.123, 0.035, 0.095))
    _box(boxes, "cyan", Vector3(2.43, 0.827, 6.46),
        Vector3(0.093, 0.014, 0.070))
    _box(boxes, "amber", Vector3(3.21, 0.827, 6.46),
        Vector3(0.093, 0.014, 0.070))
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _box(boxes, "iron", Vector3(2.82 + side * 0.68, 1.29, 6.08),
            Vector3(0.11, 0.63, 0.17))
        _box(boxes, "cyan", Vector3(2.82 + side * 0.69, 1.38, 6.31),
            Vector3(0.046, 0.21, 0.055))
        _box(boxes, "amber", Vector3(2.82 + side * 0.46, 0.62, 6.43),
            Vector3(0.11, 0.045, 0.085))

    _flush_boxes(root, boxes, {
        "steel": steel, "iron": iron, "trim": trim,
        "cyan": cyan, "amber": amber
    })


static func console_hit_corners(gate_at: Vector3,
        gate_yaw: float) -> PackedVector3Array:
    var basis := Basis(Vector3.UP, gate_yaw)
    var corners := PackedVector3Array()
    # Include the new raised, tilted instrument and keyboard. The original
    # DEPLOYMENT target is unchanged: no duplicate menu or new hit pipeline.
    for x in [2.04, 3.60]:
        for y in [-0.78, 1.91]:
            for z in [4.42, 6.78]:
                corners.append(gate_at + basis * Vector3(x, y, z))
    return corners


# All display surfaces slope backwards as they rise (local +Z = camera).
# At every Y the display glass and its glyphs remain IN FRONT of the casting,
# avoiding the old completely occluded blue panel.
static func _display_depth(y: float, step_forward: float) -> float:
    return 6.62 - (y - 0.84) * 0.445 + step_forward


static func _display_face(root: Node3D, label: String,
        center_x: float, width: float, bottom_y: float, top_y: float,
        forward: float, material: Material) -> void:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var left: float = center_x - width * 0.5
    var right: float = center_x + width * 0.5
    var a := Vector3(left, bottom_y, _display_depth(bottom_y, forward))
    var b := Vector3(right, bottom_y, _display_depth(bottom_y, forward))
    var c := Vector3(right, top_y, _display_depth(top_y, forward))
    var d := Vector3(left, top_y, _display_depth(top_y, forward))
    _tri(tool, a, b, c)
    _tri(tool, a, c, d)
    tool.generate_normals()
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = tool.commit()
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh.set_meta("sera_outline_occluder_only", true)
    mesh.set_meta("FX_NO_OUTLINE", true)
    root.add_child(mesh)


static func _display_instruments(root: Node3D) -> void:
    # A single vertex-colored mesh draws the complete 3D readout:
    # blue title bus, radar reticle, scrolling-data-like trace, segmented
    # status bars and amber safety mark. No text texture or extra viewport.
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var bright := Color("#8ff4ff")
    var muted := Color("#4c9bad")
    var warning := Color("#f1ce6b")
    _screen_stroke(tool, Vector2(2.36, 1.51), Vector2(3.28, 1.51),
        0.038, bright)
    _screen_stroke(tool, Vector2(2.36, 1.44), Vector2(2.76, 1.44),
        0.016, muted)
    _screen_stroke(tool, Vector2(3.02, 1.44), Vector2(3.28, 1.44),
        0.016, warning)
    var center := Vector2(2.64, 1.22)
    for i in range(16):
        var a: float = float(i) * TAU / 16.0
        var b: float = float(i + 1) * TAU / 16.0
        _screen_stroke(tool,
            center + Vector2(cos(a), sin(a)) * 0.155,
            center + Vector2(cos(b), sin(b)) * 0.155,
            0.010, muted if i % 4 < 2 else bright)
    _screen_stroke(tool, center + Vector2(-0.066, 0.0),
        center + Vector2(0.066, 0.0), 0.012, bright)
    _screen_stroke(tool, center + Vector2(0.0, -0.066),
        center + Vector2(0.0, 0.066), 0.012, bright)
    for i in range(4):
        var y: float = 1.36 - float(i) * 0.079
        _screen_stroke(tool, Vector2(2.91, y),
            Vector2(3.20 - float(i % 3) * 0.047, y),
            0.024, muted if i != 1 else bright)
    for i in range(5):
        var x: float = 2.40 + float(i) * 0.174
        _screen_stroke(tool, Vector2(x, 1.01),
            Vector2(x + 0.112, 1.01), 0.019,
            warning if i == 4 else bright)
    var node := MeshInstance3D.new()
    node.name = "DeploymentReadoutReticleAndStatus"
    node.mesh = tool.commit()
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.albedo_color = Color.WHITE
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("sera_outline_occluder_only", true)
    node.set_meta("FX_NO_OUTLINE", true)
    root.add_child(node)


static func _screen_stroke(tool: SurfaceTool, a: Vector2, b: Vector2,
        thickness: float, tint: Color) -> void:
    var line: Vector2 = b - a
    if line.length_squared() < 0.000001:
        return
    var cross: Vector2 = Vector2(-line.y, line.x).normalized() * (
        thickness * 0.5)
    var p0: Vector2 = a - cross
    var p1: Vector2 = b - cross
    var p2: Vector2 = b + cross
    var p3: Vector2 = a + cross
    _screen_tri(tool, p0, p1, p2, tint)
    _screen_tri(tool, p0, p2, p3, tint)


static func _screen_tri(tool: SurfaceTool, a: Vector2, b: Vector2,
        c: Vector2, tint: Color) -> void:
    tool.set_color(tint)
    tool.add_vertex(Vector3(a.x, a.y, _display_depth(a.y, 0.085)))
    tool.set_color(tint)
    tool.add_vertex(Vector3(b.x, b.y, _display_depth(b.y, 0.085)))
    tool.set_color(tint)
    tool.add_vertex(Vector3(c.x, c.y, _display_depth(c.y, 0.085)))


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
