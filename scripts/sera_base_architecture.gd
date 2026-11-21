extends RefCounted
## Industrial reference rebuild for the eight individually modelled base structures.
## Batched opaque meshes keep a dense kit-bashed silhouette on Android GL.
const COLORS = {
    "dark": "#202934", "void": "#121d27", "armor": "#53616f",
    "armor_light": "#72808c", "slate": "#3b4a59", "edge": "#84909a",
    "trim": "#303e4c", "crate": "#5a6573", "rubber": "#242b31",
    "gold": "#a98448", "caution": "#c4a35f", "cloth": "#8c8b80",
    "rust": "#785644", "blue": "#357d95", "blue_light": "#81d6ed",
    "amber": "#dd8647", "amber_light": "#ffc18b", "glass": "#276076",
    "white": "#b3c1c8"
}

class Batch:
    var host: Node3D
    var entries: Dictionary = {}
    var features: Array[String] = []

    func _init(node: Node3D) -> void:
        host = node

    func _put(feature: String, kind: String, tint: String, basis: Basis,
            at: Vector3) -> void:
        var key: String = kind + "|" + tint
        if not entries.has(key):
            entries[key] = []
        (entries[key] as Array).append(Transform3D(basis, at))
        if not features.has(feature):
            features.append(feature)

    func box(feature: String, at: Vector3, size: Vector3, tint: String = "armor",
            yaw: float = 0.0) -> void:
        _put(feature, "cube", tint, Basis(Vector3.UP, yaw).scaled_local(size), at)

    func rod(feature: String, start: Vector3, finish: Vector3, diameter: float,
            tint: String = "trim") -> void:
        var direction: Vector3 = finish - start
        if direction.length_squared() < 0.000001:
            return
        var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
        basis = basis.scaled_local(Vector3(diameter, direction.length(), diameter))
        _put(feature, "tube", tint, basis, (start + finish) * 0.5)

    func ring(feature: String, center: Vector3, radius: float,
            tint: String, axis: String = "y") -> void:
        # Eight straight segments: an angular, physically readable machine rim.
        for index in range(8):
            var a: float = TAU * float(index) / 8.0
            var b: float = TAU * float(index + 1) / 8.0
            if axis == "z":
                rod(feature, center + Vector3(cos(a) * radius, sin(a) * radius, 0),
                    center + Vector3(cos(b) * radius, sin(b) * radius, 0), 0.065, tint)
            else:
                rod(feature, center + Vector3(cos(a) * radius, 0, sin(a) * radius),
                    center + Vector3(cos(b) * radius, 0, sin(b) * radius), 0.065, tint)

    func crate(at: Vector3, size: Vector3, index: int = 0) -> void:
        box("CargoBody", at, size, "crate" if index % 3 else "slate")
        box("CargoLid", at + Vector3(0, size.y * 0.51, 0),
            Vector3(size.x * 1.03, 0.07, size.z * 1.03), "armor_light")
        for s in [-1.0, 1.0]:
            box("CargoCornerRail", at + Vector3(s * size.x * 0.44, 0,
                size.z * 0.51), Vector3(0.08, size.y, 0.06), "trim")
            box("CargoHandle", at + Vector3(s * size.x * 0.25, size.y * 0.05,
                size.z * 0.51), Vector3(0.13, 0.07, 0.05), "gold")
        box("CargoTopRib", at + Vector3(0, size.y * 0.54, 0),
            Vector3(0.08, 0.035, size.z), "edge")

    func flush() -> void:
        var keys: Array = entries.keys()
        keys.sort()
        for key_variant in keys:
            var key: String = str(key_variant)
            var names: PackedStringArray = key.split("|")
            var geometry: String = names[0]
            var tint: String = names[1]
            var poses: Array = entries[key]
            var mesh: PrimitiveMesh
            if geometry == "tube":
                var cylinder := CylinderMesh.new()
                cylinder.height = 1.0
                cylinder.top_radius = 0.5
                cylinder.bottom_radius = 0.5
                cylinder.radial_segments = 8
                mesh = cylinder
            else:
                var cube := BoxMesh.new()
                cube.size = Vector3.ONE
                mesh = cube
            var multi := MultiMesh.new()
            multi.transform_format = MultiMesh.TRANSFORM_3D
            multi.mesh = mesh
            multi.instance_count = poses.size()
            for i in range(poses.size()):
                multi.set_instance_transform(i, poses[i])
            var surface := StandardMaterial3D.new()
            surface.albedo_color = Color(COLORS[tint])
            surface.metallic = 0.31 if tint != "cloth" else 0.0
            surface.roughness = 0.75 if tint != "glass" else 0.46
            if tint in ["blue_light", "amber_light", "amber"]:
                surface.emission_enabled = true
                surface.emission = Color(COLORS[tint])
                surface.emission_energy_multiplier = 1.25 if tint == "amber" else 1.7
            var draw := MultiMeshInstance3D.new()
            draw.name = "Architectural_" + geometry + "_" + tint
            draw.multimesh = multi
            draw.material_override = surface
            draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            host.add_child(draw)
        host.set_meta("unique_model_features", features.duplicate())

