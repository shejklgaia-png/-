#!/usr/bin/env python3
"""v344: very close projected damage numbers offset but still slightly overlap."""
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
assert "MAX_ACCEPTABLE_OVERLAP: float = 0.29" in space

choices=((0,0),(44,-18),(-44,-18),(44,18),(-44,18),(0,-32),(0,32),
         (64,-8),(-64,-8),(64,24),(-64,24),(0,-53),(0,53))
def overlap(a,b):
    dx=abs(a[0]-b[0]);dy=abs(a[1]-b[1])
    return max(0,64-dx)/64*max(0,40-dy)/40
def choose(base,occupied):
    if all(overlap(base,p)<=.29 for p in occupied):return (0,0)
    best=None
    for v in choices[1:]:
        p=(base[0]+v[0],base[1]+v[1])
        values=[overlap(p,o) for o in occupied]
        if max(values)<=.29:return v
        score=sum(values)*100+(v[0]**2+v[1]**2)**.5*.2
        if best is None or score<best[0]:best=(score,v)
    return best[1]
base=(220,350)
assert choose(base,[])==(0,0)
v=choose(base,[base])
assert v==(44,-18),v
p=(base[0]+v[0],base[1]+v[1])
assert .10<overlap(base,p)<.29
assert choose((440,600),[base])==(0,0)
used=[base]
for i in range(5):
    off=choose(base,used)
    position=(base[0]+off[0],base[1]+off[1])
    assert abs(off[0])<=64 and abs(off[1])<=53
    used.append(position)
assert len(used)==6
print("PASS v344 gentle overlapping popup offsets, stable history and six hit numbers")
