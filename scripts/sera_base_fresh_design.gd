extends RefCounted
## SERA BASE FRESH_20261122 — image-reference industrial re-authoring of eight facilities.
## Reference: front-facing bunker, canvas workshop, furnace, shredder, Geometry belongs to the
## exposed generator, freight racks, grabber crane and blueprint terminal.
## Shared opaque batch renderer, no additional draw calls per part; local meters.
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
    # REFERENCE 2026-11-22: broad military workshop, exposed frontal airlock,
    # asymmetric service wings, awning at left, signal mast at right. Flat roof.
    _pad(g, 6.20, 5.15)
    g.poly("FreshNexusCommandHull", "bevel",
        Vector3(0, 2.02, -0.48), Vector3(5.28, 3.07, 3.92), "armor")
    g.poly("FreshNexusUpperDeck", "bevel",
        Vector3(0, 3.58, -0.50), Vector3(5.64, 0.26, 4.36), "slate")
    g.poly("FreshNexusSplitCrown", "bevel",
        Vector3(0, 3.79, -1.10), Vector3(3.60, 0.28, 2.63), "armor_light")
    # Roof grille reads from the actual 27-degree orthographic camera.
    for i in range(6):
        g.box("FreshNexusRoofPanelSeam",
            Vector3(-1.42 + i * 0.56, 3.97, -1.08),
            Vector3(0.07, 0.045, 2.25), "trim")
    for side in [-1.0, 1.0]:
        g.poly("FreshNexusWallButtress", "bevel",
            Vector3(side * 2.38, 1.98, 1.32),
            Vector3(0.52, 3.06, 0.84), "slate")
        g.box("FreshNexusSideWindow",
            Vector3(side * 2.25, 2.59, 1.81),
            Vector3(0.43, 0.32, 0.08), "void")
        g.box("FreshNexusSideWarmLamp",
            Vector3(side * 2.25, 2.59, 1.89),
            Vector3(0.34, 0.11, 0.065), "amber_light")
        g.box("FreshNexusWallBaseArmor",
            Vector3(side * 2.16, 0.87, 1.92),
            Vector3(0.75, 0.58, 0.17), "armor_light")
        for row in range(3):
            g.box("FreshNexusFacadeBolts",
                Vector3(side * 2.46, 0.94 + row * 0.87, 1.90),
                Vector3(0.10, 0.10, 0.10), "gold")
    # Recessed front airlock stays in full view below the roof.
    g.poly("FreshNexusGateFrame", "bevel",
        Vector3(0, 1.69, 2.05), Vector3(2.57, 2.46, 0.59), "dark")
    g.poly("FreshNexusGateCore", "bevel",
        Vector3(0, 1.66, 2.40), Vector3(2.08, 2.05, 0.18), "slate")
    for side in [-1.0, 1.0]:
        g.poly("FreshNexusBlastDoorPanel", "bevel",
            Vector3(side * 0.51, 1.65, 2.54),
            Vector3(0.96, 1.93, 0.10), "armor")
        g.box("FreshNexusBlastDoorTrack",
            Vector3(side * 1.23, 1.75, 2.60),
            Vector3(0.18, 2.37, 0.21), "armor_light")
        g.box("FreshNexusGateLight",
            Vector3(side * 1.35, 1.65, 2.71),
            Vector3(0.075, 1.42, 0.065), "blue_light")
        g.box("FreshNexusDoorLock",
            Vector3(side * 0.22, 1.64, 2.68),
            Vector3(0.075, 0.42, 0.065), "gold")
    g.box("FreshNexusGateSeam", Vector3(0, 1.68, 2.66),
        Vector3(0.06, 1.94, 0.05), "dark")
    g.poly("FreshNexusEntranceAwning", "hood",
        Vector3(0, 3.10, 2.39), Vector3(3.13, 0.36, 1.10), "armor_light")
    g.box("FreshNexusAccessBeacon",
        Vector3(0, 2.88, 2.93), Vector3(0.89, 0.19, 0.08), "amber_light")
    for step in range(3):
        g.box("FreshNexusDoorThreshold",
            Vector3(0, 0.47 - step * 0.07, 2.80 + step * 0.27),
            Vector3(2.58 + step * 0.25, 0.10, 0.25), "slate")
    # Left wing is a recognisable cargo-side awning, not another roof box.
    g.poly("FreshNexusLeftWing", "bevel",
        Vector3(-3.09, 1.35, -0.49),
        Vector3(1.86, 1.92, 2.88), "slate")
    g.poly_tilt("FreshNexusCanvasAwning", "canvas",
        Vector3(-3.34, 2.70, 1.02),
        Vector3(2.92, 0.12, 2.09), "cloth", Vector3(-0.16, 0, 0.04))
    for x in [-4.51, -2.20]:
        g.rod("FreshNexusAwningLeg", Vector3(x, 0.37, 1.96),
            Vector3(x, 2.56, 1.96), 0.10, "edge")
        g.box("FreshNexusCargoStack",
            Vector3(x, 0.76, 1.49), Vector3(0.58, 0.71, 0.55), "crate")
    # Right wing carries exposed ventilation, pipes and a *single* tall mast.
    g.poly("FreshNexusRightUtilityAnnex", "bevel",
        Vector3(3.03, 1.72, -0.67),
        Vector3(1.73, 2.72, 2.89), "slate")
    g.poly("FreshNexusRightFlatCap", "bevel",
        Vector3(3.03, 3.17, -0.67),
        Vector3(1.91, 0.23, 3.04), "armor_light")
    for i in range(5):
        g.box("FreshNexusUtilityLouver",
            Vector3(3.94, 2.11, -1.47 + i * 0.36),
            Vector3(0.11, 0.14, 0.24), "trim")
    g.rod("FreshNexusPipeVertical", Vector3(3.93, 0.68, 1.10),
        Vector3(3.93, 3.45, 1.10), 0.14, "gold")
    g.rod("FreshNexusPipeElbow", Vector3(3.93, 3.45, 1.10),
        Vector3(3.20, 3.45, 1.10), 0.14, "gold")
    g.poly("FreshNexusAntennaFoot", "bevel",
        Vector3(3.15, 3.46, -1.57),
        Vector3(0.65, 0.51, 0.65), "dark")
    g.rod("FreshNexusCommandAntenna", Vector3(3.15, 3.71, -1.57),
        Vector3(3.15, 6.20, -1.57), 0.11, "edge")
    for y in [4.25, 4.96, 5.68]:
        g.rod("FreshNexusAntennaCrossbar",
            Vector3(2.75, y, -1.57), Vector3(3.55, y, -1.57),
            0.07, "gold")
    g.box("FreshNexusSignalMarker",
        Vector3(3.15, 6.26, -1.57), Vector3(0.22, 0.22, 0.22),
        "amber_light")


