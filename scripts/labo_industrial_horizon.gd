extends RefCounted
## Shared, noninteractive industrial skyline. No lights, physics or shadow maps.
## Authored in metres, outside the worksite and its carrier routes.
const Haze = preload("res://shaders/sera_industrial_horizon.gdshader")
const RAIL_Z := -99.0
const RAIL_Y := 16.5
var root: Node3D
var train: Node3D
var material: ShaderMaterial
var shapes: Dictionary = {}
var groups: Dictionary = {}
var batches: Dictionary = {}
var districts: Array[Dictionary] = []
var district: int = -1
var visibility_signature: String = ""
var train_time: float = 0.0

func build(parent: Node3D) -> void:
    root = Node3D.new()
    root.name = "MachineCivilizationHorizon"
    parent.add_child(root)
    _no_ink(root)
    material = ShaderMaterial.new()
    material.shader = Haze
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    shapes["box"] = box
    var tube := CylinderMesh.new()
    tube.top_radius = 0.5
    tube.bottom_radius = 0.5
    tube.height = 1.0
    tube.radial_segments = 8
    tube.rings = 0
    shapes["tube"] = tube
    var taper := CylinderMesh.new()
    taper.top_radius = 0.36
    taper.bottom_radius = 0.5
    taper.height = 1.0
    taper.radial_segments = 8
    taper.rings = 0
    shapes["taper"] = taper
    var flare := CylinderMesh.new()
    flare.top_radius = 0.5
    flare.bottom_radius = 0.36
    flare.height = 1.0
    flare.radial_segments = 8
    flare.rings = 0
    shapes["flare"] = flare
    var rng := RandomNumberGenerator.new()
    rng.seed = 761024
    # Far tier first: irregular silhouette of a vast machine civilization.
    # Keep all roots on the existing steel deck and within camera far=220.
    for i in range(18):
        var angle: float = TAU*float(i)/18.0
        var r: float = 126.0+rng.randf_range(-5.0,9.0)
        var p := Vector3(sin(angle)*r,0,-cos(angle)*r)
        _district(p,15.0)
        _far_block(p,rng,i)
    # Mid-distance industrial districts. Leave the +/-Z carrier axes open
    # in the near field; no background mesh is part of the navigation room.
    var sites: Array[Vector3] = [
        Vector3(-58,0,-47),Vector3(60,0,-48),
        Vector3(-39,0,-78),Vector3(41,0,-76),
        Vector3(-82,0,6),Vector3(83,0,10),
        Vector3(-59,0,55),Vector3(58,0,57),
        Vector3(0,0,-83),Vector3(-43,0,89),Vector3(44,0,89)]
    for i in range(sites.size()):
        var p: Vector3 = sites[i]
        _district(p,14.0)
        match i%5:
            0: _cooling_plant(p,rng)
            1: _refinery(p,rng)
            2: _energy_spire(p)
            3: _fabrication_hall(p,rng)
            4: _salvage_yard(p,rng)
    # The highline is an independent through-route, not the local carrier lane.
    _district(Vector3(0,0,RAIL_Z),0.0)
    _highline()
    _flush_static([])
    visibility_signature = "[]"
    _build_train()

func _no_ink(n: Node3D) -> void:
    n.set_meta("FX_NO_OUTLINE",true)
    n.set_meta("sera_no_view_edges",true)
    n.set_meta("sera_preserve_authored_material",true)

func _district(p: Vector3,radius: float) -> void:
    district = districts.size()
    districts.append({"center":p,"radius":radius})

func _add(kind: String,p: Vector3,size: Vector3,tint: Color,yaw: float = 0.0) -> void:
    var basis := Basis(Vector3.UP,yaw).scaled_local(size)
    _piece(kind,Transform3D(basis,p),tint)

func _piece(kind: String,pose: Transform3D,tint: Color) -> void:
    if not groups.has(kind):
        groups[kind] = []
    (groups[kind] as Array).append({"pose":pose,"tint":tint,"district":district})

func _box(p: Vector3,size: Vector3,tint: Color,yaw: float = 0.0) -> void:
    _add("box",p,size,tint,yaw)

func _rod(a: Vector3,b: Vector3,width: float,tint: Color,kind: String = "tube") -> void:
    var v: Vector3 = b-a
    if v.length_squared()<0.001:
        return
    var y: Vector3 = v.normalized()
    var x: Vector3 = y.cross(Vector3.FORWARD)
    if x.length_squared()<0.001:
        x = y.cross(Vector3.RIGHT)
    x = x.normalized()
    var z: Vector3 = x.cross(y)
    _piece(kind,Transform3D(Basis(x,y,z).scaled_local(Vector3(width,v.length(),width)),(a+b)*0.5),tint)

