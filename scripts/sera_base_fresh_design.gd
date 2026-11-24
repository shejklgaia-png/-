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
        Vector3(-0.43, 2.02, -0.10), Vector3(0.31, 2.77, 0.31), "slate")
    g.poly("LabArmShoulder", "drum",
        Vector3(-0.43, 3.45, -0.10), Vector3(0.46, 0.30, 0.46), "edge")
    g.poly("LabArmLinkA", "octagonal_slew",
        Vector3(-0.9, 3.45, 0.30), Vector3(0.28, 1.25, 0.28), "gold")
    g.poly("LabArmLinkB", "octagonal_slew",
        Vector3(-0.9, 3.45, 0.60), Vector3(0.25, 1.25, 0.25), "armor_light")
    g.poly("LabArmElbow", "drum",
        Vector3(-1.25, 3.45, 0.40), Vector3(0.39, 0.34, 0.39), "edge")
    g.poly("LabArmWristHub", "drum",
        Vector3(-0.55, 3.45, 0.64), Vector3(0.31, 0.27, 0.31), "slate")
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
        Vector3(-1.55, 0.85, 0.32), Vector3(0.98, 0.65, 1.00), "crate")
    g.poly("LabStockLift", "deck", Vector3(-1.55, 0.69, 0.32),
        Vector3(0.79, 0.10, 0.83), "slate")
    for side in [-1.0, 1.0]:
        g.box("LabStockShutter", Vector3(-1.55, 1.20, 0.32 + side * 0.25),
            Vector3(0.98, 0.09, 0.49), "armor_light")
    g.box("LabStockStatus", Vector3(-1.55, 0.98, 0.84),
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
        g.poly("FreshSmelterTwinStacks", "vent_stack",
            Vector3(side * 0.81, 3.01, -0.84),
            Vector3(0.51, 2.67, 0.51), "slate")
        # Raised collars are welded into the hollow stack mesh; no
        # duplicate eight-piece rim or floating decorative rivet.
        g.box("FreshSmelterSideCoolingPanel",
            Vector3(side * 1.11, 1.32, -0.08),
            Vector3(0.24, 0.96, 1.07), "trim")
        g.poly("FreshSmelterCoolingIntake", "louver",
            Vector3(side * 1.11, 1.36, 0.56),
            Vector3(0.27, 0.78, 0.19), "edge")
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
        g.poly("FreshRecyclerDriveIntake", "louver",
            Vector3(side * 1.21, 1.13, 0.33),
            Vector3(0.25, 0.63, 0.18), "trim")
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
    g.poly("FreshGeneratorCoolingPod", "drum",
        Vector3(-1.20, 2.60, -0.57),
        Vector3(0.55, 0.89, 0.55), "slate")
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
        g.poly("FreshStorageOffsetStacks", "cargo_case", p,
            Vector3(0.93, 0.59, 0.79),
            "crate" if i % 3 else "armor_light")
        g.box("FreshStorageCaseHandle",
            p + Vector3(0, -0.04, 0.45),
            Vector3(0.37, 0.09, 0.06), "slate")
        # Case lip and welded corner guards now share the body mesh.
        g.box("FreshStorageCargoPlate",
            p + Vector3(0, 0.13, 0.45),
            Vector3(0.57, 0.14, 0.055), "caution" if i % 2 else "blue")
    for side in [-1.0, 1.0]:
        g.rod("FreshStorageLiftGuide",
            Vector3(-1.20 + side * 0.12, 0.48, 1.02),
            Vector3(-1.20 + side * 0.12, 2.48, 1.02), 0.095, "edge")
    g.poly("FreshStorageLiftDriveVent", "louver",
        Vector3(-1.20, 2.46, 1.29), Vector3(0.31, 0.18, 0.12), "edge")
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
    g.poly_tilt("FreshTerminalKeypadPlate", "tray",
        Vector3(0, 1.05, 0.66),
        Vector3(1.83, 0.19, 0.80), "slate", Vector3(-0.24, 0, 0))
    for row in range(2):
        for col in range(5):
            g.box("FreshTerminalTactileKey",
                Vector3(-0.58 + col * 0.28, 1.14,
                    0.50 + row * 0.21),
                Vector3(0.19, 0.06, 0.12),
                "blue" if col % 3 == 0 else "edge")
    g.poly("FreshTerminalChassisLouver", "louver",
        Vector3(0, 0.74, 0.68), Vector3(0.88, 0.29, 0.14), "trim")
    g.rod("FreshTerminalSignalMast",
        Vector3(0.85, 2.57, -0.74),
        Vector3(0.85, 3.81, -0.74), 0.10, "gold")
    g.box("FreshTerminalMastLamp",
        Vector3(0.85, 3.87, -0.74),
        Vector3(0.22, 0.22, 0.22), "amber_light")
    g.poly("FreshTerminalSideBattery", "cargo_case",
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
