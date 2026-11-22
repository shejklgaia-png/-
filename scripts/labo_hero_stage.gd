extends Node3D
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const CrateModel = preload("res://scripts/sera_crate_model.gd")
const SharedMaterialShading = preload("res://scripts/sera_fullbody_material_preview.gd")
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
## Three independently built portrait-game LABO preview stages. Geometry and
## camera placement follow the three panoramic Scene A / B / C user references.
## Only the CRATE model is shared with the outdoor base; no generic room reuse.
## Retain tiny SubViewport and instanced static cargo for Android performance.
var crate: Node3D
var crate_head: Node3D
var crate_arm: Node3D
var crate_left_arm: Node3D
var hero_camera: Camera3D
var warehouse_scanner: Node3D
var printer_nozzle: Node3D
var printed_part: Node3D
var work_state: String = "walk_to_terminal"
var state_time: float = 0.0
var clock: float = 0.0
var current_section: String = "LABO"
var printer_group: Node3D
var converter_group: Node3D
var warehouse_group: Node3D
var converter_crystals: Array[Node3D] = []
var _materials: Dictionary = {}

func _paint(tint: Color, emissive: bool = false) -> StandardMaterial3D:
    var key: String = tint.to_html(true) + str(emissive)
    if _materials.has(key):
        return _materials[key] as StandardMaterial3D
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.25
    mat.roughness = 0.52
    if emissive:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 1.35
    _materials[key] = mat
    return mat

func _block(parent: Node3D, label: String, point: Vector3,
        size: Vector3, tint: Color, emissive: bool = false) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    var box := BoxMesh.new()
    box.size = size
    part.mesh = box
    part.material_override = _paint(tint, emissive)
    part.position = point
    parent.add_child(part)
    return part

# Static repeated cargo and mechanical fittings share one mesh/draw call per
# group rather than generating a Node3D and a draw call for every small item.
func _instances(parent: Node3D, name: String, points: Array[Vector3],
        box_size: Vector3, tint: Color) -> MultiMeshInstance3D:
    var box := BoxMesh.new()
    box.size = box_size
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = box
    multimesh.instance_count = points.size()
    for i in range(points.size()):
        multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
    var batch := MultiMeshInstance3D.new()
    batch.name = name
    batch.multimesh = multimesh
    batch.material_override = _paint(tint)
    parent.add_child(batch)
    return batch

# The concept art uses restrained illuminated industrial signage, not flat
# UI sprites. These labels live in the same low-resolution 3D stage.
func _sign(parent: Node3D, caption: String, at: Vector3,
        size: int = 42) -> Label3D:
    var label := Label3D.new()
    label.name = "IndustrialSign_" + caption.replace(" ", "_")
    label.text = caption
    # A bundled Latin display face avoids tiny Japanese-font fallback strokes
    # on distant 3D signs. Higher glyph resolution retains world-space scale.
    label.font = LaboSkin.display_font()
    label.font_size = int(round(float(size) * 1.25))
    label.pixel_size = 0.0028
    label.outline_size = 2
    label.outline_modulate = Color("#102633")
    label.modulate = Color("#e3f3f7")
    label.position = at
    parent.add_child(label)
    return label

# SCENE A: the reference is a near-horizontal industrial workshop,
# with a large 3D printer on the LEFT and open service area on the RIGHT.
func _build_print_room() -> void:
    var room: Node3D = printer_group
    _block(room, "FactoryFloor", Vector3(0, -0.15, -1.3),
        Vector3(11.5, 0.28, 9.5), Color("#293d4a"))
    _block(room, "FactoryBackWall", Vector3(0, 2.3, -5.15),
        Vector3(11.5, 4.9, 0.20), Color("#1b3040"))
    _block(room, "PrinterLeftWall", Vector3(-5.38, 2.3, -1.4),
        Vector3(0.20, 4.8, 7.7), Color("#203746"))
    _block(room, "FactoryRightWall", Vector3(5.38, 2.3, -1.4),
        Vector3(0.20, 4.8, 7.7), Color("#203746"))
    for x in [-5.12, -3.3, -1.0, 1.65, 3.55, 5.10]:
        _block(room, "FactoryWallStiffener", Vector3(x, 2.25, -4.96),
            Vector3(0.14, 4.5, 0.24), Color("#3c5565"))
    for y in [0.72, 2.2, 3.8]:
        _block(room, "FactoryWallCrossBar", Vector3(0, y, -4.94),
            Vector3(10.5, 0.105, 0.14), Color("#2d4858"))
    for z in [-4.40, -2.65, -0.75, 1.30]:
        _block(room, "CeilingTruss", Vector3(0, 4.56, z),
            Vector3(10.8, 0.17, 0.20), Color("#354c5b"))
    for x in [-3.45, -0.55, 2.45, 4.4]:
        _block(room, "CeilingWhiteLight", Vector3(x, 4.41, -1.90),
            Vector3(0.87, 0.042, 0.21), Color("#e0e9ec"), true)
    for x in [-4.0, -1.4, 1.25, 3.95]:
        _block(room, "FloorJoint", Vector3(x, 0.008, 0.05),
            Vector3(0.024, 0.015, 5.9), Color("#466575"))
    for z in [-2.65, -0.35, 1.85]:
        _block(room, "CrossFloorJoint", Vector3(0, 0.009, z),
            Vector3(10.3, 0.015, 0.021), Color("#466575"))
    _block(room, "MachineYellowFloorBorder", Vector3(-2.10, 0.017, 1.55),
        Vector3(5.0, 0.015, 0.06), Color("#ac8749"))
    # Visible doors/placard create the reference rear-right silhouette.
    _block(room, "RearAccessDoorLeft", Vector3(1.9, 1.5, -4.77),
        Vector3(1.06, 2.95, 0.14), Color("#354b5a"))
    _block(room, "RearAccessDoorRight", Vector3(3.01, 1.5, -4.77),
        Vector3(1.06, 2.95, 0.14), Color("#304756"))
    _block(room, "DoorFrameLintel", Vector3(2.45, 3.01, -4.67),
        Vector3(2.45, 0.16, 0.22), Color("#657988"))
    _block(room, "DoorIndicator", Vector3(3.67, 1.77, -4.69),
        Vector3(0.12, 0.31, 0.04), Color("#39b8cb"), true)
    _block(room, "WallSeraPlacard", Vector3(2.60, 3.71, -4.68),
        Vector3(2.35, 0.75, 0.14), Color("#394c5a"))
    _sign(room, "SERA", Vector3(2.60, 3.65, -4.58), 70)
    # A few left-wall conduits in the background, never blocking the printer.
    for i in range(3):
        _block(room, "WorkshopConduit",
            Vector3(-5.18+float(i)*0.16, 2.55, -3.52),
            Vector3(0.06, 3.45, 0.10), Color("#8b8068"))
    _block(room, "SmallEquipmentCrate", Vector3(4.35, 0.43, -3.65),
        Vector3(0.80, 0.84, 0.78), Color("#536879"))

