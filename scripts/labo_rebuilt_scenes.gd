extends RefCounted
## Dedicated life-size OUTDOOR production sets. BASE icons are design references only.
## All dimensions are authored in metres, never scaled BASE meshes.
const Logistics = preload("res://scripts/labo_worksite_logistics.gd")
const IndustrialHorizon = preload("res://scripts/labo_industrial_horizon.gd")
var industrial_horizon: RefCounted
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
const FurnaceFlame = preload("res://scripts/sera_furnace_baked_flame.gd")
const StackInk = preload("res://shaders/sera_refinery_stack_ink.gdshader")
const EQUIPMENT_SCALE := 1.30
const WORK_DECK_RISE := 0.32
var surface_cache: Dictionary = {}
var fallback_texture: ImageTexture
var stack_ink_material: ShaderMaterial
var fire_layers: Array[Sprite3D] = []
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
var mechanism_layouts: Dictionary = {}
var logistics: Dictionary = {}
var idle_seconds: float = 0.0
var print_idle_rng := RandomNumberGenerator.new()

func build(stage: Node3D) -> void:
    host = stage
    print_idle_rng.randomize()
    _build_outdoor_deck()
    industrial_horizon = IndustrialHorizon.new()
    industrial_horizon.build(host)
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
        if key in ["LABO","STORAGE"]:
            # Lift the complete assembly as a unit. Authored machine offsets,
            # animation pivots and existing placement coordinates stay intact.
            room.position.y = WORK_DECK_RISE
            _raised_worksite(key)
            _open_box_frame(key)
            if key=="LABO":
                _lab_rear_wall(key)
        elif key=="SMELTER":
            _refinery_work_deck(key)
        # Capture relative mechanical alignment after scaling, not the whole room pose.
        _capture_mechanism(key)
        _build_logistics(key)
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
        var refinery_room := rooms.get("SMELTER") as Node3D
        var is_refinery: bool = is_instance_valid(refinery_room) and refinery_room.is_ancestor_of(b.host)
        if is_refinery:
            if tint == Color(Architecture.COLORS["trim"]):
                tint = Color("#25333e")
            elif tint == Color(Architecture.COLORS["edge"]):
                tint = Color("#a2adb3")
            elif tint == Color(Architecture.COLORS["rust"]):
                tint = Color("#916044")
            elif tint == Color(Architecture.COLORS["armor"]):
                tint = Color("#485b6c")
        elif tint.get_luminance() < 0.26 and tint != Color(Architecture.COLORS["void"]):
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

# Local depth-tested ink on the exact hollow sleeve, not a proxy box.
func _stack_ink(stack: Node3D) -> void:
    if stack_ink_material == null:
        stack_ink_material = ShaderMaterial.new()
        stack_ink_material.shader = StackInk
    for child in stack.get_children():
        var draw := child as MultiMeshInstance3D
        if draw == null or not String(draw.name).begins_with("Architectural_vent_stack_"):
            continue
        var ink := MultiMeshInstance3D.new()
        ink.name = String(draw.name) + "_LocalInk"
        ink.multimesh = draw.multimesh
        ink.material_override = stack_ink_material
        ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        ink.set_meta("FX_NO_OUTLINE",true)
        ink.set_meta("sera_no_view_edges",true)
        ink.set_meta("sera_preserve_authored_material",true)
        stack.add_child(ink)
        ink.transform = draw.transform
        # Retain the black outer/inner silhouette of the hollow sleeve only.
        # Integral collar hard-corner rings are disabled (0px).

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
    # LABO/STORAGE receive dedicated raised decks with their own markings.
    if key in ["LABO","STORAGE"]:
        return
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

# Shared silver panels with actual narrow seams; two fixed draw batches.
func _silver_worksite_panels(parent: Node3D,center: Vector2,span: Vector2,cols: int,rows: int,top: float) -> void:
    var surface := _child(parent,"SilverSteelPanels")
    var pitch := Vector2((span.x-0.56)/float(cols),(span.y-0.56)/float(rows))
    var groups: Array = [[],[]]
    for row in range(rows):
        for col in range(cols):
            var x: float = center.x-span.x*0.5+0.28+pitch.x*(float(col)+0.5)
            var z: float = center.y-span.y*0.5+0.28+pitch.y*(float(row)+0.5)
            var palette: int = 1 if posmod(row+col,4)==0 else 0
            groups[palette].append(Transform3D(Basis.IDENTITY.scaled_local(Vector3(pitch.x-0.045,0.07,pitch.y-0.045)),Vector3(x,top-0.035,z)))
    var mesh: ArrayMesh = Polygon.make("deck")
    for palette in range(2):
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = mesh
        multi.instance_count = groups[palette].size()
        for j in range(multi.instance_count):
            multi.set_instance_transform(j,groups[palette][j])
        var draw := MultiMeshInstance3D.new()
        draw.name = "SilverWorksiteBatch%d"%palette
        draw.multimesh = multi
        draw.material_override = DeckLighting.worksite_material(palette==1)
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        draw.set_meta("sera_preserve_authored_material",true)
        draw.set_meta("sera_outline_occluder_only",true)
        surface.add_child(draw)

func _refinery_work_deck(key: String) -> void:
    # 36 x 36 m apron: furnace, hopper, discharge, stacking pad,
    # both gantries and the stopped carriers. Flat at the existing work level.
    # The foundation sinks into the outdoor deck; no new raised step or walls.
    var platform := _model(key,"FacilityWorkDeck",Vector3.ZERO)
    var center := Vector2(-0.5,5.0)
    var span := Vector2(36.0,36.0)
    var b = _batch(platform)
    _box(b,Vector3(center.x,-0.08,center.y),Vector3(span.x,0.15,span.y),"dark")
    var left: float = center.x-span.x*0.5
    var right: float = center.x+span.x*0.5
    var back: float = center.y-span.y*0.5
    var front: float = center.y+span.y*0.5
    for x in [left+0.14,right-0.14]:
        _box(b,Vector3(x,-0.02,center.y),Vector3(0.28,0.04,span.y),"edge")
        for j in range(9):
            _box(b,Vector3(x,0.005,back+2.0+float(j)*4.0),Vector3(0.18,0.012,0.72),"trim")
    for z in [back+0.14,front-0.14]:
        _box(b,Vector3(center.x,-0.02,z),Vector3(span.x-0.56,0.04,0.28),"edge")
    _finish(b)
    _silver_worksite_panels(platform,center,span,8,8,0.0)

