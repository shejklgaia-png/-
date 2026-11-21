extends RefCounted
## v177 prototype equipment performance. A=medium, B=heavy.
## v180: each body part HP contribution is 1/5 of v179; A full 160, B full 208.
## v182: melee boost speed remains A=11.5/B=9.5; pre-strike tracking time A=0.4s/B=0.6s.
## v204: B and D are heavy legs; ordinary RUN reuses the BOOST pose as SLIDE.
## Other trial stats remain unchanged; no animation or mesh is replaced.
const BODY_SLOTS = ["head", "torso", "arms", "legs", "booster"]
const PROFILES = {
    "head": {
        "A": {"weight_pct": 100.0, "hp": 20.0, "defense": 0.16, "lock_range": 24.0, "tracking": 1.0},
        "B": {"weight_pct": 120.0, "hp": 26.0, "defense": 0.28, "lock_range": 20.0, "tracking": 0.88},
        # HEAD C is a lightweight redesigned optic, with A's combat tuning.
        "C": {"weight_pct": 85.0, "hp": 20.0, "defense": 0.16, "lock_range": 24.0, "tracking": 1.0},
        # HEAD D / IRIS retains the currently playable A head performance.
        # Cosmetic head option; independent balance is not approved yet.
        "D": {"weight_pct": 65.0, "hp": 20.0, "defense": 0.16, "lock_range": 24.0, "tracking": 1.0}
    },
    "torso": {
        "A": {"weight_pct": 100.0, "hp": 80.0, "defense": 0.16, "en_output_mult": 1.0},
        "B": {"weight_pct": 170.0, "hp": 104.0, "defense": 0.34, "en_output_mult": 1.15}
    },
    "arms": {
        "A": {"weight_pct": 100.0, "hp": 20.0, "defense": 0.16, "attack_mult": 1.0,
            "guard_defense_mult": 1.0, "guard_reaction": "medium", "guard_speed_mult": 1.0},
        "B": {"weight_pct": 145.0, "hp": 26.0, "defense": 0.30, "attack_mult": 1.12,
            "guard_defense_mult": 1.35, "guard_reaction": "small", "guard_speed_mult": 0.85}
    },
    "legs": {
        "A": {"weight_pct": 100.0, "hp": 20.0, "defense": 0.16, "run_speed": 4.0625,
            "boost_speed_mult": 1.0, "damage_time_mult": 1.0,
            "damage_push_mult": 1.0, "down_hits": 3,
            "weight_class": "medium", "run_motion": "run"},
        "B": {"weight_pct": 180.0, "hp": 26.0, "defense": 0.30, "run_speed": 3.35,
            "boost_speed_mult": 0.82, "damage_time_mult": 1.1,
            "damage_push_mult": 0.60, "down_hits": 3,
            "weight_class": "heavy", "run_motion": "slide"},
        # Bird-leg C uses its own gait and lower nominal assembly mass.
        "C": {"weight_pct": 75.0, "hp": 20.0, "defense": 0.16, "run_speed": 4.0625,
            "boost_speed_mult": 1.0, "damage_time_mult": 1.0,
            "damage_push_mult": 1.0, "down_hits": 3,
            "weight_class": "medium", "run_motion": "run"},
        # D is the standard-bone 12-mesh heavy lower body; use B heavy stats
        # until independent D balance values are explicitly authored.
        "D": {"weight_pct": 165.0, "hp": 26.0, "defense": 0.30, "run_speed": 3.35,
            "boost_speed_mult": 0.82, "damage_time_mult": 1.1,
            "damage_push_mult": 0.60, "down_hits": 3,
            "weight_class": "heavy", "run_motion": "slide"}
    },
    "booster": {
        "A": {"weight_pct": 100.0, "hp": 20.0, "defense": 0.16, "boost_speed": 6.09375,
            "energy_cost_mult": 1.0, "step_speed_mult": 1.0,
            "step_time_mult": 1.0, "melee_boost_speed": 11.5,
            "melee_boost_duration": 0.4},
        "B": {"weight_pct": 145.0, "hp": 26.0, "defense": 0.25, "boost_speed": 6.45,
            "energy_cost_mult": 1.40, "step_speed_mult": 0.88,
            "step_time_mult": 1.10, "melee_boost_speed": 9.5,
            "melee_boost_duration": 0.6}
    },
    "weapon_r": {
        "A": {"weight_pct": 100.0, "attack_damage": [12, 12, 26], "break_damage": [14, 14, 32],
            "stagger_gain": [10.0, 10.0, 24.0], "attack_energy": [0.0, 0.0, 0.0],
            "stagger_extend": 0.18},
        "B": {"weight_pct": 150.0, "attack_damage": [17, 17, 36], "break_damage": [22, 22, 46],
            "stagger_gain": [18.0, 18.0, 35.0], "attack_energy": [4.0, 4.0, 8.0],
            "stagger_extend": 0.07},
        # Katana K retains the established A combat baseline until authored
        # per-strike Katana balancing is approved; mass is provisional.
        "K": {"weight_pct": 135.0, "attack_damage": [12, 12, 26],
            "break_damage": [14, 14, 32], "stagger_gain": [10.0, 10.0, 24.0],
            "attack_energy": [0.0, 0.0, 0.0], "stagger_extend": 0.18}
    },
    "weapon_l": {
        "A": {"weight_pct": 100.0, "guard_cost_mult": 1.0, "guard_transition": 0.095,
            "bash_damage": 12, "bash_break": 12, "charge_damage": 20,
            "charge_break": 25, "charge_guard_mult": 1.0, "energy_shield": false},
        "B": {"weight_pct": 135.0, "guard_cost_mult": 0.85, "guard_transition": 0.14,
            "bash_damage": 16, "bash_break": 22, "charge_damage": 30,
            "charge_break": 38, "charge_guard_mult": 0.75, "energy_shield": true}
    }
}
## v553: Each A part is weight 100. Shares are canonical base-frame mass
## proportions, totaling 1.0. B/D values are provisional authoring defaults.
const WEIGHT_SHARES: Dictionary = {
    "head": 0.10, "torso": 0.26, "arms": 0.17, "legs": 0.23,
    "booster": 0.09, "weapon_r": 0.09, "weapon_l": 0.06
}
const WEIGHT_EFFECTS: Dictionary = {
    "light": {
        "movement_en_efficiency": 1.20, "run_speed_mult": 1.20,
        "boost_weight_mult": 1.15, "tracking_speed_mult": 1.25,
        "step_speed_weight_mult": 1.10, "step_distance_mult": 1.0,
        "en_output_weight_mult": 0.80, "knockback_mult": 1.25,
        "melee_attack_mult": 0.85, "attack_motion_speed_mult": 1.15,
        "guard_defense_weight_mult": 1.0, "down_hits_delta": -1
    },
    "medium": {
        "movement_en_efficiency": 1.0, "run_speed_mult": 1.0,
        "boost_weight_mult": 1.0, "tracking_speed_mult": 1.0,
        "step_speed_weight_mult": 1.0, "step_distance_mult": 1.0,
        "en_output_weight_mult": 1.0, "knockback_mult": 1.0,
        "melee_attack_mult": 1.0, "attack_motion_speed_mult": 1.0,
        "guard_defense_weight_mult": 1.0, "down_hits_delta": 0
    },
    "heavy": {
        "movement_en_efficiency": 0.90, "run_speed_mult": 0.85,
        "boost_weight_mult": 0.80, "tracking_speed_mult": 0.85,
        "step_speed_weight_mult": 0.80, "step_distance_mult": 1.20,
        "en_output_weight_mult": 1.30, "knockback_mult": 0.70,
        "melee_attack_mult": 1.25, "attack_motion_speed_mult": 0.85,
        "guard_defense_weight_mult": 1.25, "down_hits_delta": 2
    }
}
const BASE_EN_RECOVERY_PER_SECOND: float = 24.0

