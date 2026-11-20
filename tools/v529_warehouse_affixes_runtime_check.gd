extends SceneTree
## v529: test actual Godot affix storage and virtualized display; isolated user:// via CI.
const Affixes = preload("res://scripts/sera_craft_affixes.gd")
const Grid = preload("res://scripts/sera_warehouse_grid.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(msg: String) -> void:
    push_error("SERA_V529_WAREHOUSE_AFFIXES_FAIL: " + msg)
    quit(1)
func _run() -> void:
    for i in range(40):
        var rolls: Array = Affixes.roll_five()
        if rolls.size() != 5 or not Affixes.valid(rolls):
            _fail("craft rolled invalid five modifiers")
            return
    var w: ScrollContainer = Grid.new()
    w.size = Vector2(640, 460)
    root.add_child(w)
    await process_frame
    var rows: Array = []
    for i in range(999):
        rows.append({"uid": "H01-%04d" % (i+1), "blueprint": "H01",
            "name": "テスト", "affixes": Affixes.roll_five()})
    w.call("configure", rows, 2, "equipment")
    await process_frame
    await process_frame
    if int(w.get("columns")) != 2 or (w.get("entries") as Array).size() != 999:
        _fail("equipment virtual list count/column mismatch")
        return
    if (w.get("pool") as Array).size() > 32:
        _fail("warehouse allocated nodes per item, not per viewport")
        return
    if w.get_v_scroll_bar().max_value < 999.0:
        _fail("999 items did not create virtual scrolling range")
        return
    w.scroll_vertical = 3000
    await process_frame
    if (w.get("pool") as Array).size() > 32:
        _fail("scroll caused unbounded card creation")
        return
    w.call("configure", [], 2, "equipment")
    await process_frame
    if int(w.get("virtual_slots")) != 999:
        _fail("empty category must expose all 999 virtual hanger positions")
        return
    var materials: Array = []
    for family in ["scrap", "alloy", "electronics", "organic"]:
        for tier in ["low", "mid", "high"]:
            materials.append({"id": family+"_"+tier, "name": family, "count": 0})
    w.call("configure", materials, 2, "materials")
    await process_frame
    if int(w.get("columns")) != 2 or int(w.get("virtual_slots")) != 12:
        _fail("materials must be six rows of two")
        return
    var save: Node = root.get_node_or_null("SeraSave")
    if save == null:
        _fail("save autoload missing")
        return
    var old_slot: int = int(save.get("active_slot"))
    var old_data: Dictionary = save.get("active_data").duplicate(true)
    save.set("active_slot", 1)
    save.set("active_data", {
        "crafted_items": [], "craft_serials": {},
        "equipped_crafted": {}, "materials": {}
    })
    # Never touch an existing user profile on local/manual test launches:
    # run persisted crafting only if slot 3 is empty.
    if save.call("get_slot", 3).is_empty():
        if not save.call("create_data", 3):
            _fail("test save creation failed")
            return
        var uid: String = save.call("craft_prototype", "H01")
        var owned: Array = save.call("get_owned_prototypes", "head")
        if uid != "H01-0001" or owned.size() != 1 or (
                not Affixes.valid(owned[0].get("affixes", []))):
            _fail("first craft did not save exactly five affixes")
            return
        var baseline: Array = owned[0]["affixes"].duplicate(true)
        if not save.call("load_data", 3):
            _fail("crafted item cannot reload")
            return
        owned = save.call("get_owned_prototypes", "head")
        if owned.size() != 1 or owned[0]["affixes"] != baseline:
            _fail("affixes changed during reload")
            return
        if not save.call("delete_data", 3):
            _fail("fixture cleanup failed")
            return
    # Boundary via in-memory fixture to avoid 999 disk writes in CI.
    save.set("active_slot", 1)
    var full: Array = []
    for i in range(999):
        full.append({"uid": "H01-%04d" % (i+1),
            "blueprint": "H01", "slot": "head", "affixes": Affixes.roll_five()})
    save.set("active_data", {"crafted_items": full, "craft_serials": {"H01": 999}})
    if save.call("craft_prototype", "H01") != "":
        _fail("1000th head accepted")
        return
    if (save.call("get_owned_prototypes", "head") as Array).size() != 999:
        _fail("overflow test mutated existing inventory")
        return
    save.set("active_slot", old_slot)
    save.set("active_data", old_data)
    # Do not touch original index if a user profile is active.
    print("SERA_V529_WAREHOUSE_AFFIXES_RUNTIME_PASS")
    quit(0)
