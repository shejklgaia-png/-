extends RefCounted
## Larger authored silhouettes for the seven industrial stations, with a compact
## NEXUS finish. All geometry is merged into the existing opaque MultiMesh Batch.
## Local +Z faces the player; no frame updates, new shaders or per-bolt nodes.

static func _vent_fan(g: Variant, feature: String, at: Vector3,
        radius: float, accent: String = "blue") -> void:
    # A readable circular fan rather than three tiny indistinguishable vents.
    g.poly(feature + "Duct", "hood", at + Vector3(0, 0, -0.10),
        Vector3(radius * 2.45, radius * 2.45, 0.28), "dark")
    g.ring(feature, at + Vector3(0, 0, 0.095), radius, "armor_light", "z")
    g.ring(feature + "Inner", at + Vector3(0, 0, 0.11),
        radius * 0.54, "edge", "z")
    for blade in range(5):
        var a: float = TAU * float(blade) / 5.0
        var inner: Vector3 = at + Vector3(cos(a) * radius * 0.17,
            sin(a) * radius * 0.17, 0.13)
        var outer: Vector3 = at + Vector3(cos(a + 0.34) * radius * 0.81,
            sin(a + 0.34) * radius * 0.81, 0.14)
        g.rod(feature + "RotorBlade", inner, outer, radius * 0.24, "slate")
    g.poly(feature + "Hub", "bevel", at + Vector3(0, 0, 0.16),
        Vector3(radius * 0.34, radius * 0.34, 0.18), "gold")
    g.box(feature + "Status", at + Vector3(radius * 0.77,
        radius * 0.79, 0.15), Vector3(0.13, 0.08, 0.06),
        "blue_light" if accent == "blue" else "amber_light")

static func _door(g: Variant, feature: String, at: Vector3,
        width: float, height: float) -> void:
    # Prominent recessed frame, segmented metal leaf and physical latch.
    g.poly(feature + "Portal", "bevel", at,
        Vector3(width + 0.34, height + 0.27, 0.28), "edge")
    g.box(feature, at + Vector3(0, -0.035, 0.175),
        Vector3(width, height - 0.15, 0.08), "slate")
    for row in range(3):
        g.box(feature + "Division", at + Vector3(0,
            -height * 0.35 + float(row) * height * 0.34, 0.232),
            Vector3(width * 0.87, 0.045, 0.043), "dark")
    g.box(feature + "Handle", at + Vector3(width * 0.34,
        -height * 0.08, 0.255), Vector3(0.07, 0.31, 0.09), "gold")
    # Door-side emissive bars were removed at all non-smelter machines:
    # named work lamps with visible housings now own their actual spill.
    if feature == "SmelterServiceDoor":
        g.box(feature + "DoorLamp",
            at + Vector3(0, height * 0.55, 0.20),
            Vector3(width * 0.69, 0.105, 0.07), "amber_light")

static func _nexus(g: Variant) -> void:
    # Keep the already approved 1.14x NEXUS scale, only improve silhouettes.
    _vent_fan(g, "NexusServiceFan", Vector3(-2.11, 3.34, 2.83),
        0.34, "blue")
    g.poly("NexusAwningEave", "roof", Vector3(-2.83, 3.16, 3.30),
        Vector3(1.67, 0.24, 1.34), "cloth")
    for side in [-1.0, 1.0]:
        g.rod("NexusAwningBrace",
            Vector3(-2.83 + side * 0.70, 2.83, 3.75),
            Vector3(-2.83 + side * 0.70, 3.22, 2.80), 0.10, "gold")
    # Light now escapes only from the narrow shutter-floor gap emitter in
    # BaseFacilityVFX; omit the broad old amber side/door light bar.

