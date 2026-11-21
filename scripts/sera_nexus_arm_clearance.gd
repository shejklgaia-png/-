extends RefCounted
## Single NEXUS_pose arm/leg clearance implementation shared by in-game NEXUS
## and Equipment Intake FULL BODY. Display-only: never edits authored clips,
## original meshes, a save profile, or combat physics.
const NEXUS_ARM_STEP_DEGREES: float = 1.5
const NEXUS_SHOULDER_STEP_DEGREES: float = 0.2
const NEXUS_SHOULDER_MAX_DEGREES: float = 3.2
const NEXUS_ARM_MAX_STEPS: int = 16 # 24 degrees max
const NEXUS_ARM_CLEARANCE: float = 0.018

var sera_display_rig: Node3D
var nexus_arm_bones: Dictionary = {}
var nexus_arm_rest_rotations: Dictionary = {}

func fit(display_rig: Node3D, authored_rotations: Dictionary) -> void:
    if display_rig == null or authored_rotations.size() != 4:
        return
    sera_display_rig = display_rig
    nexus_arm_rest_rotations = authored_rotations.duplicate()
    nexus_arm_bones.clear()
    var bones: Dictionary = display_rig.get("bones")
    for raw_bone in bones.values():
        var bone: Node3D = raw_bone
        if nexus_arm_rest_rotations.has(str(bone.name)):
            nexus_arm_bones[str(bone.name)] = bone
    if nexus_arm_bones.size() != 4:
        return
    _fit_nexus_arms_to_lower_body()

func _restore_nexus_arm_pose() -> void:
    for name in nexus_arm_rest_rotations.keys():
        var bone: Node3D = nexus_arm_bones.get(name)
        if is_instance_valid(bone):
            bone.quaternion = nexus_arm_rest_rotations[name]

func _set_nexus_side_raise(side: String, shoulder_degrees: float,
        upperarm_degrees: float) -> void:
    # Positive Z raises R; negative Z raises L. Keep NEXUSpose's authored
    # torso, elbows, hands, weapons and every bind-position unchanged.
    var sign: float = 1.0 if side == "R" else -1.0
    for part in ["Shoulder", "UpperArm"]:
        var name: String = part + "_" + side
        var bone: Node3D = nexus_arm_bones.get(name)
        if not is_instance_valid(bone):
            continue
        var degrees: float = shoulder_degrees if part == "Shoulder" else upperarm_degrees
        var original: Quaternion = nexus_arm_rest_rotations[name]
        bone.quaternion = (
            Quaternion(Vector3.BACK, deg_to_rad(sign * degrees)) * original
        ).normalized()

func _nexus_mesh_bounds_in_rig(piece: MeshInstance3D) -> AABB:
    # Compare mesh geometry in the same rig-local space, independent of
    # exhibit yaw, zoom, and temporary camera-relative presentation scale.
    var source: AABB = piece.mesh.get_aabb()
    var result: AABB = AABB()
    var first: bool = true
    for ix in [0.0, 1.0]:
        for iy in [0.0, 1.0]:
            for iz in [0.0, 1.0]:
                var vertex: Vector3 = source.position + source.size * Vector3(ix, iy, iz)
                var point: Vector3 = sera_display_rig.to_local(piece.to_global(vertex))
                if first:
                    result = AABB(point, Vector3.ZERO)
                    first = false
                else:
                    result = result.expand(point)
    return result

func _nexus_arm_piece_on_side(piece: MeshInstance3D, side: String) -> bool:
    # The equipment provider registers the actual selected meshes under A's
    # animated bones, including B arms. No hard-coded model/set is assumed.
    var node: Node = piece.get_parent()
    while node != null and node != sera_display_rig:
        var name: String = str(node.name)
        if name == "Shoulder_" + side or name == "UpperArm_" + side or (
                name == "Forearm_" + side or name == "Hand_" + side):
            return true
        node = node.get_parent()
    return false

func _nexus_mesh_obb_in_rig(piece: MeshInstance3D) -> Dictionary:
    # A world/rig-axis AABB exaggerates the occupied space of tilted arms.
    # Keep each mesh's own axes so sloped arms do not collide with empty
    # corners of their enclosing world-aligned box.
    var local_box: AABB = piece.mesh.get_aabb()
    var pose: Transform3D = sera_display_rig.global_transform.affine_inverse() * piece.global_transform
    var axes: Array[Vector3] = [
        pose.basis.x.normalized(), pose.basis.y.normalized(), pose.basis.z.normalized()]
    var extents: Vector3 = local_box.size * 0.5
    var half: Vector3 = Vector3(
        extents.x * pose.basis.x.length(),
        extents.y * pose.basis.y.length(),
        extents.z * pose.basis.z.length())
    return {
        "center": pose * local_box.get_center(),
        "axes": axes,
        "half": half
    }

