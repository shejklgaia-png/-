extends RefCounted
const CollectorCrane = preload("res://scripts/sera_base_collector_crane.gd")
const CollectorConveyor = preload("res://scripts/sera_base_collector_conveyor.gd")
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
    # Open fabrication cell, authored for the BASE camera (27 degrees, yaw 44).
    # Every mesh is a structural member, production tool, stock holder or UI.
    # Keep the existing pad, monitor mount, lamp anchor and motion identifiers.
    _pad(g, 4.16, 4.25)
    g.poly("FreshLabWorkbenchPlatform", "deck",
        Vector3(0, 0.49, 0.02), Vector3(3.86, 0.19, 3.83), "slate")
    # Low rear splash guard and a single narrow high extraction column: no
    # full-height rear wall or wide roof to hide the tools from the camera.
    g.poly("LabRearServiceShield", "deck",
        Vector3(0.25, 1.07, -1.78), Vector3(3.12, 1.00, 0.24), "armor")
    g.poly("LabExtractionTower", "vent_stack",
        Vector3(1.29, 2.00, -1.49), Vector3(0.67, 2.88, 0.67), "slate")
    g.poly("LabExtractionCollar", "drum",
        Vector3(1.29, 2.72, -1.49), Vector3(0.89, 0.34, 0.89), "edge")
    g.poly("LabFilterIntake", "louver",
        Vector3(0.84, 1.43, -1.26), Vector3(0.83, 0.64, 0.28), "trim")
    # Short extraction hood only over the rear service channel.
    g.poly("LabFumeHood", "hood",
        Vector3(0.48, 3.18, -1.08), Vector3(1.50, 0.44, 0.83), "armor_light")
    g.poly("LabHoodBrace", "gusset",
        Vector3(1.10, 2.85, -1.28), Vector3(0.63, 0.54, 0.28), "edge")
    # Material rack, on the camera-facing left of the rear zone. Two widely
    # spaced open trays and large identifiable spools; no decorative slats.
    for x in [-1.79, -0.80]:
        g.poly("LabRackUpright", "octagonal_slew",
            Vector3(x, 1.51, -0.87), Vector3(0.22, 1.86, 0.24), "trim")
        g.poly("LabRackFoot", "gusset",
            Vector3(x, 0.77, -0.64), Vector3(0.29, 0.39, 0.58), "edge")
    for y in [1.03, 2.02]:
        g.poly("LabStockRetentionTray", "tray",
            Vector3(-1.30, y, -0.84), Vector3(1.38, 0.24, 0.78), "armor_light")
    # The lower tray holds one reinforced transport cassette, not a row of jars.
    g.poly("LabRawStockCassette", "cargo_case",
        Vector3(-1.31, 1.21, -0.84), Vector3(0.99, 0.48, 0.55), "crate")
    g.box("LabCassetteLatch", Vector3(-1.30, 1.20, -0.52),
        Vector3(0.34, 0.15, 0.10), "gold")
    # Upper tray: two different feedstock forms, vertical hollow coil and
    # squat resin cartridge. Open coil bore is actual polygon geometry.
    g.poly_tilt("LabMetalFeedSpool", "vent_stack",
        Vector3(-1.62, 2.27, -0.83), Vector3(0.63, 0.38, 0.63),
        "edge", Vector3(PI * 0.5, 0, 0))
    g.poly("LabResinCartridge", "drum",
        Vector3(-0.98, 2.25, -0.83), Vector3(0.43, 0.61, 0.43), "blue")
    g.poly("LabCartridgeCap", "gear",
        Vector3(-0.98, 2.63, -0.83), Vector3(0.47, 0.15, 0.47), "armor_light")
    g.rod("LabFeedGuide", Vector3(-1.62, 2.27, -0.55),
        Vector3(-1.05, 2.57, 0.97), 0.08, "trim")
    # Offset coolant reservoir and conduit are real support equipment.
    g.poly("LabCoolantReservoir", "drum",
        Vector3(0.19, 1.31, -0.95), Vector3(0.60, 1.38, 0.60), "blue")
    g.poly("LabCoolantValve", "gear",
        Vector3(0.19, 2.02, -0.95), Vector3(0.43, 0.18, 0.43), "gold")
    g.rod("LabCoolantSupply", Vector3(0.19, 0.72, -0.67),
        Vector3(0.19, 0.72, 0.35), 0.13, "gold")
    # Main fabrication gantry: shaped cast feet, substantial guide columns,
    # and two diagonal braces on the rear side of the carriage opening.
    g.poly("LabPrinterPedestal", "octagonal_slew",
        Vector3(0.10, 0.68, 1.13), Vector3(1.65, 0.43, 1.23), "dark")
    g.poly("FreshLabFabricationBed", "tray",
        Vector3(0.10, 0.94, 1.13), Vector3(2.11, 0.24, 1.41), "armor_light")
    for side in [-1.0, 1.0]:
        var x: float = side * 1.04
        g.poly("LabPrinterCastFoot", "gusset",
            Vector3(x, 0.89, 0.77), Vector3(0.47, 0.60, 0.53), "slate")
        g.poly("FreshLabPrinterRail", "octagonal_slew",
            Vector3(x, 1.88, 0.98), Vector3(0.34, 1.63, 0.35), "armor_light")
        g.poly("LabPrinterGuideBearing", "drum",
            Vector3(x, 2.45, 0.98), Vector3(0.43, 0.32, 0.43), "edge")
        g.rod("LabPrinterDiagonalBrace", Vector3(x, 1.00, 0.28),
            Vector3(x, 2.37, 0.98), 0.19, "trim")
        g.box("FreshLabPrinterLegLight", Vector3(x, 1.88, 1.17),
            Vector3(0.13, 0.78, 0.08), "lab_cyan")
    g.poly_tilt("FreshLabOpenPrinterBridge", "octagonal_slew",
        Vector3(0, 2.64, 0.97), Vector3(0.33, 2.30, 0.37),
        "edge", Vector3(0, 0, PI * 0.5))
    # Carriage, motor and nozzle retain their existing animation feature IDs.
    g.poly_tilt("FreshLabPrinterServo", "drum",
        Vector3(0.10, 2.40, 1.05), Vector3(0.57, 0.50, 0.57),
        "slate", Vector3(0, 0, PI * 0.5))
    g.poly("FreshLabPrinterHotHead", "octagonal_slew",
        Vector3(0.10, 1.93, 1.05), Vector3(0.39, 0.61, 0.39), "gold")
    g.poly("FreshLabPrinterTip", "drum",
        Vector3(0.10, 1.55, 1.08), Vector3(0.20, 0.20, 0.20), "amber_light")
    # A recognizable hollow Shell component under manufacture, not a cube.
    g.poly("FreshLabPrintedShell", "vent_stack",
        Vector3(0.10, 1.08, 1.13), Vector3(0.74, 0.40, 0.67), "blue")
    # Preserve B03 world-monitor alignment; recess glass into a hooded
    # operator stand instead of building a second set of fake telemetry bars.
    g.poly("FreshLabServiceConsole", "gusset",
        Vector3(1.48, 0.96, 1.27), Vector3(0.56, 0.83, 0.71), "slate")
    g.poly("LabConsoleFoot", "octagonal_slew",
        Vector3(1.46, 0.63, 1.28), Vector3(0.60, 0.20, 0.60), "dark")
    g.poly("LabConsoleHood", "hood",
        Vector3(1.46, 1.61, 1.42), Vector3(0.70, 0.31, 0.54), "armor_light")
    g.box("LabConsoleScreenHousing", Vector3(1.46, 1.37, 1.53),
        Vector3(0.56, 0.50, 0.21), "dark")
    g.box("FreshLabServiceScreen", Vector3(1.46, 1.37, 1.63),
        Vector3(0.44, 0.40, 0.06), "glass")
    # Warm task luminaire and its brace use the existing VFX aiming point.
    g.rod("LabTaskLampSupport", Vector3(0.55, 3.20, -0.95),
        Vector3(0, 3.12, -0.05), 0.16, "edge")
    g.box("FreshLabWarmWorkLight", Vector3(0, 3.12, -0.05),
        Vector3(0.56, 0.19, 0.29), "amber_light")
    # Overhead two-link SCARA: fixed column, two articulated rigid beams,
    # vertical telescopic wrist, offset crossbar and two opposed jaws.
    # Rest poses are overwritten by the same BASE MultiMesh motion sampler.
    g.poly("LabArmColumnFoot", "octagonal_slew",
        Vector3(-0.43, 0.72, -0.10), Vector3(0.55, 0.28, 0.55), "dark")
    g.poly("LabArmColumn", "octagonal_slew",
        Vector3(-0.43, 2.10, -0.10), Vector3(0.31, 2.95, 0.31), "slate")
    g.poly("LabArmShoulder", "drum",
        Vector3(-0.43, 3.60, -0.10), Vector3(0.46, 0.30, 0.46), "edge")
    g.poly("LabArmLinkA", "octagonal_slew",
        Vector3(-0.9, 3.60, 0.30), Vector3(0.28, 1.30, 0.28), "gold")
    g.poly("LabArmLinkB", "octagonal_slew",
        Vector3(-0.9, 3.60, 0.60), Vector3(0.25, 1.30, 0.25), "armor_light")
    g.poly("LabArmElbow", "drum",
        Vector3(-1.25, 3.60, 0.40), Vector3(0.39, 0.34, 0.39), "edge")
    g.poly("LabArmWristHub", "drum",
        Vector3(-0.55, 3.60, 0.64), Vector3(0.31, 0.27, 0.31), "slate")
    g.poly("LabArmWristShaft", "octagonal_slew",
        Vector3(-0.55, 2.60, 0.64), Vector3(0.15, 1.70, 0.15), "edge")
    g.box("LabArmWristOffset", Vector3(-0.55, 2.24, 0.47),
        Vector3(0.23, 0.16, 0.44), "slate")
    g.poly("LabArmGripBody", "deck", Vector3(-0.55, 2.24, 0.30),
        Vector3(1.12, 0.18, 0.25), "gold")
    for side in [-1.0, 1.0]:
        g.poly("LabArmGripJaw", "deck",
            Vector3(-0.55 + side * 0.56, 1.98, 0.30),
            Vector3(0.13, 0.36, 0.36), "edge")
    # Finished stock receiver: open lift pocket and hinged safety shutters.
    # One continuous printed part is deposited, lowered into the enclosed
    # stock chamber, and only recycled after the shutters have closed.
    g.poly("LabOutputPartsTray", "tray",
        Vector3(-1.55, 0.85, 0.02), Vector3(1.04, 0.65, 0.94), "crate")
    g.poly("LabStockLift", "deck", Vector3(-1.55, 0.69, 0.02),
        Vector3(0.79, 0.10, 0.70), "slate")
    for side in [-1.0, 1.0]:
        g.box("LabStockShutter", Vector3(-1.55, 1.20, 0.02 + side * 0.235),
            Vector3(1.04, 0.09, 0.46), "armor_light")
    g.box("LabStockStatus", Vector3(-1.55, 0.98, 0.51),
        Vector3(0.46, 0.15, 0.08), "lab_cyan")


