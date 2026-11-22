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
        var blows: Array = profile["attack_damage"] as Array
        var total: float = 0.0
        for blow in blows:
            total += float(blow)
        stats["attack"] = total / float(maxi(1, blows.size()))
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
        "weapon_l": ["bash_damage", "bash_break", "guard_cost_mult"]
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
    "weight_pct": "重量", "hp": "HP", "defense": "防御",
    "lock_range": "ロック距離", "tracking": "追尾",
    "en_output_mult": "EN出力", "attack_mult": "近接攻撃",
    "guard_defense_mult": "ガード防御",
    "guard_reaction": "ガード反応", "guard_speed_mult": "ガード速度",
    "run_speed": "歩行速度", "boost_speed_mult": "ブースト速度",
    "damage_time_mult": "被弾硬直", "damage_push_mult": "被弾後退",
    "down_hits": "ダウン耐久", "weight_class": "機体区分",
    "run_motion": "移動形式", "boost_speed": "ブースト速度",
    "energy_cost_mult": "EN消費", "step_speed_mult": "ステップ速度",
    "step_time_mult": "ステップ動作", "melee_boost_speed": "近接ブースト速度",
    "melee_boost_duration": "近接ブースト持続",
    "attack_damage": "ダメージ", "break_damage": "破壊",
    "stagger_gain": "怯み", "attack_energy": "攻撃EN消費",
    "stagger_extend": "怯み延長", "guard_cost_mult": "ガードEN消費",
    "guard_transition": "ガード移行", "bash_damage": "バッシュダメージ",
    "bash_break": "バッシュ破壊", "energy_shield": "エネルギーシールド"
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
        # Legacy shield CHARGE fields have no combat consumer. Keep their
        # serialized source data; do not advertise an unavailable attack.
        if key in ["charge_damage", "charge_break", "charge_guard_mult"]:
            continue
        var raw: Variant = profile[key]
        var printed: String = ""
        if raw is bool:
            if not bool(raw):
                continue
            printed = "有効"
        elif raw is Array:
            var amounts: Array = raw as Array
            if amounts.is_empty():
                continue
            var total: float = 0.0
            for amount in amounts:
                total += float(amount)
            var mean: float = total / float(amounts.size())
            if is_zero_approx(mean):
                continue
            printed = "%.1f" % mean
            if key == "attack_energy":
                printed += "EN"
        elif raw is float or raw is int:
            var value: float = float(raw)
            if is_zero_approx(value):
                continue
            if key == "defense":
                printed = "%.1f%%" % (value * 100.0)
            elif key == "weight_pct":
                # Only relative equipment mass is authored; no kg exists.
                printed = "%.1f%%" % value
            elif key.ends_with("_mult") or key == "tracking":
                printed = "×%.1f" % value
            elif key in ["guard_transition", "stagger_extend",
                    "melee_boost_duration"]:
                printed = "%.1fs" % value
            elif key in ["run_speed", "boost_speed", "melee_boost_speed"]:
                printed = "%.1fm/s" % value
            elif key == "lock_range":
                printed = "%.1fm" % value
            elif key == "down_hits":
                printed = "%.1f回" % value
            else:
                printed = "%.1f" % value
        else:
            if raw is String:
                var words: Dictionary = {
                    "light": "軽量", "medium": "中量", "heavy": "重量",
                    "run": "走行", "slide": "スライド", "small": "小"
                }
                printed = str(words.get(str(raw), raw))
            else:
                printed = str(raw)
        lines.append("%s  %s" % [str(PROFILE_LABELS.get(key, key)), printed])
    return "\n".join(lines)

