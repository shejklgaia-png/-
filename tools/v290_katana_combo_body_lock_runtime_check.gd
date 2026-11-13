extends SceneTree
## True Godot regression: seven meshes swap both visibility and transparency,
## 2nd Katana attack plays a distinct clip and accepts finisher flicks.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V290_KATANA_COMBO_BODY_LOCK_FAILED: " + reason)
    quit(1)


func _meshes_match(meshes: Array, showing: bool) -> bool:
    if meshes.is_empty():
        return false
    for piece in meshes:
        if not (piece is MeshInstance3D):
            return false
        if piece.visible != showing:
            return false
        if absf(piece.transparency - (0.0 if showing else 1.0)) > 0.001:
            return false
    return true


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    if rig == null or player == null or target == null:
        _fail("player/rig/target not ready")
        return
    if not bool(rig.get("loading_ok")):
        _fail("authored model failed to load")
        return
    var equip: RefCounted = rig.get("equipment_handler")
    var saya: Array = equip.get("katana_saya_meshes")
    var blade: Array = equip.get("katana_drawn_meshes")
    if saya.size() != 5 or blade.size() != 2:
        _fail("incorrect 5:2 Katana mesh classification")
        return
    if not bool(rig.call("set_equipment_selection","weapon_r","K")):
        _fail("Katana K not equipable")
        return
    if not _meshes_match(saya,true) or not _meshes_match(blade,false):
        _fail("resting sheath and sword visual state incorrect")
        return
    game.call("_start_attack")
    if int(game.call("_strike_stage_count")) != 2:
        _fail("Katana combo is not two hits")
        return
    rig.call("start_strike","Melee_katana")
    rig.set("clip_time", 0.124)
    rig.call("_apply_animation",0.0)
    if not _meshes_match(saya,true) or not _meshes_match(blade,false):
        _fail("Katana sheath prematurely disappeared before fourth frame")
        return
    rig.set("clip_time", 3.0/24.0)
    rig.call("_apply_animation",0.0)
    if not _meshes_match(saya,false) or not _meshes_match(blade,true):
        _fail("first strike did not swap sheath/drawn at frame four")
        return

    var animations: Dictionary = rig.get("animations")
    if not animations.has("Melee_katana2"):
        _fail("distinct second Katana animation missing")
        return
    game.set("strike_index",1)
    if not bool(game.call("_is_strike_finisher")):
        _fail("stage two does not open Katana flick finisher")
        return
    rig.call("start_strike","Melee_katana2")
    if str(rig.get("current_clip")) != "Melee_katana2":
        _fail("stage 2 was ignored as repeat of first clip")
        return
    rig.set("clip_time",0.0)
    rig.call("_apply_animation",0.0)
    if not _meshes_match(saya,false) or not _meshes_match(blade,true):
        _fail("stage 2 re-sheathed the blade at t=0")
        return
    var prepared: float = float(game.call("_melee3_flick_cancel_time"))
    if prepared >= 0.5 or prepared <= 7.0/24.0:
        _fail("stage two flick cancel is outside its swing-through window")
        return
    game.set("combat_state",3) # STRIKE
    game.call("_request_combo_side_kick",Vector2.RIGHT)
    if int(game.get("buffered_side_kick_side")) != 1:
        _fail("stage 2 right flick was not queued")
        return
    game.call("_request_combo_side_kick",Vector2.DOWN)
    if int(game.get("buffered_side_kick_side")) != 2:
        _fail("stage 2 down-flick did not buffer Kick_b")
        return
    game.set("combat_state",0)
    var visual_yaw: float = float(rig.call("_run_yaw_for_direction",
        Vector2.RIGHT,0.0))
    # v295: lateral RUN SHOULD rotate the visible Waist ±90° toward travel.
    # The physical CharacterBody3D remains boss-facing (verified below).
    if absf(wrapf(visual_yaw + PI * 0.5, -PI, PI)) > 0.0001:
        _fail("lateral RUN does not face rightward travel")
        return

    # SERA yaw now follows the selected limb's attack/HUD aim; the visual
    # RUN waist still turns toward the travel direction independently.
    game.set("locked_target_part_id","leg_fr")
    game.set("manual_part_lock_active",true)
    player.position=Vector3(5,0,0)
    target.position=Vector3(0,1.53,-8)
    game.set("gesture_active",false)
    game.set("direction_input",Vector2.ZERO)
    game.call("_physics_process",0.016)
    var flat_face: Vector3 = -player.global_transform.basis.z
    var want: Vector3 = parts.call("get_part_aim_world","leg_fr")-player.global_position
    want.y=0
    flat_face.y=0
    if flat_face.normalized().dot(want.normalized()) < 0.999:
        _fail("actor did not face the selected leg_fr lock point")
        return
    rig.call("finish_attack",false)
    rig.call("_apply_animation",0.0)
    if not _meshes_match(saya,true) or not _meshes_match(blade,false):
        _fail("return to idle did not restore sheath transparencies")
        return
    rig.call("set_equipment_selection","weapon_r","A")
    if not _meshes_match(saya,false) or not _meshes_match(blade,false):
        _fail("unused Katana geometry still rendered on Sword equipment")
        return
    print("GODOT_V290_KATANA_COMBO_BODY_LOCK_PASS")
    quit(0)