static func _labo(g: Variant) -> void:
    # Open tented fabricator: shelving, printer, a canvas shelter and a desk.
    _pad(g, 4.16, 4.25)
    g.poly("FreshLabWorkbenchPlatform", "bevel",
        Vector3(0, 0.49, 0.02), Vector3(3.86, 0.19, 3.83), "slate")
    g.poly("FreshLabRearWall", "bevel",
        Vector3(0, 1.84, -1.67), Vector3(3.65, 2.69, 0.33), "armor")
    for side in [-1.0, 1.0]:
        g.poly("FreshLabSideWall",
            "bevel", Vector3(side * 1.80, 1.58, -0.92),
            Vector3(0.29, 2.18, 1.65), "slate")
        for z in [-1.65, 1.58]:
            g.rod("FreshLabStructuralPost",
                Vector3(side * 1.84, 0.45, z),
                Vector3(side * 1.84, 3.48, z), 0.11, "edge")
        # Canvas only shades the REAR workbench; front opening is unblocked.
        g.poly_tilt("FreshLabTensionedAwning", "canvas",
            Vector3(side * 0.90, 3.37, -1.01),
            Vector3(1.97, 0.12, 1.75), "cloth",
            Vector3(-0.18, 0, side * -0.09))
        g.rod("FreshLabAwningTie",
            Vector3(side * 1.85, 3.24, 0.07),
            Vector3(side * 1.85, 2.71, 1.68), 0.055, "gold")
    g.box("FreshLabAwningFrontRail",
        Vector3(0, 3.17, -0.19),
        Vector3(3.84, 0.13, 0.13), "armor_light")
    # Three-dimensional fabrication gantry is deliberately in the open front.
    for side in [-1.0, 1.0]:
        g.rod("FreshLabPrinterRail",
            Vector3(side * 0.95, 0.71, 0.98),
            Vector3(side * 0.95, 2.67, 0.98), 0.12, "armor_light")
        g.box("FreshLabPrinterLegLight",
            Vector3(side * 0.95, 2.15, 1.10),
            Vector3(0.075, 0.72, 0.07), "blue_light")
    g.rod("FreshLabOpenPrinterBridge",
        Vector3(-1.00, 2.64, 0.97),
        Vector3(1.00, 2.64, 0.97), 0.20, "edge")
    g.poly("FreshLabPrinterServo", "bevel",
        Vector3(0.10, 2.40, 1.05),
        Vector3(0.50, 0.36, 0.50), "slate")
    g.poly("FreshLabPrinterHotHead", "bevel",
        Vector3(0.10, 1.93, 1.05),
        Vector3(0.30, 0.61, 0.30), "gold")
    g.box("FreshLabPrinterTip",
        Vector3(0.10, 1.55, 1.08),
        Vector3(0.11, 0.20, 0.11), "amber_light")
    g.poly("FreshLabFabricationBed", "bevel",
        Vector3(0.10, 0.88, 1.13),
        Vector3(2.11, 0.26, 1.41), "armor_light")
    g.poly("FreshLabPrintedShell", "bevel",
        Vector3(0.10, 1.10, 1.13),
        Vector3(0.65, 0.33, 0.48), "blue")
    for i in range(4):
        g.box("FreshLabBedTrack",
            Vector3(-0.71 + i * 0.50, 1.03, 1.75),
            Vector3(0.11, 0.09, 0.07), "gold")
    # Rear tool wall and shelves are identifiable through the open workshop.
    for y in [1.02, 1.65, 2.28]:
        g.box("FreshLabToolShelf",
            Vector3(-0.93, y, -1.36),
            Vector3(1.27, 0.12, 0.46), "armor_light")
    for col in range(5):
        g.box("FreshLabToolJar",
            Vector3(-1.44 + col * 0.27, 1.80, -1.37),
            Vector3(0.17, 0.27, 0.19), "crate")
    g.poly("FreshLabServiceConsole", "bevel",
        Vector3(1.46, 1.07, 1.28),
        Vector3(0.59, 1.18, 0.59), "slate")
    g.box("FreshLabServiceScreen",
        Vector3(1.46, 1.37, 1.63),
        Vector3(0.44, 0.40, 0.06), "glass")
    for i in range(3):
        g.box("FreshLabTelemetry",
            Vector3(1.46, 1.21 + i * 0.11, 1.70),
            Vector3(0.34, 0.035, 0.025), "blue_light")
    # Rear utility fixtures glow through the front gap and visibly
    # separate the fabrication opening from its canopy at gameplay scale.
    g.box("FreshLabWarmWorkLight",
        Vector3(0, 2.86, -1.35),
        Vector3(1.56, 0.16, 0.11), "amber_light")
    g.box("FreshLabInteriorLightRail",
        Vector3(0, 2.26, -1.49),
        Vector3(2.29, 0.12, 0.11), "amber_light")
    for side in [-1.0, 1.0]:
        g.box("FreshLabFrontMachinePylon",
            Vector3(side * 1.13, 1.58, 1.38),
            Vector3(0.18, 1.65, 0.17), "armor_light")
        g.box("FreshLabFrontMachineGlow",
            Vector3(side * 1.13, 1.55, 1.51),
            Vector3(0.07, 1.11, 0.06), "blue_light")
    for side in [-1.0, 1.0]:
        g.poly("FreshLabPartsBin", "bevel",
            Vector3(side * 1.53, 0.70, 0.20),
            Vector3(0.51, 0.46, 0.62), "crate")
    g.poly_tilt("FreshLabHangingBanner", "canvas",
        Vector3(-1.98, 1.97, -0.33),
        Vector3(0.08, 1.75, 0.84), "blue", Vector3(0.05, 0, -0.03))


