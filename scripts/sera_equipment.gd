extends RefCounted
## Seven interchangeable Blockbench equipment slots driven by the existing animated A rig.
## The authored model stays in one .bbmodel: first character root=A, next=B/C/etc.
const LIVE_SOURCE: String = "res://models/SERA_BOOSTER_allテスト.bbmodel"
const EMBEDDED_SOURCE = preload("res://assets/sera_equipment_data.gd")
# Author-normalized standard legs use a dedicated source, not the C head's root index.
const LOWER_BODY_D_SOURCE: String = "res://models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel"
const LOWER_BODY_D_EMBEDDED = preload("res://assets/sera_lower_body_d_data.gd")
const BACK_THRUSTER_FX = preload("res://scripts/back_thruster_fx.gd")
const SAVE_PATH: String = "user://sera_equipment.cfg"
const SLOTS = ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]
const MODEL_UNIT: float = 0.065
# Training's visible grid is at -0.038 with 0.009 thickness: top = -0.0335.
# This is visual only; the logical Player still moves on its Y=0 XZ plane.
const TRAINING_VISIBLE_FLOOR_Y: float = -0.0335
# B has a red palette tint; all other sets retain their authored colors.
const B_SET_TINT: Color = Color(1.0, 0.18, 0.18, 1.0)

var rig: Node3D
var available: Dictionary = {}  # set letter -> slot -> Array[MeshInstance3D]
var selected: Dictionary = {}
# Katana is right-weapon set K: sheath left, exposed blade right.
var katana_saya_meshes: Array[MeshInstance3D] = []
var katana_drawn_meshes: Array[MeshInstance3D] = []
# Both selectable booster sets have their own two nozzle effects.
var back_thruster_effects: Dictionary = {}
# Per-set bind-pose feet. The base reference is measured once with no motion
# to avoid raising/lowering the body at each step (which would erase the gait).
var foot_meshes: Dictionary = {}
# Cached true mesh vertices avoid AABB-only false soles for rotated shoes.
var foot_vertex_cache: Dictionary = {}
# Cache original mesh-local positions for contact-only RUN foot placement.
var contact_foot_bind_positions: Dictionary = {}
var bind_sole_heights: Dictionary = {}
var standard_sole_y: float = 0.0
var rig_original_y: float = 0.0
var grounding_height_offset: float = 0.0
# Nexus is a camera-fitted exhibition: changing rig.position breaks the preview.
var grounding_enabled: bool = true
# Bird C alone keeps a smoothed, persistent visual root offset instead of
# resetting its soles to bind height and teleporting a shoe once per stride.
const BIRD_GROUND_FOLLOW_SECONDS: float = 0.10
# v227/v228: Only heavy B/D SLIDE receives render-only two-bone leg IK.
# B and D's shoe bottoms are planar and lie parallel to the foot's local XZ.
const SLIDE_IK_REACH_MARGIN: float = 0.003
# A slight crouch adds knee flexion before dynamically solving foot contact.
const SLIDE_IK_BASE_HIP_DROP: float = 0.07
const SLIDE_IK_MAX_HIP_DROP: float = 0.30
const SLIDE_IK_MIN_CHAIN_LENGTH: float = 0.04
var bird_grounding_render_y: float = 0.0
var slide_leg_chains: Dictionary = {}

func setup(target_rig: Node3D) -> void:
    rig = target_rig
    rig_original_y = rig.position.y
    _collect_original_meshes(rig)
    var data: Dictionary = _read_model()
    _install_alternative_sets(data)
    # v205: Chest/BOOSTER is authored on A's original Chest, not the alternate torso.
    _install_back_booster_placeholder(data)
    _install_standard_lower_body_d()
    _cache_bind_foot_geometry()
    _cache_slide_leg_chains()
    for slot in SLOTS:
        selected[slot] = "A"
    _restore_saved()
    _apply_part_visibility()
    _apply_legs_grounding(str(selected.get("legs", "A")))

func options_for(slot: String) -> Array:
    if not SLOTS.has(slot):
        return []
    if slot == "booster":
        return ["A", "B"]
    var options: Array = []
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
    selected[slot] = set_id
    _apply_part_visibility()
    if slot == "legs":
        _apply_legs_grounding(set_id)
        rig.call("reset_foot_contacts")
    _sync_afterimage_visibility()
    if persist:
        _save_selection()
    return true

