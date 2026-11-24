extends RefCounted
## Dedicated life-size OUTDOOR production sets. BASE icons are design references only.
## All dimensions are authored in metres, never scaled BASE meshes.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const Monitor = preload("res://scripts/sera_labo_monitor_24fps.gd")
const DeckLayout = preload("res://scripts/sera_base_deck_layout.gd")
const DeckLighting = preload("res://scripts/sera_base_floor_lighting.gd")
const Polygon = preload("res://scripts/sera_base_polygon_meshes.gd")
const CONTEXT_SPACING := 4.5
const CONTEXT_MODEL_SCALE := 2.0
var context_root: Node3D
var context_models: Dictionary = {}
var context_poses: Dictionary = {}
const IndustrialSurface = preload("res://shaders/sera_labo_industrial_surface.gdshader")
const Combustion = preload("res://shaders/sera_labo_combustion.gdshader")
const EQUIPMENT_SCALE := 1.30
var surface_cache: Dictionary = {}
var fallback_texture: ImageTexture
var fire_layers: Array[ShaderMaterial] = []
var fire_light: OmniLight3D
const KEYS = ["LABO", "SMELTER", "RECYCLER", "STORAGE"]
var host: Node3D
var rooms: Dictionary = {}
var targets: Dictionary = {}
var terminals: Dictionary = {}
var inspection: Dictionary = {}
var motion_parts: Dictionary = {}
var screens: Dictionary = {}
var active_key: String = ""
var elapsed: float = 0.0
var cycle_running: bool = false

func build(stage: Node3D) -> void:
    host = stage
    _build_outdoor_deck()
    context_root = _child(host,"DistantBaseFacilities")
    for key in KEYS:
        var room := Node3D.new()
        room.name = key + "_OutdoorWorksite"
        host.add_child(room)
        rooms[key] = room
        targets[key] = []
        screens[key] = []
        motion_parts[key] = {}
        _outdoor_worksite(key)
        match key:
            "LABO": _labo(key)
            "SMELTER": _smelter(key)
            "RECYCLER": _recycler(key)
            "STORAGE": _storage(key)
        _expand_equipment(key)
        room.visible = false

func _model(key: String, label: String, at: Vector3) -> Node3D:
    var n := Node3D.new()
    n.name = label
    (rooms[key] as Node3D).add_child(n)
    n.position = at
    (targets[key] as Array).append(n)
    return n

func _child(parent: Node3D, label: String, at: Vector3 = Vector3.ZERO) -> Node3D:
    var n := Node3D.new()
    n.name = label
    parent.add_child(n)
    n.position = at
    return n

func _batch(n: Node3D):
    var b := Architecture.Batch.new(n)
    b.outline_enabled = true
    return b

func _finish(b) -> void:
    b.flush()
    for child in b.host.get_children():
        if not child is MultiMeshInstance3D:
            continue
        var draw := child as MultiMeshInstance3D
        if not draw.material_override is StandardMaterial3D:
            continue
        var source := draw.material_override as StandardMaterial3D
        draw.set_meta("sera_preserve_authored_material",true)
        if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or source.emission_enabled:
            continue
        var texture: Texture2D = source.albedo_texture
        if texture == null:
            if fallback_texture == null:
                var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
                image.fill(Color.WHITE)
                fallback_texture = ImageTexture.create_from_image(image)
            texture = fallback_texture
        var tint: Color = source.albedo_color
        if tint.get_luminance() < 0.26 and tint != Color(Architecture.COLORS["void"]):
            tint = tint.lerp(Color("#627382"),0.28)
        var cache_key: String = str(texture.get_instance_id()) + "/" + tint.to_html() + "/" + str(source.roughness)
        var mat: ShaderMaterial = surface_cache.get(cache_key) as ShaderMaterial
        if mat == null:
            mat = ShaderMaterial.new()
            mat.shader = IndustrialSurface
            mat.set_shader_parameter("surface_map",texture)
            mat.set_shader_parameter("paint",tint)
            mat.set_shader_parameter("roughness_value",source.roughness)
            surface_cache[cache_key] = mat
        draw.material_override = mat

func _expand_equipment(key: String) -> void:
    # Dedicated industrial models only; never enlarge the BASE icon mesh.
    var room := rooms[key] as Node3D
    for node in targets[key]:
        var model := node as Node3D
        if model.get_parent() != room:
            continue
        if model.name == "OutdoorWorkMarkings":
            continue
        model.position *= EQUIPMENT_SCALE
        if model != terminals.get(key):
            model.scale *= EQUIPMENT_SCALE

func _box(b, p: Vector3, s: Vector3, c: String = "armor") -> void:
    b.box("Panel", p, s, c)

func _shape(b, kind: String, p: Vector3, s: Vector3, c: String = "armor") -> void:
    b.poly("MachinedShape", kind, p, s, c)

func _pipe(b, a: Vector3, z: Vector3, d: float, c: String = "edge") -> void:
    b.rod("Pipe", a, z, d, c)

func _moving(key: String, label: String, n: Node3D) -> void:
    motion_parts[key][label] = n

func _build_outdoor_deck() -> void:
    # One shared BASE-style patchwork floor, not four repeated indoor rooms.
    var floor := _child(host,"OutdoorPatchworkSteelDeck")
    var backing := MeshInstance3D.new()
    backing.name = "ContinuousGround"
    var backing_mesh := BoxMesh.new()
    backing_mesh.size = Vector3(320,0.30,320)
    backing.mesh = backing_mesh
    backing.position.y = -0.24
    var backing_mat := StandardMaterial3D.new()
    backing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    backing_mat.albedo_color = Color("#12171b")
    backing.material_override = backing_mat
    backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    backing.set_meta("sera_outline_occluder_only",true)
    floor.add_child(backing)
    var tints := [Color("#1e2326"),Color("#252729"),Color("#292b2a"),
        Color("#27292c"),Color("#21262a"),Color("#302c29")]
    var groups: Array = [[],[],[],[],[],[]]
    for panel in DeckLayout.generate(24,3.0):
        var center: Vector2 = panel["center"]
        var span: Vector2 = panel["size"]
        groups[int(panel["tint"])].append(Transform3D(
            Basis.IDENTITY.scaled_local(Vector3(span.x,0.30,span.y)),
            Vector3(center.x,-0.18,center.y)))
    # Beyond the detailed 147m deck, cover the horizon with larger steel
    # plates. Four disjoint strips: no z-fighting and only ~300 instances.
    for side in [-1,1]:
        for ring in range(7):
            var outer: float = float(side)*(79.5+12.0*ring)
            for col in range(7):
                var inner: float = -63.0+21.0*col
                groups[posmod(ring+col+side,6)].append(Transform3D(
                    Basis.IDENTITY.scaled_local(Vector3(20.94,0.30,11.94)),
                    Vector3(inner,-0.18,outer)))
            for row in range(15):
                var along: float = -147.0+21.0*row
                groups[posmod(ring+row+side+2,6)].append(Transform3D(
                    Basis.IDENTITY.scaled_local(Vector3(11.94,0.30,20.94)),
                    Vector3(outer,-0.18,along)))
    var plate_mesh: ArrayMesh = Polygon.make("deck")
    var deck_texture: Texture2D = load("res://assets/base/industrial_deck_wear.svg") as Texture2D
    for i in range(tints.size()):
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = plate_mesh
        multi.instance_count = groups[i].size()
        for j in range(multi.instance_count):
            multi.set_instance_transform(j,groups[i][j])
        multi.custom_aabb = AABB(Vector3(-158,-0.4,-158),Vector3(316,0.8,316))
        var draw := MultiMeshInstance3D.new()
        draw.name = "OutdoorDeckBatch_"+str(i)
        draw.multimesh = multi
        var source := StandardMaterial3D.new()
        source.albedo_color = tints[i]
        source.albedo_texture = deck_texture
        source.uv1_offset = Vector3(0.17*float(i%3),0.21*float(i/3),0)
        source.uv1_scale = Vector3(0.93+0.07*float(i%3),0.96+0.06*float(i/3),1)
        var material := DeckLighting.deck_material(source)
        material.set_shader_parameter("top_edge_darkness",0.0)
        material.set_shader_parameter("lower_corner_darkness",0.0)
        draw.material_override = material
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        draw.set_meta("sera_outline_occluder_only",true)
        draw.set_meta("sera_preserve_authored_material",true)
        floor.add_child(draw)

