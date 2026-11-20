extends SceneTree
## Real GUI tree and transactional sample-material/unique-item flow.
const MAT = preload("res://scripts/sera_base_materials.gd")
const CATALOG = preload("res://scripts/sera_prototype_catalog.gd")
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_V517_UI_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var save: Node = root.get_node_or_null("SeraSave")
    if save == null:
        _fail("save autoload missing")
        return
    var prior_slot: int = int(save.get("active_slot"))
    var prior_data: Dictionary = save.get("active_data").duplicate(true)
    var prior_gear: Dictionary = save.get("working_equipment").duplicate(true)
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    await process_frame
    var facility: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if facility == null or hub.has_node("BaseHUDLayer/BaseHUD/BaseQuickActions"):
        _fail("facility missing or obsolete bottom buttons returned")
        return
    await process_frame
    var viewport_rect := Rect2(Vector2.ZERO, hub.get_viewport().get_visible_rect().size)
    # A fresh runtime with no selected profile must still show the catalog.
    save.set("active_slot", 0)
    save.set("active_data", {})
    facility.call("_switch_section", "craft")
    # v527 creates every native card before icon loading. The deferred icon
    # binding must finish before asserting art, without relaxing the assertion.
    await process_frame
    if str(facility.get("page")) != "prototypes":
        _fail("quick craft did not open LABO recipes")
        return
    var actions: VBoxContainer = facility.get("modal_actions") as VBoxContainer
    for blueprint in CATALOG.ORDER:
        var spec: Dictionary = CATALOG.spec(str(blueprint))
        facility.call("_select_craft_slot", str(spec["slot"]))
        await process_frame
        var row: Button = (facility.get("item_layer") as Control).find_child(
            "PrototypeIcon_" + str(blueprint), true, false) as Button
        if row == null or (row.find_child("ItemArt", true, false) as TextureRect).texture == null:
            _fail("unrenderable craft icon: " + str(blueprint))
            return
    facility.call("_select_craft_slot", "head")
    await process_frame
    await process_frame
    var first_icon: Button = (facility.get("item_layer") as Control).find_child("PrototypeIcon_H01", true, false) as Button
    if not first_icon.is_visible_in_tree() or (
            not viewport_rect.has_point(first_icon.get_global_rect().get_center())):
        _fail("first craft icon does not appear in visible modal")
        return
    var open_slot: int = 0
    for slot in range(1, 4):
        if save.call("get_slot", slot).is_empty():
            open_slot = slot
            break
    if open_slot > 0:
        var start: Button = actions.get_node_or_null("CreateTrialProfile") as Button
        if start == null:
            _fail("no one-tap profile creation on unsaved catalog")
            return
        start.pressed.emit()
        if int(save.get("active_slot")) != open_slot:
            _fail("sample save was not activated")
            return
        facility.call("_select_prototype", "H01")
        var confirm: Control = facility.get("confirmation_overlay") as Control
        if not confirm.visible:
            _fail("craft confirmation hidden on active profile")
            return
        if (save.call("get_owned_prototypes", "head") as Array).size() != 0:
            _fail("craft wrote an item before confirmation")
            return
        facility.call("_accept_confirmation")
        if save.call("get_owned_prototypes", "head").size() != 1:
            _fail("trial equipment not saved to warehouse")
            return
        facility.call("open_facility", "LABO")
        if (facility.get("modal_actions") as VBoxContainer).find_child(
                "ClaimTrialMaterialsCatalog", true, false) != null:
            _fail("trial-material reward must not appear in LABO")
            return
        # Legacy API is retained for save compatibility; no longer a UI entry.
        if not bool(save.call("claim_trial_materials")):
            _fail("legacy trial reward persistence API is broken")
            return
        var stock: Dictionary = save.call("get_material_inventory")
        for id in MAT.all_ids():
            if int(stock.get(id, 0)) < 6:
                _fail("trial material missing: " + str(id))
                return
        if bool(save.call("claim_trial_materials")):
            _fail("test material reward duplicated")
            return
        if not bool(save.call("load_data", open_slot)):
            _fail("sample profile not persisted")
            return
        if save.call("get_owned_prototypes", "head").size() != 1 or (
                not bool(save.call("get_active_data").get("trial_materials_claimed", false))):
            _fail("trial items or reward flag lost on reload")
            return
        if not bool(save.call("delete_data", open_slot)):
            _fail("test save cleanup failed")
            return
    save.set("active_slot", prior_slot)
    save.set("active_data", prior_data)
    save.set("working_equipment", prior_gear)
    save.call("_write_index", prior_slot)
    facility.call("_switch_section", "materials")
    if str(facility.get("page")) != "families":
        _fail("materials shortcut must open conversion")
        return
    facility.call("_switch_section", "warehouse")
    # Preserve the exact 12-icon requirement after deferred binding settles.
    await process_frame
    if str(facility.get("page")) != "inventory":
        _fail("warehouse shortcut did not open storage")
        return
    actions = facility.get("modal_actions") as VBoxContainer
    var warehouse: ScrollContainer = (facility.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if warehouse == null or int(warehouse.get("columns")) != 3 or (
            (warehouse.get("entries") as Array).size() != MAT.all_ids().size()):
        _fail("warehouse must retain all twelve materials in the virtual list")
        return
    await process_frame
    var first_material: Button = (facility.get("item_layer") as Control).find_child("MaterialIcon_scrap_low", true, false) as Button
    if first_material == null or (
            (first_material.get_node("ItemArt") as TextureRect).texture == null) or (
            not first_material.is_visible_in_tree()) or (
            not viewport_rect.has_point(first_material.get_global_rect().get_center())):
        _fail("first warehouse material icon does not appear in visible modal")
        return
    print("SERA_V517_UI_RUNTIME_PASS: direct actions, 19 icons, sample stock, save and duplicates")
    quit(0)
