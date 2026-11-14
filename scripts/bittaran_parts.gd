extends "res://scripts/target_parts.gd"
## Bittaran lock/hit presentation: BODY + HEAD + four true shin bones.
## Reuses the game's existing break gauges, damage and manual/auto locking.
## Never changes Blockbench bone names or the generic training-room target.
const SHIN_BONES: Dictionary = {
    "leg_fl": "FrontLowerLeg_L",
    "leg_fr": "FrontLowerLeg_R",
    "leg_rl": "RearLowerLeg_L",
    "leg_rr": "RearLowerLeg_R"
}
const LEG_ROOT_BONES: Dictionary = {
    "leg_fl": "FrontLeg_L",
    "leg_fr": "FrontLeg_R",
    "leg_rl": "RearLeg_L",
    "leg_rr": "RearLeg_R"
}
const SHIN_LABELS: Dictionary = {
    "leg_fl": "FRONT LEFT SHIN", "leg_fr": "FRONT RIGHT SHIN",
    "leg_rl": "REAR LEFT SHIN", "leg_rr": "REAR RIGHT SHIN"
}
const HIT_COLOR: Color = Color("#ff5772")
const HIT_EMISSION: Color = Color("#c52f43")
const BROKEN_STEEL: Color = Color("#252c34")
const BROKEN_GLOW: Color = Color("#b14322")
const DEATH_STEEL: Color = Color("#10141a")
const LOCK_VOLUME_EXPANSION: float = 1.15
## Bittaran SHIN-only AUTO/MANUAL selection volume: exactly twice the
## authored lower-leg mesh AABB, not the 3-bone leg or its physical collider.
const SHIN_SELECTION_VOLUME_SCALE: float = 2.0
# A front/rear pair may overlap the same two horizontal lock rays.
# Hold the selected left/right shin until SERA clearly crosses the center.
const LATERAL_SHIN_LOCK_HYSTERESIS_METERS: float = 0.65
const MIN_SHIN_BOX: Vector3 = Vector3(0.52, 0.65, 0.52)
const MIN_BODY_BOX: Vector3 = Vector3(0.65, 0.55, 0.65)
# "body" is an explicit MANUAL selection. The legacy "" ID remains the
# AUTO/core fallback, so old SERA damage, saves and HUD still work.
const BODY_MANUAL_LOCK_ID: String = "body"
const BODY_MAX_HP: float = 500.0

var boss_model: Node3D
var collision_body: AnimatableBody3D
var bone_nodes: Dictionary = {}
var camera_areas: Dictionary = {}
## Standing mesh-space calibration, captured once after the IK rig is planted.
## Walking / step-lift / knockdown may change the rendered shin's Y, but the
## lock box height and dimensions remain fixed in WORLD coordinates.
var shin_selection_standing: Dictionary = {}
## Initial standing calibration validates the four-shin setup. Runtime
## selection uses the final IK shin positions, not this saved rig-local pose.
var lock_front_mid_local: Vector3 = Vector3.ZERO
var lock_rear_mid_local: Vector3 = Vector3.ZERO
var lock_halfway_initialized: bool = false
var combat_shapes: Dictionary = {}
var fx_meshes: Dictionary = {}
var fx_timers: Dictionary = {}
var fx_durations: Dictionary = {}
var installed: bool = false
var down_lock_enabled: bool = false
var head_support_leg_id: String = ""
const UNDER_HEAD_LEG_AUTO_PENALTY: float = 5.0
var death_visual_power: float = 0.0

func _ready() -> void:
    super._ready()

