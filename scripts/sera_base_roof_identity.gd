extends RefCounted
## SERA BASE roof readability, revision 2.
## Keep active machinery exposed: one easy-to-read silhouette per facility.
## This intentionally REPLACES the former layered roof identity pass.
## Existing opaque MultiMesh/materials only, no new nodes or draw passes.
## All coordinates are LOCAL: the working entrance faces +Z.

static func _nexus(g: Variant) -> void:
    # A simple flat industrial roof and strong entrance direction marker.
    # No extra upper crown, tower or nested secondary roof is required.
    g.box("NexusRoofCommandStripe", Vector3(0.0, 4.70, 2.23),
        Vector3(3.22, 0.12, 0.18), "armor_light")
    g.box("NexusEntranceDirectionBand", Vector3(0.0, 3.22, 2.80),
        Vector3(2.40, 0.13, 0.10), "blue_light")
    for side in [-1.0, 1.0]:
        g.box("NexusRoofCornerAnchor",
            Vector3(side * 2.70, 4.74, 2.31),
            Vector3(0.17, 0.20, 0.19), "trim")


    # Command hub: the door remains the main visual anchor, not the roof.
    g.box("NexusDoorOuterHeader", Vector3(0.0, 3.05, 3.02),
        Vector3(3.12, 0.20, 0.19), "armor_light")
    for side in [-1.0, 1.0]:
        g.box("NexusDoorOuterFrame", Vector3(side * 1.43, 1.59, 3.00),
            Vector3(0.22, 2.72, 0.22), "slate")
        g.box("NexusDoorGuideLight", Vector3(side * 1.32, 1.68, 3.13),
            Vector3(0.055, 1.51, 0.045), "blue_light")
        g.box("NexusPortalCornerBeacon", Vector3(side * 1.43, 3.12, 3.11),
            Vector3(0.19, 0.13, 0.11), "amber_light")


static func _labo(g: Variant) -> void:
    # A single rear lean-to sheet; leave the FRONT half of the workshop open
    # so benches, printer and inner lighting are visible in portrait view.
    g.box_tilt("LabSingleSlopeCanopy",
        Vector3(0.0, 3.54, -0.95), Vector3(3.82, 0.12, 1.75),
        "cloth", Vector3(-0.15, 0.0, 0.0))
    g.box("LabSideRoll", Vector3(-1.84, 3.48, -1.01),
        Vector3(0.21, 0.26, 1.38), "rust")
    for side in [-1.0, 1.0]:
        g.rod("LabCanopyOpenPost",
            Vector3(side * 1.86, 0.37, -0.32),
            Vector3(side * 1.86, 3.44, -0.32), 0.085, "edge")
    g.box("LabCanopySingleEave",
        Vector3(0.0, 3.35, -0.07),
        Vector3(3.80, 0.10, 0.13), "armor_light")


    # Open fabrication cell: a visible printer bridge and toolhead below
    # the shallow rear tarp. The entire front remains unobstructed.
    # ONE clear industrial printer cell: cool-blue parallel uprights,
    # single overhead slide, amber deposition head, contrasting print bed.
    # The earlier three crossing gantries are retired.
    g.box("LabWorkcellGantryHeader", Vector3(0.0, 2.67, 1.47),
        Vector3(2.34, 0.17, 0.19), "armor_light")
    for side in [-1.0, 1.0]:
        g.rod("LabPrintRailUpright",
            Vector3(side * 1.04, 0.75, 1.49),
            Vector3(side * 1.04, 2.66, 1.49), 0.15, "blue")
        g.box("LabPrintRailAccent",
            Vector3(side * 1.05, 1.79, 1.61),
            Vector3(0.10, 1.48, 0.08), "blue_light")
    g.box("LabPrinterToolhead", Vector3(0.18, 2.25, 1.67),
        Vector3(0.87, 0.47, 0.46), "slate")
    g.box("LabPrinterFrontHousing", Vector3(0.18, 2.03, 1.99),
        Vector3(0.72, 0.47, 0.16), "blue")
    g.box("LabPrinterNozzle", Vector3(0.18, 1.67, 2.04),
        Vector3(0.31, 0.34, 0.16), "amber_light")
    g.box("LabFocalPrintBed", Vector3(0.18, 0.94, 1.79),
        Vector3(1.68, 0.18, 0.98), "slate")
    g.box("LabPrinterWorkSurface", Vector3(0.18, 1.04, 1.84),
        Vector3(1.35, 0.11, 0.73), "armor_light")
    g.poly("LabPrinterPrintedPart", "bevel",
        Vector3(0.18, 1.20, 1.91), Vector3(0.47, 0.28, 0.43), "blue")
    g.box("LabCanopyHazardHem", Vector3(0.0, 3.32, 0.08),
        Vector3(3.72, 0.09, 0.09), "caution")


