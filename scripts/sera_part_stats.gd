extends RefCounted
## v177 prototype equipment performance. A=medium, B=heavy.
## v180: each body part HP contribution is 1/5 of v179; A full 160, B full 208.
## v182: melee boost speed remains A=11.5/B=9.5; pre-strike tracking time A=0.4s/B=0.6s.
## v204: B and D are heavy legs; ordinary RUN reuses the BOOST pose as SLIDE.
## Other trial stats remain unchanged; no animation or mesh is replaced.
const BODY_SLOTS = ["head", "torso", "arms", "legs", "booster"]
const PROFILES = {
    "head": {
        "A": {"hp": 20.0, "defense": 0.16, "lock_range": 24.0, "tracking": 1.0},
        "B": {"hp": 26.0, "defense": 0.28, "lock_range": 20.0, "tracking": 0.88}
    },
    "torso": {
        "A": {"hp": 80.0, "defense": 0.16},
        "B": {"hp": 104.0, "defense": 0.34}
    },
    "arms": {
        "A": {"hp": 20.0, "defense": 0.16, "attack_mult": 1.0,
            "guard_defense_mult": 1.0, "guard_reaction": "medium", "guard_speed_mult": 1.0},
        "B": {"hp": 26.0, "defense": 0.30, "attack_mult": 1.12,
            "guard_defense_mult": 1.35, "guard_reaction": "small", "guard_speed_mult": 0.85}
    },
    "legs": {
        "A": {"hp": 20.0, "defense": 0.16, "run_speed": 4.0625,
            "boost_speed_mult": 1.0, "damage_time_mult": 1.0,
            "damage_push_mult": 1.0, "down_hits": 3,
            "weight_class": "medium", "run_motion": "run"},
        "B": {"hp": 26.0, "defense": 0.30, "run_speed": 3.35,
            "boost_speed_mult": 0.82, "damage_time_mult": 1.1,
            "damage_push_mult": 0.60, "down_hits": 5,
            "weight_class": "heavy", "run_motion": "slide"},
        # D is the standard-bone 12-mesh heavy lower body; use B heavy stats
        # until independent D balance values are explicitly authored.
        "D": {"hp": 26.0, "defense": 0.30, "run_speed": 3.35,
            "boost_speed_mult": 0.82, "damage_time_mult": 1.1,
            "damage_push_mult": 0.60, "down_hits": 5,
            "weight_class": "heavy", "run_motion": "slide"}
    },
    "booster": {
        "A": {"hp": 20.0, "defense": 0.16, "boost_speed": 6.09375,
            "energy_cost_mult": 1.0, "step_speed_mult": 1.0,
            "step_time_mult": 1.0, "melee_boost_speed": 11.5,
            "melee_boost_duration": 0.4},
        "B": {"hp": 26.0, "defense": 0.25, "boost_speed": 6.45,
            "energy_cost_mult": 1.40, "step_speed_mult": 0.88,
            "step_time_mult": 1.10, "melee_boost_speed": 9.5,
            "melee_boost_duration": 0.6}
    },
    "weapon_r": {
        "A": {"attack_damage": [12, 12, 26], "break_damage": [14, 14, 32],
            "stagger_gain": [10.0, 10.0, 24.0], "attack_energy": [0.0, 0.0, 0.0],
            "stagger_extend": 0.18},
        "B": {"attack_damage": [17, 17, 36], "break_damage": [22, 22, 46],
            "stagger_gain": [18.0, 18.0, 35.0], "attack_energy": [4.0, 4.0, 8.0],
            "stagger_extend": 0.07}
    },
    "weapon_l": {
        "A": {"guard_cost_mult": 1.0, "guard_transition": 0.095,
            "bash_damage": 12, "bash_break": 12, "charge_damage": 20,
            "charge_break": 25, "charge_guard_mult": 1.0, "energy_shield": false},
        "B": {"guard_cost_mult": 0.85, "guard_transition": 0.14,
            "bash_damage": 16, "bash_break": 22, "charge_damage": 30,
            "charge_break": 38, "charge_guard_mult": 0.75, "energy_shield": true}
    }
}
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
    return stats