func _apply_part_visibility() -> void:
    for set_key in available.keys():
        var set_id: String = str(set_key)
        var parts: Dictionary = available[set_id]
        for slot_key in parts.keys():
            var slot: String = str(slot_key)
            for raw_piece in parts[slot]:
                var piece: MeshInstance3D = raw_piece
                piece.visible = set_id == str(selected.get(slot, "A"))
    update_katana_visibility(str(rig.get("current_clip")), float(rig.get("clip_time")))


# v290: independently drive the SEVEN authored Katana meshes (5 saya,
# 2 drawn). Use both GeometryInstance3D.transparency and visible to keep
# the cut/draw state unambiguous in the opaque forward rendering pipeline.
# The fourth Blockbench 24fps frame is 3/24 seconds into the first strike.
# A second Katana slash never re-sheathes between combo hits.
func _set_katana_mesh_display(piece: MeshInstance3D, display: bool) -> bool:
    if not is_instance_valid(piece):
        return false
    var next_transparency: float = 0.0 if display else 1.0
    var changed: bool = piece.visible != display or absf(
        piece.transparency - next_transparency) > 0.001
    piece.transparency = next_transparency
    piece.visible = display
    return changed


func update_katana_visibility(clip_name: String, t: float) -> void:
    var equipped: bool = str(selected.get("weapon_r", "A")) == "K"
    var drawn: bool = equipped and (
        clip_name == "Melee_katana2"
        or (clip_name == "Melee_katana" and t >= 3.0 / 24.0 - 0.00001))
    var changed: bool = false
    for piece in katana_saya_meshes:
        changed = _set_katana_mesh_display(piece, equipped and not drawn) or changed
    for piece in katana_drawn_meshes:
        changed = _set_katana_mesh_display(piece, equipped and drawn) or changed
    if changed:
        _sync_afterimage_visibility()

func set_grounding_enabled(enabled: bool) -> void:
    grounding_enabled = enabled
    if not grounding_enabled:
        # In the preview the camera fitter owns the entire rig transform.
        grounding_height_offset = 0.0
        rig.position.y = rig_original_y
        bird_grounding_render_y = rig.position.y
        return
    _apply_legs_grounding(str(selected.get("legs", "A")))

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
    # Actual triangles, not the transformed eight corners of their AABB.
    # For a tilted boot the AABB extends below geometry and makes the actual
    # sole appear to hover even if the bounding box is planted.
    var cache_key: int = piece.get_instance_id()
    if not foot_vertex_cache.has(cache_key):
        var vertices := PackedVector3Array()
        for surface in range(piece.mesh.get_surface_count()):
            var arrays: Array = piece.mesh.surface_get_arrays(surface)
            if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
                vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
        foot_vertex_cache[cache_key] = vertices
    var vertices: PackedVector3Array = foot_vertex_cache[cache_key]
    if vertices.is_empty():
        return INF
    # All transforms are relative to the rig, so adjusting rig.position.y
    # does not change this measurement and create a feedback loop.
    var to_rig: Transform3D = rig.global_transform.affine_inverse() * piece.global_transform
    var sole_y: float = INF
    for vertex in vertices:
        sole_y = minf(sole_y, (to_rig * vertex).y)
    return sole_y

func _cache_bind_foot_geometry() -> void:
    foot_meshes.clear()
    foot_vertex_cache.clear()
    contact_foot_bind_positions.clear()
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
            contact_foot_bind_positions[piece.get_instance_id()] = piece.position
            sole_y = minf(sole_y, _mesh_lowest_y(piece))
        if sole_y < INF and not (side_meshes["L"] as Array).is_empty() and not (side_meshes["R"] as Array).is_empty():
            foot_meshes[set_id] = side_meshes
            bind_sole_heights[set_id] = sole_y
    standard_sole_y = float(bind_sole_heights.get("A", 0.0))

func _apply_legs_grounding(set_id: String) -> void:
    # A baseline remains unchanged; the selected sole is aligned to A's
    # ground plane. A larger downward foot raises the model and its head.
    if not grounding_enabled:
        grounding_height_offset = 0.0
        return
    grounding_height_offset = standard_sole_y - float(
        bind_sole_heights.get(set_id, standard_sole_y))
    rig.position.y = rig_original_y + grounding_height_offset
    bird_grounding_render_y = rig.position.y

func restore_grounding_baseline() -> void:
    # v200: all combat / step / airborne poses keep v198's fixed bind offset.
    # This only changes the visible rig; NEXUS preview stays camera-fitted.
    if not grounding_enabled or rig == null:
        return
    if str(selected.get("legs", "A")) == "C":
        rig.position.y = bird_grounding_render_y
    else:
        rig.position.y = rig_original_y + grounding_height_offset

