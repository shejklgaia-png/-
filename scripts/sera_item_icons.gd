extends RefCounted
## Two shared WebP sprite atlases (no procedural icon generation):
## - Pixel materials: 3 columns x 4 rows, 12 alpha-backed sprites, 72px per cell.
## - Legacy matte equipment: 4 columns x 5 rows, 7 equipment slots unchanged.
## Material IDs and blueprint IDs are stable across visual changes.
const ATLAS_PATH: String = "res://assets/ui/sera_matte_icon_atlas.webp"
# The original atlas retains all 7 equipment portraits unchanged.
# 12 material sprites live in a separate transparent 3-column x 4-row sheet.
const MATERIAL_ATLAS_PATH: String = "res://assets/ui/sera_pixel_material_atlas.webp"
const MATERIAL_COLUMNS: int = 3
const MATERIAL_ROWS: int = 4
static var _material_atlas_loaded: bool = false
static var _material_texture_cache: Texture2D = null
static var _material_method: String = "not loaded"
# In Android Godot Editor a Git-synced source WebP may exist while the editor's
# transient .godot/imported cache does not. Do not preload the imported texture:
# it couples script parsing and every card to successful editor import.
static var _atlas_loaded: bool = false
static var _atlas_texture_cache: Texture2D = null
static var _atlas_method: String = "not loaded"

static func _decode_webp_source(path: String, expected_width: int = 288,
        expected_height: int = 360) -> Texture2D:
    if not FileAccess.file_exists(path):
        return null
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return null
    var source_image := Image.new()
    if source_image.load_webp_from_buffer(bytes) != OK:
        return null
    if source_image.get_width() != expected_width or source_image.get_height() != expected_height:
        return null
    return ImageTexture.create_from_image(source_image)

static func _atlas_texture() -> Texture2D:
    if _atlas_loaded:
        return _atlas_texture_cache
    _atlas_loaded = true
    # Prefer the normal imported texture in APKs. Android editor can fall back
    # to decoding the tracked WebP bytes without using its import cache.
    if ResourceLoader.exists(ATLAS_PATH):
        var source: Resource = ResourceLoader.load(ATLAS_PATH, "Texture2D")
        if source is Texture2D:
            _atlas_texture_cache = source as Texture2D
            _atlas_method = "imported"
    if _atlas_texture_cache == null:
        _atlas_texture_cache = _decode_webp_source(ATLAS_PATH)
        _atlas_method = "source-webp" if _atlas_texture_cache != null else "unavailable"
    return _atlas_texture_cache

static func _material_atlas_texture() -> Texture2D:
    if _material_atlas_loaded:
        return _material_texture_cache
    _material_atlas_loaded = true
    # Keep Android's imported-resource fast path and also support editor-side
    # GitSync immediately after pulling new files (import cache may be stale).
    if ResourceLoader.exists(MATERIAL_ATLAS_PATH):
        var loaded: Resource = ResourceLoader.load(MATERIAL_ATLAS_PATH, "Texture2D")
        if loaded is Texture2D and loaded.get_width() == 216 and loaded.get_height() == 288:
            _material_texture_cache = loaded as Texture2D
            _material_method = "imported"
    if _material_texture_cache == null:
        _material_texture_cache = _decode_webp_source(MATERIAL_ATLAS_PATH, 216, 288)
        _material_method = "source-webp" if _material_texture_cache != null else "unavailable"
    return _material_texture_cache

static func atlas_status() -> String:
    _atlas_texture()
    _material_atlas_texture()
    return "equipment=%s (%s), materials=%s (%s)" % [
        _atlas_method, "YES" if FileAccess.file_exists(ATLAS_PATH) else "NO",
        _material_method, "YES" if FileAccess.file_exists(MATERIAL_ATLAS_PATH) else "NO"]

const CELL: int = 72
const COLUMNS: int = 4
const MATERIAL_INDICES = {
    "scrap_low": 0, "scrap_mid": 1, "scrap_high": 2,
    "alloy_low": 3, "alloy_mid": 4, "alloy_high": 5,
    "electronics_low": 6, "electronics_mid": 7, "electronics_high": 8,
    "organic_low": 9, "organic_mid": 10, "organic_high": 11
}
const EQUIPMENT_INDICES = {
    "H01": 12, "T01": 13, "A01": 14, "L01": 15,
    "B01": 16, "WR01": 17, "WL01": 18
}

static func _frame(index: int) -> Texture2D:
    if index < 0 or index > 18:
        return null
    var source: Texture2D = _atlas_texture()
    if source == null:
        return null
    var icon := AtlasTexture.new()
    icon.atlas = source
    icon.region = Rect2(
        float(index % COLUMNS) * CELL, float(index / COLUMNS) * CELL,
        CELL, CELL)
    icon.filter_clip = true
    return icon

static func _material_frame(index: int) -> Texture2D:
    if index < 0 or index >= MATERIAL_COLUMNS * MATERIAL_ROWS:
        return null
    var source: Texture2D = _material_atlas_texture()
    if source == null:
        return null
    var icon := AtlasTexture.new()
    icon.atlas = source
    icon.region = Rect2(
        float(index % MATERIAL_COLUMNS) * CELL,
        float(index / MATERIAL_COLUMNS) * CELL,
        CELL, CELL)
    icon.filter_clip = true
    return icon

static func material_icon(material_id: String) -> Texture2D:
    if not MATERIAL_INDICES.has(material_id):
        return null
    return _material_frame(int(MATERIAL_INDICES[material_id]))

static func equipment_icon(blueprint_id: String) -> Texture2D:
    if not EQUIPMENT_INDICES.has(blueprint_id):
        return null
    return _frame(int(EQUIPMENT_INDICES[blueprint_id]))

static func icon_for(item_id: String) -> Texture2D:
    if MATERIAL_INDICES.has(item_id):
        return material_icon(item_id)
    return equipment_icon(item_id)

static func material_has_icon(material_id: String) -> bool:
    return MATERIAL_INDICES.has(material_id)

static func equipment_has_icon(blueprint_id: String) -> bool:
    return EQUIPMENT_INDICES.has(blueprint_id)
