extends RefCounted
## Six interchangeable Blockbench equipment slots driven by the existing animated A rig.
## The authored model stays in one .bbmodel: first character root=A, next=B/C/etc.
const LIVE_SOURCE: String = "res://models/SERA_BOOSTER_allテスト.bbmodel"
const EMBEDDED_SOURCE = preload("res://assets/sera_equipment_data.gd")
const SAVE_PATH: String = "user://sera_equipment.cfg"
const SLOTS = ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]
const MODEL_UNIT: float = 0.065
# B has a red palette tint; all other sets retain their authored colors.
const B_SET_TINT: Color = Color(1.0, 0.18, 0.18, 1.0)

var rig: Node3D
var available: Dictionary = {}  # set letter -> slot -> Array[MeshInstance3D]
var selected: Dictionary = {}
# Per-set bind-pose feet. The base reference is measured once with no motion
# to avoid raising/lowering the body at each step (which would erase the gait).
var foot_meshes: Dictionary = {}
var bind_sole_heights: Dictionary = {}
var standard_sole_y: float = 0.0
var rig_original_y: float = 0.0
var grounding_height_offset: float = 0.0

func setup(target_rig: Node3D) -> void:
    rig = target_rig
    rig_original_y = rig.position.y
    _collect_original_meshes(rig)
    var data: Dictionary = _read_model()
    _install_alternative_sets(data)
    _cache_bind_foot_geometry()
    for slot in SLOTS:
        selected[slot] = "A"
    _restore_saved()
    # No saved selection means A: maintain the exact v189 default height.
    _apply_legs_grounding(str(selected.get("legs", "A")))

func options_for(slot: String) -> Array:
    var options: Array = []
    if not SLOTS.has(slot):
        return options
    # Booster currently has no separate Blockbench mesh. A/B profiles are selectable
    # independently while reusing the existing visual booster.
    if slot == "booster":
        return ["A", "B"]
    for set_id in available.keys():
        if (available[set_id] as Dictionary).get(slot, []).size() > 0:
            options.append(str(set_id))
    options.sort()
    return options

func current_for(slot: String) -> String:
    return str(selected.get(slot, "A"))

func select_part(slot: String, set_id: String, persist: bool = true) -> bool:
    if not options_for(slot).has(set_id):
        return false
    for variant in available.keys():
        for piece_variant in (available[variant] as Dictionary).get(slot, []):
            var piece: MeshInstance3D = piece_variant
            piece.visible = str(variant) == set_id
    selected[slot] = set_id
    if slot == "legs":
        _apply_legs_grounding(set_id)
        rig.call("reset_foot_contacts")
    _sync_afterimage_visibility()
    if persist:
        _save_selection()
    return true

# The static sole points are measured on the actual MeshInstance geometry
# (including mesh rotations), not inferred from file names or a fixed leg length.
func _foot_side(piece: MeshInstance3D) -> String:
    var node: Node = piece.get_parent()
    while node != null and node != rig:
        var name: String = str(node.name).to_lower()
        if name.contains("foot"):
            if name.ends_with("_l"):
                return "L"
            if name.ends_with("_r"):
                return "R"
            return ""
        node = node.get_parent()
    return ""

func _mesh_lowest_y(piece: MeshInstance3D) -> float:
    if piece.mesh == null:
        return INF
    var bounds: AABB = piece.mesh.get_aabb()
    var result: float = INF
    for ix in [0.0, 1.0]:
        for iy in [0.0, 1.0]:
            for iz in [0.0, 1.0]:
                var corner := bounds.position + Vector3(
                    bounds.size.x * ix, bounds.size.y * iy, bounds.size.z * iz)
                result = minf(result, rig.to_local(piece.to_global(corner)).y)
    return result