func smooth_bird_grounding(delta: float) -> void:
    # Unlike A/B/D, reverse-jointed C has a large changing sole envelope.
    # Follow the actual lower sole smoothly each frame, maintaining support
    # across steps without a one-frame character-root or mesh teleport.
    if not grounding_enabled or rig == null or str(selected.get("legs", "A")) != "C":
        return
    var wearer: Node3D = rig.get_parent() as Node3D
    if wearer == null or absf(wearer.global_position.y) > 0.05 \
            or bool(rig.get("jump_playback")):
        return
    var heights: Dictionary = get_active_foot_heights()
    if not heights.has("L") or not heights.has("R"):
        return
    var lowest: float = minf(float(heights["L"]), float(heights["R"]))
    if is_inf(lowest) or is_nan(lowest):
        return
    var sole_world_y: float = rig.to_global(Vector3(0.0, lowest, 0.0)).y
    var goal_y: float = rig.position.y + (TRAINING_VISIBLE_FLOOR_Y - sole_world_y)
    var blend: float = 1.0 - exp(-maxf(delta, 0.0) / BIRD_GROUND_FOLLOW_SECONDS)
    bird_grounding_render_y = lerpf(bird_grounding_render_y, goal_y, blend)
    rig.position.y = bird_grounding_render_y

func snap_grounded_sole_to_floor() -> void:
    # v199: evaluate the *current animated pose*, not only the bind pose.
    # The logical Player still stays on its existing XZ plane at world Y=0.
    # This translates only Sera's visual rig; it does not modify gameplay
    # velocity, collision mask, capsule dimensions, or authoring keyframes.
    if not grounding_enabled or rig == null:
        return
    var wearer: Node3D = rig.get_parent() as Node3D
    if wearer == null:
        return
    # During an authored/debug jump, preserve actual air height. The next
    # grounded frame resumes the exact sole-plane correction automatically.
    if absf(wearer.global_position.y) > 0.05 or bool(rig.get("jump_playback")):
        return
    var heights: Dictionary = get_active_foot_heights()
    if not heights.has("L") or not heights.has("R"):
        return
    var current_sole: float = minf(float(heights["L"]), float(heights["R"]))
    if is_inf(current_sole) or is_nan(current_sole):
        return
    # Ground plane is the top of the visible training grid. Player logical
    # height/velocity stay unchanged. The translation exactly plants one foot.
    rig.position.y = TRAINING_VISIBLE_FLOOR_Y - current_sole - wearer.global_position.y
    if str(selected.get("legs", "A")) == "C":
        bird_grounding_render_y = rig.position.y

# Restore last frame's contact-only foot translation before measuring the
# next animated pose. No player root translation or authored bone changes.
func restore_run_contact_foot_positions() -> void:
    for set_key in foot_meshes.keys():
        var sides: Dictionary = foot_meshes[set_key]
        for side in ["L", "R"]:
            for raw_piece in sides.get(side, []):
                var piece: MeshInstance3D = raw_piece
                if is_instance_valid(piece) and contact_foot_bind_positions.has(piece.get_instance_id()):
                    piece.position = contact_foot_bind_positions[piece.get_instance_id()]

func snap_run_contact_foot_to_floor(side: String) -> void:
    if not grounding_enabled or rig == null:
        return
    var wearer: Node3D = rig.get_parent() as Node3D
    if wearer == null or absf(wearer.global_position.y) > 0.05:
        return
    var feet: Dictionary = foot_meshes.get(str(selected.get("legs", "A")), {})
    var parts: Array = feet.get(side, [])
    var sole_heights: Dictionary = get_active_foot_heights()
    if parts.is_empty() or not sole_heights.has(side):
        return
    var sole_y: float = float(sole_heights[side])
    if is_inf(sole_y) or is_nan(sole_y):
        return
    var current_world_y: float = rig.to_global(Vector3(0.0, sole_y, 0.0)).y
    var adjustment: float = TRAINING_VISIBLE_FLOOR_Y - current_world_y
    # The contacting shoe alone reaches the visible floor on its sound frame.
    # This prevents the old full-body one-frame vertical pop/flicker.
    for raw_piece in parts:
        var piece: MeshInstance3D = raw_piece
        if is_instance_valid(piece):
            piece.global_position += Vector3.UP * adjustment

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

