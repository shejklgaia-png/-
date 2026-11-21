extends RefCounted
## Reference-image architectural finish. Every detail is fed into the existing
## per-material opaque MultiMesh Batch; no individual mesh or light per bolt.
## Local +Z is the working/entrance side, including rotated BASE facilities.
## Keep dimensions inside the original dedicated single-piece facility pads.

static func _nexus(g: Variant) -> void:
    # Layered roof battlements, welds, corner fixings and exposed services.
    g.poly("NexusRoofCornerBevel", "bevel",
        Vector3(-2.12, 4.91, -1.78),
        Vector3(0.92, 0.34, 0.68), "armor_light")
    for side in [-1.0, 1.0]:
        for row in range(4):
            var z: float = -1.76 + float(row) * 1.06
            g.box("NexusRoofParapetBraces",
                Vector3(side * 3.03, 4.61, z),
                Vector3(0.18, 0.31, 0.63), "armor_light")
            g.box("NexusRoofParapetRivets",
                Vector3(side * 3.135, 4.66, z),
                Vector3(0.045, 0.10, 0.10), "edge")
        g.rod("NexusRoofServiceConduit",
            Vector3(side * 2.60, 4.75, -2.10),
            Vector3(side * 2.60, 4.75, 1.55), 0.10, "rubber")
        g.box("NexusCornerFloodlight",
            Vector3(side * 2.92, 3.03, 2.74),
            Vector3(0.28, 0.17, 0.14), "amber_light")
        # Readable sidewall window cages and heavy surface bolts.
        for level in range(3):
            g.box("NexusArmorTie", Vector3(side * 3.08,
                0.90 + level * 0.98, 1.40),
                Vector3(0.08, 0.14, 0.71), "edge")
            for z in [-1.74, -0.75, 0.25, 1.30]:
                g.box("NexusWallFastener",
                    Vector3(side * 3.11, 1.01 + level * 0.98, z),
                    Vector3(0.06, 0.08, 0.085), "dark")
    for step in range(3):
        g.box("NexusEntranceThreshold",
            Vector3(0, 0.115 + step * 0.035, 3.13 + step * 0.21),
            Vector3(2.35 + step * 0.10, 0.09, 0.23), "slate")
    for rib in range(5):
        g.box("NexusThresholdSafetyStrip",
            Vector3(-1.02 + rib * 0.51, 0.25, 3.48),
            Vector3(0.11, 0.018, 0.26), "caution")
    # The asymmetric cloth awning is visibly supported, not floating.
    for beam in range(3):
        g.rod("NexusAwningCrossbrace",
            Vector3(-3.53 + beam * 0.52, 2.71, 2.25),
            Vector3(-3.41 + beam * 0.52, 2.93, 3.36),
            0.07, "trim")
    for unit in range(3):
        var x: float = -1.45 + float(unit) * 1.27
        g.box("NexusHVACHousing", Vector3(x, 5.05, -1.65),
            Vector3(0.82, 0.42, 0.71), "armor_light")
        for vent in range(4):
            g.box("NexusHVACGrille",
                Vector3(x - 0.28 + vent * 0.19, 5.279, -1.65),
                Vector3(0.06, 0.025, 0.48), "dark")

