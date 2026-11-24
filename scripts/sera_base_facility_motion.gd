extends Node
const CollectorConveyor = preload("res://scripts/sera_base_collector_conveyor.gd")
## BASE equipment: eight deterministic production-loop motions of actual existing
## authored MultiMesh instances. No additional 3D draw nodes, colliders or lights.
## Animated positions are in the same local coordinates as the authored model.
## The already-restored archived NEXUS geometry is never replaced or reauthored.

const MOTION_FEATURES: Dictionary = {
    "NEXUS": ["NexusServiceAwning", "NexusAwningValance", "NexusFanBlade",
        "NexusDishAzimuthBearing", "NexusDishYoke", "NexusDishHinge",
        "NexusDishReflector", "NexusDishFeedArm", "NexusDishFeed",
        "NexusAntennaYagiBoom", "NexusAntennaYagiElement",
        "NexusPlenumLouver", "NexusSignalIndicator", "NexusSupplyDrawer", "NexusSupplyCase"],
    "LABO": ["FreshLabPrinterServo", "FreshLabPrinterHotHead",
        "FreshLabPrinterTip", "FreshLabPrintedShell", "LabPrintedGear", "LabPrintedArmor", "LabPrintedJoint", "LabInputPellet",
        "LabArmLinkA", "LabArmLinkB", "LabArmElbow", "LabArmWristHub",
        "LabArmWristShaft", "LabArmWristOffset", "LabArmGripBody",
        "LabArmGripJaw", "LabStockLift", "LabStockShutter", "LabMetalFeedSpool"],
    "SCRAP_COLLECTOR": ["FreshCollectorSuspendedCable", "FreshCollectorClawHead",
        "FreshCollectorJawHinge", "FreshCollectorOpenGrip",
        "FreshCollectorConveyorFlight", "FreshCollectorPickupScrap"],
    "SMELTER": ["SmelterFeedScrap", "SmelterMoltenPour", "SmelterCastIngot", "SmelterChargeGate"],
    "RECYCLER": ["FreshRecyclerRoller", "FreshRecyclerTooth", "RecyclerRecoveredPart"],
    "GENERATOR": ["FreshGeneratorRotorBlade", "FreshGeneratorMeterRow"],
    "STORAGE": ["FreshStorageLoadingLift", "StorageMovingCase", "StorageMovingLock", "StorageTransferFork", "StorageStoredCase", "StorageStoredLock"],
    "BUILD_TERMINAL": ["FreshBuildModuleLock", "FreshBuildArmForelink", "FreshBuildArmToolChuck", "FreshBuildArmClampJaw"],
}
# Bearing and pinion stay fixed while the machine above the slewing ring
# rotates together. The existing 30 Hz MultiMesh animation cap is retained.
const CRANE_SLEW_FEATURES = [
    "FreshCollectorWinchMotor", "FreshCollectorMotorGlow",
    "CollectorCraneInnerRace", "CollectorCraneTurntableSkirt",
    "CollectorCraneOctagonalSpindle", "CollectorCranePivotCheek",
    "CollectorCraneBaseWeb", "CollectorCraneLowerPin", "CollectorCranePivotLock",
    "CollectorCranePrimaryCasting", "CollectorCraneSecondaryCasting",
    "CollectorCranePrimaryCapRail", "CollectorCraneStickCapRail",
    "CollectorCraneDiagonalStiffener", "CollectorCraneStickWeb",
    "CollectorCraneElbowGuard", "CollectorCraneElbowShaft",
    "CollectorCraneElbowWasher", "CollectorCraneLiftCylinder",
    "CollectorCraneLiftPiston", "CollectorCraneLiftSeal",
    "CollectorCraneStickCylinder", "CollectorCraneStickPiston",
    "CollectorCranePressureHose", "CollectorCraneStickHose",
    "CollectorCraneSheave", "CollectorCraneSheaveAxle",
    "CollectorCraneSheaveFork", "CollectorCraneSheaveGuard",
]
const TICK_SECONDS: float = 1.0 / 30.0

static func animated_features_for(key: String) -> Array:
    var features: Array = (MOTION_FEATURES.get(key, []) as Array).duplicate()
    if key == "SCRAP_COLLECTOR":
        features.append_array(CRANE_SLEW_FEATURES)
    return features

var _model: Node3D
var facility_key: String = ""
var _parts: Dictionary = {}
var _body_yaw: float = 0.0
var _model_scale: float = 1.0
var _clock: float = 0.0
var _accumulator: float = 0.0
const MATERIAL_SECONDS = {"LABO":21.2, "SMELTER":7.2, "RECYCLER":6.4, "STORAGE":7.5}
var _material_running: bool = false
var _material_has_completed: bool = false
var _print_variant: int = 0
var _next_print_variant: int = 0
var _intake_preparing: bool = false
var _intake_received: int = 0
const INTAKE_LOCAL = {
    "SMELTER": Vector3(-1.66,1.58,0.86),
    "RECYCLER": Vector3(0.0,2.68,-0.62),
    "LABO": Vector3(-2.05,1.28,1.45),
    "STORAGE": Vector3(-1.20,1.09,1.18)}