# v227: Two-bone IK keeps BOTH B/D soles on the training floor while their
# upper body continues following the existing half-strength BOOST SLIDE pose.
# This is intentionally not a foot-mesh translation: thigh and shin rotate,
# then the authored global foot orientation is restored. The feet travel with
# the sliding character instead of locking at their previous world XZ position.
func _cache_slide_leg_chains() -> void:
    slide_leg_chains.clear()
    for side in ["L", "R"]:
        var thigh: Node3D = rig.get_node_or_null("Waist/Thigh_" + side) as Node3D
        var knee: Node3D = rig.get_node_or_null(
            "Waist/Thigh_" + side + "/LowerLeg_" + side) as Node3D
        var foot: Node3D = rig.get_node_or_null(
            "Waist/Thigh_" + side + "/LowerLeg_" + side + "/Foot_" + side) as Node3D
        if thigh == null or knee == null or foot == null:
            push_warning("SERA SLIDE IK: missing standard %s leg joint chain" % side)
            continue
        slide_leg_chains[side] = {"thigh": thigh, "knee": knee, "foot": foot}


func _solve_slide_two_bone_ik(chain: Dictionary, target: Vector3, side: String) -> void:
    var thigh: Node3D = chain["thigh"] as Node3D
    var knee: Node3D = chain["knee"] as Node3D
    var foot: Node3D = chain["foot"] as Node3D
    var hip_pos: Vector3 = thigh.global_position
    var knee_pos: Vector3 = knee.global_position
    var ankle_pos: Vector3 = foot.global_position
    var upper: float = hip_pos.distance_to(knee_pos)
    var lower: float = knee_pos.distance_to(ankle_pos)
    if upper < SLIDE_IK_MIN_CHAIN_LENGTH or lower < SLIDE_IK_MIN_CHAIN_LENGTH:
        return
    var to_goal: Vector3 = target - hip_pos
    if to_goal.length_squared() < 0.000001:
        return
    var direction: Vector3 = to_goal.normalized()
    # Clamping prevents straight-leg singularities and impossible stretches.
    var distance: float = clampf(to_goal.length(),
        absf(upper - lower) + SLIDE_IK_REACH_MARGIN,
        upper + lower - SLIDE_IK_REACH_MARGIN)
    var reachable_goal: Vector3 = hip_pos + direction * distance
    var along: float = (upper * upper + distance * distance - lower * lower) / (2.0 * distance)
    var away: float = sqrt(maxf(0.0, upper * upper - along * along))
    # Preserve the authored knee bend side rather than flipping at near-full
    # extension. A rig-relative lateral pole is the degenerate fallback.
    var pole: Vector3 = knee_pos - hip_pos
    pole -= direction * pole.dot(direction)
    if pole.length_squared() < 0.000001:
        pole = rig.global_basis * (Vector3.LEFT if side == "L" else Vector3.RIGHT)
        pole -= direction * pole.dot(direction)
    if pole.length_squared() < 0.000001:
        pole = rig.global_basis * Vector3.BACK
        pole -= direction * pole.dot(direction)
    if pole.length_squared() < 0.000001:
        return
    var desired_knee: Vector3 = hip_pos + direction * along + pole.normalized() * away
    var foot_basis: Basis = foot.global_basis
    var hip_turn := Quaternion(
        (knee_pos - hip_pos).normalized(), (desired_knee - hip_pos).normalized())
    thigh.global_basis = Basis(hip_turn) * thigh.global_basis
    var knee_after: Vector3 = knee.global_position
    var ankle_after: Vector3 = foot.global_position
    var shin_from: Vector3 = ankle_after - knee_after
    var shin_to: Vector3 = reachable_goal - knee_after
    if shin_from.length_squared() > 0.000001 and shin_to.length_squared() > 0.000001:
        var knee_turn := Quaternion(shin_from.normalized(), shin_to.normalized())
        knee.global_basis = Basis(knee_turn) * knee.global_basis
    # Undo the inherited thigh/shin twist on the shoe, preserving the authored
    # boost/slide toe angle and the actual lowest-triangle sole measurement.
    foot.global_basis = foot_basis


