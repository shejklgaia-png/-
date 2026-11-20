extends Node3D
const BaseMaterials = preload("res://scripts/sera_base_materials.gd")
const IconAtlas = preload("res://scripts/sera_item_icons.gd")
const PrototypeCatalog = preload("res://scripts/sera_prototype_catalog.gd")
const ChamferSlot = preload("res://scripts/sera_chamfer_slot.gd")
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
var modal_title: Label
var modal_body: Label
var modal_actions: VBoxContainer
var actions_area: PanelContainer
var warehouse_section: String = "materials"
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
    shade.color = Color(0.0, 0.015, 0.035, 0.82)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.gui_input.connect(_on_shade_input)
    modal.add_child(shade)
    modal_panel = PanelContainer.new()
    modal_panel.name = "FacilitySheet"
    modal_panel.anchor_left = 0.04
    modal_panel.anchor_top = 0.08
    modal_panel.anchor_right = 0.96
    modal_panel.anchor_bottom = 0.92
    modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#132435")
    style.border_color = Color("#59b9ca")
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    modal_panel.add_theme_stylebox_override("panel", style)
    modal.add_child(modal_panel)
    var padding := MarginContainer.new()
    padding.name = "FacilityPadding"
    for side in ["left", "right", "top", "bottom"]:
        padding.add_theme_constant_override("margin_" + side, 12)
    modal_panel.add_child(padding)
    var body := VBoxContainer.new()
    body.name = "FacilityContent"
    body.add_theme_constant_override("separation", 9)
    padding.add_child(body)
    var header_row := HBoxContainer.new()
    header_row.name = "FacilityHeaderRow"
    header_row.add_theme_constant_override("separation", 8)
    body.add_child(header_row)
    modal_title = Label.new()
    modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modal_title.add_theme_font_size_override("font_size", 23)
    modal_title.add_theme_color_override("font_color", Color("#b8f0ff"))
    header_row.add_child(modal_title)
    # Persistent, non-scrolling tabs remain accessible in every sub-page.
    section_tabs = HBoxContainer.new()
    section_tabs.name = "FacilitySectionTabs"
    section_tabs.add_theme_constant_override("separation", 5)
    body.add_child(section_tabs)
    for entry in [
        {"id": "TabCraft", "label": "装備製作", "target": "craft"},
        {"id": "TabMaterials", "label": "素材変換", "target": "materials"},
        {"id": "TabWarehouse", "label": "倉庫", "target": "warehouse"}
    ]:
        var button := Button.new()
        button.name = str(entry["id"])
        button.text = str(entry["label"])
        button.toggle_mode = true
        button.custom_minimum_size.y = 58.0
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 17)
        button.add_theme_color_override("font_color", Color("#f4fbff"))
        var inactive := StyleBoxFlat.new()
        inactive.bg_color = Color("#26394b")
        inactive.border_color = Color("#516d7d")
        inactive.set_border_width_all(1)
        inactive.set_corner_radius_all(7)
        button.add_theme_stylebox_override("normal", inactive)
        var active: StyleBoxFlat = inactive.duplicate()
        active.bg_color = Color("#145e74")
        active.border_color = Color("#99edff")
        active.set_border_width_all(2)
        button.add_theme_stylebox_override("pressed", active)
        button.add_theme_stylebox_override("hover", active)
        button.pressed.connect(_switch_section.bind(str(entry["target"])))
        section_tabs.add_child(button)
    modal_body = Label.new()
    modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    modal_body.add_theme_font_size_override("font_size", 16)
    modal_body.add_theme_color_override("font_color", Color("#dce9ee"))
    body.add_child(modal_body)
    # A regular container is intentional: Android screenshots showed that
    # ScrollContainer displayed no item children, despite passing headless tests.
    # All baseline lists are paginated/gridded to fit this fixed content area.
    actions_area = PanelContainer.new()
    actions_area.name = "FacilityActionsArea"
    actions_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    actions_area.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    body.add_child(actions_area)
    modal_actions = VBoxContainer.new()
    modal_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modal_actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
    modal_actions.add_theme_constant_override("separation", 8)
    actions_area.add_child(modal_actions)
    var close_button := Button.new()
    close_button.name = "CloseFacility"
    close_button.text = "戻る"
    close_button.custom_minimum_size.y = 58.0
    close_button.pressed.connect(navigate_back)
    body.add_child(close_button)

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

