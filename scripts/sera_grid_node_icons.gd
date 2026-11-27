extends RefCounted
## Original geometric SVG symbols shared by palette and board; no external assets.
const PATHS = {
    "S": "M15 38L25 19L39 23L48 15L55 37L42 50L23 49Z M25 19L32 36L55 37 M32 36L23 49",
    "A": "M14 23L32 14L50 23L32 32Z M14 33L32 42L50 33 M14 43L32 52L50 43",
    "E": "M20 20H44V44H20Z M26 26H38V38H26Z M12 25H20 M12 32H20 M12 39H20 M44 25H52 M44 32H52 M44 39H52 M25 12V20 M32 12V20 M39 12V20 M25 44V52 M32 44V52 M39 44V52",
    "O": "M32 13L48 24V42L32 51L16 42V24Z M32 13V51 M16 24L48 42 M48 24L16 42",
    "GEN": "M15 34A17 17 0 1 1 49 34A17 17 0 0 1 15 34Z M34 17L24 35H35L30 50L43 30H31Z",
    "BAT": "M16 22H48V48H16Z M27 16H37V22 M22 30H42 M22 39H36",
    "WIRE": "M32 9V55 M9 32H55 M25 25H39V39H25Z",
    "AMP": "M14 44L32 15L50 44Z M32 25V38 M26 31H38 M14 51H50",
    "YIELD": "M14 32H25V50H14Z M28 24H39V50H28Z M42 14H53V50H42Z M13 15L25 15L25 22",
    "SAVE": "M32 12L17 35H30L24 52L48 28H34L40 12 M13 52H19",
    "ATK": "M16 48L42 16L51 13L48 23L22 49Z M14 36L28 50 M12 52L18 46",
    "BREAK": "M13 17H51V49H13Z M32 17L25 29L39 34L28 49 M13 33H23 M41 33H51",
    "HP": "M25 13H39V25H51V39H39V51H25V39H13V25H25Z",
    "DEF": "M32 12L50 20V35L45 45L32 53L19 45L14 35V20Z M23 32L29 38L41 25",
    "SPD": "M12 18L29 32L12 46 M27 18L44 32L27 46 M42 18L55 32L42 46",
    "EN": "M18 23A17 17 0 0 1 48 23L52 15 M48 23L39 22 M46 41A17 17 0 0 1 16 41L12 49 M16 41L25 42 M35 22L26 34H34L29 43L40 30H32"
}
static var _cache: Dictionary = {}

static func texture(code: String) -> Texture2D:
    if _cache.has(code):
        return _cache[code] as Texture2D
    var key := code
    var rank := 0
    if code.length() == 2 and code.right(1).is_valid_int():
        rank = int(code.right(1))
        key = code.left(1)
    if not PATHS.has(key):
        return null
    var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 64 64"><rect x="2" y="2" width="60" height="60" rx="8" fill="#142633" stroke="#84aebd" stroke-width="1.5"/>'
    svg += '<path d="%s" fill="none" stroke="#e0f5ff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>' % PATHS[key]
    for i in range(rank):
        svg += '<rect x="%d" y="55" width="8" height="4" rx="1" fill="#94e2e6"/>' % (18 + i * 14)
    svg += '</svg>'
    var img := Image.new()
    if img.load_svg_from_string(svg) != OK:
        return null
    var tex := ImageTexture.create_from_image(img)
    _cache[code] = tex
    return tex
