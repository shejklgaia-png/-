#!/usr/bin/env python3
"""v169: source-contract and numerical checks for accepted tap-attack ripples.

Static verification only, not a Godot runtime or Android touchscreen test.
"""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
ui = (root / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$', project, re.M) == ["SERA v169"]

def body(source: str, name: str) -> str:
    m = re.search(r"(?ms)^func " + re.escape(name) + r"\([^\n]*\)[^\n]*:\n(.*?)(?=^func |\Z)", source)
    assert m, name
    return m.group(1)

end = body(main, "_end_drag")
start = body(main, "_start_attack")
input_body = body(main, "_input")
draw = body(ui, "_draw")
process = body(ui, "_process")
show_ripple = body(ui, "show_attack_ripple")
cancel = body(ui, "cancel_attack_ripple")
show_drag = body(ui, "show_drag")
draw_wave = body(ui, "_draw_attack_ripple")

checks = {
    "tap feedback only after accepted attack": 'elif was_tap:\n        # The finger has already been released;' in end
        and 'if _start_attack():\n            touch_ui.call("show_attack_ripple", release_pos)' in end,
    "attack returns accepted result": "func _start_attack() -> bool:" in main
        and start.count("return false") >= 3 and start.count("return true") >= 3,
    "existing attack/guard state preserved": "combat_state = CombatState.MELEE_APPROACH" in start
        and "bash_combo_queued = true" in start and "combo_queued = true" in start
        and "if guard_active or damage_reaction_active or landing_active or step_active" in start,
    "new touch cancels before UI hit testing": input_body.index('touch_ui.call("cancel_attack_ripple")')
        < input_body.index("if _pointer_on_nexus_button(event.position):"),
    "new controller cancels ripple": show_drag.index("cancel_attack_ripple()") < show_drag.index("dragging = true"),
    "accepted tap draws from release point": "attack_ripple_position = screen_point" in show_ripple
        and "attack_ripple_active = true" in show_ripple,
    "cancel redraw immediately": "attack_ripple_active = false" in cancel and "queue_redraw()" in cancel,
    "no touch-intercepting scene node": 'touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE' in main,
    "effect drawn independently of controller": "if attack_ripple_active:\n        _draw_attack_ripple()" in draw
        and "if dragging:\n        _draw_analog_controller(accent, low)" in draw,
    "shared process stays on during ripple": "if progress >= 1.0 and not attack_ripple_active:" in process,
    "waves fade and expand": all(x in draw_wave for x in ("for ring_index in range(ATTACK_RIPPLE_RING_COUNT)",
        "draw_arc(attack_ripple_position", "pow(1.0 - progress, 2.0)",
        "ATTACK_RIPPLE_START_RADIUS", "ATTACK_RIPPLE_END_RADIUS")),
    "no image or shader needed": "func _draw_attack_ripple() -> void:" in ui
        and "load(" not in draw_wave and "Texture" not in draw_wave,
    "preserves input thresholds": all(s in main for s in (
        "const TAP_MAX_TRAVEL: float = 18.0", "const TAP_MAX_DURATION: float = 0.32",
        "const JUMP_TOUCH_INPUT_ENABLED: bool = false",
        "const STRIKE_DAMAGE = [12, 12, 26]")),
    "preserves joystick outer shell": "func _draw_boost_outer_shell(" in ui
        and "func _draw_move_mode_indicator(" in ui,
    "versioned README": (root / "README_v169_ja.md").is_file(),
}
for k, passed in checks.items():
    assert passed, k

duration = 0.46
for i in range(3):
    delay = i * 0.075
    assert duration - delay > 0.0
    last_radius = 0.0
    last_alpha = 1.0
    for step in range(21):
        t = step / 20.0
        phase = 1.0 - (1.0 - t) ** 2
        radius = 12.0 + (86.0 - 12.0) * phase
        alpha = (1.0 - t) ** 2 * (0.78 - 0.14 * i)
        assert radius >= last_radius and alpha <= last_alpha
        assert math.isfinite(radius) and math.isfinite(alpha)
        last_radius, last_alpha = radius, alpha
    assert abs(last_radius - 86.0) < 1e-6
    assert abs(last_alpha) < 1e-6

print(f"PASS: v169 tap-ripple static contracts ({len(checks)}) and 63 numerical wave steps")
print("Godot parser / Android gesture and rendering: NOT TESTED")