func _clear_actions() -> void:
    # No ScrollContainer: rebuild the actual grid on each tab transition.
    for child in modal_actions.get_children():
        modal_actions.remove_child(child)
        child.queue_free()

func _add_action(label: String, detail: String) -> void:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size.y = 62.0
    button.add_theme_font_size_override("font_size", 19)
    button.pressed.connect(_show_detail.bind(detail))
    modal_actions.add_child(button)

func _switch_section(target: String) -> void:
    match target:
        "craft":
            open_facility("LABO")
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
            current = "TabCraft"
        "SMELTER", "RECYCLER":
            current = "TabMaterials"
        "STORAGE":
            current = "TabWarehouse"
    for child in section_tabs.get_children():
        if child is Button:
            (child as Button).button_pressed = child.name == current


func open_facility(key: String) -> void:
    var spec: Dictionary = _spec_for(key)
    if modal == null or spec.is_empty():
        return
    active_key = key
    page = "home"
    modal_title.text = str(spec["name"])
    modal.visible = true
    _clear_actions()
    match key:
        "LABO":
            modal_body.text = "研究開発の統合施設です。\nOS＝機能拡充 / Shell＝性能向上。"
            # The working Shell development entry opens the real prototype catalog.
            # Rarity research remains a future feature, not a fake craft action.
            var shell_button := Button.new()
            shell_button.name = "OpenPrototypeCatalog"
            shell_button.text = "試作装備を製作"
            shell_button.icon = IconAtlas.equipment_icon("H01")
            shell_button.custom_minimum_size.y = 74.0
            shell_button.pressed.connect(_show_prototype_catalog)
            modal_actions.add_child(shell_button)
            var trial_button := Button.new()
            trial_button.name = "ClaimTrialMaterials"
            trial_button.text = "試作素材を受け取る"
            trial_button.icon = IconAtlas.material_icon("scrap_mid")
            trial_button.custom_minimum_size.y = 66.0
            trial_button.disabled = SeraSave.active_slot <= 0 or (
                bool(SeraSave.get_active_data().get("trial_materials_claimed", false)))
            trial_button.pressed.connect(_claim_trial_materials)
            modal_actions.add_child(trial_button)
            _add_action("OS開発", "新しいアクションや操作・照準などの機能を解放します。\nジャスト系の機能は採用しません。")
            _add_action("追加効果スロット研究", "装備レアリティごとの上限内で、LABO研究によりスロット枠を解放します。\n装着と交換はNEXUSのアセンブルで行います。")
        "SCRAP_COLLECTOR":
            modal_body.text = "回収機\n現在の所持素材は倉庫で確認できます。"
            var stock_button := Button.new()
            stock_button.name = "OpenMaterialInventory"
            stock_button.text = "素材一覧を表示"
            stock_button.icon = IconAtlas.material_icon("scrap_low")
            stock_button.custom_minimum_size.y = 66.0
            stock_button.pressed.connect(open_facility.bind("STORAGE"))
            modal_actions.add_child(stock_button)
            _add_action("回収設備の情報", "将来の実際の素材回収機能です。試作用素材はLABOから一度だけ受け取れます。")
        "SMELTER":
            _show_conversion(1)
        "RECYCLER":
            _show_conversion(-1)
        "GENERATOR":
            modal_body.text = "発電機\n生産設備と拠点施設に電力を供給します。"
            _add_action("稼働状況", "発電機は稼働演出中です。電力容量・消費量は今後のバランス設計で確定します。")
        "STORAGE":
            _show_inventory()
        "BUILD_TERMINAL":
            modal_body.text = "建設端末\nフィールド上の設備や床・通路を管理します。"
            _add_action("拠点の発展", "施設を一棟に集約せず、資源・生産・発展設備をフィールド上に独立配置します。\n配置変更と建設コストは今後実装します。")
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


