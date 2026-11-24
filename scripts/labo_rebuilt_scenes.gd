extends RefCounted
## Dedicated life-size production sets. BASE icons are design references only.
## All dimensions are authored in metres, never scaled BASE meshes.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const Monitor = preload("res://scripts/sera_labo_monitor_24fps.gd")
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
    for key in KEYS:
        var room := Node3D.new()
        room.name = key + "_IndustrialHall"
        host.add_child(room)
        rooms[key] = room
        targets[key] = []
        screens[key] = []
        motion_parts[key] = {}
        _hall(key)
        match key:
            "LABO": _labo(key)
            "SMELTER": _smelter(key)
            "RECYCLER": _recycler(key)
            "STORAGE": _storage(key)
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

func _box(b, p: Vector3, s: Vector3, c: String = "armor") -> void:
    b.box("Panel", p, s, c)

func _shape(b, kind: String, p: Vector3, s: Vector3, c: String = "armor") -> void:
    b.poly("MachinedShape", kind, p, s, c)

func _pipe(b, a: Vector3, z: Vector3, d: float, c: String = "edge") -> void:
    b.rod("Pipe", a, z, d, c)

func _moving(key: String, label: String, n: Node3D) -> void:
    motion_parts[key][label] = n

func _hall(key: String) -> void:
    var floor := _model(key, "StructuralFloor", Vector3.ZERO)
    var b = _batch(floor)
    for x in range(-5,6):
        for z in range(-4,5):
            _box(b, Vector3(x*3.0,-0.17,z*3.0), Vector3(2.98,0.32,2.98), "slate" if posmod(x+z,4)==0 else "trim")
    for x in [-6.0,6.0]:
        _box(b, Vector3(x,0.005,5.5),Vector3(0.09,0.025,9.0),"caution")
    for x in range(-5,6):
        _box(b,Vector3(x*0.95,0.01,9.5),Vector3(0.65,0.025,0.14),"caution")
    b.flush()
    for child in floor.get_children():
        if child is GeometryInstance3D:
            child.set_meta("sera_outline_occluder_only",true)
    var wall := _model(key,"RearServiceWall",Vector3(0,0,-10.0))
    b = _batch(wall)
    for x in range(-4,5):
        _box(b,Vector3(x*3.5,5.6,0),Vector3(3.43,11.2,0.36),"dark")
        _box(b,Vector3(x*3.5,1.15,0.24),Vector3(3.35,1.9,0.17),"trim")
        _shape(b,"bevel",Vector3(x*3.5,5.5,0.29),Vector3(0.25,11.0,0.40),"slate")
    _box(b,Vector3(0,8.9,0.5),Vector3(31.5,0.5,0.75),"slate")
    b.flush()
    for side in [-1,1]:
        var utilities := _model(key,"UtilityBank_" + ("Left" if side<0 else "Right"),Vector3(side*11.3,0,-5.8))
        b = _batch(utilities)
        _shape(b,"bevel",Vector3(0,2.2,0),Vector3(2.7,4.4,2.5),"slate")
        for i in range(5):
            _box(b,Vector3(0,1.3+i*0.45,1.3),Vector3(2.0,0.16,0.13),"trim")
        _pipe(b,Vector3(0,4.4,0),Vector3(0,7.8,0),0.55)
        _pipe(b,Vector3(0,7.8,0),Vector3(-side*3.5,7.8,0),0.55)
        _box(b,Vector3(0,4.9,1.1),Vector3(0.9,0.13,0.15),"blue_light")
        b.flush()
    var gantry := _model(key,"OverheadServiceTruss",Vector3(0,9.8,-6.8))
    b = _batch(gantry)
    for z in [-0.8,0.8]:
        _box(b,Vector3(0,0,z),Vector3(27,0.32,0.32),"slate")
        _box(b,Vector3(0,1.2,z),Vector3(27,0.28,0.28),"trim")
        for i in range(-6,6):
            _pipe(b,Vector3(i*2.2,0,z),Vector3((i+1)*2.2,1.2,z),0.16,"slate")
    for x in [-9.0,0.0,9.0]:
        _box(b,Vector3(x,-0.18,0),Vector3(3.1,0.25,0.7),"armor")
        _box(b,Vector3(x,-0.33,0),Vector3(2.8,0.06,0.52),"blue_light")
    b.flush()

