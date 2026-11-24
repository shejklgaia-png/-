extends RefCounted
## NEXUS TRAINING: replace the rectangular auxiliary sensor tower and its
## low flat ventilation plate with one functional cast-metal service assembly.
## Built once, opaque, one ArrayMesh / one draw node, no material animations.
##
## The authored TRAINING block volumes are still used for selection corners;
## this is only a replacement for their visible cuboids, not for touch input.

const ARMOR: Color = Color("#455b6e")
const CAST: Color = Color("#72889a")
const EDGE: Color = Color("#a3bac9")
const DARK: Color = Color("#233949")
const INSET: Color = Color("#192d3b")
const STEEL: Color = Color("#c1d0da")
const CYAN: Color = Color("#4bd5ec")
const AMBER: Color = Color("#e9b644")


static func build(room: Node3D, training_at: Vector3, yaw: float) -> void:
    var faces: Array = []
    var outline_ranges: Array[Vector2i] = []
    _formed_tower(faces, outline_ranges)
    for side in [-1.0, 1.0]:
        _service_hatch(faces, side, outline_ranges)
        _side_cooling_channel(faces, side, outline_ranges)
        _latch_and_hinges(faces, side, outline_ranges)
        _diagonal_foot(faces, side, outline_ranges)
    # Preserve the original Blockbench tower's 11-degree Z inclination.
    # Its selection/hit cuboid still uses precisely that same authored tilt.
    var source_pivot := Vector3(0.80, 1.320, -0.280)
    var source_tilt := Basis(Vector3.BACK, deg_to_rad(11.0))
    for face in faces:
        for i in range(3):
            face[i] = source_pivot + source_tilt * (face[i] - source_pivot)
    # Lower side vent was a separate, UNROTATED Blockbench element.
    _lower_front_vent(faces, outline_ranges)

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
    # Selection-only grouping of actual render faces; no extra render nodes.
    mesh.set_meta("nexus_selection_face_ranges", outline_ranges)

    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.albedo_color = Color.WHITE
    material.metallic = 0.43
    material.roughness = 0.49
    material.metallic_specular = 0.42
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var root := Node3D.new()
    root.name = "TrainingServiceAssembly"
    root.position = training_at
    root.rotation.y = yaw
    room.add_child(root)
    var casting := MeshInstance3D.new()
    casting.name = "ServiceTowerHatchCoolingAndSupport"
    casting.mesh = mesh
    casting.material_override = material
    casting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # This mesh actually REPLACES the outlined source tower; unlike extra
    # trim pieces it should retain the NEXUS facility edge classification.
    casting.set_meta("sera_outline_role", "facility")
    root.add_child(casting)


static func _formed_tower(faces: Array, outline_ranges: Array[Vector2i]) -> void:
    # Source cube: x 0.625..0.975, y 0.555..2.085, z -0.515..-0.045.
    # Replace the simple box with a profiled, eight-sided upright.
    # A mild waist reduction and broad, folded shoulders communicate a
    # functional support rather than a painted rectangular box.
    var levels: Array = [
        [0.555, 0.145, 0.206],
        [0.635, 0.175, 0.235],
        [0.755, 0.168, 0.221],
        [1.200, 0.161, 0.219],
        [1.760, 0.175, 0.235],
        [1.965, 0.175, 0.235],
        [2.085, 0.136, 0.194]
    ]
    for j in range(levels.size() - 1):
        var start: int = faces.size()
        var bottom: Array[Vector3] = _tower_outline(
            float(levels[j][0]), float(levels[j][1]),
            float(levels[j][2]))
        var top: Array[Vector3] = _tower_outline(
            float(levels[j + 1][0]), float(levels[j + 1][1]),
            float(levels[j + 1][2]))
        for i in range(8):
            var k: int = (i + 1) % 8
            var tint: Color = ARMOR
            if i in [1, 2, 5, 6]:
                tint = CAST if j % 3 != 1 else ARMOR
            if j in [0, 5]:
                tint = EDGE if i in [0, 3, 4, 7] else CAST
            _quad(faces, bottom[i], bottom[k], top[k], top[i], tint)
        _outline_range(outline_ranges, start, faces.size())
    var foot: Array[Vector3] = _tower_outline(0.555, 0.145, 0.206)
    var crown: Array[Vector3] = _tower_outline(2.085, 0.136, 0.194)
    for i in range(8):
        var j: int = (i + 1) % 8
        _tri(faces, Vector3(0.80, 0.555, -0.280),
            foot[j], foot[i], DARK)
        _tri(faces, Vector3(0.80, 2.085, -0.280),
            crown[i], crown[j], CAST)
    # The end caps lie inside the first/last section's convex projection.
    # Their vertices are already represented by those section rings.
    # Keep them out of the normal selection pass, but in the render mesh.


