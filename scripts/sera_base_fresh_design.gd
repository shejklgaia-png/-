extends RefCounted
## SERA BASE FRESH_20261122 — all eight machine/building designs newly authored.
## No legacy facility part generator is called. Geometry belongs to the
## existing single opaque batched renderer; all dimensions are local meters.
## The active camera sees the working front on +Z from ~27 degrees above.
## Old models remain intact on archive/base-models-20261122-before-rebuild.

static func _pad(g: Variant, width: float, depth: float) -> void:
    g.poly("FreshFoundation", "bevel",
        Vector3(0.0, 0.26, 0.0),
        Vector3(width, 0.33, depth), "dark")
    g.box("FreshFoundationRim",
        Vector3(0.0, 0.40, depth * 0.48),
        Vector3(width * 0.88, 0.10, 0.10), "gold")
    for side in [-1.0, 1.0]:
        g.box("FreshFoundationSideBeam",
            Vector3(side * width * 0.48, 0.39, 0.0),
            Vector3(0.13, 0.17, depth * 0.89), "trim")
        for end in [-1.0, 1.0]:
            g.box("FreshFootAnchor",
                Vector3(side * width * 0.40, 0.41, end * depth * 0.38),
                Vector3(0.22, 0.09, 0.21), "edge")


static func _nexus(g: Variant) -> void:
    # Command bunker: broad, low chamfered armored body rather than an
    # accumulation of roofs. Split rear crown and unmistakable luminous gate.
    _pad(g, 5.90, 5.05)
    g.poly("FreshNexusCommandHull", "bevel",
        Vector3(0, 1.92, -0.34), Vector3(5.30, 2.96, 3.82), "slate")
    g.poly("FreshNexusUpperDeck", "bevel",
        Vector3(0, 3.43, -0.55), Vector3(5.63, 0.43, 4.24), "armor")
    g.box("FreshNexusRoofShadow",
        Vector3(0.0, 3.66, 0.09), Vector3(3.10, 0.08, 1.70), "dark")
    # Paired directional roofs are set apart by a gap revealing the
    # original roof deck: readable from fixed 27-degree oblique viewpoint.
    for side in [-1.0, 1.0]:
        g.poly_tilt("FreshNexusSplitCrown", "roof",
            Vector3(side * 1.53, 4.03, -0.95),
            Vector3(2.39, 0.29, 3.10), "armor_light",
            Vector3(-0.10, 0, side * -0.18))
        g.box("FreshNexusCrownRim",
            Vector3(side * 1.55, 4.14, 0.62),
            Vector3(2.22, 0.14, 0.15), "gold")
        g.box("FreshNexusFrontButtress",
            Vector3(side * 2.23, 1.87, 1.70),
            Vector3(0.40, 2.86, 0.62), "armor")
        g.poly_tilt("FreshNexusArmorCheek", "bevel",
            Vector3(side * 2.12, 2.10, 2.03),
            Vector3(0.62, 2.64, 0.37), "armor_light",
            Vector3(0, side * -0.18, 0))
        g.box("FreshNexusServiceWindow",
            Vector3(side * 2.06, 2.55, 2.28),
            Vector3(0.56, 0.35, 0.08), "void")
        g.box("FreshNexusServiceWindowLight",
            Vector3(side * 2.06, 2.55, 2.34),
            Vector3(0.42, 0.12, 0.06), "blue_light")
        g.rod("FreshNexusRoofHandrail",
            Vector3(side * 2.56, 3.60, -2.25),
            Vector3(side * 2.56, 3.60, 0.83), 0.11, "edge")
        g.box("FreshNexusRoofAntennaFoot",
            Vector3(side * 2.16, 4.15, -1.82),
            Vector3(0.44, 0.26, 0.41), "slate")
        for j in range(3):
            g.box("FreshNexusCrownPanelRib",
                Vector3(side * (0.85 + j * 0.63), 4.23,
                    -0.87),
                Vector3(0.07, 0.07, 2.34), "trim")
    # Recessed gate: visible empty dark throat and bright threshold.
    g.poly("FreshNexusGateFrame", "bevel",
        Vector3(0, 1.64, 1.79), Vector3(2.63, 2.73, 0.60), "armor_light")
    g.poly("FreshNexusGateCore", "bevel",
        Vector3(0, 1.52, 2.17), Vector3(1.94, 2.30, 0.27), "void")
    # Actual split armored entry door: the first capture showed a large
    # black hole, not a command facility. Make each panel a real metal slab.
    for side in [-1.0, 1.0]:
        g.poly_tilt("FreshNexusBlastDoorPanel", "bevel",
            Vector3(side * 0.48, 1.46, 2.39),
            Vector3(0.91, 1.90, 0.17), "slate",
            Vector3(0, side * -0.065, 0))
        g.box("FreshNexusBlastDoorJoint",
            Vector3(side * 0.50, 1.42, 2.52),
            Vector3(0.58, 0.09, 0.10), "armor_light")
    g.box("FreshNexusGateSeam",
        Vector3(0, 1.45, 2.53), Vector3(0.11, 1.95, 0.07), "void")
    g.box("FreshNexusAccessBeacon",
        Vector3(0, 2.41, 2.55), Vector3(0.40, 0.12, 0.07), "blue_light")
    g.box("FreshNexusGateDarkFloor",
        Vector3(0, 0.55, 2.38), Vector3(2.12, 0.12, 0.57), "dark")
    for side in [-1.0, 1.0]:
        g.box("FreshNexusGateLight",
            Vector3(side * 1.11, 1.68, 2.25),
            Vector3(0.12, 2.30, 0.11), "blue_light")
        g.box("FreshNexusGateProtection",
            Vector3(side * 1.28, 1.63, 2.14),
            Vector3(0.19, 2.62, 0.22), "slate")
        for row in range(3):
            g.box("FreshNexusGateServiceSlot",
                Vector3(side * 1.65, 1.15 + row * 0.65, 2.06),
                Vector3(0.25, 0.08, 0.09), "gold")
    g.box("FreshNexusGateLintel",
        Vector3(0, 2.95, 2.31), Vector3(2.56, 0.23, 0.19), "gold")
    g.box("FreshNexusGateCaution",
        Vector3(0, 0.48, 2.78), Vector3(2.30, 0.11, 0.15), "amber_light")
    # Roof service set: one purposeful vent and exposed comms array.
    g.poly("FreshNexusControlTower", "hood",
        Vector3(-0.10, 4.28, -1.75), Vector3(1.14, 0.64, 0.92), "slate")
    for col in range(5):
        g.box("FreshNexusTowerVent",
            Vector3(-0.50 + col * 0.19, 4.39, -1.23),
            Vector3(0.11, 0.22, 0.08), "blue")
    g.rod("FreshNexusCommandAntenna",
        Vector3(1.54, 4.18, -1.93),
        Vector3(1.54, 5.49, -1.93), 0.10, "gold")
    g.box("FreshNexusSignalMarker",
        Vector3(1.54, 5.53, -1.93), Vector3(0.23, 0.25, 0.19), "amber_light")
    # A separate left-hand receiving hood, not a repeat of the main roof.
    g.poly_tilt("FreshNexusSideLoadingHood", "canvas",
        Vector3(-2.78, 2.64, 1.43),
        Vector3(0.82, 0.12, 1.59), "cloth",
        Vector3(0, 0, 0.13))
    for j in range(3):
        g.box("FreshNexusSideCargo",
            Vector3(-2.82, 0.72 + j * 0.55, 1.71),
            Vector3(0.52, 0.45, 0.60), "rust" if j == 0 else "crate")