func apply_slide_leg_ik(weight: float = 1.0) -> void:
    var influence: float = clampf(weight, 0.0, 1.0)
    if influence <= 0.00001 or not grounding_enabled or rig == null \
            or not (str(selected.get("legs", "A")) in ["B", "D"]):
        return
    if not slide_leg_chains.has("L") or not slide_leg_chains.has("R"):
        return
    var wearer: Node3D = rig.get_parent() as Node3D
    if wearer == null or absf(wearer.global_position.y) > 0.05 or bool(rig.get("jump_playback")):
        return
    # Capture uncorrected pose BEFORE leveling shoes and moving the hip.
    var baseline_rig_y: float = rig.position.y
    var original_rotations: Dictionary = {}
    if influence < 0.99999:
        for side in ["L", "R"]:
            var chain: Dictionary = slide_leg_chains[side]
            original_rotations[side] = {
                "thigh": (chain["thigh"] as Node3D).quaternion,
                "knee": (chain["knee"] as Node3D).quaternion,
                "foot": (chain["foot"] as Node3D).quaternion
            }
    # v228: B and D have genuinely flat shoe undersides in the authoring
    # geometry (mesh-local Y constant, zero mesh rotation). Correct both
    # shoes' pitch/roll BEFORE sampling vertices and solving ankle targets;
    # v227 preserved the tilted BOOST ankle pose, causing toe/heel floating.
    # The shortest-arc rotation preserves heading as much as possible.
    for side in ["L", "R"]:
        var foot: Node3D = slide_leg_chains[side]["foot"] as Node3D
        var sole_up: Vector3 = foot.global_basis * Vector3.UP
        if sole_up.length_squared() < 0.000001:
            return
        var level_rotation := Quaternion(sole_up.normalized(), Vector3.UP)
        foot.global_basis = Basis(level_rotation) * foot.global_basis
    var soles: Dictionary = get_active_foot_heights()
    if not soles.has("L") or not soles.has("R"):
        return
    var targets: Dictionary = {}
    var needed_hip_drop: float = 0.0
    for side in ["L", "R"]:
        var sole_y: float = float(soles[side])
        if is_nan(sole_y) or is_inf(sole_y):
            return
        var chain: Dictionary = slide_leg_chains[side]
        var thigh: Node3D = chain["thigh"] as Node3D
        var knee: Node3D = chain["knee"] as Node3D
        var foot: Node3D = chain["foot"] as Node3D
        # The leveled shoe orientation is retained by the IK solver;
        # using its real lowest triangles plants the entire flat outsole.
        var sole_world_y: float = rig.to_global(Vector3(0.0, sole_y, 0.0)).y
        var goal: Vector3 = foot.global_position + Vector3.UP * (
            TRAINING_VISIBLE_FLOOR_Y - sole_world_y)
        targets[side] = goal
        var hip: Vector3 = thigh.global_position
        var reach: float = thigh.global_position.distance_to(knee.global_position) + (
            knee.global_position.distance_to(foot.global_position)) - SLIDE_IK_REACH_MARGIN
        var lateral: float = Vector2(goal.x - hip.x, goal.z - hip.z).length()
        if reach > lateral:
            var vertical_reach: float = sqrt(maxf(0.0, reach * reach - lateral * lateral))
            needed_hip_drop = maxf(needed_hip_drop, hip.y - goal.y - vertical_reach)
    # Only the visual rig moves, never CharacterBody3D or its collision.
    # The existing grounding baseline is restored at the next frame.
    var hip_drop: float = clampf(maxf(SLIDE_IK_BASE_HIP_DROP,
        needed_hip_drop + SLIDE_IK_REACH_MARGIN), 0.0, SLIDE_IK_MAX_HIP_DROP)
    rig.position.y -= hip_drop
    for side in ["L", "R"]:
        _solve_slide_two_bone_ik(slide_leg_chains[side], targets[side], side)
    # Fade the solved hip, thigh, knee and leveled foot together.
    if influence < 0.99999:
        rig.position.y = lerpf(baseline_rig_y, rig.position.y, influence)
        for side in ["L", "R"]:
            var chain: Dictionary = slide_leg_chains[side]
            var start: Dictionary = original_rotations[side]
            for joint in ["thigh", "knee", "foot"]:
                var bone: Node3D = chain[joint] as Node3D
                bone.quaternion = (start[joint] as Quaternion).slerp(
                    bone.quaternion, influence).normalized()


func sync_afterimages() -> void:
    _sync_afterimage_visibility()

