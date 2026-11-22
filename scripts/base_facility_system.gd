extends Node3D

signal power_board_requested
const BaseMaterials = preload("res://scripts/sera_base_materials.gd")
const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")
const IconAtlas = preload("res://scripts/sera_item_icons.gd")
const EquipmentPreview = preload("res://tools/equipment_intake/godot_preview.gd")
const WarehouseDetailPopup = preload("res://scripts/sera_warehouse_detail_popup.gd")
const RotateMark = preload("res://scripts/sera_rotatable_mark.gd")
const PrototypeCatalog = preload("res://scripts/sera_prototype_catalog.gd")
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const MarkIcon = preload("res://scripts/sera_mark_icon.gd")
const SeraFontDiag = preload("res://scripts/sera_font_diagnostics.gd")
const LaboTouchScroll = preload("res://scripts/sera_labo_touch_scroll.gd")
const WarehouseGrid = preload("res://scripts/sera_warehouse_grid.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")
const LaboStats = preload("res://scripts/sera_labo_stats.gd")
const StatUI = preload("res://scripts/sera_status_column_ui.gd")
const PreviewRim = preload("res://scripts/sera_tech_preview_frame.gd")
const WarehouseStatsTable = preload("res://scripts/sera_warehouse_stats_table.gd")
const LaboMaterialCardScene = preload("res://ui/labo/LaboMaterialCard.tscn")
const LaboEquipmentCardScene = preload("res://ui/labo/LaboEquipmentCard.tscn")
const LaboSectionTabScene = preload("res://ui/labo/LaboSectionTab.tscn")
# Shared portrait touch-target scale (Godot Control pixels, no extra sprites).
const LABO_NAV_HEIGHT: float = 64.0
const LABO_SLOT_HEIGHT: float = 58.0
const LABO_BACK_HEIGHT: float = 66.0
const LABO_CONFIRM_HEIGHT: float = 70.0
const LABO_CRAFT_CARD_HEIGHT: float = 160.0
const CRAFT_CATALOG_SLOTS: int = 20
const LABO_CONVERSION_HEIGHT: float = 84.0
const MATERIAL_CARD_HEIGHT: float = 108.0
const MATERIAL_ICON_WIDTH: int = 54
## Orthographic 720x1280 projected arrangement: upper NEXUS, central LABO,
## six independent facilities in staggered left/right columns. World coordinates
## staggered toward the camera without forming rigid rows, keeping a loose center.
## Base field architecture: LABO is one building; resources, power and construction
## are independent physical machines. NEXUS remains in the parent scene.
## Five vertically staggered rows create more screen-space separation while
## keeping all models, dedicated slab origins, tap targets and physical doors
## synchronized; world coordinates are chosen along the 27-degree camera axis.
const FACILITY_SPECS = [
    {"id": "LABO", "name": "LABO", "at": Vector3(7.15, 0.0, 6.95),
        "size": Vector3(4.25, 4.1, 4.35), "subtitle": "Shell / OS / スロット開発"},
    {"id": "SCRAP_COLLECTOR", "name": "回収機", "at": Vector3(9.95, 0.0, 22.18),
        "size": Vector3(2.35, 2.55, 2.25), "subtitle": "スクラップ収集"},
    {"id": "SMELTER", "name": "精製装置", "at": Vector3(-12.61, 0.0, -7.70),
        "size": Vector3(2.40, 2.85, 2.40), "subtitle": "素材の精製"},
    {"id": "RECYCLER", "name": "分解装置", "at": Vector3(-1.85, 0.0, -14.73),
        "size": Vector3(2.45, 2.55, 2.35), "subtitle": "不要素材の分解"},
    {"id": "GENERATOR", "name": "電力制御施設", "at": Vector3(7.37, 0.0, -3.57),
        "size": Vector3(2.40, 3.10, 2.25), "subtitle": "電力・素材・熱の回路制御"},
    {"id": "STORAGE", "name": "資材保管庫", "at": Vector3(-3.43, 0.0, 3.92),
        "size": Vector3(2.45, 2.15, 2.30), "subtitle": "資源の保管"},
    {"id": "BUILD_TERMINAL", "name": "建設端末", "at": Vector3(19.49, 0.0, 15.88),
        "size": Vector3(2.10, 2.55, 2.10), "subtitle": "拠点の建設・拡張"}
]

var facility_nodes: Dictionary = {}
var facility_tags: Dictionary = {}
var modal: Control
var modal_panel: PanelContainer
var terminal_code: Label
var module_caption: Label
var module_status: Label
var modal_title: Label
var warehouse_header_marks: HBoxContainer
var warehouse_detail_popup: Control
var craft_rotate_cue: Control
var modal_body: Label
var modal_actions: VBoxContainer
var item_layer: Control
var actions_area: PanelContainer
var actions_scroll: ScrollContainer
var pending_confirmation: Callable = Callable()
var confirmation_overlay: Control
var confirmation_panel: PanelContainer
var confirmation_text: Label
var confirmation_title: Label
var confirmation_system: Label
var confirmation_subtitle: Label
var confirmation_prompt: Label
var confirmation_craft_card: PanelContainer
var confirmation_preview_square: AspectRatioContainer
var confirmation_phase: Label
var confirmation_item_icon: TextureRect
var confirmation_preview_host: SubViewportContainer
var confirmation_preview_viewport: SubViewport
var confirmation_preview_scene: Node3D
var confirmation_item_name: Label
var confirmation_item_slot: Label
var confirmation_item_stats: Label
var confirmation_stat_rows: Array[Dictionary] = []
var confirmation_accept_button: Button
var craft_slot: String = "head"
var warehouse_notice: String = ""
var warehouse_section: String = "materials"
var warehouse_slot: String = "head"
var owned_blueprint: String = ""
var owned_page: int = 0
var section_tabs: HBoxContainer
var active_key: String = ""
var field_tags_enabled: bool = true
var selected_prototype: String = ""
var prototype_notice: String = ""
var conversion_mode: int = 0
var conversion_family: String = "scrap"
var conversion_batches: int = 1
var conversion_notice: String = ""
# All twelve material names and the recipe's source/target names use one size.
var _uniform_material_name_size: int = 16
var page: String = ""
var generator_rotor: Node3D
var diagnostic_button: Button
var diagnostic_readout: Label
var font_diag_button: Button
var font_diag_overlay: Control
var font_diag_report: Label
var font_diag_copy_button: Button
var diag_section: String = ""
var diag_stage: String = "initial"
var diag_expected: int = 0
var diag_created: int = 0
var diag_icon_count: int = 0
var diag_update_timer: float = 0.0
var diag_header_taps: int = 0
var diag_last_header_tap_ms: int = 0
var hero_host: SubViewportContainer
var hero_viewport: SubViewport
var hero_stage: Node3D

func _ready() -> void:
    name = "BaseFacilities"
    _build_facilities()

func _mat(tint: Color, emissive: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = 0.35
    material.roughness = 0.62
    if emissive:
        material.emission_enabled = true
        material.emission = tint
        material.emission_energy_multiplier = 1.3
    return material

func _box(parent: Node3D, title: String, at: Vector3, size: Vector3,
        tint: Color, glow: bool = false) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = title
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = _mat(tint, glow)
    node.position = at
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, title: String, at: Vector3, radius: float,
        height: float, tint: Color, glow: bool = false) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = title
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    node.mesh = mesh
    node.material_override = _mat(tint, glow)
    node.position = at
    parent.add_child(node)
    return node

func _build_facilities() -> void:
    for spec in FACILITY_SPECS:
        var key: String = str(spec["id"])
        var root_node := Node3D.new()
        root_node.name = key
        root_node.position = spec["at"]
        add_child(root_node)
        facility_nodes[key] = root_node
        var foundation: MeshInstance3D = _box(root_node, "Foundation", Vector3(0, 0.16, 0),
            Vector3(float((spec["size"] as Vector3).x), 0.32,
                float((spec["size"] as Vector3).z)), Color("#46535c"))
        foundation.rotation.y = BaseArchitecture.facility_yaw_radians(key)
        # All seven stations now have separately authored industrial geometry.
        BaseArchitecture.build_facility(root_node, key)
        # Keep the generator's existing rotor animation after the geometry swap.
        if key == "GENERATOR":
            generator_rotor = Node3D.new()
            generator_rotor.name = "EnergyRotor"
            var rotor_yaw: float = BaseArchitecture.facility_yaw_radians(key)
            generator_rotor.position = Basis(Vector3.UP, rotor_yaw) * Vector3(-0.60, 2.15, -0.34)
            generator_rotor.rotation.y = rotor_yaw
            root_node.add_child(generator_rotor)
            _box(generator_rotor, "RotorHub", Vector3.ZERO,
                Vector3(0.22, 0.15, 0.22), Color("#576d79"))
            for spoke in range(4):
                var spin: float = float(spoke) * PI * 0.5
                var vane: MeshInstance3D = _box(generator_rotor, "RotorBlade",
                    Basis(Vector3.UP, spin) * Vector3(0.22, 0, 0),
                    Vector3(0.30, 0.05, 0.09), Color("#8db7c4"))
                vane.rotation.y = spin
        var sign := Label3D.new()
        sign.name = "FacilitySign"
        sign.text = str(spec["name"])
        sign.font = LaboSkin.ui_font()
        # The HUD owns the sole name label in the FOV-free BASE overview.
        # Keep the 3D sign node for prefab hierarchy/diagnostics, but avoid
        # two superimposed captions at small portrait screen sizes.
        sign.visible = false
        sign.font_size = 70
        sign.pixel_size = 0.006
        sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sign.modulate = Color("#c0eff9")
        sign.position = Vector3(0.0, float((spec["size"] as Vector3).y) + 0.28, 0.0)
        root_node.add_child(sign)

func _build_labo(parent: Node3D) -> void:
    _box(parent, "LaboratoryHall", Vector3(0, 1.70, 0),
        Vector3(3.88, 3.05, 3.85), Color("#526677"))
    _box(parent, "Roof", Vector3(0, 3.44, 0),
        Vector3(4.25, 0.38, 4.22), Color("#20394a"))
    _box(parent, "FrontEntrance", Vector3(0, 1.15, 2.01),
        Vector3(1.48, 2.13, 0.18), Color("#122b3b"))
    _box(parent, "FrontLight", Vector3(0, 2.31, 2.14),
        Vector3(1.84, 0.16, 0.10), Color("#76e5dd"), true)
    for side in [-1.0, 1.0]:
        _box(parent, "SidePanel", Vector3(side * 1.80, 1.6, 0.0),
            Vector3(0.13, 2.30, 2.60), Color("#344b5d"))
        _cylinder(parent, "CoolantTank", Vector3(side * 1.20, 3.85, -0.55),
            0.42, 0.90, Color("#6d93a5"))
        _box(parent, "LabWindow", Vector3(side * 1.00, 2.15, 1.99),
            Vector3(0.50, 0.48, 0.08), Color("#4bc0cc"), true)

func _build_scrap_collector(parent: Node3D) -> void:
    _box(parent, "CollectorBody", Vector3(0, 0.65, 0),
        Vector3(1.80, 1.00, 1.50), Color("#657180"))
    for side in [-1.0, 1.0]:
        _box(parent, "GrabberArm", Vector3(side * 0.85, 1.33, -0.25),
            Vector3(0.21, 1.40, 0.25), Color("#b8a275"))
        _box(parent, "GrabberClaw", Vector3(side * 0.70, 1.98, -0.20),
            Vector3(0.50, 0.18, 0.20), Color("#c5c9ce"))
    _box(parent, "Hopper", Vector3(0, 1.35, 0.44),
        Vector3(1.22, 0.53, 0.68), Color("#2c4251"))
    _box(parent, "ReadyLamp", Vector3(0, 1.72, 0.54),
        Vector3(0.42, 0.08, 0.21), Color("#66dfe0"), true)

func _build_smelter(parent: Node3D) -> void:
    _box(parent, "Furnace", Vector3(0, 1.00, 0),
        Vector3(1.72, 1.80, 1.74), Color("#38404b"))
    _box(parent, "FurnaceMouth", Vector3(0, 0.97, 0.93),
        Vector3(1.04, 0.80, 0.13), Color("#f17f3e"), true)
    _box(parent, "HeatShield", Vector3(0, 1.90, 0),
        Vector3(2.10, 0.25, 2.00), Color("#76818b"))
    for side in [-1.0, 1.0]:
        _cylinder(parent, "ExhaustStack", Vector3(side * 0.60, 2.17, -0.48),
            0.25, 1.20, Color("#546475"))

func _build_recycler(parent: Node3D) -> void:
    _box(parent, "RecyclingHull", Vector3(0, 0.78, 0),
        Vector3(2.10, 1.18, 1.70), Color("#64717b"))
    _box(parent, "InputPort", Vector3(0, 1.46, 0),
        Vector3(1.30, 0.30, 1.20), Color("#223240"))
    for side in [-1.0, 1.0]:
        var roller := _cylinder(parent, "CrusherRoller", Vector3(side * 0.37, 1.63, 0),
            0.27, 1.10, Color("#a6b2b8"))
        roller.rotation_degrees.z = 90.0
    _box(parent, "OutputTray", Vector3(0, 0.42, 1.13),
        Vector3(1.30, 0.18, 0.65), Color("#3fc1d3"), true)

func _build_generator(parent: Node3D) -> void:
    _box(parent, "GeneratorFoot", Vector3(0, 0.42, 0),
        Vector3(1.85, 0.55, 1.84), Color("#4b5d6f"))
    _cylinder(parent, "CoreCasing", Vector3(0, 1.35, 0),
        0.62, 1.55, Color("#3f6375"))
    _cylinder(parent, "EnergyCore", Vector3(0, 1.37, 0),
        0.43, 1.28, Color("#44cbe2"), true)
    generator_rotor = Node3D.new()
    generator_rotor.name = "EnergyRotor"
    generator_rotor.position = Vector3(0, 2.24, 0)
    parent.add_child(generator_rotor)
    for index in range(4):
        var blade := _box(generator_rotor, "RotorBlade", Vector3(0.58, 0, 0),
            Vector3(0.90, 0.14, 0.20), Color("#c0d5dc"))
        blade.rotation.y = float(index) * PI * 0.5
        # Put each blade at the rotated radial position.
        blade.position = Basis(Vector3.UP, float(index) * PI * 0.5) * Vector3(0.58, 0, 0)
    _box(parent, "EnergyStatus", Vector3(0, 2.62, 0),
        Vector3(0.40, 0.12, 0.40), Color("#64e4c9"), true)

func _build_storage(parent: Node3D) -> void:
    _box(parent, "StorageDeck", Vector3(0, 0.27, 0),
        Vector3(2.13, 0.24, 1.88), Color("#657383"))
    for i in range(3):
        for j in range(2):
            _box(parent, "CargoCase", Vector3(-0.67 + i * 0.67,
                0.76 + j * 0.67, 0),
                Vector3(0.62, 0.61, 1.25), Color("#4b6475"))
            _box(parent, "CargoStripe", Vector3(-0.67 + i * 0.67,
                0.76 + j * 0.67, 0.64),
                Vector3(0.42, 0.09, 0.035), Color("#d0a85a"))

func _build_construction(parent: Node3D) -> void:
    _box(parent, "TerminalPole", Vector3(0, 0.99, 0),
        Vector3(0.52, 1.60, 0.52), Color("#4f6577"))
    _box(parent, "BuildDisplay", Vector3(0, 1.77, 0.26),
        Vector3(1.58, 0.90, 0.22), Color("#22374b"))
    _box(parent, "DisplayGlow", Vector3(0, 1.80, 0.39),
        Vector3(1.31, 0.65, 0.06), Color("#38b8dd"), true)
    _cylinder(parent, "PlanningAntenna", Vector3(0.58, 2.24, -0.20),
        0.055, 0.70, Color("#a6b7c2"))
    _box(parent, "BuildPad", Vector3(0, 0.29, 0.80),
        Vector3(1.72, 0.13, 0.80), Color("#687e8d"))

