#!/usr/bin/env python3
"""Export one slim SERA Godot Web/GL Compatibility scene and the intake form.
Do not approximate the SeraRig mesh/material in browser JavaScript.
Usage:
  python3 tools/equipment_intake/build_web_preview.py --stage /tmp/sera-web --site /tmp/sera-site
  godot --headless --editor --path /tmp/sera-web --import --quit
  godot --headless --path /tmp/sera-web --export-release "SERA Equipment Web" /tmp/sera-site/preview/preview.html
"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / "tools" / "equipment_intake"
SCENE = Path("tools/equipment_intake/godot_preview.tscn")
# Runtime FileAccess paths are not automatically discovered by the Godot
# resource dependency scanner. Include the exact canonical Blockbench assets.
LIVE_MODELS = (
    "assets/sera_source.json",
    "models/core/Equipment.bbmodel",
    "models/core/BirdLeg.bbmodel",
    "models/core/Katana.bbmodel",
    "models/storage/Head_C.bbmodel",
    "models/storage/LowerBody_D.bbmodel",
    "models/storage/カメラアイ頭部.bbmodel",
)
PRELOAD_RE = re.compile(r'(?:preload|load)\(\s*"res://([^"]+)"\s*\)')


def slim_project(stage: Path) -> list[str]:
    if stage.resolve() == ROOT.resolve():
        raise ValueError("stage must not be the source project")
    stage.mkdir(parents=True, exist_ok=True)
    pending = {SCENE, Path("tools/equipment_intake/godot_preview.gd"),
               Path("tools/equipment_intake/preview_runtime_check.gd")}
    pending.update(Path(p) for p in LIVE_MODELS)
    copied: set[Path] = set()
    while pending:
        relative = pending.pop()
        if relative in copied:
            continue
        src = ROOT / relative
        if not src.is_file():
            raise FileNotFoundError(f"Missing required SERA resource: {relative}")
        dst = stage / relative
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        copied.add(relative)
        if src.suffix in {".gd", ".tscn", ".tres"}:
            content = src.read_text(encoding="utf-8")
            for match in PRELOAD_RE.finditer(content):
                pending.add(Path(match.group(1)))
            for match in re.finditer(r'(?:path|script)\s*=\s*"?res://([^"\n]+)', content):
                pending.add(Path(match.group(1)))
    project = """
config_version=5

[application]
config/name="SERA Equipment Native Preview"
run/main_scene="res://tools/equipment_intake/godot_preview.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]
window/size/viewport_width=512
window/size/viewport_height=512
window/stretch/mode="canvas_items"

[input_devices]
pointing/emulate_mouse_from_touch=false

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
"""
    (stage / "project.godot").write_text(project.lstrip(), encoding="utf-8")
    preset = """
