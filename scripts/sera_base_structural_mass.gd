extends RefCounted
## Structural silhouettes for all eight BASE buildings. Sculpt actual pitched
## panels, beams, ribs, stacks and service hatches in the existing opaque
## material MultiMesh Batch. Do NOT add lights, draw nodes or physics bodies.
## Local +Z is the visible entrance; keep foundations / tap areas untouched.

static func _nexus(g: Variant) -> void:
    # A restrained upgrade: no change to the NEXUS's 1.14x footprint or height.
    for side in [-1.0, 1.0]:
        g.poly_tilt("NexusCornerButtress", "bevel",
            Vector3(side * 2.72, 2.38, 2.50),
            Vector3(0.43, 3.00, 0.54), "slate",
            Vector3(0, 0, side * 0.08))
        g.box("NexusButtressCap", Vector3(side * 2.72, 3.93, 2.53),
            Vector3(0.51, 0.21, 0.65), "armor_light")
        g.rod("NexusReinforcementTie",
            Vector3(side * 2.81, 1.03, 2.74),
            Vector3(side * 2.51, 3.75, 2.74),
            0.10, "edge")
    g.box_tilt("NexusRoofGutter", Vector3(0, 4.68, 2.57),
        Vector3(5.70, 0.17, 0.24), "armor_light",
        Vector3(0.25, 0, 0))
    for i in range(6):
        g.box("NexusGutterRivet",
            Vector3(-2.36 + float(i) * 0.94, 4.70, 2.75),
            Vector3(0.11, 0.11, 0.07), "dark")


static func _labo(g: Variant) -> void:
    # The front of the workshop remains open. A pair of real pitched canvas
    # roof slopes meets at a raised steel ridge; not an enlarged box.
    for side in [-1.0, 1.0]:
        g.poly_tilt("LabAngledSideRoof", "canvas",
            Vector3(side * 1.81, 3.45, -1.06),
            Vector3(0.18, 0.12, 1.32), "cloth",
            Vector3(-0.05, 0.0, -side * 0.08))
        g.rod("LabAFrameTruss",
            Vector3(0.0, 3.80, -0.12),
            Vector3(side * 2.05, 3.38, -0.12), 0.13, "armor_light")
        g.rod("LabAFrameTruss",
            Vector3(0.0, 3.80, -1.72),
            Vector3(side * 2.05, 3.39, -1.72), 0.11, "edge")
        g.box_tilt("LabSideRainFlashing",
            Vector3(side * 1.93, 3.34, -1.00),
            Vector3(0.13, 0.10, 1.30), "armor_light",
            Vector3(0, 0, side * 0.11))
    g.rod("LabAFrameRidge",
        Vector3(0, 3.83, -1.82), Vector3(0, 3.83, -0.08),
        0.16, "edge")
    # A distinct recessed roll-up work bay on the front right, away from the
    # wide central opening and the service door on the opposite side.
    g.poly("LabRollUpServiceBay", "bevel",
        Vector3(1.69, 1.37, 1.77), Vector3(0.55, 2.04, 0.20), "trim")
    for row in range(6):
        g.box("LabRollUpServiceSlat",
            Vector3(1.69, 0.58 + float(row) * 0.27, 1.91),
            Vector3(0.43, 0.14, 0.05), "armor_light" if row % 2 else "slate")
    g.box("LabRollUpMotor",
        Vector3(1.69, 2.49, 1.83), Vector3(0.71, 0.27, 0.30), "rust")
    g.box("LabRollUpWarningLight",
        Vector3(1.45, 2.49, 2.01), Vector3(0.14, 0.09, 0.08), "amber_light")
    g.rod("LabSuspendedToolRail", Vector3(-1.15, 2.58, 0.72),
        Vector3(1.25, 2.58, 0.72), 0.08, "gold")