func _spec_for(key: String) -> Dictionary:
    for spec in FACILITY_SPECS:
        if str(spec["id"]) == key:
            return spec
    return {}

func _projected_bounds(camera: Camera3D, key: String) -> Rect2:
    var spec: Dictionary = _spec_for(key)
    if spec.is_empty() or not facility_nodes.has(key) or camera == null:
        return Rect2()
    var parent: Node3D = facility_nodes[key]
    var size: Vector3 = spec["size"]
    var body_orientation := Basis(Vector3.UP,
        BaseArchitecture.facility_yaw_radians(key))
    var low := Vector2(INF, INF)
    var high := Vector2(-INF, -INF)
    for x in [-size.x * 0.5, size.x * 0.5]:
        for y in [0.0, size.y + 0.6]:
            for z in [-size.z * 0.5, size.z * 0.5]:
                var vertex: Vector3 = parent.to_global(body_orientation * Vector3(x, y, z))
                if camera.is_position_behind(vertex):
                    continue
                var pixel: Vector2 = camera.unproject_position(vertex)
                low = Vector2(minf(low.x, pixel.x), minf(low.y, pixel.y))
                high = Vector2(maxf(high.x, pixel.x), maxf(high.y, pixel.y))
    if not is_finite(low.x) or not is_finite(high.x):
        return Rect2()
    return Rect2(low, high - low).grow(7.0)

func key_at(camera: Camera3D, pixel: Vector2) -> String:
    var nearest: String = ""
    var distance: float = INF
    for spec in FACILITY_SPECS:
        var key: String = str(spec["id"])
        if not _projected_bounds(camera, key).has_point(pixel):
            continue
        var center: Vector2 = camera.unproject_position(
            (facility_nodes[key] as Node3D).global_position +
            Vector3(0, float((spec["size"] as Vector3).y) * 0.5, 0))
        var test_distance: float = center.distance_squared_to(pixel)
        if test_distance < distance:
            distance = test_distance
            nearest = key
    return nearest

# Fit the largest readable Japanese glyphs into the existing touch targets.
# Seven part tabs stay one row; no ScrollContainer or per-frame allocation.
func _nav_font_size() -> int:
    # The top edge uses full uppercase Latin labels; reserve extra tracking
    # space instead of sizing for the old four-character Japanese text.
    var width: float = get_viewport().get_visible_rect().size.x
    return 20 if width < 540.0 else 23 if width < 720.0 else 24


func _section_label_font_size(button: Button) -> int:
    # EQUIPMENT is the longest navigation word. Keep it readable without
    # ellipsis; the other two tabs retain their stronger large-label scale.
    return mini(20, _nav_font_size()) if button.name == "TabCraft" else _nav_font_size()


func _layout_section_tabs() -> void:
    if section_tabs == null:
        return
    # Not inside the modal panel's VBox: the tabs are actually flush with
    # the screen's upper-left edge, hanging over the 3D header background.
    var available: float = get_viewport().get_visible_rect().size.x
    section_tabs.position = Vector2.ZERO
    section_tabs.size = Vector2(maxf(1.0, minf(540.0, available - 8.0)),
        LABO_NAV_HEIGHT + 20.0)
    for child in section_tabs.get_children():
        if child is Button:
            var tab: Button = child as Button
            if tab.name == "TabCraft":
                tab.text = "EQUIP" if available < 540.0 else "EQUIPMENT"
            tab.add_theme_font_size_override("font_size", _section_label_font_size(tab))

func _slot_font_size() -> int:
    var width: float = get_viewport().get_visible_rect().size.x
    # Two-character JP labels must remain inside seven non-scrolling buttons.
    return 18 if width < 520.0 else 21 if width < 720.0 else 22

func _material_card_font_size() -> int:
    var width: float = get_viewport().get_visible_rect().size.x
    # Two short lines (grade / family), one font size across all 12 cards.
    return 18 if width >= 590.0 else 16 if width >= 460.0 else 14

func _material_icon_side() -> float:
    var width: float = get_viewport().get_visible_rect().size.x
    # Retain breathing room for balanced left and text-gap padding.
    return 46.0 if width >= 590.0 else 40.0 if width >= 460.0 else 30.0


func _fit_material_titles(grid: VBoxContainer) -> void:
    # Measure both explicit lines of every grade/family label against the
    # narrowest card. Apply ONE shared size (no per-item shrinking).
    # Runs only after layout changes; no work is performed each frame.
    if not is_instance_valid(grid) or grid.is_queued_for_deletion() or (
            not grid.is_inside_tree()):
        return
    var titles: Array[Label] = []
    var minimum_width: float = INF
    for material_id in BaseMaterials.all_ids():
        var card: Button = grid.find_child(
            "MaterialIcon_" + str(material_id), true, false) as Button
        if card == null:
            return
        var label: Label = card.get_node_or_null(
            "CardContent/Row/TextStack/ItemTitle") as Label
        var art_dock: MarginContainer = card.get_node_or_null(
            "CardContent/Row/MaterialArtOffset") as MarginContainer
        if label == null or art_dock == null:
            return
        var row: HBoxContainer = art_dock.get_parent() as HBoxContainer
        var outer: MarginContainer = row.get_parent() as MarginContainer
        var available: float = minf(label.size.x,
            card.size.x - float(outer.get_theme_constant("margin_left")) -
            float(outer.get_theme_constant("margin_right")) -
            art_dock.get_combined_minimum_size().x -
            float(row.get_theme_constant("separation")))
        if available < 20.0:
            return
        titles.append(label)
        minimum_width = minf(minimum_width, available)
    var font: Font = LaboSkin.ui_font()
    var chosen: int = _material_card_font_size()
    while chosen > 10:
        var fits_every_name: bool = true
        for label in titles:
            for one_line in label.text.split("\n"):
                if font.get_string_size(one_line,
                        HORIZONTAL_ALIGNMENT_LEFT, -1.0, chosen).x > minimum_width - 1.0:
                    fits_every_name = false
                    break
            if not fits_every_name:
                break
        if fits_every_name:
            break
        chosen -= 1
    _uniform_material_name_size = chosen
    for label in titles:
        label.add_theme_font_size_override("font_size", chosen)
        LaboSkin.refresh_name_underline(label)


