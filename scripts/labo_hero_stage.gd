extends Node3D
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const CrateModel = preload("res://scripts/sera_crate_model.gd")
## Shared LABO / converter / warehouse hero. Real low-poly 3D, no imported image.
## All parts are generated once; no physics, navigation or per-frame allocations.
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
    label.font = LaboSkin.title_font()
    label.font_size = size
    label.pixel_size = 0.0035
    label.modulate = Color("#ddf8ff")
    label.position = at
    parent.add_child(label)
    return label

func _build_print_room() -> void:
    _block(printer_group, "Floor", Vector3(0, -0.15, -0.6),
        Vector3(8.2, 0.26, 6.0), Color("#273949"))
    _block(printer_group, "BackWall", Vector3(0, 2.18, -3.45),
        Vector3(8.2, 4.6, 0.20), Color("#1b2e3f"))
    for x in [-3.7, 0.0, 3.7]:
        _block(printer_group, "StructuralColumn", Vector3(x, 2.1, -3.1),
            Vector3(0.20, 4.2, 0.24), Color("#425c6c"))
    for y in [1.05, 2.8, 4.0]:
        _block(printer_group, "WallBeam", Vector3(0, y, -3.18),
            Vector3(8.0, 0.12, 0.18), Color("#3c5a6c"))
    for x in [-3.0, -1.3, 0.4, 2.1, 3.4]:
        _block(printer_group, "FloorLine", Vector3(x, -0.01, -0.6),
            Vector3(0.018, 0.012, 5.7), Color("#3b798d"), true)
    for x in [-2.95, 0.0, 2.95]:
        _block(printer_group, "OverheadLight", Vector3(x, 3.95, -2.35),
            Vector3(0.95, 0.06, 0.16), Color("#6dc3d6"), true)
    _block(printer_group, "RearEquipmentRack", Vector3(0.35, 1.05, -3.0),
        Vector3(1.22, 1.9, 0.55), Color("#354b5a"))
    for y in [0.65, 1.45, 2.05]:
        _block(printer_group, "EquipmentRackLight", Vector3(0.35, y, -2.70),
            Vector3(0.92, 0.055, 0.045), Color("#4a9eb1"), true)
    _block(printer_group, "AirVent", Vector3(-1.2, 2.55, -3.2),
        Vector3(0.95, 0.42, 0.12), Color("#344755"))
    # Entirely printer-owned industrial hall: no common geometry on other tabs.
    _block(printer_group, "PrinterLeftWall", Vector3(-4.25, 2.15, -0.75),
        Vector3(0.18, 4.50, 6.35), Color("#263d4e"))
    _block(printer_group, "PrinterGantryOverhang", Vector3(-2.20, 3.75, -0.65),
        Vector3(3.95, 0.21, 2.75), Color("#394f61"))
    _block(printer_group, "PrinterFloorSafetyLine", Vector3(-2.24, 0.017, 2.01),
        Vector3(3.5, 0.018, 0.10), Color("#d9a94e"))
    # Asymmetric suspended service walkway: architectural diagonals converge
    # on the foreground printer rather than mirroring the opposite wall.
    var upper_walkway := Node3D.new()
    upper_walkway.name = "PrinterHighServiceBridge"
    upper_walkway.position = Vector3(1.14, 3.52, -2.60)
    upper_walkway.rotation.y = -0.36
    printer_group.add_child(upper_walkway)
    _block(upper_walkway, "BridgeDeck", Vector3.ZERO,
        Vector3(3.65, 0.11, 0.84), Color("#425a6a"))
    _block(upper_walkway, "OpenSideGuard", Vector3(0, 0.48, 0.38),
        Vector3(3.66, 0.06, 0.07), Color("#7898a7"))
    for k in range(5):
        _block(upper_walkway, "BridgeBaluster",
            Vector3(-1.53 + float(k)*0.77, 0.23, 0.38),
            Vector3(0.045, 0.46, 0.05), Color("#708594"))
    # Distinct front/right close-up structure introduces foreground parallax.
    _block(printer_group, "RightMaintenancePedestal", Vector3(3.35, 0.45, 1.35),
        Vector3(0.92, 0.90, 1.03), Color("#415767"))
    _block(printer_group, "RightMaintenanceLight", Vector3(3.35, 0.87, 1.90),
        Vector3(0.55, 0.07, 0.05), Color("#c1a04d"), true)
    _block(printer_group, "RightWallPipe", Vector3(3.63, 2.83, -2.84),
        Vector3(0.11, 1.95, 0.18), Color("#8a9daa"))
    # Framing beams belong only to the printing hall.
    for z in [-2.65, -1.25, 0.15]:
        _block(printer_group, "CeilingRail", Vector3(0, 4.05, z),
            Vector3(8.0, 0.15, 0.16), Color("#304b5c"))
    for x in [-2.6, 0.0, 2.6]:
        _block(printer_group, "CoolWhiteCeilingLight", Vector3(x, 4.02, -1.20),
            Vector3(0.63, 0.035, 0.18), Color("#d0f6ff"), true)
    for i in range(4):
        _block(printer_group, "CautionStripe", Vector3(-3.45 + float(i)*0.19, 0.015, 2.1),
            Vector3(0.10, 0.013, 0.48), Color("#cd9e42"))
    _block(printer_group, "BacklitCompanyPanel", Vector3(2.65, 2.60, -3.30),
        Vector3(1.55, 0.78, 0.075), Color("#172d3c"))
    _sign(printer_group, "SERA", Vector3(2.65, 2.54, -3.22), 62)

