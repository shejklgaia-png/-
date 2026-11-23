extends RefCounted
## Sculpted, material-batched recovery crane for the BASE SCRAP_COLLECTOR.
## Parts are placed once, in the current facility's local coordinate system.
## Existing "FreshCollector..." hoist/jaw animation groups are preserved.
## Cargo-case/gear/drum/gusset/hood are real shared polygon meshes.

const CollectorConveyor = preload("res://scripts/sera_base_collector_conveyor.gd")


# One-time geometry adapter: all crane parts move together, including the
# bearing, bolts, hydraulic hoses, gripper and suspended rope. No 3D nodes
# or per-frame transformations are created by this authoring-time wrapper.
class ShiftedBatch:
    var _source: Variant
    var _offset: Vector3

    func _init(source: Variant, offset: Vector3) -> void:
        _source = source
        _offset = offset

    func poly(feature: String, kind: String, at: Vector3,
            size: Vector3, tint: String = "armor",
            yaw: float = 0.0) -> void:
        _source.poly(feature, kind, at + _offset, size, tint, yaw)

    func poly_tilt(feature: String, kind: String, at: Vector3,
            size: Vector3, tint: String, angles: Vector3) -> void:
        _source.poly_tilt(feature, kind, at + _offset, size, tint, angles)

    func box(feature: String, at: Vector3, size: Vector3,
            tint: String = "armor", yaw: float = 0.0) -> void:
        _source.box(feature, at + _offset, size, tint, yaw)

    func rod(feature: String, start: Vector3, finish: Vector3,
            diameter: float, tint: String = "trim") -> void:
        _source.rod(feature, start + _offset, finish + _offset,
            diameter, tint)


static func _beam(g: Variant, feature: String, a: Vector3, b: Vector3,
        width: float, depth: float, tint: String,
        profile: String = "cargo_case") -> void:
    var direction: Vector3 = b - a
    var length: float = direction.length()
    if length < 0.001:
        return
    # Align the polygon's long local Y axis with the actual mechanical axis.
    # The angled casting is not simulated with a bounding cube or a decal.
    var rotation := Basis(Quaternion(Vector3.UP, direction / length)).get_euler()
    g.poly_tilt(feature, profile, (a + b) * 0.5,
        Vector3(width, length, depth), tint, rotation)


static func _axle(g: Variant, feature: String, center: Vector3,
        width: float, radius: float, tint: String) -> void:
    _beam(g, feature, center - Vector3(width * 0.5, 0, 0),
        center + Vector3(width * 0.5, 0, 0),
        radius * 2.0, radius * 2.0, tint, "drum")


