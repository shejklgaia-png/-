extends Node3D
const BaseMaterials = preload("res://scripts/sera_base_materials.gd")
const IconAtlas = preload("res://scripts/sera_item_icons.gd")
const PrototypeCatalog = preload("res://scripts/sera_prototype_catalog.gd")
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const LaboTouchScroll = preload("res://scripts/sera_labo_touch_scroll.gd")
const WarehouseGrid = preload("res://scripts/sera_warehouse_grid.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")
const LaboStats = preload("res://scripts/sera_labo_stats.gd")
const LaboMaterialCardScene = preload("res://ui/labo/LaboMaterialCard.tscn")
const LaboEquipmentCardScene = preload("res://ui/labo/LaboEquipmentCard.tscn")
const LaboSectionTabScene = preload("res://ui/labo/LaboSectionTab.tscn")
# Shared portrait touch-target scale (Godot Control pixels, no extra sprites).
const LABO_NAV_HEIGHT: float = 64.0
const LABO_SLOT_HEIGHT: float = 58.0
const LABO_BACK_HEIGHT: float = 66.0
const LABO_CONFIRM_HEIGHT: float = 70.0
const LABO_CRAFT_CARD_HEIGHT: float = 108.0
const LABO_CONVERSION_HEIGHT: float = 84.0
const MATERIAL_CARD_HEIGHT: float = 108.0
const MATERIAL_ICON_WIDTH: int = 54
## Base field architecture: LABO is one building; resources, power and construction
## are independent physical machines. NEXUS remains in the parent scene.
const FACILITY_SPECS = [
    {"id": "LABO", "name": "LABO", "at": Vector3(0.00, 0.0, -2.20),
        "size": Vector3(4.25, 4.1, 4.35), "subtitle": "Shell / OS / スロット開発"},
    {"id": "SCRAP_COLLECTOR", "name": "回収機", "at": Vector3(-5.10, 0.0, 7.00),
        "size": Vector3(2.35, 2.55, 2.25), "subtitle": "スクラップ収集"},
    {"id": "SMELTER", "name": "精製装置", "at": Vector3(-5.40, 0.0, -4.70),
        "size": Vector3(2.40, 2.85, 2.40), "subtitle": "素材の精製"},
    {"id": "RECYCLER", "name": "分解装置", "at": Vector3(5.30, 0.0, -3.50),
        "size": Vector3(2.45, 2.55, 2.35), "subtitle": "不要素材の分解"},
    {"id": "GENERATOR", "name": "発電機", "at": Vector3(4.70, 0.0, 6.30),
        "size": Vector3(2.40, 3.10, 2.25), "subtitle": "拠点電力"},
    {"id": "STORAGE", "name": "資材保管庫", "at": Vector3(-5.00, 0.0, 0.60),
        "size": Vector3(2.45, 2.15, 2.30), "subtitle": "資源の保管"},
    {"id": "BUILD_TERMINAL", "name": "建設端末", "at": Vector3(0.20, 0.0, 8.00),
        "size": Vector3(2.10, 2.55, 2.10), "subtitle": "拠点の建設・拡張"}
]

var facility_nodes: Dictionary = {}
var facility_tags: Dictionary = {}
var modal: Control
var modal_panel: PanelContainer
var terminal_code: Label
var modal_title: Label
var modal_body: Label
var modal_actions: VBoxContainer
var item_layer: Control
var actions_area: PanelContainer
var actions_scroll: ScrollContainer
var pending_confirmation: Callable = Callable()
var confirmation_overlay: Control
var confirmation_text: Label
var confirmation_title: Label
var craft_slot: String = "head"
var warehouse_notice: String = ""
var warehouse_section: String = "materials"
var warehouse_slot: String = "head"
var owned_blueprint: String = ""
var owned_page: int = 0
var section_tabs: HBoxContainer
var active_key: String = ""
var selected_prototype: String = ""
var prototype_notice: String = ""
var conversion_mode: int = 0
var conversion_family: String = "scrap"
var conversion_batches: int = 1
var conversion_notice: String = ""
var page: String = ""
var generator_rotor: Node3D
var diagnostic_button: Button
var diagnostic_readout: Label
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
        _box(root_node, "Foundation", Vector3(0, 0.16, 0),
            Vector3(float((spec["size"] as Vector3).x), 0.32,
                float((spec["size"] as Vector3).z)), Color("#263747"))
        match key:
            "LABO":
                _build_labo(root_node)
            "SCRAP_COLLECTOR":
                _build_scrap_collector(root_node)
            "SMELTER":
                _build_smelter(root_node)
            "RECYCLER":
                _build_recycler(root_node)
            "GENERATOR":
                _build_generator(root_node)
            "STORAGE":
                _build_storage(root_node)
            "BUILD_TERMINAL":
                _build_construction(root_node)
        var sign := Label3D.new()
        sign.name = "FacilitySign"
        sign.text = str(spec["name"])
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
    var low := Vector2(INF, INF)
    var high := Vector2(-INF, -INF)
    for x in [-size.x * 0.5, size.x * 0.5]:
        for y in [0.0, size.y + 0.6]:
            for z in [-size.z * 0.5, size.z * 0.5]:
                var vertex: Vector3 = parent.to_global(Vector3(x, y, z))
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
    return 19 if width < 540.0 else 21 if width < 720.0 else 22


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
            (child as Button).add_theme_font_size_override("font_size", _nav_font_size())

