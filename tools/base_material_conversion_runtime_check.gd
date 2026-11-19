extends SceneTree
## Material contracts: four families/three ranks; exact recipe keys; reversible
## 2:1/1:2 provisional rank conversion; no material creation or substitution.
const MAT = preload("res://scripts/sera_base_materials.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_BASE_MATERIAL_FAIL: " + reason)
    quit(1)
func _run() -> void:
    var all: Array = MAT.all_ids()
    if all.size() != 12:
        _fail("four families x three ranks not registered")
        return
    var unique: Dictionary = {}
    for id in all:
        if unique.has(id) or str(MAT.display_name(id)).is_empty():
            _fail("duplicate or unnamed inventory ID: " + str(id))
            return
        unique[id] = true
    if MAT.FAMILY_IDS.size() != 4 or MAT.TIERS.size() != 3:
        _fail("family or tier count changed")
        return
    var initial: Dictionary = MAT.empty_inventory()
    for id in all:
        if initial.get(id, -1) != 0:
            _fail("fresh inventory must start empty without free resources")
            return
    # A crafting requirement is exact; neighboring quality materials must
    # never be accepted as direct substitutes.
    initial["alloy_low"] = 2
    if bool(MAT.meets_requirements(initial, {"alloy_mid": 1})):
        _fail("lower-quality alloy substituted for exact mid-tier alloy")
        return
    if not bool(MAT.meets_requirements(initial, {"alloy_low": 2})):
        _fail("exact crafting recipe was rejected")
        return
    for family in MAT.FAMILY_IDS:
        var low: String = family + "_low"
        var mid: String = family + "_mid"
        var high: String = family + "_high"
        var stocks: Dictionary = MAT.empty_inventory()
        stocks[low] = 4
        var step1: Dictionary = MAT.convert(stocks, family, 0, 1, 2)
        if not bool(step1.get("ok", false)) or (
                int((step1["inventory"] as Dictionary)[low]) != 0) or (
                int((step1["inventory"] as Dictionary)[mid]) != 2):
            _fail("low to mid exact conversion failed for " + family)
            return
        var step2: Dictionary = MAT.convert(step1["inventory"], family, 1, 1, 1)
        if not bool(step2.get("ok", false)) or (
                int((step2["inventory"] as Dictionary)[high]) != 1):
            _fail("mid to high refinement failed for " + family)
            return
        var down1: Dictionary = MAT.convert(step2["inventory"], family, 2, -1, 1)
        var down2: Dictionary = MAT.convert(down1.get("inventory", {}), family, 1, -1, 2)
        if not bool(down1.get("ok", false)) or not bool(down2.get("ok", false)):
            _fail("high to low dismantle failed for " + family)
            return
        var final_stock: Dictionary = down2["inventory"]
        if final_stock != stocks:
            _fail("round-trip has a resource duplication/loss: " + family)
            return
        var unmet: Dictionary = MAT.convert(stocks, family, 0, 1, 3)
        if bool(unmet.get("ok", false)) or stocks[low] != 4:
            _fail("insufficient stock created or consumed a material")
            return
    if bool(MAT.convert(initial, "alloy", 0, -1, 1).get("ok", false)) or (
            bool(MAT.convert(initial, "unknown", 0, 1, 1).get("ok", false))) or (
            bool(MAT.convert(initial, "alloy", 2, 1, 1).get("ok", false))) or (
            bool(MAT.convert(initial, "alloy", 0, 1, 0).get("ok", false))):
        _fail("invalid rank, family, or quantity was accepted")
        return
    var profile: Node = root.get_node_or_null("SeraSave")
    if profile == null:
        _fail("persistent profile autoload missing")
        return
    # No active save => cannot spend or mint goods.
    var slot_before: int = int(profile.get("active_slot"))
    var data_before: Dictionary = profile.get("active_data").duplicate(true)
    profile.set("active_slot", 0)
    if bool(profile.call("convert_material", "alloy", 0, 1, 1)):
        _fail("conversion without a selected profile was allowed")
        return
    profile.set("active_slot", slot_before)
    profile.set("active_data", data_before)
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    await process_frame
    var devices: Node3D = hub.get_node_or_null("BaseFacilities")
    if devices == null:
        _fail("converter field structures are absent")
        return
    for key in ["SMELTER", "RECYCLER", "STORAGE"]:
        devices.call("open_facility", key)
        var panel: Control = devices.get("modal") as Control
        if panel == null or not panel.visible:
            _fail("converter/store modal failed to open: " + key)
            return
        devices.call("close_menu")
    print("SERA_BASE_MATERIAL_RUNTIME_PASS: 12 exact inputs, bidirectional conversion and menus")
    quit(0)