func _outdoor_worksite(key: String) -> void:
    # Open air in every direction. No continuous enclosure or hall ceiling.
    var markings := _model(key,"OutdoorWorkMarkings",Vector3.ZERO)
    var b = _batch(markings)
    for x in [-8.0,8.0]:
        _box(b,Vector3(x,0.005,6.8),Vector3(0.11,0.025,11.0),"caution")
    for x in range(-7,8):
        _box(b,Vector3(float(x)*1.02,0.01,12.3),Vector3(0.68,0.025,0.14),"caution")
    _finish(b)
    for child in markings.get_children():
        if child is GeometryInstance3D:
            child.set_meta("sera_outline_occluder_only",true)

func set_base_context(sources: Dictionary) -> void:
    # Copy render nodes only. No duplicated scripts, lights, particles or UI.
    # Reuse actual BASE mesh resources and current canonical transforms.
    context_poses.clear()
    for key in sources:
        var source := sources[key] as Node3D
        if not is_instance_valid(source):
            continue
        context_poses[key] = {"position":source.global_position,
            "yaw":source.global_rotation.y}
        if context_models.has(key):
            continue
        var body := source.get_node_or_null(
            "NexusArchitecture" if key == "NEXUS" else "IndustrialModel") as Node3D
        if body == null:
            continue
        var proxy := _child(context_root,"Distant_"+str(key))
        proxy.set_meta("sera_outline_role","facility")
        context_models[key] = proxy
        for child in body.get_children():
            if not child is MultiMeshInstance3D:
                continue
            var original := child as MultiMeshInstance3D
            if original.multimesh == null or not original.visible:
                continue
            var draw := MultiMeshInstance3D.new()
            draw.name = original.name
            draw.multimesh = original.multimesh
            draw.material_override = original.material_override
            draw.transform = body.transform * original.transform
            draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            draw.set_meta("sera_preserve_authored_material",true)
            draw.set_meta("FX_NO_OUTLINE",true)
            draw.set_meta("sera_no_view_edges",true)
            proxy.add_child(draw)
    _position_context(active_key)

func _position_context(key: String) -> void:
    if not context_poses.has(key):
        for proxy in context_models.values():
            proxy.visible = false
        return
    var focus: Dictionary = context_poses[key]
    var origin: Vector3 = focus["position"]
    var focus_yaw: float = float(focus["yaw"])+Architecture.facility_yaw_radians(key)
    var inverse := Basis(Vector3.UP,-focus_yaw)
    for id in context_models:
        var proxy: Node3D = context_models[id]
        proxy.visible = id != key and context_poses.has(id)
        if not proxy.visible:
            continue
        var entry: Dictionary = context_poses[id]
        var at: Vector3 = inverse*((entry["position"] as Vector3)-origin)
        at.y = 0.0
        at *= CONTEXT_SPACING
        if at.length() < 29.0 and at.length() > 0.001:
            at = at.normalized()*29.0
        proxy.position = at
        proxy.rotation.y = float(entry["yaw"])-focus_yaw
        proxy.scale = Vector3.ONE*CONTEXT_MODEL_SCALE

func _console(key: String, at: Vector3, mode: int) -> void:
    var n := _model(key,"CrateOperatorTerminal",at)
    terminals[key] = n
    var b = _batch(n)
    _shape(b,"bevel",Vector3(0,0.12,0),Vector3(1.15,0.24,0.95),"trim")
    _shape(b,"gusset",Vector3(0,0.62,0),Vector3(0.67,1.1,0.70),"slate")
    _shape(b,"bevel",Vector3(0,1.23,0),Vector3(1.15,0.63,0.32),"armor")
    _box(b,Vector3(0,0.95,0.28),Vector3(1.12,0.12,0.42),"edge")
    _box(b,Vector3(-0.35,0.99,0.40),Vector3(0.14,0.05,0.12),"blue_light")
    _finish(b)
    var panel := Monitor.new()
    panel.name = "OperatorDisplay"
    panel.position = Vector3(0,1.23,0.18)
    panel.configure(Vector2(0.95,0.46),mode)
    n.add_child(panel)
    panel.set_process(false)
    (screens[key] as Array).append(panel)

func _conveyor(key: String, label: String, at: Vector3, width: float, length: float) -> Node3D:
    var n := _model(key,label,at)
    var b = _batch(n)
    _box(b,Vector3(0,0.72,0),Vector3(width,0.40,length),"slate")
    for x in [-1,1]:
        _box(b,Vector3(x*width*0.49,1.05,0),Vector3(0.16,0.31,length),"caution")
        for z in [-0.39,0.39]:
            _shape(b,"gusset",Vector3(x*width*0.39,0.35,z*length),Vector3(0.28,0.7,0.48),"trim")
    for i in range(int(length/0.32)):
        var z: float = -length*0.5+0.16+i*0.32
        _pipe(b,Vector3(-width*0.44,0.99,z),Vector3(width*0.44,0.99,z),0.18,"edge")
    _finish(b)
    return n

func _cargo(parent: Node3D, label: String, at: Vector3, s: Vector3) -> Node3D:
    var n := _child(parent,label,at)
    var b = _batch(n)
    b.crate(Vector3(0,s.y*0.5,0),s)
    _finish(b)
    return n

func _skid(b, width: float, depth: float) -> void:
    _shape(b,"deck",Vector3(0,0.28,0),Vector3(width,0.56,depth),"slate")
    for side in [-1.0,1.0]:
        _shape(b,"deck",Vector3(side*(width*0.5-0.28),0.34,0),
            Vector3(0.36,0.34,depth-0.35),"edge")
        for z in [-depth*0.39,depth*0.39]:
            _shape(b,"octagonal_slew",Vector3(side*(width*0.5-0.55),0.61,z),
                Vector3(0.30,0.16,0.30),"trim")

