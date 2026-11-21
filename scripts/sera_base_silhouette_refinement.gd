extends RefCounted
## Large-scale readability pass for the reference-image SERA industrial yard.
## A roof / louver is a single directly authored polygonal ArrayMesh reused by
## the existing material MultiMesh. No lights, colliders, scene nodes or updates.

static func _nexus(g: Variant) -> void:
    # Distinctive heavy pitched shelter over the recessed gate. It projects
    # beyond the main armor, so the entrance silhouette reads from above.
    g.poly("NexusGabledEntranceShelter", "roof",
        Vector3(0, 3.19, 2.82), Vector3(3.05, 0.52, 1.13), "slate")
    g.poly("NexusAwningUnderplate", "bevel",
        Vector3(0, 2.91, 2.97), Vector3(2.82, 0.10, 1.18), "dark")
    for side in [-1.0, 1.0]:
        g.rod("NexusGabledShelterBrace",
            Vector3(side * 1.37, 2.82, 3.26),
            Vector3(side * 1.13, 3.23, 2.48), 0.083, "edge")
        g.poly_tilt("NexusSideServiceLouver", "louver",
            Vector3(side * 3.16, 2.65, 0.80),
            Vector3(0.12, 0.76, 0.73), "trim",
            Vector3(0, side * PI * 0.5, 0))
        g.poly("NexusRoofServiceCowl", "roof",
            Vector3(side * 1.86, 5.27, -1.11),
            Vector3(1.16, 0.42, 1.10), "armor_light")
        for i in range(4):
            g.box("NexusServiceCowlComb",
                Vector3(side * 1.86, 5.13, -1.47 + i * 0.24),
                Vector3(0.72, 0.035, 0.060), "dark")
    for n in range(4):
        var x: float = -1.86 + float(n) * 1.24
        g.poly("NexusVentRecess", "louver",
            Vector3(x, 4.88, 1.78),
            Vector3(0.66, 0.29, 0.15), "trim")
        g.rod("NexusRoofTieBar",
            Vector3(x, 4.79, 1.32),
            Vector3(x, 4.85, 1.90), 0.035, "gold")
    for idx in range(3):
        g.poly("NexusDoorKickplate", "bevel",
            Vector3(0, 0.58 + float(idx) * 0.48, 2.864),
            Vector3(1.72, 0.37, 0.075), "armor" if idx != 1 else "slate")

static func _labo(g: Variant) -> void:
    # Front-facing structural eave and cloth tension cables; keep the
    # workshop open and the existing sagging cloth panels fully visible.
    g.poly("LabFabricCanopyRail", "roof",
        Vector3(0, 3.18, 1.03),
        Vector3(3.96, 0.32, 0.58), "cloth")
    for i in range(5):
        var x: float = -1.55 + float(i) * 0.78
        g.rod("LabCanopyTensionCable",
            Vector3(x, 3.30, 0.87), Vector3(x * 0.96, 3.32, -1.82),
            0.025, "dark")
    for side in [-1.0, 1.0]:
        g.poly_tilt("LabWorkshopCoolingShutter", "louver",
            Vector3(side * 1.86, 1.68, -0.89),
            Vector3(0.15, 0.86, 0.72), "edge",
            Vector3(0, side * PI * 0.5, 0))
        g.rod("LabEntryCrossbrace",
            Vector3(side * 1.92, 1.42, 1.91),
            Vector3(side * 1.92, 2.92, 1.14),
            0.058, "gold")
    for i in range(3):
        g.poly("LabSideEquipmentHood", "hood",
            Vector3(-1.12 + float(i) * 0.82, 2.22, -1.47),
            Vector3(0.63, 0.37, 0.44), "armor")

static func _collector(g: Variant) -> void:
    g.poly("CollectorOpenGearHousing", "louver",
        Vector3(-0.82, 0.88, 0.13),
        Vector3(0.54, 0.60, 0.20), "edge")
    g.poly("CollectorCranePivotCover", "hood",
        Vector3(-0.71, 1.99, -0.37),
        Vector3(0.60, 0.38, 0.53), "gold")
    # Twin parallel hydraulic rails give the angled boom real thickness.
    for offset in [-0.12, 0.12]:
        g.rod("CollectorTwinBoomRail",
            Vector3(-0.76 + offset, 1.20, -0.51),
            Vector3(-0.60 + offset, 2.29, -0.55), 0.080, "armor_light")
        g.rod("CollectorTwinBoomRail",
            Vector3(-0.60 + offset, 2.29, -0.55),
            Vector3(0.46 + offset, 2.17, -0.10), 0.065, "armor_light")
    g.poly("CollectorSortingLip", "hood",
        Vector3(0.35, 1.10, 0.83),
        Vector3(1.40, 0.25, 0.30), "rust")
    for i in range(4):
        g.box_tilt("CollectorTumbledChips",
            Vector3(0.02 + float(i) * 0.21, 1.02 + float(i % 2) * 0.07, 0.27),
            Vector3(0.11, 0.08, 0.22),
            "edge" if i % 2 else "rust",
            Vector3(0.10, float(i) * 0.57, -0.11))

