extends SceneTree
## Full reroll->render->copy contract. No mutations of saved equipment or buildings.
const Layout = preload("res://scripts/sera_base_layout_preview.gd")
const Props = preload("res://scripts/sera_base_clutter.gd")
const Deck = preload("res://scripts/sera_base_deck_layout.gd")
const Fac = preload("res://scripts/base_facility_system.gd")
const KEYS = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL",
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_LAYOUT_SHUFFLE_FAIL: " + message)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/base_exploration.tscn")
    if packed == null:
        _fail("no BASE scene")
        return
    var hub: Node3D = packed.instantiate() as Node3D
    root.add_child(hub)
    for i in range(5):
        await process_frame
    var ui: Control = hub.get_node_or_null("BaseHUDLayer/BaseHUD") as Control
    if ui == null:
        _fail("no BASE HUD")
        return
    var shuffle: Button = ui.get_node_or_null("LayoutTools/LayoutShuffleButton") as Button
    var copy: Button = ui.get_node_or_null("LayoutTools/LayoutCopyButton") as Button
    if shuffle == null or copy == null:
        _fail("layout buttons unavailable on BASE screen")
        return
    var initial_text: String = hub.call("_layout_export_text")
    var initial: Dictionary = JSON.parse_string(initial_text)
    if initial.is_empty() or initial.get("format", "") != Layout.FORMAT:
        _fail("the default BASE layout does not export full JSON")
        return
    var before_facility: Vector3 = (hub.get_node("BaseFacilities/LABO") as Node3D).position
    var rng := RandomNumberGenerator.new()
    rng.seed = 481629
    var selected: Dictionary = Layout.generate(
        Vector3(-13.44, 0.0, -19.91),
        Fac.FACILITY_SPECS, rng)
    if selected.is_empty():
        _fail("no valid random layout found")
        return
    for key in KEYS:
        var props: Array = selected["sites"][key]
        if props.size() != Props.default_props_for(key).size():
            _fail(key + " dropped any authored part")
            return
        var slab: Rect2 = Layout.site_slab(
            key, Vector3(-13.44, 0.0, -19.91), Fac.FACILITY_SPECS)
        var occupied: Array[Rect2] = []
        for prop in props:
            var rect: Rect2 = Layout.prop_envelope(prop)
            if not slab.grow(-0.15).encloses(rect):
                _fail(key + " exceeds its reserved floor plate")
                return
            if rect.intersects(Props._clear_zone(key)):
                _fail(key + " covers the entrance")
                return
            for other in occupied:
                if rect.intersects(other):
                    _fail(key + " prop cluster collision")
                    return
            occupied.append(rect)
    if selected["scrap"].size() != 16:
        _fail("lost a salvage pile")
        return
    # Test real UI handler and geometry rebuild after first paint.
    hub.call("_apply_layout_preview", selected)
    var after_text: String = hub.call("_layout_export_text")
    var after: Dictionary = JSON.parse_string(after_text)
    if after.is_empty() or after_text == initial_text:
        _fail("reroll failed to change the copied coordinates")
        return
    if (hub.get_node("BaseFacilities/LABO") as Node3D).position != before_facility:
        _fail("reroll moved a facility")
        return
    for site in after["sites"]:
        if (site["items"] as Array).size() != Props.default_props_for(str(site["site"])).size():
            _fail("missing or extra item in text export")
            return
        for item in site["items"]:
            for field in ["index", "kind", "x", "z", "scale", "yaw_deg", "stack", "pattern", "accent"]:
                if not item.has(field):
                    _fail("cannot reproduce model, field absent: " + field)
                    return
    for scrap in after["scrap"]:
        if not scrap.has("stack") or not scrap.has("pattern"):
            _fail("copy format dropped selected scrap stack layout")
            return
        if int(scrap["stack"]) < 1 or int(scrap["stack"]) > 8:
            _fail("scrap amount outside model capability")
            return
    for i in range(16):
        var scrap_node: Node3D = hub.get_node_or_null("ScrapPile_%02d" % i)
        if scrap_node == null:
            _fail("salvage geometry/node missing after reroll")
            return
    var labs: Node3D = hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel")
    if labs == null or (labs.get_meta("clutter_props", []) as Array).size() < 8:
        _fail("real LABO mesh not rebuilt with sampled clutter")
        return
    Props.clear_preview()
    print("SERA_BASE_LAYOUT_SHUFFLE_RUNTIME_PASS")
    quit(0)
