extends RefCounted
## Compact read-only NEXUS stats for the currently selected equipment sets.
## These are real combat profile values. Crafted affixes remain presentation-only
## elsewhere until their combat mapping is approved, so they are not counted here.
const PartStats = preload("res://scripts/sera_part_stats.gd")


static func _first(stats: Dictionary, key: String) -> float:
    var raw: Variant = stats.get(key, [])
    if raw is Array and not (raw as Array).is_empty():
        return float((raw as Array)[0])
    return 0.0


static func _add(candidates: Array[Dictionary], label: String,
        amount: float, decimals: int = 0, suffix: String = "") -> void:
    candidates.append({
        "label": label, "amount": amount, "decimals": decimals,
        "suffix": suffix
    })


static func from_selection(selected: Dictionary) -> Array[Dictionary]:
    return from_stats(PartStats.build(selected))


static func from_stats(stats: Dictionary) -> Array[Dictionary]:
    var candidates: Array[Dictionary] = []
    # Synthetic snapshots and legacy saves must not gain fabricated nonzero rows.
    if stats.has("weight_pct"):
        var weight_classes: Dictionary = {
            "light": "軽量", "medium": "中量", "heavy": "重量"
        }
        var category: String = str(weight_classes.get(
            str(stats.get("weight_class", "medium")).to_lower(), "不明"))
        _add(candidates, "重量比（" + category + "）", float(stats["weight_pct"]), 1, "%")
    if stats.has("en_recovery_per_second"):
        _add(candidates, "EN回復速度", float(stats["en_recovery_per_second"]), 2, "/s")
    if stats.has("tracking_speed_mult"):
        _add(candidates, "追尾速度", float(stats["tracking_speed_mult"]) * 100.0, 0, "%")
    if stats.has("attack_motion_speed_mult"):
        _add(candidates, "攻撃速度", float(stats["attack_motion_speed_mult"]) * 100.0, 0, "%")
    _add(candidates, "耐久力", float(stats.get("max_hp", 0.0)))
    _add(candidates, "防御率", float(stats.get("defense", 0.0)) * 100.0, 1, "%")
    _add(candidates, "攻撃力", _first(stats, "attack_damage") *
        float(stats.get("attack_mult", 1.0)))
    _add(candidates, "ブレイク力", _first(stats, "break_damage"))
    _add(candidates, "怯み蓄積", _first(stats, "stagger_gain"))
    _add(candidates, "攻撃EN消費", _first(stats, "attack_energy"))
    _add(candidates, "走行速度", float(stats.get("run_speed", 0.0)), 2)
    _add(candidates, "ブースト速度", float(stats.get("boost_speed", 0.0)) *
        float(stats.get("boost_speed_mult", 1.0)), 2)
    _add(candidates, "ロック距離", float(stats.get("lock_range", 0.0)), 0, "m")
    _add(candidates, "ガード性能", float(stats.get("guard_defense_mult", 0.0)) *
        100.0, 0, "%")
    _add(candidates, "EN消費倍率", float(stats.get("energy_cost_mult", 0.0)) *
        100.0, 0, "%")
    _add(candidates, "ステップ速度", float(stats.get("step_speed_mult", 0.0)) *
        100.0, 0, "%")
    _add(candidates, "バッシュ威力", float(stats.get("bash_damage", 0.0)))
    _add(candidates, "チャージ威力", float(stats.get("charge_damage", 0.0)))
    var visible: Array[Dictionary] = []
    for stat in candidates:
        var amount: float = float(stat["amount"])
        if is_zero_approx(amount):
            continue
        var number: String = ("%.2f" % amount if int(stat["decimals"]) == 2
            else "%.1f" % amount if int(stat["decimals"]) == 1
            else str(roundi(amount)))
        visible.append({
            "label": str(stat["label"]),
            "value": number + str(stat["suffix"])
        })
    return visible