func _panel_detail(b, x: float, y: float, z: float, width: float, height: float) -> void:
    _shape(b,"bevel",Vector3(x,y,z),Vector3(width,height,0.16),"slate")
    for side in [-1.0,1.0]:
        for v in [-1.0,1.0]:
            _shape(b,"octagonal_slew",Vector3(x+side*(width*0.5-0.12),y+v*(height*0.5-0.12),z+0.10),
                Vector3(0.12,0.08,0.12),"edge")
    _box(b,Vector3(x,y+height*0.32,z+0.10),Vector3(width*0.54,0.07,0.04),"blue_light")

func _floor_cable(b, points: Array, diameter: float = 0.12) -> void:
    for i in range(points.size()-1):
        _pipe(b,points[i],points[i+1],diameter,"rubber")
        _shape(b,"drum",points[i],Vector3(diameter*1.14,diameter*1.14,diameter*1.14),"rubber")

func _task_light(parent: Node3D, at: Vector3, tint: Color, reach: float, energy: float) -> void:
    var light := OmniLight3D.new()
    light.name = "LocalWorkLight"
    light.position = at
    light.light_color = tint
    light.omni_range = reach
    light.light_energy = energy
    light.shadow_enabled = false
    parent.add_child(light)

func _labo(key: String) -> void:
    # Independent full-size design: BASE's open two-column fabrication bridge,
    # left feedstock racks, rear extraction, central bed and SCARA output arm.
    var frame := _model(key,"OpenFabricationCell",Vector3(0,0,-1.0))
    var b = _batch(frame)
    _skid(b,15.4,12.2)
    _shape(b,"deck",Vector3(0,0.72,0.65),Vector3(14.3,0.32,10.9),"armor")
    _shape(b,"octagonal_slew",Vector3(1.10,1.10,2.0),Vector3(5.9,0.65,4.4),"dark")
    _shape(b,"tray",Vector3(1.10,1.56,2.0),Vector3(6.6,0.46,4.9),"armor_light")
    for side in [-1.0,1.0]:
        var x: float = 1.1+side*3.35
        _shape(b,"gusset",Vector3(x,1.46,1.65),Vector3(1.30,1.45,2.4),"slate")
        _shape(b,"octagonal_slew",Vector3(x,4.70,1.65),Vector3(1.05,6.35,1.1),"armor_light")
        _shape(b,"drum",Vector3(x,7.82,1.65),Vector3(1.38,0.48,1.38),"edge")
        _pipe(b,Vector3(x,1.6,-1.4),Vector3(x,6.65,1.5),0.46,"trim")
        _box(b,Vector3(x,4.5,2.24),Vector3(0.25,3.5,0.10),"lab_cyan")
        _panel_detail(b,x,2.4,2.31,0.62,0.82)
        for y in [2.9,5.7,7.2]:
            _shape(b,"deck",Vector3(x,y,1.65),Vector3(1.25,0.17,1.30),"edge")
    b.poly_tilt("OpenPrinterBridge","octagonal_slew",Vector3(1.10,8.0,1.65),
        Vector3(0.95,7.7,1.10),"slate",Vector3(0,0,PI*0.5))
    _box(b,Vector3(1.10,7.57,1.67),Vector3(6.5,0.22,0.64),"edge")
    _box(b,Vector3(1.10,7.68,2.19),Vector3(6.4,0.11,0.06),"lab_cyan")
    # A short rear guard only. No surrounding building or ceiling.
    _shape(b,"deck",Vector3(0,2.4,-4.95),Vector3(10.8,3.0,0.42),"armor")
    for x in [-3.8,-0.7,2.4]:
        _panel_detail(b,x,2.4,-4.69,2.3,1.9)
    _finish(b)
    inspection[key] = {"root":frame,"stand":Vector3(-0.8,0,7.0),"focus":Vector3(1.1,2.0,2.0)}
    var carriage_mount := _child(frame,"PrinterCarriagePlacement",Vector3(1.10,7.40,1.65))
    (targets[key] as Array).append(carriage_mount)
    var carriage := _child(carriage_mount,"Carriage")
    b = _batch(carriage)
    b.poly_tilt("DriveMotor","drum",Vector3(0,0.12,0),Vector3(1.50,1.10,1.50),"slate",Vector3(0,0,PI*0.5))
    _shape(b,"bevel",Vector3(0,-0.55,0.16),Vector3(1.50,1.1,1.4),"armor")
    _shape(b,"louver",Vector3(0,-0.55,0.91),Vector3(0.96,0.62,0.16),"trim")
    _finish(b)
    var head_mount := _child(carriage,"PrintHeadPlacement",Vector3(0,-1.0,0.35))
    (targets[key] as Array).append(head_mount)
    var head := _child(head_mount,"HotEnd")
    b = _batch(head)
    _pipe(b,Vector3(0,0,0),Vector3(0,-2.65,0),0.45,"edge")
    _shape(b,"octagonal_slew",Vector3(0,-2.68,0),Vector3(1.00,0.88,1.00),"gold")
    _shape(b,"drum",Vector3(0,-3.22,0),Vector3(0.44,0.24,0.44),"amber_light")
    _finish(b)
    _moving(key,"bridge",carriage)
    _moving(key,"head",head)
    var rack := _model(key,"FeedstockRacks",Vector3(-6.4,0,-3.0))
    b = _batch(rack)
    for x in [-1.7,1.7]:
        for z in [-0.9,0.9]:
            _shape(b,"octagonal_slew",Vector3(x,3.5,z),Vector3(0.36,7.0,0.36),"slate")
        _pipe(b,Vector3(x,0.5,-0.9),Vector3(x,6.4,0.9),0.18,"edge")
    for y in [1.0,3.7,6.3]:
        _shape(b,"tray",Vector3(0,y,0),Vector3(3.9,0.36,2.35),"armor_light")
    _shape(b,"cargo_case",Vector3(0,1.75,0),Vector3(3.1,1.2,1.8),"crate")
    b.poly_tilt("FeedSpool","vent_stack",Vector3(-0.94,4.6,0),Vector3(1.75,0.78,1.75),"edge",Vector3(PI*0.5,0,0))
    _shape(b,"drum",Vector3(0.98,4.7,0),Vector3(1.10,1.65,1.10),"blue")
    _shape(b,"gear",Vector3(0.98,5.62,0),Vector3(1.24,0.24,1.24),"gold")
    _shape(b,"roof",Vector3(0,7.25,-0.20),Vector3(4.5,0.22,2.8),"armor")
    _finish(b)
    var supply := _model(key,"ReceivingHopperAndFeed",Vector3(-8.1,0,2.8))
    b = _batch(supply)
    _shape(b,"hopper",Vector3(0,2.65,0),Vector3(2.8,2.0,2.7),"armor_light")
    for x in [-0.9,0.9]:
        _shape(b,"gusset",Vector3(x,0.9,0),Vector3(0.50,1.8,1.4),"slate")
    _pipe(b,Vector3(0,1.78,0),Vector3(0.7,1.78,-5.8),0.57,"trim")
    _pipe(b,Vector3(0.7,1.78,-5.8),Vector3(1.7,2.1,-5.8),0.57,"edge")
    _finish(b)
    var extraction := _model(key,"RearExtractionAndCoolant",Vector3(5.4,0,-4.5))
    b = _batch(extraction)
    _shape(b,"vent_stack",Vector3(0,5.1,0),Vector3(2.0,10.2,2.0),"slate")
    _shape(b,"drum",Vector3(0,8.0,0),Vector3(2.6,0.64,2.6),"edge")
    _shape(b,"louver",Vector3(0,3.5,1.1),Vector3(1.45,1.7,0.25),"trim")
    _shape(b,"hood",Vector3(-2.1,8.5,0.8),Vector3(3.7,0.9,2.6),"armor_light")
    _pipe(b,Vector3(0,8.5,0),Vector3(-2.1,8.5,0.8),0.82,"trim")
    _shape(b,"drum",Vector3(-2.2,2.0,-0.5),Vector3(1.65,3.6,1.65),"blue")
    for y in [0.65,3.55]:
        _shape(b,"gear",Vector3(-2.2,y,-0.5),Vector3(1.9,0.28,1.9),"edge")
    _pipe(b,Vector3(-2.2,0.9,0.1),Vector3(-2.2,0.9,4.6),0.34,"gold")
    _finish(b)
    # Left output stock pocket is connected by an articulated two-link arm.
    var tray := _child(frame,"FinishedStockReceiver",Vector3(-5.4,0,0.3))
    (targets[key] as Array).append(tray)
    b = _batch(tray)
    _shape(b,"tray",Vector3(0,1.12,0),Vector3(3.1,1.1,3.1),"crate")
    _shape(b,"deck",Vector3(0,1.50,0),Vector3(2.6,0.18,2.6),"edge")
    _box(b,Vector3(0,1.15,1.58),Vector3(1.7,0.2,0.08),"lab_cyan")
    _finish(b)
    var arm_mount := _child(frame,"SCARAPlacement",Vector3(-2.25,0,-0.6))
    (targets[key] as Array).append(arm_mount)
    b = _batch(arm_mount)
    _shape(b,"octagonal_slew",Vector3(0,0.95,0),Vector3(1.65,0.55,1.65),"dark")
    _shape(b,"octagonal_slew",Vector3(0,4.35,0),Vector3(0.88,6.8,0.88),"slate")
    _shape(b,"drum",Vector3(0,7.85,0),Vector3(1.45,0.55,1.45),"edge")
    _finish(b)
    var shoulder := _child(arm_mount,"Shoulder",Vector3(0,7.85,0))
    b = _batch(shoulder)
    _shape(b,"bevel",Vector3(0,0,1.95),Vector3(0.94,0.66,4.05),"gold")
    _pipe(b,Vector3(0.34,0.35,0.30),Vector3(0.34,0.35,3.6),0.13,"rubber")
    _finish(b)
    var elbow := _child(shoulder,"Elbow",Vector3(0,0,3.9))
    b = _batch(elbow)
    _shape(b,"drum",Vector3(0,0,0),Vector3(1.05,0.72,1.05),"edge")
    _shape(b,"bevel",Vector3(0,0,1.95),Vector3(0.72,0.50,4.05),"armor_light")
    _finish(b)
    var wrist := _child(elbow,"Wrist",Vector3(0,0,3.9))
    b = _batch(wrist)
    _shape(b,"drum",Vector3(0,0,0),Vector3(0.85,0.48,0.85),"slate")
    _pipe(b,Vector3(0,0,0),Vector3(0,-2.5,0),0.28,"edge")
    _finish(b)
    var gripper := _child(wrist,"TelescopingGrip",Vector3(0,-2.5,0))
    b = _batch(gripper)
    _pipe(b,Vector3(0,0,0),Vector3(0,-1.75,0),0.17,"edge")
    _shape(b,"deck",Vector3(0,-1.75,0),Vector3(2.1,0.27,0.72),"gold")
    for x in [-0.96,0.96]:
        _shape(b,"deck",Vector3(x,-2.1,0),Vector3(0.22,0.74,0.72),"edge")
    _finish(b)
    _moving(key,"shoulder",shoulder)
    _moving(key,"elbow",elbow)
    _moving(key,"gripper",gripper)
    _moving(key,"arm_mount",arm_mount)
    _moving(key,"tray",tray)
    var product_root := _child(frame,"FabricatedWorkpieces",Vector3(1.1,1.8,2.0))
    (targets[key] as Array).append(product_root)
    for i in range(4):
        var piece := _child(product_root,"Product"+str(i))
        b = _batch(piece)
        match i:
            0: _shape(b,"vent_stack",Vector3(0,0.65,0),Vector3(1.65,1.3,1.55),"blue")
            1: _shape(b,"gear",Vector3(0,0.45,0),Vector3(1.75,0.9,1.75),"edge")
            2: _shape(b,"bevel",Vector3(0,0.55,0),Vector3(1.9,1.1,1.6),"armor_light")
            3: _shape(b,"octagonal_slew",Vector3(0,0.7,0),Vector3(1.55,1.4,1.55),"gold")
        _finish(b)
        piece.visible = false
    _moving(key,"products",product_root)
    motion_parts[key]["variant"] = -1
    var utility := _model(key,"LabPowerAndTaskLighting",Vector3(7.3,0,2.5))
    b = _batch(utility)
    _shape(b,"bevel",Vector3(0,1.0,0),Vector3(1.45,2.0,1.2),"slate")
    _panel_detail(b,0,1.12,0.65,1.1,1.5)
    _pipe(b,Vector3(0,1.9,0),Vector3(0,6.0,0),0.22,"trim")
    _pipe(b,Vector3(0,6.0,0),Vector3(-1.9,6.0,-0.4),0.22,"edge")
    _shape(b,"hood",Vector3(-1.9,6.0,-0.4),Vector3(1.1,0.35,0.7),"armor")
    _box(b,Vector3(-1.9,5.79,-0.4),Vector3(0.8,0.07,0.52),"amber_light")
    _floor_cable(b,[Vector3(0,0.1,0.6),Vector3(0,0.1,2.1),Vector3(-1.7,0.1,2.8),Vector3(-3.3,0.1,2.8)])
    _finish(b)
    _task_light(utility,Vector3(-1.9,5.52,-0.4),Color("#ffe0b2"),8.0,1.4)
    _console(key,Vector3(3.2,0,6.6),0)

