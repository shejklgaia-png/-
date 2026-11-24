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
var crate_right_wrist: Node3D
var crate_left_wrist: Node3D
var idle_rng := RandomNumberGenerator.new()
var idle_kind: int = -1
var idle_age: float = 0.0
var idle_duration: float = 2.0
var idle_sign: float = 1.0
var attention_target: Node3D
var attention_queue: Array[Node3D] = []
var carrier_seen: Array[bool] = [false,false]
const GLANCE_TURN_SECONDS := 0.30
const GLANCE_HOLD_SECONDS := 1.50
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
var nav_path: Array[Vector2] = []
var nav_speed: float = 0.0
var nav_index: int = 0
var nav_goal := Vector2i(99999,99999)
var nav_dirty := true
var nav_bounds := Rect2()
var nav_docked := false
var nav_ready := false
var nav_route_failed := false
var nav_dock_checked := false
var nav_dock_allowed := false
var console_pending := false
var dock_plan_ready := false
var dock_approach := Vector2.ZERO
var dock_stand := Vector2.ZERO
var dock_grid := Vector2i(99999,99999)
var terminal_fallback := false
const DOCK_HAND_OFFSET := 0.55
const DOCK_STAND_DISTANCE := 1.36

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
    crate_right_wrist = crate_arm.get_node("WristPivot") as Node3D
    crate_left_wrist = crate_left_arm.get_node("WristPivot") as Node3D
    idle_rng.randomize()


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
    set_section(current_section,false)

func set_base_context(sources: Dictionary) -> void:
    if rebuilt_scenes != null:
        rebuilt_scenes.set_base_context(sources)

func set_section(section: String,dispatch: bool = true) -> void:
    current_section = section if section in ["LABO", "SMELTER", "RECYCLER", "STORAGE"] else "LABO"
    rebuilt_scenes.select(current_section)
    clock = 0.0
    state_time = 0.0
    work_state = "idle"
    console_pending = dispatch
    attention_target = null
    attention_queue.clear()
    carrier_seen = [false,false]
    idle_kind = -1
    idle_age = 0.0
    idle_duration = idle_rng.randf_range(0.5,1.5)
    crate_right_wrist.rotation = Vector3.ZERO
    crate_left_wrist.rotation = Vector3.ZERO
    crate_head.rotation = Vector3.ZERO
    crate_arm.rotation = Vector3.ZERO
    crate_left_arm.rotation = Vector3.ZERO
    crate.scale = Vector3.ONE
    match current_section:
        "LABO":
            # Fit the complete open portal frame, including the near feet.
            hero_camera.position = Vector3(11.5,14.0,48.0)
            camera_look = Vector3(-0.7,8.0,1.1)
            hero_camera.fov = 47.0
        "SMELTER":
            # Left-front perspective shows the side charge inlet and hot throat.
            hero_camera.position = Vector3(-10.5,12.0,38.0)
            camera_look = Vector3(-0.5,8.2,-0.8)
            hero_camera.fov = 39.0
        "RECYCLER":
            # Higher front view reveals both cutter shafts and the feed path.
            hero_camera.position = Vector3(9.0,16.0,38.0)
            camera_look = Vector3(0,4.5,-0.8)
            hero_camera.fov = 42.0
        "STORAGE":
            # Full-height storage portal and receiving ramps in the same view.
            hero_camera.position = Vector3(-11.5,15.5,52.0)
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
    var spawn: Vector2i = dock_grid if dock_plan_ready else _nearest_free(_terminal_point(2.7))
    nav_ready = nav.region.has_point(spawn) and not nav.is_point_solid(spawn)
    crate.visible = nav_ready
    if nav_ready:
        if dock_plan_ready:
            # A nearby reachable idle bay creates a visible approach after the
            # carrier glance. Never spawn across an obstacle from the console.
            var side_dir: Vector2 = (dock_approach-dock_stand).normalized().orthogonal()
            for offset in [side_dir*2.0,-side_dir*2.0,side_dir*1.0,-side_dir*1.0]:
                var candidate: Vector2i = _nearest_free(dock_approach+offset,0.35)
                if nav.region.has_point(candidate) and _segment_clear(_nav_position(candidate),dock_approach):
                    spawn = candidate
                    break
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
    # Menu entry is the dispatch trigger, after saved placement is applied.
    # No dependency on the operator reaching the console first.
    if dispatch:
        rebuilt_scenes.start_cycle(current_section,true)

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
    return _room_point(terminal.to_global(Vector3(DOCK_HAND_OFFSET,0,distance)))

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
    if node.name in ["FacilityWorkDeck","OutdoorWorkMarkings","WorksiteLogistics"]:
        return
    if node == rebuilt_scenes.terminal_node(current_section) and not terminal:
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
    nav_speed = 0.0
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
    for reserve in rebuilt_scenes.logistics_reservations(current_section):
        _add_obstacle(reserve,false)
    _plan_console_dock()
    _collect_obstacles(rebuilt_scenes.terminal_node(current_section),true)
    if dock_plan_ready and nav.is_point_solid(dock_grid):
        dock_plan_ready = false
    nav_dirty = false