func attach_hud(hud: Control) -> void:
    for spec in FACILITY_SPECS:
        var tag := Label.new()
        tag.name = "FieldTag_" + str(spec["id"])
        tag.text = str(spec["name"])
        tag.add_theme_font_override("font", LaboSkin.ui_font())
        tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tag.add_theme_font_size_override("font_size", 17)
        tag.add_theme_color_override("font_color", Color("#dce4ea"))
        # Matte nameplates float ABOVE the equipment instead of drawing
        # bright text directly across its functional silhouette.
        var nameplate := StyleBoxFlat.new()
        nameplate.bg_color = Color(0.045, 0.095, 0.125, 0.93)
        nameplate.border_color = Color("#55798a")
        nameplate.border_width_bottom = 1
        nameplate.set_corner_radius_all(0)
        nameplate.content_margin_left = 8.0
        nameplate.content_margin_right = 8.0
        tag.add_theme_stylebox_override("normal", nameplate)
        tag.set_meta("FacilityNamePlate", true)
        LaboSkin.attach_name_underline(tag)
        tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hud.add_child(tag)
        facility_tags[str(spec["id"])] = tag
    modal = Control.new()
    modal.name = "FacilityModal"
    modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    modal.mouse_filter = Control.MOUSE_FILTER_STOP
    modal.visible = false
    hud.add_child(modal)
    var shade := ColorRect.new()
    shade.name = "DismissShade"
    shade.color = Color(0.006, 0.015, 0.026, 0.86)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.gui_input.connect(_on_shade_input)
    modal.add_child(shade)
    modal_panel = PanelContainer.new()
    modal_panel.name = "FacilitySheet"
    modal_panel.anchor_left = 0.025
    modal_panel.anchor_top = 0.055
    modal_panel.anchor_right = 0.975
    modal_panel.anchor_bottom = 0.945
    modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    # Cached gradient texture, no per-frame shader cost.
    modal_panel.add_theme_stylebox_override("panel", LaboSkin.panel_style())
    # A single common rounded native Button theme covers tabs, choices,
    # warehouse categories, conversion actions and Back without extra nodes.
    modal_panel.theme = LaboSkin.common_theme()
    modal.add_child(modal_panel)
    var padding := MarginContainer.new()
    padding.name = "FacilityPadding"
    for side in ["left", "right", "top", "bottom"]:
        padding.add_theme_constant_override("margin_" + side, 12)
    modal_panel.add_child(padding)
    var body := VBoxContainer.new()
    body.name = "FacilityContent"
    body.add_theme_constant_override("separation", 10)
    padding.add_child(body)
    # 30% of the visible portrait viewport. The actual 3D stage is created
    # lazily once and shared by LABO / SMELTER / RECYCLER / STORAGE.
    hero_host = SubViewportContainer.new()
    hero_host.name = "LaboHero3D"
    hero_host.stretch = true
    hero_host.stretch_shrink = 1
    hero_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hero_host.custom_minimum_size.y = get_viewport().get_visible_rect().size.y * 0.30
    hero_host.visible = false
    body.add_child(hero_host)
    var header_row := HBoxContainer.new()
    header_row.name = "FacilityHeaderRow"
    header_row.add_theme_constant_override("separation", 10)
    body.add_child(header_row)
    var header_accent := ColorRect.new()
    header_accent.name = "SectionHeaderAccent"
    header_accent.color = Color("#9cf0ed")
    header_accent.custom_minimum_size = Vector2(5, 32)
    header_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header_row.add_child(header_accent)
    modal_title = Label.new()
    modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modal_title.add_theme_font_size_override("font_size", 32)
    modal_title.add_theme_color_override("font_outline_color", Color("#071522"))
    modal_title.add_theme_constant_override("outline_size", 1)
    modal_title.add_theme_font_override("font", LaboSkin.title_font())
    modal_title.add_theme_color_override("font_color", Color("#e4edf0"))
    modal_title.mouse_filter = Control.MOUSE_FILTER_STOP
    modal_title.gui_input.connect(_on_modal_title_input)
    header_row.add_child(modal_title)
    LaboSkin.attach_name_underline(modal_title)
    terminal_code = Label.new()
    terminal_code.name = "FacilitySystemTag"
    terminal_code.mouse_filter = Control.MOUSE_FILTER_IGNORE
    terminal_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    terminal_code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    terminal_code.add_theme_font_override("font", LaboSkin.tracked_data_font())
    terminal_code.add_theme_font_size_override("font_size", 13)
    terminal_code.add_theme_color_override("font_color", Color("#9bd5db"))
    header_row.add_child(terminal_code)
    # Persistent, low-cost status rail at the top-right of the warehouse
    # detail heading. Both icons are allocated once and only toggled by item.
    var detail_marks := HBoxContainer.new()
    detail_marks.name = "WarehouseDetailHeaderMarks"
    detail_marks.add_theme_constant_override("separation", 4)
    detail_marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    detail_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
    detail_marks.visible = false
    for marker_kind in ["favorite", "junk"]:
        var detail_mark: Control = MarkIcon.new()
        detail_mark.name = ("WarehouseHeaderFavoriteMarkIcon"
            if marker_kind == "favorite" else "WarehouseHeaderJunkMarkIcon")
        detail_mark.set("kind", marker_kind)
        detail_mark.custom_minimum_size = Vector2(34.0, 34.0)
        detail_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        detail_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        detail_marks.add_child(detail_mark)
        detail_mark.visible = false
    header_row.add_child(detail_marks)
    warehouse_header_marks = detail_marks
    # Compact instrument strip underneath the main title; one-time UI nodes.
    var module_strip := HBoxContainer.new()
    module_strip.name = "FacilityModuleStrip"
    module_strip.custom_minimum_size.y = 27.0
    module_strip.add_theme_constant_override("separation", 8)
    body.add_child(module_strip)
    var module_rail := ColorRect.new()
    module_rail.name = "ModuleSignalRail"
    module_rail.color = Color("#8cece8")
    module_rail.custom_minimum_size = Vector2(24.0, 2.0)
    module_rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    module_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    module_strip.add_child(module_rail)
    module_caption = Label.new()
    module_caption.name = "ModuleCaption"
    module_caption.text = "01 / SHELL FABRICATION"
    module_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    module_caption.add_theme_font_override("font", LaboSkin.tracked_data_font())
    module_caption.add_theme_font_size_override("font_size", 14)
    module_caption.add_theme_color_override("font_color", Color("#9dcbd4"))
    module_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    module_strip.add_child(module_caption)
    module_status = Label.new()
    module_status.name = "ModuleStatus"
    module_status.text = "SYSTEM / ONLINE"
    module_status.add_theme_font_override("font", LaboSkin.tracked_data_font())
    module_status.add_theme_font_size_override("font_size", 12)
    module_status.visible = get_viewport().get_visible_rect().size.x >= 580.0
    module_status.add_theme_color_override("font_color", Color("#80cfd2"))
    module_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    module_strip.add_child(module_status)
    diagnostic_button = Button.new()
    diagnostic_button.name = "UIDiagnosticToggle"
    diagnostic_button.text = "診断"
    diagnostic_button.visible = false
    diagnostic_button.custom_minimum_size = Vector2(78.0, 46.0)
    diagnostic_button.add_theme_font_size_override("font_size", 16)
    diagnostic_button.tooltip_text = "Android版Godotの一覧表示を診断"
    diagnostic_button.pressed.connect(_diag_toggle)
    header_row.add_child(diagnostic_button)
    font_diag_button = Button.new()
    font_diag_button.name = "UIFontDiagnosticToggle"
    font_diag_button.text = "FONT"
    font_diag_button.visible = false
    font_diag_button.custom_minimum_size = Vector2(67.0, 46.0)
    font_diag_button.add_theme_font_override("font", LaboSkin.tracked_display_font())
    font_diag_button.add_theme_font_size_override("font_size", 17)
    font_diag_button.tooltip_text = "Show actual Godot font loading on this device"
    font_diag_button.pressed.connect(_font_diag_toggle)
    header_row.add_child(font_diag_button)
    # Three fixed, lightweight native Buttons attach to the ACTUAL viewport
    # top-left, separate from the 3D/header/content VBox. The selected tongue
    # hangs 18px lower; the unselected tongues remain short and restrained.
    section_tabs = HBoxContainer.new()
    section_tabs.name = "FacilitySectionTabs"
    section_tabs.mouse_filter = Control.MOUSE_FILTER_PASS
    section_tabs.theme = LaboSkin.common_theme()
    section_tabs.add_theme_constant_override("separation", 3)
    section_tabs.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    modal.add_child(section_tabs)
    var section_group := ButtonGroup.new()
    for entry in [
        {"id": "TabCraft", "label": "EQUIPMENT", "serial": "01", "target": "craft"},
        {"id": "TabMaterials", "label": "REFINERY", "serial": "02", "target": "materials"},
        {"id": "TabWarehouse", "label": "STORAGE", "serial": "03", "target": "warehouse"}
    ]:
        var button: Button = LaboSectionTabScene.instantiate() as Button
        button.name = str(entry["id"])
        button.text = str(entry["label"])
        button.toggle_mode = true
        button.button_group = section_group
        button.mouse_filter = Control.MOUSE_FILTER_STOP
        button.custom_minimum_size = Vector2(0.0, LABO_NAV_HEIGHT)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        button.alignment = HORIZONTAL_ALIGNMENT_CENTER
        button.add_theme_font_size_override("font_size", _nav_font_size())
        button.add_theme_font_override("font", LaboSkin.tracked_display_font())
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        button.add_theme_color_override("font_color", Color("#b4cbd5"))
        button.add_theme_color_override("font_pressed_color", Color("#dceff3"))
        button.add_theme_color_override("font_hover_color", Color("#e2f0f5"))
        button.add_theme_color_override("font_hover_pressed_color", Color("#e2f0f5"))
        button.add_theme_stylebox_override("normal", LaboSkin.hanging_tab_style("normal"))
        button.add_theme_stylebox_override("hover", LaboSkin.hanging_tab_style("hover"))
        button.add_theme_stylebox_override("pressed", LaboSkin.hanging_tab_style("selected"))
        button.add_theme_stylebox_override("hover_pressed", LaboSkin.hanging_tab_style("selected"))
        button.add_theme_stylebox_override("focus", LaboSkin.hanging_tab_style("normal"))
        button.add_theme_stylebox_override("disabled", LaboSkin.hanging_tab_style("disabled"))
        # Tiny etched terminal address above the main label, not a separate
        # touchable layer. All three serial labels are allocated only once.
        var serial := Label.new()
        serial.name = "TabSerial"
        serial.text = str(entry["serial"])
        serial.position = Vector2(13.0, 5.0)
        serial.size = Vector2(34.0, 17.0)
        serial.mouse_filter = Control.MOUSE_FILTER_IGNORE
        serial.add_theme_font_override("font", LaboSkin.tracked_data_font())
        serial.add_theme_font_size_override("font_size", 12)
        serial.add_theme_color_override("font_color", Color("#adced6"))
        button.add_child(serial)
        var selected_mark := ColorRect.new()
        selected_mark.name = "SelectedTabMark"
        selected_mark.color = Color("#74e3ed")
        selected_mark.position = Vector2(5.0, 9.0)
        selected_mark.size = Vector2(8.0, 8.0)
        selected_mark.visible = false
        selected_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_child(selected_mark)
        button.pressed.connect(_switch_section.bind(str(entry["target"])))
        section_tabs.add_child(button)
    _layout_section_tabs()
    get_viewport().size_changed.connect(_layout_section_tabs)
    # The 3D viewport retains its own fixed 30% height in the body below.
    modal_body = Label.new()
    modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    modal_body.add_theme_font_size_override("font_size", 19)
    modal_body.add_theme_font_override("font", LaboSkin.ui_font())
    modal_body.add_theme_color_override("font_color", Color("#a9cbd3"))
    body.add_child(modal_body)
    # Keep text values for diagnostics, but remove gray instruction prose from
    # the LABO panel without disturbing the existing controller structure.
    modal_body.visible = false
    diagnostic_readout = Label.new()
    diagnostic_readout.name = "UIDiagnosticReadout"
    diagnostic_readout.visible = false
    diagnostic_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    diagnostic_readout.add_theme_font_size_override("font_size", 12)
    diagnostic_readout.add_theme_color_override("font_color", Color("#fff0ae"))
    diagnostic_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body.add_child(diagnostic_readout)
    # Keep non-grid buttons immediately below the header and above the cards.
    # A vertical EXPAND here consumed the rest of the sheet on Android.
    actions_area = PanelContainer.new()
    actions_area.name = "FacilityActionsArea"
    actions_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    actions_area.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    body.add_child(actions_area)
    modal_actions = VBoxContainer.new()
    modal_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modal_actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    modal_actions.add_theme_constant_override("separation", 9)
    actions_scroll = LaboTouchScroll.new()
    actions_scroll.name = "FacilityActionScroll"
    actions_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    actions_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    actions_area.add_child(actions_scroll)
    actions_scroll.add_child(modal_actions)
    # The *same* VBoxContainer renders the known-working header tabs and
    # native item cards. No full-screen overlay, no manual pixel coordinates,
    # no nested scroll clipping. The container owns the sizing on Android.
    item_layer = VBoxContainer.new()
    item_layer.name = "FacilityItemLayer"
    item_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    item_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body.add_child(item_layer)
    var expand_spacer := Control.new()
    expand_spacer.name = "FacilityRemainingSpace"
    expand_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    expand_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    body.add_child(expand_spacer)
    var close_button := Button.new()
    close_button.name = "CloseFacility"
    close_button.text = "‹   戻る"
    close_button.custom_minimum_size.y = LABO_BACK_HEIGHT
    close_button.add_theme_font_size_override("font_size", 23)
    close_button.add_theme_font_override("font", LaboSkin.control_font())
    close_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _style_terminal_segment(close_button)
    var exit_tag := Label.new()
    exit_tag.name = "ExitKey"
    exit_tag.text = "EXIT / BACK"
    exit_tag.anchor_left = 1.0
    exit_tag.anchor_right = 1.0
    exit_tag.anchor_top = 0.5
    exit_tag.anchor_bottom = 0.5
    exit_tag.offset_left = -132.0
    exit_tag.offset_right = -15.0
    exit_tag.offset_top = -10.0
    exit_tag.offset_bottom = 10.0
    exit_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    exit_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
    exit_tag.add_theme_font_override("font", LaboSkin.data_font())
    exit_tag.add_theme_font_size_override("font_size", 12)
    exit_tag.add_theme_color_override("font_color", Color("#82b9c4"))
    close_button.add_child(exit_tag)
    close_button.pressed.connect(navigate_back)
    body.add_child(close_button)
    # Own full-screen confirmation layer; does not depend on Android popup
    # window support. It is deliberately outside the scrolling content.
    confirmation_overlay = Control.new()
    confirmation_overlay.name = "LaboConfirmation"
    confirmation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    confirmation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    confirmation_overlay.visible = false
    modal.add_child(confirmation_overlay)
    var confirm_shade := ColorRect.new()
    confirm_shade.color = Color(0.008, 0.021, 0.032, 0.93)
    confirm_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    confirm_shade.mouse_filter = Control.MOUSE_FILTER_STOP
    confirm_shade.gui_input.connect(_on_confirmation_shade_input)
    confirmation_overlay.add_child(confirm_shade)
    var confirm_panel := PanelContainer.new()
    confirm_panel.name = "LaboConfirmPanel"
    confirmation_panel = confirm_panel
    confirm_panel.anchor_left = 0.065
    confirm_panel.anchor_right = 0.935
    confirm_panel.anchor_top = 0.105
    confirm_panel.anchor_bottom = 0.895
    confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var confirm_skin := StyleBoxFlat.new()
    confirm_skin.bg_color = Color("#0d222d")
    confirm_skin.border_color = Color("#55798a")
    confirm_skin.set_border_width_all(2)
    confirm_skin.set_corner_radius_all(1)
    confirm_skin.content_margin_left = 19
    confirm_skin.content_margin_right = 19
    confirm_skin.content_margin_top = 18
    confirm_skin.content_margin_bottom = 22
    confirm_panel.add_theme_stylebox_override("panel", confirm_skin)
    confirmation_overlay.add_child(confirm_panel)
    confirmation_overlay.resized.connect(_layout_craft_confirmation)
    var confirm_vbox := VBoxContainer.new()
    confirm_vbox.name = "LaboConfirmLayout"
    confirm_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    confirm_vbox.add_theme_constant_override("separation", 10)
    confirm_panel.add_child(confirm_vbox)
    var confirm_system := Label.new()
    confirm_system.name = "LaboConfirmSystem"
    confirm_system.text = "—  SERA LAB  /  SYSTEM CONFIRMATION  —"
    confirm_system.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirm_system.add_theme_font_override("font", LaboSkin.tracked_data_font())
    confirm_system.add_theme_font_size_override("font_size", 13)
    confirm_system.add_theme_color_override("font_color", Color("#80ced7"))
    confirm_vbox.add_child(confirm_system)
    confirmation_system = confirm_system
    confirmation_phase = Label.new()
    confirmation_phase.name = "LaboConfirmPhase"
    confirmation_phase.text = "SERA  /  EQUIPMENT FABRICATION"
    confirmation_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirmation_phase.add_theme_font_override("font", LaboSkin.tracked_data_font())
    confirmation_phase.add_theme_font_size_override("font_size", 14)
    confirmation_phase.add_theme_color_override("font_color", Color("#8ed7df"))
    confirm_vbox.add_child(confirmation_phase)
    confirmation_title = Label.new()
    confirmation_title.name = "LaboConfirmTitle"
    confirmation_title.text = "以下の装備を作成します"
    confirmation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirmation_title.add_theme_font_size_override("font_size", 27)
    confirmation_title.add_theme_font_override("font", LaboSkin.title_font())
    confirmation_title.add_theme_color_override("font_color", Color("#eef9fc"))
    confirm_vbox.add_child(confirmation_title)
    var accent_rail := ColorRect.new()
    accent_rail.name = "LaboConfirmAccentRail"
    accent_rail.color = Color("#55798a")
    accent_rail.custom_minimum_size = Vector2(0, 2)
    accent_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    accent_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    confirm_vbox.add_child(accent_rail)
    var confirm_subtitle := Label.new()
    confirm_subtitle.name = "LaboConfirmSubtitle"
    confirm_subtitle.text = "ASSEMBLY  /  CONFIRMATION"
    confirm_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirm_subtitle.add_theme_font_override("font", LaboSkin.tracked_data_font())
    confirm_subtitle.add_theme_font_size_override("font_size", 12)
    confirm_subtitle.add_theme_color_override("font_color", Color("#80cad5"))
    confirm_vbox.add_child(confirm_subtitle)
    confirmation_subtitle = confirm_subtitle
    confirmation_craft_card = PanelContainer.new()
    confirmation_craft_card.name = "LaboConfirmCraftCard"
    confirmation_craft_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    confirmation_craft_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    confirmation_craft_card.custom_minimum_size.y = 610.0
    var craft_skin := StyleBoxFlat.new()
    craft_skin.bg_color = Color("#102733")
    craft_skin.border_color = Color("#3a6573")
    craft_skin.set_border_width_all(1)
    craft_skin.set_corner_radius_all(1)
    craft_skin.content_margin_left = 18.0
    craft_skin.content_margin_right = 18.0
    craft_skin.content_margin_top = 16.0
    craft_skin.content_margin_bottom = 17.0
    confirmation_craft_card.add_theme_stylebox_override("panel", craft_skin)
    confirm_vbox.add_child(confirmation_craft_card)
    # Portrait-first: full-width name, centered 1:1 model, stats below.
    # The old HBox squeezed the model between the text and card border.
    var craft_info := VBoxContainer.new()
    craft_info.name = "LaboConfirmItemRow"
    craft_info.alignment = BoxContainer.ALIGNMENT_CENTER
    craft_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    craft_info.add_theme_constant_override("separation", 9)
    confirmation_craft_card.add_child(craft_info)
    var craft_info_column := VBoxContainer.new()
    craft_info_column.name = "LaboConfirmItemIdentity"
    craft_info_column.alignment = BoxContainer.ALIGNMENT_CENTER
    craft_info_column.add_theme_constant_override("separation", 4)
    craft_info.add_child(craft_info_column)
    confirmation_item_slot = Label.new()
    confirmation_item_slot.name = "LaboConfirmItemSlot"
    confirmation_item_slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirmation_item_slot.add_theme_font_override("font", LaboSkin.tracked_data_font())
    confirmation_item_slot.add_theme_font_size_override("font_size", 14)
    confirmation_item_slot.add_theme_color_override("font_color", Color("#8bd5df"))
    craft_info_column.add_child(confirmation_item_slot)
    confirmation_item_name = Label.new()
    confirmation_item_name.name = "LaboConfirmItemName"
    confirmation_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirmation_item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    confirmation_item_name.add_theme_font_override("font", LaboSkin.equipment_font())
    confirmation_item_name.add_theme_font_size_override("font_size", 30)
    confirmation_item_name.add_theme_color_override("font_color", Color("#eef7fa"))
    craft_info_column.add_child(confirmation_item_name)
    LaboSkin.attach_name_underline(confirmation_item_name)

    var preview_center := CenterContainer.new()
    preview_center.name = "LaboConfirmPreviewCenter"
    preview_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_center.mouse_filter = Control.MOUSE_FILTER_PASS
    craft_info.add_child(preview_center)
    confirmation_preview_square = AspectRatioContainer.new()
    confirmation_preview_square.name = "LaboConfirmSquarePreview"
    confirmation_preview_square.ratio = 1.0
    confirmation_preview_square.custom_minimum_size = Vector2(352, 352)
    confirmation_preview_square.mouse_filter = Control.MOUSE_FILTER_PASS
    preview_center.add_child(confirmation_preview_square)
    var square_frame := PanelContainer.new()
    square_frame.name = "LaboConfirmPreviewFrame"
    var square_skin := StyleBoxFlat.new()
    square_skin.bg_color = Color("#111e28")
    square_skin.border_color = Color("#294653")
    square_skin.set_border_width_all(1)
    square_skin.set_corner_radius_all(0)
    # One continuous 1px frame; no second 5px inset around the 3D grid.
    square_skin.content_margin_left = 0.0
    square_skin.content_margin_right = 0.0
    square_skin.content_margin_top = 0.0
    square_skin.content_margin_bottom = 0.0
    square_frame.add_theme_stylebox_override("panel", square_skin)
    confirmation_preview_square.add_child(square_frame)
    var square_content := Control.new()
    square_content.name = "LaboConfirmPreviewContent"
    square_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    square_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    square_content.mouse_filter = Control.MOUSE_FILTER_PASS
    square_content.clip_contents = true
    square_frame.add_child(square_content)
    confirmation_item_icon = TextureRect.new()
    confirmation_item_icon.name = "LaboConfirmItemIcon"
    confirmation_item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    confirmation_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    confirmation_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    confirmation_item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    confirmation_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    square_content.add_child(confirmation_item_icon)
    # Both fallback image and interactive Godot model occupy the SAME square.
    confirmation_preview_host = SubViewportContainer.new()
    confirmation_preview_host.name = "LaboConfirmRotatablePart"
    confirmation_preview_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    confirmation_preview_host.stretch = true
    confirmation_preview_host.mouse_filter = Control.MOUSE_FILTER_STOP
    confirmation_preview_host.mouse_default_cursor_shape = Control.CURSOR_MOVE
    confirmation_preview_host.visible = false
    square_content.add_child(confirmation_preview_host)
    craft_rotate_cue = RotateMark.new()
    craft_rotate_cue.name = "LaboCraftRotateCue"
    craft_rotate_cue.position = Vector2(9, 9)
    craft_rotate_cue.size = Vector2(28, 28)
    craft_rotate_cue.visible = false
    square_content.add_child(craft_rotate_cue)
    var preview_outline := PreviewRim.new()
    preview_outline.name = "LaboConfirmPreviewTechFrame"
    preview_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    preview_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
    square_content.add_child(preview_outline)
    var preview_legend := Label.new()
    preview_legend.name = "LaboConfirmPreviewLegend"
    preview_legend.text = "DRAG  /  ROTATE       •       PINCH  /  ZOOM"
    preview_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview_legend.add_theme_font_override("font", LaboSkin.tracked_data_font())
    preview_legend.add_theme_font_size_override("font_size", 12)
    preview_legend.add_theme_color_override("font_color", Color("#8db7c2"))
    craft_info.add_child(preview_legend)

    var stats_panel := PanelContainer.new()
    stats_panel.name = "LaboConfirmStatsPanel"
    stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var stats_skin := StyleBoxFlat.new()
    stats_skin.bg_color = Color("#0b1d27")
    stats_skin.border_color = Color("#365866")
    stats_skin.set_border_width_all(1)
    stats_skin.set_corner_radius_all(0)
    stats_skin.content_margin_left = 14.0
    stats_skin.content_margin_right = 14.0
    stats_skin.content_margin_top = 8.0
    stats_skin.content_margin_bottom = 9.0
    stats_panel.add_theme_stylebox_override("panel", stats_skin)
    craft_info.add_child(stats_panel)
    var stats_column := VBoxContainer.new()
    stats_column.name = "LaboConfirmStatsColumn"
    stats_column.add_theme_constant_override("separation", 6)
    stats_panel.add_child(stats_column)
    var confirmation_stats_list := VBoxContainer.new()
    confirmation_stats_list.name = "LaboConfirmStatRows"
    confirmation_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    confirmation_stats_list.add_theme_constant_override("separation", 7)
    stats_column.add_child(confirmation_stats_list)
    for row_id in range(3):
        var stat_row := HBoxContainer.new()
        stat_row.name = "LaboConfirmStatRow_%d" % row_id
        stat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        stat_row.custom_minimum_size.y = 27.0
        stat_row.add_theme_constant_override("separation", 14)
        confirmation_stats_list.add_child(stat_row)
        var key_label := Label.new()
        key_label.name = "StatName"
        key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        stat_row.add_child(key_label)
        var number_label := Label.new()
        number_label.name = "StatValue"
        number_label.custom_minimum_size.x = 156.0
        number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        stat_row.add_child(number_label)
        StatUI.style_stat_labels(key_label, number_label, 18, 20)
        confirmation_stat_rows.append({
            "panel": stat_row, "name": key_label, "value": number_label
        })
    # Legacy read-only diagnostic node: no duplicate text is drawn.
    confirmation_item_stats = Label.new()
    confirmation_item_stats.name = "LaboConfirmItemStats"
    confirmation_item_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    confirmation_item_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    confirmation_item_stats.add_theme_font_override("font", LaboSkin.stats_font())
    confirmation_item_stats.add_theme_font_size_override("font_size", 19)
    confirmation_item_stats.add_theme_color_override("font_color", Color("#d3e9ee"))
    confirmation_item_stats.visible = false
    stats_column.add_child(confirmation_item_stats)
    confirmation_text = Label.new()
    confirmation_text.name = "LaboConfirmDescription"
    confirmation_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirmation_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    confirmation_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    confirmation_text.add_theme_font_size_override("font_size", 19)
    confirmation_text.add_theme_font_override("font", LaboSkin.ui_font())
    confirm_vbox.add_child(confirmation_text)
    # Decision question belongs beneath the large item preview, directly
    # above the two equal-width actions.
    confirmation_prompt = Label.new()
    confirmation_prompt.name = "LaboConfirmPrompt"
    confirmation_prompt.text = "作成しますか？"
    confirmation_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirmation_prompt.add_theme_font_override("font", LaboSkin.ui_font())
    confirmation_prompt.add_theme_font_size_override("font_size", 23)
    confirmation_prompt.add_theme_color_override("font_color", Color("#e4edf0"))
    confirm_vbox.add_child(confirmation_prompt)
    var confirm_buttons := HBoxContainer.new()
    confirm_buttons.add_theme_constant_override("separation", 10)
    confirm_vbox.add_child(confirm_buttons)
    var cancel_button := Button.new()
    cancel_button.name = "LaboConfirmCancel"
    cancel_button.text = "キャンセル"
    cancel_button.custom_minimum_size.y = LABO_CONFIRM_HEIGHT
    cancel_button.add_theme_font_size_override("font_size", 22)
    cancel_button.add_theme_font_override("font", LaboSkin.control_font())
    cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel_button.add_theme_stylebox_override(
        "normal", LaboSkin.terminal_segment_style("normal"))
    cancel_button.pressed.connect(_dismiss_confirmation)
    confirm_buttons.add_child(cancel_button)
    confirmation_accept_button = Button.new()
    confirmation_accept_button.name = "LaboConfirmAccept"
    confirmation_accept_button.text = "作成"
    confirmation_accept_button.custom_minimum_size.y = LABO_CONFIRM_HEIGHT
    confirmation_accept_button.add_theme_font_size_override("font_size", 22)
    confirmation_accept_button.add_theme_font_override("font", LaboSkin.control_font())
    confirmation_accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for style_state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
        confirmation_accept_button.add_theme_stylebox_override(
            style_state, LaboSkin.terminal_segment_style("selected"))
    confirmation_accept_button.add_theme_color_override("font_color", Color("#edffff"))
    confirmation_accept_button.pressed.connect(_accept_confirmation)
    confirm_buttons.add_child(confirmation_accept_button)
    # One overlay is reused for every warehouse UID; do not allocate it for
    # each of the 999 virtualized equipment cards.
    warehouse_detail_popup = WarehouseDetailPopup.new()
    modal.add_child(warehouse_detail_popup)
    warehouse_detail_popup.closed.connect(_on_warehouse_detail_closed)
    warehouse_detail_popup.marks_changed.connect(_show_warehouse_equipment)