const INTAKE_CLEAR_HEIGHT = {"SMELTER":3.4,"RECYCLER":3.35,"LABO":4.05,"STORAGE":3.25}
const PRINT_FEATURES = ["FreshLabPrintedShell","LabPrintedGear","LabPrintedArmor","LabPrintedJoint"]

func material_intake_world() -> Vector3:
    return _model.to_global(_at(INTAKE_LOCAL[facility_key]))

# Raw salvage is released onto the actual rear gravity feed and then
# slides into the center line of the two cutter shafts.
func recycler_salvage_drop_world(slot: int) -> Vector3:
    return _model.to_global(_at(Vector3(-0.40+0.80*float(slot),2.68,-0.62)))

func recycler_salvage_world(slot: int, progress: float) -> Vector3:
    var x: float = -0.40+0.80*float(slot)
    var staged := Vector3(x,2.02,-0.62)
    var throat := Vector3(x,1.10,0.22)
    return _model.to_global(_at(staged.lerp(throat,clampf(progress,0.0,1.0))))

func material_support_world() -> Vector3:
    # Actual structural anchor, not a free-floating beam end.
    var supports := {"SMELTER":Vector3(-1.12,0.75,0.69),
        "RECYCLER":Vector3(1.12,1.57,0.22),
        "LABO":Vector3(-2.30,0.0,1.45),
        "STORAGE":Vector3(-1.20,2.55,1.02)}
    return _model.to_global(_at(supports[facility_key]))

func material_rail_world_y() -> float:
    return _model.to_global(_at(Vector3(0,float(INTAKE_CLEAR_HEIGHT[facility_key]),0))).y

func material_print_variant() -> int:
    return _print_variant

func prepare_material_intake() -> void:
    _intake_preparing = true
    _intake_received = 0
    sample_at(float(MATERIAL_SECONDS[facility_key])-0.001)

func receive_material_item() -> void:
    _intake_received = mini(2,_intake_received+1)
    sample_at(float(MATERIAL_SECONDS[facility_key])-0.001)

func begin_material_cycle() -> void:
    if not MATERIAL_SECONDS.has(facility_key):
        return
    _intake_preparing = false
    if facility_key == "LABO":
        _print_variant = _next_print_variant
        _next_print_variant = (_next_print_variant + 1) % PRINT_FEATURES.size()
    _clock = 0.0
    _accumulator = 0.0
    _material_running = true
    sample_at(0.0)

func material_cycle_complete() -> bool:
    return not _material_running

func bind_to(model: Node3D, key: String) -> void:
    var source: Dictionary = model.get_meta("motion_entries", {})
    var expected: Array = animated_features_for(key)
    if key == "NEXUS" and model.get_meta("base_design", "") != "NEXUS_COMMAND_BUNKER_20261124":
        expected = []
    for feature in expected:
        if not source.has(feature) or (source[feature] as Array).is_empty():
            push_warning("SERA_BASE_MOTION_MISSING: " + key + "/" + str(feature))
    name = "FacilityMotion"
    _model = model
    facility_key = key
    _parts = source
    _body_yaw = float(model.get_meta("body_yaw", 0.0))
    _model_scale = float(model.get_meta("visual_model_scale", 1.0))
    model.add_child(self)
    # No processing for models without animated instances.
    set_process(not expected.is_empty())
    if not expected.is_empty():
        # Idle pose shows finished/stowed equipment; first real delivery starts the batch.
        sample_at(float(MATERIAL_SECONDS.get(key, 0.0)) - 0.001 if MATERIAL_SECONDS.has(key) else 0.0)

func _process(delta: float) -> void:
    if MATERIAL_SECONDS.has(facility_key) and not _material_running:
        return
    _clock += maxf(0.0, delta)
    if _material_running and _clock >= float(MATERIAL_SECONDS[facility_key]):
        _clock = float(MATERIAL_SECONDS[facility_key]) - 0.001
        sample_at(_clock)
        _material_running = false
        _material_has_completed = true
        return
    _accumulator += maxf(0.0, delta)
    # A stable 30Hz animation cap amortizes MultiMesh transform uploads on
    # Android without storing a new copy of any geometry or spawning timers.
    if _accumulator < TICK_SECONDS:
        return
    _accumulator = fmod(_accumulator, TICK_SECONDS)
    sample_at(_clock)

