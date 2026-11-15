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
# Parent-local pivots are immutable Blockbench rig geometry. IK may
# translate a foot in WORLD space for saturated contact, but that must
# never become the following frame's anatomical joint origin.
var bind_positions: Dictionary = {}
var animations: Dictionary = {}
var bone_uuid_by_name: Dictionary = {}
var attack_entry_rotations: Dictionary = {}
var active_authored_attack: String = ""
var authored_leg_id: String = ""
# Rotational bearing adjustment is applied to the entire attacking leg.
# Authored joint-local rotations are never stretched or rewritten.
const ATTACK_LEG_AIM_MAX_DEGREES: float = 100.0
const ATTACK_LEG_AIM_TURN_DEGREES_PER_SECOND: float = 300.0
var attack_leg_aim_yaw: float = 0.0
# Captured ACTUAL active combat pose becomes a six-tenths-second smooth
# transition into the raised original STOMP anticipation pose. HEAD is
# deliberately excluded: its live player-tracking owner never changes.
var down_stomp_leg_id: String = ""
var down_stomp_entry_rotations: Dictionary = {}
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
    # Initialize the HEAD's static neck pitch ONCE. Thereafter only
    # battle.gd's live look controller owns this quaternion; playing a
    # locomotion/attack clip must never overwrite even one frame of yaw.
    apply_pose("Wait", 0.0)
    var head_uid: String = str(bone_uuid_by_name.get("Head", ""))
    if bones.has(head_uid):
        (bones[head_uid] as Node3D).quaternion = _authored_key_rotation(
            "Wait", "Head", 0.0)

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
        bind_positions[uid] = joint.position
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
        if joint.name != "Head":
            # Solve contacts only for the CURRENT rendered frame. A foot
            # was translated globally by IK near the floor in previous
            # frames; restore its exact authored LOCAL pivot before the
            # next clip sample to prevent permanent bone length drift.
            joint.position = bind_positions[uid]
        if joint.name == "Head":
            # NEVER write HEAD here. The tracking controller owns its
            # rotation continuously across Idle, Turn, Approach, attack,
            # and the 0.24s motion-crossfade frames. Reapplying Wait
            # each tick previously erased the previous look at the
            # animation update and produced a visible pose flicker.
            continue
        var rotation: Quaternion = bind_rotations[uid]
        if tracks.has(uid):
            rotation = rotation * _sample_rotation(
                tracks[uid].get("keyframes", []), sample_time)
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
            if joint.name == "Head":
                continue
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
    attack_leg_aim_yaw = 0.0
    for uid in bones:
        attack_entry_rotations[uid] = (bones[uid] as Node3D).quaternion



## Capture joint-local rotations BEFORE clearing the active attack. Use
## the author's STOMP windup keys as a target (not a newly fabricated
## folded pose); all untouched support arms remain under world-fixed IK.
func begin_stomp_down_windup(id: String) -> bool:
    if not loading_ok or not ATTACK_LEG_BONES.has(id):
        return false
    down_stomp_leg_id = id
    down_stomp_entry_rotations.clear()
    var names: Array[String] = ["Body"]
    for name in ATTACK_LEG_BONES[id]:
        names.append(str(name))
    for name in names:
        var uid: String = str(bone_uuid_by_name.get(name, ""))
        if uid.is_empty() or not bones.has(uid):
            clear_stomp_down_windup()
            return false
        down_stomp_entry_rotations[uid] = (
            bones[uid] as Node3D).quaternion
    return true


func apply_stomp_down_windup(progress: float) -> void:
    if down_stomp_leg_id.is_empty():
        return
    var alpha: float = smoothstep(0.0, 1.0,
        clampf(progress, 0.0, 1.0))
    var names: Array[String] = ["Body"]
    for name in ATTACK_LEG_BONES[down_stomp_leg_id]:
        names.append(str(name))
    for slot in range(names.size()):
        var name: String = names[slot]
        var uid: String = str(bone_uuid_by_name.get(name, ""))
        if not bones.has(uid) or not down_stomp_entry_rotations.has(uid):
            continue
        var destination: Quaternion = (
            _authored_key_rotation("踏みつけ", "Body", 1.25)
            if slot == 0 else _authored_rotation_for_leg(
                "stomp", down_stomp_leg_id, slot - 1, 1.25))
        var origin: Quaternion = down_stomp_entry_rotations[uid]
        (bones[uid] as Node3D).quaternion = origin.slerp(
            destination, alpha).normalized()


func clear_stomp_down_windup() -> void:
    down_stomp_leg_id = ""
    down_stomp_entry_rotations.clear()

func end_authored_attack() -> void:
    active_authored_attack = ""
    authored_leg_id = ""
    attack_leg_aim_yaw = 0.0
    attack_entry_rotations.clear()


## Attack interruption by a real leg-break knockdown. The battle
## controller first captures the CURRENT world-space planted sole anchors,
## then this resets all four articulated limbs and BODY to their genuine
## neutral Wait pose. No lingering attack keys may reappear on the next
## Idle/Turn/Approach frame. HEAD stays controller-owned throughout.
func cancel_authored_attack_for_down() -> bool:
    clear_stomp_down_windup()
    if active_authored_attack.is_empty():
        return false
    end_authored_attack()
    blend_from.clear()
    blend_elapsed = BLEND_SECONDS
    current_clip = "Idle"
    elapsed = 0.0
    apply_pose("Wait", 0.0)
    return true


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