# Material conversion room: separate bulkhead, tall processing pipework and
# side catwalk; no printer hall or warehouse architecture is reused.
func _build_conversion_room() -> void:
    var room: Node3D = converter_group
    _block(room, "RefineryFloor", Vector3(0, -0.17, -0.7),
        Vector3(10.2, 0.30, 7.8), Color("#2b414f"))
    _block(room, "RefineryBackBulkhead", Vector3(0, 2.35, -4.50),
        Vector3(10.1, 4.9, 0.19), Color("#172b3a"))
    _block(room, "RefineryLeftWall", Vector3(-5.05, 2.25, -1.0),
        Vector3(0.2, 4.6, 7.5), Color("#364957"))
    _block(room, "RefineryCatwalk", Vector3(0, 3.28, -3.58),
        Vector3(9.8, 0.17, 0.80), Color("#546d7c"))
    for x in [-4.6, -2.75, -0.9, 0.95, 2.80, 4.55]:
        _block(room, "RefineryUpright", Vector3(x, 2.3, -4.38),
            Vector3(0.14, 4.6, 0.18), Color("#657d8b"))
        _block(room, "RefineryOverheadPipe", Vector3(x, 3.65, -3.28),
            Vector3(0.12, 0.65, 0.12), Color("#ad813c"))
    for z in [-3.8, -2.2, 0.4, 2.35]:
        _block(room, "RefineryCeilingTruss", Vector3(0, 4.50, z),
            Vector3(9.9, 0.14, 0.16), Color("#455d6c"))
    for x in [-3.2, 0.0, 2.95]:
        _block(room, "RefineryColdCeilingLamp", Vector3(x, 4.40, -1.7),
            Vector3(0.9, 0.05, 0.18), Color("#d6eff3"), true)
    _block(room, "ConverterRightConsole", Vector3(3.05, 1.28, -1.3),
        Vector3(1.40, 0.95, 0.14), Color("#607b89"))
    _block(room, "ConverterRightDisplay", Vector3(3.05, 1.29, -1.22),
        Vector3(1.22, 0.80, 0.015), Color("#175268"))
    for i in range(3):
        _block(room, "ConverterGauge", Vector3(2.71+float(i)*0.34, 1.26, -1.195),
            Vector3(0.16, 0.22+float(i)*0.12, 0.012),
            Color("#5fc4da") if i != 0 else Color("#ebad50"), true)
    for step in range(4):
        _block(room, "RefineryRightStair",
            Vector3(4.18, 0.16+float(step)*0.20, -1.75-float(step)*0.38),
            Vector3(1.03, 0.10, 0.48), Color("#698390"))
    _block(room, "SampleSortingBench", Vector3(1.8, 0.46, 0.45),
        Vector3(1.55, 0.27, 0.80), Color("#526b79"))
    _sign(room, "REFINERY", Vector3(2.8, 3.75, -4.14), 34)

# Storage room: receding central aisle, twin rack banks and high ceiling.
# It has no refinery pipes, chamber effects or printer gantry.
func _build_warehouse_room() -> void:
    var room: Node3D = warehouse_group
    _block(room, "StorageAisleFloor", Vector3(0, -0.18, -0.7),
        Vector3(10.9, 0.31, 8.45), Color("#304655"))
    _block(room, "StorageRearWall", Vector3(0, 2.30, -4.78),
        Vector3(10.9, 4.82, 0.24), Color("#1c3545"))
    _block(room, "StorageShutter", Vector3(0.10, 1.65, -4.61),
        Vector3(1.85, 3.08, 0.075), Color("#445f70"))
    for row in range(7):
        _block(room, "ShutterRib", Vector3(0.1, 0.30+float(row)*0.41, -4.55),
            Vector3(1.8, 0.05, 0.025), Color("#859aa6"))
    for side in [-1, 1]:
        _block(room, "StorageAisleSide", Vector3(float(side)*5.30, 2.25, -0.65),
            Vector3(0.20, 4.7, 8.45), Color("#2e4352"))
        _block(room, "StorageAisleGuide", Vector3(float(side)*1.25, 0.013, -0.45),
            Vector3(0.05, 0.015, 6.5), Color("#6a8c9b"))
    for z in [-4.1, -2.0, 0.2, 2.30]:
        _block(room, "StorageRoofRib", Vector3(0, 4.55, z),
            Vector3(10.5, 0.18, 0.18), Color("#496373"))
    for x in [-3.55, 0.0, 3.55]:
        _block(room, "AisleCeilingLight", Vector3(x, 4.42, -1.45),
            Vector3(1.15, 0.045, 0.21), Color("#d9f4fb"), true)
    for z in [-3.20, -2.02, -0.84]:
        _block(room, "LeftPalletStack", Vector3(-4.50, 0.45, z),
            Vector3(0.83, 0.80, 0.92), Color("#596f7c"))
    _block(room, "StockControlMonitor", Vector3(0.85, 2.20, -4.47),
        Vector3(1.46, 1.1, 0.095), Color("#536f7e"))
    _block(room, "StockControlDisplay", Vector3(0.85, 2.20, -4.41),
        Vector3(1.31, 0.94, 0.016), Color("#194a5d"))
    for i in range(4):
        _block(room, "InventoryStatusBar", Vector3(0.55, 2.51-float(i)*0.19, -4.395),
            Vector3(0.60, 0.04, 0.015), Color("#5ebacb"), true)
    _block(room, "SorterScannerRail", Vector3(0.28, 1.10, -0.40),
        Vector3(1.30, 0.075, 0.07), Color("#748f9a"))
    _sign(room, "H02", Vector3(-2.65, 2.60, -1.89), 28)
    _sign(room, "B02", Vector3(2.65, 2.60, -1.89), 28)

