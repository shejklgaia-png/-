#!/usr/bin/env python3
"""v139: staged 3D SERA entrance, enlarged fitted pose and low placement.

Static/source and view-box geometry only; Android/Godot graphical verification
still required.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")

assert 'config/name="SERA v144 - Torso-anchored straight transfer"' in p
assert 'const CUSTOMIZE_ENTRANCE_SECONDS: float = 0.28' in s
assert 'const CUSTOMIZE_BOTTOM_GAP_PIXELS: float = 10.0' in s
assert 'const CAMERA_TRANSITION_SECONDS: float = 0.18' in s
assert 'const CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.435' in s
assert 'allowed_width * 0.97' in s
assert 'var bottom: float = minf(view.y * 0.615,' in s
assert 'square.position.y - maxf(12.0, view.y * 0.012)' in s

def section(a,b):
    return s.split("func "+a,1)[1].split("func "+b,1)[0]

show = section("_show_customization_preview() -> void:",
               "_apply_customization_entrance(")
animate = section("_apply_customization_entrance(progress: float,",
                  "_customization_entrance_arrived(")
arrived = section("_customization_entrance_arrived(final_world: Transform3D) -> void:",
                  "_restore_customization_preview()")
restore = section("_restore_customization_preview() -> void:","_customization_screen_bounds()")
fit = section("_fit_customization_preview() -> void:",
              "_constrain_customization_preview_to_safe_area()")
constrain = section("_constrain_customization_preview_to_safe_area() -> void:",
                    "_is_customization_drag_zone(")
rotate = section("_rotate_customization_preview(delta_x: float) -> void:",
                 "_update_projected_silhouettes()")
focus = section("_focus_arrived(target_name: String) -> void:",
                "_return_to_overview()")
back = section("_return_to_overview() -> void:", "_overview_arrived()")

assert show.index('var initial_world: Transform3D = sera_display_rig.global_transform') < show.index('_fit_customization_preview()')
assert show.index('_fit_customization_preview()') < show.index('var final_world: Transform3D = sera_display_rig.global_transform')
assert show.index('var final_world: Transform3D = sera_display_rig.global_transform') < show.index('_capture_customization_glow_layout()')
assert show.index('_capture_customization_glow_layout()') < show.index('sera_display_rig.global_transform = initial_world')
assert show.index('sera_display_rig.global_transform = initial_world') < show.index('customize_entrance_tween = create_tween()')
assert 'customize_entrance_tween.set_trans(Tween.TRANS_CUBIC)' in show
assert 'customize_entrance_tween.set_ease(Tween.EASE_IN_OUT)' in show
assert 'customize_entrance_tween.tween_method(_apply_customization_entrance.bind(' in show
assert '0.0, 1.0, CUSTOMIZE_ENTRANCE_SECONDS)' in show
assert 'in_transition = true' in show
assert 'start_camera_local.interpolate_with(' in animate
assert 'end_camera_local, progress)' in animate
assert 'sera_display_rig.global_transform = final_world' in arrived
assert '_capture_sera_silhouette(sera_display_rig)' in arrived
assert 'in_transition = false' in arrived
assert 'customize_entrance_tween.kill()' in restore
assert '_show_customization_preview()' not in focus
assert 'if target_name == "CUSTOMIZE":' in back or 'if focused_target == "CUSTOMIZE" and customize_preview_active:' in back
selected = section("_select_target(target_name: String) -> void:", "_focus_arrived(")
assert '_show_customization_preview()' in selected
assert selected.index("_show_customization_preview()") < selected.index("_move_camera(")
assert '_restore_customization_preview()' in back

assert fit.count('bottom_limit - CUSTOMIZE_BOTTOM_GAP_PIXELS - rect.end.y') == 1
assert constrain.count('bottom_limit - CUSTOMIZE_BOTTOM_GAP_PIXELS - rect.end.y') == 1
assert '_constrain_customization_preview_to_safe_area()' not in rotate
assert '_update_customization_glow()' not in rotate
assert 'customize_preview_scale =' not in rotate
assert 'customize_preview_position' not in rotate

# Simulate layout dimensions at representative portrait screen sizes.
for width,height in ((720,1280),(658,1168),(1080,1920)):
    square_side = min(width*.435, height*.28)
    square_top = .865*height - square_side
    preview_bottom = min(.615*height,square_top-max(12.,height*.012))
    target_bottom = preview_bottom-10.0
    intended_gap = square_top - target_bottom
    preview_top = height*.10
    assert preview_top < target_bottom < square_top
    assert intended_gap >= 22.0
    width_target = min(width*.435,square_side*.97)
    assert width_target <= square_side
    assert width_target > .39*width
assert abs((.865*1280-313.2)-(min(.615*1280,(.865*1280-313.2)-max(12.,.012*1280))-10.0)-25.36) < 0.1

print("v139 animated exhibit-to-preview transform, low fit and fixed yaw: STATIC PASS")
print("Godot/Android visual render and input testing: NOT TESTED")