func _layout_craft_confirmation() -> void:
    if confirmation_overlay == null or confirmation_preview_square == null:
        return
    # Square 3D/PNG occupies the available portrait width; reduce only on
    # shorter screens so the name, stats and bottom buttons remain reachable.
    var available: Vector2 = confirmation_overlay.size
    if available.x < 1.0 or available.y < 1.0:
        available = get_viewport().get_visible_rect().size
    var side: float = clampf(minf(available.x * 0.59, available.y * 0.32),
        248.0, 380.0)
    confirmation_preview_square.custom_minimum_size = Vector2(side, side)


func _set_labo_scroll_input_enabled(enabled: bool) -> void:
    if actions_scroll != null and actions_scroll.has_method("set_touch_scroll_enabled"):
        actions_scroll.call("set_touch_scroll_enabled", enabled)
    if item_layer != null:
        for child in item_layer.get_children():
            if child.has_method("set_touch_scroll_enabled"):
                child.call("set_touch_scroll_enabled", enabled)


func _request_confirmation(title: String, detail: String, action: Callable,
        equipment_blueprint: String = "") -> void:
    if confirmation_overlay == null or not action.is_valid():
        return
    pending_confirmation = action
    _set_labo_scroll_input_enabled(false)
    var is_craft: bool = not equipment_blueprint.is_empty()
    # Keep ordinary delete/convert confirmations compact; only equipment
    # fabrication owns the tall, portrait-focused panel.
    confirmation_panel.anchor_top = 0.105 if is_craft else 0.235
    confirmation_panel.anchor_bottom = 0.895 if is_craft else 0.765
    confirmation_title.text = "以下の装備を作成します" if is_craft else title
    confirmation_title.add_theme_font_size_override(
        "font_size", 32 if is_craft else 27)
    confirmation_system.visible = not is_craft
    confirmation_subtitle.visible = not is_craft
    confirmation_phase.visible = is_craft
    confirmation_prompt.text = "作成しますか？" if is_craft else (
        "操作内容をご確認ください。")
    confirmation_craft_card.visible = is_craft
    confirmation_text.visible = not is_craft
    confirmation_text.text = detail
    confirmation_accept_button.text = (
        "作成" if is_craft else "廃棄" if title.contains("廃棄")
        else "実行")
    if is_craft:
        var spec: Dictionary = PrototypeCatalog.spec(equipment_blueprint)
        confirmation_item_icon.texture = IconAtlas.equipment_icon(equipment_blueprint)
        confirmation_item_icon.visible = true
        confirmation_preview_host.visible = false
        craft_rotate_cue.visible = false
        confirmation_item_name.text = str(spec.get("name", ""))
        confirmation_item_slot.text = "EQUIPMENT / " + str(
            spec.get("slot", "")).to_upper()
        confirmation_item_stats.text = LaboStats.baseline(equipment_blueprint).trim_prefix("基礎ステータス\n")
        var status_rows: Array[Dictionary] = StatUI.baseline_rows(equipment_blueprint)
        for row_id in range(confirmation_stat_rows.size()):
            var view_row: Dictionary = confirmation_stat_rows[row_id]
            var show_row: bool = row_id < status_rows.size()
            (view_row["panel"] as HBoxContainer).visible = show_row
            if show_row:
                (view_row["name"] as Label).text = str(status_rows[row_id]["label"])
                (view_row["value"] as Label).text = str(status_rows[row_id]["value"])
        LaboSkin.refresh_name_underline(confirmation_item_name)
    confirmation_overlay.visible = true
    confirmation_overlay.move_to_front()
    _layout_craft_confirmation()
    if is_craft:
        call_deferred("_show_craft_rotatable_part", equipment_blueprint)

func _ensure_craft_part_preview() -> void:
    if is_instance_valid(confirmation_preview_scene):
        return
    confirmation_preview_viewport = SubViewport.new()
    confirmation_preview_viewport.name = "CraftEquipmentViewport"
    confirmation_preview_viewport.size = Vector2i(384, 384)
    confirmation_preview_viewport.own_world_3d = true
    confirmation_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    confirmation_preview_host.add_child(confirmation_preview_viewport)
    confirmation_preview_scene = EquipmentPreview.new()
    confirmation_preview_scene.name = "CraftNativePartViewer"
    # The LABO confirmation viewer shares the single-part outline preference.
    confirmation_preview_scene.set_meta("sera_graphics_outline_category", "part")
    confirmation_preview_viewport.add_child(confirmation_preview_scene)

func _show_craft_rotatable_part(blueprint: String) -> void:
    if confirmation_overlay == null or not confirmation_overlay.visible:
        return
    var spec: Dictionary = PrototypeCatalog.spec(blueprint)
    if spec.is_empty():
        return
    _ensure_craft_part_preview()
    confirmation_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    # First-time SeraRig loads asynchronously. Never expose an empty 3D panel.
    for index in range(12):
        if not is_instance_valid(confirmation_preview_scene):
            return
        if bool(confirmation_preview_scene.get("ready_for_commands")):
            break
        await get_tree().process_frame
    if not is_instance_valid(confirmation_preview_scene) or not (
            bool(confirmation_preview_scene.get("ready_for_commands"))):
        push_warning("LABO craft 3D preview could not initialize; static icon retained")
        return
    if not confirmation_overlay.visible or (
            confirmation_item_name.text != str(spec.get("name", ""))):
        return
    var selected_parts: Dictionary = {}
    for slot in SeraSave.EQUIPMENT_SLOTS:
        selected_parts[slot] = "A"
    # rig_set is an internal source-model identifier, not an equipment set.
    var edited_slot: String = str(spec.get("slot", "head"))
    selected_parts[edited_slot] = str(spec.get("rig_set", "A"))
    confirmation_preview_scene.call("_apply_command", {
        "mode": "icon", "editing_slot": edited_slot,
        "selected": selected_parts, "size": 1.0, "keep_aspect": true,
        "background_mode": "grid",
        "camera": {"yaw": 156.900744628906, "pitch": 11.8749389648438, "roll": 0.0,
            "panX": 0.0, "panY": 0.0, "zoom": 1.0, "outlinePx": 3.0},
        "seq": -1})
    confirmation_item_icon.visible = false
    confirmation_preview_host.visible = true
    craft_rotate_cue.visible = true

func _dismiss_confirmation() -> void:
    pending_confirmation = Callable()
    _set_labo_scroll_input_enabled(true)
    if confirmation_preview_host != null:
        confirmation_preview_host.visible = false
    if craft_rotate_cue != null:
        craft_rotate_cue.visible = false
    if confirmation_preview_viewport != null:
        confirmation_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    if confirmation_overlay != null:
        confirmation_overlay.visible = false

func _accept_confirmation() -> void:
    var action: Callable = pending_confirmation
    _dismiss_confirmation()
    if action.is_valid():
        action.call()

func _on_confirmation_shade_input(event: InputEvent) -> void:
    if (event is InputEventScreenTouch and event.pressed) or (
            event is InputEventMouseButton and event.pressed and
            event.button_index == MOUSE_BUTTON_LEFT):
        _dismiss_confirmation()

func _configure_page_scroll(action_height: float = 0.0,
        action_expand: bool = false) -> void:
    if actions_area == null:
        return
    actions_area.size_flags_vertical = (
        Control.SIZE_EXPAND_FILL if action_expand else Control.SIZE_SHRINK_BEGIN)
    actions_scroll.custom_minimum_size.y = action_height
    actions_scroll.scroll_vertical = 0
    item_layer.visible = not action_expand

func set_field_tags_visible(enabled: bool) -> void:
    field_tags_enabled = enabled
    if not enabled:
        for value in facility_tags.values():
            if value is Label:
                (value as Label).visible = false

func update_tags(camera: Camera3D) -> void:
    if camera == null or not field_tags_enabled:
        return
    for spec in FACILITY_SPECS:
        var key: String = str(spec["id"])
        var tag: Label = facility_tags.get(key)
        if tag == null:
            continue
        var vertex: Vector3 = (facility_nodes[key] as Node3D).global_position + Vector3(
            0, float((spec["size"] as Vector3).y) + 0.65, 0)
        tag.visible = not camera.is_position_behind(vertex)
        if tag.visible:
            var point: Vector2 = camera.unproject_position(vertex)
            # Outer facilities approach the portrait view edges. Keep labels
            # readable without moving their physical touch targets inward.
            var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
            # Compact plates reflect real text length, leaving more of the
            # 3D scene visible than the former 190×40 invisible label rect.
            var label_width: float = clampf(
                30.0 + float(tag.text.length()) * 18.0, 96.0,
                minf(172.0, viewport.x - 16.0))
            tag.size = Vector2(label_width, 28.0)
            tag.position = Vector2(
                clampf(point.x - label_width * 0.5, 8.0,
                    maxf(8.0, viewport.x - label_width - 8.0)),
                clampf(point.y - 46.0, 104.0,
                    maxf(104.0, viewport.y - 142.0)))

func is_menu_open() -> bool:
    return modal != null and modal.visible


func _ensure_labo_hero() -> void:
    if hero_viewport != null:
        return
    hero_viewport = SubViewport.new()
    hero_viewport.name = "LabViewport"
    hero_viewport.own_world_3d = true
    hero_viewport.size = Vector2i(480, 240)
    hero_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    hero_host.add_child(hero_viewport)
    hero_stage = load("res://scenes/labo_hero_stage.tscn").instantiate() as Node3D
    hero_viewport.add_child(hero_stage)
    hero_stage.set_process(false)


func _set_labo_hero(enabled: bool, section: String = "") -> void:
    if hero_host == null:
        return
    hero_host.visible = enabled
    if enabled:
        _ensure_labo_hero()
        # The content area remains native Android Button rows. The hero owns
        # its dedicated 30%, with smaller cards below and no clipping/scroll.
        hero_host.custom_minimum_size.y = get_viewport().get_visible_rect().size.y * 0.30
        modal_panel.anchor_top = 0.015
        modal_panel.anchor_bottom = 0.985
        hero_stage.call("set_section", section)
        hero_stage.set_process(true)
        hero_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    else:
        modal_panel.anchor_top = 0.08
        modal_panel.anchor_bottom = 0.92
        if hero_stage != null:
            hero_stage.set_process(false)
            hero_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _diag_begin(section: String, expected: int) -> void:
    diag_section = section
    diag_expected = expected
    diag_created = 0
    diag_icon_count = 0
    diag_stage = "starting " + section


