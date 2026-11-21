extends RefCounted
## On-demand LAB font diagnostics. Bundled WOFF2 face identity and glyph checks.
## The optional OS candidate remains for troubleshooting older builds.
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const JP_TEXT: String = "装備 精製 倉庫 日本語 漢字"
const LATIN_TEXT: String = "EQUIPMENT Aa 0123456789"

static func roles() -> Array[Dictionary]:
    return [
        {"id": "JP BODY", "font": LaboSkin.ui_font()},
        {"id": "JP TITLE", "font": LaboSkin.title_font()},
        {"id": "JP EQUIPMENT", "font": LaboSkin.equipment_font()},
        {"id": "JP CONTROL", "font": LaboSkin.control_font()},
        {"id": "JP STATS", "font": LaboSkin.stats_font()},
        {"id": "LATIN NAV", "font": LaboSkin.tracked_display_font()},
        {"id": "MONO ID", "font": LaboSkin.tracked_data_font()},
    ]


static func _base_system(font: Font) -> SystemFont:
    if font is SystemFont:
        return font as SystemFont
    if font is FontVariation:
        var root: Font = (font as FontVariation).base_font
        if root is SystemFont:
            return root as SystemFont
    return null


static func _embedded_face(font: Font) -> FontFile:
    if font is FontFile:
        return font as FontFile
    if font is FontVariation and (font as FontVariation).base_font is FontFile:
        return (font as FontVariation).base_font as FontFile
    return null


static func _asset_path(role_id: String) -> String:
    match role_id:
        "JP TITLE", "JP EQUIPMENT":
            return LaboSkin.JP_TITLE_FONT_PATH
        "JP BODY":
            return LaboSkin.JP_UI_FONT_PATH
        "JP CONTROL":
            return LaboSkin.JP_CONTROL_FONT_PATH
        "JP STATS":
            return LaboSkin.JP_STATS_FONT_PATH
        "LATIN NAV":
            return LaboSkin.NAV_FONT_PATH
        _:
            return LaboSkin.DATA_FONT_PATH


static func _check_char(font: Font, codepoint: int) -> String:
    # has_char indicates glyph availability reported by Font; it does not
    # prove that the pixel is drawn correctly. Always inspect sample labels.
    return "Y" if font.has_char(codepoint) else "N"


static func _first_face(font: Font) -> String:
    var names: Array[String] = []
    var server: TextServer = TextServerManager.get_primary_interface()
    if server == null:
        return "text server unavailable"
    for rid: RID in font.get_rids():
        if rid.is_valid():
            var family: String = server.font_get_name(rid)
            if family.is_empty():
                family = "(unnamed)"
            names.append(family)
        if names.size() >= 3:
            break
    return ", ".join(names) if not names.is_empty() else "(no font RID)"


static func _requested_font_name(font: SystemFont) -> String:
    if font.font_names.is_empty():
        return "(default)"
    return str(font.font_names[0])


static func _path_result(name: String, weight: int) -> String:
    var path: String = OS.get_system_font_path(name, weight)
    return path.get_file() if not path.is_empty() else "(no path)"


static func report() -> String:
    var lines: PackedStringArray = []
    lines.append("SERA FONT DIAG v548 / MIXED FONTS")
    lines.append("Godot: " + str(Engine.get_version_info().get("string", "?")))
    lines.append("Platform: " + OS.get_name())
    lines.append("Locale: " + OS.get_locale())
    lines.append("Display: " + DisplayServer.get_name())
    var families: PackedStringArray = OS.get_system_fonts()
    lines.append("System font families: " + str(families.size()))
    var matched: PackedStringArray = []
    for family in families:
        var key: String = family.to_lower()
        if "noto" in key or "roboto" in key or "m plus" in key:
            matched.append(family)
        if matched.size() >= 12:
            break
    lines.append("Named families: " +
        (", ".join(matched) if not matched.is_empty() else "(none listed)"))
    lines.append("Font mode: bundled WOFF2 / RAW_BYTES > IMPORTED_RESOURCE")
    lines.append("Note: has_char does NOT prove visible pixels.")
    lines.append("---")
    for entry: Dictionary in roles():
        var font: Font = entry["font"] as Font
        var name: String = str(entry["id"])
        var base: SystemFont = _base_system(font)
        var embedded: FontFile = _embedded_face(font)
        lines.append(name + " | " + font.get_class())
        var asset: String = _asset_path(name)
        var direct_path: String = ("YES" if FileAccess.file_exists(asset) else "NO")
        var import_path: String = ("YES" if ResourceLoader.exists(asset) else "NO")
        lines.append("  embedded: " + asset.get_file() +
            " / " + ("OK" if embedded != null else "FAILED"))
        lines.append("  available: RAW=" + direct_path + " / IMPORTED=" + import_path)
        lines.append("  load route: " + LaboSkin.font_load_status(asset))
        if embedded != null:
            lines.append("  file glyphs A/JPN/kanji/kana: " +
                _check_char(embedded, 0x41) + "/" +
                _check_char(embedded, 0x65E5) + "/" +
                _check_char(embedded, 0x6F22) + "/" +
                _check_char(embedded, 0x30AB))
            if name.begins_with("JP ") and embedded.has_char(0x65E5):
                lines.append("  JAPANESE FONT: PASS")
            elif name.begins_with("JP "):
                lines.append("  JAPANESE FONT: FAIL")
        if embedded == null:
            lines.append("  FONT BASE: MISSING (default Open Sans may be used)")
            if name.begins_with("JP "):
                lines.append("  JAPANESE FONT: FAIL")
        if base != null:
            var requested: String = _requested_font_name(base)
            lines.append("  requested: " + requested + " / weight " +
                str(base.font_weight) + " / fallback " +
                ("ON" if base.allow_system_fallback else "OFF"))
            lines.append("  OS candidate: " +
                _path_result(requested, base.font_weight))
            var substitutes: PackedStringArray = OS.get_system_font_path_for_text(
                requested, "日本語", "ja", "Jpan", base.font_weight)
            lines.append("  JP candidate count: " + str(substitutes.size()) +
                " / first: " + (
                str(substitutes[0]).get_file() if not substitutes.is_empty()
                else "(no path)"))
        lines.append("  TextServer primary RID: " + _first_face(font))
        lines.append("  glyph A/JPN/kanji/kana: " +
            _check_char(font, 0x41) + "/" +
            _check_char(font, 0x65E5) + "/" +
            _check_char(font, 0x6F22) + "/" +
            _check_char(font, 0x30AB))
    lines.append("---")
    lines.append("Expected JP glyphs: Y/Y/Y/Y for all JP roles.")
    lines.append("Roles: TITLE/EQUIPMENT/STATS=Noto Sans JP; BODY/CONTROL=IBM Plex JP; LATIN=Rajdhani/IBM Plex Mono")
    lines.append("Latin/mono faces may legitimately lack Japanese glyphs.")
    lines.append("Inspect LIVE SAMPLES for actual rendered differences.")
    return "\n".join(lines)
