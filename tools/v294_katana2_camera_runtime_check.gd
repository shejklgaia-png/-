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
    var keyed_frames: int = 0
    var keyed_bones: int = 0
    var tracks: Dictionary = authored.get("tracks", {})
    for bone_data in tracks.values():
        if not (bone_data is Dictionary):
            continue
        var count: int = 0
        for channel in ["rotation", "position", "scale"]:
            count += (bone_data.get(channel, []) as Array).size()
        if count > 0:
            keyed_bones += 1
            keyed_frames += count
    if keyed_bones != 19 or keyed_frames != 70:
        _fail("authored tracks lost or UUIDs mismatched")
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
