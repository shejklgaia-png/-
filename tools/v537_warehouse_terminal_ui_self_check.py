#!/usr/bin/env python3
"""v537: SERA warehouse terminal restyle, responsive titles, and pooled cards."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fac = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
grid = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'grid.configure(entries, 2, "materials")' in fac
assert 'grid.call("configure", entries, 2, "equipment")' in fac
assert 'MATERIAL ARCHIVE' in fac and 'EQUIPMENT ARCHIVE' in fac
assert 'hero_host.custom_minimum_size.y = get_viewport().get_visible_rect().size.y * 0.30' in fac
assert 'const MAX_POOL_CARDS: int = 32' in grid
assert 'get_v_scroll_bar().value_changed.connect' in grid
assert 'const CARD_HEIGHT_MATERIALS: float = 120.0' in grid
for token in ('marker.name = "TierMarker"', 'meta.name = "ItemMeta"',
              'title.autowrap_mode = TextServer.AUTOWRAP_OFF',
              'title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS',
              'var compact: bool = _card_width < 244.0',
              'Icons.material_icon(id)',
              'art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED',
              'marker.mouse_filter = Control.MOUSE_FILTER_IGNORE',
              'title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER'):
    assert token in grid, token
assert 'result.border_width_bottom = 3' in skin
assert 'result.shadow_size = 0' in skin
assert 'func card_style(' in skin and 'StyleBoxTexture.new()' in skin
assert 'py tools/v537_warehouse_terminal_ui_self_check.py' in manifest
assert 'gd tools/v537_warehouse_terminal_ui_runtime_check.gd' in manifest
print("SERA_V537_TERMINAL_UI_STATIC_PASS")
