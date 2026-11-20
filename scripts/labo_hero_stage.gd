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
    _block(printer_group, "PrinterFloorSafetyLine", Vector3(-1.92, 0.017, 1.88),
        Vector3(3.5, 0.018, 0.10), Color("#d9a94e"))
    # Additional architectural depth like the reference 3D laboratory.
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
    _block(room, "SorterScannerRail", Vector3(0.13, 1.10, 0.10),
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
    pivot.position = Vector3(-1.96, 0, -0.40)
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
    printer_nozzle.position = Vector3(-1.96, 1.73, -0.40)
    printer_group.add_child(printer_nozzle)
    _block(printer_nozzle, "ToolHead", Vector3(0, 0, 0),
        Vector3(0.43, 0.38, 0.42), Color("#92a8b7"))
    _block(printer_nozzle, "Extruder", Vector3(0, -0.29, 0),
        Vector3(0.10, 0.20, 0.10), light, true)
    printed_part = Node3D.new()
    printed_part.name = "PrintedPart"
    printed_part.position = Vector3(-1.96, 0.70, -0.40)
    printer_group.add_child(printed_part)
    _block(printed_part, "ArmorShell", Vector3.ZERO,
        Vector3(0.95, 0.38, 0.57), Color("#94aec1"))
    _block(printed_part, "ArmorCutout", Vector3(0.0, 0.23, 0),
        Vector3(0.43, 0.13, 0.35), Color("#3b718d"))
    _block(printed_part, "PrintEdge", Vector3(0, -0.22, 0.31),
        Vector3(0.95, 0.065, 0.035), light, true)
    # The reference shows a broad enclosed gantry and a solid helmet shell.
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
    _block(printer_group, "TerminalColumn", Vector3(2.24, 0.62, -0.35),
        Vector3(0.38, 1.12, 0.36), Color("#486476"))
    _block(printer_group, "TerminalConsole", Vector3(2.24, 1.06, -0.2),
        Vector3(1.27, 0.18, 0.87), Color("#486476"))
    var screen := Node3D.new()
    screen.name = "TerminalScreen"
    screen.position = Vector3(2.24, 1.60, -0.65)
    screen.rotation.x = -0.22
    printer_group.add_child(screen)
    _block(screen, "DisplayBack", Vector3.ZERO,
        Vector3(1.38, 0.91, 0.08), Color("#425e6c"))
    _block(screen, "DisplayGlass", Vector3(0, 0, 0.055),
        Vector3(1.22, 0.76, 0.022), Color("#183a4f"))
    for row in range(4):
        _block(screen, "ReadoutLine", Vector3(-0.22, 0.26 - row * 0.16, 0.07),
            Vector3(0.59 - row * 0.04, 0.025, 0.008), Color("#45b1d2"), true)
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
    _block(converter_group, "MachineBackplane", Vector3(-1.50, 1.25, -2.85),
        Vector3(4.95, 2.75, 0.36), Color("#2f4656"))
    var glows: Array[Color] = [
        Color("#edac49"), Color("#56b8e0"), Color("#aa80d7")]
    for i in range(3):
        var x: float = -3.05 + float(i) * 1.50
        _cylinder(converter_group, "ChamberBase", Vector3(x, 0.45, -1.52),
            0.62, 0.40, Color("#354a59"))
        _cylinder(converter_group, "ChamberBody", Vector3(x, 1.35, -1.52),
            0.53, 1.52, Color("#344c5e"))
        # Open front of the opaque chamber, so the emissive contents remain
        # visible without costly refractive glass/transparency passes.
        _block(converter_group, "ChamberWindow", Vector3(x, 1.33, -0.98),
            Vector3(0.75, 1.03, 0.08), Color("#132c3c"))
        _cylinder(converter_group, "ChamberRoof", Vector3(x, 2.22, -1.52),
            0.65, 0.20, Color("#6e8795"))
        _cylinder(converter_group, "RingTop", Vector3(x, 2.03, -1.52),
            0.56, 0.07, glows[i], true)
        _cylinder(converter_group, "RingLower", Vector3(x, 0.70, -1.52),
            0.56, 0.07, glows[i], true)
        var rotor := Node3D.new()
        rotor.name = "CrystalRotor_" + str(i)
        rotor.position = Vector3(x, 1.25, -0.87)
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
                0.21 * cos(float(j) * 2.5),
                -0.23 + float(j % 3) * 0.20,
                0.11 * sin(float(j) * 2.5))
            rotor.add_child(crystal)
        # A pipe joint and illuminated status stripe identify each station.
        _block(converter_group, "PipeUpright", Vector3(x, 2.70, -2.75),
            Vector3(0.15, 0.92, 0.13), Color("#718897"))
        _block(converter_group, "StatusScreen", Vector3(x, 0.40, -0.62),
            Vector3(0.72, 0.24, 0.06), Color("#21495d"))
        _block(converter_group, "Readout", Vector3(x, 0.42, -0.57),
            Vector3(0.47, 0.03, 0.015), glows[i], true)
    for i in range(3):
        _sign(converter_group, "REF %d" % (i+1),
            Vector3(-3.05 + float(i)*1.50, 2.48, -0.90), 25)
    _block(converter_group, "ServiceBench", Vector3(0, 0.29, 0.42),
        Vector3(4.9, 0.35, 0.76), Color("#435b6b"))
    for j in range(6):
        var box_x: float = -2.65 + float(j) * 0.49
        _block(converter_group, "SortedMaterials", Vector3(box_x, 0.54, 0.46),
            Vector3(0.27, 0.20, 0.23), glows[int(j/2)])