# Plan a real front-facing stand and a reachable grid cell before marking
# the terminal itself solid. The last segment may ignore only that terminal.
func _dock_candidate(terminal: Node3D) -> bool:
    var center: Vector2 = _room_point(terminal.global_position)
    var stand: Vector2 = _terminal_point(DOCK_STAND_DISTANCE)
    if not _segment_clear(center,stand,true):
        return false
    var relative: Transform3D = nav_room.global_transform.affine_inverse()*terminal.global_transform
    var footprint: AABB = relative*AABB(Vector3(-0.60,0,-0.50),Vector3(1.20,1.60,1.04))
    var terminal_exclusion := Rect2(Vector2(footprint.position.x,footprint.position.z),Vector2(footprint.size.x,footprint.size.z)).grow(NAV_RADIUS+NAV_STEP*0.72)
    for distance in [2.35,2.60,2.85,3.10,3.35]:
        var approach: Vector2 = _terminal_point(float(distance))
        if not _segment_clear(stand,approach,true):
            continue
        var id: Vector2i = _nearest_free(approach,0.40)
        if not nav.region.has_point(id) or nav.is_point_solid(id):
            continue
        var grid_point: Vector2 = _nav_position(id)
        # The console footprint is 1.15 x 0.98; its expanded navigation
        # rectangle must not contain the chosen staging cell.
        var local: Vector3 = terminal.to_local(nav_room.to_global(Vector3(grid_point.x,0,grid_point.y)))
        if local.z<2.20 or terminal_exclusion.has_point(grid_point):
            continue
        if not _segment_clear(grid_point,stand,true):
            continue
        dock_grid = id
        dock_approach = grid_point
        dock_stand = stand
        return true
    return false

func _plan_console_dock() -> void:
    var terminal: Node3D = rebuilt_scenes.terminal_node(current_section)
    dock_plan_ready = false
    terminal_fallback = false
    dock_grid = Vector2i(99999,99999)
    if _dock_candidate(terminal):
        dock_plan_ready = true
        return
    # A saved/default terminal can be boxed in by machinery or deck edges.
    # Search a nearby clear service bay; this is a runtime fallback only,
    # never an overwrite of the user's saved canonical placement.
    var original: Transform3D = terminal.transform
    var best: float = INF
    var best_pose: Transform3D = original
    for radius in range(1,13):
        for direction in range(16):
            var angle: float = TAU*float(direction)/16.0
            var offset := Vector3(cos(angle),0,sin(angle))*float(radius)*0.5
            terminal.position = original.origin+offset
            for yaw in [original.basis.get_euler().y,0.0,PI*0.5,-PI*0.5,PI]:
                terminal.rotation.y = float(yaw)
                var cost: float = offset.length()+0.25*absf(angle_difference(original.basis.get_euler().y,float(yaw)))
                if cost>=best:
                    continue
                if _dock_candidate(terminal):
                    best = cost
                    best_pose = terminal.transform
        if best<INF:
            break
    terminal.transform = best_pose
    if best<INF:
        dock_plan_ready = _dock_candidate(terminal)
        terminal_fallback = dock_plan_ready

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
    crate_left_wrist.rotation = crate_left_wrist.rotation.lerp(Vector3.ZERO,minf(1.0,delta*5.0))
    crate_right_wrist.rotation = crate_right_wrist.rotation.lerp(Vector3.ZERO,minf(1.0,delta*5.0))

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

