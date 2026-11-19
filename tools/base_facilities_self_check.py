#!/usr/bin/env python3
"""Independent hub contract: one LABO, six directly placed resource/production/construction devices."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
base = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
facility = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
scene = (root / "scenes/base_exploration.tscn").read_text(encoding="utf-8")
assert 'res://scripts/base_exploration.gd' in scene
assert 'res://scripts/base_facility_system.gd' in base
assert 'const HUB_SERA_CONTROLS_ENABLED: bool = false' in base
assert 'func _nexus_hit(' in base and 'func _enter_nexus(' in base
assert 'func _build_nexus_building(' in base
assert 'func _input(' in base and 'call("key_at",' in base
assert 'func _create_hud(' in base and 'call("attach_hud",' in base
# These are independent places on the outdoor 3D field, NOT NEXUS submenus.
for key in ("LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER",
            "GENERATOR", "STORAGE", "BUILD_TERMINAL"):
    assert f'"{key}"' in facility, f"Missing physical facility {key}"
for f in ("func _build_facilities(", "func key_at(", "func open_facility(",
          "func close_menu(", "func _projected_bounds("):
    assert f in facility, f
assert 'Shell' in facility and 'OS' in facility and 'スロット' in facility
assert 'NEXUS' not in facility.split('const FACILITY_SPECS', 1)[1].split('var ', 1)[0], "NEXUS features must not be duplicated"
assert 'func _update_crate(' in base
assert 'GridPlateBatch_' in base
print("SERA_BASE_FACILITIES_STATIC_PASS")
