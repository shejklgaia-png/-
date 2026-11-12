extends SceneTree
## SERA v276 actual Godot equipment and authored clip playback.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V276_KATANA_RUNTIME_FAILED: " + reason)
    quit(1)

func _check(parts: Array, expected: bool) -> bool:
    if parts.is_empty():
        return false
    for node in parts:
        if not (node is MeshInstance3D) or node.visible != expected:
            return false
    return true

func _run() -> void:
    var script: GDScript = load("res://scripts/sera_rig.gd")
    if script == null:
        _fail("missing SeraRig")
        return
    var rig: Node3D = script.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _fail("rig not initialized")
        return
    var equip: RefCounted = rig.get("equipment_handler")
    var saya: Array = equip.get("katana_saya_meshes")
    var drawn: Array = equip.get("katana_drawn_meshes")
    if saya.size() != 5 or drawn.size() != 2:
        _fail("incorrect mesh classification")
        return
    if not (rig.call("get_equipment_options", "weapon_r") as Array).has("K"):
        _fail("K not selectable")
        return
    if not bool(rig.call("set_equipment_selection", "weapon_r", "K")):
        _fail("failed to equip K")
        return
    if not _check(saya, true) or not _check(drawn, false):
        _fail("resting visibility incorrect")
        return
    rig.call("start_strike", "Melee_katana")
    if str(rig.get("current_clip")) != "Melee_katana":
        _fail("Katana clip cannot start")
        return
    rig.set("clip_time", 0.124)
    rig.call("_apply_animation", 0.0)
    if not _check(saya, true) or not _check(drawn, false):
        _fail("switched before frame 4")
        return
    rig.set("clip_time", 3.0 / 24.0)
    rig.call("_apply_animation", 0.0)
    if not _check(saya, false) or not _check(drawn, true):
        _fail("frame-4 swap missing")
        return
    var blade: PackedVector3Array = rig.call("get_blade_world_segment")
    if blade.size() != 2 or blade[0].distance_to(blade[1]) < 0.5:
        _fail("Katana collision blade invalid")
        return
    rig.call("finish_attack", false)
    rig.call("_apply_animation", 0.0)
    if not _check(saya, true) or not _check(drawn, false):
        _fail("re-sheathing failed")
        return
    rig.call("set_equipment_selection", "weapon_r", "A")
    if not _check(saya, false) or not _check(drawn, false):
        _fail("old Sword selection leaked Katana")
        return
    print("GODOT_KATANA_V276_PASS")
    quit(0)
