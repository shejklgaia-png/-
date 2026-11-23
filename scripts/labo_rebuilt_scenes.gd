extends RefCounted
const IndustrialDetail = preload("res://scripts/sera_labo_industrial_details.gd")
const DeckArchitecture = preload("res://scripts/sera_labo_deck_architecture.gd")
## SERA LABO / REFINE / STORAGE: independent, authored procedural 3D environments.
## No generated textures. Repeated fittings are two colored MultiMesh batches per mount.
## Coordinates keep the existing three camera compositions and CRATE work routes.
const HULL := Color("#273e4d")
const SHADOW := Color("#142b39")
const DEEP := Color("#102633")
const METAL := Color("#5f7988")
const EDGE := Color("#94acb7")
const CYAN := Color("#48bcd1")
const WARM := Color("#c79650")
const WHITE := Color("#d7e9ed")
const COPPER := Color("#9f7358")
var host
var _queue: Dictionary = {}
var _material_cache: Dictionary = {}
var _box_mesh := BoxMesh.new()
var _pipe_mesh := CylinderMesh.new()
var _batch_material: StandardMaterial3D
var _spool: Node3D
var _lift: Node3D
var _refinery_impellers: Array[Node3D] = []
var _industrial_detail
var _deck_architecture

func build(stage) -> void:
    host = stage
    _box_mesh.size = Vector3.ONE
    _pipe_mesh.top_radius = 1.0
    _pipe_mesh.bottom_radius = 1.0
    _pipe_mesh.height = 1.0
    _pipe_mesh.radial_segments = 10
    _batch_material = StandardMaterial3D.new()
    _batch_material.vertex_color_use_as_albedo = true
    _batch_material.vertex_color_is_srgb = true
    _batch_material.metallic = 0.28
    _batch_material.roughness = 0.62
    _build_fabrication()
    _build_refining()
    _build_storage()
    _flush_batches()
    # One authored low-draw-call detail pass per room; keeps existing UI,
    # live 24fps displays, camera, CRATE routing and warehouse identifiers.
    _industrial_detail = IndustrialDetail.new()
    _industrial_detail.build(host.printer_group, host.converter_group,
        host.warehouse_group)
    # Real octagonal floor plates and exposed ceiling steelwork: one static
    # surface per scene, retained alongside the prior facility detail pass.
    _deck_architecture = DeckArchitecture.new()
    _deck_architecture.build(host.printer_group, host.converter_group,
        host.warehouse_group)

func animate(time: float, section: String) -> void:
    if _industrial_detail != null:
        _industrial_detail.animate(time, section)
    if section == "LABO" and is_instance_valid(_spool):
        _spool.rotation.x = time * 0.28
    elif section in ["SMELTER", "RECYCLER"]:
        for index in range(_refinery_impellers.size()):
            _refinery_impellers[index].rotation.y = time * (0.20 + index * 0.08)
    elif section == "STORAGE" and is_instance_valid(_lift):
        _lift.position.y = 0.19 + 0.13 * (0.5 + 0.5 * sin(time * 0.65))

func _node(parent: Node3D, name: String, at: Vector3 = Vector3.ZERO) -> Node3D:
    var item := Node3D.new()
    item.name = name
    item.position = at
    parent.add_child(item)
    return item

func _mat(tint: Color, bright: bool = false) -> StandardMaterial3D:
    var key := tint.to_html() + ("_lit" if bright else "_matte")
    if _material_cache.has(key):
        return _material_cache[key]
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = 0.14 if bright else 0.34
    material.roughness = 0.36 if bright else 0.58
    if bright:
        material.emission_enabled = true
        material.emission = tint
        material.emission_energy_multiplier = 1.45
    _material_cache[key] = material
    return material

func _mesh(parent: Node3D, name: String, shape: Mesh, at: Vector3,
        tint: Color, bright: bool = false) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = name
    item.mesh = shape
    item.position = at
    item.material_override = _mat(tint, bright)
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    item.set_meta("sera_preserve_authored_material", true)
    parent.add_child(item)
    return item

func _box(parent: Node3D, name: String, at: Vector3, size: Vector3,
        tint: Color, bright: bool = false) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    return _mesh(parent, name, shape, at, tint, bright)

func _cylinder(parent: Node3D, name: String, at: Vector3, radius: float,
        height: float, tint: Color, bright: bool = false, sides: int = 16) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = sides
    return _mesh(parent, name, shape, at, tint, bright)

func _ring(parent: Node3D, name: String, at: Vector3,
        inner: float, outer: float, tint: Color, bright: bool = false) -> void:
    var mesh := TorusMesh.new()
    mesh.inner_radius = inner
    mesh.outer_radius = outer
    mesh.ring_segments = 10
    mesh.rings = 28
    _mesh(parent, name, mesh, at, tint, bright)

# Real eight-cut-corner panels for prominent CNC housings and monitor bezels.
# This is an extruded indexed-shape equivalent, not layered rectangular decals.
func _emit_triangle(tool: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3) -> void:
    tool.add_vertex(a)
    tool.add_vertex(b)
    tool.add_vertex(c)