func _build_printer() -> void:
    printer_group = Node3D.new()
    printer_group.name = "PrinterScene"
    add_child(printer_group)
    var steel := Color("#657887")
    var dark := Color("#314757")
    var light := Color("#5abce4")
    var pivot := Node3D.new()
    pivot.name = "Printer"
    pivot.position = Vector3(-2.30, 0, 0.28)
    pivot.rotation.y = 0.37 # Three-quarter gantry, not a square-on elevation.
    printer_group.add_child(pivot)
    _block(pivot, "Platform", Vector3(0, 0.29, 0),
        Vector3(2.10, 0.40, 1.60), dark)
    _block(pivot, "BuildPlate", Vector3(0, 0.51, 0),
        Vector3(1.40, 0.08, 0.95), Color("#48667a"))
    for x in [-1.04, 1.04]:
        for z in [-0.73, 0.73]:
            _block(pivot, "GantryPillar", Vector3(x, 1.37, z),
                Vector3(0.12, 2.20, 0.12), steel)
    for z in [-0.73, 0.73]:
        _block(pivot, "TopRail", Vector3(0, 2.43, z),
            Vector3(2.20, 0.13, 0.17), steel)
    for x in [-1.04, 1.04]:
        _block(pivot, "SideRail", Vector3(x, 2.43, 0),
            Vector3(0.14, 0.14, 1.60), steel)
    _block(pivot, "PrinterHeader", Vector3(0, 2.33, 0.79),
        Vector3(1.7, 0.25, 0.15), Color("#405d70"))
    _block(pivot, "PrinterStatus", Vector3(0, 2.33, 0.89),
        Vector3(0.88, 0.05, 0.035), light, true)
    for x in [-0.82, 0.82]:
        _block(pivot, "Scanner", Vector3(x, 0.60, 0.76),
            Vector3(0.08, 0.065, 0.05), light, true)
    printer_nozzle = Node3D.new()
    printer_nozzle.name = "PrinterNozzle"
    printer_nozzle.position = Vector3(-2.30, 1.73, 0.28)
    printer_nozzle.rotation.y = pivot.rotation.y
    printer_group.add_child(printer_nozzle)
    _block(printer_nozzle, "ToolHead", Vector3(0, 0, 0),
        Vector3(0.43, 0.38, 0.42), Color("#92a8b7"))
    _block(printer_nozzle, "Extruder", Vector3(0, -0.29, 0),
        Vector3(0.10, 0.20, 0.10), light, true)
    printed_part = Node3D.new()
    printed_part.name = "PrintedPart"
    printed_part.position = Vector3(-2.30, 0.70, 0.28)
    printed_part.rotation.y = pivot.rotation.y
    printer_group.add_child(printed_part)
    _block(printed_part, "ArmorShell", Vector3.ZERO,
        Vector3(0.95, 0.38, 0.57), Color("#94aec1"))
    _block(printed_part, "ArmorCutout", Vector3(0.0, 0.23, 0),
        Vector3(0.43, 0.13, 0.35), Color("#3b718d"))
    _block(printed_part, "PrintEdge", Vector3(0, -0.22, 0.31),
        Vector3(0.95, 0.065, 0.035), light, true)
    # An imposing enclosed gantry and a solid manufactured helmet shell.
    _block(pivot, "GantrySideArmorL", Vector3(-1.08, 1.43, 0),
        Vector3(0.16, 2.14, 1.65), Color("#526b7c"))
    _block(pivot, "GantrySideArmorR", Vector3(1.08, 1.43, 0),
        Vector3(0.16, 2.14, 1.65), Color("#526b7c"))
    _block(pivot, "CeilingCasing", Vector3(0, 2.55, 0),
        Vector3(2.38, 0.23, 1.74), Color("#405868"))
    for x in [-0.54, -0.36, -0.18]:
        _block(pivot, "StatusPip", Vector3(x, 2.39, 0.91),
            Vector3(0.10, 0.05, 0.04), Color("#e3af42"), true)
    _block(pivot, "BedGlow", Vector3(0, 0.52, 0.50),
        Vector3(1.20, 0.035, 0.05), Color("#2395af"), true)
    _sign(pivot, "3D PRINTER", Vector3(0, 2.32, 0.99), 37)
    for i in range(4):
        _block(pivot, "HazardAmber", Vector3(-0.70 + float(i)*0.17, 0.16, 0.82),
            Vector3(0.105, 0.06, 0.025), Color("#dfac45"), true)

