extends RefCounted
## Exact cropped 2026-11-20 user-approved matte artwork (not procedural fallback).
## Single WebP sprite atlas: 4 columns x 5 rows, each image cell 72px square.
## Rows 0-2: 12 material icons (family -> low,mid,high).
## Rows 3-4: H01,T01,A01,L01 / B01,WR01,WL01 / final empty cell.
const ATLAS: Texture2D = preload("res://assets/ui/sera_matte_icon_atlas.webp")
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
    if index < 0 or index > 18 or ATLAS == null:
        return null
    var icon := AtlasTexture.new()
    icon.atlas = ATLAS
    icon.region = Rect2(
        float(index % COLUMNS) * CELL, float(index / COLUMNS) * CELL,
        CELL, CELL)
    icon.filter_clip = true
    return icon

static func material_icon(material_id: String) -> Texture2D:
    if not MATERIAL_INDICES.has(material_id):
        return null
    return _frame(int(MATERIAL_INDICES[material_id]))

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
