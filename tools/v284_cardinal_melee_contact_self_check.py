#!/usr/bin/env python3
"""SERA v284: fixed screen quadrants, 50ms finisher cancel, hit-then-retreat and shared thrusters."""
from pathlib import Path

# v317 refactor: assert main's delegation and the canonical pure math.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
import json,re,math

R=Path(__file__).resolve().parents[1]
m=(R/"scripts/main.gd").read_text(encoding="utf-8")
rig=(R/"scripts/sera_rig.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
source=json.loads((R/"assets/sera_source.json").read_text(encoding="utf-8"))
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=284
assert "MELEE3_FLICK_CANCEL_DELAY: float = 0.05" in m
assert math.isclose(15/24+0.05,0.675)
assert "STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]" in m
assert "BACK_SOMERSAULT_STRIKE_SECONDS: float" in m
assert "BACK_SOMERSAULT_REAR_FLIGHT_SECONDS: float" in m
assert "back_somersault_launched: bool = false" in m

classification=SERA_INPUT.split("static func combo_kick_side(flick: Vector2) -> int:",1)[1].split("static func upward_jump_flick",1)[0]
assert "flick, Vector2.UP" in classification
assert "gesture_screen_forward" not in classification
for token in ("1:", "2:", "3:", "return 1", "return 2", "return -1", "return 0"):
    assert token in classification
bash=m.split("func _is_character_forward_flick(displacement: Vector2, seconds: float) -> bool:",1)[1].split(
    "func _classify_recent_character_forward_flick",1)[0]
assert "displacement, seconds, Vector2.UP" in bash
change=m.split("func _change_drag(pos: Vector2) -> void:",1)[1].split(
    "func _update_boost_gesture",1)[0]
assert "displacement, Vector2.UP" in change
release=m.split("func _end_drag(release_pos: Vector2) -> void:",1)[1].split(
    "func _remember_jump_flick_sample",1)[0]
assert release.index("_request_combo_side_kick(kick_flick_direction)")<release.index(
    "_request_combo_bash()")

kick_start=m.split("func _start_back_somersault() -> bool:",1)[1].split(
    "func _back_somersault_arc_offset(",1)[0]
assert "back_somersault_launched = false" in kick_start
assert 'rig.call("start_back_somersault")' in kick_start
kick=m.split("func _advance_back_somersault(delta: float) -> void:",1)[1].split(
    "func _cancel_back_somersault(",1)[0]
assert kick.index("_advance_homing_toward_target(strike_dt, BASH_REACH)")<kick.index(
    'rig.call("set_back_somersault_progress",')
assert kick.index("back_somersault_hit_checked = true")<kick.index(
    "back_somersault_launched = true")<kick.index(
    "if back_somersault_launched:")
assert "back_somersault_start = player.position" in kick
assert "_capture_back_somersault_retreat_direction()" in kick
assert "_move_player_swept(Vector3(arc_delta.x, 0.0, arc_delta.z), true)" in kick
assert "BACK_SOMERSAULT_REAR_FLIGHT_SECONDS" in kick
assert "if back_somersault_hit:" in kick
assert "_begin_landing(true)" in kick
assert 'rig.call("finish_jump", false, false)' in kick
assert "_register_side_kick_hit()" in kick

fx=m.split("var tracking_exhaust: bool = (",1)[1].split(
    'rig.call("update_back_thruster_fx",',1)[0]
for state in ["MELEE_APPROACH","DASH","STRIKE_TRACK","STRIKE","BASH_TRACK","BASH","BACK_KICK_TRACK"]:
    assert "combat_state == CombatState."+state in fx
assert "var normal_kick_exhaust: bool = (kick_side_this_frame != 0" in fx
assert "or somersault_this_frame)" in fx
assert "var normal_attack_exhaust: bool = normal_melee_exhaust or normal_kick_exhaust" in fx
assert "and not back_somersault_hit_checked" in fx
assert "back_somersault_launched and not thruster_accel_previous_somersault" in fx
motion=(R/"scripts/sera_motion_direction.gd").read_text(encoding="utf-8")
assert "MOTION_DIRECTION.exhaust_direction(" in fx
assert "normal_attack_exhaust, tracking_exhaust, stepping_this_frame," in fx
assert "if normal_attack_exhaust and not tracking_exhaust" in motion
assert "normal_attack_exhaust)" in m
assert "back_somersault_launched, back_somersault_direction," in fx
assert "if somersault_this_frame and somersault_launched:" in motion
assert "direction_of_exhaust = -somersault_direction" in motion

clips={a["name"]:a for a in source["animations"]}
assert math.isclose(float(clips["Kick_b"]["length"]),0.79167,rel_tol=0.02)
assert math.isclose(float(clips["Melee3"]["length"]),0.83333,rel_tol=0.001)
print("V284_CARDINAL_MELEE_CONTACT_STATIC_PASS")

assert "return INPUT_GESTURES.combo_kick_side(flick)" in m
