extends Node3D
## Outdoor logistics is a visual production loop, never a resource/save mutation.
## One shared batch per geometry/material, fixed 30 Hz poses and startup-only
## route search. Whole-circuit reservations guarantee that a moving vehicle
## never has to acquire a second intersection while holding the first.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const Clutter = preload("res://scripts/sera_base_clutter.gd")
const FreshDesign = preload("res://scripts/sera_base_fresh_design.gd")
const Power = preload("res://scripts/sera_base_power_distribution.gd")
const CELL: float = 0.75
const REGION := Rect2i(-46, -46, 93, 93)
const CLEARANCE: float = 0.84
const STEP: float = 1.0 / 30.0
const SPEED: float = 1.65
const BOX_TIME: float = 3.8
const DECK_Y: float = 0.39
const RACK_Y: float = 0.61
const ROUTES = [
    ["SCRAP_COLLECTOR", "LABO"], ["SCRAP_COLLECTOR", "SMELTER"],
    ["SCRAP_COLLECTOR", "RECYCLER"], ["LABO", "STORAGE"],
    ["SMELTER", "STORAGE"], ["RECYCLER", "STORAGE"]
]

class Visual:
    var slots: Dictionary = {}
    var pose: Transform3D = Transform3D.IDENTITY
    var shown: bool = true
    var dirty: bool = true

class Dock:
    var cell: Vector2i
    var stage: Vector2
    var pivot: Vector2
    var yaw: float
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
    var leg: int = 0
    var waypoint: int = 1
    var prefix_end: int = 0
    var mode: String = "home"
    var wait: float = 0.0
    var clock: float = 0.0
    var tread_distance: float = 0.0
    var body: Visual
    var cargo: Array[Visual] = []
    var lamp_go: Visual
    var lamp_wait: Visual
    var treads: Array[Visual] = []
    var loaded: bool = false

var _grid := AStarGrid2D.new()
var _docks: Dictionary = {}
var _trucks: Array[Truck] = []
var _homes: Array[Vector2i] = []
var _held: Dictionary = {}
var _pending: Truck
var _visuals: Array[Visual] = []
var _draws: Dictionary = {}
var _batch: Variant
var _acc: float = 0.0
var _dispatch: float = 0.0

func _xz(v: Vector3) -> Vector2:
    return Vector2(v.x, v.z)

func _v3(v: Vector2, y: float = 0.0) -> Vector3:
    return Vector3(v.x, y, v.y)

func _point(cell: Vector2i) -> Vector2:
    return Vector2(cell) * CELL

func _cell(p: Vector2) -> Vector2i:
    return Vector2i(roundi(p.x / CELL), roundi(p.y / CELL))

func _free(c: Vector2i) -> bool:
    return REGION.has_point(c) and not _grid.is_point_solid(c)

func _block_circle(p: Vector2, radius: float) -> void:
    var c: Vector2i = _cell(p)
    var n: int = ceili(radius / CELL) + 1
    for x in range(c.x - n, c.x + n + 1):
        for z in range(c.y - n, c.y + n + 1):
            var q := Vector2i(x, z)
            if REGION.has_point(q) and _point(q).distance_to(p) <= radius:
                _grid.set_point_solid(q, true)

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
        for prop in Clutter.props_for(key):
            # Clutter.decorate rotates around the individual prop's own pivot,
            # not the building origin: its anchor is in world-aligned XZ.
            var size: Vector2 = Clutter.bounds_for(str(prop["kind"])) * float(prop["scale"])
            _block_rect(at + (prop["at"] as Vector2), deg_to_rad(float(prop.get("yaw_deg", 0.0))), Vector2.ZERO, size * 0.5)
    for node in root.get_children():
        if node is Node3D and str(node.name).begins_with("ScrapPile_"):
            _block_circle(_xz((node as Node3D).position), 1.15 * float(node.get_meta("visual_scale", 1.26)) + CLEARANCE)
    if is_instance_valid(power):
        for p in power.get_meta("logistics_obstacles", []):
            _block_circle(p, 0.82 + CLEARANCE)
    # CRATE's established patrol remains untouched. Keep its whole corridor free.
    for i in range(crate_path.size()):
        var a: Vector2 = crate_path[i]
        var b: Vector2 = crate_path[(i + 1) % crate_path.size()]
        var count: int = maxi(1, ceili(a.distance_to(b) / 0.35))
        for j in range(count + 1):
            _block_circle(a.lerp(b, float(j) / count), 1.0)

