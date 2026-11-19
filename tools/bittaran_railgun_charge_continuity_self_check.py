#!/usr/bin/env python3
"""Railgun charge motor: source contract and independent time-step math.

The old 0.7s boundary used 100% instantaneous yaw tracking at weight=1,
while weight<1 used an exponential filter. This test rejects that jump
and proves the approved 30/s filter is frame-rate invariant.
"""
from __future__ import annotations

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = (ROOT / "scripts" / "bittaran_railgun.gd").read_text(encoding="utf-8")

def require(statement: bool, error: str) -> None:
    if not statement:
        raise AssertionError(error)

def constant(name: str) -> float:
    match = re.search(
        rf"(?m)^const {re.escape(name)}: float = ([0-9.]+)\s*$", SOURCE
    )
    require(match is not None, "missing current gameplay constant: " + name)
    return float(match.group(1))

def response(rate: float, dt: float, acquisition_weight: float) -> float:
    return 1.0 - math.exp(-rate * max(dt, 0.0) * acquisition_weight)

def main() -> None:
    rate = constant("CHARGE_TRACK_FILTER_PER_SECOND")
    require(abs(rate - 30.0) < 1e-9, "charge response changed without approval")
    require(abs(constant("TRACK_BLEND_SECONDS") - 0.7) < 1e-9,
            "approved 0.7-second entry timing changed")
    require(abs(constant("BEAM_TRACK_SPEED_MULTIPLIER") - 0.7) < 1e-9,
            "blue-sphere shrink must remain 0.7x")
    require(abs(constant("BEAM_ON_AXIS_SPEED_MULTIPLIER") - 0.85) < 1e-9,
            "beam on-axis speed must remain 0.85x")
    require(abs(constant("BEAM_GROUND_GAP_METERS") - 1.5) < 1e-9,
            "beam catch-up distance must remain 1.5m")
    track = SOURCE.split("func _track_player(", 1)[1].split(
        "\nfunc _show_charge(", 1
    )[0]
    require("if fast_charge_tracking:" in track, "missing rapid acquisition")
    require("actual = angle_error * charge_response" in track,
            "charge motor must always apply a continuous response")
    require(re.search(
        r"-CHARGE_TRACK_FILTER_PER_SECOND\s*\*\s*maxf\(delta, 0\.0\)"
        r"\s*\*\s*weight", track) is not None,
        "charge response must scale by delta and clamped acquisition weight")
    require("charge_response if weight < 1.0 else 1.0" not in track,
            "old instantaneous frame spike returned")
    require("actual = angle_error * (charge_response if" not in track,
            "acquisition must not bypass smoothing")
    for hz in (30, 60, 120, 240):
        dt = 1.0 / hz
        nearly = response(rate, dt, 0.999999)
        full = response(rate, dt, 1.0)
        require(0.0 < nearly < full < 1.0, f"{hz}Hz invalid gain bounds")
        require(full / nearly < 1.00001,
                f"{hz}Hz instant yaw speed spike at acquisition weight 1")
        # Across a fixed 0.5s period, a 30/s first-order response must
        # decay the SAME angular error at 30/60/120/240Hz.
        error = 1.0
        for _ in range(hz // 2):
            error *= (1.0 - full)
        require(abs(error - math.exp(-rate * 0.5)) < 1e-12,
                f"{hz}Hz chase smoothing depends on frame duration")
    require(response(rate, 0.0, 1.0) == 0.0,
            "zero time must never rotate the turret")
    print("BITTARAN_CHARGE_CONTINUITY_PASS "
          "weight_boundary_1_no_snap=true rates_30_60_120_240_equal=true "
          "run_boost_shrink_laser_contract_unchanged=true")

if __name__ == "__main__":
    main()