static func _collector(g: Variant) -> void:
    # Small excavator arm on a rotating carriage; claw hangs above scrap skip.
    _pad(g, 2.33, 2.24)
    # An actual eight-faced steel pedestal sits behind the yellow hopper
    # and INSIDE the 2.33 x 2.24m base. Unlike the old rectangular skirt, its
    # rear-left footprint is kept clear of all four foundation edges.
    g.poly("FreshCollectorTurntable", "octagonal_slew",
        Vector3(-0.78, 0.65, -0.48) + CollectorConveyor.CRANE_OFFSET,
        Vector3(0.66, 0.57, 0.66), "slate")
    g.poly("FreshCollectorWinchMotor", "bevel",
        Vector3(-0.74, 1.08, -0.40) + CollectorConveyor.CRANE_OFFSET,
        Vector3(0.83, 0.50, 0.72), "gold")
    g.box("FreshCollectorMotorGlow",
        Vector3(-0.75, 1.10, 0.00) + CollectorConveyor.CRANE_OFFSET,
        Vector3(0.39, 0.12, 0.07), "blue_light")
    g.poly("FreshCollectorSortPan", "hopper",
        Vector3(0.36, 0.66, 0.68), Vector3(1.78, 0.75, 1.36), "armor")
    # The generated hopper has an actual open throat; no flat cover slab.
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
    # The conveyor originates beyond the portrait left edge. Build it in the
    # collector local frame so the entire feed follows the station body yaw.
    CollectorConveyor.build(g)
    # The detailed crane now slews around the belt pickup and hopper; its
    # entire rig shares the same material-batched MultiMeshes as the belt.
    CollectorCrane.build(g)
    g.box("FreshCollectorHazardLamp",
        Vector3(-0.99, 1.44, -0.21) + CollectorConveyor.CRANE_OFFSET,
        Vector3(0.23, 0.19, 0.12), "amber_light")


