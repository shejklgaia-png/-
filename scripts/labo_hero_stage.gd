extends Node3D

const PlacementStore = preload("res://scripts/sera_placement_store.gd")
const RebuiltScenes = preload("res://scripts/labo_rebuilt_scenes.gd")
const CrateModel = preload("res://scripts/sera_crate_model.gd")
const SharedMaterialShading = preload("res://scripts/sera_fullbody_material_preview.gd")
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
## Close-up sets are independent life-size outdoor worksites; BASE is iconography.
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
# Lightweight, cached 2D clearance map of actual industrial mesh instances.
const NAV_STEP := 0.25
const NAV_RADIUS := 1.42
const NAV_HEIGHT := 2.30
const OPERATE_SECONDS := 6.0
var nav := AStarGrid2D.new()
var nav_room: Node3D
var nav_obstacles: Array[Rect2] = []
var nav_other_obstacles: Array[Rect2] = []
var nav_path: Array[Vector2i] = []
var nav_index: int = 0
var nav_goal := Vector2i(99999,99999)
var nav_dirty := true
var nav_bounds := Rect2()
var nav_docked := false
var nav_ready := false
var nav_route_failed := false
var nav_dock_checked := false
var nav_dock_allowed := false

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
    environment.background_color = Color("#607d8f")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b7cadb")
    environment.ambient_light_energy = 0.85
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.name = "SofterIndustrialKeyLight"
    sun.rotation_degrees = Vector3(-56.0, -25.0, 0.0)
    sun.light_energy = 1.15
    sun.shadow_enabled = false
    add_child(sun)
    # Every facility now has a separately generated open industrial worksite.
    rebuilt_scenes = RebuiltScenes.new()
    rebuilt_scenes.build(self)
    _build_crate()
    # Industrial meshes use metre-mapped native-lit shaders. Only CRATE
    # goes through the character material pipeline.
    SharedMaterialShading.apply_to_subtree(crate)
    var ink := SeraViewEdges.new()
    ink.name = "ViewEdges"
    add_child(ink)
    hero_camera = Camera3D.new()
    hero_camera.name = "HeroCamera"
    add_child(hero_camera)
    hero_camera.current = true
    hero_camera.near = 0.10
    hero_camera.far = 220.0
    hero_camera.keep_aspect = Camera3D.KEEP_HEIGHT
    set_section(current_section)

func set_base_context(sources: Dictionary) -> void:
    if rebuilt_scenes != null:
        rebuilt_scenes.set_base_context(sources)

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
            # Fit the complete open portal frame, including the near feet.
            hero_camera.position = Vector3(11.5,12.0,42.0)
            camera_look = Vector3(-0.7,8.0,1.1)
            hero_camera.fov = 47.0
        "SMELTER":
            # Left-front perspective shows the side charge inlet and hot throat.
            hero_camera.position = Vector3(-9.4,8.8,30.2)
            camera_look = Vector3(-0.5,8.2,-0.8)
            hero_camera.fov = 39.0
        "RECYCLER":
            # Higher front view reveals both cutter shafts and the feed path.
            hero_camera.position = Vector3(8.8,13.0,24.5)
            camera_look = Vector3(0,4.5,-0.8)
            hero_camera.fov = 42.0
        "STORAGE":
            # Full-height storage portal and receiving ramps in the same view.
            hero_camera.position = Vector3(-11.5,13.0,46.0)
            camera_look = Vector3(-0.4,9.2,2.5)
            hero_camera.fov = 47.0
    hero_camera.look_at(camera_look, Vector3.UP)
    var key: String = camera_section_id()
    crate_route.transform = crate_route_poses.get(key, Transform3D.IDENTITY)
    for target in placement_models():
        var model_saved: Dictionary = PlacementStore.read(_model_placement_key(target))
        if model_saved.get("space") == "parent_local" and model_saved.has("position") and model_saved.has("rotation_degrees"):
            target.position = PlacementStore.vec(model_saved["position"])
            target.rotation_degrees = PlacementStore.vec(model_saved["rotation_degrees"])
    # Start on a clear approach lane; previous room coordinates are never reused.
    nav_docked = false
    nav_dirty = true
    _build_navigation()
    var spawn: Vector2i = _nearest_free(_terminal_point(2.7))
    nav_ready = nav.region.has_point(spawn) and not nav.is_point_solid(spawn)
    crate.visible = nav_ready
    if nav_ready:
        crate.position = _nav_local(_nav_position(spawn))
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
    return current_section + "_OUTDOOR_V6"