func _nexus_boxes_overlap(a: Dictionary, b: Dictionary) -> bool:
    # OBB/OBB separating-axis theorem: test 3 axes per mesh and all 9 cross
    # products. A tilted shoulder's broadphase AABB alone is not a collision.
    var aa: Array = a["axes"]
    var ba: Array = b["axes"]
    var axes: Array[Vector3] = []
    for axis in aa:
        axes.append(axis)
    for axis in ba:
        axes.append(axis)
    for i in range(3):
        for j in range(3):
            var cross_axis: Vector3 = (aa[i] as Vector3).cross(ba[j])
            if cross_axis.length_squared() > 0.000001:
                axes.append(cross_axis.normalized())
    var a_half: Vector3 = a["half"]
    var b_half: Vector3 = b["half"]
    var delta: Vector3 = (b["center"] as Vector3) - (a["center"] as Vector3)
    for axis in axes:
        var radius_a: float = (
            absf(axis.dot(aa[0])) * a_half.x
            + absf(axis.dot(aa[1])) * a_half.y
            + absf(axis.dot(aa[2])) * a_half.z)
        var radius_b: float = (
            absf(axis.dot(ba[0])) * b_half.x
            + absf(axis.dot(ba[1])) * b_half.y
            + absf(axis.dot(ba[2])) * b_half.z)
        if absf(delta.dot(axis)) > radius_a + radius_b + NEXUS_ARM_CLEARANCE:
            return false
    return true

func _nexus_side_overlap_count(side: String, arms: Array,
        leg_boxes: Array[Dictionary]) -> int:
    # Use a fast axis-aligned broadphase and an oriented narrowphase.
    var overlaps: int = 0
    for raw_piece in arms:
        if not raw_piece is MeshInstance3D:
            continue
        var piece: MeshInstance3D = raw_piece
        if piece.mesh == null or not piece.is_visible_in_tree():
            continue
        if not _nexus_arm_piece_on_side(piece, side):
            continue
        var arm_box: AABB = _nexus_mesh_bounds_in_rig(piece).grow(NEXUS_ARM_CLEARANCE)
        var arm_obb: Dictionary = {}
        for leg_data in leg_boxes:
            if not arm_box.intersects(leg_data["aabb"]):
                continue
            if arm_obb.is_empty():
                arm_obb = _nexus_mesh_obb_in_rig(piece)
            if _nexus_boxes_overlap(arm_obb, leg_data["obb"]):
                overlaps += 1
    return overlaps

func _fit_nexus_arms_to_lower_body() -> void:
    if sera_display_rig == null or nexus_arm_rest_rotations.size() != 4:
        return
    # Always begin from the untouched NEXUSpose; no accumulated offsets.
    _restore_nexus_arm_pose()
    var handler: RefCounted = sera_display_rig.get("equipment_handler")
    if handler == null:
        return
    var choices: Dictionary = handler.get("available")
    var selected_legs: String = str(sera_display_rig.call("get_equipment_selection", "legs"))
    var selected_arms: String = str(sera_display_rig.call("get_equipment_selection", "arms"))
    var legs: Array = (choices.get(selected_legs, {}) as Dictionary).get("legs", [])
    var arms: Array = (choices.get(selected_arms, {}) as Dictionary).get("arms", [])
    var leg_boxes: Array[Dictionary] = []
    for raw_piece in legs:
        if not raw_piece is MeshInstance3D:
            continue
        var piece: MeshInstance3D = raw_piece
        if piece.mesh != null and piece.is_visible_in_tree():
            leg_boxes.append({
                "aabb": _nexus_mesh_bounds_in_rig(piece),
                "obb": _nexus_mesh_obb_in_rig(piece)
            })
    if leg_boxes.is_empty():
        return
    for side in ["L", "R"]:
        var original_contacts: int = _nexus_side_overlap_count(side, arms, leg_boxes)
        if original_contacts == 0:
            continue # Keep EXACT original NEXUSpose on clear side.
        var best_contacts: int = original_contacts
        var best_step: int = 0
        # Hard cap at 24 degrees of upper-arm lift; shoulders move only 3.2.
        # If geometry cannot clear, choose the *least interfering* modest
        # angle instead of forcing the arms nearly horizontal.
        for step in range(1, NEXUS_ARM_MAX_STEPS + 1):
            var shoulder: float = minf(
                NEXUS_SHOULDER_MAX_DEGREES,
                float(step) * NEXUS_SHOULDER_STEP_DEGREES)
            var upper: float = float(step) * NEXUS_ARM_STEP_DEGREES
            _set_nexus_side_raise(side, shoulder, upper)
            var contacts: int = _nexus_side_overlap_count(side, arms, leg_boxes)
            if contacts < best_contacts:
                best_contacts = contacts
                best_step = step
            if contacts == 0:
                break # Minimum fully clear angle.
        if best_step == 0:
            # No improvement anywhere in the allowed range: leave the
            # authored pose unchanged rather than making it point sideways.
            _set_nexus_side_raise(side, 0.0, 0.0)
        else:
            _set_nexus_side_raise(side,
                minf(NEXUS_SHOULDER_MAX_DEGREES,
                    float(best_step) * NEXUS_SHOULDER_STEP_DEGREES),
                float(best_step) * NEXUS_ARM_STEP_DEGREES)
        if best_contacts > 0:
            push_warning("NEXUSpose: " + side
                + " arm has remaining contact, preserved minimal practical lift")

