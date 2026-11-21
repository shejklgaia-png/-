extends RefCounted
## SERA BASE functional industrial finish: readable mid-scale geometry rather
## than repeating tiny bolts. All features enter the existing opaque Batch.
## Exterior face is local +Z; preserve doorways, roof clearance and single pads.
## This layer contains NO frame loops, light nodes or collision shapes.

static func _nexus(g: Variant) -> void:
    # Service catwalk visibly separates the armored roof from the front wall.
    g.poly("NexusRaisedCatwalk", "bevel",
        Vector3(0.0, 4.59, 2.19), Vector3(3.62, 0.14, 0.54), "slate")
    for side in [-1.0, 1.0]:
        g.rod("NexusCatwalkDiagonal",
            Vector3(side * 1.64, 4.52, 2.42),
            Vector3(side * 1.48, 4.14, 2.13), 0.075, "edge")
        g.rod("NexusRoofSafetyHandrail",
            Vector3(side * 1.55, 4.74, 2.43),
            Vector3(side * 1.55, 5.06, 2.43), 0.042, "edge")
        g.box("NexusInsetServiceHatch",
            Vector3(side * 2.95, 1.58, 1.48),
            Vector3(0.13, 0.89, 0.77), "dark")
        g.poly("NexusHatchArmorLip", "bevel",
            Vector3(side * 3.00, 1.58, 1.48),
            Vector3(0.11, 1.03, 0.92), "armor_light")
        g.box("NexusServiceHandle",
            Vector3(side * 3.071, 1.47, 1.48),
            Vector3(0.035, 0.15, 0.24), "gold")
    g.rod("NexusRoofSafetyHandrail",
        Vector3(-1.55, 5.04, 2.43),
        Vector3(1.55, 5.04, 2.43), 0.045, "edge")
    # Roof openings remain lower-contrast than the doorway sign.
    for i in range(5):
        var x: float = -1.24 + float(i) * 0.62
        g.box("NexusRoofServiceSlots",
            Vector3(x, 4.87, -0.12), Vector3(0.38, 0.05, 0.92), "dark")
        for rib in range(3):
            g.box("NexusRoofServiceFins",
                Vector3(x - 0.125 + rib * 0.125, 4.922, -0.12),
                Vector3(0.058, 0.037, 0.83), "armor_light")
    # Accessible ladder on an external side; clear of the center gate.
    for step in range(6):
        g.box("NexusWallAccessLadder",
            Vector3(2.99, 0.66 + float(step) * 0.43, -0.72),
            Vector3(0.19, 0.055, 0.49), "gold")
    for z in [-0.94, -0.51]:
        g.rod("NexusWallAccessLadder",
            Vector3(3.07, 0.49, z), Vector3(3.07, 3.10, z),
            0.055, "edge")

static func _labo(g: Variant) -> void:
    # Actual fabrication head rails, not another opaque wall.
    g.rod("LabPrinterServiceGantry",
        Vector3(-1.36, 2.58, 0.15), Vector3(1.30, 2.58, 0.15),
        0.12, "armor_light")
    g.rod("LabPrinterCrossSlide",
        Vector3(0.29, 2.55, -0.33), Vector3(0.29, 2.55, 0.88),
        0.09, "edge")
    g.box("LabPrinterDriveHousing",
        Vector3(0.29, 2.44, 0.22),
        Vector3(0.42, 0.25, 0.38), "slate")
    for side in [-1.0, 1.0]:
        g.rod("LabOverheadBrace",
            Vector3(side * 1.50, 2.60, 0.10),
            Vector3(side * 1.80, 3.05, 1.10), 0.055, "edge")
        g.poly("LabFrontStorageCabinet", "bevel",
            Vector3(side * 1.34, 0.65, 1.30),
            Vector3(0.45, 0.78, 0.48), "slate")
        g.box("LabDrawerHighlight",
            Vector3(side * 1.34, 0.67, 1.55),
            Vector3(0.34, 0.05, 0.028), "gold")
    for index in range(4):
        var x: float = -0.73 + 0.47 * float(index)
        g.box("LabFabFloorChannels",
            Vector3(x, 0.42, 0.75),
            Vector3(0.09, 0.028, 1.38), "dark")
    g.box("LabDiagnosticConsole",
        Vector3(0.82, 1.43, -1.28),
        Vector3(0.72, 0.41, 0.10), "void")
    for index in range(3):
        g.box("LabDiagnosticTelemetry",
            Vector3(0.66 + 0.18 * float(index), 1.45, -1.22),
            Vector3(0.08, 0.16 + index * 0.07, 0.025), "blue_light")

static func _collector(g: Variant) -> void:
    # Segmented hose clearly follows the angled boom and final claw joint.
    var joints: Array[Vector3] = [
        Vector3(-0.93, 0.89, -0.59),
        Vector3(-0.92, 1.72, -0.59),
        Vector3(-0.69, 2.38, -0.57),
        Vector3(0.28, 2.30, -0.17),
        Vector3(0.46, 1.84, -0.17),
    ]
    for i in range(joints.size() - 1):
        g.rod("CollectorArticulatedLine",
            joints[i], joints[i + 1], 0.065, "rubber")
    for j in [1, 2, 3]:
        g.poly("CollectorLineCouplers", "bevel",
            joints[j], Vector3(0.22, 0.20, 0.22), "gold")
    g.poly("CollectorCraneHydraulicSeat", "bevel",
        Vector3(-0.80, 0.44, -0.30),
        Vector3(0.85, 0.30, 0.70), "dark")
    for tooth in range(3):
        var z: float = -0.18 + tooth * 0.28
        g.box_tilt("CollectorLooseScrapSlices",
            Vector3(0.28 + tooth * 0.21, 1.10 + 0.04 * tooth, z),
            Vector3(0.25, 0.065, 0.17), "edge" if tooth % 2 else "rust",
            Vector3(0.11, 0.31 * tooth, -0.13))