func _smooth_route(ids: Array[Vector2i], here: Vector2) -> Array[Vector2]:
    # Greedy line-of-sight shortcuts remove grid staircase turns.
    var coarse: Array[Vector2] = [here]
    var i: int = 0
    while i<ids.size()-1:
        var next: int = i+1
        for j in range(ids.size()-1,i,-1):
            if _segment_clear(coarse[-1],_nav_position(ids[j])):
                next = j
                break
        var point: Vector2 = _nav_position(ids[next])
        if not _segment_clear(coarse[-1],point):
            return []
        if coarse[-1].distance_to(point)>0.001:
            coarse.append(point)
        i = next
    if ids.size()==1 and here.distance_to(_nav_position(ids[0]))>0.001:
        coarse.append(_nav_position(ids[0]))
    var result: Array[Vector2] = [coarse[0]]
    # Round each corner with a checked quadratic Bezier. Never cut an obstacle.
    for k in range(1,coarse.size()-1):
        var corner: Vector2 = coarse[k]
        var a: Vector2 = coarse[k-1]
        var b: Vector2 = coarse[k+1]
        var radius: float = minf(1.30,minf(a.distance_to(corner),b.distance_to(corner))*0.40)
        var accepted: bool = false
        for factor in [1.0,0.7,0.45,0.2]:
            var d: float = radius*float(factor)
            if d<0.04:
                continue
            var entry: Vector2 = corner.move_toward(a,d)
            var exit: Vector2 = corner.move_toward(b,d)
            var curve: Array[Vector2] = [entry]
            var clear: bool = _segment_clear(result[-1],entry)
            for j in range(1,9):
                var u: float = float(j)/8.0
                var q: Vector2 = entry.lerp(corner,u).lerp(corner.lerp(exit,u),u)
                if not _segment_clear(curve[-1],q):
                    clear = false
                    break
                curve.append(q)
            if clear and _segment_clear(exit,b):
                result.append_array(curve)
                accepted = true
                break
        if not accepted:
            result.append(corner)
    if coarse.size()>1:
        result.append(coarse[-1])
    for j in range(1,result.size()):
        if not _segment_clear(result[j-1],result[j]):
            return coarse
    return result

func _walk_route(destination: Vector2, delta: float) -> bool:
    if not nav_ready or nav_route_failed:
        return false
    var here: Vector2 = _room_point(crate.global_position)
    if nav_path.is_empty():
        var goal := dock_grid if dock_plan_ready and destination.is_equal_approx(dock_approach) else _nearest_free(destination)
        var origin := _nearest_free(here,0.60)
        if not nav.region.has_point(origin) or not nav.region.has_point(goal) or not _segment_clear(here,_nav_position(origin)):
            nav_route_failed = true
            return false
        var ids: Array[Vector2i] = nav.get_id_path(origin,goal)
        if ids.is_empty():
            nav_route_failed = true
            return false
        nav_path = _smooth_route(ids,here)
        if nav_path.is_empty():
            nav_route_failed = true
            return false
        nav_index = 1
        nav_goal = goal
    if nav_index>=nav_path.size():
        nav_speed = 0.0
        return true
    var remaining: float = here.distance_to(nav_path[nav_index])
    for i in range(nav_index,nav_path.size()-1):
        remaining += nav_path[i].distance_to(nav_path[i+1])
    if remaining<=0.008:
        crate.position = _nav_local(nav_path[-1])
        nav_index = nav_path.size()
        nav_speed = 0.0
        return true
    var desired: float = minf(1.8,sqrt(maxf(0.0,remaining)*4.0))
    nav_speed = move_toward(nav_speed,desired,delta*3.0)
    var budget: float = minf(nav_speed*delta,0.25)
    while budget>0.0001 and nav_index<nav_path.size():
        var next: Vector2 = nav_path[nav_index]
        var distance: float = here.distance_to(next)
        if distance<=budget+0.0001:
            here = next
            budget -= distance
            nav_index += 1
        else:
            here = here.move_toward(next,budget)
            budget = 0.0
    # Look ahead along the curve instead of yawing at every sample point.
    if nav_index<nav_path.size():
        var look: Vector2 = here
        var lead: float = 0.65
        for j in range(nav_index,nav_path.size()):
            var d: float = look.distance_to(nav_path[j])
            if d>=lead:
                look = look.move_toward(nav_path[j],lead)
                break
            lead -= d
            look = nav_path[j]
        _face_point(_nav_local(look),delta)
    crate.position = _nav_local(here)
    _relax_arms(delta)
    if nav_index>=nav_path.size():
        nav_speed = 0.0
        return true
    return false