static func _labo(g: Variant) -> void:
    # Open robotic fabrication cell + taut *rear* tensile roof. Empty center
    # between worktables, single printer head at the front. No box-shaped shed.
    _pad(g, 3.82, 3.88)
    g.poly("FreshLabWorkbenchPlatform", "bevel",
        Vector3(0, 0.55, 0.60), Vector3(3.43, 0.36, 2.57), "slate")
    g.box("FreshLabRearControlWall",
        Vector3(0.0, 1.62, -1.62), Vector3(3.50, 2.20, 0.24), "armor")
    g.box("FreshLabDarkInterior",
        Vector3(0.0, 1.60, -1.47), Vector3(2.92, 1.86, 0.08), "void")
    for side in [-1.0, 1.0]:
        g.rod("FreshLabStructuralPost",
            Vector3(side * 1.73, 0.60, -1.32),
            Vector3(side * 1.73, 3.49, -1.32), 0.17, "gold")
        g.poly_tilt("FreshLabTensionedAwning", "canvas",
            Vector3(side * 0.88, 3.23, -1.08),
            Vector3(1.68, 0.10, 1.56), "cloth",
            Vector3(-0.21, 0, side * -0.21))
        g.rod("FreshLabOpenPrinterBridge",
            Vector3(side * 0.98, 0.85, 1.01),
            Vector3(side * 0.98, 2.83, 1.01), 0.18, "blue")
        g.box("FreshLabPrinterLegLight",
            Vector3(side * 0.99, 1.90, 1.16),
            Vector3(0.10, 1.55, 0.08), "blue_light")
        g.rod("FreshLabAwningCable",
            Vector3(side * 1.65, 3.40, -1.57),
            Vector3(side * 1.40, 3.17, -0.22), 0.05, "dark")
        g.box("FreshLabFloorTrack",
            Vector3(side * 1.15, 0.77, 0.65),
            Vector3(0.11, 0.11, 2.12), "edge")
    g.box("FreshLabPrinterBridgeTop",
        Vector3(0.0, 2.84, 1.02), Vector3(2.42, 0.23, 0.24), "armor_light")
    g.box("FreshLabPrinterServo",
        Vector3(0.0, 2.59, 1.18), Vector3(0.84, 0.55, 0.49), "slate")
    g.box("FreshLabPrinterBlueFace",
        Vector3(0.0, 2.39, 1.48), Vector3(0.62, 0.33, 0.12), "blue")
    g.poly("FreshLabPrinterHotHead", "bevel",
        Vector3(0.0, 1.99, 1.48), Vector3(0.31, 0.48, 0.27), "amber")
    g.box("FreshLabPrinterTip",
        Vector3(0.0, 1.69, 1.48), Vector3(0.12, 0.20, 0.16), "amber_light")
    g.poly("FreshLabFabricationBed", "bevel",
        Vector3(0, 1.06, 1.11), Vector3(1.91, 0.26, 1.45), "armor_light")
    g.poly("FreshLabPrintedShell", "bevel",
        Vector3(0.05, 1.38, 1.14), Vector3(0.69, 0.43, 0.58), "blue")
    g.box("FreshLabPrintBedMark",
        Vector3(0.0, 1.20, 1.80), Vector3(1.37, 0.09, 0.10), "gold")
    # Discrete side modules leave the printer absolutely unobstructed.
    g.poly("FreshLabServiceConsole", "bevel",
        Vector3(1.43, 1.24, -0.56), Vector3(0.77, 1.05, 0.83), "slate")
    g.box("FreshLabServiceScreen",
        Vector3(1.43, 1.64, -0.11), Vector3(0.55, 0.35, 0.09), "blue_light")
    for j in range(3):
        g.box("FreshLabTelemetry",
            Vector3(1.23 + j * 0.19, 1.68 - j * 0.08, 0.01),
            Vector3(0.10, 0.055, 0.04), "void")
    for j in range(3):
        g.poly("FreshLabPartsBin", "bevel",
            Vector3(-1.38, 0.93 + j * 0.53, -0.81),
            Vector3(0.58, 0.42, 0.60), "crate" if j % 2 else "rust")
    g.box("FreshLabWorkLamp",
        Vector3(0, 3.08, 0.02), Vector3(1.18, 0.10, 0.13), "amber")
    g.poly("FreshLabRearVent", "hood",
        Vector3(0.00, 3.34, -1.27), Vector3(0.86, 0.42, 0.74), "armor_light")