func _cache_bind_foot_geometry() -> void:
    foot_meshes.clear()
    bind_sole_heights.clear()
    for set_key in available.keys():
        var set_id: String = str(set_key)
        var side_meshes: Dictionary = {"L": [], "R": []}
        var sole_y: float = INF
        for part in (available[set_id] as Dictionary).get("legs", []):
            var piece: MeshInstance3D = part
            var side: String = _foot_side(piece)
            if side.is_empty():
                continue
            (side_meshes[side] as Array).append(piece)
            sole_y = minf(sole_y, _mesh_lowest_y(piece))
        if sole_y < INF and not (side_meshes["L"] as Array).is_empty() and not (side_meshes["R"] as Array).is_empty():
            foot_meshes[set_id] = side_meshes
            bind_sole_heights[set_id] = sole_y
    standard_sole_y = float(bind_sole_heights.get("A", 0.0))

func _apply_legs_grounding(set_id: String) -> void:
    # A baseline remains unchanged; the selected sole is aligned to A's
    # ground plane. A larger downward foot raises the model and its head.
    grounding_height_offset = standard_sole_y - float(
        bind_sole_heights.get(set_id, standard_sole_y))
    rig.position.y = rig_original_y + grounding_height_offset

func get_grounding_height_offset() -> float:
    return grounding_height_offset

func get_standard_sole_y() -> float:
    return standard_sole_y

func get_active_foot_heights() -> Dictionary:
    var feet: Dictionary = foot_meshes.get(str(selected.get("legs", "A")), {})
    var result: Dictionary = {}
    for side in ["L", "R"]:
        var minimum: float = INF
        for piece in feet.get(side, []):
            minimum = minf(minimum, _mesh_lowest_y(piece))
        if minimum < INF:
            result[side] = minimum
    return result

func sync_afterimages() -> void:
    _sync_afterimage_visibility()

func _collect_original_meshes(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            var slot: String = _slot_for_bone(child.get_parent())
            if bool(child.get_meta("sera_bird_leg", false)):
                _add_mesh("D", "legs", child)
            elif not slot.is_empty() and child.name != "Swordeffect":
                _add_mesh("A", slot, child)
        else:
            _collect_original_meshes(child)

func _add_mesh(set_id: String, slot: String, mesh: MeshInstance3D) -> void:
    if not available.has(set_id):
        available[set_id] = {}
    var parts: Dictionary = available[set_id]
    if not parts.has(slot):
        parts[slot] = []
    (parts[slot] as Array).append(mesh)

func _read_model() -> Dictionary:
    # Live Blockbench files work in the Android editor. Exported games use
    # the embedded snapshot generated by tools/rebuild_equipment_data.py.
    if FileAccess.file_exists(LIVE_SOURCE):
        var current: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIVE_SOURCE))
        if current is Dictionary:
            return current
    var backup: Variant = JSON.parse_string(EMBEDDED_SOURCE.get_json())
    return backup if backup is Dictionary else {}

func _install_alternative_sets(data: Dictionary) -> void:
    var groups: Dictionary = {}
    for raw_group in data.get("groups", []):
        if raw_group is Dictionary:
            groups[str(raw_group.get("uuid", ""))] = raw_group
    var elements: Dictionary = {}
    for raw_mesh in data.get("elements", []):
        if raw_mesh is Dictionary:
            elements[str(raw_mesh.get("uuid", ""))] = raw_mesh
    var roots: Array = []
    for entry in data.get("outliner", []):
        if not entry is Dictionary:
            continue
        var group: Dictionary = groups.get(str(entry.get("uuid", "")), {})
        if _simple_name(str(group.get("name", ""))).begins_with("set"):
            var wrapped: Dictionary = _find_character_root(entry, groups)
            if not wrapped.is_empty():
                roots.append(wrapped)
        elif _is_character_root(entry, groups):
            roots.append(entry)
    if roots.size() < 2:
        return
    var base_root: Node3D = null
    for child in rig.get_children():
        if child is Node3D and child.has_meta("bb_origin"):
            base_root = child
            break
    if base_root == null:
        push_warning("SERA equipment: base root unavailable")
        return
    for index in range(1, mini(roots.size(), 26)):
        var letter: String = String.chr(65 + index)
        var entry: Dictionary = roots[index]
        _attach_group_meshes(entry, base_root, groups, elements, letter)
        if not available.has(letter):
            push_warning("SERA equipment set %s has no matching meshes" % letter)