func _diag_step(stage: String) -> void:
    # Keep the diagnostic probe fully idle unless the developer enables it.
    if not diagnostic_button.visible:
        return
    # Written before potentially failing resource/graphics operations.
    diag_stage = stage


func _diag_toggle() -> void:
    if diagnostic_readout == null:
        return
    diagnostic_readout.visible = not diagnostic_readout.visible
    _diag_update()


func _on_modal_title_input(event: InputEvent) -> void:
    # An optional debug control without a new panel, timer or idle polling:
    # tap the modal title five times quickly. Normal gameplay has no debug UI.
    var title_tapped: bool = (event is InputEventScreenTouch and event.pressed) or (
        event is InputEventMouseButton and event.pressed
        and event.button_index == MOUSE_BUTTON_LEFT)
    if not title_tapped:
        return
    var now_ms: int = Time.get_ticks_msec()
    if now_ms - diag_last_header_tap_ms > 1700:
        diag_header_taps = 0
    diag_last_header_tap_ms = now_ms
    diag_header_taps += 1
    if diag_header_taps >= 5:
        diag_header_taps = 0
        diagnostic_button.visible = not diagnostic_button.visible
        font_diag_button.visible = diagnostic_button.visible
        if diagnostic_button.visible:
            terminal_code.visible = false
        else:
            diagnostic_readout.visible = false
            diag_update_timer = 0.0
            _font_diag_close()
            _sync_section_tabs()
    get_viewport().set_input_as_handled()



## Standalone font inspector; only constructed and measured on explicit request.
## The six live preview labels make missing glyphs and identical fallback faces
## visually apparent even if Font.has_char reports support.
func _font_diag_create() -> void:
    font_diag_overlay = Control.new()
    font_diag_overlay.name = "FontDiagnosticOverlay"
    font_diag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    font_diag_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    font_diag_overlay.visible = false
    modal.add_child(font_diag_overlay)
    var dim := ColorRect.new()
    dim.name = "FontDiagnosticShade"
    dim.color = Color(0.005, 0.014, 0.029, 0.94)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    font_diag_overlay.add_child(dim)
    var panel := PanelContainer.new()
    panel.name = "FontDiagnosticPanel"
    panel.anchor_left = 0.035
    panel.anchor_right = 0.965
    panel.anchor_top = 0.035
    panel.anchor_bottom = 0.965
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", LaboSkin.panel_style())
    panel.theme = LaboSkin.common_theme()
    font_diag_overlay.add_child(panel)
    var pad := MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 14)
    pad.add_theme_constant_override("margin_right", 14)
    pad.add_theme_constant_override("margin_top", 14)
    pad.add_theme_constant_override("margin_bottom", 14)
    panel.add_child(pad)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 8)
    pad.add_child(body)
    var heading := Label.new()
    heading.name = "FontDiagnosticHeading"
    heading.text = "FONT DIAGNOSTIC / DEVICE"
    heading.add_theme_font_override("font", LaboSkin.tracked_display_font())
    heading.add_theme_font_size_override("font_size", 22)
    heading.add_theme_color_override("font_color", Color("#a1f3f1"))
    body.add_child(heading)
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 8)
    body.add_child(buttons)
    var refresh := Button.new()
    refresh.name = "FontDiagRefresh"
    refresh.text = "RESCAN"
    refresh.custom_minimum_size = Vector2(0, 45)
    refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    refresh.pressed.connect(_font_diag_refresh)
    buttons.add_child(refresh)
    font_diag_copy_button = Button.new()
    font_diag_copy_button.name = "FontDiagCopy"
    font_diag_copy_button.text = "COPY LOG"
    font_diag_copy_button.custom_minimum_size = Vector2(0, 45)
    font_diag_copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    font_diag_copy_button.pressed.connect(_font_diag_copy)
    buttons.add_child(font_diag_copy_button)
    var close := Button.new()
    close.name = "FontDiagClose"
    close.text = "CLOSE"
    close.custom_minimum_size = Vector2(0, 45)
    close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    close.pressed.connect(_font_diag_close)
    buttons.add_child(close)
    var scroll := ScrollContainer.new()
    scroll.name = "FontDiagScroll"
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    var rows := VBoxContainer.new()
    rows.name = "FontDiagRows"
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation", 4)
    scroll.add_child(rows)
    var legend := Label.new()
    legend.text = "LIVE SAMPLES - compare shapes, JP glyphs, weights:"
    legend.add_theme_font_override("font", LaboSkin.data_font())
    legend.add_theme_font_size_override("font_size", 13)
    legend.add_theme_color_override("font_color", Color("#b4d4dd"))
    rows.add_child(legend)
    for entry: Dictionary in SeraFontDiag.roles():
        var role := Label.new()
        role.text = str(entry["id"])
        role.add_theme_font_override("font", LaboSkin.data_font())
        role.add_theme_font_size_override("font_size", 12)
        role.add_theme_color_override("font_color", Color("#81c8d0"))
        rows.add_child(role)
        var sample := Label.new()
        sample.name = "FontSample_" + str(entry["id"]).replace(" ", "_")
        # Latin-only fonts legitimately lack JP glyphs; avoid tofu squares.
        sample.text = ("装備 精製 倉庫 日本語 漢字 / Aa 0123456789"
            if str(entry["id"]).begins_with("JP ") else
            "Aa 0123456789  UNIT / H01  SYSTEM ONLINE")
        sample.add_theme_font_override("font", entry["font"] as Font)
        sample.add_theme_font_size_override("font_size", 21)
        sample.add_theme_color_override("font_color", Color("#ffffff"))
        sample.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        sample.custom_minimum_size.y = 33
        rows.add_child(sample)
    var separator := HSeparator.new()
    rows.add_child(separator)
    font_diag_report = Label.new()
    font_diag_report.name = "FontDiagnosticReport"
    font_diag_report.add_theme_font_override("font", LaboSkin.data_font())
    font_diag_report.add_theme_font_size_override("font_size", 13)
    font_diag_report.add_theme_color_override("font_color", Color("#d4e4e9"))
    font_diag_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    font_diag_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_child(font_diag_report)


func _font_diag_toggle() -> void:
    if font_diag_overlay == null:
        _font_diag_create()
    font_diag_overlay.visible = not font_diag_overlay.visible
    if font_diag_overlay.visible:
        _font_diag_refresh()


func _font_diag_refresh() -> void:
    if font_diag_report == null:
        return
    font_diag_report.text = SeraFontDiag.report()
    if font_diag_copy_button != null:
        font_diag_copy_button.text = "COPY LOG"
    print("SERA_FONT_DIAG_BEGIN\n" + font_diag_report.text + "\nSERA_FONT_DIAG_END")


func _font_diag_copy() -> void:
    if font_diag_report == null:
        return
    DisplayServer.clipboard_set(font_diag_report.text)
    font_diag_copy_button.text = "COPIED"


func _font_diag_close() -> void:
    if font_diag_overlay != null:
        font_diag_overlay.visible = false


func _diag_update() -> void:
    if diagnostic_readout == null or not diagnostic_readout.visible:
        return
    var version_info: Dictionary = Engine.get_version_info()
    var engine_version: String = str(version_info.get("string", "unknown"))
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    var atlas_present: bool = ResourceLoader.exists("res://assets/ui/sera_matte_icon_atlas.webp")
    var card_count: int = 0
    var visible_count: int = 0
    var real_icons: int = 0
    var virtual_total: int = 0
    var first_card: Button = null
    var row_count: int = 0
    if item_layer != null:
        for grid_node in item_layer.get_children():
            if grid_node is not Control:
                continue
            if grid_node is ScrollContainer and grid_node.has_method("configure"):
                var entries: Array = grid_node.get("entries")
                var cards: Array = grid_node.get("pool")
                virtual_total += entries.size()
                row_count += ceili(float(grid_node.get("virtual_slots")) /
                    float(grid_node.get("columns")))
                for candidate in cards:
                    var card: Button = candidate as Button
                    card_count += 1
                    if card.is_visible_in_tree():
                        visible_count += 1
                    var texture: TextureRect = card.get_node("ItemArt") as TextureRect
                    if texture.texture != null:
                        real_icons += 1
                    if first_card == null:
                        first_card = card
                continue
            row_count += grid_node.get_child_count()
            for row_node in grid_node.get_children():
                for child in row_node.get_children():
                    if child is Button:
                        var card: Button = child as Button
                        card_count += 1
                        if card.is_visible_in_tree():
                            visible_count += 1
                        if card.icon != null:
                            real_icons += 1
                        if first_card == null:
                            first_card = card
    var first_rect: String = "none"
    if first_card != null:
        var rect: Rect2 = first_card.get_global_rect()
        first_rect = "(%d,%d) %dx%d" % [
            int(rect.position.x), int(rect.position.y),
            int(rect.size.x), int(rect.size.y)]
    diagnostic_readout.text = (
        "Godot %s / %s | save=%d\n" % [engine_version, OS.get_name(),
            SeraSave.active_slot]
        + "section: %s | stage: %s\n" % [diag_section, diag_stage]
        + "created %d/%d | icons %d | slots: %d visible %d, art %d\n" % [
            diag_created, diag_expected, diag_icon_count,
            card_count, visible_count, real_icons]
        + "virtual %d items | " % virtual_total
        + "atlas: %s | rows %d | viewport: %dx%d\n" % [
            "OK" if atlas_present else "MISSING", row_count,
            int(viewport.x), int(viewport.y)]
        + "first: " + first_rect + "\n"
        + "icon source: " + IconAtlas.atlas_status())

func _clear_actions() -> void:
    _set_warehouse_header_marks()
    # Warehouse navigation is non-scrollable; restore scrolling for all other
    # LABO pages before rebuilding their native action controls.
    actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _configure_page_scroll()
    for child in modal_actions.get_children():
        modal_actions.remove_child(child)
        child.queue_free()
    if item_layer != null:
        for child in item_layer.get_children():
            item_layer.remove_child(child)
            child.queue_free()
    # _clear_actions runs before screen titles are reassigned.
    # Refresh after the page is built, without polling every frame.
    call_deferred("_refresh_modal_name_underline")

func _refresh_modal_name_underline() -> void:
    if modal_title != null and is_instance_valid(modal_title):
        LaboSkin.refresh_name_underline(modal_title)

func _invoke_scroll_action(action: Callable, scroll: ScrollContainer) -> void:
    # A screen drag may release on the same Button; never treat it as a tap.
    if scroll != null and scroll.has_method("touch_drag_consumed") and (
            bool(scroll.call("touch_drag_consumed"))):
        return
    if action.is_valid():
        action.call()


## Reuse native Android Buttons with a shared, non-glowing console skin.
func _style_terminal_segment(button: Button) -> void:
    button.add_theme_font_override("font", LaboSkin.control_font())
    button.add_theme_stylebox_override("normal", LaboSkin.terminal_segment_style("normal"))
    button.add_theme_stylebox_override("hover", LaboSkin.terminal_segment_style("hover"))
    button.add_theme_stylebox_override("pressed", LaboSkin.terminal_segment_style("selected"))
    button.add_theme_stylebox_override("hover_pressed", LaboSkin.terminal_segment_style("selected"))
    button.add_theme_stylebox_override("disabled", LaboSkin.terminal_segment_style("disabled"))
    button.add_theme_stylebox_override("focus", LaboSkin.terminal_segment_style("normal"))
    button.add_theme_color_override("font_color", Color("#c9e6ea"))
    button.add_theme_color_override("font_pressed_color", Color("#e3eff3"))
    button.add_theme_color_override("font_hover_pressed_color", Color("#e3eff3"))
    button.add_theme_color_override("font_hover_color", Color("#e3eff3"))
    if button.toggle_mode:
        var selected_mark := ColorRect.new()
        selected_mark.name = "SelectedTabMark"
        selected_mark.color = Color("#9bf1ed")
        selected_mark.position = Vector2(6.0, 6.0)
        selected_mark.size = Vector2(6.0, 6.0)
        selected_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        selected_mark.visible = button.button_pressed
        button.add_child(selected_mark)
        button.toggled.connect(func(pressed: bool) -> void:
            selected_mark.visible = pressed)


func _add_labo_mark_icon(button: Button, kind: String) -> void:
    # Native vector pictogram: no missing-font symbols and no extra texture.
    var icon: Control = MarkIcon.new()
    icon.name = "JunkMarkIcon" if kind == "junk" else "FavoriteMarkIcon"
    icon.set("kind", kind)
    icon.anchor_top = 0.5
    icon.anchor_bottom = 0.5
    icon.offset_left = 15.0
    icon.offset_right = 39.0
    icon.offset_top = -12.0
    icon.offset_bottom = 12.0
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(icon)


func _set_warehouse_header_marks(favorite: bool = false, junk: bool = false) -> void:
    if warehouse_header_marks == null:
        return
    var favorite_icon: Control = warehouse_header_marks.get_node(
        "WarehouseHeaderFavoriteMarkIcon") as Control
    var junk_icon: Control = warehouse_header_marks.get_node(
        "WarehouseHeaderJunkMarkIcon") as Control
    favorite_icon.visible = favorite
    junk_icon.visible = junk
    warehouse_header_marks.visible = favorite or junk


func _add_terminal_notice(message: String) -> void:
    if message.is_empty():
        return
    var notice := Label.new()
    notice.name = "TerminalStatus"
    notice.text = "SYSTEM / " + message
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.add_theme_font_override("font", LaboSkin.ui_font())
    notice.add_theme_font_size_override("font_size", 17)
    notice.add_theme_color_override("font_color", Color("#93d2db"))
    notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    modal_actions.add_child(notice)


func _add_action(label: String, detail: String) -> void:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size.y = 88.0
    button.add_theme_font_size_override("font_size", 22)
    button.add_theme_font_override("font", LaboSkin.control_font())
    button.pressed.connect(_invoke_scroll_action.bind(_show_detail.bind(detail),
        actions_scroll))
    modal_actions.add_child(button)

func _switch_section(target: String) -> void:
    _dismiss_confirmation()
    match target:
        "craft":
            # Avoid constructing and immediately discarding the four LABO-home
            # action buttons (and their deferred icons) on every craft tap.
            if modal == null:
                return
            active_key = "LABO"
            modal.visible = true
            _set_labo_hero(true, "LABO")
            modal_body.visible = false
            _show_prototype_catalog()
        "materials":
            open_facility("SMELTER")
        "warehouse":
            open_facility("STORAGE")


func _sync_section_tabs() -> void:
    if section_tabs == null:
        return
    var current: String = ""
    match active_key:
        "LABO":
            if page in ["prototypes", "prototype_detail"]:
                current = "TabCraft"
        "SMELTER", "RECYCLER":
            current = "TabMaterials"
        "STORAGE":
            current = "TabWarehouse"
    if terminal_code != null:
        match active_key:
            "LABO":
                terminal_code.text = "ASSEMBLY / " + craft_slot.to_upper()
            "SMELTER", "RECYCLER":
                terminal_code.text = "MATERIAL"
            "STORAGE":
                terminal_code.text = ("ARCHIVE / 12" if warehouse_section == "materials"
                    else "HANGAR / %03d" % SeraSave.get_owned_prototypes(warehouse_slot).size())
            _:
                terminal_code.text = ""
        terminal_code.visible = get_viewport().get_visible_rect().size.x >= 460.0
    if module_caption != null:
        match current:
            "TabCraft":
                module_caption.text = "01 / SHELL FABRICATION"
            "TabMaterials":
                module_caption.text = "02 / MATERIAL REFINERY"
            "TabWarehouse":
                module_caption.text = ("03 / MATERIAL MANIFEST"
                    if warehouse_section == "materials" else "03 / EQUIPMENT ARCHIVE")
            _:
                module_caption.text = "SERA / FIELD TERMINAL"
    if module_status != null:
        module_status.visible = get_viewport().get_visible_rect().size.x >= 580.0
        module_status.text = ("READY / 20 SLOTS" if current == "TabCraft" else
            "REFINE / ONLINE" if current == "TabMaterials" else
            "STORAGE / ONLINE" if current == "TabWarehouse" else
            "SYSTEM / ONLINE")
    for child in section_tabs.get_children():
        if child is Button:
            var button: Button = child as Button
            var selected: bool = button.name == current
            button.button_pressed = selected
            button.add_theme_font_size_override("font_size", _section_label_font_size(button))
            var selected_mark: ColorRect = button.get_node_or_null("SelectedTabMark") as ColorRect
            if selected_mark != null:
                selected_mark.visible = selected
            button.custom_minimum_size.y = (
                LABO_NAV_HEIGHT + 18.0 if selected else LABO_NAV_HEIGHT)


