extends SceneTree
## Every material + test item has a real alpha-bearing image, and owned items
## use stable names/IDs across multiple craft operations and save/reload.
const IconAtlas = preload("res://scripts/sera_item_icons.gd")
const Materials = preload("res://scripts/sera_base_materials.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_MATTE_ICON_RUNTIME_FAIL: " + reason)
    quit(1)

func _real_icon(texture: Texture2D) -> bool:
    if texture == null or texture.get_width() < 20 or texture.get_height() < 20:
        return false
    var img: Image = texture.get_image()
    if img == null:
        return false
    for x in range(0, img.get_width(), 4):
        for y in range(0, img.get_height(), 4):
            if img.get_pixel(x, y).a > 0.35:
                return true
    return false

func _run() -> void:
    if Materials.all_ids().size() != 12 or Catalog.PROTOTYPES.size() != 7:
        _fail("catalog does not have exactly twelve materials and seven items")
        return
    for id in Materials.all_ids():
        if not _real_icon(IconAtlas.material_icon(str(id))):
            _fail("empty material image: " + str(id))
            return
    for id in Catalog.PROTOTYPES.keys():
        if not _real_icon(IconAtlas.equipment_icon(str(id))):
            _fail("empty craftable image: " + str(id))
            return
    # Material icons are independent 72x72 textures: using a single AtlasTexture
    # caused Android to show a fragment of the next sprite-sheet row.
    var used_regions: Dictionary = {}
    for material_id in Materials.all_ids():
        var material_icon: Texture2D = IconAtlas.material_icon(str(material_id))
        if material_icon == null or material_icon is AtlasTexture or (
                material_icon.get_width() != 72 or material_icon.get_height() != 72):
            _fail("material icon not independently cropped: " + str(material_id))
            return
        var key: String = str(material_icon.get_instance_id())
        if used_regions.has(key):
            _fail("shared material sprite: " + str(material_id))
            return
        used_regions[key] = true
    for blueprint in Catalog.PROTOTYPES.keys():
        var equipment_icon_atlas: AtlasTexture = IconAtlas.equipment_icon(str(blueprint)) as AtlasTexture
        var equipment_key: String = str(equipment_icon_atlas.atlas.get_instance_id()) + ":" + str(equipment_icon_atlas.region) if equipment_icon_atlas != null else ""
        if equipment_icon_atlas == null or used_regions.has(equipment_key):
            _fail("duplicate or missing equipment atlas region: " + str(blueprint))
            return
        used_regions[equipment_key] = true
    if used_regions.size() != 19 or Catalog.uid_for("H01", 1) != "H01-0001" or (
            not Catalog.valid_uid("H01-0001", "H01")) or (
            Catalog.valid_uid("H01-1", "H01")) or (
            Catalog.valid_uid("T01-0001", "H01")):
        _fail("unique icons or canonical item UID contract failed")
        return
    var profile: Node = root.get_node_or_null("SeraSave")
    if profile == null:
        _fail("SeraSave missing")
        return
    # Protect real user data if this standalone test is launched locally.
    var old_slot: int = int(profile.get("active_slot"))
    var old_data: Dictionary = profile.get("active_data").duplicate(true)
    profile.set("active_slot", 0)
    if profile.call("craft_prototype", "H01") != "":
        _fail("crafting without selected profile is allowed")
        return
    profile.set("active_slot", old_slot)
    profile.set("active_data", old_data)
    if profile.call("get_slot", 3).is_empty():
        if not bool(profile.call("create_data", 3)):
            _fail("cannot create isolated profile")
            return
        var name1: String = profile.call("craft_prototype", "H01")
        var name2: String = profile.call("craft_prototype", "H01")
        if name1 != "H01-0001" or name2 != "H01-0002":
            _fail("duplicate-proof sequential names failed: " + name1 + "/" + name2)
            return
        var torso_name: String = profile.call("craft_prototype", "T01")
        if torso_name != "T01-0001":
            _fail("per-blueprint sequence failed: " + torso_name)
            return
        if profile.call("craft_prototype", "NOT_A_BLUEPRINT") != "":
            _fail("invalid craft ID should not create inventory")
            return
        if not bool(profile.call("equip_prototype", "head", name2)):
            _fail("owned head item cannot be selected")
            return
        if bool(profile.call("equip_prototype", "legs", name2)):
            _fail("head item applied in legs slot")
            return
        if not bool(profile.call("load_data", 3)):
            _fail("failed to reload crafted inventory")
            return
        if profile.call("get_equipped_prototype", "head") != name2:
            _fail("selected crafted item was not saved")
            return
        var owned: Array = profile.call("get_owned_prototypes", "head")
        if owned.size() != 2 or owned[0]["uid"] == owned[1]["uid"]:
            _fail("inventory did not persist unique item copies")
            return
        if profile.call("get_owned_prototypes", "torso").size() != 1 or (
                Catalog.display_instance(name2).find(name2) == -1):
            _fail("per-slot storage or unique display name missing")
            return
        if profile.call("craft_prototype", "H01") != "H01-0003":
            _fail("serial not monotonic after profile reload")
            return
        if not bool(profile.call("delete_data", 3)):
            _fail("test fixture cleanup failed")
            return
        profile.set("active_slot", old_slot)
        profile.set("active_data", old_data)
        profile.call("_write_index", old_slot)
    var hub_scene: PackedScene = load("res://scenes/base_exploration.tscn")
    var hub: Node3D = hub_scene.instantiate()
    root.add_child(hub)
    await process_frame
    var facilities: Node = hub.get_node_or_null("BaseFacilities")
    if facilities == null:
        _fail("missing base facilities")
        return
    facilities.call("open_facility", "STORAGE")
    await process_frame
    await process_frame
    var actions: VBoxContainer = facilities.get("modal_actions") as VBoxContainer
    var warehouse: ScrollContainer = (facilities.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if warehouse == null or (warehouse.get("entries") as Array).size() != 12:
        _fail("twelve material entries missing from warehouse virtual list")
        return
    for material_id in Materials.all_ids():
        var exists: bool = false
        for entry in warehouse.get("entries"):
            if str(entry.get("id", "")) == str(material_id):
                exists = true
                break
        if not exists:
            _fail("missing material from virtual list: " + str(material_id))
            return
    if (warehouse.get("pool") as Array).is_empty():
        _fail("no visible material cards were created")
        return
    facilities.call("open_facility", "SMELTER")
    facilities.call("_select_conversion_family", "organic")
    actions = facilities.get("modal_actions") as VBoxContainer
    var conversion: Button = actions.find_child("ConvertRank_0", true, false) as Button
    if conversion == null or (
            (conversion.find_child("ConvertInputIcon_0", true, false) as TextureRect).texture == null) or (
            (conversion.find_child("ConvertOutputIcon_0", true, false) as TextureRect).texture == null):
        _fail("converter must show source and destination icon")
        return
    facilities.call("open_facility", "LABO")
    facilities.call("_show_prototype_catalog")
    actions = facilities.get("modal_actions") as VBoxContainer
    for id in Catalog.PROTOTYPES.keys():
        facilities.call("_select_craft_slot", str(Catalog.spec(str(id))["slot"]))
        if (facilities.get("item_layer") as Control).find_child(
                "PrototypeIcon_" + str(id), true, false) == null:
            _fail("LABO blueprint is missing icon: " + str(id))
            return
    print("SERA_MATTE_ICON_RUNTIME_PASS: every icon, crafting, unique naming, warehouse, customization registry")
    quit(0)