func _far_block(p: Vector3,rng: RandomNumberGenerator,i: int) -> void:
    var steel := Color("#526674")
    var face := Color("#5e7380")
    var recess := Color("#475a68")
    var h: float = rng.randf_range(24.0,48.0)
    var w: float = rng.randf_range(12.0,20.0)
    _box(p+Vector3(0,h*0.5,0),Vector3(w,h,12),steel)
    _box(p+Vector3(0,h*0.43,6.2),Vector3(w*0.76,h*0.73,0.8),recess)
    _box(p+Vector3(0,h+2.0,0),Vector3(w*0.72,4.0,10),face)
    for side in [-1.0,1.0]:
        _box(p+Vector3(float(side)*w*0.46,h*0.50,0),Vector3(1.7,h,13.0),face)
    for j in range(3):
        _box(p+Vector3(0,h*(0.22+0.23*float(j)),6.75),Vector3(w*0.69,0.7,0.30),face)
    if i%3==0:
        _add("taper",p+Vector3(0,h+9.0,0),Vector3(5.0,15.0,5.0),steel)
        _box(p+Vector3(0,h+17.5,0),Vector3(0.8,7.0,0.8),face)
    elif i%3==1:
        _box(p+Vector3(w*0.54,h*0.32,-1.0),Vector3(6.0,h*0.64,8.0),recess)
        _add("tube",p+Vector3(-w*0.20,h+7.0,0),Vector3(2.5,12.0,2.5),face)
    else:
        _box(p+Vector3(0,h+5.0,0),Vector3(w*0.82,2.0,13.0),recess)
        for side in [-1.0,1.0]:
            _box(p+Vector3(float(side)*w*0.32,h+7.0,0),Vector3(2.0,5.5,7.0),steel)

func _cooling_plant(p: Vector3,rng: RandomNumberGenerator) -> void:
    var body := Color("#455a65")
    var rim := Color("#697d85")
    var dark := Color("#394c59")
    _box(p+Vector3(0,1.0,0),Vector3(24,2,17),dark)
    for i in range(2):
        var q: Vector3 = p+Vector3(-5.8+float(i)*11.6,0,0)
        var h: float = rng.randf_range(19.0,26.0)
        _add("taper",q+Vector3(0,h*0.24+2,0),Vector3(10,h*0.48,10),body)
        _add("tube",q+Vector3(0,h*0.55+2,0),Vector3(7.2,h*0.20,7.2),dark)
        _add("flare",q+Vector3(0,h*0.81+2,0),Vector3(10.0,h*0.30,10.0),body)
        _add("tube",q+Vector3(0,h*0.96+2,0),Vector3(10.3,1.3,10.3),rim)
        _add("tube",q+Vector3(0,h*0.96+2.7,0),Vector3(8.5,0.25,8.5),dark)
        for j in range(4):
            var a: float = TAU*float(j)/4.0
            var radial := Vector3(cos(a),0,sin(a))
            _rod(q+radial*4.6+Vector3.UP*2.0,q+radial*3.6+Vector3.UP*(h*0.47+2),0.7,rim,"box")
    _rod(p+Vector3(-12,4,6),p+Vector3(12,4,6),1.6,rim)
    for x in [-11.0,11.0]:
        _rod(p+Vector3(x,0.1,6),p+Vector3(x,4,6),0.9,dark,"box")

func _refinery(p: Vector3,rng: RandomNumberGenerator) -> void:
    var armor := Color("#465965")
    var edge := Color("#6b7b80")
    var dark := Color("#344650")
    var amber := Color("#a18b69")
    _box(p+Vector3(0,4,0),Vector3(22,8,14),dark)
    for i in range(3):
        var q: Vector3 = p+Vector3(-7.5+7.5*float(i),0,-1)
        var h: float = rng.randf_range(12.0,19.0)
        _add("tube",q+Vector3.UP*(8+h*0.5),Vector3(5.2,h,5.2),armor)
        _add("taper",q+Vector3.UP*(8+h+1.5),Vector3(5.3,3,5.3),edge)
        for y in [10.0,14.0,18.0]:
            if y<8+h:
                _add("tube",q+Vector3.UP*y,Vector3(5.5,0.5,5.5),edge)
        _rod(q+Vector3(0,10,2.5),q+Vector3(0,10,6),1.2,edge)
        _rod(q+Vector3(0,10,6),q+Vector3(0,4,6),1.2,edge)
        _box(q+Vector3(0,4,6.9),Vector3(3.6,3.5,0.4),armor)
        _box(q+Vector3(0,5.8,7.15),Vector3(1.1,0.25,0.1),amber)
    _rod(p+Vector3(-10,11,6),p+Vector3(10,11,6),1.5,edge)
    _rod(p+Vector3(-10,13,6),p+Vector3(10,13,6),1.0,armor)
    for x in [-10.0,0.0,10.0]:
        _rod(p+Vector3(x,8,6),p+Vector3(x,13,6),0.9,dark,"box")

