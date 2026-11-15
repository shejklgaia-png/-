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
# v400: phase weight for the KICK shoulder's world-mirror blend (see
# _authored_rotation_for_leg). Set by apply_authored_attack_pose from
# the frame's phase timings; 0 outside a KICK strike/hold.
var kick_mirror_weight: float = 0.0
# v404: KICK pose blend toward Wait that shortens the extension for
# close targets (see apply_authored_attack_pose). 1.0 = authored.
var kick_reach_factor: float = 1.0
# v405: true while initial_authored_sole_height samples the
# canonical contact pose; disables the v404 Body-damping
# compensation so the sample stays the author's original pose.
var authored_contact_probe_active: bool = false

# Rotational bearing adjustment is applied to the entire attacking leg.
# Authored joint-local rotations are never stretched or rewritten.
const ATTACK_LEG_AIM_MAX_DEGREES: float = 100.0
# v404: fractions of the authored Body track's pitch/roll delta
# kept for KICK/SWEEP (see _authored_body_rotation_for_attack).
# The SWEEP keeps more pitch: its forward pitch is functional and
# holds the sweeping ankle below hip height (v396); at 0.45 the
# ankle rises above the hip mid-arc, at 0.60 it stays ~0.19m below.
const ATTACK_BODY_PITCH_SCALE_KICK: float = 0.45
const ATTACK_BODY_PITCH_SCALE_SWEEP: float = 0.60
const ATTACK_BODY_ROLL_SCALE: float = 0.45
# v404: KICK reach scaling. The authored kick always extends to its
# full hip-to-foot length; a player 2m from the hip is speared
# metres past and held there. The pose is blended toward Wait so
# the foot lands near the aim point instead. Calibration measured
# in-scene on the authored leg: hip-to-foot XZ at the extension
# peak is about 2.30m at factor 0 and grows ~3.2m per factor
# (4.5m at 0.7, then flattens), so the factor inverts that line.
const KICK_REACH_BASE_METERS: float = 2.30
const KICK_REACH_PER_FACTOR: float = 3.2
const KICK_REACH_AIM_MARGIN_METERS: float = 0.4
const KICK_REACH_MIN_FACTOR: float = 0.12
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


## Reflect a world-space rotation across the plane through the rig
## origin with unit normal n: R -> S R S with S = I - 2nn^T.
func _reflect_world_rotation(q: Quaternion, n: Vector3) -> Quaternion:
    var s := Basis(
        Vector3(1.0 - 2.0 * n.x * n.x, -2.0 * n.y * n.x,
            -2.0 * n.z * n.x),
        Vector3(-2.0 * n.x * n.y, 1.0 - 2.0 * n.y * n.y,
            -2.0 * n.z * n.y),
        Vector3(-2.0 * n.x * n.z, -2.0 * n.y * n.z,
            1.0 - 2.0 * n.z * n.z))
    return (s * Basis(q) * s).get_rotation_quaternion()


## World-space mirror of the source leg's chain, built on a supplied
## BODY world rotation; returns every joint's mirrored world rotation.
## The component-flip maps (_mirror_author_delta) conjugate each LOCAL
## quaternion as if the reflection planes were coordinate planes of
## every parent frame; the leg joints' parent frames are themselves
## rotated (Body crouch, folded bind poses), so mapped feet ended up
## rolled/pitched by up to ~100 degrees on non-source legs while joint
## positions still landed correctly. Reflecting each joint's WORLD
## rotation across the anatomical planes through the rig is exact:
## measured, every leg's mirrored KICK foot matches the source leg's
## 9-degree extension tilt.
func _mirrored_chain_worlds(kind: String, target_id: String,
        at: float, body_world: Quaternion) -> Array:
    var world: Basis = global_basis.orthonormalized()
    var source_world: Quaternion = body_world
    var worlds: Array = []
    for slot in range(3):
        var source_local: Quaternion = _authored_key_rotation(
            str(ATTACK_NAMES[kind]),
            str(ATTACK_LEG_BONES["leg_fl"][slot]), at)
        source_world = (source_world * source_local).normalized()
        var reflected: Quaternion = source_world
        if target_id.ends_with("r"):
            reflected = _reflect_world_rotation(
                reflected, world.x.normalized())
        if target_id.begins_with("leg_r"):
            reflected = _reflect_world_rotation(
                reflected, world.z.normalized())
        worlds.append(reflected)
    return worlds