static func _collector(g: Variant) -> void:
    # Small excavator arm on a rotating carriage; claw hangs above scrap skip.
    _pad(g, 2.33, 2.24)
    g.poly("FreshCollectorTurntable", "bevel",
        Vector3(-0.78, 0.65, -0.48), Vector3(1.13, 0.57, 1.10), "slate")
    g.poly("FreshCollectorWinchMotor", "bevel",
        Vector3(-0.74, 1.08, -0.40), Vector3(0.83, 0.50, 0.72), "gold")
    g.box("FreshCollectorMotorGlow",
        Vector3(-0.75, 1.10, 0.00), Vector3(0.39, 0.12, 0.07), "blue_light")
    g.poly("FreshCollectorSortPan", "hopper",
        Vector3(0.36, 0.66, 0.68), Vector3(1.78, 0.75, 1.36), "armor")
    g.box("FreshCollectorOpenHopper",
        Vector3(0.36, 0.93, 0.69),
        Vector3(1.50, 0.12, 1.15), "dark")
    for side in [-1.0, 1.0]:
        g.box("FreshCollectorPanLedge",
            Vector3(side * 0.88 + 0.36, 1.05, 0.68),
            Vector3(0.14, 0.17, 1.43), "caution")
    for i in range(10):
        g.poly_tilt("FreshCollectorLooseScrap", "bevel",
            Vector3(-0.30 + float(i % 5) * 0.30,
                1.07 + float(i % 3) * 0.095,
                0.28 + float(i / 5) * 0.48),
            Vector3(0.16, 0.13, 0.25), "rust" if i % 3 else "edge",
            Vector3(0.12 * (i % 3), 0.23 * i, 0.08 * i))
    # Distinct rising boom silhouette, visibly separate from the skip.
    g.rod("FreshCollectorTallBoom", Vector3(-0.78, 1.28, -0.43),
        Vector3(-0.35, 2.97, -0.31), 0.34, "gold")
    g.rod("FreshCollectorTallBoom", Vector3(-0.35, 2.97, -0.31),
        Vector3(0.76, 2.59, 1.04), 0.28, "gold")
    g.poly("FreshCollectorBoomPivot", "bevel",
        Vector3(-0.35, 2.98, -0.31),
        Vector3(0.42, 0.42, 0.45), "slate")
    g.rod("FreshCollectorHydraulicRam",
        Vector3(-0.80, 1.78, -0.44),
        Vector3(-0.27, 2.69, -0.29), 0.13, "edge")
    g.rod("FreshCollectorHydraulicRam",
        Vector3(-0.13, 2.79, -0.26),
        Vector3(0.56, 2.59, 0.71), 0.11, "edge")
    g.box("FreshCollectorPulley",
        Vector3(0.76, 2.59, 1.04),
        Vector3(0.40, 0.36, 0.39), "slate")
    g.rod("FreshCollectorSuspendedCable",
        Vector3(0.76, 2.54, 1.04),
        Vector3(0.76, 1.84, 1.04), 0.070, "dark")
    g.poly("FreshCollectorClawHead", "bevel",
        Vector3(0.76, 1.82, 1.04),
        Vector3(0.58, 0.38, 0.52), "armor_light")
    for side in [-1.0, 1.0]:
        g.rod("FreshCollectorJawHinge",
            Vector3(0.76 + side * 0.28, 1.80, 1.04),
            Vector3(0.76 + side * 0.43, 1.43, 1.16), 0.11, "edge")
        g.poly_tilt("FreshCollectorOpenGrip", "bevel",
            Vector3(0.76 + side * 0.52, 1.32, 1.20),
            Vector3(0.20, 0.73, 0.25), "armor_light",
            Vector3(0.15, 0.0, side * 0.34))
    g.box("FreshCollectorHazardLamp",
        Vector3(-0.99, 1.44, -0.21),
        Vector3(0.23, 0.19, 0.12), "amber_light")