## Sample the ACTUAL source keyframe-zero attacking sole at the current
## root pose. Only KICK/SWEEP use this once when their attack starts.
## Do not advance or re-key the user's authored clips; restore every
## sampled joint before the normal animation/IK update.
func initial_authored_sole_height(kind: String, id: String,
        sole_local: Vector3) -> float:
    if not loading_ok or not ATTACK_LEG_BONES.has(id) or (
            kind != "kick" and kind != "sweep"):
        return NAN
    var tracked: Array[String] = ["Body"]
    for value in ATTACK_LEG_BONES[id]:
        tracked.append(str(value))
    var saved: Dictionary = {}
    for name in tracked:
        var uid: String = str(bone_uuid_by_name.get(name, ""))
        if uid.is_empty() or not bones.has(uid):
            return NAN
        var joint: Node3D = bones[uid]
        saved[uid] = joint.quaternion
        if name == "Body":
            joint.quaternion = _authored_key_rotation(
                str(ATTACK_NAMES[kind]), name, 0.0)
        else:
            joint.quaternion = _authored_rotation_for_leg(
                kind, id, tracked.find(name) - 1, 0.0)
    var foot: Node3D = find_child(
        str(ATTACK_LEG_BONES[id][2]), true, false) as Node3D
    var height: float = NAN
    if foot != null:
        height = foot.to_global(sole_local).y
    for uid in saved:
        (bones[uid] as Node3D).quaternion = saved[uid]
    return height


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
    var hold: float = float(frame.get("hold", 0.0))
    var preparation: float = 0.0 if kind == "stomp" else windup
    var clip_time: float = clampf(
        float(frame.get("authored_time", seconds - preparation)),
        0.0, authored_clip_length(kind))
    if kind == "stomp":
        # Freeze the exact last strike key during its 1.50s hit pause.
        # The authored t=1.75 source tail previously animated a knee
        # under the planted toe. Recovery is the normal smooth blend.
        clip_time = minf(clip_time, windup + strike)
    var blend_in: float = clampf(seconds /
        maxf(0.24 if kind == "stomp" else preparation, 0.001), 0.0, 1.0)
    blend_in = blend_in * blend_in * (3.0 - 2.0 * blend_in)
    var retreat: float = clampf((seconds - windup - strike - hold) /
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



## Sample the actual authored extended strike pose at the CURRENT chest
## heading, then rotate the ENTIRE attacking leg about its shoulder.
## The knee/ankle's relative keyframed bends remain unchanged.
func aim_authored_attack_leg(frame: Dictionary, delta: float) -> void:
    var kind: String = str(frame.get("kind", ""))
    var id: String = str(frame.get("id", ""))
    if (kind != "kick" and kind != "sweep") or not ATTACK_LEG_BONES.has(id):
        return
    var aim: Vector3 = frame.get("aim", Vector3.INF)
    if aim == Vector3.INF:
        return
    var joints: Array[Node3D] = []
    var saved: Array[Quaternion] = []
    for name in ATTACK_LEG_BONES[id]:
        var joint: Node3D = find_child(str(name), true, false) as Node3D
        if joint == null:
            return
        joints.append(joint)
        saved.append(joint.quaternion)
    # Do not aim from the folded KICK prepose: it points in a completely
    # different direction to the real contact/extended-foot pose.
    var reference_time: float = 0.625 if kind == "kick" else 0.50
    for slot in range(3):
        joints[slot].quaternion = _authored_rotation_for_leg(
            kind, id, slot, reference_time)
    var from_hip: Vector3 = (
        joints[2].global_position - joints[0].global_position)
    for slot in range(3):
        joints[slot].quaternion = saved[slot]
    var to_player: Vector3 = aim - joints[0].global_position
    from_hip.y = 0.0
    to_player.y = 0.0
    if from_hip.length_squared() < 0.0001 or to_player.length_squared() < 0.0001:
        return
    # Only anticipation acquires a moving player. Retain the last
    # correction throughout the strike and post-hit hold.
    if bool(frame.get("tracking", false)):
        var wanted: float = wrapf(
            atan2(to_player.x, to_player.z)
            - atan2(from_hip.x, from_hip.z), -PI, PI)
        wanted = clampf(wanted,
            -deg_to_rad(ATTACK_LEG_AIM_MAX_DEGREES),
            deg_to_rad(ATTACK_LEG_AIM_MAX_DEGREES))
        attack_leg_aim_yaw = move_toward(attack_leg_aim_yaw, wanted,
            deg_to_rad(ATTACK_LEG_AIM_TURN_DEGREES_PER_SECOND)
            * maxf(delta, 0.0))
    var t: float = float(frame.get("time", 0.0))
    var windup: float = float(frame.get("windup", 0.70))
    var strike: float = float(frame.get("strike", 1.0))
    var hold: float = float(frame.get("hold", 0.0))
    var recovery: float = float(frame.get("recovery", 0.60))
    var incoming: float = smoothstep(0.0, maxf(windup, 0.001), t)
    var outgoing: float = 1.0 - smoothstep(
        windup + strike + hold,
        windup + strike + hold + maxf(recovery, 0.001), t)
    var shoulder: Node3D = joints[0]
    var old_basis: Basis = shoulder.global_basis
    var turn: Basis = Basis(Quaternion(
        Vector3.UP, attack_leg_aim_yaw * incoming * outgoing))
    shoulder.global_basis = (
        turn * old_basis.orthonormalized()).scaled(old_basis.get_scale())


func bone_names() -> Array[String]:
    var result: Array[String] = []
    for raw in bones.values():
        result.append(str((raw as Node3D).name))
    return result
