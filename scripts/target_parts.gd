extends Node3D
## SERA v239: five independent rectangular breakable parts around a longer body.
## Opaque BoxMesh mechanical frames; no user Blockbench assets modified.
## The 2.0 x 2.0 x 3.4m torso keeps the authoritative collider and boss HP.

const CORE_HP_SHARE: float = 0.50
const EACH_PART_HP_SHARE: float = 0.10
const PART_ORDER = ["head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const LEG_IDS = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const SELECTION_HYSTERESIS_RADIANS: float = 0.13
const CORE_DEFENSE: float = 0.14

var parts: Dictionary = {}

func _ready() -> void:
    # Torso is 2m wide/high and 3.4m long (front/rear Z = +/-1.7m).
    # Four 2m-tall rectangular legs connect to its side walls, reaching
    # the floor. The lowered front sensor housing is within melee blade height.
    _add_part("head", "HEAD", Vector3(0.0, -0.44, 1.85),
        Vector3(1.48, 0.82, 0.96), Vector3(0.0, -0.03, 0.37),
        38.0, 0.20, 0.10, "change", Color("da755a"))
    _add_part("leg_fl", "FRONT L", Vector3(-1.23, -0.53, 1.27),
        Vector3(1.38, 2.00, 1.02), Vector3(-0.37, -0.27, 0.12),
        30.0, 0.12, 0.00, "remove", Color("b9604c"))
    _add_part("leg_fr", "FRONT R", Vector3(1.23, -0.53, 1.27),
        Vector3(1.38, 2.00, 1.02), Vector3(0.37, -0.27, 0.12),
        30.0, 0.12, 0.00, "remove", Color("b9604c"))
    _add_part("leg_rl", "REAR L", Vector3(-1.23, -0.53, -1.27),
        Vector3(1.38, 2.00, 1.02), Vector3(-0.37, -0.27, 0.12),
        32.0, 0.16, 0.12, "remain", Color("a95043"))
    _add_part("leg_rr", "REAR R", Vector3(1.23, -0.53, -1.27),
        Vector3(1.38, 2.00, 1.02), Vector3(0.37, -0.27, 0.12),
        32.0, 0.16, 0.12, "remain", Color("a95043"))

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


func _build_leg_frame(pivot: Node3D, side: float,
        shell: StandardMaterial3D, accent: StandardMaterial3D,
        frame: StandardMaterial3D, dark: StandardMaterial3D) -> void:
    # Full assembly spans local Y=-1..+1, equal to the torso's 2m height.
    # The support mount overlaps X=+/-1m; all components are square/rectangular.
    # At target center Y=1.53, the local sole at -1.00 touches the floor.
    _make_box(pivot, "SideMount", Vector3(-side * 0.26, 0.865, 0.0),
        Vector3(0.68, 0.27, 0.58), dark)
    _make_box(pivot, "HipJoint", Vector3(-side * 0.02, 0.81, 0.0),
        Vector3(0.40, 0.38, 0.44), accent)
    _make_box(pivot, "Outrigger", Vector3(side * 0.18, 0.65, 0.0),
        Vector3(0.55, 0.18, 0.28), frame)
    _make_box(pivot, "UpperStrut", Vector3(side * 0.34, 0.35, 0.0),
        Vector3(0.23, 0.87, 0.31), shell)
    _make_box(pivot, "KneeHinge", Vector3(side * 0.34, -0.22, 0.0),
        Vector3(0.37, 0.28, 0.38), accent)
    _make_box(pivot, "LowerStrut", Vector3(side * 0.34, -0.55, 0.0),
        Vector3(0.18, 0.68, 0.22), frame)
    _make_box(pivot, "Piston", Vector3(side * 0.34, -0.50, 0.15),
        Vector3(0.09, 0.64, 0.09), accent)
    _make_box(pivot, "OuterPlate", Vector3(side * 0.51, -0.05, 0.0),
        Vector3(0.12, 0.87, 0.37), shell)
    _make_box(pivot, "HeelBrace", Vector3(side * 0.34, -0.81, -0.09),
        Vector3(0.30, 0.17, 0.36), dark)
    _make_box(pivot, "Foot", Vector3(side * 0.37, -0.91, 0.13),
        Vector3(0.55, 0.18, 0.68), accent)


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
        _build_leg_frame(pivot, side, shell, accent, frame, dark)
    # The dimensions cover the entire exposed framework, not just one plate.
    # This keeps sword contact and automatic occlusion checks aligned.
    parts[id] = {
        "id": id, "display": display, "node": pivot, "size": dimensions,
        "aim": aim_offset, "max_integrity": integrity,
        "integrity": integrity, "defense": defense,
        "break_defense": break_defense, "break_mode": break_mode,
        "broken": false, "shell": shell, "accent": accent,
        "original_color": color, "fracture": fracture,
        "hp_share": EACH_PART_HP_SHARE
    }

func reset_parts() -> void:
    for id in PART_ORDER:
        var part: Dictionary = parts[id]
        part["integrity"] = part["max_integrity"]
        part["broken"] = false
        var pivot: Node3D = part["node"]
        pivot.visible = true
        var shell: StandardMaterial3D = part["shell"]
        shell.albedo_color = part["original_color"]
        var accent: StandardMaterial3D = part["accent"]
        accent.albedo_color = Color("5d4140")
        var fracture: MeshInstance3D = part["fracture"]
        if fracture != null:
            fracture.visible = false

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
        var mode: String = str(part["break_mode"])
        if mode == "remove":
            pivot.visible = false
        elif mode == "change":
            var shell: StandardMaterial3D = part["shell"]
            shell.albedo_color = Color("5b6570")
            var fracture: MeshInstance3D = part["fracture"]
            if fracture != null:
                fracture.visible = true
        else:
            var shell: StandardMaterial3D = part["shell"]
            shell.albedo_color = Color("4c555d")
            var accent: StandardMaterial3D = part["accent"]
            accent.albedo_color = Color("283039")
        result["broken"] = true
        result["kind"] = "head" if effective_id == "head" else "leg"
        result["broken_legs"] = broken_leg_count()
    return result

func select_front_part(origin: Vector3, forward: Vector3,
        current: String, core_box: AABB) -> String:
    # Use a shallow vertical weight: this is primarily SERA's facing angle,
    # not distance-to-center or camera position. Broken parts are excluded.
    var desired: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
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
        if toward.length_squared() < 0.000001:
            continue
        # Exclude an exterior limb behind the solid core from this vantage.
        var core_contact: Variant = core_box.intersects_segment(origin, aim)
        if core_contact != null and origin.distance_to(core_contact) < (
                toward.length() - 0.22):
            continue
        # A front leg can also hide a rear leg below the central box.
        # Remove occluded candidates, but not already-removed armor.
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
        var adjusted: Vector3 = Vector3(
            toward.x, toward.y * 0.35, toward.z).normalized()
        var score: float = acos(clampf(desired.dot(adjusted), -1.0, 1.0))
        if id == current:
            old_score = score
        if score < best_score:
            best_score = score
            best_id = id
    if is_targetable(current) and old_score < INF             and old_score <= best_score + SELECTION_HYSTERESIS_RADIANS:
        return current
    return best_id
