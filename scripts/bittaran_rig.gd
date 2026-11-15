extends Node3D
## Bittaran quadruped: independent Blockbench bone rig, authored stance and
## looping IDLE/TURN/APPROACH clips. Player's SeraRig is never modified.
const SOURCE_PATH: String = "res://models/bosses/Bittaran.bbmodel"
const EMBEDDED = preload("res://assets/bittaran_data.gd")
const UNIT: float = 0.145
const BLEND_SECONDS: float = 0.24
const PALETTE = [
    Color("#66748a"), Color("#8597b0"), Color("#b2c7df"),
    Color("#b5cbe4"), Color("#8ba9c9"), Color("#a1bddb"),
    Color("#3e526c"), Color("#c8dcef"), Color("#526a89"), Color("#e0ebf5")
]
var bones: Dictionary = {}
var bind_rotations: Dictionary = {}
var animations: Dictionary = {}
var bone_uuid_by_name: Dictionary = {}
var attack_entry_rotations: Dictionary = {}
var active_authored_attack: String = ""
var authored_leg_id: String = ""
# The user authored one front-left limb. Retarget its rotational DELTAS
# relative to Wait for each of the other three mechanically symmetric limbs.
const ATTACK_NAMES: Dictionary = {
    "stomp": "踏みつけ", "kick": "弾き", "sweep": "なぎ払い"
}
const ATTACK_LEG_BONES: Dictionary = {
    "leg_fl": ["FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L"],
    "leg_fr": ["FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R"],
    "leg_rl": ["RearLeg_L", "RearLowerLeg_L", "RearFoot_L"],
    "leg_rr": ["RearLeg_R", "RearLowerLeg_R", "RearFoot_R"]
}
var current_clip: String = "Idle"
var elapsed: float = 0.0
var blend_elapsed: float = BLEND_SECONDS
var blend_from: Dictionary = {}
# Procedural HEAD look yaw is not part of an authored blend source.
var external_head_yaw: float = 0.0
var loading_ok: bool = false

func _ready() -> void:
    # Interpolate all IK pose joints against the interpolated combat camera.
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
    # Source is useful for desktop authoring; embed works in Android exports.
    var source: String = ""
    if FileAccess.file_exists(SOURCE_PATH):
        source = FileAccess.get_file_as_string(SOURCE_PATH)
    if source.is_empty():
        source = EMBEDDED.get_json()
    var parsed: Variant = JSON.parse_string(source)
    if not parsed is Dictionary:
        push_error("Bittaran: missing/corrupt Blockbench model")
        return
    var data: Dictionary = parsed
    var groups: Dictionary = {}
    var elements: Dictionary = {}
    for group in data.get("groups", []):
        groups[str(group.get("uuid", ""))] = group
    for element in data.get("elements", []):
        elements[str(element.get("uuid", ""))] = element
    for entry in data.get("outliner", []):
        _add_entry(entry, self, Vector3.ZERO, groups, elements)
    for clip in data.get("animations", []):
        animations[str(clip.get("name", ""))] = clip
    loading_ok = bones.size() == 14 and animations.has("Wait") and (
        animations.has("Idle") and animations.has("Turn")
        and animations.has("Approach")
        and animations.has("踏みつけ") and animations.has("弾き")
        and animations.has("なぎ払い"))
    if not loading_ok:
        push_error("Bittaran: missing legs, feet or motion clips")
        return
    apply_pose("Wait", 0.0)

func _v3(raw: Variant) -> Vector3:
    if raw is Array and raw.size() >= 3:
        return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
    return Vector3.ZERO

func _bb_rotation(angles: Vector3) -> Quaternion:
    return (Quaternion(Vector3.BACK, deg_to_rad(angles.z))
        * Quaternion(Vector3.UP, deg_to_rad(angles.y))
        * Quaternion(Vector3.RIGHT, deg_to_rad(angles.x))).normalized()