func _raised_worksite(key: String) -> void:
    # BASE's facility pads and partial protection structures are translated
    # into real-size geometry. The two sets have open fronts and open skies.
    # Everything below is authored AFTER the 1.30 machinery scaling.
    var is_lab: bool = key == "LABO"
    var center_x: float = -0.7 if is_lab else -0.4
    var center_z: float = 1.1 if is_lab else 2.5
    var width: float = 29.0 if is_lab else 30.0
    var depth: float = 24.0 if is_lab else 25.0
    var left: float = center_x-width*0.5
    var right: float = center_x+width*0.5
    var rear: float = center_z-depth*0.5
    var front: float = center_z+depth*0.5
    var platform := _model(key,"FacilityWorkDeck",Vector3.ZERO)
    var b = _batch(platform)
    # Slab bottom rests on the BASE floor (-0.03m); deck top at room y=0.
    _shape(b,"bevel",Vector3(center_x,-0.205,center_z),
        Vector3(width,0.29,depth),"dark")
    # Recessed edge rails and service sockets echo the small BASE foundation.
    for x in [left+0.14,right-0.14]:
        _box(b,Vector3(x,-0.055,center_z),Vector3(0.28,0.11,depth),"trim")
        _box(b,Vector3(x,-0.18,center_z),Vector3(0.10,0.15,depth-0.28),"edge")
        for i in range(6):
            var z: float = rear+1.3+(depth-2.6)*float(i)/5.0
            _shape(b,"bevel",Vector3(x,-0.11,z),Vector3(0.32,0.17,0.55),"edge")
    for z in [rear+0.14,front-0.14]:
        _box(b,Vector3(center_x,-0.055,z),Vector3(width-0.56,0.11,0.28),"trim")
    # Front edge interrupted at the access ramps. No fence across the approach.
    var access_x: float = 2.8 if is_lab else 5.3
    for i in range(14):
        var x: float = left+1.0+float(i)*(width-2.0)/13.0
        if absf(x-access_x)<3.1 or (not is_lab and absf(x+10.0)<2.8):
            continue
        _box(b,Vector3(x,0.008,front-0.55),Vector3(1.15,0.016,0.16),"caution")
    var ramp_centers: Array = [access_x] if is_lab else [access_x,-10.0]
    for x in ramp_centers:
        b.box_tilt("AccessRamp",Vector3(float(x),-0.22,front+1.0),
            Vector3(5.2,0.12,2.02),"armor",Vector3(0.1587,0,0))
        for side in [-1.0,1.0]:
            b.box_tilt("RampEdgeMark",Vector3(float(x)+side*2.43,-0.151,front+1.0),
                Vector3(0.11,0.015,2.01),"caution",Vector3(0.1587,0,0))
    # Visible operating lanes outside machine plinths, not a second floor.
    for x in [left+1.1,right-1.1]:
        _box(b,Vector3(x,0.008,center_z),Vector3(0.10,0.016,depth-3.0),"caution")
    _finish(b)
    _silver_worksite_panels(platform,Vector2(center_x,center_z),Vector2(width,depth),6,5,0.0)
    for child in platform.get_children():
        if child is GeometryInstance3D:
            child.set_meta("sera_preserve_authored_material",true)
    # Distinct designs: the LABO has a rear splash/wind screen with short
    # returns; storage has a cargo-restraint perimeter and rear weather screen.
    var enclosure := _model(key,"LabOpenWorkcellEnclosure" if is_lab else "StorageOpenYardEnclosure",Vector3.ZERO)
    b = _batch(enclosure)
    var rear_z: float = rear+0.58
    var panel_height: float = 3.1 if is_lab else 2.45
    var post_height: float = 4.65 if is_lab else 3.45
    var post_x0: float = left+0.68
    var post_x1: float = right-0.68
    var bay: float = (post_x1-post_x0)/6.0
    for i in range(7):
        var x: float = post_x0+bay*float(i)
        _shape(b,"gusset",Vector3(x,0.34,rear_z),Vector3(0.78,0.68,0.84),"edge")
        _shape(b,"octagonal_slew",Vector3(x,post_height*0.5,rear_z),
            Vector3(0.36,post_height,0.40),"slate")
        _shape(b,"bevel",Vector3(x,post_height-0.16,rear_z),
            Vector3(0.51,0.24,0.55),"edge")
        if i<6:
            var mid: float = x+bay*0.5
            _shape(b,"bevel",Vector3(mid,panel_height*0.5+0.24,rear_z),
                Vector3(bay-0.44,panel_height,0.24),"armor")
            _box(b,Vector3(mid,0.29,rear_z+0.16),Vector3(bay-0.47,0.19,0.12),"trim")
            _box(b,Vector3(mid,panel_height+0.21,rear_z+0.16),
                Vector3(bay-0.44,0.15,0.12),"edge")
            if is_lab:
                _shape(b,"louver",Vector3(mid,1.14,rear_z+0.17),
                    Vector3(bay*0.58,0.9,0.13),"trim")
            else:
                _pipe(b,Vector3(x+0.22,panel_height+0.52,rear_z),
                    Vector3(x+bay-0.22,post_height-0.18,rear_z),0.15,"trim")
    _box(b,Vector3(center_x,post_height-0.18,rear_z),
        Vector3(post_x1-post_x0+0.35,0.22,0.32),"edge")
    # Side returns stop in the rear part of each yard. The front and
    # the left-side storage receiving conveyor remain open.
    for side in [-1.0,1.0]:
        var x: float = left+0.68 if side<0 else right-0.68
        var side_span: float = 7.2 if is_lab else 5.2
        var end_z: float = rear_z+side_span
        var side_h: float = 2.35 if is_lab else 1.28
        for i in range(1,4):
            var z: float = rear_z+side_span*float(i)/3.0
            _shape(b,"gusset",Vector3(x,0.30,z),Vector3(0.65,0.60,0.65),"edge")
            _shape(b,"octagonal_slew",Vector3(x,(side_h+0.52)*0.5,z),
                Vector3(0.29,side_h+0.52,0.29),"slate")
            if is_lab:
                _shape(b,"bevel",Vector3(x,side_h*0.5+0.16,z-side_span/6.0),
                    Vector3(0.22,side_h,side_span/3.0-0.35),"armor")
            else:
                for y in [0.42,1.22]:
                    _box(b,Vector3(x,y,z-side_span/6.0),
                        Vector3(0.19,0.15,side_span/3.0),"edge" if y<1.0 else "gold")
        _box(b,Vector3(x,side_h+0.32,(rear_z+end_z)*0.5),
            Vector3(0.23,0.14,side_span),"edge")
        _box(b,Vector3(x,side_h+0.18,end_z+0.04),Vector3(0.25,0.18,0.11),"lab_cyan")
    if is_lab:
        # A narrow weather hood above the rear perimeter only. It never
        # spans the printer/SCARA envelope or replaces the open sky.
        for x in [post_x0+bay,post_x0+bay*3.0,post_x0+bay*5.0]:
            _pipe(b,Vector3(x,post_height-0.22,rear_z),
                Vector3(x,post_height-0.48,rear_z+1.40),0.18,"trim")
        b.poly_tilt("RearServiceWeatherHood","roof",Vector3(center_x,post_height-0.16,rear_z+0.56),
            Vector3(width-1.1,0.16,1.42),"armor_light",Vector3(0.09,0,0))
    else:
        # Warehouse rear screen receives a slim weather cap. No whole-yard roof.
        b.poly_tilt("CargoRearWeatherCap","roof",Vector3(center_x,post_height-0.12,rear_z+0.28),
            Vector3(width-1.1,0.16,0.96),"armor",Vector3(0.09,0,0))
    _finish(b)

