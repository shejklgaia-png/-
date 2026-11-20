extends SceneTree
## LABO v531: exercise actual 3D nodes, native UI and atomic profile changes.
const Stats = preload("res://scripts/sera_labo_stats.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V531_LABO_RUNTIME_FAIL: " + message)
    quit(1)
func _run() -> void:
    var base: Dictionary = Stats.base_values("H01")
    if not is_equal_approx(float(base.get("hp", 0)), 20.0) or (
            not is_equal_approx(float(base.get("defense", 0)), 16.0)):
        _fail("base must reflect real A head stats")
        return
    var effects: Array = [
        {"id": "hp", "value": 4}, {"id": "defense", "value": 2},
        {"id": "energy", "value": 3}, {"id": "boost", "value": 3},
        {"id": "energy_recovery", "value": 2}
    ]
    var formula: String = Stats.total_formula("H01", effects)
    if not formula.contains("20.0 + (20.0 × 4%) = 20.8") or (
            not formula.contains("16.0% + 2% = 18.0%")):
        _fail("base + trait calculation or visible intermediate steps incorrect")
        return
    var hero: Node3D = load("res://scenes/labo_hero_stage.tscn").instantiate()
    root.add_child(hero)
    await process_frame
    hero.call("set_section", "SMELTER")
    if not (hero.get("converter_group") as Node3D).visible or (
            (hero.get("printer_group") as Node3D).visible):
        _fail("material conversion scene is not distinct 3D")
        return
    hero.call("set_section", "STORAGE")
    if not (hero.get("warehouse_group") as Node3D).visible or (
            (hero.get("converter_group") as Node3D).visible):
        _fail("warehouse scene is not distinct 3D")
        return
    hero.call("set_section", "LABO")
    if not (hero.get("printer_group") as Node3D).visible or (
            (hero.get("warehouse_group") as Node3D).visible):
        _fail("printer stage did not return")
        return
    hero.queue_free()
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    var scroll: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "PrototypeGridScroll", true, false) as ScrollContainer
    var card: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    if scroll == null or card == null or not card.is_visible_in_tree() or (
            scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO):
        _fail("craft bars are not a scrollable native card list")
        return
    var store: Node = root.get_node_or_null("SeraSave")
    if store == null:
        _fail("save autoload missing")
        return
    # Touch-equivalent entry must not produce an item before user confirms.
    fac.call("_select_prototype", "H01")
    if not (fac.get("confirmation_overlay") as Control).visible:
        _fail("craft tap skips the shared confirmation layer")
        return
    fac.call("_dismiss_confirmation")
    if (fac.get("confirmation_overlay") as Control).visible:
        _fail("cancel does not dismiss confirmation")
        return
    fac.call("_switch_section", "materials")
    fac.call("_select_conversion_family", "alloy")
    var amount: SpinBox = (fac.get("modal_actions") as VBoxContainer).find_child(
        "ConversionCount_0", true, false) as SpinBox
    if amount == null or amount.value != 1 or (
            not ((fac.get("modal_actions") as VBoxContainer).find_child(
                "ConvertRank_0", true, false) is Button)):
        _fail("conversion bar with adjacent quantity is missing")
        return
    # Persisted test only when profile 3 is free: never overwrite user data.
    if store.call("get_slot", 3).is_empty():
        var old_slot: int = int(store.get("active_slot"))
        var old_data: Dictionary = store.get("active_data").duplicate(true)
        var old_gear: Dictionary = store.get("working_equipment").duplicate(true)
        if not store.call("create_data", 3):
            _fail("isolated save creation failed")
            return
        fac.call("_switch_section", "craft")
        fac.call("_select_prototype", "H01")
        if not (store.call("get_owned_prototypes", "head") as Array).is_empty():
            _fail("craft minted before confirmation")
            return
        fac.call("_accept_confirmation")
        var owned: Array = store.call("get_owned_prototypes", "head")
        if owned.size() != 1 or not Affixes.valid(owned[0]["affixes"]):
            _fail("accept did not mint a saved item with five effects")
            return
        var uid: String = str(owned[0]["uid"])
        if not store.call("set_prototype_mark", uid, "favorite", true):
            _fail("cannot favorite a crafted item")
            return
        if not store.call("set_prototype_mark", uid, "junk", true):
            _fail("cannot mark an item as junk")
            return
        if not store.call("load_data", 3):
            _fail("new flags did not survive reload")
            return
        owned = store.call("get_owned_prototypes", "head")
        if bool(owned[0].get("favorite", true)) or (
                not bool(owned[0].get("junk", false))):
            _fail("favorite and junk must be exclusive and persisted")
            return
        if not store.call("equip_prototype", "head", uid):
            _fail("cannot equip fixture")
            return
        if int(store.call("count_junk_prototypes", "head")) != 0 or (
                int(store.call("delete_junk_prototypes", "head")) != 0):
            _fail("equipped junk was incorrectly deletable")
            return
        if not store.call("clear_equipped_prototype", "head") or (
                int(store.call("delete_junk_prototypes", "head")) != 1):
            _fail("confirmed bulk junk deletion failed")
            return
        var later: String = str(store.call("craft_prototype", "H01"))
        if later == uid or not later.ends_with("0002"):
            _fail("deleted item identity was reused")
            return
        if not store.call("delete_data", 3):
            _fail("fixture cleanup failed")
            return
        store.set("active_slot", old_slot)
        store.set("active_data", old_data)
        store.set("working_equipment", old_gear)
    print("SERA_V531_LABO_RUNTIME_PASS")
    quit(0)
