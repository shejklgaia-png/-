extends RefCounted
## A distinct roof language for each BASE activity, not eight instances of
## the same symmetric gable. All pieces enter the existing opaque MultiMesh.
## Local +Z is the entrance; leave foundation, yaw, lights and hit areas intact.
##
## NEXUS: stepped blastproof parapet / LABO: asymmetric fabric sail
## COLLECTOR: open crane gantry / SMELTER: exhaust heat baffles
## RECYCLER: split hinged jaw / GENERATOR: exposed turbine roll cage
## STORAGE: offset steel cargo lids / TERMINAL: cantilevered data canopy.

static func _nexus(g: Variant) -> void:
    # Layered horizontal armored deck, never a second pitched hall.
    g.poly("NexusSteppedRoofCrown", "bevel",
        Vector3(-0.38, 4.99, -0.17),
        Vector3(2.46, 0.35, 2.13), "slate")
    g.box("NexusRoofCommandSpine", Vector3(-0.38, 5.23, -0.16),
        Vector3(2.08, 0.14, 0.27), "edge")
    for side in [-1.0, 1.0]:
        # Asymmetric height, but no increase in the permitted footprint.
        var y: float = 4.90 if side < 0.0 else 4.76
        g.box("NexusRoofParapet", Vector3(side * 2.82, y, 0.38),
            Vector3(0.20, 0.52 if side < 0.0 else 0.33, 2.70),
            "armor_light")
        g.box("NexusRoofAccessSteps",
            Vector3(side * 2.33, 4.81, 1.57),
            Vector3(0.68, 0.15, 0.46), "trim")
    for i in range(4):
        g.box("NexusCommandDeckCoolingSlots",
            Vector3(-1.28 + float(i) * 0.57, 5.19, -0.23),
            Vector3(0.12, 0.045, 1.15), "dark")


static func _labo(g: Variant) -> void:
    # The extra textile is a pulled-up side flap, not another symmetric pitch.
    g.poly_tilt("LabAsymmetricSailFlap", "canvas",
        Vector3(1.45, 3.90, 0.30),
        Vector3(1.46, 0.18, 3.24), "cloth",
        Vector3(-0.08, 0, -0.38))
    g.rod("LabTarpRidgeHoop",
        Vector3(-1.96, 3.37, 1.44),
        Vector3(0.03, 4.23, 1.44), 0.11, "armor_light")
    g.rod("LabTarpRidgeHoop",
        Vector3(0.03, 4.23, 1.44),
        Vector3(2.14, 3.37, 1.44), 0.11, "armor_light")
    g.rod("LabTarpRidgeTie",
        Vector3(0.03, 4.23, -1.73),
        Vector3(0.03, 4.23, 1.44), 0.08, "edge")
    for i in range(4):
        var z: float = -1.42 + float(i) * 0.79
        g.box_tilt("LabSailFabricSeam",
            Vector3(1.48, 3.98, z), Vector3(1.37, 0.035, 0.06),
            "rust", Vector3(-0.08, 0, -0.38))
    g.rod("LabOpenEaveTensionCord",
        Vector3(2.15, 3.51, 1.56),
        Vector3(2.01, 0.30, 1.75), 0.055, "gold")


static func _collector(g: Variant) -> void:
    # Open-sided transverse maintenance walkway: no solid roof over the claw.
    g.box("CollectorOpenGantryDeck",
        Vector3(-0.07, 3.02, -1.06),
        Vector3(2.35, 0.17, 0.40), "rust")
    for side in [-1.0, 1.0]:
        g.rod("CollectorGantryLeg",
            Vector3(side * 1.09, 0.28, -1.03),
            Vector3(side * 1.09, 2.98, -1.03), 0.10, "edge")
        g.rod("CollectorGantryDiagonalBrace",
            Vector3(side * 1.09, 1.68, -1.03),
            Vector3(side * 0.58, 2.99, -1.03), 0.065, "gold")
        g.rod("CollectorGantryVoidRail",
            Vector3(side * 1.05, 3.33, -1.30),
            Vector3(side * 0.05, 3.33, -1.30), 0.072, "armor_light")
    for i in range(4):
        var x: float = -0.88 + float(i) * 0.57
        g.box("CollectorOpenDeckGrate",
            Vector3(x, 3.14, -1.06), Vector3(0.085, 0.035, 0.36), "dark")
    g.rod("CollectorWarningBeaconPost",
        Vector3(-1.10, 3.09, -1.18),
        Vector3(-1.10, 3.59, -1.18), 0.075, "edge")


static func _smelter(g: Variant) -> void:
    # One isolated heat hood opposite the two tall open exhaust pipes.
    for i in range(5):
        var z: float = -0.65 + float(i) * 0.31
        g.box_tilt("SmelterHeatDissipationFin",
            Vector3(0.49, 2.57, z),
            Vector3(0.98, 0.31, 0.085),
            "rust" if i % 2 == 0 else "armor_light",
            Vector3(0, 0, -0.17))
    g.poly("SmelterStackCanopy", "bevel",
        Vector3(-0.66, 4.38, -0.55),
        Vector3(0.94, 0.17, 0.82), "slate")
    for side in [-1.0, 1.0]:
        g.rod("SmelterStackCapStandoff",
            Vector3(-0.66 + side * 0.33, 4.10, -0.55),
            Vector3(-0.66 + side * 0.33, 4.29, -0.55), 0.055, "gold")
        g.box("SmelterFurnaceRoofThermalBridge",
            Vector3(side * 0.92, 2.20, 0.47),
            Vector3(0.10, 0.13, 0.74), "edge")