static func _facade(g: Batch, half_width: float, height: float,
        depth: float) -> void:
    for side in [-1.0, 1.0]:
        g.box("FacadePillars", Vector3(side * half_width, height * 0.5, depth),
            Vector3(0.19, height, 0.24), "trim")
        for row in range(3):
            g.box("WallArmorBands", Vector3(side * (half_width - 0.17),
                0.72 + float(row) * 1.0, depth), Vector3(0.10, 0.12, 0.24), "edge")

static func build_nexus(parent: Node3D) -> void:
    var node := Node3D.new()
    node.name = "NexusArchitecture"
    parent.add_child(node)
    var g := Batch.new(node)
    # Wide reinforced shell, individual roof modules, recessed front blast door.
    g.box("ArmoredRoofHall", Vector3(0, 2.25, -0.08), Vector3(5.70, 3.98, 4.95), "armor")
    g.box("ArmoredRoof", Vector3(0, 4.38, -0.15), Vector3(6.27, 0.32, 5.27), "slate")
    g.box("ArmoredRoofRim", Vector3(0, 4.62, 2.27), Vector3(6.20, 0.17, 0.22), "edge")
    g.box("ArmoredRoofRim", Vector3(0, 4.62, -2.50), Vector3(6.20, 0.15, 0.20), "trim")
    for i in range(7):
        var x: float = -2.64 + float(i) * 0.88
        g.box("RoofPanelSeams", Vector3(x, 4.57, 0), Vector3(0.04, 0.02, 4.70), "dark")
        g.box("RoofFrontRivet", Vector3(x, 4.63, 2.20), Vector3(0.11, 0.05, 0.12), "edge")
    for side in [-1.0, 1.0]:
        g.box("FacadeBlastArmor", Vector3(side * 2.80, 2.10, 0),
            Vector3(0.35, 3.5, 4.75), "trim")
        g.box("SideServicePod", Vector3(side * 2.75, 1.90, 1.04),
            Vector3(0.45, 2.45, 1.65), "armor_light")
        g.box("RoofUtilityCabinet", Vector3(side * 1.75, 4.86, -1.20),
            Vector3(0.94, 0.42, 0.88), "crate")
        for row in range(4):
            g.box("RoofVentSlits", Vector3(side * 1.75, 5.09,
                -1.49 + row * 0.18), Vector3(0.71, 0.035, 0.07), "dark")
        g.rod("RoofPiping", Vector3(side * 2.23, 4.60, -2.10),
            Vector3(side * 2.23, 4.60, 1.20), 0.16, "gold")
        g.box("FacadeRail", Vector3(side * 2.0, 2.10, 2.42),
            Vector3(0.11, 3.5, 0.15), "edge")
        g.box("WarningSideLamp", Vector3(side * 2.25, 2.38, 2.65),
            Vector3(0.44, 0.17, 0.10), "amber_light")
    g.box("GatePortal", Vector3(0, 1.50, 2.51), Vector3(2.65, 2.85, 0.38), "dark")
    g.box("SealedGate", Vector3(0, 1.25, 2.77), Vector3(1.94, 2.35, 0.10), "slate")
    g.box("GatePortalLintel", Vector3(0, 2.97, 2.68), Vector3(2.42, 0.25, 0.27), "edge")
    g.box("GatePortalGlow", Vector3(0, 2.83, 2.86), Vector3(2.05, 0.13, 0.07), "amber_light")
    for side in [-1.0, 1.0]:
        g.box("GateBlueWayfinder", Vector3(side * 1.07, 1.39, 2.89),
            Vector3(0.065, 0.76, 0.045), "blue_light")
        g.box("GateTrack", Vector3(side * 0.82, 1.22, 2.84),
            Vector3(0.045, 2.32, 0.05), "dark")
    for row in range(4):
        g.box("BlastDoorSeam", Vector3(0, 0.56 + 0.47 * row, 2.84),
            Vector3(1.77, 0.025, 0.034), "dark")
    # Distinctive wall insignia made of physical crossed steel strips.
    g.rod("FrontEmblem", Vector3(-0.49, 3.70, 2.49),
        Vector3(0, 3.24, 2.49), 0.075, "white")
    g.rod("FrontEmblem", Vector3(0.49, 3.70, 2.49),
        Vector3(0, 3.24, 2.49), 0.075, "white")
    g.box("FrontEmblemCenter", Vector3(0, 3.62, 2.52),
        Vector3(0.16, 0.31, 0.06), "edge")
    # Crooked salvage-yard awning along the exposed left side of the building.
    for p in range(3):
        g.box("CanopyCanvas", Vector3(-2.30 + p * 0.40, 2.82 - p * 0.08, 2.42),
            Vector3(0.46, 0.045, 1.62), "cloth", -0.04)
    for side in [-1.0, 1.0]:
        g.rod("CanopySupport", Vector3(-2.18 + side * 0.55, 0.20, 3.08),
            Vector3(-2.18 + side * 0.55, 2.74, 3.08), 0.09, "trim")
    for i in range(4):
        g.crate(Vector3(-2.53 + float(i % 2) * 0.65, 0.43,
            3.02 - float(i / 2) * 0.70), Vector3(0.55, 0.70, 0.58), i)
    g.flush()