static func _smelter(g: Variant) -> void:
    # The orange furnace opening is the focal point; exhaust pipes are behind.
    _pad(g, 2.48, 2.50)
    g.poly("FreshSmelterFurnaceBase", "bevel",
        Vector3(0, 0.57, -0.10), Vector3(2.16, 0.71, 2.10), "slate")
    g.poly("FreshSmelterBlastJacket", "drum",
        Vector3(0, 1.61, -0.19), Vector3(2.04, 2.02, 2.04), "armor")
    g.poly("FreshSmelterUpperCollar", "bevel",
        Vector3(0, 2.59, -0.19), Vector3(2.19, 0.27, 2.16), "rust")
    for i in range(10):
        var theta: float = float(i) * TAU / 10.0
        g.box("FreshSmelterThermalBolts",
            Vector3(cos(theta) * 0.97, 2.58,
                sin(theta) * 0.97 - 0.19),
            Vector3(0.17, 0.17, 0.17), "gold")
    # Recessed, open glowing combustion port under a stepped dark hood.
    g.poly("FreshSmelterHotThroat", "bevel",
        Vector3(0, 1.43, 0.86), Vector3(1.47, 1.07, 0.37), "rust")
    g.box("FreshSmelterCombustionCore",
        Vector3(0, 1.44, 1.105),
        Vector3(1.24, 0.77, 0.09), "amber")
    g.box("FreshSmelterLowFire",
        Vector3(0, 1.23, 1.18),
        Vector3(0.92, 0.19, 0.09), "amber_light")
    for i in range(4):
        g.poly_tilt("FreshSmelterFlameTongue", "bevel",
            Vector3(-0.42 + i * 0.27, 1.50, 1.18),
            Vector3(0.13, 0.51 + (i % 2) * 0.17, 0.06),
            "amber_light", Vector3(0, 0, (i - 2) * 0.15))
        g.box("FreshSmelterGrate",
            Vector3(-0.55 + i * 0.35, 1.34, 1.22),
            Vector3(0.085, 0.78, 0.09), "dark")
    g.poly("FreshSmelterCombustionHood", "hood",
        Vector3(0, 2.17, 1.04),
        Vector3(1.74, 0.32, 0.62), "armor_light")
    # Angled side heat guard, offset so it cannot cover the bright furnace.
    g.poly_tilt("FreshSmelterObliqueShield", "roof",
        Vector3(1.08, 2.36, 0.44),
        Vector3(0.48, 0.15, 0.88), "armor_light",
        Vector3(-0.20, 0.0, 0.22))
    for side in [-1.0, 1.0]:
        g.poly("FreshSmelterTwinStacks", "drum",
            Vector3(side * 0.81, 3.01, -0.84),
            Vector3(0.51, 2.67, 0.51), "slate")
        g.ring("FreshSmelterStackRim",
            Vector3(side * 0.81, 4.38, -0.84),
            0.26, "edge")
        g.box("FreshSmelterStackRivet",
            Vector3(side * 0.81, 4.20, -0.55),
            Vector3(0.20, 0.13, 0.11), "gold")
        g.box("FreshSmelterSideCoolingPanel",
            Vector3(side * 1.11, 1.32, -0.08),
            Vector3(0.24, 0.96, 1.07), "trim")
        for rib in range(4):
            g.box("FreshSmelterHeatFin",
                Vector3(side * 1.27, 1.04 + rib * 0.23, 0.11),
                Vector3(0.16, 0.10, 0.73), "edge")
    g.poly("FreshSmelterSideController", "bevel",
        Vector3(-1.06, 0.88, 0.69),
        Vector3(0.38, 0.62, 0.43), "slate")
    g.box("FreshSmelterControllerLamp",
        Vector3(-1.06, 1.03, 0.94),
        Vector3(0.21, 0.13, 0.06), "blue_light")
    for i in range(3):
        g.poly("FreshSmelterDischargedSlag", "bevel",
            Vector3(0.46 + i * 0.20, 0.43, 1.13 + i * 0.12),
            Vector3(0.19, 0.20, 0.22), "rust")