static func _labo(g: Variant) -> void:
    # One sweeping pitch is readable from a high camera: stitched panels below.
    # Real two-plane tent roof; the high central ridge is not a flat slab.
    for side in [-1.0, 1.0]:
        g.poly_tilt("LabCanopyCrest", "roof",
            Vector3(side * 1.73, 3.48, -1.08),
            Vector3(0.21, 0.13, 1.28), "cloth",
            Vector3(0.0, 0.0, -side * 0.12))
    g.poly("LabCanopyFrontLip", "roof", Vector3(0, 3.34, -0.30),
        Vector3(3.78, 0.12, 0.16), "slate")
    for side in [-1.0, 1.0]:
        g.rod("LabTarpHeavyTension",
            Vector3(side * 1.91, 3.53, -1.60),
            Vector3(side * 1.91, 3.31, 0.02), 0.075, "edge")
        g.box("LabGantryLamp", Vector3(side * 1.38, 2.55, 1.65),
            Vector3(0.58, 0.13, 0.11), "amber_light")
    _vent_fan(g, "LabVentFan", Vector3(-0.86, 1.74, -1.20),
        0.40, "blue")
    _door(g, "LabServiceDoor", Vector3(-1.72, 1.26, 1.22), 0.54, 1.67)
    g.poly("LabRoofExhaust", "hood", Vector3(1.28, 3.73, -1.05),
        Vector3(0.76, 0.58, 0.80), "armor_light")

static func _collector(g: Variant) -> void:
    # Open front stays visible below the elevated salvage-sorting shed.
    for side in [-1.0, 1.0]:
        g.poly_tilt("CollectorWeatherHood", "roof",
            Vector3(side * 1.04 - 0.10, 2.39, -0.86),
            Vector3(0.29, 0.16, 0.72), "rust",
            Vector3(0.0, 0.0, -side * 0.09))
    for side in [-1.0, 1.0]:
        g.rod("CollectorShedPost", Vector3(side * 1.13, 0.20, -0.99),
            Vector3(side * 1.13, 2.35, -0.99), 0.11, "edge")
    _vent_fan(g, "CollectorVentFan", Vector3(-0.84, 1.56, 0.62),
        0.28, "blue")
    _door(g, "CollectorServiceDoor", Vector3(-1.15, 0.84, 0.26),
        0.46, 1.15)
    g.box("CollectorSignalBar", Vector3(0.34, 2.38, 0.18),
        Vector3(0.91, 0.14, 0.11), "blue_light")

static func _smelter(g: Variant) -> void:
    # Taller segmented exhaust is the primary vertical focal point.
    g.rod("SmelterTallExhaust", Vector3(-0.66, 2.18, -0.55),
        Vector3(-0.66, 3.97, -0.55), 0.61, "rust")
    g.ring("SmelterChimneyRim", Vector3(-0.66, 3.95, -0.55),
        0.34, "edge")
    g.poly("SmelterChimneyRainHood", "roof",
        Vector3(-0.66, 4.16, -0.55),
        Vector3(1.02, 0.26, 0.93), "slate")
    g.rod("SmelterChimneyCapSupport",
        Vector3(-0.92, 3.94, -0.55),
        Vector3(-0.92, 4.11, -0.55), 0.07, "gold")
    _vent_fan(g, "SmelterCoolingFan", Vector3(0.85, 1.69, 0.68),
        0.27, "amber")
    _door(g, "SmelterServiceDoor", Vector3(1.03, 0.87, 0.71),
        0.42, 0.94)
    g.box("SmelterHeatBand", Vector3(0, 0.24, 1.17),
        Vector3(1.23, 0.12, 0.13), "amber_light")