func _energy_spire(p: Vector3) -> void:
    var dark := Color("#3b4e5b")
    var armor := Color("#596d79")
    var cyan := Color("#77b7c6")
    _box(p+Vector3(0,2,0),Vector3(18,4,16),dark)
    _add("taper",p+Vector3(0,17,0),Vector3(9,30,9),armor)
    _add("tube",p+Vector3(0,29,0),Vector3(12,2.0,12),dark)
    _add("tube",p+Vector3(0,30.2,0),Vector3(11.4,0.45,11.4),cyan)
    _add("taper",p+Vector3(0,35,0),Vector3(5,8,5),armor)
    for i in range(4):
        var a: float = TAU*float(i)/4.0+PI*0.25
        var r := Vector3(cos(a),0,sin(a))
        _rod(p+r*7.0+Vector3.UP*4,p+r*3.2+Vector3.UP*23,1.0,dark,"box")
        _rod(p+r*3.5+Vector3.UP*13,p+r*2.5+Vector3.UP*28,0.35,cyan,"box")
    _rod(p+Vector3(0,39,0),p+Vector3(0,43,0),0.55,armor)

func _fabrication_hall(p: Vector3,rng: RandomNumberGenerator) -> void:
    var wall := Color("#4a5e6a")
    var frame := Color("#697b85")
    var dark := Color("#344653")
    var h: float = rng.randf_range(16.0,22.0)
    _box(p+Vector3(0,h*0.5,0),Vector3(26,h,14),wall)
    _box(p+Vector3(0,h+1.1,0),Vector3(28,2.2,16),frame)
    for i in range(4):
        var x: float = -10.0+float(i)*6.7
        _box(p+Vector3(x,h*0.49,7.1),Vector3(4.8,h*0.80,0.45),dark)
        _box(p+Vector3(x,h*0.49,7.5),Vector3(0.5,h*0.85,0.6),frame)
        for j in range(3):
            _box(p+Vector3(x,3+float(j)*4.1,7.4),Vector3(4.2,0.32,0.4),frame)
    for side in [-1.0,1.0]:
        _rod(p+Vector3(float(side)*13,0,7),p+Vector3(float(side)*13,h,7),1.4,frame,"box")
    for i in range(3):
        _box(p+Vector3(-7.0+float(i)*7,h+3.2,-2),Vector3(4.2,2.2,6.5),dark)

func _salvage_yard(p: Vector3,rng: RandomNumberGenerator) -> void:
    var steel := Color("#52616a")
    var dark := Color("#3c4c55")
    var rust := Color("#78675d")
    _box(p+Vector3(0,0.5,0),Vector3(21,1,17),dark)
    for i in range(12):
        var at: Vector3 = p+Vector3(rng.randf_range(-8,8),rng.randf_range(1.5,3.3),rng.randf_range(-6,6))
        var rot := Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis(Vector3.RIGHT,rng.randf_range(-0.5,0.5))
        var size := Vector3(rng.randf_range(1.7,4.5),rng.randf_range(1.0,3.0),rng.randf_range(2.0,5.5))
        _piece("tube" if i%3==0 else "box",Transform3D(rot.scaled_local(size),at),rust if i%4==0 else steel)
    # Abandoned gantry frame and long wrecked machine shell.
    for x in [-9.0,9.0]:
        _box(p+Vector3(x,5.5,-6),Vector3(1.2,11,1.2),steel)
    _rod(p+Vector3(-9,11,-6),p+Vector3(9,11,-6),1.3,steel,"box")
    _rod(p+Vector3(-9,7,-6),p+Vector3(-5,11,-6),0.6,rust,"box")
    _rod(p+Vector3(9,7,-6),p+Vector3(5,11,-6),0.6,rust,"box")