func _add_entry(entry: Variant, parent: Node3D, parent_origin: Vector3,
        groups: Dictionary, elements: Dictionary) -> void:
    if entry is Dictionary:
        var uid: String = str(entry.get("uuid", ""))
        if not groups.has(uid):
            return
        var group: Dictionary = groups[uid]
        var origin: Vector3 = _v3(group.get("origin", [0, 0, 0]))
        var joint := Node3D.new()
        joint.name = str(group.get("name", "Joint"))
        joint.position = (origin - parent_origin) * UNIT
        joint.quaternion = _bb_rotation(_v3(group.get("rotation", [0, 0, 0])))
        joint.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
        parent.add_child(joint)
        bones[uid] = joint
        bone_uuid_by_name[joint.name] = uid
        bind_rotations[uid] = joint.quaternion
        for child in entry.get("children", []):
            _add_entry(child, joint, origin, groups, elements)
    elif entry is String and elements.has(entry):
        var element: Dictionary = elements[entry]
        var mesh: MeshInstance3D = _make_mesh(element)
        if mesh == null:
            return
        mesh.name = str(element.get("name", "Plate"))
        mesh.position = (_v3(element.get("origin", [0, 0, 0])) - parent_origin) * UNIT
        mesh.quaternion = _bb_rotation(_v3(element.get("rotation", [0, 0, 0])))
        parent.add_child(mesh)

func _make_mesh(element: Dictionary) -> MeshInstance3D:
    var verts: Dictionary = element.get("vertices", {})
    var faces: Dictionary = element.get("faces", {})
    if verts.is_empty() or faces.is_empty():
        return null
    var centroid := Vector3.ZERO
    for raw in verts.values():
        centroid += _v3(raw) * UNIT
    centroid /= float(verts.size())
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var triangles: int = 0
    for raw_face in faces.values():
        var face: Dictionary = raw_face
        var points: Array[Vector3] = []
        for key in face.get("vertices", []):
            if verts.has(key):
                points.append(_v3(verts[key]) * UNIT)
        if points.size() < 3:
            continue
        var face_center := Vector3.ZERO
        for point in points:
            face_center += point
        face_center /= float(points.size())
        var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
        if normal.length_squared() < 0.00000001:
            continue
        if normal.dot(face_center - centroid) < 0.0:
            points.reverse()
        for i in range(1, points.size() - 1):
            var n: Vector3 = (points[i] - points[0]).cross(
                points[i + 1] - points[0]).normalized()
            if n.length_squared() < 0.00000001:
                continue
            for p in [points[0], points[i], points[i + 1]]:
                tool.set_normal(n)
                tool.add_vertex(p)
            triangles += 1
    if triangles == 0:
        return null
    var piece := MeshInstance3D.new()
    piece.mesh = tool.commit()
    var mat := StandardMaterial3D.new()
    var index: int = clampi(int(element.get("color", 2)), 0, PALETTE.size() - 1)
    mat.albedo_color = PALETTE[index]
    mat.metallic = 0.43
    mat.roughness = 0.67
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    piece.material_override = mat
    piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return piece

func _key_rotation(key: Dictionary) -> Quaternion:
    var points: Array = key.get("data_points", [])
    if points.is_empty():
        return Quaternion.IDENTITY
    var p: Dictionary = points[0]
    return _bb_rotation(Vector3(float(p.get("x", 0)), float(p.get("y", 0)),
        float(p.get("z", 0))))

func _sample_rotation(keys: Array, t: float) -> Quaternion:
    if keys.is_empty():
        return Quaternion.IDENTITY
    if t <= float(keys[0].get("time", 0)):
        return _key_rotation(keys[0])
    for i in range(1, keys.size()):
        var end: float = float(keys[i].get("time", 0))
        if t <= end:
            var start: float = float(keys[i - 1].get("time", 0))
            var alpha: float = clampf((t - start) / maxf(end - start, 0.0001), 0.0, 1.0)
            return _key_rotation(keys[i - 1]).slerp(_key_rotation(keys[i]), alpha)
    return _key_rotation(keys[keys.size() - 1])

