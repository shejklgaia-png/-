extends SceneTree
## IRIS HEAD D: LAB -> confirmation -> warehouse -> NEXUS rig selection -> reload.
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const Stats = preload("res://scripts/sera_labo_stats.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")
const Icons = preload("res://scripts/sera_item_icons.gd")
const Rig = preload("res://scripts/sera_rig.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("SERA_IRIS_H02_CRAFT_RUNTIME_FAIL: " + message)
    quit(1)


func _run() -> void:
    var spec: Dictionary = Catalog.spec("H02")
    if str(spec.get("name", "")) != "アイリス" or (
            spec.get("slot") != "head" or spec.get("rig_set") != "D" or
            not Catalog.ORDER.has("H02")):
        _fail("H02 is not a selectable real D head blueprint")
        return
    if not is_equal_approx(float(Stats.base_values("H02").get("hp", -1)), 40.0):
        _fail("H02 must preserve current A-derived head base stats until balanced")
        return
    var icon: Texture2D = Icons.equipment_icon("H02")
    if icon == null or icon.get_width() != 512 or icon.get_height() != 512:
        _fail("H02 screenshot icon missing or not rendered at 512x512")
        return
    var pixels: Image = icon.get_image()
    if pixels == null or pixels.get_pixel(256, 256).a <= 0.0:
        _fail("H02 screenshot icon transparent at expected model center")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if fac == null:
        _fail("LAB facility missing")
        return
    fac.call("_switch_section", "craft")
    await process_frame
    var catalog_entry: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H02", true, false) as Button
    if catalog_entry == null or not catalog_entry.is_visible_in_tree():
        _fail("H02 icon/blueprint card missing in LAB's HEAD section")
        return
    fac.call("_select_prototype", "H02")
    if not (fac.get("confirmation_overlay") as Control).visible:
        _fail("H02 must require standard manufacturing confirmation")
        return
    fac.call("_dismiss_confirmation")
    if (fac.get("confirmation_overlay") as Control).visible:
        _fail("cancel did not dismiss H02 manufacture")
        return
    var rig: Node3D = Rig.new()
    root.add_child(rig)
    await process_frame
    if not (rig.call("get_equipment_options", "head") as Array).has("D"):
        _fail("authored HEAD D not selectable in real SERA rig")
        return
    rig.queue_free()
    var store: Node = root.get_node_or_null("SeraSave")
    if store == null:
        _fail("SeraSave autoload missing")
        return
    # Only touch an empty fixture save slot, preserving all real user saves.
    if store.call("get_slot", 3).is_empty():
        var old_slot: int = int(store.get("active_slot"))
        var old_data: Dictionary = store.get("active_data").duplicate(true)
        var old_gear: Dictionary = store.get("working_equipment").duplicate(true)
        if not store.call("create_data", 3):
            _fail("fixture save initialization failed")
            return
        fac.call("_switch_section", "craft")
        fac.call("_select_prototype", "H02")
        if not (store.call("get_owned_prototypes", "head") as Array).is_empty():
            _fail("H02 minted before accepting confirmation")
            return
        fac.call("_accept_confirmation")
        var owned: Array = store.call("get_owned_prototypes", "head")
        if owned.size() != 1 or str(owned[0].get("uid", "")) != "H02-0001" or (
                not Affixes.valid(owned[0].get("affixes", []))):
            _fail("H02 manufactured UID/5-affix item not present")
            return
        if not store.call("equip_prototype", "head", "H02-0001"):
            _fail("could not equip crafted H02")
            return
        if str(store.get("working_equipment").get("head", "")) != "D":
            _fail("craft-equipping H02 did not select real HEAD D")
            return
        if not store.call("load_data", 3):
            _fail("fixture reload failed")
            return
        if str(store.call("get_equipped_prototype", "head")) != "H02-0001" or (
                str(store.get("working_equipment").get("head", "")) != "D"):
            _fail("H02 UID and rig HEAD D did not survive reload")
            return
        if not store.call("delete_data", 3):
            _fail("fixture cleanup failed")
            return
        store.set("active_slot", old_slot)
        store.set("active_data", old_data)
        store.set("working_equipment", old_gear)
    print("SERA_IRIS_H02_CRAFT_RUNTIME_PASS")
    quit(0)