func _open_box_frame(key: String) -> void:
    # A real perimeter portal frame above the separate equipment, not a
    # sealed hall. Dimensions are in final scene metres, after machine scaling.
    var is_lab: bool = key == "LABO"
    var cx: float = -0.7 if is_lab else -0.4
    var cz: float = 1.1 if is_lab else 2.5
    var width: float = 27.4 if is_lab else 28.4
    var depth: float = 22.4 if is_lab else 23.4
    var height: float = 16.4 if is_lab else 19.0
    var left: float = cx-width*0.5
    var right: float = cx+width*0.5
    var rear: float = cz-depth*0.5
    var front: float = cz+depth*0.5
    var frame := _model(key,"LabOpenSteelPortalFrame" if is_lab else "StorageOpenSteelPortalFrame",Vector3.ZERO)
    var b = _batch(frame)
    # Four leg assemblies, wide clear front opening and no intermediate
    # columns in the robot path, stock transfer, or crane operating envelope.
    for x in [left,right]:
        for z in [rear,front]:
            _shape(b,"deck",Vector3(x,0.12,z),Vector3(1.45,0.24,1.45),"trim")
            _shape(b,"bevel",Vector3(x,0.43,z),Vector3(1.08,0.62,1.08),"armor")
            for sx in [-1.0,1.0]:
                for sz in [-1.0,1.0]:
                    _shape(b,"drum",Vector3(x+sx*0.50,0.27,z+sz*0.50),
                        Vector3(0.16,0.12,0.16),"edge")
            _box(b,Vector3(x,height*0.5,z),Vector3(0.62,height,0.64),"slate")
            for sx in [-1.0,1.0]:
                _box(b,Vector3(x+sx*0.34,height*0.5,z),
                    Vector3(0.14,height,0.96),"armor")
                _box(b,Vector3(x+sx*0.43,1.25,z),
                    Vector3(0.035,1.72,0.80),"trim")
            for y in [0.76,2.2,height-1.10]:
                _shape(b,"bevel",Vector3(x,y,z),Vector3(0.96,0.19,1.05),"edge")
            _box(b,Vector3(x,1.48,z+0.50),Vector3(0.50,0.18,0.05),"caution")
            _box(b,Vector3(x,1.14,z+0.50),Vector3(0.50,0.18,0.05),"caution")
            _shape(b,"bevel",Vector3(x,height-0.22,z),Vector3(1.24,0.44,1.24),"armor_light")
            for y in [height-0.72,height-1.00]:
                _box(b,Vector3(x,y,z+0.49),Vector3(0.42,0.095,0.08),"edge")
    # Deep fabricated beams with separate flanges and web stiffeners.
    for z in [rear,front]:
        _box(b,Vector3(cx,height-0.48,z),Vector3(width,0.95,0.53),"slate")
        for y in [height-0.04,height-0.92]:
            _box(b,Vector3(cx,y,z),Vector3(width+0.78,0.18,0.94),"armor")
        for i in range(1,7):
            var x: float = left+width*float(i)/7.0
            _box(b,Vector3(x,height-0.48,z),Vector3(0.16,0.74,0.80),"trim")
    for x in [left,right]:
        _box(b,Vector3(x,height-0.48,cz),Vector3(0.53,0.95,depth),"slate")
        for y in [height-0.04,height-0.92]:
            _box(b,Vector3(x,y,cz),Vector3(0.94,0.18,depth+0.78),"armor")
        for i in range(1,6):
            var z: float = rear+depth*float(i)/6.0
            _box(b,Vector3(x,height-0.48,z),Vector3(0.80,0.74,0.16),"trim")
    # Top lattice: two cross beams and longitudinal service rails. Large
    # rectangular openings show the sky; no roof sheet or continuous ceiling.
    for z in [rear+depth*0.33,rear+depth*0.67]:
        _box(b,Vector3(cx,height-0.68,z),Vector3(width-0.8,0.46,0.30),"slate")
        for y in [height-0.43,height-0.93]:
            _box(b,Vector3(cx,y,z),Vector3(width-0.8,0.12,0.60),"edge")
    for x in [cx-width*0.25,cx+width*0.25]:
        _box(b,Vector3(x,height-0.34,cz),Vector3(0.30,0.34,depth-0.92),"trim")
    # Knee braces stay in the upper corners. No diagonal across the front
    # face; all goods, CRATE and the central machine remain visible.
    for x in [left,right]:
        var sx: float = 1.0 if x<cx else -1.0
        for z in [rear,front]:
            var sz: float = 1.0 if z<cz else -1.0
            _pipe(b,Vector3(x,height-3.45,z),Vector3(x,height-1.0,z+sz*3.1),0.32,"edge")
            if z == rear:
                _pipe(b,Vector3(x,height-3.45,z),Vector3(x+sx*3.1,height-1.0,z),0.32,"edge")
        # High-side diagonal bracing restricted to rear bay only.
        _pipe(b,Vector3(x,5.1,rear),Vector3(x,height-1.05,rear+depth*0.32),0.26,"slate")
        _pipe(b,Vector3(x,height-1.05,rear),Vector3(x,5.1,rear+depth*0.32),0.26,"slate")
        # Rear half has a separately supported maintenance rail.
        _box(b,Vector3(x,5.1,rear+depth*0.16),Vector3(0.38,0.34,depth*0.32),"trim")
    # Low perimeter cable tray, junction boxes and connected risers.
    # No cables or obstacles cross the access ramps or the work route.
    for x in [left,right]:
        var inward: float = 1.0 if x<cx else -1.0
        var cable_x: float = x+inward*0.72
        _box(b,Vector3(cable_x,0.14,cz-1.6),Vector3(0.39,0.24,depth-4.8),"trim")
        for j in range(8):
            var z: float = rear+1.0+float(j)*(depth-5.6)/7.0
            _box(b,Vector3(cable_x,0.29,z),Vector3(0.48,0.08,0.14),"edge")
        _pipe(b,Vector3(cable_x,0.26,rear+0.8),Vector3(cable_x,0.26,rear),0.16,"rubber")
        _pipe(b,Vector3(cable_x,0.26,rear),Vector3(cable_x,3.3,rear),0.16,"rubber")
        _pipe(b,Vector3(cable_x,3.3,rear),Vector3(x+inward*0.44,3.3,rear),0.16,"rubber")
        _shape(b,"bevel",Vector3(x+inward*0.68,2.55,rear),
            Vector3(0.62,1.0,0.65),"armor_light")
        _box(b,Vector3(x+inward*0.68,2.72,rear+0.35),
            Vector3(0.40,0.11,0.05),"lab_cyan")
        # Recessed side service drains and the near corner bumper.
        for z in [cz-3.1,cz+3.1]:
            _box(b,Vector3(x+inward*1.42,0.028,z),Vector3(0.78,0.045,1.6),"dark")
            for j in range(7):
                _box(b,Vector3(x+inward*1.42,0.060,z-0.66+float(j)*0.22),
                    Vector3(0.69,0.045,0.065),"edge")
        _shape(b,"octagonal_slew",Vector3(x+inward*1.05,0.64,front-1.25),
            Vector3(0.38,1.28,0.38),"gold")
        _box(b,Vector3(x+inward*1.05,0.86,front-1.25),Vector3(0.42,0.15,0.42),"trim")
    # Dedicated fixture identities: LABO cool task light, STORAGE amber
    # loading indicator. Emissive geometry shares the existing batch palette.
    for x in [left,right]:
        var inward: float = 1.0 if x<cx else -1.0
        for z in [rear,front]:
            var lamp_x: float = x+inward*1.45
            _pipe(b,Vector3(x,7.2,z),Vector3(lamp_x,7.2,z),0.16,"trim")
            _shape(b,"hood",Vector3(lamp_x,7.02,z),Vector3(0.9,0.30,0.74),"armor")
            _box(b,Vector3(lamp_x,6.83,z),Vector3(0.68,0.06,0.52),
                "lab_cyan" if is_lab else "amber_light")
    # Small equipment identification panels on the front top beam.
    # They are separate physical faces rather than UI overlay.
    _shape(b,"bevel",Vector3(cx,height-0.49,front+0.53),Vector3(4.5,0.70,0.18),"dark")
    for i in range(3):
        _box(b,Vector3(cx-1.55+float(i)*0.32,height-0.48,front+0.65),
            Vector3(0.17,0.34,0.07),"lab_cyan" if is_lab else "amber_light")
    _box(b,Vector3(cx+0.82,height-0.49,front+0.65),Vector3(2.10,0.09,0.07),"edge")
    _finish(b)
    # Two near-corner lamps illuminate only the loading edge; no new shadows.
    for x in [left,right]:
        var inward: float = 1.0 if x<cx else -1.0
        _task_light(frame,Vector3(x+inward*1.45,6.65,front),
            Color("#c4efff") if is_lab else Color("#ffdda1"),9.0,0.65)

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
        industrial_horizon.avoid_base_proxies(context_models)
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
    industrial_horizon.avoid_base_proxies(context_models)

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

# Product dimensions share the print-head and transfer clearance limits.
# True segmented bores are open geometry, not painted black circles.
const PART_HEIGHTS := [1.30,0.90,1.10,1.40]
const PART_WIDTHS := [1.65,1.75,1.90,1.55]
const PART_NAMES := ["HydraulicActuator","ReductionGearbox","JointMountingYoke","CoolantValveBlock"]

func _part_ring(b,center: Vector3,outer: float,inner: float,h: float,mat: String) -> void:
    var count: int = 12
    var radius: float = (outer+inner)*0.5
    for j in range(count):
        var angle: float = TAU*(float(j)+0.5)/float(count)
        var pos := center+Vector3(cos(angle)*radius,0,sin(angle)*radius)
        b.box_tilt("MachinedAnnularSegment",pos,
            Vector3(outer-inner,h,2.0*outer*tan(PI/float(count))+0.015),mat,Vector3(0,-angle,0))

func _part_bolts(b,y: float,r: float,count: int) -> void:
    for j in range(count):
        var angle: float = TAU*float(j)/float(count)
        _shape(b,"drum",Vector3(cos(angle)*r,y,sin(angle)*r),Vector3(0.11,0.07,0.11),"edge")

func _fabricated_part(b,i: int) -> void:
    match i:
        0:
            # Hydraulic linear actuator: square mounting flange, pressure body,
            # piston gland, exposed chrome rod and upper mounting eye.
            _shape(b,"bevel",Vector3(0,0.09,0),Vector3(1.35,0.18,1.22),"armor_light")
            _shape(b,"drum",Vector3(0,0.45,0),Vector3(0.88,0.65,0.88),"blue")
            _shape(b,"octagonal_slew",Vector3(0,0.75,0),Vector3(1.05,0.16,1.05),"edge")
            _shape(b,"drum",Vector3(0,0.94,0),Vector3(0.36,0.29,0.36),"armor_light")
            b.poly_tilt("ActuatorClevis","drum",Vector3(0,1.065,0),Vector3(0.40,0.28,0.40),"slate",Vector3(PI*0.5,0,0))
            _box(b,Vector3(0,1.265,0),Vector3(0.52,0.07,0.38),"edge")
            for side in [-1.0,1.0]:
                _pipe(b,Vector3(side*0.44,0.30,0),Vector3(side*0.70,0.30,0),0.16,"gold")
                _shape(b,"octagonal_slew",Vector3(side*0.68,0.30,0),Vector3(0.20,0.22,0.22),"edge")
            _part_bolts(b,0.20,0.51,4)
        1:
            # Reduction gearbox: finned cast housing, output flange, hub and
            # two identifiable mounting ears.
            _shape(b,"bevel",Vector3(0,0.30,0),Vector3(1.32,0.60,1.30),"slate")
            for side in [-1.0,1.0]:
                _shape(b,"bevel",Vector3(side*0.70,0.10,0),Vector3(0.35,0.20,0.83),"armor_light")
                for z in [-0.38,-0.13,0.13,0.38]:
                    _box(b,Vector3(side*0.69,0.37,z),Vector3(0.12,0.35,0.10),"edge")
            _shape(b,"drum",Vector3(0,0.64,0),Vector3(1.12,0.16,1.12),"armor_light")
            _part_ring(b,Vector3(0,0.78,0),0.48,0.25,0.16,"gold")
            _shape(b,"drum",Vector3(0,0.79,0),Vector3(0.34,0.22,0.34),"edge")
            _part_bolts(b,0.755,0.51,6)
        2:
            # Open joint yoke: reinforced base and twin bearing ears with
            # a genuine through-bore assembled from an annular profile.
            _shape(b,"bevel",Vector3(0,0.12,0),Vector3(1.90,0.24,1.48),"armor_light")
            for side in [-1.0,1.0]:
                _shape(b,"gusset",Vector3(side*0.66,0.44,0),Vector3(0.32,0.74,1.20),"slate")
                for j in range(12):
                    var theta: float = TAU*(float(j)+0.5)/12.0
                    var pos := Vector3(side*0.66,0.65+cos(theta)*0.27,sin(theta)*0.27)
                    b.box_tilt("BearingEarSegment",pos,Vector3(0.33,0.16,0.18),"edge",Vector3(theta,0,0))
            _box(b,Vector3(0,1.055,0),Vector3(1.58,0.09,0.36),"gold")
            for x in [-0.72,0.72]:
                for z in [-0.54,0.54]:
                    _shape(b,"drum",Vector3(x,0.265,z),Vector3(0.13,0.07,0.13),"edge")
        3:
            # Coolant valve manifold: cast port block, opposed fittings,
            # selector cylinder, bolted cap and a central pickup pad.
            _shape(b,"bevel",Vector3(0,0.31,0),Vector3(1.22,0.62,1.38),"armor_light")
            for side in [-1.0,1.0]:
                for z in [-0.40,0.40]:
                    _pipe(b,Vector3(side*0.48,0.32,z),Vector3(side*0.66,0.32,z),0.22,"gold")
                    _shape(b,"octagonal_slew",Vector3(side*0.66,0.32,z),Vector3(0.22,0.31,0.31),"edge")
            _shape(b,"drum",Vector3(0,0.88,0),Vector3(0.72,0.54,0.72),"blue")
            _shape(b,"octagonal_slew",Vector3(0,1.18,0),Vector3(0.91,0.18,0.91),"gold")
            _shape(b,"drum",Vector3(0,1.33,0),Vector3(0.42,0.14,0.42),"edge")
            _part_bolts(b,0.655,0.45,4)

