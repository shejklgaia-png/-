extends Node
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
        "FreshCollectorJawHinge", "FreshCollectorOpenGrip"],
    "SMELTER": ["FreshSmelterFlameTongue", "FreshSmelterLowFire"],
    "RECYCLER": ["FreshRecyclerRoller", "FreshRecyclerTooth"],
    "GENERATOR": ["FreshGeneratorRotorBlade"],
    "STORAGE": ["FreshStorageLoadingLift"],
    "BUILD_TERMINAL": ["FreshTerminalBlueprintRows", "FreshTerminalMastLamp"],
}
const TICK_SECONDS: float = 1.0 / 30.0

var _model: Node3D
var facility_key: String = ""
var _parts: Dictionary = {}
var _body_yaw: float = 0.0
var _model_scale: float = 1.0
var _clock: float = 0.0
var _accumulator: float = 0.0

func bind_to(model: Node3D, key: String) -> void:
    var source: Dictionary = model.get_meta("motion_entries", {})
    var expected: Array = MOTION_FEATURES.get(key, [])
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
                    var hoist: float = 0.16 * sin(time * 1.17)
                    var sway: float = 0.06 * sin(time * 0.70)
                    if feature == "FreshCollectorSuspendedCable":
                        pose.origin += _at(Vector3(sway * 0.5, hoist * 0.5, 0))
                        pose.basis = rest.basis.scaled_local(
                            Vector3(1.0, 1.0 - hoist / 0.70, 1.0))
                    else:
                        pose.origin += _at(Vector3(sway, hoist, 0))
                        if feature == "FreshCollectorOpenGrip":
                            var grip: float = 0.20 * sin(time * 1.17 + 0.7)
                            var side: float = -1.0 if i % 2 == 0 else 1.0
                            pose.basis = Basis(
                                _axis(Vector3.FORWARD), grip * side) * rest.basis
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