func _at(local: Vector3) -> Vector3:
    return Basis(Vector3.UP, _body_yaw) * (local * _model_scale)

func _axis(local: Vector3) -> Vector3:
    return Basis(Vector3.UP, _body_yaw) * local

func _spin_about(base: Transform3D, center: Vector3,
        axis: Vector3, angle: float) -> Transform3D:
    var rotation := Basis(axis.normalized(), angle)
    return Transform3D(rotation * base.basis,
        center + rotation * (base.origin - center))

func part_pose(feature: String, slot: int = 0) -> Transform3D:
    var records: Array = _parts.get(feature, [])
    if slot < 0 or slot >= records.size():
        return Transform3D.IDENTITY
    var record: Dictionary = records[slot]
    var multi: MultiMesh = record["mesh"] as MultiMesh
    return multi.get_instance_transform(int(record["index"]))

# BASE LABO: 18.2s mechanical production cell. All positions are authored
# local metres; the existing yaw and scale are applied once by _at().
const LAB_CYCLE: float = 18.2
const LAB_ARM_ROOT := Vector3(-0.43, 3.60, -0.10)
const LAB_ARM_LINK: float = 1.30
const LAB_BED_CENTER := Vector3(0.10, 1.06, 1.13)
const LAB_STOCK_CENTER := Vector3(-1.55, 1.39, 0.02)
const LAB_ARM_IDLE := Vector3(-0.55, 1.90, 0.30)

func _lab_ease(t: float, a: float, b: float) -> float:
    var u: float = clampf((t - a) / (b - a), 0.0, 1.0)
    return u * u * (3.0 - 2.0 * u)

func _lab_arm_target(t: float) -> Vector3:
    # Lift first; travel around the FRONT of the left guide column, then
    # retreat to stock from its outer side. No diagonal through the gantry.
    var up := Vector3(0.10, 1.53, 1.13)
    var front := Vector3(0.10, 1.53, 1.70)
    # Both stock hatch leaves stand upright when open (top <= 1.71 m).
    # The carried shell extends 0.20 m below its centre: cross the front
    # leaf only at 2.02 m, then descend vertically inside the opening.
    # Keep the lower pickup path clear of the printer gantry.
    var outer := Vector3(-1.78, 2.02, 1.70)
    var outer_stock := Vector3(-1.78, 2.02, 0.02)
    var above_stock := Vector3(LAB_STOCK_CENTER.x, 2.02, LAB_STOCK_CENTER.z)
    var retreat := above_stock
    if t < 7.0: return LAB_ARM_IDLE
    if t < 7.45: return LAB_ARM_IDLE.lerp(Vector3(0.10, 1.90, 0.30), _lab_ease(t, 7.0, 7.45))
    if t < 8.0: return Vector3(0.10, 1.90, 0.30).lerp(up, _lab_ease(t, 7.45, 8.0))
    if t < 9.0: return up.lerp(LAB_BED_CENTER, _lab_ease(t, 8.0, 9.0))
    if t < 9.5: return LAB_BED_CENTER
    if t < 10.4: return LAB_BED_CENTER.lerp(up, _lab_ease(t, 9.5, 10.4))
    if t < 11.1: return up.lerp(front, _lab_ease(t, 10.4, 11.1))
    if t < 12.2: return front.lerp(outer, _lab_ease(t, 11.1, 12.2))
    if t < 13.0: return outer.lerp(outer_stock, _lab_ease(t, 12.2, 13.0))
    # Centre the payload over the aperture before lowering; never enter
    # diagonally across a hatch. Release and withdraw along the same axis.
    if t < 13.4: return outer_stock.lerp(above_stock, _lab_ease(t, 13.0, 13.4))
    if t < 14.2: return above_stock.lerp(LAB_STOCK_CENTER, _lab_ease(t, 13.4, 14.2))
    if t < 14.7: return LAB_STOCK_CENTER
    if t < 15.5: return LAB_STOCK_CENTER.lerp(retreat, _lab_ease(t, 14.7, 15.5))
    return retreat.lerp(LAB_ARM_IDLE, _lab_ease(t, 15.5, 17.0))

func _lab_segment(a: Vector3, b: Vector3, width: float, depth: float) -> Transform3D:
    var direction: Vector3 = b - a
    var length: float = maxf(direction.length(), 0.001)
    var axis: Vector3 = direction / length
    var local_basis := Basis(Quaternion(Vector3.UP, axis))
    local_basis = local_basis.scaled_local(Vector3(width, length, depth) * _model_scale)
    return Transform3D(Basis(Vector3.UP, _body_yaw) * local_basis, _at((a + b) * 0.5))

func _lab_position(rest: Transform3D, local: Vector3) -> Transform3D:
    return Transform3D(rest.basis, _at(local))