static func _labo(g: Variant) -> void:
    # Open equipment bays and an actual visible fabrication workhead.
    for side in [-1.0, 1.0]:
        g.rod("LabCanopyDiagonalTruss",
            Vector3(side * 1.86, 1.39, 1.88),
            Vector3(side * 1.86, 2.99, 0.58), 0.09, "edge")
        g.box("LabFrontWorkLampBracket",
            Vector3(side * 1.27, 2.48, 1.91),
            Vector3(0.43, 0.09, 0.09), "dark")
        g.box("LabFrontWorkLamp",
            Vector3(side * 1.27, 2.39, 1.97),
            Vector3(0.34, 0.065, 0.095), "amber_light")
    # Workshop's legacy secondary machine is BEHIND the foreground printer.
    g.rod("LabPrinterRail", Vector3(-1.11, 2.20, -1.10),
        Vector3(0.81, 2.20, -1.10), 0.085, "slate")
    g.box("LabPrinterCarrier", Vector3(-0.13, 2.08, -1.10),
        Vector3(0.46, 0.29, 0.36), "armor")
    g.rod("LabPrinterNozzle", Vector3(-0.13, 1.95, -1.10),
        Vector3(-0.13, 1.30, -1.10), 0.10, "gold")
    g.box("LabPrinterBuildPlate", Vector3(-0.13, 1.14, -1.07),
        Vector3(1.11, 0.11, 0.72), "slate")
    for row in range(3):
        g.box("LabFabricationRibs", Vector3(-0.55 + row * 0.42,
            1.21 + row * 0.10, 0.40),
            Vector3(0.18, 0.13, 0.45), "armor_light")
    for row in range(5):
        g.box("LabStorageBin", Vector3(-1.23 + float(row % 2) * 0.36,
            0.45 + float(row / 2) * 0.42, -0.93),
            Vector3(0.29, 0.28, 0.30),
            "rust" if row % 3 == 0 else "crate")
    g.box("LabMonitorBackplane", Vector3(0.97, 1.62, -1.33),
        Vector3(0.75, 0.66, 0.09), "void")
    for i in range(4):
        g.box("LabMonitorTelemetry", Vector3(0.87,
            1.44 + i * 0.12, -1.26),
            Vector3(0.42 - i * 0.055, 0.035, 0.04),
            "blue_light" if i % 2 else "blue")
    for row in range(4):
        g.box_tilt("LabCanopyStitchedFlap",
            Vector3(-1.42 + row * 0.91, 3.29, -0.97),
            Vector3(0.58, 0.036, 0.29), "cloth",
            Vector3(-0.11 - 0.015 * row, 0.0, 0.0))

static func _collector(g: Variant) -> void:
    # Multiple articulated pivots and hoses distinguish a real grapple crane.
    for joint in [Vector3(-0.76, 1.06, -0.30),
                  Vector3(-0.62, 2.25, -0.35),
                  Vector3(0.46, 2.12, 0.02)]:
        g.ring("CollectorHydraulicJoint", joint, 0.18, "trim", "z")
    g.rod("CollectorHydraulicHose",
        Vector3(-0.91, 0.77, -0.61),
        Vector3(-0.82, 1.77, -0.61), 0.08, "rubber")
    g.rod("CollectorHydraulicHose",
        Vector3(-0.82, 1.77, -0.61),
        Vector3(0.28, 2.30, -0.25), 0.08, "rubber")
    g.rod("CollectorRamChrome",
        Vector3(-0.60, 1.20, -0.19),
        Vector3(-0.05, 2.04, -0.05), 0.08, "white")
    for side in [-1.0, 1.0]:
        g.box("CollectorHopperWallArmor",
            Vector3(0.35 + side * 0.71, 0.92, 0.28),
            Vector3(0.14, 0.45, 1.40), "armor_light")
        for tooth in range(3):
            g.rod("CollectorGrappleTeeth",
                Vector3(0.46 + side * (0.17 + tooth * 0.05),
                    1.22, -0.10 + tooth * 0.14),
                Vector3(0.46 + side * (0.10 + tooth * 0.04),
                    0.97, -0.02 + tooth * 0.12), 0.065, "edge")
    for chip in range(9):
        g.box_tilt("CollectorLooseCuttings",
            Vector3(0.13 + (chip % 3) * 0.27,
                1.16 + (chip % 4) * 0.036,
                -0.19 + (chip / 3) * 0.23),
            Vector3(0.13 + (chip % 3) * 0.047, 0.065, 0.16),
            "rust" if chip % 2 else "edge",
            Vector3(0.12, chip * 0.37, -0.14))