static func _recycler(g: Variant) -> void:
    # An industrial shredder with naked contra-rotating cutting teeth.
    _pad(g, 2.50, 2.45)
    g.poly("FreshRecyclerLowerBody", "bevel",
        Vector3(0, 0.72, -0.25),
        Vector3(2.35, 0.77, 2.06), "slate")
    g.box("FreshRecyclerBlackFeedBed",
        Vector3(0, 1.19, 0.11),
        Vector3(2.04, 0.11, 1.83), "dark")
    for side in [-1.0, 1.0]:
        g.poly_tilt("FreshRecyclerOpenVJaws", "bevel",
            Vector3(side * 1.05, 1.76, 0.20),
            Vector3(0.27, 1.11, 2.14), "armor",
            Vector3(0.0, 0.0, side * 0.25))
        g.box("FreshRecyclerCautionJawEdge",
            Vector3(side * 1.12, 2.18, 0.95),
            Vector3(0.16, 0.16, 0.34), "caution")
        g.poly("FreshRecyclerSideDrive", "bevel",
            Vector3(side * 1.21, 1.23, -0.22),
            Vector3(0.30, 1.22, 0.96), "armor_light")
        for i in range(3):
            g.box("FreshRecyclerMotorCoolingFin",
                Vector3(side * 1.41, 0.85 + i * 0.26, -0.23),
                Vector3(0.13, 0.10, 0.69), "trim")
    # Horizontal cutter cylinders and coarse teeth readable from above.
    for line in [-1.0, 1.0]:
        g.poly_tilt("FreshRecyclerRoller", "drum",
            Vector3(0, 1.37, 0.22 + line * 0.39),
            Vector3(0.56, 2.11, 0.56), "edge",
            Vector3(0, 0, PI * 0.5))
        for i in range(7):
            var x: float = -0.80 + i * 0.27
            g.poly_tilt("FreshRecyclerTooth", "gear",
                Vector3(x, 1.40, 0.22 + line * 0.39),
                Vector3(0.65, 0.17, 0.65), "armor_light",
                Vector3(0, 0, PI * 0.5))
    g.poly_tilt("FreshRecyclerFeedRamp", "bevel",
        Vector3(0, 0.62, 1.10), Vector3(2.14, 0.13, 0.82),
        "slate", Vector3(-0.13, 0, 0))
    for i in range(5):
        g.box("FreshRecyclerExitCaution",
            Vector3(-0.74 + i * 0.37, 0.69, 1.48),
            Vector3(0.16, 0.09, 0.21), "caution")
    g.poly("FreshRecyclerRearGearbox", "bevel",
        Vector3(0, 1.84, -1.05),
        Vector3(1.31, 0.61, 0.39), "armor")
    g.box("FreshRecyclerRearAccessLamp",
        Vector3(0, 1.93, -0.81),
        Vector3(0.64, 0.14, 0.06), "amber_light")