static func _collector(g: Variant) -> void:
    # Open single-jib crane, with suspended, separate yellow claws and a
    # dark exposed sorting pan. Dominant L silhouette, no enclosing shed.
    _pad(g, 2.34, 2.28)
    g.poly("FreshCollectorTurntable", "bevel",
        Vector3(-0.62, 0.77, -0.42), Vector3(0.89, 0.42, 0.87), "slate")
    g.poly("FreshCollectorWinchMotor", "bevel",
        Vector3(-0.73, 1.19, -0.59), Vector3(0.72, 0.68, 0.65), "armor_light")
    g.box("FreshCollectorMotorGlow",
        Vector3(-0.73, 1.45, -0.21), Vector3(0.37, 0.10, 0.07), "blue_light")
    g.poly("FreshCollectorSortPan", "hopper",
        Vector3(0.49, 0.75, 0.34), Vector3(1.33, 0.49, 1.40), "rust")
    g.box("FreshCollectorOpenHopper",
        Vector3(0.49, 1.04, 0.33), Vector3(0.91, 0.10, 1.01), "void")
    for side in [-1.0, 1.0]:
        g.box("FreshCollectorPanLedge",
            Vector3(0.49 + side * 0.58, 1.03, 0.34),
            Vector3(0.12, 0.16, 1.30), "armor_light")
    for j in range(4):
        g.poly_tilt("FreshCollectorSortedScrap", "bevel",
            Vector3(0.19 + (j % 2) * 0.42, 1.16, 0.02 + (j / 2) * 0.39),
            Vector3(0.32, 0.13, 0.28), "armor" if j % 2 else "edge",
            Vector3(0, j * 0.5, 0.09))
    g.rod("FreshCollectorTallBoom",
        Vector3(-0.71, 1.34, -0.60), Vector3(-0.36, 3.63, -0.66),
        0.33, "gold")
    g.rod("FreshCollectorTallBoom",
        Vector3(-0.36, 3.63, -0.66), Vector3(0.43, 3.08, 1.06),
        0.28, "gold")
    g.rod("FreshCollectorHydraulicRam",
        Vector3(-0.86, 1.09, -0.52), Vector3(-0.41, 2.79, -0.47),
        0.13, "armor_light")
    g.poly("FreshCollectorBoomElbow", "bevel",
        Vector3(-0.37, 3.52, -0.63), Vector3(0.52, 0.48, 0.46), "slate")
    g.box("FreshCollectorPulley",
        Vector3(0.43, 3.07, 1.06), Vector3(0.45, 0.38, 0.36), "gold")
    g.rod("FreshCollectorSuspendedCable",
        Vector3(0.43, 2.92, 1.07), Vector3(0.43, 2.11, 1.07),
        0.09, "dark")
    g.box("FreshCollectorJawMotor",
        Vector3(0.43, 2.10, 1.13), Vector3(0.60, 0.33, 0.38), "armor")
    # A genuine open gripping form: two separate opposing assemblies.
    for side in [-1.0, 1.0]:
        g.rod("FreshCollectorJawHinge",
            Vector3(0.43, 2.05, 1.15),
            Vector3(0.43 + side * 0.64, 1.58, 1.36), 0.22, "gold")
        g.poly_tilt("FreshCollectorOpenGrip", "bevel",
            Vector3(0.43 + side * 0.69, 1.52, 1.43),
            Vector3(0.35, 0.83, 0.32), "caution",
            Vector3(0, 0, side * -0.20))
        g.rod("FreshCollectorGripTip",
            Vector3(0.43 + side * 0.77, 1.23, 1.48),
            Vector3(0.43 + side * 0.32, 0.93, 1.64), 0.15, "armor_light")
        g.box("FreshCollectorJawHazard",
            Vector3(0.43 + side * 0.67, 1.68, 1.63),
            Vector3(0.22, 0.13, 0.08), "void")
    g.box("FreshCollectorHazardLamp",
        Vector3(-0.71, 2.10, -0.40), Vector3(0.40, 0.18, 0.16), "amber_light")