static func _smelter(g: Variant) -> void:
    # Ceramic retainer arch, stepped chimney and staged molten metal trays.
    g.ring("FurnaceRetainerRing", Vector3(0, 1.04, 1.065),
        0.68, "gold", "z")
    for side in [-1.0, 1.0]:
        g.box("FurnaceBaffledIntake",
            Vector3(side * 0.89, 1.39, 0.95),
            Vector3(0.13, 1.17, 0.13), "rust")
        for bolt in range(4):
            g.box("FurnaceDoorRivets",
                Vector3(side * 0.72, 0.55 + bolt * 0.29, 1.11),
                Vector3(0.085, 0.085, 0.055), "edge")
        g.rod("FurnaceCoolingLine",
            Vector3(side * 0.97, 0.50, -0.56),
            Vector3(side * 1.06, 1.53, -0.72), 0.10, "gold")
    for level in range(3):
        g.ring("FurnaceStackBand",
            Vector3(-0.66, 2.05 + level * 0.33, -0.55),
            0.30, "edge")
    for grate in range(5):
        g.box("FurnaceUpperExhaustLouvers",
            Vector3(-0.47 + grate * 0.22, 1.94, 0.74),
            Vector3(0.13, 0.035, 0.19), "dark")
    g.box("FurnacePouringTrough", Vector3(0, 0.24, 1.22),
        Vector3(1.27, 0.12, 0.40), "rust")
    for i in range(3):
        g.box_tilt("FurnaceIngotCast", Vector3(-0.31 + i * 0.32,
            0.35, 1.31), Vector3(0.20, 0.10, 0.27),
            "gold", Vector3(0, 0.05 * i, -0.06))

static func _recycler(g: Variant) -> void:
    # Sloping feed hopper, reinforced drum ends and debris output.
    g.box_tilt("CrusherFeedRamp", Vector3(0.0, 1.46, -0.72),
        Vector3(1.74, 0.10, 0.79), "armor_light",
        Vector3(-0.31, 0.0, 0.0))
    for side in [-1.0, 1.0]:
        g.box_tilt("CrusherFeedGuard",
            Vector3(side * 0.86, 1.45, -0.73),
            Vector3(0.10, 0.42, 0.78), "edge",
            Vector3(-0.27, 0, 0))
        g.ring("CrusherDriveGear", Vector3(side * 1.08,
            1.04, -0.38), 0.32, "gold", "z")
        for rib in range(3):
            g.box("CrusherMotorHeatSink",
                Vector3(side * 1.19, 0.68 + rib * 0.19, -0.58),
                Vector3(0.06, 0.09, 0.36), "armor_light")
    for row in range(4):
        for cut in range(5):
            g.box_tilt("CrusherSerratedTeeth",
                Vector3(-0.59 + cut * 0.28, 1.22,
                    -0.38 + row * 0.24),
                Vector3(0.09, 0.16, 0.09), "dark",
                Vector3(0, 0, 0.28 if row % 2 else -0.28))
    for scrap in range(7):
        g.box_tilt("CrusherDischargeShards",
            Vector3(-0.57 + (scrap % 4) * 0.34,
                0.69 + (scrap % 3) * 0.04,
                1.15 + (scrap / 4) * 0.22),
            Vector3(0.21, 0.06, 0.13),
            "rust" if scrap % 3 == 0 else "edge",
            Vector3(0.04, scrap * 0.38, 0.12))

static func _generator(g: Variant) -> void:
    # Broad blue turbine: separate finned bearings, coil guards and power ducts.
    for side in [-1.0, 1.0]:
        for fin in range(6):
            var z: float = -0.47 + fin * 0.185
            g.box("GeneratorCoolingFins",
                Vector3(side * 0.78, 1.10, z),
                Vector3(0.09, 0.84, 0.085), "armor_light")
        g.rod("GeneratorCableFeed",
            Vector3(side * 0.77, 0.74, -0.35),
            Vector3(side * 1.06, 0.42, 0.64),
            0.10, "rubber")
        g.box("GeneratorBearingRetainer",
            Vector3(side * 0.54, 1.12, 0.69),
            Vector3(0.15, 1.03, 0.11), "trim")
    for coil in range(6):
        var x: float = -0.42 + coil * 0.175
        g.box("GeneratorLuminousWinding",
            Vector3(x, 1.17, 0.68),
            Vector3(0.095, 0.43, 0.055), "blue_light")
        g.box("GeneratorCoilClamp",
            Vector3(x, 1.42, 0.71),
            Vector3(0.12, 0.075, 0.12), "gold")
    for slot in range(5):
        g.box("GeneratorConverterVents",
            Vector3(1.17, 1.11 + slot * 0.22, -0.38),
            Vector3(0.05, 0.075, 0.57), "dark")
    g.box("GeneratorStatusPanel",
        Vector3(0.87, 1.78, 0.36),
        Vector3(0.31, 0.22, 0.09), "blue")