func _cut_corner_mesh(size: Vector3, bevel: float) -> ArrayMesh:
    var hx: float = size.x * 0.5
    var hy: float = size.y * 0.5
    var hz: float = size.z * 0.5
    var cut: float = minf(bevel, minf(hx, hy) * 0.75)
    var rim: Array[Vector2] = [
        Vector2(-hx + cut, -hy), Vector2(hx - cut, -hy),
        Vector2(hx, -hy + cut), Vector2(hx, hy - cut),
        Vector2(hx - cut, hy), Vector2(-hx + cut, hy),
        Vector2(-hx, hy - cut), Vector2(-hx, -hy + cut)]
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in range(1, 7):
        _emit_triangle(tool,
            Vector3(rim[0].x, rim[0].y, hz),
            Vector3(rim[index].x, rim[index].y, hz),
            Vector3(rim[index + 1].x, rim[index + 1].y, hz))
        _emit_triangle(tool,
            Vector3(rim[0].x, rim[0].y, -hz),
            Vector3(rim[index + 1].x, rim[index + 1].y, -hz),
            Vector3(rim[index].x, rim[index].y, -hz))
    for index in range(8):
        var a: Vector2 = rim[index]
        var b: Vector2 = rim[(index + 1) % 8]
        var front_a := Vector3(a.x, a.y, hz)
        var front_b := Vector3(b.x, b.y, hz)
        var back_a := Vector3(a.x, a.y, -hz)
        var back_b := Vector3(b.x, b.y, -hz)
        _emit_triangle(tool, front_a, back_b, front_b)
        _emit_triangle(tool, front_a, back_a, back_b)
    tool.generate_normals()
    return tool.commit()

func _beveled_panel(parent: Node3D, name: String, at: Vector3,
        size: Vector3, cut: float, tint: Color) -> MeshInstance3D:
    return _mesh(parent, name, _cut_corner_mesh(size, cut), at, tint)

func _b(parent: Node3D, at: Vector3, size: Vector3, tint: Color) -> void:
    _push(parent, "box", Transform3D(Basis.IDENTITY.scaled_local(size), at), tint)

func _line(parent: Node3D, a: Vector3, b: Vector3,
        diameter: float, tint: Color) -> void:
    var direction := b - a
    if direction.length_squared() < 0.000001:
        return
    var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
    basis = basis.scaled_local(Vector3(diameter, direction.length(), diameter))
    _push(parent, "pipe", Transform3D(basis, (a + b) * 0.5), tint)

func _push(parent: Node3D, style: String, pose: Transform3D, tint: Color) -> void:
    var key := str(parent.get_instance_id()) + "_" + style
    if not _queue.has(key):
        _queue[key] = {"parent": parent, "style": style, "poses": [], "tints": []}
    var info: Dictionary = _queue[key]
    info["poses"].append(pose)
    info["tints"].append(tint)

func _flush_batches() -> void:
    for info in _queue.values():
        var poses: Array = info["poses"]
        if poses.is_empty():
            continue
        var colors: Array = info["tints"]
        var pack := MultiMesh.new()
        pack.transform_format = MultiMesh.TRANSFORM_3D
        pack.use_colors = true
        pack.mesh = _box_mesh if info["style"] == "box" else _pipe_mesh
        pack.instance_count = poses.size()
        for i in range(poses.size()):
            pack.set_instance_transform(i, poses[i])
            pack.set_instance_color(i, colors[i])
        var item := MultiMeshInstance3D.new()
        item.name = "BatchedPanels" if info["style"] == "box" else "BatchedPipes"
        item.multimesh = pack
        item.material_override = _batch_material
        item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        item.set_meta("sera_preserve_authored_material", true)
        info["parent"].add_child(item)
    _queue.clear()

func _label(parent: Node3D, caption: String, position: Vector3, font_size: int) -> void:
    host._sign(parent, caption, position, font_size)

func _screen(parent: Node3D, name: String, at: Vector3, size: Vector2,
        mode: int, angle: float = 0.0) -> void:
    var mount := _node(parent, name, at)
    mount.rotation.y = angle
    _beveled_panel(mount, "OctagonalDisplayHousing", Vector3.ZERO,
        Vector3(size.x + 0.15, size.y + 0.15, 0.16), 0.095, METAL)
    _box(mount, "DisplayBezel", Vector3(0, 0, 0.09),
        Vector3(size.x + 0.06, size.y + 0.06, 0.025), DEEP)
    host._live_display(mount, name + "LiveSurface", 0.108, size, mode)
    for side in [-1.0, 1.0]:
        _b(mount, Vector3(side * (size.x * 0.5 + 0.055), 0, 0.115),
            Vector3(0.035, size.y + 0.13, 0.015), EDGE)
    _box(mount, "PoweredLED", Vector3(size.x * 0.48, -size.y * 0.5 - 0.055, 0.115),
        Vector3(0.07, 0.018, 0.016), CYAN, true)

func _light(parent: Node3D, name: String, at: Vector3, tint: Color, energy: float) -> void:
    var lamp := OmniLight3D.new()
    lamp.name = name
    lamp.position = at
    lamp.light_color = tint
    lamp.light_energy = energy
    lamp.omni_range = 5.8
    lamp.shadow_enabled = false
    parent.add_child(lamp)