static func _smelter(g: Variant) -> void:
    # Narrow high masonry-like smelter, asymmetrical exposed exhaust stacks,
    # a single huge orange furnace aperture at eye level.
    _pad(g, 2.28, 2.22)
    g.poly("FreshSmelterFurnaceBase", "bevel",
        Vector3(0.0, 1.27, -0.07), Vector3(2.00, 1.78, 1.89), "rust")
    g.poly("FreshSmelterBlastJacket", "bevel",
        Vector3(0.0, 1.85, -0.38), Vector3(2.07, 1.18, 1.47), "slate")
    g.poly("FreshSmelterHotThroat", "bevel",
        Vector3(0.0, 1.16, 1.02), Vector3(1.52, 1.47, 0.30), "void")
    # Orange fire body with smaller hot slots; avoid all-white blown-out
    # vertical bars visible in the first actual gameplay image.
    g.box("FreshSmelterCombustionCore",
        Vector3(0.0, 1.21, 1.25), Vector3(1.15, 1.13, 0.14), "amber")
    g.box("FreshSmelterLowFire",
        Vector3(0.0, 0.77, 1.40), Vector3(0.91, 0.22, 0.06), "amber_light")
    for j in range(4):
        g.box("FreshSmelterFurnaceGrate",
            Vector3(-0.48 + j * 0.32, 1.21, 1.38),
            Vector3(0.08, 1.29, 0.08), "dark")
    g.box("FreshSmelterFurnaceLintel",
        Vector3(0.0, 2.00, 1.24), Vector3(1.67, 0.22, 0.25), "armor_light")
    for side in [-1.0, 1.0]:
        g.poly("FreshSmelterTwinStacks", "drum",
            Vector3(side * 0.70, 3.15 - (0.41 if side > 0 else 0),
                -0.54), Vector3(0.62, 1.82 if side < 0 else 1.32, 0.62),
            "slate")
        g.ring("FreshSmelterStackRim",
            Vector3(side * 0.70, 4.15 if side < 0 else 3.48, -0.54),
            0.32, "gold")
        g.box("FreshSmelterSideCoolingPanel",
            Vector3(side * 1.00, 1.19, -0.17),
            Vector3(0.16, 1.00, 1.19), "armor_light")
        for fin in range(4):
            g.box("FreshSmelterHeatFin",
                Vector3(side * 1.09, 0.78 + fin * 0.29, -0.16),
                Vector3(0.13, 0.07, 1.09), "rust")
    g.poly_tilt("FreshSmelterObliqueShield", "roof",
        Vector3(0.0, 2.47, 0.25), Vector3(2.01, 0.20, 0.83),
        "armor_light", Vector3(-0.18, 0, 0))
    g.box("FreshSmelterCinderLip",
        Vector3(0.0, 0.47, 1.33), Vector3(1.89, 0.17, 0.28), "gold")
    for i in range(3):
        g.poly("FreshSmelterDischargedSlag", "bevel",
            Vector3(-0.61 + i * 0.51, 0.52, 1.27),
            Vector3(0.40, 0.15, 0.40), "dark" if i % 2 else "rust")


