#!/usr/bin/env python3
"""Historical authored second windup and physical somersault; v340 no orbit."""
from pathlib import Path
import json,re
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
assets=json.loads((r/"assets/sera_source.json").read_text())
assert int(re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text()).group(1))>=340
clips={a["name"]:a for a in assets["animations"]}
for name,t,key in (("Kick_r",.33333,"SIDE_KICK_SECOND_WINDUP_R"),("Kick_l",.41667,"SIDE_KICK_SECOND_WINDUP_L")):
    assert f"const {key}: float = {t}" in m
    assert abs(float(clips[name]["length"])-1.0)<1e-5
    assert any(abs(float(frame["time"])-t)<1e-4
        for anim in clips[name]["animators"].values()
        for frame in anim.get("keyframes",[]))
advance=m.split("func _advance_side_step(delta: float) -> void:",1)[1].split("func _move_player_swept(",1)[0]
for token in ("if side_kick_active:","side_kick_travel_anchor_set = true",
              "_advance_homing_toward_target(second_chase_dt, SIDE_KICK_REACH)",
              "side_kick_linear_active = true","side_kick_linear_start_elapsed = step_elapsed",
              "side_kick_linear_direction * side_kick_linear_distance * line_progress",
              "if previous_progress < impact_progress and progress >= impact_progress:"):
    assert token in advance,token
assert "step_signed_angle * orbit_progress" not in advance
assert "_configure_side_kick_orbit" not in m
back=m.split("func _advance_back_somersault(delta: float) -> void:",1)[1].split("func _cancel_back_somersault(",1)[0]
for token in ("var angle: float = TAU * progress","rig.rotation.x = angle",
              "BACK_SOMERSAULT_VISUAL_PIVOT_HEIGHT * (1.0 - cos(angle))",
              'rig.call("set_back_somersault_progress", pose_progress)'):
    assert token in back,token
assert "func _back_somersault_arc_offset(progress: float) -> Vector3:" in m
assert 'const BACK_SOMERSAULT_CLIP: String = "Kick_b"' in rig
print("V280_KICK_MOTION_STATIC_PASS (authored kicks + original somersault)")