## v400: a KICK joint's local rotation taken from the world-space
## mirror instead of the delta map: build the mirrored world chain
## on the frame's own BODY target and convert the requested joint
## back to a local against its mirrored parent. The component-flip
## retarget error lives in these upper joints, whose parent frames
## are themselves rotated (crouched BODY, folded binds).
func _mirrored_chain_local_for_leg(kind: String, target_id: String,
        bone_slot: int, at: float) -> Quaternion:
    # v404: the mirrored target worlds stay anchored to the FULL
    # Body pose (the pose the chain was authored against), while
    # the conversion back to a local rotation uses the ACTUAL
    # parent world — the damped Body for the shoulder — so the
    # composed chain keeps its authored world orientation under
    # the damped Body.
    var full_world: Quaternion = (
        global_basis.get_rotation_quaternion()
        * _authored_body_full_rotation(kind, target_id, at)
        ).normalized()
    var worlds: Array = _mirrored_chain_worlds(
        kind, target_id, at, full_world)
    var parent_world: Quaternion
    if bone_slot == 0:
        parent_world = (
            global_basis.get_rotation_quaternion()
            * _authored_body_rotation_for_attack(
                kind, target_id, at)).normalized()
    else:
        parent_world = worlds[bone_slot - 1] as Quaternion
    return (parent_world.inverse()
        * (worlds[bone_slot] as Quaternion)).normalized()


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
    # SWEEP is an authored spatial path: all four anatomical limb pivots
    # are reflected copies in BODY-local coordinates, but their WAIT
    # rotations are NOT. In particular the rear WAIT knees have different
    # base pitch/roll. Applying a mirrored WAIT delta to those bones pitches
    # the entire sweeping limb upward. Mirror the absolute source pose for
    # SWEEP, and let the existing blend-in/out connect it to each leg's
    # own WAIT stance. Other attack types retain their original delta map.
    # v400: the KICK shoulder and knee — where the retarget error
    # lives — blend from the delta map to the world-space mirror
    # across the strike (kick_mirror_weight, set from the frame's
    # phases). The delta fold keeps the striking foot planted through
    # the windup, which the mirrored joints cannot do on the rear
    # legs' different bind geometry (their mirrored folds float ~1m
    # and the chassis floor clamp cannot follow); once the leg is
    # airborne and extending, the mirrored joints give the source
    # leg's true orientation. The foot keeps the delta map (its local
    # error is small once the chain above it is right). STOMP keeps
    # the delta map for every joint: its limb is IK-driven to the
    # aim, and only its windup keys come from here.
    if kind == "sweep":
        # v404: the absolute mirrored pose was authored against the
        # full Body pose; compensate at the chain root for the
        # damped Body (see _body_damp_compensation).
        var sweep_mapped: Quaternion = _mirror_author_delta(
            source_action, target_id)
        if bone_slot == 0:
            sweep_mapped = (_body_damp_compensation(
                kind, target_id, at) * sweep_mapped).normalized()
        return sweep_mapped
    var delta: Quaternion = (source_wait.inverse() * source_action).normalized()
    var mapped: Quaternion = (
        dest_wait * _mirror_author_delta(delta, target_id)).normalized()
    if kind == "kick" and bone_slot == 0:
        # v404: same compensation for the delta map, applied at the
        # chain root BEFORE the world-mirror blend below. Both
        # blend ends then produce the authored world orientation
        # under the damped Body (the mirror side anchors its target
        # worlds to the full Body pose, see
        # _mirrored_chain_local_for_leg), so the blend stays on the
        # authored path at every weight.
        mapped = (_body_damp_compensation(kind, target_id, at)
            * mapped).normalized()
    if kind == "kick" and bone_slot <= 1 and kick_mirror_weight > 0.0:
        mapped = mapped.slerp(
            _mirrored_chain_local_for_leg(
                kind, target_id, bone_slot, at),
            kick_mirror_weight).normalized()
    # v406: the KICK reach is NOT shortened here any more. The
    # v404 pose slerp toward Wait rotated the extended leg down
    # through the floor (leg mesh lowest -2.4m at factor 0.5), and
    # the IK's whole-limb floor lift then hoisted the attacking
    # hip by that amount for the whole strike/hold (device
    # report: hip 2.66 -> 4.35m, leg dangling). The rig always
    # returns the full authored pose; bittaran_foot_ik shortens
    # the strike geometrically along the hip->foot ray instead,
    # using kick_reach_factor below.
    return mapped