static func weight_class_for(percent: float) -> String:
    if percent <= 70.0:
        return "light"
    if percent >= 140.0:
        return "heavy"
    return "medium"

static func weight_percent_for(selected: Dictionary) -> float:
    var total: float = 0.0
    for slot in WEIGHT_SHARES:
        # K occupies both hands: the regular left-hand shield is not worn.
        if slot == "weapon_l" and str(selected.get("weapon_r", "A")) == "K":
            continue
        var set_id: String = str(selected.get(slot, "A"))
        var profiles: Dictionary = PROFILES[slot]
        var profile: Dictionary = profiles.get(set_id, profiles["A"])
        total += float(WEIGHT_SHARES[slot]) * float(profile.get("weight_pct", 100.0))
    return total

static func authoring_baseline(slot: String) -> Dictionary:
    if not PROFILES.has(slot):
        return {}
    return (PROFILES[slot]["A"] as Dictionary).duplicate(true)

static func build(selected: Dictionary) -> Dictionary:
    var stats: Dictionary = {}
    var hp_total: float = 0.0
    var defense_total: float = 0.0
    for slot in PROFILES.keys():
        var set_id: String = str(selected.get(slot, "A"))
        var options: Dictionary = PROFILES[slot]
        var part: Dictionary = options.get(set_id, options["A"])
        if BODY_SLOTS.has(slot):
            hp_total += float(part["hp"])
            defense_total += float(part["defense"])
        for key in part.keys():
            if key != "hp" and key != "defense":
                stats[key] = part[key]
    stats["max_hp"] = hp_total
    stats["defense"] = defense_total / float(BODY_SLOTS.size())
    var weight_percent: float = weight_percent_for(selected)
    var weight_class: String = weight_class_for(weight_percent)
    var effect: Dictionary = WEIGHT_EFFECTS[weight_class]
    stats["weight_pct"] = weight_percent
    stats["weight_class"] = weight_class
    for key in effect:
        stats[key] = effect[key]
    # Apply categorical modifiers ONCE, after all part-specific profiles merge.
    stats["run_speed"] = float(stats.get("run_speed", 4.0625)) * float(effect["run_speed_mult"])
    stats["boost_speed_mult"] = float(stats.get("boost_speed_mult", 1.0)) * float(effect["boost_weight_mult"])
    stats["step_speed_mult"] = float(stats.get("step_speed_mult", 1.0)) * float(effect["step_speed_weight_mult"])
    stats["attack_mult"] = float(stats.get("attack_mult", 1.0)) * float(effect["melee_attack_mult"])
    stats["guard_defense_mult"] = float(stats.get("guard_defense_mult", 1.0)) * float(effect["guard_defense_weight_mult"])
    stats["damage_push_mult"] = float(stats.get("damage_push_mult", 1.0)) * float(effect["knockback_mult"])
    stats["down_hits"] = maxi(1, int(stats.get("down_hits", 3)) + int(effect["down_hits_delta"]))
    stats["en_output_mult"] = float(stats.get("en_output_mult", 1.0)) * float(effect["en_output_weight_mult"])
    stats["en_recovery_per_second"] = BASE_EN_RECOVERY_PER_SECOND * float(stats["en_output_mult"])
    return stats