func _smelter(key: String) -> void:
    var furnace := _model(key,"RefractorySmeltingFurnace",Vector3(0,0,-2.0))
    var b = _batch(furnace)
    _shape(b,"deck",Vector3(0,0.4,0),Vector3(10.0,0.8,7.0),"slate")
    _shape(b,"octagonal_slew",Vector3(0,4.0,-0.7),Vector3(7.4,6.4,6.0),"armor")
    _shape(b,"gear",Vector3(0,1.15,-0.7),Vector3(8.05,0.46,6.5),"trim")
    _shape(b,"gear",Vector3(0,7.28,-0.7),Vector3(8.05,0.48,6.6),"edge")
    _shape(b,"drum",Vector3(0,7.78,-0.7),Vector3(6.9,0.48,5.6),"blue_light")
    _shape(b,"octagonal_slew",Vector3(0,8.25,-0.7),Vector3(7.4,0.45,6.0),"slate")
    _shape(b,"hood",Vector3(0,8.78,-0.7),Vector3(6.2,0.65,5.3),"armor_light")
    for side in [-1.0,1.0]:
        var x: float = side*4.15
        _shape(b,"drum",Vector3(x,3.45,-0.55),Vector3(1.75,4.8,1.75),"blue")
        for y in [1.25,5.65]:
            _shape(b,"gear",Vector3(x,y,-0.55),Vector3(2.05,0.32,2.05),"edge")
        _pipe(b,Vector3(x,5.85,-0.55),Vector3(x,7.15,-0.55),0.38,"gold")
        _pipe(b,Vector3(x,7.15,-0.55),Vector3(side*2.85,7.15,-0.55),0.38,"gold")
        _pipe(b,Vector3(x,1.1,-0.55),Vector3(side*2.95,0.9,-0.55),0.48,"trim")
        _shape(b,"louver",Vector3(x,3.2,0.42),Vector3(1.25,2.1,0.25),"armor_light")
        _panel_detail(b,x,2.0,0.59,0.84,0.9)
        _shape(b,"gusset",Vector3(x,0.72,-0.55),Vector3(1.4,1.2,1.5),"slate")
        _pipe(b,Vector3(side*2.7,7.8,-1.5),Vector3(side*2.65,8.65,-2.7),0.85,"trim")
    for x in [-2.4,2.4]:
        _panel_detail(b,x,4.9,2.32,1.8,1.8)
    # Separate refractory throat in front of the sealed vessel; unobstructed window.
    _box(b,Vector3(0,3.0,3.55),Vector3(4.8,4.2,0.42),"void")
    for x in [-2.7,2.7]:
        _shape(b,"bevel",Vector3(x,3.2,3.9),Vector3(0.7,4.8,0.95),"armor_light")
        _box(b,Vector3(x,3.2,4.42),Vector3(0.22,3.8,0.15),"rust")
    for y in [0.9,5.5]:
        _shape(b,"bevel",Vector3(0,y,3.9),Vector3(5.8,0.62,0.95),"slate")
    for x in [-3.2,3.2]:
        _pipe(b,Vector3(x,1.1,2.5),Vector3(x,6.8,2.5),0.38,"rust")
    for i in range(5):
        _box(b,Vector3(0,6.1+i*0.18,3.0),Vector3(4.8,0.09,0.15),"edge")
    _finish(b)
    inspection[key] = {"root":furnace,"stand":Vector3(2.4,0,5.3),"focus":Vector3(0,3.0,4.1)}
    var hot := _child(furnace,"RecessedFire",Vector3(0,3.0,3.80))
    (targets[key] as Array).append(hot)
    for i in range(3):
        var flame := MeshInstance3D.new()
        flame.name = "CombustionLayer"+str(i)
        var quad := QuadMesh.new()
        quad.size = Vector2(4.46-float(i)*0.23,3.92-float(i)*0.20)
        flame.mesh = quad
        flame.position = Vector3(0.045*float(i-1),-0.10*float(i),0.19*float(i))
        var mat := ShaderMaterial.new()
        mat.shader = Combustion
        mat.set_shader_parameter("layer_phase",float(i)*0.371)
        mat.set_shader_parameter("layer_opacity",[0.93,0.57,0.36][i])
        flame.material_override = mat
        flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        flame.set_meta("FX_NO_OUTLINE",true)
        flame.set_meta("sera_no_view_edges",true)
        flame.set_meta("sera_preserve_authored_material",true)
        hot.add_child(flame)
        fire_layers.append(mat)
    fire_light = OmniLight3D.new()
    fire_light.name = "LocalizedFurnaceRadiance"
    fire_light.position = Vector3(0,2.0,4.50)
    fire_light.light_color = Color("#ff9b54")
    fire_light.light_energy = 1.5
    fire_light.omni_range = 5.2
    fire_light.shadow_enabled = false
    furnace.add_child(fire_light)
    var throat := _child(furnace,"RefractoryLining")
    b = _batch(throat)
    for side in [-1,1]:
        _box(b,Vector3(side*2.33,3.18,4.04),Vector3(0.24,4.13,0.85),"rust")
        _box(b,Vector3(side*1.85,3.19,4.51),Vector3(0.085,4.05,0.15),"trim")
    _box(b,Vector3(0,0.99,4.0),Vector3(4.55,0.20,0.86),"rust")
    for x in [-1.35,1.35]:
        _box(b,Vector3(x,3.18,4.56),Vector3(0.10,4.05,0.13),"trim")
        for y in [1.20,5.12]:
            _shape(b,"bevel",Vector3(x,y,4.54),Vector3(0.30,0.20,0.27),"edge")
    for i in range(7):
        _shape(b,"gear",Vector3(-1.80+i*0.60,1.12,4.0),Vector3(0.32,0.12,0.32),"edge")
    _finish(b)
    for i in range(2):
        var stack := _model(key,"ExhaustStack"+str(i),Vector3(-2.1+i*4.2,0,-4.7))
        b = _batch(stack)
        _shape(b,"vent_stack",Vector3(0,10.2,0),Vector3(1.65,8.3,1.65),"slate")
        _pipe(b,Vector3(0,6.05,0),Vector3(0,5.0,1.25),0.96,"trim")
        _shape(b,"drum",Vector3(0,8.15,0),Vector3(2.1,0.64,2.1),"rust")
        for y in [9.3,11.5,13.45]:
            _shape(b,"gear",Vector3(0,y,0),Vector3(2.15,0.29,2.15),"edge")
        for y in [7.1,8.5,9.9]:
            _shape(b,"octagonal_slew",Vector3(0,y,0),Vector3(1.65,0.24,1.65),"edge")
        _shape(b,"vent_stack",Vector3(0,14.25,0),Vector3(2.0,0.46,2.0),"edge")
        _finish(b)
    var feed := _model(key,"SideChargeHopper",Vector3(-6.6,0,-0.6))
    b = _batch(feed)
    _shape(b,"hopper",Vector3(0,4.5,0),Vector3(3.5,2.7,3.7),"armor")
    for x in [-1.2,1.2]:
        for z in [-1.1,1.1]:
            _shape(b,"gusset",Vector3(x,1.8,z),Vector3(0.45,3.6,0.48),"slate")
    _pipe(b,Vector3(0,3.5,0),Vector3(3.4,3.5,0),1.20,"armor")
    _shape(b,"tray",Vector3(0,1.18,2.25),Vector3(2.5,0.32,2.4),"slate")
    _pipe(b,Vector3(-1.1,1.1,-0.9),Vector3(-1.1,3.7,-0.9),0.20,"edge")
    _panel_detail(b,0,1.72,1.02,1.05,0.9)
    _finish(b)
    var conveyor := _conveyor(key,"ChargeConveyor",Vector3(-6.6,0,3.5),2.4,5.0)
    var feed_mount := _child(conveyor,"FeedChargePlacement",Vector3(0,1.12,0))
    (targets[key] as Array).append(feed_mount)
    var raw := _cargo(feed_mount,"FeedCharge",Vector3(0,0,1.7),Vector3(1.3,0.6,1.0))
    _moving(key,"feed",raw)
    _moving(key,"hopper",feed)
    var cast := _conveyor(key,"CastingCoolingLine",Vector3(5.9,0,2.0),2.5,6.2)
    var ingot_mount := _child(cast,"IngotPlacement",Vector3(0,1.15,0))
    (targets[key] as Array).append(ingot_mount)
    var ingot := _child(ingot_mount,"CooledIngot",Vector3(0,0,-2.1))
    b = _batch(ingot)
    _shape(b,"bevel",Vector3(0,0.30,0),Vector3(1.9,0.60,1.2),"amber")
    _box(b,Vector3(0,0.64,0),Vector3(1.55,0.07,0.9),"amber_light")
    _finish(b)
    _moving(key,"output",ingot)
    var cooling := _model(key,"CastingSpoutAndCoolingService",Vector3(3.7,0,1.2))
    b = _batch(cooling)
    _shape(b,"tray",Vector3(0,1.35,0.35),Vector3(2.7,0.45,2.8),"rust")
    _pipe(b,Vector3(-1.3,1.65,-0.45),Vector3(-0.15,1.40,0.35),0.36,"rust")
    _shape(b,"deck",Vector3(0.25,1.60,0.65),Vector3(1.2,0.07,1.30),"amber")
    _shape(b,"bevel",Vector3(1.55,1.2,-1.25),Vector3(1.3,2.4,1.4),"slate")
    _shape(b,"louver",Vector3(1.55,1.3,-0.50),Vector3(0.96,1.65,0.15),"edge")
    _pipe(b,Vector3(1.55,2.45,-1.25),Vector3(0.3,2.45,-1.25),0.23,"gold")
    _floor_cable(b,[Vector3(1.55,0.1,-0.7),Vector3(1.55,0.1,0.85),Vector3(0,0.1,2.0)])
    _finish(b)
    _task_light(cooling,Vector3(0.0,2.1,0.65),Color("#ffae68"),5.0,0.8)
    _console(key,Vector3(-3.3,0,6.7),2)

