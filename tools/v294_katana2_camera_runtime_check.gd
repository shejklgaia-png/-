extends SceneTree
## v294: actual Godot clip-import and combat camera radius smoke check.

func _fail(reason: String) -> void:
    push_error("V294_KATANA2_CAMERA: " + reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene not found")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    await process_frame
    var rig: Node = game.get("rig")
    var camera: Camera3D = game.get("camera")
    if rig == null or camera == null:
        _fail("scene missing rig or camera")
        return
    var clips: Dictionary = rig.get("animations")
    if not clips.has("Melee_katana2") or not clips.has("Melee_katana"):
        _fail("Katana clips unavailable")
        return
    var authored: Dictionary = clips["Melee_katana2"]
    if absf(float(authored.get("length", 0.0)) - 0.58333) > 0.0001:
        _fail("not using the newly authored 0.58333s second clip")
        return
    # All 19 authored A-rig tracks (70 keys) must survive import unchanged.
    # The rig then fills one Wait_motion key for each of six BIRD joints:
    # those additional stabilizers are intentional, not corrupted Katana keys.
    var source_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(
        "res://models/storage/SERA_BOOSTER_allテスト.bbmodel"))
    if not (source_value is Dictionary):
        _fail("Katana2 Blockbench source cannot be parsed")
        return
    var author_animators: Dictionary = {}
    for raw_clip in (source_value as Dictionary).get("animations", []):
        if str(raw_clip.get("name", "")) == "Melee_katana2":
            author_animators = raw_clip.get("animators", {})
            break
    if author_animators.is_empty():
        _fail("authored Katana2 missing from original model")
        return
    var tracks: Dictionary = authored.get("tracks", {})
    var raw_keyed_bones: int = 0
    var raw_keyframes: int = 0
    for raw_uid in author_animators.keys():
        var source_anim: Dictionary = author_animators[raw_uid]
        var source_keys: Array = source_anim.get("keyframes", [])
        if source_keys.is_empty():
            continue
        raw_keyed_bones += 1
        raw_keyframes += source_keys.size()
        if not tracks.has(raw_uid):
            _fail("missing authored Katana2 runtime bone " + str(raw_uid))
            return
        var imported: Dictionary = tracks[raw_uid]
        var copied_keys: int = 0
        for channel in ["rotation", "position", "scale"]:
            copied_keys += (imported.get(channel, []) as Array).size()
        if copied_keys != source_keys.size():
            _fail("Katana2 bone key mismatch " + str(raw_uid) +
                ": raw=" + str(source_keys.size()) +
                " runtime=" + str(copied_keys))
            return
    if raw_keyed_bones != 19 or raw_keyframes != 70:
        _fail("authored Katana2 source keys changed: %d bones/%d keys" % [
            raw_keyed_bones, raw_keyframes])
        return
    var bird_bones: Array = rig.get("bird_bone_ids")
    var extra_bird_keys: int = 0
    for raw_uid in tracks.keys():
        var raw_frames: Array = []
        if author_animators.has(raw_uid):
            raw_frames = (author_animators[raw_uid] as Dictionary).get("keyframes", [])
        if not raw_frames.is_empty():
            continue
        var imported: Dictionary = tracks[raw_uid]
        var count: int = 0
        for channel in ["rotation", "position", "scale"]:
            count += (imported.get(channel, []) as Array).size()
        if count == 0:
            continue
        if not bird_bones.has(raw_uid) or count != 1:
            _fail("non-authored Katana2 frames appeared outside bird idle fallback")
            return
        extra_bird_keys += count
    if extra_bird_keys != bird_bones.size():
        _fail("bird-leg idle stabilization incomplete")
        return
    rig.call("start_strike", "Melee_katana2")
    if str(rig.get("current_clip")) != "Melee_katana2":
        _fail("second strike could not start")
        return
    game.set("camera_radius", 9.6)
    game.call("_place_camera")
    var followed: Vector2 = game.get("camera_focus_follow_xz")
    var focus: Vector3 = Vector3(followed.x, 1.53 - 1.35, followed.y)
    var expected: float = 9.6 * sqrt(1.0 + 0.21 * 0.21)
    if absf(camera.position.distance_to(focus) - expected) > 0.0001:
        _fail("camera does not use the reduced orbit radius")
        return
    print("V294_KATANA2_CAMERA_RUNTIME_PASS")
    quit(0)
