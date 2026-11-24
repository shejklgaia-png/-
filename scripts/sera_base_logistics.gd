extends Node3D
## Outdoor logistics is a visual production loop, never a resource/save mutation.
## One shared batch per geometry/material, fixed 30 Hz poses and startup-only
## authored route sampling. Traffic uses short-horizon proximity prediction
## and actual vehicle clearance, never a whole-leg reservation.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const Clutter = preload("res://scripts/sera_base_clutter.gd")
const FreshDesign = preload("res://scripts/sera_base_fresh_design.gd")
const Power = preload("res://scripts/sera_base_power_distribution.gd")
const FixedLayout = preload("res://scripts/sera_base_authored_layout.gd")
const Polygon = preload("res://scripts/sera_base_polygon_meshes.gd")
const CELL: float = 0.75
const REGION := Rect2i(-46, -46, 93, 93)
const CLEARANCE: float = 0.84
const STEP: float = 1.0 / 30.0
const SPEED: float = 2.35
const CARRIER_SCALE := Vector3(1.20, 1.0, 1.20)
const TRAFFIC_GAP: float = 2.18
const TRAFFIC_FORECAST_GAP: float = 2.40
const TRAFFIC_HORIZON: float = 1.5
const TRAFFIC_SAMPLE: float = 0.25
const TRAFFIC_BRAKE: float = 5.0
const VEHICLES_PER_ROUTE: int = 2
const FLEET_SIZE: int = 6
const BOX_TIME: float = 3.8
const DECK_Y: float = 0.39
const RACK_Y: float = 0.61
const ROUTES = [
    ["SCRAP_COLLECTOR", "LABO"], ["SCRAP_COLLECTOR", "SMELTER"],
    ["SCRAP_COLLECTOR", "RECYCLER"]
]

class Visual:
    var slots: Dictionary = {}
    var pose: Transform3D = Transform3D.IDENTITY
    var shown: bool = true
    var dirty: bool = true
    var node: MeshInstance3D

class Dock:
    var cell: Vector2i
    var stage: Vector2
    var pivot: Vector2
    var yaw: float
    var hatch_side: float
    var link_a: Visual
    var link_b: Visual
    var elbow: Visual
    var wrist: Visual
    var grip: Visual
    var jaw_a: Visual
    var jaw_b: Visual
    var lifts: Array[Visual] = []
    var shutters: Array[Visual] = []

class Truck:
    var id: int
    var source: String
    var destination: String
    var raw: bool
    var home: Vector2i
    var pos: Vector2
    var yaw: float
    var speed: float = 0.0
    var legs: Array = []
    var cells: Dictionary = {}
    var leg_cells: Array[Dictionary] = []
    var segment_cells: Array = []
    var leg: int = 0
    var waypoint: int = 1
    var traffic_limit: float = INF
    var traffic_blocked: bool = false
    var yield_age: float = 0.0
    var mode: String = "home"
    var wait: float = 0.0
    var clock: float = 0.0
    var tread_distance: float = 0.0
    var body: Visual
    var cargo: Array[Visual] = []
    var raw_meshes: Array[ArrayMesh] = []
    var product_meshes: Array[ArrayMesh] = []
    var lamp_go: Visual
    var lamp_wait: Visual
    var treads: Array[Visual] = []
    var loaded: bool = false
    var carrier_pose: Transform3D = Transform3D.IDENTITY

var _grid := AStarGrid2D.new()
var _docks: Dictionary = {}
var _trucks: Array[Truck] = []
var _homes: Array[Vector2i] = []
var _pair_priority: Dictionary = {}
var _visuals: Array[Visual] = []
var _draws: Dictionary = {}
var _batch: Variant
var _acc: float = 0.0
var _traffic_elapsed: float = 0.10
var _camera: Camera3D
var _network_anchor := Vector2i(0, 40)
var _route_parking_exclusion: Dictionary = {}
var _screen_costs: Dictionary = {}
var _reserved: Dictionary = {}
var _road_cells: Dictionary = {}
var _ramp_surface: Node3D
var _cable_cells: Dictionary = {}
var _power_cells: Dictionary = {}
var _protector_bounds: Array[Rect2] = []
var _solid_meshes: Dictionary = {}
var _phase: String = "NEW"
var _planned_count: int = 0
var _vehicle_count: int = 0
var _cargo_count: int = 0
var _ready_for_motion: bool = false
var _facility_motion: Dictionary = {}
var _intakes: Dictionary = {}
const INTAKE_ITEM_TIME: float = 5.0

func bind_facility_motion(key: String, motion: Node) -> void:
    if is_instance_valid(motion):
        _facility_motion[key] = motion
        if motion.has_method("material_intake_world") and _docks.has(key):
            _build_intake(key, motion)

# Fixed straight overhead shuttle, surveyed from the dock stage to the
# real machine mouth. The hoist can slide across the two rack slots.
func _build_intake(key: String, motion: Node) -> void:
    var d: Dock = _docks[key]
    var target: Vector3 = to_local(motion.call("material_intake_world"))
    var rail_y: float = to_local(Vector3(0,float(motion.call("material_rail_world_y")),0)).y
    var start := _v3(d.stage, rail_y)
    var end := Vector3(target.x,rail_y,target.z)
    var axis: Vector3 = (end-start).normalized()
    var side := Vector3(-axis.z,0,axis.x)
    var g: Variant = _template()
    g.rod("IntakeRail",start-side*0.19,end-side*0.19,0.10,"trim")
    g.rod("IntakeRail",start+side*0.19,end+side*0.19,0.10,"trim")
    for point in [start,end]:
        var p: Vector3 = point
        g.rod("IntakeCrossmember",p-side*0.56,p+side*0.56,0.12,"edge")
    # Dock mast, braced clear of the moving pallet and existing gripper.
    var mast: Vector3 = start-axis*0.72+side*0.68
    g.rod("IntakeMast",Vector3(mast.x,0.10,mast.z),mast,0.16,"slate")
    g.rod("IntakeMastBrace",mast,start,0.14,"edge")
    # Machine end is cantilevered from a side support outside the mouth.
    var anchor: Vector3 = end+side*0.70
    g.rod("IntakeEndBrace",end,anchor+Vector3.DOWN*0.65,0.14,"edge")
    g.rod("IntakeEndSupport",anchor+Vector3.DOWN*0.65,anchor+Vector3.DOWN*1.30,0.15,"slate")
    _direct_visual(g,"intake_rail_"+key,"MaterialIntakeRail_"+key)
    var trolley_model: Variant = _template()
    trolley_model.box("IntakeTrolley",Vector3.ZERO,Vector3(0.44,0.16,0.38),"slate")
    var trolley: Visual = _direct_visual(trolley_model,"intake_trolley","IntakeTrolley_"+key)
    var hoist_model: Variant = _template()
    hoist_model.rod("IntakeHoistCable",Vector3(0,-0.5,0),Vector3(0,0.5,0),0.034,"edge")
    var hoist: Visual = _direct_visual(hoist_model,"intake_hoist","IntakeHoist_"+key)
    var grip_model: Variant = _template()
    grip_model.box("IntakeGripBeam",Vector3(0,0.05,0),Vector3(0.61,0.10,0.13),"gold")
    for sign in [-1.0,1.0]:
        grip_model.box("IntakeGripJaw",Vector3(sign*0.30,-0.08,0),Vector3(0.06,0.24,0.21),"edge")
    var grip: Visual = _direct_visual(grip_model,"intake_grip","IntakeGrip_"+key)
    _intakes[key] = {"target":target,"rail_y":rail_y,"start":start,"end":end,
        "trolley":trolley,"hoist":hoist,"grip":grip}
    _apply_visual_pose(trolley,_pose(start),true)
    _apply_visual_pose(hoist,Transform3D.IDENTITY,false)
    _apply_visual_pose(grip,Transform3D.IDENTITY,false)

func _intake_pose(record: Dictionary, cargo_at: Vector3, yaw: float, shown: bool) -> void:
    var top := Vector3(cargo_at.x,float(record["rail_y"]),cargo_at.z)
    var grip_at: Vector3 = cargo_at+Vector3.UP*0.37
    _apply_visual_pose(record["trolley"],_pose(top,yaw),true)
    _apply_visual_pose(record["hoist"],_segment(top,grip_at),shown)
    _apply_visual_pose(record["grip"],_pose(grip_at,yaw),shown)

func _feed_stock(t: Truck, dt: float) -> void:
    var key: String = t.destination if t.leg == 1 else "STORAGE"
    var d: Dock = _dock_for(t)
    var r: Dictionary = _intakes[key]
    t.clock += dt
    var i: int = mini(1,floori(t.clock/INTAKE_ITEM_TIME))
    var phase: float = minf(INTAKE_ITEM_TIME,t.clock-float(i)*INTAKE_ITEM_TIME)
    var rack: Vector3 = _rack_slot(d,i)
    var mouth: Vector3 = r["target"]
    var high: float = float(r["rail_y"])-0.65
    var above_rack := Vector3(rack.x,high,rack.z)
    var above_mouth := Vector3(mouth.x,high,mouth.z)
    var at: Vector3 = rack
    var visible: bool = true
    var lift: float = RACK_Y
    if phase < 0.55:
        lift = lerpf(RACK_Y-0.48,RACK_Y,smoothstep(0.0,0.55,phase))
        at.y = lift
    elif phase < 1.35:
        at = rack.lerp(above_rack,smoothstep(0.55,1.35,phase))
    elif phase < 2.45:
        at = above_rack.lerp(above_mouth,smoothstep(1.35,2.45,phase))
    elif phase < 3.15:
        at = above_mouth.lerp(mouth,smoothstep(2.45,3.15,phase))
    elif phase < 3.65:
        at = mouth
    elif phase < 4.1:
        at = mouth.lerp(above_mouth,smoothstep(3.65,4.1,phase))
        visible = false
    else:
        at = above_mouth.lerp(above_rack,smoothstep(4.1,5.0,phase))
        visible = false
    _buffer_pose(d,i,lift,1.0-smoothstep(0.55,1.35,phase))
    var pose: Transform3D = _pose(at,d.yaw)
    if key != "STORAGE" and phase >= 3.15 and phase < 3.65:
        pose.basis = pose.basis * Basis(Vector3.RIGHT,1.1*smoothstep(3.15,3.55,phase))
    _apply_visual_pose(t.cargo[i],pose,visible)
    for j in range(t.cargo.size()):
        if j != i:
            _apply_visual_pose(t.cargo[j],_pose(_rack_slot(d,j),d.yaw),false)
    _intake_pose(r,at,d.yaw,phase < 4.99)
    if t.clock >= INTAKE_ITEM_TIME*2.0:
        for j in range(2):
            _buffer_pose(d,j,RACK_Y-0.48,0.0)
            _apply_visual_pose(t.cargo[j],Transform3D.IDENTITY,false)
        _intake_pose(r,Vector3(rack.x,high,rack.z),d.yaw,false)
        var motion: Node = _facility_motion.get(key)
        if is_instance_valid(motion):
            motion.call("begin_material_cycle")
        t.mode = "process_stock"
        t.clock = 0.0


