#!/usr/bin/env python3
"""User-approved intake navigation/preview invariants (2026-11-21)."""
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
def read(p):
    return (ROOT / p).read_text(encoding="utf-8")

class DOM(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []
        self.in_section = {}
        self.attributes = {}
        self.ids = {}
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if a.get("id"):
            self.ids[a["id"]] = a
        if tag == "section" and "data-section" in a:
            self.stack.append(a["data-section"])
        elif tag == "section":
            self.stack.append(None)
        if a.get("id") and self.stack:
            self.in_section[a["id"]] = next((x for x in reversed(self.stack) if x), None)
    def handle_endtag(self, tag):
        if tag == "section" and self.stack:
            self.stack.pop()

html = read("tools/equipment_intake/dist/SERA_Equipment_Intake_IRIS.html")
dom = DOM()
dom.feed(html)
assert dom.in_section["sizeDelta"] == "rig", "Size controls only in full-body preview"
assert dom.in_section["sizeAspect"] == "rig"
assert dom.in_section["specialEffect"] == "stats", "Special effects belong to parameters"
assert dom.in_section["materialRows"] == "materials"
assert dom.in_section["statsPartPreview"] == "stats"
assert dom.in_section["statRows"] == "stats"
assert "intake-viewer-card" in dom.ids
assert 'data-nav="rig"' in html and 'data-nav="icon"' in html
assert html.count('id="specialEffect"') == 1
assert html.count('id="statsPartPreview"') == 1
assert "SERA_EQUIPMENT_INTAKE_V1" in html
# Production letters are *model IDs*, never a gameplay equipment-set selector.
assert "rigSet" not in html, "Old redundant equipment-set selector/controller survived"
assert '装備セット</label>' not in html, "Visible set input survived"
assert 'head:D' not in html or 'id="equipName"' in html


ui = read("tools/equipment_intake/intake_ui.js")
hook = read("tools/equipment_intake/intake_preview_hook.js")
godot = read("tools/equipment_intake/godot_preview.gd")
web = read("tools/equipment_intake/build_web_preview.py")
for literal in ('activeTab==="rig"?"body":"icon"', "updateStatsPreview",
                'selected=Object.fromEntries', '"head"?"D":"A"',
                "SERA_INTAKE_RENDER.snapshot()", 'name==="icon"'):
    assert literal in ui, literal
assert "rigSet" not in ui, "Model variant must be read from the selected slot"
assert "rig_set:selected[slot]" in ui, "Export must use the selected individual slot model"
assert "rig_selection:{...selected}" in ui, "Seven independent slot picks must be retained"
assert "SERA_INTAKE_REQUEST_REFRESH" in ui, "Model loading and selection must still refresh"
assert "intakeStandaloneDoc" in hook
assert 'snapshot:async()' in hook or 'snapshot:()=> ' in hook
assert 'intake-viewer-card' in web
assert 'view_mode=="icon"' in godot
assert 'if view_mode=="icon":' in godot
print("SERA_INTAKE_PREVIEW_TABS_STATIC_OK")