func _inspection_point() -> Vector2:
    # The editable route offset is a preference, never a reason to cross solid mesh.
    var world: Vector3 = rebuilt_scenes.work_point(current_section,true)
    return _room_point(crate_route.to_global(to_local(world)))

func _terminal_facing_point() -> Vector3:
    var terminal: Node3D = rebuilt_scenes.terminal_node(current_section)
    return crate_route.to_local(terminal.to_global(Vector3(DOCK_HAND_OFFSET,0,0)))

func _dock(delta: float, reverse: bool = false) -> bool:
    if not dock_plan_ready:
        nav_dock_checked = true
        nav_dock_allowed = false
        return false
    var here: Vector2 = _room_point(crate.global_position)
    var target: Vector2 = dock_approach if reverse else dock_stand
    nav_dock_checked = true
    nav_dock_allowed = _segment_clear(here,target,true)
    if not nav_dock_allowed:
        return false
    # Face the actual console first, then move in or back out along the
    # validated corridor. Keep the docking flag until fully clear.
    _face_point(_terminal_facing_point(),delta)
    var facing: Vector3 = _terminal_facing_point()-crate.position
    facing.y = 0.0
    if absf(angle_difference(crate.rotation.y,atan2(-facing.x,-facing.z)))>0.07:
        return false
    nav_docked = true
    if not _move_to(_nav_local(target),delta,false):
        return false
    nav_docked = not reverse
    return true

func _enter(state: String) -> void:
    work_state = state
    state_time = 0.0
    nav_path.clear()
    nav_index = 0
    nav_speed = 0.0
    nav_route_failed = false
    nav_dock_checked = false

func _observe_carrier_starts() -> void:
    # Rising visibility marks the actual dispatch of each independent vehicle.
    # One reaction per arrival, not one reaction per animation frame.
    for i in range(2):
        var vehicle: Node3D = rebuilt_scenes.logistics_carrier(current_section,i==0)
        var present: bool = is_instance_valid(vehicle) and vehicle.visible
        if present and not carrier_seen[i]:
            attention_queue.append(vehicle)
        carrier_seen[i] = present

