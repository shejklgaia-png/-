extends RefCounted
## WIDE 1.94m local conveyor feeding the SCRAP_COLLECTOR from screen-left.
## The initial belt end is intentionally beyond the portrait camera left edge.
## Geometry uses existing opaque, shared Batch materials and polygon meshes;
## the belt flights and one visible scrap parcel are the only moving belt parts.

const LOOP_SECONDS: float = 8.0
const BELT_START_X: float = -5.70
const BELT_PICKUP_X: float = -1.50
const BELT_Z: float = 1.59
const BELT_SPEED: float = 1.3548387  # 4.20m / 3.10s
# The physical slewing bearing, boom, hook and carried cargo share this
# inboard offset. Keep the belt fixed; retarget pickup yaw to meet its gate.
const CRANE_OFFSET: Vector3 = Vector3(0.18, 0.0, 0.08)
const PICKUP_ANGLE: float = deg_to_rad(-70.0)
const CRANE_PIVOT: Vector3 = Vector3(-0.78, 1.07, -0.48) + CRANE_OFFSET
const HOIST_CABLE_LENGTH: float = 0.70

static func phase_at(seconds: float) -> float:
    return fposmod(maxf(seconds, 0.0), LOOP_SECONDS)


static func slew_at(phase: float) -> float:
    # Rotate the entire crane upper carriage to the belt, then the hopper.
    if phase < 4.18:
        return PICKUP_ANGLE
    if phase < 5.62:
        return lerpf(PICKUP_ANGLE, 0.0, smoothstep(4.18, 5.62, phase))
    if phase < 6.70:
        return 0.0
    return lerpf(0.0, PICKUP_ANGLE, smoothstep(6.70, 7.70, phase))


# High clearance is only used while slewing across the fixed sorting
# table's raised rim. Lowering is permitted solely after yaw has settled.
const SWEEP_CLEARANCE_LIFT: float = 0.44
const SORT_PAN_DROP_LIFT: float = 0.12


static func lift_at(phase: float) -> float:
    # Keep the rotating gripper and carried metal above the hopper's steel
    # rim throughout both yaw traversals. Cable is 0.70m at rest; +0.44m
    # leaves a real 0.26m tether rather than inverting its stretch axis.
    if phase < 2.60:
        return 0.17
    if phase < 3.10:
        return lerpf(0.17, -0.17, smoothstep(2.60, 3.10, phase))
    if phase < 3.52:
        return -0.17
    if phase < 4.18:
        # Complete the lift before the crane starts rotating at 4.18s.
        return lerpf(-0.17, SWEEP_CLEARANCE_LIFT,
            smoothstep(3.52, 4.18, phase))
    if phase < 5.62:
        return SWEEP_CLEARANCE_LIFT
    if phase < 6.04:
        # The arm faces the hopper before the load descends for release.
        return lerpf(SWEEP_CLEARANCE_LIFT, SORT_PAN_DROP_LIFT,
            smoothstep(5.62, 6.04, phase))
    if phase < 6.32:
        return SORT_PAN_DROP_LIFT
    if phase < 6.70:
        # Retract before returning across the raised worktable rim.
        return lerpf(SORT_PAN_DROP_LIFT, SWEEP_CLEARANCE_LIFT,
            smoothstep(6.32, 6.70, phase))
    if phase < 7.70:
        return SWEEP_CLEARANCE_LIFT
    # Only lower again after the return rotation has completely stopped.
    return lerpf(SWEEP_CLEARANCE_LIFT, 0.17,
        smoothstep(7.70, LOOP_SECONDS, phase))


static func grip_at(phase: float) -> float:
    # Positive angle opens both opposing fingers around their root pins.
    if phase < 3.10:
        return 0.27
    if phase < 3.52:
        return lerpf(0.27, 0.0, smoothstep(3.10, 3.52, phase))
    if phase < 6.04:
        return 0.0
    if phase < 6.32:
        return lerpf(0.0, 0.27, smoothstep(6.04, 6.32, phase))
    return 0.27