[preset.0]
name="SERA Equipment Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.bbmodel,*.json"
exclude_filter=""
export_path=""
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
"""
    (stage / "export_presets.cfg").write_text(preset.lstrip(), encoding="utf-8")
    return sorted(map(str, copied))


def webpage(site: Path) -> None:
    """Retain SERA's existing UI rules, input panels and graphics settings."""
    source = (HERE / "dist" / "SERA_Equipment_Intake_IRIS.html").read_text("utf-8")
    style = re.search(r"<style>([\s\S]*?)</style>", source)
    tabs = re.search(r'<nav id="intakeTabs"[\s\S]*?</nav>', source)
    panels = re.search(r'<section class="card intakePanel"[\s\S]*?</main>', source)
    data = re.search(r'<script type="application/json" id="intake-reference-data">([\s\S]*?)</script>', source)
    if not all((style, tabs, panels, data)):
        raise ValueError("Cannot find original SERA UI tabs/panels/reference data")
    # Guard against the old giant per-model JSON pack being embedded again.
    assert "intake-model-packs" not in data.group(0)
    json.loads(data.group(1))
    css = style.group(1)
    # Hiding the old HTML WebGL canvas is NOT enough: it must be removed.
    native_layout = """
<section class="card" id="intake-viewer-card">
 <div class="viewer-top"><h2>3D PREVIEW <span class="pill">GODOT / GL</span></h2>
 <small id="modelTitle">SERA NATIVE EQUIPMENT</small></div>
 <div class="viewer" id="viewer">
  <iframe id="godotPreview" title="SERA Godot 装備プレビュー"
   src="preview/preview.html" allow="fullscreen" scrolling="no"></iframe>
  <div id="frame" class="hidden"></div>
  <div class="viewer-caption" id="hint">1本指：回転 / 2本指：平行移動・ピンチ</div>
 </div>
 <div id="status" role="status">Godot WebGL2プレビューを読み込んでいます…</div>
 <div class="sample-row">
 <span id="bundleTag">SERA Rig / REAL GAME MATERIALS</span>
 <button id="reset" type="button">カメラ初期化</button></div>
 <div class="actions"><button type="button" class="primary" id="downloadPng">Godot画像を保存</button></div>
 <div id="intake-picker" hidden>
  <div class="subhead">FULL BODY / EQUIPPED PARTS</div>
  <p id="rigHint" class="helper">全身装備Aを基準に、実ゲーム用のモデルを換装します。</p>
  <div id="partChoices"></div>
 </div>
 <p class="loaded-note">描画：Godot 4.7 / SeraRig / SeraEquipment / ViewEdges。BlockbenchをJavaScriptで再メッシュ化しません。</p>
</section>
<section class="card" id="intake-controls" hidden>
 <h2>ICON STUDIO / GODOT</h2>
 <p class="helper">アイコンもGodotシーンから撮影します。モーション・輪郭線・反射はゲーム素材を使用します。</p>
 <div class="field"><label for="yaw">左右回転</label><input id="yaw" type="range" min="-180" max="180" value="160"><output id="yawVal">160°</output></div>
 <div class="field"><label for="pitch">上下回転</label><input id="pitch" type="range" min="-89" max="89" value="-18"><output id="pitchVal">-18°</output></div>
 <div class="field"><label for="roll">傾き</label><input id="roll" type="range" min="-180" max="180" value="0"><output id="rollVal">0°</output></div>
 <div class="field"><label for="zoom">拡大</label><input id="zoom" type="range" min="0.25" max="4" step="0.01" value="1"><output id="zoomVal">100%</output></div>
 <div class="field"><label for="panX">左右移動</label><input id="panX" type="range" min="-0.7" max="0.7" step="0.005" value="0"><output id="panXVal">0</output></div>
 <div class="field"><label for="panY">上下移動</label><input id="panY" type="range" min="-0.7" max="0.7" step="0.005" value="0"><output id="panYVal">0</output></div>
 <div class="field"><label for="outlinePx">輪郭線幅（本体シェーダー）</label><input id="outlinePx" type="range" min="0" max="6" step="0.5" value="3"><output id="outlinePxVal">3px</output></div>
 <div class="sample-row"><label><input id="showFrame" type="checkbox"> 撮影用ガイドを表示（PNGには含めない）</label></div>
 <div class="two"><button id="copy" class="primary">アイコン設定をコピー</button><button id="savePreset">この端末に保存</button></div>
 <textarea id="presetText" spellcheck="false" aria-label="アイコン撮影設定"></textarea>
 <div class="two"><button id="applyPreset">設定テキストを適用</button><button id="exportPreset">設定JSONを保存</button></div>
 <div class="two"><select id="saved"><option value="">保存設定を選択</option></select><button id="loadSaved">読み込む</button></div>
</section>
"""
    extra_css = """
#godotPreview{width:100%;height:100%;border:0;display:block;background:#101c26;touch-action:none}
#viewer{touch-action:none}#viewer iframe{aspect-ratio:1;width:100%;height:auto}
#intake-main .viewer{width:min(100%,600px);aspect-ratio:1;max-width:100%}
#intake-main .viewer-caption{pointer-events:none}
#intake-main #intake-viewer-card{position:sticky;top:0;z-index:2}
@media(max-width:800px){#intake-main #intake-viewer-card{position:relative}}
"""
    html_document = (
        '<!doctype html><html lang="ja"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
        '<title>SERA | GODOT EQUIPMENT INTAKE</title>'
        '<style>' + css + extra_css + '</style></head><body>'
        '<header><div class="title">SERA <span>EQUIPMENT INTAKE</span></div>'
        '<span class="tag">GODOT / GAME MATERIALS</span></header>'
        + tabs.group(0) + '<main id="intake-main">' + native_layout
        + panels.group(0) + data.group(0)
        + '<script src="./godot_bridge.js"></script>'
        + '<script src="./intake_ui.js"></script></body></html>'
    )
    if "id=\"intake-model-packs\"" in html_document or "<canvas id=\"glview\"" in html_document:
        raise ValueError("Legacy WebGL renderer escaped the template")
    site.mkdir(parents=True, exist_ok=True)
    (site / "index.html").write_text(html_document, "utf-8")
    shutil.copy2(HERE / "godot_bridge.js", site / "godot_bridge.js")
    shutil.copy2(HERE / "intake_ui.js", site / "intake_ui.js")
    (site / "preview").mkdir(exist_ok=True)
    (site / ".nojekyll").write_text("", "utf-8")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--stage", type=Path, required=True)
    p.add_argument("--site", type=Path, required=True)
    a = p.parse_args()
    copied = slim_project(a.stage)
    webpage(a.site)
    print(f"SERA_GODOT_WEB_STAGE_OK files={len(copied)} page={(a.site / 'index.html').stat().st_size}")