func _recycler(key: String) -> void:
    var base := _model(key,"TwinShaftCrusherHousing",Vector3(0,0,-1.7))
    var b = _batch(base)
    _shape(b,"deck",Vector3(0,0.4,0),Vector3(10.5,0.8,7.0),"slate")
    for x in [-3.7,3.7]:
        _shape(b,"bevel",Vector3(x,2.9,0),Vector3(1.5,5.0,6.6),"armor")
        _shape(b,"octagonal_slew",Vector3(x,3.6,0),Vector3(2.1,2.1,2.1),"slate")
        for i in range(6):
            _box(b,Vector3(x,1.2+i*0.48,3.36),Vector3(1.05,0.13,0.13),"edge")
    _box(b,Vector3(0,1.5,-2.8),Vector3(6.2,2.2,0.5),"trim")
    _box(b,Vector3(0,0.95,1.2),Vector3(6.0,0.4,4.0),"void")
    for side in [-1.0,1.0]:
        b.box_tilt("FlaredHopperCheek",Vector3(side*3.45,5.3,-0.25),
            Vector3(0.37,4.1,6.4),"armor_light",Vector3(0,0,-side*0.34))
        _pipe(b,Vector3(side*4.1,7.18,-3.4),Vector3(side*4.1,7.18,2.9),0.24,"caution")
        _shape(b,"vent_stack",Vector3(side*4.3,2.1,-1.35),Vector3(1.25,2.2,1.25),"slate")
        for line in [-0.9,0.85]:
            b.poly_tilt("ShaftBearing","drum",Vector3(side*3.72,3.6,line),
                Vector3(1.7,0.64,1.7),"edge",Vector3(0,0,PI*0.5))
        _panel_detail(b,side*3.7,1.9,3.42,1.0,1.45)
    b.box_tilt("RearGravityChute",Vector3(0,5.9,-2.7),Vector3(6.2,0.28,4.1),
        "slate",Vector3(0.70,0,0))
    b.box_tilt("DischargeChute",Vector3(0,1.64,2.75),Vector3(5.8,0.34,3.45),
        "armor",Vector3(0.26,0,0))
    for side in [-1.0,1.0]:
        b.box_tilt("OutletCheek",Vector3(side*2.9,1.98,2.75),Vector3(0.24,0.60,3.45),
            "slate",Vector3(0.26,0,0))
    for x in [-3.0,3.0]:
        _box(b,Vector3(x,4.4,2.2),Vector3(0.24,0.18,2.0),"caution")
    _finish(b)
    inspection[key] = {"root":base,"stand":Vector3(-2.0,0,4.7),"focus":Vector3(0,3.4,0)}
    for i in range(2):
        var shaft_root := _model(key,"CutterShaft"+str(i),Vector3(0,3.6,-2.6+i*1.75))
        var shaft := _child(shaft_root,"Rotor")
        b = _batch(shaft)
        _pipe(b,Vector3(-3.1,0,0),Vector3(3.1,0,0),0.80,"edge")
        for x in range(-4,5):
            b.poly_tilt("InterleavedCutterDisk","gear",Vector3(x*0.65+float(i)*0.325,0,0),
                Vector3(2.10,0.28,2.10),"armor_light",Vector3(0,0,PI*0.5))
        for x in [-3.05,3.05]:
            b.poly_tilt("ShaftCollar","drum",Vector3(x,0,0),
                Vector3(1.22,0.38,1.22),"edge",Vector3(0,0,PI*0.5))
        _finish(b)
        _moving(key,"shaft"+str(i),shaft)
    var feed := _conveyor(key,"ScrapFeedLine",Vector3(0,0,-6.3),4.5,5.6)
    var feed_mount := _child(feed,"ScrapBatchPlacement",Vector3(0,1.1,0))
    (targets[key] as Array).append(feed_mount)
    var raw := _child(feed_mount,"ScrapBatch",Vector3(0,0,-1.8))
    b = _batch(raw)
    _shape(b,"bevel",Vector3(0,0.24,0),Vector3(1.95,0.48,1.45),"slate")
    b.poly_tilt("BentScrapPlate","deck",Vector3(-0.42,0.56,0.12),
        Vector3(0.95,0.20,1.35),"edge",Vector3(0.35,0.25,-0.12))
    b.poly_tilt("ScrapBearing","gear",Vector3(0.48,0.55,-0.18),
        Vector3(0.88,0.45,0.88),"rust",Vector3(0.2,0,0.55))
    _pipe(b,Vector3(-0.64,0.38,-0.5),Vector3(0.65,0.64,0.5),0.22,"trim")
    _finish(b)
    _moving(key,"feed",raw)
    _moving(key,"crusher",base)
    var output := _conveyor(key,"SortedMaterialLine",Vector3(0,0,4.6),3.8,5.0)
    var bin_mount := _child(output,"SortedBatchPlacement",Vector3(0,1.1,0))
    (targets[key] as Array).append(bin_mount)
    var bin := _child(bin_mount,"SortedBatch",Vector3(0,0,-1.7))
    b = _batch(bin)
    for i in range(3):
        _shape(b,"gear",Vector3(-0.58+float(i)*0.58,0.16,0.1),Vector3(0.49,0.32,0.49),"edge")
        _shape(b,"bevel",Vector3(-0.58+float(i)*0.58,0.12,-0.45),Vector3(0.44,0.24,0.42),"rust")
    _finish(b)
    _moving(key,"output",bin)
    _console(key,Vector3(4.7,0,4.0),3)