func _find_character_root(entry: Dictionary, groups: Dictionary) -> Dictionary:
    for child in entry.get("children", []):
        if child is Dictionary:
            if _is_character_root(child, groups):
                return child
            var result: Dictionary = _find_character_root(child, groups)
            if not result.is_empty():
                return result
    return {}

func _is_character_root(entry: Dictionary, groups: Dictionary) -> bool:
    var group: Dictionary = groups.get(str(entry.get("uuid", "")), {})
    var name: String = _simple_name(str(group.get("name", "")))
    if name.begins_with("waist"):
        return true
    var torso_found: bool = false
    var leg_found: bool = false
    for child in entry.get("children", []):
        if not child is Dictionary:
            continue
        var child_group: Dictionary = groups.get(str(child.get("uuid", "")), {})
        var child_name: String = _simple_name(str(child_group.get("name", "")))
        torso_found = torso_found or child_name.contains("torso") or child_name.contains("chest")
        leg_found = leg_found or child_name.contains("thigh") or child_name.contains("leg")
    return torso_found and leg_found

func _attach_group_meshes(entry: Dictionary, target_bone: Node3D, groups: Dictionary,
        elements: Dictionary, set_id: String) -> void:
    for child in entry.get("children", []):
        if child is Dictionary:
            var group: Dictionary = groups.get(str(child.get("uuid", "")), {})
            if group.is_empty():
                continue
            # Head C's authored pivot is not A Head's original pivot.
            # Place a parallel controller below A Neck so A and B remain unchanged.
            if set_id == "C" and _simple_name(str(group.get("name", ""))) == "head":
                var pivot := Node3D.new()
                pivot.name = "HeadC_AuthorPivot"
                var source_origin: Vector3 = _v3(group.get("origin", [0, 0, 0]))
                var target_origin: Vector3 = target_bone.get_meta("bb_origin", Vector3.ZERO)
                pivot.position = (source_origin - target_origin) * MODEL_UNIT
                pivot.set_meta("bb_origin", source_origin)
                target_bone.add_child(pivot)
                rig.call("register_head_c_pivot", pivot)
                _attach_group_meshes(child, pivot, groups, elements, set_id)
                continue
            var match_bone: Node3D = _match_child_bone(target_bone, group)
            if match_bone != null:
                _attach_group_meshes(child, match_bone, groups, elements, set_id)
            else:
                push_warning("SERA equipment: ambiguous joint %s under %s" % [
                    str(group.get("name", "?")), target_bone.name])
        elif child is String and elements.has(child):
            var element: Dictionary = elements[child]
            var slot: String = _slot_for_bone(target_bone)
            if slot.is_empty() or not element.has("vertices") or not element.has("faces"):
                continue
            var piece: MeshInstance3D = rig.call("_make_mesh", element)
            if piece == null:
                continue
            piece.name = "%s_%s" % [set_id, str(element.get("name", "Mesh"))]
            _apply_equipment_tint(piece, set_id)
            var base_origin: Vector3 = target_bone.get_meta("bb_origin", Vector3.ZERO)
            piece.position = (_v3(element.get("origin", [0, 0, 0])) - base_origin) * MODEL_UNIT
            # User-authored Head C meshes have nonzero local rotations.
            piece.quaternion = rig.call("_blockbench_rotation", _v3(element.get("rotation", [0, 0, 0])))
            target_bone.add_child(piece)
            piece.visible = false
            _add_mesh(set_id, slot, piece)

func _apply_equipment_tint(piece: MeshInstance3D, set_id: String) -> void:
    # Keep A untouched and isolate B's material from other variants.
    piece.set_meta("sera_equipment_set", set_id)
    # No texture is embedded in the Head C Blockbench source. Tint only C,
    # which otherwise samples the nearly white corner of SERA's palette.
    if set_id == "C":
        var original_c: StandardMaterial3D = piece.material_override as StandardMaterial3D
        if original_c != null:
            var material_c: StandardMaterial3D = original_c.duplicate() as StandardMaterial3D
            material_c.albedo_color = Color(0.60, 0.65, 0.72, 1.0)
            piece.material_override = material_c
        return
    if set_id != "B":
        return
    var original: StandardMaterial3D = piece.material_override as StandardMaterial3D
    if original == null:
        return
    var tinted: StandardMaterial3D = original.duplicate() as StandardMaterial3D
    tinted.albedo_color = B_SET_TINT
    # Keep the original palette texture, UVs and authored light/dark shading.
    piece.material_override = tinted