func _lab_pose(feature: String, slot: int, rest: Transform3D, t: float,
        target: Vector3, elbow: Vector3, wrist: Vector3) -> Transform3D:
    # Ring toolpath and monotonic layer height. The carriage stays on its
    # guide; the gold telescoping head follows the advancing build surface.
    var progress: float = clampf((t - 0.35) / 5.65, 0.025, 1.0)
    var x: float = 0.10 + 0.29 * cos(t * TAU / 1.15)
    var z: float = 1.13 + 0.25 * sin(t * TAU / 1.15)
    var tip_y: float = 0.86 + 0.40 * progress + 0.12
    if t > 6.0:
        var park: float = _lab_ease(t, 6.0, 7.0)
        x = lerpf(0.10 + 0.29 * cos(6.0 * TAU / 1.15), 0.57, park)
        z = lerpf(1.13 + 0.25 * sin(6.0 * TAU / 1.15), 1.08, park)
        tip_y = lerpf(1.38, 2.15, park)
    var grip: float = _lab_ease(t, 9.0, 9.5) * (1.0 - _lab_ease(t, 14.2, 14.7))
    var lift: float = _lab_ease(t, 1.4, 2.4) * (1.0 - _lab_ease(t, 15.5, 16.4))
    var opening: float = _lab_ease(t, 0.4, 1.4) * (1.0 - _lab_ease(t, 16.4, 17.2))
    var hand := target + Vector3(0, 0.34, 0)
    match feature:
        "LabMetalFeedSpool":
            return _spin_about(rest, rest.origin, _axis(Vector3.BACK), minf(t, 6.0)*2.0)
        "FreshLabPrinterServo":
            return _lab_position(rest, Vector3(x, 2.40, 1.05))
        "FreshLabPrinterHotHead":
            return _lab_segment(Vector3(x, tip_y + 0.08, z),
                Vector3(x, 2.27, z), 0.39, 0.39)
        "FreshLabPrinterTip":
            return _lab_position(rest, Vector3(x, tip_y, z))
        "FreshLabPrintedShell", "LabPrintedGear", "LabPrintedArmor", "LabPrintedJoint":
            if feature != PRINT_FEATURES[_print_variant] or t >= 17.2:
                return Transform3D(rest.basis.scaled_local(Vector3.ONE * 0.0001), rest.origin)
            if t < 6.0:
                # Keep the bottom fixed to the fabrication bed while growing.
                return Transform3D(rest.basis.scaled_local(Vector3(1, progress, 1)),
                    _at(Vector3(0.10, 0.86 + 0.20 * progress, 1.13)))
            if t < 9.5:
                return _lab_position(rest, LAB_BED_CENTER)
            if t < 14.2:
                return _lab_position(rest, target)
            return _lab_position(rest, LAB_STOCK_CENTER - Vector3(0,
                0.45 * _lab_ease(t, 15.5, 16.4), 0))
        "LabArmLinkA":
            return _lab_segment(LAB_ARM_ROOT, elbow, 0.28, 0.28)
        "LabArmLinkB":
            return _lab_segment(elbow, wrist, 0.25, 0.25)
        "LabArmElbow":
            return _lab_position(rest, elbow)
        "LabArmWristHub":
            return _lab_position(rest, wrist)
        "LabArmWristShaft":
            return _lab_segment(Vector3(wrist.x, hand.y, wrist.z),
                wrist, 0.15, 0.15)
        "LabArmWristOffset":
            return _lab_position(rest, hand + Vector3(0, 0, 0.17))
        "LabArmGripBody":
            return _lab_position(rest, hand)
        "LabArmGripJaw":
            var side: float = -1.0 if slot == 0 else 1.0
            return _lab_position(rest, target + Vector3(
                side * lerpf(0.56, 0.45, grip), 0.08, 0))
        "LabStockLift":
            return _lab_position(rest, Vector3(-1.55, 0.69 + 0.45 * lift, 0.02))
        "LabStockShutter":
            var side: float = -1.0 if slot == 0 else 1.0
            return _spin_about(rest, _at(Vector3(-1.55, 1.20, 0.02 + side * 0.47)),
                _axis(Vector3.RIGHT), side * opening * PI * 0.5)
    return rest


# Distinct hold / traverse phases make the dish acquire a target rather
# than spin like a factory motor. Angles interpolate with zero end velocity.
func _nexus_scan(t: float) -> Vector2:
    var phase: float = fposmod(t, 19.0)
    if phase < 3.0: return Vector2(-0.65, 0.38)
    if phase < 7.0: return Vector2(-0.65, 0.38).lerp(Vector2(0.84, 0.62), smoothstep(3.0, 7.0, phase))
    if phase < 11.0: return Vector2(0.84, 0.62)
    if phase < 14.0: return Vector2(0.84, 0.62).lerp(Vector2(0.10, 0.27), smoothstep(11.0, 14.0, phase))
    if phase < 16.0: return Vector2(0.10, 0.27)
    return Vector2(0.10, 0.27).lerp(Vector2(-0.65, 0.38), smoothstep(16.0, 19.0, phase))