func _slot_font_size() -> int:
    var width: float = get_viewport().get_visible_rect().size.x
    var per_tab: float = (width * 0.92 - 16.0) / 7.0
    var glyphs: float = 1.0 if width < 520.0 else 2.0
    return clampi(int((per_tab - 16.0) / glyphs), 17, 22)

func _material_card_font_size() -> int:
    var width: float = get_viewport().get_visible_rect().size.x
    return 19 if width >= 590.0 else 17 if width >= 460.0 else 15

func _material_icon_side() -> float:
    var width: float = get_viewport().get_visible_rect().size.x
    return 62.0 if width >= 590.0 else 48.0 if width >= 460.0 else 32.0

func attach_hud(hud: Control) -> void:
    for spec in FACILITY_SPECS:
        var tag := Label.new()
        tag.name = "FieldTag_" + str(spec["id"])
        tag.text = str(spec["name"])
        tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tag.add_theme_font_size_override("font_size", 17)
        tag.add_theme_color_override("font_color", Color("#a5ecf7"))
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
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#0b1924")
    style.border_color = Color("#294653")
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    modal_panel.add_theme_stylebox_override("panel", style)
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
    hero_host.stretch_shrink = 2
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
    header_accent.color = Color("#62cbd6")
    header_accent.custom_minimum_size = Vector2(3, 28)
    header_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header_row.add_child(header_accent)
    modal_title = Label.new()
    modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modal_title.add_theme_font_size_override("font_size", 27)
    modal_title.add_theme_font_override("font", LaboSkin.title_font())
    modal_title.add_theme_color_override("font_color", Color("#f2f8f9"))
    modal_title.mouse_filter = Control.MOUSE_FILTER_STOP
    modal_title.gui_input.connect(_on_modal_title_input)
    header_row.add_child(modal_title)
    terminal_code = Label.new()
    terminal_code.name = "FacilitySystemTag"
    terminal_code.mouse_filter = Control.MOUSE_FILTER_IGNORE
    terminal_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    terminal_code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    terminal_code.add_theme_font_override("font", LaboSkin.data_font())
    terminal_code.add_theme_font_size_override("font_size", 12)
    terminal_code.add_theme_color_override("font_color", Color("#7dabb8"))
    header_row.add_child(terminal_code)
    diagnostic_button = Button.new()
    diagnostic_button.name = "UIDiagnosticToggle"
    diagnostic_button.text = "診断"
    diagnostic_button.visible = false
    diagnostic_button.custom_minimum_size = Vector2(78.0, 46.0)
    diagnostic_button.add_theme_font_size_override("font_size", 16)
    diagnostic_button.tooltip_text = "Android版Godotの一覧表示を診断"
    diagnostic_button.pressed.connect(_diag_toggle)
    header_row.add_child(diagnostic_button)
    # Three fixed, lightweight native Buttons attach to the ACTUAL viewport
    # top-left, separate from the 3D/header/content VBox. The selected tongue
    # hangs 18px lower; the unselected tongues remain short and restrained.
    section_tabs = HBoxContainer.new()
    section_tabs.name = "FacilitySectionTabs"
    section_tabs.mouse_filter = Control.MOUSE_FILTER_PASS
    section_tabs.theme = LaboSkin.common_theme()
    section_tabs.add_theme_constant_override("separation", 4)
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
        button.add_theme_font_override("font", LaboSkin.data_font())
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        button.add_theme_color_override("font_color", Color("#b4cbd5"))
        button.add_theme_color_override("font_pressed_color", Color("#e9fcff"))
        button.add_theme_color_override("font_hover_color", Color("#effbff"))
        button.add_theme_color_override("font_hover_pressed_color", Color("#effbff"))
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
        serial.add_theme_font_override("font", LaboSkin.data_font())
        serial.add_theme_font_size_override("font_size", 11)
        serial.add_theme_color_override("font_color", Color("#819ca9"))
        button.add_child(serial)
        button.pressed.connect(_switch_section.bind(str(entry["target"])))
        section_tabs.add_child(button)
    _layout_section_tabs()
    get_viewport().size_changed.connect(_layout_section_tabs)
    # The 3D viewport retains its own fixed 30% height in the body below.
    modal_body = Label.new()
    modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    modal_body.add_theme_font_size_override("font_size", 19)
    modal_body.add_theme_font_override("font", LaboSkin.ui_font())
    modal_body.add_theme_color_override("font_color", Color("#92abb7"))
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
    close_button.add_theme_font_override("font", LaboSkin.title_font())
    close_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _style_terminal_segment(close_button)
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
    confirm_shade.color = Color(0.01, 0.025, 0.045, 0.86)
    confirm_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    confirm_shade.mouse_filter = Control.MOUSE_FILTER_STOP
    confirm_shade.gui_input.connect(_on_confirmation_shade_input)
    confirmation_overlay.add_child(confirm_shade)
    var confirm_panel := PanelContainer.new()
    confirm_panel.name = "LaboConfirmPanel"
    confirm_panel.anchor_left = 0.09
    confirm_panel.anchor_right = 0.91
    confirm_panel.anchor_top = 0.33
    confirm_panel.anchor_bottom = 0.67
    confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    confirm_panel.theme = LaboSkin.common_theme()
    confirmation_overlay.add_child(confirm_panel)
    var confirm_vbox := VBoxContainer.new()
    confirm_vbox.add_theme_constant_override("separation", 13)
    confirm_panel.add_child(confirm_vbox)
    confirmation_title = Label.new()
    confirmation_title.name = "LaboConfirmTitle"
    confirmation_title.text = "作成しますか？"
    confirmation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirmation_title.add_theme_font_size_override("font_size", 27)
    confirmation_title.add_theme_font_override("font", LaboSkin.title_font())
    confirm_vbox.add_child(confirmation_title)
    confirmation_text = Label.new()
    confirmation_text.name = "LaboConfirmDescription"
    confirmation_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirmation_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    confirmation_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    confirmation_text.add_theme_font_size_override("font_size", 20)
    confirm_vbox.add_child(confirmation_text)
    var confirm_buttons := HBoxContainer.new()
    confirm_buttons.add_theme_constant_override("separation", 8)
    confirm_vbox.add_child(confirm_buttons)
    var cancel_button := Button.new()
    cancel_button.name = "LaboConfirmCancel"
    cancel_button.text = "キャンセル"
    cancel_button.custom_minimum_size.y = LABO_CONFIRM_HEIGHT
    cancel_button.add_theme_font_size_override("font_size", 22)
    cancel_button.add_theme_font_override("font", LaboSkin.title_font())
    cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel_button.pressed.connect(_dismiss_confirmation)
    confirm_buttons.add_child(cancel_button)
    var accept_button := Button.new()
    accept_button.name = "LaboConfirmAccept"
    accept_button.text = "作成"
    accept_button.custom_minimum_size.y = LABO_CONFIRM_HEIGHT
    accept_button.add_theme_font_size_override("font_size", 22)
    accept_button.add_theme_font_override("font", LaboSkin.title_font())
    accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    accept_button.pressed.connect(_accept_confirmation)
    confirm_buttons.add_child(accept_button)