func _build_terminal() -> void:
    # The inspection console is turned toward the oblique camera and set
    # deeper than the printer rather than forming a flat parallel row.
    var console := Node3D.new()
    console.name = "PrinterInspectionStation"
    console.position = Vector3(1.90, 0.0, -1.43)
    console.rotation.y = 0.43
    printer_group.add_child(console)
    _block(console, "TerminalColumn", Vector3(0, 0.62, 0),
        Vector3(0.38, 1.12, 0.36), Color("#486476"))
    _block(console, "TerminalConsole", Vector3(0, 1.06, 0.16),
        Vector3(1.27, 0.18, 0.87), Color("#486476"))
    var screen := Node3D.new()
    screen.name = "TerminalScreen"
    screen.position = Vector3(0, 1.62, -0.27)
    screen.rotation.x = -0.22
    console.add_child(screen)
    _block(screen, "DisplayBack", Vector3.ZERO,
        Vector3(1.38, 0.91, 0.08), Color("#425e6c"))
    _block(screen, "DisplayGlass", Vector3(0, 0, 0.055),
        Vector3(1.22, 0.76, 0.022), Color("#183a4f"))
    for row in range(4):
        _block(screen, "ReadoutLine",
            Vector3(-0.22, 0.26 - float(row)*0.16, 0.07),
            Vector3(0.59 - float(row)*0.04, 0.025, 0.008),
            Color("#45b1d2"), true)
    _block(screen, "ReadoutModel", Vector3(0.39, 0.01, 0.07),
        Vector3(0.26, 0.36, 0.008), Color("#6cd9f0"), true)
    _block(screen, "ScreenCorner", Vector3(0.49, -0.27, 0.073),
        Vector3(0.11, 0.035, 0.012), Color("#68d5e5"), true)

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

func _build_converter() -> void:
    converter_group = Node3D.new()
    converter_group.name = "MaterialConversionScene"
    add_child(converter_group)
    var glows: Array[Color] = [
        Color("#edac49"), Color("#56b8e0"), Color("#aa80d7")]
    # Three LARGE tanks step diagonally away from the left foreground.
    # Tank internals remain consistent; the placement is NOT a straight row.
    var stations: Array[Vector2] = [
        Vector2(-2.75, 0.10),
        Vector2(-0.91, -1.22),
        Vector2(0.90, -2.50)]
    _block(converter_group, "RefineryBackingMachinery",
        Vector3(-0.70, 1.35, -3.49),
        Vector3(6.15, 2.65, 0.29), Color("#294354"))
    for i in range(3):
        var x: float = stations[i].x
        var z: float = stations[i].y
        var station := Node3D.new()
        station.name = "RefineryVessel_%d" % i
        station.position = Vector3(x, 0, z)
        # Face toward the high left-side service camera.
        station.rotation.y = -0.14
        converter_group.add_child(station)
        _cylinder(station, "ChamberBase", Vector3(0, 0.45, 0),
            0.62, 0.40, Color("#354a59"))
        _cylinder(station, "ChamberBody", Vector3(0, 1.35, 0),
            0.53, 1.52, Color("#344c5e"))
        _block(station, "ChamberWindow", Vector3(0, 1.33, 0.54),
            Vector3(0.75, 1.03, 0.075), Color("#132c3c"))
        _cylinder(station, "ChamberRoof", Vector3(0, 2.22, 0),
            0.65, 0.20, Color("#6e8795"))
        _cylinder(station, "RingTop", Vector3(0, 2.03, 0),
            0.56, 0.07, glows[i], true)
        _cylinder(station, "RingLower", Vector3(0, 0.70, 0),
            0.56, 0.07, glows[i], true)
        var rotor := Node3D.new()
        rotor.name = "CrystalRotor_" + str(i)
        rotor.position = Vector3(x, 1.25, z + 0.68)
        converter_group.add_child(rotor)
        converter_crystals.append(rotor)
        for j in range(5):
            var gem := SphereMesh.new()
            gem.radius = 0.19 if j % 2 == 0 else 0.14
            gem.height = gem.radius * 2.0
            gem.radial_segments = 6
            gem.rings = 3
            var crystal := MeshInstance3D.new()
            crystal.name = "ConverterCrystal"
            crystal.mesh = gem
            crystal.material_override = _paint(glows[i], j == 0)
            crystal.position = Vector3(
                0.21*cos(float(j)*2.5),
                -0.23+float(j % 3)*0.20,
                0.11*sin(float(j)*2.5))
            rotor.add_child(crystal)
        _block(station, "FeedPipe", Vector3(-0.22, 2.72, -0.78),
            Vector3(0.17, 0.95, 0.14), Color("#7d929e"))
        _block(station, "StatusScreen", Vector3(0, 0.40, 0.90),
            Vector3(0.76, 0.25, 0.065), Color("#21495d"))
        _block(station, "Readout", Vector3(0, 0.42, 0.95),
            Vector3(0.50, 0.03, 0.015), glows[i], true)
        _sign(station, "REF %d" % (i+1),
            Vector3(0, 2.52, 0.72), 28)
    # Far-side raised operator platform adds a second architectural plane.
    var catwalk := Node3D.new()
    catwalk.name = "OverheadObliqueRefineryBridge"
    catwalk.position = Vector3(1.15, 3.24, -3.18)
    catwalk.rotation.y = -0.34
    converter_group.add_child(catwalk)
    _block(catwalk, "Walkway", Vector3.ZERO,
        Vector3(3.55, 0.15, 0.75), Color("#68808e"))
    _block(catwalk, "SafetyRail", Vector3(0, 0.46, 0.37),
        Vector3(3.5, 0.07, 0.05), Color("#aec1c8"))
    for k in range(5):
        _block(catwalk, "CatwalkBaluster",
            Vector3(-1.48+float(k)*0.74, 0.23, 0.37),
            Vector3(0.05, 0.44, 0.05), Color("#8ca8b5"))
    # Sample sorting occupies the open right foreground, NOT in front of tank 1.
    _block(converter_group, "SampleExchangeBench", Vector3(1.60, 0.29, 0.73),
        Vector3(2.65, 0.35, 0.72), Color("#445f6e"))
    for j in range(6):
        var box_x: float = 0.59 + float(j)*0.40
        _block(converter_group, "SortedMaterials",
            Vector3(box_x, 0.54, 0.75),
            Vector3(0.24, 0.20, 0.23), glows[int(j / 2)])

