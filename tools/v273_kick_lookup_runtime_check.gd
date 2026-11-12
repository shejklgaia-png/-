extends SceneTree
## v273: REAL Godot engine regression, not Python source-text inspection.
## Executes the same SeraRig startup, has_side_kick() and start_side_kick()
## called by the Android combat controller. No scene UI/touch emulation.
func _initialize() -> void:
    call_deferred("_run_side_kick_test")


func _fail(message: String) -> void:
    push_error("SERA KICK RUNTIME FAILED: " + message)
    quit(1)


func _run_side_kick_test() -> void:
    var rig_script: GDScript = load("res://scripts/sera_rig.gd")
    if rig_script == null:
        _fail("rig script failed to load")
        return
    var rig: Node3D = rig_script.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _fail("base rig not loaded")
        return
    for side in [1, -1]:
        var expected: String = "Kick_r" if side == 1 else "Kick_l"
        if not bool(rig.call("has_side_kick", side)):
            _fail(expected + ": has_side_kick=false, " + str(
                rig.call("get_side_kick_diagnostic", side)))
            return
        var selected: String = str(rig.call("_side_kick_clip_for", side))
        if selected != expected:
            _fail(expected + ": returned different clip name: " + selected)
            return
        if not bool(rig.call("start_side_kick", side, 0.40)):
            _fail(expected + ": start_side_kick returned false")
            return
        if str(rig.get("current_clip")) != expected:
            _fail(expected + ": current_clip is " + str(rig.get("current_clip")))
            return
        if str(rig.get("side_kick_clip_name")) != expected:
            _fail(expected + ": animation name is " + str(rig.get("side_kick_clip_name")))
            return
        rig.call("finish_side_step", false, false)
        print("GODOT_RUNTIME_KICK_PASS ", expected)
    print("GODOT_RUNTIME_KICK_TEST PASSED: both authored clips are playable")
    quit(0)