# Authored fixed-length links, analytical two-bone IK, independent wrist.
const PRINT_UPPER := 2.65
const PRINT_FORE := 2.55
const PRINT_TOOL := 0.62
const PRINT_SHOULDER := Vector3(0,2.20,0)

func _lab_rear_wall(key: String) -> void:
    # Only the far side is opaque. It sits against the rear portal, not
    # across the floor or any of the three open access faces.
    var wall := _model(key,"LabRearIndustrialServiceWall",Vector3(-0.7,0,-10.1))
    var b = _batch(wall)
    _box(b,Vector3(0,7.7,0),Vector3(26.3,15.4,0.52),"dark")
    _box(b,Vector3(0,0.52,0.34),Vector3(26.3,1.04,0.28),"trim")
    _box(b,Vector3(0,15.02,0.34),Vector3(26.3,0.52,0.32),"slate")
    # Recessed central spine, two stepped machinery bays and tall outer bays.
    for side in [-1.0,1.0]:
        var sx: float = float(side)
        _shape(b,"bevel",Vector3(sx*10.2,7.7,0.37),Vector3(5.1,13.6,0.48),"slate")
        _shape(b,"bevel",Vector3(sx*5.65,7.7,0.43),Vector3(3.65,13.6,0.62),"armor")
        _box(b,Vector3(sx*3.48,7.75,0.63),Vector3(0.42,14.0,0.78),"trim")
        _box(b,Vector3(sx*12.7,7.75,0.58),Vector3(0.36,14.0,0.52),"edge")
        for y in [2.0,5.7,9.4,13.1]:
            _panel_detail(b,sx*10.2,y,0.65,4.15,2.75)
        for y in [3.0,7.1,11.2]:
            _shape(b,"louver",Vector3(sx*5.65,y,0.80),Vector3(2.72,2.45,0.22),"trim")
            _box(b,Vector3(sx*5.65,y+1.42,0.93),Vector3(1.82,0.10,0.07),"edge")
        # Routed coolant and power conduits are fixed to the wall surface.
        for j in range(2):
            var x: float = sx*(7.72+float(j)*0.43)
            _pipe(b,Vector3(x,1.15,0.68),Vector3(x,13.85,0.68),0.19,"edge" if j==0 else "blue")
            for y in [2.0,5.5,9.0,12.5]:
                _box(b,Vector3(x,y,0.67),Vector3(0.34,0.12,0.24),"trim")
        _box(b,Vector3(sx*3.48,11.95,1.04),Vector3(0.12,3.9,0.08),"lab_cyan")
        _shape(b,"bevel",Vector3(sx*2.25,3.25,0.57),Vector3(1.75,4.0,0.38),"armor")
        _panel_detail(b,sx*2.25,3.25,0.81,1.35,2.9)
    _shape(b,"bevel",Vector3(0,8.5,0.34),Vector3(6.25,11.8,0.35),"slate")
    _shape(b,"bevel",Vector3(0,11.95,0.66),Vector3(4.6,2.5,0.36),"armor")
    _box(b,Vector3(0,11.95,0.88),Vector3(3.8,1.88,0.08),"dark")
    # Compact central status motif made of three machine-status glyphs.
    for i in range(3):
        _box(b,Vector3(-1.24+float(i)*1.24,12.0,0.95),Vector3(0.76,0.38,0.07),"lab_cyan")
        _box(b,Vector3(-1.24+float(i)*1.24,11.54,0.95),Vector3(0.76,0.10,0.07),"edge")
    for y in [4.9,6.5,8.1]:
        _shape(b,"louver",Vector3(0,y,0.63),Vector3(3.9,0.95,0.22),"trim")
    _finish(b)
    _moving(key,"rear_wall",wall)

func _print_joint(parent: Node3D,label: String,radius: float,width: float) -> Node3D:
    var n := _child(parent,label)
    var b = _batch(n)
    b.poly_tilt("JointBarrel","drum",Vector3.ZERO,Vector3(radius*2,width,radius*2),"slate",Vector3(0,0,PI*0.5))
    for side in [-1.0,1.0]:
        b.poly_tilt("JointCap","octagonal_slew",Vector3(float(side)*(width*0.5+0.045),0,0),Vector3(radius*1.55,0.12,radius*1.55),"armor_light",Vector3(0,0,PI*0.5))
        b.poly_tilt("JointAxle","drum",Vector3(float(side)*(width*0.5+0.12),0,0),Vector3(radius*0.68,0.10,radius*0.68),"gold",Vector3(0,0,PI*0.5))
    _finish(b)
    return n

func _print_link(parent: Node3D,label: String,length: float,width: float) -> Node3D:
    var n := _child(parent,label)
    var b = _batch(n)
    # Local +Y is the link axis. End faces overlap the joint housings.
    _shape(b,"bevel",Vector3(0,length*0.5,0),Vector3(width,length-0.28,width*0.74),"armor")
    for side in [-1.0,1.0]:
        _box(b,Vector3(float(side)*width*0.49,length*0.5,0),Vector3(0.09,length-0.44,width*0.60),"slate")
        _pipe(b,Vector3(float(side)*width*0.39,0.26,-width*0.42),Vector3(float(side)*width*0.39,length-0.26,-width*0.42),0.10,"edge")
    _box(b,Vector3(0,length*0.5,width*0.39),Vector3(width*0.36,length*0.42,0.055),"lab_cyan")
    _finish(b)
    return n

func _make_print_arm(mount: Node3D,radial: Vector3) -> Dictionary:
    var b = _batch(mount)
    _shape(b,"bevel",Vector3(0,1.01,0),Vector3(1.48,0.28,1.48),"slate")
    _shape(b,"drum",Vector3(0,1.29,0),Vector3(1.22,0.28,1.22),"edge")
    _shape(b,"octagonal_slew",Vector3(0,1.58,0),Vector3(1.08,0.44,1.08),"armor")
    for x in [-0.56,0.56]:
        for z in [-0.56,0.56]:
            _shape(b,"drum",Vector3(x,1.18,z),Vector3(0.15,0.08,0.15),"gold")
    _finish(b)
    var swivel := _child(mount,"BaseYaw")
    b = _batch(swivel)
    _shape(b,"bevel",Vector3(0,1.91,0),Vector3(0.80,0.66,0.80),"slate")
    _finish(b)
    var shoulder := _print_joint(mount,"ShoulderPitch",0.48,0.80)
    var upper := _print_link(mount,"UpperLink",PRINT_UPPER,0.66)
    var elbow := _print_joint(mount,"ElbowPitch",0.40,0.68)
    var fore := _print_link(mount,"Forearm",PRINT_FORE,0.52)
    var wrist := _print_joint(mount,"WristPitch",0.26,0.45)
    var tool := _child(mount,"PrintNozzle")
    b = _batch(tool)
    _shape(b,"bevel",Vector3(0,0.17,0),Vector3(0.53,0.34,0.53),"slate")
    _shape(b,"octagonal_slew",Vector3(0,0.38,0),Vector3(0.46,0.20,0.46),"gold")
    _shape(b,"drum",Vector3(0,0.54,0),Vector3(0.20,0.16,0.20),"edge")
    _shape(b,"drum",Vector3(0,0.61,0),Vector3(0.12,0.02,0.12),"lab_cyan")
    # Asymmetric service lug makes wrist rotation visible even at a distance.
    _shape(b,"bevel",Vector3(0.30,0.22,0),Vector3(0.16,0.25,0.23),"gold")
    _box(b,Vector3(0.39,0.22,0),Vector3(0.035,0.13,0.11),"lab_cyan")
    _finish(b)
    return {"radial":radial,"swivel":swivel,"shoulder":shoulder,"upper":upper,"elbow":elbow,"fore":fore,"wrist":wrist,"tool":tool,"idle_time":-print_idle_rng.randf_range(0.1,1.8),"idle_duration":2.0,"idle_kind":0,"idle_sign":1.0}