func _console(key: String, at: Vector3, mode: int) -> void:
    var n := _model(key,"CrateOperatorTerminal",at)
    terminals[key] = n
    var b = _batch(n)
    _shape(b,"bevel",Vector3(0,0.12,0),Vector3(1.15,0.24,0.95),"trim")
    _shape(b,"gusset",Vector3(0,0.62,0),Vector3(0.67,1.1,0.70),"slate")
    _shape(b,"bevel",Vector3(0,1.23,0),Vector3(1.15,0.63,0.32),"armor")
    _box(b,Vector3(0,0.95,0.28),Vector3(1.12,0.12,0.42),"edge")
    _box(b,Vector3(-0.35,0.99,0.40),Vector3(0.14,0.05,0.12),"blue_light")
    b.flush()
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
    b.flush()
    return n

func _cargo(parent: Node3D, label: String, at: Vector3, s: Vector3) -> Node3D:
    var n := _child(parent,label,at)
    var b = _batch(n)
    b.crate(Vector3(0,s.y*0.5,0),s)
    b.flush()
    return n

func _labo(key: String) -> void:
    var frame := _model(key,"AdditiveFabricationCell",Vector3(0,0,-1.8))
    var b = _batch(frame)
    _shape(b,"deck",Vector3(0,0.42,0),Vector3(10.0,0.84,7.0),"slate")
    for x in [-4.1,4.1]:
        for z in [-2.8,2.8]:
            _shape(b,"bevel",Vector3(x,4.0,z),Vector3(0.80,7.8,0.85),"armor")
            _box(b,Vector3(x,4.0,z+0.46),Vector3(0.20,5.5,0.10),"edge")
            _box(b,Vector3(x,6.8,z+0.52),Vector3(0.42,0.22,0.13),"blue_light")
        _box(b,Vector3(x,7.8,0),Vector3(1.15,0.68,6.6),"slate")
        _box(b,Vector3(x,1.1,0),Vector3(1.0,0.55,6.3),"trim")
    for z in [-2.8,2.8]:
        _shape(b,"bevel",Vector3(0,7.8,z),Vector3(9.2,0.9,0.9),"armor")
    for x in [-3.5,3.5]:
        _box(b,Vector3(x,4.0,-3.0),Vector3(1.0,5.2,0.36),"trim")
        for i in range(7):
            _box(b,Vector3(x,2.0+i*0.6,-2.77),Vector3(0.75,0.12,0.09),"edge")
    _box(b,Vector3(0,0.95,0),Vector3(5.2,0.3,4.7),"edge")
    _box(b,Vector3(0,1.16,0),Vector3(4.6,0.17,4.2),"dark")
    b.flush()
    inspection[key] = {"root":frame,"stand":Vector3(-2.4,0,4.5),"focus":Vector3(0,2.1,0)}
    var bridge_root := _model(key,"PrinterTravelBridge",Vector3(0,7.15,-1.8))
    var bridge := _child(bridge_root,"Travel")
    b = _batch(bridge)
    _shape(b,"bevel",Vector3(0,0,0),Vector3(8.1,0.65,0.95),"armor_light")
    _box(b,Vector3(0,-0.41,0),Vector3(7.2,0.14,0.55),"trim")
    b.flush()
    var head := _child(bridge,"PrintHead")
    b = _batch(head)
    _shape(b,"bevel",Vector3(0,-0.72,0),Vector3(1.28,1.05,1.35),"slate")
    _pipe(b,Vector3(0,-1.2,0),Vector3(0,-3.5,0),0.40,"edge")
    _shape(b,"hood",Vector3(0,-3.65,0),Vector3(0.90,0.38,0.90),"armor")
    _box(b,Vector3(0,-3.86,0),Vector3(0.38,0.08,0.38),"lab_cyan")
    b.flush()
    _moving(key,"bridge",bridge)
    _moving(key,"head",head)
    var stock := _model(key,"RawMaterialFeedTower",Vector3(-7.1,0,-3.2))
    b = _batch(stock)
    _shape(b,"bevel",Vector3(0,3.0,0),Vector3(3.5,6.0,3.5),"slate")
    for x in [-1.2,1.2]:
        _pipe(b,Vector3(x,0.3,1.8),Vector3(x,5.4,1.8),0.38)
    _shape(b,"hopper",Vector3(0,6.0,0),Vector3(3.7,2.0,3.6),"armor")
    _pipe(b,Vector3(1.0,5.0,0),Vector3(3.2,5.0,0),0.65,"gold")
    b.flush()
    _conveyor(key,"FinishedPartConveyor",Vector3(6.6,0,1.5),2.6,6.0)
    var product_root := _model(key,"FabricatedWorkpieces",Vector3(0,1.26,-1.8))
    for i in range(4):
        var piece := _child(product_root,"Product"+str(i))
        b = _batch(piece)
        match i:
            0:
                _shape(b,"bevel",Vector3(0,0.85,0),Vector3(2.6,1.7,1.9),"armor_light")
                _box(b,Vector3(0,0.95,0.99),Vector3(1.3,0.4,0.12),"blue_light")
            1:
                _shape(b,"octagonal_slew",Vector3(0,0.85,0),Vector3(1.75,1.7,1.75),"armor")
                _pipe(b,Vector3(0,1.5,0),Vector3(0,2.25,0),0.75)
            2:
                for x in [-0.65,0.65]:
                    _shape(b,"bevel",Vector3(x,0.6,0),Vector3(0.9,1.2,2.2),"armor")
                _box(b,Vector3(0,0.4,0),Vector3(1.4,0.45,1.5),"slate")
            3:
                _shape(b,"gusset",Vector3(0,1.0,0),Vector3(2.0,2.0,1.65),"armor_light")
                _box(b,Vector3(0,0.25,0),Vector3(2.4,0.5,2.0),"slate")
        b.flush()
        piece.visible = false
    _moving(key,"products",product_root)
    motion_parts[key]["variant"] = -1
    _console(key,Vector3(3.1,0,4.5),0)

