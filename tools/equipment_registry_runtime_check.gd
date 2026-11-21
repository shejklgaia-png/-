extends SceneTree
## Live model + exact stats + bitmap coverage; no user-save mutation.
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const PartStats = preload("res://scripts/sera_part_stats.gd")
const Icons = preload("res://scripts/sera_item_icons.gd")
const RigScript = preload("res://scripts/sera_rig.gd")

func _initialize() -> void:
    call_deferred("_check")

func _fail(reason: String) -> void:
    push_error("SERA_EQUIPMENT_REGISTRY_RUNTIME_FAIL: " + reason)
    quit(1)

func _check() -> void:
    var rig: Node3D = RigScript.new()
    root.add_child(rig)
    await process_frame
    if not bool(rig.get("loading_ok")):
        _fail("SeraRig loading failed")
        return
    var handler: RefCounted = rig.get("equipment_handler") as RefCounted
    if handler == null:
        _fail("Equipment handler not loaded")
        return
    var profiles: Dictionary = PartStats.PROFILES
    var seen: Dictionary = {}
    var available: Dictionary = handler.get("available")
    for bp in Catalog.ORDER:
        var id: String = str(bp)
        var spec: Dictionary = Catalog.spec(id)
        var slot: String = str(spec.get("slot", ""))
        var model_key: String = str(spec.get("rig_set", ""))
        var key: String = slot + ":" + model_key
        if seen.has(key):
            _fail("Duplicate model registered under two blueprints: " + key)
            return
        seen[key] = true
        if not profiles.has(slot) or not (profiles[slot] as Dictionary).has(model_key):
            _fail(id + ": missing full authored performance profile")
            return
        var stats: Dictionary = profiles[slot][model_key]
        if stats.is_empty() or not stats.has("weight_pct"):
            _fail(id + ": profile has no part-specific mass/performance")
            return
        var base: Dictionary = profiles[slot]["A"]
        for field in base.keys():
            if not stats.has(field):
                _fail(id + ": missing base-profile property " + str(field))
                return
        if not available.has(model_key) or (available[model_key] as Dictionary).get(slot, []).is_empty():
            _fail(id + ": no real runtime MeshInstance3D for " + key)
            return
        var icon: Texture2D = Icons.equipment_icon(id)
        if icon == null or icon.get_width() != 512 or icon.get_height() != 512:
            _fail(id + ": no transparent native PNG/composite")
            return
        if icon != Icons.equipment_icon(id):
            _fail(id + ": one-icon-per-blueprint cache is broken")
            return
        var original: String = Icons.NATIVE_EQUIPMENT_DIRECTORY + "/" + id + ".png"
        if not FileAccess.file_exists(original) and not ResourceLoader.exists(original):
            _fail(id + ": native source PNG missing")
            return
        if not Catalog.valid_uid(Catalog.uid_for(id, 1), id):
            _fail(id + ": crafted UID identity invalid")
            return
    if seen.size() != 19:
        _fail("Installed model coverage is not nineteen")
        return
    print("SERA_EQUIPMENT_REGISTRY_RUNTIME_PASS parts=19 real_models=true complete_profiles=true")
    quit(0)
