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
    var bar: HBoxContainer = hub.get_node_or_null("BaseHUDLayer/BaseHUD/BaseQuickActions") as HBoxContainer
    var facility: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if bar == null or facility == null or not bar.visible:
        _fail("first-launch shortcuts not visible")
        return
    var btn: Button = bar.get_node_or_null("QuickCraft") as Button
    var resources: Button = bar.get_node_or_null("QuickMaterials") as Button
    var warehouse: Button = bar.get_node_or_null("QuickWarehouse") as Button
    if btn == null or resources == null or warehouse == null:
        _fail("craft/material/warehouse shortcuts missing")
        return
    if btn.text.contains("›") or resources.text.contains("▸"):
        _fail("decorative arrows returned in shortcuts")
        return
    # A fresh runtime with no selected profile must still show the catalog.
    save.set("active_slot", 0)
    save.set("active_data", {})
    btn.pressed.emit()
    if str(facility.get("page")) != "prototypes":
        _fail("quick craft did not open LABO recipes")
        return
    var actions: VBoxContainer = facility.get("modal_actions") as VBoxContainer
    for blueprint in CATALOG.ORDER:
        var row: HBoxContainer = actions.get_node_or_null("PrototypeIcon_" + str(blueprint)) as HBoxContainer
        var icon: TextureRect = row.get_node_or_null("Icon") as TextureRect if row != null else null
        if icon == null or icon.texture == null or (
                icon.texture.get_width() <= 0):
            _fail("unrenderable craft icon: " + str(blueprint))
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
        actions = facility.get("modal_actions") as VBoxContainer
        var make: Button = actions.get_node_or_null("CraftPrototype") as Button
        if make == null or make.disabled:
            _fail("craft action hidden or disabled on active profile")
            return
        make.pressed.emit()
        if save.call("get_owned_prototypes", "head").size() != 1:
            _fail("trial equipment not saved to warehouse")
            return
        facility.call("open_facility", "LABO")
        var collect: Button = (facility.get("modal_actions") as VBoxContainer).get_node_or_null("ClaimTrialMaterials") as Button
        if collect == null:
            _fail("material trial action missing from LABO")
            return
        collect.pressed.emit()
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
    resources.pressed.emit()
    if str(facility.get("page")) != "families":
        _fail("materials shortcut must open conversion")
        return
    warehouse.pressed.emit()
    if str(facility.get("page")) != "inventory":
        _fail("warehouse shortcut did not open storage")
        return
    actions = facility.get("modal_actions") as VBoxContainer
    for material_id in MAT.all_ids():
        var row: HBoxContainer = actions.get_node_or_null("MaterialIcon_" + str(material_id)) as HBoxContainer
        var icon: TextureRect = row.get_node_or_null("Icon") as TextureRect if row != null else null
        if icon == null or icon.texture == null:
            _fail("material icon missing in visible warehouse: " + str(material_id))
            return
    print("SERA_V517_UI_RUNTIME_PASS: direct actions, 19 icons, sample stock, save and duplicates")
    quit(0)