static func _tower_outline(y: float, half_x: float,
        half_z: float) -> Array[Vector3]:
    var x0: float = 0.80 - half_x
    var x1: float = 0.80 + half_x
    var z0: float = -0.28 - half_z
    var z1: float = -0.28 + half_z
    var clip: float = 0.065
    return [
        Vector3(x0 + clip, y, z0),
        Vector3(x1 - clip, y, z0),
        Vector3(x1, y, z0 + clip),
        Vector3(x1, y, z1 - clip),
        Vector3(x1 - clip, y, z1),
        Vector3(x0 + clip, y, z1),
        Vector3(x0, y, z1 - clip),
        Vector3(x0, y, z0 + clip)
    ]


static func _service_hatch(faces: Array, side: float, outline_ranges: Array[Vector2i]) -> void:
    # Maintenance door in the flank: raised 8-sided rim, sloping relief and
    # a recessed inner panel. The narrow hinge side is structurally distinct.
    var center := Vector2(-0.295, 1.535) # z, y
    _side_octagon(faces, outline_ranges, side, center, Vector2(0.315, 0.565),
        0.202, DARK, CAST, 0.68)
    _side_octagon(faces, outline_ranges, side, center, Vector2(0.256, 0.493),
        0.194, INSET, STEEL, 0.80)
    # Two raised longitudinal die-cast reinforcing creases.
    for dz in [-0.078, 0.014]:
        var z: float = center.x + float(dz)
        _side_bar(faces, outline_ranges, side, z, 1.530, 0.020, 0.35,
            0.209, EDGE if dz < 0.0 else ARMOR)
    # Lower identification stamp, deliberately not a luminous square.
    _side_bar(faces, outline_ranges, side, -0.300, 1.345, 0.139, 0.018, 0.208, CAST)


static func _side_octagon(faces: Array, outline_ranges: Array[Vector2i], side: float, center: Vector2,
        size: Vector2, x_away: float, inside_color: Color,
        bevel_color: Color, inset_ratio: float) -> void:
    # x_away is distance from tower centre 0.8; local section is YZ.
    # True bevel vertices and inner panel are connected, not a texture.
    var start: int = faces.size()
    var outer_x: float = 0.80 + side * x_away
    var inner_x: float = 0.80 + side * (x_away - 0.027)
    var outer: Array[Vector2] = _octagon(center, size)
    var inner: Array[Vector2] = _octagon(center, size * inset_ratio)
    for i in range(8):
        var j: int = (i + 1) % 8
        var a := Vector3(outer_x, outer[i].y, outer[i].x)
        var b := Vector3(outer_x, outer[j].y, outer[j].x)
        var c := Vector3(inner_x, inner[j].y, inner[j].x)
        var d := Vector3(inner_x, inner[i].y, inner[i].x)
        _quad(faces, a, b, c, d,
            EDGE if i in [0, 4] else bevel_color)
        _tri(faces, Vector3(inner_x, center.y, center.x), d, c,
            inside_color)
    _outline_range(outline_ranges, start, faces.size())


static func _octagon(center: Vector2, size: Vector2) -> Array[Vector2]:
    var rx: float = size.x * 0.5
    var ry: float = size.y * 0.5
    var dx: float = rx * 0.26
    var dy: float = ry * 0.17
    return [
        center + Vector2(-rx + dx, -ry),
        center + Vector2(rx - dx, -ry),
        center + Vector2(rx, -ry + dy),
        center + Vector2(rx, ry - dy),
        center + Vector2(rx - dx, ry),
        center + Vector2(-rx + dx, ry),
        center + Vector2(-rx, ry - dy),
        center + Vector2(-rx, -ry + dy)
    ]