func _set_labo_scroll_input_enabled(enabled: bool) -> void:
    if actions_scroll != null and actions_scroll.has_method("set_touch_scroll_enabled"):
        actions_scroll.call("set_touch_scroll_enabled", enabled)
    if item_layer != null:
        for child in item_layer.get_children():
            if child.has_method("set_touch_scroll_enabled"):
                child.call("set_touch_scroll_enabled", enabled)


func _request_confirmation(title: String, detail: String, action: Callable) -> void:
    if confirmation_overlay == null or not action.is_valid():
        return
    pending_confirmation = action
    _set_labo_scroll_input_enabled(false)
    confirmation_title.text = title
    confirmation_text.text = detail
    confirmation_overlay.visible = true
    confirmation_overlay.move_to_front()

func _dismiss_confirmation() -> void:
    pending_confirmation = Callable()
    _set_labo_scroll_input_enabled(true)
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

func update_tags(camera: Camera3D) -> void:
    if camera == null:
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
            var label_width: float = minf(190.0, maxf(80.0, viewport.x - 16.0))
            tag.size = Vector2(label_width, 40.0)
            tag.position = Vector2(
                clampf(point.x - label_width * 0.5, 8.0,
                    maxf(8.0, viewport.x - label_width - 8.0)),
                clampf(point.y - 22.0, 110.0,
                    maxf(110.0, viewport.y - 130.0)))

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
        if not diagnostic_button.visible:
            diagnostic_readout.visible = false
            diag_update_timer = 0.0
    get_viewport().set_input_as_handled()


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
    # Rebuild only on tab changes; ScrollContainers reuse native Button rendering.
    _configure_page_scroll()
    for child in modal_actions.get_children():
        modal_actions.remove_child(child)
        child.queue_free()
    if item_layer != null:
        for child in item_layer.get_children():
            item_layer.remove_child(child)
            child.queue_free()