func _hall(parent: Node3D, theme: String) -> void:
    # Storage is a genuinely larger load-bearing envelope, not a zoomed
    # camera inside the old room. FAB / REFINE retain their original geometry.
    var storage: bool = theme == "storage"
    var primary: Color = HULL
    if theme == "refine":
        primary = Color("#304551")
    elif storage:
        primary = Color("#243b49")
    var width: float = 18.0 if storage else 12.0
    var depth: float = 13.5 if storage else 9.7
    var center_z: float = -1.40 if storage else -1.28
    var rear_z: float = -8.03 if storage else -5.35
    var side_x: float = 8.76 if storage else 5.72
    var side_length: float = 13.50 if storage else 8.2
    _b(parent, Vector3(0, -0.22, center_z), Vector3(width, 0.40, depth), primary)
    _b(parent, Vector3(0, 2.30, rear_z), Vector3(width, 5.2, 0.32), SHADOW)
    if storage:
        # The previous expanded warehouse had only open beams, letting an
        # exterior camera see its roof top and the empty world. Add one solid
        # ceiling facing the room; trusses and lighting remain underneath it.
        # Batched into the existing opaque hall geometry (no extra draw pass).
        _b(parent, Vector3(0, 4.93, center_z),
            Vector3(width, 0.16, depth), HULL)
        # The near-front portal remains behind the new interior camera.
        # Close the side-wall/endplate seams to prevent exterior slivers.
        for x in [-side_x, side_x]:
            _b(parent, Vector3(x, 2.18, 5.08),
                Vector3(0.34, 4.80, 0.45), primary)
    for x in [-side_x, side_x]:
        _b(parent, Vector3(x, 2.18, center_z),
            Vector3(0.25, 4.80, side_length), HULL)
    var rear_columns: Array = [-5.25, -2.70, -0.10, 2.65, 5.25]
    if storage:
        # Keep the -2.32 .. +0.22m freight doorway free of pillars.
        rear_columns = [-8.15, -5.45, -3.10, 2.95, 5.45, 8.15]
    for x in rear_columns:
        _b(parent, Vector3(x, 2.45, rear_z+0.26),
            Vector3(0.22, 4.85, 0.22), METAL)
        _b(parent, Vector3(x, 2.45, rear_z+0.42),
            Vector3(0.065, 4.35, 0.045), DEEP)
    for y in [0.71, 2.17, 3.88]:
        _b(parent, Vector3(0, y, rear_z+0.33),
            Vector3(width-1.40, 0.095, 0.14), METAL)
    var roof_spans: Array = [-4.60, -2.60, -0.40, 1.70]
    if storage:
        roof_spans = [-7.20, -4.65, -2.10, 0.65, 3.30]
    for z in roof_spans:
        _b(parent, Vector3(0, 4.65, z),
            Vector3(width-1.0, 0.23, 0.23), METAL)
        _b(parent, Vector3(0, 4.51, z),
            Vector3(width-1.30, 0.045, 0.31), DEEP)
        var braced_x: Array = [-4.80, 4.80]
        if storage:
            braced_x = [-7.70, -3.85, 3.85, 7.70]
        for x in braced_x:
            _line(parent, Vector3(x, 4.56, z-0.75),
                Vector3(x, 3.95, z+0.10), 0.055, EDGE)
    # Visible ceiling diffusers use the original emissive material.
    var diffuser_x: Array = [-3.80, 0.0, 3.80]
    var diffuser_z: Array = [-1.15]
    if storage:
        diffuser_x = [-6.60, 0.0, 6.60]
        diffuser_z = [-4.10, 1.10]
    for z in diffuser_z:
        for x in diffuser_x:
            _box(parent, "RecessedCeilingDiffuser", Vector3(x, 4.42, z),
                Vector3(1.15, 0.065, 0.22), WHITE, true)
            _b(parent, Vector3(x, 4.48, z),
                Vector3(1.33, 0.07, 0.35), DEEP)
    # The new cast deck is generated separately and covers the old flat seams.
    _light(parent, "CoolRoomFill", Vector3(0.4, 3.65, 0.45),
        Color("#89c9e3"), 0.47)