func open_facility(key: String) -> void:
    if key == "GENERATOR":
        # The controller opens its physical connected 3D grid stage instead
        # of covering the outdoor world with the generic field modal.
        power_board_requested.emit()
        return
    var spec: Dictionary = _spec_for(key)
    if modal == null or spec.is_empty():
        return
    _dismiss_confirmation()
    if warehouse_detail_popup != null:
        warehouse_detail_popup.close_item()
    active_key = key
    page = "home"
    modal_body.visible = not key in ["LABO", "SMELTER", "RECYCLER", "STORAGE"]
    modal_title.text = str(spec["name"])
    modal.visible = true
    _set_labo_hero(key in ["LABO", "SMELTER", "RECYCLER", "STORAGE"], key)
    # LABO has no separate landing menu: the first frame is the craft list.
    # Bypass home-action allocation and retain the three persistent nav tabs.
    if key == "LABO":
        _show_prototype_catalog()
        return
    _clear_actions()
    match key:
        "SCRAP_COLLECTOR":
            modal_body.text = "回収機\n現在の所持素材は倉庫で確認できます。"
            var stock_button := Button.new()
            stock_button.name = "OpenMaterialInventory"
            stock_button.text = "素材一覧を表示"
            _queue_card_icon(stock_button, "scrap_low")
            stock_button.custom_minimum_size.y = 78.0
            stock_button.pressed.connect(_invoke_scroll_action.bind(
                open_facility.bind("STORAGE"), actions_scroll))
            modal_actions.add_child(stock_button)
            _add_action("回収設備の情報", "将来の実際の素材回収機能です。素材は所持データから確認できます。")
        "SMELTER":
            _show_conversion(1)
        "RECYCLER":
            _show_conversion(-1)
        "STORAGE":
            _show_inventory("equipment")
        "BUILD_TERMINAL":
            modal_body.text = "建設端末\nフィールド上の設備や床・通路を管理します。"
            _add_action("拠点の発展", "施設を一棟に集約せず、資源・生産・発展設備をフィールド上に独立配置します。\n配置変更と建設コストは今後実装します。")
    if page == "home":
        _configure_page_scroll(0, true)
    _sync_section_tabs()

func _claim_trial_materials(return_to_catalog: bool = false) -> void:
    var granted: bool = SeraSave.claim_trial_materials()
    if return_to_catalog:
        _show_prototype_catalog()
    else:
        open_facility("LABO")
    modal_body.text += ("\n全12種類の試作素材を各6個受け取りました。"
        if granted else "\n受け取り済み、またはセーブデータがありません。")


func _create_trial_profile() -> void:
    # Never overwrite existing saves, including an inactive legacy slot.
    if SeraSave.active_slot > 0:
        return
    for slot in range(1, SeraSave.SLOT_COUNT + 1):
        if SeraSave.get_slot(slot).is_empty():
            if SeraSave.create_data(slot):
                prototype_notice = "セーブスロット%dを作成しました。" % slot
                _show_prototype_catalog()
            else:
                prototype_notice = "保存に失敗しました。"
                _show_prototype_catalog()
            return
    prototype_notice = "セーブスロットが満杯です。NEXUSから既存データを読み込んでください。"
    _show_prototype_catalog()


func _apply_card_skin(card: Button) -> void:
    if not is_instance_valid(card) or card.is_queued_for_deletion() or (
            not card.is_inside_tree()):
        return
    if diagnostic_button.visible:
        _diag_step("skin " + card.name + " normal")
    card.add_theme_stylebox_override("normal", LaboSkin.card_style("normal"))
    card.add_theme_stylebox_override("hover", LaboSkin.card_style("hover"))
    card.add_theme_stylebox_override("pressed", LaboSkin.card_style("pressed"))
    card.add_theme_stylebox_override("disabled", LaboSkin.card_style("disabled"))
    if diagnostic_button.visible:
        _diag_step("skin " + card.name + " ready")


func _queue_card_icon(card: Button, item_id: String, equipment: bool = false) -> void:
    # Cards and their hit areas exist before any import-dependent icon load.
    # A failed editor texture import cannot abort the entire 7/12-card loop.
    call_deferred("_apply_card_icon", card, item_id, equipment)


func _apply_card_icon(card: Button, item_id: String, equipment: bool = false) -> void:
    if not is_instance_valid(card) or card.is_queued_for_deletion() or (
            not card.is_inside_tree()):
        return
    if diagnostic_button.visible:
        _diag_step("icon " + item_id + " loading")
    var texture: Texture2D = (IconAtlas.equipment_icon(item_id)
        if equipment else IconAtlas.material_icon(item_id))
    # Native root Button receives input and background, not the bitmap.
    # The independent, clipped TextureRect is guaranteed to fit the card.
    var art: TextureRect = card.find_child("ItemArt", true, false) as TextureRect
    if art != null:
        art.texture = texture
        art.texture_filter = (CanvasItem.TEXTURE_FILTER_LINEAR if equipment
            else CanvasItem.TEXTURE_FILTER_NEAREST)
    if texture != null:
        diag_icon_count += 1
        if diagnostic_button.visible:
            _diag_step("icon " + item_id + " ready")
    elif diagnostic_button.visible:
        _diag_step("icon " + item_id + " unavailable (card retained)")


func _new_grid(grid_name: String, columns: int = 3) -> VBoxContainer:
    # HBoxContainer + native Button is the same renderer path as the tabs
    # verified visible on the user's Android screen. Avoid the previous custom
    # PanelContainer and GridContainer combination that rendered as a blank area.
    var grid := VBoxContainer.new()
    grid.name = grid_name
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("separation", 9)
    grid.set_meta("card_columns", columns)
    grid.set_meta("card_count", 0)
    if grid_name in ["PrototypeGrid", "MaterialFamilyGrid"]:
        var scroll := LaboTouchScroll.new()
        scroll.name = grid_name + "Scroll"
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        scroll.mouse_filter = Control.MOUSE_FILTER_STOP
        item_layer.add_child(scroll)
        scroll.add_child(grid)
    else:
        item_layer.add_child(grid)
    if diagnostic_button.visible:
        _diag_step("grid " + grid_name + " ready")
    return grid


func _finish_grid(grid: VBoxContainer) -> void:
    # Only an incomplete last row needs spacers. No temporary allocation or
    # remove_child/queue_free is required during native Button construction.
    var count: int = int(grid.get_meta("card_count", 0))
    var columns: int = int(grid.get_meta("card_columns", 3))
    if grid.name == "MaterialFamilyGrid":
        # A single deferred resize callback keeps every title identical.
        grid.resized.connect(_fit_material_titles.bind(grid), CONNECT_DEFERRED)
        call_deferred("_fit_material_titles", grid)
    if count == 0 or count % columns == 0:
        return
    var last_row: HBoxContainer = grid.get_child(grid.get_child_count() - 1) as HBoxContainer
    for col in range(count % columns, columns):
        var spacer := Control.new()
        spacer.name = "CardSpacer_%d" % col
        spacer.custom_minimum_size.x = 108.0
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        last_row.add_child(spacer)


func _new_slot(parent: Control, key: String, icon: Texture2D,
        title: String, info: String, action: Callable = Callable(),
        action_name: String = "") -> Control:
    if diagnostic_button.visible:
        _diag_step("slot " + key + " start")
    var columns: int = int(parent.get_meta("card_columns", 3))
    var index: int = int(parent.get_meta("card_count", 0))
    var col: int = index % columns
    var row: HBoxContainer
    if col == 0:
        row = HBoxContainer.new()
        row.name = "CardRow_%d" % int(index / columns)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_theme_constant_override("separation", 7)
        parent.add_child(row)
    else:
        row = parent.get_child(parent.get_child_count() - 1) as HBoxContainer
    var material_choice: bool = (parent.name == "MaterialFamilyGrid")
    # Both reusable scenes have a standard Button as their root, because
    # custom PanelContainer hit testing previously failed in Android Editor.
    var card: Button
    if material_choice:
        card = LaboMaterialCardScene.instantiate() as Button
    else:
        card = LaboEquipmentCardScene.instantiate() as Button
    card.name = key
    card.clip_contents = true
    card.icon = null
    card.text = title + "\n" + info  # semantic/accessibility metadata
    card.tooltip_text = title + " / " + info
    card.custom_minimum_size = Vector2(108,
        MATERIAL_CARD_HEIGHT if material_choice else LABO_CRAFT_CARD_HEIGHT)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.alignment = HORIZONTAL_ALIGNMENT_LEFT
    # The Button no longer draws textual content itself. The child labels
    # have independent width, wrapping, contrast and padding.
    card.add_theme_font_size_override("font_size", 1)
    for state in ["font_color", "font_hover_color", "font_pressed_color",
            "font_disabled_color", "font_focus_color"]:
        card.add_theme_color_override(state, Color.TRANSPARENT)
    var art: TextureRect = card.get_node("CardContent/Row/ItemArt") as TextureRect
    art.texture = icon
    art.clip_contents = true
    art.texture_filter = (CanvasItem.TEXTURE_FILTER_NEAREST if material_choice
        else CanvasItem.TEXTURE_FILTER_LINEAR)
    var title_label: Label = card.get_node(
        "CardContent/Row/TextStack/ItemTitle") as Label
    var info_label: Label = card.get_node(
        "CardContent/Row/TextStack/ItemInfo") as Label
    title_label.text = title
    # Japanese names share one cohesive face; Latin-only locked slots are
    # intentionally condensed while Japanese stats never use a mono fallback.
    title_label.add_theme_font_override("font", (
        LaboSkin.ui_font() if material_choice else
        LaboSkin.tracked_display_font() if key.begins_with("LockedCraftSlot_") else
        LaboSkin.equipment_font()))
    info_label.add_theme_font_override("font", (
        LaboSkin.tracked_data_font() if key.begins_with("LockedCraftSlot_") else
        LaboSkin.stats_font()))
    if material_choice:
        # Slight left/down shift, without stretching or clipping pixel art.
        # This wrapper is only allocated for the twelve refinery tiles.
        var material_row: HBoxContainer = art.get_parent() as HBoxContainer
        var material_padding: MarginContainer = material_row.get_parent() as MarginContainer
        # The icon is inset 12px from the left, and its gap to text is
        # also 12px (the tier rail is outside this content area).
        material_padding.add_theme_constant_override("margin_left", 12)
        material_padding.add_theme_constant_override("margin_right", 5)
        material_row.add_theme_constant_override("separation", 12)
        var art_dock := MarginContainer.new()
        art_dock.name = "MaterialArtOffset"
        art_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
        art_dock.add_theme_constant_override("margin_top", 7)
        material_row.add_child(art_dock)
        material_row.move_child(art_dock, 0)
        art.reparent(art_dock, false)
        art.custom_minimum_size = Vector2(_material_icon_side(), _material_icon_side())
        art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        title_label.max_lines_visible = 2
        title_label.add_theme_constant_override("line_spacing", 0)
        title_label.clip_text = true
        title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        title_label.add_theme_font_size_override(
            "font_size", _material_card_font_size())
        info_label.add_theme_font_size_override(
            "font_size", maxi(15, _material_card_font_size() - 4))
        title_label.add_theme_color_override("font_color", Color("#eaf3f5"))
        info_label.add_theme_color_override("font_color", Color("#9cdbe4"))
    else:
        title_label.add_theme_font_size_override("font_size",
            (24 if get_viewport().get_visible_rect().size.x >= 500.0 else 22)
            if key.begins_with("LockedCraftSlot_") else
            (28 if get_viewport().get_visible_rect().size.x >= 500.0 else 24))
        info_label.add_theme_font_size_override(
            "font_size", 17 if key.begins_with("LockedCraftSlot_") else 20)
        info_label.add_theme_constant_override("line_spacing", 3)
        title_label.add_theme_color_override("font_color",
            Color("#8da9b5") if key.begins_with("LockedCraftSlot_") else
            Color("#eaf4f5"))
        info_label.add_theme_color_override("font_color",
            Color("#587786") if key.begins_with("LockedCraftSlot_") else
            Color("#e0f4f6"))
        if key.begins_with("LockedCraftSlot_"):
            art.visible = false
            art.custom_minimum_size = Vector2.ZERO
    info_label.text = (info if material_choice else
        info.replace("基礎ステータス / ", ""))
    row.add_child(card)
    if not key.begins_with("LockedCraftSlot_"):
        LaboSkin.attach_name_underline(title_label)
    parent.set_meta("card_count", index + 1)
    diag_created += 1
    # Small overlay accents distinguish purpose and quality without using
    # per-frame shaders or stealing touches from the native card.
    if material_choice:
        var tier_rail := ColorRect.new()
        tier_rail.name = "TierRail"
        tier_rail.color = Color("#79b6c2")
        tier_rail.position = Vector2(3.0, 18.0)
        tier_rail.size = Vector2(3.0, MATERIAL_CARD_HEIGHT - 36.0)
        tier_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(tier_rail)
        var grade_tag := Label.new()
        grade_tag.name = "MaterialGradeTag"
        grade_tag.text = ("R1" if key.ends_with("_low") else
            "R2" if key.ends_with("_mid") else "R3")
        grade_tag.anchor_left = 1.0
        grade_tag.anchor_right = 1.0
        grade_tag.offset_left = -42.0
        grade_tag.offset_right = -9.0
        grade_tag.offset_top = 1.0
        grade_tag.offset_bottom = 17.0
        grade_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        grade_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
        grade_tag.add_theme_font_override("font", LaboSkin.tracked_data_font())
        grade_tag.add_theme_font_size_override("font_size", 12)
        grade_tag.add_theme_color_override("font_color", Color("#90cbd3"))
        card.add_child(grade_tag)
    else:
        var serial := Label.new()
        serial.name = "UnitSerial"
        serial.text = ("SLOT / " + key.trim_prefix("LockedCraftSlot_")
            if key.begins_with("LockedCraftSlot_") else
            "UNIT / " + key.trim_prefix("PrototypeIcon_"))
        serial.anchor_left = 1.0
        serial.anchor_right = 1.0
        serial.offset_left = -128.0
        serial.offset_right = -10.0
        serial.offset_top = 3.0
        serial.offset_bottom = 19.0
        serial.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        serial.mouse_filter = Control.MOUSE_FILTER_IGNORE
        serial.add_theme_font_override("font", LaboSkin.tracked_data_font())
        serial.add_theme_font_size_override("font_size", 12)
        serial.add_theme_color_override("font_color", Color("#a5c8d3"))
        card.add_child(serial)
        var locked: bool = key.begins_with("LockedCraftSlot_")
        var edge := ColorRect.new()
        edge.name = "CardSignalRail"
        edge.color = Color("#3b5a66") if locked else Color("#90eeea")
        edge.position = Vector2(3.0, 23.0)
        edge.size = Vector2(4.0, LABO_CRAFT_CARD_HEIGHT - 46.0)
        edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(edge)
        var footer := Label.new()
        footer.name = "CardSystemState"
        footer.text = "ACCESS / LOCKED" if locked else "SCHEMATIC / AVAILABLE"
        footer.anchor_left = 1.0
        footer.anchor_right = 1.0
        footer.anchor_top = 1.0
        footer.anchor_bottom = 1.0
        footer.offset_left = -251.0
        footer.offset_right = -15.0
        footer.offset_top = -27.0
        footer.offset_bottom = -8.0
        footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        footer.add_theme_font_override("font", LaboSkin.tracked_data_font())
        footer.add_theme_font_size_override("font_size", 12)
        footer.add_theme_color_override("font_color",
            Color("#5a7c89") if locked else Color("#80d9db"))
        card.add_child(footer)
    # Styles and artwork are deferred until all native Buttons exist.
    call_deferred("_apply_card_skin", card)
    card.disabled = not action.is_valid()
    if action.is_valid():
        card.pressed.connect(_invoke_scroll_action.bind(
            action, parent.get_parent() as ScrollContainer))
        card.set_meta("action_id", action_name)
    if diagnostic_button.visible:
        _diag_step("slot " + key + " complete")
    return card


