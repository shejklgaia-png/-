extends Node3D
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

func _build_printer() -> void:
    var steel := Color("#657887")
    var dark := Color("#314757")
    var light := Color("#5abce4")
    var pivot := Node3D.new()
    pivot.name = "Printer"
    pivot.position = Vector3(-1.96, 0, -0.40)
    add_child(pivot)
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
    add_child(printer_nozzle)
    _block(printer_nozzle, "ToolHead", Vector3(0, 0, 0),
        Vector3(0.43, 0.38, 0.42), Color("#92a8b7"))
    _block(printer_nozzle, "Extruder", Vector3(0, -0.29, 0),
        Vector3(0.10, 0.20, 0.10), light, true)
    printed_part = Node3D.new()
    printed_part.name = "PrintedPart"
    printed_part.position = Vector3(-1.96, 0.70, -0.40)
    add_child(printed_part)
    _block(printed_part, "ArmorShell", Vector3.ZERO,
        Vector3(0.95, 0.38, 0.57), Color("#94aec1"))
    _block(printed_part, "ArmorCutout", Vector3(0.0, 0.23, 0),
        Vector3(0.43, 0.13, 0.35), Color("#3b718d"))
    _block(printed_part, "PrintEdge", Vector3(0, -0.22, 0.31),
        Vector3(0.95, 0.065, 0.035), light, true)

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
    _build_terminal()
    _build_crate()
    var camera := Camera3D.new()
    camera.name = "HeroCamera"
    camera.position = Vector3(0.25, 1.42, 6.20)
    camera.fov = 55.0
    add_child(camera)
    camera.look_at(Vector3(0, 1.65, -0.55), Vector3.UP)
    camera.current = true

func set_section(section: String) -> void:
    current_section = section

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