static func _recycler(g: Variant) -> void:
    # Split retractable V-wing steel covers reveal the roller throat.
    for side in [-1.0, 1.0]:
        g.box_tilt("RecyclerSplitJawRoof",
            Vector3(side * 0.68, 2.66, -0.57),
            Vector3(1.10, 0.13, 1.17),
            "armor_light" if side < 0.0 else "rust",
            Vector3(0.18, 0, side * 0.35))
        g.rod("RecyclerWingHinge",
            Vector3(side * 1.02, 2.24, -1.06),
            Vector3(side * 1.02, 2.67, 0.00), 0.09, "edge")
        g.box("RecyclerRaisedGapTeeth",
            Vector3(side * 0.22, 2.83, -0.22),
            Vector3(0.08, 0.24, 0.38), "caution")
    for i in range(4):
        g.box("RecyclerHopperVentSlot",
            Vector3(-0.67 + float(i) * 0.44, 2.28, -1.14),
            Vector3(0.21, 0.055, 0.11), "dark")


static func _generator(g: Variant) -> void:
    # Exposed turbine arc is a roll-cage, not a sheeted pitched roof.
    for i in range(4):
        var z: float = -0.87 + float(i) * 0.53
        g.rod("GeneratorTurbineArchRib",
            Vector3(-1.07, 1.94, z), Vector3(-0.72, 2.71, z),
            0.105, "armor_light")
        g.rod("GeneratorTurbineArchRib",
            Vector3(-0.72, 2.71, z), Vector3(0.05, 3.00, z),
            0.105, "armor_light")
        g.rod("GeneratorTurbineArchRib",
            Vector3(0.05, 3.00, z), Vector3(0.81, 2.64, z),
            0.105, "armor_light")
        g.rod("GeneratorTurbineArchRib",
            Vector3(0.81, 2.64, z), Vector3(1.12, 1.96, z),
            0.105, "armor_light")
    g.rod("GeneratorSpineRail",
        Vector3(0.05, 3.02, -0.89),
        Vector3(0.05, 3.02, 0.75), 0.13, "gold")
    for i in range(3):
        g.box("GeneratorBlueArcPowerTab",
            Vector3(0.05, 3.10, -0.55 + float(i) * 0.55),
            Vector3(0.25, 0.09, 0.22), "blue_light")


static func _storage(g: Variant) -> void:
    # Uneven overlapping shipping-container lids: hard metal, unlike LABO.
    for i in range(3):
        var x: float = -0.69 + float(i) * 0.71
        var lift: float = 0.18 if i == 1 else 0.0
        g.box_tilt("StorageSteppedSteelLid",
            Vector3(x, 2.92 + lift, -0.29),
            Vector3(0.89, 0.15, 2.40),
            "armor_light" if i == 1 else "slate",
            Vector3(-0.08, 0, 0.045 * float(i-1)))
        g.box("StorageRoofWaterChannel",
            Vector3(x + 0.33, 3.03 + lift, -0.29),
            Vector3(0.055, 0.08, 2.25), "dark")
    g.poly("StorageRaisedCargoHatch", "bevel",
        Vector3(-0.58, 3.29, -0.66),
        Vector3(0.64, 0.26, 0.61), "rust")
    for side in [-1.0, 1.0]:
        g.rod("StorageLoadingHoistAnchor",
            Vector3(side * 1.09, 2.55, 0.93),
            Vector3(side * 1.09, 3.00, 0.93), 0.105, "gold")


static func _terminal(g: Variant) -> void:
    # One forward-projecting solar/data blade on offset steel arms.
    g.box_tilt("TerminalCantileverRoofBlade",
        Vector3(-0.15, 3.29, 0.36),
        Vector3(2.28, 0.15, 1.46),
        "slate", Vector3(-0.19, 0, 0.08))
    g.box_tilt("TerminalCantileverSolarSurface",
        Vector3(-0.15, 3.40, 0.30),
        Vector3(1.86, 0.045, 1.06),
        "blue", Vector3(-0.19, 0, 0.08))
    for side in [-1.0, 1.0]:
        g.rod("TerminalSuspendedRoofBrace",
            Vector3(side * 0.80, 2.38, -0.77),
            Vector3(side * 0.80, 3.25, 0.34), 0.115, "gold")
        g.box("TerminalCanopyEdgeCap",
            Vector3(side * 1.08, 3.34, 0.34),
            Vector3(0.12, 0.20, 1.46), "edge")
    for i in range(4):
        g.box_tilt("TerminalSolarLine",
            Vector3(-0.85 + float(i) * 0.46, 3.43, 0.30),
            Vector3(0.035, 0.022, 0.96), "blue_light",
            Vector3(-0.19, 0, 0.08))


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