func _highline() -> void:
    var steel := Color("#596b77")
    var dark := Color("#3d515e")
    var edge := Color("#73838b")
    _box(Vector3(0,RAIL_Y-0.8,RAIL_Z),Vector3(180,1.6,4.8),dark)
    for side in [-1.0,1.0]:
        _box(Vector3(0,RAIL_Y+0.10,RAIL_Z+float(side)*1.35),Vector3(180,0.20,0.28),edge)
        _box(Vector3(0,RAIL_Y-0.28,RAIL_Z+float(side)*2.25),Vector3(180,0.42,0.22),steel)
    for i in range(10):
        var x: float = -81.0+18.0*float(i)
        _box(Vector3(x,0.65,RAIL_Z),Vector3(4.5,1.3,5.2),dark)
        _box(Vector3(x,(RAIL_Y-1.6)*0.5,RAIL_Z),Vector3(1.5,RAIL_Y-1.6,2.4),steel)
        _box(Vector3(x,RAIL_Y-2.0,RAIL_Z),Vector3(4.0,0.8,4.8),steel)
        for sign_value in [-1.0,1.0]:
            _rod(Vector3(x,RAIL_Y-5.5,RAIL_Z),Vector3(x+float(sign_value)*3.8,RAIL_Y-1.6,RAIL_Z),0.75,steel,"box")
    # Two large fluid trunk pipes, with support on the same piers.
    for side in [-1.0,1.0]:
        _rod(Vector3(-90,RAIL_Y-3.3,RAIL_Z+float(side)*1.65),Vector3(90,RAIL_Y-3.3,RAIL_Z+float(side)*1.65),0.85,edge)
    for x in [-91.0,91.0]:
        _box(Vector3(x,10,RAIL_Z),Vector3(15,20,12),steel)
        _box(Vector3(x,21,RAIL_Z),Vector3(16,2,13),dark)

func _flush_static(blocked: Array[int]) -> void:
    for kind in groups:
        var selected: Array = []
        for piece in groups[kind]:
            if not blocked.has(int(piece["district"])):
                selected.append(piece)
        var multi: MultiMesh
        if batches.has(kind):
            multi = (batches[kind] as MultiMeshInstance3D).multimesh
            multi.instance_count = 0
        else:
            multi = MultiMesh.new()
            multi.transform_format = MultiMesh.TRANSFORM_3D
            multi.use_colors = true
            multi.mesh = shapes[kind]
            var draw := MultiMeshInstance3D.new()
            draw.name = "Skyline_"+str(kind)
            draw.multimesh = multi
            draw.material_override = material
            draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            _no_ink(draw)
            root.add_child(draw)
            batches[kind] = draw
        multi.instance_count = selected.size()
        for i in range(selected.size()):
            multi.set_instance_transform(i,selected[i]["pose"])
            multi.set_instance_color(i,selected[i]["tint"])

func avoid_base_proxies(proxies: Dictionary) -> void:
    # The real BASE facility proxies have priority over fictional skyline
    # masses. Rebatch only if a section/placement changes the blocked set.
    var blocked: Array[int] = []
    for i in range(districts.size()):
        var entry: Dictionary = districts[i]
        if float(entry["radius"])<=0.0:
            continue
        var p: Vector3 = entry["center"]
        for proxy in proxies.values():
            var node := proxy as Node3D
            if not is_instance_valid(node) or not node.visible:
                continue
            var d: Vector2 = Vector2(p.x-node.position.x,p.z-node.position.z)
            if d.length()<float(entry["radius"])+10.0:
                blocked.append(i)
                break
    var signature: String = str(blocked)
    if signature==visibility_signature:
        return
    visibility_signature = signature
    _flush_static(blocked)

func _build_train() -> void:
    train = Node3D.new()
    train.name = "DistantAutonomousFreightTrain"
    root.add_child(train)
    _no_ink(train)
    var parts: Array[Dictionary] = []
    for i in range(3):
        var x: float = -6.0+6.0*float(i)
        parts.append({"p":Vector3(x,0.55,0),"s":Vector3(5.65,1.1,2.6),"c":Color("#485d69")})
        parts.append({"p":Vector3(x,1.40,0),"s":Vector3(5.2,1.0,2.4),"c":Color("#73838b")})
        parts.append({"p":Vector3(x,1.42,1.23),"s":Vector3(4.2,0.24,0.08),"c":Color("#9f9a76")})
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = shapes["box"]
    multi.instance_count = parts.size()
    for i in range(parts.size()):
        multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled_local(parts[i]["s"]),parts[i]["p"]))
        multi.set_instance_color(i,parts[i]["c"])
    var draw := MultiMeshInstance3D.new()
    draw.multimesh = multi
    draw.material_override = material
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _no_ink(draw)
    train.add_child(draw)
    train.position = Vector3(-86,RAIL_Y+0.22,RAIL_Z)

func animate(delta: float) -> void:
    if not is_instance_valid(train):
        return
    # One moving node, no new geometry. Reversals ease into terminal buildings.
    train_time = fposmod(train_time+minf(delta,0.1),96.0)
    var phase: float = train_time/48.0
    var u: float = phase if phase<=1.0 else 2.0-phase
    train.position.x = lerpf(-86.0,86.0,smoothstep(0.0,1.0,u))
