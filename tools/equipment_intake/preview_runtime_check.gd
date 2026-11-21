extends SceneTree
## Real SERA runtime check, not a fake mesh/HTML parser.
const Preview = preload("res://tools/equipment_intake/godot_preview.gd")
const PortraitBackground = preload("res://scripts/sera_icon_background.gd")

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
    # Actual equipped B arms + D lower body at edited size: BODY must run
    # exactly the same NEXUS solver, using the post-scale real meshes.
    preview.call("_apply_command", {"mode":"body","editing_slot":"arms",
        "selected":{"head":"D","torso":"A","arms":"B","legs":"D",
            "booster":"A","weapon_r":"A","weapon_l":"A"},
        "size":1.5,"keep_aspect":true,"seq":121})
    await process_frame
    var captured_fitted: Dictionary = {}
    var fitted_bones: Dictionary = {}
    for raw_bone in (rig.get("bones") as Dictionary).values():
        var bone: Node3D = raw_bone
        if ["Shoulder_L","Shoulder_R","UpperArm_L","UpperArm_R"].has(str(bone.name)):
            fitted_bones[str(bone.name)] = bone
            captured_fitted[str(bone.name)] = bone.quaternion
    if captured_fitted.size() != 4:
        _fail("Full-body solver missing four shoulder/upper-arm bones")
        return
    preview.call("_apply_preview_standing_pose")
    for name in captured_fitted:
        var authored: Quaternion = (fitted_bones[name] as Node3D).quaternion
        var fitted: Quaternion = captured_fitted[name]
        var max_delta: float = 3.2 if name.begins_with("Shoulder") else 24.0
        if rad_to_deg(authored.angle_to(fitted)) > max_delta + 0.01:
            _fail("Full-body clearance exceeded NEXUS joint limit: "+name)
            return
    preview.call("_fit_full_body_clearance")
    for name in captured_fitted:
        if not (fitted_bones[name] as Node3D).quaternion.is_equal_approx(captured_fitted[name]):
            _fail("Full-body clearance cannot reproduce the same fitted pose: "+name)
            return
    # Reselecting the same models must start at the authored pose again.
    preview.call("_apply_command", {"mode":"body","editing_slot":"arms",
        "selected":{"head":"D","torso":"A","arms":"B","legs":"D",
            "booster":"A","weapon_r":"A","weapon_l":"A"},
        "size":1.5,"keep_aspect":true,"seq":122})
    await process_frame
    for name in captured_fitted:
        if not (fitted_bones[name] as Node3D).quaternion.is_equal_approx(captured_fitted[name]):
            _fail("Full-body clearance accumulated across equipment refresh: "+name)
            return
    # Restore baseline selections; isolated ICON must never inherit the fit.
    preview.call("_apply_command", {"mode":"body","editing_slot":"head",
        "selected":{"head":"D","torso":"A","arms":"A","legs":"C",
            "booster":"B","weapon_r":"K","weapon_l":"A"},
        "size":1.0,"keep_aspect":false,"seq":123})
    await process_frame
    # Isolated ICON and PARAMETERS preview must hide every other body slot.
    preview.call("_apply_command", {"mode":"icon", "editing_slot":"head",
        "selected":{"head":"D","torso":"A","arms":"A","legs":"A",
            "booster":"A","weapon_r":"A","weapon_l":"A"},
        "size":1.0,"keep_aspect":true,"seq":13})
    await process_frame
    if str(rig.get("current_clip"))!="NEXUS_pose":
        _fail("ICON must retain the authored NEXUS_pose")
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
    # Canonical background must have a solid #111e28 base and blue-grey
    # grid lines; SOLID mode must contain no lines.
    var grid: Image = PortraitBackground.make_image(128, "grid")
    var solid: Image = PortraitBackground.make_image(128, "solid")
    if not solid.get_pixel(2, 2).is_equal_approx(Color("#111e28")) or (
            grid.get_pixel(16, 6).is_equal_approx(solid.get_pixel(16, 6))):
        _fail("Shared icon background lost grid/solid distinction")
        return
    preview.call("_apply_command", {"mode":"icon","editing_slot":"head",
        "selected":{"head":"D","torso":"A","arms":"A","legs":"A",
            "booster":"A","weapon_r":"A","weapon_l":"A"},
        "size":1.0,"background_mode":"grid","seq":15})
    await process_frame
    var backdrop: MeshInstance3D = preview.get("background_quad") as MeshInstance3D
    if backdrop==null or not backdrop.visible:
        _fail("ICON lacks canonical visible grid mesh")
        return
    # A new second finger must NOT alter zoom/pan. Subsequent movement uses
    # only the midpoint and distance between stable touch contacts.
    var old_zoom: float = float(preview.get("camera_zoom"))
    var old_pan: Vector2 = preview.get("camera_pan")
    preview.call("_on_preview_touch",0,true,Vector2(90,140))
    preview.call("_on_preview_touch",1,true,Vector2(190,140))
    if not is_equal_approx(float(preview.get("camera_zoom")),old_zoom) or (
            (preview.get("camera_pan") as Vector2).distance_to(old_pan)>0.00001):
        _fail("Second finger caused a camera jump without movement")
        return
    preview.call("_on_preview_drag",0,Vector2(80,140))
    preview.call("_on_preview_drag",1,Vector2(200,140))
    var moved_zoom: float = float(preview.get("camera_zoom"))
    if moved_zoom<=old_zoom or moved_zoom>old_zoom*1.26:
        _fail("Pinch distance update unstable")
        return
    preview.call("_on_preview_touch",1,false,Vector2(200,140))
    var yaw_before: float = float(preview.get("camera_yaw"))
    preview.call("_on_preview_drag",0,Vector2(90,142))
    if absf(float(preview.get("camera_yaw"))-yaw_before)>8.0:
        _fail("One remaining finger caused rotation jump")
        return
    preview.call("_on_preview_touch",0,false,Vector2(90,142))
    # Shared game/form behavior: drag downward INCREASES pitch; upward
    # DECREASES it. Horizontal yaw must stay fixed on vertical-only movement.
    var drag_start_pitch: float = float(preview.get("camera_pitch"))
    var drag_start_yaw: float = float(preview.get("camera_yaw"))
    preview.call("_on_preview_touch",2,true,Vector2(120,140))
    preview.call("_on_preview_drag",2,Vector2(120,160))
    if float(preview.get("camera_pitch")) <= drag_start_pitch or (
            absf(float(preview.get("camera_yaw"))-drag_start_yaw)>0.001):
        _fail("Touch vertical drag is not inverted, or changed horizontal yaw")
        return
    preview.call("_on_preview_drag",2,Vector2(120,120))
    if float(preview.get("camera_pitch")) >= drag_start_pitch:
        _fail("Upward touch drag did not decrease pitch")
        return
    preview.call("_on_preview_touch",2,false,Vector2(120,120))
    var mouse_press := InputEventMouseButton.new()
    mouse_press.button_index = MOUSE_BUTTON_LEFT
    mouse_press.pressed = true
    preview.call("_input", mouse_press)
    var mouse_start_pitch: float = float(preview.get("camera_pitch"))
    var mouse_motion := InputEventMouseMotion.new()
    mouse_motion.relative = Vector2(0, 15)
    preview.call("_input", mouse_motion)
    if float(preview.get("camera_pitch")) <= mouse_start_pitch:
        _fail("Mouse vertical drag direction differs from touch")
        return
    mouse_press.pressed = false
    preview.call("_input", mouse_press)
    preview.call("_apply_command", {"mode":"icon","editing_slot":"head",
        "selected":{"head":"D"},"size":1.0,"background_mode":"solid","seq":16})
    await process_frame
    if backdrop.visible:
        _fail("Solid mode should remove the grid while keeping the navy background")
        return
    print("SERA_ICON_BACKGROUND_AND_TOUCH_RUNTIME_OK")
    print("SERA_GODOT_INTAKE_RUNTIME_OK real_rig=true material=game outline=game nexus_pose=true shared_arm_clearance=true icon_restored=true")
    quit(0)