func _collect_original_meshes(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            var slot: String = _slot_for_bone(child.get_parent())
            var katana_role: String = _katana_role(child.get_parent())
            if not katana_role.is_empty():
                child.set_meta("sera_equipment_set", "K")
                _add_mesh("K", "weapon_r", child)
                if katana_role == "drawn":
                    katana_drawn_meshes.append(child)
                else:
                    katana_saya_meshes.append(child)
            elif bool(child.get_meta("sera_bird_leg", false)):
                # Existing reverse-jointed lower body now occupies C, freeing
                # D for the new complete standard-skeleton lower-body set.
                _add_mesh("C", "legs", child)
            elif not slot.is_empty() and child.name != "Swordeffect":
                _add_mesh("A", slot, child)
        else:
            _collect_original_meshes(child)

func _katana_role(node: Node) -> String:
    var parent: Node = node
    while parent != null and parent != rig:
        var group_name: String = str(parent.name).to_lower()
        if group_name == "katana_r_nukimi":
            return "drawn"
        if group_name.begins_with("katana_"):
            return "saya"
        parent = parent.get_parent()
    return ""

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

# v194: LOWER BODY D comes only from the normalized 12-mesh standard-leg asset.
# The combined Waist3 root is also used for HEAD C, so it must not install a
# second copy of the legs. Export builds use the embedded equivalent.
func _read_standard_lower_body_d() -> Dictionary:
    if FileAccess.file_exists(LOWER_BODY_D_SOURCE):
        var live: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOWER_BODY_D_SOURCE))
        if live is Dictionary and live.has("groups") and live.has("elements") and live.has("outliner"):
            return live
        push_warning("SERA lower body D: invalid live model, using embedded copy")
    var fallback: Variant = JSON.parse_string(LOWER_BODY_D_EMBEDDED.get_json())
    return fallback if fallback is Dictionary else {}


# The combined authoring model contains the temporary BOOSTER under A Chest.
# It is a separate equipment slot and follows Chest even if TORSO=B is selected.
func _find_outliner_group(entry: Dictionary, groups: Dictionary, name: String) -> Dictionary:
    var group: Dictionary = groups.get(str(entry.get("uuid", "")), {})
    if str(group.get("name", "")) == name:
        return entry
    for child in entry.get("children", []):
        if child is Dictionary:
            var found: Dictionary = _find_outliner_group(child, groups, name)
            if not found.is_empty():
                return found
    return {}

func _install_back_booster_placeholder(data: Dictionary) -> void:
    var roots: Array = data.get("outliner", [])
    if roots.is_empty() or not roots[0] is Dictionary:
        return
    var groups: Dictionary = {}
    var elements: Dictionary = {}
    for group in data.get("groups", []):
        if group is Dictionary:
            groups[str(group.get("uuid", ""))] = group
    for element in data.get("elements", []):
        if element is Dictionary:
            elements[str(element.get("uuid", ""))] = element
    var a_chest_entry: Dictionary = _find_outliner_group(roots[0], groups, "Chest")
    if a_chest_entry.is_empty():
        push_warning("SERA booster: A Chest authoring group is missing")
        return
    var booster_entry: Dictionary = _find_outliner_group(a_chest_entry, groups, "BOOSTER")
    if booster_entry.is_empty():
        return
    var chest_bone: Node3D = rig.get_node_or_null("Waist/Torso/Chest") as Node3D
    if chest_bone == null or not chest_bone.has_meta("bb_origin"):
        push_warning("SERA booster: A Chest runtime pivot is missing")
        return
    var chest_origin: Vector3 = chest_bone.get_meta("bb_origin", Vector3.ZERO)
    for set_id in ["A", "B"]:
        _attach_back_booster_group(booster_entry, chest_bone,
            chest_origin, groups, elements, set_id)

func _attach_back_booster_group(entry: Dictionary, parent: Node3D, parent_origin: Vector3,
        groups: Dictionary, elements: Dictionary, set_id: String) -> void:
    var group: Dictionary = groups.get(str(entry.get("uuid", "")), {})
    if group.is_empty():
        return
    var group_origin: Vector3 = _v3(group.get("origin", [0, 0, 0]))
    var pivot := Node3D.new()
    pivot.name = str(group.get("name", "BOOSTER")) + "_" + set_id
    # Blockbench group origins are absolute authoring-space positions. Each
    # child local transform must be measured from its immediate parent's Pivot.
    pivot.position = (group_origin - parent_origin) * MODEL_UNIT
    pivot.quaternion = rig.call("_blockbench_rotation",
        _v3(group.get("rotation", [0, 0, 0])))
    parent.add_child(pivot)
    for child in entry.get("children", []):
        if child is Dictionary:
            _attach_back_booster_group(child, pivot, group_origin, groups, elements, set_id)
        elif child is String and elements.has(child):
            var element: Dictionary = elements[child]
            if not element.has("vertices") or not element.has("faces"):
                continue
            var piece: MeshInstance3D = rig.call("_make_mesh", element)
            if piece == null:
                continue
            piece.name = set_id + "_" + str(element.get("name", "BoosterMesh"))
            piece.position = (_v3(element.get("origin", [0, 0, 0])) - group_origin) * MODEL_UNIT
            piece.quaternion = rig.call("_blockbench_rotation",
                _v3(element.get("rotation", [0, 0, 0])))
            var authored_name: String = str(element.get("name", ""))
            var mat: StandardMaterial3D = piece.material_override as StandardMaterial3D
            if mat != null:
                var steel: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
                steel.albedo_texture = null
                steel.albedo_color = Color("#141e2a") if authored_name.ends_with("_Inner") else (
                    Color("#48535f") if authored_name.ends_with("_Outer") else Color("#77818b"))
                piece.material_override = steel
            piece.set_meta("sera_equipment_set", set_id)
            # v205 mistakenly added pieces to the *parent*, bypassing the
            # pivot translation. Attach under the authoring group itself.
            pivot.add_child(piece)
            piece.visible = false
            _add_mesh(set_id, "booster", piece)
    if str(group.get("name", "")).begins_with("Thruster_"):
        _add_back_thruster_effect(pivot, group, entry, elements, set_id)