func _build_fabrication() -> void:
    var room := _node(host, "PrinterScene")
    host.printer_group = room
    _hall(room, "fabricate")
    # The fabrication aperture is oriented exactly toward the RIGHT (+X),
    # directly facing the monitoring station on the opposite side of the aisle.
    # Its open 3D print envelope remains visible from the right-front camera.
    var machine := _node(room, "AtlasOpenFramePrinter", Vector3(-2.42, 0, -1.34))
    machine.rotation.y = PI * 0.5
    machine.scale = Vector3(1.30, 1.20, 1.06)
    _b(machine, Vector3(0, 0.25, 0.06), Vector3(3.14, 0.50, 2.12), DEEP)
    _b(machine, Vector3(0, 0.53, 0.08), Vector3(2.62, 0.10, 1.65), METAL)
    _b(machine, Vector3(0, 0.61, 0.08), Vector3(2.19, 0.045, 1.32), SHADOW)
    _b(machine, Vector3(0, 0.64, 0.08), Vector3(1.93, 0.025, 1.12), Color("#658c9a"))
    for x in [-1.36, 1.36]:
        for z in [-0.77, 0.80]:
            _b(machine, Vector3(x, 1.60, z), Vector3(0.19, 2.23, 0.20), METAL)
            _b(machine, Vector3(x, 1.63, z + 0.107),
                Vector3(0.07, 1.68, 0.027), DEEP)
        _line(machine, Vector3(x, 0.84, -0.85), Vector3(x, 2.42, 0.90), 0.035, EDGE)
    _b(machine, Vector3(0, 2.79, 0.02), Vector3(2.95, 0.34, 1.84), HULL)
    _beveled_panel(machine, "GantryCutCornerFascia",
        Vector3(0, 2.54, 0.91), Vector3(2.81, 0.33, 0.18), 0.09, METAL)
    _b(machine, Vector3(0, 2.38, 0.95), Vector3(2.56, 0.075, 0.12), EDGE)
    for x in [-1.13, 1.13]:
        _box(machine, "WorkEnvelopeIlluminator", Vector3(x, 1.47, 0.80),
            Vector3(0.035, 1.42, 0.04), CYAN, true)
    for i in range(11):
        _b(machine, Vector3(-1.05 + i * 0.21, 2.94, 0.95),
            Vector3(0.13, 0.075, 0.04), DEEP)
    _label(machine, "SERA / FAB", Vector3(0, 2.60, 1.045), 38)
    # Cross-rail and functional mobile head are part of the live animation.
    for z in [-0.52, 0.55]:
        _line(machine, Vector3(-1.25, 2.15, z),
            Vector3(1.25, 2.15, z), 0.055, EDGE)
    host.printer_nozzle = _node(machine, "PrinterNozzle",
        Vector3(0.13, 2.09, 0.24))
    _b(host.printer_nozzle, Vector3(0, 0, 0), Vector3(0.41, 0.22, 0.39), EDGE)
    _b(host.printer_nozzle, Vector3(0, -0.18, 0), Vector3(0.14, 0.24, 0.17), METAL)
    _cylinder(host.printer_nozzle, "ExtrusionEmitter",
        Vector3(0, -0.33, 0), 0.065, 0.15, CYAN, true)
    host.printed_part = _node(machine, "PrintedPart", Vector3(-0.34, 0.95, -0.06))
    var dome := SphereMesh.new()
    dome.radius = 0.52
    dome.height = 0.98
    dome.radial_segments = 16
    dome.rings = 8
    var helmet := _mesh(host.printed_part, "ForgingShell", dome,
        Vector3(0, 0.18, 0), Color("#819da9"))
    helmet.scale = Vector3(0.79, 0.53, 0.79)
    _b(host.printed_part, Vector3(0, -0.06, 0.22),
        Vector3(0.70, 0.20, 0.35), HULL)
    _box(host.printed_part, "OpticalVisor", Vector3(0, 0.16, 0.39),
        Vector3(0.53, 0.12, 0.060), CYAN, true)
    for x in [-0.33, 0.33]:
        _b(host.printed_part, Vector3(x, 0.05, 0.27),
            Vector3(0.12, 0.35, 0.11), EDGE)
    # Dual cable reels with six real radial spokes; one slowly rotates.
    _spool = _node(machine, "LiveFeedSpool", Vector3(1.57, 1.70, -0.10))
    for x in [-0.13, 0.13]:
        var wheel := _cylinder(_spool, "SideReel", Vector3(x, 0, 0),
            0.41, 0.07, METAL)
        wheel.rotation.z = PI * 0.5
    for spoke in range(6):
        var angle: float = TAU * spoke / 6.0
        _line(_spool, Vector3(0, 0, 0),
            Vector3(0, sin(angle) * 0.35, cos(angle) * 0.35), 0.035, COPPER)
    _line(machine, Vector3(1.60, 1.70, -0.08),
        Vector3(0.55, 2.62, -0.40), 0.040, COPPER)
    for side in [-1.0, 1.0]:
        _b(machine, Vector3(side * 1.03, 0.37, 1.08),
            Vector3(0.68, 0.51, 0.12), HULL)
        for j in range(4):
            _b(machine, Vector3(side * 1.03 - 0.21 + j * 0.14, 0.34, 1.16),
                Vector3(0.07, 0.19, 0.027), SHADOW)
    # Tool discharge points toward the console; the octagonal platen and its
    # linear rollers make the gantry's +X fabrication output explicit.
    _beveled_panel(machine, "RightFacingFabricationOutfeed",
        Vector3(0, 0.73, 1.28), Vector3(1.52, 0.11, 0.73), 0.12, METAL)
    for roll in range(5):
        _line(machine, Vector3(-0.58 + roll * 0.29, 0.81, 1.39),
            Vector3(-0.58 + roll * 0.29, 0.81, 1.60), 0.036, EDGE)
    for side in [-1.0, 1.0]:
        _b(machine, Vector3(side * 0.70, 0.77, 1.46),
            Vector3(0.07, 0.14, 0.42), HULL)
    # Workshop stores are kept behind the printer, not between the two
    # machines, leaving a clear walking corridor for the roaming CRATE.
    for i in range(2):
        var x: float = -4.85 + 0.57 * i
        _b(room, Vector3(x, 0.52, 1.62), Vector3(0.47, 0.96, 0.78), METAL)
        _b(room, Vector3(x, 0.69, 2.03), Vector3(0.21, 0.055, 0.035), EDGE)
    # Right-side command station: large 24fps process monitor, machined
    # octagonal chassis and low-profile controls rather than a bare pedestal.
    var desk := _node(room, "TechnicalConsole", Vector3(2.58, 0, -1.35))
    desk.rotation.y = -0.34
    _b(desk, Vector3(0, 0.16, 0.01), Vector3(1.15, 0.26, 1.00), DEEP)
    _beveled_panel(desk, "TaperedOperatorPlinth",
        Vector3(0, 0.75, 0.03), Vector3(0.81, 1.21, 0.78), 0.13, HULL)
    _beveled_panel(desk, "FullWidthControlDeck",
        Vector3(0, 1.35, 0.20), Vector3(1.94, 0.17, 0.92), 0.16, METAL)
    _b(desk, Vector3(0, 1.44, 0.48), Vector3(1.75, 0.040, 0.27), DEEP)
    for side in [-1.0, 1.0]:
        _line(desk, Vector3(side * 0.69, 1.33, -0.22),
            Vector3(side * 0.66, 1.85, -0.22), 0.077, EDGE)
        _b(desk, Vector3(side * 0.79, 1.32, 0.57),
            Vector3(0.16, 0.045, 0.14), CYAN, true)
    _beveled_panel(desk, "MonitorRearSpine",
        Vector3(0, 2.06, -0.17), Vector3(1.98, 1.25, 0.20),
        0.17, SHADOW)
    _screen(desk, "PrintProgressMonitor", Vector3(0, 2.07, -0.02),
        Vector2(1.78, 1.06), 0)
    for row in range(2):
        for key in range(7):
            _b(desk, Vector3(-0.60 + key * 0.20, 1.50,
                0.36 + row * 0.15), Vector3(0.13, 0.024, 0.105),
                EDGE if (key + row) % 4 == 0 else HULL)
    for vent in range(6):
        _b(desk, Vector3(0.41, 0.63 + vent * 0.13, 0.43),
            Vector3(0.15, 0.045, 0.03), DEEP)
    _label(desk, "PRINT / OS", Vector3(0, 2.82, 0.04), 30)
    # An overhead service line links the fabrication cell with the command
    # station; a precisely framed floor passage signals their interaction.
    _line(room, Vector3(-1.20, 3.65, -2.62),
        Vector3(2.55, 3.65, -2.62), 0.082, EDGE)
    _line(room, Vector3(-1.20, 3.65, -2.62),
        Vector3(-1.35, 3.11, -2.38), 0.068, COPPER)
    _line(room, Vector3(2.55, 3.65, -2.62),
        Vector3(2.55, 2.93, -1.72), 0.058, COPPER)
    for i in range(10):
        _b(room, Vector3(-0.64 + i * 0.32, 0.064, 0.88),
            Vector3(0.17, 0.017, 0.04), CYAN if i % 3 == 0 else METAL)
    for z in [-0.92, 1.08]:
        _b(room, Vector3(0.52, 0.053, z),
            Vector3(3.56, 0.025, 0.044), EDGE)
    for x in [-0.65, 1.85]:
        _beveled_panel(room, "OperatorDockingPoint",
            Vector3(x, 0.054, -0.12), Vector3(0.52, 0.026, 0.52), 0.08,
            Color("#3c6677"))
    # Service gate gives scale to the enclosed room without blocking the machine.
    for x in [1.65, 3.66]:
        _b(room, Vector3(x, 1.65, -4.97),
            Vector3(0.18, 3.22, 0.26), EDGE)
    _b(room, Vector3(2.66, 3.24, -4.94),
        Vector3(2.26, 0.20, 0.20), METAL)
    _b(room, Vector3(2.66, 1.56, -5.0),
        Vector3(1.72, 3.04, 0.07), HULL)
    _label(room, "LAB / 01", Vector3(3.70, 3.75, -4.85), 35)