func _build_warehouse() -> void:
    warehouse_group = Node3D.new()
    warehouse_group.name = "WarehouseScene"
    add_child(warehouse_group)
    # Two rack banks have very different distances from camera. Their
    # individually turned faces create a receding, asymmetric warehouse aisle.
    for side in [-1, 1]:
        var bay := Node3D.new()
        bay.name = "RackBay_Left" if side < 0 else "RackBay_Right"
        bay.position = (Vector3(-2.66, 0.0, 0.12) if side < 0
            else Vector3(2.70, 0.0, -2.03))
        bay.rotation.y = -0.31 if side < 0 else 0.16
        warehouse_group.add_child(bay)
        _block(bay, "RackBack", Vector3(0, 1.67, -0.26),
            Vector3(2.18, 3.18, 0.16), Color("#253d4c"))
        for col in range(3):
            for row in range(4):
                var box_x: float = -0.68 + float(col)*0.67
                var box_y: float = 0.59 + float(row)*0.67
                _block(bay, "StorageBin", Vector3(box_x, box_y, -0.02),
                    Vector3(0.53, 0.45, 0.40), Color("#536c7b"))
                _block(bay, "BinID", Vector3(box_x, box_y+0.10, 0.20),
                    Vector3(0.36, 0.08, 0.02), Color("#a9ccd9"))
                _block(bay, "BinHandle", Vector3(box_x, box_y-0.12, 0.20),
                    Vector3(0.17, 0.04, 0.025), Color("#253c4e"))
        for row in range(5):
            _block(bay, "ShelfBar", Vector3(0, 0.26+float(row)*0.67, 0.09),
                Vector3(2.25, 0.09, 0.52), Color("#718b98"))
        for edge in [-1.12, 1.12]:
            _block(bay, "RackPost", Vector3(edge, 1.66, 0.07),
                Vector3(0.11, 3.40, 0.12), Color("#7793a0"))
        _sign(bay, "H01" if side < 0 else "B01",
            Vector3(0, 3.20, 0.16), 42)
    # Off-center inventory processing table establishes a distinct third layer.
    _block(warehouse_group, "SortingTable", Vector3(0.28, 0.51, -0.41),
        Vector3(1.25, 0.28, 0.84), Color("#465e6d"))
    _block(warehouse_group, "ScanningPanel", Vector3(0.28, 0.70, -0.37),
        Vector3(1.05, 0.07, 0.67), Color("#23495d"))
    for col in range(4):
        _block(warehouse_group, "SortingReadout",
            Vector3(-0.10+float(col)*0.25, 0.75, -0.40),
            Vector3(0.13, 0.02, 0.44), Color("#56b6d3"), true)
    # Small foreground crane at an angle, not a parallel rack row.
    var overhead_rail := Node3D.new()
    overhead_rail.name = "WarehouseConveyorOverhead"
    overhead_rail.position = Vector3(0.80, 3.90, -1.05)
    overhead_rail.rotation.y = 0.36
    warehouse_group.add_child(overhead_rail)
    _block(overhead_rail, "ConveyorRail", Vector3.ZERO,
        Vector3(3.45, 0.22, 0.24), Color("#6c8491"))
    _block(overhead_rail, "ConveyorLuminousStrip", Vector3(0, -0.14, 0.10),
        Vector3(3.35, 0.045, 0.04), Color("#6cc2d8"), true)