func apply_camera_preview(eye: Vector3, look: Vector3, fov: float) -> void:
    camera_look = look
    hero_camera.position = eye
    hero_camera.look_at(camera_look, Vector3.UP)
    hero_camera.fov = fov
    camera_previews[camera_section_id()] = {"eye":eye,"look":look,"fov":fov}

func placement_models() -> Array[Node3D]:
    var targets: Array[Node3D] = rebuilt_scenes.placement_models(current_section)
    targets.append(crate_route)
    return targets

func _model_placement_key(target: Node3D) -> String:
    return "labo/model/" + camera_section_id() + "/" + str(get_path_to(target))

func remember_model_placement(target: Node3D) -> void:
    if target == crate_route:
        crate_route_poses[camera_section_id()] = target.transform
    nav_dirty = true
    PlacementStore.stage(_model_placement_key(target), {
        "space":"parent_local","position":PlacementStore.array3(target.position),
        "rotation_degrees":PlacementStore.array3(target.rotation_degrees)})

func flush_model_placement() -> void:
    PlacementStore.flush()

func _room_point(world: Vector3) -> Vector2:
    var p: Vector3 = nav_room.to_local(world)
    return Vector2(p.x,p.z)

func _nav_local(p: Vector2) -> Vector3:
    return crate_route.to_local(nav_room.to_global(Vector3(p.x,0,p.y)))

func _nav_position(id: Vector2i) -> Vector2:
    return Vector2(id)*NAV_STEP

func _nav_cell(p: Vector2) -> Vector2i:
    return Vector2i(roundi(p.x/NAV_STEP),roundi(p.y/NAV_STEP))

func _terminal_point(distance: float) -> Vector2:
    var terminal: Node3D = rebuilt_scenes.terminal_node(current_section)
    return _room_point(terminal.to_global(Vector3(0.55,0,distance)))

func _add_obstacle(bounds: AABB, terminal: bool) -> void:
    # Ignore the floor surface and beams above the full robot silhouette.
    if bounds.end.y <= 0.075 or bounds.position.y >= NAV_HEIGHT:
        return
    var rect := Rect2(Vector2(bounds.position.x,bounds.position.z),
        Vector2(bounds.size.x,bounds.size.z)).grow(NAV_RADIUS+NAV_STEP*0.72)
    nav_obstacles.append(rect)
    if not terminal:
        nav_other_obstacles.append(rect)
    var lo := _nav_cell(rect.position-Vector2.ONE*NAV_STEP)
    var hi := _nav_cell(rect.end+Vector2.ONE*NAV_STEP)
    lo = Vector2i(maxi(lo.x,nav.region.position.x),maxi(lo.y,nav.region.position.y))
    hi = Vector2i(mini(hi.x,nav.region.end.x-1),mini(hi.y,nav.region.end.y-1))
    for z in range(lo.y,hi.y+1):
        for x in range(lo.x,hi.x+1):
            var id := Vector2i(x,z)
            if rect.has_point(_nav_position(id)):
                nav.set_point_solid(id)

func _collect_obstacles(node: Node3D, terminal: bool = false) -> void:
    # Exclude authored floor/markings; all legs and partial walls still count.
    if node.name in ["FacilityWorkDeck","OutdoorWorkMarkings"]:
        return
    terminal = terminal or node == rebuilt_scenes.terminal_node(current_section)
    if node is MultiMeshInstance3D:
        var draw := node as MultiMeshInstance3D
        var multi: MultiMesh = draw.multimesh
        if multi != null and multi.mesh != null:
            var relative: Transform3D = nav_room.global_transform.affine_inverse()*draw.global_transform
            var box: AABB = multi.mesh.get_aabb()
            for i in range(multi.instance_count):
                _add_obstacle(relative*multi.get_instance_transform(i)*box,terminal)
    elif node is MeshInstance3D:
        var draw := node as MeshInstance3D
        if draw.mesh != null:
            var relative: Transform3D = nav_room.global_transform.affine_inverse()*draw.global_transform
            _add_obstacle(relative*draw.mesh.get_aabb(),terminal)
    for child in node.get_children():
        if child is Node3D:
            _collect_obstacles(child as Node3D,terminal)