# SCENE B: same tonal language as the concept but fully distinct 3D architecture.
# Back pipes and amber catwalk behind three tanks, recycling sign at far right.
func _build_conversion_room() -> void:
    var room: Node3D = converter_group
    _block(room, "RefineryFloor", Vector3(0, -0.15, -1.35),
        Vector3(11.9, 0.28, 9.0), Color("#2e424e"))
    _block(room, "RefineryBackWall", Vector3(0, 2.35, -5.18),
        Vector3(11.8, 5.10, 0.21), Color("#1a3040"))
    for x in [-5.1, -3.1, -0.7, 1.8, 4.95]:
        _block(room, "RefineryVerticalSupport", Vector3(x, 2.4, -4.91),
            Vector3(0.16, 4.9, 0.23), Color("#4b6472"))
    for y in [1.3, 2.5, 3.6]:
        _block(room, "PipeTrunk", Vector3(-0.5, y, -4.74),
            Vector3(10.4, 0.09, 0.12), Color("#6a7e85"))
    for x in [-5.05, -4.55, -4.05, -1.24, 1.05, 3.50]:
        _block(room, "CopperFeedPipe", Vector3(x, 2.80, -4.53),
            Vector3(0.09, 2.54, 0.11), Color("#bb8546"))
    for z in [-3.45, -1.42, 1.40]:
        _block(room, "RefineryCeilingCrossbeam", Vector3(0, 4.68, z),
            Vector3(10.5, 0.18, 0.22), Color("#344c5c"))
    for x in [-3.15, -0.8, 1.75, 3.85]:
        _block(room, "RefineryCeilingLight", Vector3(x, 4.53, -1.75),
            Vector3(0.82, 0.042, 0.21), Color("#e7f0f3"), true)
    var catwalk := Node3D.new()
    catwalk.name = "RefineryCatwalk"
    catwalk.position = Vector3(-0.15, 3.62, -3.95)
    catwalk.rotation.y = -0.05
    room.add_child(catwalk)
    _block(catwalk, "GratedWalkway", Vector3.ZERO,
        Vector3(9.80, 0.15, 0.70), Color("#4c6472"))
    _block(catwalk, "AmberSafetyRail", Vector3(0, 0.70, 0.31),
        Vector3(9.85, 0.07, 0.08), Color("#b08a4c"))
    for k in range(11):
        _block(catwalk, "CatwalkPost", Vector3(-4.6+float(k)*0.92, 0.34, 0.31),
            Vector3(0.05, 0.73, 0.07), Color("#aa874d"))
    # The large rear-right sign and stairs must stay beyond the vat silhouettes.
    var recycle := Node3D.new()
    recycle.name = "RefineryRecycleSign"
    recycle.position = Vector3(3.92, 2.90, -4.79)
    room.add_child(recycle)
    _block(recycle, "RecycleScreenFrame", Vector3.ZERO,
        Vector3(1.72, 1.26, 0.14), Color("#5b7989"))
    _block(recycle, "RecycleDisplay", Vector3(0, 0, 0.085),
        Vector3(1.49, 1.03, 0.035), Color("#134155"))
    # Reference shows a bright triangular recycling pictogram.
    # Build it from three short 3D bars instead of a flat UI decal.
    var triangle_points: Array[Vector2] = [
        Vector2(-0.43, -0.31), Vector2(0.43, -0.31),
        Vector2(0, 0.39)]
    for i in range(3):
        var p1: Vector2 = triangle_points[i]
        var p2: Vector2 = triangle_points[(i+1)%3]
        var center: Vector2 = (p1+p2)*0.5
        var stroke: MeshInstance3D = _block(recycle, "RecyclingTriangleEdge",
            Vector3(center.x, center.y, 0.116),
            Vector3(p1.distance_to(p2), 0.07, 0.024),
            Color("#66e7e6"), true)
        stroke.rotation.z = (p2-p1).angle()
    _sign(recycle, "RECYCLE", Vector3(0, -0.47, 0.114), 25)
    for step in range(7):
        _block(room, "RefineryStairRiser",
            Vector3(4.48, 0.21+float(step)*0.34, -0.5-float(step)*0.48),
            Vector3(0.97, 0.12, 0.54), Color("#788b93"))
    _block(room, "RefineryStairRail", Vector3(4.09, 2.01, -2.22),
        Vector3(0.07, 2.70, 0.09), Color("#9bb1bd"))
    for x in [-3.45, 0.15, 3.25]:
        _block(room, "RefineryFloorSeam", Vector3(x, 0.005, -0.50),
            Vector3(0.027, 0.012, 6.15), Color("#426172"))