static func _collector(g: Variant) -> void:
    # Distinct counterweight mass balances the tall cantilevered claw.
    g.poly("CollectorCraneCounterweight", "bevel",
        Vector3(-1.03, 1.51, -0.82),
        Vector3(0.67, 0.92, 0.73), "rust")
    g.box("CollectorCounterweightPlate",
        Vector3(-1.03, 1.62, -0.42),
        Vector3(0.53, 0.56, 0.075), "armor_light")
    for side in [-1.0, 1.0]:
        g.rod("CollectorDiagonalArmBrace",
            Vector3(-0.97, 1.48, -0.73 + side * 0.18),
            Vector3(-0.45, 2.26, -0.32 + side * 0.18),
            0.11, "edge")
        g.poly_tilt("CollectorSortingRoofFin", "roof",
            Vector3(side * 1.03, 2.45, -0.88),
            Vector3(0.25, 0.17, 0.64),
            "slate" if side < 0.0 else "armor_light",
            Vector3(0.07, 0, -side * 0.17))
    g.ring("CollectorClawPivotFlange",
        Vector3(-0.48, 2.27, -0.34), 0.22, "gold", "z")


static func _smelter(g: Variant) -> void:
    # Two chimneys of unequal height make the thermal machine recognizable.
    g.rod("SmelterSecondaryExhaust",
        Vector3(0.66, 2.06, -0.62),
        Vector3(0.66, 3.48, -0.62), 0.37, "rust")
    for y in [2.33, 3.30]:
        g.ring("SmelterSecondaryPipeCollar",
            Vector3(0.66, y, -0.62), 0.23, "edge")
    g.poly("SmelterSecondaryRainCap", "roof",
        Vector3(0.66, 3.60, -0.62),
        Vector3(0.61, 0.20, 0.57), "armor_light")
    for side in [-1.0, 1.0]:
        g.poly_tilt("SmelterWindBaffle", "hood",
            Vector3(side * 0.90, 1.94, 0.13),
            Vector3(0.47, 0.80, 1.07), "armor",
            Vector3(0.13, 0, side * 0.19))
    g.box("SmelterDoubleStackManifold",
        Vector3(0, 2.27, -0.55),
        Vector3(1.67, 0.19, 0.21), "gold")
    for row in range(4):
        g.box("SmelterFurnaceCheekRib",
            Vector3(-0.82 + float(row) * 0.55, 0.52, 0.97),
            Vector3(0.11, 0.60, 0.14), "trim")


static func _recycler(g: Variant) -> void:
    # Exposed opposing jaws read immediately as a crusher, even from low
    # oblique angles. Their edges are V-shaped, rather than square housings.
    for side in [-1.0, 1.0]:
        g.poly_tilt("RecyclerSplayedArmorJaw", "bevel",
            Vector3(side * 0.77, 1.13, 0.78),
            Vector3(0.29, 1.14, 0.95),
            "armor_light", Vector3(0.0, 0.0, -side * 0.24))
        g.rod("RecyclerJawHydraulicPiston",
            Vector3(side * 1.12, 0.57, -0.51),
            Vector3(side * 0.84, 1.64, 0.29), 0.17, "rust")
        g.box("RecyclerJawHingeBlock",
            Vector3(side * 1.11, 0.73, -0.56),
            Vector3(0.30, 0.40, 0.45), "trim")
    g.poly_tilt("RecyclerCantedCowl", "roof",
        Vector3(0, 2.05, -1.01),
        Vector3(0.86, 0.16, 0.36), "armor_light",
        Vector3(0.18, 0.0, -0.04))
    g.box("RecyclerHopperLip",
        Vector3(0, 0.60, 1.38), Vector3(1.72, 0.18, 0.18), "edge")
    for tooth in range(5):
        g.poly("RecyclerDischargeTeeth", "gear",
            Vector3(-0.59 + float(tooth) * 0.29, 0.69, 1.47),
            Vector3(0.18, 0.26, 0.18), "slate")


