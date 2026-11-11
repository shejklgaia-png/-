extends Node3D
## SERA v237: five independent, targetable dummy boss parts.
## Opaque procedural geometry; no modifications to the player Blockbench model.
## The central cube retains the authoritative movement collider and boss HP.

const CORE_HP_SHARE: float = 0.50
const EACH_PART_HP_SHARE: float = 0.10
const PART_ORDER = ["head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const LEG_IDS = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const SELECTION_HYSTERESIS_RADIANS: float = 0.13
const CORE_DEFENSE: float = 0.14

var parts: Dictionary = {}

func _ready() -> void:
    # The four columns reach the floor beneath the existing 2m cube.
    # Positive Z is its training-arena front face, facing the spawn point.
    _add_part("head", "HEAD", Vector3(0.0, 1.18, 0.58),
        Vector3(1.08, 0.75, 0.90), Vector3(0.0, 0.18, 0.34),
        38.0, 0.20, 0.10, "change", Color("da755a"))
    _add_part("leg_fl", "FRONT L", Vector3(-0.78, -1.03, 0.73),
        Vector3(0.43, 1.04, 0.46), Vector3(0.0, -0.30, 0.0),
        30.0, 0.12, 0.00, "remove", Color("b9604c"))
    _add_part("leg_fr", "FRONT R", Vector3(0.78, -1.03, 0.73),
        Vector3(0.43, 1.04, 0.46), Vector3(0.0, -0.30, 0.0),
        30.0, 0.12, 0.00, "remove", Color("b9604c"))
    _add_part("leg_rl", "REAR L", Vector3(-0.78, -1.03, -0.73),
        Vector3(0.43, 1.04, 0.46), Vector3(0.0, -0.30, 0.0),
        32.0, 0.16, 0.12, "remain", Color("a95043"))
    _add_part("leg_rr", "REAR R", Vector3(0.78, -1.03, -0.73),
        Vector3(0.43, 1.04, 0.46), Vector3(0.0, -0.30, 0.0),
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

func _add_part(id: String, display: String, center: Vector3,
        dimensions: Vector3, aim_offset: Vector3, integrity: float,
        defense: float, break_defense: float, break_mode: String,
        color: Color) -> void:
    var pivot := Node3D.new()
    pivot.name = id
    pivot.position = center
    add_child(pivot)
    var shell := _make_material(color)
    var accent := _make_material(Color("5d4140"))
    _make_box(pivot, "Armor", Vector3.ZERO, dimensions, shell)
    var fracture: MeshInstance3D = null
    if id == "head":
        _make_box(pivot, "Visor", Vector3(0.0, 0.05, 0.45),
            Vector3(0.70, 0.20, 0.06), accent)
        fracture = _make_box(pivot, "FracturedVisor",
            Vector3(0.0, 0.06, 0.50), Vector3(0.50, 0.40, 0.08),
            _make_material(Color("293540")))
        fracture.visible = false
    else:
        _make_box(pivot, "Foot", Vector3(0.0, -0.42, 0.13),
            Vector3(0.53, 0.18, 0.67), accent)
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