func _authored_body_rotation_for_attack(kind: String, id: String,
        at: float) -> Quaternion:
    var source: Quaternion = _authored_key_rotation(
        str(ATTACK_NAMES[kind]), "Body", at)
    # The asymmetrical SWEEP BODY roll is part of the left-front
    # attack pose. Reflect it together with the striking leg;
    # otherwise right-side soles are lifted metres above the left.
    # v404: the damping is applied to the SOURCE pose BEFORE the
    # mirror, so mirrored legs stay exact mirrors of the damped
    # source (v396).
    var target: Quaternion = _damp_body_source(kind, source)
    if kind == "sweep":
        target = _mirror_author_delta(target, id)
    return target


# v404: the shared KICK/SWEEP Body track pitches 34.4 degrees and
# rolls 19.7 degrees from Wait at its peak, and the clips END at
# that peak, so the pose is held fully twisted through the whole
# 1.50s KICK hold; stacked with the 45-degree chest tracking yaw,
# the torso reads as corkscrewing (device feedback on v403,
# measured in-scene at pitch 33.5 / roll 21.1 degrees). Keep the
# track's timing, direction and yaw, but damp its pitch/roll delta
# from Wait: KICK pitch/roll to 45 percent, SWEEP pitch to 60
# percent (its forward pitch holds the sweeping ankle below hip
# height, v396; at 45 percent the ankle rises above the hip) and
# roll to 45 percent. A heavy crouch and weight shift remain; the
# excessive twist does not.
func _damp_body_source(kind: String, source: Quaternion) -> Quaternion:
    if kind != "kick" and kind != "sweep":
        return source
    var wait_body: Quaternion = _authored_key_rotation(
        "Wait", "Body", 0.0)
    var delta: Quaternion = (
        wait_body.inverse() * source).normalized()
    var e: Vector3 = delta.get_euler()
    e.x *= ATTACK_BODY_PITCH_SCALE_KICK if kind == "kick" \
        else ATTACK_BODY_PITCH_SCALE_SWEEP
    e.z *= ATTACK_BODY_ROLL_SCALE
    return (wait_body * Basis.from_euler(e)
        .get_rotation_quaternion()).normalized()


# v404: the attack Body rotation WITHOUT the pitch/roll damping
# (source pose, mirrored for SWEEP): the reference the attacking
# leg's locals were authored against.
func _authored_body_full_rotation(kind: String, id: String,
        at: float) -> Quaternion:
    var source: Quaternion = _authored_key_rotation(
        str(ATTACK_NAMES[kind]), "Body", at)
    if kind == "sweep":
        return _mirror_author_delta(source, id)
    return source


