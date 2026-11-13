extends SceneTree
## Real Godot verification of the v321 SERA rig, equipment and camera math.
const CAMERA_MATH = preload("res://scripts/sera_camera_math.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_V321_RUNTIME_FAIL: " + message)
    quit(1)

func _shown(parts: Array, visible: bool) -> bool:
    if parts.is_empty():
        return false
    for raw_piece in parts:
        var piece: MeshInstance3D = raw_piece
        if not is_instance_valid(piece) or piece.visible != visible:
            return false
        if absf(piece.transparency - (0.0 if visible else 1.0)) > 0.001:
            return false
    return true

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    if rig == null or not bool(rig.get("loading_ok")):
        _fail("SERA rig not loaded")
        return
    var equip: RefCounted = rig.get("equipment_handler")

    # The original idle key places the waist at -3 BB units (-0.195m).
    # All forward/back RUN frames must remain at or below that idle height.
    var info: Dictionary = rig.get_script().get_script_constant_map()
    var waist_id: String = str(info["RUN_ROOT_BONE_UUID"])
    var bones: Dictionary = rig.get("bones")
    var waist: Node3D = bones[waist_id]
    rig.call("set_moving", false)
    rig.call("_process", 0.01)
    var idle_y: float = waist.position.y
    rig.call("set_moving", true, false, Vector2.UP, false)
    rig.call("_process", 0.22)
    if str(rig.get("current_clip")) != "run_front_original":
        _fail("normal RUN did not play")
        return
    if waist.position.y >= idle_y - 0.005:
        _fail("RUN pelvis still rises above the idle stance")
        return
    for retreat in [0.0, 0.5, 1.0]:
        rig.set("run_retreat_blend", retreat)
        for t in [0.0, 0.25, 0.5, 0.75]:
            var pose: Dictionary = rig.call("_blended_run_pose", waist_id, t, false)
            if (pose["position"] as Vector3).y > -0.195 + 0.00001:
                _fail("RUN sampled a high pelvis key")
                return

    # A 5m STEP must not teleport the camera focus to the 0.65m leash.
    var old_focus := Vector2.ZERO
    var new_focus: Vector2 = CAMERA_MATH.advance_follow_focus(
        old_focus, Vector2(5.0, 0.0), 1.0/60.0, 15.0, 0.65)
    if new_focus.x <= 0.0 or new_focus.x > 0.30:
        _fail("camera focus teleports on large displacement")
        return
    var stable: float = CAMERA_MATH.stable_near_bearing(0.0, PI,
        0.20, 1.0/60.0)
    if absf(stable) > 0.00001:
        _fail("overlap camera bearing flipped at boss center")
        return

    # The three solid scabbard meshes ALWAYS remain on the left forearm.
    if not bool(rig.call("set_equipment_selection", "weapon_r", "K")):
        _fail("Katana cannot be equipped")
        return
    var all_saya: Array = equip.get("katana_saya_meshes")
    var stowed: Array = equip.get("katana_sheathed_blade_meshes")
    var drawn: Array = equip.get("katana_drawn_meshes")
    var scabbard: Array = []
    for raw_piece in all_saya:
        if not stowed.has(raw_piece):
            scabbard.append(raw_piece)
    if scabbard.size() != 3 or stowed.size() != 2 or drawn.size() != 2:
        _fail("Katana geometry roles incorrectly classified")
        return
    if not _shown(scabbard, true) or not _shown(stowed, true) or not _shown(drawn, false):
        _fail("scabbard/paired blades incorrect at rest")
        return
    rig.call("start_strike", "Melee_katana")
    rig.set("clip_time", 3.0 / 24.0)
    rig.call("_apply_animation", 0.0)
    if not _shown(scabbard, true) or not _shown(stowed, false) or not _shown(drawn, true):
        _fail("scabbard disappeared during first Katana attack")
        return
    rig.call("start_strike", "Melee_katana2")
    rig.set("clip_time", 0.1)
    rig.call("_apply_animation", 0.0)
    if not _shown(scabbard, true) or not _shown(stowed, false) or not _shown(drawn, true):
        _fail("scabbard disappeared or sword re-sheathed in second attack")
        return
    rig.call("finish_attack", false)
    rig.call("_apply_animation", 0.0)
    if not _shown(scabbard, true) or not _shown(stowed, true) or not _shown(drawn, false):
        _fail("blade did not re-sheathe after attack")
        return

    # All configured part variants must retain authored base materials across
    # the attack FX toggle. KO and EN overlay remain separate intentional cases.
    for slot in ["head", "torso", "arms", "legs"]:
        var options: Array = rig.call("get_equipment_options", slot)
        for variant in options:
            rig.call("set_equipment_selection", slot, str(variant))
            rig.call("set_slash_player_foreground", true)
            for raw_part in rig.get("_foreground_parts"):
                var piece: MeshInstance3D = raw_part
                if not is_instance_valid(piece):
                    _fail("missing original part mesh")
                    return
                if piece.material_override == null or piece.material_overlay != null:
                    _fail("slash overlay hid original texture on " + piece.name)
                    return
            rig.call("set_slash_player_foreground", false)
    print("SERA_V321_RUN_CAMERA_KATANA_MATERIAL_RUNTIME_PASS")
    quit(0)