func _new_grid(grid_name: String, columns: int = 3) -> GridContainer:
    var grid := GridContainer.new()
    grid.name = grid_name
    grid.columns = columns
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    modal_actions.add_child(grid)
    return grid


func _new_slot(parent: Control, key: String, icon: Texture2D,
        title: String, info: String, action: Callable = Callable(),
        action_name: String = "") -> Control:
    var card := ChamferSlot.new()
    card.name = key
    card.custom_minimum_size = Vector2(108, 100)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(card)
    var pad := MarginContainer.new()
    pad.name = "SlotPadding"
    for side in ["left", "right", "top", "bottom"]:
        pad.add_theme_constant_override("margin_" + side, 6)
    card.add_child(pad)
    var content := VBoxContainer.new()
    content.name = "SlotContent"
    content.add_theme_constant_override("separation", 2)
    pad.add_child(content)
    var image := TextureRect.new()
    image.name = "Icon"
    image.texture = icon
    image.custom_minimum_size = Vector2(43, 43)
    image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(image)
    if action.is_valid():
        var choose := Button.new()
        choose.name = action_name if not action_name.is_empty() else "Select"
        choose.text = title
        choose.custom_minimum_size.y = 28
        choose.add_theme_font_size_override("font_size", 13)
        choose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        choose.pressed.connect(action)
        content.add_child(choose)
    else:
        var heading := Label.new()
        heading.name = "SlotTitle"
        heading.text = title
        heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        heading.add_theme_font_size_override("font_size", 13)
        heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        content.add_child(heading)
    var quantity := Label.new()
    quantity.name = "SlotQuantity"
    quantity.text = info
    quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    quantity.add_theme_font_size_override("font_size", 12)
    quantity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    content.add_child(quantity)
    return card


func _add_item_tile(icon: Texture2D, title: String,
        key: String, parent: VBoxContainer = null) -> void:
    if parent == null:
        parent = modal_actions
    var row := HBoxContainer.new()
    row.name = key
    row.custom_minimum_size.y = 66.0
    parent.add_child(row)
    var art := TextureRect.new()
    art.name = "Icon"
    art.texture = icon
    art.custom_minimum_size = Vector2(58, 58)
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(art)
    var caption := Label.new()
    caption.name = "Caption"
    caption.text = title
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 16)
    row.add_child(caption)


func _show_inventory(section: String = "materials") -> void:
    warehouse_section = section
    page = "inventory"
    _clear_actions()
    modal_title.text = "資材保管庫"
    modal_body.text = "未所持も枠付きで表示します。"
    var switcher := HBoxContainer.new()
    switcher.name = "WarehouseCategoryTabs"
    modal_actions.add_child(switcher)
    for choice in [
        {"key": "materials", "name": "WarehouseMaterialsTab", "caption": "素材12種"},
        {"key": "equipment", "name": "WarehouseEquipmentTab", "caption": "装備7種"}
    ]:
        var button := Button.new()
        button.name = str(choice["name"])
        button.text = str(choice["caption"])
        button.toggle_mode = true
        button.button_pressed = section == str(choice["key"])
        button.custom_minimum_size.y = 47
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_show_inventory.bind(str(choice["key"])))
        switcher.add_child(button)
    if section == "materials":
        var grid := _new_grid("WarehouseMaterials")
        var inventory: Dictionary = SeraSave.get_material_inventory()
        for family in BaseMaterials.FAMILY_IDS:
            for tier in BaseMaterials.TIERS:
                var id: String = str(family) + "_" + str(tier)
                _new_slot(grid, "MaterialIcon_" + id,
                    IconAtlas.material_icon(id), BaseMaterials.display_name(id),
                    "所持 %d" % int(inventory[id]))
    else:
        _show_warehouse_equipment()


