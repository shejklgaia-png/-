extends SceneTree
## Real Godot scene: shape-upgrade batch, preserved eight interactive
## front-facing stations and unchanged 152 site decorative placements.
const Arch = preload("res://scripts/sera_base_architecture.gd")
const Mass = preload("res://scripts/sera_base_structural_mass.gd")
const Features = {
    "NEXUS": ["NexusCornerButtress", "NexusRoofGutter"],
    "LABO": ["LabAFrameRidge", "LabAngledSideRoof", "LabRollUpServiceBay"],
    "SCRAP_COLLECTOR": ["CollectorCraneCounterweight", "CollectorDiagonalArmBrace"],
    "SMELTER": ["SmelterSecondaryExhaust", "SmelterWindBaffle"],
    "RECYCLER": ["RecyclerSplayedArmorJaw", "RecyclerCantedCowl"],
    "GENERATOR": ["GeneratorExternalCoolingDrum", "GeneratorRibbedTurbineGuard"],
    "STORAGE": ["StorageRaisedLoadingFrame", "StorageTarpSaddle"],
    "BUILD_TERMINAL": ["TerminalSlopedRoofWing", "TerminalToolHatch"],
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_STRUCTURAL_MASS_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _step in range(28):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null:
            break
    var camera: Camera3D = hub.get("cam") as Camera3D
    var stations: Node3D = hub.get_node("BaseFacilities") as Node3D
    var nexus: Node3D = hub.get_node("NEXUSBuilding") as Node3D
    var view: Vector2 = camera.get_viewport().get_visible_rect().size
    var total: int = 0
    for key in Features:
        var building: Node3D = nexus if key == "NEXUS" else (
            stations.get_node(key) as Node3D)
        var model: Node3D = building.get_node(
            "NexusArchitecture" if key == "NEXUS" else "IndustrialModel") as Node3D
        var features: Array = model.get_meta("unique_model_features", [])
        var model_scale: float = float(model.get_meta("visual_model_scale", 0.0))
        var expected_scale: float = (
            1.14 if key == "NEXUS" else
            1.45 if key == "LABO" else 1.55)
        if absf(model_scale - expected_scale) > 0.001:
            _fail(key + " facility footprint / model scale changed")
            return
        for feature in Features[key]:
            if not features.has(feature):
                _fail(key + " shape is missing real batch geometry: " + feature)
                return
        var props: Array = model.get_meta("clutter_props", [])
        total += props.size()
        var capture_host := Node3D.new()
        var probe := Arch.Batch.new(capture_host)
        Mass.add_details(probe, key)
        if probe.entries.is_empty():
            _fail(key + " structural model created no polygon batches")
            capture_host.free()
            return
        var tilted: bool = false
        for rows in probe.entries.values():
            for raw in rows:
                var pose: Transform3D = raw
                if absf(pose.basis.x.y) > 0.05 or absf(pose.basis.z.y) > 0.05:
                    tilted = true
                    break
            if tilted:
                break
        capture_host.free()
        if not tilted:
            _fail(key + " has no visibly sloped roof/brace geometry")
            return
        var center: Vector2 = camera.unproject_position(
            building.global_position + Vector3(0, 1.0, 0))
        if key == "NEXUS":
            if not bool(hub.call("_nexus_hit", center)):
                _fail("NEXUS lost its tap area")
                return
        elif str(stations.call("key_at", camera, center)) != key:
            _fail(key + " moved off its tap area")
            return
        if key == "LABO":
            var uv: Vector2 = camera.unproject_position(
                building.global_position) / view
            if uv.y < 0.683 or uv.y > 0.693:
                _fail("LABO was not moved down 22px: " + str(uv))
                return
    if total != 152:
        _fail("site clutter changed from 152 modeled placements: " + str(total))
        return
    print("SERA_BASE_STRUCTURAL_MASS_RUNTIME_PASS eight sculpted buildings / LABO lower / 152 props")
    quit(0)
