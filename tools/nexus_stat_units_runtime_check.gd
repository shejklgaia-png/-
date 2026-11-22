extends SceneTree
## Contract for user-facing one-decimal equipment numbers and units.
const Labo = preload("res://scripts/sera_labo_stats.gd")
const Stats = preload("res://scripts/sera_nexus_stat_rows.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("NEXUS_STAT_UNITS_RUNTIME_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var blade: String = Labo.complete_profile_text("WR01")
    var blade_b: String = Labo.complete_profile_text("WR02")
    var shield: String = Labo.complete_profile_text("WL01")
    var leg: String = Labo.complete_profile_text("L01")
    var booster: String = Labo.complete_profile_text("B01")
    if not blade.contains("ダメージ  16.7") or (
            not blade.contains("破壊  20.0")) or (
            not blade.contains("怯み  14.7")) or (
            not blade_b.contains("ダメージ  23.3")):
        _fail("right weapon profile must report all-strike arithmetic mean")
        return
    if not shield.contains("バッシュダメージ  12.0") or (
            not shield.contains("バッシュ破壊  12.0")) or (
            shield.contains("溜め")) or (
            shield.contains("charge")):
        _fail("obsolete shield charge stats leaked into equipment UI")
        return
    if not leg.contains("被弾硬直  ×1.0") or (
            not leg.contains("移動形式  走行")) or (
            not leg.contains("重量  100.0%")):
        _fail("component multipliers, movement types and mass need real units")
        return
    if not booster.contains("近接ブースト持続  0.4s") or (
            not booster.contains("ブースト速度  6.1m/s")):
        _fail("durations and speeds must use one decimal and real units")
        return
    for source in [blade, shield, leg, booster]:
        for obsolete in ["（各段）", "倍率", "秒数", "防御率",
                "重量比", "部位破壊威力", "怯み蓄積"]:
            if source.contains(obsolete):
                _fail("outdated field name " + obsolete)
                return
    var a: Array[Dictionary] = Stats.from_selection({
        "head": "A", "torso": "A", "arms": "A", "legs": "A",
        "booster": "A", "weapon_r": "A", "weapon_l": "A"
    })
    var entered_weapon: bool = false
    for entry in a:
        var weapon: bool = str(entry.get("group", "")) == "weapon"
        if entered_weapon and not weapon:
            _fail("body and weapon groups interleaved")
            return
        entered_weapon = entered_weapon or weapon
        var content: String = str(entry["value"])
        if content.is_empty() or content.contains("倍率") or (
                str(entry["label"]).contains("（各段）")):
            _fail("invalid complete loadout value: " + str(entry["label"]))
            return
    print("NEXUS_STAT_UNITS_RUNTIME_PASS")
    quit(0)
