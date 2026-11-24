extends RefCounted
## Materials use a 3x4 transparent WebP atlas. Equipment uses one 512px
## Godot-native photographed PNGs: full 512px, warehouse 82px and craft
## catalog 96px, each with independent screen-native outline strokes.
## Composition is cached once per blueprint+display profile.
const ATLAS_PATH: String = "res://assets/ui/sera_matte_icon_atlas.webp" # Retired; diagnostics only.
const NATIVE_EQUIPMENT_DIRECTORY: String = "res://assets/ui/sera_equipment_icons"
# Approved per-blueprint model screenshots; Base64 holds original PNG bytes,
# requiring no binary asset upload through GitHub text-content integrations.
const CustomEquipmentIcons = preload("res://assets/ui/sera_custom_equipment_icons.gd")
const IconBackground = preload("res://scripts/sera_icon_background.gd")
static var _presented_equipment_cache: Dictionary = {}
static var _custom_equipment_icon_cache: Dictionary = {}
static var _small_atlases_ready: Dictionary = {}
const SMALL_ATLAS_PAD: int = 4
const SMALL_ATLAS_COLUMNS: int = 8

# The old matte equipment atlas remains an archival asset, NOT a blueprint.
# 12 material sprites live in a separate transparent 3-column x 4-row sheet.
const MATERIAL_ATLAS_PATH: String = "res://assets/ui/sera_pixel_material_atlas.webp"
const MATERIAL_COLUMNS: int = 3
const MATERIAL_ROWS: int = 4
static var _material_atlas_loaded: bool = false
static var _material_texture_cache: Texture2D = null
# GPU atlas subregions can sample adjacent rows in the Android renderer.
# Decode/crop once and cache twelve genuinely independent, square textures.
static var _material_frame_cache: Dictionary = {}
static var _material_source_image: Image = null
static var _material_source_attempted: bool = false
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
    _material_source()
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

static func _material_source() -> Image:
    if _material_source_attempted:
        return _material_source_image
    _material_source_attempted = true
    # The source file preserves the precise 72px tile pixels even before
    # Godot's Android editor builds its transient imported-resource cache.
    if FileAccess.file_exists(MATERIAL_ATLAS_PATH):
        var bytes: PackedByteArray = FileAccess.get_file_as_bytes(MATERIAL_ATLAS_PATH)
        if not bytes.is_empty():
            var decoded := Image.new()
            if decoded.load_webp_from_buffer(bytes) == OK and (
                    decoded.get_width() == 216 and decoded.get_height() == 288):
                _material_source_image = decoded
                _material_method = "source-webp-independent-tiles"
                return _material_source_image
    # APKs may ship the imported texture without the original WebP bytes.
    var imported: Texture2D = _material_atlas_texture()
    if imported != null:
        var decoded_import: Image = imported.get_image()
        if decoded_import != null:
            if decoded_import.is_compressed() and decoded_import.decompress() != OK:
                return null
            if decoded_import.get_width() == 216 and decoded_import.get_height() == 288:
                _material_source_image = decoded_import
                _material_method = "imported-independent-tiles"
    return _material_source_image

static func _material_frame(index: int) -> Texture2D:
    if index < 0 or index >= MATERIAL_COLUMNS * MATERIAL_ROWS:
        return null
    if _material_frame_cache.has(index):
        return _material_frame_cache[index] as Texture2D
    var source: Image = _material_source()
    if source == null:
        return null
    # An actual 72x72 pixel crop, NOT a UV view of the 3x4 source atlas.
    # Adjacent sprite pixels can never appear, even with hardware filtering.
    var tile: Image = source.get_region(Rect2i(
        (index % MATERIAL_COLUMNS) * CELL,
        int(index / MATERIAL_COLUMNS) * CELL,
        CELL, CELL))
    if tile == null or tile.get_width() != CELL or tile.get_height() != CELL:
        return null
    var icon: Texture2D = ImageTexture.create_from_image(tile)
    _material_frame_cache[index] = icon
    return icon

static func material_icon(material_id: String) -> Texture2D:
    if not MATERIAL_INDICES.has(material_id):
        return null
    return _material_frame(int(MATERIAL_INDICES[material_id]))

# Keep the original alpha-backed 72px textures intact, but cache small
# nearest-neighbor copies for short native Button rows. This is necessary
# because Godot 4.7's Button has no "icon_max_width" property.
static var _material_sized_cache: Dictionary = {}

