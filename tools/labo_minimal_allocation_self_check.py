#!/usr/bin/env python3
"""LABO allocation contract: no intermediate home or temporary per-card spacers."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ui=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
switch=ui.split("func _switch_section(",1)[1].split("\nfunc ",1)[0]
assert 'open_facility("LABO")' not in switch, "opening craft must not construct a discarded LABO home"
assert 'active_key = "LABO"' in switch and '_show_prototype_catalog()' in switch
slot=ui.split("func _new_slot(",1)[1].split("\nfunc ",1)[0]
assert 'for i in range(columns):' not in slot, "never create and queue_free three temporary placeholders per row"
assert 'row.remove_child(spacer_node)' not in slot
assert 'row.move_child(card, col)' not in slot
assert 'row.add_child(card)' in slot, "Android-validated native Buttons must remain"
assert 'func _finish_grid(' in ui, "only the incomplete last row may have placeholders"
assert '_finish_grid(grid)' in ui
assert 'if not diagnostic_button.visible:' in ui, "disabled diagnostics must avoid per-card stage writes"
# Keep WebP source fallback, framed native cards and the existing layout approach.
assert 'func _queue_card_icon(' in ui
assert 'card.text = title + "\\n" + info' in slot
assert 'ScrollContainer.new()' in ui, "native scroll is required in LABO"
assert 'GridContainer.new()' not in ui
assert 'py tools/labo_minimal_allocation_self_check.py' in manifest
assert 'gd tools/labo_minimal_allocation_runtime_check.gd' in manifest
print("SERA_LABO_MINIMAL_ALLOCATION_STATIC_PASS")