func _find_dock(key: String, at: Vector2) -> Dock:
    var forward: Vector2 = _xz(Basis(Vector3.UP, Architecture.facility_yaw_radians(key)) * Vector3.BACK)
    var best: float = INF
    var result: Dock
    var base_cell: Vector2i = _cell(at)
    # Choose the closest clear three-part work cell in the service apron.
    # All racks/pedestals and vehicle centers are disjoint from authored props.
    for dx in range(-11, 12):
        for dz in range(-11, 12):
            var c: Vector2i = base_cell + Vector2i(dx, dz)
            if not _free(c):
                continue
            var offset: Vector2 = _point(c) - at
            var length: float = offset.length()
            if length < 2.4 or length > 7.9:
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
                    if not _free(stage_cell + along) or not _free(stage_cell - along):
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
                    if score >= best:
                        continue
                    best = score
                    result = Dock.new()
                    result.cell = c
                    result.stage = _point(stage_cell)
                    result.pivot = _point(pivot_cell)
                    result.yaw = atan2(float(along.x), float(along.y))
    if result != null:
        _block_circle(result.stage, 0.72 + CLEARANCE)
        _block_circle(result.pivot, 0.23 + CLEARANCE)
        # The central parking cell was explicitly checked before the rack
        # was installed. Its center has 1.50m side spacing from the rack.
        _grid.set_point_solid(result.cell, false)
    return result

func _find_home(source: Dock, target: Dock) -> Vector2i:
    var best: float = INF
    var answer := Vector2i(999, 999)
    var a: Vector2 = _point(source.cell)
    var direction: Vector2 = (_point(target.cell) - a).normalized()
    for x in range(-12, 13):
        for z in range(-12, 13):
            var c: Vector2i = source.cell + Vector2i(x, z)
            if not _free(c):
                continue
            var p: Vector2 = _point(c)
            var d: float = p.distance_to(a)
            if d < 2.9 or d > 9.1:
                continue
            var ok: bool = true
            for dock in _docks.values():
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
            # Parking is an off-dock holding bay, preferably to the side of
            # the loaded direction, not immediately in the transfer lane.
            var score: float = d + absf((p - a).normalized().dot(direction)) * 1.9
            if score < best:
                var exits: int = 0
                for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                    if _free(c + delta):
                        exits += 1
                if exits >= 2:
                    best = score
                    answer = c
    return answer

func _expand_cell(target: Dictionary, c: Vector2i) -> void:
    # A 0.92 x 1.30m vehicle can turn in place within a radius of 0.80m.
    # One complete neighboring ring also protects diagonal swept segments.
    for x in range(-1, 2):
        for z in range(-1, 2):
            target[c + Vector2i(x, z)] = true

func _plan(t: Truck) -> bool:
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
    var b: Array[Vector2i] = _grid.get_id_path(source.cell, destination.cell)
    # Give the empty return its own lane when there is any sensible alternative.
    var previous_weights: Dictionary = {}
    for c in b:
        if c != source.cell and c != destination.cell:
            previous_weights[c] = _grid.get_point_weight_scale(c)
            _grid.set_point_weight_scale(c, float(previous_weights[c]) + 1.8)
    var c_path: Array[Vector2i] = _grid.get_id_path(destination.cell, t.home)
    for c in previous_weights:
        _grid.set_point_weight_scale(c, float(previous_weights[c]))
    for c in temporarily_blocked:
        _grid.set_point_solid(c, false)
    if a.size() < 2 or b.size() < 2 or c_path.size() < 2:
        return false
    t.legs = [a, b, c_path]
    for leg in t.legs:
        for c in leg:
            _expand_cell(t.cells, c)
            if _free(c):
                # Later routes prefer separate streets, with shared crossings
                # allowed only where space does not permit another lane.
                _grid.set_point_weight_scale(c, minf(3.8, _grid.get_point_weight_scale(c) + 0.20))
    return true