func _nexus_pose(feature: String, slot: int, rest: Transform3D, t: float,
        scan: Vector2) -> Transform3D:
    var pose: Transform3D = rest
    match feature:
        "NexusServiceAwning":
            # Wind travels between the two bays. Their shared and outer
            # edges remain fixed to the frame, even during the strongest gust.
            var phase: float = t * 3.4 - float(slot) * 1.85
            var gust: float = 0.5 + 0.5 * sin(t * 0.82)
            var billow: float = 0.67 + (0.42 + 0.13 * gust) * sin(phase) + 0.12 * sin(phase * 2.0 + 0.6)
            pose.basis = rest.basis.scaled_local(Vector3(1.0, maxf(0.10, billow), 1.0))
        "NexusAwningValance":
            # The pleated skirt visibly kicks out into the wind, then
            # drops back. Rotate about the actual upper attachment line.
            var phase: float = t * 3.4 - float(slot) * 1.85 + 0.7
            var lift: float = 0.57 + 0.45 * sin(phase) + 0.16 * sin(phase * 2.0)
            var hinge: Vector3 = rest.origin + rest.basis.y * 0.5
            pose = _spin_about(rest, hinge, _axis(Vector3.RIGHT), -clampf(lift, 0.0, 1.18))
        "NexusFanBlade":
            var local: Vector3 = Basis(Vector3.UP, -_body_yaw) * rest.origin / _model_scale
            var side: float = -1.0 if local.x < 0.0 else 1.0
            var row: int = 0 if local.z < 0.48 else 1
            var center := Vector3(side * 1.99, 4.96, 0.04 + float(row) * 0.88)
            pose = _spin_about(rest, _at(center), _axis(Vector3.UP),
                t * (5.0 + float(row) * 1.2) * side)
        "NexusDishAzimuthBearing", "NexusDishYoke", "NexusDishHinge", "NexusDishReflector", "NexusDishFeedArm", "NexusDishFeed":
            var pivot: Vector3 = _at(Vector3(0, 5.90, 0.32))
            # Elevation applies to dish and its focal feed only. The yoke
            # rotates around the vertical bearing but never pitches.
            if feature in ["NexusDishReflector", "NexusDishFeedArm", "NexusDishFeed"]:
                pose = _spin_about(pose, pivot, _axis(Vector3.RIGHT), -scan.y)
            pose = _spin_about(pose, pivot, _axis(Vector3.UP), scan.x)
        "NexusAntennaYagiBoom", "NexusAntennaYagiElement":
            var angle: float = 0.52 * sin(t * 0.30 + 1.2)
            pose = _spin_about(rest, _at(Vector3(0.62, 5.68, -1.58)),
                _axis(Vector3.UP), angle)
        "NexusPlenumLouver":
            var open: float = smoothstep(0.4, 1.7, fposmod(t, 9.7)) * (
                1.0 - smoothstep(6.3, 7.6, fposmod(t, 9.7)))
            pose = _spin_about(rest, rest.origin, _axis(Vector3.RIGHT), -open * 0.78)
        "NexusSupplyDrawer", "NexusSupplyCase":
            var phase: float = fposmod(t, 13.0)
            var travel: float = smoothstep(0.5, 2.4, phase) * (1.0 - smoothstep(6.0, 8.5, phase))
            pose.origin += _at(Vector3(0.62 * travel, 0, 0))
            if feature == "NexusSupplyCase" and (phase < 1.5 or phase > 8.2):
                pose.basis = rest.basis.scaled_local(Vector3.ONE * 0.0001)
        "NexusSignalIndicator":
            var phase: float = fposmod(t + float(slot) * 0.35, 2.4)
            var glow: float = 1.0 if phase < 0.38 or phase > 2.12 else 0.001
            pose.basis = rest.basis.scaled_local(Vector3.ONE * glow)
    return pose