func _storage(key: String) -> void:
    # BASE: rear rack bank, clear forward apron and left-side loading lift.
    var rack := _model(key,"RearHighBayRackBank",Vector3(1.0,0,-3.4))
    var b = _batch(rack)
    _skid(b,16.8,5.8)
    for x in [-7.5,-2.5,2.5,7.5]:
        for z in [-2.3,2.3]:
            _shape(b,"bevel",Vector3(x,5.8,z),Vector3(0.48,11.6,0.52),"armor_light")
            for y in [0.68,3.18,5.68,8.18,10.68]:
                _shape(b,"deck",Vector3(x,y,z),Vector3(0.65,0.18,0.68),"edge")
        _pipe(b,Vector3(x,0.7,-2.3),Vector3(x,11.2,2.3),0.19,"trim")
    for level in range(4):
        var y: float = 0.75+float(level)*2.5
        _shape(b,"deck",Vector3(0,y,0),Vector3(15.8,0.30,4.7),"slate")
        for z in [-2.38,2.38]:
            _box(b,Vector3(0,y,z),Vector3(15.8,0.24,0.22),"gold")
        for x in [-5.0,0.0,5.0]:
            _box(b,Vector3(x,y+0.20,-2.07),Vector3(0.30,0.24,0.20),"edge")
            _box(b,Vector3(x,y+0.20,2.42),Vector3(0.64,0.12,0.06),"lab_cyan")
    for side in [-1.0,1.0]:
        _pipe(b,Vector3(side*7.5,0.72,-2.3),Vector3(-side*7.5,11.25,-2.3),0.25,"edge")
    _shape(b,"roof",Vector3(0,11.75,-0.8),Vector3(16.6,0.25,3.25),"armor")
    _finish(b)
    for level in range(4):
        for col in range(6):
            if level==2 and col==0:
                continue
            var cargo := _child(rack,"Stock_"+str(level)+"_"+str(col),
                Vector3(-6.25+float(col)*2.5,0.90+float(level)*2.5,0.2))
            (targets[key] as Array).append(cargo)
            var cb = _batch(cargo)
            _shape(cb,"cargo_case",Vector3(0,0.83,0),Vector3(2.17,1.60,3.5),
                "crate" if posmod(level+col,3)!=0 else "slate")
            _box(cb,Vector3(0,0.84,1.79),Vector3(0.64,0.22,0.09),"gold")
            for side in [-1.0,1.0]:
                _box(cb,Vector3(side*0.86,0.84,1.79),Vector3(0.12,1.3,0.12),"edge")
            _finish(cb)
    var mast := _model(key,"LeftLoadingLiftMast",Vector3(-7.7,0,2.5))
    b = _batch(mast)
    _skid(b,4.4,4.4)
    for x in [-1.6,1.6]:
        _shape(b,"bevel",Vector3(x,5.85,0),Vector3(0.48,11.7,0.78),"armor_light")
        _box(b,Vector3(x,5.8,0.42),Vector3(0.10,11.1,0.12),"edge")
        _pipe(b,Vector3(x,0.5,-0.5),Vector3(x,11.1,-0.5),0.18,"gold")
        _shape(b,"gusset",Vector3(x,0.90,-1.2),Vector3(0.75,1.4,1.9),"slate")
    _shape(b,"drum",Vector3(0,11.62,0),Vector3(2.0,0.9,1.7),"slate")
    _shape(b,"louver",Vector3(0,11.55,0.88),Vector3(1.65,0.56,0.18),"edge")
    _box(b,Vector3(0,11.05,0.45),Vector3(2.6,0.14,0.11),"lab_cyan")
    _finish(b)
    var platform_mount := _child(mast,"LiftPlacement",Vector3(0,0.93,0.45))
    (targets[key] as Array).append(platform_mount)
    var platform := _child(platform_mount,"LiftCarriage")
    b = _batch(platform)
    _shape(b,"tray",Vector3(0,0,0),Vector3(3.0,0.35,3.0),"gold")
    for x in [-1.2,1.2]:
        _box(b,Vector3(x,0.28,0),Vector3(0.20,0.19,2.75),"edge")
    _finish(b)
    var fork := _child(platform,"TransferFork")
    b = _batch(fork)
    for x in [-0.75,0.75]:
        _box(b,Vector3(x,0.23,-0.25),Vector3(0.28,0.14,2.6),"edge")
    _finish(b)
    var extension := _child(platform,"TelescopingForkSupport")
    b = _batch(extension)
    _shape(b,"bevel",Vector3(0,0,0),Vector3(0.52,0.24,1.0),"armor")
    _finish(b)
    _moving(key,"extension",extension)
    var load_mount := _child(mast,"LiftCargoPlacement")
    (targets[key] as Array).append(load_mount)
    var load := _cargo(load_mount,"LiftCargo",Vector3.ZERO,Vector3(2.17,1.6,3.5))
    _moving(key,"lift",platform)
    _moving(key,"lift_cargo",load)
    _moving(key,"fork",fork)
    var apron := _model(key,"ForwardLoadingApron",Vector3(1.0,0,3.5))
    b = _batch(apron)
    _skid(b,16.1,6.4)
    _shape(b,"deck",Vector3(0,0.47,0),Vector3(15.4,0.20,5.7),"armor")
    for x in [-4.5,0.0,4.5]:
        _box(b,Vector3(x,0.59,0),Vector3(0.11,0.03,5.4),"caution")
    _box(b,Vector3(0,0.61,2.8),Vector3(14.0,0.17,0.20),"rubber")
    for x in [-6.0,6.0]:
        _pipe(b,Vector3(x,0.5,-2.5),Vector3(x,4.7,-2.5),0.22,"edge")
        _pipe(b,Vector3(x,4.7,-2.5),Vector3(x,4.7,0.5),0.20,"edge")
        _shape(b,"hood",Vector3(x,4.7,0.5),Vector3(1.1,0.37,0.7),"armor")
        _box(b,Vector3(x,4.48,0.5),Vector3(0.88,0.08,0.53),"amber_light")
    _finish(b)
    var dispatch := _conveyor(key,"LeftReceivingRollers",Vector3(-7.7,0,6.25),3.0,3.5)
    inspection[key] = {"root":apron,"stand":Vector3(0.5,0,4.0),"focus":Vector3(-2.0,2.0,-1.0)}
    _moving(key,"rack",rack)
    _moving(key,"mast",mast)
    _moving(key,"dispatch",dispatch)
    for x in [-6.0,6.0]:
        _task_light(apron,Vector3(x,4.15,0.5),Color("#ffe0b2"),6.0,1.0)
    _console(key,Vector3(5.8,0,7.6),4)