func _invoke_scroll_action(action: Callable, scroll: ScrollContainer) -> void:
    # A screen drag may release on the same Button; never treat it as a tap.
    if scroll != null and scroll.has_method("touch_drag_consumed") and (
            bool(scroll.call("touch_drag_consumed"))):
        return
    if action.is_valid():
        action.call()


## Reuse native Android Buttons with a shared, non-glowing console skin.
func _style_terminal_segment(button: Button) -> void:
    button.add_theme_stylebox_override("normal", LaboSkin.terminal_segment_style("normal"))
    button.add_theme_stylebox_override("hover", LaboSkin.terminal_segment_style("hover"))
    button.add_theme_stylebox_override("pressed", LaboSkin.terminal_segment_style("selected"))
    button.add_theme_stylebox_override("hover_pressed", LaboSkin.terminal_segment_style("selected"))
    button.add_theme_stylebox_override("disabled", LaboSkin.terminal_segment_style("disabled"))
    button.add_theme_stylebox_override("focus", LaboSkin.terminal_segment_style("normal"))
    button.add_theme_color_override("font_color", Color("#c3d5dd"))
    button.add_theme_color_override("font_pressed_color", Color("#f1fcff"))
    button.add_theme_color_override("font_hover_pressed_color", Color("#f1fcff"))
    button.add_theme_color_override("font_hover_color", Color("#f1fcff"))


func _add_terminal_notice(message: String) -> void:
    if message.is_empty():
        return
    var notice := Label.new()
    notice.name = "TerminalStatus"
    notice.text = "SYSTEM / " + message
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.add_theme_font_override("font", LaboSkin.ui_font())
    notice.add_theme_font_size_override("font_size", 16)
    notice.add_theme_color_override("font_color", Color("#93d2db"))
    notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    modal_actions.add_child(notice)


func _add_action(label: String, detail: String) -> void:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size.y = 88.0
    button.add_theme_font_size_override("font_size", 22)
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
                terminal_code.text = "MATERIAL / 12"
            "STORAGE":
                terminal_code.text = ("ARCHIVE / 12" if warehouse_section == "materials"
                    else "HANGAR / %03d" % SeraSave.get_owned_prototypes(warehouse_slot).size())
            _:
                terminal_code.text = ""
        terminal_code.visible = get_viewport().get_visible_rect().size.x >= 460.0
    for child in section_tabs.get_children():
        if child is Button:
            var button: Button = child as Button
            var selected: bool = button.name == current
            button.button_pressed = selected
            button.custom_minimum_size.y = (
                LABO_NAV_HEIGHT + 18.0 if selected else LABO_NAV_HEIGHT)