# These heavy props sit between the camera and workshop and are intentionally
# larger than the visible crop. The room perimeter is NOT a composition target.
func _build_printer_closeup() -> void:
    var loader := Node3D.new()
    loader.name = "PrinterForegroundLoader"
    loader.position = Vector3(-0.38, 0, 2.23)
    loader.rotation.y = -0.31
    printer_group.add_child(loader)
    _block(loader, "HydraulicLoaderBase", Vector3(0, 0.21, 0.05),
        Vector3(2.05, 0.43, 1.42), Color("#3b5364"))
    _block(loader, "CradleDeck", Vector3(0, 0.48, -0.13),
        Vector3(1.79, 0.13, 1.05), Color("#849aa7"))
    for side in [-1.0, 1.0]:
        _block(loader, "LoaderArm", Vector3(side*0.86, 0.86, -0.22),
            Vector3(0.20, 0.83, 0.28), Color("#526c7b"))
        _block(loader, "HydraulicPiston", Vector3(side*0.84, 0.96, -0.42),
            Vector3(0.09, 0.66, 0.10), Color("#b4c5c9"))
        _block(loader, "ClampJaw", Vector3(side*0.74, 1.19, -0.28),
            Vector3(0.23, 0.18, 0.39), Color("#99aeba"))
    _block(loader, "LifterStatus", Vector3(0, 0.44, 0.81),
        Vector3(1.35, 0.07, 0.035), Color("#dfb455"), true)
    var harness := Node3D.new()
    harness.name = "PrinterHangingHarness"
    harness.position = Vector3(-2.30, 3.32, 1.45)
    harness.rotation.y = 0.21
    printer_group.add_child(harness)
    _block(harness, "GantryCrossCasing", Vector3(0, 0.13, 0),
        Vector3(4.55, 0.50, 0.76), Color("#334c5c"))
    _block(harness, "HangingDriveMotor", Vector3(-1.38, -0.53, 0.10),
        Vector3(0.79, 1.07, 0.64), Color("#536e7e"))
    _block(harness, "CableCarriage", Vector3(0.65, -0.39, 0.17),
        Vector3(0.59, 0.60, 0.62), Color("#778e9d"))
    var cable_points: Array[Vector3] = []
    for i in range(6):
        cable_points.append(Vector3(-1.54 + float(i)*0.58, -0.09, 0.45))
    _instances(harness, "OverheadCableRibs", cable_points,
        Vector3(0.055, 0.54, 0.065), Color("#9bb1bc"))
    _block(harness, "InspectionStrip", Vector3(0.3, -0.16, 0.41),
        Vector3(2.8, 0.048, 0.036), Color("#59c1d8"), true)
    var parts_rack := Node3D.new()
    parts_rack.name = "PrinterStackedComponents"
    parts_rack.position = Vector3(2.78, 0, -0.48)
    parts_rack.rotation.y = 0.43
    printer_group.add_child(parts_rack)
    for row in range(3):
        _block(parts_rack, "AssemblyShelf",
            Vector3(0, 0.40+float(row)*0.69, -0.06),
            Vector3(1.65, 0.11, 0.76), Color("#657f8b"))
    var cartridges: Array[Vector3] = []
    for row in range(3):
        for col in range(3):
            cartridges.append(Vector3(-0.48+float(col)*0.47,
                0.57+float(row)*0.69, -0.05))
    _instances(parts_rack, "ArmorToolCartridges", cartridges,
        Vector3(0.30, 0.22, 0.44), Color("#a0b2ba"))
    _block(printer_group, "NearSideStructuralBeam", Vector3(-3.97, 2.1, 1.88),
        Vector3(0.48, 4.27, 0.83), Color("#465f70"))

func _build_refinery_closeup() -> void:
    # A partly off-screen intake manifold frames the nearest tank from below.
    var manifold := Node3D.new()
    manifold.name = "RefineryForegroundManifold"
    manifold.position = Vector3(-2.80, 0.0, 0.90)
    manifold.rotation.y = -0.28
    converter_group.add_child(manifold)
    _block(manifold, "ManifoldHousing", Vector3(0, 0.42, 0),
        Vector3(1.32, 0.83, 1.36), Color("#516f7c"))
    _block(manifold, "ManifoldLargePipe", Vector3(0.12, 1.18, 0.20),
        Vector3(0.56, 1.85, 0.66), Color("#657f8c"))
    _block(manifold, "ManifoldPipeCollar", Vector3(0.12, 2.17, 0.20),
        Vector3(0.82, 0.23, 0.80), Color("#95a9b0"))
    for k in range(3):
        _block(manifold, "ManifoldValve",
            Vector3(-0.38+float(k)*0.39, 0.85, 0.73),
            Vector3(0.27, 0.38, 0.13), Color("#b68b53"))
    var upper := Node3D.new()
    upper.name = "RefineryHangingPipes"
    upper.position = Vector3(0.20, 3.50, 0.74)
    upper.rotation.y = 0.32
    converter_group.add_child(upper)
    for i in range(3):
        _block(upper, "SlopingPrimaryFeed",
            Vector3(-1.65+float(i)*1.04, 0.05, 0),
            Vector3(0.22, 0.25, 3.65), Color("#6c8b9a"))
        _block(upper, "DropNeck",
            Vector3(-1.65+float(i)*1.04, -0.53, -0.33),
            Vector3(0.28, 1.18, 0.25), Color("#8da3ad"))
        _block(upper, "PipeAmberGauge",
            Vector3(-1.65+float(i)*1.04, -0.70, 0.28),
            Vector3(0.12, 0.22, 0.03),
            Color("#e9b760") if i == 0 else Color("#60b9d8"), true)
    _block(upper, "BroadPressureHousing", Vector3(-0.5, 0.50, -0.24),
        Vector3(4.6, 0.65, 0.88), Color("#3d5767"))
    var casks := Node3D.new()
    casks.name = "RefinerySampleCasks"
    casks.position = Vector3(2.80, 0.0, 1.73)
    casks.rotation.y = 0.45
    converter_group.add_child(casks)
    _block(casks, "SampleDolly", Vector3(0, 0.23, 0),
        Vector3(2.10, 0.34, 1.13), Color("#476472"))
    var sample_points: Array[Vector3] = []
    for row in range(2):
        for col in range(4):
            sample_points.append(Vector3(-0.76+float(col)*0.48,
                0.61, -0.22+float(row)*0.45))
    _instances(casks, "LoadedSampleIngots", sample_points,
        Vector3(0.36, 0.43, 0.30), Color("#879ba9"))
    _block(converter_group, "RefineryNearSidePipeline",
        Vector3(3.48, 1.97, 0.97),
        Vector3(0.32, 3.99, 0.45), Color("#405d6f"))

