#!/usr/bin/env python3
"""v291: camera-center selectable boss parts, symmetric two-hand slot and sheath mesh orientation."""
from pathlib import Path
import json,re,math
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text()
parts=(root/"scripts/target_parts.gd").read_text()
equipment=(root/"scripts/sera_equipment.gd").read_text()
rig=(root/"scripts/sera_rig.gd").read_text()
nexus=(root/"scripts/command_nexus.gd").read_text()
overlay=(root/"scripts/touch_overlay.gd").read_text()
project=(root/"project.godot").read_text()
source=json.loads((root/"assets/sera_source.json").read_text())
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=291

# Camera-forward auto selector: no distance threshold, forced LOS occlusion,
# or SERA-relative front-dot cutoff. Existing lock has a modest hysteresis.
sel=parts.split("func select_camera_front_part(view_camera: Camera3D, current: String) -> String:",1)[1].split(
    "func select_front_part(",1)[0]
assert "view_camera.unproject_position(aim)" in sel
assert "view_camera.is_position_behind(aim)" in sel
assert "normalized_offset.length()" in sel
assert "CAMERA_PART_DISTANCE_TIE_WEIGHT: float = 0.001" in parts
assert "score += minf(0.03," in sel
assert "current_score <= best_score + CAMERA_PART_LOCK_HYSTERESIS" in sel
assert "core_box.intersects_segment" not in sel
assert "straight_depth" not in sel
manual=parts.split("func get_visible_part_ids(",1)[1]
assert "core_box.intersects_segment" not in manual
assert "other_contact" not in manual

physics=main.split("func _physics_process(delta: float) -> void:",1)[1].split(
    "func _process(delta: float) -> void:",1)[0]
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in physics
assert "if not combo_held:" in physics
assert 'var locked_part_broken: bool = (' in physics
assert "player.look_at(player.global_position + aim, Vector3.UP)" in physics
switch=main.split("func _switch_lock_screen_direction(direction: int) -> void:",1)[1].split(
    "func _update_target_marker_projection(",1)[0]
assert "get_visible_part_ids" in switch
assert "wrapped_id" in switch and "wrapped_x" in switch
assert "forward_id if not forward_id.is_empty() else wrapped_id" in switch
assert "core_box.intersects_segment" not in switch
toggle=main.split("func _toggle_auto_lock_mode() -> void:",1)[1].split(
    "func _controller_start_area_contains(",1)[0]
assert '"select_camera_front_part", camera, ""' in toggle
reticle=main.split("func _update_target_marker_projection() -> void:",1)[1].split(
    "func _step_speed_for_player_position(",1)[0]
assert 'clampf(screen_position.x, edge_margin' in reticle
assert '"set_target_marker_projection", safe_screen, true, is_offscreen' in reticle
assert "var target_marker_offscreen: bool = false" in overlay
assert "if target_marker_offscreen:" in overlay

# Two-hand occupancy is generic in both directions. Saved offhand selection
# remains in memory while its visible meshes and its controls are disabled.
assert 'TWO_HANDED_WEAPON_LABELS: Dictionary = {"K": "KATANA"}' in equipment
blocked=equipment.split("func two_handed_blocker(slot: String) -> Dictionary:",1)[1].split(
    "func select_part(",1)[0]
assert '"weapon_r" if slot == "weapon_l" else "weapon_l"' in blocked
assert "TWO_HANDED_WEAPON_LABELS.has(other_id)" in blocked
assert '"name": str(TWO_HANDED_WEAPON_LABELS[other_id])' in blocked
select=equipment.split("func select_part(slot: String, set_id: String, persist: bool = true) -> bool:",1)[1].split(
    "func _apply_part_visibility(",1)[0]
assert "if persist and not two_handed_blocker(slot).is_empty():" in select
show=equipment.split("func _apply_part_visibility() -> void:",1)[1].split(
    "func _set_katana_mesh_display(",1)[0]
assert 'two_handed_blocker("weapon_l")' in show
assert 'two_handed_blocker("weapon_r")' in show
assert 'piece.visible = not reserved and set_id == str(selected.get(slot, "A"))' in show
assert "get_equipment_two_handed_blocker(slot: String) -> Dictionary:" in rig
refresh=nexus.split("func _refresh_equipment_controls() -> void:",1)[1].split(
    "func _tap_equipment_control(",1)[0]
assert 'row.modulate = Color(0.48, 0.50, 0.54, 1.0)' in refresh
assert 'label.text = str(blocker.get("name", "TWO-HANDED"))' in refresh
assert 'row.modulate = Color.WHITE' in refresh
tap=nexus.split("func _tap_equipment_control(point: Vector2) -> bool:",1)[1].split(
    "func ",1)[0]
assert '"get_equipment_two_handed_blocker", slot' in tap
assert "if not blocker.is_empty():" in tap

# The authored Katana_l3 sheath mesh has a real +90deg element-local yaw.
# Godot previously imported local rotations only for Bird_, causing the
# left forearm saya mesh to point the wrong way.
assert 'str(parent.name).begins_with("Katana_")' in rig
assert "piece.quaternion = _blockbench_rotation(" in rig
groups={g["uuid"]:g for g in source["groups"]}
elements={e["uuid"]:e for e in source["elements"]}
rotated=[]
def scan(node,parents=()):
    if isinstance(node,str):
        e=elements[node]
        if "Katana_l3" in parents and abs(float(e.get("rotation",[0,0,0])[1])-90)<1e-4:
            rotated.append(e)
        return
    g=groups[node["uuid"]]
    for child in node.get("children",[]):
        scan(child, parents+(g["name"],))
for root_node in source["outliner"]:scan(root_node)
assert len(rotated)==1,(len(rotated),rotated)
assert "Katana_r_saya" in [g["name"] for g in source["groups"]]
assert "Katana_r_nukimi" in [g["name"] for g in source["groups"]]
print("V291_CAMERA_LOCK_TWOHAND_SAYA_STATIC_PASS")