static func _labo(g: Batch) -> void:
    # Smaller, busy semi-open workshop: tarpaulin canopy, worktables and consoles.
    g.box("LabWorkshopShell", Vector3(0, 1.59, -0.32),
        Vector3(3.65, 2.82, 3.50), "slate")
    g.box("LabWorkshopInterior", Vector3(0, 1.28, 1.49),
        Vector3(2.55, 2.10, 0.15), "void")
    g.box("LabWorkFloor", Vector3(0, 0.28, 1.58),
        Vector3(3.55, 0.17, 1.85), "armor_light")
    g.box("LabCanopyFrame", Vector3(0, 3.01, 0.10),
        Vector3(4.05, 0.20, 4.0), "edge")
    for i in range(6):
        x = -1.74 + float(i) * 0.68
        g.box("CanopyCanvas", Vector3(x, 3.16 + 0.08 * cos(i * 1.2), 1.30),
            Vector3(0.73, 0.055, 2.65), "cloth")
    for side in [-1.0, 1.0]:
        g.rod("CanopyAwningPosts", Vector3(side * 1.82, 0.20, 2.16),
            Vector3(side * 1.82, 3.20, 2.16), 0.10, "dark")
        g.box("LabShelf", Vector3(side * 1.32, 1.12, 0.92),
            Vector3(0.52, 1.65, 0.45), "trim")
        for row in range(3):
            g.box("LabShelfEquipment", Vector3(side * 1.30,
                0.50 + row * 0.53, 1.22),
                Vector3(0.32, 0.29, 0.10), "amber" if row == 1 else "armor")
    g.box("LabWorkbench", Vector3(0.48, 0.86, 2.02),
        Vector3(1.45, 0.17, 0.75), "armor_light")
    g.box("LabWorkbenchFrame", Vector3(0.48, 0.46, 2.01),
        Vector3(1.17, 0.62, 0.62), "trim")
    g.box("LabConsoleScreen", Vector3(1.22, 1.75, 1.57),
        Vector3(0.70, 0.51, 0.08), "glass")
    g.box("LabConsoleDisplay", Vector3(1.22, 1.76, 1.63),
        Vector3(0.57, 0.38, 0.05), "blue")
    for row in range(3):
        g.box("LabConsoleTelemetry", Vector3(1.14, 1.64 + row * 0.10, 1.66),
            Vector3(0.26 + row * 0.09, 0.024, 0.015), "blue_light")
    for i in range(6):
        g.box("LabWallTool", Vector3(-1.25 + (i % 3) * 0.44,
            1.15 + (i / 3) * 0.55, 1.66),
            Vector3(0.10, 0.38, 0.09), "edge")
    g.box("LabAmberLamp", Vector3(0, 2.49, 1.75),
        Vector3(1.18, 0.10, 0.08), "amber_light")
    g.crate(Vector3(-1.50, 0.43, 2.14), Vector3(0.56, 0.62, 0.48))
    g.crate(Vector3(1.56, 0.33, -1.30), Vector3(0.52, 0.46, 0.48), 1)