static func _generator(g: Variant) -> void:
    # Horizontal exposed electric turbine, cool blue core, isolated right cabinet.
    _pad(g, 2.55, 2.38)
    g.poly("FreshGeneratorMotorFrame", "bevel",
        Vector3(-0.20, 0.63, -0.23),
        Vector3(2.39, 0.59, 1.92), "slate")
    for side in [-1.0, 1.0]:
        g.rod("FreshGeneratorSideSupport",
            Vector3(side * 0.91 - 0.25, 0.60, 0.76),
            Vector3(side * 0.91 - 0.25, 2.32, 0.76),
            0.16, "armor_light")
        g.poly("FreshGeneratorBearing",
            "bevel", Vector3(side * 1.00 - 0.25, 1.45, 0.31),
            Vector3(0.33, 1.26, 1.28), "armor")
    # Rotor axis is horizontal and the near-side ribs show true cylindrical depth.
    g.poly_tilt("FreshGeneratorFrontRotor", "drum",
        Vector3(-0.27, 1.43, 0.29),
        Vector3(1.11, 2.30, 1.11), "blue",
        Vector3(0, 0, PI * 0.5))
    for i in range(6):
        g.poly_tilt("FreshGeneratorCoreRib", "drum",
            Vector3(-1.15 + i * 0.34, 1.43, 0.29),
            Vector3(1.24, 0.12, 1.24), "blue_light" if i % 2 == 0 else "edge",
            Vector3(0, 0, PI * 0.5))
    g.box("FreshGeneratorBlueCoreFace",
        Vector3(-0.25, 1.36, 0.98),
        Vector3(1.90, 0.70, 0.10), "glass")
    # Bright core is INSIDE the rotor. Opaque narrow grilles sit in FRONT
    # of it, so the light is revealed only through real physical slots,
    # rather than being an unmasked blue decal on the exterior.
    g.box("FreshGeneratorCoreRearEmitter",
        Vector3(-0.27, 1.43, 1.065),
        Vector3(1.52, 0.66, 0.028), "generator_emitter")
    for i in range(5):
        g.box("FreshGeneratorFanShadowLouver",
            Vector3(-0.27, 1.15 + float(i) * 0.14, 1.114),
            Vector3(1.62, 0.067, 0.060), "edge")
    # Horizontal energy rails emphasize the cylindrical blue core,
    # rather than allowing the front circular corona to read as a white logo.
    for y in [1.00, 1.81]:
        g.box("FreshGeneratorHorizontalGlow",
            Vector3(-0.27, y, 1.07),
            Vector3(2.06, 0.10, 0.10), "blue_light")
    for i in range(5):
        g.box("FreshGeneratorAxialLight",
            Vector3(-1.07 + i * 0.40, 1.37, 1.06),
            Vector3(0.12, 0.57, 0.08), "blue_light")
    g.ring("FreshGeneratorBlueCorona",
        Vector3(-0.27, 1.43, 1.07), 0.46, "blue_light", "z")
    g.ring("FreshGeneratorRotorInnerRim",
        Vector3(-0.27, 1.43, 1.11), 0.36, "edge", "z")
    # Four true spokes across the exposed turbine face (not a solid plate).
    for i in range(4):
        var phase: float = TAU * float(i) / 4.0
        g.rod("FreshGeneratorRotorBlade",
            Vector3(-0.27, 1.43, 1.16),
            Vector3(-0.27 + cos(phase) * 0.47,
                1.43 + sin(phase) * 0.47, 1.16),
            0.11, "edge")
    g.box("FreshGeneratorHousingUpper",
        Vector3(-0.21, 2.25, -0.25),
        Vector3(2.40, 0.24, 1.11), "armor_light")
    g.poly("FreshGeneratorPowerCabinet", "bevel",
        Vector3(1.22, 1.58, -0.29),
        Vector3(0.78, 2.18, 1.31), "armor")
    g.box("FreshGeneratorCabinetGlass",
        Vector3(1.22, 1.88, 0.41),
        Vector3(0.52, 0.55, 0.09), "glass")
    for i in range(3):
        g.box("FreshGeneratorMeterRow",
            Vector3(1.22, 1.74 + i * 0.15, 0.48),
            Vector3(0.35, 0.055, 0.05), "blue_light")
    g.poly("FreshGeneratorCoolingPod", "drum",
        Vector3(-1.20, 2.60, -0.57),
        Vector3(0.55, 0.89, 0.55), "slate")
    for i in range(3):
        g.box("FreshGeneratorHeatSink",
            Vector3(-1.20, 2.90 + i * 0.16, -0.57),
            Vector3(0.64, 0.09, 0.66), "edge")
    g.rod("FreshGeneratorPowerCable", Vector3(1.40, 0.60, 0.35),
        Vector3(1.40, 0.45, 1.39), 0.12, "rubber")


