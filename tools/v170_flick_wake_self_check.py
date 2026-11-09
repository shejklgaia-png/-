#!/usr/bin/env python3
"""v170 directional V-wake static checks, not an Android/Godot runtime test."""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
ui = (root / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$', project, re.M) == ["SERA v170"]

def body(source: str, name: str) -> str:
    match = re.search(r"(?ms)^func " + re.escape(name) + r"\([^\n]*\)[^\n]*:\n(.*?)(?=^func |\Z)", source)
    assert match, name
    return match.group(1)

release = body(main, "_end_drag")
input_ = body(main, "_input")
back = body(main, "_start_back_step")
side = body(main, "_start_side_step")
process = body(ui, "_process")
draw = body(ui, "_draw")
wake = body(ui, "_draw_flick_wake")
show = body(ui, "show_flick_wake")
stop = body(ui, "cancel_flick_wake")
drag = body(ui, "show_drag")
checks = {
    "side/back flicks trigger only after accepted": all(x in release for x in (
        "if _start_back_step():", "if _start_side_step(flick_direction):",
        'touch_ui.call("show_flick_wake", pointer_origin, release_pos)')),
    "all Bash flicks supported": all(x in release for x in (
        'if bash_requested and _request_combo_bash():',
        "if guard_bash_requested:",
        'touch_ui.call("show_flick_wake", guard_flick_origin, release_pos)')),
    "side/back report success": ("func _start_back_step() -> bool:" in main
        and "func _start_side_step(side: int) -> bool:" in main
        and all(x in back for x in ("return false", "return true"))
        and all(x in side for x in ("return false", "return true"))),
    "optional jump keeps debug flag": ('const JUMP_TOUCH_INPUT_ENABLED: bool = false' in main
        and 'if jump_active:' in release),
    "new press stops both effects": (input_.count('touch_ui.call("cancel_gesture_effects")') == 2
        and input_.index("cancel_gesture_effects") < input_.index("_pointer_on_nexus_button")),
    "joystick cancels release FX": ("cancel_gesture_effects()" in drag
        and drag.index("cancel_gesture_effects()") < drag.index("dragging = true")),
    "wake source direction": ("flick_wake_tip = end_point" in show
        and "displacement.normalized()" in show),
    "wave lifetime": ("FLICK_WAKE_DURATION: float = 0.43" in ui
        and "if flick_wake_elapsed >= FLICK_WAKE_DURATION:" in process),
    "shared animation process": "not attack_ripple_active and not flick_wake_active" in process,
    "instant cancellation": "flick_wake_active = false" in stop and "queue_redraw()" in stop,
    "three curved V pairs": all(x in wake for x in (
        "for band in range(FLICK_WAKE_BANDS)",
        "for side in [-1.0, 1.0]:", "sin(t * PI)",
        "flick_wake_forward * back", "draw_polyline(points, stroke")),
    "wake visible in HUD": "if flick_wake_active:\n        _draw_flick_wake()" in draw,
    "tap ripple preserved": ("func _draw_attack_ripple() -> void:" in ui
        and 'touch_ui.call("show_attack_ripple", release_pos)' in release),
    "controller and lock preserved": all(x in ui for x in (
        "func _draw_analog_controller(", "func _draw_boost_outer_shell(",
        "func _draw_move_mode_indicator(", "func set_melee_in_range(")),
    "unchanged input thresholds": all(x in main for x in (
        "const TAP_MAX_TRAVEL: float = 18.0",
        "const TAP_MAX_DURATION: float = 0.32",
        "const STRIKE_DAMAGE = [12, 12, 26]")),
    "README version": (root / "README_v170_ja.md").is_file(),
}
for name, result in checks.items():
    assert result, name

# Four cardinal directions, three bands, 21 frames each. Every pair must
# extend behind the release and spread away from the central wake axis.
numerical = 0
for direction in ((1, 0), (-1, 0), (0, 1), (0, -1)):
    for band in range(3):
        prev_alpha = 1.0
        for frame in range(21):
            t = frame / 20.0
            alpha = (1-t)**2 * (0.84-0.14*band)
            back = 8.0 + (110.0-8.0)*t
            spread = 13.0 + (53.0-13.0)*t
            assert alpha <= prev_alpha + 1e-9
            assert back > 0 and spread > 0
            for side_value in (-1, 1):
                x = direction[0] * -back + direction[1] * (-side_value * spread)
                y = direction[1] * -back + (-direction[0]) * (-side_value * spread)
                assert math.isfinite(x) and math.isfinite(y)
            prev_alpha = alpha
            numerical += 1
print(f"PASS: v170 V-wake {len(checks)} static checks, {numerical} numerical states")
print("Godot and Android runtime: NOT TESTED")