static func _collector(g: Batch) -> void:
    # A real pick-and-drop scrap recovery claw over a low sorting hopper.
    g.box("CollectorBase", Vector3(0, 0.35, 0), Vector3(2.17, 0.55, 2.0), "trim")
    g.box("ScrapHopper", Vector3(0.35, 0.67, 0.22),
        Vector3(1.34, 0.70, 1.24), "slate")
    for side in [-1.0, 1.0]:
        g.box("HopperRim", Vector3(side * 0.67 + 0.35, 1.08, 0.22),
            Vector3(0.11, 0.16, 1.34), "edge")
    for i in range(8):
        var x: float = 0.02 + float(i % 4) * 0.25
        var z: float = -0.18 + float(i / 4) * 0.43
        g.box("RecoveredMetalScrap", Vector3(x, 1.06 + float(i % 3) * 0.08, z),
            Vector3(0.30, 0.12, 0.21), "armor_light" if i % 2 else "dark",
            0.22 * i)
    g.box("CollectorMotor", Vector3(-0.84, 0.78, -0.30),
        Vector3(0.46, 0.88, 0.60), "armor")
    g.rod("HydraulicCrane", Vector3(-0.76, 1.05, -0.30),
        Vector3(-0.62, 2.25, -0.35), 0.29, "gold")
    g.rod("HydraulicCrane", Vector3(-0.62, 2.25, -0.35),
        Vector3(0.46, 2.12, 0.02), 0.27, "gold")
    g.rod("HydraulicPiston", Vector3(-0.62, 1.35, -0.34),
        Vector3(0.07, 2.04, -0.15), 0.10, "edge")
    g.rod("GrabberChain", Vector3(0.46, 2.12, 0.02),
        Vector3(0.46, 1.52, 0.02), 0.08, "dark")
    for side in [-1.0, 1.0]:
        g.rod("ClawFinger", Vector3(0.46, 1.50, 0.02),
            Vector3(0.46 + side * 0.23, 1.14, 0.05), 0.12, "edge")
        g.rod("ClawTooth", Vector3(0.46 + side * 0.23, 1.14, 0.05),
            Vector3(0.46 + side * 0.11, 0.96, 0.11), 0.08, "armor_light")
    g.box("CollectorWarningLight", Vector3(-0.84, 1.43, 0.20),
        Vector3(0.40, 0.10, 0.06), "blue_light")

static func _smelter(g: Batch) -> void:
    # Glowing heat chamber, copper chimney and exposed pressure pipes.
    g.box("FurnaceCore", Vector3(0, 0.93, 0),
        Vector3(1.73, 1.50, 1.70), "armor")
    g.box("FurnaceMouth", Vector3(0, 0.94, 0.90),
        Vector3(1.17, 0.98, 0.09), "amber")
    g.box("FurnaceGlow", Vector3(0, 0.91, 0.96),
        Vector3(0.87, 0.72, 0.05), "amber_light")
    for i in range(5):
        g.box("FurnaceGrille", Vector3(-0.46 + i * 0.23, 0.98, 1.02),
            Vector3(0.065, 0.92, 0.07), "dark")
    for side in [-1.0, 1.0]:
        g.box("FurnaceOuterRib", Vector3(side * 0.89, 1.05, 0),
            Vector3(0.20, 1.98, 1.84), "trim")
        g.rod("HeatPipe", Vector3(side * 0.80, 1.73, -0.35),
            Vector3(side * 1.01, 2.35, -0.35), 0.17, "rust")
        g.rod("HeatPipe", Vector3(side * 1.01, 2.35, -0.35),
            Vector3(side * 1.01, 2.35, 0.58), 0.15, "gold")
    g.box("FurnaceArmorLid", Vector3(0, 1.86, -0.09),
        Vector3(2.18, 0.25, 1.98), "edge")
    g.rod("ExhaustStack", Vector3(-0.66, 1.88, -0.55),
        Vector3(-0.66, 2.82, -0.55), 0.53, "slate")
    g.ring("ExhaustStackRim", Vector3(-0.66, 2.81, -0.55), 0.31, "edge")
    g.box("FurnaceControl", Vector3(0.87, 0.88, 0.54),
        Vector3(0.30, 0.59, 0.34), "trim")
    g.box("FurnaceControlLight", Vector3(1.04, 1.09, 0.62),
        Vector3(0.04, 0.17, 0.13), "blue_light")
    for i in range(5):
        g.box("HazardStripe", Vector3(-0.74 + i * 0.35, 0.26, 1.06),
            Vector3(0.12, 0.08, 0.15), "caution")

