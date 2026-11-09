#!/usr/bin/env python3
"""SERA v201: lock BOOST re-entry after EN failure until an inward touch move."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
version = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert version and int(version.group(1)) >= 201

assert "var boost_rearm_required: bool = false" in main
begin = main.split("func _begin_drag(pos: Vector2) -> void:", 1)[1].split(
    "func _analog_stick_direction(", 1)[0]
assert "boost_rearm_required = false" in begin
gesture = main.split("func _update_boost_gesture(delta: float) -> void:", 1)[1].split(
    "func _end_drag(release_pos: Vector2)", 1)[0]
for token in (
    "if energy_exhausted:",
    "boost_rearm_required = true",
    "if boost_rearm_required:",
    "if finger_distance >= DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:",
    "boost_confirm_elapsed = 0.0\n            return\n        boost_rearm_required = false",
    "elif finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO:",
    "boost_confirm_elapsed >= BOOST_CONFIRM_SECONDS:",
):
    assert token in gesture, token
assert gesture.index("if boost_rearm_required:") < gesture.index(
    "if movement_boost_active:\n        # Hysteresis:")
physics = main.split("func _physics_process(delta: float) -> void:", 1)[1]
for token in (
    "var boost_energy_ok: bool = _spend_energy(",
    "if not boost_energy_ok or energy_exhausted:",
    "boost_rearm_required = true",
    "movement_boost_active = false",
    'touch_ui.call("set_movement_boost", false)',
):
    assert token in physics, token
assert physics.index("boost_rearm_required = true") < physics.index(
    "_update_boost_speed(delta)")

# Numerical state-model checks for the existing entry/exit thresholds.
ENTRY, EXIT, CONFIRM = 168 * 1.10, 168 * 0.95, 0.10
class Gesture:
    def __init__(self):
        self.active, self.locked, self.elapsed = False, False, 0.0

    def energy_stop(self):
        self.active, self.locked, self.elapsed = False, True, 0.0

    def tick(self, distance, dt):
        if self.locked:
            if distance >= EXIT:
                self.elapsed = 0.0
                return self.active
            self.locked = False
        if self.active:
            if distance < EXIT:
                self.active, self.elapsed = False, 0.0
        elif distance >= ENTRY:
            self.elapsed += dt
            if self.elapsed >= CONFIRM:
                self.active = True
        else:
            self.elapsed = 0.0
        return self.active

g = Gesture()
for _ in range(7):
    g.tick(190.0, 0.016)
assert g.active
# Sustained valid BOOST has no RUN frames.
for _ in range(1000):
    assert g.tick(190.0, 0.016)
# Even when energy later recovers, stationary hold stays RUN after a stop.
g.energy_stop()
for _ in range(3000):
    assert not g.tick(190.0, 0.016)
assert g.locked and g.elapsed == 0.0
# An intentional inward drag re-arms, then the standard 0.10s hold starts.
assert not g.tick(159.0, 0.016)
assert not g.locked
assert not g.tick(190.0, 0.050)
assert not g.tick(190.0, 0.049)
assert g.tick(190.0, 0.002)
assert g.tick(175.0, 0.016)  # Hysteresis remains.
assert not g.tick(158.0, 0.016)
# A new touch clears the previous lockout.
g.energy_stop()
g = Gesture()
for _ in range(7):
    g.tick(190.0, 0.016)
assert g.active
print("PASS: v201 BOOST held-input lockout, deliberate rearm, unchanged hysteresis")
print("Godot / Android runtime: NOT TESTED")
