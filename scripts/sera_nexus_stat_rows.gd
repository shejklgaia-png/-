extends RefCounted
## Read-only NEXUS total status. Body and equipped weapons share the
## same underlying combat profile, but have separate visual sections.
## Crafted affixes are not combat-effective yet and are not added here.
const PartStats = preload("res://scripts/sera_part_stats.gd")

static func _average(raw: Variant) -> float:
    if not (raw is Array) or (raw as Array).is_empty():
        return 0.0
    var sum: float = 0.0
    for value in raw as Array:
        sum += float(value)
    return sum / float((raw as Array).size())


static func _add(candidates: Array[Dictionary], group: String,
        label: String, amount: float, suffix: String = "") -> void:
    candidates.append({
        "group": group, "label": label,
        "amount": amount, "suffix": suffix
    })


static func from_selection(selected: Dictionary) -> Array[Dictionary]:
    return from_stats(PartStats.build(selected), selected)


static func from_stats(stats: Dictionary,
        selected: Dictionary = {}) -> Array[Dictionary]:
    var candidates: Array[Dictionary] = []
    # BODY: basic performance -> movement -> body attack -> support.
    # No artificial kg mass: authored weight_pct is a baseline percentage.
    if stats.has("weight_pct"):
        _add(candidates, "body", "重量", float(stats["weight_pct"]), "%")
    _add(candidates, "body", "耐久力", float(stats.get("max_hp", 0.0)))
    _add(candidates, "body", "防御", float(stats.get("defense", 0.0)) * 100.0, "%")
    _add(candidates, "body", "走行速度", float(stats.get("run_speed", 0.0)), "m/s")
    _add(candidates, "body", "ブースト速度", float(stats.get("boost_speed", 0.0)) *
        float(stats.get("boost_speed_mult", 1.0)), "m/s")
    _add(candidates, "body", "ステップ速度",
        float(stats.get("step_speed_mult", 0.0)), "×")
    _add(candidates, "body", "ロック距離", float(stats.get("lock_range", 0.0)), "m")
    _add(candidates, "body", "攻撃速度",
        float(stats.get("attack_motion_speed_mult", 0.0)), "×")
    _add(candidates, "body", "近接攻撃",
        float(stats.get("attack_mult", 0.0)), "×")
    _add(candidates, "body", "EN回復",
        float(stats.get("en_recovery_per_second", 0.0)), "EN/s")
    _add(candidates, "body", "追尾",
        float(stats.get("tracking_speed_mult", 0.0)), "×")
    _add(candidates, "body", "ガード防御",
        float(stats.get("guard_defense_mult", 0.0)), "×")

    # WEAPON ATTACK: three actual combo strikes, equally averaged.
    # The authored combat values are untouched.
    _add(candidates, "weapon", "ダメージ",
        _average(stats.get("attack_damage", [])) *
        float(stats.get("attack_mult", 1.0)))
    _add(candidates, "weapon", "破壊", _average(stats.get("break_damage", [])))
    _add(candidates, "weapon", "怯み", _average(stats.get("stagger_gain", [])))
    _add(candidates, "weapon", "攻撃EN消費",
        _average(stats.get("attack_energy", [])), "EN")

    # WEAPON DEFENSE / ASSIST: hide left-hand status for two-hand Katana K.
    var has_left_weapon: bool = str(selected.get("weapon_r", "")) != "K"
    if has_left_weapon:
        _add(candidates, "weapon", "バッシュダメージ",
            float(stats.get("bash_damage", 0.0)))
        _add(candidates, "weapon", "バッシュ破壊",
            float(stats.get("bash_break", 0.0)))
        _add(candidates, "weapon", "ガードEN消費",
            float(stats.get("guard_cost_mult", 0.0)), "×")
        _add(candidates, "weapon", "ガード移行",
            float(stats.get("guard_transition", 0.0)), "s")

    var visible: Array[Dictionary] = []
    for stat in candidates:
        var amount: float = float(stat["amount"])
        if is_zero_approx(amount):
            continue
        var suffix: String = str(stat["suffix"])
        # Unit prefixes for multipliers are written as ×1.0, not 1.0×.
        var number: String = "%.1f" % amount
        if suffix == "×":
            number = "×" + number
        else:
            number += suffix
        visible.append({
            "group": str(stat["group"]),
            "label": str(stat["label"]),
            "value": number
        })
    if has_left_weapon and bool(stats.get("energy_shield", false)):
        visible.append({
            "group": "weapon", "label": "シールド", "value": "有効"
        })
    return visible