func _build_warehouse_closeup() -> void:
    # The near rack continues off the right edge, its full top and side unseen.
    var extension := Node3D.new()
    extension.name = "WarehouseNearRackExtension"
    extension.position = Vector3(3.45, 0, 1.07)
    extension.rotation.y = 0.27
    warehouse_group.add_child(extension)
    _block(extension, "NearTowerBack", Vector3(0, 2.50, -0.48),
        Vector3(2.45, 4.94, 0.29), Color("#253f50"))
    for edge in [-1.0, 1.0]:
        _block(extension, "NearTowerCorner", Vector3(edge*1.20, 2.65, 0.02),
            Vector3(0.16, 5.37, 0.15), Color("#8a9eaa"))
    var crates: Array[Vector3] = []
    for row in range(6):
        _block(extension, "NearTowerShelf",
            Vector3(0, 0.32+float(row)*0.74, 0),
            Vector3(2.59, 0.10, 0.83), Color("#718897"))
        for col in range(3):
            crates.append(Vector3(-0.77+float(col)*0.75,
                0.59+float(row)*0.74, 0))
    _instances(extension, "NearTowerPackedBins", crates,
        Vector3(0.60, 0.46, 0.54), Color("#637b89"))
    var pallets := Node3D.new()
    pallets.name = "WarehouseForegroundPallets"
    pallets.position = Vector3(-1.47, 0, 2.28)
    pallets.rotation.y = -0.27
    warehouse_group.add_child(pallets)
    _block(pallets, "PalletBase", Vector3(0, 0.12, 0),
        Vector3(2.85, 0.23, 1.32), Color("#506572"))
    var packed: Array[Vector3] = []
    for row in range(2):
        for col in range(4):
            packed.append(Vector3(-1.05+float(col)*0.67,
                0.57+float(row)*0.74, 0))
    _instances(pallets, "CratePalletStacks", packed,
        Vector3(0.56, 0.65, 0.82), Color("#8699a4"))
    for side in [-1.0, 1.0]:
        _block(pallets, "PalletSafetyGuard",
            Vector3(side*1.42, 0.75, 0),
            Vector3(0.10, 1.44, 1.18), Color("#4a6071"))
    var hoist := Node3D.new()
    hoist.name = "WarehouseLargeOverheadHoist"
    hoist.position = Vector3(-0.25, 4.02, 0.50)
    hoist.rotation.y = -0.38
    warehouse_group.add_child(hoist)
    _block(hoist, "CeilingBridge", Vector3.ZERO,
        Vector3(5.40, 0.46, 0.86), Color("#394f60"))
    _block(hoist, "HangingHoistCarriage", Vector3(1.55, -0.65, 0),
        Vector3(0.73, 0.93, 0.72), Color("#6f8996"))
    _block(hoist, "WinchCable", Vector3(1.55, -1.54, 0),
        Vector3(0.08, 0.84, 0.09), Color("#a3b7c2"))
    _block(warehouse_group, "DeepAisleBulkContainers",
        Vector3(-0.63, 0.73, -3.64),
        Vector3(1.28, 1.44, 0.98), Color("#4c6675"))

func _ready() -> void:
    var world := WorldEnvironment.new()
    world.name = "Environment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#111f2d")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b4d0dc")
    environment.ambient_light_energy = 0.67
    world.environment = environment
    add_child(world)
    var light := DirectionalLight3D.new()
    light.name = "IndustrialKeyLight"
    light.rotation_degrees = Vector3(-45.0, 22.0, -14.0)
    light.light_energy = 1.15
    light.shadow_enabled = false
    add_child(light)
    # Independent scenery roots (only the active one is rendered).
    _build_printer()
    _build_print_room()
    _build_terminal()
    _build_converter()
    _build_conversion_room()
    _build_warehouse()
    _build_warehouse_room()
    _build_crate()
    _build_printer_closeup()
    _build_refinery_closeup()
    _build_warehouse_closeup()
    warehouse_scanner = Node3D.new()
    warehouse_scanner.name = "TravelingInventoryScanner"
    warehouse_scanner.position = Vector3(0.28, 1.12, -0.40)
    warehouse_group.add_child(warehouse_scanner)
    _block(warehouse_scanner, "ScanHead", Vector3.ZERO,
        Vector3(0.19, 0.10, 0.33), Color("#4ce0e9"), true)
    hero_camera = Camera3D.new()
    hero_camera.name = "HeroCamera"
    add_child(hero_camera)
    hero_camera.current = true
    set_section(current_section)