func _print_link_pose(n: Node3D,a: Vector3,z: Vector3,hinge: Vector3) -> void:
    var y: Vector3 = (z-a).normalized()
    var x: Vector3 = hinge.normalized()
    var depth: Vector3 = x.cross(y).normalized()
    x = y.cross(depth).normalized()
    n.transform = Transform3D(Basis(x,y,depth),a)

func _sample_print_arm(arm: Dictionary,index: int,t: float,height: float,grow: float) -> void:
    var radial: Vector3 = arm["radial"]
    var tangent: Vector3 = Vector3.UP.cross(radial)
    var blend: float = smoothstep(0.015+float(index)*0.018,0.10,t)*(1.0-smoothstep(0.46,0.56-float(index)*0.014,t))
    var wave: float = sin(t*TAU*8.0+float(index)*2.094)
    var nominal_radius: float = 0.64 if index==2 else 0.73
    var scan_radius: float = nominal_radius+0.06*cos(t*TAU*6.0+float(index)*2.094)
    # Local mount coordinates; radial sectors never cross the bed center.
    var work: Vector3 = radial*(scan_radius-4.35)+tangent*(0.16*wave)
    work.y = 2.12+height*grow+0.20
    var park: Vector3 = -radial*1.20+Vector3.UP*4.45
    var tip: Vector3 = park.lerp(work,blend)
    var tool_axis: Vector3 = (Vector3.DOWN-radial*0.16*blend).normalized()
    _pose_print_arm(arm,tip,tool_axis,0.0)

func _pose_print_arm(arm: Dictionary,tip: Vector3,tool_axis: Vector3,roll: float) -> void:
    var wrist_pos: Vector3 = tip-tool_axis*PRINT_TOOL
    var delta: Vector3 = wrist_pos-PRINT_SHOULDER
    var d: float = clampf(delta.length(),0.18,PRINT_UPPER+PRINT_FORE-0.025)
    var along: Vector3 = delta.normalized()
    wrist_pos = PRINT_SHOULDER+along*d
    tip = wrist_pos+tool_axis*PRINT_TOOL
    var perpendicular: Vector3 = (Vector3.UP-along*along.dot(Vector3.UP)).normalized()
    var projected: float = (PRINT_UPPER*PRINT_UPPER-PRINT_FORE*PRINT_FORE+d*d)/(2.0*d)
    var rise: float = sqrt(maxf(0.0,PRINT_UPPER*PRINT_UPPER-projected*projected))
    var elbow_pos: Vector3 = PRINT_SHOULDER+along*projected+perpendicular*rise
    var hinge: Vector3 = along.cross(perpendicular).normalized()
    var swivel: Node3D = arm["swivel"]
    swivel.rotation.y = atan2(-along.x,-along.z)
    _print_link_pose(arm["shoulder"],PRINT_SHOULDER,elbow_pos,hinge)
    _print_link_pose(arm["upper"],PRINT_SHOULDER,elbow_pos,hinge)
    _print_link_pose(arm["elbow"],elbow_pos,wrist_pos,hinge)
    _print_link_pose(arm["fore"],elbow_pos,wrist_pos,hinge)
    _print_link_pose(arm["wrist"],wrist_pos,tip,hinge)
    _print_link_pose(arm["tool"],wrist_pos,tip,hinge)
    (arm["tool"] as Node3D).rotate_object_local(Vector3.UP,roll)

func _animate_print_idle(delta: float) -> void:
    # The idle envelope returns the heads to their authored neutral position
    # before printing begins or the scene is switched. No movement near stock.
    var weight: float = 1.0
    if cycle_running:
        var t: float = elapsed/maxf(0.01,float(logistics["LABO"].duration()))
        if t<0.29:
            weight = 1.0-smoothstep(0.23,0.29,t)
        elif t<0.72:
            var machine_t: float = (t-0.29)/0.43
            weight = smoothstep(0.56,0.64,machine_t)
        else:
            weight = 1.0
    if weight<=0.001:
        return
    var arms: Array = motion_parts["LABO"]["print_arms"]
    for arm in arms:
        var age: float = float(arm["idle_time"])+delta
        var span: float = float(arm["idle_duration"])
        if age>=span:
            age = -print_idle_rng.randf_range(0.6,2.8)
            arm["idle_kind"] = print_idle_rng.randi_range(0,4)
            arm["idle_duration"] = print_idle_rng.randf_range(1.4,3.1)
            arm["idle_sign"] = -1.0 if print_idle_rng.randf()<0.5 else 1.0
            span = float(arm["idle_duration"])
        arm["idle_time"] = age
        var u: float = clampf(age/span,0.0,1.0)
        var e: float = sin(PI*u)*weight
        var radial: Vector3 = arm["radial"]
        var tangent: Vector3 = Vector3.UP.cross(radial)
        var tip: Vector3 = -radial*1.20+Vector3.UP*4.45
        var axis: Vector3 = Vector3.DOWN
        var roll: float = 0.0
        var sign_value: float = float(arm["idle_sign"])
        match int(arm["idle_kind"]):
            0: roll = sign_value*TAU*e
            1: tip.y += 0.40*e
            2: axis = (Vector3.DOWN+tangent*(0.24*sin(TAU*u)*e)).normalized()
            3:
                tip += radial*0.28*e
                roll = sign_value*0.65*sin(TAU*u)*e
            4:
                tip.y += 0.23*e
                tip += tangent*(0.16*sin(TAU*u)*e)
        _pose_print_arm(arm,tip,axis,roll)

