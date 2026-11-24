extends Node3D

const PlacementStore = preload("res://scripts/sera_placement_store.gd")
const RebuiltScenes = preload("res://scripts/labo_rebuilt_scenes.gd")
const CrateModel = preload("res://scripts/sera_crate_model.gd")
const SharedMaterialShading = preload("res://scripts/sera_fullbody_material_preview.gd")
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
## Close-up sets use the actual BASE machine geometry, not unrelated rooms.
## Keep the existing viewport, model placement and angle editor APIs.
var crate: Node3D
var crate_route: Node3D
var crate_route_poses: Dictionary = {}
var crate_head: Node3D
var crate_arm: Node3D
var crate_left_arm: Node3D
var hero_camera: Camera3D
var camera_look: Vector3 = Vector3.ZERO
var camera_previews: Dictionary = {}
var work_state: String = "walk_to_terminal"
var state_time: float = 0.0
var clock: float = 0.0
var current_section: String = "LABO"
var rebuilt_scenes: RefCounted

func _build_crate() -> void:
    # Exact same factory and mesh as the roaming robot in the base.
    crate = CrateModel.create_model()
    crate_route = Node3D.new()
    crate_route.name = "CrateRoute"
    add_child(crate_route)
    crate_route.add_child(crate)
    crate_head = crate.get_node("HeadPivot") as Node3D
    crate_arm = crate.get_node("RightArmPivot") as Node3D
    crate_left_arm = crate.get_node("LeftArmPivot") as Node3D


func _ready() -> void:
    var world := WorldEnvironment.new()
    world.name = "Environment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#101e2b")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b9cbd3")
    environment.ambient_light_energy = 0.72
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.name = "SofterIndustrialKeyLight"
    sun.rotation_degrees = Vector3(-43.0, 28.0, -8.0)
    sun.light_energy = 1.23
    sun.shadow_enabled = false
    add_child(sun)
    # Every facility now has a separately generated open industrial worksite.
    rebuilt_scenes = RebuiltScenes.new()
    rebuilt_scenes.build(self)
    _build_crate()
    # Preserve authored BASE materials and use the common character shading.
    SharedMaterialShading.apply_to_subtree(self)
    var ink := SeraViewEdges.new()
    ink.name = "ViewEdges"
    add_child(ink)
    hero_camera = Camera3D.new()
    hero_camera.name = "HeroCamera"
    add_child(hero_camera)
    hero_camera.current = true
    hero_camera.near = 0.10
    hero_camera.far = 100.0
    hero_camera.keep_aspect = Camera3D.KEEP_HEIGHT
    set_section(current_section)

func set_section(section: String) -> void:
    current_section = section if section in ["LABO", "SMELTER", "RECYCLER", "STORAGE"] else "LABO"
    rebuilt_scenes.select(current_section)
    clock = 0.0
    state_time = 0.0
    work_state = "walk_to_terminal"
    crate_head.rotation = Vector3.ZERO
    crate_arm.rotation = Vector3.ZERO
    crate_left_arm.rotation = Vector3.ZERO
    crate.scale = Vector3.ONE
    match current_section:
        "LABO":
            hero_camera.position = Vector3(4.7,5.0,15.0)
            camera_look = Vector3(0.0,2.25,0.9)
            hero_camera.fov = 55.0
        "SMELTER":
            # Left-front perspective shows the side charge inlet and hot throat.
            hero_camera.position = Vector3(-5.3,4.8,16.0)
            camera_look = Vector3(0,3.10,0.7)
            hero_camera.fov = 54.0
        "RECYCLER":
            # Higher front view reveals both cutter shafts and the feed path.
            hero_camera.position = Vector3(5.0,5.8,14.0)
            camera_look = Vector3(0,1.45,0.65)
            hero_camera.fov = 54.0
        "STORAGE":
            hero_camera.position = Vector3(-4.5,4.2,13.0)
            camera_look = Vector3(0,2.05,0.45)
            hero_camera.fov = 48.0
    hero_camera.look_at(camera_look, Vector3.UP)
    var key: String = camera_section_id()
    crate_route.transform = crate_route_poses.get(key, Transform3D.IDENTITY)
    for target in placement_models():
        var model_saved: Dictionary = PlacementStore.read(_model_placement_key(target))
        if model_saved.get("space") == "parent_local" and model_saved.has("position") and model_saved.has("rotation_degrees"):
            target.position = PlacementStore.vec(model_saved["position"])
            target.rotation_degrees = PlacementStore.vec(model_saved["rotation_degrees"])
    # Start on a clear approach lane; previous room coordinates are never reused.
    crate.position = _work_point(false) + Vector3(0,0,1.15)
    crate.rotation.y = 0.0
    if camera_previews.has(key):
        var pose: Dictionary = camera_previews[key]
        apply_camera_preview(pose["eye"],pose["look"],float(pose["fov"]))
    else:
        var saved: Dictionary = PlacementStore.read("labo/camera/" + key)
        if saved.has("eye") and saved.has("look") and saved.has("fov"):
            apply_camera_preview(PlacementStore.vec(saved["eye"]),
                PlacementStore.vec(saved["look"]),float(saved["fov"]))

