extends SceneTree
## Missing imported WebP must not prevent any of the 7/12/12 native cards.
const Icons = preload("res://scripts/sera_item_icons.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_V527_ANDROID_ICON_RESILIENCE_FAIL: " + message)
    quit(1)

func _card_count(layer: Control) -> int:
    var count := 0
    for grid in layer.get_children():
        for row in grid.get_children():
            for card in row.get_children():
                if card is Button:
                    count += 1
    return count

func _expect(fac: Node, target: String, count: int, first_name: String) -> bool:
    fac.call("_switch_section", target)
    await process_frame
    await process_frame
    var layer: Control = fac.get("item_layer") as Control
    var first: Button = layer.find_child(first_name, true, false) as Button
    if first == null or not first.is_visible_in_tree() or first.text.is_empty():
        _fail("missing native labelled slot without an image: " + first_name)
        return false
    if _card_count(layer) != count or first.get_global_rect().size.y < 80.0:
        _fail("no-image slot count or layout broken for " + target)
        return false
    if first.icon != null:
        _fail("simulated missing atlas unexpectedly loaded an icon")
        return false
    if first.get_theme_stylebox("normal") is not StyleBoxFlat:
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
    # Force the exact resource-unavailable branch of the icon getter.
    Icons._atlas_loaded = true
    Icons._atlas_texture_cache = null
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node = hub.get_node("BaseFacilities")
    if not await _expect(fac, "craft", 7, "PrototypeIcon_H01"):
        return
    if not await _expect(fac, "materials", 12, "MaterialIcon_scrap_low"):
        return
    if not await _expect(fac, "warehouse", 12, "MaterialIcon_scrap_low"):
        return
    Icons._atlas_loaded = false
    Icons._atlas_texture_cache = null
    if Icons.material_icon("scrap_low") == null or Icons.equipment_icon("H01") == null:
        _fail("icon lookup failed after recovering normal atlas loading")
        return
    print("SERA_V527_ANDROID_ICON_RESILIENCE_RUNTIME_PASS: raw WebP load; 7+12+12 text/frame slots without imports")
    quit(0)