func _show_warehouse_equipment() -> void:
    var grid := _new_grid("WarehouseEquipment")
    for bp in PrototypeCatalog.ORDER:
        var id: String = str(bp)
        var spec: Dictionary = PrototypeCatalog.spec(id)
        var owned: Array = []
        for item in SeraSave.get_owned_prototypes(str(spec["slot"])):
            if str(item["blueprint"]) == id:
                owned.append(item)
        var qty: String = "未所持 0" if owned.is_empty() else "所持 %d" % owned.size()
        var card: Control = _new_slot(grid, "WarehouseBlueprint_" + id,
            IconAtlas.equipment_icon(id), str(spec["name"]), qty,
            _show_owned_items.bind(id, 0), "ShowOwned_" + id)
        if not owned.is_empty():
            var uid := Label.new()
            uid.text = str(owned[owned.size() - 1]["uid"])
            uid.name = "LastCraftedUID"
            uid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            uid.add_theme_font_size_override("font_size", 11)
            (card.find_child("SlotContent", true, false) as VBoxContainer).add_child(uid)


func _show_owned_items(blueprint: String, item_page: int = 0) -> void:
    if not PrototypeCatalog.valid(blueprint):
        return
    owned_blueprint = blueprint
    owned_page = maxi(item_page, 0)
    page = "warehouse_owned"
    _clear_actions()
    var spec: Dictionary = PrototypeCatalog.spec(blueprint)
    modal_title.text = str(spec["name"]) + "の所持品"
    var found: Array = []
    for item in SeraSave.get_owned_prototypes(str(spec["slot"])):
        if str(item["blueprint"]) == blueprint:
            found.append(item)
    modal_body.text = "個体IDで区別します。所持 %d個" % found.size()
    var grid := _new_grid("OwnedEquipmentGrid")
    var start: int = owned_page * 9
    for i in range(start, mini(start + 9, found.size())):
        var uid: String = str(found[i]["uid"])
        _new_slot(grid, "WarehouseItem_" + uid,
            IconAtlas.equipment_icon(blueprint), str(spec["name"]), uid)
    if found.is_empty():
        _new_slot(grid, "WarehouseItemEmpty",
            IconAtlas.equipment_icon(blueprint), str(spec["name"]), "未所持 0")
    if start > 0:
        var previous := Button.new()
        previous.text = "前の9件"
        previous.pressed.connect(_show_owned_items.bind(blueprint, owned_page - 1))
        modal_actions.add_child(previous)
    if start + 9 < found.size():
        var next := Button.new()
        next.text = "次の9件"
        next.pressed.connect(_show_owned_items.bind(blueprint, owned_page + 1))
        modal_actions.add_child(next)


func _show_prototype_catalog() -> void:
    page = "prototypes"
    _clear_actions()
    modal_title.text = "試作装備の製作"
    modal_body.text = (
        "7種類から選択してください。試作は素材消費なし。"
        + "\n完成品は倉庫に登録され、NEXUSで装備できます。")
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
            start.custom_minimum_size.y = 65.0
            start.pressed.connect(_create_trial_profile)
            modal_actions.add_child(start)
        else:
            modal_body.text += "\nセーブの空きがありません。NEXUSで既存データを読み込んでください。"
    if not prototype_notice.is_empty():
        modal_body.text += "\n" + prototype_notice
    if SeraSave.active_slot > 0 and not bool(
            SeraSave.get_active_data().get("trial_materials_claimed", false)):
        var trial := Button.new()
        trial.name = "ClaimTrialMaterialsCatalog"
        trial.text = "試作用素材を受け取る"
        trial.icon = IconAtlas.material_icon("scrap_mid")
        trial.custom_minimum_size.y = 62.0
        trial.pressed.connect(_claim_trial_materials.bind(true))
        modal_actions.add_child(trial)
    var grid := _new_grid("PrototypeGrid")
    for bp in PrototypeCatalog.ORDER:
        var id: String = str(bp)
        var entry: Dictionary = PrototypeCatalog.spec(id)
        var owned_count: int = 0
        for item in SeraSave.get_owned_prototypes(str(entry["slot"])):
            if str(item["blueprint"]) == id:
                owned_count += 1
        _new_slot(grid, "PrototypeIcon_" + id,
            IconAtlas.equipment_icon(id), str(entry["name"]),
            "未作成 0" if owned_count == 0 else "所持 %d" % owned_count,
            _select_prototype.bind(id), "Choose_" + id)