func open_facility(key: String) -> void:
    var spec: Dictionary = _spec_for(key)
    if modal == null or spec.is_empty():
        return
    _dismiss_confirmation()
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
        "GENERATOR":
            modal_body.text = "発電機\n生産設備と拠点施設に電力を供給します。"
            _add_action("稼働状況", "発電機は稼働演出中です。電力容量・消費量は今後のバランス設計で確定します。")
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
    title_label.add_theme_font_override("font", LaboSkin.title_font())
    if material_choice:
        var side: float = _material_icon_side()
        art.custom_minimum_size = Vector2(side, side)
        title_label.add_theme_font_size_override(
            "font_size", _material_card_font_size())
        info_label.add_theme_font_size_override(
            "font_size", maxi(14, _material_card_font_size() - 3))
    else:
        title_label.add_theme_font_size_override("font_size", 21)
        info_label.add_theme_font_size_override("font_size", 17)
        info_label.add_theme_font_override("font", LaboSkin.data_font())
    info_label.text = (info if material_choice else
        info.replace("基礎ステータス（現行Aセット参照） / ", "基礎："))
    row.add_child(card)
    parent.set_meta("card_count", index + 1)
    diag_created += 1
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
    art.custom_minimum_size = Vector2(66, 66)
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(art)
    var caption := Label.new()
    caption.name = "Caption"
    caption.text = title
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 21)
    caption.add_theme_font_override("font", LaboSkin.title_font())
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
        {"key": "materials", "name": "WarehouseMaterialsTab", "caption": "素材"},
        {"key": "equipment", "name": "WarehouseEquipmentTab", "caption": "装備"}
    ]:
        var button: Button = LaboSectionTabScene.instantiate() as Button
        button.name = str(choice["name"])
        button.text = str(choice["caption"])
        button.toggle_mode = true
        button.button_group = warehouse_group
        button.button_pressed = section == str(choice["key"])
        button.custom_minimum_size.y = 59.0
        button.add_theme_font_size_override("font_size", 22)
        button.add_theme_font_override("font", LaboSkin.title_font())
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_invoke_scroll_action.bind(
            _show_inventory.bind(str(choice["key"])), actions_scroll))
        switcher.add_child(button)
    var grid := WarehouseGrid.new()
    item_layer.add_child(grid)
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    if section == "materials":
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
            tab.text = _slot_tab_caption(slot)
            tab.tooltip_text = _warehouse_slot_name(slot)
            tab.custom_minimum_size = Vector2(0, LABO_SLOT_HEIGHT)
            tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            tab.add_theme_font_size_override("font_size", _slot_font_size())
            tab.add_theme_font_override("font", LaboSkin.title_font())
            tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            tab.toggle_mode = true
            tab.button_group = hanger_group
            tab.button_pressed = warehouse_slot == slot
            tab.pressed.connect(_invoke_scroll_action.bind(
                _select_warehouse_slot.bind(slot_index), actions_scroll))
            hanger.add_child(tab)
        grid.name = "WarehouseEquipment"
        grid.entry_pressed.connect(_on_warehouse_entry_pressed)
        var junk_button := Button.new()
        junk_button.name = "BulkDeleteJunk"
        var junk_count: int = SeraSave.count_junk_prototypes(warehouse_slot)
        junk_button.text = "不用品を一括削除 (%d)" % junk_count
        junk_button.custom_minimum_size.y = 66
        junk_button.add_theme_font_size_override("font_size", 20)
        junk_button.disabled = junk_count == 0
        junk_button.pressed.connect(_invoke_scroll_action.bind(
            _confirm_bulk_junk_deletion, actions_scroll))
        modal_actions.add_child(junk_button)
        _show_warehouse_equipment(grid)
    _configure_page_scroll(80 if section == "materials" else 210)
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
    var owned: Array = SeraSave.get_owned_prototypes(warehouse_slot)
    for item in owned:
        if str(item.get("uid", "")) != uid:
            continue
        var blueprint: String = str(item.get("blueprint", ""))
        var spec: Dictionary = PrototypeCatalog.spec(blueprint)
        if spec.is_empty():
            return
        page = "warehouse_item"
        _clear_actions()
        modal_title.text = str(spec["name"])
        modal_body.text = "%s / %s" % [
            uid, _warehouse_slot_name(warehouse_slot)]
        var breakdown := Label.new()
        breakdown.name = "WarehouseStatsBreakdown"
        breakdown.text = LaboStats.total_formula(blueprint, item.get("affixes", []))
        breakdown.add_theme_font_size_override("font_size", 19)
        breakdown.add_theme_font_override("font", LaboSkin.data_font())
        breakdown.add_theme_color_override("font_color", Color("#eff8ff"))
        breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        modal_actions.add_child(breakdown)
        _add_item_tile(IconAtlas.equipment_icon(blueprint),
            str(spec["name"]) + "  " + uid, "WarehouseDetail_" + uid)
        var favorite := Button.new()
        favorite.name = "WarehouseFavoriteToggle"
        favorite.text = "★ お気に入り解除" if bool(item.get("favorite", false)) else "☆ お気に入りにする"
        favorite.custom_minimum_size.y = 70
        favorite.add_theme_font_size_override("font_size", 21)
        favorite.pressed.connect(_invoke_scroll_action.bind(
            _mark_warehouse_item.bind(uid, "favorite",
                not bool(item.get("favorite", false))), actions_scroll))
        modal_actions.add_child(favorite)
        var junk := Button.new()
        junk.name = "WarehouseJunkToggle"
        junk.text = "不用品指定を解除" if bool(item.get("junk", false)) else "不用品に指定"
        junk.custom_minimum_size.y = 70
        junk.add_theme_font_size_override("font_size", 21)
        junk.pressed.connect(_invoke_scroll_action.bind(
            _mark_warehouse_item.bind(uid, "junk",
                not bool(item.get("junk", false))), actions_scroll))
        modal_actions.add_child(junk)
        _configure_page_scroll(0, true)
        return