static func _smelter(g: Variant) -> void:
    # Thermal ribs sit OUTSIDE the glowing mouth, so its light stays visible.
    for side in [-1.0, 1.0]:
        for level in range(4):
            g.box("FurnaceHeatShieldRibs",
                Vector3(side * 1.00, 0.57 + level * 0.33, 0.34),
                Vector3(0.11, 0.09, 0.71), "rust")
        g.rod("FurnaceCoolantReturn",
            Vector3(side * 1.02, 0.42, -0.73),
            Vector3(side * 1.10, 1.57, -0.73), 0.095, "gold")
    g.poly("FurnaceSlagTray", "hood",
        Vector3(0, 0.23, 1.30),
        Vector3(1.47, 0.19, 0.44), "slate")
    for index in range(4):
        g.box_tilt("FurnaceSpentIngot",
            Vector3(-0.47 + index * 0.30, 0.34, 1.41),
            Vector3(0.18, 0.09, 0.21), "gold" if index % 2 else "rust",
            Vector3(0, 0, 0.05 * index))

static func _recycler(g: Variant) -> void:
    for side in [-1.0, 1.0]:
        g.rod("CrusherInputSafetyRim",
            Vector3(side * 0.90, 1.49, -1.03),
            Vector3(side * 0.90, 1.69, -0.48), 0.11, "gold")
        g.rod("CrusherInputSafetyRim",
            Vector3(side * 0.90, 1.69, -0.48),
            Vector3(side * 0.90, 1.30, 0.44), 0.10, "edge")
        g.poly("CrusherMotorSideBearing", "bevel",
            Vector3(side * 1.07, 1.05, 0.12),
            Vector3(0.30, 0.54, 0.61), "armor_light")
    for i in range(6):
        var x: float = -0.69 + i * 0.28
        g.box("CrusherSortingChuteRibs",
            Vector3(x, 0.59, 1.06),
            Vector3(0.075, 0.10, 0.58), "trim")
    g.poly("CrusherOutletLip", "bevel",
        Vector3(0.0, 0.52, 1.32),
        Vector3(1.85, 0.13, 0.31), "rust")

static func _generator(g: Variant) -> void:
    for side in [-1.0, 1.0]:
        g.rod("GeneratorWindingGuard",
            Vector3(side * 0.45, 1.60, 0.71),
            Vector3(side * 0.45, 0.66, 0.71), 0.09, "edge")
        g.poly("GeneratorRotorSeal", "bevel",
            Vector3(side * 0.63, 1.10, -0.34),
            Vector3(0.15, 1.22, 0.36), "gold")
        g.rod("GeneratorHighVoltageFeeder",
            Vector3(side * 0.87, 0.44, 0.68),
            Vector3(side * 1.09, 0.28, 1.01), 0.085, "rubber")
    for i in range(7):
        g.box("GeneratorCopperLoop",
            Vector3(-0.46 + i * 0.154, 1.17, 0.76),
            Vector3(0.080, 0.51, 0.06), "gold" if i % 3 == 0 else "blue_light")
    g.box("GeneratorControlReadout",
        Vector3(0.98, 1.48, 0.48),
        Vector3(0.38, 0.28, 0.08), "blue")

static func _storage(g: Variant) -> void:
    # Distinguish warehouse loading face from solid sealed containers.
    g.poly("CargoLoadingFrame", "bevel",
        Vector3(0.0, 0.53, 0.84),
        Vector3(2.12, 0.23, 0.32), "slate")
    for side in [-1.0, 1.0]:
        g.rod("CargoLoadingHandleBar",
            Vector3(side * 0.81, 0.46, 1.01),
            Vector3(side * 0.81, 1.39, 1.01),
            0.075, "gold")
        g.poly("CargoUnderRoofVent", "louver",
            Vector3(side * 0.63, 1.64, 0.31),
            Vector3(0.50, 0.27, 0.11), "trim")
    for index in range(4):
        g.box("CargoLoadingRampRib",
            Vector3(-0.73 + 0.46 * index, 0.29, 1.16),
            Vector3(0.11, 0.07, 0.35), "armor_light")

static func _terminal(g: Variant) -> void:
    # Illuminated worklight is above the display, not over the blueprint.
    g.poly("BlueprintWorkLightSconce", "hood",
        Vector3(0, 2.21, 0.19),
        Vector3(1.05, 0.19, 0.31), "armor")
    g.box("BlueprintWorkLightSource",
        Vector3(0, 2.10, 0.35),
        Vector3(0.78, 0.047, 0.045), "amber_light")
    for side in [-1.0, 1.0]:
        g.rod("BlueprintConsoleSideRiser",
            Vector3(side * 0.77, 0.44, 0.49),
            Vector3(side * 0.90, 1.78, 0.04),
            0.077, "edge")
    g.poly("BlueprintKeyboardTray", "bevel",
        Vector3(0, 0.97, 0.58),
        Vector3(1.45, 0.13, 0.45), "slate")
    for i in range(5):
        g.box("BlueprintKeyArray",
            Vector3(-0.54 + i * 0.27, 1.06, 0.67),
            Vector3(0.14, 0.032, 0.11), "blue" if i == 2 else "edge")

static func add_details(g: Variant, key: String) -> void:
    match key:
        "NEXUS": _nexus(g)
        "LABO": _labo(g)
        "SCRAP_COLLECTOR": _collector(g)
        "SMELTER": _smelter(g)
        "RECYCLER": _recycler(g)
        "GENERATOR": _generator(g)
        "STORAGE": _storage(g)
        "BUILD_TERMINAL": _terminal(g)
