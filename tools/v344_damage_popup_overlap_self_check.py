#!/usr/bin/env python3
"""v344: overlapping projected damage labels get a small frozen offset."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
m=(root/"scripts/main.gd").read_text(encoding="utf-8")
space=(root/"scripts/sera_damage_popup_spacing.gd").read_text(encoding="utf-8")
presenter=(root/"scripts/sera_hit_fx_presentation.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v344"' in project
assert 'preload("res://scripts/sera_damage_popup_spacing.gd")' in m
assert "const DAMAGE_POPUP_HISTORY_CAPACITY: int = 5" in m
assert "func _show_target_damage_popup(amount: int, hit_world: Vector3) -> void:" in m
assert m.count('_show_target_damage_popup(int(result["applied_damage"]),')==3
assert 'damage_popup_history.append({' in m
assert 'layer.move_child(damage_label, layer.get_child_count() - 1)' in m
assert 'history_label.position = damage_label.position' in m
assert 'previous["remaining"] = damage_popup_remaining' in m
assert 'previous["world"] = impact_origin' in m
assert 'previous["offset"] = damage_popup_offset' in m
assert 'DAMAGE_POPUP_SPACING.choose_offset(' in m
assert "damage_label.position += damage_popup_offset" in m
assert "history_label.position += entry[\"offset\"] as Vector2" in m
assert "damage_popup_history[i] = entry" in m
assert "HIT_FX_PRESENTATION.present_damage_popup(" in m
assert "present_damage_popup(label: Label, view_camera: Camera3D," in presenter
assert "view_camera.unproject_position(impact_origin + Vector3.UP * 0.28)" in presenter
assert "(0.58 - remaining) * 75.0" in presenter
assert 'label.modulate.a = minf(1.0, remaining / 0.17)' in presenter
assert "static func choose_offset(" in space
assert "static func overlap_ratio(" in space
assert "APPROX_TEXT_WIDTH: float = 64.0" in space
assert "APPROX_TEXT_HEIGHT: float = 40.0" in space

# Replicate the exact scoring to validate the intended soft overlap rather
# than relying on vague "spread" offsets or clipping all text apart.
options=((0,0),(44,-18),(-44,-18),(44,18),(-44,18),(0,-32),(0,32),
         (64,-8),(-64,-8),(64,24),(-64,24),(0,-53),(0,53))
def overlap(a,b):
    dx=abs(a[0]-b[0]);dy=abs(a[1]-b[1])
    return max(0,64-dx)/64*max(0,40-dy)/40
def choose(base,occupied):
    if not occupied:return (0,0)
    return min(options,key=lambda v:
        sum(overlap((base[0]+v[0],base[1]+v[1]),o)*120 for o in occupied)
        +abs(v[0])*.12+abs(v[1])*.5)
base=(220,350)
assert choose(base,[])==(0,0)
chosen=choose(base,[base])
assert chosen!=(0,0)
shifted=(base[0]+chosen[0],base[1]+chosen[1])
assert 0.01<overlap(base,shifted)<.38
assert max(abs(chosen[0]),abs(chosen[1]))<=64
assert choose((440,600),[base])==(0,0)
used=[base]
for _ in range(5):
    v=choose(base,used)
    p=(base[0]+v[0],base[1]+v[1])
    assert abs(v[0])<=64 and abs(v[1])<=53
    used.append(p)
assert len(used)==6
print("PASS v344 gentle popup spacing, stable per-hit offsets and 6 visible hits")