static func _side_cooling_channel(faces: Array, side: float, outline_ranges: Array[Vector2i]) -> void:
    # Separate lower heat exchanger. There is a dark recess, and each fin
    # is pitched in depth so it catches light with a proper face normal.
    _side_octagon(faces, outline_ranges, side, Vector2(-0.280, 0.885),
        Vector2(0.314, 0.385), 0.208, INSET, CAST, 0.78)
    for i in range(6):
        var start: int = faces.size()
        var y: float = 0.752 + float(i) * 0.050
        var x0: float = 0.80 + side * 0.215
        var x1: float = 0.80 + side * 0.237
        var left: float = -0.392
        var right: float = -0.163
        _quad(faces, Vector3(x0, y - 0.012, left),
            Vector3(x0, y - 0.012, right),
            Vector3(x1, y + 0.012, right),
            Vector3(x1, y + 0.012, left),
            CAST if i % 2 == 0 else EDGE)
        _outline_range(outline_ranges, start, faces.size())
    _side_bar(faces, outline_ranges, side, -0.173, 0.712, 0.028, 0.031,
        0.240, CYAN)


static func _latch_and_hinges(faces: Array, side: float, outline_ranges: Array[Vector2i]) -> void:
    # Machined hinge discs with an actual recessed bore. Each shares the
    # 10-vertex ring profile, without another mesh or separate draw call.
    for height in [1.345, 1.710]:
        _side_annulus(faces, outline_ranges, side, -0.459, float(height),
            0.032, 0.014, 0.245)
    _side_annulus(faces, outline_ranges, side, -0.126, 1.530, 0.049, 0.024, 0.250)
    # The perpendicular latch lever is a bevelled forged tab.
    _side_bar(faces, outline_ranges, side, -0.125, 1.553, 0.032, 0.135,
        0.261, STEEL)
    _side_bar(faces, outline_ranges, side, -0.125, 1.608, 0.065, 0.028,
        0.278, AMBER)


static func _side_annulus(faces: Array, outline_ranges: Array[Vector2i], side: float, z: float,
        y: float, outer_radius: float, inner_radius: float,
        x_distance: float) -> void:
    var start: int = faces.size()
    var outer_x: float = 0.80 + side * x_distance
    var inner_x: float = 0.80 + side * (x_distance - 0.016)
    for i in range(10):
        var a: float = TAU * float(i) / 10.0
        var b: float = TAU * float(i + 1) / 10.0
        var ao := Vector3(outer_x, y + sin(a) * outer_radius,
            z + cos(a) * outer_radius)
        var bo := Vector3(outer_x, y + sin(b) * outer_radius,
            z + cos(b) * outer_radius)
        var ai := Vector3(inner_x, y + sin(a) * inner_radius,
            z + cos(a) * inner_radius)
        var bi := Vector3(inner_x, y + sin(b) * inner_radius,
            z + cos(b) * inner_radius)
        _quad(faces, ao, bo, bi, ai, EDGE if i % 3 == 0 else CAST)
    # Each hinge is a separate exterior decagon. Its internal bore is not
    # part of the selection outer boundary (black surface ink is unchanged).
    _outline_range(outline_ranges, start, faces.size())


static func _side_bar(faces: Array, outline_ranges: Array[Vector2i], side: float, z: float,
        y: float, width: float, height: float, distance: float,
        color: Color) -> void:
    # A pitched trapezoid with physical side thickness, not a 2D line.
    var start: int = faces.size()
    var x0: float = 0.80 + side * distance
    var x1: float = 0.80 + side * (distance + 0.016)
    var z0: float = z - width * 0.5
    var z1: float = z + width * 0.5
    var y0: float = y - height * 0.5
    var y1: float = y + height * 0.5
    _quad(faces, Vector3(x0, y0, z0), Vector3(x0, y0, z1),
        Vector3(x1, y1, z1), Vector3(x1, y1, z0), color)
    _outline_range(outline_ranges, start, faces.size())
    # Single visible pitched surface (do not duplicate a coplanar quad).


