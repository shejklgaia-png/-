extends RefCounted
## LABO presentation math. Body/weapon bases come from the current actual rig
## profiles; H02 (camera-eye) uses real HEAD D with unchanged A head baseline.
## Provisional item affixes are display-only until combat wiring lands.
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
    # Compact LABO cards must summarize the REAL authored part, not just
    # Affixes' HP/DEF/attack keys. In particular left-hand shields previously
    # displayed "no baseline" despite their real guard/bash profiles.
    var spec: Dictionary = Catalog.spec(blueprint)
    if spec.is_empty():
        return ""
    var slot: String = str(spec.get("slot", ""))
    var summary_fields: Dictionary = {
        "head": ["hp", "defense", "lock_range"],
        "torso": ["hp", "defense", "en_output_mult"],
        "arms": ["hp", "defense", "attack_mult"],
        "legs": ["hp", "run_speed", "boost_speed_mult"],
        "booster": ["hp", "boost_speed", "energy_cost_mult"],
        "weapon_r": ["attack_damage", "break_damage", "stagger_extend"],
        "weapon_l": ["bash_damage", "charge_damage", "guard_cost_mult"]
    }
    var complete: PackedStringArray = complete_profile_text(blueprint).split("\n")
    var lines: PackedStringArray = ["基礎ステータス"]
    for key in summary_fields.get(slot, []):
        var match_prefix: String = str(PROFILE_LABELS.get(key, key)) + "  "
        for candidate in complete:
            if str(candidate).begins_with(match_prefix):
                lines.append(str(candidate))
                break
    if lines.size() == 1:
        lines.append("性能登録エラー：参照先に基礎値がありません")
    return "\n".join(lines)

static func total_stat_rows(blueprint: String, effects: Variant) -> Array[Dictionary]:
    # The UI is a true table: each entry is a discrete label, expression,
    # and final value. Computation and save/affix rules remain unchanged.
    var base: Dictionary = base_values(blueprint)
    var bonuses: Dictionary = {}
    for key in Affixes.EFFECT_IDS:
        bonuses[key] = 0
    for entry in Affixes.sanitize(effects):
        bonuses[str(entry["id"])] = int(entry["value"])
    var rows: Array[Dictionary] = []
    for key in Affixes.EFFECT_IDS:
        var amount: float = float(base[key])
        var bonus: int = int(bonuses[key])
        var formula: String = ""
        var total: String = ""
        if key in ["hp", "attack"] and amount > 0.0:
            var add: float = amount * float(bonus) / 100.0
            formula = "%s + (%s × %d%%)" % [
                _amount(amount), _amount(amount), bonus]
            total = _amount(amount + add)
        else:
            formula = "%s%% + %d%%" % [_amount(amount), bonus]
            total = "%s%%" % _amount(amount + float(bonus))
        rows.append({
            "id": key,
            "name": Affixes.EFFECT_NAMES[key],
            "formula": formula,
            "total": total,
        })
    return rows


static func total_formula(blueprint: String, effects: Variant) -> String:
    # Text-only compatibility for diagnostics; warehouse screen uses a grid.
    # No annotation is inserted into either representation.
    var lines: PackedStringArray = ["基礎 + 特性（装備単体の表示値）"]
    for row in total_stat_rows(blueprint, effects):
        lines.append("%s  %s = %s" % [
            row["name"], row["formula"], row["total"]])
    return "\n".join(lines)

# Complete, source-driven statistics for each authored part. Do not silently
# substitute an A profile or invent separate balancing for C/D/K.
const PROFILE_LABELS: Dictionary = {
    "weight_pct": "重量比", "hp": "HP", "defense": "防御率",
    "lock_range": "ロック距離", "tracking": "追尾性能",
    "en_output_mult": "EN出力", "attack_mult": "近接攻撃倍率",
    "guard_defense_mult": "ガード防御倍率",
    "guard_reaction": "ガード反応", "guard_speed_mult": "ガード速度倍率",
    "run_speed": "歩行速度", "boost_speed_mult": "ブースト速度倍率",
    "damage_time_mult": "被弾時間倍率", "damage_push_mult": "被弾後退倍率",
    "down_hits": "ダウン被弾回数", "weight_class": "部位モデル区分",
    "run_motion": "歩行モーション", "boost_speed": "ブースト速度",
    "energy_cost_mult": "EN消費倍率", "step_speed_mult": "ステップ速度倍率",
    "step_time_mult": "ステップ時間倍率",
    "melee_boost_speed": "近接ブースト速度",
    "melee_boost_duration": "近接ブースト時間",
    "attack_damage": "攻撃威力（各段）", "break_damage": "部位破壊威力（各段）",
    "stagger_gain": "怯み蓄積（各段）", "attack_energy": "攻撃EN消費（各段）",
    "stagger_extend": "怯み延長秒数", "guard_cost_mult": "ガードEN消費倍率",
    "guard_transition": "ガード移行時間", "bash_damage": "バッシュ威力",
    "bash_break": "バッシュ部位破壊", "charge_damage": "溜め威力",
    "charge_break": "溜め部位破壊", "charge_guard_mult": "溜めガード倍率",
    "energy_shield": "エネルギーシールド"
}

static func complete_profile_text(blueprint: String) -> String:
    var spec: Dictionary = Catalog.spec(blueprint)
    if spec.is_empty():
        return ""
    var slot: String = str(spec.get("slot", ""))
    var rig_set: String = str(spec.get("rig_set", ""))
    var profile: Dictionary = PartStats.PROFILES.get(slot, {}).get(rig_set, {})
    if profile.is_empty():
        return "性能登録エラー：モデル参照先がありません"
    var lines: PackedStringArray = ["基礎ステータス"]
    for key in profile.keys():
        var raw: Variant = profile[key]
        var printed: String = ""
        if raw is bool:
            if not bool(raw):
                continue
            printed = "有効"
        elif raw is Array:
            var values: PackedStringArray = []
            var all_zero: bool = true
            for n in raw:
                values.append(str(n))
                if absf(float(n)) > 0.00001:
                    all_zero = false
            if all_zero:
                continue
            printed = " / ".join(values)
        elif raw is float or raw is int:
            var value: float = float(raw)
            if is_zero_approx(value):
                continue
            if key == "defense":
                printed = "%.1f%%" % (value * 100.0)
            elif key == "weight_pct":
                printed = "%.1f%%" % value
            elif key.ends_with("_mult") or key == "tracking":
                printed = "%.1f%%" % (value * 100.0)
            else:
                printed = str(raw)
        else:
            printed = str(raw)
        lines.append("%s  %s" % [str(PROFILE_LABELS.get(key, key)), printed])
    return "\n".join(lines)