# v404: B_damped^-1 * B_full for an attack Body pose. The attacking
# leg's locals were authored against the FULL Body pose, so with
# the Body damped their world orientation tilts by the removed
# pitch (the v400 extension foot tilt went from 9 to 31 degrees and
# the windup fold sole floated). _authored_rotation_for_leg
# premultiplies the chain-root local of the delta-mapped and
# absolute-mirrored families with this compensation, and the KICK
# world-mirror family anchors its target worlds to the full pose
# instead; both restore the chain's authored world orientation
# while the torso itself stays damped. The shoulder aim samples
# the same rotations, so the v403 direction correction is
# unaffected. While the IK's canonical contact sample is being
# taken (initial_authored_sole_height), the compensation is
# disabled: that sample must describe the author's original pose,
# not the damped in-game one (v405).
func _body_damp_compensation(kind: String, id: String,
        at: float) -> Quaternion:
    if authored_contact_probe_active:
        return Quaternion.IDENTITY
    if kind != "kick" and kind != "sweep":
        return Quaternion.IDENTITY
    var source: Quaternion = _authored_key_rotation(
        str(ATTACK_NAMES[kind]), "Body", at)
    var full: Quaternion = _authored_body_full_rotation(kind, id, at)
    var damped: Quaternion = _damp_body_source(kind, source)
    if kind == "sweep":
        damped = _mirror_author_delta(damped, id)
    return (damped.inverse() * full).normalized()


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
    # The keyframe-zero sample is the grounded fold: always the pure
    # delta map, never a leftover strike-phase mirror weight.
    # v405: the sample is the author's canonical pose — the FULL
    # Body track with no v404 damping or leg compensation. The IK's
    # actor offset (initial_attack_contact_height_world) is
    # calibrated to exactly this sample; when v404's damping first
    # leaked into it through the calls below, the offset dragged
    # the chassis to the floor during attacks (device report:
    # chassis bone at 0.06m instead of the authored ~0.57m crouch).
    var saved_mirror_weight: float = kick_mirror_weight
    kick_mirror_weight = 0.0
    var saved_probe: bool = authored_contact_probe_active
    authored_contact_probe_active = true
    var saved_reach_factor: float = kick_reach_factor
    kick_reach_factor = 1.0
    var saved: Dictionary = {}
    for name in tracked:
        var uid: String = str(bone_uuid_by_name.get(name, ""))
        if uid.is_empty() or not bones.has(uid):
            return NAN
        var joint: Node3D = bones[uid]
        saved[uid] = joint.quaternion
        if name == "Body":
            joint.quaternion = _authored_body_full_rotation(
                kind, id, 0.0)
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
    kick_mirror_weight = saved_mirror_weight
    kick_reach_factor = saved_reach_factor
    authored_contact_probe_active = saved_probe
    return height