static func _storage(g: Variant) -> void:
    # Freight yard: separate stacked metal cases on a rear rack, open in front.
    _pad(g, 2.61, 2.36)
    g.poly("FreshStorageLoadPallet", "bevel",
        Vector3(0, 0.54, 0.04),
        Vector3(2.41, 0.29, 2.05), "slate")
    for side in [-1.0, 1.0]:
        for z in [-0.93, 0.98]:
            g.rod("FreshStorageRackUpright",
                Vector3(side * 1.15, 0.57, z),
                Vector3(side * 1.15, 2.65, z), 0.12, "edge")
    for y in [1.21, 2.09]:
        g.box("FreshStorageRackBeam",
            Vector3(0, y, -0.88),
            Vector3(2.44, 0.12, 0.16), "gold")
    var stacks: Array[Vector3] = [
        Vector3(-0.55, 0.91, 0.42),
        Vector3(0.49, 0.85, 0.43),
        Vector3(-0.55, 1.61, 0.28),
        Vector3(0.49, 1.50, 0.10),
        Vector3(-0.55, 2.48, -0.14),
    ]
    for i in range(stacks.size()):
        var p: Vector3 = stacks[i]
        g.poly("FreshStorageOffsetStacks", "bevel", p,
            Vector3(0.93, 0.59, 0.79),
            "crate" if i % 3 else "armor_light")
        g.box("FreshStorageCaseHandle",
            p + Vector3(0, -0.04, 0.45),
            Vector3(0.37, 0.09, 0.06), "slate")
        g.box("FreshStorageCaseLid",
            p + Vector3(0, 0.31, 0),
            Vector3(0.98, 0.08, 0.84), "armor_light")
        g.box("FreshStorageCargoPlate",
            p + Vector3(0, 0.13, 0.45),
            Vector3(0.57, 0.14, 0.055), "caution" if i % 2 else "blue")
        for side in [-1.0, 1.0]:
            g.box("FreshStorageBoxCorner",
                p + Vector3(side * 0.40, 0, 0.44),
                Vector3(0.095, 0.52, 0.075), "gold")
    for side in [-1.0, 1.0]:
        g.rod("FreshStorageLiftGuide",
            Vector3(-1.20 + side * 0.12, 0.48, 1.02),
            Vector3(-1.20 + side * 0.12, 2.48, 1.02), 0.095, "edge")
    g.poly("FreshStorageLoadingLift", "bevel",
        Vector3(-1.20, 1.01, 1.18),
        Vector3(0.55, 0.18, 0.58), "gold")
    g.box("FreshStorageLiftPower",
        Vector3(-1.20, 2.46, 1.02),
        Vector3(0.43, 0.27, 0.47), "slate")
    # Rear weather strip only; cargo must remain BELOW the edge in screen space.
    g.poly_tilt("FreshStorageShortRearTarp", "canvas",
        Vector3(0, 2.63, -1.03), Vector3(2.13, 0.12, 0.63),
        "cloth", Vector3(-0.13, 0, 0))


