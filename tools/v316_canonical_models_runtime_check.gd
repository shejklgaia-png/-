extends SceneTree
## Verify actual Godot loads canonical models, bird tracks and independent parts.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V316_CANONICAL_RUNTIME_FAILED: " + reason)
    quit(1)

func _run() -> void:
    var script: GDScript = load("res://scripts/sera_rig.gd")
    if script == null:
        _fail("missing canonical SERA rig")
        return
    var rig: Node3D = script.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _fail("canonical rig failed to initialize")
        return
    var equipment: RefCounted = rig.get("equipment_handler")
    var available: Dictionary = equipment.get("available")
    if not available.has("C") or not available.has("D"):
        _fail("missing bird C or lower body D set")
        return
    var c: Dictionary = available["C"]
    var d: Dictionary = available["D"]
    if (c.get("head", []) as Array).size() != 2:
        _fail("standalone Head C not installed as two meshes")
        return
    if (c.get("legs", []) as Array).size() != 10:
        _fail("bird C geometry or bone hierarchy lost")
        return
    if (d.get("legs", []) as Array).size() != 12:
        _fail("standalone Lower Body D not installed as twelve meshes")
        return
    if not (rig.call("get_equipment_options", "head") as Array).has("C"):
        _fail("Head C not selectable")
        return
    if not (rig.call("get_equipment_options", "legs") as Array).has("D"):
        _fail("Lower Body D not selectable")
        return
    var clips: Dictionary = rig.get("animations")
    for name in ["NEXUS_pose","Melee_katana","Melee_katana2","Kick_l","Kick_r","Step_R"]:
        if not clips.has(name):
            _fail("canonical authored animation missing: " + name)
            return
        var tracks: Dictionary = (clips[name] as Dictionary).get("tracks", {})
        if tracks.is_empty():
            _fail("animation has no bone tracks: " + name)
            return
    var bird_uids: Array = rig.get("bird_bone_ids")
    if bird_uids.size() != 6:
        _fail("bird skeleton has incorrect joint count")
        return
    for uid in bird_uids:
        if not (clips["NEXUS_pose"]["tracks"] as Dictionary).has(uid):
            _fail("bird pose track missing from NEXUS pose")
            return
    rig.call("start_strike", "Melee_katana2")
    if str(rig.get("current_clip")) != "Melee_katana2":
        _fail("authored Katana2 was not playable")
        return
    print("GODOT_V316_CANONICAL_SOURCES_PASS")
    quit(0)