func apply_pose(clip_name: String, t: float) -> void:
    if not animations.has(clip_name):
        return
    var clip: Dictionary = animations[clip_name]
    var duration: float = float(clip.get("length", 0.0))
    var sample_time: float = fposmod(t, duration) if duration > 0.0 else 0.0
    var tracks: Dictionary = clip.get("animators", {})
    for uid in bones.keys():
        var joint: Node3D = bones[uid]
        var rotation: Quaternion = bind_rotations[uid]
        if tracks.has(uid):
            rotation = rotation * _sample_rotation(tracks[uid].get("keyframes", []), sample_time)
        if blend_elapsed < BLEND_SECONDS and blend_from.has(uid):
            var amount: float = clampf(blend_elapsed / BLEND_SECONDS, 0.0, 1.0)
            rotation = (blend_from[uid] as Quaternion).slerp(rotation, amount)
        joint.quaternion = rotation.normalized()

func set_external_head_yaw(yaw: float) -> void:
    external_head_yaw = yaw


func set_motion(clip_name: String, delta: float) -> void:
    if not loading_ok or not animations.has(clip_name):
        return
    if current_clip != clip_name:
        blend_from.clear()
        for uid in bones.keys():
            var joint: Node3D = bones[uid]
            var source: Quaternion = joint.quaternion
            if joint.name == "Head" and absf(external_head_yaw) > 0.000001:
                source = (source * Quaternion(
                    Vector3.UP, -external_head_yaw)).normalized()
            blend_from[uid] = source
        current_clip = clip_name
        elapsed = 0.0
        blend_elapsed = 0.0
    elapsed += maxf(0.0, delta)
    blend_elapsed = minf(BLEND_SECONDS, blend_elapsed + maxf(0.0, delta))
    apply_pose(current_clip, elapsed)

## Playback of user-authored attack keys, separate from procedural foot
## contact IK. Only Body and the chosen attacking leg receive author data;
## support legs continue to use their world-planted IK anchors.
func start_authored_attack(kind: String, id: String) -> void:
    if not loading_ok or not ATTACK_NAMES.has(kind) or (
            not ATTACK_LEG_BONES.has(id)):
        return
    if active_authored_attack == kind and authored_leg_id == id:
        return
    active_authored_attack = kind
    authored_leg_id = id
    attack_entry_rotations.clear()
    for uid in bones:
        attack_entry_rotations[uid] = (bones[uid] as Node3D).quaternion


func end_authored_attack() -> void:
    active_authored_attack = ""
    authored_leg_id = ""
    attack_entry_rotations.clear()


func _authored_key_rotation(clip_name: String,
        bone_name: String, seconds: float) -> Quaternion:
    var uid: String = str(bone_uuid_by_name.get(bone_name, ""))
    if uid.is_empty() or not animations.has(clip_name):
        return Quaternion.IDENTITY
    var clip: Dictionary = animations[clip_name]
    var tracks: Dictionary = clip.get("animators", {})
    var track: Dictionary = tracks.get(uid, {})
    var keys: Array = track.get("keyframes", [])
    var bind: Quaternion = bind_rotations.get(uid, Quaternion.IDENTITY)
    if keys.is_empty():
        return bind
    return (bind * _sample_rotation(keys, seconds)).normalized()


func _mirror_author_delta(delta: Quaternion, target_id: String) -> Quaternion:
    # Spatial reflections of an AXIAL rotation: S*R*S, det(S)=-1.
    # Mirroring X swaps left/right; mirroring Z swaps fore/rear.
    var q: Quaternion = delta
    if target_id.ends_with("r"):
        q = Quaternion(q.x, -q.y, -q.z, q.w)
    if target_id.begins_with("leg_r"):
        q = Quaternion(-q.x, -q.y, q.z, q.w)
    return q.normalized()