func _labo(key: String) -> void:
    # Independent full-size design: three articulated print arms, left feedstock
    # racks, rear extraction, central bed and guided output shuttle.
    var frame := _model(key,"OpenFabricationCell",Vector3(0,0,-1.0))
    var b = _batch(frame)
    _skid(b,13.6,12.2)
    _shape(b,"deck",Vector3(0,0.72,0.65),Vector3(13.2,0.32,10.9),"armor")
    # Recessed base service panels and visible hardware, outside the shuttle sweep.
    for side in [-1.0,1.0]:
        for z in [-3.5,-1.2,1.1,3.4]:
            _box(b,Vector3(side*6.57,0.69,z),Vector3(0.07,0.19,1.68),"slate")
            _box(b,Vector3(side*6.62,0.70,z),Vector3(0.04,0.055,0.45),"edge")
        for z in [-3.9,4.8]:
            _shape(b,"drum",Vector3(side*6.05,0.91,z),Vector3(0.22,0.09,0.22),"trim")
    _shape(b,"octagonal_slew",Vector3(1.10,1.10,2.0),Vector3(5.9,0.65,4.4),"dark")
    _shape(b,"deck",Vector3(1.10,1.56,2.0),Vector3(6.6,0.46,4.9),"armor_light")
    _finish(b)
    inspection[key] = {"root":frame,"stand":Vector3(-2.0,0,8.15),"focus":Vector3(1.1,2.5,2.0)}
    var arm_data: Array[Dictionary] = []
    # Three sectors: left, right and rear. The entire front stays open for
    # the existing shuttle, receiving rollers and CRATE.
    for i in range(3):
        var radial: Vector3 = [Vector3.LEFT,Vector3.RIGHT,Vector3(0,0,-1)][i]
        var mount := _child(frame,"ArticulatedPrinterMount%d"%(i+1),Vector3(1.10,0,2.0)+radial*4.35)
        (targets[key] as Array).append(mount)
        var arm: Dictionary = _make_print_arm(mount,radial)
        _sample_print_arm(arm,i,0.0,1.30,0.0)
        arm_data.append(arm)
        _moving(key,"arm_mount%d"%i,mount)
    motion_parts[key]["print_arms"] = arm_data
    var rack := _model(key,"FeedstockRacks",Vector3(-9.1,0,-3.0))
    rack.scale.x = 0.90
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
    for y in [1.0,3.7,6.3]:
        for x in [-1.45,1.45]:
            _box(b,Vector3(x,y,1.19),Vector3(0.42,0.13,0.06),"gold")
    for x in [-1.62,1.62]:
        _box(b,Vector3(x,6.84,0.98),Vector3(0.18,0.55,0.11),"lab_cyan")
    _finish(b)
    var supply := _model(key,"ReceivingHopperAndFeed",Vector3(-9.0,0,2.8))
    _moving(key,"supply",supply)
    b = _batch(supply)
    _shape(b,"hopper",Vector3(0,2.65,0),Vector3(2.8,2.0,2.7),"armor_light")
    for x in [-0.9,0.9]:
        _shape(b,"gusset",Vector3(x,0.9,0),Vector3(0.50,1.8,1.4),"slate")
    _pipe(b,Vector3(0,1.78,0),Vector3(0.7,1.78,-5.8),0.57,"trim")
    _pipe(b,Vector3(0.7,1.78,-5.8),Vector3(1.7,2.1,-5.8),0.57,"edge")
    for side in [-1.0,1.0]:
        _box(b,Vector3(side*1.16,2.9,1.19),Vector3(0.12,0.85,0.09),"edge")
    _box(b,Vector3(0,2.75,1.24),Vector3(0.55,0.17,0.09),"lab_cyan")
    _shape(b,"bevel",Vector3(0,1.30,0.25),Vector3(0.80,0.56,0.68),"slate")
    _finish(b)
    var extraction := _model(key,"RearExtractionAndCoolant",Vector3(8.25,0,-4.5))
    b = _batch(extraction)
    _shape(b,"vent_stack",Vector3(0,5.1,0),Vector3(2.0,10.2,2.0),"slate")
    _shape(b,"drum",Vector3(0,8.0,0),Vector3(2.6,0.64,2.6),"edge")
    _shape(b,"louver",Vector3(0,3.5,1.1),Vector3(1.45,1.7,0.25),"trim")
    for y in [2.3,4.7,6.8]:
        _shape(b,"gear",Vector3(0,y,0),Vector3(2.12,0.16,2.12),"edge")
    _box(b,Vector3(0,4.65,1.13),Vector3(0.66,0.15,0.07),"lab_cyan")
    _shape(b,"hood",Vector3(-2.1,8.5,0.8),Vector3(3.7,0.9,2.6),"armor_light")
    _pipe(b,Vector3(0,8.5,0),Vector3(-2.1,8.5,0.8),0.82,"trim")
    _shape(b,"drum",Vector3(-0.4,2.0,2.2),Vector3(1.65,3.6,1.65),"blue")
    for y in [0.65,3.55]:
        _shape(b,"gear",Vector3(-0.4,y,2.2),Vector3(1.9,0.28,1.9),"edge")
    _pipe(b,Vector3(-0.4,0.9,2.8),Vector3(-0.4,0.9,4.6),0.34,"gold")
    _finish(b)
    # Independent straight shuttle: no rotating arm crossing printer columns.
    # The rails, shuttle, and product use one frame-local coordinate system.
    var rail := _child(frame,"PrintTransferRails",Vector3(1.10,0,2.0))
    (targets[key] as Array).append(rail)
    b = _batch(rail)
    for x in [-0.92,0.92]:
        _box(b,Vector3(x,1.84,1.85),Vector3(0.18,0.10,5.65),"edge")
        for z in [0.0,2.4,4.4]:
            _shape(b,"gusset",Vector3(x,1.28,z),Vector3(0.30,1.02,0.50),"slate")
    _finish(b)
    var tray := _child(rail,"FinishedStockReceiver",Vector3(0,0,3.7))
    (targets[key] as Array).append(tray)
    b = _batch(tray)
    # Open-sided receiver: shuttle passes between guide rails without a front wall.
    for x in [-1.50,1.50]:
        _shape(b,"gusset",Vector3(x,0.95,0),Vector3(0.35,1.9,1.8),"slate")
        _box(b,Vector3(x,1.93,0),Vector3(0.24,0.16,2.5),"gold")
    _box(b,Vector3(0,1.3,1.35),Vector3(3.0,0.20,0.18),"edge")
    for side in [-1.0,1.0]:
        _box(b,Vector3(side*1.45,1.47,1.80),Vector3(0.15,0.24,2.85),"slate")
        _box(b,Vector3(side*1.45,1.48,3.13),Vector3(0.19,0.20,0.09),"lab_cyan")
    # The outfeed rollers are flush with the shuttle and beyond its travel end.
    for x in [-1.12,1.12]:
        _shape(b,"gusset",Vector3(x,1.02,2.5),Vector3(0.32,2.0,0.6),"slate")
    for j in range(9):
        var z: float = 1.34+float(j)*0.29
        _pipe(b,Vector3(-1.16,2.02,z),Vector3(1.16,2.02,z),0.20,"edge")
    _finish(b)
    var shuttle := _child(rail,"PrintTransferShuttle")
    b = _batch(shuttle)
    _shape(b,"deck",Vector3(0,2.03,0),Vector3(2.55,0.18,2.35),"armor_light")
    for x in [-0.92,0.92]:
        _box(b,Vector3(x,1.94,0),Vector3(0.26,0.10,1.75),"gold")
    _finish(b)
    _moving(key,"shuttle",shuttle)
    _moving(key,"rail",rail)
    _moving(key,"print_frame",frame)
    _moving(key,"tray",tray)
    var product_root := _child(shuttle,"FabricatedWorkpieces",Vector3(0,2.12,0))
    # Product is physically parented to its carrier, never interpolated independently.
    for i in range(4):
        var piece := _child(product_root,PART_NAMES[i])
        b = _batch(piece)
        _fabricated_part(b,i)
        _finish(b)
        piece.visible = false
    _moving(key,"products",product_root)
    motion_parts[key]["variant"] = -1
    var utility := _model(key,"LabPowerAndTaskLighting",Vector3(7.7,0,2.5))
    b = _batch(utility)
    _shape(b,"bevel",Vector3(0,1.0,0),Vector3(1.45,2.0,1.2),"slate")
    _panel_detail(b,0,1.12,0.65,1.1,1.5)
    _shape(b,"louver",Vector3(0,0.46,0.68),Vector3(0.82,0.41,0.09),"trim")
    for x in [-0.31,0.0,0.31]:
        _box(b,Vector3(x,1.76,0.67),Vector3(0.13,0.08,0.05),"lab_cyan" if x==0.0 else "gold")
    _pipe(b,Vector3(0,1.9,0),Vector3(0,6.0,0),0.22,"trim")
    _pipe(b,Vector3(0,6.0,0),Vector3(-1.9,6.0,-0.4),0.22,"edge")
    _shape(b,"hood",Vector3(-1.9,6.0,-0.4),Vector3(1.1,0.35,0.7),"armor")
    _box(b,Vector3(-1.9,5.79,-0.4),Vector3(0.8,0.07,0.52),"amber_light")
    _floor_cable(b,[Vector3(0,0.1,0.6),Vector3(0,0.1,2.1),Vector3(-1.7,0.1,2.8),Vector3(-3.3,0.1,2.8)])
    _finish(b)
    _task_light(utility,Vector3(-1.9,5.52,-0.4),Color("#ffe0b2"),8.0,1.4)
    _console(key,Vector3(3.2,0,7.15),0)

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
        for y in [2.0,3.0,4.0,6.1]:
            _box(b,Vector3(x,y,2.30),Vector3(1.45,0.14,0.16),"edge")
        _box(b,Vector3(x,5.75,2.40),Vector3(0.70,0.14,0.08),"amber_light")
    for side in [-1.0,1.0]:
        for y in [2.1,3.4,4.7,6.0]:
            _shape(b,"gear",Vector3(side*4.15,y,-0.55),Vector3(1.86,0.10,1.86),"trim")
        _pipe(b,Vector3(side*3.35,1.0,-2.8),Vector3(side*3.35,6.9,-2.8),0.24,"rust")
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
    # Strengthen the upper grille and furnace frame outside the fire opening.
    _shape(b,"bevel",Vector3(0,6.47,3.22),Vector3(5.25,1.02,0.36),"trim")
    for j in range(5):
        _box(b,Vector3(0,6.13+float(j)*0.16,3.46),Vector3(4.63,0.085,0.15),"edge")
    for side in [-1.0,1.0]:
        var x: float = side*3.05
        _box(b,Vector3(x,3.18,4.36),Vector3(0.18,3.95,0.14),"trim")
        for y in [1.35,2.20,3.05,3.90,4.75]:
            _box(b,Vector3(x,y,4.47),Vector3(0.34,0.16,0.13),"edge")
        _shape(b,"bevel",Vector3(side*3.72,5.85,2.85),Vector3(0.95,0.52,0.42),"rust")
        _box(b,Vector3(side*3.72,5.86,3.10),Vector3(0.52,0.10,0.07),"amber_light")
        _shape(b,"gusset",Vector3(side*3.65,0.93,2.60),Vector3(0.80,1.1,1.45),"trim")
    _finish(b)
    inspection[key] = {"root":furnace,"stand":Vector3(0.8,0,6.5),"focus":Vector3(0,3.0,4.1)}
    var hot := _child(furnace,"RecessedFire",Vector3(0,3.0,3.80))
    (targets[key] as Array).append(hot)
    # Three small fixed-depth alpha sheets, not billboarded to the camera.
    # The baked advection carries real coherent shapes instead of scrolling noise.
    var spans := [Vector2(4.38,3.80),Vector2(4.22,3.58),Vector2(3.95,3.45)]
    var phases := [0,31,67]
    var opacity := [1.0,0.72,0.48]
    for i in range(3):
        var sheet: Sprite3D = FurnaceFlame.make_sheet("CombustionLayer"+str(i),
            spans[i],Vector3(float(i-1)*0.08,-0.04-0.5*(3.80-spans[i].y),0.065+float(i)*0.20),
            opacity[i],phases[i])
        if sheet == null:
            continue
        hot.add_child(sheet)
        fire_layers.append(sheet)
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
        for y in [9.3,11.5,13.45]:
            _shape(b,"drum",Vector3(0,y-0.20,0),Vector3(1.84,0.12,1.84),"trim")
            for j in range(8):
                var a: float = TAU*float(j)/8.0
                _box(b,Vector3(cos(a)*0.96,y+0.19,sin(a)*0.96),
                    Vector3(0.13,0.11,0.13),"edge")
        for y in [10.0,12.2]:
            _box(b,Vector3(0,y,0.80),Vector3(0.48,0.50,0.14),"trim")
            _box(b,Vector3(0,y,0.89),Vector3(0.31,0.09,0.05),"edge")
        _finish(b)
        _stack_ink(stack)
    var feed := _model(key,"SideChargeHopper",Vector3(-6.6,0,-0.6))
    b = _batch(feed)
    _shape(b,"hopper",Vector3(0,4.5,0),Vector3(3.5,2.7,3.7),"armor")
    for x in [-1.2,1.2]:
        for z in [-1.1,1.1]:
            _shape(b,"gusset",Vector3(x,1.8,z),Vector3(0.45,3.6,0.48),"slate")
    _pipe(b,Vector3(0,3.5,0),Vector3(3.4,3.5,0),1.20,"armor")
    _shape(b,"tray",Vector3(0,1.18,0.95),Vector3(2.5,0.32,1.0),"slate")
    _pipe(b,Vector3(-1.1,1.1,-0.9),Vector3(-1.1,3.7,-0.9),0.20,"edge")
    _panel_detail(b,0,1.72,1.02,1.05,0.9)
    _box(b,Vector3(0,5.78,1.83),Vector3(3.42,0.23,0.25),"trim")
    for x in [-1.42,1.42]:
        _pipe(b,Vector3(x,5.62,1.72),Vector3(x*0.52,3.62,0.83),0.18,"edge")
        _box(b,Vector3(x,5.84,1.86),Vector3(0.25,0.10,0.18),"caution")
    _shape(b,"bevel",Vector3(0,4.83,1.72),Vector3(1.18,0.48,0.22),"slate")
    _box(b,Vector3(0,4.84,1.87),Vector3(0.65,0.10,0.06),"edge")
    _finish(b)
    _moving(key,"hopper",feed)
    _moving(key,"furnace",furnace)
    # Feed neck is enclosed, with visible flanges and a grounded service drive.
    var service := _child(feed,"ChargeMeteringService")
    b = _batch(service)
    _shape(b,"bevel",Vector3(1.15,0.75,-0.65),Vector3(1.1,1.5,1.3),"slate")
    _shape(b,"louver",Vector3(1.15,0.78,0.03),Vector3(0.75,0.75,0.12),"edge")
    _pipe(b,Vector3(1.15,1.5,-0.65),Vector3(1.15,3.5,-0.65),0.22,"gold")
    for y in [3.15,3.55]:
        _shape(b,"gear",Vector3(2.55,y,0),Vector3(0.24,0.32,0.32),"edge")
    _finish(b)
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
        for line in [-1.15,1.15]:
            b.poly_tilt("ShaftBearing","drum",Vector3(side*3.72,3.6,line),
                Vector3(1.7,0.64,1.7),"edge",Vector3(0,0,PI*0.5))
        _panel_detail(b,side*3.7,1.9,3.42,1.0,1.45)
    b.box_tilt("RearGravityChute",Vector3(0,5.63,-2.30),Vector3(5.8,0.22,1.90),
        "slate",Vector3(0.60,0,0))
    b.box_tilt("DischargeChute",Vector3(0,1.64,2.75),Vector3(5.8,0.34,3.45),
        "armor",Vector3(0.26,0,0))
    for side in [-1.0,1.0]:
        b.box_tilt("OutletCheek",Vector3(side*2.9,1.98,2.75),Vector3(0.24,0.60,3.45),
            "slate",Vector3(0.26,0,0))
    for x in [-3.0,3.0]:
        _box(b,Vector3(x,4.4,2.2),Vector3(0.24,0.18,2.0),"caution")
    _finish(b)
    inspection[key] = {"root":base,"stand":Vector3(-4.7,0,6.8),"focus":Vector3(0,3.4,0)}
    for i in range(2):
        var shaft_root := _model(key,"CutterShaftV2_"+str(i),Vector3(0,3.6,-2.85+i*2.30))
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
        _moving(key,"shaft_root"+str(i),shaft_root)
    var feed := _conveyor(key,"ScrapFeedLineV2",Vector3(0,0,-12.2),4.5,4.1)
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
    _moving(key,"feed_conveyor",feed)
    _moving(key,"scrap_mount",feed_mount)
    var ramp := _child(base,"ElevatedFeedRamp")
    (targets[key] as Array).append(ramp)
    b = _batch(ramp)
    # Rollers from the ground conveyor to the rear gravity chute.
    var start := Vector3(0,0.99,-8.4)
    var end := Vector3(0,6.10,-3.1)
    var rise: Vector3 = end-start
    for side in [-1.0,1.0]:
        _pipe(b,start+Vector3(side*2.15,0,0),end+Vector3(side*2.15,0,0),0.25,"caution")
        _pipe(b,Vector3(side*2.15,0,-5.8),Vector3(side*2.15,3.45,-5.8),0.30,"slate")
    for j in range(15):
        var at: Vector3 = start+rise*(float(j)/14.0)
        _pipe(b,at+Vector3(-2.0,0,0),at+Vector3(2.0,0,0),0.22,"edge")
    _finish(b)
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
    _moving(key,"ramp",ramp)
    _moving(key,"sorted_line",output)
    _moving(key,"sorted_mount",bin_mount)
    _console(key,Vector3(4.7,0,4.0),3)