static func _recycler(g: Variant) -> void:
    # Open horizontal shear crusher, visible V jaws and paired exposed
    # longitudinal rollers. All cutting surfaces point toward camera.
    _pad(g, 2.36, 2.35)
    g.poly("FreshRecyclerFeedFrame", "bevel",
        Vector3(0, 0.68, 0.00), Vector3(2.04, 0.69, 1.99), "slate")
    g.box("FreshRecyclerBlackFeedBed",
        Vector3(0, 1.06, 0.13), Vector3(1.70, 0.11, 1.56), "void")
    for side in [-1.0, 1.0]:
        g.poly_tilt("FreshRecyclerOpenVJaws", "bevel",
            Vector3(side * 0.70, 1.63, 0.26),
            Vector3(0.31, 1.32, 1.53), "armor_light",
            Vector3(0, 0, -side * 0.33))
        g.box("FreshRecyclerCautionJawEdge",
            Vector3(side * 0.51, 1.81, 0.80),
            Vector3(0.14, 0.28, 0.48), "gold")
        g.rod("FreshRecyclerHydraulicRod",
            Vector3(side * 1.02, 0.55, -0.61),
            Vector3(side * 0.75, 1.68, 0.02), 0.15, "rust")
        g.poly("FreshRecyclerJawPivot", "bevel",
            Vector3(side * 0.90, 0.82, -0.63),
            Vector3(0.40, 0.37, 0.43), "dark")
    for j in range(4):
        g.poly_tilt("FreshRecyclerRoller", "drum",
            Vector3(0.0, 1.14, -0.40 + j * 0.31),
            Vector3(1.29, 0.27, 0.29), "edge",
            Vector3(0, 0, PI * 0.5))
        for tooth in range(4):
            g.poly("FreshRecyclerTooth", "gear",
                Vector3(-0.48 + tooth * 0.32, 1.31,
                    -0.40 + j * 0.31),
                Vector3(0.19, 0.17, 0.17), "dark")
    g.poly_tilt("FreshRecyclerFeedRamp", "roof",
        Vector3(0, 0.79, 1.01), Vector3(1.65, 0.13, 0.76),
        "rust", Vector3(-0.24, 0, 0))
    g.box("FreshRecyclerChuteLip",
        Vector3(0, 0.57, 1.43), Vector3(1.69, 0.15, 0.17), "gold")
    g.poly("FreshRecyclerSideDrive", "bevel",
        Vector3(-1.06, 1.20, -0.59), Vector3(0.38, 0.74, 0.87), "armor")
    g.ring("FreshRecyclerDriveRing",
        Vector3(-1.26, 1.24, -0.54), 0.31, "gold", "z")


