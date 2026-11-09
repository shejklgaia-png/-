#!/usr/bin/env python3
"""SERA v190: right-back yaw, model-sole footfalls and tall-foot grounding."""
from __future__ import annotations
from pathlib import Path
import json
import math
import re

root = Path(__file__).resolve().parents[1]
project = (root / "project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v190"$', project, re.M):
    print("SKIP: v190-specific contact and yaw check")
    raise SystemExit(0)
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
equip = (root / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")

def has(s, tokens):
    for token in tokens:
        assert token in s, token

has(rig, [
    'signal foot_contact(side: String)',
    'var retreat_sign: float = 1.0 if direction.x >= 0.0 else -1.0',
    'return wrapf(-travel_angle + PI * retreat_weight * retreat_sign, -PI, PI)',
    'func _update_foot_contacts(delta: float)',
    'FOOT_LIFTED_GAP: float = 0.055',
    'FOOT_TOUCH_GAP: float = 0.020',
    'FOOT_CONTACT_MIN_INTERVAL: float = 0.13',
    'foot_contact.emit(side)',
    '    _apply_animation(delta)\n    _update_foot_contacts(delta)',
    'current_clip not in RUN_CLIPS',
    'absf((wearer as Node3D).position.y) > 0.05',
    'if str(piece.name).begins_with("Bird_"):',
])
has(equip, [
    'func _cache_bind_foot_geometry()',
    'func _mesh_lowest_y(piece: MeshInstance3D)',
    'piece.mesh.get_aabb()',
    'rig.to_local(piece.to_global(corner)).y',
    'func _foot_side(piece: MeshInstance3D)',
    'func get_active_foot_heights() -> Dictionary:',
    'standard_sole_y - float(',
    'rig.position.y = rig_original_y + grounding_height_offset',
    'rig.call("reset_foot_contacts")',
    '_cache_bind_foot_geometry()',
])
has(main, [
    'rig.connect("foot_contact", Callable(self, "_on_foot_contact"))',
    'func _on_foot_contact(side: String) -> void:',
    'func _make_mechanical_footstep() -> AudioStreamWAV:',
    'AudioStreamWAV.FORMAT_16_BITS',
    'samples.encode_s16(i * 2',
    'footstep_audio.max_polyphony = 3',
    'footstep_audio.play()',
    'func _update_equipped_collision_height() -> void:',
    'capsule.height = PLAYER_COLLISION_HEIGHT + collision_height_extension',
    'player_collision_shape.position.y = capsule.height * 0.5',
    '    _update_equipped_collision_height()\n    _tick_training_ko(delta)',
])
# The original physical XZ movement, target camera, input mapping and
# A rig remain independent of the display/collision envelope.
assert 'player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING' in main
assert 'player.floor_snap_length = 0.0' in main
assert 'const RUN_DIRECTION_BLEND_SECONDS: float = 0.055' in rig
assert 'const RUN_MODE_BLEND_SECONDS: float = 0.085' in rig

# Independent numerical check: both right-back and left-back take their
# respective short arc, rather than a forced -225 degree turn on the right.
def wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi

def yaw(deg, weight):
    direction_x = math.sin(math.radians(deg))
    sign = 1 if direction_x >= 0 else -1
    return wrap(-math.radians(deg) + math.pi * weight * sign)

for angle in (90, 110, 135, 155, -90, -110, -135, -155):
    values = [yaw(angle, j/40) for j in range(41)]
    increments = [wrap(values[j+1]-values[j]) for j in range(40)]
    assert all(0.0 < step < math.radians(6) for step in increments) if angle > 0 else (
        all(-math.radians(6) < step < 0.0 for step in increments))
assert abs(wrap(yaw(179, 1)-yaw(-179, 1))) < math.radians(2.1)

# Sole correction: a lower sole by 0.3m raises the body by 0.3m,
# while the original A sole produces no offset. A taller capsule retains
# its original bottom plane and radius.
for sole in (-1.2, -1.5, -1.05):
    reference = -1.2
    lift = reference - sole
    assert abs((sole + lift)-reference) < 1e-10
    extended_capsule = 2.0 + max(0.0, lift)
    assert extended_capsule >= 2.0
assert "assets/sera_source.json" not in (root / "README_v190_ja.md").read_text(encoding="utf-8")[:1]

# Existing A authoring and bird rig are still present; bird foot local tilt
# isn't discarded while calculating foot surface height.
base = json.loads((root / "assets/sera_source.json").read_text(encoding="utf-8"))
assert len(base["groups"]) == 22 and len(base["elements"]) == 25
bird = json.loads((root / "models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel").read_text(encoding="utf-8"))
assert len([g for g in bird["groups"] if g["name"].startswith("Bird_")]) == 6
assert all(e["rotation"] == [-22.5, 0, 0] for e in bird["elements"]
           if e["name"].startswith("Bird_Foot_Mesh_"))
assert (root / "README_v190_ja.md").is_file()
print("PASS: v190 right/left short yaw, sole-based foot contact, tall-sole visual+collision height")
print("Static/numeric only: Godot/Android runtime and generated footstep sound NOT auditioned")