func placement_models(key: String) -> Array[Node3D]:
    var result: Array[Node3D] = []
    for model in targets.get(key,[]):
        result.append(model as Node3D)
    return result

func select(key: String) -> void:
    active_key = key
    _position_context(key)
    for id in KEYS:
        (rooms[id] as Node3D).visible = id == key
    elapsed = 0.0
    cycle_running = false
    _sample(key,0.0)

func work_point(key: String, inspect: bool) -> Vector3:
    if inspect:
        var data: Dictionary = inspection[key]
        return (data["root"] as Node3D).to_global(data["stand"])
    return (terminals[key] as Node3D).to_global(Vector3(0,0,0.95))

func focus_point(key: String, inspect: bool) -> Vector3:
    if inspect:
        var data: Dictionary = inspection[key]
        return (data["root"] as Node3D).to_global(data["focus"])
    return (terminals[key] as Node3D).to_global(Vector3(0,1.05,0.34))

func start_cycle(key: String) -> void:
    if key != active_key:
        return
    elapsed = 0.0
    cycle_running = true
    if key == "LABO":
        motion_parts[key]["variant"] = (int(motion_parts[key]["variant"])+1)%4
    _sample(key,0.0)

func cycle_complete() -> bool:
    return not cycle_running

func animate(delta: float, time: float, key: String) -> void:
    if key != active_key:
        return
    for panel in screens.get(key,[]):
        panel.call("_process",delta)
    if key == "SMELTER":
        for layer in fire_layers:
            layer.set_shader_parameter("phase_time",time)
        if is_instance_valid(fire_light):
            fire_light.light_energy = 1.38+0.16*sin(time*3.13)+0.10*sin(time*7.71)
    if cycle_running:
        elapsed = minf(10.0,elapsed+delta)
        _sample(key,elapsed/10.0)
        cycle_running = elapsed < 10.0