func _build_navigation() -> void:
    nav_room = rebuilt_scenes.navigation_room(current_section)
    nav_obstacles.clear()
    nav_other_obstacles.clear()
    nav_path.clear()
    nav_index = 0
    nav_goal = Vector2i(99999,99999)
    nav_route_failed = false
    nav_dock_checked = false
    # Stay on the raised deck, not its edge or the lower surrounding floor.
    nav_bounds = Rect2(-22,-22,44,44)
    if current_section == "LABO":
        nav_bounds = Rect2(-15.2,-10.9,29,24).grow(-NAV_RADIUS)
    elif current_section == "STORAGE":
        nav_bounds = Rect2(-15.4,-10,30,25).grow(-NAV_RADIUS)
    var first := Vector2i(ceili(nav_bounds.position.x/NAV_STEP),ceili(nav_bounds.position.y/NAV_STEP))
    var last := Vector2i(floori(nav_bounds.end.x/NAV_STEP),floori(nav_bounds.end.y/NAV_STEP))
    nav.region = Rect2i(first,last-first+Vector2i.ONE)
    nav.cell_size = Vector2.ONE*NAV_STEP
    nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    nav.update()
    nav.fill_solid_region(nav.region,false)
    _collect_obstacles(nav_room)
    # The storage transfer lane remains reserved even when cargo is elevated.
    if current_section == "STORAGE":
        var mast := nav_room.get_node_or_null("LeftLoadingLiftMastV2") as Node3D
        if mast != null:
            var relative: Transform3D = nav_room.global_transform.affine_inverse()*mast.global_transform
            _add_obstacle(relative*AABB(Vector3(-1.65,0,-2.0),Vector3(3.3,2.4,4.7)),false)
    nav_dirty = false

func _nearest_free(p: Vector2, limit: float = 8.0) -> Vector2i:
    var center := _nav_cell(p)
    var best := Vector2i(99999,99999)
    var score: float = limit*limit
    var span: int = ceili(limit/NAV_STEP)
    for z in range(maxi(center.y-span,nav.region.position.y),mini(center.y+span,nav.region.end.y-1)+1):
        for x in range(maxi(center.x-span,nav.region.position.x),mini(center.x+span,nav.region.end.x-1)+1):
            var id := Vector2i(x,z)
            if nav.is_point_solid(id):
                continue
            var d: float = _nav_position(id).distance_squared_to(p)
            if d < score:
                best = id
                score = d
    return best

func _segment_clear(a: Vector2, b: Vector2, ignore_terminal: bool = false) -> bool:
    var obstacles: Array[Rect2] = nav_other_obstacles if ignore_terminal else nav_obstacles
    var steps: int = maxi(1,ceili(a.distance_to(b)/(NAV_STEP*0.25)))
    for i in range(steps+1):
        var p: Vector2 = a.lerp(b,float(i)/float(steps))
        if not nav_bounds.has_point(p):
            return false
        for rect in obstacles:
            if rect.has_point(p):
                return false
    return true

func _face_point(goal: Vector3, delta: float) -> void:
    var diff: Vector3 = goal - crate.position
    diff.y = 0.0
    if diff.length_squared() > 0.001:
        crate.rotation.y = lerp_angle(crate.rotation.y,atan2(-diff.x,-diff.z),minf(1.0,delta*6.0))

func _relax_arms(delta: float) -> void:
    crate_head.rotation = crate_head.rotation.lerp(Vector3.ZERO,minf(1.0,delta*5.0))
    crate_arm.rotation = crate_arm.rotation.lerp(Vector3.ZERO,minf(1.0,delta*5.0))
    crate_left_arm.rotation = crate_left_arm.rotation.lerp(Vector3.ZERO,minf(1.0,delta*5.0))

func _move_to(goal: Vector3, delta: float, turn: bool = true) -> bool:
    var diff: Vector3 = goal - crate.position
    if diff.length() <= 0.025:
        crate.position = goal
        return true
    if turn:
        _face_point(goal,delta)
    crate.position = crate.position.move_toward(goal,minf(1.8*delta,0.20))
    _relax_arms(delta)
    return false

func _walk_route(destination: Vector2, delta: float) -> bool:
    if not nav_ready or nav_route_failed:
        return false
    var here: Vector2 = _room_point(crate.global_position)
    if nav_path.is_empty():
        var goal := _nearest_free(destination)
        var origin := _nearest_free(here,0.60)
        if not nav.region.has_point(origin) or not nav.region.has_point(goal):
            nav_route_failed = true
            return false
        if not _segment_clear(here,_nav_position(origin)):
            nav_route_failed = true
            return false
        var ids: Array[Vector2i] = nav.get_id_path(origin,goal)
        if ids.is_empty():
            nav_route_failed = true
            return false
        nav_goal = goal
        nav_path = ids
        nav_index = 0
    while nav_index < nav_path.size():
        var p: Vector2 = _nav_position(nav_path[nav_index])
        if not _move_to(_nav_local(p),delta):
            return false
        nav_index += 1
    return true

