extends SceneTree
## Real SERA runtime check, not a fake mesh/HTML parser.
const Preview = preload("res://tools/equipment_intake/godot_preview.gd")

func _initialize() -> void:
    call_deferred("_check")

func _fail(msg: String) -> void:
    push_error("SERA_GODOT_INTAKE_FAIL: " + msg)
    quit(1)

func _check() -> void:
    var preview: Node3D = Preview.new()
    root.add_child(preview)
    for i in range(8):
        await process_frame
    if not bool(preview.get("ready_for_commands")):
        _fail("Real rig failed startup")
        return
    var rig: Node3D = preview.get("rig")
    if rig==null or not bool(rig.get("loading_ok")):
        _fail("Canonical SeraRig not active")
        return
    if rig.get_script().resource_path!="res://scripts/sera_rig.gd":
        _fail("Preview uses a substituted rig")
        return
    var ink: Node = rig.get_node_or_null("ViewEdges")
    if ink==null or ink.get_script().resource_path!="res://scripts/sera_view_edges.gd":
        _fail("Game ViewEdges are not shared")
        return
    var handler: RefCounted = preview.get("handler")
    if handler==null or handler.get_script().resource_path!="res://scripts/sera_equipment.gd":
        _fail("Not the real SeraEquipment handler")
        return
    # The NEXUS pose is a real authoring clip, not the crouched Wait_motion.
    var named_pose: String = "NEXUS_pose"
    var animations: Dictionary = rig.get("animations")
    if not animations.has(named_pose):
        _fail("Canonical SeraRig lacks NEXUS_pose")
        return
    if str(rig.get("current_clip"))!=named_pose or (
            str(preview.get("active_full_body_pose"))!=named_pose):
        _fail("Startup body pose is not the NEXUS stance")
        return
    var head_options: Array = handler.call("options_for","head")
    if not head_options.has("D") or not head_options.has("C"):
        _fail("Current HEAD D/C equipment missing")
        return
    preview.call("_apply_command", {"mode":"body",
        "editing_slot":"head",
        "selected":{"head":"D","torso":"A","arms":"A","legs":"C",
            "booster":"B","weapon_r":"K","weapon_l":"A"},
        "size":1.0, "keep_aspect":false,
        "camera":{"yaw":154.0,"pitch":-16.0,"outlinePx":3.0},
        "seq":12})
    await process_frame
    if str(rig.get("current_clip"))!=named_pose:
        _fail("Full-body equip changed the NEXUS_pose to the combat idle")
        return
    # Compare real authored animation data (not only the clip label).
    var pose_tracks: Dictionary = (animations[named_pose] as Dictionary)["tracks"]
    var matched_bone: bool = false
    for uid in pose_tracks.keys():
        var keyed: Dictionary = pose_tracks[uid]
        var rotations: Array = keyed.get("rotation", [])
        if rotations.is_empty() or not (rig.get("bones") as Dictionary).has(uid):
            continue
        var bone: Node3D = (rig.get("bones") as Dictionary)[uid]
        if str(bone.name)!="Waist":
            continue
        var expected_quaternion: Quaternion = rotations[0]["quaternion"]
        if not bone.quaternion.is_equal_approx(expected_quaternion):
            _fail("Waist is not using authored NEXUS_pose rotation")
            return
        matched_bone = true
    if not matched_bone:
        _fail("NEXUS_pose has no mapped Waist rotation")
        return
    if str(handler.call("current_for","head"))!="D" or (
            str(handler.call("current_for","legs"))!="C" or
            str(handler.call("current_for","weapon_r"))!="K"):
        _fail("Game equipment selection did not execute")
        return
    var shield: Array = (handler.get("available") as Dictionary).get("A",{}).get("weapon_l",[])
    if shield.is_empty():
        _fail("Regular shield source missing")
        return
    for part in shield:
        if part is MeshInstance3D and part.visible:
            _fail("Two-hand Katana failed to suppress the shield")
            return
    if preview.get("camera")==null:
        _fail("No Godot Camera3D")
        return
    var effects: Dictionary = handler.get("available")
    var source_head: Array = (effects.get("D",{}) as Dictionary).get("head",[])
    if source_head.size()!=6:
        _fail("Canonical camera eye lost its six meshes")
        return
    for piece in source_head:
        if piece is MeshInstance3D and piece.material_override==null:
            _fail("Godot game material missing")
            return
    # Isolated ICON and PARAMETERS preview must hide every other body slot.
    preview.call("_apply_command", {"mode":"icon", "editing_slot":"head",
        "selected":{"head":"D","torso":"A","arms":"A","legs":"A",
            "booster":"A","weapon_r":"A","weapon_l":"A"},
        "size":1.0,"keep_aspect":true,"seq":13})
    await process_frame
    if str(rig.get("current_clip"))!=str(preview.get("icon_idle_clip")):
        _fail("ICON must restore its previous single-part idle stance")
        return
    var available: Dictionary = handler.get("available")
    var visible_head: int = 0
    var visible_other: int = 0
    for set_name in available:
        for slot_name in available[set_name]:
            for mesh in available[set_name][slot_name]:
                if mesh is MeshInstance3D and mesh.visible:
                    if str(slot_name)=="head":
                        visible_head+=1
                    else:
                        visible_other+=1
    if visible_head!=6 or visible_other!=0:
        _fail("ICON view must show only HEAD D meshes: %d / %d" % [
            visible_head,visible_other])
        return
    # Re-entering body mode must restore the A-set companions.
    preview.call("_apply_command",{"mode":"body","editing_slot":"head",
        "selected":{"head":"D","torso":"A","arms":"A","legs":"A",
            "booster":"A","weapon_r":"A","weapon_l":"A"},
        "size":1.0,"keep_aspect":true,"seq":14})
    await process_frame
    if str(rig.get("current_clip"))!=named_pose:
        _fail("NEXUS_pose not restored on return from ICON to BODY")
        return
    var other_restored: bool=false
    for set_name in available:
        for slot_name in available[set_name]:
            if str(slot_name)=="head":
                continue
            for mesh in available[set_name][slot_name]:
                if mesh is MeshInstance3D and mesh.visible:
                    other_restored=true
    if not other_restored:
        _fail("Body mode did not restore companion meshes")
        return
    print("SERA_GODOT_INTAKE_RUNTIME_OK real_rig=true material=game outline=game nexus_pose=true icon_restored=true")
    quit(0)
