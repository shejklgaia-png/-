#!/usr/bin/env python3
"""No-dependency checks for the developer parameter/dependency audit tools."""
from pathlib import Path

from sera_parameter_audit import ROOT, TuningAuditError, audit
from sera_change_impact import dependencies_of, inventory, impact_report, suggested_tests

main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
ui = (ROOT / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
values = audit(main, ui)
assert values["run_radius_px"] > values["run_deadzone_px"] > 0
assert values["boost_enter_distance_px"] > values["boost_leave_distance_px"]
# Intentional mismatches must fail closed, not silently pass.
try:
    audit(main, ui.replace("const CONTROLLER_RUN_RADIUS: float = 105.0",
                           "const CONTROLLER_RUN_RADIUS: float = 106.0"))
except TuningAuditError:
    pass
else:
    raise AssertionError("RUN radius drift must fail")
try:
    audit(main.replace('touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)',
                       'touch_ui.call("show_drag", pointer_origin, pointer_location, 999.0)'), ui)
except TuningAuditError:
    pass
else:
    raise AssertionError("HUD path disconnect must fail")
refs = dependencies_of('const A = preload("res://scripts/sera_rig.gd")\n'
                       'const B = load("res://scripts/touch_overlay.gd")\n')
assert refs == {"scripts/sera_rig.gd", "scripts/touch_overlay.gd"}, refs
inv = inventory()
assert "scripts/main.gd" in inv and "scripts/sera_rig.gd" in inv
assert "scripts/sera_rig.gd" in inv["scripts/main.gd"]["depends_on"]
assert "scripts/main.gd" in inv["scripts/sera_rig.gd"]["used_by"]
report = impact_report(["scripts/main.gd"])
assert report["changed_or_queried"]["scripts/main.gd"]["present_in_scripts"]
tests = suggested_tests(["scripts/main.gd"])
assert any("v246_fullscreen_controller_self_check.py" in x for x in tests)
assert all((ROOT / p).is_file() for p in tests)
print("PASS: parameter coherence, mismatch detection, source dependency graph, change-impact hints")
print("No Godot/Android runtime or dynamic-call soundness claim is made.")