func _inspection_point() -> Vector2:
    # The editable route offset is a preference, never a reason to cross solid mesh.
    var world: Vector3 = rebuilt_scenes.work_point(current_section,true)
    return _room_point(crate_route.to_global(to_local(world)))

func _terminal_facing_point() -> Vector3:
    var terminal: Node3D = rebuilt_scenes.terminal_node(current_section)
    return crate_route.to_local(terminal.to_global(Vector3(0.55,0,0)))

func _dock(delta: float, reverse: bool = false) -> bool:
    var approach: Vector2 = _terminal_point(2.25)
    var stand: Vector2 = _terminal_point(1.49)
    var here: Vector2 = _room_point(crate.global_position)
    # Only the last straight, aligned approach may use the tighter terminal
    # envelope. The body and forward hand stay outside the console face.
    if not nav_dock_checked:
        nav_dock_checked = true
        nav_dock_allowed = _segment_clear(stand,approach,true)
        if not reverse:
            nav_dock_allowed = nav_dock_allowed and _segment_clear(here,approach)
    if not nav_dock_allowed:
        return false
    if not reverse and here.distance_to(approach)>0.035 and not nav_docked:
        if not _move_to(_nav_local(approach),delta):
            return false
        nav_docked = true
    if not reverse:
        nav_docked = true
    _face_point(_terminal_facing_point(),delta)
    var facing: Vector3 = _terminal_facing_point()-crate.position
    facing.y = 0.0
    if absf(angle_difference(crate.rotation.y,atan2(-facing.x,-facing.z)))>0.07:
        return false
    if not _move_to(_nav_local(approach if reverse else stand),delta,false):
        return false
    nav_docked = not reverse
    return true

func _enter(state: String) -> void:
    work_state = state
    state_time = 0.0
    nav_path.clear()
    nav_index = 0
    nav_route_failed = false
    nav_dock_checked = false

func _process(delta: float) -> void:
    clock += delta
    state_time += delta
    rebuilt_scenes.animate(delta,clock,current_section)
    if nav_dirty:
        _build_navigation()
        nav_docked = false
        var safe := _nearest_free(_room_point(crate.global_position))
        nav_ready = nav.region.has_point(safe) and not nav.is_point_solid(safe)
        crate.visible = nav_ready
        if nav_ready:
            crate.position = _nav_local(_nav_position(safe))
        _enter("walk_to_terminal")
    if not nav_ready:
        return
    match work_state:
        "walk_to_terminal":
            if _walk_route(_terminal_point(2.25),delta):
                _enter("dock")
        "dock":
            if _dock(delta):
                _enter("operate")
        "operate":
            _face_point(_terminal_facing_point(),delta)
            # Several deliberate button presses, short reading pauses, then release.
            var envelope: float = smoothstep(0.12,0.65,state_time)*(1.0-smoothstep(5.45,5.95,state_time))
            var tap: float = 0.5+0.5*sin(state_time*TAU/0.95)
            crate_left_arm.rotation.x = (0.10+0.16*tap)*envelope
            crate_head.rotation.x = -0.07+0.06*sin(state_time*1.4)
            crate_head.rotation.y = 0.07*sin(state_time*0.9)
            if state_time >= 2.0 and rebuilt_scenes.cycle_complete():
                rebuilt_scenes.start_cycle(current_section)
            if state_time >= OPERATE_SECONDS:
                _enter("undock")
        "undock":
            if _dock(delta,true):
                _enter("walk_to_inspection")
        "walk_to_inspection":
            if _walk_route(_inspection_point(),delta):
                _enter("inspect")
        "inspect":
            _face_point(crate_route.to_local(rebuilt_scenes.focus_point(current_section,true)),delta)
            crate_head.rotation.x = -0.12 + 0.08*sin(state_time*1.5)
            crate_head.rotation.y = 0.12*sin(state_time*0.9)
            crate_left_arm.rotation.x = -0.17*(0.5+0.5*sin(state_time*2.0))
            if state_time >= 2.5 and rebuilt_scenes.cycle_complete():
                _enter("walk_to_terminal")
