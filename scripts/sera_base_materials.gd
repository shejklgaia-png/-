extends RefCounted
## Twelve physical basic materials; rarity is an exact crafting requirement,
## never an implicit substitute. All conversions stay within one family.
##
## Conversion rate is a configurable provisional 2:1 upgrade / 1:2 downgrade.
## The two operations are strictly resource-neutral on a round trip. Revising
## costs later changes only these recipe constants, not save IDs.
const FAMILY_IDS = ["scrap", "alloy", "electronics", "organic"]
const TIERS = ["low", "mid", "high"]
const FAMILY_NAMES = {
    "scrap": "スクラップ", "alloy": "合金",
    "electronics": "電子部品", "organic": "有機素材"
}
const GRADE_NAMES = {
    "scrap": {"low": "雑", "mid": "選別", "high": "高純度"},
    "alloy": {"low": "粗製", "mid": "精製", "high": "高強度"},
    "electronics": {"low": "再生", "mid": "汎用", "high": "高精度"},
    "organic": {"low": "低活性", "mid": "安定", "high": "高活性"}
}
const STARTER_SCRAP_COUNT: int = 5
const MATERIAL_NAMES = {
    "scrap_low": "雑スクラップ",
    "scrap_mid": "選別スクラップ",
    "scrap_high": "高純度スクラップ",
    "alloy_low": "粗製合金",
    "alloy_mid": "精製合金",
    "alloy_high": "高強度合金",
    "electronics_low": "再生電子部品",
    "electronics_mid": "汎用電子部品",
    "electronics_high": "高精度電子部品",
    "organic_low": "低活性有機素材",
    "organic_mid": "安定有機素材",
    "organic_high": "高活性有機素材"
}
const REFINE_INPUT_PER_BATCH: int = 2
const REFINE_OUTPUT_PER_BATCH: int = 1
const DISMANTLE_INPUT_PER_BATCH: int = 1
const DISMANTLE_OUTPUT_PER_BATCH: int = 2
const MAX_BATCHES: int = 999

static func all_ids() -> Array:
    var ids: Array = []
    for family in FAMILY_IDS:
        for tier in TIERS:
            ids.append(str(family) + "_" + str(tier))
    return ids

static func display_name(material_id: String) -> String:
    return str(MATERIAL_NAMES.get(material_id, ""))

## Catalog uses exactly two visual rows: grade name, then material family.
## The full original name is still retained as the save/tooltip identifier.
static func display_lines(material_id: String) -> String:
    var parts: PackedStringArray = material_id.split("_")
    if parts.size() != 2:
        return display_name(material_id)
    var grade: Dictionary = GRADE_NAMES.get(parts[0], {})
    if not grade.has(parts[1]) or not FAMILY_NAMES.has(parts[0]):
        return display_name(material_id)
    return str(grade[parts[1]]) + "\n" + str(FAMILY_NAMES[parts[0]])


static func empty_inventory() -> Dictionary:
    var stock: Dictionary = {}
    for material_id in all_ids():
        stock[material_id] = 0
    return stock

## Only new profiles start with five scraps. Zero-filled inventories are
## still required for legacy imports, conversion arithmetic and old saves.
static func starter_inventory() -> Dictionary:
    var stock: Dictionary = empty_inventory()
    stock["scrap_low"] = STARTER_SCRAP_COUNT
    return stock


static func sanitize_inventory(candidate: Variant) -> Dictionary:
    var stock: Dictionary = empty_inventory()
    if candidate is Dictionary:
        for material_id in stock.keys():
            var value: Variant = candidate.get(material_id, 0)
            if value is int or value is float:
                stock[material_id] = clampi(int(value), 0, 2147483647)
    return stock

static func meets_requirements(candidate: Dictionary, requirements: Dictionary) -> bool:
    # A specific quality is required: higher/lower quality does not count.
    var inventory: Dictionary = sanitize_inventory(candidate)
    for raw_id in requirements.keys():
        var material_id: String = str(raw_id)
        var needed: Variant = requirements[raw_id]
        if not MATERIAL_NAMES.has(material_id) or not (needed is int) or needed <= 0:
            return false
        if int(inventory[material_id]) < int(needed):
            return false
    return true

static func recipe(family: String, from_rank: int, direction: int,
        batches: int = 1) -> Dictionary:
    if not FAMILY_IDS.has(family) or batches < 1 or batches > MAX_BATCHES:
        return {}
    if direction != 1 and direction != -1:
        return {}
    var to_rank: int = from_rank + direction
    if from_rank < 0 or from_rank > 2 or to_rank < 0 or to_rank > 2:
        return {}
    var input_id: String = family + "_" + str(TIERS[from_rank])
    var output_id: String = family + "_" + str(TIERS[to_rank])
    var per_input: int = (
        REFINE_INPUT_PER_BATCH if direction == 1
        else DISMANTLE_INPUT_PER_BATCH)
    var per_output: int = (
        REFINE_OUTPUT_PER_BATCH if direction == 1
        else DISMANTLE_OUTPUT_PER_BATCH)
    return {
        "input_id": input_id, "output_id": output_id,
        "input_count": per_input * batches,
        "output_count": per_output * batches,
        "family": family, "from_rank": from_rank,
        "to_rank": to_rank, "direction": direction, "batches": batches
    }

static func convert(candidate: Dictionary, family: String, from_rank: int,
        direction: int, batches: int = 1) -> Dictionary:
    var plan: Dictionary = recipe(family, from_rank, direction, batches)
    if plan.is_empty():
        return {"ok": false, "error": "invalid_recipe"}
    var inventory: Dictionary = sanitize_inventory(candidate)
    var from_id: String = str(plan["input_id"])
    var to_id: String = str(plan["output_id"])
    var needed: int = int(plan["input_count"])
    var output: int = int(plan["output_count"])
    if not meets_requirements(inventory, {from_id: needed}):
        return {"ok": false, "error": "insufficient_material"}
    if int(inventory[to_id]) > 2147483647 - output:
        return {"ok": false, "error": "inventory_overflow"}
    inventory[from_id] = int(inventory[from_id]) - needed
    inventory[to_id] = int(inventory[to_id]) + output
    return {
        "ok": true, "inventory": inventory, "recipe": plan,
        "input_id": from_id, "output_id": to_id,
        "input_count": needed, "output_count": output
    }