static func material_icon_sized(material_id: String, size: int) -> Texture2D:
    if size < 1 or size > CELL:
        return null
    var key: String = material_id + ":" + str(size)
    if _material_sized_cache.has(key):
        return _material_sized_cache[key] as Texture2D
    var source: Texture2D = material_icon(material_id)
    if source == null:
        return null
    var pixels: Image = source.get_image()
    if pixels == null:
        return source
    if pixels.get_width() != size or pixels.get_height() != size:
        pixels.resize(size, size, Image.INTERPOLATE_NEAREST)
    var tile: Texture2D = ImageTexture.create_from_image(pixels)
    _material_sized_cache[key] = tile
    return tile

static func _native_equipment_icon(blueprint_id: String,
        profile: String = "full") -> Texture2D:
    # PNGs are generated off-device at each UI's actual visual resolution.
    # Preserve the 512px master for large panels / other NEXUS consumers.
    var side: int = 512
    var filename: String = blueprint_id + ".png"
    match profile:
        "warehouse":
            side = 82
            filename = "warehouse/" + filename
        "craft":
            side = 96
            filename = "craft/" + filename
    var path: String = NATIVE_EQUIPMENT_DIRECTORY + "/" + filename
    var bitmap: Image = null
    # Decode source PNG first on Android/editor. Avoid false missing .ctex
    # errors from stale import caches; packaged builds can use imported texture.
    if FileAccess.file_exists(path):
        var png: PackedByteArray = FileAccess.get_file_as_bytes(path)
        var decoded := Image.new()
        if not png.is_empty() and decoded.load_png_from_buffer(png) == OK:
            bitmap = decoded
    if bitmap == null and ResourceLoader.exists(path):
        var res: Resource = ResourceLoader.load(path, "Texture2D")
        if res is Texture2D:
            bitmap = (res as Texture2D).get_image()
    if bitmap == null or bitmap.get_width() != side or bitmap.get_height() != side:
        return null
    # Reuse one composited texture per blueprint+profile. Never duplicate
    # 512px images for the 82px/96px LABO card lists.
    return ImageTexture.create_from_image(bitmap)


static func _approved_equipment_icon(blueprint_id: String) -> Texture2D:
    if not CustomEquipmentIcons.ICON_PNG_BASE64.has(blueprint_id):
        return null
    if _custom_equipment_icon_cache.has(blueprint_id):
        return _custom_equipment_icon_cache[blueprint_id] as Texture2D
    var png: PackedByteArray = Marshalls.base64_to_raw(str(
        CustomEquipmentIcons.ICON_PNG_BASE64[blueprint_id]))
    var bitmap := Image.new()
    if png.is_empty() or bitmap.load_png_from_buffer(png) != OK:
        push_warning("SERA equipment icon PNG invalid for " + blueprint_id)
        return null
    if bitmap.get_width() != 512 or bitmap.get_height() != 512:
        push_warning("SERA equipment icon dimension invalid for " + blueprint_id)
        return null
    var texture: Texture2D = ImageTexture.create_from_image(bitmap)
    _custom_equipment_icon_cache[blueprint_id] = texture
    return texture


static func equipment_icon(blueprint_id: String,
        profile: String = "full") -> Texture2D:
    # One 2D blend per model + display profile; no runtime 3D capture.
    # The small source is already photographed by Godot at exactly 82/96px,
    # so the full 512px outline is NEVER shrunk onto tiny cards.
    var selected_profile: String = profile if profile in [
        "full", "warehouse", "craft"] else "full"
    var cache_key: String = blueprint_id + ":" + selected_profile
    if _presented_equipment_cache.has(cache_key):
        return _presented_equipment_cache[cache_key] as Texture2D
    var source: Texture2D = _native_equipment_icon(
        blueprint_id, selected_profile)
    if source == null and selected_profile != "full":
        # Compatibility while clients synchronize the newly captured images.
        source = _native_equipment_icon(blueprint_id)
    if source == null and blueprint_id == "H02":
        source = _approved_equipment_icon(blueprint_id)
    if source == null:
        return null
    var presented: Texture2D = IconBackground.composite(source)
    _presented_equipment_cache[cache_key] = presented
    return presented

static func card_icon_cached(id: String, equipment: bool) -> bool:
    if equipment:
        return _presented_equipment_cache.has(id + ":craft")
    return MATERIAL_INDICES.has(id) and _material_frame_cache.has(int(MATERIAL_INDICES[id]))