func _sample(key: String, t: float) -> void:
    var m: Dictionary = motion_parts[key]
    match key:
        "LABO":
            var carriage: Node3D = m["bridge"]
            var head: Node3D = m["head"]
            var printing: float = smoothstep(0.01,0.10,t)*(1.0-smoothstep(0.48,0.58,t))
            var grow: float = smoothstep(0.10,0.48,t)
            carriage.position.x = sin(t*TAU*11.0)*0.55*printing
            head.position.y = (-1.14+grow*1.14)*printing
            var product: Node3D = m["products"]
            var arm: Node3D = m["arm_mount"]
            var shoulder: Node3D = m["shoulder"]
            var elbow: Node3D = m["elbow"]
            var grip: Node3D = m["gripper"]
            var tray: Node3D = m["tray"]
            var pickup: Vector3 = arm.to_local(product.global_position)
            var drop: Vector3 = arm.to_local(tray.to_global(Vector3(0,1.59,0)))
            var park := Vector3(-2.4,0,-3.4)
            var target: Vector3 = park.lerp(pickup,smoothstep(0.52,0.63,t))
            if t>=0.68:
                target = pickup.lerp(drop,smoothstep(0.68,0.85,t))
            if t>=0.92:
                target = drop.lerp(park,smoothstep(0.92,1.0,t))
            var distance: float = clampf(Vector2(target.x,target.z).length(),0.15,7.77)
            var bend: float = acos(distance/7.8)
            shoulder.rotation.y = atan2(target.x,target.z)-bend
            elbow.rotation.y = 2.0*bend
            var lower: float = smoothstep(0.62,0.67,t)*(1.0-smoothstep(0.68,0.73,t))
            lower += smoothstep(0.84,0.89,t)*(1.0-smoothstep(0.90,0.95,t))
            grip.position.y = -2.5-0.55*lower
            for i in range(product.get_child_count()):
                var p := product.get_child(i) as Node3D
                p.visible = i==int(m["variant"]) and t>0.10
                p.scale.y = maxf(0.03,grow)
                p.position = Vector3.ZERO
                if t>=0.68:
                    var flight: float = smoothstep(0.68,0.85,t)
                    var world_drop: Vector3 = tray.to_global(Vector3(0,1.59,0))
                    var local_drop: Vector3 = product.to_local(world_drop)
                    p.position = local_drop*flight
                    p.position.y += 1.0*smoothstep(0.68,0.73,t)*(1.0-smoothstep(0.82,0.89,t))
        "SMELTER","RECYCLER":
            var feed: Node3D = m["feed"]
            var output: Node3D = m["output"]
            feed.visible = t<0.35
            feed.position.z = (1.7 if key=="SMELTER" else -1.8)+(-3.4 if key=="SMELTER" else 3.4)*smoothstep(0.0,0.35,t)
            output.visible = t>0.55
            output.position.z = (-2.1 if key=="SMELTER" else -1.7)+3.4*smoothstep(0.55,1.0,t)
            if key=="SMELTER":
                var hopper: Node3D = m["hopper"]
                var feed_parent := feed.get_parent() as Node3D
                var mouth: Vector3 = feed_parent.to_local(hopper.to_global(Vector3(0,5.4,0)))
                var floor_end := Vector3(0,0,-1.75)
                var hoist: float = smoothstep(0.17,0.35,t)
                if t<0.17:
                    feed.position = Vector3(0,0,lerpf(1.7,-1.75,smoothstep(0.0,0.17,t)))
                else:
                    feed.position = floor_end.lerp(mouth,hoist)
                feed.visible = t<0.35
            if key=="RECYCLER":
                var crusher: Node3D = m["crusher"]
                var feed_parent := feed.get_parent() as Node3D
                var entrance: Vector3 = feed_parent.to_local(crusher.to_global(Vector3(0,6.2,-3.1)))
                var cutter: Vector3 = feed_parent.to_local(crusher.to_global(Vector3(0,3.9,-0.9)))
                if t<0.21:
                    feed.position = Vector3(0,0,-1.8).lerp(entrance,smoothstep(0.0,0.21,t))
                else:
                    feed.position = entrance.lerp(cutter,smoothstep(0.21,0.35,t))
                feed.visible = t<0.35
                (m["shaft0"] as Node3D).rotation.x = t*TAU*4.0
                (m["shaft1"] as Node3D).rotation.x = -t*TAU*4.0
        "STORAGE":
            var lift: Node3D = m["lift"]
            var fork: Node3D = m["fork"]
            var cargo: Node3D = m["lift_cargo"]
            var rack: Node3D = m["rack"]
            var dispatch: Node3D = m["dispatch"]
            var height: float = smoothstep(0.20,0.42,t)*(1.0-smoothstep(0.81,1.0,t))
            lift.position.y = 4.72*height
            var mount := cargo.get_parent() as Node3D
            var incoming: Vector3 = mount.to_local(dispatch.to_global(Vector3(0,1.10,0.8)))
            var on_lift: Vector3 = mount.to_local(lift.to_global(Vector3(0,0.175,0.32)))
            var destination: Vector3 = mount.to_local(rack.to_global(Vector3(-6.25,5.90,0.2)))
            var across: float = smoothstep(0.44,0.55,t)
            var inward: float = smoothstep(0.55,0.71,t)
            var on_shelf := Vector3(lerpf(on_lift.x,destination.x,across),
                lerpf(on_lift.y,destination.y,inward),lerpf(on_lift.z,destination.z,inward))
            cargo.position = incoming.lerp(on_lift,smoothstep(0.0,0.20,t))
            if t>=0.44:
                cargo.position = on_shelf
            if t>=0.71:
                cargo.position = destination
            var retract: float = 1.0-smoothstep(0.71,0.81,t)
            var extension: Node3D = m["extension"]
            var transfer_world: Vector3 = mount.to_global(on_shelf)
            var transfer_local: Vector3 = lift.to_local(transfer_world)
            fork.position = Vector3(transfer_local.x,0,transfer_local.z-0.32)*retract
            var span: float = fork.position.length()
            extension.visible = span>0.04
            extension.position = fork.position*0.5+Vector3(0,0.13,0)
            extension.rotation.y = atan2(fork.position.x,fork.position.z)
            extension.scale.z = maxf(0.04,span)