static func _smelter(g: Variant) -> void:
    # Plasma-assisted thermal refinery: fixed footprint and original smoke anchors.
    _pad(g, 2.48, 2.50)
    g.poly("FreshSmelterFurnaceBase", "octagonal_slew",
        Vector3(0, 0.59, -0.12), Vector3(2.18, 0.47, 2.10), "slate")
    g.poly("FreshSmelterBlastJacket", "octagonal_slew",
        Vector3(0, 1.59, -0.23), Vector3(1.80, 1.72, 1.76), "armor")
    g.poly("FreshSmelterLowerPressureSeal", "gear",
        Vector3(0, 0.87, -0.23), Vector3(2.05, 0.25, 1.98), "trim")
    g.poly("FreshSmelterUpperCollar", "gear",
        Vector3(0, 2.47, -0.23), Vector3(2.12, 0.30, 1.99), "edge")
    g.poly("FreshSmelterMagneticConfinementCoil", "drum",
        Vector3(0, 2.73, -0.23), Vector3(1.56, 0.29, 1.56), "blue_light")
    g.poly("FreshSmelterCoilShield", "octagonal_slew",
        Vector3(0, 2.96, -0.23), Vector3(1.74, 0.25, 1.74), "slate")
    g.poly("FreshSmelterPressureCap", "hood",
        Vector3(0, 3.17, -0.26), Vector3(1.36, 0.28, 1.30), "armor_light")
    # Deep combustion cavity: back wall front z=0.79, flame z=0.92,
    # front safety cage z=1.36. Refractory returns give actual parallax.
    g.box("FreshSmelterRefractoryBacking",
        Vector3(0, 1.45, 0.73), Vector3(1.46, 1.12, 0.12), "dark")
    for side in [-1.0, 1.0]:
        g.box("FreshSmelterRefractoryReturn",
            Vector3(side * 0.65, 1.45, 1.055), Vector3(0.10, 0.99, 0.53), "dark")
        g.box("FreshSmelterHeatStainedInnerEdge",
            Vector3(side * 0.60, 1.45, 1.22), Vector3(0.035, 0.96, 0.10), "rust")
        g.poly_tilt("FreshSmelterHotThroat", "octagonal_slew",
            Vector3(side * 0.77, 1.46, 1.05), Vector3(0.30, 1.29, 0.37),
            "edge", Vector3(0, 0, -side * 0.10))
        g.poly("FreshSmelterThermalGuardFoot", "gusset",
            Vector3(side * 0.83, 0.82, 0.94),
            Vector3(0.46, 0.56, 0.68), "slate")
        g.box("FreshSmelterPortalPost",
            Vector3(side * 0.70, 1.48, 1.30),
            Vector3(0.14, 1.10, 0.24), "trim")
        g.rod("FreshSmelterRefractoryTie",
            Vector3(side * 0.70, 0.98, 1.33),
            Vector3(side * 0.79, 0.88, 0.99), 0.085, "edge")
        g.box("FreshSmelterGrate",
            Vector3(side * 0.42, 1.45, 1.36),
            Vector3(0.055, 0.89, 0.075), "trim")
        for y in [1.02, 1.91]:
            g.box("FreshSmelterGrateMount",
                Vector3(side * 0.42, y, 1.36),
                Vector3(0.12, 0.09, 0.12), "edge")
    # A projecting sill and narrow header make the guards part of a real
    # furnace assembly instead of floating bars. No central crossbar.
    g.box("FreshSmelterPortalHeader",
        Vector3(0, 1.98, 1.30), Vector3(1.49, 0.12, 0.24), "trim")
    g.box("FreshSmelterPortalSill",
        Vector3(0, 0.96, 1.34), Vector3(1.49, 0.12, 0.32), "trim")
    g.box("FreshSmelterHotInnerLip",
        Vector3(0, 1.025, 1.23), Vector3(1.22, 0.045, 0.10), "rust")
    g.poly("FreshSmelterCombustionHood", "hood",
        Vector3(0, 2.11, 0.99), Vector3(1.73, 0.28, 0.63), "armor_light")
    g.poly("FreshSmelterSlagChannel", "tray",
        Vector3(0, 0.86, 1.18), Vector3(1.46, 0.24, 0.70), "rust")
    g.box("FreshSmelterMoltenBed",
        Vector3(0, 0.99, 1.045), Vector3(1.16, 0.07, 0.45), "rust")
    g.box("FreshSmelterIncandescentFuelBed",
        Vector3(0, 1.027, 0.97), Vector3(0.96, 0.026, 0.25), "amber")
    for side in [-1.0, 1.0]:
        # Exhaust branches physically lead to two open stacks, outlet y=4.345.
        g.rod("FreshSmelterExhaustManifold",
            Vector3(side * 0.52, 2.69, -0.24),
            Vector3(side * 0.81, 2.90, -0.84), 0.27, "trim")
        g.poly("FreshSmelterTwinStacks", "vent_stack",
            Vector3(side * 0.81, 3.01, -0.84),
            Vector3(0.51, 2.67, 0.51), "slate")
        g.poly("FreshSmelterExhaustFilter", "gear",
            Vector3(side * 0.81, 3.50, -0.84),
            Vector3(0.72, 0.31, 0.72), "edge")
        g.poly("FreshSmelterExhaustCoupling", "drum",
            Vector3(side * 0.81, 2.81, -0.84),
            Vector3(0.65, 0.22, 0.65), "rust")
        g.poly("FreshSmelterCoolantReservoir", "drum",
            Vector3(side * 1.07, 1.45, -0.10),
            Vector3(0.49, 1.30, 0.49), "blue")
        for y in [0.94, 1.88]:
            g.poly("FreshSmelterCoolantClamp", "gear",
                Vector3(side * 1.07, y, -0.10),
                Vector3(0.58, 0.16, 0.58), "edge")
        g.rod("FreshSmelterCoolantReturn",
            Vector3(side * 1.07, 2.03, -0.10),
            Vector3(side * 0.73, 2.54, 0.05), 0.15, "gold")
        g.poly_tilt("FreshSmelterObliqueShield", "roof",
            Vector3(side * 1.10, 1.66, 0.43),
            Vector3(0.49, 0.18, 0.64), "armor_light",
            Vector3(-0.10, 0.0, -side * 0.30))
        g.box("FreshSmelterCoolantStatus",
            Vector3(side * 1.10, 1.60, 0.54),
            Vector3(0.18, 0.34, 0.075), "blue_light")
    g.poly("FreshSmelterSideController", "gusset",
        Vector3(-1.06, 0.88, 0.69),
        Vector3(0.38, 0.62, 0.43), "slate")
    g.box("FreshSmelterControllerLamp",
        Vector3(-1.06, 1.03, 0.94),
        Vector3(0.21, 0.13, 0.06), "blue_light")
    # Charge and casting mould on the refractory apron.
    g.poly("SmelterChargeRail", "tray", Vector3(-0.35, 0.89, 1.63),
        Vector3(0.61, 0.18, 0.65), "trim")
    g.poly("SmelterCastingMould", "tray", Vector3(0.39, 0.88, 1.62),
        Vector3(0.62, 0.19, 0.65), "dark")
    g.rod("SmelterCastingSpout", Vector3(0.32, 1.03, 1.14),
        Vector3(0.39, 0.98, 1.47), 0.12, "rust")
    for i in range(3):
        g.poly_tilt("SmelterFeedScrap", "bevel",
            Vector3(-0.35 + float(i-1)*0.14, 1.05, 1.68),
            Vector3(0.16, 0.19, 0.25), "edge" if i == 1 else "rust",
            Vector3(0.12, float(i)*0.4, 0.12))
    g.box("SmelterMoltenPour", Vector3(0.39, 0.98, 1.62),
        Vector3(0.44, 0.035, 0.43), "amber")
    for i in range(2):
        g.poly("SmelterCastIngot", "bevel", Vector3(0.39, 1.03, 1.50+float(i)*0.23),
            Vector3(0.43, 0.14, 0.18), "edge")
    g.poly("FreshSmelterDischargedSlag", "cargo_case",
        Vector3(0.77, 0.55, 1.35), Vector3(0.39, 0.28, 0.38), "rust")