func setup(root: Node3D, nexus_origin: Vector3, specs: Array, power: Node3D, crate_path: Array) -> void:
    var sites: Array = [{"id": "NEXUS", "at": nexus_origin}]
    sites.append_array(specs)
    _obstacles(root, sites, power, crate_path)
    for spec in specs:
        var key: String = str(spec["id"])
        if key not in ["SCRAP_COLLECTOR", "LABO", "SMELTER", "RECYCLER", "STORAGE"]:
            continue
        var dock: Dock = _find_dock(key, _xz(spec["at"]))
        if dock != null:
            _docks[key] = dock
        else:
            push_warning("BASE logistics: no clear cargo dock for " + key)
    for route in ROUTES:
        var source: String = route[0]
        var destination: String = route[1]
        if not _docks.has(source) or not _docks.has(destination):
            continue
        for i in range(2):
            var home: Vector2i = _find_home(_docks[source], _docks[destination])
            if not REGION.has_point(home):
                push_warning("BASE logistics: no safe holding bay for " + source + " -> " + destination)
                continue
            var t := Truck.new()
            t.id = _trucks.size()
            t.source = source
            t.destination = destination
            t.raw = source == "SCRAP_COLLECTOR"
            t.home = home
            t.pos = _point(home)
            t.yaw = (_docks[source] as Dock).yaw
            t.wait = -float(t.id) * 0.65
            _homes.append(home)
            _trucks.append(t)
    for t in _trucks:
        if not _plan(t):
            t.mode = "unavailable"
            push_warning("BASE logistics: route obstructed for " + t.source + " -> " + t.destination)
    _batch = Architecture.Batch.new(self)
    for dock in _docks.values():
        _make_dock(dock)
    for t in _trucks:
        if t.mode != "unavailable":
            _make_truck(t)
    _batch.flush()
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
    for t in _trucks:
        if t.mode != "unavailable":
            _truck_pose(t)
    _flush_poses()

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

func _set(v: Visual, pose: Transform3D, shown: bool = true) -> void:
    if v == null:
        return
    if v.pose != pose or v.shown != shown:
        v.pose = pose
        v.shown = shown
        v.dirty = true

func _pose(p: Vector3, yaw: float = 0.0) -> Transform3D:
    return Transform3D(Basis(Vector3.UP, yaw), p)

func _flush_poses() -> void:
    for v in _visuals:
        if not v.dirty:
            continue
        var transform: Transform3D = v.pose if v.shown else Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3(0, -10, 0))
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