static func _generator(g: Variant) -> void:
    # Compact power station with one truly massive forward-facing rotor,
    # cool-blue halo, angular coolant cylinders and open heavy chassis.
    _pad(g, 2.38, 2.30)
    g.poly("FreshGeneratorMotorFrame", "bevel",
        Vector3(0, 1.35, -0.52), Vector3(2.11, 1.60, 1.23), "slate")
    g.box("FreshGeneratorMotorVent",
        Vector3(0, 2.14, -0.50), Vector3(1.72, 0.16, 1.19), "armor_light")
    for side in [-1.0, 1.0]:
        g.rod("FreshGeneratorSideSupport",
            Vector3(side * 1.00, 0.52, 0.67),
            Vector3(side * 1.00, 2.41, -0.21), 0.17, "gold")
        g.poly("FreshGeneratorCoolantTank", "drum",
            Vector3(side * 0.90, 2.23, -0.73),
            Vector3(0.46, 1.09, 0.55), "armor_light")
        g.box("FreshGeneratorCoolantCap",
            Vector3(side * 0.90, 2.79, -0.73),
            Vector3(0.52, 0.12, 0.58), "slate")
        for j in range(3):
            g.box("FreshGeneratorHeatSink",
                Vector3(side * 1.13, 0.98 + j * 0.35, -0.26),
                Vector3(0.13, 0.14, 0.83), "rust")
    # The main rotor faces +Z directly, not a small decorative icon.
    g.poly("FreshGeneratorFrontRotor", "drum",
        Vector3(0, 1.41, 0.82), Vector3(1.75, 1.79, 0.59), "armor")
    g.box("FreshGeneratorBlackRotorWell",
        Vector3(0, 1.41, 1.14), Vector3(1.53, 1.55, 0.14), "void")
    g.ring("FreshGeneratorBlueCorona",
        Vector3(0, 1.41, 1.30), 0.76, "blue", "z")
    g.ring("FreshGeneratorRotorInnerRim",
        Vector3(0, 1.41, 1.32), 0.57, "blue", "z")
    for j in range(5):
        var a: float = float(j) * TAU / 5.0
        g.rod("FreshGeneratorRotorBlade",
            Vector3(cos(a) * 0.14, 1.41 + sin(a) * 0.14, 1.36),
            Vector3(cos(a + 0.35) * 0.55, 1.41 + sin(a + 0.35) * 0.55, 1.36),
            0.19, "blue_light")
    g.poly("FreshGeneratorRotorHub", "bevel",
        Vector3(0, 1.41, 1.41), Vector3(0.35, 0.34, 0.25), "armor_light")
    g.box("FreshGeneratorControlMeter",
        Vector3(0.86, 1.62, 0.72), Vector3(0.31, 0.29, 0.15), "amber_light")
    g.rod("FreshGeneratorOutputConduit",
        Vector3(0.78, 0.68, -0.72),
        Vector3(1.31, 0.52, -1.09), 0.24, "blue")