func _build_refining() -> void:
    var room := _node(host, "MaterialConversionScene")
    host.converter_group = room
    _hall(room, "refine")
    var colors: Array[Color] = [
        Color("#efa24b"), Color("#53c6de"), Color("#b087df")]
    var locations: Array[Vector3] = [
        Vector3(-2.65, 0, -0.35),
        Vector3(-0.15, 0, -1.05),
        Vector3(1.70, 0, -1.60)]
    # Overhead gantry, header pipe and individually routed feeds.
    for z in [-4.38, -3.78]:
        _line(room, Vector3(-4.8, 3.82, z),
            Vector3(4.1, 3.82, z), 0.12, COPPER)
    for index in range(3):
        var station := _node(room, "RefineryTower_%02d" % index, locations[index])
        var color: Color = colors[index]
        # A machined octagonal core with layered lips, bolted cages and turbine.
        _cylinder(station, "BaseSocket", Vector3(0, 0.43, 0),
            0.90, 0.50, HULL, false, 10)
        _cylinder(station, "ReactionBase", Vector3(0, 0.78, 0),
            0.79, 0.24, METAL, false, 12)
        _cylinder(station, "ReactorChamber", Vector3(0, 1.60, 0),
            0.65, 1.52, Color("#263e4c"), false, 12)
        for y in [0.92, 1.50, 2.12, 2.46]:
            _ring(station, "ReinforcedCollar", Vector3(0, y, 0), 0.66, 0.77, EDGE)
        for angle in range(8):
            var a: float = TAU * angle / 8.0
            var x: float = cos(a) * 0.74
            var z: float = sin(a) * 0.74
            _line(station, Vector3(x, 0.77, z),
                Vector3(x, 2.43, z), 0.040, METAL)
        _cylinder(station, "UpperCap", Vector3(0, 2.54, 0),
            0.81, 0.28, HULL, false, 12)
        _cylinder(station, "PortFlange", Vector3(0, 2.76, 0),
            0.36, 0.22, EDGE)
        _line(station, Vector3(0, 2.83, 0),
            Vector3(0, 3.55, 0), 0.14, COPPER)
        _line(room, locations[index] + Vector3(0, 3.55, 0),
            Vector3(locations[index].x, 3.82, -3.78), 0.11, METAL)
        _cylinder(station, "ThermalCore", Vector3(0, 1.57, 0),
            0.35, 0.94, color, true, 9)
        var impeller := _node(station, "ActiveImpeller", Vector3(0, 1.56, 0))
        _refinery_impellers.append(impeller)
        for blade in range(6):
            var a: float = TAU * blade / 6.0
            _line(impeller, Vector3.ZERO,
                Vector3(cos(a) * 0.59, 0.13, sin(a) * 0.59), 0.070, EDGE)
        # The existing animated ore rotor remains a distinct reference.
        var rotor := _node(station, "CrystalRotor_%d" % index,
            Vector3(0, 1.05, 0))
        host.converter_crystals.append(rotor)
        for piece in range(7):
            var crystal := _cylinder(rotor, "FacetedFeedstock",
                Vector3((piece % 3 - 1) * 0.20, (piece / 3) * 0.12,
                (piece % 2 - 0.5) * 0.24),
                0.13, 0.22, color, piece == 0, 5)
            crystal.rotation.z = float(piece) * 0.29
        _box(station, "SightWindow", Vector3(0, 1.68, 0.658),
            Vector3(0.44, 0.81, 0.085), color, true)
        _b(station, Vector3(0, 1.68, 0.711),
            Vector3(0.30, 0.68, 0.028), DEEP)
        for side in [-1.0, 1.0]:
            _b(station, Vector3(side * 0.32, 1.62, 0.715),
                Vector3(0.056, 0.94, 0.06), EDGE)
        _b(station, Vector3(0, 0.42, 0.83),
            Vector3(0.68, 0.20, 0.14), HULL)
        _box(station, "TowerStatusLight", Vector3(0, 0.45, 0.92),
            Vector3(0.46, 0.06, 0.026), color, true)
        _label(station, "R%02d" % (index + 1),
            Vector3(0, 2.72, 0.86), 26)
    # Four physically populated feed bins, dissimilar silhouettes by material.
    var bins := _node(room, "MaterialReceivingArray", Vector3(-0.44, 0, 1.68))
    for bin in range(4):
        var x: float = -2.67 + bin * 1.42
        var tint: Color = colors[bin] if bin < 3 else Color("#91ae89")
        _b(bins, Vector3(x, 0.32, 0), Vector3(1.26, 0.46, 0.92), HULL)
        _b(bins, Vector3(x, 0.57, -0.03), Vector3(1.11, 0.04, 0.80), SHADOW)
        for side in [-1.0, 1.0]:
            _b(bins, Vector3(x + side * 0.60, 0.57, 0),
                Vector3(0.07, 0.13, 0.90), EDGE)
        for j in range(6):
            var sx: float = x - 0.35 + (j % 3) * 0.34
            var sz: float = -0.20 + int(j / 3) * 0.38
            if bin % 2 == 0:
                _b(bins, Vector3(sx, 0.67, sz),
                    Vector3(0.25, 0.19, 0.24), tint)
                _b(bins, Vector3(sx, 0.78, sz),
                    Vector3(0.16, 0.055, 0.18), EDGE)
            else:
                _line(bins, Vector3(sx, 0.62, sz),
                    Vector3(sx + 0.06, 0.85, sz), 0.11, tint)
        _b(bins, Vector3(x, 0.26, 0.49),
            Vector3(0.51, 0.12, 0.035), WARM)
    # A rear elevated pipe service deck distinguishes REFINE from the FAB hall.
    _b(room, Vector3(-0.17, 3.38, -4.05),
        Vector3(9.3, 0.16, 0.90), METAL)
    for i in range(13):
        _b(room, Vector3(-4.50 + i * 0.72, 3.49, -3.60),
            Vector3(0.07, 0.80, 0.07), EDGE)
    _b(room, Vector3(-0.17, 3.92, -3.58),
        Vector3(9.27, 0.075, 0.08), WARM)
    # Three preserved independent animated monitors: FLOW, PURITY, RECYCLE.
    for i in range(2):
        var console := _node(room, "RefineryOperator_%d" % i,
            Vector3(-4.36, 0, 0.55) if i == 0 else Vector3(-1.43, 0, 0.72))
        _b(console, Vector3(0, 0.64, 0), Vector3(0.44, 1.25, 0.46), HULL)
        _b(console, Vector3(0, 1.12, 0.18), Vector3(0.88, 0.12, 0.50), METAL)
        _screen(console, "FlowScreen" if i == 0 else "PurityScreen",
            Vector3(0, 1.55, 0.02), Vector2(0.83, 0.57), 1 if i == 0 else 2)
    _screen(room, "RecycleStatus", Vector3(4.04, 2.86, -4.83),
        Vector2(1.57, 1.05), 3)
    _label(room, "REFINE / 02", Vector3(3.92, 3.79, -4.80), 31)
    _light(room, "WarmReactorFill", Vector3(-2.30, 3.6, 0.10),
        Color("#d8a66b"), 0.38)

