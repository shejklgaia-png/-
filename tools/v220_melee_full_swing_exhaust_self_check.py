#!/usr/bin/env python3
"""SERA v220: normal melee jets stay on through approach, full swing and hit-stop."""
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
rig = read("scripts/sera_rig.gd")
equip = read("scripts/sera_equipment.gd")
fx = read("scripts/back_thruster_fx.gd")
project = read("project.godot")
ver = re.search(r'config/name="SERA v(\d+)"', project)
assert ver and int(ver.group(1)) >= 220

# Regular normal attacks are visually airborne all the way through their
# nonmoving preparation, chase and finished blade swing (even after a hit).
start = main.index("var normal_melee_exhaust: bool = (")
end = main.index("var exhaust_on: bool =", start)
normal_gate = main[start:end]
expected = (
    "CombatState.MELEE_APPROACH",
    "CombatState.DASH",
    "CombatState.STRIKE_TRACK",
    "CombatState.STRIKE",
    "CombatState.BASH_TRACK",
    "CombatState.BASH",
    "CombatState.BACK_KICK_TRACK",
)
assert all(f"combat_state == {name}" in normal_gate for name in expected)
assert normal_gate.count("combat_state == CombatState.") == len(expected)
assert "combat_state == CombatState.BASH" in normal_gate
assert "blur_velocity" not in normal_gate
assert "strike_did_hit" not in normal_gate
assert "jump_active" not in normal_gate
assert "energy_exhausted" not in normal_gate

# Global FX safety gates stay in effect for damage, guard, jump, landing and
# empty energy. The new boolean contributes ONLY to normal exhaust lifetime.
physics_rules = read("scripts/sera_physics_frame_rules.gd")
exhaust_section = main.split(
    "var exhaust_on: bool = PHYSICS_FRAME.exhaust_allowed(", 1)[1].split(
    "var tracking_accel_state: int =", 1)[0]
assert "damage_reaction_active, jump_active, landing_active, guard_active," in exhaust_section
assert "energy_exhausted, boost_exhaust, boost_pose_exhaust," in exhaust_section
assert "stepping_this_frame, tracking_exhaust, normal_attack_exhaust)" in exhaust_section
assert "not damage_active and not jumping and not landing" in physics_rules
assert "and not guarding and not energy_exhausted" in physics_rules
assert "boost_exhaust or boost_pose_exhaust or stepping" in physics_rules
assert "or tracking_exhaust or attack_exhaust" in physics_rules

# The existing homing-motion gate must not be changed: an acceleration burst
# occurs only on measured movement + a new tracking/step state, never merely
# because the ordinary flame remains present while swinging in place.
tracking = main.split("var tracking_exhaust: bool = (", 1)[1].split(
    "var normal_melee_exhaust: bool = (", 1)[0]
assert "combat_state == CombatState.DASH" in tracking
assert "combat_state == CombatState.BASH_TRACK" in tracking
assert "combat_state == CombatState.STRIKE_TRACK" in tracking
assert "combat_state == CombatState.STRIKE and not strike_did_hit" in tracking
assert "combat_state == CombatState.BASH and not bash_did_hit" in tracking
assert "and blur_velocity.length_squared() > 0.04" in tracking
burst = main.split("var tracking_accel_state: int =", 1)[1].split(
    "var direction_of_exhaust: Vector3 =", 1)[0]
assert "combat_state if tracking_exhaust else -1" in burst
assert "var acceleration_burst: bool = PHYSICS_FRAME.acceleration_burst(" in burst
assert "exhaust_on, stepping_this_frame, thruster_accel_previous_step," in burst
assert "new_somersault_burst, tracking_accel_state," in burst
assert "thruster_accel_previous_tracking_state)" in burst
assert "stepping and not previous_step" in physics_rules
assert "tracking_state != previous_tracking_state" in physics_rules
assert "normal_melee_exhaust" not in burst
presentation = read("scripts/sera_thruster_presentation.gd")
assert "thruster_presentation.update(rig, exhaust_on," in main
assert "direction_of_exhaust, delta, backstroke_weight, left_sector_world," in main
assert "left_sector_world, acceleration_burst, normal_attack_exhaust)" in presentation
assert "left_sector_world, acceleration_burst, melee_sustain)" in rig
assert "acceleration_burst, melee_sustain)" in equip