static func _storage(g: Variant) -> void:
    # Corrugated cargo faces, diagonal restraint straps and varied small loads.
    g.poly("CargoChamferedContainer", "bevel",
        Vector3(0.79, 0.49, 1.02),
        Vector3(0.75, 0.56, 0.51), "crate")
    for slot in range(3):
        var x: float = -0.73 + slot * 0.73
        for ridge in range(5):
            g.box("CargoCorrugatedDoors",
                Vector3(x - 0.22 + ridge * 0.11, 0.89, 0.225),
                Vector3(0.045, 0.99, 0.095),
                "armor_light" if ridge % 2 else "trim")
        g.box("CargoIdentificationPlate",
            Vector3(x, 1.16, 0.298),
            Vector3(0.27, 0.14, 0.04), "edge")
    for side in [-1.0, 1.0]:
        g.rod("CargoTieDownBraces",
            Vector3(side * 1.07, 0.23, 0.71),
            Vector3(side * 1.07, 1.81, -0.71), 0.09, "gold")
        g.box("CargoEdgeProtector",
            Vector3(side * 1.15, 1.60, 0.05),
            Vector3(0.10, 0.20, 1.77), "dark")
    g.crate(Vector3(-0.64, 0.35, 0.99),
        Vector3(0.43, 0.43, 0.47), 1)
    g.crate(Vector3(0.21, 0.38, 0.94),
        Vector3(0.65, 0.50, 0.42), 2)
    for swatch in range(4):
        g.box_tilt("CargoCanvasHems",
            Vector3(-0.77 + swatch * 0.49, 1.80, 0.62),
            Vector3(0.43, 0.045, 0.28), "cloth",
            Vector3(0.14, 0.0, -0.06 + swatch * 0.03))

static func _terminal(g: Variant) -> void:
    # A true three-dimensional wireframe crate on the physical blue monitor.
    g.poly("BlueprintAngledHood", "hood",
        Vector3(0, 2.19, -0.21),
        Vector3(1.83, 0.26, 0.52), "slate")
    for x in [-0.36, 0.32]:
        for y in [1.56, 1.92]:
            g.rod("BlueprintWireframeCrate", Vector3(x, y, 0.05),
                Vector3(x + 0.21, y + 0.11, 0.052),
                0.024, "blue_light")
    for y in [1.56, 1.92]:
        g.rod("BlueprintWireframeCrate", Vector3(-0.36, y, 0.05),
            Vector3(0.32, y, 0.05), 0.024, "blue_light")
        g.rod("BlueprintWireframeCrate", Vector3(-0.15, y + 0.11, 0.052),
            Vector3(0.53, y + 0.11, 0.052), 0.024, "blue_light")
    for x in [-0.36, 0.32, -0.15, 0.53]:
        var y_shift: float = 0.11 if x > 0.35 or is_equal_approx(x, -0.15) else 0.0
        g.rod("BlueprintWireframeCrate",
            Vector3(x, 1.56 + y_shift, 0.05),
            Vector3(x, 1.92 + y_shift, 0.05),
            0.024, "blue_light")
    for side in [-1.0, 1.0]:
        g.box("BlueprintSideVent",
            Vector3(side * 0.87, 1.61, -0.34),
            Vector3(0.08, 0.57, 0.30), "dark")
        for row in range(3):
            g.box("BlueprintPanelFasteners",
                Vector3(side * 0.78, 1.34 + row * 0.30, -0.11),
                Vector3(0.085, 0.06, 0.04), "edge")
    g.box_tilt("BlueprintTerminalGlareHood",
        Vector3(0, 2.21, 0.05),
        Vector3(1.78, 0.12, 0.48), "slate",
        Vector3(-0.16, 0.0, 0.0))
    g.box("BlueprintConnectorSocket",
        Vector3(-0.67, 0.88, 0.31),
        Vector3(0.32, 0.25, 0.19), "gold")
    g.rod("BlueprintGroundCable",
        Vector3(-0.76, 0.79, 0.36),
        Vector3(-1.04, 0.32, 0.70), 0.10, "rubber")

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