func _build_storage() -> void:
    var room := _node(host, "WarehouseScene")
    host.warehouse_group = room
    _hall(room, "storage")
    # Four substantial rack banks (two depths on each side) keep the center
    # aisle open, doubling stored rack freight before counting side overstock.
    for side in [-1, 1]:
        _build_cargo_rack(room, side, false)
        _build_cargo_rack(room, side, true)
    _build_bulk_cargo_rows(room)
    # Mechanically credible freight bulkhead: segmented shutter, header,
    # angled docking rails and a movable pallet elevator, not flat decoration.
    var gate := _node(room, "RearFreightBulkhead", Vector3(-1.05, 0, -7.74))
    _b(gate, Vector3(0, 1.75, 0),
        Vector3(2.55, 3.52, 0.24), DEEP)
    for segment in range(11):
        var y: float = 0.18 + segment * 0.30
        _b(gate, Vector3(0, y, 0.18),
            Vector3(2.33, 0.27, 0.11), HULL)
        _b(gate, Vector3(0, y + 0.13, 0.24),
            Vector3(2.26, 0.026, 0.028), METAL)
    for edge in [-1.23, 1.23]:
        _b(gate, Vector3(edge, 1.72, 0.26),
            Vector3(0.17, 3.50, 0.27), EDGE)
    _beveled_panel(gate, "FreightHeaderArmor",
        Vector3(0, 3.45, 0.20), Vector3(2.80, 0.26, 0.31), 0.08, METAL)
    for i in range(5):
        _b(gate, Vector3(-0.70 + i * 0.35, 3.44, 0.39),
            Vector3(0.18, 0.07, 0.025), WARM)
    for side in [-1.65, 1.65]:
        _b(room, Vector3(side, 0.018, -0.65),
            Vector3(0.06, 0.025, 6.70), WARM)
    # Crane rail adds a recognizable vertical mass without filling the aisle.
    _line(room, Vector3(3.95, 3.93, -4.30),
        Vector3(3.95, 3.93, 0.50), 0.085, EDGE)
    _lift = _node(room, "ElevatingCargoPallet", Vector3(4.68, 0.19, -3.42))
    _b(_lift, Vector3(0, 0.02, 0),
        Vector3(1.28, 0.16, 1.15), METAL)
    for x in [-0.50, 0.50]:
        _b(_lift, Vector3(x, 0.42, 0),
            Vector3(0.10, 0.85, 0.10), HULL)
    _b(_lift, Vector3(0, 0.67, 0),
        Vector3(1.04, 0.63, 0.85), Color("#867c6c"))
    for x in [-0.30, 0.30]:
        _b(_lift, Vector3(x, 0.72, 0.45),
            Vector3(0.10, 0.26, 0.04), WARM)
    # Both warehouse displays remain live with their original modes.
    _screen(room, "InventoryMasterMonitor",
        Vector3(1.50, 2.61, -7.56), Vector2(2.34, 1.40), 4)
    _b(room, Vector3(1.52, 0.65, -0.75),
        Vector3(0.56, 1.30, 0.61), HULL)
    var scan := _node(room, "WarehouseScanningConsole", Vector3(1.52, 1.43, -0.85))
    scan.rotation.x = -0.24
    _screen(scan, "LocalBarcodeScanner",
        Vector3.ZERO, Vector2(0.94, 0.56), 5)
    host.warehouse_scanner = _node(room, "TravelingInventoryScanner",
        Vector3(1.53, 1.10, -0.86))
    _box(host.warehouse_scanner, "ActiveScanLaser",
        Vector3(0, 0, 0), Vector3(0.14, 0.085, 0.22), CYAN, true)
    _label(room, "STORAGE / 03", Vector3(-3.60, 4.01, -7.55), 36)
    _light(room, "AisleColdFill", Vector3(0, 3.70, -1.25),
        Color("#94b6d7"), 0.42)


