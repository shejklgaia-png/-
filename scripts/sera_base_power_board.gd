extends RefCounted
## SERA BASE / Ver.0.9 POWER CONTROL preview.
## Drawn off the overview at camera-right, not an independent scene.
## No simulation is claimed until the G/H/K/P/C/D/R/X/Y/T/O rules are fixed.
const GRID_SIDE: int = 8
const CELL_PITCH: float = 1.28
const BOARD_CENTER: Vector3 = Vector3(35.5, 0.0, -20.0)
const GENERATOR_ORIGIN: Vector3 = Vector3(8.85, 0.0, -1.65)
const CABLE_SEGMENTS: int = 48
const TUBE_SIDES: int = 8
const CAMERA_SIZE: float = 23.6


static func board_focus() -> Vector3:
    return BOARD_CENTER + Vector3(0.0, 0.4, 0.0)


static func cable_point(t: float) -> Vector3:
    # Generator exit -> curving screen-right cable -> grid inlet.
    # Since camera-right is roughly (+X,-Z), this offset reads left to right.
    var start := GENERATOR_ORIGIN + Vector3(1.20, 0.23, -0.55)
    var finish := BOARD_CENTER + Vector3(-6.26, 0.29, 0.0)
    var route: Vector3 = finish - start
    var across := Vector3(-route.z, 0.0, route.x).normalized()
    var wave: float = sin(t * TAU * 2.25) * sin(PI * t) * 0.94
    return start.lerp(finish, t) + across * wave + Vector3(
        0.0, 0.075 * sin(PI * t) * sin(TAU * t * 3.0), 0.0)


static func _metal(color: Color, glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.22 if not glow else 0.08
    mat.roughness = 0.67
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.35
    return mat


static func _box(parent: Node3D, name: String, at: Vector3,
        size: Vector3, color: Color, luminous: bool = false) -> void:
    var item := MeshInstance3D.new()
    item.name = name
    var box := BoxMesh.new()
    box.size = size
    item.mesh = box
    item.material_override = _metal(color, luminous)
    item.position = at
    parent.add_child(item)


static func _tube(parent: Node3D, name: String, radius: float,
        color: Color, y_offset: float = 0.0, luminous: bool = false) -> void:
    # One indexed 8-sided tube / 48 segments = one mesh, not 48 nodes.
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    for row in range(CABLE_SEGMENTS + 1):
        var t: float = float(row) / float(CABLE_SEGMENTS)
        var point: Vector3 = cable_point(t) + Vector3.UP * y_offset
        var before: Vector3 = cable_point(maxf(0.0, t - 0.005))
        var after: Vector3 = cable_point(minf(1.0, t + 0.005))
        var tangent: Vector3 = (after - before).normalized()
        var across: Vector3 = tangent.cross(Vector3.UP).normalized()
        for side in range(TUBE_SIDES):
            var theta: float = float(side) / float(TUBE_SIDES) * TAU
            var normal: Vector3 = across * cos(theta) + Vector3.UP * sin(theta)
            vertices.append(point + normal * radius)
            normals.append(normal)
    for row in range(CABLE_SEGMENTS):
        for side in range(TUBE_SIDES):
            var a: int = row * TUBE_SIDES + side
            var b: int = row * TUBE_SIDES + (side + 1) % TUBE_SIDES
            var c: int = a + TUBE_SIDES
            var d: int = b + TUBE_SIDES
            indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var item := MeshInstance3D.new()
    item.name = name
    item.mesh = mesh
    item.material_override = _metal(color, luminous)
    parent.add_child(item)


static func _cells(parent: Node3D) -> void:
    var tile_mesh := BoxMesh.new()
    tile_mesh.size = Vector3(1.17, 0.085, 1.17)
    for shade in range(2):
        var groups := MultiMesh.new()
        groups.transform_format = MultiMesh.TRANSFORM_3D
        groups.mesh = tile_mesh
        groups.instance_count = int(GRID_SIDE * GRID_SIDE / 2)
        var index: int = 0
        for z in range(GRID_SIDE):
            for x in range(GRID_SIDE):
                if (x + z) % 2 != shade:
                    continue
                var offset := Vector3(
                    (float(x) - 3.5) * CELL_PITCH,
                    0.38, (float(z) - 3.5) * CELL_PITCH)
                groups.set_instance_transform(index,
                    Transform3D(Basis.IDENTITY, BOARD_CENTER + offset))
                index += 1
        var node := MultiMeshInstance3D.new()
        node.name = "PowerTileShade%d" % shade
        node.multimesh = groups
        node.material_override = _metal(
            Color("#243948") if shade == 0 else Color("#304656"))
        parent.add_child(node)


static func build(parent: Node3D) -> Node3D:
    var stage := Node3D.new()
    stage.name = "PowerPuzzleZone"
    parent.add_child(stage)

    var cable := Node3D.new()
    cable.name = "WindingPowerCable"
    stage.add_child(cable)
    _tube(cable, "PowerCableOuter", 0.145, Color("#161d28"))
    _tube(cable, "PowerCableSignalStripe", 0.034,
        Color("#5fabc4"), 0.137, true)
    _box(cable, "CableGeneratorPlug", cable_point(0.0),
        Vector3(0.42, 0.28, 0.40), Color("#45697b"))
    _box(cable, "CableBoardPlug", cable_point(1.0),
        Vector3(0.45, 0.34, 0.48), Color("#5a899e"))

    var frame := Node3D.new()
    frame.name = "PowerGrid8x8"
    stage.add_child(frame)
    # One continuous plinth under the 64 actual slot surfaces.
    _box(frame, "GridFoundation", BOARD_CENTER + Vector3(0, 0.12, 0),
        Vector3(11.75, 0.30, 11.75), Color("#1a252f"))
    _box(frame, "GridUnderframe", BOARD_CENTER + Vector3(0, 0.29, 0),
        Vector3(11.16, 0.10, 11.16), Color("#506879"))
    _cells(frame)
    for side in [-1.0, 1.0]:
        _box(frame, "GridEdgeEastWest", BOARD_CENTER +
            Vector3(0, 0.48, side * 5.40),
            Vector3(11.0, 0.19, 0.20), Color("#526e7e"))
        _box(frame, "GridEdgeNorthSouth", BOARD_CENTER +
            Vector3(side * 5.40, 0.48, 0),
            Vector3(0.20, 0.19, 11.0), Color("#526e7e"))
        _box(frame, "GridTraceEastWest", BOARD_CENTER +
            Vector3(0, 0.585, side * 5.40),
            Vector3(10.9, 0.019, 0.045), Color("#79b0c3"), true)
        _box(frame, "GridTraceNorthSouth", BOARD_CENTER +
            Vector3(side * 5.40, 0.585, 0),
            Vector3(0.045, 0.019, 10.9), Color("#79b0c3"), true)

    var legend := Label3D.new()
    legend.name = "PowerGridLabel"
    legend.text = "POWER GRID / 08 x 08"
    legend.font_size = 48
    legend.pixel_size = 0.009
    legend.modulate = Color("#a5c7d4")
    legend.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    legend.position = BOARD_CENTER + Vector3(0, 0.75, -6.10)
    stage.add_child(legend)
    return stage