func _xz(v: Vector3) -> Vector2:
    return Vector2(v.x, v.z)

func _v3(v: Vector2, y: float = 0.0) -> Vector3:
    return Vector3(v.x, y, v.y)

func _point(cell: Variant) -> Vector2:
    return cell if cell is Vector2 else Vector2(cell) * CELL

func _cell(p: Vector2) -> Vector2i:
    return Vector2i(roundi(p.x / CELL), roundi(p.y / CELL))

func _free(c: Vector2i) -> bool:
    return REGION.has_point(c) and not _grid.is_point_solid(c)

func _block_circle(p: Vector2, radius: float, changed: Array[Vector2i] = []) -> void:
    var c: Vector2i = _cell(p)
    var n: int = ceili(radius / CELL) + 1
    for x in range(c.x - n, c.x + n + 1):
        for z in range(c.y - n, c.y + n + 1):
            var q := Vector2i(x, z)
            if _free(q) and _point(q).distance_to(p) <= radius:
                _grid.set_point_solid(q, true)
                changed.append(q)

func _block_rect(origin: Vector2, yaw: float, local: Vector2, half: Vector2) -> void:
    var turn := Basis(Vector3.UP, yaw)
    var inverse: Basis = turn.inverse()
    var center: Vector2 = origin + _xz(turn * _v3(local))
    var c: Vector2i = _cell(center)
    var n: int = ceili((half.length() + CLEARANCE) / CELL) + 1
    for x in range(c.x - n, c.x + n + 1):
        for z in range(c.y - n, c.y + n + 1):
            var q := Vector2i(x, z)
            var offset: Vector2 = _xz(inverse * _v3(_point(q) - center))
            if REGION.has_point(q) and absf(offset.x) <= half.x + CLEARANCE and absf(offset.y) <= half.y + CLEARANCE:
                _grid.set_point_solid(q, true)

func _obstacles(root: Node3D, sites: Array, power: Node3D, crate_path: Array) -> void:
    _grid.region = REGION
    _grid.cell_size = Vector2.ONE * CELL
    _grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    _grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
    _grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
    _grid.update()
    for spec in sites:
        var key: String = str(spec["id"])
        var at: Vector2 = _xz(spec["at"])
        var yaw: float = Architecture.facility_yaw_radians(key)
        _block_rect(at, yaw, Vector2.ZERO, Power._footprint(key))
        if key == "NEXUS":
            _block_rect(at, yaw, Vector2(0, 3.2), Vector2(3.8, 1.7))
        if key == "SCRAP_COLLECTOR":
            # Incoming conveyor is 1.55x authored scale; its guards count.
            _block_rect(at, yaw, Vector2(-5.25, 1.98), Vector2(3.8, 1.65))
    # The power network is already fixed. Only solid cabinets block traffic;
    # cables remain traversable and are reserved separately for stationary props.
    if is_instance_valid(power):
        for value in power.get_meta("logistics_obstacles", []):
            var center: Vector2 = value
            _block_circle(center, 0.83 + CLEARANCE)
            _expand_cell(_power_cells, _cell(center))
        _reserve_fixed_cables(power)
    # Loose decorative props and salvage are generated after logistics.
    _block_rect(Vector2(35.5, -20.0), 0.0, Vector2.ZERO, Vector2(5.8, 5.8))
    # CRATE's established patrol remains untouched. Keep its whole corridor free.
    for i in range(crate_path.size()):
        var a: Vector2 = crate_path[i]
        var b: Vector2 = crate_path[(i + 1) % crate_path.size()]
        var count: int = maxi(1, ceili(a.distance_to(b) / 0.35))
        for j in range(count + 1):
            _block_circle(a.lerp(b, float(j) / count), 1.0)

func _reserve_fixed_cables(power: Node3D) -> void:
    for record in power.get_meta("cable_paths", []):
        var points: PackedVector3Array = record["points"]
        for i in range(1, points.size()):
            var a: Vector2 = _xz(points[i - 1])
            var b: Vector2 = _xz(points[i])
            var steps: int = maxi(1, ceili(a.distance_to(b) / (CELL * 0.35)))
            for j in range(steps + 1):
                _cable_cells[_cell(a.lerp(b, float(j) / float(steps)))] = true


func _cable_clear_station(p: Vector2, radius: float) -> bool:
    return not _rect_hits(_cable_cells, Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))


func _screen_penalty(p: Vector2) -> float:
    if not is_instance_valid(_camera):
        return 0.0
    var cell: Vector2i = _cell(p)
    if _screen_costs.has(cell):
        return float(_screen_costs[cell])
    var rect: Rect2 = _camera.get_viewport().get_visible_rect()
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return 0.0
    var uv: Vector2 = (_camera.unproject_position(_v3(p, 0.4)) - rect.position) / rect.size
    if not _camera.is_position_behind(_v3(p, 0.4)) and uv.x >= 0.07 and uv.x <= 0.93 and uv.y >= 0.10 and uv.y <= 0.90:
        _screen_costs[cell] = 0.0
        return 0.0
    var cost: float = 25.0 + (uv - Vector2(0.5, 0.5)).length() * 10.0
    _screen_costs[cell] = cost
    return cost


func _find_network_anchor(budget: Variant = null) -> void:
    if _free(_network_anchor):
        return
    for z in range(REGION.position.y + 1, REGION.end.y - 1):
        if budget != null:
            await budget.checkpoint("network anchor")
        for x in [REGION.position.x + 1, REGION.end.x - 2]:
            var c := Vector2i(x, z)
            if _free(c):
                _network_anchor = c
                return


func _find_dock(key: String, at: Vector2, budget: Variant = null) -> Dock:
    var forward: Vector2 = _xz(Basis(Vector3.UP, Architecture.facility_yaw_radians(key)) * Vector3.BACK)
    var candidates: Array[Dictionary] = []
    var base_cell: Vector2i = _cell(at)
    # Choose the closest clear three-part work cell in the service apron.
    # All racks/pedestals and vehicle centers are disjoint from authored props.
    for dx in range(-17, 18):
        if budget != null:
            await budget.checkpoint("dock candidates")
        for dz in range(-17, 18):
            var c: Vector2i = base_cell + Vector2i(dx, dz)
            if not _free(c):
                continue
            var offset: Vector2 = _point(c) - at
            var length: float = offset.length()
            if length < 2.4 or length > 12.0:
                continue
            # Flat loading positions are selected away from fixed cords.
            if not _cable_clear_station(_point(c), 1.0):
                continue
            for direction in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
                var along: Vector2i = direction
                var lateral := Vector2i(along.y, -along.x)
                for sign_value in [-1, 1]:
                    var side: Vector2i = lateral * int(sign_value)
                    var stage_cell: Vector2i = c + side * 2
                    var pivot_cell: Vector2i = c + side + along
                    if not _free(stage_cell) or not _free(pivot_cell) or not _free(c + along) or not _free(c - along):
                        continue
                    if not _free(stage_cell + along) or not _free(stage_cell - along) or not _free(stage_cell + side):
                        continue
                    if not _cable_clear_station(_point(stage_cell), 0.75) or not _cable_clear_station(_point(pivot_cell), 0.30) or not _cable_clear_station(_point(stage_cell + side), 0.45):
                        continue
                    var separated: bool = true
                    for old_value in _docks.values():
                        var old: Dock = old_value
                        if _point(c).distance_to(_point(old.cell)) < 2.7 or _point(stage_cell).distance_to(_point(old.cell)) < 2.4 or _point(pivot_cell).distance_to(_point(old.cell)) < 2.1:
                            separated = false
                            break
                    if not separated:
                        continue
                    var score: float = length + (1.0 - offset.normalized().dot(forward)) * 2.8
                    # Prefer the rack on the facility side and the dock facing
                    # along its open service apron; no arbitrary visual shift.
                    score += (_point(stage_cell).distance_to(at) - length) * 0.45
                    score += _screen_penalty(_point(c)) * 0.45
                    candidates.append({"score": score, "cell": c,
                        "stage": _point(stage_cell), "pivot": _point(pivot_cell),
                        "yaw": atan2(float(along.x), float(along.y)),
                        "side": float(sign_value)})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
    for candidate_index in range(mini(160, candidates.size())):
        if budget != null:
            await budget.checkpoint("dock connectivity")
        var choice: Dictionary = candidates[candidate_index]
        var result := Dock.new()
        result.cell = choice["cell"]
        result.stage = choice["stage"]
        result.pivot = choice["pivot"]
        result.yaw = choice["yaw"]
        result.hatch_side = choice["side"]
        var changed: Array[Vector2i] = []
        _block_circle(result.stage, 0.72 + CLEARANCE, changed)
        var slide: Vector2 = _xz(Basis(Vector3.UP, result.yaw) * Vector3(0.74 * result.hatch_side, 0, 0))
        _block_circle(result.stage + slide, 0.47 + CLEARANCE, changed)
        _block_circle(result.pivot, 0.23 + CLEARANCE, changed)
        _grid.set_point_solid(result.cell, false)
        var connected: bool = _free(_network_anchor)
        if connected:
            connected = not _grid.get_id_path(_network_anchor, result.cell).is_empty()
        if connected:
            for old_value in _docks.values():
                var old: Dock = old_value
                if not _free(old.cell) or _grid.get_id_path(_network_anchor, old.cell).is_empty():
                    connected = false
                    break
        if connected:
            return result
        for c in changed:
            _grid.set_point_solid(c, false)
    return null