func _select_prototype(blueprint: String) -> void:
    if not PrototypeCatalog.valid(blueprint):
        return
    selected_prototype = blueprint
    prototype_notice = ""
    page = "prototype_detail"
    _render_prototype_detail()

func _craft_selected_prototype() -> void:
    var uid: String = SeraSave.craft_prototype(selected_prototype)
    if uid.is_empty():
        prototype_notice = "製作できません。NEXUSでセーブデータを選択してください。"
    else:
        prototype_notice = "保管庫に登録：%s" % PrototypeCatalog.display_instance(uid)
    _render_prototype_detail()

func _render_prototype_detail() -> void:
    _clear_actions()
    var spec: Dictionary = PrototypeCatalog.spec(selected_prototype)
    if spec.is_empty():
        navigate_back()
        return
    modal_title.text = str(spec["name"])
    modal_body.text = "%s\n対象スロット：%s\n試作のため素材消費なし。" % [
        spec["description"], spec["slot"]]
    modal_body.text += "\n3D表示は現行のAモデルを使用します。"
    if not prototype_notice.is_empty():
        modal_body.text += "\n" + prototype_notice
    # The craft action is above the icon so it cannot be hidden below the fold.
    var make := Button.new()
    make.name = "CraftPrototype"
    make.text = "製作して倉庫に登録"
    make.custom_minimum_size.y = 74.0
    make.disabled = SeraSave.active_slot == 0
    make.pressed.connect(_craft_selected_prototype)
    modal_actions.add_child(make)
    _add_item_tile(IconAtlas.equipment_icon(selected_prototype),
        str(spec["name"]),
        "PrototypePreview_" + selected_prototype)

func _show_conversion(direction: int) -> void:
    conversion_mode = direction
    conversion_notice = ""
    conversion_batches = 1
    page = "families"
    _render_family_page()

func _render_family_page() -> void:
    _clear_actions()
    modal_title.text = (
        "精製する素材" if conversion_mode == 1
        else "分解する素材")
    modal_body.text = (
        "素材を選んでランクアップしてください。"
        if conversion_mode == 1 else "素材を選んでランクダウンしてください。")
    var inventory: Dictionary = SeraSave.get_material_inventory()
    var grid := _new_grid("MaterialFamilyGrid")
    for family in BaseMaterials.FAMILY_IDS:
        for tier in BaseMaterials.TIERS:
            var id: String = str(family) + "_" + str(tier)
            var button_name: String = "Open_" + str(family) if str(tier) == "low" else "Open_" + id
            var card: Control = _new_slot(grid, "MaterialIcon_" + id,
                IconAtlas.material_icon(id), BaseMaterials.display_name(id),
                "所持 %d" % int(inventory[id]),
                _select_conversion_family.bind(str(family)), button_name)
            if str(tier) == "low":
                var caption := Label.new()
                caption.name = "FamilyChoice_" + str(family)
                caption.text = str(BaseMaterials.FAMILY_NAMES[family])
                caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                caption.add_theme_font_size_override("font_size", 11)
                (card.find_child("SlotContent", true, false) as VBoxContainer).add_child(caption)

func _select_conversion_family(family: String) -> void:
    if not BaseMaterials.FAMILY_IDS.has(family) or page != "families":
        return
    conversion_family = family
    conversion_batches = 1
    conversion_notice = ""
    page = "conversion"
    _render_conversion()

func _conversion_batches_changed(delta: int) -> void:
    conversion_batches = clampi(conversion_batches + delta, 1, 99)
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

