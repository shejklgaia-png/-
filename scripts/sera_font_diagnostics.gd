extends RefCounted
## On-demand LAB font diagnostics. No font assets, file writes or polling.
## Note: SystemFont resolves to the default theme font on Android (Godot 4.7).
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const JP_TEXT: String = "装備 精製 倉庫 日本語 漢字"
const LATIN_TEXT: String = "EQUIPMENT Aa 0123456789"

static func roles() -> Array[Dictionary]:
    return [
        {"id": "JP BODY", "font": LaboSkin.ui_font()},
        {"id": "JP TITLE", "font": LaboSkin.title_font()},
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
    lines.append("SERA FONT DIAG v545")
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
    lines.append("Note: candidate paths do NOT prove actual rendered face.")
    lines.append("Note: has_char does NOT prove visible pixels.")
    lines.append("---")
    for entry: Dictionary in roles():
        var font: Font = entry["font"] as Font
        var name: String = str(entry["id"])
        var base: SystemFont = _base_system(font)
        lines.append(name + " | " + font.get_class())
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
    lines.append("If all faces look identical on Android, SystemFont may")
    lines.append("be using the default theme font. Inspect on-device samples.")
    return "\n".join(lines)