static func _collector(g: Variant) -> void:
    # OPEN hydraulic crane: a marked crossbeam, not a box or roof over the claw.
    g.rod("CollectorOpenBoomCrossbar",
        Vector3(-0.93, 2.70, -0.94),
        Vector3(0.31, 2.70, -0.94), 0.075, "slate")
    for side in [-1.0, 1.0]:
        g.rod("CollectorBoomSideStay",
            Vector3(side * 0.81, 2.70, -1.15),
            Vector3(side * 0.86, 1.31, -1.09), 0.052, "slate")
    g.box("CollectorCraneMarker",
        Vector3(-0.81, 2.84, -0.94),
        Vector3(0.30, 0.18, 0.19), "caution")


    # The overhead gantry ends in unmistakable oversized open grabber jaws.
    # Do not put an opaque shed above the claw / sorting hopper.
    g.poly("CollectorCranePivotArmor", "bevel",
        Vector3(-0.60, 2.23, -0.33),
        Vector3(0.53, 0.42, 0.52), "gold")
    g.box("CollectorCraneHydraulicStrip",
        Vector3(-0.62, 2.42, -0.01),
        Vector3(0.30, 0.11, 0.12), "armor_light")
    # The former grapple hung behind the hopper from this camera. The
    # paired jaws now project in front of the machinery, below the UI label.
    for side in [-1.0, 1.0]:
        g.rod("CollectorOpenClawJaw",
            Vector3(0.46, 1.96, 1.25),
            Vector3(0.46 + side * 0.57, 1.40, 1.47),
            0.20, "armor_light")
        g.rod("CollectorClawPoint",
            Vector3(0.46 + side * 0.57, 1.40, 1.47),
            Vector3(0.46 + side * 0.26, 1.05, 1.62),
            0.14, "caution")
        g.box("CollectorClawPin",
            Vector3(0.46 + side * 0.57, 1.40, 1.47),
            Vector3(0.17, 0.19, 0.17), "gold")
        # Broad color-blocked grabber cheeks, visible even when screen
        # downscaled to the real Android portrait width.
        g.box_tilt("CollectorVisibleJawCheek",
            Vector3(0.46 + side * 0.54, 1.62, 1.56),
            Vector3(0.38, 0.65, 0.20), "slate",
            Vector3(0.0, 0.0, -side * 0.24))
        g.poly_tilt("CollectorClawSignalCheek", "bevel",
            Vector3(0.46 + side * 0.62, 1.64, 1.72),
            Vector3(0.38, 0.73, 0.25), "caution",
            Vector3(0.0, 0.0, -side * 0.27))
    # One dark pocket behind the two jaws creates visual separation.
    g.box("CollectorCraneCableSeat",
        Vector3(0.46, 1.53, 1.31),
        Vector3(1.63, 0.82, 0.17), "dark")
    # Readable high-mounted boom and drop cable, visible above the sorting deck.
    g.rod("CollectorRaisedJib",
        Vector3(-0.73, 1.65, -0.40),
        Vector3(-0.25, 3.14, -0.48), 0.23, "gold")
    g.rod("CollectorRaisedJib",
        Vector3(-0.25, 3.14, -0.48),
        Vector3(0.46, 2.86, 1.05), 0.22, "caution")
    g.box("CollectorRaisedJibPivot",
        Vector3(-0.25, 3.12, -0.46),
        Vector3(0.32, 0.30, 0.28), "armor_light")
    g.rod("CollectorForwardCable",
        Vector3(0.46, 2.86, 1.05),
        Vector3(0.46, 1.98, 1.25), 0.10, "dark")
    g.box("CollectorWinchHead", Vector3(0.46, 2.83, 1.05),
        Vector3(0.34, 0.25, 0.28), "gold")


static func _smelter(g: Variant) -> void:
    # Two tall exhausts already define this station: thermal shields belong
    # below them and leave the orange furnace mouth completely visible.
    for i in range(3):
        g.box_tilt("SmelterHeatShieldRib",
            Vector3(0.68, 2.38, -0.35 + float(i) * 0.30),
            Vector3(0.72, 0.23, 0.085), "rust",
            Vector3(0.0, 0.0, -0.13))
    g.box("SmelterHeatVent", Vector3(0.75, 2.59, -0.36),
        Vector3(0.72, 0.09, 0.31), "armor_light")


    # Tall dual exhaust stacks get distinct exposed hot-metal collars;
    # the orange furnace opening remains fully visible below.
    g.ring("SmelterStackHeatCollar",
        Vector3(-0.66, 3.22, -0.55), 0.40, "caution")
    g.ring("SmelterSecondaryHeatCollar",
        Vector3(0.66, 3.04, -0.62), 0.26, "gold")
    for side in [-1.0, 1.0]:
        g.box("SmelterVentRiser",
            Vector3(side * 0.86, 1.99, 0.52),
            Vector3(0.11, 0.31, 0.26), "rust")
    g.box("SmelterMouthSafetyBrow", Vector3(0.0, 1.62, 1.02),
        Vector3(1.56, 0.11, 0.13), "rust")