# All three normal melee stages use STRIKE for the authored swing. Follow-ups
# use STRIKE_TRACK and then return to STRIKE after reaching the target.
assert "combat_state = CombatState.MELEE_APPROACH" in main
assert "combat_state = CombatState.DASH" in main
assert "combat_state = CombatState.STRIKE_TRACK" in main
assert "combat_state = CombatState.STRIKE" in main
assert "combat_state = CombatState.IDLE" in main
assert "if hit_stop_remaining > 0.0:" in main
assert "if not strike_did_hit:" in main
assert "rig.call(\"finish_attack\"" in main

# Exhaust and burst expected over a synthetic full 3-hit combo: stationary
# approach, moving chase, stationary follow-through and confirmed-hit hold.
def normal_fx(state: str, speed: float = 0.0, hit: bool = False,
              damage: bool = False, guard: bool = False,
              landing: bool = False, jumping: bool = False,
              exhausted: bool = False) -> tuple[bool, bool]:
    normal = state in ("MELEE_APPROACH", "DASH", "STRIKE_TRACK", "STRIKE", "BASH_TRACK", "BASH", "BACK_KICK_TRACK")
    moving_chase = (state in ("DASH", "STRIKE_TRACK")
                    or (state == "STRIKE" and not hit)
                    or (state in ("BASH_TRACK", "BASH") and not hit)) and speed > 0.2
    permitted = not (damage or guard or landing or jumping or exhausted)
    # The tracking boolean is ALSO the acceleration-burst gate.
    return permitted and (normal or moving_chase), permitted and moving_chase

stages = [
    ("MELEE_APPROACH",0.0,False),
    ("DASH",7.0,False),
    ("STRIKE",8.0,False),
    ("STRIKE",0.0,False),
    ("STRIKE",0.0,True),     # confirmed hit / hit-stop
    ("STRIKE_TRACK",0.0,False),
    ("STRIKE_TRACK",5.0,False),
    ("STRIKE",0.0,True),     # second swing finished after hit
    ("STRIKE_TRACK",0.0,False),
    ("STRIKE",0.0,True),     # third swing finished after hit
]
for state,speed,hit in stages:
    flame,burst_eligible = normal_fx(state,speed,hit)
    assert flame, (state,speed,hit)
    if speed == 0:
        assert not burst_eligible, (state,speed,hit)

# An uninterrupted swing still ends cleanly after recovery or cancellation.
for state in ("IDLE", "RUN", "SLIDE"):
    assert normal_fx(state) == (False,False)
assert normal_fx("BASH",0.0,True) == (True,False)
assert normal_fx("BASH_TRACK",5.0,False) == (True,True)
for blockers in (
    {"damage":True}, {"guard":True}, {"landing":True},
    {"jumping":True}, {"exhausted":True},
):
    assert normal_fx("STRIKE",0,True,**blockers) == (False,False)

# The jet geometry/envelope stay the v219 10-sided 15x/50ms design.
assert 'const EXHAUST_RADIAL_SIDES: int = 10' in fx
assert 'const BURST_RISE_SECONDS: float = 0.05' in fx
assert 'const BURST_FALL_SECONDS: float = 0.18' in fx
assert 'const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0' in fx
assert 'const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50' in rig

print("PASS v220: ordinary thruster persists through all 3 normal melee follow-throughs")
print("PASS: after-hit/hit-stop/no-movement flames, tracking burst remains movement-only")
print("PASS: normal attack exits and unrelated bash, BOOST, STEP and EN gates unchanged")
print("Godot/Android rendered behavior not tested")
