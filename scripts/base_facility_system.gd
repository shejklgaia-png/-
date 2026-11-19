extends Node3D
## Base field architecture: LABO is one building; resources, power and construction
## are independent physical machines. NEXUS remains in the parent scene.
const FACILITY_SPECS = [
    {"id": "LABO", "name": "LABO", "at": Vector3(-4.90, 0.0, -14.40),
        "size": Vector3(4.25, 4.1, 4.35), "subtitle": "Shell / OS / スロット開発"},
    {"id": "SCRAP_COLLECTOR", "name": "回収機", "at": Vector3(-5.10, 0.0, 7.00),
        "size": Vector3(2.35, 2.55, 2.25), "subtitle": "スクラップ収集"},
    {"id": "SMELTER", "name": "精製炉", "at": Vector3(-5.40, 0.0, -4.70),
        "size": Vector3(2.40, 2.85, 2.40), "subtitle": "素材の精製"},
    {"id": "RECYCLER", "name": "リサイクラー", "at": Vector3(5.30, 0.0, -3.50),
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
var active_key: String = ""
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
        tag.text = str(spec["name"]) + "  ▸"
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
    modal_panel.anchor_left = 0.07
    modal_panel.anchor_top = 0.17
    modal_panel.anchor_right = 0.93
    modal_panel.anchor_bottom = 0.83
    modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#132435")
    style.border_color = Color("#59b9ca")
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    modal_panel.add_theme_stylebox_override("panel", style)
    modal.add_child(modal_panel)
    var padding := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        padding.add_theme_constant_override("margin_" + side, 20)
    modal_panel.add_child(padding)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 15)
    padding.add_child(body)
    modal_title = Label.new()
    modal_title.add_theme_font_size_override("font_size", 28)
    modal_title.add_theme_color_override("font_color", Color("#b8f0ff"))
    body.add_child(modal_title)
    modal_body = Label.new()
    modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    modal_body.add_theme_font_size_override("font_size", 18)
    modal_body.add_theme_color_override("font_color", Color("#dce9ee"))
    body.add_child(modal_body)
    modal_actions = VBoxContainer.new()
    modal_actions.add_theme_constant_override("separation", 12)
    body.add_child(modal_actions)
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(spacer)
    var close_button := Button.new()
    close_button.name = "CloseFacility"
    close_button.text = "閉じる"
    close_button.custom_minimum_size.y = 58.0
    close_button.pressed.connect(close_menu)
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
                    maxf(110.0, viewport.y - 48.0)))

func is_menu_open() -> bool:
    return modal != null and modal.visible

func _clear_actions() -> void:
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

func open_facility(key: String) -> void:
    var spec: Dictionary = _spec_for(key)
    if modal == null or spec.is_empty():
        return
    active_key = key
    modal_title.text = str(spec["name"])
    modal.visible = true
    _clear_actions()
    match key:
        "LABO":
            modal_body.text = "研究開発の統合施設です。\nOS＝機能拡充 / Shell＝性能向上。"
            _add_action("Shell開発", "装備の製作・レアリティ昇格・性能開発を担当します。\n装備レベル制はありません。")
            _add_action("OS開発", "新しいアクションや操作・照準などの機能を解放します。\nジャスト系の機能は採用しません。")
            _add_action("追加効果スロット研究", "装備レアリティごとの上限内で、LABO研究によりスロット枠を解放します。\n装着と交換はNEXUSのアセンブルで行います。")
        "SCRAP_COLLECTOR":
            modal_body.text = "回収機\nフィールドの廃材を回収する設備です。"
            _add_action("回収設備の情報", "スクラップの収集設備です。報酬量と回収方法は経済設計が確定してから接続します。")
        "SMELTER":
            modal_body.text = "精製炉\n基礎資源を装備・建築用の素材に加工します。"
            _add_action("精製工程", "素材の変換比率と製作時間は未確定です。仮の消費や生産を発生させません。")
        "RECYCLER":
            modal_body.text = "リサイクラー\n不要になった資材・パーツを分解する設備です。"
            _add_action("分解工程", "装備・資材の再利用を担当します。確定前の装備を消費する処理は追加しません。")
        "GENERATOR":
            modal_body.text = "発電機\n生産設備と拠点施設に電力を供給します。"
            _add_action("稼働状況", "発電機は稼働演出中です。電力容量・消費量は今後のバランス設計で確定します。")
        "STORAGE":
            modal_body.text = "資材保管庫\n戦闘報酬と設備で得た資材の集積場所です。"
            _add_action("保管の仕組み", "資材の種類・上限が確定した時点で所持数と連動させます。")
        "BUILD_TERMINAL":
            modal_body.text = "建設端末\nフィールド上の設備や床・通路を管理します。"
            _add_action("拠点の発展", "施設を一棟に集約せず、資源・生産・発展設備をフィールド上に独立配置します。\n配置変更と建設コストは今後実装します。")

func _show_detail(detail: String) -> void:
    if modal_body != null:
        modal_body.text = detail

func close_menu() -> void:
    if modal != null:
        modal.visible = false
    active_key = ""

func _on_shade_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        close_menu()
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed             and event.button_index == MOUSE_BUTTON_LEFT:
        close_menu()
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if generator_rotor != null:
        generator_rotor.rotate_y(delta * 0.95)
