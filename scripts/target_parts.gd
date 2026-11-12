extends Node3D
## SERA v240: enlarged rectangular arm-like outriggers and four heavy legs.
## Opaque BoxMesh mechanical frames; no user Blockbench assets modified.
## The 2.0 x 2.0 x 3.4m torso keeps the authoritative collider and boss HP.

const CORE_HP_SHARE: float = 0.50
const EACH_PART_HP_SHARE: float = 0.10
const PART_ORDER = ["head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const LEG_IDS = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const SELECTION_HYSTERESIS_RADIANS: float = 0.13
const CORE_DEFENSE: float = 0.14
# v289: use the same dark-red contact flash and wobble as the central boss.
const PART_HIT_DARK_COLOR: Color = Color("632535")
const PART_HIT_GLOW_COLOR: Color = Color("6b1727")
const PART_HIT_WOBBLE_METERS: float = 0.09
const PART_HIT_WOBBLE_DEGREES: float = 6.0

var parts: Dictionary = {}

func _ready() -> void:
    # Torso is 2m wide/high and 3.4m long (front/rear Z = +/-1.7m).
    # Four enlarged 2m-tall arm/leg frames attach along the sides.
    # Their outward guards are mirrored across X and front/rear Z.
    _add_part("head", "HEAD", Vector3(0.0, -0.44, 1.85),
        Vector3(1.48, 0.82, 0.96), Vector3(0.0, -0.03, 0.37),
        100.0, 0.20, 0.10, "change", Color("da755a"))
    _add_part("leg_fl", "FRONT L", Vector3(-1.23, -0.53, 1.27),
        Vector3(2.24, 2.00, 1.36), Vector3(-0.78, -0.27, 0.52),
        100.0, 0.12, 0.00, "remain", Color("b9604c"))
    _add_part("leg_fr", "FRONT R", Vector3(1.23, -0.53, 1.27),
        Vector3(2.24, 2.00, 1.36), Vector3(0.78, -0.27, 0.52),
        100.0, 0.12, 0.00, "remain", Color("b9604c"))
    _add_part("leg_rl", "REAR L", Vector3(-1.23, -0.53, -1.27),
        Vector3(2.24, 2.00, 1.36), Vector3(-0.78, -0.27, -0.52),
        100.0, 0.16, 0.12, "remain", Color("a95043"))
    _add_part("leg_rr", "REAR R", Vector3(1.23, -0.53, -1.27),
        Vector3(2.24, 2.00, 1.36), Vector3(0.78, -0.27, -0.52),
        100.0, 0.16, 0.12, "remain", Color("a95043"))

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
    # The dimensions cover the entire exposed framework, not just one plate.
    # This keeps sword contact and automatic occlusion checks aligned.
    parts[id] = {
        "id": id, "display": display, "node": pivot, "size": dimensions,
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


func is_targetable(id: String) -> bool:
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

func select_front_part(origin: Vector3, forward: Vector3,
        current: String, core_box: AABB) -> String:
    # The whole enemy's center (the CAMERA ROTATION AXIS), not the
    # previously selected part, defines SERA's forward sightline.
    var enemy_pivot: Node3D = get_parent().get_parent() as Node3D
    var to_center: Vector3 = (enemy_pivot.global_position - origin
        if enemy_pivot != null else forward)
    var desired: Vector3 = Vector3(to_center.x, 0.0, to_center.z).normalized()
    if desired.length_squared() < 0.000001:
        desired = Vector3(forward.x, 0.0, forward.z).normalized()
    if desired.length_squared() < 0.000001:
        return current if is_targetable(current) else ""
    var best_id: String = ""
    var best_score: float = INF
    var old_score: float = INF
    for id in PART_ORDER:
        if not is_targetable(id):
            continue
        var aim: Vector3 = get_part_aim_world(id)
        var toward: Vector3 = aim - origin
        var flat_toward: Vector3 = Vector3(toward.x, 0.0, toward.z)
        var straight_depth: float = desired.dot(flat_toward)
        # Ignore limbs behind SERA; rank viable parts by their angular
        # deviation from SERA->whole-boss center, not camera screen X.
        if straight_depth <= 0.0 or flat_toward.length_squared() < 0.000001:
            continue
        var core_contact: Variant = core_box.intersects_segment(origin, aim)
        if core_contact != null and origin.distance_to(core_contact) < (
                toward.length() - 0.22):
            continue
        var hidden_by_limb: bool = false
        for other_id in PART_ORDER:
            if other_id == id:
                continue
            var other_node: Node3D = parts[other_id]["node"]
            if not other_node.visible:
                continue
            var other_contact: Variant = get_part_aabb(other_id).intersects_segment(
                origin, aim)
            if other_contact != null and origin.distance_to(other_contact) < (
                    toward.length() - 0.22):
                hidden_by_limb = true
                break
        if hidden_by_limb:
            continue
        var lateral: float = absf(desired.cross(flat_toward).y)
        var score: float = atan2(lateral, straight_depth)
        score += 0.12 * absf(toward.y) / maxf(0.3, flat_toward.length())
        if id == current:
            old_score = score
        if score < best_score:
            best_score = score
            best_id = id
    if is_targetable(current) and old_score < INF \
            and old_score <= best_score + SELECTION_HYSTERESIS_RADIANS:
        return current
    return best_id


func get_visible_part_ids(origin: Vector3, core_box: AABB) -> Array[String]:
    # Manual selection uses the camera's line of sight but exactly the same
    # geometry/visibility rules as the existing automatic part selector.
    var candidates: Array[String] = []
    for id in PART_ORDER:
        if not is_targetable(id):
            continue
        var aim: Vector3 = get_part_aim_world(id)
        var toward: Vector3 = aim - origin
        if toward.length_squared() < 0.000001:
            continue
        var core_hit: Variant = core_box.intersects_segment(origin, aim)
        if core_hit != null and origin.distance_to(core_hit) < (
                toward.length() - 0.22):
            continue
        var occluded: bool = false
        for other_id in PART_ORDER:
            if other_id == id:
                continue
            var other_node: Node3D = parts[other_id]["node"]
            if not other_node.visible:
                continue
            var other_hit: Variant = get_part_aabb(other_id).intersects_segment(
                origin, aim)
            if other_hit != null and origin.distance_to(other_hit) < (
                    toward.length() - 0.22):
                occluded = true
                break
        if not occluded:
            candidates.append(id)
    return candidates