static func build(g: Variant) -> void:
    # Move the complete multi-part crane away from the yellow table edge.
    # Keep its original mechanical relationships and use one shared offset
    # with the runtime swivel pivot and the separate suspended cargo.
    g = ShiftedBatch.new(g, CollectorConveyor.CRANE_OFFSET)
    var foot := Vector3(-0.78, 1.25, -0.43)
    var elbow := Vector3(-0.35, 2.97, -0.31)
    var tip := Vector3(0.76, 2.59, 1.04)

    # Slewing pedestal: real toothed bearing, double race and exposed pinion.
    g.poly("CollectorCraneSlewRace", "gear",
        Vector3(-0.78, 0.98, -0.48),
        Vector3(1.04, 0.16, 1.04), "edge")
    g.poly("CollectorCraneInnerRace", "drum",
        Vector3(-0.78, 1.07, -0.48),
        Vector3(0.77, 0.22, 0.77), "dark")
    g.poly("CollectorCraneTurntableSkirt", "cargo_case",
        Vector3(-0.78, 1.16, -0.48),
        Vector3(0.94, 0.19, 0.83), "slate")
    g.poly("CollectorCraneDrivePinion", "gear",
        Vector3(-0.31, 1.00, -0.65),
        Vector3(0.29, 0.12, 0.29), "gold")
    for i in range(8):
        var angle: float = TAU * float(i) / 8.0
        g.poly("CollectorCraneBearingFastener", "drum",
            Vector3(-0.78 + cos(angle) * 0.42, 1.10,
                -0.48 + sin(angle) * 0.42),
            Vector3(0.095, 0.08, 0.095), "gold")

    # Paired side cheeks, transverse journal and lateral gusset braces.
    for side in [-1.0, 1.0]:
        var x: float = foot.x + side * 0.28
        g.poly("CollectorCranePivotCheek", "gusset",
            Vector3(x, 1.42, -0.43),
            Vector3(0.21, 0.62, 0.49), "slate")
        _beam(g, "CollectorCraneBaseWeb",
            Vector3(x, 1.23, -0.83),
            Vector3(x, 1.72, -0.42),
            0.15, 0.15, "armor_light", "gusset")
    _axle(g, "CollectorCraneLowerPin", foot, 0.78, 0.17, "edge")
    for x in [-1.15, -0.41]:
        g.poly("CollectorCranePivotLock", "gear",
            Vector3(x, 1.25, -0.43),
            Vector3(0.22, 0.10, 0.22), "gold")

    # Main boom and stick are two separate tapered polygon castings.
    # Narrow steel cap rails, spaced stiffeners and triangular welded webs
    # remain legible at the portrait BASE camera's oblique viewing angle.
    _beam(g, "CollectorCranePrimaryCasting", foot, elbow,
        0.40, 0.48, "gold")
    _beam(g, "CollectorCraneSecondaryCasting", elbow, tip,
        0.33, 0.40, "gold")
    for side in [-1.0, 1.0]:
        var shift := Vector3(side * 0.20, 0, 0)
        _beam(g, "CollectorCranePrimaryCapRail",
            foot + shift, elbow + shift, 0.085, 0.12, "armor_light")
        _beam(g, "CollectorCraneStickCapRail",
            elbow + shift * 0.86, tip + shift * 0.86,
            0.075, 0.10, "slate")
        for part in range(3):
            var t: float = 0.22 + 0.23 * float(part)
            var spine: Vector3 = foot.lerp(elbow, t)
            g.rod("CollectorCraneDiagonalStiffener",
                spine + Vector3(side * 0.24, -0.13, 0.0),
                spine + Vector3(side * 0.24, 0.17, 0.11),
                0.07, "slate")
        for part in range(2):
            var t: float = 0.30 + 0.36 * float(part)
            var spine: Vector3 = elbow.lerp(tip, t)
            _beam(g, "CollectorCraneStickWeb",
                spine + Vector3(side * 0.19, -0.12, 0.12),
                spine + Vector3(side * 0.19, 0.13, -0.12),
                0.11, 0.13, "slate", "gusset")
    # The knuckle has an actual crosswise pin and a polygon collar.
    g.poly("CollectorCraneElbowGuard", "hood",
        elbow + Vector3(0, 0, -0.03),
        Vector3(0.68, 0.52, 0.61), "slate")
    _axle(g, "CollectorCraneElbowShaft", elbow, 0.77, 0.16, "edge")
    _axle(g, "CollectorCraneElbowWasher", elbow, 0.90, 0.12, "gold")

    # Hydraulic cylinders use independent 16-sided bodies, chromed piston
    # rods, seals, clevis pivots and a pair of routed hose lines.
    for side in [-1.0, 1.0]:
        var xshift: float = side * 0.20
        var low := Vector3(-0.94 + xshift, 1.64, -0.49)
        var upper := Vector3(-0.43 + xshift, 2.56, -0.33)
        _beam(g, "CollectorCraneLiftCylinder", low,
            low.lerp(upper, 0.65), 0.20, 0.20, "slate", "drum")
        _beam(g, "CollectorCraneLiftPiston", low.lerp(upper, 0.58),
            upper, 0.095, 0.095, "edge", "drum")
        _axle(g, "CollectorCraneLiftSeal",
            low.lerp(upper, 0.64), 0.20, 0.12, "gold")
        var stick_start := Vector3(-0.19 + xshift, 2.79, -0.23)
        var stick_end := Vector3(0.52 + xshift, 2.62, 0.74)
        _beam(g, "CollectorCraneStickCylinder",
            stick_start, stick_start.lerp(stick_end, 0.65),
            0.16, 0.16, "slate", "drum")
        _beam(g, "CollectorCraneStickPiston",
            stick_start.lerp(stick_end, 0.58),
            stick_end, 0.083, 0.083, "edge", "drum")
        for i in range(3):
            var t: float = float(i) / 2.0
            var start: Vector3 = foot.lerp(elbow, t)
            var end: Vector3 = foot.lerp(elbow, minf(t + 0.22, 1.0))
            g.rod("CollectorCranePressureHose",
                start + Vector3(side * 0.29, 0.02, -0.20),
                end + Vector3(side * 0.29, 0.07, -0.20),
                0.035, "dark")
        g.rod("CollectorCraneStickHose",
            elbow + Vector3(side * 0.26, 0.08, -0.05),
            tip + Vector3(side * 0.20, 0.10, -0.15),
            0.033, "dark")

    # Twin outboard pulley plates and a detailed rotating sheave.
    g.poly("CollectorCraneSheave", "gear",
        tip, Vector3(0.45, 0.20, 0.45), "edge")
    _axle(g, "CollectorCraneSheaveAxle", tip, 0.64, 0.11, "gold")
    for side in [-1.0, 1.0]:
        _beam(g, "CollectorCraneSheaveFork",
            tip + Vector3(side * 0.26, 0.08, -0.22),
            tip + Vector3(side * 0.26, -0.14, 0.16),
            0.12, 0.12, "slate", "gusset")
    g.poly("CollectorCraneSheaveGuard", "hood",
        tip + Vector3(0, 0.15, -0.02),
        Vector3(0.53, 0.25, 0.61), "armor_light")

    # Keep the old hoist feature and exact 0.70m cable length: its per-frame
    # squash and vertical translation are already driven by facility_motion.
    g.rod("FreshCollectorSuspendedCable",
        Vector3(0.76, 2.54, 1.04),
        Vector3(0.76, 1.84, 1.04), 0.068, "dark")
    g.poly("FreshCollectorClawHead", "cargo_case",
        Vector3(0.76, 1.80, 1.04),
        Vector3(0.62, 0.31, 0.53), "armor_light")
    g.poly("FreshCollectorClawHead", "hood",
        Vector3(0.76, 1.97, 1.04),
        Vector3(0.43, 0.19, 0.42), "slate")
    g.poly("FreshCollectorClawHead", "gear",
        Vector3(0.76, 1.74, 1.04),
        Vector3(0.40, 0.10, 0.40), "gold")

    # Four individual forged gripping fingers, arranged as opposing pairs.
    # Motion names and side ordering match the original oscillating jaw driver.
    for row in [-1.0, 1.0]:
        for side in [-1.0, 1.0]:
            var root := Vector3(0.76 + side * 0.24,
                1.72, 1.04 + row * 0.21)
            var knuckle := Vector3(0.76 + side * 0.47,
                1.42, 1.04 + row * 0.30)
            var tooth := Vector3(0.76 + side * 0.24,
                1.20, 1.04 + row * 0.20)
            _axle(g, "FreshCollectorJawHinge",
                root, 0.15, 0.105, "gold")
            _beam(g, "FreshCollectorOpenGrip", root, knuckle,
                0.18, 0.20, "armor_light", "gusset")
    for row in [-1.0, 1.0]:
        for side in [-1.0, 1.0]:
            var knuckle := Vector3(0.76 + side * 0.47,
                1.42, 1.04 + row * 0.30)
            var tooth := Vector3(0.76 + side * 0.24,
                1.20, 1.04 + row * 0.20)
            _beam(g, "FreshCollectorOpenGrip", knuckle, tooth,
                0.16, 0.15, "edge", "cargo_case")