# SCENE C: looking down a narrow central storage aisle at near-eye height.
# Sign racks on both sides; diagnostic monitor centered behind CRATE.
func _build_warehouse_room() -> void:
    var room: Node3D = warehouse_group
    _block(room, "StorageAisleFloor", Vector3(0, -0.16, -1.15),
        Vector3(12.3, 0.30, 9.30), Color("#2b3f4c"))
    _block(room, "StorageBackWall", Vector3(0, 2.42, -5.20),
        Vector3(12.2, 5.10, 0.22), Color("#1c3442"))
    _block(room, "StorageLeftWall", Vector3(-5.82, 2.40, -1.25),
        Vector3(0.19, 5.05, 8.45), Color("#293e4e"))
    _block(room, "StorageRightWall", Vector3(5.82, 2.40, -1.25),
        Vector3(0.19, 5.05, 8.45), Color("#293e4e"))
    for x in [-5.5, -2.6, 0.1, 2.7, 5.5]:
        _block(room, "StorageRearPillar", Vector3(x, 2.36, -4.97),
            Vector3(0.17, 4.90, 0.23), Color("#445d6a"))
    for z in [-4.28, -2.60, -0.76, 1.28]:
        _block(room, "AisleRoofGirder", Vector3(0, 4.75, z),
            Vector3(11.5, 0.22, 0.21), Color("#3d5563"))
    for x in [-3.7, -0.70, 2.60, 4.7]:
        _block(room, "StorageCeilingWhiteLamp", Vector3(x, 4.52, -2.20),
            Vector3(1.07, 0.042, 0.20), Color("#ecf4f7"), true)
    for x in [-4.78, -2.32, 0, 2.32, 4.78]:
        _block(room, "StorageFloorTileJoint", Vector3(x, 0.006, -0.40),
            Vector3(0.025, 0.012, 7.3), Color("#53727f"))
    for z in [-3.8, -2.15, -0.60, 1.45]:
        _block(room, "StorageCrossTileJoint", Vector3(0, 0.007, z),
            Vector3(11.7, 0.012, 0.025), Color("#4e707e"))
    _block(room, "StorageYellowAisleBorderL", Vector3(-1.68, 0.017, -0.45),
        Vector3(0.065, 0.018, 6.9), Color("#ac8b4b"))
    _block(room, "StorageYellowAisleBorderR", Vector3(1.71, 0.017, -0.45),
        Vector3(0.065, 0.018, 6.9), Color("#ac8b4b"))
    # Rear monitoring screen (helm blueprint + gauges in this 3D world).
    var monitor := Node3D.new()
    monitor.name = "WarehouseInventoryMonitor"
    monitor.position = Vector3(1.48, 2.57, -4.77)
    monitor.rotation.y = -0.06
    room.add_child(monitor)
    _block(monitor, "StockMonitorOuterFrame", Vector3.ZERO,
        Vector3(2.48, 1.58, 0.19), Color("#7592a0"))
    _block(monitor, "StockMonitorGlass", Vector3(0, 0, 0.13),
        Vector3(2.23, 1.33, 0.02), Color("#17465b"))
    for i in range(5):
        _block(monitor, "InventoryDiagnosticLine",
            Vector3(0.58, 0.53-float(i)*0.23, 0.155),
            Vector3(0.56, 0.035, 0.012), Color("#5baabd"), true)
    _block(monitor, "HeadShellDiagram", Vector3(-0.54, 0.15, 0.153),
        Vector3(0.61, 0.33, 0.018), Color("#52b9d0"), true)
    _block(monitor, "DiagramSideRail", Vector3(-0.55, -0.23, 0.16),
        Vector3(0.90, 0.028, 0.012), Color("#65d0e0"), true)
    _block(room, "WarehouseTerminalColumn", Vector3(1.53, 0.61, -0.75),
        Vector3(0.46, 1.18, 0.49), Color("#4c6674"))
    var terminal := Node3D.new()
    terminal.name = "WarehouseScanningConsole"
    terminal.position = Vector3(1.53, 1.35, -0.87)
    terminal.rotation.x = -0.27
    room.add_child(terminal)
    _block(terminal, "TerminalFrame", Vector3.ZERO,
        Vector3(1.02, 0.67, 0.15), Color("#637f8d"))
    _block(terminal, "TerminalScreen", Vector3(0, 0, 0.09),
        Vector3(0.86, 0.50, 0.021), Color("#27617c"))
    _block(terminal, "TerminalStatus", Vector3(0, 0.03, 0.105),
        Vector3(0.64, 0.17, 0.011), Color("#6bd0e2"), true)

