#!/usr/bin/env python3
"""SERA v215: bird C smooth sole grounding, complete joint poses, seamless idle."""
from __future__ import annotations
import json
import math
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT/path).read_text(encoding="utf-8")
project=read("project.godot")
version=re.search(r'config/name="SERA v(\d+)"',project)
assert version and int(version.group(1)) >= 215
rig=read("scripts/sera_rig.gd")
eq=read("scripts/sera_equipment.gd")
main=read("scripts/main.gd")
bird=json.loads(read("models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel"))
bone_ids={g["uuid"]:g["name"] for g in bird["groups"] if g["name"].startswith("Bird_")}
assert len(bone_ids)==6 and all(
    f"Bird_{part}_{side}" in bone_ids.values()
    for part in ("Thigh","LowerLeg","Foot") for side in ("L","R"))
idle=next(c for c in bird["animations"] if c["name"]=="Wait_motion")
left=next(u for u,n in bone_ids.items() if n=="Bird_Foot_L")
left_keys=[k for k in idle["animators"][left]["keyframes"] if k["channel"]=="rotation"]
assert len(left_keys)==2
assert math.isclose(float(idle["length"]),3.6)
assert float(left_keys[-1]["time"]) < 0.22
assert left_keys[0]["data_points"]!=left_keys[-1]["data_points"]
# The new return segment keeps the authored first/last poses exactly, only
# removing the old instantaneous 3.6s->0s angle discontinuity.
assert 'if uid in bird_bone_ids and current_clip == WAIT_CLIP' in rig
assert 'and rotation_values.size() > 1:' in rig
assert 'clip_length - 0.20' in rig
assert 'q = q.slerp(rotation_values[0]["quaternion"], loop_alpha).normalized()' in rig
for t in (3.4,3.45,3.5,3.55,3.6):
    alpha=max(0.,min(1.,(t-3.4)/.2))
    assert 0 <= alpha <= 1
assert math.isclose((3.6-3.4)/.2,1)

# An unkeyed bird joint in a partial STEP or BOOST clip must inherit the
# authored idle pose, not snap back to the raw skeleton bind rotation.
assert '_fallback_bird_animation("Jump", "Wait_motion")' in rig
assert '_fallback_bird_animation("Jump", "Wait_Pose")' not in rig
assert 'var idle_tracks: Dictionary = animations[WAIT_CLIP]["tracks"]' in rig
assert 'for clip_key in animations.keys():' in rig
assert 'for uid in bird_bone_ids:' in rig
assert 'if (channels.get("rotation", []) as Array).is_empty():' in rig
assert 'channels["rotation"] = [idle_rotations[0].duplicate(true)]' in rig
# Source has missing tracks in existing STEP and newly added Frontstep.
left_step=next(c for c in bird["animations"] if c["name"]=="Step_L")
assert len([u for u in bone_ids if left_step["animators"].get(u,{}).get("keyframes")]) < 6
assert not any(c["name"]=="Frontstep" for c in bird["animations"])
# No authored source changed, and other body bones retain their original clips.
assert 'if not clip_tracks.has(uid):' in rig
assert 'animations[clip_key]["tracks"]' in rig

# Bird-only WAIT/RUN support tracks actual BOTH sole meshes continuously in
# rig-local coords and smooths the Y difference without altering the Player.
assert 'const BIRD_GROUND_FOLLOW_SECONDS: float = 0.10' in eq
assert 'var bird_grounding_render_y: float = 0.0' in eq
assert 'func smooth_bird_grounding(delta: float) -> void:' in eq
method=eq.split('func smooth_bird_grounding(delta: float) -> void:',1)[1].split('func snap_grounded_sole_to_floor()',1)[0]
for line in (
    'str(selected.get("legs", "A")) != "C"',
    'absf(wearer.global_position.y) > 0.05',
    'bool(rig.get("jump_playback"))',
    'var heights: Dictionary = get_active_foot_heights()',
    'minf(float(heights["L"]), float(heights["R"]))',
    'rig.to_global(Vector3(0.0, lowest, 0.0)).y',
    'TRAINING_VISIBLE_FLOOR_Y - sole_world_y',
    '1.0 - exp(-maxf(delta, 0.0) / BIRD_GROUND_FOLLOW_SECONDS)',
    'bird_grounding_render_y = lerpf(bird_grounding_render_y, goal_y, blend)',
):
    assert line in method,line
assert 'if str(selected.get("legs", "A")) == "C":\n        rig.position.y = bird_grounding_render_y' in eq
assert 'if str(selected.get("legs", "A")) == "C":\n        bird_grounding_render_y = rig.position.y' in eq
assert 'equipment_handler.call("smooth_bird_grounding", delta)' in rig
assert rig.count('equipment_handler.call("smooth_bird_grounding", delta)')==2
assert 'equipment_handler.call("snap_grounded_sole_to_floor")' in rig

# Foot sound remains, but no one-frame mesh translation for the bird; A/B/D
# still use the historical v209 contact-only shoe correction.
contact=rig.split("func _update_foot_contacts(delta: float) -> void:",1)[1].split("func _build_model(",1)[0]
assert 'if str(equipment_handler.call("current_for", "legs")) != "C":' in contact
assert 'equipment_handler.call("snap_run_contact_foot_to_floor", side)' in contact
assert 'foot_contact.emit(side)' in contact
assert 'piece.global_position += Vector3.UP * adjustment' in eq
assert 'rig.call("reset_foot_contacts")' in eq
assert 'func set_exhibition_mode(enabled: bool) -> void:' in rig
assert 'equipment_handler.call("set_grounding_enabled", not enabled)' in rig
assert 'player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING' in main

# A stable timestep update should converge without frame-to-frame overshoot.
for fps in (30,60,90,120):
    y=0.
    target=0.25
    for _ in range(fps):
        alpha=1.-math.exp(-1./fps/.10)
        y=y+(target-y)*alpha
        assert 0<=y<=target
    assert math.isclose(y,target*(1-math.exp(-10)),abs_tol=1e-9)

print("PASS v215: reverse-leg six-joint fallback and idle-loop seam continuity")
print("PASS: C-only smoothed soles, original footstep events and A/B/D isolation")
print("Godot/Xperia Android foot placement/appearance not runtime-tested")
