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


static func _collector(g: Variant) -> void:
    # OPEN hydraulic crane: a marked crossbeam, not a box or roof over the claw.
    g.rod("CollectorOpenBoomCrossbar",
        Vector3(-1.03, 2.70, -0.94),
        Vector3(0.93, 2.70, -0.94), 0.12, "gold")
    for side in [-1.0, 1.0]:
        g.rod("CollectorBoomSideStay",
            Vector3(side * 0.93, 2.70, -0.94),
            Vector3(side * 0.86, 1.31, -0.88), 0.090, "edge")
    g.box("CollectorCraneMarker",
        Vector3(-0.81, 2.84, -0.94),
        Vector3(0.30, 0.18, 0.19), "caution")


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


static func _storage(g: Variant) -> void:
    # ONE unmistakable flat container roof; folded fabric is on the rear only.
    g.box("StorageContainerRoof", Vector3(0.0, 2.76, -0.40),
        Vector3(2.30, 0.14, 2.10), "armor_light")
    for x in [-0.80, 0.0, 0.80]:
        g.box("StorageRoofRidge", Vector3(x, 2.85, -0.40),
            Vector3(0.105, 0.09, 1.95), "slate")
    g.box("StorageFrontLoadingVisor",
        Vector3(0.0, 2.70, 0.77),
        Vector3(2.42, 0.12, 0.22), "rust")


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