# A: enlarged printer, 60% of visual width as in the reference.
# Printer, arm and workpiece share the same *local* machine coordinates.
func _build_printer() -> void:
    printer_group = Node3D.new()
    printer_group.name = "PrinterScene"
    add_child(printer_group)
    var pivot := Node3D.new()
    pivot.name = "Printer"
    pivot.position = Vector3(-2.23, 0, -0.76)
    pivot.scale = Vector3(1.94, 1.36, 1.23)
    pivot.rotation.y = 0.09
    printer_group.add_child(pivot)
    var metal := Color("#6e8290")
    var dark := Color("#2c4454")
    var cyan := Color("#53c7df")
    _block(pivot, "MachineSubframe", Vector3(0, 0.30, 0),
        Vector3(3.04, 0.50, 1.88), dark)
    _block(pivot, "MachineWorkPlate", Vector3(0, 0.60, 0.03),
        Vector3(2.17, 0.075, 1.42), Color("#577585"))
    _block(pivot, "MachineCoolWorkLight", Vector3(0, 0.665, 0.45),
        Vector3(1.83, 0.032, 0.08), cyan, true)
    # Left and right thick steel pillars form the striking open gantry frame.
    for x in [-1.38, 1.38]:
        _block(pivot, "GantryOuterPost", Vector3(x, 1.57, 0),
            Vector3(0.29, 2.44, 1.81), metal)
        _block(pivot, "GantryDarkInlay", Vector3(x + (0.05 if x < 0 else -0.05),
            1.53, 0.86), Vector3(0.14, 1.78, 0.08), Color("#354d5e"))
    _block(pivot, "GantryRoofCasing", Vector3(0, 2.83, -0.02),
        Vector3(3.11, 0.39, 1.87), Color("#697e8e"))
    _block(pivot, "GantryFrontHeader", Vector3(0, 2.65, 0.95),
        Vector3(2.74, 0.42, 0.16), Color("#405769"))
    _block(pivot, "GantryHeaderBottomTrim", Vector3(0, 2.40, 1.01),
        Vector3(2.84, 0.07, 0.09), Color("#9aabb2"))
    _sign(pivot, "3D PRINTER", Vector3(0, 2.64, 1.061), 43)
    _block(pivot, "InsetDarkBackPanel", Vector3(0, 1.55, -0.89),
        Vector3(2.52, 1.67, 0.08), Color("#153548"))
    for x in [-0.88, 0, 0.88]:
        _block(pivot, "InteriorPrintGuide", Vector3(x, 1.49, -0.83),
            Vector3(0.03, 1.60, 0.04), Color("#39728b"))
    for y in [1.06, 1.76]:
        _block(pivot, "InteriorLightStrip", Vector3(0, y, -0.79),
            Vector3(2.24, 0.028, 0.024), Color("#3faabe"), true)
    for x in [-1.13, 1.13]:
        _block(pivot, "PrintChamberSideLight", Vector3(x, 1.74, 0.67),
            Vector3(0.032, 1.28, 0.035), cyan, true)
    for x in [-1.12, 1.12]:
        _block(pivot, "FrontSafetyPanel", Vector3(x, 0.36, 0.95),
            Vector3(0.63, 0.47, 0.14), Color("#486171"))
    for i in range(3):
        _block(pivot, "YellowSafetyDash", Vector3(-0.95+float(i)*0.19, 0.22, 1.03),
            Vector3(0.12, 0.06, 0.035), Color("#d9a443"), true)
        _block(pivot, "YellowStatusDash", Vector3(0.61+float(i)*0.15, 2.63, 1.06),
            Vector3(0.085, 0.055, 0.035), Color("#d6a03b"), true)
    _block(pivot, "VentGrille", Vector3(0, 0.36, 1.02),
        Vector3(1.04, 0.13, 0.04), Color("#101f2c"))
    for i in range(4):
        _block(pivot, "PrinterVentSlot", Vector3(-0.31+float(i)*0.20, 0.36, 1.047),
            Vector3(0.09, 0.05, 0.012), Color("#577181"))
    # Modelled inside the printer, not in front of it.
    printed_part = Node3D.new()
    printed_part.name = "PrintedPart"
    printed_part.position = Vector3(-0.32, 0.96, -0.10)
    pivot.add_child(printed_part)
    var shell := SphereMesh.new()
    shell.radius = 0.5
    shell.height = 1.0
    shell.radial_segments = 12
    shell.rings = 6
    var workpiece := MeshInstance3D.new()
    workpiece.name = "HeadArmorPrototype"
    workpiece.mesh = shell
    workpiece.position = Vector3(0, 0.19, 0)
    workpiece.scale = Vector3(0.84, 0.42, 0.64)
    workpiece.material_override = _paint(Color("#90bbc9"))
    printed_part.add_child(workpiece)
    _block(printed_part, "PrintedFaceShield", Vector3(0, 0.16, 0.31),
        Vector3(0.55, 0.14, 0.045), Color("#4bd1e4"), true)
    _block(printed_part, "PrintedChinShell", Vector3(0, -0.10, 0.21),
        Vector3(0.70, 0.17, 0.33), Color("#7ca3b7"))
    # Jointed robotic manipulator occupies upper-right of the chamber.
    var arm := Node3D.new()
    arm.name = "PrinterManipulator"
    arm.position = Vector3(0.77, 1.82, -0.26)
    pivot.add_child(arm)
    _block(arm, "ArmUpper", Vector3(-0.16, 0.08, 0),
        Vector3(0.64, 0.15, 0.19), Color("#a6c0ca"))
    _block(arm, "ElbowJoint", Vector3(-0.51, 0.08, 0),
        Vector3(0.23, 0.23, 0.23), Color("#587b8a"))
    _block(arm, "ArmForearm", Vector3(-0.64, -0.21, 0.02),
        Vector3(0.17, 0.55, 0.17), Color("#98b2bd"))
    _block(arm, "ManipulatorHead", Vector3(-0.65, -0.50, 0.06),
        Vector3(0.24, 0.18, 0.27), Color("#627d8c"))
    _block(arm, "BluePrintTip", Vector3(-0.65, -0.62, 0.06),
        Vector3(0.10, 0.07, 0.12), cyan, true)
    printer_nozzle = Node3D.new()
    printer_nozzle.name = "PrinterNozzle"
    printer_nozzle.position = Vector3(0.13, 2.09, 0.24)
    pivot.add_child(printer_nozzle)
    _block(printer_nozzle, "NozzleCarriage", Vector3.ZERO,
        Vector3(0.35, 0.26, 0.33), Color("#91adbb"))
    _block(printer_nozzle, "ActivePrintEmitter", Vector3(0, -0.15, 0),
        Vector3(0.08, 0.15, 0.08), cyan, true)
    # The reference's stacked side service cases.
    for k in range(2):
        _block(printer_group, "PrinterServiceCase",
            Vector3(-4.83+float(k)*0.50, 0.48, 1.25),
            Vector3(0.46, 0.89, 0.94), Color("#576d7b"))
        _block(printer_group, "ServiceCaseLatch",
            Vector3(-4.83+float(k)*0.50, 0.68, 1.74),
            Vector3(0.19, 0.07, 0.04), Color("#b3c2c8"))