static func _diagonal_foot(faces: Array, side: float, outline_ranges: Array[Vector2i]) -> void:
    # Two triangular cast brace webs connect the sensor mast to the original
    # cabinet; outer points remain inside the original selection footprint.
    for z0 in [-0.415, -0.120]:
        var z: float = float(z0)
        var x_a: float = 0.80 + side * 0.125
        var x_b: float = 0.80 + side * 0.180
        var x_c: float = 0.80 + side * 0.105
        var a := Vector3(x_a, 0.305, z)
        var b := Vector3(x_b, 0.635, z)
        var c := Vector3(x_c, 0.635, z + 0.108)
        var d := Vector3(x_a, 0.305, z + 0.048)
        var start: int = faces.size()
        _quad(faces, a, b, c, d, CAST)
        _quad(faces, a + Vector3(0, 0, -0.011),
            b + Vector3(0, 0, -0.011), b, a, EDGE)
        # Braces are not guaranteed planar/convex as a whole.
        for index in range(start, faces.size()):
            _outline_range(outline_ranges, index, index + 1)


static func _lower_front_vent(faces: Array, outline_ranges: Array[Vector2i]) -> void:
    # Replaces the separate, featureless block at front (+Z) of the lower
    # TRAINING cabinet. x 0.255..0.585, y 0.19..0.71 in source model.
    var center := Vector2(0.420, 0.445)
    var frame: Array[Vector2] = _octagon(center, Vector2(0.338, 0.512))
    var pocket: Array[Vector2] = _octagon(center, Vector2(0.272, 0.412))
    # Real tapered mounting well connects the cassette to the cabinet face
    # at z=0.27. Without this bridge the old flat side block floated.
    var start: int = faces.size()
    for i in range(8):
        var j: int = (i + 1) % 8
        var rear_a: Vector2 = center + (frame[i] - center) * 0.86
        var rear_b: Vector2 = center + (frame[j] - center) * 0.86
        _quad(faces, Vector3(rear_a.x, rear_a.y, 0.275),
            Vector3(rear_b.x, rear_b.y, 0.275),
            Vector3(frame[j].x, frame[j].y, 0.555),
            Vector3(frame[i].x, frame[i].y, 0.555),
            ARMOR if i % 2 == 0 else CAST)
    _outline_range(outline_ranges, start, faces.size())
    start = faces.size()
    for i in range(8):
        var j: int = (i + 1) % 8
        _quad(faces,
            Vector3(frame[i].x, frame[i].y, 0.555),
            Vector3(frame[j].x, frame[j].y, 0.555),
            Vector3(pocket[j].x, pocket[j].y, 0.570),
            Vector3(pocket[i].x, pocket[i].y, 0.570), EDGE)
        _tri(faces, Vector3(center.x, center.y, 0.562),
            Vector3(pocket[i].x, pocket[i].y, 0.570),
            Vector3(pocket[j].x, pocket[j].y, 0.570), INSET)
    _outline_range(outline_ranges, start, faces.size())
    for i in range(6):
        start = faces.size()
        var y: float = 0.296 + float(i) * 0.050
        _quad(faces, Vector3(0.317, y, 0.574),
            Vector3(0.519, y, 0.574),
            Vector3(0.519, y + 0.017, 0.609),
            Vector3(0.317, y + 0.017, 0.609),
            CAST if i % 2 == 0 else STEEL)
        _outline_range(outline_ranges, start, faces.size())
    start = faces.size()
    # Non-emissive cyan indicator lens and a protected amber latch.
    _quad(faces, Vector3(0.515, 0.615, 0.575),
        Vector3(0.554, 0.615, 0.575),
        Vector3(0.554, 0.644, 0.575),
        Vector3(0.515, 0.644, 0.575), CYAN)
    _outline_range(outline_ranges, start, faces.size())
    start = faces.size()
    _quad(faces, Vector3(0.298, 0.222, 0.576),
        Vector3(0.350, 0.222, 0.576),
        Vector3(0.350, 0.246, 0.576),
        Vector3(0.298, 0.246, 0.576), AMBER)
    _outline_range(outline_ranges, start, faces.size())


static func _outline_range(ranges: Array[Vector2i], start: int, end: int) -> void:
    if end > start:
        ranges.append(Vector2i(start * 3, end * 3))


static func _tri(faces: Array, a: Vector3, b: Vector3,
        c: Vector3, color: Color) -> void:
    faces.append([a, b, c, color])


static func _quad(faces: Array, a: Vector3, b: Vector3,
        c: Vector3, d: Vector3, color: Color) -> void:
    _tri(faces, a, b, c, color)
    _tri(faces, a, c, d, color)
