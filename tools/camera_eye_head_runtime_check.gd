extends SceneTree
## Real Godot import/playback smoke: camera-eye HEAD D, texture and A/C preservation.
const Rig = preload("res://scripts/sera_rig.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("SERA_CAMERA_EYE_HEAD_RUNTIME_FAIL: " + message)
    quit(1)


func _run() -> void:
    var world := Node3D.new()
    world.name = "CameraEyeSmokeWorld"
    root.add_child(world)
    var player := Node3D.new()
    player.name = "CameraEyeSmokeActor"
    world.add_child(player)
    var rig: Node3D = Rig.new()
    rig.name = "SERA"
    player.add_child(rig)
    await process_frame
    if not bool(rig.get("loading_ok")):
        _fail("base SERA rig/animation loading failed")
        return
    var options: Array = rig.call("get_equipment_options", "head")
    for variant in ["A", "B", "C", "D"]:
        if not options.has(variant):
            _fail("missing selectable HEAD " + variant)
            return
    var head: Node3D = rig.get_node_or_null(
        "Waist/Torso/Chest/Neck/Head") as Node3D
    if head == null:
        _fail("standard animated head pivot missing")
        return
    var pivot: Node3D = head.get_node_or_null("CameraEyeHeadD") as Node3D
    if pivot == null:
        _fail("HEAD D is not parented to the animated HEAD bone")
        return
    var equipment: RefCounted = rig.get("equipment_handler") as RefCounted
    var available: Dictionary = equipment.get("available")
    var camera_parts: Array = (available["D"] as Dictionary).get("head", [])
    if camera_parts.size() != 6:
        _fail("camera-eye head must have the six authored mesh parts")
        return
    for part in camera_parts:
        var piece: MeshInstance3D = part as MeshInstance3D
        var material: StandardMaterial3D = piece.material_override as StandardMaterial3D
        if piece.mesh == null or piece.mesh.get_surface_count() == 0:
            _fail("missing camera-eye mesh triangles")
            return
        if material == null or material.albedo_texture == null or \
                material.albedo_texture.get_width() != 16 or \
                material.albedo_texture.get_height() != 16:
            _fail("camera-eye 16x16 author texture not applied")
            return
        if piece.visible:
            _fail("HEAD D visible while default HEAD A selected")
            return
    if not bool(equipment.call("select_part", "head", "D", false)):
        _fail("HEAD D could not be equipped")
        return
    for piece in camera_parts:
        if not piece.visible:
            _fail("missing visible camera-eye mesh when equipped")
            return
    for piece in (available["A"] as Dictionary).get("head", []):
        if piece.visible:
            _fail("HEAD A overlapped active camera-eye head")
            return
    if not bool(equipment.call("select_part", "head", "A", false)):
        _fail("cannot return to HEAD A")
        return
    for piece in camera_parts:
        if piece.visible:
            _fail("HEAD D leaked after returning to A")
            return
    print("PASS: camera-eye HEAD D six meshes, 16px atlas, select/restore and animated parent")
    world.queue_free()
    quit(0)
