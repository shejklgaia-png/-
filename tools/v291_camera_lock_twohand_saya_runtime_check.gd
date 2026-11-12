extends SceneTree
## Godot scene checks: camera-forward AUTO always finds intact target parts;
## MANUAL wraps after the screen edge; Katana reserves left hand, restores
## original mesh display and respects the sheath's authored +90deg rotation.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V291_CAMERA_LOCK_TWOHAND_SAYA_FAILED: " + reason)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main scene is missing")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var camera: Camera3D = game.get("camera")
    var target: Node3D = game.get("target")
    var parts: Node3D = game.get("target_parts")
    var rig: Node3D = game.get("rig")
    if camera == null or target == null or parts == null or rig == null:
        _fail("camera, target parts or equipment rig unavailable")
        return
    if not bool(rig.get("loading_ok")):
        _fail("authored SERA failed to load")
        return

    game.set("target_hp",500)
    target.position = Vector3(0,1.53,0)
    camera.global_position = target.global_position + Vector3(5,3,9)
    camera.look_at(target.global_position,Vector3.UP)
    var best: String = str(parts.call("select_camera_front_part",camera,""))
    if best.is_empty() or not bool(parts.call("is_targetable",best)):
        _fail("camera-forward selector could not lock any intact boss limb")
        return
    if str(parts.call("select_camera_front_part",camera,best)) != best:
        _fail("AUTO candidate flickered without camera movement")
        return
    game.set("auto_lock_enabled",true)
    game.set("manual_part_lock_active",false)
    game.set("locked_target_part_id","")
    game.call("_physics_process",0.016)
    # Since v293 AUTO may intentionally lock the boss BODY (empty part ID),
    # an empty limb ID is not evidence of a missing lock.
    if not bool(game.get("auto_lock_initialized")):
        _fail("AUTO did not initialize either a body or a limb lock")
        return

    # Screen-side manual selector must wrap instead of stalling at edge.
    game.set("auto_lock_enabled",false)
    game.set("manual_part_lock_active",true)
    var leftmost: String = ""
    var rightmost: String = ""
    var left_x: float = INF
    var right_x: float = -INF
    for raw_id in ["head","leg_fl","leg_fr","leg_rl","leg_rr"]:
        var part_id: String = str(raw_id)
        var aim: Vector3 = parts.call("get_part_aim_world",part_id)
        if camera.is_position_behind(aim):
            continue
        var x: float = camera.unproject_position(aim).x
        if x < left_x:
            left_x = x
            leftmost = part_id
        if x > right_x:
            right_x = x
            rightmost = part_id
    if leftmost.is_empty() or rightmost.is_empty() or leftmost == rightmost:
        _fail("manual lock does not have multiple front camera candidates")
        return
    game.set("locked_target_part_id",rightmost)
    game.call("_switch_lock_screen_direction",1)
    if str(game.get("locked_target_part_id")) != leftmost:
        _fail("screen-right manual lock did not wrap to leftmost part")
        return

    var overlay: Node = game.get("touch_ui")
    overlay.call("set_target_marker_projection",Vector2(42,42),true,true)
    if not bool(overlay.get("target_marker_offscreen")):
        _fail("edge-pinned offscreen lock indicator missing")
        return

    var equip: RefCounted = rig.get("equipment_handler")
    var available: Dictionary = equip.get("available")
    var normal_left: Array = (available["A"] as Dictionary).get("weapon_l",[])
    if normal_left.is_empty():
        _fail("normal LEFT WEAPON visual is unavailable for overlap test")
        return
    if not bool(rig.call("set_equipment_selection","weapon_r","K")):
        _fail("Katana cannot equip")
        return
    var occupant: Dictionary = rig.call("get_equipment_two_handed_blocker","weapon_l")
    if str(occupant.get("name","")) != "KATANA" \
            or str(occupant.get("owner","")) != "weapon_r":
        _fail("Katana did not reserve the LEFT WEAPON slot")
        return
    if bool(rig.call("set_equipment_selection","weapon_l","A")):
        _fail("reserved left hand still accepts equipment selection")
        return
    for raw_piece in normal_left:
        var piece: MeshInstance3D = raw_piece
        if piece.visible:
            _fail("left weapon shield overlaps Katana's left forearm saya")
            return
    var saya_joint: Node3D = rig.find_child("Katana_l3",true,false)
    if saya_joint == null:
        _fail("left forearm Katana_l3 pivot missing")
        return
    var found_rotated_saya: bool = false
    var authored_yaw: Quaternion = Quaternion(Vector3.UP,PI*0.5)
    for child in saya_joint.get_children():
        if child is MeshInstance3D:
            var mesh_piece: MeshInstance3D = child
            if mesh_piece.quaternion.angle_to(authored_yaw) < 0.01:
                found_rotated_saya = true
    if not found_rotated_saya:
        _fail("authored +90deg mesh rotation ignored on left sheath")
        return
    if not bool(rig.call("set_equipment_selection","weapon_r","A")):
        _fail("could not unequip Katana")
        return
    if not (rig.call("get_equipment_two_handed_blocker","weapon_l") as Dictionary).is_empty():
        _fail("left hand stayed greyed out after unequipping Katana")
        return
    for raw_piece in normal_left:
        if not (raw_piece as MeshInstance3D).visible:
            _fail("original offhand visual was not restored")
            return
    # A future left-handed two-handed weapon uses the same reservation rule.
    var selections: Dictionary = equip.get("selected")
    selections["weapon_l"] = "K"
    occupant = rig.call("get_equipment_two_handed_blocker","weapon_r")
    if str(occupant.get("owner","")) != "weapon_l" \
            or str(occupant.get("name","")) != "KATANA":
        _fail("left-hand two-hander did not symmetrically reserve RIGHT")
        return
    selections["weapon_l"] = "A"
    equip.call("_apply_part_visibility")
    print("GODOT_V291_CAMERA_LOCK_TWOHAND_SAYA_PASS")
    quit(0)