func _storage(key: String) -> void:
    # Full-size warehouse is built by the shared logistics module after scaling.
    var anchor := _model(key,"WarehouseInspectionAnchor",Vector3(0,0,0))
    inspection[key] = {"root":anchor,"stand":Vector3(0,0,4.5),"focus":Vector3(0,3,-4.0)}
    _moving(key,"storage_anchor",anchor)
    _console(key,Vector3(0,0,7.5),4)

func _build_logistics(key: String) -> void:
    var m: Dictionary = motion_parts[key]
    var room: Node3D = rooms[key]
    var source := Vector3.ZERO
    var destination := Vector3.ZERO
    if key=="LABO":
        var supply := room.get_node("ReceivingHopperAndFeed") as Node3D
        source = room.to_local(supply.to_global(Vector3(0,3.75,0)))
        m["variant"] = 0
        _sample_machine(key,1.0)
        var product: Node3D = (m["products"] as Node3D).get_child(0) as Node3D
        destination = room.to_local(product.global_position)
        m["variant"] = -1
        _sample_machine(key,0.0)
    elif key=="SMELTER":
        var hopper: Node3D = m["hopper"]
        # The box front lower lip is directly above the real hopper opening.
        source = room.to_local(hopper.to_global(Vector3(0,5.85,0)))+Vector3(0,0.85,1.75)
        destination = Vector3(9.6,1.25,7.5)
    elif key!="STORAGE":
        _sample_machine(key,0.0)
        source = room.to_local((m["feed"] as Node3D).global_position)
        _sample_machine(key,1.0)
        destination = room.to_local((m["output"] as Node3D).global_position)
        _sample_machine(key,0.0)
        (m["feed"] as Node3D).visible = false
        (m["output"] as Node3D).visible = false
    var flow := Logistics.new()
    flow.build(room,key,source,destination)
    logistics[key] = flow
    # The complete connected logistics assembly is a single editable model.
    (targets[key] as Array).append(flow.root)

func logistics_reservations(key: String) -> Array[AABB]:
    var flow = logistics.get(key)
    if flow==null:
        return []
    var result: Array[AABB] = []
    for bounds in flow.reserves:
        result.append(flow.root.transform*bounds)
    return result

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
    idle_seconds = 0.0
    if logistics.has(key):
        logistics[key].reset()
    if key not in ["STORAGE","SMELTER"]:
        _sample_machine(key,0.0)
        _hide_machine_payloads(key)

func work_point(key: String, inspect: bool) -> Vector3:
    if inspect:
        var data: Dictionary = inspection[key]
        return (data["root"] as Node3D).to_global(data["stand"])
    return (terminals[key] as Node3D).to_global(Vector3(0,0,2.05))

