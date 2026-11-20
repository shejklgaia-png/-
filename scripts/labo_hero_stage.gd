extends Node3D
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
## Shared LABO / converter / warehouse hero. Real low-poly 3D, no imported image.
## All parts are generated once; no physics, navigation or per-frame allocations.
var crate: Node3D
var crate_head: Node3D
var crate_arm: Node3D
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

func _build_room() -> void:
    _block(self, "Floor", Vector3(0, -0.15, -0.6),
        Vector3(8.2, 0.26, 6.0), Color("#273949"))
    _block(self, "BackWall", Vector3(0, 2.18, -3.45),
        Vector3(8.2, 4.6, 0.20), Color("#1b2e3f"))
    for x in [-3.7, 0.0, 3.7]:
        _block(self, "StructuralColumn", Vector3(x, 2.1, -3.1),
            Vector3(0.20, 4.2, 0.24), Color("#425c6c"))
    for y in [1.05, 2.8, 4.0]:
        _block(self, "WallBeam", Vector3(0, y, -3.18),
            Vector3(8.0, 0.12, 0.18), Color("#3c5a6c"))
    for x in [-3.0, -1.3, 0.4, 2.1, 3.4]:
        _block(self, "FloorLine", Vector3(x, -0.01, -0.6),
            Vector3(0.018, 0.012, 5.7), Color("#3b798d"), true)
    for x in [-2.95, 0.0, 2.95]:
        _block(self, "OverheadLight", Vector3(x, 3.95, -2.35),
            Vector3(0.95, 0.06, 0.16), Color("#6dc3d6"), true)
    _block(self, "RearEquipmentRack", Vector3(0.35, 1.05, -3.0),
        Vector3(1.22, 1.9, 0.55), Color("#354b5a"))
    for y in [0.65, 1.45, 2.05]:
        _block(self, "EquipmentRackLight", Vector3(0.35, y, -2.70),
            Vector3(0.92, 0.055, 0.045), Color("#4a9eb1"), true)
    _block(self, "AirVent", Vector3(-1.2, 2.55, -3.2),
        Vector3(0.95, 0.42, 0.12), Color("#344755"))
    # Additional architectural depth like the reference 3D laboratory.
    for z in [-2.65, -1.25, 0.15]:
        _block(self, "CeilingRail", Vector3(0, 4.05, z),
            Vector3(8.0, 0.15, 0.16), Color("#304b5c"))
    for x in [-2.6, 0.0, 2.6]:
        _block(self, "CoolWhiteCeilingLight", Vector3(x, 4.02, -1.20),
            Vector3(0.63, 0.035, 0.18), Color("#d0f6ff"), true)
    for i in range(4):
        _block(self, "CautionStripe", Vector3(-3.45 + float(i)*0.19, 0.015, 2.1),
            Vector3(0.10, 0.013, 0.48), Color("#cd9e42"))
    _block(self, "BacklitCompanyPanel", Vector3(2.65, 2.60, -3.30),
        Vector3(1.55, 0.78, 0.075), Color("#172d3c"))
    _sign(self, "SERA", Vector3(2.65, 2.54, -3.22), 62)

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
    _block(self, "TerminalColumn", Vector3(2.24, 0.62, -0.35),
        Vector3(0.38, 1.12, 0.36), Color("#486476"))
    _block(self, "TerminalConsole", Vector3(2.24, 1.06, -0.2),
        Vector3(1.27, 0.18, 0.87), Color("#486476"))
    var screen := Node3D.new()
    screen.name = "TerminalScreen"
    screen.position = Vector3(2.24, 1.60, -0.65)
    screen.rotation.x = -0.22
    add_child(screen)
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
    crate = Node3D.new()
    crate.name = "Crate"
    crate.position = Vector3(-0.78, 0, 0.97)
    add_child(crate)
    for x in [-0.37, 0.37]:
        _block(crate, "Track", Vector3(x, 0.24, 0),
            Vector3(0.30, 0.40, 1.05), Color("#202c37"))
        _block(crate, "TrackPanel", Vector3(x * 1.18, 0.33, 0),
            Vector3(0.04, 0.26, 0.84), Color("#547185"))
        for z in [-0.33, 0.0, 0.33]:
            _block(crate, "TrackTread", Vector3(x, 0.045, z),
                Vector3(0.31, 0.06, 0.16), Color("#455b6a"))
    _block(crate, "Chassis", Vector3(0, 0.50, 0),
        Vector3(0.88, 0.37, 0.85), Color("#8b9fae"))
    _block(crate, "ChassisTrim", Vector3(0, 0.59, 0.44),
        Vector3(0.68, 0.11, 0.06), Color("#3999b9"), true)
    crate_head = Node3D.new()
    crate_head.name = "HeadPivot"
    crate_head.position = Vector3(0, 0.83, -0.08)
    crate.add_child(crate_head)
    _block(crate_head, "Helmet", Vector3(0, 0, 0),
        Vector3(0.86, 0.43, 0.64), Color("#acb9c4"))
    _block(crate_head, "Visor", Vector3(0, 0.035, 0.335),
        Vector3(0.66, 0.11, 0.045), Color("#46d5e7"), true)
    _block(crate_head, "VisorRim", Vector3(0, 0.14, 0.33),
        Vector3(0.77, 0.04, 0.05), Color("#425769"))
    crate_arm = Node3D.new()
    crate_arm.name = "ArmPivot"
    crate_arm.position = Vector3(0.37, 0.61, 0.02)
    crate.add_child(crate_arm)
    _block(crate_arm, "UpperArm", Vector3(0.20, 0.04, 0.15),
        Vector3(0.38, 0.13, 0.16), Color("#7994a6"))
    _block(crate_arm, "Forearm", Vector3(0.38, 0.04, 0.32),
        Vector3(0.13, 0.12, 0.36), Color("#adbdca"))
    for i in range(3):
        _block(crate_arm, "ManipulatorFinger", Vector3(0.40 + (i - 1)*0.09, 0.035, 0.56),
            Vector3(0.06, 0.085, 0.18), Color("#8da9ba"))

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
    environment.background_color = Color("#101d2c")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#a5c7df")
    environment.ambient_light_energy = 0.52
    world.environment = environment
    add_child(world)
    var light := DirectionalLight3D.new()
    light.name = "AreaKeyLight"
    light.rotation_degrees = Vector3(-45.0, 22.0, -14.0)
    light.light_energy = 1.15
    light.shadow_enabled = false
    add_child(light)
    _build_room()
    _build_printer()
    _build_converter()
    _build_warehouse()
    _build_terminal()
    _build_crate()
    set_section(current_section)
    var camera := Camera3D.new()
    camera.name = "HeroCamera"
    camera.position = Vector3(0.25, 1.42, 6.20)
    camera.fov = 55.0
    add_child(camera)
    camera.look_at(Vector3(0, 1.65, -0.55), Vector3.UP)
    camera.current = true

func set_section(section: String) -> void:
    current_section = section
    if printer_group != null:
        printer_group.visible = section == "LABO"
    if converter_group != null:
        converter_group.visible = section in ["SMELTER", "RECYCLER"]
    if warehouse_group != null:
        warehouse_group.visible = section == "STORAGE"

func _move_to(goal: Vector3, delta: float) -> bool:
    var planar := Vector3(goal.x, crate.position.y, goal.z)
    var diff: Vector3 = planar - crate.position
    if diff.length() <= 0.07:
        crate.position = planar
        return true
    crate.position = crate.position.move_toward(planar, minf(1.05*delta, 0.26))
    var desired_yaw: float = atan2(diff.x, diff.z)
    crate.rotation.y = lerp_angle(crate.rotation.y, desired_yaw, minf(1.0, 2.5*delta))
    crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.0, minf(1.0, 4.0*delta))
    crate_arm.rotation.x = lerpf(crate_arm.rotation.x, 0.0, minf(1.0, 3.0*delta))
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
