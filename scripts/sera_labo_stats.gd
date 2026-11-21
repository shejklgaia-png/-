extends RefCounted
## LABO presentation math. Body/weapon bases come from the existing A-rig
## profiles; provisional item affixes are display-only until combat wiring lands.
const PartStats = preload("res://scripts/sera_part_stats.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")

static func base_values(blueprint: String) -> Dictionary:
    var stats: Dictionary = {}
    for key in Affixes.EFFECT_IDS:
        stats[key] = 0.0
    var spec: Dictionary = Catalog.spec(blueprint)
    if spec.is_empty():
        return stats
    var slot: String = str(spec.get("slot", ""))
    var profile: Dictionary = PartStats.PROFILES.get(slot, {}).get(
        str(spec.get("rig_set", "A")), {})
    if profile.has("hp"):
        stats["hp"] = float(profile["hp"])
    if profile.has("defense"):
        stats["defense"] = float(profile["defense"]) * 100.0
    if slot == "weapon_r" and profile.has("attack_damage"):
        stats["attack"] = float((profile["attack_damage"] as Array)[0])
    return stats

static func _amount(value: float) -> String:
    return "%.1f" % value

static func baseline(blueprint: String) -> String:
    var base: Dictionary = base_values(blueprint)
    var lines: PackedStringArray = ["基礎ステータス（現行Aセット参照）"]
    for key in Affixes.EFFECT_IDS:
        if float(base[key]) <= 0.0:
            continue
        var unit: String = "" if key in ["hp", "attack"] else "%"
        lines.append("%s  %s%s" % [
            Affixes.EFFECT_NAMES[key], _amount(float(base[key])), unit])
    if lines.size() == 1:
        lines.append("固有基礎値は未設定（Aセットを使用）")
    return "\n".join(lines)

static func total_formula(blueprint: String, effects: Variant) -> String:
    var base: Dictionary = base_values(blueprint)
    var bonuses: Dictionary = {}
    for key in Affixes.EFFECT_IDS:
        bonuses[key] = 0
    for entry in Affixes.sanitize(effects):
        bonuses[str(entry["id"])] = int(entry["value"])
    var lines: PackedStringArray = [
        "基礎 + 特性（装備単体の表示値）",
        "注: 追加特性は戦闘計算へ未接続の試作値です。"
    ]
    for key in Affixes.EFFECT_IDS:
        var amount: float = float(base[key])
        var bonus: int = int(bonuses[key])
        # HP and weapon damage are flat base figures; affix values are
        # percentage multipliers. Other stats are percent modifiers.
        if key in ["hp", "attack"] and amount > 0.0:
            var add: float = amount * float(bonus) / 100.0
            lines.append("%s  %s + (%s × %d%%) = %s" % [
                Affixes.EFFECT_NAMES[key], _amount(amount), _amount(amount),
                bonus, _amount(amount + add)])
        else:
            lines.append("%s  %s%% + %d%% = %s%%" % [
                Affixes.EFFECT_NAMES[key], _amount(amount), bonus,
                _amount(amount + float(bonus))])
    return "\n".join(lines)
