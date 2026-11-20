#!/usr/bin/env python3
"""SERA v546: fully bundled, license-noticed WOFF2 fonts for all devices."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
assets = root / "assets/fonts"
skin = (root / "scripts/sera_labo_round_skin.gd").read_text("utf-8")
diag = (root / "scripts/sera_font_diagnostics.gd").read_text("utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text("utf-8")
files = [
    ("NotoSansJP-VF.woff2", "OFL-NotoSansJP.txt"),
    ("Rajdhani-Bold.woff2", "OFL-Rajdhani.txt"),
    ("IBMPlexMono-Medium.woff2", "OFL-IBMPlexMono.txt"),
]
for name, license_name in files:
    path = assets / name
    assert path.is_file(), f"Missing portable font: {name}"
    assert path.read_bytes()[:4] == b"wOF2", f"Invalid WOFF2: {name}"
    assert (assets / license_name).is_file()
    assert "SIL OPEN FONT LICENSE" in (assets / license_name).read_text("utf-8").upper()
    assert 20_000 < path.stat().st_size < 5_500_000
assert "SystemFont.new()" not in skin
assert "static func ui_font() -> FontVariation:" in skin
assert "static func title_font() -> FontVariation:" in skin
assert "static func control_font() -> FontVariation:" in skin
assert "static func stats_font() -> FontVariation:" in skin
assert "static func display_font() -> FontFile:" in skin
assert "static func data_font() -> FontFile:" in skin
for name, _ in files:
    assert name in skin
assert "variation_opentype = {ts.name_to_tag(\"wght\"): weight}" in skin
assert "embedded:" in diag and "JAPANESE FONT: PASS" in diag
assert "py tools/v546_bundled_font_self_check.py" in ci
assert "gd tools/v546_bundled_font_runtime_check.gd" in ci
print("SERA_V546_BUNDLED_FONT_STATIC_PASS")