func _mark_warehouse_item(uid: String, mark: String, enabled: bool) -> void:
    warehouse_notice = (
        "分類を保存しました。" if SeraSave.set_prototype_mark(uid, mark, enabled)
        else "分類を保存できませんでした。")
    _show_warehouse_item_detail(uid)

func _confirm_bulk_junk_deletion() -> void:
    var count: int = SeraSave.count_junk_prototypes(warehouse_slot)
    if count <= 0:
        return
    _request_confirmation("削除しますか？",
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
    _diag_begin("craft", PrototypeCatalog.ORDER.size())
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
    if not prototype_notice.is_empty():
        modal_body.text += "\n" + prototype_notice
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
        b.custom_minimum_size = Vector2(0, LABO_SLOT_HEIGHT)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.add_theme_font_size_override("font_size", _slot_font_size())
        b.add_theme_font_override("font", LaboSkin.title_font())
        b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        b.pressed.connect(_invoke_scroll_action.bind(
            _select_craft_slot.bind(str(slot)), actions_scroll))
        slot_tabs.add_child(b)
    var grid := _new_grid("PrototypeGrid", 1)
    var first_id: String = ""
    for bp in PrototypeCatalog.ORDER:
        var id: String = str(bp)
        var entry: Dictionary = PrototypeCatalog.spec(id)
        if str(entry.get("slot", "")) != craft_slot:
            continue
        if first_id.is_empty():
            first_id = id
        var card: Button = _new_slot(grid, "PrototypeIcon_" + id,
            null, str(entry["name"]),
            LaboStats.baseline(id).replace("\n", " / "),
            _select_prototype.bind(id), "Choose_" + id) as Button
        _queue_card_icon(card, id, true)
    _finish_grid(grid)
    if not first_id.is_empty():
        # Reference image shows an equipment preview directly under the list,
        # framed like a catalog detail. Keep it passive (no extra click targets).
        var preview := PanelContainer.new()
        preview.name = "PrototypeBasePreview"
        preview.custom_minimum_size.y = 137.0
        preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        preview.add_theme_stylebox_override("panel", LaboSkin.card_style("normal"))
        grid.add_child(preview)
        var preview_padding := MarginContainer.new()
        preview_padding.add_theme_constant_override("margin_left", 12)
        preview_padding.add_theme_constant_override("margin_right", 12)
        preview_padding.add_theme_constant_override("margin_top", 10)
        preview_padding.add_theme_constant_override("margin_bottom", 10)
        preview.add_child(preview_padding)
        var preview_row := HBoxContainer.new()
        preview_row.add_theme_constant_override("separation", 14)
        preview_padding.add_child(preview_row)
        var preview_art := TextureRect.new()
        preview_art.name = "PrototypeBaseArt"
        preview_art.texture = IconAtlas.equipment_icon(first_id)
        preview_art.custom_minimum_size = Vector2(100, 100)
        preview_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        preview_row.add_child(preview_art)
        var preview_text := VBoxContainer.new()
        preview_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        preview_row.add_child(preview_text)
        var preview_name := Label.new()
        preview_name.name = "PrototypeBaseName"
        preview_name.text = str(PrototypeCatalog.spec(first_id).get("name", ""))
        preview_name.add_theme_font_override("font", LaboSkin.title_font())
        preview_name.add_theme_font_size_override("font_size", 21)
        preview_name.add_theme_color_override("font_color", Color("#f4ffff"))
        preview_text.add_child(preview_name)
        var baseline := Label.new()
        baseline.name = "PrototypeBaseStats"
        baseline.text = LaboStats.baseline(first_id)
        baseline.add_theme_font_size_override("font_size", 18)
        baseline.add_theme_font_override("font", LaboSkin.data_font())
        baseline.add_theme_color_override("font_color", Color("#c6eaf7"))
        baseline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        preview_text.add_child(baseline)
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
    _request_confirmation("作成しますか？",
        "%s\n%s\n製作後、倉庫に保存します。" % [
            str(spec["name"]), LaboStats.baseline(selected_prototype)],
        _craft_selected_prototype)

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
    modal_body.text += "\n" + LaboStats.baseline(selected_prototype)
    modal_body.text += "\n3D表示は現行のAモデルを使用します。"
    if not prototype_notice.is_empty():
        modal_body.text += "\n" + prototype_notice
    # The craft action is above the icon so it cannot be hidden below the fold.
    var make := Button.new()
    make.name = "CraftPrototype"
    make.text = "製作して倉庫に登録"
    make.custom_minimum_size.y = 88.0
    make.add_theme_font_size_override("font_size", 21)
    make.disabled = SeraSave.active_slot == 0
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
        "素材を選んでランクアップしてください。"
        if conversion_mode == 1 else "素材を選んでランクダウンしてください。")
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
            var card: Control = _new_slot(grid, "MaterialIcon_" + id,
                null, BaseMaterials.display_name(id),
                "所持 %d" % int(inventory[id]),
                _select_conversion_family.bind(str(family)), button_name)
            _queue_card_icon(card as Button, id)
            if str(tier) == "low":
                card.tooltip_text = str(BaseMaterials.FAMILY_NAMES[family])
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
    _request_confirmation("作成しますか？",
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
    modal_body.text = "\n".join(lines)
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
        recipe_title.add_theme_font_override("font", LaboSkin.title_font())
        recipe_title.add_theme_font_size_override("font_size", 19)
        recipe_title.text = "%s ×%d" % [
            BaseMaterials.display_name(source_id), int(plan["input_count"])]
        var recipe_info: Label = bar.get_node(
            "CardContent/Row/TextStack/ItemInfo") as Label
        recipe_info.add_theme_font_size_override("font_size", 19)
        recipe_info.add_theme_font_override("font", LaboSkin.data_font())
        recipe_info.text = "≫ %s ×%d" % [
            BaseMaterials.display_name(target_id), int(plan["output_count"])]
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
        bar.pressed.connect(_invoke_scroll_action.bind(
            _confirm_conversion.bind(rank), actions_scroll))
        row.add_child(bar)
        call_deferred("_apply_card_skin", bar)
        var amount := SpinBox.new()
        amount.name = "ConversionCount_" + str(rank)
        amount.min_value = 1
        amount.max_value = BaseMaterials.MAX_BATCHES
        amount.step = 1
        amount.value = conversion_batches
        amount.rounded = true
        amount.custom_minimum_size = Vector2(92, 72)
        amount.add_theme_font_size_override("font_size", 23)
        amount.add_theme_font_override("font", LaboSkin.data_font())
        amount.tooltip_text = "変換回数"
        amount.value_changed.connect(_conversion_batches_set)
        row.add_child(amount)
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
    _dismiss_confirmation()
    _set_labo_hero(false)
    if modal != null:
        modal.visible = false
    active_key = ""
    page = ""

func _input(event: InputEvent) -> void:
    if not is_menu_open():
        return
    if event.is_action_pressed("ui_cancel") or (
            event is InputEventKey and event.pressed and not event.echo
            and event.keycode in [KEY_BACK, KEY_ESCAPE]):
        if confirmation_overlay != null and confirmation_overlay.visible:
            _dismiss_confirmation()
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
