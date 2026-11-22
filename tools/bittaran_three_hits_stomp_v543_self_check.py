#!/usr/bin/env python3
"""v543: three real received SERA hits queue next legal Bittaran STOMP; loud combat audio."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
director = (root / "scripts/bittaran_attacks.gd").read_text(encoding="utf-8")
battle = (root / "scripts/bittaran_battle.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert re.search(r"^const RECEIVED_HITS_FOR_STOMP: int = 3$", director, re.M)
assert "func register_received_hit() -> void:" in director
assert "var received_hit_count: int = 0" in director
assert "var guaranteed_stomp_pending: bool = false" in director
assert "if guaranteed_stomp_pending:" in director
assert 'return ("stomp" if' in director or 'return "stomp"' in director
assert "func _consume_guaranteed_stomp() -> void:" in director
assert 'bittaran_attacks.call("register_received_hit")' in battle
assert 'int(result.get("applied_damage", 0)) > 0' in battle
assert 'const FRONT_STOMP_RANGE_METERS: float = 3.70' in director
assert 'const STOMP_RANGE_METERS: float = 3.00' in director
assert 'const KICK_MIN_RANGE_METERS: float = 3.10' in director
assert 'const KICK_HALF_ANGLE_DEGREES: float = 60.0' in director
assert '"arm": 4.0' in battle
assert "bittaran_bgm.volume_db = -8.0" in battle
assert "_tick_bittaran_attack_sfx()" in battle
for name in ["py tools/bittaran_three_hits_stomp_v543_self_check.py",
             "gd tools/bittaran_three_hits_stomp_v543_runtime_check.gd",
             "gd tools/bittaran_sfx_event_runtime_check.gd",
             "gd tools/bittaran_ten_min_balance_runtime_check.gd"]:
    assert name in manifest, f"unregistered {name}"
print("PASS v543 guaranteed stomp after 3 hits and combat SE louder")