static func build(g: Variant) -> void:
    var span: float = BELT_PICKUP_X - BELT_START_X
    var mid_x: float = (BELT_START_X + BELT_PICKUP_X) * 0.5
    # A broad reinforced frame, physically sloped rollers, non-glowing
    # rubber track and side guides, all in the same machine yaw as the crane.
    g.poly("FreshCollectorConveyorTray", "tray",
        Vector3(mid_x, 0.71, BELT_Z),
        Vector3(span + 0.18, 0.21, 1.94), "slate")
    g.box("FreshCollectorConveyorBelt",
        Vector3(mid_x, 0.84, BELT_Z),
        Vector3(span, 0.07, 1.68), "rubber")
    for side in [-1.0, 1.0]:
        var rail_z: float = BELT_Z + side * 0.92
        g.poly("FreshCollectorConveyorRail", "cargo_case",
            Vector3(mid_x, 0.95, rail_z),
            Vector3(span + 0.16, 0.31, 0.14), "armor_light")
        g.box("FreshCollectorConveyorSafetyStripe",
            Vector3(mid_x, 1.105, rail_z),
            Vector3(span + 0.12, 0.055, 0.11), "gold")
        for i in range(3):
            var x: float = -5.28 + float(i) * 1.63
            g.poly("FreshCollectorConveyorSupportFoot", "cargo_case",
                Vector3(x, 0.35, rail_z),
                Vector3(0.22, 0.68, 0.24), "dark")
            g.rod("FreshCollectorConveyorCrossBrace",
                Vector3(x - 0.28, 0.21, rail_z),
                Vector3(x + 0.19, 0.72, rail_z),
                0.08, "edge")
    for i in range(7):
        var x: float = BELT_START_X + 0.22 + float(i) * (span - 0.44) / 6.0
        g.poly_tilt("FreshCollectorConveyorRoller", "drum",
            Vector3(x, 0.72, BELT_Z),
            Vector3(0.20, 1.78, 0.20), "edge",
            Vector3(PI * 0.5, 0.0, 0.0))
        for side in [-1.0, 1.0]:
            g.poly("FreshCollectorConveyorAxleCap", "gear",
                Vector3(x, 0.72, BELT_Z + side * 0.90),
                Vector3(0.16, 0.075, 0.16), "gold")
    # The motor and guarded transfer gate sit at the actual pickup end.
    g.poly("FreshCollectorBeltDrive", "cargo_case",
        Vector3(-1.63, 0.62, 0.59),
        Vector3(0.62, 0.53, 0.54), "slate")
    g.poly("FreshCollectorBeltSprocket", "gear",
        Vector3(-1.62, 0.73, 0.28),
        Vector3(0.32, 0.14, 0.32), "gold")
    # Two side-only terminal guides leave the moving scrap and claw fully
    # visible; there is no solid full-width block over the pickup parcel.
    for side in [-1.0, 1.0]:
        g.poly("FreshCollectorPickupSideGuide", "gusset",
            Vector3(BELT_PICKUP_X - 0.05, 1.06,
                BELT_Z + side * 0.80),
            Vector3(0.28, 0.29, 0.15), "caution")
    g.box("FreshCollectorPickupUnderstop",
        Vector3(BELT_PICKUP_X + 0.11, 0.72, BELT_Z),
        Vector3(0.12, 0.11, 1.60), "edge")

    # Moving transverse tread bars communicate a continuous physical belt
    # without animating the entire static conveyor or creating many nodes.
    for i in range(14):
        var x: float = BELT_START_X + 0.16 + float(i) * (span - 0.32) / 14.0
        g.box("FreshCollectorConveyorFlight",
            Vector3(x, 0.90, BELT_Z),
            Vector3(0.085, 0.045, 1.52), "slate")

    # The same salvage parcel first rides the belt, is hidden when the jaws
    # close, and becomes the crane payload; no duplicated visible cargo.
    g.poly_tilt("FreshCollectorPickupScrap", "cargo_case",
        Vector3(BELT_START_X, 1.02, BELT_Z),
        Vector3(0.46, 0.25, 0.41), "rust",
        Vector3(0.16, 0.22, 0.10))
    g.poly("FreshCollectorPickupScrap", "gear",
        Vector3(BELT_START_X - 0.07, 1.16, BELT_Z + 0.05),
        Vector3(0.24, 0.14, 0.24), "edge")
    # Staged at the unslewed claw rest point; only displayed while held.
    g.poly_tilt("FreshCollectorCranePayload", "cargo_case",
        Vector3(0.76, 1.19, 1.04) + CRANE_OFFSET,
        Vector3(0.46, 0.25, 0.41), "rust",
        Vector3(0.16, 0.22, 0.10))
    g.poly("FreshCollectorCranePayload", "gear",
        Vector3(0.69, 1.33, 1.09) + CRANE_OFFSET,
        Vector3(0.24, 0.14, 0.24), "edge")