func _build_cargo_rack(room: Node3D, side: int, rear: bool) -> void:
    # Keep the original named front racks for the machine-detail add-on.
    # Rear racks have distinct stable names and occupy the expanded depth.
    var rack_name: String = "CargoRackPort" if side < 0 else "CargoRackStarboard"
    if rear:
        rack_name += "Rear"
    var x: float = -5.64 if side < 0 else 5.73
    var z: float = -5.19 if rear else (-1.46 if side < 0 else -1.35)
    var bay := _node(room, rack_name, Vector3(x, 0, z))
    bay.rotation.y = 0.075 if side < 0 else -0.065
    _b(bay, Vector3(0, 2.24, -0.60),
        Vector3(2.77, 4.52, 0.19), DEEP)
    for column_x in [-1.34, 1.34]:
        for post_z in [-0.51, 0.42]:
            _b(bay, Vector3(column_x, 2.27, post_z),
                Vector3(0.15, 4.58, 0.16), EDGE)
        _line(bay, Vector3(column_x, 0.38, -0.58),
            Vector3(column_x, 4.16, 0.44), 0.054, METAL)
    for shelf in range(4):
        var shelf_y: float = 0.39 + shelf * 1.05
        _b(bay, Vector3(0, shelf_y, 0.13),
            Vector3(2.69, 0.13, 1.23), METAL)
        _b(bay, Vector3(0, shelf_y + 0.08, 0.66),
            Vector3(2.52, 0.04, 0.08), WARM)
    for row in range(3):
        for col in range(3):
            var crate_x: float = -0.84 + col * 0.84
            var crate_y: float = 0.78 + row * 1.05
            var crate_z: float = 0.0 if (row + col) % 3 == 0 else -0.12
            var tint: Color = Color("#67818c") if (row + col) % 2 == 0 else Color("#526975")
            if rear:
                tint = Color("#6b777c") if (row + col) % 2 == 0 else Color("#465d69")
            _b(bay, Vector3(crate_x, crate_y, crate_z),
                Vector3(0.67, 0.62, 0.76), tint)
            _b(bay, Vector3(crate_x, crate_y + 0.13, crate_z + 0.39),
                Vector3(0.55, 0.05, 0.035), SHADOW)
            _b(bay, Vector3(crate_x, crate_y - 0.08, crate_z + 0.40),
                Vector3(0.26, 0.09, 0.045), WARM)
            for offset in [-0.27, 0.27]:
                _b(bay, Vector3(crate_x + offset, crate_y, crate_z + 0.39),
                    Vector3(0.038, 0.56, 0.05), EDGE)
    var tags: Array[String] = ["A01", "H02", "H01"]
    if side > 0:
        tags = ["A02", "B02", "B01"]
    if rear:
        tags = ["C03", "D03", "C01"] if side < 0 else ["D04", "E02", "D01"]
    for row in range(3):
        var y: float = 1.14 + row * 1.05
        _b(bay, Vector3(-0.76, y, 0.73),
            Vector3(1.15, 0.59, 0.08), HULL)
        _label(bay, tags[row], Vector3(-0.76, y - 0.05, 0.785),
            70 if rear else 81)
        _b(bay, Vector3(-0.29, y + 0.35, 0.76),
            Vector3(0.15, 0.054, 0.042), WARM)