static func _recycler(g: Variant) -> void:
    for side in [-1.0, 1.0]:
        g.poly_tilt("RecyclerRoofCowl", "roof",
            Vector3(side * 0.97, 1.98, -0.91),
            Vector3(0.31, 0.15, 0.61), "armor_light",
            Vector3(0.0, 0.0, -side * 0.12))
    g.poly("RecyclerCowlIntake", "hood", Vector3(0, 1.75, -1.08),
        Vector3(1.80, 0.45, 0.48), "dark")
    for side in [-1.0, 1.0]:
        g.box("RecyclerVerticalBracing", Vector3(side * 1.10, 1.15, -0.28),
            Vector3(0.16, 1.53, 0.20), "gold")
    _vent_fan(g, "RecyclerVentFan", Vector3(-1.03, 1.15, 0.80),
        0.34, "blue")
    _door(g, "RecyclerServiceDoor", Vector3(1.07, 1.04, 0.80),
        0.50, 1.32)
    # Purpose-built guarded crusher work lamps replace this bright strip.

static func _generator(g: Variant) -> void:
    g.poly("GeneratorRoofShield", "hood", Vector3(0.88, 2.13, -0.55),
        Vector3(0.74, 0.34, 1.06), "slate")
    for side in [-1.0, 1.0]:
        g.rod("GeneratorRoofSupport",
            Vector3(side * 1.07, 1.58, -0.91),
            Vector3(side * 1.06, 2.37, -0.91), 0.105, "edge")
    _vent_fan(g, "GeneratorVentFan", Vector3(-0.62, 1.50, 0.83),
        0.35, "blue")
    _door(g, "GeneratorServiceDoor", Vector3(1.01, 0.99, 0.65),
        0.53, 1.25)
    g.box("GeneratorPowerIndicator", Vector3(-0.60, 2.29, 0.32),
        Vector3(0.66, 0.14, 0.11), "blue_light")
    g.poly("GeneratorTransformerCowl", "hood", Vector3(0.84, 2.07, -0.35),
        Vector3(0.80, 0.35, 0.65), "armor_light")

static func _storage(g: Variant) -> void:
    # Full-size tensioned cloth shelter; the loading aperture stays exposed.
    for side in [-1.0, 1.0]:
        g.poly_tilt("StorageFabricCanopy", "canvas",
            Vector3(side * 0.72, 2.21, -0.96),
            Vector3(0.28, 0.20, 0.66), "cloth",
            Vector3(0.0, 0.0, -side * 0.23))
    g.poly("StorageTarpRainPeak", "hood", Vector3(0, 2.45, -1.00),
        Vector3(0.39, 0.18, 0.50), "armor")
    for side in [-1.0, 1.0]:
        g.rod("StorageTarpGrommetCord",
            Vector3(side * 1.25, 2.28, 0.72),
            Vector3(side * 1.24, 0.48, 1.12), 0.075, "gold")
    _vent_fan(g, "StorageVentFan", Vector3(-0.83, 1.47, 0.92),
        0.26, "blue")
    _door(g, "StorageLoadingDoor", Vector3(0.13, 0.94, 1.08),
        0.91, 1.37)
    # Dedicated industrial downlights with round pools now serve entry.

static func _terminal(g: Variant) -> void:
    # Small station grows into a sheltered maintenance kiosk, not a monolith.
    for side in [-1.0, 1.0]:
        g.poly_tilt("TerminalServiceRoof", "roof",
            Vector3(side * 0.74, 2.47, -0.90),
            Vector3(0.30, 0.15, 0.46), "armor",
            Vector3(0.0, 0.0, -side * 0.08))
    g.poly("TerminalUpperCoolingDuct", "hood", Vector3(0.52, 2.38, -0.60),
        Vector3(0.74, 0.42, 0.63), "slate")
    for side in [-1.0, 1.0]:
        g.rod("TerminalRoofPillar",
            Vector3(side * 0.94, 0.38, -0.95),
            Vector3(side * 0.94, 2.57, -0.95), 0.09, "edge")
    _vent_fan(g, "TerminalVentFan", Vector3(0.74, 1.21, 0.45),
        0.20, "blue")
    _door(g, "TerminalMaintenanceHatch", Vector3(-0.76, 0.86, 0.49),
        0.40, 1.12)
    # A physically modeled task lamp at the panel replaces roof-side glow.

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
