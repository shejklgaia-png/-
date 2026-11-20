extends RefCounted
## Lightweight per-instance crafting modifiers.  Five distinct rolled effects
## are stored under each crafted UID.  Researchable module slots are separate.
const ROLL_COUNT: int = 5
const EFFECT_IDS: Array[String] = [
    "hp", "energy", "attack", "defense", "energy_recovery",
    "guard", "boost", "stagger"
]
const EFFECT_NAMES: Dictionary = {
    "hp": "最大HP", "energy": "最大EN", "attack": "攻撃",
    "defense": "防御", "energy_recovery": "EN回復",
    "guard": "ガード", "boost": "ブースト", "stagger": "怯み耐性"
}
# Provisional small-value rolls. No combat stat mapping is implied until that
# separate integration has been checked against actual SERA balance contracts.
const MIN_PERCENT: int = 1
const MAX_PERCENT: int = 5

static func roll_five() -> Array:
    var choices: Array = EFFECT_IDS.duplicate()
    var output: Array = []
    for i in range(ROLL_COUNT):
        var selected: int = randi_range(0, choices.size() - 1)
        var effect_id: String = str(choices[selected])
        choices.remove_at(selected)
        output.append({
            "id": effect_id, "value": randi_range(MIN_PERCENT, MAX_PERCENT)
        })
    return output

static func valid(raw: Variant) -> bool:
    if not (raw is Array) or raw.size() != ROLL_COUNT:
        return false
    var seen: Dictionary = {}
    for effect in raw:
        if not (effect is Dictionary):
            return false
        var effect_id: String = str(effect.get("id", ""))
        var value: Variant = effect.get("value", 0)
        if not EFFECT_NAMES.has(effect_id) or seen.has(effect_id):
            return false
        if not (value is int) or int(value) < MIN_PERCENT or int(value) > MAX_PERCENT:
            return false
        seen[effect_id] = true
    return true

static func sanitize(raw: Variant) -> Array:
    # Legacy created gear has no effects; leave it untouched (no retroactive roll).
    if not valid(raw):
        return []
    var clean: Array = []
    for effect in raw:
        clean.append({"id": str(effect["id"]), "value": int(effect["value"])})
    return clean

static func label(effect: Dictionary) -> String:
    var id: String = str(effect.get("id", ""))
    if not EFFECT_NAMES.has(id):
        return ""
    return "%s +%d%%" % [EFFECT_NAMES[id], int(effect.get("value", 0))]

static func describe(effects: Variant) -> String:
    if not valid(effects):
        return "追加性能なし（旧装備）"
    var labels: PackedStringArray = []
    for effect in effects:
        labels.append(label(effect))
    return "\n".join(labels)