static func _storage(g: Variant) -> void:
    # Asymmetric shipping yard made from real stacked freight units,
    # not a little shed hiding its contents behind the roof.
    _pad(g, 2.36, 2.29)
    g.poly("FreshStorageFreightPlatform", "bevel",
        Vector3(0, 0.52, 0.24), Vector3(2.09, 0.33, 1.95), "rust")
    # Off-center stacks create a readable stair-step skyline in play view.
    var stacks: Array[Vector3] = [
        Vector3(-0.55, 0.91, 0.42),
        Vector3(0.49, 0.85, 0.43),
        Vector3(-0.55, 1.61, 0.28),
        Vector3(0.49, 1.50, 0.10),
        Vector3(-0.55, 2.48, -0.14),
    ]
    for i in range(stacks.size()):
        var at: Vector3 = stacks[i]
        g.poly("FreshStorageOffsetStacks", "bevel", at,
            Vector3(0.93 if i % 2 == 0 else 0.86,
                0.58 if i != 4 else 0.49, 0.79),
            "armor_light" if i == 4 else ("crate" if i % 3 else "rust"))
        g.box("FreshStorageColoredCargoLabel",
            at + Vector3(0.02, -0.04, 0.44),
            Vector3(0.51, 0.13, 0.08),
            "caution" if i % 2 else "blue")
        g.box("FreshStorageFrontContainerSeam",
            at + Vector3(0.0, 0.18, 0.44),
            Vector3(0.74, 0.07, 0.085), "dark")
        g.box("FreshStorageContainerLid",
            at + Vector3(0, 0.32, 0),
            Vector3(0.95, 0.08, 0.82), "armor_light")
        for edge in [-1.0, 1.0]:
            g.box("FreshStorageContainerLock",
                at + Vector3(edge * 0.36, 0, 0.43),
                Vector3(0.10, 0.51, 0.11), "gold")
        g.box("FreshStorageContainerHandle",
            at + Vector3(0.0, -0.06, 0.45),
            Vector3(0.35, 0.075, 0.08), "slate")
    # Simple exposed loading forklift/lift on the left: distinct from the
    # container stacks and readable next to them in the fixed camera view.
    for side in [-1.0, 1.0]:
        g.rod("FreshStorageLiftGuide",
            Vector3(-1.06 + side * 0.13, 0.51, 0.92),
            Vector3(-1.06 + side * 0.13, 2.41, 0.92),
            0.11, "armor_light")
    g.box("FreshStorageLoadingLift",
        Vector3(-1.12, 1.01, 1.09), Vector3(0.55, 0.19, 0.66), "gold")
    g.box("FreshStorageLiftPower",
        Vector3(-1.12, 2.44, 0.90), Vector3(0.42, 0.31, 0.43), "slate")
    g.box("FreshStorageLiftLight",
        Vector3(-1.12, 2.47, 1.14), Vector3(0.21, 0.09, 0.10), "amber_light")
    # ONLY short rear weather strip so the freight contents are unoccluded.
    g.poly_tilt("FreshStorageShortRearTarp", "canvas",
        Vector3(0, 2.63, -1.03), Vector3(2.13, 0.12, 0.63),
        "cloth", Vector3(-0.13, 0, 0))