func _watch_carrier(delta: float) -> bool:
    if work_state!="watch_carrier":
        if attention_queue.is_empty() or work_state in ["walk_to_terminal","dock","operate","undock"]:
            return false
        attention_target = attention_queue.pop_front()
        console_pending = true
        _enter("watch_carrier")
    if not is_instance_valid(attention_target):
        _enter("walk_to_terminal")
        return false
    # Turn the neck toward the moving truck; if it is far behind, use a
    # modest base turn only while clear of the console.
    var aim: Vector3 = attention_target.global_position+Vector3.UP*1.15
    var local: Vector3 = crate.to_local(aim)
    var yaw: float = atan2(-local.x,-local.z)
    if absf(yaw)>1.15 and not nav_docked:
        crate.rotation.y += signf(yaw)*minf(absf(yaw)-1.15,delta*3.5)
        local = crate.to_local(aim)
        yaw = atan2(-local.x,-local.z)
    var pitch: float = atan2(local.y-1.30,maxf(0.05,Vector2(local.x,local.z).length()))
    var rate: float = 12.0
    crate_head.rotation.x = lerpf(crate_head.rotation.x,clampf(pitch,-0.34,0.34),minf(1.0,delta*rate))
    crate_head.rotation.y = lerp_angle(crate_head.rotation.y,clampf(yaw,-2.65,2.65),minf(1.0,delta*rate))
    crate_head.rotation.z = lerpf(crate_head.rotation.z,0.0,minf(1.0,delta*rate))
    crate_arm.rotation = crate_arm.rotation.lerp(Vector3.ZERO,minf(1.0,delta*6.0))
    crate_left_arm.rotation = crate_left_arm.rotation.lerp(Vector3.ZERO,minf(1.0,delta*6.0))
    crate_right_wrist.rotation = crate_right_wrist.rotation.lerp(Vector3.ZERO,minf(1.0,delta*6.0))
    crate_left_wrist.rotation = crate_left_wrist.rotation.lerp(Vector3.ZERO,minf(1.0,delta*6.0))
    if state_time>=GLANCE_TURN_SECONDS+GLANCE_HOLD_SECONDS:
        attention_target = null
        idle_age = 0.0
        idle_kind = -1
        # Already standing at the console? Resume the operator pose without
        # walking through it. A partially docked robot finishes its approach.
        if nav_docked:
            if _room_point(crate.global_position).distance_to(dock_stand)<0.08:
                _enter("operate")
            else:
                _enter("dock")
        else:
            _enter("walk_to_terminal")
    return true

func _crate_idle(delta: float) -> void:
    idle_age += delta
    if idle_kind<0:
        if idle_age<idle_duration:
            _relax_arms(delta)
            return
        idle_kind = idle_rng.randi_range(0,9)
        idle_age = 0.0
        idle_duration = idle_rng.randf_range(1.6,3.8)
        idle_sign = -1.0 if idle_rng.randf()<0.5 else 1.0
    var u: float = clampf(idle_age/idle_duration,0.0,1.0)
    var envelope: float = sin(PI*u)
    var wave: float = sin(TAU*u)*envelope
    var h := Vector3.ZERO
    var l := Vector3.ZERO
    var r := Vector3.ZERO
    var lw: float = 0.0
    var rw: float = 0.0
    match idle_kind:
        0: # Look left then right.
            h.y = 0.55*wave*idle_sign
        1: # Tilt the head quizzically.
            h = Vector3(-0.08*envelope,0.18*envelope*idle_sign,0.16*envelope*idle_sign)
        2: # Two small nods.
            h.x = 0.17*sin(TAU*2.0*u)*envelope
        3: # Examine the raised left hand and turn the wrist.
            l.x = 0.36*envelope
            h = Vector3(-0.14*envelope,0.24*envelope,0)
            lw = TAU*envelope
        4: # Examine the right hand.
            r.x = 0.36*envelope
            h = Vector3(-0.14*envelope,-0.24*envelope,0)
            rw = -TAU*envelope
        5: # A tiny alternating arm stretch.
            l.x = 0.22*maxf(0.0,wave)
            r.x = 0.22*maxf(0.0,-wave)
        6: # Look up at overhead machinery.
            h.x = 0.27*envelope
            h.y = 0.16*wave
        7: # Rotate both wrists, without moving the tracks.
            l.x = 0.13*envelope
            r.x = 0.13*envelope
            lw = TAU*envelope
            rw = -TAU*envelope
        8: # Brief two-arm lift, then relax.
            l.x = 0.26*envelope
            r.x = 0.26*envelope
            h.x = -0.12*envelope
        9: # A small one-arm wave and head tilt.
            h.z = 0.10*envelope*idle_sign
            if idle_sign>0:
                l.x = (0.23+0.08*sin(TAU*3.0*u))*envelope
                lw = 0.45*wave
            else:
                r.x = (0.23+0.08*sin(TAU*3.0*u))*envelope
                rw = 0.45*wave
    # If an approach failed with CRATE still close to the terminal, keep
    # arms tucked instead of letting idle gestures sweep into the console.
    if nav_docked:
        l = Vector3.ZERO
        r = Vector3.ZERO
        lw = 0.0
        rw = 0.0
    var rate: float = minf(1.0,delta*10.0)
    crate_head.rotation = crate_head.rotation.lerp(h,rate)
    crate_arm.rotation = crate_arm.rotation.lerp(r,rate)
    crate_left_arm.rotation = crate_left_arm.rotation.lerp(l,rate)
    crate_left_wrist.rotation.z = lerpf(crate_left_wrist.rotation.z,lw,rate)
    crate_right_wrist.rotation.z = lerpf(crate_right_wrist.rotation.z,rw,rate)
    if u>=1.0:
        idle_kind = -1
        idle_age = 0.0
        idle_duration = idle_rng.randf_range(0.8,3.2)