static func _recycler(g: Variant) -> void:
    # No third pitched roof over the crusher. Short SIDE covers allow the
    # intake rollers and central dark throat to remain visible from above.
    for side in [-1.0, 1.0]:
        g.box_tilt("RecyclerSideRoofShutter",
            Vector3(side * 0.96, 2.12, -0.52),
            Vector3(0.43, 0.12, 0.73),
            "rust" if side < 0.0 else "armor_light",
            Vector3(-0.12, 0.0, side * 0.22))
        g.rod("RecyclerShutterPivot",
            Vector3(side * 1.12, 1.75, -0.79),
            Vector3(side * 1.12, 2.25, -0.76), 0.08, "edge")
    g.rod("RecyclerOpenThroatRail",
        Vector3(-0.74, 2.21, -1.04),
        Vector3(0.74, 2.21, -1.04), 0.10, "caution")


    # Exposed V feed guides and a clearly combed cutter mouth, rather
    # than another indistinct block of weathered metal.
    for side in [-1.0, 1.0]:
        g.rod("RecyclerOpenVFeedRail",
            Vector3(side * 1.03, 2.14, -0.78),
            Vector3(side * 0.78, 1.35, 0.92),
            0.16, "caution")
        g.box("RecyclerFeederWarningCheek",
            Vector3(side * 0.91, 1.38, 0.88),
            Vector3(0.20, 0.35, 0.22), "rust")
    g.rod("RecyclerCutterFrontTie",
        Vector3(-0.70, 1.31, 0.84),
        Vector3(0.70, 1.31, 0.84), 0.12, "edge")
    for index in range(4):
        g.box("RecyclerOpenToothTip",
            Vector3(-0.53 + float(index) * 0.35, 1.28, 0.96),
            Vector3(0.19, 0.13, 0.12), "armor_light")
    # Broad opposing crusher jaws read as a pair of machine plates, not
    # a solid lid: the rollers remain visible between their inner edges.
    for side in [-1.0, 1.0]:
        g.poly_tilt("RecyclerOpposedJawFace", "bevel",
            Vector3(side * 0.76, 1.52, 0.81),
            Vector3(0.24, 0.83, 0.19), "armor_light",
            Vector3(-0.16, 0.0, side * 0.19))
        g.box("RecyclerJawCautionInset",
            Vector3(side * 0.76, 1.58, 0.96),
            Vector3(0.19, 0.16, 0.09), "caution")


static func _generator(g: Variant) -> void:
    # Only the ring cage follows the blue turbine, no solid gabled shelter.
    for z in [-0.65, 0.47]:
        g.rod("GeneratorTurbineHoop",
            Vector3(-1.03, 1.96, z), Vector3(-0.71, 2.55, z),
            0.12, "edge")
        g.rod("GeneratorTurbineHoop",
            Vector3(-0.71, 2.55, z), Vector3(0.02, 2.77, z),
            0.12, "edge")
        g.rod("GeneratorTurbineHoop",
            Vector3(0.02, 2.77, z), Vector3(0.76, 2.47, z),
            0.12, "edge")
        g.rod("GeneratorTurbineHoop",
            Vector3(0.76, 2.47, z), Vector3(1.07, 1.96, z),
            0.12, "edge")
    g.rod("GeneratorPowerSpine",
        Vector3(0.02, 2.80, -0.65), Vector3(0.02, 2.80, 0.47),
        0.105, "blue_light")


    # A high contrast BLUE front-facing turbine corona, no roof plate.
    # Keep the ring ahead of the motor shell, behind the outer guard.
    # The power core was lost among dark housings and cables. One dark,
    # front-facing disc and three spokes give the fixed gameplay view a
    # clear rotor symbol instead of a heap of thin electric wires.
    g.box("GeneratorCoreBackdrop", Vector3(-0.08, 1.18, 1.10),
        Vector3(1.42, 1.42, 0.13), "dark")
    g.ring("GeneratorCoreCorona",
        Vector3(-0.08, 1.18, 1.27), 0.63, "blue_light", "z")
    g.box("GeneratorCoreHub", Vector3(-0.08, 1.18, 1.32),
        Vector3(0.29, 0.29, 0.13), "slate")
    g.box("GeneratorCoreHubLight",
        Vector3(-0.08, 1.18, 1.40),
        Vector3(0.13, 0.13, 0.07), "blue_light")
    for angle in [0.0, 2.0944, 4.1888]:
        var delta: Vector2 = Vector2(cos(angle), sin(angle))
        g.rod("GeneratorVisibleRotorSpoke",
            Vector3(-0.08 + delta.x * 0.18, 1.18 + delta.y * 0.18, 1.32),
            Vector3(-0.08 + delta.x * 0.49, 1.18 + delta.y * 0.49, 1.32),
            0.125, "blue_light")