func _add_item_tile(icon: Texture2D, title: String,
        key: String, parent: VBoxContainer = null) -> void:
    if parent == null:
        parent = modal_actions
    var row := HBoxContainer.new()
    row.name = key
    row.custom_minimum_size.y = 80.0
    parent.add_child(row)
    var art := TextureRect.new()
    art.name = "Icon"
    art.clip_contents = true
    art.texture = icon
    # 512px H02 portrait assets must never impose their source dimensions
    # on a narrow Android warehouse-detail row.
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.custom_minimum_size = Vector2(66, 66)
    art.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(art)
    var caption := Label.new()
    caption.name = "Caption"
    caption.text = title
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 21)
    caption.add_theme_font_override("font", LaboSkin.control_font())
    row.add_child(caption)


func _show_inventory(section: String = "equipment") -> void:
    warehouse_section = section
    page = "inventory"
    _clear_actions()
    _diag_begin("warehouse " + section, 12 if section == "materials" else 2)
    modal_title.text = "倉庫"
    modal_body.text = ("MATERIAL ARCHIVE   /   12種類の素材" if section == "materials"
        else "EQUIPMENT ARCHIVE   /   装備と追加特性")
    var switcher := HBoxContainer.new()
    switcher.name = "WarehouseCategoryTabs"
    modal_actions.add_child(switcher)
    var warehouse_group := ButtonGroup.new()
    for choice in [
        {"key": "equipment", "name": "WarehouseEquipmentTab", "caption": "装備 / GEAR"},
        {"key": "materials", "name": "WarehouseMaterialsTab", "caption": "素材 / MATERIAL"}
    ]:
        var button: Button = LaboSectionTabScene.instantiate() as Button
        button.name = str(choice["name"])
        button.text = str(choice["caption"])
        button.toggle_mode = true
        button.button_group = warehouse_group
        button.button_pressed = section == str(choice["key"])
        button.custom_minimum_size.y = 59.0
        button.add_theme_font_size_override("font_size", 19)
        button.add_theme_font_override("font", LaboSkin.control_font())
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _style_terminal_segment(button)
        button.pressed.connect(_invoke_scroll_action.bind(
            _show_inventory.bind(str(choice["key"])), actions_scroll))
        switcher.add_child(button)
    var grid := WarehouseGrid.new()
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    if section == "materials":
        item_layer.add_child(grid)
        var stock: Dictionary = SeraSave.get_material_inventory()
        var entries: Array = []
        # Four families, each with low/mid/high in a single row.
        for family in BaseMaterials.FAMILY_IDS:
            for tier in BaseMaterials.TIERS:
                var id: String = str(family) + "_" + str(tier)
                entries.append({"id": id, "name": BaseMaterials.display_name(id),
                    "count": int(stock[id])})
        grid.name = "WarehouseMaterials"
        grid.configure(entries, 2, "materials")
    else:
        # Seven fixed tabs. The entire hanger stays visible without a
        # horizontal ScrollContainer, even when Android has a narrow viewport.
        var hanger := HBoxContainer.new()
        hanger.name = "WarehouseHangerTabs"
        hanger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hanger.custom_minimum_size.y = LABO_SLOT_HEIGHT
        hanger.add_theme_constant_override("separation", 2)
        modal_actions.add_child(hanger)
        var hanger_group := ButtonGroup.new()
        for slot_index in range(SeraSave.EQUIPMENT_SLOTS.size()):
            var slot: String = str(SeraSave.EQUIPMENT_SLOTS[slot_index])
            var tab: Button = LaboSectionTabScene.instantiate() as Button
            tab.name = "HangerSlot_" + slot
            # Native Button text creates a minimum width and can force the
            # seventh tab outside narrow Android viewports. Render the same
            # caption as a passive child; the Button remains the tap target.
            tab.text = ""
            tab.tooltip_text = _warehouse_slot_name(slot)
            tab.clip_contents = true
            tab.custom_minimum_size = Vector2(0, LABO_SLOT_HEIGHT)
            tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            tab.toggle_mode = true
            tab.button_group = hanger_group
            tab.button_pressed = warehouse_slot == slot
            _style_terminal_segment(tab)
            var caption := Label.new()
            caption.name = "HangerCaption"
            caption.text = _slot_tab_caption(slot)
            caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
            caption.clip_text = true
            caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            caption.add_theme_font_override("font", LaboSkin.control_font())
            caption.add_theme_font_size_override("font_size",
                _slot_font_size() + 1 if tab.button_pressed else maxi(18, _slot_font_size() - 1))
            caption.add_theme_color_override("font_color",
                Color("#e8f4f6") if tab.button_pressed else Color("#aec4d0"))
            tab.add_child(caption)
            caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            tab.pressed.connect(_invoke_scroll_action.bind(
                _select_warehouse_slot.bind(slot_index), actions_scroll))
            hanger.add_child(tab)
        grid.entry_pressed.connect(_on_warehouse_entry_pressed)
        var junk_button := Button.new()
        junk_button.name = "BulkDeleteJunk"
        var junk_count: int = SeraSave.count_junk_prototypes(warehouse_slot)
        junk_button.text = "不用品を一括廃棄 (%d)" % junk_count
        junk_button.custom_minimum_size.y = 56
        junk_button.add_theme_font_size_override("font_size", 20)
        junk_button.disabled = junk_count == 0
        _style_terminal_segment(junk_button)
        junk_button.add_theme_stylebox_override(
            "normal", LaboSkin.terminal_segment_style("destructive"))
        _add_labo_mark_icon(junk_button, "junk")
        # The purge action belongs with the cards, not inside the compact
        # action-tab area. Both navigation rows stay in place and fully visible.
        junk_button.pressed.connect(_confirm_bulk_junk_deletion)
        item_layer.add_child(junk_button)
        item_layer.add_child(grid)
        # WarehouseGrid._ready sets its default node name. Assign the stable
        # search identity only AFTER entering the tree, as in the old layout.
        grid.name = "WarehouseEquipment"
        _show_warehouse_equipment(grid)
    _configure_page_scroll(80 if section == "materials" else 140)
    actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _sync_section_tabs()

func _slot_tab_caption(slot: String) -> String:
    # Two Japanese glyphs on tablets; single glyph on narrow phones.
    var tight: bool = get_viewport().get_visible_rect().size.x < 520.0
    match slot:
        "head": return "頭" if tight else "頭部"
        "torso": return "胴" if tight else "胴体"
        "arms": return "腕" if tight else "腕部"
        "legs": return "脚" if tight else "脚部"
        "booster": return "推" if tight else "推進"
        "weapon_r": return "右" if tight else "右手"
        "weapon_l": return "左" if tight else "左手"
    return slot


func _warehouse_slot_name(slot: String) -> String:
    match slot:
        "head": return "頭部"
        "torso": return "胴体"
        "arms": return "腕部"
        "legs": return "脚部"
        "booster": return "ブースター"
        "weapon_r": return "右手武器"
        "weapon_l": return "左手武器"
    return slot

func _select_warehouse_slot(index: int) -> void:
    if index < 0 or index >= SeraSave.EQUIPMENT_SLOTS.size():
        return
    warehouse_slot = str(SeraSave.EQUIPMENT_SLOTS[index])
    _show_inventory("equipment")

func _show_warehouse_equipment(grid: Control = null) -> void:
    if grid == null:
        grid = item_layer.find_child("WarehouseEquipment", false, false)
    if grid == null:
        return
    var entries: Array = []
    var owned: Array = SeraSave.get_owned_prototypes(warehouse_slot)
    for item in owned:
        var blueprint: String = str(item.get("blueprint", ""))
        var spec: Dictionary = PrototypeCatalog.spec(blueprint)
        if spec.is_empty():
            continue
        entries.append({"uid": str(item.get("uid", "")),
            "blueprint": blueprint, "name": str(spec["name"]),
            "affixes": item.get("affixes", []),
            "favorite": bool(item.get("favorite", false)),
            "junk": bool(item.get("junk", false))})
    modal_body.text = "%s ハンガー  %d / 999" % [
        _warehouse_slot_name(warehouse_slot), owned.size()]
    if not warehouse_notice.is_empty():
        modal_body.text += "\n" + warehouse_notice
    grid.call("configure", entries, 2, "equipment")

func _on_warehouse_entry_pressed(item: Dictionary) -> void:
    if warehouse_section != "equipment":
        return
    _show_warehouse_item_detail(str(item.get("uid", "")))

func _show_warehouse_item_detail(uid: String) -> void:
    # Window overlays STORAGE without replacing its fast virtual list.
    # Stats are calculated once for this actual UID by WarehouseDetailPopup.
    var owned: Array = SeraSave.get_owned_prototypes(warehouse_slot)
    for record in owned:
        var entry: Dictionary = record
        if str(entry.get("uid", "")) != uid:
            continue
        var blueprint: String = str(entry.get("blueprint", ""))
        if PrototypeCatalog.spec(blueprint).is_empty():
            return
        page = "warehouse_item"
        warehouse_detail_popup.open_item(entry)
        return


func _on_warehouse_detail_closed() -> void:
    # Close returns to the exact hanger position; no list reconstruction.
    if page == "warehouse_item":
        page = "inventory"

func _mark_warehouse_item(uid: String, mark: String, enabled: bool) -> void:
    # Success is already represented instantly by the heading icon and
    # action-label state. Only report failure, not a redundant SYSTEM toast.
    var saved: bool = SeraSave.set_prototype_mark(uid, mark, enabled)
    warehouse_notice = "" if saved else "分類を保存できませんでした。"
    _show_warehouse_item_detail(uid)

func _confirm_bulk_junk_deletion() -> void:
    var count: int = SeraSave.count_junk_prototypes(warehouse_slot)
    if count <= 0:
        return
    _request_confirmation("不用品の廃棄確認",
        "%sの不用品 %d 件を削除します。\nお気に入りと装備中の個体は削除しません。\nこの操作は取り消せません。" % [
            _warehouse_slot_name(warehouse_slot), count],
        _delete_warehouse_junk)

func _delete_warehouse_junk() -> void:
    var count: int = SeraSave.delete_junk_prototypes(warehouse_slot)
    warehouse_notice = ("%d 件を削除しました。" % count if count > 0
        else "削除対象なし、または保存に失敗しました。")
    _show_inventory("equipment")

func _show_prototype_catalog() -> void:
    page = "prototypes"
    _clear_actions()
    _diag_begin("craft", CRAFT_CATALOG_SLOTS)
    modal_title.text = "装備製作"
    modal_body.text = "部位と装備を選択してください。完成品は倉庫に登録されます。"
    if SeraSave.active_slot == 0:
        modal_body.text += "\n製作するにはセーブデータが必要です。"
        var available_slot: int = 0
        for slot in range(1, SeraSave.SLOT_COUNT + 1):
            if SeraSave.get_slot(slot).is_empty():
                available_slot = slot
                break
        if available_slot > 0:
            var start := Button.new()
            start.name = "CreateTrialProfile"
            start.text = "セーブを新規作成して製作を始める"
            start.custom_minimum_size.y = 78.0
            start.add_theme_font_size_override("font_size", 20)
            start.pressed.connect(_invoke_scroll_action.bind(
                _create_trial_profile, actions_scroll))
            modal_actions.add_child(start)
        else:
            modal_body.text += "\nセーブの空きがありません。NEXUSで既存データを読み込んでください。"
            _add_terminal_notice("セーブの空きがありません。NEXUSでデータを読み込んでください。")
    if not prototype_notice.is_empty():
        modal_body.text += "\n" + prototype_notice
        _add_terminal_notice(prototype_notice)
    # Identical fixed-width seven-tab layout for craft and warehouse.
    # Short localized labels preserve tap targets without sideways scrolling.
    var slot_tabs := HBoxContainer.new()
    slot_tabs.name = "CraftSlotTabs"
    slot_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slot_tabs.custom_minimum_size.y = LABO_SLOT_HEIGHT
    slot_tabs.add_theme_constant_override("separation", 2)
    modal_actions.add_child(slot_tabs)
    var group := ButtonGroup.new()
    for slot in SeraSave.EQUIPMENT_SLOTS:
        var b: Button = LaboSectionTabScene.instantiate() as Button
        b.name = "CraftSlot_" + str(slot)
        b.text = _slot_tab_caption(str(slot))
        b.tooltip_text = _warehouse_slot_name(str(slot))
        b.toggle_mode = true
        b.button_group = group
        b.button_pressed = craft_slot == str(slot)
        _style_terminal_segment(b)
        b.custom_minimum_size = Vector2(0, LABO_SLOT_HEIGHT)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.add_theme_font_size_override("font_size",
            _slot_font_size() + 1 if b.button_pressed else maxi(18, _slot_font_size() - 1))
        b.add_theme_font_override("font", LaboSkin.control_font())
        b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        b.pressed.connect(_invoke_scroll_action.bind(
            _select_craft_slot.bind(str(slot)), actions_scroll))
        slot_tabs.add_child(b)
    var grid := _new_grid("PrototypeGrid", 1)
    for bp in PrototypeCatalog.ORDER:
        var id: String = str(bp)
        var entry: Dictionary = PrototypeCatalog.spec(id)
        if str(entry.get("slot", "")) != craft_slot:
            continue
        var card: Button = _new_slot(grid, "PrototypeIcon_" + id,
            null, str(entry["name"]),
            LaboStats.baseline(id).replace("\n", " / "),
            _select_prototype.bind(id), "Choose_" + id) as Button
        _queue_card_icon(card, id, true)
    # Each part has twenty positions; unknown blueprints remain locked.
    for slot_number in range(int(grid.get_meta("card_count", 0)) + 1,
            CRAFT_CATALOG_SLOTS + 1):
        _new_slot(grid, "LockedCraftSlot_%02d" % slot_number,
            null, "—  LOCKED SLOT  —",
            "POSITION %02d  /  UNAVAILABLE" % slot_number)
    _finish_grid(grid)
    _configure_page_scroll(158 if modal_actions.get_child_count() > 1 else 82)
    _sync_section_tabs()

func _select_craft_slot(slot: String) -> void:
    if not SeraSave.EQUIPMENT_SLOTS.has(slot):
        return
    craft_slot = slot
    _show_prototype_catalog()

