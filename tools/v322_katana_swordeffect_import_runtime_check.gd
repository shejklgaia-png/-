extends SceneTree
## Verify actual Katana Swordeffect authored pose plus the existing v85 volume/arc FX.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_V322_KATANA_SWORDEFFECT_FAILED: " + message)
    quit(1)

func _assert_pose(rig: Node3D, clip: String, t: float,
        rotation: Vector3, position: Vector3, scale_value: Vector3) -> bool:
    rig.call("start_strike", clip)
    if str(rig.get("current_clip")) != clip:
        _fail("Could not start " + clip)
        return false
    rig.set("clip_time", t)
    rig.set("blending_for", rig.get("blend_duration"))
    rig.call("_apply_animation", 0.0)
    var joint: Node3D = rig.get("sword_effect_bone")
    if joint == null:
        _fail("Swordeffect joint is missing")
        return false
    var id: String = str(joint.get_meta("bb_uuid", ""))
    var authored_rotation: Quaternion = rig.call("_blockbench_rotation", rotation)
    if joint.quaternion.angle_to(authored_rotation) > 0.0001:
        _fail(clip + ": rotation key was not applied")
        return false
    var bone_map: Dictionary = rig.get("bones")
    var bind: Dictionary = rig.get("bind_positions")
    var uid: String = ""
    for key in bone_map.keys():
        if bone_map[key] == joint:
            uid = str(key)
            break
    if uid.is_empty() or not bind.has(uid):
        _fail("Swordeffect joint UUID not registered")
        return false
    var expected_position: Vector3 = bind[uid] + position * 0.065
    if joint.position.distance_to(expected_position) > 0.0001:
        _fail(clip + ": position key was not applied")
        return false
    if joint.scale.distance_to(scale_value) > 0.0001:
        _fail(clip + ": scale key was not applied")
        return false
    return true

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("Main training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var trail: Node3D = game.get("sword_trail")
    if rig == null or trail == null or not bool(rig.get("loading_ok")):
        _fail("Rig or V85 sword trail not initialized")
        return
    var plane: MeshInstance3D = rig.call("get_sword_effect_mesh")
    var effect_root: Node3D = trail.get("effect_root")
    if plane == null or effect_root == null:
        _fail("Authored Swordeffect board/3D effect not found")
        return
    if effect_root.get_parent() != plane.get_parent():
        _fail("3D arc is not attached to the animated Swordeffect pivot")
        return
    if effect_root.transform != plane.transform or plane.visible:
        _fail("Effect geometry does not follow the hidden authored board")
        return
    if not _assert_pose(rig, "Melee_katana", 0.33333,
            Vector3(-12.4539,1.0809,4.882),
            Vector3(5.6,-17.3,-15), Vector3(4.05,1,3.56)):
        return
    trail.call("begin_swing", 0.0)
    trail.call("sample_swing", Vector3.ZERO, Vector3.ONE, 0.33333, 0.016)
    trail.call("advance", 0.016, false)
    if not effect_root.visible:
        _fail("Katana first slash generated no 3D sword effect")
        return
    var flat: MeshInstance3D = trail.get("flat_mesh")
    var lens: MeshInstance3D = trail.get("lens_mesh")
    if flat == null or flat.mesh == null or lens == null or lens.mesh == null:
        _fail("V85 cutout arc and convex 3D volume were not created")
        return
    trail.call("stop_swing")
    if not _assert_pose(rig, "Melee_katana2", 0.0,
            Vector3(0,0,75), Vector3(1.7,-10.8,-10.2),
            Vector3(4.84,1,4.18)):
        return
    trail.call("begin_swing", 0.0)
    trail.call("sample_swing", Vector3.ZERO, Vector3.ONE, 0.25, 0.016)
    trail.call("advance", 0.016, false)
    if not effect_root.visible or not is_instance_valid(flat.mesh):
        _fail("Katana second slash generated no 3D sword effect")
        return
    trail.call("stop_swing")
    print("SERA_V322_KATANA_SWORDEFFECT_IMPORT_RUNTIME_PASS")
    quit(0)