func _make_truck(t: Truck) -> void:
    var g: Variant = _template()
    # Thin steel flatbed, independent crawler pods, front-facing sensor.
    g.poly("CarrierDeck", "bevel", Vector3(0, 0.32, 0), Vector3(0.94, 0.14, 1.30), "caution")
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
    t.body = _visual(g)
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
    for i in range(2):
        var cargo: Variant = _template()
        if t.raw:
            # Exactly the BASE boxed-scrap construction, scaled for the deck.
            cargo.pivot = Vector3(0, -0.16, 0)
            Clutter._make_scrap_crate(cargo, Vector2.ZERO, 0.62, i, 7)
            for key in cargo.entries:
                var pieces: Array = cargo.entries[key]
                for j in range(pieces.size()):
                    var p: Transform3D = pieces[j]
                    p.origin.y += 0.083
                    pieces[j] = p
        else:
            # Use the actual warehouse builder, not a second lookalike.
            FreshDesign.storage_cargo(cargo, Vector3(0, 0.58 * 0.62 * 0.5, 0), 0.62, i, i)
        var v: Visual = _visual(cargo)
        _set(v, Transform3D.IDENTITY, false)
        t.cargo.append(v)

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
    fixed.box("LogisticsBufferStatus", Vector3(0, 0.40, 0.765), Vector3(0.28, 0.07, 0.035), "blue_light")
    _set(_visual(fixed), _pose(_v3(d.stage), d.yaw))
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
    _set(_visual(post), _pose(_v3(d.pivot)))
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
    _set(d.link_a, _segment(a, b))
    _set(d.link_b, _segment(b, c))
    _set(d.elbow, _pose(b))
    _set(d.wrist, _segment(c, hand))
    _set(d.grip, _pose(hand, d.yaw))
    var turn := Basis(Vector3.UP, d.yaw)
    _set(d.jaw_a, _pose(hand + turn * Vector3(-jaw, 0, 0), d.yaw))
    _set(d.jaw_b, _pose(hand + turn * Vector3(jaw, 0, 0), d.yaw))

func _buffer_pose(d: Dock, i: int, y: float, opening: float) -> void:
    var rack: Vector3 = _rack_slot(d, i)
    var turn := Basis(Vector3.UP, d.yaw)
    var lift_at := Vector3(rack.x, y, rack.z)
    # Hatch slides sideways into a raised external guide, never through cargo.
    var cover_at: Vector3 = rack + turn * Vector3(0.73 * opening, 0.075, 0)
    _set(d.lifts[i], _pose(lift_at, d.yaw))
    _set(d.shutters[i], _pose(cover_at, d.yaw))


func _deck_slot(t: Truck, i: int) -> Vector3:
    return _v3(t.pos, DECK_Y) + Basis(Vector3.UP, t.yaw) * Vector3(0, 0, -0.32 + 0.64 * i)

func _rack_slot(d: Dock, i: int) -> Vector3:
    return _v3(d.stage, RACK_Y) + Basis(Vector3.UP, d.yaw) * Vector3(0, 0, -0.34 + 0.68 * i)

func _truck_pose(t: Truck) -> void:
    var p: Transform3D = _pose(_v3(t.pos), t.yaw)
    _set(t.body, p)
    var waiting: bool = t.mode == "home" or (t.mode == "approach" and t.waypoint > t.prefix_end)
    _set(t.lamp_go, p, not waiting)
    _set(t.lamp_wait, p, waiting)
    for i in range(t.treads.size()):
        var z: float = -0.56 + fposmod(float(i) * 0.14 - t.tread_distance, 1.12)
        _set(t.treads[i], p * _pose(Vector3(0, 0, z)))
    if t.mode not in ["load", "unload"]:
        for i in range(t.cargo.size()):
            _set(t.cargo[i], _pose(_deck_slot(t, i), t.yaw), t.loaded)

func _overlap(a: Dictionary, b: Dictionary) -> bool:
    for cell in a:
        if b.has(cell):
            return true
    return false

func _conflict(cells: Dictionary, own: int) -> bool:
    for id in _held:
        if int(id) != own and _overlap(cells, _held[id]):
            return true
    return false

func _start(t: Truck) -> void:
    _held[t.id] = t.cells
    if t.mode == "home":
        t.leg = 0
        t.waypoint = 1
    t.mode = "drive"
    t.wait = 0.0

func _approach(t: Truck) -> void:
    # One FIFO waiting vehicle may advance only as far as the last clear
    # grid point before the first reserved crossing. Active circuits already
    # hold all their cells; they never need to negotiate with this queue.
    var prefix: Dictionary = {}
    var path: Array = t.legs[0]
    var end: int = 0
    for i in range(path.size()):
        var ring: Dictionary = {}
        _expand_cell(ring, path[i])
        if _conflict(ring, t.id):
            break
        prefix.merge(ring, true)
        end = i
    if end > 0:
        _held[t.id] = prefix
        t.mode = "approach"
        t.prefix_end = end
        t.waypoint = 1
        t.leg = 0
    _pending = t