func sample_at(seconds: float) -> void:
    # This exact public sampler is used during normal _process and by live
    # Godot CI to compare real MultiMesh poses at multiple animation times.
    var time: float = maxf(0.0, seconds)
    var crane_phase: float = 0.0
    var crane_slew: float = 0.0
    var crane_lift: float = 0.0
    var crane_grip: float = 0.0
    var scrap_shift := Vector3.ZERO
    var scrap_rock: float = 0.0
    var crane_center := Vector3.ZERO
    var crane_rotation := Basis.IDENTITY
    if facility_key == "SCRAP_COLLECTOR":
        crane_phase = CollectorConveyor.phase_at(time)
        crane_slew = CollectorConveyor.slew_at(crane_phase)
        crane_lift = CollectorConveyor.lift_at(crane_phase)
        crane_grip = CollectorConveyor.grip_at(crane_phase)
        scrap_shift = CollectorConveyor.scrap_offset_at(crane_phase)
        scrap_rock = CollectorConveyor.scrap_rock_at(crane_phase)
        crane_center = _at(CollectorConveyor.CRANE_PIVOT)
        crane_rotation = Basis(_axis(Vector3.UP), crane_slew)
    var lab_t: float = 0.0
    var lab_target := Vector3.ZERO
    var lab_elbow := Vector3.ZERO
    var lab_wrist := Vector3.ZERO
    if facility_key == "LABO":
        lab_t = clampf(time - 3.0, 0.0, LAB_CYCLE - 0.001)
        lab_target = _lab_arm_target(lab_t)
        lab_wrist = Vector3(lab_target.x, LAB_ARM_ROOT.y, lab_target.z + 0.34)
        # Analytic two-link planar IK: both castings retain fixed lengths.
        var reach: Vector3 = lab_wrist - LAB_ARM_ROOT
        var distance: float = maxf(reach.length(), 0.001)
        var perpendicular := Vector3(-reach.z, 0, reach.x) / distance
        var offset: float = sqrt(maxf(0.0,
            LAB_ARM_LINK * LAB_ARM_LINK - distance * distance * 0.25))
        lab_elbow = LAB_ARM_ROOT + reach * 0.5 + perpendicular * offset
    var nexus_scan := Vector2.ZERO
    if facility_key == "NEXUS":
        nexus_scan = _nexus_scan(time)
    for name_variant in _parts.keys():
        var feature: String = str(name_variant)
        # The one-shot entry transition owns these transforms, not the idle cycle.
        if feature in ["NexusBlastDoor", "NexusBlastShutterSlat"]:
            continue
        var records: Array = _parts[feature]
        for i in range(records.size()):
            var record: Dictionary = records[i]
            var rest: Transform3D = record["bind"]
            var pose: Transform3D = rest
            match facility_key:
                "NEXUS":
                    pose = _nexus_pose(feature, i, rest, time, nexus_scan)
                "LABO":
                    if feature == "LabInputPellet":
                        var feed: float = smoothstep(0.15,1.2,time)
                        pose.origin += _at(Vector3(0,-0.45*feed,0))
                        if time >= 1.2:
                            pose.basis = rest.basis.scaled_local(Vector3.ONE*0.0001)
                    else:
                        pose = _lab_pose(feature, i, rest, lab_t,
                            lab_target, lab_elbow, lab_wrist)
                        if time < 3.0 and feature in PRINT_FEATURES:
                            pose.basis = rest.basis.scaled_local(Vector3.ONE*0.0001)
                "SCRAP_COLLECTOR":
                    if feature in CRANE_SLEW_FEATURES:
                        # All sculpted upper boom parts share one genuine
                        # turntable pivot, including their hydraulic plumbing.
                        pose = _spin_about(rest, crane_center,
                            _axis(Vector3.UP), crane_slew)
                    elif feature == "FreshCollectorConveyorFlight":
                        # A moving wide tread pattern on the static belt.
                        var belt_local: Vector3 = Basis(
                            Vector3.UP, -_body_yaw) * rest.origin / _model_scale
                        var belt_span: float = (
                            CollectorConveyor.BELT_PICKUP_X -
                            CollectorConveyor.BELT_START_X)
                        var shifted: float = fposmod(
                            belt_local.x - CollectorConveyor.BELT_START_X +
                            time * CollectorConveyor.BELT_SPEED, belt_span)
                        pose.origin += _at(Vector3(
                            CollectorConveyor.BELT_START_X + shifted -
                            belt_local.x, 0.0, 0.0))
                    elif feature == "FreshCollectorPickupScrap":
                        # One continuous two-part parcel, never exchanged
                        # for a separate payload. Before gripping it rides
                        # the belt, jolts up the ramp and settles.
                        if crane_phase < 3.72:
                            pose.origin += _at(scrap_shift)
                            if absf(scrap_rock) > 0.00001:
                                pose = _spin_about(pose,
                                    _at(Vector3(
                                        CollectorConveyor.BELT_START_X,
                                        CollectorConveyor.SCRAP_BELT_Y,
                                        CollectorConveyor.BELT_Z) + scrap_shift),
                                    # +Z pitches the leading (+X) edge
                                    # upward while climbing the ramp.
                                    _axis(Vector3.BACK), scrap_rock)
                        else:
                            # Anchor the exact last resting pose to the
                            # crane, rotating around its real slewing axis.
                            # At the instant of capture, angle and height
                            # deltas are zero: no jump or mesh swapping.
                            var settled: Vector3 = (
                                CollectorConveyor.scrap_offset_at(
                                    CollectorConveyor.SCRAP_SETTLE_FINISH))
                            pose.origin += _at(settled)
                            pose = _spin_about(pose, crane_center,
                                _axis(Vector3.UP),
                                crane_slew - CollectorConveyor.PICKUP_ANGLE)
                            pose.origin += _at(Vector3(0.0,
                                crane_lift -
                                CollectorConveyor.SCRAP_PICKUP_LIFT, 0.0))
                            if crane_phase > 6.14:
                                pose.origin += _at(Vector3(0.0,
                                    -0.42 * smoothstep(
                                        6.14, 6.54, crane_phase), 0.0))
                            if crane_phase >= 6.54:
                                pose.basis = pose.basis.scaled_local(
                                    Vector3.ONE * 0.0001)
                    elif feature in ["FreshCollectorSuspendedCable",
                            "FreshCollectorClawHead",
                            "FreshCollectorJawHinge", "FreshCollectorOpenGrip"]:
                        # Hook, jaws and payload inherit the boom's real yaw.
                        pose = _spin_about(rest, crane_center,
                            _axis(Vector3.UP), crane_slew)
                        if feature == "FreshCollectorSuspendedCable":
                            # Cable top stays attached to the final sheave:
                            # only its lower end follows the hoisting winch.
                            pose.origin += _at(
                                Vector3(0.0, crane_lift * 0.5, 0.0))
                            pose.basis = pose.basis.scaled_local(
                                Vector3(1.0,
                                    (CollectorConveyor.HOIST_CABLE_LENGTH -
                                    crane_lift) /
                                    CollectorConveyor.HOIST_CABLE_LENGTH,
                                    1.0))
                        else:
                            pose.origin += _at(Vector3(0.0, crane_lift, 0.0))
                            if feature == "FreshCollectorOpenGrip":
                                # Two submeshes per jaw share the actual pin.
                                var side: float = (
                                    -1.0 if i % 2 == 0 else 1.0)
                                var row: float = (
                                    -1.0 if posmod(i, 4) < 2 else 1.0)
                                var jaw_pin := Vector3(
                                    CollectorConveyor.CRANE_TIP_X +
                                    side * 0.24, 1.72,
                                    CollectorConveyor.CRANE_TIP_Z +
                                    row * 0.21) + CollectorConveyor.CRANE_OFFSET
                                var jaw_world: Vector3 = (
                                    crane_center + crane_rotation *
                                    (_at(jaw_pin) - crane_center) +
                                    _at(Vector3(0.0, crane_lift, 0.0)))
                                # Godot's FORWARD is local -Z: it would
                                # rotate both finger pairs inward when the
                                # controller requests OPEN. Positive local
                                # Z (BACK) makes side*angle spread fingers.
                                pose = _spin_about(pose, jaw_world,
                                    crane_rotation * _axis(Vector3.BACK),
                                    side * crane_grip)
                "SMELTER":
                    var t: float = minf(time, 7.199)
                    if feature == "SmelterChargeGate":
                        pose.origin += _at(Vector3(-0.66 * (1.0-smoothstep(1.5,2.4,t)),0,0))
                    elif feature == "SmelterFeedScrap":
                        pose.origin += _at(Vector3(0.45*smoothstep(0.3,2.1,t), -0.43*smoothstep(0.3,2.1,t), -0.15*smoothstep(0.3,2.1,t)))
                        if t >= 2.1:
                            pose.basis = rest.basis.scaled_local(Vector3.ONE * 0.0001)
                    elif feature == "SmelterMoltenPour":
                        var fill: float = smoothstep(2.4, 4.2, t) * (1.0-smoothstep(4.2, 5.2, t))
                        pose.basis = rest.basis.scaled_local(Vector3.ONE * maxf(0.0001, fill))
                    elif feature == "SmelterCastIngot":
                        var cast: float = smoothstep(4.2, 5.2, t)
                        pose.basis = rest.basis.scaled_local(Vector3(1, maxf(0.0001, cast), 1))
                        pose.origin += _at(Vector3(0, -0.07*(1.0-cast), 0.20*smoothstep(5.6, 6.7,t)))
                        if t < 4.2 or t >= 7.0:
                            pose.basis = rest.basis.scaled_local(Vector3.ONE * 0.0001)
                "RECYCLER":
                    var t: float = minf(time, 6.399)
                    if feature in ["FreshRecyclerRoller", "FreshRecyclerTooth"]:
                        var local: Vector3 = Basis(Vector3.UP, -_body_yaw) * rest.origin / _model_scale
                        var side: float = 1.0 if local.z > 0.22 else -1.0
                        var center: Vector3 = _at(Vector3(0.0, 1.37, 0.22 + side * 0.39))
                        pose = _spin_about(rest, center, _axis(Vector3.RIGHT), t * 2.0 * side)
                    elif feature == "RecyclerRecoveredPart":
                        var slide: float = smoothstep(2.6+i*0.4, 4.6+i*0.4, t)
                        pose.origin += _at(Vector3(0, -0.25*slide, 0.76*slide))
                        if t < 2.6+i*0.4 or t >= 6.0:
                            pose.basis = rest.basis.scaled_local(Vector3.ONE * 0.0001)
                "GENERATOR":
                    if feature == "FreshGeneratorRotorBlade":
                        pose = _spin_about(rest, _at(Vector3(-0.27, 1.43, 1.16)),
                            _axis(Vector3.BACK), time * 2.4)
                    elif feature == "FreshGeneratorMeterRow":
                        var level: float = 0.42 + 0.58*(0.5+0.5*sin(time*1.6+float(i)*0.9))
                        pose.basis = rest.basis.scaled_local(Vector3(level, 1, 1))
                        pose.origin -= _at(Vector3(0.175*(1.0-level),0,0))
                "STORAGE":
                    var t: float = minf(time, 7.499)
                    var lift: float = smoothstep(0.4, 2.0, t) * (1.0-smoothstep(5.8,7.3,t))
                    var across: float = smoothstep(2.0, 2.8, t) * (1.0-smoothstep(5.1,5.8,t))
                    var inward: float = smoothstep(2.8, 3.8, t) * (1.0-smoothstep(4.1,5.1,t))
                    if feature == "FreshStorageLoadingLift":
                        pose.origin += _at(Vector3(0, 0.57*lift, 0))
                    elif feature in ["StorageStoredCase", "StorageStoredLock"]:
                        # Previous buffered case transfers into the rear stock
                        # chamber before the next case is delivered to this bay.
                        if t < 0.6 and _material_has_completed:
                            pose.origin += _at(Vector3(0,0,-0.66*smoothstep(0.0,0.6,t)))
                        elif t < 3.8 or (not _material_running and not _material_has_completed):
                            pose.basis = rest.basis.scaled_local(Vector3.ONE*0.0001)
                    else:
                        pose.origin += _at(Vector3(0.65*across, 0.57*lift, -1.56*inward))
                        if feature != "StorageTransferFork" and (t < 0.25 or t >= 3.8):
                            pose.basis = rest.basis.scaled_local(Vector3.ONE*0.0001)
                "BUILD_TERMINAL":
                    var phase: float = fposmod(time, 8.5)
                    var press: float = smoothstep(1.0, 2.2, phase) * (1.0-smoothstep(4.3,5.8,phase))
                    if feature == "FreshBuildModuleLock":
                        pose.origin += _at(Vector3(0, 0.20*(1.0-smoothstep(1.0,3.1,phase)),0))
                    else:
                        pose = _spin_about(rest, _at(Vector3(0.74,1.53,0.78)),
                            _axis(Vector3.BACK), 0.24*press)
            # While the hoist is delivering, show material only after it
            # reaches the mouth. Keep the side charge gate open until fed.
            if _intake_preparing:
                if feature == "SmelterChargeGate":
                    pose = rest
                    pose.origin += _at(Vector3(-0.66,0,0))
                elif feature in ["SmelterFeedScrap","LabInputPellet"]:
                    pose = rest
                    if _intake_received == 0 or (i > 0 and _intake_received == 1):
                        pose.basis = rest.basis.scaled_local(Vector3.ONE*0.0001)
            var multi: MultiMesh = record["mesh"] as MultiMesh
            multi.set_instance_transform(int(record["index"]), pose)
            # Same indexed transform as its real opaque part: no trailing or
            # detached lines while the printer / cutter / crane animates.
            if record.has("ink_mesh"):
                var ink_mesh: MultiMesh = record["ink_mesh"] as MultiMesh
                ink_mesh.set_instance_transform(int(record["ink_index"]), pose)
            # The independent 2px front-corner pass follows the same moving
            # part with no drift, just like its SERA-style 6px silhouette.
            if record.has("crease_mesh"):
                var crease_mesh: MultiMesh = record["crease_mesh"] as MultiMesh
                crease_mesh.set_instance_transform(
                    int(record["crease_index"]), pose)
    # Explicit 30 Hz marker for the shared ID viewport. In-place MultiMesh
    # updates do not change resource identity or node transforms.
    if is_instance_valid(_model):
        _model.set_meta("sera_outline_pose_stamp",
            int(_model.get_meta("sera_outline_pose_stamp", 0)) + 1)