func _parking_options(origin: Vector2, destination: Vector2, budget: Variant = null) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var direction: Vector2 = (destination - origin).normalized()
    for z in range(REGION.position.y + 1, REGION.end.y - 1):
        if budget != null:
            await budget.checkpoint("parking search")
        for x in range(REGION.position.x + 1, REGION.end.x - 1):
            var c := Vector2i(x, z)
            if not _free(c) or _route_parking_exclusion.has(c):
                continue
            var p: Vector2 = _point(c)
            var d: float = p.distance_to(origin)
            if d < 2.0 or not _cable_clear_station(p, 0.65):
                continue
            var ok: bool = true
            for dock_value in _docks.values():
                var dock: Dock = dock_value
                if p.distance_to(_point(dock.cell)) < 2.7:
                    ok = false
                    break
            if not ok:
                continue
            for h in _homes:
                if p.distance_to(_point(h)) < 2.35:
                    ok = false
                    break
            if not ok:
                continue
            var exits: int = 0
            for offset_value in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                var offset: Vector2i = offset_value
                if _free(c + offset):
                    exits += 1
            if exits < 2:
                continue
            var score: float = d + absf((p - origin).normalized().dot(direction)) * 1.9 + _screen_penalty(p)
            result.append({"cell": c, "score": score})
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
    return result


func _keep_parking_clear(t: Truck) -> void:
    # Preserve the original 1.51m parked-truck separation along the new
    # shortcut segments, not just at their endpoints.
    for leg in t.legs:
        for i in range(1, leg.size()):
            for c in _trace(leg[i - 1], leg[i], false):
                for x in range(-2, 3):
                    for z in range(-2, 3):
                        if Vector2(x, z).length() * CELL < 1.51:
                            _route_parking_exclusion[c + Vector2i(x, z)] = true


func _expand_cell(target: Dictionary, c: Vector2i) -> void:
    # The 1.13 x 1.56m chassis uses a conservative neighboring ring.
    # Additional clearance for diagonal turns is reserved by trace sampling.
    for x in range(-1, 2):
        for z in range(-1, 2):
            target[c + Vector2i(x, z)] = true

# Greedy line-of-sight shortcutting on the already inflated obstacle grid.
# Sample the full segment, including diagonal corner crossings, before
# accepting it. Reservations are generated from these same swept segments.
func _trace(a: Variant, b: Variant, require_clear: bool = true) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    var start_point: Vector2 = _point(a)
    var end_point: Vector2 = _point(b)
    var steps: int = maxi(1, ceili(start_point.distance_to(end_point) / (CELL * 0.20)))
    var previous: Vector2i = _cell(start_point)
    for i in range(steps + 1):
        var c: Vector2i = _cell(start_point.lerp(end_point, float(i) / float(steps)))
        if require_clear and not _free(c):
            return []
        if c != previous and c.x != previous.x and c.y != previous.y:
            var side_a := Vector2i(c.x, previous.y)
            var side_b := Vector2i(previous.x, c.y)
            if require_clear and (not _free(side_a) or not _free(side_b)):
                return []
            result.append(side_a)
            result.append(side_b)
        if result.is_empty() or c != previous:
            result.append(c)
        previous = c
    return result


func _straighten(path: Array[Vector2i], budget: Variant = null) -> Array[Vector2i]:
    if path.size() < 3:
        return path
    var output: Array[Vector2i] = [path[0]]
    var i: int = 0
    while i < path.size() - 1:
        var next: int = i + 1
        for j in range(path.size() - 1, i + 1, -1):
            if budget != null:
                await budget.checkpoint("route shortcut")
            if not _trace(path[i], path[j]).is_empty():
                next = j
                break
        output.append(path[next])
        i = next
    return output


# Check each generated bend and retry with smaller radii before accepting.
func _rounded(path: Array[Vector2i], budget: Variant = null) -> Array[Vector2]:
    var result: Array[Vector2] = [_point(path[0])]
    for i in range(1, path.size() - 1):
        if budget != null:
            await budget.checkpoint("route curve")
        var prev: Vector2 = _point(path[i - 1])
        var corner: Vector2 = _point(path[i])
        var next: Vector2 = _point(path[i + 1])
        var incoming: Vector2 = (corner - prev).normalized()
        var outgoing: Vector2 = (next - corner).normalized()
        var radius: float = minf(2.6, minf(prev.distance_to(corner), corner.distance_to(next)) * 0.42)
        var accepted: bool = false
        if incoming.dot(outgoing) < 0.995:
            for factor in [1.0, 0.75, 0.5, 0.25]:
                var distance: float = radius * float(factor)
                if distance < 0.09:
                    continue
                var entry: Vector2 = corner - incoming * distance
                var exit: Vector2 = corner + outgoing * distance
                if _trace(result[-1], entry).is_empty():
                    continue
                var samples: Array[Vector2] = [entry]
                var steps: int = maxi(5, ceili(distance * 2.0 / 0.20))
                var clear: bool = true
                for j in range(1, steps + 1):
                    var fraction: float = float(j) / float(steps)
                    var point: Vector2 = entry.lerp(corner, fraction).lerp(corner.lerp(exit, fraction), fraction)
                    if _trace(samples[-1], point).is_empty():
                        clear = false
                        break
                    samples.append(point)
                if clear and not _trace(exit, next).is_empty():
                    result.append_array(samples)
                    accepted = true
                    break
        if not accepted:
            result.append(corner)
    result.append(_point(path[-1]))
    for i in range(1, result.size()):
        if _trace(result[i - 1], result[i]).is_empty():
            result.clear()
            for cell in path:
                result.append(_point(cell))
            break
    return result


func _record_leg(t: Truck, leg: Array[Vector2], budget: Variant = null) -> void:
    var all: Dictionary = {}
    var segments: Array[Dictionary] = []
    for i in range(1, leg.size()):
        if budget != null:
            await budget.checkpoint("route swept reservation")
        var swept: Dictionary = {}
        for c in _trace(leg[i - 1], leg[i], false):
            _expand_cell(swept, c)
        segments.append(swept)
        all.merge(swept, true)
    t.leg_cells.append(all)
    t.segment_cells.append(segments)
    t.cells.merge(all, true)


func _plan(t: Truck, commit_weights: bool = true, budget: Variant = null) -> bool:
    t.legs.clear()
    t.leg_cells.clear()
    t.segment_cells.clear()
    t.cells.clear()
    var temporarily_blocked: Array[Vector2i] = []
    for h in _homes:
        if h == t.home:
            continue
        for x in range(-2, 3):
            for z in range(-2, 3):
                var c: Vector2i = h + Vector2i(x, z)
                if _free(c) and _point(c).distance_to(_point(h)) < 1.51:
                    _grid.set_point_solid(c, true)
                    temporarily_blocked.append(c)
    var source: Dock = _docks[t.source]
    var destination: Dock = _docks[t.destination]
    var a: Array[Vector2i] = _grid.get_id_path(t.home, source.cell)
    if budget != null:
        await budget.checkpoint("AStar home to source")
    var b: Array[Vector2i] = _grid.get_id_path(source.cell, destination.cell)
    if budget != null:
        await budget.checkpoint("AStar source to facility")
    # Give the empty return its own lane when there is any sensible alternative.
    var previous_weights: Dictionary = {}
    for c in b:
        if c != source.cell and c != destination.cell:
            previous_weights[c] = _grid.get_point_weight_scale(c)
            _grid.set_point_weight_scale(c, float(previous_weights[c]) + 0.35)
    var storage: Dock = _docks["STORAGE"]
    var c_path: Array[Vector2i] = _grid.get_id_path(destination.cell, storage.cell)
    if budget != null:
        await budget.checkpoint("AStar facility to storage")
    var d_path: Array[Vector2i] = _grid.get_id_path(storage.cell, t.home)
    if budget != null:
        await budget.checkpoint("AStar storage to home")
    for c in previous_weights:
        _grid.set_point_weight_scale(c, float(previous_weights[c]))
    var valid: bool = a.size() >= 2 and b.size() >= 2 and c_path.size() >= 2 and d_path.size() >= 2
    if valid:
        # Keep the parking obstacles active during shortcutting as well.
        for raw_path in [a, b, c_path, d_path]:
            var straight: Array[Vector2i] = await _straighten(raw_path, budget)
            var rounded: Array[Vector2] = await _rounded(straight, budget)
            t.legs.append(rounded)
        for leg_value in t.legs:
            var leg: Array[Vector2] = leg_value
            await _record_leg(t, leg, budget)
    for c in temporarily_blocked:
        _grid.set_point_solid(c, false)
    if not valid:
        return false
    if commit_weights:
        await _commit_road_weights(t, budget)
    return true


func _commit_road_weights(t: Truck, budget: Variant = null) -> void:
    # A modest preference for distinct streets, without lengthy detours.
    for leg in t.legs:
        for i in range(1, leg.size()):
            if budget != null:
                await budget.checkpoint("route weights")
            for c in _trace(leg[i - 1], leg[i], false):
                if _free(c):
                    _grid.set_point_weight_scale(c, minf(1.6, _grid.get_point_weight_scale(c) + 0.07))