static func _recycler(g: Batch) -> void:
    # Open crushing mouth with exposed grooved cylindrical cutters and discharge bin.
    g.box("CrusherDeck", Vector3(0, 0.35, 0),
        Vector3(2.23, 0.44, 2.01), "armor")
    for side in [-1.0, 1.0]:
        g.box("CrusherSideGuard", Vector3(side * 0.96, 1.22, 0),
            Vector3(0.22, 1.32, 1.86), "trim")
        g.box("CrusherMotor", Vector3(side * 0.99, 0.93, -0.58),
            Vector3(0.34, 0.54, 0.51), "slate")
    g.box("CrusherThroat", Vector3(0, 1.0, 0.0),
        Vector3(1.66, 0.33, 1.39), "void")
    for row in range(5):
        var z: float = -0.48 + float(row) * 0.24
        g.rod("CrusherRoller", Vector3(-0.75, 1.11, z),
            Vector3(0.75, 1.11, z), 0.21, "edge")
        for k in range(6):
            g.box("CrusherCutterTeeth", Vector3(-0.58 + float(k) * 0.23,
                1.24, z), Vector3(0.12, 0.10, 0.06), "dark")
    g.box("CrusherOutputTray", Vector3(0, 0.54, 1.04),
        Vector3(1.66, 0.11, 0.76), "armor_light")
    for i in range(5):
        g.box("CrusherCautionStripes", Vector3(-0.75 + 0.35 * i,
            0.67, 1.28), Vector3(0.15, 0.04, 0.25), "caution")
    g.box("CrusherStatusLight", Vector3(1.02, 1.71, 0.57),
        Vector3(0.17, 0.10, 0.25), "amber_light")

static func _generator(g: Batch) -> void:
    # Horizontal blue turbine and a separate dark power conditioning cabinet.
    g.box("GeneratorSkid", Vector3(0, 0.31, 0),
        Vector3(2.2, 0.44, 1.99), "trim")
    for side in [-1.0, 1.0]:
        g.box("EnergyBearing", Vector3(side * 0.58, 0.91, 0.0),
            Vector3(0.25, 1.24, 1.26), "armor")
        g.ring("EnergyEndRim", Vector3(side * 0.62, 1.08, 0.0),
            0.43, "edge", "z")
    g.box("EnergyCore", Vector3(0.0, 1.11, 0.0),
        Vector3(0.91, 0.69, 1.10), "blue")
    for index in range(7):
        g.box("EnergyCoil", Vector3(-0.38 + float(index) * 0.13,
            1.10, 0.63), Vector3(0.065, 0.54, 0.06), "blue_light")
    g.box("GeneratorPowerCabinet", Vector3(0.87, 1.36, -0.32),
        Vector3(0.59, 1.98, 1.06), "crate")
    g.box("GeneratorPanel", Vector3(0.86, 1.56, 0.25),
        Vector3(0.41, 0.58, 0.08), "dark")
    for row in range(4):
        g.box("GeneratorPanelMeters", Vector3(0.84, 1.37 + row * 0.13,
            0.32), Vector3(0.24, 0.045, 0.03), "blue_light")
    for side in [-1.0, 1.0]:
        g.rod("PowerConduit", Vector3(side * 0.7, 0.60, -0.45),
            Vector3(side * 0.94, 0.34, -0.84), 0.12, "rubber")
    g.box("GeneratorAmberIndicator", Vector3(-0.90, 1.87, 0.34),
        Vector3(0.22, 0.14, 0.08), "amber_light")