## v407: sample ONE pure KICK chain (mirror weight 0 or 1) at a clip
## time and report the attacking leg's sole position, foot rotation
## and knee position in world space; the joints are restored before
## returning. The foot IK blends the two chains in FOOT space
## during the strike's mirror ramp: blending the joint rotations
## themselves swings the foot over the top of the body like a whip
## whenever the chains disagree (measured on leg_rl: the two folds'
## soles sit 4.2m apart and the slerp arc peaks 1.96m above the
## hip), because the shortest rotation between the two shoulder
## orientations passes overhead. A straight foot-space blend keeps
## the strike in its natural plane.
func sample_authored_kick_sole(id: String, at: float,
        mirror_weight: float, sole_local: Vector3) -> Dictionary:
    if not loading_ok or not ATTACK_LEG_BONES.has(id):
        return {}
    var saved_mirror_weight: float = kick_mirror_weight
    kick_mirror_weight = mirror_weight
    var joints: Array[Node3D] = []
    var saved: Array[Quaternion] = []
    for name in ATTACK_LEG_BONES[id]:
        var uid: String = str(bone_uuid_by_name.get(str(name), ""))
        if uid.is_empty() or not bones.has(uid):
            kick_mirror_weight = saved_mirror_weight
            return {}
        var joint: Node3D = bones[uid]
        joints.append(joint)
        saved.append(joint.quaternion)
    for slot in range(3):
        joints[slot].quaternion = _authored_rotation_for_leg(
            "kick", id, slot, at)
    var result: Dictionary = {
        "sole": joints[2].to_global(sole_local),
        "rotation": joints[2].global_basis.get_rotation_quaternion(),
        "knee": joints[1].global_position,
    }
    for slot in range(3):
        joints[slot].quaternion = saved[slot]
    kick_mirror_weight = saved_mirror_weight
    return result


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
    # v400: the KICK shoulder blends to its world-mirrored rotation
    # over the first 0.30s of the strike (the leg is airborne by then
    # and reaches full extension early in the strike, so the blend
    # must complete before it), holds it, and blends back over the
    # first 0.30s of recovery.
    kick_mirror_weight = 0.0
    if kind == "kick":
        var ramp_in: float = clampf(
            (seconds - windup) / maxf(minf(strike, 0.30), 0.001),
            0.0, 1.0)
        var ramp_out: float = clampf(
            (seconds - windup - strike - hold)
            / maxf(minf(recovery, 0.30), 0.001), 0.0, 1.0)
        kick_mirror_weight = (
            (ramp_in * ramp_in * (3.0 - 2.0 * ramp_in))
            * (1.0 - ramp_out * ramp_out * (3.0 - 2.0 * ramp_out)))
    # v404: shorten the KICK for close targets. The factor follows
    # the (windup-tracked, then locked) aim point's horizontal
    # distance from the attacking hip, so the foot lands near the
    # player instead of spearing metres past them and holding there
    # (device feedback on v403, front-right leg in front of the
    # boss: foot 3.5m past the player, toe tip 5.2m past). The
    # factor is consumed by bittaran_foot_ik (v406 geometric
    # shortening); the pose itself stays fully authored.
    kick_reach_factor = 1.0
    if kind == "kick":
        var aim: Vector3 = frame.get("aim", Vector3.INF)
        var hip_uid: String = str(bone_uuid_by_name.get(
            str(ATTACK_LEG_BONES[id][0]), ""))
        if aim != Vector3.INF and bones.has(hip_uid):
            var hip_pos: Vector3 = (
                bones[hip_uid] as Node3D).global_position
            var flat: Vector2 = Vector2(
                aim.x - hip_pos.x, aim.z - hip_pos.z)
            kick_reach_factor = clampf(
                (flat.length() + KICK_REACH_AIM_MARGIN_METERS
                    - KICK_REACH_BASE_METERS)
                / KICK_REACH_PER_FACTOR,
                KICK_REACH_MIN_FACTOR, 1.0)
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
            target_rotation = _authored_body_rotation_for_attack(
                kind, id, clip_time)
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
    var t: float = float(frame.get("time", 0.0))
    var windup: float = float(frame.get("windup", 0.70))
    var strike: float = float(frame.get("strike", 1.0))
    var hold: float = float(frame.get("hold", 0.0))
    var recovery: float = float(frame.get("recovery", 0.60))
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
    var saved_mirror_weight: float = kick_mirror_weight
    if kind == "kick":
        if t >= windup:
            # v403: during the strike and hold, sample the pose the leg
            # actually has NOW. The retargeted KICK clips rotate their
            # hip->foot direction by 50-100 degrees while extending on
            # every leg except the authored leg_fl (measured: fr -56,
            # rl -97, rr +57 degrees of drift between strike start and
            # full extension), so a yaw fitted to the fixed extended
            # reference cannot hold the kick on target: by full
            # extension it pointed up to 91 degrees away from the
            # player. Sampling the current pose lets the yaw update
            # below cancel that internal rotation as it happens. The
            # aim POINT stays the windup-locked one (the director stops
            # tracking at release), so this is drift cancellation, not
            # homing.
            reference_time = clampf(
                float(frame.get("authored_time", t - windup)),
                0.0, authored_clip_length(kind))
        else:
            # Windup keeps the predictive extended-pose sample, but the
            # sample must use the strike's world-mirror weight (1.0):
            # at weight 0 the reference direction itself is off by up
            # to 18 degrees on the right legs, which showed up as a
            # fixed direction error already at strike start.
            kick_mirror_weight = 1.0
    for slot in range(3):
        joints[slot].quaternion = _authored_rotation_for_leg(
            kind, id, slot, reference_time)
    var from_hip: Vector3 = (
        joints[2].global_position - joints[0].global_position)
    for slot in range(3):
        joints[slot].quaternion = saved[slot]
    kick_mirror_weight = saved_mirror_weight
    var to_player: Vector3 = aim - joints[0].global_position
    from_hip.y = 0.0
    to_player.y = 0.0
    if from_hip.length_squared() < 0.0001 or to_player.length_squared() < 0.0001:
        return
    # Only anticipation acquires a moving player. Retain the last
    # correction throughout the strike and post-hit hold. v403: KICK
    # keeps updating through the strike and hold as well, but against
    # the windup-locked aim point and the CURRENT pose direction, which
    # cancels the retargeted clips' internal direction drift without
    # re-aiming at the moving player.
    var may_aim: bool = bool(frame.get("tracking", false)) or (
        kind == "kick" and t <= windup + strike + hold)
    if may_aim:
        var wanted: float = wrapf(
            atan2(to_player.x, to_player.z)
            - atan2(from_hip.x, from_hip.z), -PI, PI)
        wanted = clampf(wanted,
            -deg_to_rad(ATTACK_LEG_AIM_MAX_DEGREES),
            deg_to_rad(ATTACK_LEG_AIM_MAX_DEGREES))
        attack_leg_aim_yaw = move_toward(attack_leg_aim_yaw, wanted,
            deg_to_rad(ATTACK_LEG_AIM_TURN_DEGREES_PER_SECOND)
            * maxf(delta, 0.0))
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