func _build_bulk_cargo_rows(room: Node3D) -> void:
    # 8 industrial overstock pallets carrying 2 visible cargo cassettes each.
    # Located in the expanded margin outside the four original-scale racks;
    # never invade the CRATE aisle, terminal, lift or freight-door approach.
    var yard := _node(room, "WallSideOverstockPallets")
    for side in [-1.0, 1.0]:
        for slot in range(4):
            var x: float = side * 7.74
            var z: float = -6.55 + float(slot) * 1.80
            var bay_tint: Color = Color("#657985") if slot%2 == 0 else Color("#576f78")
            if side > 0:
                bay_tint = Color("#6e7877") if slot%2 == 0 else Color("#4d6572")
            _b(yard, Vector3(x, 0.18, z),
                Vector3(1.25, 0.20, 1.20), DEEP)
            for foot in [-0.41, 0.41]:
                _b(yard, Vector3(x+foot, 0.065, z),
                    Vector3(0.16, 0.13, 1.07), HULL)
            for layer in range(2):
                var y: float = 0.57 + float(layer) * 0.64
                _b(yard, Vector3(x, y, z),
                    Vector3(1.05, 0.55, 1.03), bay_tint)
                _b(yard, Vector3(x, y + 0.27, z),
                    Vector3(1.10, 0.048, 1.05), EDGE)
                _b(yard, Vector3(x, y - 0.08, z + 0.535),
                    Vector3(0.66, 0.07, 0.027), SHADOW)
                for edge_x in [-0.42, 0.42]:
                    _b(yard, Vector3(x+edge_x, y, z+0.53),
                        Vector3(0.046, 0.50, 0.045), WARM)
                _line(yard, Vector3(x-0.47, y-0.25, z+0.55),
                    Vector3(x+0.47, y+0.25, z+0.55), 0.026, EDGE)
    # Rear replenishment stacks have different silhouettes and keep a clear
    # central portal between them.
    for side in [-1.0, 1.0]:
        var sx: float = side * 3.1
        var zone := _node(room, "BulkOutbound_%d" % int(side), Vector3(sx, 0, -6.75))
        _b(zone, Vector3(0, 0.13, 0), Vector3(1.85, 0.20, 1.20), HULL)
        for j in range(3):
            var x: float = -0.55 + float(j)*0.55
            _b(zone, Vector3(x, 0.53, 0.0),
                Vector3(0.46, 0.61, 0.84), Color("#657b87"))
            _b(zone, Vector3(x, 0.89, 0.0),
                Vector3(0.48, 0.09, 0.89), METAL)
            _b(zone, Vector3(x, 0.51, 0.45),
                Vector3(0.25, 0.10, 0.035), WARM)