func _match_child_bone(target_parent: Node3D, source_group: Dictionary) -> Node3D:
    var name: String = _simple_name(str(source_group.get("name", "")))
    var source_origin: Vector3 = _v3(source_group.get("origin", [0, 0, 0]))
    var nearest: Node3D = null
    var best: float = INF
    var next_best: float = INF
    for child in target_parent.get_children():
        if not child is Node3D or not child.has_meta("bb_origin"):
            continue
        if _simple_name(child.name) == name:
            return child
        var score: float = source_origin.distance_squared_to(
            child.get_meta("bb_origin", Vector3.ZERO))
        if score < best:
            next_best = best
            best = score
            nearest = child
        elif score < next_best:
            next_best = score
    # Hierarchy and authored pivot location are stronger than minor renames.
    # Do not silently attach an uncertain left/right or otherwise remote joint.
    if nearest != null and best < 16.0 and next_best - best > 0.01:
        return nearest
    return null

func _slot_for_bone(node: Node) -> String:
    var current: Node = node
    while current != null and current != rig:
        var name: String = _simple_name(current.name)
        if name.contains("sword") or name.contains("weaponr") or name.contains("rightweapon"):
            return "weapon_r"
        if name.contains("shield") or name.contains("weaponl") or name.contains("leftweapon"):
            return "weapon_l"
        if name.contains("head") or name.contains("neck"):
            return "head"
        if name.contains("shoulder") or name.contains("upperarm") or name.contains("forearm") or name.contains("hand"):
            return "arms"
        if name.contains("thigh") or name.contains("lowerleg") or name.contains("foot"):
            return "legs"
        if name.contains("chest") or name.contains("torso"):
            return "torso"
        if name.contains("waist") or name.contains("hip"):
            return "legs"
        current = current.get_parent()
    return ""

func _simple_name(raw_name: String) -> String:
    var name: String = raw_name.to_lower().replace("_", "").replace("-", "").replace(" ", "")
    while not name.is_empty() and name.substr(name.length() - 1, 1).is_valid_int():
        name = name.substr(0, name.length() - 1)
    return name

func _v3(value: Variant) -> Vector3:
    if value is Array and value.size() >= 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO

func _restore_saved() -> void:
    # When a profile is active, its session working copy takes precedence over
    # the legacy global cfg. Scene changes retain edits; only SAVE commits them.
    var archive: Node = rig.get_node_or_null("/root/SeraSave")
    if archive != null and int(archive.get("active_slot")) > 0:
        var working: Dictionary = archive.call("get_working_equipment")
        for slot in SLOTS:
            select_part(slot, str(working.get(slot, "A")), false)
        return
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    for slot in SLOTS:
        select_part(slot, str(cfg.get_value("equipment", slot, "A")), false)

func _save_selection() -> void:
    var archive: Node = rig.get_node_or_null("/root/SeraSave")
    if archive != null:
        for slot in SLOTS:
            archive.call("update_working_equipment", slot, str(selected.get(slot, "A")))
    var cfg := ConfigFile.new()
    for slot in SLOTS:
        cfg.set_value("equipment", slot, selected.get(slot, "A"))
    if cfg.save(SAVE_PATH) != OK:
        push_warning("SERA equipment: unable to save selection")

func _sync_afterimage_visibility() -> void:
    if rig == null:
        return
    var source_meshes: Array = rig.get("_foreground_parts")
    var ghost_meshes: Array = rig.get("_afterimage_meshes")
    for i in range(mini(source_meshes.size(), ghost_meshes.size())):
        var source: MeshInstance3D = source_meshes[i]
        var ghost: MultiMeshInstance3D = ghost_meshes[i]
        ghost.visible = source.visible