func _authored_rotation_for_leg(kind: String,
        target_id: String, bone_slot: int, at: float) -> Quaternion:
    var source_name: String = ATTACK_LEG_BONES["leg_fl"][bone_slot]
    var dest_name: String = ATTACK_LEG_BONES[target_id][bone_slot]
    var source_wait: Quaternion = _authored_key_rotation("Wait",
        source_name, 0.0)
    var dest_wait: Quaternion = _authored_key_rotation("Wait",
        dest_name, 0.0)
    var source_action: Quaternion = _authored_key_rotation(
        str(ATTACK_NAMES[kind]), source_name, at)
    var delta: Quaternion = (source_wait.inverse() * source_action).normalized()
    return (dest_wait * _mirror_author_delta(delta, target_id)).normalized()


func authored_clip_length(kind: String) -> float:
    if not ATTACK_NAMES.has(kind):
        return 0.0
    var clip: Dictionary = animations.get(str(ATTACK_NAMES[kind]), {})
    return float(clip.get("length", 0.0))


func apply_authored_attack_pose(frame: Dictionary) -> void:
    if frame.is_empty() or not loading_ok:
        return
    var kind: String = str(frame.get("kind", ""))
    var id: String = str(frame.get("id", ""))
    if not ATTACK_NAMES.has(kind) or not ATTACK_LEG_BONES.has(id):
        return
    if active_authored_attack != kind or authored_leg_id != id:
        start_authored_attack(kind, id)
    var seconds: float = float(frame.get("time", 0.0))
    var windup: float = float(frame.get("windup", 1.0))
    var strike: float = float(frame.get("strike", 0.2))
    var recovery: float = float(frame.get("recovery", 0.5))
    var preparation: float = 0.0 if kind == "stomp" else windup
    var clip_time: float = clampf(seconds - preparation,
        0.0, authored_clip_length(kind))
    var blend_in: float = clampf(seconds /
        maxf(0.24 if kind == "stomp" else preparation, 0.001), 0.0, 1.0)
    blend_in = blend_in * blend_in * (3.0 - 2.0 * blend_in)
    var retreat: float = clampf((seconds - windup - strike) /
        maxf(recovery, 0.001), 0.0, 1.0)
    var blend_out: float = 1.0 - retreat * retreat * (3.0 - 2.0 * retreat)
    var weight: float = blend_in * blend_out
    # The Body track is the LOW authored crouch at t=0 for KICK/SWEEP,
    # reached over exactly 0.70s before those authored strikes play.
    var slots: Array[String] = ["Body"]
    for raw in ATTACK_LEG_BONES[id]:
        slots.append(str(raw))
    for bone_name in slots:
        var uid: String = str(bone_uuid_by_name.get(bone_name, ""))
        if uid.is_empty() or not bones.has(uid):
            continue
        var node: Node3D = bones[uid]
        var target_rotation: Quaternion
        if bone_name == "Body":
            target_rotation = _authored_key_rotation(
                str(ATTACK_NAMES[kind]), bone_name, clip_time)
        else:
            var bone_slot: int = slots.find(bone_name) - 1
            target_rotation = _authored_rotation_for_leg(
                kind, id, bone_slot, clip_time)
        var entry: Quaternion = attack_entry_rotations.get(
            uid, node.quaternion)
        var rest: Quaternion = _authored_key_rotation("Wait", bone_name, 0.0)
        # Smoothly leave the current Turn/Approach pose, and blend out
        # toward neutral to hand control back to the existing Idle clip.
        node.quaternion = entry.slerp(target_rotation, weight).slerp(
            rest, 1.0 - blend_out).normalized()


func bone_names() -> Array[String]:
    var result: Array[String] = []
    for raw in bones.values():
        result.append(str((raw as Node3D).name))
    return result
