extends SceneTree
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_PALETTE_CANOPY_FAIL: "+reason)
    quit(1)

func _run() -> void:
    var hub: Node3D=load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for frame in range(24):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") != null:
            break
    var floor: Node3D=hub.get_node_or_null("PatchworkSteelFloor") as Node3D
    var nexus: Node3D=hub.get_node_or_null("NEXUSBuilding/NexusArchitecture") as Node3D
    var lab: Node3D=hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") as Node3D
    if floor == null or nexus == null or lab == null:
        _fail("actual BASE was not built")
        return
    var expected := [
        "#1e2326","#252729","#292b2a",
        "#27292c","#21262a","#302c29",
    ]
    for i in range(6):
        var draw: MultiMeshInstance3D = floor.get_node_or_null(
            "GridPlateBatch_%02d" % i) as MultiMeshInstance3D
        if draw == null:
            _fail("steel floor six-batch draw lost")
            return
        var material: StandardMaterial3D=draw.material_override as StandardMaterial3D
        if material == null or material.albedo_color != Color(expected[i]):
            _fail("mismatched distinct industrial deck tone: "+str(i))
            return
        var tone: Color=material.albedo_color
        if maxf(maxf(tone.r,tone.g),tone.b) > 0.23 or material.roughness < 0.92:
            _fail("floor must remain visibly darker than building")
            return
    for building in [nexus,lab]:
        var canvas: MultiMeshInstance3D=building.get_node_or_null(
            "Architectural_canvas_cloth") as MultiMeshInstance3D
        if canvas == null:
            _fail("textured canopy/canvas was lost")
            return
        var material: StandardMaterial3D=canvas.material_override as StandardMaterial3D
        if material == null or material.albedo_color != Color("#68685f"):
            _fail("weathered workshop canvas is not muted")
            return
    print("SERA_BASE_PALETTE_CANOPY_RUNTIME_PASS")
    quit(0)