func _build_terminal() -> void:
    var console := Node3D.new()
    console.name = "PrinterInspectionStation"
    console.position = Vector3(3.25, 0, -0.80)
    console.rotation.y = -0.18
    printer_group.add_child(console)
    _block(console, "TerminalPlinth", Vector3(0, 0.65, 0),
        Vector3(0.50, 1.28, 0.51), Color("#344d5b"))
    _block(console, "CantileverDesk", Vector3(0, 1.28, 0.21),
        Vector3(0.91, 0.13, 0.64), Color("#516d7d"))
    var screen := Node3D.new()
    screen.name = "TerminalScreen"
    screen.position = Vector3(0, 1.91, -0.15)
    screen.rotation.x = -0.13
    console.add_child(screen)
    _block(screen, "ScreenOuterCase", Vector3.ZERO,
        Vector3(1.05, 0.74, 0.08), Color("#6f8997"))
    _block(screen, "TechnicalDisplay", Vector3(0, 0, 0.055),
        Vector3(0.92, 0.61, 0.023), Color("#175268"))
    for j in range(3):
        _block(screen, "StatusGraph", Vector3(0.19, 0.21-float(j)*0.16, 0.074),
            Vector3(0.39, 0.024, 0.008), Color("#6ec3d6"), true)
    _block(screen, "HeadDraft", Vector3(-0.25, 0.03, 0.076),
        Vector3(0.31, 0.22, 0.01), Color("#79d8e7"), true)

func _build_crate() -> void:
    # Exact same factory and mesh as the roaming robot in the base.
    crate = CrateModel.create_model()
    add_child(crate)
    crate_head = crate.get_node("HeadPivot") as Node3D
    crate_arm = crate.get_node("RightArmPivot") as Node3D
    crate_left_arm = crate.get_node("LeftArmPivot") as Node3D

func _cylinder(parent: Node3D, label: String, point: Vector3,
        radius: float, height: float, tint: Color, glow: bool = false) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.material_override = _paint(tint, glow)
    node.position = point
    parent.add_child(node)
    return node