func camera_section_id() -> String:
    # New geometry has different bounds. Legacy camera/model coordinates from
    # the independent rooms must not overwrite the new initial composition.
    return current_section + "_BASE_V2"

func apply_camera_preview(eye: Vector3, look: Vector3, fov: float) -> void:
    camera_look = look
    hero_camera.position = eye
    hero_camera.look_at(camera_look, Vector3.UP)
    hero_camera.fov = fov
    camera_previews[camera_section_id()] = {"eye":eye,"look":look,"fov":fov}

func placement_models() -> Array[Node3D]:
    var targets: Array[Node3D] = []
    var machine: Node3D = rebuilt_scenes.machine_for(current_section)
    if is_instance_valid(machine):
        targets.append(machine)
    targets.append(crate_route)
    return targets

func _model_placement_key(target: Node3D) -> String:
    return "labo/model/" + camera_section_id() + "/" + str(get_path_to(target))

func remember_model_placement(target: Node3D) -> void:
    if target == crate_route:
        crate_route_poses[camera_section_id()] = target.transform
    PlacementStore.stage(_model_placement_key(target), {
        "space":"parent_local","position":PlacementStore.array3(target.position),
        "rotation_degrees":PlacementStore.array3(target.rotation_degrees)})

func flush_model_placement() -> void:
    PlacementStore.flush()

func _work_point(inspect: bool) -> Vector3:
    # Machine placement transforms follow the equipment; the independently
    # editable CRATE route is applied afterwards as an intentional offset.
    var world: Vector3 = rebuilt_scenes.work_point(current_section,inspect)
    var local: Vector3 = to_local(world)
    local.y = 0.0
    return local

func _focus_point(inspect: bool) -> Vector3:
    var world: Vector3 = rebuilt_scenes.focus_point(current_section,inspect)
    return crate_route.to_local(world)

func _face_point(goal: Vector3, delta: float) -> void:
    var diff: Vector3 = goal - crate.position
    diff.y = 0.0
    if diff.length_squared() > 0.001:
        crate.rotation.y = lerp_angle(crate.rotation.y,atan2(-diff.x,-diff.z),minf(1.0,delta*4.0))

func _move_to(goal: Vector3, delta: float) -> bool:
    var planar := Vector3(goal.x,crate.position.y,goal.z)
    var diff: Vector3 = planar - crate.position
    if diff.length() <= 0.045:
        crate.position = planar
        return true
    _face_point(planar,delta)
    crate.position = crate.position.move_toward(planar,minf(1.35*delta,0.22))
    crate_head.rotation = crate_head.rotation.lerp(Vector3.ZERO,minf(1.0,delta*4.0))
    crate_arm.rotation = crate_arm.rotation.lerp(Vector3.ZERO,minf(1.0,delta*4.0))
    crate_left_arm.rotation = crate_left_arm.rotation.lerp(Vector3.ZERO,minf(1.0,delta*4.0))
    return false

func _enter(state: String) -> void:
    work_state = state
    state_time = 0.0

func _process(delta: float) -> void:
    clock += delta
    state_time += delta
    rebuilt_scenes.animate(delta,clock,current_section)
    match work_state:
        "walk_to_terminal":
            if _move_to(_work_point(false),delta):
                _enter("operate")
        "operate":
            _face_point(_focus_point(false),delta)
            # Reach toward the reachable console and release before moving.
            var press: float = smoothstep(0.15,0.7,state_time)*(1.0-smoothstep(1.0,1.6,state_time))
            crate_arm.rotation.x = -0.80*press
            crate_head.rotation.x = 0.12*press
            if state_time >= 0.85 and rebuilt_scenes.cycle_complete():
                rebuilt_scenes.start_cycle(current_section)
            if state_time >= 1.7:
                _enter("walk_to_inspection")
        "walk_to_inspection":
            if _move_to(_work_point(true),delta):
                _enter("inspect")
        "inspect":
            _face_point(_focus_point(true),delta)
            crate_head.rotation.x = -0.12 + 0.08*sin(state_time*1.5)
            crate_head.rotation.y = 0.12*sin(state_time*0.9)
            crate_left_arm.rotation.x = -0.17*(0.5+0.5*sin(state_time*2.0))
            if state_time >= 2.5 and rebuilt_scenes.cycle_complete():
                _enter("walk_to_terminal")
