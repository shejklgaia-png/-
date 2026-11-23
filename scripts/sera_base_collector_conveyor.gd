extends RefCounted
## WIDE 1.94m local conveyor feeding the SCRAP_COLLECTOR from screen-left.
## The initial belt end is intentionally beyond the portrait camera left edge.
## Geometry uses existing opaque, shared Batch materials and polygon meshes;
## the belt flights and one visible scrap parcel are the only moving belt parts.

const LOOP_SECONDS: float = 8.0
const BELT_START_X: float = -5.70
const BELT_PICKUP_X: float = -1.30
const BELT_Z: float = 1.28
const BELT_SPEED: float = 1.5597015  # 4.18m in 2.68s, before the ramp
# In the oblique camera, moving local -X/-Z shifts the shaft upper-left.
# The octave-bearing center is isolated behind the yellow hopper rim.
# The shorter boom and the retracted belt pickup meet at this new position.
const CRANE_OFFSET: Vector3 = Vector3(0.0, 0.0, -0.30)
const CRANE_PIVOT: Vector3 = Vector3(-0.78, 1.07, -0.48) + CRANE_OFFSET
const CRANE_TIP_X: float = 0.72
const CRANE_TIP_Z: float = 1.02
const PICKUP_ANGLE: float = -1.033234918  # -59.2 degrees, 2.12m reach
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
    # Open claws while high, keep them visibly open, then descend onto the
    # cargo only after the belt parcel has bumped up and settled on the plate.
    if phase < 3.16:
        return 0.17
    if phase < 3.44:
        return lerpf(0.17, -0.17, smoothstep(3.16, 3.44, phase))
    if phase < 3.72:
        return -0.17
    if phase < 4.18:
        # Gripping is complete before any upward motion or slewing.
        return lerpf(-0.17, SWEEP_CLEARANCE_LIFT,
            smoothstep(3.72, 4.18, phase))
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


const GRIP_OPEN_ANGLE: float = 0.42
const SCRAP_RAMP_START: float = 2.68
const SCRAP_RAMP_FINISH: float = 2.96
const SCRAP_SETTLE_FINISH: float = 3.16
const SCRAP_PLATE_RISE: float = 0.14


static func grip_at(phase: float) -> float:
    # The returning claws start CLOSED. Open 0.8 seconds before descent,
    # hold fully open until lowered, then grip while remaining down.
    if phase < 2.00:
        return 0.0
    if phase < 2.36:
        return lerpf(0.0, GRIP_OPEN_ANGLE,
            smoothstep(2.00, 2.36, phase))
    if phase < 3.44:
        return GRIP_OPEN_ANGLE
    if phase < 3.72:
        return lerpf(GRIP_OPEN_ANGLE, 0.0,
            smoothstep(3.44, 3.72, phase))
    if phase < 6.04:
        return 0.0
    if phase < 6.32:
        return lerpf(0.0, GRIP_OPEN_ANGLE,
            smoothstep(6.04, 6.32, phase))
    if phase < 7.70:
        return GRIP_OPEN_ANGLE
    # Close again only when back at the upper pickup station. This makes
    # the 8s loop wrap continuously with closed claws at phase zero.
    return lerpf(GRIP_OPEN_ANGLE, 0.0,
        smoothstep(7.70, LOOP_SECONDS, phase))


static func scrap_offset_at(phase: float) -> Vector3:
    # 0–2.68s: regular belt transport; the scrap approaches the ramp lip.
    var approach: float = BELT_PICKUP_X - 0.22 - BELT_START_X
    if phase < SCRAP_RAMP_START:
        return Vector3(BELT_SPEED * phase, 0.0, 0.0)
    if phase < SCRAP_RAMP_FINISH:
        # The inertia carries the part up a short steel ramp; one visible
        # upward bump is separate from the small later settling vibration.
        var t: float = smoothstep(
            SCRAP_RAMP_START, SCRAP_RAMP_FINISH, phase)
        return Vector3(approach + 0.32 * t,
            SCRAP_PLATE_RISE * t + 0.075 * sin(t * PI), 0.0)
    if phase < SCRAP_SETTLE_FINISH:
        var t: float = (phase - SCRAP_RAMP_FINISH) / (
            SCRAP_SETTLE_FINISH - SCRAP_RAMP_FINISH)
        var fade: float = 1.0 - t
        return Vector3(approach + 0.32 +
            0.027 * sin(t * TAU) * fade,
            SCRAP_PLATE_RISE + 0.034 *
            sin(t * TAU * 1.5) * fade,
            0.014 * sin(t * TAU) * fade)
    # Cargo remains supported and motionless on the actual elevated plate
    # until the jaws have completed their close around it at 3.72 seconds.
    return Vector3(approach + 0.32, SCRAP_PLATE_RISE, 0.0)


static func scrap_rock_at(phase: float) -> float:
    if phase < SCRAP_RAMP_START or phase >= SCRAP_SETTLE_FINISH:
        return 0.0
    if phase < SCRAP_RAMP_FINISH:
        var t: float = smoothstep(
            SCRAP_RAMP_START, SCRAP_RAMP_FINISH, phase)
        return 0.24 * sin(t * PI)
    var t: float = (phase - SCRAP_RAMP_FINISH) / (
        SCRAP_SETTLE_FINISH - SCRAP_RAMP_FINISH)
    return 0.17 * sin(t * TAU * 1.5) * (1.0 - t)


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
        Vector3(BELT_PICKUP_X - 0.13, 0.62, BELT_Z - 1.00),
        Vector3(0.62, 0.53, 0.54), "slate")
    g.poly("FreshCollectorBeltSprocket", "gear",
        Vector3(BELT_PICKUP_X - 0.12, 0.73, BELT_Z - 1.31),
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
    # The pickup has its own raised steel loading plate, 0.14m above the
    # belt. A gently pitched metal lip lets the scrap actually ride up.
    g.poly_tilt("FreshCollectorPickupRamp", "cargo_case",
        Vector3(BELT_PICKUP_X - 0.20, 0.94, BELT_Z),
        Vector3(0.36, 0.065, 1.22), "edge",
        Vector3(0.0, 0.0, 0.25))
    g.poly("FreshCollectorPickupPlate", "cargo_case",
        Vector3(BELT_PICKUP_X + 0.12, 0.93, BELT_Z),
        Vector3(0.50, 0.18, 1.26), "slate")
    for side in [-1.0, 1.0]:
        g.box("FreshCollectorPickupPlateSideLip",
            Vector3(BELT_PICKUP_X + 0.11, 1.06,
                BELT_Z + side * 0.61),
            Vector3(0.43, 0.08, 0.055), "armor_light")

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
        Vector3(CRANE_TIP_X, 1.19, CRANE_TIP_Z) + CRANE_OFFSET,
        Vector3(0.46, 0.25, 0.41), "rust",
        Vector3(0.16, 0.22, 0.10))
    g.poly("FreshCollectorCranePayload", "gear",
        Vector3(CRANE_TIP_X - 0.07, 1.33,
            CRANE_TIP_Z + 0.05) + CRANE_OFFSET,
        Vector3(0.24, 0.14, 0.24), "edge")