func _dispatch_waiting() -> void:
    if _pending != null and not _conflict(_pending.cells, _pending.id):
        _start(_pending)
        _pending = null
    var candidates: Array[Truck] = []
    for t in _trucks:
        if t.mode == "home" and t.wait >= 0.0 and t != _pending:
            candidates.append(t)
    candidates.sort_custom(func(a: Truck, b: Truck) -> bool: return a.wait > b.wait)
    for t in candidates:
        if _pending != null and _overlap(t.cells, _pending.cells):
            continue
        if _conflict(t.cells, t.id):
            if _pending == null:
                _approach(t)
        else:
            _start(t)

func _drive(t: Truck, dt: float) -> void:
    var path: Array = t.legs[t.leg]
    var last: int = t.prefix_end if t.mode == "approach" else path.size() - 1
    if t.waypoint > last:
        t.speed = 0.0
        if t.mode == "approach":
            return
        if t.leg == 2:
            _held.erase(t.id)
            t.mode = "home"
            t.wait = -1.1 - float(t.id % 2) * 0.5
            t.loaded = false
            return
        t.mode = "align"
        return
    var goal: Vector2 = _point(path[t.waypoint])
    var delta: Vector2 = goal - t.pos
    if delta.length() < 0.001:
        t.pos = goal
        t.waypoint += 1
        return
    var target_yaw: float = atan2(delta.x, delta.y)
    var error: float = absf(angle_difference(t.yaw, target_yaw))
    t.yaw = rotate_toward(t.yaw, target_yaw, 4.4 * dt)
    if error > 0.20:
        t.speed = 0.0
        return
    var remaining: float = delta.length()
    if t.waypoint < last:
        remaining += CELL
    var desired: float = minf(SPEED, sqrt(2.0 * 2.5 * remaining))
    t.speed = move_toward(t.speed, desired, 2.7 * dt)
    var distance: float = minf(delta.length(), t.speed * dt)
    t.pos = t.pos.move_toward(goal, distance)
    t.tread_distance += distance
    if t.pos.distance_to(goal) < 0.001:
        t.pos = goal
        t.waypoint += 1

func _dock_for(t: Truck) -> Dock:
    return _docks[t.source] if t.leg == 0 else _docks[t.destination]

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
    _set(t.cargo[index], _pose(cargo, d.yaw), visible_cargo)
    for i in range(2):
        if i == index:
            continue
        _buffer_pose(d, i, RACK_Y - 0.48, 0.0)
        var on_deck: bool = (i < index) if loading else (i > index)
        _set(t.cargo[i], _pose(_deck_slot(t, i), t.yaw), on_deck)
    if t.clock >= BOX_TIME * 2.0:
        for i in range(2):
            _buffer_pose(d, i, RACK_Y - 0.48, 0.0)
        t.loaded = loading
        _arm(d, idle, 0.37)
        t.leg += 1
        t.waypoint = 1
        t.mode = "drive"
        t.clock = 0.0

func advance(delta: float) -> void:
    _acc = minf(_acc + delta, STEP * 3.0)
    while _acc >= STEP:
        _acc -= STEP
        _dispatch += STEP
        if _dispatch >= 0.25:
            _dispatch = 0.0
            _dispatch_waiting()
        for t in _trucks:
            match t.mode:
                "home":
                    t.wait += STEP
                "drive", "approach":
                    _drive(t, STEP)
                "align":
                    var d: Dock = _dock_for(t)
                    t.yaw = rotate_toward(t.yaw, d.yaw, 3.5 * STEP)
                    if absf(angle_difference(t.yaw, d.yaw)) < 0.015:
                        t.yaw = d.yaw
                        t.mode = "load" if t.leg == 0 else "unload"
                        t.clock = 0.0
                "load", "unload":
                    _handle(t, _dock_for(t), STEP)
                "unavailable":
                    continue
            _truck_pose(t)
    _flush_poses()