func focus_point(key: String, inspect: bool) -> Vector3:
    if inspect:
        var data: Dictionary = inspection[key]
        return (data["root"] as Node3D).to_global(data["focus"])
    return (terminals[key] as Node3D).to_global(Vector3(0,1.05,0.34))

func start_cycle(key: String,prefer_inbound: bool = false) -> void:
    if key != active_key or cycle_running or not _mechanism_aligned(key):
        return
    elapsed = 0.0
    cycle_running = true
    if key == "LABO":
        motion_parts[key]["variant"] = (int(motion_parts[key]["variant"])+1)%4
    idle_seconds = 0.0
    logistics[key].begin(prefer_inbound)
    _sample(key,0.0)

func cycle_complete() -> bool:
    return not cycle_running

func logistics_carrier(key: String,inbound: bool) -> Node3D:
    var flow = logistics.get(key)
    if flow==null:
        return null
    return flow.truck_in if inbound else flow.truck_out

func animate(delta: float, time: float, key: String) -> void:
    if key != active_key:
        return
    industrial_horizon.animate(delta)
    for panel in screens.get(key,[]):
        panel.call("_process",delta)
    if key == "SMELTER":
        for layer in fire_layers:
            FurnaceFlame.sample(layer,time)
        if is_instance_valid(fire_light):
            var energy: float = 0.50*FurnaceFlame.radiance(time)+0.32*FurnaceFlame.radiance(time,31)+0.18*FurnaceFlame.radiance(time,67)
            fire_light.light_energy = 1.46*energy
    if cycle_running:
        if not _mechanism_aligned(key):
            cycle_running = false
            logistics[key].reset()
            return
        var duration: float = logistics[key].duration()
        # Do not skip a reserved stock handoff after a long app/frame pause.
        var advance: float = minf(delta,0.10)
        elapsed = minf(duration,elapsed+advance)
        _sample(key,elapsed/duration)
        cycle_running = elapsed < duration
    else:
        idle_seconds += delta
        if idle_seconds>=5.0:
            idle_seconds = 0.0
            start_cycle(key)
    if key=="LABO":
        _animate_print_idle(delta)

func _sample_machine(key: String, t: float, update_printer_arms: bool = true) -> void:
    var m: Dictionary = motion_parts[key]
    match key:
        "LABO":
            var shuttle: Node3D = m["shuttle"]
            var product: Node3D = m["products"]
            var variant: int = int(m["variant"])
            var product_height: float = float(PART_HEIGHTS[maxi(0,variant)])
            var grow: float = smoothstep(0.10,0.46,t)
            # All three heads work from independent radial sectors and retract
            # before the shuttle starts its forward travel at t=0.60.
            if update_printer_arms:
                for i in range(3):
                    _sample_print_arm(m["print_arms"][i],i,t,product_height,grow)
            shuttle.position.z = 3.7*smoothstep(0.60,0.76,t)
            # Roll the completed product onto the fixed outfeed before the shuttle returns.
            if t>=0.91:
                shuttle.position.z = 3.7*(1.0-smoothstep(0.91,1.0,t))
            for i in range(product.get_child_count()):
                var p := product.get_child(i) as Node3D
                p.visible = i==variant and t>0.10
                p.scale.y = maxf(0.03,grow)
                p.position = Vector3.ZERO
                if t>=0.76:
                    p.position.z = 3.7+2.50*smoothstep(0.76,0.91,t)-shuttle.position.z
        "RECYCLER":
            var feed: Node3D = m["feed"]
            var output: Node3D = m["output"]
            var crusher: Node3D = m["crusher"]
            var parent := feed.get_parent() as Node3D
            var incoming: Vector3 = parent.to_local((m["feed_conveyor"] as Node3D).to_global(Vector3(0,1.08,-1.0)))
            var start: Vector3 = parent.to_local(crusher.to_global(Vector3(0,1.10,-8.4)))
            var top: Vector3 = parent.to_local(crusher.to_global(Vector3(0,6.22,-3.1)))
            var chute_end: Vector3 = parent.to_local(crusher.to_global(Vector3(0,5.20,-1.52)))
            feed.scale = Vector3.ONE
            feed.rotation.x = 0.0
            feed.visible = t<0.52
            if t<0.16:
                feed.position = incoming.lerp(start,smoothstep(0.0,0.16,t))
            elif t<0.36:
                feed.position = start.lerp(top,smoothstep(0.16,0.36,t))
                feed.position.y += 0.44*smoothstep(0.16,0.20,t)-0.24*smoothstep(0.20,0.24,t)
                feed.rotation.x = -0.767*smoothstep(0.16,0.20,t)*(1.0-smoothstep(0.32,0.36,t))
            else:
                feed.position = top.lerp(chute_end,smoothstep(0.36,0.52,t))
                feed.position.y += lerpf(0.20,0.18,smoothstep(0.36,0.40,t))
                feed.rotation.x = 0.60*smoothstep(0.36,0.40,t)
                # Raw scrap is consumed above the cutter tips, not pushed through metal.
                feed.scale = Vector3.ONE*(1.0-0.92*smoothstep(0.44,0.52,t))
            (m["shaft0"] as Node3D).rotation.x = t*TAU*4.0
            (m["shaft1"] as Node3D).rotation.x = -t*TAU*4.0
            output.visible = t>0.60
            output.position.z = -1.7+3.4*smoothstep(0.60,1.0,t)
func _hide_machine_payloads(key: String) -> void:
    var m: Dictionary = motion_parts[key]
    if key=="LABO":
        for p in (m["products"] as Node3D).get_children():
            (p as Node3D).visible = false
    elif key not in ["STORAGE","SMELTER"]:
        (m["feed"] as Node3D).visible = false
        (m["output"] as Node3D).visible = false

func _sample(key: String,t: float) -> void:
    var flow = logistics[key]
    if key=="STORAGE":
        flow.sample_storage(t)
        return
    if key=="SMELTER":
        flow.sample_refinery(t)
        return
    var m: Dictionary = motion_parts[key]
    if t<0.29:
        # Idle poses belong to the independent printer idle animator.
        _sample_machine(key,0.0,false)
        _hide_machine_payloads(key)
        var input: Node3D = null if key=="LABO" else m["feed"] as Node3D
        flow.sample_in(t,input)
        return
    flow.truck_in.visible = false
    flow.raw.visible = false
    flow.sample_in_return(t)
    if t<0.72:
        _sample_machine(key,clampf((t-0.29)/0.43,0.0,1.0))
        return
    _sample_machine(key,1.0,false)
    var output: Node3D
    var payload_height: float = 0.90
    var payload_width: float = 1.0
    if key=="LABO":
        var variant: int = int(m["variant"])
        output = (m["products"] as Node3D).get_child(variant) as Node3D
        payload_height = float(PART_HEIGHTS[variant])*EQUIPMENT_SCALE
        payload_width = float(PART_WIDTHS[variant])*EQUIPMENT_SCALE+0.12
    else:
        output = m["output"] as Node3D
        payload_height = 0.55
        payload_width = 1.7
    flow.sample_out(t,output,payload_height,payload_width)

# Linked machinery must retain its relative alignment. The entire room or a
# complete mechanism may move; independent unsafe placement stops animation.
func _mechanism_nodes(key: String) -> Array[Node3D]:
    var m: Dictionary = motion_parts[key]
    var result: Array[Node3D] = []
    var names: Array = []
    match key:
        "LABO": names = ["print_frame","rail","tray","arm_mount0","arm_mount1","arm_mount2","supply","rear_wall"]
        "SMELTER": names = ["hopper","furnace"]
        "RECYCLER": names = ["crusher","feed_conveyor","scrap_mount","shaft_root0","shaft_root1","ramp","sorted_line","sorted_mount"]
        "STORAGE": names = ["storage_anchor"]
    for label in names:
        result.append(m[label] as Node3D)
    return result

func _mechanism_pose(nodes: Array[Node3D], i: int) -> Transform3D:
    if i==0:
        return (nodes[0].get_parent() as Node3D).global_transform.affine_inverse()*nodes[0].global_transform
    return nodes[0].global_transform.affine_inverse()*nodes[i].global_transform

func _capture_mechanism(key: String) -> void:
    var nodes := _mechanism_nodes(key)
    var poses: Array[Transform3D] = []
    for i in range(nodes.size()):
        poses.append(_mechanism_pose(nodes,i))
    mechanism_layouts[key] = poses

func _mechanism_aligned(key: String) -> bool:
    var nodes := _mechanism_nodes(key)
    var poses: Array = mechanism_layouts.get(key,[])
    if poses.size()!=nodes.size():
        return false
    if logistics.has(key) and not (logistics[key].root as Node3D).transform.is_equal_approx(Transform3D.IDENTITY):
        return false
    for i in range(nodes.size()):
        var original: Transform3D = poses[i]
        var current: Transform3D = _mechanism_pose(nodes,i)
        if not current.is_equal_approx(original):
            return false
    return true

func navigation_room(key: String) -> Node3D:
    return rooms[key] as Node3D

func terminal_node(key: String) -> Node3D:
    return terminals[key] as Node3D