func _smelter(key: String) -> void:
    var furnace := _model(key,"RefractorySmeltingFurnace",Vector3(0,0,-2.0))
    var b = _batch(furnace)
    _shape(b,"deck",Vector3(0,0.4,0),Vector3(10.0,0.8,7.0),"slate")
    _shape(b,"octagonal_slew",Vector3(0,4.0,-0.7),Vector3(7.4,6.4,6.0),"armor")
    _shape(b,"bevel",Vector3(0,7.0,-0.7),Vector3(7.8,1.1,6.2),"slate")
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
    b.flush()
    inspection[key] = {"root":furnace,"stand":Vector3(2.4,0,5.3),"focus":Vector3(0,3.0,4.1)}
    var hot := _child(furnace,"RecessedFire",Vector3(0,3.0,3.80))
    var flame := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(4.55,3.95)
    flame.mesh = quad
    var shader := Shader.new()
    shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
    vec2 p = UV;
    float h = 1.0-p.y;
    float wave = sin(p.x*22.0+TIME*3.2+h*9.0)*0.11 + sin(p.x*43.0-TIME*4.1+h*15.0)*0.07;
    float tongues = smoothstep(0.05,0.30,0.67+wave-h);
    float edge = smoothstep(0.0,0.12,p.x)*smoothstep(0.0,0.12,1.0-p.x);
    float flicker = 0.86+0.14*sin(TIME*9.0+p.x*17.0+h*13.0);
    vec3 heat = mix(vec3(0.18,0.55,1.0),vec3(1.0,0.31,0.035),smoothstep(0.08,0.32,h));
    heat = mix(heat,vec3(1.0,0.78,0.25),smoothstep(0.45,0.9,tongues)*0.55);
    ALBEDO = mix(vec3(0.08,0.045,0.028),heat,tongues*edge*flicker);
}"""
    var mat := ShaderMaterial.new()
    mat.shader = shader
    flame.material_override = mat
    flame.set_meta("sera_preserve_authored_material",true)
    flame.set_meta("sera_outline_occluder_only",true)
    hot.add_child(flame)
    for i in range(2):
        var stack := _model(key,"ExhaustStack"+str(i),Vector3(-2.1+i*4.2,0,-4.7))
        b = _batch(stack)
        _pipe(b,Vector3(0,6.8,0),Vector3(0,10.3,0),1.32,"slate")
        for y in [7.1,8.5,9.9]:
            _shape(b,"octagonal_slew",Vector3(0,y,0),Vector3(1.65,0.24,1.65),"edge")
        _shape(b,"hood",Vector3(0,10.45,0),Vector3(1.9,0.42,1.9),"trim")
        b.flush()
    var feed := _model(key,"SideChargeHopper",Vector3(-6.6,0,-0.6))
    b = _batch(feed)
    _shape(b,"hopper",Vector3(0,4.5,0),Vector3(3.5,2.7,3.7),"armor")
    for x in [-1.2,1.2]:
        for z in [-1.1,1.1]:
            _shape(b,"gusset",Vector3(x,1.8,z),Vector3(0.45,3.6,0.48),"slate")
    _pipe(b,Vector3(0,3.5,0),Vector3(3.4,3.5,0),1.20,"armor")
    b.flush()
    var conveyor := _conveyor(key,"ChargeConveyor",Vector3(-6.6,0,3.5),2.4,5.0)
    var raw := _cargo(conveyor,"FeedCharge",Vector3(0,1.12,1.7),Vector3(1.3,0.6,1.0))
    _moving(key,"feed",raw)
    var cast := _conveyor(key,"CastingCoolingLine",Vector3(5.9,0,2.0),2.5,6.2)
    var ingot := _child(cast,"CooledIngot",Vector3(0,1.15,-2.1))
    b = _batch(ingot)
    _shape(b,"bevel",Vector3(0,0.30,0),Vector3(1.9,0.60,1.2),"amber")
    _box(b,Vector3(0,0.64,0),Vector3(1.55,0.07,0.9),"amber_light")
    b.flush()
    _moving(key,"output",ingot)
    _console(key,Vector3(-3.3,0,5.7),2)

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
    _shape(b,"hood",Vector3(0,5.4,-1.8),Vector3(6.3,2.1,3.1),"slate")
    for x in [-3.0,3.0]:
        _box(b,Vector3(x,4.4,2.2),Vector3(0.24,0.18,2.0),"caution")
    b.flush()
    inspection[key] = {"root":base,"stand":Vector3(-2.0,0,4.7),"focus":Vector3(0,3.4,0)}
    for i in range(2):
        var shaft_root := _model(key,"CutterShaft"+str(i),Vector3(0,3.6,-2.6+i*1.75))
        var shaft := _child(shaft_root,"Rotor")
        b = _batch(shaft)
        _pipe(b,Vector3(-3.1,0,0),Vector3(3.1,0,0),0.80,"edge")
        for x in range(-4,5):
            for j in range(6):
                var a: float = TAU*j/6.0+x*0.24
                b.box_tilt("CutterTooth",Vector3(x*0.58,cos(a)*0.66,sin(a)*0.66),Vector3(0.34,0.75,0.37),"armor",Vector3(a,0,0))
        b.flush()
        _moving(key,"shaft"+str(i),shaft)
    var feed := _conveyor(key,"ScrapFeedLine",Vector3(0,0,-6.3),4.5,5.6)
    var raw := _cargo(feed,"ScrapBatch",Vector3(0,1.1,-1.8),Vector3(2.1,0.7,1.4))
    _moving(key,"feed",raw)
    var output := _conveyor(key,"SortedMaterialLine",Vector3(0,0,4.6),3.8,5.0)
    var bin := _cargo(output,"SortedBatch",Vector3(0,1.1,-1.7),Vector3(2.0,0.65,1.3))
    _moving(key,"output",bin)
    _console(key,Vector3(4.7,0,4.0),3)

func _storage(key: String) -> void:
    for side in [-1,1]:
        var rack := _model(key,"AutomatedRack"+("Left" if side<0 else "Right"),Vector3(side*4.8,0,-3.2))
        var b = _batch(rack)
        for x in [-2.4,2.4]:
            for z in [-2.0,2.0]:
                _shape(b,"bevel",Vector3(x,4.7,z),Vector3(0.42,9.4,0.45),"slate")
        for level in range(4):
            var y: float = 0.45+level*2.25
            _box(b,Vector3(0,y,0),Vector3(4.9,0.28,4.0),"gold")
            for z in [-2.04,2.04]:
                _box(b,Vector3(0,y+0.15,z),Vector3(4.9,0.18,0.20),"caution")
        _box(b,Vector3(0,9.1,0),Vector3(5.2,0.38,4.3),"armor")
        for z in [-2.0,2.0]:
            _pipe(b,Vector3(-2.4,0.5,z),Vector3(2.4,9.0,z),0.16,"trim")
        b.flush()
        for level in range(4):
            for col in range(2):
                var cargo := _model(key,"Stock_"+str(side+1)+"_"+str(level)+"_"+str(col),rack.position+Vector3(-1.18+col*2.36,0.60+level*2.25,0.15))
                _cargo(cargo,"Container",Vector3.ZERO,Vector3(2.0,1.45,2.8))
    var rail := _model(key,"HighBayLiftMast",Vector3(0,0,-2.8))
    var b = _batch(rail)
    for x in [-1.35,1.35]:
        _shape(b,"bevel",Vector3(x,4.8,0),Vector3(0.45,9.6,0.72),"armor_light")
        _box(b,Vector3(x,4.7,0.42),Vector3(0.10,9.0,0.12),"edge")
        _pipe(b,Vector3(x,0.3,-0.5),Vector3(x,9.1,-0.5),0.16,"gold")
    _box(b,Vector3(0,9.55,0),Vector3(3.25,0.60,1.1),"slate")
    _box(b,Vector3(0,0.18,0),Vector3(3.25,0.36,2.2),"trim")
    b.flush()
    var lift_root := _model(key,"CargoLiftPlatform",Vector3(0,0,-2.8))
    var platform := _child(lift_root,"LiftCarriage",Vector3(0,0.6,0.6))
    b = _batch(platform)
    _shape(b,"deck",Vector3(0,0,0),Vector3(2.65,0.35,2.3),"gold")
    _box(b,Vector3(0,0.75,-0.65),Vector3(2.55,1.35,0.23),"slate")
    for x in [-1.1,1.1]:
        _box(b,Vector3(x,0.23,0.9),Vector3(0.2,0.24,2.5),"edge")
    b.flush()
    var load := _cargo(platform,"LiftCargo",Vector3(0,0.2,0.12),Vector3(1.8,1.25,1.6))
    _moving(key,"lift",platform)
    _moving(key,"lift_cargo",load)
    var dispatch := _conveyor(key,"DispatchLane",Vector3(0,0,3.7),2.8,5.0)
    var out := _cargo(dispatch,"DispatchContainer",Vector3(0,1.1,-1.8),Vector3(1.8,1.25,1.6))
    _moving(key,"output",out)
    inspection[key] = {"root":dispatch,"stand":Vector3(-2.3,0,0.1),"focus":Vector3(0,1.6,0.1)}
    _console(key,Vector3(2.9,0,5.1),4)

func placement_models(key: String) -> Array[Node3D]:
    var result: Array[Node3D] = []
    for model in targets.get(key,[]):
        result.append(model as Node3D)
    return result

func select(key: String) -> void:
    active_key = key
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

func animate(delta: float, _time: float, key: String) -> void:
    if key != active_key:
        return
    for panel in screens.get(key,[]):
        panel.call("_process",delta)
    if cycle_running:
        elapsed = minf(10.0,elapsed+delta)
        _sample(key,elapsed/10.0)
        cycle_running = elapsed < 10.0

func _sample(key: String, t: float) -> void:
    var m: Dictionary = motion_parts[key]
    match key:
        "LABO":
            var bridge: Node3D = m["bridge"]
            var head: Node3D = m["head"]
            var running: float = smoothstep(0.02,0.15,t)*(1.0-smoothstep(0.82,0.99,t))
            bridge.position.z = sin(t*TAU*3.0)*1.35*running
            head.position.x = sin(t*TAU*5.0)*1.5*running
            head.position.y = -1.25*running+0.55*t*running
            var product: Node3D = m["products"]
            for i in range(product.get_child_count()):
                var p := product.get_child(i) as Node3D
                p.visible = i==int(m["variant"]) and t>0.18
                p.scale.y = maxf(0.03,smoothstep(0.18,0.80,t))
        "SMELTER","RECYCLER":
            var feed: Node3D = m["feed"]
            var output: Node3D = m["output"]
            feed.visible = t<0.35
            feed.position.z = (1.7 if key=="SMELTER" else -1.8)+(-3.4 if key=="SMELTER" else 3.4)*smoothstep(0.0,0.35,t)
            output.visible = t>0.55
            output.position.z = (-2.1 if key=="SMELTER" else -1.7)+3.4*smoothstep(0.55,1.0,t)
            if key=="RECYCLER":
                (m["shaft0"] as Node3D).rotation.x = t*TAU*4.0
                (m["shaft1"] as Node3D).rotation.x = -t*TAU*4.0
        "STORAGE":
            var lift: Node3D = m["lift"]
            lift.position.y = 0.6+6.75*smoothstep(0.0,0.32,t)*(1.0-smoothstep(0.50,0.83,t))
            (m["lift_cargo"] as Node3D).visible = t<0.78
            var output: Node3D = m["output"]
            output.visible = t>0.78
            output.position.z = -1.8+3.6*smoothstep(0.78,1.0,t)
