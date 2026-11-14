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
const LOCK_VOLUME_EXPANSION: float = 1.15
const MIN_SHIN_BOX: Vector3 = Vector3(0.52, 0.65, 0.52)
const MIN_BODY_BOX: Vector3 = Vector3(0.65, 0.55, 0.65)

var boss_model: Node3D
var collision_body: AnimatableBody3D
var bone_nodes: Dictionary = {}
var camera_areas: Dictionary = {}
var combat_shapes: Dictionary = {}
var fx_meshes: Dictionary = {}
var fx_timers: Dictionary = {}
var fx_durations: Dictionary = {}
var installed: bool = false

func _ready() -> void:
    super._ready()

func setup_bittaran(model: Node3D, moving_body: AnimatableBody3D) -> bool:
    boss_model = model
    collision_body = moving_body
    installed = false
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
    return true

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

func _bounds(id: String) -> AABB:
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

func get_body_hit_aabb() -> AABB:
    return _bounds("")

func get_part_center(id: String) -> Vector3:
    if not installed or not bone_nodes.has(id):
        return super.get_part_center(id)
    return _bounds(id).get_center()

func get_part_aim_world(id: String) -> Vector3:
    if not installed or not bone_nodes.has(id):
        return super.get_part_aim_world(id)
    return _bounds(id).get_center()

func get_part_local_aim(id: String) -> Vector3:
    if not installed or not bone_nodes.has(id):
        return super.get_part_local_aim(id)
    return _bounds(id).get_center() - boss_model.get_parent().global_position

func get_part_aabb(id: String) -> AABB:
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
        # World-oriented volumes follow each articulated shin and head.
        area.global_transform = Transform3D(Basis.IDENTITY, bounds.get_center())
        var collision: CollisionShape3D = area.get_node("CameraOnlyBox")
        var box: BoxShape3D = collision.shape
        box.size = bounds.size * LOCK_VOLUME_EXPANSION
        var physical: CollisionShape3D = combat_shapes[id]
        var box_solid: BoxShape3D = physical.shape
        box_solid.size = bounds.size
        # Nodes live under a 2x parent; the global basis cancels that scale
        # to preserve a true world-space AABB instead of scaling twice.
        physical.set_deferred("global_transform",
            Transform3D(Basis.IDENTITY, bounds.get_center()))

func trigger_part_hit_fx(id: String, duration: float) -> void:
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
        for record in fx_meshes[id]:
            var material: StandardMaterial3D = record["material"]
            material.albedo_color = (record["albedo"] as Color).lerp(
                HIT_COLOR, power * 0.8)
            material.emission_enabled = power > 0.0 or bool(record["emission_on"])
            material.emission = (record["emission"] as Color).lerp(
                HIT_EMISSION, power)
            material.emission_energy_multiplier = lerpf(
                float(record["energy"]), 0.52, power)

func reset_parts() -> void:
    super.reset_parts()
    for id in fx_timers:
        fx_timers[id] = 0.0
    advance_part_hit_fx(0.0)