# B: three processing vats left-to-right in amber, cyan, and violet.
# They remain visible as complete tall machines in the reference frame.
func _build_converter() -> void:
    converter_group = Node3D.new()
    converter_group.name = "MaterialConversionScene"
    add_child(converter_group)
    var colors: Array[Color] = [
        Color("#ffa83c"), Color("#4ebcfc"), Color("#b36bea")]
    var locations: Array[Vector3] = [
        Vector3(-2.65, 0, -0.35),
        Vector3(-0.15, 0, -1.05),
        Vector3(1.70, 0, -1.60)]
    for i in range(3):
        var station := Node3D.new()
        station.name = "RefineryVessel_%d" % i
        station.position = locations[i]
        converter_group.add_child(station)
        # Transparent sleeve with metal end rings and active material inside.
        _cylinder(station, "VesselBase", Vector3(0, 0.47, 0),
            0.75, 0.50, Color("#566d78"))
        _cylinder(station, "LowerSealingRim", Vector3(0, 0.76, 0),
            0.77, 0.13, Color("#81959e"))
        _cylinder(station, "UpperSealingRim", Vector3(0, 2.36, 0),
            0.79, 0.14, Color("#91a6ae"))
        _cylinder(station, "TankRoof", Vector3(0, 2.59, 0),
            0.72, 0.36, Color("#526e7e"))
        _cylinder(station, "TallPipeCoupling", Vector3(0, 2.92, 0),
            0.30, 0.34, Color("#9ab2bc"))
        _cylinder(station, "FeedPipeCrown", Vector3(0, 3.26, 0),
            0.13, 0.46, Color("#586f7c"))
        for side in [-1.0, 1.0]:
            _block(station, "VerticalSupport",
                Vector3(side*0.62, 1.54, 0.0),
                Vector3(0.11, 1.52, 0.14), Color("#678291"))
        # Glass cylinder uses alpha blending, but does not hide the modelled
        # amber/blue/violet feedstock.
        var sleeve_mesh := CylinderMesh.new()
        sleeve_mesh.top_radius = 0.69
        sleeve_mesh.bottom_radius = 0.69
        sleeve_mesh.height = 1.48
        sleeve_mesh.radial_segments = 18
        var glass := StandardMaterial3D.new()
        glass.albedo_color = Color(colors[i].r, colors[i].g, colors[i].b, 0.12)
        glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        glass.metallic = 0.1
        glass.roughness = 0.3
        glass.cull_mode = BaseMaterial3D.CULL_DISABLED
        var tank_window := MeshInstance3D.new()
        tank_window.name = "RefineryTransparentChamber"
        tank_window.mesh = sleeve_mesh
        tank_window.material_override = glass
        tank_window.position = Vector3(0, 1.54, 0)
        station.add_child(tank_window)
        _cylinder(station, "TopProcessingNeon", Vector3(0, 2.21, 0),
            0.72, 0.045, colors[i], true)
        _cylinder(station, "LowerProcessingNeon", Vector3(0, 0.82, 0),
            0.71, 0.045, colors[i], true)
        var rotor := Node3D.new()
        rotor.name = "CrystalRotor_" + str(i)
        rotor.position = Vector3(0, 1.05, 0)
        station.add_child(rotor)
        converter_crystals.append(rotor)
        for j in range(10):
            var p := SphereMesh.new()
            p.radius = 0.19 if j % 3 == 0 else 0.15
            p.height = p.radius * 2.0
            p.radial_segments = 7
            p.rings = 4
            var ore := MeshInstance3D.new()
            ore.name = "HeatedFeedstock"
            ore.mesh = p
            ore.material_override = _paint(colors[i], j % 4 == 0)
            ore.position = Vector3(
                float((j % 3)-1)*0.32,
                float(int(j / 3))*0.26,
                (float(j % 2)-0.5)*0.38)
            rotor.add_child(ore)
        _block(station, "TankServicePanel", Vector3(0, 0.46, 0.78),
            Vector3(0.59, 0.19, 0.10), Color("#294959"))
        _block(station, "TankServiceIndicator", Vector3(0, 0.47, 0.84),
            Vector3(0.37, 0.04, 0.018), colors[i], true)
    var trays := Node3D.new()
    trays.name = "RefineryFeedstockTrays"
    trays.position = Vector3(-0.50, 0, 1.66)
    converter_group.add_child(trays)
    # Four open trays need four palette entries; only three processing
    # vessels exist, so keep their original colors and add a neutral feedstock.
    var tray_colors: Array[Color] = [
        colors[0], colors[1], Color("#a6b5c3"), Color("#94a884")]
    for i in range(4):
        var x: float = -2.65 + float(i)*1.41
        _block(trays, "IndustrialMaterialBin",
            Vector3(x, 0.30, 0), Vector3(1.22, 0.41, 0.82),
            Color("#4a6473"))
        _block(trays, "BinInnerDarkSurface",
            Vector3(x, 0.52, -0.03), Vector3(1.08, 0.02, 0.68),
            Color("#253e4b"))
        for corner in [-1.0, 1.0]:
            _block(trays, "BinRim",
                Vector3(x+corner*0.59, 0.53, 0),
                Vector3(0.055, 0.09, 0.87), Color("#92a5ad"))
        var sample_positions: Array[Vector3] = []
        for row in range(2):
            for col in range(3):
                sample_positions.append(Vector3(
                    x-0.37+float(col)*0.36,
                    0.65+float((col+row)%2)*0.08,
                    -0.24+float(row)*0.40))
        _instances(trays, "MaterialSampleBatch_%d" % i,
            sample_positions, Vector3(0.27, 0.23, 0.27),
            tray_colors[i])
        _block(trays, "MaterialLabelPlate", Vector3(x, 0.25, 0.435),
            Vector3(0.44, 0.075, 0.018), Color("#b49a63"))
    # Separate control consoles on the left edge and between the first tanks.
    for idx in range(2):
        var controller := Node3D.new()
        controller.name = "RefineryControlTerminal_%d" % idx
        controller.position = (Vector3(-4.20, 0, 0.55) if idx == 0
            else Vector3(-1.52, 0, 0.72))
        controller.rotation.y = -0.19
        converter_group.add_child(controller)
        _block(controller, "PanelSupport", Vector3(0, 0.62, 0),
            Vector3(0.34, 1.20, 0.39), Color("#445c6c"))
        var display := Node3D.new()
        display.name = "PanelScreen"
        display.position = Vector3(0, 1.38, 0.08)
        display.rotation.x = -0.18
        controller.add_child(display)
        _block(display, "PanelMetalFrame", Vector3.ZERO,
            Vector3(0.85, 0.58, 0.12), Color("#a2b7c0"))
        _block(display, "PanelGlass", Vector3(0, 0, 0.078),
            Vector3(0.72, 0.44, 0.02), Color("#225970"))
        for k in range(3):
            _block(display, "LinePlot",
                Vector3(-0.19, 0.15-float(k)*0.11, 0.095),
                Vector3(0.28, 0.027, 0.01), Color("#70cfe0"), true)