# Anchor flames on the authored OUTER nozzle rim, not on a hard-coded pivot.
# Re-editing any nozzle group origin in Blockbench keeps the nozzle and flame
# together. Local +Z is the rectangular exhaust's outward axis.
func _add_back_thruster_effect(pivot: Node3D, group: Dictionary,
        entry: Dictionary, elements: Dictionary, set_id: String) -> void:
    var side_name: String = str(group.get("name", ""))
    var outer: Dictionary = {}
    for child in entry.get("children", []):
        if child is String:
            var candidate: Dictionary = elements.get(child, {})
            if str(candidate.get("name", "")) == side_name + "_Outer":
                outer = candidate
                break
    if outer.is_empty():
        push_warning("SERA booster: missing authored nozzle rim %s" % side_name)
        return
    var far_z: float = -INF
    for vertex in (outer.get("vertices", {}) as Dictionary).values():
        var position: Vector3 = _v3(vertex)
        far_z = maxf(far_z, position.z)
    if is_inf(far_z):
        return
    var author_rim: Vector3 = _v3(outer.get("origin", [0, 0, 0]))
    author_rim.z += far_z + 0.08  # 0.08 Blockbench units outside the metal.
    var fx: Node3D = BACK_THRUSTER_FX.new()
    fx.name = side_name + "_ExhaustFX"
    fx.position = (author_rim - _v3(group.get("origin", [0, 0, 0]))) * MODEL_UNIT
    pivot.add_child(fx)
    if not back_thruster_effects.has(set_id):
        back_thruster_effects[set_id] = []
    (back_thruster_effects[set_id] as Array).append(fx)

func update_back_thruster_fx(active: bool, exhaust_world: Vector3,
        delta: float, backstroke_weight: float = 0.0,
        left_sector_world: Vector3 = Vector3.ZERO,
        acceleration_burst: bool = false,
        melee_sustain: bool = false) -> void:
    var selected_booster: String = str(selected.get("booster", "A"))
    for set_id in back_thruster_effects.keys():
        for raw_fx in back_thruster_effects[set_id]:
            var fx: Node3D = raw_fx
            if is_instance_valid(fx):
                fx.call("set_exhaust", active and str(set_id) == selected_booster,
                    exhaust_world, delta, backstroke_weight, left_sector_world,
                    acceleration_burst, melee_sustain)

