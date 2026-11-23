extends Node
const CollectorConveyor = preload("res://scripts/sera_base_collector_conveyor.gd")
## BASE equipment: eight deterministic production-loop motions of actual existing
## authored MultiMesh instances. No additional 3D draw nodes, colliders or lights.
## Animated positions are in the same local coordinates as the authored model.
## The already-restored archived NEXUS geometry is never replaced or reauthored.

const MOTION_FEATURES: Dictionary = {
    # NEXUS antennas are now rigid. Only the beacon's emissive diode
    # toggles on Morse-like timer events in BaseFacilityVFX.
    "NEXUS": [],
    "LABO": ["FreshLabPrinterServo", "FreshLabPrinterHotHead",
        "FreshLabPrinterTip", "FreshLabPrintedShell"],
    "SCRAP_COLLECTOR": ["FreshCollectorSuspendedCable", "FreshCollectorClawHead",
        "FreshCollectorJawHinge", "FreshCollectorOpenGrip",
        "FreshCollectorConveyorFlight", "FreshCollectorPickupScrap",
        "FreshCollectorCranePayload"],
    "SMELTER": ["FreshSmelterFlameTongue", "FreshSmelterLowFire"],
    "RECYCLER": ["FreshRecyclerRoller", "FreshRecyclerTooth"],
    "GENERATOR": ["FreshGeneratorRotorBlade"],
    "STORAGE": ["FreshStorageLoadingLift"],
    "BUILD_TERMINAL": ["FreshTerminalBlueprintRows", "FreshTerminalMastLamp"],
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

func bind_to(model: Node3D, key: String) -> void:
    var source: Dictionary = model.get_meta("motion_entries", {})
    var expected: Array = animated_features_for(key)
    for feature in expected:
        if not source.has(feature) or (source[feature] as Array).is_empty():
            push_error("SERA_BASE_MOTION_MISSING: " + key + "/" + str(feature))
            return
    name = "FacilityMotion"
    _model = model
    facility_key = key
    _parts = source
    _body_yaw = float(model.get_meta("body_yaw", 0.0))
    _model_scale = float(model.get_meta("visual_model_scale", 1.0))
    model.add_child(self)
    # Stop per-frame work (and GPU MultiMesh uploads) for static NEXUS.
    set_process(not expected.is_empty())
    if not expected.is_empty():
        sample_at(0.0)

func _process(delta: float) -> void:
    _clock += maxf(0.0, delta)
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
    for name_variant in _parts.keys():
        var feature: String = str(name_variant)
        var records: Array = _parts[feature]
        for i in range(records.size()):
            var record: Dictionary = records[i]
            var rest: Transform3D = record["bind"]
            var pose: Transform3D = rest
            match facility_key:
                "LABO":
                    if feature in ["FreshLabPrinterServo",
                            "FreshLabPrinterHotHead", "FreshLabPrinterTip"]:
                        # The entire nozzle carriage travels together, not the
                        # whole workshop or the motionless external frame.
                        pose.origin += _at(Vector3(0.49 * sin(time * 1.35), 0, 0))
                    elif feature == "FreshLabPrintedShell":
                        var progress: float = 0.72 + 0.28 * (
                            0.5 + 0.5 * sin(time * 0.70 - 1.10))
                        pose.basis = rest.basis.scaled_local(
                            Vector3(1.0, progress, 1.0))
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
                        # Both visible fragments share ONE common rigid
                        # pose: belt travel, a short rise onto the metal
                        # plate, a single clunk/rock, and damped settling.
                        pose.origin += _at(scrap_shift)
                        if absf(scrap_rock) > 0.00001:
                            pose = _spin_about(pose,
                                _at(Vector3(
                                    CollectorConveyor.BELT_START_X, 1.02,
                                    CollectorConveyor.BELT_Z) + scrap_shift),
                                _axis(Vector3.FORWARD), scrap_rock)
                        # Swap to the attached payload ONLY once closed.
                        if crane_phase >= 3.72:
                            pose.basis = rest.basis.scaled_local(
                                Vector3.ONE * 0.0001)
                    elif feature in ["FreshCollectorSuspendedCable",
                            "FreshCollectorClawHead",
                            "FreshCollectorJawHinge", "FreshCollectorOpenGrip",
                            "FreshCollectorCranePayload"]:
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
                                pose = _spin_about(pose, jaw_world,
                                    crane_rotation * _axis(Vector3.FORWARD),
                                    side * crane_grip)
                            elif feature == "FreshCollectorCranePayload":
                                # Never show two copies at the handoff.
                                # Once released, fall into the real hopper.
                                if crane_phase < 3.72 or crane_phase >= 6.54:
                                    pose.basis = rest.basis.scaled_local(
                                        Vector3.ONE * 0.0001)
                                elif crane_phase > 6.14:
                                    pose.origin += _at(Vector3(0.0,
                                        -0.42 * smoothstep(
                                            6.14, 6.54, crane_phase), 0.0))
                "SMELTER":
                    if feature == "FreshSmelterFlameTongue":
                        # Irregular phase offsets prevent all four heat tongues
                        # from expanding in perfect synchrony.
                        var heat: float = 0.73 + 0.24 * (
                            0.5 + 0.5 * sin(time * 5.0 + float(i) * 1.9))
                        pose.basis = rest.basis.scaled_local(
                            Vector3(1.0, heat, 1.0))
                        pose.origin += _at(Vector3(0, (heat - 0.73) * 0.09, 0))
                    elif feature == "FreshSmelterLowFire":
                        pose.basis = rest.basis.scaled_local(
                            Vector3(0.86 + 0.12 * sin(time * 4.1), 1.0, 1.0))
                "RECYCLER":
                    if feature in ["FreshRecyclerRoller", "FreshRecyclerTooth"]:
                        # Two X-axis cutter shafts counter-rotate about their
                        # common centers, including every individual tooth.
                        var local: Vector3 = Basis(
                            Vector3.UP, -_body_yaw) * rest.origin / _model_scale
                        var side: float = 1.0 if local.z > 0.22 else -1.0
                        var center: Vector3 = _at(
                            Vector3(0.0, 1.37, 0.22 + side * 0.39))
                        pose = _spin_about(rest, center,
                            _axis(Vector3.RIGHT), time * 2.0 * side)
                "GENERATOR":
                    if feature == "FreshGeneratorRotorBlade":
                        # Visible front fan is on the +Z surface: spin around
                        # its *normal*, not the entire station's Y axis.
                        pose = _spin_about(rest,
                            _at(Vector3(-0.27, 1.43, 1.16)),
                            _axis(Vector3.BACK), time * 2.4)
                "STORAGE":
                    if feature == "FreshStorageLoadingLift":
                        pose.origin += _at(
                            Vector3(0.0, 0.25 * (0.5 +
                                0.5 * sin(time * 1.15)), 0.0))
                "BUILD_TERMINAL":
                    if feature == "FreshTerminalBlueprintRows":
                        pose.origin += _at(Vector3(0.0,
                            0.11 * sin(time * 2.1 + float(i) * 0.62), 0.0))
                    elif feature == "FreshTerminalMastLamp":
                        var blink: float = 0.93 + 0.19 * (
                            0.5 + 0.5 * sin(time * 3.4))
                        pose.basis = rest.basis.scaled_local(
                            Vector3(blink, blink, blink))
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