func set_section(section: String) -> void:
    # Refining and disassembly are different tabs of the material room.
    current_section = section if section in ["LABO", "SMELTER", "RECYCLER", "STORAGE"] else "LABO"
    printer_group.visible = current_section == "LABO"
    converter_group.visible = current_section in ["SMELTER", "RECYCLER"]
    warehouse_group.visible = current_section == "STORAGE"
    clock = 0.0
    state_time = 0.0
    crate_head.rotation = Vector3.ZERO
    crate_arm.rotation = Vector3.ZERO
    crate_left_arm.rotation = Vector3.ZERO
    match current_section:
        "LABO":
            crate.position = Vector3(1.20, 0, 0.60)
            crate.rotation.y = 2.55
            work_state = "print_to_terminal"
            # Low-right, upward-looking diagonal frame: foreground printer,
            # middle ground CRATE and rear suspended service bridge.
            # No room overview: giant printer, loader, and overhead drive
            # continue past viewport edges. Camera stays inside the workshop.
            hero_camera.position = Vector3(1.35, 1.55, 3.30)
            hero_camera.fov = 51.0
            hero_camera.look_at(Vector3(-0.78, 1.62, -0.44), Vector3.UP)
        "SMELTER", "RECYCLER":
            crate.position = Vector3(2.18, 0, 0.78)
            crate.rotation.y = 2.80
            work_state = "refinery_audit"
            # High-left downward three-quarter shot along the diagonal
            # procession of three staggered refinery chambers.
            # Half-frame foreground vessel, hanging pipeworks and a shrinking
            # diagonal tank line: walls/floor perimeter are never fully seen.
            hero_camera.position = Vector3(-1.20, 2.80, 3.30)
            hero_camera.fov = 53.0
            hero_camera.look_at(Vector3(-0.30, 1.50, -1.00), Vector3.UP)
        "STORAGE":
            crate.position = Vector3(0.70, 0, 0.27)
            crate.rotation.y = 2.95
            work_state = "storage_scan"
            # Elevated aisle-wide camera, opposite the refinery's left-side
            # vantage: near-left rack and distant right bank make deep parallax.
            # Foreground pallets and tower rack are intentionally cut by the
            # edges; only a small part of the deep, stocked aisle is visible.
            hero_camera.position = Vector3(2.35, 2.50, 2.85)
            hero_camera.fov = 54.0
            hero_camera.look_at(Vector3(0.10, 1.50, -0.90), Vector3.UP)

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
    # Print head and part grow on the manufacturing page only.
    printer_nozzle.position.x = -2.30 + 0.54 * sin(clock * 1.9)
    printer_nozzle.position.z = 0.28 + 0.24 * cos(clock * 1.13)
    printed_part.scale.y = 0.78 + 0.15 * sin(clock * 0.37)
    match work_state:
        "print_to_terminal":
            if _move_to(Vector3(1.50, 0, -0.35), delta):
                _enter("print_inspect_terminal")
        "print_inspect_terminal":
            crate.rotation.y = lerp_angle(crate.rotation.y, -2.85, minf(delta*2.0, 1.0))
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.23, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = -0.38 + 0.06*sin(clock*3.5)
            if state_time > 3.1:
                _enter("print_to_machine")
        "print_to_machine":
            if _move_to(Vector3(-0.58, 0, 1.39), delta):
                _enter("print_inspect_shell")
        "print_inspect_shell":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, -0.18, minf(delta*3.0, 1.0))
            crate_left_arm.rotation.x = 0.16*sin(clock*2.0)
            if state_time > 2.5:
                _enter("print_to_terminal")

func _animate_refinery(delta: float) -> void:
    # Refinery alone: rotating feedstock in each colored processing chamber.
    for i in range(converter_crystals.size()):
        var rotor: Node3D = converter_crystals[i]
        rotor.rotation.y = clock * (0.26 + float(i)*0.12)
        rotor.position.y = 1.25 + 0.065*sin(clock*1.6 + float(i)*1.3)
    match work_state:
        "refinery_audit":
            crate.rotation.y = lerp_angle(crate.rotation.y, 2.45, minf(delta*2.3, 1.0))
            crate_head.rotation.y = 0.17*sin(clock*1.1)
            crate_arm.rotation.x = -0.25 + 0.19*sin(clock*2.1)
            if state_time > 3.5:
                _enter("refinery_to_samples")
        "refinery_to_samples":
            if _move_to(Vector3(1.07, 0, 1.50), delta):
                _enter("refinery_sort")
        "refinery_sort":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.27, minf(delta*3.0, 1.0))
            crate_left_arm.rotation.x = -0.28 + 0.31*sin(clock*2.7)
            if state_time > 2.7:
                _enter("refinery_return")
        "refinery_return":
            if _move_to(Vector3(2.18, 0, 0.78), delta):
                _enter("refinery_audit")

func _animate_inventory(delta: float) -> void:
    # Warehouse alone: rail scanner sweeps, robot checks bins and logs stock.
    warehouse_scanner.position.x = 0.28 + 0.46*sin(clock*1.8)
    warehouse_scanner.rotation.y = 0.22*sin(clock*1.2)
    match work_state:
        "storage_scan":
            crate_head.rotation.y = 0.25*sin(clock*0.95)
            crate_arm.rotation.x = -0.12
            if state_time > 2.2:
                _enter("storage_go_left")
        "storage_go_left":
            if _move_to(Vector3(-0.94, 0, 1.18), delta):
                _enter("storage_get_bin")
        "storage_get_bin":
            crate_left_arm.rotation.x = -0.26 + 0.24*sin(clock*2.3)
            crate_arm.rotation.x = -0.29 + 0.20*sin(clock*2.3 + 0.75)
            crate_head.rotation.x = lerpf(crate_head.rotation.x, -0.23, minf(delta*3.0, 1.0))
            if state_time > 2.8:
                _enter("storage_go_terminal")
        "storage_go_terminal":
            if _move_to(Vector3(0.70, 0, 0.27), delta):
                _enter("storage_log_stock")
        "storage_log_stock":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.20, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = -0.18 + 0.07*sin(clock*3.0)
            if state_time > 2.5:
                _enter("storage_scan")