func _install_standard_lower_body_d() -> void:
    var data: Dictionary = _read_standard_lower_body_d()
    var groups: Dictionary = {}
    var elements: Dictionary = {}
    for group in data.get("groups", []):
        if group is Dictionary:
            groups[str(group.get("uuid", ""))] = group
    for mesh in data.get("elements", []):
        if mesh is Dictionary:
            elements[str(mesh.get("uuid", ""))] = mesh
    var roots: Array = data.get("outliner", [])
    if roots.size() != 1 or groups.size() != 7 or elements.size() != 12:
        push_error("SERA lower body D requires one root, seven bones and twelve meshes")
        return
    var root_entry: Variant = roots[0]
    if not root_entry is Dictionary or _simple_name(str(groups.get(
            str(root_entry.get("uuid", "")), {}).get("name", ""))) != "waist":
        push_error("SERA lower body D: Waist root not found")
        return
    var base_root: Node3D = null
    for child in rig.get_children():
        if child is Node3D and child.has_meta("bb_origin"):
            base_root = child
            break
    if base_root == null:
        push_error("SERA lower body D: original waist bone not found")
        return
    # All meshes inherit A's existing hip/knee/ankle animation pivots.
    _attach_group_meshes(root_entry, base_root, groups, elements, "D")
    var imported: Array = (available.get("D", {}) as Dictionary).get("legs", [])
    if imported.size() != 12:
        push_error("SERA lower body D: %d / 12 meshes imported" % imported.size())
        for raw_piece in imported:
            var piece: MeshInstance3D = raw_piece
            piece.visible = false
        available.erase("D")

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
            # Waist3's legacy embedded D geometry is superseded by the
            # dedicated D source. Retain Head C from this root unchanged.
            if set_id == "C" and slot == "legs":
                continue
            if slot.is_empty() or not element.has("vertices") or not element.has("faces"):
                continue
            var piece: MeshInstance3D = rig.call("_make_mesh", element)
            if piece == null:
                continue
            # Authored Waist3 contains Head C and a full human lower body.
            # Only lower-body geometry becomes set D; HEAD stays C.
            var equipment_set: String = "D" if set_id == "C" and slot == "legs" else set_id
            piece.name = "%s_%s" % [equipment_set, str(element.get("name", "Mesh"))]
            _apply_equipment_tint(piece, equipment_set, int(element.get("color", -1)))
            var base_origin: Vector3 = target_bone.get_meta("bb_origin", Vector3.ZERO)
            piece.position = (_v3(element.get("origin", [0, 0, 0])) - base_origin) * MODEL_UNIT
            # User-authored Head C meshes have nonzero local rotations.
            piece.quaternion = rig.call("_blockbench_rotation", _v3(element.get("rotation", [0, 0, 0])))
            target_bone.add_child(piece)
            piece.visible = false
            _add_mesh(equipment_set, slot, piece)

func _apply_equipment_tint(piece: MeshInstance3D, set_id: String, color_index: int = -1) -> void:
    # Keep A untouched and isolate B's material from other variants.
    piece.set_meta("sera_equipment_set", set_id)
    # Blockbench free-model material color is an editor palette index. The
    # author's D uses rose pelvis/leg armor and pale-blue boots; its 16x16
    # UVs are not valid coordinates for the normal SERA 96x32 character atlas.
    # Do not render it with A's palette, which made the D set appear like A.
    if set_id == "D":
        var authored: StandardMaterial3D = piece.material_override as StandardMaterial3D
        if authored != null:
            var material_d: StandardMaterial3D = authored.duplicate() as StandardMaterial3D
            material_d.albedo_texture = null
            match color_index:
                1:
                    material_d.albedo_color = Color("#c98d8d") # pelvis
                3:
                    material_d.albedo_color = Color("#ce8585") # thighs + shins
                5:
                    material_d.albedo_color = Color("#adc7df") # boots
                _:
                    material_d.albedo_color = Color("#afb8c2")
            piece.material_override = material_d
        return
    # No texture is embedded in the Head C Blockbench source. Tint only C,
    # which otherwise samples the nearly white corner of SERA's palette.
    if set_id == "C" and str(piece.name).contains("HeadC_"):
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
    # Active v1 local profiles are migrated to the new v2 leg IDs by SeraSave.
    var archive: Node = rig.get_node_or_null("/root/SeraSave")
    if archive != null and int(archive.get("active_slot")) > 0:
        var working: Dictionary = archive.call("get_working_equipment")
        for slot in SLOTS:
            select_part(slot, str(working.get(slot, "A")), false)
        return
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    # Historical v191/v192 global cfg files lack schema_version and may
    # contain the removed FEET slot. v193+ cfg values must not be remapped.
    var legacy: bool = int(cfg.get_value("equipment", "schema_version", 1)) < 2
    var legs: String = str(cfg.get_value("equipment", "legs", "A"))
    if legacy:
        var feet: String = str(cfg.get_value("equipment", "feet", "A"))
        if legs == "D":  # v189-v192 D = bird
            legs = "C"
        elif legs == "C" or feet == "C":  # v191 C or v192 FEET C = human
            legs = "D"
    for slot in SLOTS:
        var saved_set: String = str(cfg.get_value("equipment", slot, "A"))
        if slot == "legs":
            saved_set = legs
        select_part(slot, saved_set, false)

func _save_selection() -> void:
    var archive: Node = rig.get_node_or_null("/root/SeraSave")
    if archive != null:
        for slot in SLOTS:
            archive.call("update_working_equipment", slot, str(selected.get(slot, "A")))
    var cfg := ConfigFile.new()
    for slot in SLOTS:
        cfg.set_value("equipment", slot, selected.get(slot, "A"))
    cfg.set_value("equipment", "schema_version", 2)
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