func _route_score(t: Truck) -> float:
    var score: float = 0.0
    for leg in t.legs:
        for i in range(1, leg.size()):
            score += _point(leg[i - 1]).distance_to(_point(leg[i]))
    for previous in _trucks:
        for c in t.cells:
            if previous.cells.has(c):
                score += 0.018
    return score


# The layout drawing is the only source of dock and driving coordinates.
# Reservation grids are used for traffic occupancy and decor, NOT routing.
func setup(_root: Node3D, _nexus_origin: Vector3, _specs: Array, power: Node3D, _crate_path: Array, camera: Camera3D = null, budget: Variant = null) -> void:
    _camera = camera
    _phase = "FIXED_LAYOUT"
    if is_instance_valid(power):
        for value in power.get_meta("logistics_obstacles", []):
            var center: Vector2 = value
            _expand_cell(_power_cells, _cell(center))
        _reserve_fixed_cables(power)
    for key in FixedLayout.DOCKS:
        var spec: Array = FixedLayout.DOCKS[key]
        var center: Vector2 = spec[0]
        var side: Vector2 = spec[1]
        var forward: Vector2 = spec[2]
        var d := Dock.new()
        d.cell = _cell(center)
        d.stage = center + side * 1.65
        d.pivot = center + side * 0.98 + forward * 0.85
        d.yaw = atan2(forward.x,forward.y)
        var right := Vector2(forward.y,-forward.x)
        d.hatch_side = signf(side.dot(right))
        _docks[key] = d
    for route in ROUTES:
        for i in range(VEHICLES_PER_ROUTE):
            var t := Truck.new()
            t.id = _trucks.size()
            t.source = route[0]
            t.destination = route[1]
            t.raw = true
            var home: Vector2 = FixedLayout.QUEUE_ENTRY
            t.home = _cell(home)
            t.pos = home
            t.yaw = 0.0
            t.wait = 0.0
            t.legs = FixedLayout.road_legs(t.destination,t.id)
            for leg_value in t.legs:
                var leg: Array[Vector2] = leg_value
                await _record_leg(t,leg,budget)
            _homes.append(t.home)
            _trucks.append(t)
            if budget != null:
                await budget.checkpoint("authored logistics route")
    _planned_count = _trucks.size()
    _seed_active_deliveries()
    _capture_reservations()
    _phase = "PLANNED"
    print("SERA_BASE_LOGISTICS: fixed layout, docks=",_docks.size()," vehicles=",_trucks.size())


# Separate public entrypoints: if the routing call terminates early, the
# BASE can still draw the successfully allocated vehicles and report why.
func ensure_parked_fleet(_specs: Array, _budget: Variant = null) -> void:
    # Admit only complete operating loops, not permanently parked props.
    _capture_reservations()


func build_carriers(budget: Variant = null) -> void:
    var previous_phase: String = _phase
    _phase = "CARRIER_DRAW"
    _batch = Architecture.Batch.new(self)
    # Chassis for every allocated vehicle before cargo or articulated docks.
    for t in _trucks:
        _make_chassis(t)
        _truck_pose(t)
        if budget != null:
            await budget.checkpoint("carrier model")
        elif t.id % 4 == 3:
            await get_tree().process_frame
    _phase = "CARGO_DRAW"
    for t in _trucks:
        _make_truck_details(t)
        _truck_pose(t)
        if budget != null:
            await budget.checkpoint("carrier model")
        elif t.id % 4 == 3:
            await get_tree().process_frame
    _phase = "CARRIERS" if previous_phase == "PLANNED" else previous_phase + "/CARRIERS"
    print("SERA_BASE_LOGISTICS: direct chassis=", _vehicle_count, " cargo=", _cargo_count)


func build_docks_and_motion(budget: Variant = null) -> void:
    var previous_phase: String = _phase
    _phase = "DOCK_DRAW"
    if _batch == null:
        _batch = Architecture.Batch.new(self)
    for dock in _docks.values():
        if budget != null:
            await budget.checkpoint("dock model")
        _make_dock(dock)
    # Bake actual world transforms before creating renderers.
    for v in _visuals:
        if budget != null:
            await budget.checkpoint("dock transforms")
        var transform: Transform3D = _visible_transform(v)
        for key in v.slots:
            var record: Dictionary = v.slots[key]
            var local: Array = record["local"]
            var dest: Array = _batch.entries[key]
            var first: int = int(record["start"])
            for i in range(local.size()):
                dest[first + i] = transform * (local[i] as Transform3D)
    if budget != null:
        await _batch.flush(budget)
    else:
        await _batch.flush()
    for child in get_children():
        if child is MultiMeshInstance3D:
            var draw: MultiMeshInstance3D = child
            for key in _batch.entries:
                var parts: PackedStringArray = str(key).split("|")
                if str(draw.name) == "Architectural_" + parts[0] + "_" + parts[1]:
                    _draws[key] = draw.multimesh
                    draw.multimesh.custom_aabb = AABB(Vector3(-36, -1, -36), Vector3(72, 6, 72))
                    draw.set_meta("sera_preserve_authored_material", true)
                    if parts[1] == "caution":
                        (draw.material_override as StandardMaterial3D).albedo_color = Color("#e7b637")
                    break
    print("SERA_BASE_LOGISTICS: render_buckets=", _draws.size(), "/", _batch.entries.size())
    _flush_poses()
    _ready_for_motion = previous_phase == "CARRIERS" and _vehicle_count == _trucks.size() and _cargo_count == _vehicle_count * 2
    _phase = "READY" if _ready_for_motion else previous_phase + "/STOP"


func diagnostic_text() -> String:
    var projected: int = 0
    if is_instance_valid(_camera):
        var view: Rect2 = _camera.get_viewport().get_visible_rect()
        for t in _trucks:
            if t.body == null or not is_instance_valid(t.body.node):
                continue
            var p: Vector3 = t.body.node.global_position + Vector3.UP * 0.4
            if t.body.node.is_visible_in_tree() and not _camera.is_position_behind(p) and view.has_point(_camera.unproject_position(p)):
                projected += 1
    var driving: int = 0
    var handling: int = 0
    var waiting: int = 0
    for t in _trucks:
        if t.mode == "drive" and t.traffic_blocked:
            waiting += 1
        elif t.mode == "drive":
            driving += 1
        elif t.mode in ["align","load","unload","feed_stock","process_stock"]:
            handling += 1
    return "物流 %s\n車体 %d/%d  経路 %d\n画面内 %d  貨物 %d\n走行 %d  荷役 %d  譲合 %d\nドック %d" % [
        _phase, _vehicle_count, FLEET_SIZE, _planned_count, projected, _cargo_count, driving, handling, waiting, _docks.size()]


func _capture_reservations() -> void:
    for t in _trucks:
        _reserved.merge(t.cells, true)
        _road_cells.merge(t.cells, true)
        _expand_cell(_reserved, t.home)
    for dock_value in _docks.values():
        var d: Dock = dock_value
        for center in [_point(d.cell), d.stage, d.pivot,
                d.stage + _xz(Basis(Vector3.UP, d.yaw) * Vector3(d.hatch_side * 0.74, 0, 0))]:
            _expand_cell(_reserved, _cell(center))


func _rect_hits(cells: Dictionary, bounds: Rect2) -> bool:
    var area: Rect2 = bounds.grow(CELL * 0.5)
    var lo := Vector2i(ceili(area.position.x / CELL), ceili(area.position.y / CELL))
    var hi := Vector2i(floori(area.end.x / CELL), floori(area.end.y / CELL))
    for x in range(lo.x, hi.x + 1):
        for z in range(lo.y, hi.y + 1):
            if cells.has(Vector2i(x, z)):
                return true
    return false


func placement_clear(bounds: Rect2) -> bool:
    var padded: Rect2 = bounds.grow(0.12)
    if _rect_hits(_reserved, padded) or _rect_hits(_power_cells, padded) or _rect_hits(_cable_cells, padded):
        return false
    for rect in _protector_bounds:
        if rect.intersects(padded):
            return false
    return true


func road_segments() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for t in _trucks:
        for leg in t.legs:
            for i in range(1, leg.size()):
                result.append({"a": _point(leg[i - 1]), "b": _point(leg[i])})
    return result


func road_at(p: Vector2) -> bool:
    return _rect_hits(_road_cells, Rect2(p - Vector2.ONE * 0.22, Vector2.ONE * 0.44))


func power_device_clear(p: Vector2) -> bool:
    return placement_clear(Rect2(p - Vector2.ONE * 0.88, Vector2.ONE * 1.76))


func cable_dock_obstacles() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for dock_value in _docks.values():
        var d: Dock = dock_value
        for p in [_point(d.cell), d.stage, d.pivot]:
            result.append({"at": p, "radius": 0.9})
    return result


func set_ramp_surface(surface: Node3D) -> void:
    _ramp_surface = surface
    _protector_bounds.clear()
    if is_instance_valid(surface):
        _protector_bounds.assign(surface.call("placement_bounds"))
        for t in _trucks:
            _truck_pose(t)
        _flush_poses()


func _ground_height(p: Vector2) -> float:
    if is_instance_valid(_ramp_surface):
        return float(_ramp_surface.call("height_at", p))
    return 0.0


func _seed_active_deliveries() -> void:
    # The six positions are authored on separate working segments, not
    # selected from a row of parking spaces or assigned from the camera.
    for t in _trucks:
        var spec: Array = FixedLayout.START_PHASES[t.id]
        var leg: int = int(spec[0])
        var desired: Vector2 = spec[1]
        var path: Array = t.legs[leg]
        var best: float = INF
        var chosen: int = 1
        var seed: Vector2 = _point(path[0])
        for i in range(1,path.size()):
            var start: Vector2 = _point(path[i-1])
            var end: Vector2 = _point(path[i])
            if start.distance_squared_to(end) < 0.000001:
                continue
            var point: Vector2 = Geometry2D.get_closest_point_to_segment(desired,start,end)
            var score: float = point.distance_squared_to(desired)
            if score < best:
                best = score
                chosen = i
                seed = point
        t.leg = leg
        t.waypoint = chosen
        t.pos = seed
        var direction: Vector2 = (_point(path[chosen])-_point(path[chosen-1])).normalized()
        t.yaw = atan2(direction.x,direction.y)
        t.loaded = leg in [1,2]
        t.raw = leg != 2
        t.mode = "drive"
        t.speed = SPEED * 0.7
        t.wait = 0.0


