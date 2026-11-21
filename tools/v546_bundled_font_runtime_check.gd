extends SceneTree
## SERA v546: test actual imported WOFF2 glyphs and font RID identities.
const LaboFontSkin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V546_BUNDLED_FONT_FAIL: " + why)
    quit(1)
func _run() -> void:
    var jp: FontVariation = LaboFontSkin.ui_font()
    var bold: FontVariation = LaboFontSkin.title_font()
    var control: FontVariation = LaboFontSkin.control_font()
    var stats: FontVariation = LaboFontSkin.stats_font()
    var latin: FontFile = LaboFontSkin.display_font()
    var mono: FontFile = LaboFontSkin.data_font()
    var jpfile: FontFile = jp.base_font as FontFile
    if jpfile == null or not jpfile is FontFile:
        _fail("Japanese font is not a real bundled FontFile")
        return
    if jpfile == latin or jpfile == mono or latin == mono:
        _fail("three font families must be distinct and bundled")
        return
    for letter in [0x0041, 0x65E5, 0x6F22, 0x30AB, 0x3042, 0x88C5, 0x5099]:
        if not jpfile.has_char(letter):
            _fail("Japanese glyph missing: U+" + ("%04X" % letter))
            return
    if not latin.has_char(0x0041) or not mono.has_char(0x0041):
        _fail("technical font has no latin glyphs")
        return
    var ts: TextServer = TextServerManager.get_primary_interface()
    var tag: int = ts.name_to_tag("wght")
    if int(bold.variation_opentype.get(tag, 0)) != 850 or (
            int(stats.variation_opentype.get(tag, 0)) != 550):
        _fail("bundled JP weight axes not applied")
        return
    # Approved cyber typography: Noto's variable face is intentionally
    # shared by headline and stats, but their weight/spacing remain distinct.
    if bold.base_font == jpfile or control.base_font == jpfile or (
            stats.base_font == jpfile) or (
            bold.base_font != stats.base_font):
        _fail("JP headline and stats must share cached Noto while body stays IBM")
        return
    if jpfile.get_rids().is_empty() or latin.get_rids().is_empty() or (
            mono.get_rids().is_empty()):
        _fail("bundled fonts could not create actual TextServer RID")
        return
    var name: String = ts.font_get_name(jpfile.get_rids()[0])
    if not name.to_lower().contains("plex"):
        _fail("TextServer loaded unexpected Japanese font: " + name)
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var header: Label = fac.get("modal_title") as Label
    var tab: Button = (fac.get("section_tabs") as Control).get_node("TabCraft") as Button
    if header.get_theme_font("font") != bold or (
            tab.get_theme_font("font") != LaboFontSkin.tracked_display_font()):
        _fail("LAB controls are not wired to the shipped font resources")
        return
    print("SERA_V546_BUNDLED_FONT_RUNTIME_PASS: " + name)
    quit(0)
