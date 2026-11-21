extends SceneTree
## v548: validate every shipped face and typography slot with real Godot 4.7.
const TypeSkin = preload("res://scripts/sera_labo_round_skin.gd")
const TypeDiag = preload("res://scripts/sera_font_diagnostics.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_V548_LAB_FONT_MIX_FAIL: " + reason)
    quit(1)
func _family(face: FontFile) -> String:
    var server: TextServer = TextServerManager.get_primary_interface()
    var rids: Array[RID] = face.get_rids()
    return server.font_get_name(rids[0]).to_lower().replace(" ", "") if not rids.is_empty() else ""
func _run() -> void:
    var pairs: Array = [
        [TypeSkin.JP_TITLE_FONT_PATH, 0x88C5, "udev"],
        [TypeSkin.JP_STATS_FONT_PATH, 0x65E5, "moralerspace"],
        [TypeSkin.JP_UI_FONT_PATH, 0x88C5, "udev"],
        [TypeSkin.JP_CONTROL_FONT_PATH, 0x88C5, "udev"],
    ]
    for row: Array in pairs:
        var path: String = str(row[0])
        var face: FontFile = TypeSkin._font_from_raw(path, int(row[1]))
        if face == null:
            _fail("could not parse bundled TTF: " + path)
            return
        for cp: int in [0x0041,0x88C5,0x5099,0x6F22,0x30AB]:
            if not face.has_char(cp):
                _fail("missing JP glyph " + str(cp) + " from " + path)
                return
        var found: String = _family(face)
        if not found.contains(str(row[2])):
            _fail("unexpected family " + found + " from " + path)
            return
    var headline: FontVariation = TypeSkin.title_font()
    var itemname: FontVariation = TypeSkin.equipment_font()
    var body: FontVariation = TypeSkin.ui_font()
    var control: FontVariation = TypeSkin.control_font()
    var stat: FontVariation = TypeSkin.stats_font()
    if headline.base_font == null or (
            itemname.base_font != headline.base_font) or (
            headline.base_font == body.base_font) or (
            body.base_font == control.base_font) or (
            stat.base_font == headline.base_font) or (
            stat.base_font == body.base_font):
        _fail("role faces are not separated as designed")
        return
    if headline.base_font != control.base_font or (
            stat.base_font != TypeSkin.data_font() or
            stat.base_font == TypeSkin.display_font()):
        _fail("shared UDEV Bold and Moralerspace Regular face mapping incorrect")
        return
    for path: String in [TypeSkin.JP_TITLE_FONT_PATH,
            TypeSkin.JP_STATS_FONT_PATH,
            TypeSkin.JP_UI_FONT_PATH,
            TypeSkin.JP_CONTROL_FONT_PATH]:
        if not TypeSkin.font_load_status(path).begins_with("RAW_BYTES"):
            _fail("font not loaded via Android-safe raw path: " + path)
            return
    var report: String = TypeDiag.report()
    if report.count("JAPANESE FONT: PASS") != 5 or (
            report.count("embedded: ") != 7) or (
            report.count("load route: RAW_BYTES") != 7):
        _fail("font diagnostic missing new mixed-face rows")
        return
    var base_resource: PackedScene = load("res://scenes/base_exploration.tscn") as PackedScene
    if base_resource == null:
        _fail("BASE scene cannot be loaded for font check")
        return
    var base: Node3D = base_resource.instantiate() as Node3D
    if base == null or base.get_script() == null:
        _fail("BASE script does not compile; font test cannot continue")
        return
    root.add_child(base)
    await process_frame
    await process_frame
    var fac: Node3D = base.get_node_or_null("BaseFacilities") as Node3D
    if fac == null:
        _fail("BASE facilities missing; avoid hanging on null UI")
        return
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var heading: Label = fac.get("modal_title") as Label
    if heading.get_theme_font("font") != headline:
        _fail("LAB title is not UDEV Gothic Bold")
        return
    var content: Control = fac.get("item_layer") as Control
    var craft: Button = content.find_child("PrototypeIcon_H01",true,false) as Button
    if craft == null or (
            (craft.find_child("ItemTitle",true,false) as Label).get_theme_font("font") != itemname) or (
            (craft.find_child("ItemInfo",true,false) as Label).get_theme_font("font") != stat):
        _fail("craft item is not UDEV item + Moralerspace stats")
        return
    var actions: Control = fac.get("modal_actions") as Control
    var part: Button = actions.find_child("CraftSlot_head",true,false) as Button
    if part == null or part.get_theme_font("font") != control:
        _fail("craft categories are not UDEV Gothic Bold")
        return
    fac.call("_switch_section","materials")
    await process_frame
    await process_frame
    content = fac.get("item_layer") as Control
    var material: Button = content.find_child("MaterialIcon_scrap_low",true,false) as Button
    if material == null or (
            (material.find_child("ItemTitle",true,false) as Label).get_theme_font("font") != body) or (
            (material.find_child("ItemInfo",true,false) as Label).get_theme_font("font") != stat):
        _fail("refinery item font assignments regressed")
        return
    fac.call("_switch_section","warehouse")
    await process_frame
    await process_frame
    var wh: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment",true,false) as ScrollContainer
    if wh == null or int(wh.get("virtual_slots")) != 999 or (
            (wh.get("pool") as Array).size() > 32):
        _fail("999-slot virtualization regressed")
        return
    var pool: Array = wh.get("pool")
    if pool.is_empty() or (
            (pool[0] as Button).get_node("ItemTitle").get_theme_font("font") != itemname) or (
            (pool[0] as Button).get_node("ItemEffects").get_theme_font("font") != stat):
        _fail("warehouse typefaces are not applied to reusable cards")
        return
    # The actively drawn battle HP/EN/BOSS text uses the same cached sharp
    # role faces. No generic Godot fallback is permitted for visible labels.
    var battle_ui: Control = load(
        "res://scripts/sera_clean_training_hud.gd").new() as Control
    root.add_child(battle_ui)
    if battle_ui.call("_font_for_text", "BOSS") != TypeSkin.tracked_display_font() or (
            battle_ui.call("_font_for_text", "480 / 800") != TypeSkin.tracked_data_font()) or (
            battle_ui.call("_font_for_text", "頭部") != TypeSkin.equipment_font()):
        _fail("combat bar text does not use technical Latin/JP bundled faces")
        return
    print("SERA_V548_LAB_FONT_MIX_RUNTIME_PASS")
    quit(0)
