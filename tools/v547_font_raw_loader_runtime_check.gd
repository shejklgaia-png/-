extends SceneTree
## Direct TTF loading must work without a populated .godot import cache.
const LaboFontSkin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V547_FONT_RAW_LOADER_FAIL: " + message)
    quit(1)
func _run() -> void:
    var cases: Array = [
        [LaboFontSkin.JP_FONT_PATH, 0x65E5, "UDEV"],
        [LaboFontSkin.NAV_FONT_PATH, 0x41, "Moralerspace"],
        [LaboFontSkin.DATA_FONT_PATH, 0x41, "Moralerspace"],
    ]
    var server: TextServer = TextServerManager.get_primary_interface()
    for entry: Array in cases:
        var path: String = str(entry[0])
        var glyph: int = int(entry[1])
        if not FileAccess.file_exists(path):
            _fail("missing raw font source " + path)
            return
        var font: FontFile = LaboFontSkin._font_from_raw(path, glyph)
        if font == null or font.get_data().size() < 100 or (
                not font.has_char(glyph)) or font.get_rids().is_empty():
            _fail("raw FontFile.data cannot parse " + path)
            return
        var actual_name: String = server.font_get_name(font.get_rids()[0])
        if not actual_name.to_lower().contains(str(entry[2]).to_lower()):
            _fail("raw font RID mismatch for " + path + ": " + actual_name)
            return
    var jp: FontVariation = LaboFontSkin.ui_font()
    var title: FontVariation = LaboFontSkin.title_font()
    var nav: FontFile = LaboFontSkin.display_font()
    var mono: FontFile = LaboFontSkin.data_font()
    var control: FontVariation = LaboFontSkin.control_font()
    var stats: FontVariation = LaboFontSkin.stats_font()
    if jp.base_font == null or not jp.has_char(0x65E5) or (
            not jp.has_char(0x6F22)) or (
            title.base_font == jp.base_font) or (
            not nav.has_char(0x41)) or (
            not mono.has_char(0x41)):
        _fail("UI font families did not bind to raw assets")
        return
    # UDEV and Moralerspace use four cached, unmodified bundled TTF faces.
    for path: String in [LaboFontSkin.JP_UI_FONT_PATH,
            LaboFontSkin.JP_TITLE_FONT_PATH,
            LaboFontSkin.JP_CONTROL_FONT_PATH,
            LaboFontSkin.JP_STATS_FONT_PATH,
            LaboFontSkin.NAV_FONT_PATH, LaboFontSkin.DATA_FONT_PATH]:
        var route: String = LaboFontSkin.font_load_status(path)
        if not route.begins_with("RAW_BYTES"):
            _fail("unimported font route did not use raw bytes: " + route)
            return
    var reportScript = load("res://scripts/sera_font_diagnostics.gd")
    var report: String = reportScript.report()
    if report.count("JAPANESE FONT: PASS") != 5 or (
            report.count("embedded: ") != 7) or (
            report.count("load route: RAW_BYTES") != 7):
        _fail("diagnostic does not expose all seven embedded font records")
        return
    print("SERA_V547_FONT_RAW_LOADER_RUNTIME_PASS")
    quit(0)
