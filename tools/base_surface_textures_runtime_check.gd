extends SceneTree
## Real Godot 4.7 material binding test. BASE builds after its startup overlay.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_SURFACE_TEXTURE_FAIL: " + message)
    quit(1)

func _material_for(group: Node3D, tint: String) -> StandardMaterial3D:
    for child in group.get_children():
        if child is MultiMeshInstance3D and child.name == "Architectural_cube_" + tint:
            return child.material_override as StandardMaterial3D
    return null

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    var floor: Node3D = null
    var nexus: Node3D = null
    var lab: Node3D = null
    for attempt in range(16):
        await process_frame
        floor = hub.get_node_or_null("PatchworkSteelFloor") as Node3D
        nexus = hub.get_node_or_null("NEXUSBuilding/NexusArchitecture") as Node3D
        lab = hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") as Node3D
        if floor != null and nexus != null and lab != null:
            break
    if floor == null or nexus == null or lab == null:
        _fail("full BASE startup did not finish")
        return
    var deck_texture: Texture2D = load("res://assets/base/industrial_deck_wear.svg")
    var armor_texture: Texture2D = load("res://assets/base/industrial_armor_chipped.svg")
    var oxide_texture: Texture2D = load("res://assets/base/industrial_oxidized_metal.svg")
    if deck_texture == null or armor_texture == null or oxide_texture == null:
        _fail("industrial textures were not imported")
        return
    var count: int = 0
    for child in floor.get_children():
        if child.name.begins_with("GridPlateBatch_"):
            if not child is MultiMeshInstance3D:
                _fail("deck mesh batch replaced")
                return
            var material: StandardMaterial3D = child.material_override as StandardMaterial3D
            if material == null or material.albedo_texture != deck_texture:
                _fail("floor must share the dedicated deck texture")
                return
            if material.roughness < 0.92 or material.metallic > 0.15:
                _fail("floor reflectivity should remain restrained")
                return
            count += 1
    if count != 6:
        _fail("six existing deck palette batches not preserved")
        return
    for group in [nexus, lab]:
        var armor: StandardMaterial3D = _material_for(group, "armor")
        var rust: StandardMaterial3D = _material_for(group, "rust")
        if armor == null or armor.albedo_texture != armor_texture:
            _fail("painted armor texture not used by an actual facility")
            return
        if rust == null or rust.albedo_texture != oxide_texture:
            _fail("rust texture not used by an actual facility")
            return
        if armor.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
            _fail("opaque armor changed to transparent rendering")
            return
    print("SERA_BASE_SURFACE_TEXTURE_RUNTIME_PASS")
    quit(0)