# C: loaded racks face the central aisle, with two different banks and
# individually readable H01/H02/A01 and B01/B02/A02 storage IDs.
func _build_warehouse() -> void:
    warehouse_group = Node3D.new()
    warehouse_group.name = "WarehouseScene"
    add_child(warehouse_group)
    var color_main := Color("#617a88")
    for side in [-1, 1]:
        var bay := Node3D.new()
        bay.name = "RackBay_Left" if side < 0 else "RackBay_Right"
        bay.position = (Vector3(-3.55, 0, -1.80) if side < 0
            else Vector3(3.65, 0, -1.24))
        bay.rotation.y = 0.16 if side < 0 else -0.12
        warehouse_group.add_child(bay)
        _block(bay, "StorageBackplate", Vector3(0, 2.32, -0.46),
            Vector3(2.72, 4.62, 0.17), Color("#2b4454"))
        for edge in [-1.34, 1.34]:
            _block(bay, "TallRackPost", Vector3(edge, 2.38, 0),
                Vector3(0.14, 4.75, 0.21), Color("#91a1ac"))
        for shelf in range(4):
            _block(bay, "VerticalTierBeam",
                Vector3(0, 0.40+float(shelf)*1.03, 0.27),
                Vector3(2.70, 0.10, 0.72), Color("#718996"))
        var bin_positions: Array[Vector3] = []
        for row in range(3):
            for col in range(3):
                bin_positions.append(Vector3(-0.82+float(col)*0.82,
                    0.76+float(row)*1.03, -0.01))
        _instances(bay, "FullStockCartons", bin_positions,
            Vector3(0.67, 0.65, 0.56), Color("#71818c"))
        var stockstrips: Array[Vector3] = []
        for row in range(3):
            for col in range(3):
                stockstrips.append(Vector3(-0.82+float(col)*0.82,
                    0.96+float(row)*1.03, 0.285))
        _instances(bay, "CartonAmberHandles", stockstrips,
            Vector3(0.30, 0.055, 0.027), Color("#cba35d"))
        var inventory_plate := Node3D.new()
        inventory_plate.name = "WarehouseLeftStockLabels" if side < 0 \
            else "WarehouseRightStockLabels"
        inventory_plate.position = Vector3(-0.72, 0, 0.45)
        bay.add_child(inventory_plate)
        var ids: Array[String] = ["A01", "H02", "H01"]
        if side > 0:
            ids = ["A02", "B02", "B01"]
        for j in range(3):
            var label_y: float = 1.17 + float(j)*1.04
            _block(inventory_plate, "LargeStockCodePlate",
                Vector3(0, label_y, 0), Vector3(1.15, 0.64, 0.07),
                Color("#435b6b"))
            _sign(inventory_plate, ids[j],
                Vector3(0, label_y-0.08, 0.061), 94)
            _block(inventory_plate, "AmberShelfMarker",
                Vector3(0.43, label_y+0.37, 0.042),
                Vector3(0.18, 0.05, 0.028), Color("#d09a43"), true)
    for side in [-1.0, 1.0]:
        _block(warehouse_group, "PeripheralHeavyCrate",
            Vector3(side*5.55, 0.46, 1.84),
            Vector3(1.32, 0.88, 1.06), color_main)
        _block(warehouse_group, "CrateTopPlate",
            Vector3(side*5.55, 0.91, 1.84),
            Vector3(1.20, 0.08, 0.98), Color("#788f9b"))
    _block(warehouse_group, "AmberCargoAtRear", Vector3(3.10, 0.31, -3.60),
        Vector3(0.88, 0.55, 0.72), Color("#b58e4d"))

func _ready() -> void:
    var world := WorldEnvironment.new()
    world.name = "Environment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#101e2b")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b9cbd3")
    environment.ambient_light_energy = 0.72
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.name = "SofterIndustrialKeyLight"
    sun.rotation_degrees = Vector3(-43.0, 28.0, -8.0)
    sun.light_energy = 1.23
    sun.shadow_enabled = false
    add_child(sun)
    # Build each entirely independent room. Large photographic obstructions
    # from the previous close-up experiment are intentionally NOT instantiated.
    _build_printer()
    _build_print_room()
    _build_terminal()
    _build_converter()
    _build_conversion_room()
    _build_warehouse()
    _build_warehouse_room()
    _build_crate()
    warehouse_scanner = Node3D.new()
    warehouse_scanner.name = "TravelingInventoryScanner"
    warehouse_scanner.position = Vector3(1.53, 1.10, -0.86)
    warehouse_group.add_child(warehouse_scanner)
    _block(warehouse_scanner, "ScanHead", Vector3.ZERO,
        Vector3(0.16, 0.10, 0.24), Color("#50b6cd"), true)
    # LAB manufacturing / recycling / storage use independent 3D scenes.
    # Retain emitted lights and no separate surface pass for solid shading.
    SharedMaterialShading.apply_to_subtree(self)
    var ink := SeraViewEdges.new()
    ink.name = "ViewEdges"
    add_child(ink)
    hero_camera = Camera3D.new()
    hero_camera.name = "HeroCamera"
    add_child(hero_camera)
    hero_camera.current = true
    hero_camera.near = 0.10
    hero_camera.far = 75.0
    set_section(current_section)

func set_section(section: String) -> void:
    current_section = section if section in ["LABO", "SMELTER", "RECYCLER", "STORAGE"] else "LABO"
    printer_group.visible = current_section == "LABO"
    converter_group.visible = current_section in ["SMELTER", "RECYCLER"]
    warehouse_group.visible = current_section == "STORAGE"
    clock = 0.0
    state_time = 0.0
    crate_head.rotation = Vector3.ZERO
    crate_arm.rotation = Vector3.ZERO
    crate_left_arm.rotation = Vector3.ZERO
    crate.scale = Vector3.ONE
    match current_section:
        "LABO":
            # Scene A: low camera from front RIGHT (24 degree yaw) makes the
            # oversized left printer gantry visibly three-dimensional,
            # while preserving CRATE and terminal on the right.
            crate.position = Vector3(1.96, 0.0, 0.55)
            crate.rotation.y = 2.26
            work_state = "print_to_terminal"
            hero_camera.position = Vector3(2.65, 1.45, 4.40)
            hero_camera.fov = 50.0
            hero_camera.look_at(Vector3(0.15, 1.90, -0.70), Vector3.UP)
        "SMELTER", "RECYCLER":
            # Scene B: front LEFT 21 degree viewpoint and raised camera.
            # Orange vessel appears nearer than cyan and violet; four
            # front bins remain visible and CRATE stays to the right.
            crate.position = Vector3(3.00, 0.0, 0.45)
            crate.rotation.y = 2.34
            work_state = "refinery_audit"
            hero_camera.position = Vector3(-3.40, 2.90, 5.55)
            hero_camera.fov = 55.0
            hero_camera.look_at(Vector3(-0.10, 1.65, -1.00), Vector3.UP)
        "STORAGE":
            # Scene C: from front RIGHT, moderately elevated (23 degree yaw).
            # The near right shelf shows its depth while both label banks
            # and the central monitoring terminal remain in frame.
            crate.position = Vector3(0.05, 0.0, 0.85)
            crate.rotation.y = -2.87
            work_state = "storage_scan"
            hero_camera.position = Vector3(3.35, 2.45, 5.35)
            hero_camera.fov = 55.0
            hero_camera.look_at(Vector3(0.00, 1.75, -1.00), Vector3.UP)