static func _terminal(g: Variant) -> void:
    # Tall two-column public engineering console / holographic blueprint
    # screen. One clean luminous face and keypad; not a small roof house.
    _pad(g, 2.09, 1.97)
    g.poly("FreshTerminalSignalBody", "bevel",
        Vector3(0, 1.18, -0.45), Vector3(1.83, 1.45, 0.87), "slate")
    for side in [-1.0, 1.0]:
        g.rod("FreshTerminalMonitorUpright",
            Vector3(side * 0.89, 0.55, -0.44),
            Vector3(side * 0.89, 2.81, -0.44), 0.14, "armor_light")
        g.box("FreshTerminalEdgeLight",
            Vector3(side * 0.89, 1.95, 0.09),
            Vector3(0.085, 0.98, 0.08), "blue_light")
    g.poly_tilt("FreshTerminalMonitorVisor", "roof",
        Vector3(0, 2.78, -0.19), Vector3(2.00, 0.15, 0.65),
        "armor", Vector3(-0.14, 0, 0))
    g.poly("FreshTerminalDisplayFrame", "bevel",
        Vector3(0.0, 1.96, 0.16), Vector3(1.89, 1.34, 0.35), "armor_light")
    g.box("FreshTerminalWideScreen",
        Vector3(0, 1.96, 0.39), Vector3(1.61, 1.13, 0.10), "void")
    g.box("FreshTerminalLiveDisplay",
        Vector3(0, 1.96, 0.48), Vector3(1.47, 1.00, 0.085), "glass")
    for row in range(4):
        g.box("FreshTerminalBlueprintRows",
            Vector3(0.0, 1.63 + row * 0.23, 0.55),
            Vector3(1.26, 0.035, 0.028), "blue_light")
    for col in range(4):
        g.box("FreshTerminalBlueprintCols",
            Vector3(-0.47 + col * 0.31, 1.96, 0.55),
            Vector3(0.024, 0.89, 0.032), "blue")
    g.poly_tilt("FreshTerminalKeypadPlate", "bevel",
        Vector3(0, 1.10, 0.65), Vector3(1.91, 0.18, 0.76),
        "slate", Vector3(-0.28, 0, 0))
    for row in range(2):
        for col in range(5):
            g.box("FreshTerminalTactileKey",
                Vector3(-0.56 + col * 0.28, 1.19, 0.52 + row * 0.20),
                Vector3(0.17, 0.05, 0.10),
                "edge" if col % 2 else "blue")
    g.rod("FreshTerminalSignalMast",
        Vector3(0.80, 2.71, -0.76),
        Vector3(0.80, 3.79, -0.76), 0.10, "gold")
    g.box("FreshTerminalMastLamp",
        Vector3(0.80, 3.80, -0.76), Vector3(0.25, 0.23, 0.24), "blue_light")
    g.poly("FreshTerminalSideBattery", "bevel",
        Vector3(-0.88, 0.75, -0.64),
        Vector3(0.43, 0.72, 0.65), "rust")


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
