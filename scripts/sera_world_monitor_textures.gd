extends RefCounted
## Numbered, exact-aspect SVGs projected onto existing BASE / NEXUS 3D screens.
const Modules = preload("res://assets/base_command_modules.gd")
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const MONITOR_SHADER = preload("res://assets/monitors/world_monitor.gdshader")
const Frames = preload("res://assets/monitors/numbered_frames.gd")
const FRAME_RATES = {"N01": 5.0, "N02": 3.0, "N03": 4.0, "N04": 6.0, "N05": 3.0, "N06": 4.0,
    "B01": 1.5, "B02": 1.33, "B03": 1.0, "B04": 3.0, "B05": 0.85}
const BLOCKBENCH = [
    {"id":"N01","scene":"NEXUS","module":"system_console","part":"SYSTEM blue operational screen","offset":0.55},
    {"id":"N02","scene":"NEXUS","module":"system_console","part":"SYSTEM auxiliary angled slim right readout","offset":0.12},
    {"id":"N03","scene":"NEXUS","module":"training_console","part":"TRAINING deep cyan screen","offset":0.18},
    {"id":"N04","scene":"NEXUS","module":"training_console","part":"TRAINING right lateral data display","offset":0.38},
    {"id":"N05","scene":"NEXUS","module":"data_bank","part":"Archive static phosphor blue glass -1","offset":0.62},
    {"id":"N06","scene":"NEXUS","module":"data_bank","part":"Archive static phosphor blue glass 1","offset":0.62},
    {"id":"B01","scene":"BASE","module":"data_bank","part":"Archive static phosphor blue glass -1","offset":0.62},
    {"id":"B02","scene":"BASE","module":"data_bank","part":"Archive static phosphor blue glass 1","offset":0.62}
]
const FACILITIES = [
    {"id":"B03","key":"LABO","at":Vector3(1.46,1.37,1.63),"size":Vector2(0.44,0.40),"face":0.14},
    {"id":"B04","key":"GENERATOR","at":Vector3(1.22,1.88,0.41),"size":Vector2(0.52,0.55),"face":0.19},
    {"id":"B05","key":"BUILD_TERMINAL","at":Vector3(0,1.94,0.46),"size":Vector2(1.49,0.99),"face":0.12}
]
static func _v(a: Array) -> Vector3:
    return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func _surface(host: Node3D, id: String, pose: Transform3D, size: Vector2) -> void:
    # Decode each compact indexed PNG only when its scene builds. Embedding
    # the bytes keeps Android source sync independent of editor import state.
    var image := Image.new()
    if image.load_png_from_buffer(Marshalls.base64_to_raw(Frames.PNG[id])) != OK:
        push_error("Invalid monitor atlas: " + id)
        return
    image.generate_mipmaps()
    var texture := ImageTexture.create_from_image(image)
    var mesh := QuadMesh.new()
    mesh.size = size
    var display := MeshInstance3D.new()
    display.name = "MON_" + id
    display.mesh = mesh
    display.transform = pose
    display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    display.set_meta("FX_NO_OUTLINE", true)
    display.set_meta("sera_outline_occluder_only", true)
    display.set_meta("sera_preserve_authored_material", true)
    display.set_meta("monitor_id", id)
    display.set_meta("monitor_resolution", texture.get_size() / Vector2(4, 2))
    var mat := ShaderMaterial.new()
    mat.shader = MONITOR_SHADER
    mat.set_shader_parameter("atlas", texture)
    mat.set_shader_parameter("fps", FRAME_RATES[id])
    display.material_override = mat
    host.add_child(display)

static func attach_blockbench(host: Node3D, module: String, at: Vector3,
        yaw: float, factor: float, height_factor: float, scene: String) -> void:
    if not Modules.MODULES.has(module):
        return
    var facing := Basis(Vector3.UP,yaw)
    for config in BLOCKBENCH:
        if str(config["scene"]) != scene or str(config["module"]) != module:
            continue
        for part in Modules.MODULES[module]:
            if str(part[0]) != str(config["part"]):
                continue
            var stretch := Vector3(1,height_factor,1)*Modules.UNIT*factor
            var low := _v(part[1])*stretch
            var high := _v(part[2])*stretch
            var tilted := Basis.from_euler(_v(part[4])*(PI/180.0))
            var center := (low+high)*0.5
            var forward: float = (high.z-low.z)*0.5 + float(config["offset"])*Modules.UNIT*factor
            var location: Vector3 = at + facing*(center + tilted*Vector3(0,0,forward))
            _surface(host,str(config["id"]),Transform3D(facing*tilted,location),
                Vector2(high.x-low.x,high.y-low.y))
            break

static func attach_facility(host: Node3D, key: String) -> void:
    if Architecture.ACTIVE_BASE_MODEL != "FRESH_20261122":
        return
    for config in FACILITIES:
        if str(config["key"]) != key:
            continue
        var scale: float = 1.45 if key == "LABO" else 1.55
        var facing := Basis(Vector3.UP,Architecture.facility_yaw_radians(key))
        var at: Vector3 = config["at"]
        at.z += float(config["face"])
        var dims: Vector2 = config["size"]
        _surface(host,str(config["id"]),Transform3D(facing,facing*(at*scale)),dims*scale)