func _template() -> Variant:
    return Architecture.Batch.new(self)

func _visual(g: Variant) -> Visual:
    var v := Visual.new()
    for key in g.entries:
        if not _batch.entries.has(key):
            _batch.entries[key] = []
        var dest: Array = _batch.entries[key]
        var local: Array = g.entries[key]
        v.slots[key] = {"start": dest.size(), "local": local}
        for pose in local:
            dest.append(pose)
    _visuals.append(v)
    return v

func _apply_visual_pose(v: Visual, pose: Transform3D, shown: bool = true) -> void:
    if v == null:
        return
    if v.pose != pose or v.shown != shown:
        v.pose = pose
        v.shown = shown
        v.dirty = true
        if is_instance_valid(v.node):
            v.node.transform = pose
            v.node.visible = shown

func _pose(p: Vector3, yaw: float = 0.0) -> Transform3D:
    return Transform3D(Basis(Vector3.UP, yaw), p)

func _visible_transform(v: Visual) -> Transform3D:
    return v.pose if v.shown else Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3(0, -10, 0))


func _flush_poses() -> void:
    for v in _visuals:
        if not v.dirty:
            continue
        var transform: Transform3D = _visible_transform(v)
        for key in v.slots:
            if not _draws.has(key):
                continue
            var multi: MultiMesh = _draws[key]
            var record: Dictionary = v.slots[key]
            var local: Array = record["local"]
            var start: int = int(record["start"])
            for i in range(local.size()):
                multi.set_instance_transform(start + i, transform * (local[i] as Transform3D))
        v.dirty = false

# Bake the same authored vehicle parts into one real MeshInstance3D.
# No shared instance-slot lookup, hidden zero-scale matrices or custom AABB
# are involved in drawing a carrier or its two boxes.
func _primitive(kind: String) -> Mesh:
    if kind == "cube":
        var cube := BoxMesh.new()
        cube.size = Vector3.ONE
        return cube
    if kind == "tube":
        var tube := CylinderMesh.new()
        tube.top_radius = 0.5
        tube.bottom_radius = 0.5
        tube.height = 1.0
        tube.radial_segments = 8
        return tube
    return Polygon.make(kind)


func _bake_mesh(g: Variant) -> ArrayMesh:
    var mesh := ArrayMesh.new()
    for glowing in [false, true]:
        var vertices := PackedVector3Array()
        var normals := PackedVector3Array()
        var colors := PackedColorArray()
        var indices := PackedInt32Array()
        for key in g.entries:
            var parts: PackedStringArray = str(key).split("|")
            var kind: String = parts[0]
            var tint: String = parts[1]
            var luminous: bool = tint in ["blue_light", "amber_light", "amber", "lab_cyan"]
            if luminous != bool(glowing):
                continue
            var primitive: Mesh = _primitive(kind)
            if primitive == null:
                continue
            var color := Color(str(Architecture.COLORS.get(tint, "#9ba8b1")))
            if tint == "caution":
                color = Color("#e7b637")
            for surface_index in range(primitive.get_surface_count()):
                var arrays: Array = primitive.surface_get_arrays(surface_index)
                var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var source_normals := PackedVector3Array()
                if arrays[Mesh.ARRAY_NORMAL] != null:
                    source_normals = arrays[Mesh.ARRAY_NORMAL]
                var source_indices: PackedInt32Array = []
                if arrays[Mesh.ARRAY_INDEX] != null:
                    source_indices = arrays[Mesh.ARRAY_INDEX]
                for local_value in g.entries[key]:
                    var local: Transform3D = local_value
                    var normal_basis: Basis = local.basis.inverse().transposed()
                    var first: int = vertices.size()
                    for j in range(source_vertices.size()):
                        vertices.append(local * source_vertices[j])
                        normals.append((normal_basis * source_normals[j]).normalized() if j < source_normals.size() else Vector3.UP)
                        colors.append(color)
                    if source_indices.is_empty():
                        for j in range(source_vertices.size()):
                            indices.append(first + j)
                    else:
                        for j in source_indices:
                            indices.append(first + j)
        if vertices.is_empty():
            continue
        var output: Array = []
        output.resize(Mesh.ARRAY_MAX)
        output[Mesh.ARRAY_VERTEX] = vertices
        output[Mesh.ARRAY_NORMAL] = normals
        output[Mesh.ARRAY_COLOR] = colors
        output[Mesh.ARRAY_INDEX] = indices
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output)
        var material := StandardMaterial3D.new()
        material.albedo_color = Color.WHITE
        material.vertex_color_use_as_albedo = true
        material.vertex_color_is_srgb = true
        material.metallic = 0.18
        material.roughness = 0.82
        if glowing:
            material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mesh.surface_set_material(mesh.get_surface_count() - 1, material)
    return mesh


func _direct_visual(g: Variant, cache_key: String, label: String) -> Visual:
    if not _solid_meshes.has(cache_key):
        _solid_meshes[cache_key] = _bake_mesh(g)
    var mesh: ArrayMesh = _solid_meshes[cache_key]
    var v := Visual.new()
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = mesh
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.set_meta("sera_outline_role", "clutter")
    draw.set_meta("sera_preserve_authored_material", true)
    add_child(draw)
    v.node = draw
    return v


func _make_chassis(t: Truck) -> void:
    var g: Variant = _template()
    # Thin steel flatbed, independent crawler pods, front-facing sensor.
    g.poly("CarrierDeck", "bevel", Vector3(0, 0.32, 0), Vector3(0.94, 0.14, 1.30), "slate")
    g.box("CarrierUnderside", Vector3(0, 0.20, 0), Vector3(0.53, 0.18, 1.02), "dark")
    for s in [-1.0, 1.0]:
        var x: float = s * 0.34
        g.poly("CarrierTrackBelt", "bevel", Vector3(x, 0.13, 0), Vector3(0.24, 0.32, 1.17), "rubber")
        for z in [-0.40, -0.13, 0.13, 0.40]:
            g.poly_tilt("CarrierRoller", "drum", Vector3(s * 0.468, 0.13, z), Vector3(0.22, 0.055, 0.22), "edge", Vector3(0, 0, PI * 0.5))
        g.box("CarrierSideRail", Vector3(s * 0.47, 0.29, 0), Vector3(0.035, 0.10, 1.12), "trim")
        g.box("CarrierHeadlamp", Vector3(s * 0.34, 0.33, 0.66), Vector3(0.16, 0.055, 0.035), "blue_light")
        g.box("CarrierRearReflector", Vector3(s * 0.35, 0.30, -0.66), Vector3(0.13, 0.055, 0.035), "amber")
        for z in [-0.48, 0.48]:
            g.box("CarrierLashingCleat", Vector3(s * 0.44, 0.40, z), Vector3(0.07, 0.065, 0.11), "edge")
    g.poly("CarrierSensorHousing", "bevel", Vector3(0, 0.23, 0.67), Vector3(0.32, 0.22, 0.13), "slate")
    g.poly_tilt("CarrierSensorLens", "drum", Vector3(0, 0.23, 0.75), Vector3(0.15, 0.045, 0.15), "blue_light", Vector3(PI * 0.5, 0, 0))
    for i in range(3):
        g.box_tilt("CarrierWarningStripe", Vector3(-0.28 + i * 0.12, 0.35, -0.655), Vector3(0.07, 0.07, 0.02), "dark", Vector3(0, 0, -0.45))
    t.body = _direct_visual(g, "chassis", "Carrier_%02d" % t.id)
    if t.body.node.mesh != null and t.body.node.mesh.get_surface_count() > 0:
        _vehicle_count += 1
    else:
        push_error("SERA_BASE_LOGISTICS: carrier chassis mesh empty")


func _make_truck_details(t: Truck) -> void:
    # Eight top-return cleats on both crawlers: phase follows travelled metres.
    for i in range(8):
        var tread: Variant = _template()
        for s in [-1.0, 1.0]:
            tread.box("CarrierTreadCleat", Vector3(s * 0.35, 0.285, 0), Vector3(0.25, 0.027, 0.060), "edge")
        t.treads.append(_visual(tread))
    var go: Variant = _template()
    go.box("TrafficProceed", Vector3(0.0, 0.36, -0.66), Vector3(0.16, 0.06, 0.035), "blue_light")
    t.lamp_go = _visual(go)
    var wait: Variant = _template()
    wait.box("TrafficYield", Vector3(0.0, 0.36, -0.66), Vector3(0.16, 0.06, 0.035), "amber_light")
    t.lamp_wait = _visual(wait)
    for raw in [true, false]:
        for i in range(2):
            var mesh: ArrayMesh = _cargo_mesh(bool(raw), i, t.destination)
            if raw:
                t.raw_meshes.append(mesh)
            else:
                t.product_meshes.append(mesh)
    for i in range(2):
        var v := Visual.new()
        var draw := MeshInstance3D.new()
        draw.name = "CarrierCargo_%02d_%d" % [t.id, i]
        draw.mesh = t.raw_meshes[i] if t.raw else t.product_meshes[i]
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        draw.set_meta("sera_outline_role", "clutter")
        draw.set_meta("sera_preserve_authored_material", true)
        add_child(draw)
        v.node = draw
        _apply_visual_pose(v, Transform3D.IDENTITY, false)
        t.cargo.append(v)
        if draw.mesh != null and draw.mesh.get_surface_count() > 0:
            _cargo_count += 1