static func _storage(g: Batch) -> void:
    g.box("CargoStoragePallet", Vector3(0, 0.24, 0),
        Vector3(2.3, 0.29, 2.07), "trim")
    for i in range(6):
        var x: float = -0.72 + float(i % 3) * 0.70
        var y: float = 0.68 + float(i / 3) * 0.68
        g.crate(Vector3(x, y, -0.27), Vector3(0.59, 0.58, 0.90), i)
    for side in [-1.0, 1.0]:
        for row in range(3):
            g.box("CargoStoragePalletRail", Vector3(side * 1.12,
                0.52 + row * 0.42, 0), Vector3(0.095, 0.11, 1.91), "edge")
        g.rod("CargoStorageCornerPost", Vector3(side * 1.10, 0.18, -0.90),
            Vector3(side * 1.10, 1.86, -0.90), 0.10, "gold")
    g.box("CargoStorageTarp", Vector3(0.0, 1.76, -0.11),
        Vector3(2.15, 0.045, 1.72), "cloth")
    for i in range(4):
        g.box("CargoStorageTieStrap", Vector3(-0.73 + i * 0.48,
            1.79, -0.11), Vector3(0.04, 0.04, 1.67), "rust")

static func _construction(g: Batch) -> void:
    # Operator-height terminal with an angled holographic blueprint stand.
    g.box("BlueprintTerminalFoot", Vector3(0, 0.30, 0.11),
        Vector3(1.97, 0.43, 1.85), "trim")
    g.box("BlueprintTerminalBody", Vector3(0, 0.90, -0.23),
        Vector3(1.68, 0.80, 0.86), "armor")
    g.box("BlueprintScreenHousing", Vector3(0, 1.68, -0.31),
        Vector3(1.73, 1.07, 0.34), "edge")
    g.box("BlueprintScreenDark", Vector3(0, 1.70, -0.09),
        Vector3(1.48, 0.85, 0.08), "void")
    g.box("BlueprintScreen", Vector3(0, 1.71, -0.045),
        Vector3(1.31, 0.70, 0.042), "glass")
    for row in range(5):
        g.box("BlueprintGridHorizontal", Vector3(0, 1.47 + row * 0.11,
            -0.009), Vector3(1.15, 0.012, 0.011), "blue")
    for col in range(6):
        g.box("BlueprintGridVertical", Vector3(-0.51 + col * 0.20,
            1.71, -0.006), Vector3(0.012, 0.57, 0.011), "blue")
    g.box("BlueprintWireframe", Vector3(0.02, 1.78, 0.018),
        Vector3(0.44, 0.28, 0.014), "blue_light")
    g.box("BlueprintKeypad", Vector3(0, 1.02, 0.51),
        Vector3(1.45, 0.18, 0.65), "slate")
    for row in range(3):
        for col in range(6):
            g.box("BlueprintKeys", Vector3(-0.53 + col * 0.20,
                1.13, 0.32 + 0.17 * row), Vector3(0.12, 0.02, 0.08),
                "edge" if col % 2 else "blue")
    g.rod("BlueprintAntenna", Vector3(0.79, 1.58, -0.54),
        Vector3(0.79, 2.45, -0.54), 0.065, "edge")
    g.box("BlueprintAntennaTip", Vector3(0.79, 2.48, -0.54),
        Vector3(0.15, 0.18, 0.15), "amber_light")

static func build_facility(parent: Node3D, key: String) -> void:
    var node := Node3D.new()
    node.name = "IndustrialModel"
    parent.add_child(node)
    var g := Batch.new(node)
    match key:
        "LABO":
            _labo(g)
        "SCRAP_COLLECTOR":
            _collector(g)
        "SMELTER":
            _smelter(g)
        "RECYCLER":
            _recycler(g)
        "GENERATOR":
            _generator(g)
        "STORAGE":
            _storage(g)
        "BUILD_TERMINAL":
            _construction(g)
        _:
            push_warning("Unknown base device: " + key)
            return
    # Shared bolted skid and utility conduits, with unique anatomy above.
    for side in [-1.0, 1.0]:
        g.box("BaseMountingRail", Vector3(side * 0.72, 0.24, 0.0),
            Vector3(0.10, 0.15, 1.65), "dark")
        for end in [-1.0, 1.0]:
            g.box("BaseMountingBolt", Vector3(side * 0.72, 0.34, end * 0.71),
                Vector3(0.11, 0.055, 0.11), "edge")
    g.flush()