static func _recycler(g: Variant) -> void:
    # Open gravity feed -> twin cutter shafts -> low discharge chute.
    # The shafts stay at the exact existing motion pivots.
    _pad(g, 2.50, 2.45)
    for side in [-1.0, 1.0]:
        g.poly("FreshRecyclerLoadBearingSkid", "deck",
            Vector3(side * 0.87, 0.58, -0.12),
            Vector3(0.48, 0.32, 2.08), "edge")
        g.poly("FreshRecyclerCastBearingHousing", "octagonal_slew",
            Vector3(side * 1.12, 1.37, 0.22),
            Vector3(0.86, 0.40, 1.70), "armor")
        # The side plates rise and flare outward, leaving the two cutters visible.
        g.box_tilt("FreshRecyclerHopperWall",
            Vector3(side * 1.07, 1.95, 0.22),
            Vector3(0.15, 1.10, 1.93), "armor_light",
            Vector3(0, 0, -side * 0.34))
        g.rod("FreshRecyclerHopperLip",
            Vector3(side * 1.25, 2.47, -0.76),
            Vector3(side * 1.25, 2.47, 1.20), 0.15, "caution")
        g.poly("FreshRecyclerWebReinforcement", "gusset",
            Vector3(side * 1.20, 1.62, -0.45),
            Vector3(0.36, 0.73, 0.19), "trim", PI if side < 0.0 else 0.0)
        g.poly("FreshRecyclerMotorCoolingShell", "vent_stack",
            Vector3(side * 1.12, 0.90, -0.72),
            Vector3(0.50, 0.65, 0.50), "slate")
        for line in [-1.0, 1.0]:
            g.poly_tilt("FreshRecyclerShaftBearing", "drum",
                Vector3(side * 1.13, 1.37, 0.22 + line * 0.39),
                Vector3(0.61, 0.29, 0.61), "edge", Vector3(0, 0, PI * 0.5))
    g.box_tilt("FreshRecyclerRearGravityFeed",
        Vector3(0, 1.98, -0.79), Vector3(2.03, 0.14, 0.98),
        "slate", Vector3(0.73, 0, 0))
    g.box("FreshRecyclerRearFeedLip",
        Vector3(0, 2.30, -1.12), Vector3(2.22, 0.15, 0.15), "caution")
    for line in [-1.0, 1.0]:
        var z: float = 0.22 + line * 0.39
        g.poly_tilt("FreshRecyclerRoller", "drum",
            Vector3(0, 1.37, z), Vector3(0.48, 2.11, 0.48), "edge",
            Vector3(0, 0, PI * 0.5))
        # Staggered disks on the opposing shafts interleave axially.
        for i in range(6):
            var x: float = -0.88 + float(i) * 0.29 + (0.145 if line > 0.0 else 0.0)
            g.poly_tilt("FreshRecyclerTooth", "gear",
                Vector3(x, 1.37, z), Vector3(0.78, 0.13, 0.78),
                "armor_light", Vector3(0, 0, PI * 0.5))
    # A dark lower throat and an open outlet, not a solid decorative block.
    g.box("FreshRecyclerThroatShadow",
        Vector3(0, 0.89, -0.43), Vector3(1.50, 0.47, 0.13), "void")
    g.box_tilt("FreshRecyclerDischargeChute",
        Vector3(0, 0.82, 0.80), Vector3(1.52, 0.13, 1.41),
        "slate", Vector3(0.34, 0, 0))
    for side in [-1.0, 1.0]:
        g.box_tilt("FreshRecyclerDischargeSidewall",
            Vector3(side * 0.80, 0.94, 0.80),
            Vector3(0.13, 0.30, 1.43), "armor", Vector3(0.34, 0, 0))
    g.box("FreshRecyclerOutletWearEdge",
        Vector3(0, 0.59, 1.48), Vector3(1.72, 0.11, 0.13), "gold")
    # Intact salvage travels from rear gravity feed through the cutters.
    for i in range(2):
        g.poly_tilt("RecyclerIntactPart", "bevel",
            Vector3(-0.32 + 0.64*float(i), 2.23, -0.85),
            Vector3(0.40, 0.33, 0.46), "rust" if i == 0 else "armor",
            Vector3(0.15, 0.25*float(i), 0.1))
    g.poly("RecyclerRecoveredPart", "gear", Vector3(-0.43, 0.87, 0.77),
        Vector3(0.29, 0.14, 0.29), "edge")
    g.box("RecyclerRecoveredPart", Vector3(0, 0.89, 0.72),
        Vector3(0.32, 0.11, 0.25), "blue")
    g.poly_tilt("RecyclerRecoveredPart", "drum", Vector3(0.40, 0.93, 0.64),
        Vector3(0.23, 0.25, 0.23), "gold", Vector3(0, 0, PI*0.5))
    g.poly("FreshRecyclerControlInterlock", "deck",
        Vector3(1.08, 1.03, 1.12), Vector3(0.35, 0.44, 0.33), "armor")
    g.box("FreshRecyclerInterlockLamp",
        Vector3(1.08, 1.12, 1.30), Vector3(0.20, 0.11, 0.07), "amber_light")