func _move_to(goal: Vector3, delta: float) -> bool:
    var planar := Vector3(goal.x, crate.position.y, goal.z)
    var diff: Vector3 = planar - crate.position
    if diff.length() <= 0.07:
        crate.position = planar
        return true
    crate.position = crate.position.move_toward(planar, minf(0.95*delta, 0.23))
    # CRATE's unified model faces -Z.
    var desired_yaw: float = atan2(-diff.x, -diff.z)
    crate.rotation.y = lerp_angle(crate.rotation.y, desired_yaw, minf(1.0, 2.8*delta))
    crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.0, minf(1.0, 3.5*delta))
    crate_arm.rotation.x = lerpf(crate_arm.rotation.x, 0.0, minf(1.0, 3.0*delta))
    crate_left_arm.rotation.x = lerpf(crate_left_arm.rotation.x, 0.0, minf(1.0, 3.0*delta))
    return false

func _enter(state: String) -> void:
    work_state = state
    state_time = 0.0

func _process(delta: float) -> void:
    clock += delta
    state_time += delta
    match current_section:
        "LABO":
            _animate_manufacturing(delta)
        "SMELTER", "RECYCLER":
            _animate_refinery(delta)
        "STORAGE":
            _animate_inventory(delta)

func _animate_manufacturing(delta: float) -> void:
    # Printer nozzle moves in the local, scaled printer frame.
    printer_nozzle.position.x = 0.13 + 0.24*sin(clock*1.8)
    printer_nozzle.position.z = 0.24 + 0.13*cos(clock*1.2)
    printed_part.scale.y = 0.92 + 0.06*sin(clock*0.4)
    match work_state:
        "print_to_terminal":
            if _move_to(Vector3(2.60, 0, 0.24), delta):
                _enter("print_inspect_terminal")
        "print_inspect_terminal":
            crate.rotation.y = lerp_angle(crate.rotation.y, 2.10, minf(delta*2.0, 1.0))
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.17, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = -0.30 + 0.06*sin(clock*2.2)
            if state_time > 3.1:
                _enter("print_to_machine")
        "print_to_machine":
            if _move_to(Vector3(1.32, 0, 0.42), delta):
                _enter("print_inspect_shell")
        "print_inspect_shell":
            crate.rotation.y = lerp_angle(crate.rotation.y, 2.65, minf(delta*2.5, 1.0))
            crate_head.rotation.x = lerpf(crate_head.rotation.x, -0.13, minf(delta*3.0, 1.0))
            crate_left_arm.rotation.x = 0.12*sin(clock*1.8)
            if state_time > 2.6:
                _enter("print_to_terminal")

func _animate_refinery(delta: float) -> void:
    # Low amplitude rotation/pulsing inside chambers; caps and columns are fixed.
    for i in range(converter_crystals.size()):
        var rotor: Node3D = converter_crystals[i]
        rotor.rotation.y = clock*(0.16 + float(i)*0.10)
        rotor.position.y = 1.05 + 0.028*sin(clock*1.65 + float(i))
    match work_state:
        "refinery_audit":
            crate.rotation.y = lerp_angle(crate.rotation.y, 2.40, minf(delta*2.0, 1.0))
            crate_head.rotation.y = 0.13*sin(clock*0.8)
            crate_arm.rotation.x = -0.21 + 0.12*sin(clock*1.8)
            if state_time > 3.5:
                _enter("refinery_to_samples")
        "refinery_to_samples":
            if _move_to(Vector3(2.47, 0, 0.62), delta):
                _enter("refinery_sort")
        "refinery_sort":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.26, minf(delta*3.0, 1.0))
            crate_left_arm.rotation.x = -0.24 + 0.18*sin(clock*2.4)
            if state_time > 2.9:
                _enter("refinery_return")
        "refinery_return":
            if _move_to(Vector3(3.0, 0, 0.45), delta):
                _enter("refinery_audit")

func _animate_inventory(delta: float) -> void:
    # Warehouse robot remains at aisle center rather than driving into a rack.
    warehouse_scanner.position.x = 1.53 + 0.12*sin(clock*1.5)
    warehouse_scanner.rotation.y = 0.08*sin(clock*0.8)
    match work_state:
        "storage_scan":
            crate_head.rotation.y = 0.18*sin(clock*0.8)
            crate_arm.rotation.x = -0.12
            if state_time > 2.6:
                _enter("storage_go_left")
        "storage_go_left":
            if _move_to(Vector3(-0.68, 0, 0.72), delta):
                _enter("storage_get_bin")
        "storage_get_bin":
            crate_left_arm.rotation.x = -0.24 + 0.14*sin(clock*2.1)
            crate_head.rotation.x = lerpf(crate_head.rotation.x, -0.15, minf(delta*3.0, 1.0))
            if state_time > 2.2:
                _enter("storage_go_terminal")
        "storage_go_terminal":
            if _move_to(Vector3(0.47, 0, 0.58), delta):
                _enter("storage_log_stock")
        "storage_log_stock":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.18, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = -0.16 + 0.05*sin(clock*2.5)
            if state_time > 2.5:
                _enter("storage_scan")