static func _storage(g: Variant) -> void:
    # ONE unmistakable flat container roof; folded fabric is on the rear only.
    # One REAR roof strip rather than a full overhead cap. With the fixed
    # 27-degree camera, the missing front half now reveals actual cargo.
    g.box("StorageContainerRoof", Vector3(0.0, 2.76, -1.00),
        Vector3(2.30, 0.14, 0.96), "armor_light")
    for x in [-0.80, 0.0, 0.80]:
        g.box("StorageRoofRidge", Vector3(x, 2.85, -1.00),
            Vector3(0.105, 0.09, 0.88), "slate")
    g.box("StorageFrontLoadingVisor",
        Vector3(0.0, 2.70, 0.77),
        Vector3(2.42, 0.12, 0.22), "rust")


    # A compact container loading portal with positive metal corner locks.
    # Roof remains one flat pressed-steel lid, not overlapping tarps.
    g.box("StorageLoadingHeader", Vector3(0.0, 2.36, 1.13),
        Vector3(2.42, 0.19, 0.14), "armor_light")
    for side in [-1.0, 1.0]:
        g.box("StorageLoadingJamb",
            Vector3(side * 1.07, 1.32, 1.14),
            Vector3(0.16, 1.89, 0.18), "gold")
        g.box("StorageCargoLatch",
            Vector3(side * 0.68, 1.12, 1.17),
            Vector3(0.16, 0.46, 0.10), "armor_light")
    for index in range(4):
        g.box("StorageRoofPlateSegment",
            Vector3(-0.76 + float(index) * 0.50, 2.94, -1.00),
            Vector3(0.13, 0.035, 0.84), "slate")
    # Two exposed shipping cases occupy the front OPEN loading aperture.
    # At normal camera distance, these large faces read as cargo instead
    # of the old featureless dark warehouse doorway.
    g.poly("StorageVisibleCargoCase", "bevel",
        Vector3(-0.53, 1.21, 1.16),
        Vector3(0.77, 0.75, 0.49), "rust")
    g.poly("StorageVisibleCargoCase", "bevel",
        Vector3(0.36, 1.10, 1.15),
        Vector3(0.85, 0.61, 0.50), "armor_light")
    for x in [-0.53, 0.36]:
        g.box("StorageVisibleCargoHandle", Vector3(x, 1.36, 1.46),
            Vector3(0.32, 0.075, 0.065), "gold")
        g.box("StorageVisibleCargoBand", Vector3(x, 1.00, 1.46),
            Vector3(0.49, 0.065, 0.07), "trim")


static func _terminal(g: Variant) -> void:
    # A SLIM illuminated data visor above the display, not a full kiosk roof.
    g.box_tilt("TerminalSlimDataVisor",
        Vector3(0.0, 2.67, 0.47), Vector3(1.89, 0.10, 0.52),
        "blue", Vector3(-0.12, 0.0, 0.0))
    for side in [-1.0, 1.0]:
        g.rod("TerminalVisorBracket",
            Vector3(side * 0.82, 2.12, -0.15),
            Vector3(side * 0.82, 2.65, 0.47), 0.08, "armor_light")
    g.box("TerminalDataVisorFrontEdge",
        Vector3(0.0, 2.61, 0.75),
        Vector3(1.75, 0.09, 0.07), "blue_light")


    # Brighter electronic screen frame and small finned data visor.
    # All framing stays OFF the active blueprint display area.
    for side in [-1.0, 1.0]:
        g.box("TerminalScanFrameSide",
            Vector3(side * 0.88, 1.68, 0.25),
            Vector3(0.08, 1.08, 0.10), "blue_light")
    g.box("TerminalScanFrameHeader",
        Vector3(0.0, 2.25, 0.23),
        Vector3(1.88, 0.08, 0.10), "blue")
    for index in range(3):
        g.box("TerminalCoolingNotch",
            Vector3(-0.60 + float(index) * 0.60, 2.78, 0.48),
            Vector3(0.08, 0.07, 0.40), "slate")
    g.box("TerminalHandshakeStatus",
        Vector3(0.0, 1.25, 0.29),
        Vector3(0.35, 0.06, 0.06), "blue_light")


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