static func _generator(g: Variant) -> void:
    # Power regulation: a suspended horizontal rotor, transformer bank,
    # a separate switching cabinet and physically connected cooling loop.
    _pad(g, 2.55, 2.38)
    for z in [-0.73, 0.71]:
        g.poly("FreshGeneratorIsolationSkid", "deck",
            Vector3(-0.21, 0.57, z), Vector3(2.34, 0.30, 0.39), "edge")
    for side in [-1.0, 1.0]:
        var x: float = side * 0.91 - 0.25
        g.poly("FreshGeneratorBearingPedestal", "gusset",
            Vector3(x, 0.88, 0.30), Vector3(0.50, 0.71, 0.88), "armor")
        g.poly_tilt("FreshGeneratorBearing", "octagonal_slew",
            Vector3(x, 1.43, 0.29), Vector3(1.37, 0.32, 1.37),
            "armor_light", Vector3(0, 0, PI * 0.5))
        g.rod("FreshGeneratorLoadBrace",
            Vector3(x, 0.67, -0.72), Vector3(x, 1.43, 0.29), 0.16, "trim")
    # Bus duct from the right-hand bearing to the isolated switching cabinet.
    g.rod("FreshGeneratorCopperBus",
        Vector3(0.77, 1.43, 0.29), Vector3(1.22, 1.43, 0.29), 0.19, "gold")
    # Rotor axis is horizontal and the near-side ribs show true cylindrical depth.
    g.poly_tilt("FreshGeneratorFrontRotor", "vent_stack",
        Vector3(-0.27, 1.43, 0.29),
        Vector3(1.11, 2.30, 1.11), "blue",
        Vector3(0, 0, PI * 0.5))
    # Four real radial bands are enough now that the drum itself has
    # raised machined collars; the previous six hid too much of the core.
    for i in range(4):
        g.poly_tilt("FreshGeneratorCoreRib", "drum",
            Vector3(-0.93 + i * 0.44, 1.43, 0.29),
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
    # The actual four open channels between the five steel louvers:
    # each thin emitter is centered in the 0.073m vertical opening.
    # Keep the LED face behind the grille's front depth (z=1.144).
    # All leak bars use the existing generator_emitter MultiMesh batch;
    # this adds no new SpotLights or individual mesh draw calls.
    for i in range(4):
        g.box("FreshGeneratorRotorGapLeak",
            Vector3(-0.27, 1.22 + float(i) * 0.14, 1.095),
            Vector3(1.44, 0.050, 0.020), "generator_emitter")
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
    # An open top frame exposes the rotor and the voltage-regulation coils.
    g.rod("FreshGeneratorUpperRail",
        Vector3(-1.19, 2.19, -0.57), Vector3(0.71, 2.19, -0.57), 0.16, "armor_light")
    for x in [-0.76, -0.14, 0.48]:
        g.poly("FreshGeneratorRegulatorCore", "drum",
            Vector3(x, 2.36, -0.61), Vector3(0.44, 0.47, 0.44), "slate")
        for y in [2.24, 2.39, 2.53]:
            g.poly("FreshGeneratorCoilTurn", "drum",
                Vector3(x, y, -0.61), Vector3(0.52, 0.10, 0.52), "gold")
        g.box("FreshGeneratorInsulatedTerminal",
            Vector3(x, 2.65, -0.61), Vector3(0.16, 0.15, 0.16), "edge")
    g.rod("FreshGeneratorHighVoltageBus",
        Vector3(-0.76, 2.73, -0.61), Vector3(1.22, 2.73, -0.61), 0.12, "gold")
    g.poly("FreshGeneratorPowerCabinet", "deck",
        Vector3(1.22, 1.58, -0.29), Vector3(0.78, 2.18, 1.31), "armor")
    g.poly("FreshGeneratorCabinetCoolingIntake", "louver",
        Vector3(1.22, 0.92, 0.40), Vector3(0.54, 0.48, 0.12), "edge")
    g.poly("FreshGeneratorSwitchIsolator", "octagonal_slew",
        Vector3(1.22, 2.74, -0.61), Vector3(0.40, 0.23, 0.40), "edge")
    g.box("FreshGeneratorCabinetGlass",
        Vector3(1.22, 1.88, 0.41),
        Vector3(0.52, 0.55, 0.09), "glass")
    for i in range(3):
        g.box("FreshGeneratorMeterRow",
            Vector3(1.22, 1.74 + i * 0.15, 0.48),
            Vector3(0.35, 0.055, 0.05), "blue_light")
    # Line up luminous filaments with the four actual cut-outs created
    # by BaseFacilityVFX._generator_vent_slit. The metal lips remain
    # closer to the camera than these two fine cores in each vent.
    for row in range(4):
        for filament in [-1.0, 1.0]:
            g.box("FreshGeneratorCabinetSlotLeak",
                Vector3(1.22,
                    1.70 + float(row) * 0.125 + filament * 0.017,
                    0.517),
                Vector3(0.36, 0.010, 0.014), "generator_emitter")
    g.poly("FreshGeneratorCoolingPod", "vent_stack",
        Vector3(-1.20, 2.60, -0.57), Vector3(0.55, 0.89, 0.55), "slate")
    g.rod("FreshGeneratorCoolantReturn",
        Vector3(-1.20, 2.22, -0.57), Vector3(-1.20, 1.43, 0.29), 0.16, "trim")
    g.poly("FreshGeneratorCoolantPump", "drum",
        Vector3(-1.20, 1.00, -0.57), Vector3(0.38, 0.38, 0.38), "edge")
    for i in range(3):
        g.box("FreshGeneratorHeatSink",
            Vector3(-1.20, 2.90 + i * 0.16, -0.57),
            Vector3(0.64, 0.09, 0.66), "edge")
    # Two emission strips sit in the visible gaps between the heat
    # sinks, recessed behind their front (+Z) metal edges.
    for i in range(2):
        g.box("FreshGeneratorCoolingGapLeak",
            Vector3(-1.20, 2.98 + float(i) * 0.16, -0.255),
            Vector3(0.50, 0.036, 0.018), "generator_emitter")
    g.rod("FreshGeneratorPowerCable", Vector3(1.40, 0.60, 0.35),
        Vector3(1.40, 0.45, 1.39), 0.12, "rubber")


# Common physical packaging: warehouse shelves and moving logistics pallets.
static func storage_cargo(g: Variant, p: Vector3, factor: float, column: int, row: int) -> void:
    g.poly("FreshStorageCargoCase", "cargo_case", p,
        Vector3(0.94, 0.58, 0.90) * factor, "crate" if column == 0 else "armor_light")
    g.box("FreshStorageCargoLock", p + Vector3(0, -0.07, 0.47) * factor,
        Vector3(0.32, 0.13, 0.07) * factor, "edge")
    g.box("FreshStorageCargoID", p + Vector3(0.19, 0.14, 0.47) * factor,
        Vector3(0.32, 0.15, 0.06) * factor, "caution" if row == 0 else "blue")


static func _storage(g: Variant) -> void:
    # Rear storage rack and clear forward loading apron, with rail-guided lift.
    _pad(g, 2.61, 2.36)
    g.poly("FreshStorageLoadingDeck", "deck",
        Vector3(0, 0.52, 0.02), Vector3(2.45, 0.25, 2.16), "slate")
    for side in [-1.0, 1.0]:
        for z in [-1.00, 0.22]:
            g.rod("FreshStorageRackColumn",
                Vector3(side * 1.13, 0.64, z),
                Vector3(side * 1.13, 2.65, z), 0.16, "edge")
        g.rod("FreshStorageDiagonalBrace",
            Vector3(side * 1.13, 0.66, -1.00),
            Vector3(side * 1.13, 2.59, 0.22), 0.11, "trim")
        g.rod("FreshStorageForwardLampSupport",
            Vector3(side * 1.11, 2.61, 0.22),
            Vector3(side * 1.11, 2.79, 1.11), 0.13, "edge")
    for y in [0.68, 1.59]:
        g.poly("FreshStorageLoadRatedShelf", "deck",
            Vector3(0, y, -0.39), Vector3(2.26, 0.14, 1.20), "trim")
        g.box("FreshStorageShelfFrontBeam",
            Vector3(0, y, 0.26), Vector3(2.37, 0.16, 0.12), "gold")
        for x in [-0.73, 0.0, 0.73]:
            g.box("FreshStoragePalletStop",
                Vector3(x, y + 0.10, -0.91), Vector3(0.12, 0.14, 0.16), "edge")
    # Four cargo cases rest directly on their shelves. No floating boxes.
    for row in range(2):
        for col in range(2):
            var p := Vector3(-0.55 + float(col) * 1.10,
                1.04 + float(row) * 0.91, -0.38)
            if row == 1 and col == 0:
                continue
            storage_cargo(g, p, 1.0, col, row)
    g.rod("FreshStorageRearCrossBrace",
        Vector3(-1.13, 0.67, -1.03),
        Vector3(1.13, 2.61, -1.03), 0.11, "edge")
    g.rod("FreshStorageRearCrossBrace",
        Vector3(1.13, 0.67, -1.03),
        Vector3(-1.13, 2.61, -1.03), 0.11, "edge")
    g.poly_tilt("FreshStorageWeatherCanopy", "roof",
        Vector3(0, 2.64, -0.81), Vector3(2.45, 0.19, 0.62),
        "armor", Vector3(-0.13, 0, 0))
    # Lift has a dedicated shaft, motor, and moving load tray.
    for side in [-1.0, 1.0]:
        g.rod("FreshStorageLiftGuide",
            Vector3(-1.20 + side * 0.15, 0.60, 1.02),
            Vector3(-1.20 + side * 0.15, 2.48, 1.02), 0.10, "edge")
    g.poly("FreshStorageLiftDrive", "drum",
        Vector3(-1.20, 2.46, 1.02), Vector3(0.39, 0.30, 0.39), "slate")
    g.poly("FreshStorageLiftDriveVent", "louver",
        Vector3(-1.20, 2.46, 1.26), Vector3(0.31, 0.18, 0.12), "edge")
    g.poly("FreshStorageLoadingLift", "tray",
        Vector3(-1.20, 1.01, 1.18), Vector3(0.60, 0.16, 0.65), "gold")
    g.poly("StorageMovingCase", "cargo_case", Vector3(-1.20, 1.27, 1.18),
        Vector3(0.55, 0.36, 0.52), "crate")
    g.box("StorageMovingLock", Vector3(-1.20, 1.22, 1.46),
        Vector3(0.25, 0.09, 0.05), "gold")
    g.box("StorageTransferFork", Vector3(-1.20, 1.06, 1.18),
        Vector3(0.45, 0.06, 0.54), "edge")
    g.poly("StorageStoredCase", "cargo_case", Vector3(-0.55, 1.84, -0.38),
        Vector3(0.55, 0.36, 0.52), "crate")
    g.box("StorageStoredLock", Vector3(-0.55, 1.79, -0.10),
        Vector3(0.25, 0.09, 0.05), "gold")
    # Empty pallet lanes in front of the cases indicate the loading route.
    for x in [-0.38, 0.70]:
        g.box("FreshStorageLoadingLane",
            Vector3(x, 0.66, 0.79), Vector3(0.075, 0.025, 0.71), "caution")
    g.box("FreshStorageDockBumper",
        Vector3(0.25, 0.65, 1.13), Vector3(1.50, 0.13, 0.12), "rubber")


static func _terminal(g: Variant) -> void:
    # Heavy construction commissioning cell. +Z is the working front.
    # Rear blueprint display remains on the existing animated material mapping.
    # An open front assembly jig and an articulated hydraulic handling arm
    # distinguish this from an ordinary information terminal.
    _pad(g, 2.16, 2.12)
    g.poly("FreshBuildLoadBed", "bevel",
        Vector3(0, 0.57, 0.06), Vector3(2.06, 0.30, 1.90), "dark")
    g.poly("FreshBuildJigDeck", "deck",
        Vector3(0, 0.76, 0.46), Vector3(1.43, 0.14, 0.99), "slate")
    for side in [-1.0, 1.0]:
        # Solid load path from bed to shoulder; the open middle remains visible.
        g.poly("FreshBuildFootCasting", "gusset",
            Vector3(side * 0.85, 0.79, -0.48), Vector3(0.43, 0.62, 0.86), "armor")
        g.poly("FreshBuildRearTower", "bevel",
            Vector3(side * 0.84, 1.86, -0.60), Vector3(0.40, 2.52, 0.58), "slate")
        g.poly("FreshBuildTowerShoulder", "gusset",
            Vector3(side * 0.84, 2.78, -0.48), Vector3(0.47, 0.70, 0.73), "armor_light")
        g.rod("FreshBuildTowerDiagonal",
            Vector3(side * 0.86, 0.75, 0.07),
            Vector3(side * 0.86, 2.19, -0.62), 0.12, "edge")
        g.poly("FreshBuildHydraulicService", "vent_stack",
            Vector3(side * 0.84, 1.24, -0.20), Vector3(0.34, 0.58, 0.36), "armor")
        g.box("FreshBuildFixtureRail",
            Vector3(side * 0.63, 0.85, 0.54), Vector3(0.13, 0.11, 0.88), "edge")
        g.poly("FreshBuildRailStop", "bevel",
            Vector3(side * 0.63, 0.90, 0.94), Vector3(0.27, 0.21, 0.17), "caution")
        g.box("FreshBuildBedStripe",
            Vector3(side * 0.79, 0.70, 0.99), Vector3(0.29, 0.14, 0.045), "gold")
    # Armored rear planning screen; retain the mapped display plane exactly.
    g.poly("FreshTerminalDisplayBack", "deck",
        Vector3(0, 1.94, -0.03), Vector3(1.92, 1.43, 0.36), "armor")
    g.box("FreshTerminalWideScreen",
        Vector3(0, 1.94, 0.37), Vector3(1.64, 1.13, 0.10), "void")
    g.box("FreshTerminalLiveDisplay",
        Vector3(0, 1.94, 0.46), Vector3(1.49, 0.99, 0.09), "terminal_monitor")
    for side in [-1.0, 1.0]:
        g.poly("FreshBuildScreenCheek", "bevel",
            Vector3(side * 0.87, 1.94, 0.28), Vector3(0.20, 1.43, 0.43), "armor_light")
        g.box("FreshBuildScreenStatus",
            Vector3(side * 0.87, 1.94, 0.52), Vector3(0.065, 0.74, 0.06), "blue_light")
    g.poly("FreshBuildHeader", "bevel",
        Vector3(0, 2.67, 0.08), Vector3(1.98, 0.25, 0.71), "slate")
    g.box("FreshBuildHeaderLight",
        Vector3(0, 2.63, 0.46), Vector3(0.88, 0.07, 0.07), "blue_light")
    g.poly("FreshBuildCrownCrossmember", "bevel",
        Vector3(0, 3.19, -0.57), Vector3(2.08, 0.40, 0.60), "armor")
    g.poly("FreshBuildCrownDrive", "vent_stack",
        Vector3(0.13, 3.49, -0.56), Vector3(0.79, 0.28, 0.47), "slate")
    # Off-center optical surveying head. It reads as a rugged tool, not an aerial.
    g.poly("FreshBuildSurveyBracket", "gusset",
        Vector3(-0.69, 3.43, -0.10), Vector3(0.44, 0.42, 0.65), "armor")
    g.poly_tilt("FreshBuildSurveyHead", "drum",
        Vector3(-0.69, 3.54, 0.26), Vector3(0.42, 0.36, 0.42),
        "dark", Vector3(PI * 0.5, 0, 0))
    g.box("FreshBuildSurveyLens",
        Vector3(-0.69, 3.54, 0.47), Vector3(0.20, 0.20, 0.06), "blue_light")
    g.poly("FreshBuildWorkBeacon", "octagonal_slew",
        Vector3(0.83, 3.49, -0.57), Vector3(0.27, 0.22, 0.27), "amber_light")
    # A compact slab fixture with visible foundation sockets and a central
    # structural module. Keep the front and all four corners visually open.
    g.poly("FreshBuildModuleBase", "bevel",
        Vector3(-0.15, 0.91, 0.53), Vector3(0.69, 0.16, 0.66), "armor_light")
    for side in [-1.0, 1.0]:
        for end in [-1.0, 1.0]:
            g.poly("FreshBuildModuleSocket", "octagonal_slew",
                Vector3(-0.15 + side * 0.24, 1.01, 0.53 + end * 0.22),
                Vector3(0.15, 0.12, 0.15), "dark")
        g.poly("FreshBuildModuleRib", "gusset",
            Vector3(-0.15 + side * 0.22, 1.09, 0.53),
            Vector3(0.16, 0.31, 0.38), "slate")
    g.poly("FreshBuildModuleLock", "bevel",
        Vector3(-0.15, 1.17, 0.53), Vector3(0.38, 0.19, 0.39), "armor")
    # Visible two-link arm, pivots and telescopic cylinder, on the right side
    # of the jig. Its working envelope stays below the live monitor.
    g.poly("FreshBuildArmTurret", "octagonal_slew",
        Vector3(0.79, 0.91, 0.37), Vector3(0.48, 0.26, 0.48), "dark")
    g.poly("FreshBuildArmShoulder", "bevel",
        Vector3(0.79, 1.11, 0.37), Vector3(0.31, 0.27, 0.34), "armor")
    g.rod("FreshBuildArmUpperLink",
        Vector3(0.79, 1.14, 0.37), Vector3(0.74, 1.53, 0.78), 0.15, "armor_light")
    g.rod("FreshBuildArmCylinder",
        Vector3(0.91, 1.03, 0.34), Vector3(0.88, 1.37, 0.65), 0.095, "dark")
    g.rod("FreshBuildArmPiston",
        Vector3(0.88, 1.37, 0.65), Vector3(0.85, 1.53, 0.78), 0.055, "edge")
    g.poly_tilt("FreshBuildArmElbow", "drum",
        Vector3(0.74, 1.53, 0.78), Vector3(0.27, 0.26, 0.27),
        "slate", Vector3(0, 0, PI * 0.5))
    g.rod("FreshBuildArmForelink",
        Vector3(0.74, 1.53, 0.78), Vector3(0.06, 1.53, 0.57), 0.13, "armor_light")
    g.poly("FreshBuildArmToolChuck", "octagonal_slew",
        Vector3(0.06, 1.49, 0.57), Vector3(0.24, 0.19, 0.24), "dark")
    for side in [-1.0, 1.0]:
        g.rod("FreshBuildArmClampJaw",
            Vector3(0.06 + side * 0.09, 1.44, 0.57),
            Vector3(0.06 + side * 0.13, 1.34, 0.57), 0.045, "gold")
    # Compact operator input pod on the other side, rather than a full
    # counter blocking the manufacturing bed.
    g.poly_tilt("FreshBuildControlPod", "deck",
        Vector3(-0.80, 1.18, 0.37), Vector3(0.41, 0.19, 0.40),
        "armor", Vector3(-0.24, 0, 0))
    g.box("FreshBuildControlStatus",
        Vector3(-0.80, 1.29, 0.30), Vector3(0.24, 0.06, 0.09), "blue_light")
    g.poly("FreshBuildControlDial", "gear",
        Vector3(-0.80, 1.31, 0.49), Vector3(0.20, 0.10, 0.20), "edge")


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