func _cargo_mesh(raw: bool, i: int, destination: String, variant: int = 0) -> ArrayMesh:
    var key: String = ("raw" if raw else destination+str(variant)) + str(i)
    if not _solid_meshes.has(key):
        var cargo: Variant = _template()
        if raw:
            # Exactly the BASE boxed-scrap construction, scaled for the deck.
            cargo.pivot = Vector3(0, -0.16, 0)
            Clutter._make_scrap_crate(cargo, Vector2.ZERO, 0.62, i, 7)
            for bucket in cargo.entries:
                var pieces: Array = cargo.entries[bucket]
                for j in range(pieces.size()):
                    var p: Transform3D = pieces[j]
                    p.origin.y += 0.083
                    pieces[j] = p
        else:
            cargo.poly("ProductPallet", "tray", Vector3(0,0.065,0), Vector3(0.58,0.13,0.56), "slate")
            for side in [-1.0,1.0]:
                cargo.box("ProductGripRail", Vector3(side*0.27,0.15,0), Vector3(0.045,0.19,0.53), "edge")
            match destination:
                "SMELTER":
                    for row in range(2):
                        for col in range(2):
                            cargo.poly("CastMetalIngot", "bevel", Vector3(-0.12+col*0.24,0.18,-0.13+row*0.26),
                                Vector3(0.22,0.15,0.24), "edge" if i==0 else "armor_light")
                "RECYCLER":
                    cargo.poly("RecoveredGear", "gear", Vector3(-0.12,0.19,-0.10),
                        Vector3(0.24,0.12,0.24), "edge")
                    cargo.box("RecoveredBoard", Vector3(0.13,0.15,0.10),Vector3(0.24,0.07,0.26), "blue")
                    for k in range(3):
                        cargo.box("BoardContact", Vector3(0.06+k*0.07,0.195,0.10),Vector3(0.03,0.03,0.15), "gold")
                    cargo.poly_tilt("RecoveredMotor", "drum", Vector3(0.12,0.21,-0.14),
                        Vector3(0.20,0.22,0.20), "armor_light", Vector3(0,0,PI*0.5))
                _:
                    var forms: Array[String] = ["vent_stack","gear","bevel","octagonal_slew"]
                    var colors: Array[String] = ["blue","edge","armor_light","gold"]
                    var k: int = posmod(variant,forms.size())
                    cargo.poly("FabricatedPart",forms[k],Vector3(0,0.23,0),
                        Vector3(0.44,0.31,0.43), colors[k])
        _solid_meshes[key] = _bake_mesh(cargo)
    return _solid_meshes[key]


func _cargo_kind(t: Truck, raw: bool) -> void:
    t.raw = raw
    if not raw and t.destination == "LABO" and _facility_motion.has("LABO"):
        var motion: Node = _facility_motion["LABO"]
        if is_instance_valid(motion) and motion.has_method("material_print_variant"):
            var variant: int = int(motion.call("material_print_variant"))
            for i in range(t.product_meshes.size()):
                t.product_meshes[i] = _cargo_mesh(false,i,t.destination,variant)
    for i in range(t.cargo.size()):
        t.cargo[i].node.mesh = t.raw_meshes[i] if raw else t.product_meshes[i]

func _make_dock(d: Dock) -> void:
    var fixed: Variant = _template()
    # Dedicated inbound/outbound stock buffer integrated with each facility's
    # service apron. Two recessed lift pockets and a separate SCARA pedestal.
    fixed.poly("LogisticsBufferBase", "bevel", Vector3(0, 0.055, 0), Vector3(0.76, 0.11, 1.45), "slate")
    for s in [-1.0, 1.0]:
        fixed.box("LogisticsBufferSide", Vector3(s * 0.37, 0.36, 0), Vector3(0.10, 0.58, 1.44), "armor")
        fixed.box("LogisticsBufferRim", Vector3(s * 0.37, 0.61, 0), Vector3(0.12, 0.07, 1.48), "caution")
        fixed.box("LogisticsBufferEnd", Vector3(0, 0.36, s * 0.71), Vector3(0.76, 0.58, 0.09), "armor_light")
    fixed.box("LogisticsBufferDivider", Vector3(0, 0.36, 0), Vector3(0.70, 0.48, 0.07), "trim")
    for z in [-0.68, 0.0, 0.68]:
        fixed.box("LogisticsHatchGuide", Vector3(d.hatch_side * 0.58, 0.64, z), Vector3(1.14, 0.07, 0.045), "trim")
    fixed.box("LogisticsBufferStatus", Vector3(0, 0.40, 0.765), Vector3(0.28, 0.07, 0.035), "blue_light")
    _apply_visual_pose(_visual(fixed), _pose(_v3(d.stage), d.yaw))
    var lift: Variant = _template()
    lift.box("LogisticsBufferLift", Vector3(0, -0.035, 0), Vector3(0.62, 0.07, 0.60), "slate")
    var cover: Variant = _template()
    cover.box("LogisticsBufferHatch", Vector3.ZERO, Vector3(0.68, 0.065, 0.65), "armor_light")
    cover.box("LogisticsBufferHatchRib", Vector3(0, 0.045, 0), Vector3(0.56, 0.035, 0.09), "edge")
    for i in range(2):
        d.lifts.append(_visual(lift))
        d.shutters.append(_visual(cover))
        _buffer_pose(d, i, RACK_Y - 0.48, 0.0)
    var post: Variant = _template()
    post.poly("LogisticsArmFoot", "octagonal_slew", Vector3(0, 0.09, 0), Vector3(0.44, 0.18, 0.44), "slate")
    post.poly("LogisticsArmColumn", "octagonal_slew", Vector3(0, 0.83, 0), Vector3(0.24, 1.45, 0.24), "armor")
    post.poly("LogisticsArmShoulder", "drum", Vector3(0, 1.60, 0), Vector3(0.36, 0.21, 0.36), "caution")
    _apply_visual_pose(_visual(post), _pose(_v3(d.pivot)))
    var arm_a: Variant = _template()
    arm_a.poly("LogisticsArmUpper", "octagonal_slew", Vector3.ZERO, Vector3(0.19, 1, 0.19), "caution")
    d.link_a = _visual(arm_a)
    var arm_b: Variant = _template()
    arm_b.poly("LogisticsArmLower", "octagonal_slew", Vector3.ZERO, Vector3(0.16, 1, 0.16), "armor_light")
    d.link_b = _visual(arm_b)
    var joint: Variant = _template()
    joint.poly("LogisticsElbow", "drum", Vector3.ZERO, Vector3(0.26, 0.18, 0.26), "slate")
    d.elbow = _visual(joint)
    var shaft: Variant = _template()
    shaft.poly("LogisticsTelescopicWrist", "octagonal_slew", Vector3.ZERO, Vector3(0.10, 1, 0.10), "edge")
    d.wrist = _visual(shaft)
    var grip: Variant = _template()
    grip.box("LogisticsGripper", Vector3.ZERO, Vector3(0.78, 0.12, 0.17), "caution")
    d.grip = _visual(grip)
    var jaw: Variant = _template()
    jaw.box("LogisticsJaw", Vector3(0, -0.12, 0), Vector3(0.075, 0.26, 0.28), "edge")
    d.jaw_a = _visual(jaw)
    d.jaw_b = _visual(jaw)
    _arm(d, _v3(d.stage, 1.10), 0.37)

func _segment(a: Vector3, b: Vector3) -> Transform3D:
    var direction: Vector3 = b - a
    var axis: Vector3 = direction.normalized() if direction.length_squared() > 0.000001 else Vector3.UP
    return Transform3D(Basis(Quaternion(Vector3.UP, axis)).scaled_local(Vector3(1, maxf(0.015, direction.length()), 1)), (a + b) * 0.5)

func _arm(d: Dock, payload_bottom: Vector3, jaw: float) -> void:
    # Equal length planar links with a fixed shoulder; vertical wrist carries
    # the open/closed jaws. No stretching of the two rigid main arms.
    var top: float = 1.60
    var target: Vector2 = _xz(payload_bottom)
    var delta: Vector2 = target - d.pivot
    var perpendicular := Vector2(-delta.y, delta.x).normalized()
    var reach: float = 1.12
    var bend: float = sqrt(maxf(0.0, reach * reach - delta.length_squared() * 0.25))
    var elbow: Vector2 = (target + d.pivot) * 0.5 + perpendicular * bend
    var a: Vector3 = _v3(d.pivot, top)
    var b: Vector3 = _v3(elbow, top)
    var c: Vector3 = _v3(target, top)
    var hand: Vector3 = payload_bottom + Vector3(0, 0.41, 0)
    _apply_visual_pose(d.link_a, _segment(a, b))
    _apply_visual_pose(d.link_b, _segment(b, c))
    _apply_visual_pose(d.elbow, _pose(b))
    _apply_visual_pose(d.wrist, _segment(c, hand))
    _apply_visual_pose(d.grip, _pose(hand, d.yaw))
    var turn := Basis(Vector3.UP, d.yaw)
    _apply_visual_pose(d.jaw_a, _pose(hand + turn * Vector3(-jaw, 0, 0), d.yaw))
    _apply_visual_pose(d.jaw_b, _pose(hand + turn * Vector3(jaw, 0, 0), d.yaw))

func _buffer_pose(d: Dock, i: int, y: float, opening: float) -> void:
    var rack: Vector3 = _rack_slot(d, i)
    var turn := Basis(Vector3.UP, d.yaw)
    var lift_at := Vector3(rack.x, y, rack.z)
    # Hatch slides sideways into a raised external guide, never through cargo.
    var cover_at: Vector3 = rack + turn * Vector3(d.hatch_side * 0.73 * opening, 0.075, 0)
    _apply_visual_pose(d.lifts[i], _pose(lift_at, d.yaw))
    _apply_visual_pose(d.shutters[i], _pose(cover_at, d.yaw))