static func _smelter(g: Variant) -> void:
    # The hot exhaust throat remains exposed; the cowling is on the OTHER
    # half of the furnace and has visible side profile from the camera.
    g.poly("FurnaceExhaustCowling", "roof",
        Vector3(0.51, 2.15, -0.11),
        Vector3(1.20, 0.38, 1.29), "slate")
    g.poly_tilt("FurnaceBaffledInletLouver", "louver",
        Vector3(1.15, 1.33, 0.21),
        Vector3(0.12, 0.69, 0.55), "rust",
        Vector3(0, PI * 0.5, 0))
    for side in [-1.0, 1.0]:
        g.poly("FurnaceMouthSideGuard", "hood",
            Vector3(side * 0.70, 1.11, 1.01),
            Vector3(0.30, 1.29, 0.19), "trim")
        g.rod("FurnaceStackFeed",
            Vector3(side * 0.83, 0.59, -0.47),
            Vector3(side * 0.86, 1.87, -0.47), 0.065, "gold")
    for i in range(4):
        g.box("FurnaceCastSurfaceShine",
            Vector3(-0.45 + float(i) * 0.29, 0.25, 1.38),
            Vector3(0.15, 0.028, 0.052), "caution")

static func _recycler(g: Variant) -> void:
    # The drive case is openly louvered rather than another solid block.
    g.poly("CrusherLouveredDriveCase", "louver",
        Vector3(1.13, 1.13, 0.46),
        Vector3(0.64, 0.83, 0.23), "armor_light")
    g.poly("CrusherAngledIntakeLid", "roof",
        Vector3(0, 1.70, -0.74),
        Vector3(1.78, 0.38, 0.52), "slate")
    for side in [-1.0, 1.0]:
        g.rod("CrusherHopperFrameCrossbar",
            Vector3(side * 0.92, 1.18, -0.93),
            Vector3(side * 0.86, 1.74, -0.54), 0.08, "edge")
        g.poly("CrusherHydraulicShield", "hood",
            Vector3(side * 0.97, 0.85, -0.47),
            Vector3(0.43, 0.49, 0.55), "trim")
    for i in range(5):
        g.box("CrusherFeedNicks",
            Vector3(-0.63 + i * 0.31, 1.58, -0.67),
            Vector3(0.055, 0.06, 0.30), "gold" if i % 2 else "dark")

static func _generator(g: Variant) -> void:
    g.poly_tilt("GeneratorFinnedVentFace", "louver",
        Vector3(1.18, 1.25, -0.31),
        Vector3(0.15, 0.94, 0.79), "edge",
        Vector3(0, PI * 0.5, 0))
    g.poly("GeneratorCableBridge", "hood",
        Vector3(0, 1.82, -0.38), Vector3(1.18, 0.32, 0.53), "slate")
    for side in [-1.0, 1.0]:
        g.poly("GeneratorRotorBracket", "hood",
            Vector3(side * 0.59, 1.10, 0.62),
            Vector3(0.29, 0.80, 0.19), "armor_light")
        g.rod("GeneratorSpacedSupport",
            Vector3(side * 0.87, 0.45, 0.70),
            Vector3(side * 0.82, 1.28, 0.70),
            0.064, "gold")
    for index in range(4):
        var x: float = -0.34 + index * 0.22
        g.box("GeneratorCopperClamp",
            Vector3(x, 1.48, 0.63), Vector3(0.09, 0.08, 0.22), "gold")

static func _storage(g: Variant) -> void:
    # One pitched cover floats over six distinctly stacked cargo bodies.
    g.poly("CargoShelterRoof", "roof",
        Vector3(0, 1.96, -0.31),
        Vector3(2.46, 0.43, 1.96), "cloth")
    for side in [-1.0, 1.0]:
        g.rod("CargoShelterAFrame",
            Vector3(side * 1.11, 0.22, 0.73),
            Vector3(side * 1.11, 1.77, 0.73), 0.078, "trim")
        g.rod("CargoRoofDiagonal",
            Vector3(side * 1.11, 1.72, -0.85),
            Vector3(0, 2.19, -0.85), 0.042, "gold")
    for i in range(3):
        var x: float = -0.73 + float(i) * 0.72
        g.box("CargoRoofPanelStitch",
            Vector3(x, 2.20, -0.31), Vector3(0.045, 0.023, 1.52), "trim")
        g.poly("CargoAccessHood", "hood",
            Vector3(x, 1.12, 0.31), Vector3(0.55, 0.51, 0.18), "armor")

static func _terminal(g: Variant) -> void:
    g.poly("BlueprintShelteredMonitor", "roof",
        Vector3(0, 2.24, -0.27),
        Vector3(1.98, 0.32, 0.58), "armor")
    for side in [-1.0, 1.0]:
        g.poly_tilt("BlueprintCoolingDoor", "louver",
            Vector3(side * 0.91, 1.45, -0.26),
            Vector3(0.12, 0.61, 0.32), "trim",
            Vector3(0, side * PI * 0.5, 0))
        g.rod("BlueprintMonitorBezelBrace",
            Vector3(side * 0.78, 0.97, 0.42),
            Vector3(side * 0.93, 1.72, 0.02), 0.05, "gold")
    for slot in range(5):
        g.box("BlueprintDeckIndicator",
            Vector3(-0.47 + slot * 0.24, 1.145, 0.59),
            Vector3(0.14, 0.025, 0.075),
            "blue_light" if slot == 2 else "edge")

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