static func prewarm_card_icons(ids: Array, budget: Variant, use_atlas: bool) -> void:
    # Turning the optional atlas OFF must restore independent textures on the
    # next BASE visit, even within the same process.
    if not use_atlas and not _small_atlases_ready.is_empty():
        for key in _presented_equipment_cache.keys():
            if _presented_equipment_cache[key] is AtlasTexture:
                _presented_equipment_cache.erase(key)
        _small_atlases_ready.clear()
    # All decoding/compositing takes place under the BASE loading cover.
    for id in MATERIAL_INDICES:
        material_icon(str(id))
        await budget.checkpoint("material icon " + str(id))
    for profile in ["craft", "warehouse"]:
        for id in ids:
            equipment_icon(str(id), profile)
            await budget.checkpoint("equipment icon " + str(id) + " " + profile)
        if use_atlas and not _small_atlases_ready.has(profile):
            _pack_small_atlas(ids, profile)
            await budget.checkpoint("padded UI atlas " + profile)

static func _pack_small_atlas(ids: Array, profile: String) -> void:
    # Previous material atlas had Android bleed: do not replace that
    # independent-tile path. Small equipment portraits have padded slots,
    # filter_clip and exact-size checks; 512px full fallback is never packed.
    var side: int = 96 if profile == "craft" else 82
    var stride: int = side + SMALL_ATLAS_PAD*2
    var tiles: Array[Dictionary] = []
    for id in ids:
        var key: String = str(id) + ":" + profile
        var texture := _presented_equipment_cache.get(key) as Texture2D
        if texture == null or texture is AtlasTexture or texture.get_size() != Vector2(side,side):
            continue
        var pixels := texture.get_image()
        if pixels == null or pixels.is_empty():
            continue
        if pixels.is_compressed() and pixels.decompress() != OK:
            continue
        pixels = pixels.duplicate() as Image
        pixels.convert(Image.FORMAT_RGBA8)
        tiles.append({"key":key, "pixels":pixels})
    if tiles.is_empty():
        return
    var rows: int = ceili(float(tiles.size())/float(SMALL_ATLAS_COLUMNS))
    var atlas := Image.create(SMALL_ATLAS_COLUMNS*stride, rows*stride, false, Image.FORMAT_RGBA8)
    atlas.fill(Color.TRANSPARENT)
    var regions: Dictionary = {}
    for i in range(tiles.size()):
        var origin := Vector2i((i%SMALL_ATLAS_COLUMNS)*stride+SMALL_ATLAS_PAD,
            int(i/SMALL_ATLAS_COLUMNS)*stride+SMALL_ATLAS_PAD)
        var pixels: Image = tiles[i]["pixels"]
        # Extrude actual edge colors into the four-pixel gutters.
        atlas.blit_rect(pixels, Rect2i(Vector2i.ZERO, Vector2i(side,side)), origin)
        for y in range(-SMALL_ATLAS_PAD, side+SMALL_ATLAS_PAD):
            for x in range(-SMALL_ATLAS_PAD, side+SMALL_ATLAS_PAD):
                if x >= 0 and x < side and y >= 0 and y < side:
                    continue
                atlas.set_pixelv(origin+Vector2i(x,y),pixels.get_pixel(clampi(x,0,side-1),clampi(y,0,side-1)))
        regions[tiles[i]["key"]] = Rect2(Vector2(origin),Vector2(side,side))
    var shared := ImageTexture.create_from_image(atlas)
    for key in regions:
        var region := AtlasTexture.new()
        region.atlas = shared
        region.region = regions[key]
        region.filter_clip = true
        _presented_equipment_cache[key] = region
    _small_atlases_ready[profile] = true

static func icon_for(item_id: String) -> Texture2D:
    if MATERIAL_INDICES.has(item_id):
        return material_icon(item_id)
    return equipment_icon(item_id)

static func material_has_icon(material_id: String) -> bool:
    return MATERIAL_INDICES.has(material_id)

static func equipment_has_icon(blueprint_id: String) -> bool:
    var path: String = NATIVE_EQUIPMENT_DIRECTORY + "/" + blueprint_id + ".png"
    # Exported Android packs can retain the imported texture without a
    # raw PNG file; detect both resource and source representations.
    return ResourceLoader.exists(path) or FileAccess.file_exists(path) or (
        blueprint_id == "H02" and CustomEquipmentIcons.ICON_PNG_BASE64.has(blueprint_id))