func _build_warehouse() -> void:
    warehouse_group = Node3D.new()
    warehouse_group.name = "WarehouseScene"
    add_child(warehouse_group)
    # Industrial shelving in depth; small solid bins are instanced geometry,
    # never separate UI controls, and stay under one hundred static meshes.
    for side in [-1, 1]:
        var x: float = float(side) * 2.65
        _block(warehouse_group, "RackBack", Vector3(x, 1.67, -2.45),
            Vector3(2.15, 3.15, 0.16), Color("#253d4c"))
        for col in range(3):
            for row in range(4):
                var box_x: float = x - 0.68 + float(col) * 0.67
                var box_y: float = 0.59 + float(row) * 0.67
                _block(warehouse_group, "StorageBin", Vector3(box_x, box_y, -2.23),
                    Vector3(0.53, 0.45, 0.40), Color("#536c7b"))
                _block(warehouse_group, "BinID", Vector3(box_x, box_y+0.10, -1.99),
                    Vector3(0.36, 0.08, 0.02), Color("#a9ccd9"))
                _block(warehouse_group, "BinHandle", Vector3(box_x, box_y-0.12, -1.99),
                    Vector3(0.17, 0.04, 0.025), Color("#253c4e"))
        for row in range(5):
            _block(warehouse_group, "ShelfBar", Vector3(x, 0.26+float(row)*0.67, -2.08),
                Vector3(2.25, 0.09, 0.52), Color("#718b98"))
        for edge in [-1.12, 1.12]:
            _block(warehouse_group, "RackPost", Vector3(x+edge, 1.66, -2.04),
                Vector3(0.11, 3.40, 0.12), Color("#7793a0"))
    _sign(warehouse_group, "H01",
        Vector3(-2.65, 3.20, -2.08), 40)
    _sign(warehouse_group, "B01",
        Vector3(2.65, 3.20, -2.08), 40)
    _block(warehouse_group, "SortingTable", Vector3(0.13, 0.51, 0.06),
        Vector3(1.25, 0.28, 0.84), Color("#465e6d"))
    _block(warehouse_group, "ScanningPanel", Vector3(0.13, 0.70, 0.10),
        Vector3(1.05, 0.07, 0.67), Color("#23495d"))
    for col in range(4):
        _block(warehouse_group, "SortingReadout", Vector3(-0.25+float(col)*0.25, 0.75, 0.05),
            Vector3(0.13, 0.02, 0.44), Color("#56b6d3"), true)

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
    warehouse_scanner = Node3D.new()
    warehouse_scanner.name = "TravelingInventoryScanner"
    warehouse_scanner.position = Vector3(0.1, 1.12, 0.10)
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
            crate.position = Vector3(1.25, 0, 0.96)
            crate.rotation.y = 2.55
            work_state = "print_to_terminal"
            hero_camera.position = Vector3(0.30, 1.40, 6.95)
            hero_camera.fov = 52.0
            hero_camera.look_at(Vector3(-0.2, 1.86, -0.95), Vector3.UP)
        "SMELTER", "RECYCLER":
            crate.position = Vector3(1.84, 0, 0.66)
            crate.rotation.y = 2.80
            work_state = "refinery_audit"
            hero_camera.position = Vector3(0.50, 1.49, 7.1)
            hero_camera.fov = 52.0
            hero_camera.look_at(Vector3(-0.17, 1.83, -1.15), Vector3.UP)
        "STORAGE":
            crate.position = Vector3(0.82, 0, 0.55)
            crate.rotation.y = 2.95
            work_state = "storage_scan"
            hero_camera.position = Vector3(-0.25, 1.52, 7.3)
            hero_camera.fov = 52.0
            hero_camera.look_at(Vector3(0.05, 1.93, -1.27), Vector3.UP)

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
    # The printer keeps fabricating while the lab is visible.
    printer_nozzle.position.x = -1.96 + 0.55 * sin(clock * 1.9)
    printer_nozzle.position.z = -0.40 + 0.23 * cos(clock * 1.13)
    printed_part.scale.y = 0.72 + 0.18 * sin(clock * 0.37)
    if current_section in ["SMELTER", "RECYCLER"]:
        for index in range(converter_crystals.size()):
            var crystal: Node3D = converter_crystals[index]
            crystal.rotation.y = clock * (0.18 + float(index)*0.08)
            crystal.position.y = 1.25 + 0.075 * sin(clock * 1.7 + float(index))
    match work_state:
        "walk_to_terminal":
            if _move_to(Vector3(1.18, 0, 0.65), delta):
                _enter("inspect_terminal")
        "inspect_terminal":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.24, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = lerpf(crate_arm.rotation.x, -0.55, minf(delta*3.0, 1.0))
            crate_arm.rotation.y = 0.12 * sin(clock * 2.5)
            if state_time > 3.2:
                _enter("walk_to_printer")
        "walk_to_printer":
            if _move_to(Vector3(-0.88, 0, 0.85), delta):
                _enter("inspect_printer")
        "inspect_printer":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, -0.16, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = lerpf(crate_arm.rotation.x, -0.12, minf(delta*3.0, 1.0))
            if state_time > 2.3:
                _enter("walk_to_terminal")