# Sample the actual two crawler tracks at their front and rear contacts.
# The shared rigid pose carries chassis, sensor lights, treads and cargo.
func _carrier_ground_pose(t: Truck) -> Transform3D:
    var turn := Basis(Vector3.UP, t.yaw)
    if not is_instance_valid(_ramp_surface):
        return Transform3D(turn, _v3(t.pos))
    var fl: float = _ground_height(t.pos + _xz(turn * (Vector3(-0.35, 0, 0.54) * CARRIER_SCALE)))
    var fr: float = _ground_height(t.pos + _xz(turn * (Vector3(0.35, 0, 0.54) * CARRIER_SCALE)))
    var rl: float = _ground_height(t.pos + _xz(turn * (Vector3(-0.35, 0, -0.54) * CARRIER_SCALE)))
    var rr: float = _ground_height(t.pos + _xz(turn * (Vector3(0.35, 0, -0.54) * CARRIER_SCALE)))
    var front: float = (fl + fr) * 0.5
    var rear: float = (rl + rr) * 0.5
    var left: float = (fl + rl) * 0.5
    var right: float = (fr + rr) * 0.5
    var pitch: float = atan2(front - rear, 1.08 * CARRIER_SCALE.z)
    var roll: float = atan2(right - left, 0.70 * CARRIER_SCALE.x)
    var tilted: Basis = turn * Basis.from_euler(Vector3(-pitch, 0, roll))
    # Lift the rigid track plane enough to clear the highest sampled contact
    # and the center of a crest; it must not cut through the steel deck.
    var height: float = _ground_height(t.pos)
    for sample in [Vector3(-0.35, fl, 0.54), Vector3(0.35, fr, 0.54),
            Vector3(-0.35, rl, -0.54), Vector3(0.35, rr, -0.54)]:
        var contact: Vector3 = sample
        height = maxf(height, contact.y - (tilted * (Vector3(contact.x, 0, contact.z) * CARRIER_SCALE)).y)
    return Transform3D(tilted, _v3(t.pos, height))


func _deck_slot(t: Truck, i: int) -> Vector3:
    return t.carrier_pose * Vector3(0, DECK_Y, -0.32 + 0.64 * i)

func _rack_slot(d: Dock, i: int) -> Vector3:
    return _v3(d.stage, RACK_Y) + Basis(Vector3.UP, d.yaw) * Vector3(0, 0, -0.34 + 0.68 * i)

func _truck_pose(t: Truck) -> void:
    var p: Transform3D = _carrier_ground_pose(t)
    t.carrier_pose = p
    # Enlarge chassis footprint only; cargo and grip dimensions remain matched.
    var shell := Transform3D(p.basis.scaled_local(CARRIER_SCALE), p.origin)
    _apply_visual_pose(t.body, shell)
    var waiting: bool = t.mode == "drive" and t.traffic_blocked
    _apply_visual_pose(t.lamp_go, shell, not waiting)
    _apply_visual_pose(t.lamp_wait, shell, waiting)
    for i in range(t.treads.size()):
        var z: float = -0.56 + fposmod(float(i) * 0.14 - t.tread_distance, 1.12)
        _apply_visual_pose(t.treads[i], shell * _pose(Vector3(0, 0, z)))
    if t.mode not in ["load", "unload", "feed_stock"]:
        for i in range(t.cargo.size()):
            _apply_visual_pose(t.cargo[i], Transform3D(p.basis, _deck_slot(t, i)), t.loaded)

# Sample the fixed path a short distance ahead of the actual vehicle.
# Forecasts never claim a road or a dock for a distant future arrival.
func _ahead_position(t: Truck, distance: float) -> Vector2:
    var path: Array = t.legs[t.leg]
    var p: Vector2 = t.pos
    for i in range(t.waypoint, path.size()):
        var goal: Vector2 = _point(path[i])
        var length: float = p.distance_to(goal)
        if distance <= length:
            return p.move_toward(goal, distance)
        distance -= length
        p = goal
    return p


func _travel_direction(t: Truck) -> Vector2:
    if t.mode != "drive":
        return Vector2.ZERO
    return (_ahead_position(t, 0.25) - t.pos).normalized()


# First distance along our path at which a stationary vehicle's physical
# clearance circle would be entered. An already close car can move away.
func _clearance_ahead(t: Truck, obstacle: Vector2, lookahead: float) -> float:
    var path: Array = t.legs[t.leg]
    var p: Vector2 = t.pos
    var walked: float = 0.0
    for i in range(t.waypoint, path.size()):
        var goal: Vector2 = _point(path[i])
        var full: float = p.distance_to(goal)
        if full < 0.0001:
            p = goal
            continue
        var length: float = minf(full, lookahead - walked)
        if length <= 0.0:
            break
        var direction: Vector2 = (goal - p) / full
        var relative: Vector2 = obstacle - p
        var forward: float = relative.dot(direction)
        var side_sq: float = maxf(0.0, relative.length_squared() - forward * forward)
        if relative.length_squared() < TRAFFIC_GAP * TRAFFIC_GAP:
            if forward > 0.0:
                return walked
        elif forward > 0.0 and side_sq < TRAFFIC_GAP * TRAFFIC_GAP:
            var entry: float = forward - sqrt(TRAFFIC_GAP * TRAFFIC_GAP - side_sq)
            if entry >= 0.0 and entry <= length:
                return walked + entry
        walked += length
        p += direction * length
        if walked >= lookahead:
            break
    return INF


func _begin_ready_vehicles() -> void:
    for t in _trucks:
        if t.mode not in ["home", "leg_wait"]:
            continue
        if t.mode == "home":
            t.leg = 0
        t.waypoint = 1
        t.mode = "drive"
        t.wait = 0.0
        t.traffic_blocked = false
        t.traffic_limit = SPEED
        _traffic_elapsed = 0.10


func _forecast_distance(t: Truck, seconds: float) -> float:
    # Forecast a stopped truck's possible restart as well. Braking is
    # governed by the live clearance below, not by these estimates alone.
    var speed: float = clampf(t.speed, 0.0, SPEED)
    var accel_time: float = minf(seconds, (SPEED - speed) / 3.5)
    return speed * accel_time + 1.75 * accel_time * accel_time + SPEED * (seconds - accel_time)


func _choose_priority(a: Truck, b: Truck, point: Vector2, key: Vector2i) -> int:
    var a_clear: float = _clearance_ahead(a, b.pos, 3.5)
    var b_clear: float = _clearance_ahead(b, a.pos, 3.5)
    # A vehicle already occupying another's imminent trajectory gets to
    # clear it first, otherwise a yielding car could block the winner.
    if a_clear < 1.0 and b_clear >= 1.0:
        return b.id
    if b_clear < 1.0 and a_clear >= 1.0:
        return a.id
    if _pair_priority.has(key):
        return int(_pair_priority[key])
    var da: float = a.pos.distance_to(point)
    var db: float = b.pos.distance_to(point)
    if absf(da - db) > 0.40:
        return a.id if da < db else b.id
    if absf(a.yield_age - b.yield_age) > 0.30:
        return a.id if a.yield_age > b.yield_age else b.id
    return mini(a.id, b.id)


func _update_local_traffic() -> void:
    var predictions: Dictionary = {}
    for t in _trucks:
        t.traffic_limit = SPEED
        if t.mode != "drive":
            continue
        var samples: Array[Vector2] = []
        for i in range(1, ceili(TRAFFIC_HORIZON / TRAFFIC_SAMPLE) + 1):
            samples.append(_ahead_position(t, _forecast_distance(t, float(i) * TRAFFIC_SAMPLE)))
        predictions[t.id] = samples
    var active_pairs: Dictionary = {}
    for i in range(_trucks.size()):
        var a: Truck = _trucks[i]
        if not predictions.has(a.id):
            continue
        for j in range(i + 1, _trucks.size()):
            var b: Truck = _trucks[j]
            if not predictions.has(b.id) or a.pos.distance_to(b.pos) > SPEED * TRAFFIC_HORIZON * 2.0 + TRAFFIC_FORECAST_GAP:
                continue
            var ad: Vector2 = _travel_direction(a)
            var bd: Vector2 = _travel_direction(b)
            # Same-direction traffic follows the actual leading chassis.
            # Do not make that leading chassis yield to a rear follower.
            if ad.dot(bd) > 0.72:
                continue
            var ap: Array = predictions[a.id]
            var bp: Array = predictions[b.id]
            var hit: int = -1
            for k in range(ap.size()):
                if (ap[k] as Vector2).distance_to(bp[k]) < TRAFFIC_FORECAST_GAP:
                    hit = k
                    break
            if hit < 0:
                continue
            var key := Vector2i(a.id,b.id)
            var point: Vector2 = ((ap[hit] as Vector2) + (bp[hit] as Vector2)) * 0.5
            var winner: int = _choose_priority(a,b,point,key)
            active_pairs[key] = winner
            var yielding: Truck = b if winner == a.id else a
            var distance: float = _forecast_distance(yielding, float(hit + 1) * TRAFFIC_SAMPLE)
            # Brake before reaching the predicted overlap, preserving a
            # chassis-sized clearance for the crossing vehicle.
            var available: float = maxf(0.0, distance - TRAFFIC_GAP)
            yielding.traffic_limit = minf(yielding.traffic_limit, sqrt(2.0 * TRAFFIC_BRAKE * available))
    _pair_priority = active_pairs


func _advance_waypoint(t: Truck) -> void:
    t.waypoint += 1