func _render_conversion() -> void:
    _clear_actions()
    modal_title.text = (
        "精製 " if conversion_mode == 1
        else "分解 ") + str(BaseMaterials.FAMILY_NAMES[conversion_family])
    var stock: Dictionary = SeraSave.get_material_inventory()
    # Counts are displayed alongside each actual input/output icon below.
    # Avoid a large repeated explanation pushing the action buttons off-screen.
    var lines: Array[String] = [
        "素材のランクと所持数を確認して変換してください。",
        "精製：低2→中1→高 / 分解：上1→下2（暫定）"
    ]
    if SeraSave.active_slot == 0:
        lines.append("先にNEXUSでセーブスロットを作成・選択してください。")
    if not conversion_notice.is_empty():
        lines.append(conversion_notice)
    modal_body.text = "\n".join(lines)

    var amount_row := HBoxContainer.new()
    amount_row.name = "ConversionAmount"
    amount_row.add_theme_constant_override("separation", 12)
    modal_actions.add_child(amount_row)
    var less := Button.new()
    less.name = "DecreaseBatch"
    less.text = "−"
    less.custom_minimum_size = Vector2(70, 58)
    less.disabled = conversion_batches <= 1
    less.pressed.connect(_conversion_batches_changed.bind(-1))
    amount_row.add_child(less)
    var count := Label.new()
    count.name = "BatchCount"
    count.text = "実行回数：%d" % conversion_batches
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    count.add_theme_font_size_override("font_size", 19)
    amount_row.add_child(count)
    var more := Button.new()
    more.name = "IncreaseBatch"
    more.text = "+"
    more.custom_minimum_size = Vector2(70, 58)
    more.disabled = conversion_batches >= 99
    more.pressed.connect(_conversion_batches_changed.bind(1))
    amount_row.add_child(more)

    var ranks: Array = [0, 1] if conversion_mode == 1 else [2, 1]
    for rank in ranks:
        var plan: Dictionary = BaseMaterials.recipe(
            conversion_family, rank, conversion_mode, conversion_batches)
        var source_id: String = str(plan["input_id"])
        var target_id: String = str(plan["output_id"])
        # Icon + amount -> arrow -> icon + amount, directly above the action.
        var flow := HBoxContainer.new()
        flow.name = "ConvertInputIcon_" + str(rank)
        flow.custom_minimum_size.y = 71.0
        flow.add_theme_constant_override("separation", 6)
        modal_actions.add_child(flow)
        var input_icon := TextureRect.new()
        input_icon.name = "Input"
        input_icon.texture = IconAtlas.material_icon(source_id)
        input_icon.custom_minimum_size = Vector2(61, 61)
        input_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        flow.add_child(input_icon)
        var consume := Label.new()
        consume.name = "SourceRank"
        consume.text = "%s ×%s\n所持 %s" % [
            ["低", "中", "高"][rank], str(plan["input_count"]),
            str(stock[source_id])]
        consume.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        consume.add_theme_font_size_override("font_size", 14)
        flow.add_child(consume)
        var arrow := Label.new()
        arrow.text = "→"
        arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        arrow.add_theme_font_size_override("font_size", 23)
        flow.add_child(arrow)
        var output_icon := TextureRect.new()
        output_icon.name = "Output"
        output_icon.texture = IconAtlas.material_icon(target_id)
        output_icon.custom_minimum_size = Vector2(61, 61)
        output_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        flow.add_child(output_icon)
        var gained := Label.new()
        gained.name = "TargetRank"
        gained.text = "%s ×%s\n所持 %s" % [
            ["低", "中", "高"][rank + conversion_mode],
            str(plan["output_count"]), str(stock[target_id])]
        gained.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        gained.add_theme_font_size_override("font_size", 14)
        flow.add_child(gained)
        var button := Button.new()
        button.name = "ConvertRank_" + str(rank)
        button.text = "%s から %sへ変換" % [
            BaseMaterials.display_name(source_id),
            BaseMaterials.display_name(target_id)]
        button.custom_minimum_size.y = 66.0
        button.add_theme_font_size_override("font_size", 16)
        button.disabled = not SeraSave.can_convert_material(
            conversion_family, rank, conversion_mode, conversion_batches)
        button.pressed.connect(_perform_conversion.bind(rank))
        modal_actions.add_child(button)

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
            open_facility(active_key)
        "warehouse_owned":
            _show_inventory("equipment")
        _:
            close_menu()

func close_menu() -> void:
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
    if generator_rotor != null:
        generator_rotor.rotate_y(delta * 0.95)