static func _terminal(g: Variant) -> void:
    # Slanted blueprint station; oversized readable luminous screen + keys.
    _pad(g, 2.16, 2.12)
    g.poly("FreshTerminalConsoleBase", "bevel",
        Vector3(0, 0.66, -0.20),
        Vector3(1.81, 0.75, 1.54), "slate")
    g.poly("FreshTerminalSignalBody", "bevel",
        Vector3(0, 1.79, -0.47),
        Vector3(1.97, 1.62, 0.71), "armor")
    for side in [-1.0, 1.0]:
        g.rod("FreshTerminalMonitorUpright",
            Vector3(side * 0.90, 0.60, -0.48),
            Vector3(side * 0.90, 2.73, -0.48), 0.13, "edge")
        g.box("FreshTerminalEdgeLight",
            Vector3(side * 0.88, 1.86, 0.01),
            Vector3(0.075, 0.88, 0.07), "blue_light")
    g.poly_tilt("FreshTerminalMonitorVisor", "roof",
        Vector3(0, 2.73, -0.24),
        Vector3(2.08, 0.18, 0.71), "armor_light",
        Vector3(-0.16, 0, 0))
    g.poly("FreshTerminalDisplayFrame", "bevel",
        Vector3(0, 1.91, 0.13),
        Vector3(1.90, 1.36, 0.39), "armor_light")
    g.box("FreshTerminalWideScreen",
        Vector3(0, 1.94, 0.37),
        Vector3(1.64, 1.13, 0.10), "void")
    # This is the screen itself, not just the bright blueprint strokes:
    # emissive RGB material is preserved on the opaque front glass.
    g.box("FreshTerminalLiveDisplay",
        Vector3(0, 1.94, 0.46),
        Vector3(1.49, 0.99, 0.09), "terminal_monitor")
    for i in range(4):
        g.box("FreshTerminalBlueprintRows",
            Vector3(0, 1.60 + i * 0.23, 0.53),
            Vector3(1.27, 0.032, 0.031), "blue_light")
        g.box("FreshTerminalBlueprintCols",
            Vector3(-0.45 + i * 0.30, 1.94, 0.53),
            Vector3(0.028, 0.85, 0.031), "blue")
    g.poly_tilt("FreshTerminalKeypadPlate", "bevel",
        Vector3(0, 1.05, 0.66),
        Vector3(1.83, 0.19, 0.80), "slate", Vector3(-0.24, 0, 0))
    for row in range(2):
        for col in range(5):
            g.box("FreshTerminalTactileKey",
                Vector3(-0.58 + col * 0.28, 1.14,
                    0.50 + row * 0.21),
                Vector3(0.19, 0.06, 0.12),
                "blue" if col % 3 == 0 else "edge")
    g.rod("FreshTerminalSignalMast",
        Vector3(0.85, 2.57, -0.74),
        Vector3(0.85, 3.81, -0.74), 0.10, "gold")
    g.box("FreshTerminalMastLamp",
        Vector3(0.85, 3.87, -0.74),
        Vector3(0.22, 0.22, 0.22), "amber_light")
    g.poly("FreshTerminalSideBattery", "bevel",
        Vector3(-1.00, 0.70, -0.43),
        Vector3(0.46, 0.76, 0.65), "crate")


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
