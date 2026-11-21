extends SceneTree
## Missing imported WebP must not hide native craft/conversion and virtual warehouse cells.
const Icons = preload("res://scripts/sera_item_icons.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_V527_ANDROID_ICON_RESILIENCE_FAIL: " + message)
    quit(1)

func _card_count(layer: Control) -> int:
    # Native ScrollContainer wraps the real row grid. Count actual Buttons
    # recursively rather than assuming row grid is the first direct child.
    var count: int = 0
    for child in layer.find_children("*", "Button", true, false):
        if child is Button:
            count += 1
    return count

func _expect(fac: Node, target: String, count: int, first_name: String) -> bool:
    fac.call("_switch_section", target)
    await process_frame
    await process_frame
    var layer: Control = fac.get("item_layer") as Control
    if target == "warehouse":
        fac.call("_show_inventory", "materials")
        await process_frame
        var list: ScrollContainer = layer.find_child("WarehouseMaterials", true, false) as ScrollContainer
        if list == null or int(list.get("columns")) != 2 or (
                (list.get("entries") as Array).size() != count):
            _fail("virtual materials list lost entries without imported WebP")
            return false
        var pool: Array = list.get("pool")
        if pool.is_empty() or pool.size() > 32:
            _fail("virtual missing-image card pool must stay bounded")
            return false
        var first_virtual: Button = pool[0] as Button
        if first_virtual == null or not first_virtual.is_visible_in_tree() or (
                (first_virtual.get_node("ItemTitle") as Label).text.is_empty()):
            _fail("virtual card lost text without WebP import")
            return false
        if (first_virtual.get_node("ItemArt") as TextureRect).texture != null:
            _fail("missing source unexpectedly resolved in virtual material card")
            return false
        if first_virtual.get_theme_stylebox("normal") is not StyleBoxTexture:
            _fail("missing-image material card needs cut-corner outline")
            return false
        return true
    var first: Button = layer.find_child(first_name, true, false) as Button
    if first == null or not first.is_visible_in_tree() or first.text.is_empty():
        _fail("missing native labelled slot without an image: " + first_name)
        return false
    if _card_count(layer) != count or first.get_global_rect().size.y < 80.0:
        _fail("no-image slot count or layout broken for " + target)
        return false
    # Native model PNGs remain available even when the retired WebP mockups
    # and Android's imported material atlas are deliberately unavailable.
    var photo: TextureRect = first.find_child("ItemArt", true, false) as TextureRect
    if first.icon != null:
        _fail("root Button should never draw its own icon")
        return
    if target == "craft" and (photo == null or photo.texture == null):
        _fail("native equipment photograph vanished without retired WebP")
        return
    if target != "craft" and photo != null and photo.texture != null:
        _fail("missing source unexpectedly resolved in material row")
        return false
    if first.get_theme_stylebox("normal") is not StyleBoxTexture:
        _fail("rounded frame must remain visible when icon source is missing")
        return false
    return true

func _run() -> void:
    var atlas_path := "res://assets/ui/sera_matte_icon_atlas.webp"
    var raw: Texture2D = Icons._decode_webp_source(atlas_path)
    if raw == null or raw.get_size() != Vector2(288, 360):
        _fail("raw source WebP fallback cannot decode the 4x5 icon atlas")
        return
    if Icons._decode_webp_source(atlas_path + ".missing") != null:
        _fail("missing image source must return null, not abort GDScript")
        return
    var material_raw: Texture2D = Icons._decode_webp_source(
        Icons.MATERIAL_ATLAS_PATH, 216, 288)
    if material_raw == null or material_raw.get_size() != Vector2(216, 288):
        _fail("pixel material source WebP fallback cannot decode the 3x4 atlas")
        return
    if Icons._decode_webp_source(Icons.MATERIAL_ATLAS_PATH + ".missing", 216, 288) != null:
        _fail("missing material image source must return null")
        return
    # Simulate BOTH sources being unavailable, independently of the import
    # cache. Old test assumed there was only one shared atlas.
    Icons._atlas_loaded = true
    Icons._atlas_texture_cache = null
    Icons._material_atlas_loaded = true
    Icons._material_texture_cache = null
    # v530 adds a decoded-source cache plus one ImageTexture per material.
    # Disable every cache to reproduce truly missing source + import state.
    Icons._material_source_attempted = true
    Icons._material_source_image = null
    Icons._material_frame_cache.clear()
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node = hub.get_node("BaseFacilities")
    if not await _expect(fac, "craft", 20, "PrototypeIcon_H01"):
        return
    if not await _expect(fac, "materials", 12, "MaterialIcon_scrap_low"):
        return
    if not await _expect(fac, "warehouse", 12, "MaterialIcon_scrap_low"):
        return
    Icons._atlas_loaded = false
    Icons._atlas_texture_cache = null
    Icons._material_atlas_loaded = false
    Icons._material_texture_cache = null
    Icons._material_source_attempted = false
    Icons._material_source_image = null
    Icons._material_frame_cache.clear()
    if Icons.material_icon("scrap_low") == null or Icons.equipment_icon("H01") == null:
        _fail("icon lookup failed after recovering normal atlas loading")
        return
    print("SERA_V527_ANDROID_ICON_RESILIENCE_RUNTIME_PASS: dual raw WebP sources; 1 selected-slot craft + 12 + 12 native/virtual slots without imports")
    quit(0)
