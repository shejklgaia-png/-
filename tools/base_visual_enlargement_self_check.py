#!/usr/bin/env python3
"""Enlarge readable BASE shapes while keeping functional layout and props stable."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def src(p):return (root / p).read_text(encoding="utf-8")
arch=src("scripts/sera_base_architecture.gd")
sculpt=src("scripts/sera_base_silhouette_refinement.gd")
layout=src("scripts/sera_base_deck_layout.gd")
hub=src("scripts/base_exploration.gd")
ci=src("tools/sera_ci_manifest.txt")

assert 'g.detail_scale = 1.14' in arch
assert 'g.detail_scale = 1.45 if key == "LABO" else 1.55' in arch
assert arch.count('node.set_meta("visual_model_scale", g.detail_scale)') == 2
assert arch.count('g.detail_scale = 1.0\n    BaseClutter.decorate(g,') == 2
for feature in ["NexusLeftMaintenanceAnnex", "NexusRightServiceTower",
                "NexusAnnexUtilityRoof", "NexusServiceAnnexLouver"]:
    assert '"'+feature+'"' in sculpt, feature
assert 'Vector2(10.5, 10.5)' in layout, "keep reserved NEXUS pad"
assert 'Vector2(7.0, 7.0)' in layout, "keep LABO pad"
assert 'const BASE_ORTHO_SIZE: float = 38.0' in hub, "keep established camera"
assert 'py tools/base_visual_enlargement_self_check.py' in ci
assert 'gd tools/base_visual_enlargement_runtime_check.gd' in ci
print("SERA_BASE_VISUAL_ENLARGEMENT_STATIC_PASS")
