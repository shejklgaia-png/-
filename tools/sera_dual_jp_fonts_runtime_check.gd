extends SceneTree
## Both installed OFL typefaces must really render Japanese glyphs with the
## same cached sources used by the game, not an Android SystemFont fallback.
const TypeSkin = preload("res://scripts/sera_labo_round_skin.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_DUAL_JP_FONT_FAIL: " + why)
    quit(1)

func _run() -> void:
    var faces: Array = [
        [TypeSkin.ui_font(), "UDEV UI", "装備 精製 倉庫"],
        [TypeSkin.title_font(), "UDEV title", "以下の装備を作成します"],
        [TypeSkin.control_font(), "UDEV control", "キャンセル 作成"],
        [TypeSkin.equipment_font(), "UDEV equipment", "スカウトバイザー"],
        [TypeSkin.stats_font(), "Moralerspace stats", "基本防御力 120"],
        [TypeSkin.display_font(), "Moralerspace display", "NEXUS / LAB"],
        [TypeSkin.data_font(), "Moralerspace data", "H01-0001 99/999"],
    ]
    var server: TextServer = TextServerManager.get_primary_interface()
    for item: Array in faces:
        var font: Font = item[0] as Font
        if font == null:
            _fail("missing role font " + str(item[1]))
            return
        var base: FontFile = null
        if font is FontVariation:
            base = (font as FontVariation).base_font as FontFile
        elif font is FontFile:
            base = font as FontFile
        if base == null or base.allow_system_fallback:
            _fail("role uses fallback or missing TTF: " + str(item[1]))
            return
        var source_rids: Array[RID] = base.get_rids()
        if source_rids.is_empty():
            _fail("TextServer failed to load " + str(item[1]))
            return
        var family_name: String = server.font_get_name(source_rids[0]).to_lower()
        var expected: String = ("moralerspace" if str(item[1]).begins_with(
            "Moralerspace") else "udev")
        if not family_name.contains(expected):
            _fail("unexpected family for " + str(item[1]) + ": " + family_name)
            return
        var sample: String = str(item[2])
        for i in range(sample.length()):
            if not font.has_char(sample.unicode_at(i)):
                _fail("missing glyph at " + str(i) + " for " + str(item[1]))
                return
    if TypeSkin.ui_font().base_font != TypeSkin._jp_face() or (
            TypeSkin.title_font().base_font == TypeSkin.ui_font().base_font) or (
            TypeSkin.title_font().base_font != TypeSkin.control_font().base_font) or (
            TypeSkin.stats_font().base_font != TypeSkin.data_font()) or (
            TypeSkin.display_font() == TypeSkin.data_font()):
        _fail("font source sharing / four-face cache regression")
        return
    for path: String in [
            TypeSkin.JP_FONT_PATH, TypeSkin.JP_TITLE_FONT_PATH,
            TypeSkin.JP_STATS_FONT_PATH, TypeSkin.NAV_FONT_PATH]:
        if not TypeSkin.font_load_status(path).begins_with("RAW_BYTES"):
            _fail("official font not Android-safe RAW_BYTES: " + path)
            return
    var theme: Theme = TypeSkin.common_theme()
    if theme.default_font != TypeSkin.ui_font() or (
            theme.get_font("font", "Button") != TypeSkin.ui_font()):
        _fail("base UI theme did not change to UDEV")
        return
    print("SERA_DUAL_JP_FONTS_RUNTIME_PASS")
    quit(0)