static func _generator(g: Variant) -> void:
    # A separate visible drum and strong curved tube guards distinguish the
    # energy station from the recycler's horizontal steel housing.
    g.poly_tilt("GeneratorExternalCoolingDrum", "drum",
        Vector3(-0.77, 1.67, -0.54), Vector3(0.52, 0.72, 0.54),
        "slate", Vector3(0, 0, PI * 0.5))
    for i in range(4):
        g.ring("GeneratorCoolingDrumRim",
            Vector3(-0.77, 1.65 + float(i) * 0.12, -0.54),
            0.28, "edge")
    for side in [-1.0, 1.0]:
        g.poly_tilt("GeneratorRibbedTurbineGuard", "hood",
            Vector3(side * 0.54, 2.24, 0.32),
            Vector3(1.05, 0.52, 0.77), "armor",
            Vector3(0.16, 0, -side * 0.15))
        g.rod("GeneratorPowerCableArch",
            Vector3(side * 1.02, 0.45, -0.74),
            Vector3(side * 0.76, 1.75, -0.83), 0.12, "rubber")
    for i in range(5):
        g.box("GeneratorCowlCoolingSlits",
            Vector3(-0.72 + float(i) * 0.36, 2.53, 0.67),
            Vector3(0.08, 0.07, 0.23), "dark")


static func _storage(g: Variant) -> void:
    # Visible raised aperture, short real roof pitches and tensioned posts,
    # without placing a large opaque cube over the stored containers.
    for side in [-1.0, 1.0]:
        g.rod("StorageRaisedLoadingFrame",
            Vector3(side * 1.20, 0.20, 1.05),
            Vector3(side * 1.20, 2.51, 1.05), 0.12, "armor_light")
        g.rod("StorageDiagonalPost",
            Vector3(side * 1.20, 0.65, 1.03),
            Vector3(side * 0.85, 2.33, 0.92), 0.09, "gold")
        g.poly_tilt("StorageTarpSaddle", "canvas",
            Vector3(side * 0.78, 2.40, -1.04),
            Vector3(0.27, 0.18, 0.57), "cloth",
            Vector3(0.0, 0.0, -side * 0.18))
    g.rod("StorageRoofSpine",
        Vector3(0, 2.89, -1.35),
        Vector3(0, 2.89, -0.61), 0.13, "edge")
    g.box("StorageFrontLoadingBeam",
        Vector3(0, 2.48, 1.07),
        Vector3(2.50, 0.19, 0.25), "slate")
    for i in range(3):
        g.box("StorageHoistRoller",
            Vector3(-0.62 + float(i) * 0.62, 2.49, 1.22),
            Vector3(0.30, 0.20, 0.17), "gold")


static func _terminal(g: Variant) -> void:
    # Two uneven roof wings and an identifiable side utility compartment,
    # leaving the central blueprint display unobstructed.
    for side in [-1.0, 1.0]:
        g.poly_tilt("TerminalSlopedRoofWing", "roof",
            Vector3(side * 0.76, 2.60, -0.91),
            Vector3(0.27, 0.17, 0.43),
            "slate" if side < 0 else "armor_light",
            Vector3(-0.06, 0.0, -side * 0.23))
        g.rod("TerminalRoofOuterBrace",
            Vector3(side * 0.94, 1.96, -0.94),
            Vector3(side * 1.11, 2.86, 0.12), 0.085, "gold")
    g.poly("TerminalToolHatch", "bevel",
        Vector3(-0.99, 1.16, 0.49),
        Vector3(0.37, 0.99, 0.44), "armor")
    g.box("TerminalToolHatchHandle",
        Vector3(-1.02, 1.07, 0.76),
        Vector3(0.10, 0.19, 0.06), "gold")
    g.rod("TerminalProfileAntenna",
        Vector3(0.92, 2.77, -0.78),
        Vector3(0.92, 3.55, -0.78), 0.065, "edge")
    g.box("TerminalAntennaBeacon",
        Vector3(0.92, 3.56, -0.78),
        Vector3(0.18, 0.17, 0.19), "blue_light")


static func add_details(g: Variant, key: String) -> void:
    match key:
        "NEXUS":
            _nexus(g)
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
            _terminal(g)