func _drive(t: Truck, dt: float) -> void:
    var path: Array = t.legs[t.leg]
    var last: int = path.size() - 1
    if t.waypoint > last:
        if t.leg == 3:
            # Continuous shared return: no stop or individual turning bay.
            t.leg = 0
            t.waypoint = 1
            t.loaded = false
            _cargo_kind(t, true)
            return
        t.speed = 0.0
        t.mode = "align"
        return
    var goal: Vector2 = _point(path[t.waypoint])
    var delta: Vector2 = goal - t.pos
    if delta.length() < 0.001:
        _advance_waypoint(t)
        return
    var target_yaw: float = atan2(delta.x, delta.y)
    var error: float = absf(angle_difference(t.yaw, target_yaw))
    t.yaw = rotate_toward(t.yaw, target_yaw, 5.5 * dt)
    if error > 0.48:
        t.speed = move_toward(t.speed, 0.0, 7.0 * dt)
        return
    # Brake for the final dock and genuinely tight bends, not each sample
    # of the baked curve. Carry unused movement into the next sample.
    var remaining: float = delta.length()
    var limit: float = SPEED
    var direction: Vector2 = delta.normalized()
    for j in range(t.waypoint, last):
        var next_delta: Vector2 = _point(path[j + 1]) - _point(path[j])
        var angle: float = absf(direction.angle_to(next_delta.normalized()))
        if angle > 0.18:
            var curve_speed: float = clampf(next_delta.length() * 4.2 / angle, 0.6, SPEED)
            limit = minf(limit, sqrt(curve_speed * curve_speed + 7.0 * remaining))
        remaining += next_delta.length()
        direction = next_delta.normalized()
        if remaining > 3.0:
            break
    if t.leg != 3 and (remaining <= 3.0 or t.waypoint == last):
        limit = minf(limit, sqrt(7.0 * remaining))
    # Slow naturally as the leading track approaches a raised protector.
    if is_instance_valid(_ramp_surface):
        var ahead: Vector2 = t.pos + delta.normalized() * 0.90
        var rise: float = maxf(_ground_height(t.pos), _ground_height(ahead))
        if rise > 0.025:
            limit = minf(limit, lerpf(SPEED, 1.15, clampf(rise / 0.24, 0.0, 1.0)))
    # Every 30Hz step also checks all real positions, including trucks
    # loading, turning and just moved earlier in this step. The movement
    # budget is hard-clamped so a stale forecast cannot cause contact.
    var clearance: float = INF
    for other in _trucks:
        if other == t or t.pos.distance_to(other.pos) > 6.0:
            continue
        clearance = minf(clearance, _clearance_ahead(t, other.pos, 3.8))
    var traffic_speed: float = minf(t.traffic_limit, sqrt(2.0 * TRAFFIC_BRAKE * maxf(0.0,clearance - 0.06)))
    t.traffic_blocked = traffic_speed < 0.10
    limit = minf(limit, traffic_speed)
    t.speed = move_toward(t.speed, limit, (TRAFFIC_BRAKE if t.speed > limit else 3.5) * dt)
    var budget: float = minf(t.speed * dt, maxf(0.0,clearance - 0.02))
    if t.traffic_blocked and budget < 0.002:
        t.speed = 0.0
    while budget > 0.0001 and t.waypoint <= last:
        goal = _point(path[t.waypoint])
        var distance: float = t.pos.distance_to(goal)
        var travel: float = minf(distance, budget)
        t.pos = t.pos.move_toward(goal, travel)
        t.tread_distance += travel
        budget -= travel
        if distance - travel <= 0.0001:
            t.pos = goal
            _advance_waypoint(t)
            if t.waypoint <= last:
                var next_dir: Vector2 = (_point(path[t.waypoint]) - t.pos).normalized()
                if absf(angle_difference(t.yaw, atan2(next_dir.x, next_dir.y))) > 0.48:
                    break
        else:
            break


func _dock_for(t: Truck) -> Dock:
    if t.leg == 0:
        return _docks[t.source]
    if t.leg == 1:
        return _docks[t.destination]
    return _docks["STORAGE"]

func _handle(t: Truck, d: Dock, dt: float) -> void:
    var loading: bool = t.mode == "load"
    t.clock += dt
    var index: int = mini(1, floori(t.clock / BOX_TIME))
    var phase: float = minf(BOX_TIME, t.clock - float(index) * BOX_TIME)
    var deck: Vector3 = _deck_slot(t, index)
    var rack: Vector3 = _rack_slot(d, index)
    var pick: Vector3 = rack if loading else deck
    var drop: Vector3 = deck if loading else rack
    var pick_high: Vector3 = Vector3(pick.x, 1.05, pick.z)
    var drop_high: Vector3 = Vector3(drop.x, 1.05, drop.z)
    var idle: Vector3 = _v3(d.stage, 1.10)
    var hand: Vector3 = idle
    var cargo: Vector3 = pick
    var visible_cargo: bool = true
    var lift_y: float = RACK_Y
    var opening: float = 1.0
    var jaw: float = 0.37
    if phase < 0.55:
        hand = idle.lerp(pick_high, smoothstep(0.0, 0.55, phase))
        opening = smoothstep(0.0, 0.19, phase)
        if loading:
            cargo.y = lerpf(RACK_Y - 0.48, RACK_Y, smoothstep(0.20, 0.53, phase))
            lift_y = cargo.y
        else:
            lift_y = lerpf(RACK_Y - 0.48, RACK_Y, smoothstep(0.20, 0.53, phase))
    elif phase < 1.05:
        hand = pick_high.lerp(pick, smoothstep(0.55, 1.05, phase))
    elif phase < 1.25:
        hand = pick
        jaw = lerpf(0.37, 0.30, smoothstep(1.05, 1.25, phase))
    elif phase < 1.65:
        hand = pick.lerp(pick_high, smoothstep(1.25, 1.65, phase))
        cargo = hand
        jaw = 0.30
    elif phase < 2.30:
        hand = pick_high.lerp(drop_high, smoothstep(1.65, 2.30, phase))
        cargo = hand
        jaw = 0.30
    elif phase < 2.75:
        hand = drop_high.lerp(drop, smoothstep(2.30, 2.75, phase))
        cargo = hand
        jaw = 0.30
    elif phase < 2.95:
        hand = drop
        cargo = drop
        jaw = lerpf(0.30, 0.37, smoothstep(2.75, 2.95, phase))
    elif phase < 3.35:
        hand = drop.lerp(drop_high, smoothstep(2.95, 3.35, phase))
        cargo = drop
    else:
        hand = drop_high.lerp(idle, smoothstep(3.35, BOX_TIME, phase))
        cargo = drop
        if not loading:
            # Lower into the recessed stock receiver only after release.
            cargo.y = lerpf(RACK_Y, RACK_Y - 0.48, smoothstep(3.35, 3.62, phase))
            lift_y = cargo.y
            visible_cargo = phase < BOX_TIME - 0.02
        else:
            lift_y = lerpf(RACK_Y, RACK_Y - 0.48, smoothstep(3.35, 3.62, phase))
        opening = 1.0 - smoothstep(3.62, BOX_TIME, phase)
    _buffer_pose(d, index, lift_y, opening)
    _arm(d, hand, jaw)
    _apply_visual_pose(t.cargo[index], _pose(cargo, d.yaw), visible_cargo)
    for i in range(2):
        if i == index:
            continue
        _buffer_pose(d, i, RACK_Y - 0.48, 0.0)
        var on_deck: bool = (i < index) if loading else (i > index)
        _apply_visual_pose(t.cargo[i], _pose(_deck_slot(t, i), t.yaw), on_deck)
    if t.clock >= BOX_TIME * 2.0:
        for i in range(2):
            _buffer_pose(d, i, RACK_Y - 0.48, 0.0)
        t.loaded = loading
        _arm(d, idle, 0.37)
        if not loading and t.leg in [1,2]:
            var site: String = t.destination if t.leg == 1 else "STORAGE"
            var motion: Node = _facility_motion.get(site)
            if is_instance_valid(motion) and motion.has_method("begin_material_cycle"):
                if _intakes.has(site):
                    t.mode = "feed_stock"
                else:
                    motion.call("begin_material_cycle")
                    t.mode = "process_stock"
                t.clock = 0.0
                return
            if t.leg == 1:
                _cargo_kind(t, false)
                t.mode = "load"
                t.clock = 0.0
                return
        t.leg += 1
        t.waypoint = 1
        t.mode = "leg_wait"
        t.wait = 0.0
        t.clock = 0.0

func advance(delta: float) -> void:
    if not _ready_for_motion:
        return
    _acc = minf(_acc + delta, STEP * 3.0)
    while _acc >= STEP:
        _acc -= STEP
        _begin_ready_vehicles()
        _traffic_elapsed += STEP
        if _traffic_elapsed >= 0.10:
            _traffic_elapsed = 0.0
            _update_local_traffic()
        for t in _trucks:
            match t.mode:
                "home", "leg_wait":
                    t.wait += STEP
                "drive":
                    t.traffic_blocked = false
                    _drive(t, STEP)
                    t.yield_age = t.yield_age + STEP if t.traffic_blocked else 0.0
                "align":
                    var d: Dock = _dock_for(t)
                    t.yaw = rotate_toward(t.yaw, d.yaw, 3.5 * STEP)
                    if absf(angle_difference(t.yaw, d.yaw)) < 0.015:
                        t.yaw = d.yaw
                        t.mode = "load" if t.leg == 0 else "unload"
                        t.clock = 0.0
                "load", "unload":
                    _handle(t, _dock_for(t), STEP)
                "feed_stock":
                    _feed_stock(t, STEP)
                "process_stock":
                    var site: String = t.destination if t.leg == 1 else "STORAGE"
                    var motion: Node = _facility_motion.get(site)
                    if not is_instance_valid(motion) or bool(motion.call("material_cycle_complete")):
                        if t.leg == 1:
                            _cargo_kind(t, false)
                            t.mode = "load"
                        else:
                            t.leg += 1
                            t.waypoint = 1
                            t.mode = "leg_wait"
                            t.wait = 0.0
                        t.clock = 0.0
                "unavailable":
                    continue
            _truck_pose(t)
    _flush_poses()
