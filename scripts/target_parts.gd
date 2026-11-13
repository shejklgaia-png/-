extends Node3D
## SERA v240: enlarged rectangular arm-like outriggers and four heavy legs.
## Opaque BoxMesh mechanical frames; no user Blockbench assets modified.
## The 2.0 x 2.0 x 3.4m torso keeps the authoritative collider and boss HP.

const CORE_HP_SHARE: float = 0.50
const EACH_PART_HP_SHARE: float = 0.10
const PART_ORDER = ["head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const LEG_IDS = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
# Head-only AUTO lock padding: a virtual cap above the existing head box.
# Never alter the authored geometry, collision shapes or attack hit volume.
const HEAD_LOCK_UPWARD_EXTENSION_METERS: float = 1.0
# v299: the former upper-only cap missed low, shallow-angle camera rays,
# so BODY (which always intersects the center line) won before HEAD.
# Extend the head-only virtual box toward the authored +Z face of the boss.
const HEAD_LOCK_FORWARD_EXTENSION_METERS: float = 0.85
# v304: separate CAMERA/AUTO volume for each of six selectable modules.
# A 15% size increase wraps the entire part rather than each tiny metal
# strut independently. No contact, melee or movement shape uses this size.
const CAMERA_LOCK_VOLUME_SCALE: float = 1.15
const SELECTION_HYSTERESIS_RADIANS: float = 0.13
const CAMERA_PART_LOCK_HYSTERESIS: float = 0.065
const CAMERA_PART_DISTANCE_TIE_WEIGHT: float = 0.001
const CORE_DEFENSE: float = 0.14
# v289: use the same dark-red contact flash and wobble as the central boss.
const PART_HIT_DARK_COLOR: Color = Color("632535")
const PART_HIT_GLOW_COLOR: Color = Color("6b1727")
const PART_HIT_WOBBLE_METERS: float = 0.09
const PART_HIT_WOBBLE_DEGREES: float = 6.0

var parts: Dictionary = {}
var core_camera_lock_area: Area3D

# These invisible Area3D/BoxShape3D nodes are reference volumes ONLY:
# layers/masks zero, no monitoring, no physics or attack contact callbacks.
# Local-space segment tests below use the shapes directly, not PhysicsServer.
func _create_camera_lock_volume(owner: Node3D, name: String,
        model_size: Vector3, extra_size: Vector3 = Vector3.ZERO,
        center_offset: Vector3 = Vector3.ZERO) -> Area3D:
    var area := Area3D.new()
    area.name = name
    area.collision_layer = 0
    area.collision_mask = 0
    area.monitoring = false
    area.monitorable = false
    area.position = center_offset
    var shape := CollisionShape3D.new()
    shape.name = "CameraOnlyBox"
    var box := BoxShape3D.new()
    box.size = (model_size + extra_size) * CAMERA_LOCK_VOLUME_SCALE
    shape.shape = box
    area.add_child(shape)
    owner.add_child(area)
    return area


func _camera_lock_volume_distance(origin: Vector3, destination: Vector3,
        area: Area3D) -> float:
    if area == null or not area.is_inside_tree():
        return INF
    var collision: CollisionShape3D = area.get_node_or_null(
        "CameraOnlyBox") as CollisionShape3D
    if collision == null or not collision.shape is BoxShape3D:
        return INF
    var size: Vector3 = (collision.shape as BoxShape3D).size
    var entry: Variant = AABB(-size * 0.5, size).intersects_segment(
        area.to_local(origin), area.to_local(destination))
    if entry == null:
        return INF
    return origin.distance_squared_to(area.to_global(entry))


func _camera_lock_part_volume_distance(origin: Vector3,
        destination: Vector3, id: String) -> float:
    if not is_targetable(id):
        return INF
    return _camera_lock_volume_distance(origin, destination, parts[id]["camera_lock_area"])


func _camera_lock_body_volume_distance(origin: Vector3,
        destination: Vector3) -> float:
    return _camera_lock_volume_distance(origin, destination, core_camera_lock_area)


func _ready() -> void:
    # Torso is 2m wide/high and 3.4m long (front/rear Z = +/-1.7m).
    # Four enlarged 2m-tall arm/leg frames attach along the sides.
    # Their outward guards are mirrored across X and front/rear Z.
    _add_part("head", "HEAD", Vector3(0.0, -0.44, 1.85),
        Vector3(1.48, 0.82, 0.96), Vector3(0.0, -0.03, 0.37),
        100.0, 0.20, 0.10, "change", Color("da755a"))
    # v302: the limb's model pivot is the center of its full 2m-high
    # frame; aim for that center instead of the previous outer/toe offset.
    # Only lock/aim points change. Meshes and hitboxes remain unchanged.
    _add_part("leg_fl", "FRONT L", Vector3(-1.23, -0.53, 1.27),
        Vector3(2.24, 2.00, 1.36), Vector3(0.0, 0.0, 0.0),
        100.0, 0.12, 0.00, "remain", Color("b9604c"))
    _add_part("leg_fr", "FRONT R", Vector3(1.23, -0.53, 1.27),
        Vector3(2.24, 2.00, 1.36), Vector3(0.0, 0.0, 0.0),
        100.0, 0.12, 0.00, "remain", Color("b9604c"))
    _add_part("leg_rl", "REAR L", Vector3(-1.23, -0.53, -1.27),
        Vector3(2.24, 2.00, 1.36), Vector3(0.0, 0.0, 0.0),
        100.0, 0.16, 0.12, "remain", Color("a95043"))
    _add_part("leg_rr", "REAR R", Vector3(1.23, -0.53, -1.27),
        Vector3(2.24, 2.00, 1.36), Vector3(0.0, 0.0, 0.0),
        100.0, 0.16, 0.12, "remain", Color("a95043"))
    # The central BODY also competes on the same enlarged-camera-box
    # intersection basis; it is not a forced default lock.
    var core: MeshInstance3D = get_parent() as MeshInstance3D
    if core != null and core.mesh is BoxMesh:
        core_camera_lock_area = _create_camera_lock_volume(
            core, "BodyCameraLockArea", (core.mesh as BoxMesh).size)

func _make_box(owner: Node3D, name: String, offset: Vector3,
        dimensions: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var box := BoxMesh.new()
    box.size = dimensions
    mesh.mesh = box
    mesh.material_override = material
    mesh.position = offset
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    owner.add_child(mesh)
    return mesh

func _make_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.12
    material.roughness = 0.68
    return material

func _build_head_frame(pivot: Node3D, shell: StandardMaterial3D,
        accent: StandardMaterial3D, frame: StandardMaterial3D,
        dark: StandardMaterial3D) -> MeshInstance3D:
    # A short attachment to the +Z face makes the sensor a plugged-in module.
    _make_box(pivot, "NeckMount", Vector3(0.0, -0.08, -0.23),
        Vector3(0.58, 0.34, 0.38), frame)
    _make_box(pivot, "SensorHousing", Vector3.ZERO,
        Vector3(1.12, 0.56, 0.68), shell)
    _make_box(pivot, "SideRailL", Vector3(-0.58, -0.02, 0.04),
        Vector3(0.13, 0.40, 0.52), frame)
    _make_box(pivot, "SideRailR", Vector3(0.58, -0.02, 0.04),
        Vector3(0.13, 0.40, 0.52), frame)
    _make_box(pivot, "UpperCrossmember", Vector3(0.0, 0.29, -0.05),
        Vector3(0.98, 0.12, 0.34), frame)
    _make_box(pivot, "LowerCrossmember", Vector3(0.0, -0.27, -0.04),
        Vector3(0.87, 0.10, 0.28), dark)
    _make_box(pivot, "Visor", Vector3(0.0, 0.02, 0.36),
        Vector3(0.72, 0.18, 0.08), accent)
    # A visible exposed frame sits in front of the visor after head break.
    var fracture: MeshInstance3D = _make_box(pivot, "FracturedHead",
        Vector3(0.0, 0.02, 0.42), Vector3(0.60, 0.37, 0.11), dark)
    fracture.visible = false
    return fracture


func _build_leg_frame(pivot: Node3D, side: float, fore_aft: float,
        shell: StandardMaterial3D, accent: StandardMaterial3D,
        frame: StandardMaterial3D, dark: StandardMaterial3D) -> void:
    # A heavy rectangular arm/shoulder frame feeds into the broad 2m leg.
    # X points outside the body; fore_aft mirrors protrusions on +/-Z.
    # Top local Y=+1.00, sole=-1.00: match the previous 2m height.
    _make_box(pivot, "SideMount", Vector3(-side * 0.24, 0.83, 0.0),
        Vector3(0.90, 0.34, 0.78), dark)
    _make_box(pivot, "HipJoint", Vector3(-side * 0.02, 0.76, 0.0),
        Vector3(0.64, 0.48, 0.62), accent)
    _make_box(pivot, "Outrigger", Vector3(side * 0.22, 0.63, 0.0),
        Vector3(0.95, 0.34, 0.52), frame)
    _make_box(pivot, "ShoulderArmor", Vector3(side * 0.42, 0.59, 0.0),
        Vector3(0.78, 0.54, 0.74), shell)
    _make_box(pivot, "UpperStrut", Vector3(side * 0.45, 0.30, 0.0),
        Vector3(0.46, 1.02, 0.46), shell)
    _make_box(pivot, "KneeHinge", Vector3(side * 0.49, -0.24, 0.0),
        Vector3(0.60, 0.44, 0.55), accent)
    _make_box(pivot, "LowerStrut", Vector3(side * 0.50, -0.55, 0.0),
        Vector3(0.38, 0.74, 0.38), frame)
    _make_box(pivot, "Piston", Vector3(side * 0.48, -0.52, fore_aft * 0.20),
        Vector3(0.16, 0.66, 0.15), accent)
    _make_box(pivot, "OuterPlate", Vector3(side * 0.73, -0.02, 0.0),
        Vector3(0.25, 1.08, 0.60), shell)
    _make_box(pivot, "ForearmGuard", Vector3(side * 0.70, -0.48, fore_aft * 0.12),
        Vector3(0.44, 0.70, 0.52), shell)
    _make_box(pivot, "ArmTip", Vector3(side * 0.72, -0.35, fore_aft * 0.42),
        Vector3(0.48, 0.82, 0.45), frame)
    _make_box(pivot, "HeelBrace", Vector3(side * 0.50, -0.81, -fore_aft * 0.14),
        Vector3(0.48, 0.22, 0.48), dark)
    _make_box(pivot, "Foot", Vector3(side * 0.58, -0.91, fore_aft * 0.18),
        Vector3(0.84, 0.18, 0.84), accent)


func _add_part(id: String, display: String, center: Vector3,
        dimensions: Vector3, aim_offset: Vector3, integrity: float,
        defense: float, break_defense: float, break_mode: String,
        color: Color) -> void:
    var pivot := Node3D.new()
    pivot.name = id
    pivot.position = center
    add_child(pivot)
    var shell: StandardMaterial3D = _make_material(color)
    var accent: StandardMaterial3D = _make_material(Color("5d4140"))
    var frame: StandardMaterial3D = _make_material(Color("39444d"))
    var dark: StandardMaterial3D = _make_material(Color("283039"))
    var fracture: MeshInstance3D = null
    if id == "head":
        fracture = _build_head_frame(pivot, shell, accent, frame, dark)
    else:
        # The X coordinate identifies the left/right body attachment.
        var side: float = signf(center.x)
        var fore_aft: float = signf(center.z)
        _build_leg_frame(pivot, side, fore_aft, shell, accent, frame, dark)
    # AUTO uses a dedicated 115%-sized invisible camera volume. Existing
    # combat hitboxes, all real BoxMesh components and movement collision
    # still use the unscaled original dimensions/individual pieces.
    var extra: Vector3 = Vector3.ZERO
    var shift: Vector3 = Vector3.ZERO
    if id == "head":
        # Keep the established low-HEAD acquisition cap + front extension,
        # and expand that entire lock-only volume by another 15%.
        extra = Vector3(0.0, HEAD_LOCK_UPWARD_EXTENSION_METERS,
            HEAD_LOCK_FORWARD_EXTENSION_METERS)
        shift = Vector3(0.0, HEAD_LOCK_UPWARD_EXTENSION_METERS * 0.5,
            HEAD_LOCK_FORWARD_EXTENSION_METERS * 0.5)
    var camera_area: Area3D = _create_camera_lock_volume(
        pivot, "CameraLockArea", dimensions, extra, shift)
    # Normal part metadata still refers to original mesh/hitbox size.
    parts[id] = {
        "id": id, "display": display, "node": pivot, "size": dimensions,
        "camera_lock_area": camera_area,
        "aim": aim_offset, "max_integrity": integrity,
        "integrity": integrity, "defense": defense,
        "break_defense": break_defense, "break_mode": break_mode,
        "broken": false, "shell": shell, "accent": accent,
        "frame": frame, "dark": dark, "rest_position": center,
        "original_color": color, "rest_shell": color,
        "rest_accent": Color("5d4140"),
        "rest_frame": Color("39444d"), "rest_dark": Color("283039"),
        "hit_fx_remaining": 0.0, "hit_fx_duration": 0.145,
        "fracture": fracture,
        "hp_share": EACH_PART_HP_SHARE
    }


# v251 collision contract:
# - Build a BoxShape3D for each visible BoxMesh of the existing head/legs.
#   Do not replace small real shapes with one large part AABB; that would
#   block legitimate empty space around the exposed frame.
# - Shapes are direct children of the existing AnimatableBody3D, and its
#   parent target node moves them together during training locomotion.
# - A compact extra guard per leg closes the body/limb seam near the torso.
# - These are movement solids, NOT combat hitboxes or lock/occlusion bounds.
func _append_movement_shape(body: CollisionObject3D, part_id: String,
        label: String, mesh_transform: Transform3D,
        dimensions: Vector3, initially_disabled: bool) -> CollisionShape3D:
    var collider := CollisionShape3D.new()
    collider.name = "%s_%s_Solid" % [part_id, label]
    var box := BoxShape3D.new()
    box.size = dimensions
    collider.shape = box
    collider.transform = body.global_transform.affine_inverse() * mesh_transform
    collider.disabled = initially_disabled
    body.add_child(collider)
    return collider

func install_movement_colliders(body: CollisionObject3D) -> void:
    # Called once AFTER TargetBreakableParts enters the scene tree, so the
    # source mesh global transforms and collider global transform are valid.
    for id in PART_ORDER:
        var part: Dictionary = parts[id]
        var pivot: Node3D = part["node"]
        var shapes: Array[CollisionShape3D] = []
        var fracture_shape: CollisionShape3D = null
        for child in pivot.get_children():
            if not child is MeshInstance3D:
                continue
            var visible_box: MeshInstance3D = child as MeshInstance3D
            if not visible_box.mesh is BoxMesh:
                continue
            var box_mesh: BoxMesh = visible_box.mesh as BoxMesh
            var is_fracture: bool = visible_box == part["fracture"]
            var solid: CollisionShape3D = _append_movement_shape(
                body, id, visible_box.name, visible_box.global_transform,
                box_mesh.size, is_fracture)
            shapes.append(solid)
            if is_fracture:
                fracture_shape = solid
        if id in LEG_IDS:
            # Ground-to-hip connector. This overlaps the original torso
            # and outer struts, closing the passable inside corner without
            # enveloping the whole leg or its open outer frame.
            var side: float = signf(pivot.position.x)
            var joint_pose: Transform3D = pivot.global_transform * Transform3D(
                Basis.IDENTITY, Vector3(-side * 0.19, -0.06, 0.0))
            shapes.append(_append_movement_shape(body, id, "BodyJunction",
                joint_pose, Vector3(0.96, 1.85, 0.62), false))
        part["movement_colliders"] = shapes
        part["fracture_collider"] = fracture_shape

func _set_part_movement_collision(id: String, enabled: bool) -> void:
    if not parts.has(id):
        return
    var part: Dictionary = parts[id]
    for solid in part.get("movement_colliders", []):
        var collider: CollisionShape3D = solid as CollisionShape3D
        if collider == null:
            continue
        var is_fracture: bool = collider == part.get("fracture_collider")
        # Fracture armor is only solid while its visual mesh is visible.
        var should_enable: bool = enabled and (
            not is_fracture or bool(part["broken"]))
        # Collision shapes may be changed during a physics contact callback.
        # Defer it instead of mutating PhysicsServer shape state mid-query.
        collider.set_deferred("disabled", not should_enable)

func reset_parts() -> void:
    for id in PART_ORDER:
        var part: Dictionary = parts[id]
        part["integrity"] = part["max_integrity"]
        part["broken"] = false
        part["hit_fx_remaining"] = 0.0
        part["rest_shell"] = part["original_color"]
        part["rest_accent"] = Color("5d4140")
        _set_part_movement_collision(id, true)
        var pivot: Node3D = part["node"]
        pivot.visible = true
        pivot.position = part["rest_position"]
        pivot.rotation_degrees = Vector3.ZERO
        var fracture: MeshInstance3D = part["fracture"]
        if fracture != null:
            fracture.visible = false
        _set_part_hit_visual(id, 0.0)


# A broken part remains addressable until the current combo ends, even
# though AUTO/MANUAL new-target selection excludes broken candidates.
func has_part(id: String) -> bool:
    return parts.has(id)


func trigger_part_hit_fx(id: String, duration: float) -> void:
    if not has_part(id):
        return
    var part: Dictionary = parts[id]
    part["hit_fx_duration"] = maxf(0.001, duration)
    part["hit_fx_remaining"] = part["hit_fx_duration"]


# Same .145s dark-red albedo, subdued glow and wobble as the boss core,
# but only the struck part's unique materials and visual pivot are affected.
func _set_part_hit_visual(id: String, ratio: float) -> void:
    var part: Dictionary = parts[id]
    var mix: float = clampf(ratio, 0.0, 1.0)
    for slot in ["shell", "accent", "frame", "dark"]:
        var material: StandardMaterial3D = part[slot]
        var base: Color = part["rest_" + slot]
        material.albedo_color = base.lerp(PART_HIT_DARK_COLOR, mix * 0.78)
        material.emission_enabled = mix > 0.0
        material.emission = Color("a92724").lerp(PART_HIT_GLOW_COLOR, mix)
        material.emission_energy_multiplier = lerpf(0.08, 0.03, mix)
    var pivot: Node3D = part["node"]
    var wobble: float = sin((1.0 - mix) * 44.0) * PART_HIT_WOBBLE_METERS * mix
    pivot.position = (part["rest_position"] as Vector3) + Vector3(wobble, 0.0, 0.0)
    pivot.rotation_degrees.z = sin((1.0 - mix) * 22.0) * (
        PART_HIT_WOBBLE_DEGREES * mix)


func advance_part_hit_fx(delta: float) -> void:
    for id in PART_ORDER:
        var part: Dictionary = parts[id]
        var remaining: float = float(part["hit_fx_remaining"])
        if remaining <= 0.0:
            continue
        remaining = maxf(0.0, remaining - maxf(delta, 0.0))
        part["hit_fx_remaining"] = remaining
        _set_part_hit_visual(id, remaining / float(part["hit_fx_duration"]))


# A destroyed module keeps its visible geometry, lock volume and attack AABB.
# Distinguish its functional state from whether an attack can still hit it.
func is_targetable(id: String) -> bool:
    return parts.has(id)


func is_intact(id: String) -> bool:
    return parts.has(id) and not bool(parts[id]["broken"])

func get_part_center(id: String) -> Vector3:
    if not parts.has(id):
        return global_position
    var node: Node3D = parts[id]["node"]
    return node.global_position

func get_part_aim_world(id: String) -> Vector3:
    if not parts.has(id):
        return global_position
    var node: Node3D = parts[id]["node"]
    return node.to_global(parts[id]["aim"])

func get_part_local_aim(id: String) -> Vector3:
    if not parts.has(id):
        return Vector3.ZERO
    var part: Dictionary = parts[id]
    var node: Node3D = part["node"]
    return node.position + part["aim"]

func get_part_aabb(id: String) -> AABB:
    var part: Dictionary = parts[id]
    var dimensions: Vector3 = part["size"]
    return AABB(get_part_center(id) - dimensions * 0.5, dimensions)

func get_part_defense(id: String) -> float:
    if is_targetable(id):
        return float(parts[id]["defense"])
    # The body/core uses the median, not an arbitrary extreme armor rating.
    var defenses: Array[float] = [CORE_DEFENSE]
    for part_id in PART_ORDER:
        defenses.append(float(parts[part_id]["defense"]))
    defenses.sort()
    return (defenses[2] + defenses[3]) * 0.5

func get_part_name(id: String) -> String:
    return str(parts[id]["display"]) if parts.has(id) else "CORE"

func get_part_integrity(id: String) -> float:
    return float(parts[id]["integrity"]) if parts.has(id) else 0.0

func get_part_max_integrity(id: String) -> float:
    return float(parts[id]["max_integrity"]) if parts.has(id) else 0.0

func status_line() -> String:
    var text_parts: Array[String] = []
    for id in PART_ORDER:
        var part: Dictionary = parts[id]
        var short: String = "H" if id == "head" else id.trim_prefix("leg_").to_upper()
        var state: String = "X" if bool(part["broken"]) else str(ceili(float(part["integrity"])))
        text_parts.append("%s:%s/%d" % [short, state, ceili(float(part["max_integrity"]))])
    return "PARTS  " + "  ".join(text_parts)

func broken_leg_count() -> int:
    var count: int = 0
    for id in LEG_IDS:
        if bool(parts[id]["broken"]):
            count += 1
    return count

func apply_part_hit(id: String, raw_attack: float, raw_break: float) -> Dictionary:
    # Broken modules retain their original defense and can absorb subsequent
    # attacks; only their separate break gauge stays at zero.
    var effective_id: String = id if is_targetable(id) else ""
    var defense: float = get_part_defense(effective_id)
    var boss_damage: int = maxi(1, roundi(maxf(0.0, raw_attack) * (1.0 - defense)))
    var result: Dictionary = {
        "part": effective_id, "body_damage": boss_damage,
        "part_damage": 0.0, "broken": false, "kind": "",
        "broken_legs": broken_leg_count()
    }
    if effective_id.is_empty():
        return result
    var part: Dictionary = parts[effective_id]
    var old_hp: float = float(part["integrity"])
    var break_damage: float = maxf(0.0, raw_break) * (
        1.0 - float(part["break_defense"]))
    part["integrity"] = maxf(0.0, old_hp - break_damage)
    result["part_damage"] = old_hp - float(part["integrity"])
    if old_hp > 0.0 and float(part["integrity"]) <= 0.0:
        part["broken"] = true
        var pivot: Node3D = part["node"]
        # Keep all destroyed limbs drawn and collidable; never remove
        # the front legs from the world on their breaking hit.
        pivot.visible = true
        if effective_id == "head":
            part["rest_shell"] = Color("5b6570")
            var fracture: MeshInstance3D = part["fracture"]
            if fracture != null:
                fracture.visible = true
        else:
            part["rest_shell"] = Color("4c555d")
            part["rest_accent"] = Color("283039")
        _set_part_movement_collision(effective_id, true)
        # The current hit timer flashes over this permanent broken palette.
        result["broken"] = true
        result["kind"] = "head" if effective_id == "head" else "leg"
        result["broken_legs"] = broken_leg_count()
    return result

# v296: Only real, currently visible BoxMesh pieces count as a limb hit.
# Work in each mesh's local coordinates so target yaw and animated part
# offsets cannot invalidate the line test. Bounding part AABBs deliberately
# do NOT count: their empty space contains no lockable geometry.
# INF means no hit on the finite origin->BODY-center segment (SERA in AUTO).
func _camera_center_line_part_distance(camera_origin: Vector3,
        body_center: Vector3, id: String) -> float:
    if not is_targetable(id) or camera_origin.distance_squared_to(body_center) < 0.000001:
        return INF
    var pivot: Node3D = parts[id]["node"]
    var closest: float = INF
    for child in pivot.get_children():
        if not child is MeshInstance3D:
            continue
        var mesh_node: MeshInstance3D = child as MeshInstance3D
        if not mesh_node.visible or not mesh_node.mesh is BoxMesh:
            continue
        var dimensions: Vector3 = (mesh_node.mesh as BoxMesh).size
        var local_origin: Vector3 = mesh_node.to_local(camera_origin)
        var local_center: Vector3 = mesh_node.to_local(body_center)
        var contact: Variant = AABB(
            -dimensions * 0.5, dimensions).intersects_segment(
                local_origin, local_center)
        if contact == null:
            continue
        var contact_world: Vector3 = mesh_node.to_global(contact)
        closest = minf(closest,
            camera_origin.distance_squared_to(contact_world))
    # v299: the original v297 upper-only cap overlapped the central torso.
    # Shallow sightlines entered BODY first whenever they passed below that
    # shallow cap, hiding HEAD despite its 1m vertical extension.
    # One head-only virtual AABB covers the original head extent, the same
    # 1m overhang above it, and 0.85m forward from its +Z face. This makes
    # frontal SERA-origin segments meet HEAD before BODY without any special
    # lock priority. No rendered mesh, attack hitbox or collider is changed.
    if id == "head":
        var head_size: Vector3 = parts[id]["size"]
        var overhead: AABB = AABB(
            Vector3(-head_size.x * 0.5, -head_size.y * 0.5,
                -head_size.z * 0.5),
            Vector3(head_size.x, head_size.y + HEAD_LOCK_UPWARD_EXTENSION_METERS,
                head_size.z + HEAD_LOCK_FORWARD_EXTENSION_METERS))
        var overhead_contact: Variant = overhead.intersects_segment(
            pivot.to_local(camera_origin), pivot.to_local(body_center))
        if overhead_contact != null:
            var overhead_world: Vector3 = pivot.to_global(overhead_contact)
            closest = minf(closest,
                camera_origin.distance_squared_to(overhead_world))
    return closest


# v298: The BODY is a real sixth selectable mesh, not an unconditional
# fallback. FloatingBox is the parent of the breakable parts and owns the
# authoritative 2m x 2m x 3.4m visible BoxMesh. Use the identical local-space
# finite-segment intersection and origin-distance score used by head/legs.
# The empty part ID is retained as BODY for HUD, damage and save compatibility.
func _camera_center_line_body_distance(camera_origin: Vector3,
        body_center: Vector3) -> float:
    var core_mesh: MeshInstance3D = get_parent() as MeshInstance3D
    if core_mesh == null or not core_mesh.visible or not core_mesh.mesh is BoxMesh:
        return INF
    if camera_origin.distance_squared_to(body_center) < 0.000001:
        return INF
    var core_size: Vector3 = (core_mesh.mesh as BoxMesh).size
    var contact: Variant = AABB(-core_size * 0.5, core_size).intersects_segment(
        core_mesh.to_local(camera_origin), core_mesh.to_local(body_center))
    if contact == null:
        return INF
    var contact_world: Vector3 = core_mesh.to_global(contact)
    return camera_origin.distance_squared_to(contact_world)


# v301: authoritative AUTO segment begins at SERA's collision-root world
# position and ends at the boss BODY center, not at the camera. These generic
# helpers use the SAME actual BoxMesh/HEAD virtual volume intersection and
# nearest first-contact comparison for all selectable parts including BODY.
func actor_center_line_hits_part(actor_origin: Vector3,
        body_center: Vector3, id: String) -> bool:
    if id.is_empty():
        return _camera_center_line_body_distance(actor_origin, body_center) < INF
    return _camera_center_line_part_distance(actor_origin, body_center, id) < INF


func select_actor_center_line_part(actor_origin: Vector3,
        body_center: Vector3) -> String:
    var closest: float = _camera_center_line_body_distance(actor_origin, body_center)
    var selected: String = ""
    for id in PART_ORDER:
        var distance: float = _camera_center_line_part_distance(
            actor_origin, body_center, id)
        if distance < closest:
            selected = id
            closest = distance
    return selected


# v303: two parallel SERA->BODY rays must BOTH intersect an eligible
# module. They share a horizontal perpendicular to the player's real
# forward axis (never the camera's right vector), with a 0.50m total gap.
# Use the same endpoints for gameplay selection AND optional debug display.
const PARALLEL_LOCK_HALF_SPACING: float = 0.25


func get_actor_parallel_lock_segments(actor_origin: Vector3,
        body_center: Vector3) -> PackedVector3Array:
    var forward: Vector3 = body_center - actor_origin
    forward.y = 0.0
    var lateral: Vector3 = Vector3.RIGHT
    if forward.length_squared() > 0.000001:
        forward = forward.normalized()
        lateral = Vector3(-forward.z, 0.0, forward.x)
    var side_offset: Vector3 = lateral * PARALLEL_LOCK_HALF_SPACING
    return PackedVector3Array([
        actor_origin - side_offset, body_center - side_offset,
        actor_origin + side_offset, body_center + side_offset])


func _parallel_lock_part_distance(segments: PackedVector3Array,
        id: String) -> float:
    if segments.size() != 4:
        return INF
    var first: float = INF
    var second: float = INF
    # v304: both parallel rays test the same enlarged camera-only volume.
    # The former per-mesh intersection helpers are left unchanged for
    # historical geometry regression, never used by active AUTO.
    if id.is_empty():
        first = _camera_lock_body_volume_distance(segments[0], segments[1])
        second = _camera_lock_body_volume_distance(segments[2], segments[3])
    else:
        first = _camera_lock_part_volume_distance(segments[0], segments[1], id)
        second = _camera_lock_part_volume_distance(segments[2], segments[3], id)
    # A single intersecting ray does not authorize a lock.
    if first == INF or second == INF:
        return INF
    # Rank candidates by the more distant first entry, to discourage
    # choosing an edge that only barely overlaps the second ray.
    return maxf(first, second)


func actor_parallel_lines_hits_part(actor_origin: Vector3,
        body_center: Vector3, id: String) -> bool:
    var segments: PackedVector3Array = get_actor_parallel_lock_segments(
        actor_origin, body_center)
    return _parallel_lock_part_distance(segments, id) < INF


func select_actor_parallel_lines_part(actor_origin: Vector3,
        body_center: Vector3) -> String:
    var segments: PackedVector3Array = get_actor_parallel_lock_segments(
        actor_origin, body_center)
    var closest: float = _parallel_lock_part_distance(segments, "")
    var selected: String = ""
    for id in PART_ORDER:
        var distance: float = _parallel_lock_part_distance(segments, id)
        if distance < closest:
            closest = distance
            selected = id
    return selected


# Read-only legacy camera-origin APIs retained for historic mesh-geometry
# regressions. Gameplay AUTO uses only the SERA-origin helpers above.
func camera_center_line_hits_part(view_camera: Camera3D,
        body_center: Vector3, id: String) -> bool:
    return (view_camera != null
        and actor_center_line_hits_part(
            view_camera.global_position, body_center, id))


func select_camera_center_line_part(view_camera: Camera3D,
        body_center: Vector3) -> String:
    if view_camera == null:
        return ""
    return select_actor_center_line_part(view_camera.global_position, body_center)


# v293 legacy orbital selector retained for historical regression tests.
# v293: AUTO locks follow the camera's azimuth around the boss, not
# fluctuations in projected limb-center distances. Five intact modules are
# separated by five BODY sectors, guaranteeing the requested orbital order.
# The boss's authored +Z axis is its front (HEAD); local -X is LEFT.
# A broken module maps to BODY, retaining the same orbit sector.
const CAMERA_ORBIT_RING = [
    "head", "", "leg_fl", "", "leg_rl", "",
    "leg_rr", "", "leg_fr", ""
]
const CAMERA_ORBIT_STEP_DEGREES: float = 36.0

func select_camera_orbit_part(view_camera: Camera3D) -> String:
    if view_camera == null:
        return ""
    var relative: Vector3 = to_local(view_camera.global_position)
    if Vector2(relative.x, relative.z).length_squared() < 0.000001:
        return ""
    var degrees: float = fposmod(
        rad_to_deg(atan2(-relative.x, relative.z)), 360.0)
    var index: int = posmod(
        roundi(degrees / CAMERA_ORBIT_STEP_DEGREES),
        CAMERA_ORBIT_RING.size())
    var part_id: String = str(CAMERA_ORBIT_RING[index])
    return part_id if is_targetable(part_id) else ""


# v291: camera-forward locking. The old v289 front/occlusion selector
# rejected every limb whenever a large boss torso or another leg stood
# along the SERA->aim line. That made AUTO appear unlocked on strafes.
# Choose the available part nearest the VIEWPORT CENTER instead. Screen
# offset owns the score; distance is a very weak tie-breaker, NEVER a veto.
# A slightly worse existing selection is retained to prevent lock jitter.
func select_camera_front_part(view_camera: Camera3D, current: String) -> String:
    if view_camera == null:
        return current if is_targetable(current) else ""
    var viewport_size: Vector2 = view_camera.get_viewport().get_visible_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return current if is_targetable(current) else ""
    var center: Vector2 = viewport_size * 0.5
    var scale: Vector2 = Vector2(
        maxf(1.0, viewport_size.x * 0.5),
        maxf(1.0, viewport_size.y * 0.5))
    var best_id: String = ""
    var best_score: float = INF
    var current_score: float = INF
    for id in PART_ORDER:
        if not is_targetable(id):
            continue
        var aim: Vector3 = get_part_aim_world(id)
        if view_camera.is_position_behind(aim):
            continue
        var screen_point: Vector2 = view_camera.unproject_position(aim)
        # A candidate outside the viewport can still be kept as a fallback
        # if the boss is partly out of frame. The marker itself still hides.
        var normalized_offset: Vector2 = (screen_point - center) / scale
        var score: float = normalized_offset.length()
        score += minf(0.03,
            view_camera.global_position.distance_to(aim) * CAMERA_PART_DISTANCE_TIE_WEIGHT)
        if id == current:
            current_score = score
        if score < best_score:
            best_score = score
            best_id = id
    if is_targetable(current) and current_score < INF \
            and current_score <= best_score + CAMERA_PART_LOCK_HYSTERESIS:
        return current
    return best_id


# Keep the older entry point for historical call sites, but ensure that
# new AUTO uses the camera-projection selector above rather than
# the angle/distance/core-occlusion classifier below.
func select_front_part(origin: Vector3, forward: Vector3,
        current: String, _core_box: AABB) -> String:
    var desired: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
    if desired.length_squared() < 0.000001:
        desired = Vector3(global_position.x-origin.x, 0.0,
            global_position.z-origin.z).normalized()
    var best_id: String = ""
    var best_score: float = INF
    for id in PART_ORDER:
        if not is_targetable(id):
            continue
        var aim: Vector3 = get_part_aim_world(id)
        var direction: Vector3 = Vector3(aim.x-origin.x, 0.0, aim.z-origin.z)
        if direction.length_squared() <= 0.000001:
            continue
        var score: float = 1.0 - direction.normalized().dot(desired)
        if score < best_score:
            best_id = id
            best_score = score
    return current if is_targetable(current) and best_score < 0.02 else best_id


# Manual left/right switching: any intact part in front of the camera
# may be selected even when it overlaps the torso or another massive leg.
# Hard occlusion from the old implementation frequently yielded no choices.
func get_visible_part_ids(origin: Vector3, _core_box: AABB) -> Array[String]:
    var ids: Array[String] = []
    for id in PART_ORDER:
        if is_targetable(id) and get_part_aim_world(id).distance_squared_to(origin) > 0.000001:
            ids.append(id)
    return ids
