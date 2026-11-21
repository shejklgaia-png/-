extends SceneTree
## Deterministic weight/EN-out balance smoke test, executed as its own Godot process.
const Stats = preload("res://scripts/sera_part_stats.gd")

func _initialize() -> void:
    call_deferred("_check")

func _expect(value: bool, message: String) -> bool:
    if value:
        return true
    push_error("SERA_INTAKE_WEIGHT_FAIL: " + message)
    return false

func _near(a: float, b: float) -> bool:
    return is_equal_approx(a, b)

func _check() -> void:
    var ok: bool = true
    var a: Dictionary = Stats.build({})
    ok = _expect(_near(float(a["weight_pct"]), 100.0), "A weight") and ok
    ok = _expect(str(a["weight_class"]) == "medium", "A category") and ok
    ok = _expect(_near(float(a["en_recovery_per_second"]), 24.0), "A EN/s") and ok
    ok = _expect(_near(float(a["run_speed"]), 4.0625), "A run") and ok
    ok = _expect(int(a["down_hits"]) == 3, "A down threshold") and ok
    ok = _expect(Stats.weight_class_for(70.0) == "light", "70 light inclusive") and ok
    ok = _expect(Stats.weight_class_for(70.001) == "medium", "above 70 medium") and ok
    ok = _expect(Stats.weight_class_for(139.999) == "medium", "below 140 medium") and ok
    ok = _expect(Stats.weight_class_for(140.0) == "heavy", "140 heavy inclusive") and ok
    var all_b: Dictionary = {}
    for slot in Stats.WEIGHT_SHARES:
        all_b[slot] = "B"
    var heavy: Dictionary = Stats.build(all_b)
    ok = _expect(_near(float(heavy["weight_pct"]), 156.9), "B weighted average") and ok
    ok = _expect(str(heavy["weight_class"]) == "heavy", "B heavy") and ok
    ok = _expect(_near(float(heavy["run_speed"]), 3.35 * 0.85), "heavy run") and ok
    ok = _expect(_near(float(heavy["boost_speed_mult"]), 0.82 * 0.8), "heavy boost") and ok
    ok = _expect(_near(float(heavy["step_speed_mult"]), 0.88 * 0.8), "heavy step") and ok
    ok = _expect(_near(float(heavy["step_distance_mult"]), 1.2), "heavy step range") and ok
    ok = _expect(_near(float(heavy["attack_mult"]), 1.12 * 1.25), "heavy damage") and ok
    ok = _expect(_near(float(heavy["tracking_speed_mult"]), 0.85), "heavy pursuit") and ok
    ok = _expect(_near(float(heavy["attack_motion_speed_mult"]), 0.85), "heavy motion") and ok
    ok = _expect(_near(float(heavy["guard_defense_mult"]), 1.35 * 1.25), "heavy guard") and ok
    ok = _expect(_near(float(heavy["en_recovery_per_second"]), 24.0 * 1.15 * 1.3), "heavy EN/s") and ok
    ok = _expect(_near(float(heavy["movement_en_efficiency"]), 0.9), "heavy cost efficiency") and ok
    ok = _expect(int(heavy["down_hits"]) == 5, "heavy down threshold once") and ok
    var head_d: Dictionary = Stats.build({"head": "D"})
    ok = _expect(_near(float(head_d["weight_pct"]), 96.5), "head D lightweight part") and ok
    ok = _expect(str(head_d["weight_class"]) == "medium", "full build remains medium") and ok
    if ok:
        print("SERA_INTAKE_WEIGHT_OK")
    quit(0 if ok else 1)
