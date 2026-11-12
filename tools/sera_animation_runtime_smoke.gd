extends SceneTree
## Required for ALL future SERA animation additions, not just v273 side kicks.
## Uses the actual Godot runtime and the same rig loader as the game.
## A Python JSON/static test alone failed to detect the v264-v272 regression.
func _initialize() -> void:
    call_deferred("_run")


func _failure(reason: String) -> void:
    push_error("SERA ANIMATION RUNTIME REGRESSION: " + reason)
    quit(1)


func _run() -> void:
    var script: GDScript = load("res://scripts/sera_rig.gd")
    if script == null:
        _failure("SeraRig script failed to load")
        return
    var rig: Node3D = script.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _failure("rig not initialized")
        return

    var raw: String = FileAccess.get_file_as_string("res://assets/sera_source.json")
    var data: Variant = JSON.parse_string(raw)
    if not (data is Dictionary):
        _failure("canonical animation source cannot be parsed")
        return

    var loaded: Dictionary = rig.get("animations")
    var installed_bones: Dictionary = rig.get("bones")
    var tested: int = 0
    for candidate in data.get("animations", []):
        if not (candidate is Dictionary):
            continue
        var clip_name: String = str(candidate.get("name", ""))
        if clip_name.is_empty() or not loaded.has(clip_name):
            _failure("missing canonical animation " + clip_name)
            return
        var compiled: Dictionary = loaded[clip_name]
        var length: float = float(compiled.get("length", 0.0))
        if length <= 0.001:
            _failure(clip_name + ": invalid playback duration")
            return
        var tracks: Dictionary = compiled.get("tracks", {})
        var usable_tracks: int = 0
        for uid_variant in tracks.keys():
            var uid: String = str(uid_variant)
            if not installed_bones.has(uid):
                continue
            var channels: Dictionary = tracks[uid_variant]
            for channel in ["rotation", "position", "scale"]:
                if not (channels.get(channel, []) as Array).is_empty():
                    usable_tracks += 1
        if usable_tracks == 0:
            _failure(clip_name + ": not a single playable keyed joint")
            return

        # _switch_clip and _apply_animation exercise real Godot dictionaries,
        # quaternion interpolation and node/Pivot updates, unlike JSON checks.
        rig.call("_switch_clip", clip_name, 0.05)
        rig.set("clip_time", length * 0.4)
        rig.call("_apply_animation", 0.0)
        if str(rig.get("current_clip")) != clip_name:
            _failure(clip_name + ": runtime did not switch to the clip")
            return
        tested += 1
        print("GODOT_ALL_ANIMATIONS_PASS ", clip_name, " keyed_channels=", usable_tracks)

    if tested < 20:
        _failure("unexpectedly few canonical animations: %d" % tested)
        return
    # Explicitly test both side-kick public API calls. The v272 diagnostic
    # said ALREADY READY but the search used by has_side_kick failed.
    for side in [1, -1]:
        var expected: String = "Kick_r" if side == 1 else "Kick_l"
        if not bool(rig.call("has_side_kick", side)):
            _failure(expected + ": available source but has_side_kick=false")
            return
        if str(rig.call("_side_kick_clip_for", side)) != expected:
            _failure(expected + ": runtime name lookup differs from data")
            return
        if not bool(rig.call("start_side_kick", side, 0.4)):
            _failure(expected + ": playback API rejected real clip")
            return
        if str(rig.get("current_clip")) != expected:
            _failure(expected + ": playback API chose incorrect clip")
            return
        rig.call("finish_side_step", false, false)

    print("GODOT_ALL_ANIMATIONS_TEST PASSED ", tested, " source clips and both kicks")
    quit(0)