func _process(delta: float) -> void:
    clock += delta
    state_time += minf(delta,0.10) if work_state in ["watch_carrier","operate"] else delta
    rebuilt_scenes.animate(delta,clock,current_section)
    if nav_dirty:
        _build_navigation()
        nav_docked = false
        var safe := _nearest_free(_room_point(crate.global_position))
        nav_ready = nav.region.has_point(safe) and not nav.is_point_solid(safe)
        crate.visible = nav_ready
        if nav_ready:
            crate.position = _nav_local(_nav_position(safe))
        _enter("idle")
    _observe_carrier_starts()
    if not nav_ready:
        return
    if _watch_carrier(delta):
        return
    match work_state:
        "walk_to_terminal":
            if dock_plan_ready and _walk_route(dock_approach,delta):
                _enter("dock")
            elif not dock_plan_ready or nav_route_failed:
                _enter("retry_console")
        "dock":
            if _dock(delta):
                _enter("operate")
            elif nav_dock_checked and not nav_dock_allowed:
                _enter("retry_console")
        "operate":
            _face_point(_terminal_facing_point(),delta)
            _relax_arms(delta)
            var envelope: float = smoothstep(0.12,0.65,state_time)*(1.0-smoothstep(5.45,5.95,state_time))
            var tap: float = 0.5+0.5*sin(state_time*TAU/0.95)
            crate_left_arm.rotation.x = (0.10+0.16*tap)*envelope
            crate_head.rotation.x = -0.03+0.05*sin(state_time*1.4)
            crate_head.rotation.y = 0.07*sin(state_time*0.9)
            if state_time >= OPERATE_SECONDS:
                console_pending = false
                _enter("undock")
        "undock":
            if _dock(delta,true):
                _enter("walk_to_inspection")
            elif nav_dock_checked and not nav_dock_allowed:
                _enter("retry_console")
        "walk_to_inspection":
            if _walk_route(_inspection_point(),delta):
                _enter("inspect")
            elif nav_route_failed:
                _enter("idle")
        "inspect":
            _face_point(crate_route.to_local(rebuilt_scenes.focus_point(current_section,true)),delta)
            crate_head.rotation.x = -0.12 + 0.08*sin(state_time*1.5)
            crate_head.rotation.y = 0.12*sin(state_time*0.9)
            crate_left_arm.rotation.x = -0.17*(0.5+0.5*sin(state_time*2.0))
            if state_time >= 2.5:
                _enter("idle")
        "retry_console":
            _relax_arms(delta)
            if state_time>=1.0:
                # A failed attempt is not a completed job. Retry the same
                # console with a fresh route, without bypassing collision checks.
                if nav_docked and dock_plan_ready:
                    _enter("dock" if console_pending else "undock")
                elif console_pending:
                    _enter("walk_to_terminal")
                else:
                    _enter("idle")
        "idle":
            if console_pending and state_time>=1.8:
                _enter("walk_to_terminal")
            else:
                _crate_idle(delta)