func setup_bittaran(model: Node3D, moving_body: AnimatableBody3D) -> bool:
    boss_model = model
    collision_body = moving_body
    installed = false
    down_lock_enabled = false
    death_visual_power = 0.0
    if model == null or moving_body == null or not model.is_inside_tree():
        return false
    bone_nodes.clear()
    for id in SHIN_BONES:
        bone_nodes[id] = model.find_child(str(SHIN_BONES[id]), true, false) as Node3D
        if bone_nodes[id] == null:
            push_error("Bittaran lock: missing shin " + str(SHIN_BONES[id]))
            return false
    bone_nodes["head"] = model.find_child("Head", true, false) as Node3D
    bone_nodes[""] = model.find_child("Body", true, false) as Node3D
    if bone_nodes["head"] == null or bone_nodes[""] == null:
        push_error("Bittaran lock: missing BODY/HEAD")
        return false

    # The training-room BoxMesh is hidden; replace its camera-only volumes
    # and movement solids with geometry measured from the real 14-bone rig.
    camera_areas.clear()
    shin_selection_standing.clear()
    lock_halfway_initialized = false
    for id in ["", "head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        var anchor: Node3D = bone_nodes[id]
        var camera_area := Area3D.new()
        camera_area.name = "BittaranCameraLock_" + ("BODY" if id.is_empty() else id)
        camera_area.collision_layer = 0
        camera_area.collision_mask = 0
        camera_area.monitoring = false
        camera_area.monitorable = false
        var shape := CollisionShape3D.new()
        shape.name = "CameraOnlyBox"
        shape.shape = BoxShape3D.new()
        camera_area.add_child(shape)
        anchor.add_child(camera_area)
        camera_areas[id] = camera_area
        if id == "":
            core_camera_lock_area = camera_area
        else:
            var part: Dictionary = parts[id]
            part["camera_lock_area"] = camera_area
            part["display"] = "HEAD" if id == "head" else SHIN_LABELS[id]
            # The existing break gauge remains the shin's break gauge.
            parts[id] = part

    for child in moving_body.get_children():
        if child is CollisionShape3D:
            # Existing training-room geometry does not match the new robot.
            child.set_deferred("disabled", true)
            moving_body.remove_child(child)
            child.queue_free()
    combat_shapes.clear()
    for id in ["", "head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        var solid := CollisionShape3D.new()
        solid.name = "BittaranSolid_" + ("BODY" if id.is_empty() else id)
        solid.shape = BoxShape3D.new()
        moving_body.add_child(solid)
        combat_shapes[id] = solid

    fx_meshes.clear()
    fx_timers.clear()
    fx_durations.clear()
    # BODY must not include the child head/leg bones.
    fx_meshes[""] = _material_records(bone_nodes[""], false)
    fx_meshes["head"] = _material_records(bone_nodes["head"], true)
    for id in SHIN_BONES:
        var root_leg: Node3D = model.find_child(str(LEG_ROOT_BONES[id]), true, false) as Node3D
        if root_leg == null:
            return false
        # Full leg flashes for a strike on the shin, including foot and knee.
        fx_meshes[id] = _material_records(root_leg, true)
    for id in fx_meshes:
        fx_timers[id] = 0.0
        fx_durations[id] = 0.145
    installed = true
    sync_bittaran_parts()
    _calibrate_front_rear_lock_midpoint()
    return lock_halfway_initialized

func _material_records(root: Node3D, descend: bool) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    for child in root.get_children():
        if child is MeshInstance3D:
            var mesh_node: MeshInstance3D = child as MeshInstance3D
            var old: Material = mesh_node.material_override
            if old is StandardMaterial3D:
                var material: StandardMaterial3D = old.duplicate() as StandardMaterial3D
                mesh_node.material_override = material
                records.append({
                    "material": material, "albedo": material.albedo_color,
                    "emission_on": material.emission_enabled,
                    "emission": material.emission,
                    "energy": material.emission_energy_multiplier
                })
        elif descend and child is Node3D and not child is Area3D:
            records.append_array(_material_records(child, true))
    return records

func _append_mesh_bounds(node: Node3D, bounds: Array[Vector3],
        descend: bool) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var mesh_node: MeshInstance3D = child as MeshInstance3D
            if mesh_node.mesh == null:
                continue
            var aabb: AABB = mesh_node.mesh.get_aabb()
            for corner in range(8):
                bounds.append(mesh_node.to_global(aabb.get_endpoint(corner)))
        elif descend and child is Node3D and not child is Area3D:
            _append_mesh_bounds(child, bounds, true)

func _normalize_boss_part(id: String) -> String:
    return "" if id == BODY_MANUAL_LOCK_ID else id

func set_down_lock_enabled(enabled: bool) -> void:
    # This is the actual IK fall/skid animation, not generic stagger or the
    # training-room part-break pause. Only a genuine collapse opens weakpoints.
    down_lock_enabled = enabled

func set_head_support_leg(id: String) -> void:
    # Selection penalty only: never disable the actual leg collision,
    # damage, weakpoint gauge, or explicit MANUAL selection.
    head_support_leg_id = id if id in LEG_IDS else ""


func _parallel_lock_part_distance(segments: PackedVector3Array,
        id: String) -> float:
    var distance: float = super._parallel_lock_part_distance(segments, id)
    if down_lock_enabled and id == head_support_leg_id and distance < INF:
        # During a fall the leg beneath the HEAD is an inferior AUTO
        # target even if its oversized selection box intersects first.
        return distance + UNDER_HEAD_LEG_AUTO_PENALTY
    return distance


func can_lock_boss_part(id: String) -> bool:
    if id == "head" or id.is_empty() or id == BODY_MANUAL_LOCK_ID:
        return down_lock_enabled
    return id in LEG_IDS

func is_targetable(id: String) -> bool:
    if id == "head" or id == BODY_MANUAL_LOCK_ID:
        return down_lock_enabled
    if id.is_empty():
        return false # The legacy BODY has no ordinary part gauge.
    return super.is_targetable(id)

func has_part(id: String) -> bool:
    if id == BODY_MANUAL_LOCK_ID:
        return down_lock_enabled
    return super.has_part(id)

func get_visible_part_ids(origin: Vector3, core_box: AABB) -> Array[String]:
    var ids: Array[String] = super.get_visible_part_ids(origin, core_box)
    if down_lock_enabled:
        ids.append(BODY_MANUAL_LOCK_ID)
    return ids

func _camera_lock_body_volume_distance(origin: Vector3,
        destination: Vector3) -> float:
    if not down_lock_enabled:
        return INF
    return super._camera_lock_body_volume_distance(origin, destination)

func _camera_lock_part_volume_distance(origin: Vector3,
        destination: Vector3, id: String) -> float:
    if id == BODY_MANUAL_LOCK_ID:
        return _camera_lock_body_volume_distance(origin, destination)
    if not is_targetable(id):
        return INF
    return super._camera_lock_part_volume_distance(origin, destination, id)

## The mesh BODY center is used for the actual two horizontal lock
## lines. It does NOT imply an unbiased front-vs-rear selection: the former
## first-entry intersection ranking always preferred the nearer shin.
## Validate an initial front/rear axis. Runtime uses the final IK positions.
func _calibrate_front_rear_lock_midpoint() -> void:
    lock_halfway_initialized = false
    if boss_model == null or not installed:
        return
    for id in LEG_IDS:
        if not shin_selection_standing.has(id):
            return
    var fl: Vector3 = get_shin_selection_box("leg_fl").get_center()
    var fr: Vector3 = get_shin_selection_box("leg_fr").get_center()
    var rl: Vector3 = get_shin_selection_box("leg_rl").get_center()
    var rr: Vector3 = get_shin_selection_box("leg_rr").get_center()
    lock_front_mid_local = boss_model.to_local((fl + fr) * 0.5)
    lock_rear_mid_local = boss_model.to_local((rl + rr) * 0.5)
    var axis: Vector2 = Vector2(
        lock_front_mid_local.x - lock_rear_mid_local.x,
        lock_front_mid_local.z - lock_rear_mid_local.z)
    lock_halfway_initialized = axis.length_squared() > 0.0001
    if not lock_halfway_initialized:
        push_error("Bittaran: front/rear shin midpoint axis is degenerate")


func get_front_rear_lock_midpoint_world() -> Vector3:
    if boss_model == null or not lock_halfway_initialized:
        return Vector3.ZERO
    var mids: PackedVector3Array = _current_front_rear_lock_mids()
    return (mids[0] + mids[1]) * 0.5


func _current_front_rear_lock_mids() -> PackedVector3Array:
    # Planted feet lag chassis yaw. Use final IK shin X/Z, rather than
    # rotating the initial stance with the chassis. Selection-box Y stays
    # fixed by get_shin_selection_box and is ignored by the half-plane.
    var front: Vector3 = (get_shin_selection_box("leg_fl").get_center()
        + get_shin_selection_box("leg_fr").get_center()) * 0.5
    var rear: Vector3 = (get_shin_selection_box("leg_rl").get_center()
        + get_shin_selection_box("leg_rr").get_center()) * 0.5
    return PackedVector3Array([front, rear])


func _lockable_shin_pair(origin: Vector3) -> Array[String]:
    ## Exactly one shared boundary halfway between *both* front shins
    ## and *both* rear shins. Crossing it from either direction is equally
    ## immediate. Both directions use the same final, visible shin pose.
    if boss_model == null or not lock_halfway_initialized:
        return ["leg_fl", "leg_fr"]
    var mids: PackedVector3Array = _current_front_rear_lock_mids()
    var middle: Vector3 = (mids[0] + mids[1]) * 0.5
    var front_axis: Vector2 = Vector2(
        mids[0].x - mids[1].x, mids[0].z - mids[1].z)
    var relative: Vector2 = Vector2(
        origin.x - middle.x, origin.z - middle.z)
    if relative.dot(front_axis) >= 0.0:
        return ["leg_fl", "leg_fr"]
    return ["leg_rl", "leg_rr"]


func _nearest_lockable_shin(origin: Vector3, _body_center: Vector3) -> String:
    ## After the two-line test misses, keep the same front/rear half-plane;
    ## selecting a deep back leg due to depth/Y would skew the switch point.
    var pair: Array[String] = _lockable_shin_pair(origin)
    var best_id: String = pair[0]
    var best_score: float = INF
    for id in pair:
        var box: AABB = get_shin_selection_box(id)
        var aim: Vector3 = box.get_center()
        var delta: Vector2 = Vector2(aim.x - origin.x, aim.z - origin.z)
        var score: float = delta.length_squared()
        if score < best_score:
            best_score = score
            best_id = id
    return best_id


## The Bittaran-only two-line lock scan aims at the actual BODY mesh AABB
## center, not the target Node3D's pivot/root. Only X/Z of that mesh center
## matter: Y at both endpoints stays SERA's Y, so both beams are horizontal
## even during crouch, walk bob, and a leg-break tumble.
## Reuse the shared +/-0.25m perpendicular spacing and debug visualization.
func get_actor_parallel_lock_segments(actor_origin: Vector3,
        body_center: Vector3) -> PackedVector3Array:
    var real_center: Vector3 = (
        get_body_hit_aabb().get_center() if installed else body_center)
    var horizontal_target := Vector3(
        real_center.x, actor_origin.y, real_center.z)
    return super.get_actor_parallel_lock_segments(
        actor_origin, horizontal_target)


func select_actor_parallel_lines_part(origin: Vector3,
        body_center: Vector3) -> String:
    if down_lock_enabled:
        return super.select_actor_parallel_lines_part(origin, body_center)
    var segments: PackedVector3Array = get_actor_parallel_lock_segments(
        origin, body_center)
    var best_score: float = INF
    var result: String = ""
    # Compare only the two shins on the front/rear side of the *midpoint*.
    # The old all-four min-ray-entry distance biased near/far transition.
    for id in _lockable_shin_pair(origin):
        var score: float = _parallel_lock_part_distance(segments, id)
        if score < best_score:
            best_score = score
            result = id
    if not result.is_empty():
        return result
    return _nearest_lockable_shin(origin, body_center)

func select_stable_actor_parallel_lines_part(origin: Vector3,
        body_center: Vector3, previous_id: String) -> String:
    # AUTO-only left/right ownership. Preserve the exact midpoint rule for
    # front/rear switching; this policy operates ONLY inside that pair.
    # Both enlarged shin boxes can pass both rays directly in front of the
    # boss. Comparing first-intersection distances then alternates left/right
    # whenever either grounded shin moves a few centimetres.
    if down_lock_enabled:
        return select_actor_parallel_lines_part(origin, body_center)
    var pair: Array[String] = _lockable_shin_pair(origin)
    var first: String = pair[0]
    var second: String = pair[1]
    var first_center: Vector3 = get_shin_selection_box(first).get_center()
    var second_center: Vector3 = get_shin_selection_box(second).get_center()
    var lateral_axis := Vector2(
        first_center.x - second_center.x, first_center.z - second_center.z)
    if lateral_axis.length_squared() < 0.0001:
        return select_actor_parallel_lines_part(origin, body_center)
    lateral_axis = lateral_axis.normalized()
    var midpoint: Vector3 = (first_center + second_center) * 0.5
    var relative := Vector2(origin.x - midpoint.x, origin.z - midpoint.z)
    var side_meters: float = relative.dot(lateral_axis)
    # A currently locked shin wins the central ambiguity corridor. No
    # timer/debounce: crossing 0.65m into the other side switches THIS tick.
    if previous_id == first and side_meters >= -LATERAL_SHIN_LOCK_HYSTERESIS_METERS:
        return first
    if previous_id == second and side_meters <= LATERAL_SHIN_LOCK_HYSTERESIS_METERS:
        return second
    # No previous lock (spawn), or a decisive crossover: one deterministic
    # side, rather than frame-to-frame ray-entry-distance competition.
    var preferred: String = first if side_meters >= 0.0 else second
    var alternate: String = second if preferred == first else first
    var rays: PackedVector3Array = get_actor_parallel_lock_segments(
        origin, body_center)
    if _parallel_lock_part_distance(rays, preferred) < INF:
        return preferred
    if _parallel_lock_part_distance(rays, alternate) < INF:
        return alternate
    # As with the existing selector, keep a nearest fallback where neither
    # oversized shin intersects both rays (e.g. almost side-on).
    return preferred


func select_actor_center_line_part(origin: Vector3,
        body_center: Vector3) -> String:
    if down_lock_enabled:
        return super.select_actor_center_line_part(origin, body_center)
    return _nearest_lockable_shin(origin, body_center)

func select_camera_front_part(view_camera: Camera3D,
        current: String) -> String:
    var result: String = super.select_camera_front_part(view_camera, current)
    if not down_lock_enabled and (result.is_empty() or result == "head"
            or result == BODY_MANUAL_LOCK_ID):
        return _nearest_lockable_shin(
            view_camera.global_position if view_camera != null
            else global_position + Vector3(0, 0, 10), get_body_hit_aabb().get_center())
    return result

func _bounds(id: String) -> AABB:
    id = _normalize_boss_part(id)
    if not installed or not bone_nodes.has(id):
        return AABB(Vector3(-0.4, 0.0, -0.4), Vector3(0.8, 0.8, 0.8))
    var points: Array[Vector3] = []
    # A shin lock follows the lower bone and its foot, not the whole leg.
    _append_mesh_bounds(bone_nodes[id], points, id.begins_with("leg_"))
    if points.is_empty():
        return AABB(bone_nodes[id].global_position - Vector3.ONE * 0.4,
            Vector3.ONE * 0.8)
    var minimum: Vector3 = points[0]
    var maximum: Vector3 = points[0]
    for point in points:
        minimum = minimum.min(point)
        maximum = maximum.max(point)
    var size: Vector3 = maximum - minimum
    var minimum_size: Vector3 = MIN_BODY_BOX if id.is_empty() or id == "head" else MIN_SHIN_BOX
    size = size.max(minimum_size)
    var center: Vector3 = (maximum + minimum) * 0.5
    return AABB(center - size * 0.5, size)

## Bounding box of the SHIN's mesh only. The authored Foot is a child of the
## lower-leg joint and must not inflate a box intended for the shin itself.
func _shin_mesh_bounds(id: String) -> AABB:
    if not SHIN_BONES.has(id) or not bone_nodes.has(id):
        return AABB()
    var vertices: Array[Vector3] = []
    _append_mesh_bounds(bone_nodes[id], vertices, false)
    if vertices.is_empty():
        return _bounds(id)
    var low: Vector3 = vertices[0]
    var high: Vector3 = vertices[0]
    for vertex in vertices:
        low = low.min(vertex)
        high = high.max(vertex)
    return AABB(low, high - low)

func get_shin_selection_box(id: String) -> AABB:
    ## Read-only world-space volume for lock diagnostics and tests. This
    ## deliberately differs from get_part_aabb(), which stays melee-sized.
    if not SHIN_BONES.has(id):
        return AABB()
    if not shin_selection_standing.has(id):
        return AABB()
    var standing: Dictionary = shin_selection_standing[id]
    var box: AABB = _shin_mesh_bounds(id)
    var current: Vector3 = box.get_center()
    var locked_center := Vector3(current.x, float(standing["world_y"]), current.z)
    var scaled_size: Vector3 = standing["box_size"]
    return AABB(locked_center - scaled_size * 0.5, scaled_size)

func get_head_swing_aabb() -> AABB:
    # The neck/root is integrated into the body and can have overlapping
    # world-AABB bounds even at the untouched Blockbench bind pose. Only
    # the front, articulated nose/face portion sweeps into the four legs.
    var head: Node3D = bone_nodes.get("head") as Node3D
    if head == null:
        return AABB()
    var vertices: Array[Vector3] = []
    _append_mesh_bounds(head, vertices, false)
    if vertices.is_empty():
        return AABB()
    var nearest: float = INF
    var furthest: float = -INF
    for world in vertices:
        var depth: float = -head.to_local(world).z
        nearest = minf(nearest, depth)
        furthest = maxf(furthest, depth)
    var threshold: float = lerpf(nearest, furthest, 0.55)
    var filtered: Array[Vector3] = []
    for world in vertices:
        if -head.to_local(world).z >= threshold:
            filtered.append(world)
    if filtered.is_empty():
        return AABB()
    var low: Vector3 = filtered[0]
    var high: Vector3 = filtered[0]
    for p in filtered:
        low = low.min(p)
        high = high.max(p)
    return AABB(low, high - low)


func get_leg_visual_aabb(id: String) -> AABB:
    # Full upper/lower/foot mesh bound for HEAD swing clearance, not the
    # shin-only AUTO hitbox or the larger lock-selection Area3D.
    if not installed or not LEG_ROOT_BONES.has(id):
        return AABB()
    var root_leg: Node3D = boss_model.find_child(
        str(LEG_ROOT_BONES[id]), true, false) as Node3D
    if root_leg == null:
        return AABB()
    var points: Array[Vector3] = []
    _append_mesh_bounds(root_leg, points, true)
    if points.is_empty():
        return AABB()
    var low: Vector3 = points[0]
    var high: Vector3 = points[0]
    for p in points:
        low = low.min(p)
        high = high.max(p)
    return AABB(low, high - low)


func _append_component_visual_boxes(node: Node3D,
        boxes: Array[AABB]) -> void:
    # A full leg AABB contains large EMPTY corners between the bent upper
    # limb, shin and foot. Component boxes prevent the head from treating
    # that empty space as solid when it starts tracking during stand-up.
    for child in node.get_children():
        if child is MeshInstance3D:
            var piece: MeshInstance3D = child as MeshInstance3D
            if piece.mesh == null:
                continue
            var source: AABB = piece.mesh.get_aabb()
            var first: Vector3 = piece.to_global(source.get_endpoint(0))
            var low: Vector3 = first
            var high: Vector3 = first
            for i in range(1, 8):
                var corner: Vector3 = piece.to_global(source.get_endpoint(i))
                low = low.min(corner)
                high = high.max(corner)
            boxes.append(AABB(low, high - low))
        elif child is Node3D and not child is Area3D:
            _append_component_visual_boxes(child as Node3D, boxes)


func get_leg_visual_mesh_boxes(id: String) -> Array[AABB]:
    # Read-only real mesh-component bounds, never the oversized camera-lock
    # volume. Includes every upper arm, lower arm and foot mesh.
    var boxes: Array[AABB] = []
    if not installed or not LEG_ROOT_BONES.has(id):
        return boxes
    var root_leg: Node3D = boss_model.find_child(
        str(LEG_ROOT_BONES[id]), true, false) as Node3D
    if root_leg != null:
        _append_component_visual_boxes(root_leg, boxes)
    return boxes


func get_body_hit_aabb() -> AABB:
    return _bounds("")

func get_part_center(id: String) -> Vector3:
    id = _normalize_boss_part(id)
    if not installed or not bone_nodes.has(id):
        return super.get_part_center(id)
    return _bounds(id).get_center()

func get_part_aim_world(id: String) -> Vector3:
    id = _normalize_boss_part(id)
    if not installed or not bone_nodes.has(id):
        return super.get_part_aim_world(id)
    return _bounds(id).get_center()

func get_part_local_aim(id: String) -> Vector3:
    id = _normalize_boss_part(id)
    if not installed or not bone_nodes.has(id):
        return super.get_part_local_aim(id)
    return _bounds(id).get_center() - boss_model.get_parent().global_position

func get_part_aabb(id: String) -> AABB:
    id = _normalize_boss_part(id)
    if not installed or not bone_nodes.has(id):
        return super.get_part_aabb(id)
    return _bounds(id)

func _camera_center_line_part_distance(camera_origin: Vector3,
        body_center: Vector3, id: String) -> float:
    return _camera_lock_part_volume_distance(camera_origin, body_center, id)

func _camera_center_line_body_distance(camera_origin: Vector3,
        body_center: Vector3) -> float:
    return _camera_lock_body_volume_distance(camera_origin, body_center)

func sync_bittaran_parts() -> void:
    if not installed:
        return
    for id in camera_areas:
        var bounds: AABB = _bounds(id)
        var area: Area3D = camera_areas[id]
        # Only the four shin lock-selection volumes are enlarged/fixed-height.
        # The head and BODY retain their previous collision-independent 1.15x
        # selection boxes; all actual attack/body colliders remain unchanged.
        var lock_center: Vector3 = bounds.get_center()
        var lock_size: Vector3 = bounds.size * LOCK_VOLUME_EXPANSION
        if SHIN_BONES.has(id):
            if not shin_selection_standing.has(id):
                var authored_shin: AABB = _shin_mesh_bounds(id)
                shin_selection_standing[id] = {
                    "world_y": authored_shin.get_center().y,
                    "box_size": authored_shin.size * SHIN_SELECTION_VOLUME_SCALE
                }
            var selection_box: AABB = get_shin_selection_box(id)
            lock_center = selection_box.get_center()
            lock_size = selection_box.size
        # Area3D is camera/lock math only: zero collision layers and masks.
        # World-space identity cancels rotation and inherited 2x boss scale.
        area.global_transform = Transform3D(Basis.IDENTITY, lock_center)
        var collision: CollisionShape3D = area.get_node("CameraOnlyBox")
        var box: BoxShape3D = collision.shape
        box.size = lock_size
        var physical: CollisionShape3D = combat_shapes[id]
        var box_solid: BoxShape3D = physical.shape
        box_solid.size = bounds.size
        # Nodes live under a 2x parent; the global basis cancels that scale
        # to preserve a true world-space AABB instead of scaling twice.
        physical.set_deferred("global_transform",
            Transform3D(Basis.IDENTITY, bounds.get_center()))

func get_part_name(id: String) -> String:
    return "BODY" if id == BODY_MANUAL_LOCK_ID else super.get_part_name(id)

func get_part_integrity(id: String) -> float:
    if id == BODY_MANUAL_LOCK_ID:
        var battle: Node = get_parent().get_parent().get_parent()
        return float(battle.get("target_hp")) if battle != null else 0.0
    return super.get_part_integrity(id)

func get_part_max_integrity(id: String) -> float:
    return BODY_MAX_HP if id == BODY_MANUAL_LOCK_ID else super.get_part_max_integrity(id)

func get_part_defense(id: String) -> float:
    return super.get_part_defense("") if id == BODY_MANUAL_LOCK_ID else super.get_part_defense(id)

func apply_part_hit(id: String, raw_attack: float, raw_break: float) -> Dictionary:
    # Explicit manual BODY is a core hit, not a sixth breakable gauge.
    return super.apply_part_hit(_normalize_boss_part(id), raw_attack, raw_break)

func trigger_part_hit_fx(id: String, duration: float) -> void:
    id = _normalize_boss_part(id)
    if not fx_meshes.has(id):
        return
    if not id.is_empty():
        super.trigger_part_hit_fx(id, duration)
    fx_timers[id] = maxf(0.001, duration)
    fx_durations[id] = maxf(0.001, duration)

func advance_part_hit_fx(delta: float) -> void:
    super.advance_part_hit_fx(delta)
    for id in fx_meshes:
        var remaining: float = maxf(0.0, float(fx_timers[id]) - maxf(0.0, delta))
        fx_timers[id] = remaining
        var power: float = remaining / maxf(float(fx_durations[id]), 0.001)
        var destroyed: bool = (not id.is_empty() and parts.has(id)
            and bool(parts[id]["broken"]))
        for record in fx_meshes[id]:
            var material: StandardMaterial3D = record["material"]
            var intact: Color = record["albedo"]
            var base: Color = intact.lerp(BROKEN_STEEL, 0.78) if destroyed else intact
            material.albedo_color = base.lerp(HIT_COLOR, power * 0.8)
            material.emission_enabled = (destroyed or power > 0.0
                or bool(record["emission_on"]))
            var glow: Color = BROKEN_GLOW if destroyed else record["emission"]
            material.emission = glow.lerp(HIT_EMISSION, power)
            material.emission_energy_multiplier = lerpf(
                0.18 if destroyed else float(record["energy"]), 0.52, power)

func set_death_visual(power: float) -> void:
    # Opaque materials only; no transparent clone or lost depth testing.
    death_visual_power = clampf(power, 0.0, 1.0)
    for id in fx_meshes:
        for record in fx_meshes[id]:
            var material: StandardMaterial3D = record["material"]
            material.albedo_color = material.albedo_color.lerp(
                DEATH_STEEL, death_visual_power * 0.88)
            if death_visual_power > 0.0:
                material.emission_enabled = true
                material.emission = material.emission.lerp(
                    BROKEN_GLOW, death_visual_power)
                material.emission_energy_multiplier = lerpf(
                    material.emission_energy_multiplier, 0.24, death_visual_power)

func reset_parts() -> void:
    down_lock_enabled = false
    head_support_leg_id = ""
    death_visual_power = 0.0
    super.reset_parts()
    for id in fx_timers:
        fx_timers[id] = 0.0
    advance_part_hit_fx(0.0)