func _select_prototype(blueprint: String) -> void:
    if not PrototypeCatalog.valid(blueprint):
        return
    selected_prototype = blueprint
    _confirm_selected_prototype()

func _confirm_selected_prototype() -> void:
    var spec: Dictionary = PrototypeCatalog.spec(selected_prototype)
    if spec.is_empty():
        return
    _request_confirmation("", "",
        _craft_selected_prototype, selected_prototype)

func _craft_selected_prototype() -> void:
    var uid: String = SeraSave.craft_prototype(selected_prototype)
    if uid.is_empty():
        prototype_notice = "製作できません。セーブデータとハンガー容量（上限999）を確認してください。"
    else:
        prototype_notice = "保管庫に登録：%s" % PrototypeCatalog.display_instance(uid)
    _show_prototype_catalog()

func _render_prototype_detail() -> void:
    _clear_actions()
    var spec: Dictionary = PrototypeCatalog.spec(selected_prototype)
    if spec.is_empty():
        navigate_back()
        return
    modal_title.text = str(spec["name"])
    modal_body.text = "%s\n対象スロット：%s\n試作のため素材消費なし。" % [
        spec["description"], spec["slot"]]
    # Every field in the real authored PartStats profile is shown here;
    # zero-valued stats are deliberately hidden.
    modal_body.text += "\n" + LaboStats.complete_profile_text(selected_prototype)
    if not prototype_notice.is_empty():
        modal_body.text += "\n" + prototype_notice
    # The craft action is above the icon so it cannot be hidden below the fold.
    var make := Button.new()
    make.name = "CraftPrototype"
    make.text = "製作して倉庫に登録"
    make.custom_minimum_size.y = 88.0
    make.add_theme_font_size_override("font_size", 21)
    make.disabled = SeraSave.active_slot == 0
    _style_terminal_segment(make)
    make.pressed.connect(_invoke_scroll_action.bind(
        _confirm_selected_prototype, actions_scroll))
    modal_actions.add_child(make)
    _add_item_tile(IconAtlas.equipment_icon(selected_prototype),
        str(spec["name"]),
        "PrototypePreview_" + selected_prototype)
    _configure_page_scroll(0, true)

func _show_conversion(direction: int) -> void:
    conversion_mode = direction
    conversion_notice = ""
    conversion_batches = 1
    page = "families"
    _render_family_page()

func _render_family_page() -> void:
    _clear_actions()
    _diag_begin("materials", BaseMaterials.all_ids().size())
    modal_title.text = (
        "精製する素材" if conversion_mode == 1
        else "分解する素材")
    modal_body.text = (
        "素材を精製し、より高品質な資材へ変換します。"
        if conversion_mode == 1 else "素材を分解し、低ランクの資材へ戻します。")
    modal_body.visible = conversion_mode == 1
    if diagnostic_button.visible:
        _diag_step("materials inventory load")
    var inventory: Dictionary = SeraSave.get_material_inventory()
    var grid := _new_grid("MaterialFamilyGrid")
    for family in BaseMaterials.FAMILY_IDS:
        for tier in BaseMaterials.TIERS:
            var id: String = str(family) + "_" + str(tier)
            var button_name: String = "Open_" + str(family) if str(tier) == "low" else "Open_" + id
            if diagnostic_button.visible:
                _diag_step("materials " + id + " icon")
            if diagnostic_button.visible:
                _diag_step("materials " + id + " slot")
            var count: int = int(inventory[id])
            var card: Control = _new_slot(grid, "MaterialIcon_" + id,
                null, BaseMaterials.display_lines(id),
                "所持 %d" % count,
                _select_conversion_family.bind(str(family)), button_name)
            card.tooltip_text = "%s / 所持 %d" % [
                BaseMaterials.display_name(id), count]
            card.set_meta("out_of_stock", count == 0)
            # Keep navigation enabled even for missing materials: the recipe
            # remains inspectable, but the conversion action is unavailable.
            if count == 0:
                card.modulate = Color(0.56, 0.56, 0.56, 1.0)
            _queue_card_icon(card as Button, id)
    _finish_grid(grid)

func _select_conversion_family(family: String) -> void:
    if not BaseMaterials.FAMILY_IDS.has(family) or page != "families":
        return
    conversion_family = family
    conversion_batches = 1
    conversion_notice = ""
    page = "conversion"
    _render_conversion()

func _conversion_batches_changed(delta: int) -> void:
    conversion_batches = clampi(conversion_batches + delta, 1, BaseMaterials.MAX_BATCHES)
    conversion_notice = ""
    _render_conversion()

func _perform_conversion(from_rank: int) -> void:
    if not SeraSave.convert_material(
            conversion_family, from_rank, conversion_mode,
            conversion_batches):
        conversion_notice = "素材不足、レシピ不一致、または保存不可のため中止しました。"
    else:
        conversion_notice = "変換完了：所持素材とセーブデータを更新しました。"
    _render_conversion()

func _conversion_batches_set(value: float) -> void:
    conversion_batches = clampi(int(value), 1, BaseMaterials.MAX_BATCHES)
    conversion_notice = ""
    _render_conversion()

func _confirm_conversion(from_rank: int) -> void:
    var plan: Dictionary = BaseMaterials.recipe(
        conversion_family, from_rank, conversion_mode, conversion_batches)
    if plan.is_empty() or not SeraSave.can_convert_material(
            conversion_family, from_rank, conversion_mode, conversion_batches):
        return
    _request_confirmation("精製の確認" if conversion_mode == 1 else "分解の確認",
        "%s ×%d → %s ×%d\n変換回数：%d" % [
            BaseMaterials.display_name(str(plan["input_id"])),
            int(plan["input_count"]),
            BaseMaterials.display_name(str(plan["output_id"])),
            int(plan["output_count"]), conversion_batches],
        _perform_conversion.bind(from_rank))

func _render_conversion() -> void:
    _clear_actions()
    page = "conversion"
    modal_title.text = ("精製 " if conversion_mode == 1
        else "分解 ") + str(BaseMaterials.FAMILY_NAMES[conversion_family])
    var stock: Dictionary = SeraSave.get_material_inventory()
    var lines: PackedStringArray = [
        "変換数を指定し、横長のバーをタップすると確認画面が開きます。",
        "精製：低2→中1→高 / 分解：高1→中2→低（暫定）"
    ]
    if SeraSave.active_slot == 0:
        lines.append("製作にはセーブデータが必要です。")
    if not conversion_notice.is_empty():
        lines.append(conversion_notice)
        _add_terminal_notice(conversion_notice)
    elif SeraSave.active_slot == 0:
        _add_terminal_notice("セーブデータを選択してください。")
    modal_body.text = ("素材を精製してより高品質な資材へ変換します。"
        if conversion_mode == 1 else "\n".join(lines))
    modal_body.visible = conversion_mode == 1
    var ranks: Array = [0, 1] if conversion_mode == 1 else [2, 1]
    for rank in ranks:
        var plan: Dictionary = BaseMaterials.recipe(
            conversion_family, rank, conversion_mode, conversion_batches)
        if plan.is_empty():
            continue
        var source_id: String = str(plan["input_id"])
        var target_id: String = str(plan["output_id"])
        var row := HBoxContainer.new()
        row.name = "ConversionRow_" + str(rank)
        row.custom_minimum_size.y = LABO_CONVERSION_HEIGHT + 8.0
        row.add_theme_constant_override("separation", 7)
        modal_actions.add_child(row)
        # Same native Button-root card as the material list; art is two
        # independent clipped TextureRects rather than Button.icon.
        var bar: Button = LaboMaterialCardScene.instantiate() as Button
        bar.name = "ConvertRank_" + str(rank)
        var conversion_rail := ColorRect.new()
        conversion_rail.name = "ConversionFlowRail"
        conversion_rail.color = Color("#73b8c4")
        conversion_rail.position = Vector2(3.0, 13.0)
        conversion_rail.size = Vector2(3.0, LABO_CONVERSION_HEIGHT - 26.0)
        conversion_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bar.add_child(conversion_rail)
        bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bar.custom_minimum_size.y = LABO_CONVERSION_HEIGHT
        bar.clip_contents = true
        bar.mouse_filter = Control.MOUSE_FILTER_STOP
        bar.text = "%s ×%d  »  %s ×%d" % [
            BaseMaterials.display_name(source_id), int(plan["input_count"]),
            BaseMaterials.display_name(target_id), int(plan["output_count"])]
        bar.add_theme_font_size_override("font_size", 1)
        for text_state in ["font_color", "font_hover_color",
                "font_pressed_color", "font_disabled_color"]:
            bar.add_theme_color_override(text_state, Color.TRANSPARENT)
        var source_icon: TextureRect = bar.get_node(
            "CardContent/Row/ItemArt") as TextureRect
        source_icon.name = "ConvertInputIcon_" + str(rank)
        source_icon.texture = IconAtlas.material_icon_sized(source_id, 48)
        source_icon.custom_minimum_size = Vector2(54, 54)
        var recipe_title: Label = bar.get_node(
            "CardContent/Row/TextStack/ItemTitle") as Label
        # Match all twelve catalog names: one Japanese medium face and size.
        recipe_title.add_theme_font_override("font", LaboSkin.ui_font())
        recipe_title.add_theme_font_size_override(
            "font_size", _uniform_material_name_size)
        recipe_title.autowrap_mode = TextServer.AUTOWRAP_OFF
        recipe_title.max_lines_visible = 1
        recipe_title.text = "%s ×%d" % [
            BaseMaterials.display_name(source_id), int(plan["input_count"])]
        LaboSkin.attach_name_underline(recipe_title)
        var recipe_info: Label = bar.get_node(
            "CardContent/Row/TextStack/ItemInfo") as Label
        recipe_info.add_theme_font_size_override(
            "font_size", _uniform_material_name_size)
        recipe_info.add_theme_font_override("font", LaboSkin.ui_font())
        recipe_info.autowrap_mode = TextServer.AUTOWRAP_OFF
        recipe_info.max_lines_visible = 1
        recipe_info.text = "≫ %s ×%d" % [
            BaseMaterials.display_name(target_id), int(plan["output_count"])]
        LaboSkin.attach_name_underline(recipe_info)
        recipe_info.add_theme_color_override("font_color", Color("#81f0f5"))
        var output_icon := TextureRect.new()
        output_icon.name = "ConvertOutputIcon_" + str(rank)
        output_icon.texture = IconAtlas.material_icon_sized(target_id, 44)
        output_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        output_icon.clip_contents = true
        output_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        output_icon.custom_minimum_size = Vector2(50, 50)
        output_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        output_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        output_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        (bar.get_node("CardContent/Row") as HBoxContainer).add_child(output_icon)
        bar.disabled = not SeraSave.can_convert_material(
            conversion_family, rank, conversion_mode, conversion_batches)
        var none_owned: bool = int(stock.get(source_id, 0)) == 0
        bar.set_meta("out_of_stock", none_owned)
        if none_owned or bar.disabled:
            bar.modulate = Color(0.56, 0.56, 0.56, 1.0)
        bar.pressed.connect(_invoke_scroll_action.bind(
            _confirm_conversion.bind(rank), actions_scroll))
        row.add_child(bar)
        call_deferred("_apply_card_skin", bar)
        # Compact three-cell selector: minus | perfectly centered count | plus.
        # Both refinement and dismantling use the same 1..99 batch contract.
        var stepper := HBoxContainer.new()
        stepper.name = "ConversionStepper_" + str(rank)
        stepper.custom_minimum_size = Vector2(142, 66)
        stepper.add_theme_constant_override("separation", 3)
        stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(stepper)
        var decrement := Button.new()
        decrement.name = "ConversionMinus_" + str(rank)
        decrement.text = "-"
        decrement.custom_minimum_size = Vector2(40, 66)
        decrement.add_theme_font_override("font", LaboSkin.data_font())
        decrement.add_theme_font_size_override("font_size", 28)
        decrement.disabled = conversion_batches <= 1
        _style_terminal_segment(decrement)
        decrement.pressed.connect(_conversion_batches_changed.bind(-1))
        stepper.add_child(decrement)
        var amount_frame := PanelContainer.new()
        amount_frame.name = "ConversionCountFrame_" + str(rank)
        amount_frame.custom_minimum_size = Vector2(52, 66)
        amount_frame.add_theme_stylebox_override(
            "panel", LaboSkin.terminal_segment_style("selected"))
        stepper.add_child(amount_frame)
        var amount_text := Label.new()
        amount_text.name = "ConversionCount_" + str(rank)
        amount_text.text = "%02d" % conversion_batches
        amount_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        amount_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        amount_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        amount_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
        amount_text.add_theme_font_override("font", LaboSkin.data_font())
        amount_text.add_theme_font_size_override("font_size", 24)
        amount_text.add_theme_color_override("font_color", Color("#ebf9fb"))
        amount_frame.add_child(amount_text)
        var increment := Button.new()
        increment.name = "ConversionPlus_" + str(rank)
        increment.text = "+"
        increment.custom_minimum_size = Vector2(40, 66)
        increment.add_theme_font_override("font", LaboSkin.data_font())
        increment.add_theme_font_size_override("font_size", 27)
        increment.disabled = conversion_batches >= BaseMaterials.MAX_BATCHES
        _style_terminal_segment(increment)
        increment.pressed.connect(_conversion_batches_changed.bind(1))
        stepper.add_child(increment)
    _configure_page_scroll(0, true)

func _show_detail(detail: String) -> void:
    if modal_body == null or active_key.is_empty():
        return
    page = "detail"
    modal_title.text = str(_spec_for(active_key)["name"]) + "の説明"
    _clear_actions()
    modal_body.text = detail

func navigate_back() -> void:
    if not is_menu_open():
        return
    if confirmation_overlay != null and confirmation_overlay.visible:
        _dismiss_confirmation()
        return
    if warehouse_detail_popup != null and warehouse_detail_popup.is_open():
        warehouse_detail_popup.close_item()
        return
    match page:
        "conversion":
            page = "families"
            conversion_notice = ""
            _render_family_page()
        "detail":
            open_facility(active_key)
        "prototype_detail":
            prototype_notice = ""
            _show_prototype_catalog()
        "prototypes":
            close_menu()
        "warehouse_item":
            _show_inventory("equipment")
        _:
            close_menu()

func close_menu() -> void:
    if warehouse_detail_popup != null:
        warehouse_detail_popup.close_item()
    _dismiss_confirmation()
    _set_labo_hero(false)
    if modal != null:
        modal.visible = false
    active_key = ""
    page = ""

func _input(event: InputEvent) -> void:
    if not is_menu_open():
        return
    if (font_diag_overlay != null and font_diag_overlay.visible and (
            event.is_action_pressed("ui_cancel") or (
            event is InputEventKey and event.pressed and not event.echo
            and event.keycode in [KEY_BACK, KEY_ESCAPE]))):
        _font_diag_close()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("ui_cancel") or (
            event is InputEventKey and event.pressed and not event.echo
            and event.keycode in [KEY_BACK, KEY_ESCAPE]):
        if confirmation_overlay != null and confirmation_overlay.visible:
            _dismiss_confirmation()
        elif warehouse_detail_popup != null and warehouse_detail_popup.is_open():
            warehouse_detail_popup.close_item()
        else:
            navigate_back()
        get_viewport().set_input_as_handled()

func _on_shade_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        navigate_back()
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed             and event.button_index == MOUSE_BUTTON_LEFT:
        navigate_back()
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if diagnostic_readout != null and diagnostic_readout.visible:
        diag_update_timer += delta
        if diag_update_timer >= 0.35:
            diag_update_timer = 0.0
            _diag_update()
    if generator_rotor != null:
        generator_rotor.rotate_y(delta * 0.95)
