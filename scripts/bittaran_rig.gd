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
const ATTACK_LEG_AIM_MAX_DEGREES: float = 75.0
# v409: both aim clamps are now set to the largest bearing a leg
# actually needs in the geometries the game selects, measured
# in-scene. SWEEP aim peaked at ~53 degrees on the
# front legs once the chest turns the hip corner toward the
# player (v409 battle change); the rear-side cases that used to
# demand ~88 degrees were compensating for the chest twisting
# the wrong way and now sit far lower. The KICK plays a
# foot-space trajectory that IK re-solves (v408), so its bearing
# adjustment is not bounded by a physical shoulder stop, but it
# gets the same treatment: same-side natural demand peaks at
# ~71 degrees (rear leg, player dead behind), so the clamp is 85.
# Forced cross-side cases (a rear leg aimed across the body)
# saturate at the clamp and land somewhat off instead of
# wrapping the leg around the body.
const ATTACK_LEG_AIM_MAX_DEGREES_KICK: float = 85.0
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
    kick_mirror_weight = 0.0
    kick_reach_factor = 1.0
    authored_contact_probe_active = false
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
    # v410: the mirror itself is now the exact world-space
    # reflection; the old local component flip deviated from
    # leg_fl's true mirror by up to 34 degrees on the single-flip
    # legs (device request: re-mirror the sweep torso tilt cleanly
    # from the left-front motion).
    # v411: what is mirrored is the Wait-relative MOTION (delta),
    # not the absolute pose; see _mirror_body_delta_for_attack.
    # v412: the mirror planes follow the leg's quadrant. SWEEP
    # mirrors left-right for the right legs and front-back for
    # the rear legs, so a rear sweep plays the same-side front
    # sweep's tilt reversed front-to-back (device request: rear
    # attacks reverse the front legs' torso tilt front-to-back).
    # KICK/STOMP front legs keep the unmirrored damped track --
    # mirroring KICK left-right measurably broke leg_fr's
    # sampled trajectory (v411 experiment; v400/v406/v408/v409
    # checks) -- while their rear legs get the front-back
    # reflection only, which the KICK trajectory sampler and
    # contact probe read consistently through this same target.
    var target: Quaternion = _damp_body_source(kind, source)
    if kind == "sweep":
        target = _mirror_body_delta_for_attack(target, id,
            id.ends_with("r"), id.begins_with("leg_r"))
    elif id.begins_with("leg_r"):
        target = _mirror_body_delta_for_attack(target, id,
            false, true)
    return target


## v411: mirror a (damped) leg_fl Body rotation's Wait-relative
## MOTION for SWEEP: take the delta from the Wait pose into
## world space, reflect THAT across the rig's left-right plane
## and re-anchor it on the Wait pose. Reflection conjugation
## preserves the rotation angle, so every leg plays leg_fl's
## tilt motion at exactly leg_fl's magnitude, with only its
## direction mirrored -- the same treatment the leg chains get
## from their delta map (dest_wait * mirrored delta).
## v410 mirrored the ABSOLUTE pose instead. That is the exact
## mirror image of the pose, but the boss's rest pose is not
## front-back symmetric (front hips sit higher than rear hips),
## so the Wait-relative motion the rear legs actually played
## was inflated: leg_rl's Body target delta measured 48 degrees
## against leg_fl's 23, and stacked with the chest tracking yaw
## it wound the torso to 94 degrees in-scene during leg_rl
## sweeps (device report: rear-leg attacks twist abnormally,
## worst in the windup). Mirroring the delta keeps the played
## motion at 23 degrees on every leg.
## v412: the caller chooses the reflection planes by the leg's
## quadrant (see _authored_body_rotation_for_attack). v411
## shipped left-right only: reflecting the delta front-back as
## well inverts the crouch pitch for the rear legs, which
## drops the rear hip ~0.6m; the sampled sweep pose then sits
## ~2.2m under the floor and the strike entry's blended knee
## pole crossed the hip->sole axis, snapping leg_rl's knee
## through the floor for a tick (measured -0.214m). The user
## then explicitly asked for the front-back reversal on rear
## attacks, so v412 reflects it and fixes the entry defect at
## its root instead: bittaran_foot_ik now blends the entry
## pole by direction around the hip, so the projected pole
## can no longer cross the axis mid-blend.
func _mirror_body_delta_for_attack(local_rotation: Quaternion,
        id: String, mirror_x: bool, mirror_z: bool) -> Quaternion:
    if not mirror_x and not mirror_z:
        return local_rotation
    var wait_body: Quaternion = _authored_key_rotation(
        "Wait", "Body", 0.0)
    var delta: Quaternion = (
        wait_body.inverse() * local_rotation).normalized()
    var rig_q: Quaternion = global_basis.get_rotation_quaternion()
    var world: Basis = global_basis.orthonormalized()
    var mirrored: Quaternion = (
        rig_q * delta * rig_q.inverse()).normalized()
    if mirror_x:
        mirrored = _reflect_world_rotation(
            mirrored, world.x.normalized())
    if mirror_z:
        mirrored = _reflect_world_rotation(
            mirrored, world.z.normalized())
    var local_delta: Quaternion = (
        rig_q.inverse() * mirrored * rig_q).normalized()
    return (wait_body * local_delta).normalized()


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
    var full: Quaternion = _authored_body_full_rotation(kind, id, at)
    # v410: the played (damped) side is whatever
    # _authored_body_rotation_for_attack returns, so the SWEEP
    # compensation absorbs the world-space Body mirror exactly
    # like it absorbed the v404 damping: the attacking leg's world
    # orientation stays the authored one (full pose), only the
    # torso's played tilt changes.
    # v411: same for the SWEEP delta mirror: the compensation
    # absorbs whatever the played side does, so the leg chains
    # are unaffected by the mirror change.
    var damped: Quaternion = _authored_body_rotation_for_attack(
        kind, id, at)
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


## v409: the contact height of the KICK trajectory the foot IK
## actually plays for leg `id` (see sample_authored_kick_source):
## the Body joint is set to the attack's own (damped) rotation —
## the pose the live sampling runs under — the source trajectory
## is sampled at clip time 0, and the attacking leg's sole point
## height is returned. The IK's actor offset is calibrated to
## this, so the reflected fold lands on the floor for every leg
## (the per-leg delta folds sit up to 1.15m apart and are no
## longer what is played). The fold's MESH grounding is finished
## in the IK's trajectory block (its clearance compensation):
## calibrating the offset itself to the mesh instead proved
## state-sensitive enough to collapse the chassis at close
## range (leg_fr min chassis y -0.01, measured).
## v412: the Body pose the KICK trajectory sampler and the
## contact probe sample under: the damped source track with NO
## per-leg mirror. Rear KICKs play the front-back-reversed
## Body tilt in-scene (device request), but the trajectory is
## extracted from leg_fl's chain hip-relatively and re-anchored
## at the live hip; sampling it under the reversed pose routes
## the reversal through _body_damp_compensation, which rotates
## the extracted chain at the shoulder and distorts it
## (measured on leg_rl: ankle profile off by 1.68m, extension
## foot tilt 41 degrees, trajectory goals pushed past the IK
## reach clamp). The sampler keeps the front form; the played
## chassis reversal still tilts the re-anchored leg assembly.
func _authored_body_rotation_for_kick_sampling(at: float) -> Quaternion:
    var source: Quaternion = _authored_key_rotation(
        str(ATTACK_NAMES["kick"]), "Body", at)
    return _damp_body_source("kick", source)


func kick_source_contact_height(id: String,
        sole_local: Vector3) -> float:
    if not loading_ok or not ATTACK_LEG_BONES.has(id):
        return NAN
    var body_uid: String = str(bone_uuid_by_name.get("Body", ""))
    if body_uid.is_empty() or not bones.has(body_uid):
        return NAN
    var body_joint: Node3D = bones[body_uid]
    var saved_body: Quaternion = body_joint.quaternion
    body_joint.quaternion = (
        _authored_body_rotation_for_kick_sampling(0.0))
    var src: Dictionary = sample_authored_kick_source(
        id, 0.0, sole_local)
    body_joint.quaternion = saved_body
    if src.is_empty():
        return NAN
    return (src["sole"] as Vector3).y


## v409: sample the KICK's source leg (leg_fl) authored chain at
## a clip time and reflect it across the rig's anatomical planes
## for target leg `id`; returns the sole world position, the
## foot's world rotation and the knee world position of the
## ORIGINAL motion as the target leg should reproduce it; the
## source joints are restored before returning. Joint-space
## retargets (the delta map and the world-mirror chain) preserve
## the source leg's orientations but not its foot trajectory on
## each leg's own bind geometry — measured in-scene, leg_fr's
## strike deviated from the mirrored source trajectory by up to
## 1.75m mid-strike and 0.36m at hold, its windup fold by 1.2m —
## so the foot IK now plays this reflected trajectory directly
## for every leg (device request: reproduce the original motion,
## the foot extending low along the ground, on all legs). The
## reflection of a point p across the plane through the rig
## origin with unit normal n is p - 2((p - origin) . n)n; the
## rotation reflection reuses _reflect_world_rotation.
func sample_authored_kick_source(id: String, at: float,
        source_sole_local: Vector3) -> Dictionary:
    if not loading_ok or not ATTACK_LEG_BONES.has(id):
        return {}
    var saved_mirror_weight: float = kick_mirror_weight
    kick_mirror_weight = 0.0
    var joints: Array[Node3D] = []
    var saved: Array[Transform3D] = []
    for name in ATTACK_LEG_BONES["leg_fl"]:
        var uid: String = str(bone_uuid_by_name.get(str(name), ""))
        if uid.is_empty() or not bones.has(uid):
            kick_mirror_weight = saved_mirror_weight
            return {}
        var joint: Node3D = bones[uid]
        joints.append(joint)
        saved.append(joint.transform)
        # v415: the front-left SOURCE leg is also an IK support for
        # the other three attacks. Earlier legs have already been
        # solved in this very frame, and IK can translate their local
        # pivots. Rotations-only restoration sampled a STRETCHED
        # source skeleton; its foot trajectory then changed with every
        # preceding kick/stance. Sample the immutable Blockbench bind
        # positions and restore the complete live transform afterward.
        joint.position = bind_positions[uid]
    # v409: sample under the authored Body track WITHOUT the
    # battle's chest yaw. The IK post-multiplies the chest yaw
    # (up to +-140 degrees for a rear leg tracking a player
    # behind) onto this same Body bone every tick; a trajectory
    # composed under it is spun by that yaw, and the aim then
    # has to undo the spin on top of the mirror's own diagonal
    # (leg_rl's demand passed even a 130-degree clamp, leaving
    # 56 degrees of travel error). The trajectory is a
    # hip-relative shape: composing it under the track-only
    # Body and anchoring it at the live hip keeps the shape
    # identical while the chest still carries the body.
    var body_node: Node3D = joints[0].get_parent() as Node3D
    var saved_body: Quaternion = Quaternion.IDENTITY
    if body_node != null:
        saved_body = body_node.quaternion
        body_node.quaternion = (
            _authored_body_rotation_for_kick_sampling(at))
    for slot in range(3):
        joints[slot].quaternion = _authored_rotation_for_leg(
            "kick", "leg_fl", slot, at)
    var rotation: Quaternion = (
        joints[2].global_basis.get_rotation_quaternion())
    var knee: Vector3 = joints[1].global_position
    var foot: Vector3 = joints[2].global_position
    var sole: Vector3 = joints[2].to_global(source_sole_local)
    var source_hip: Vector3 = joints[0].global_position
    for slot in range(3):
        joints[slot].transform = saved[slot]
    if body_node != null:
        body_node.quaternion = saved_body
    kick_mirror_weight = saved_mirror_weight
    # NOTE: leg_fl also goes through the transfer below (with an
    # identity flip): the sampled points are composed in the
    # track-only state, so they must be re-anchored at the LIVE
    # target hip like every other leg's. Returning the raw
    # sample for leg_fl left its goal offset by the chest yaw's
    # displacement of the hip (fold radius 1.70 vs the source's
    # 0.94, measured).
    # Transfer the trajectory HIP-RELATIVELY: the rig is not
    # front-back symmetric (rear hips sit lower and further back
    # than the front pair), so reflecting positions across the
    # rig's planes puts the rear goals metres from the rear hips'
    # workspace. Express each sampled point relative to the
    # source hip, mirror the relative vector in the rig frame,
    # and place it at the target leg's own hip; the shape, the
    # height profile above the hip and the reach are the source
    # leg's, on the target leg's own skeleton. The foot ROTATION
    # still plane-reflects (orientations mirror exactly, v400).
    var target_hip: Vector3 = Vector3.INF
    var target_uid: String = str(bone_uuid_by_name.get(
        str(ATTACK_LEG_BONES[id][0]), ""))
    if not target_uid.is_empty() and bones.has(target_uid):
        target_hip = (bones[target_uid] as Node3D).global_position
    if target_hip == Vector3.INF:
        return {}
    # v409: the points mirror in the rig-root frame (the boss's
    # anatomical planes). The Body bone's own frame is bind-
    # tilted ~28 degrees off them, so mirroring there crossed
    # the trajectory (profile error ~1.4m, foot tilt 35.8
    # degrees); the rig frame reproduced the source profile to
    # 0.13m on leg_fr. The aim demand this leaves on the rear
    # legs is handled by the wider KICK aim clamp in
    # aim_authored_attack_leg.
    var world: Basis = global_basis.orthonormalized()
    var point_frame: Basis = world
    var inv_point: Basis = point_frame.inverse()
    var flip := Vector3(
        -1.0 if id.ends_with("r") else 1.0, 1.0,
        -1.0 if id.begins_with("leg_r") else 1.0)
    var rel_knee: Vector3 = inv_point * (knee - source_hip)
    var rel_foot: Vector3 = inv_point * (foot - source_hip)
    var rel_sole: Vector3 = inv_point * (sole - source_hip)
    knee = target_hip + point_frame * (rel_knee * flip)
    foot = target_hip + point_frame * (rel_foot * flip)
    sole = target_hip + point_frame * (rel_sole * flip)
    if flip.x < 0.0:
        rotation = _reflect_world_rotation(
            rotation, world.x.normalized())
    if flip.z < 0.0:
        rotation = _reflect_world_rotation(
            rotation, world.z.normalized())
    return {"rotation": rotation, "knee": knee, "foot": foot,
        "sole": sole}


## Lowest mesh corner under a joint subtree, measured exactly
## like bittaran_foot_ik's _leg_mesh_lowest_y (direct mesh
## children of every descendant joint).
func _subtree_mesh_lowest_y(joint: Node3D) -> float:
    var lowest: float = INF
    for child in joint.get_children():
        if child is MeshInstance3D:
            var piece: MeshInstance3D = child as MeshInstance3D
            if piece.mesh == null:
                continue
            var box: AABB = piece.mesh.get_aabb()
            for corner in range(8):
                lowest = minf(lowest,
                    piece.to_global(box.get_endpoint(corner)).y)
        elif child is Node3D:
            lowest = minf(lowest,
                _subtree_mesh_lowest_y(child as Node3D))
    return lowest


## v410: sample the attacking leg's OWN authored SWEEP pose at a
## clip time (its joints are already retargeted per leg by
## _authored_rotation_for_leg), composed under the authored Body
## track only (no battle chest yaw, like sample_authored_kick_
## source), returning the sole/foot/knee/rotation and the hip
## they were composed from. bittaran_foot_ik blends the strike
## entry from the planted basic stance to this pose over the
## first 0.36s of the strike: during that window the DISPLAYED
## leg is still slerping from its entry locals, whose raw foot
## sits metres under the floor under the fully turned Body, so
## the entry goal must come from a clean sample, re-anchored at
## the live hip by the caller.
func sample_authored_sweep_pose(id: String, at: float,
        sole_local: Vector3) -> Dictionary:
    if not loading_ok or not ATTACK_LEG_BONES.has(id):
        return {}
    var joints: Array[Node3D] = []
    var saved: Array[Transform3D] = []
    for name in ATTACK_LEG_BONES[id]:
        var uid: String = str(bone_uuid_by_name.get(str(name), ""))
        if uid.is_empty() or not bones.has(uid):
            return {}
        var joint: Node3D = bones[uid]
        joints.append(joint)
        saved.append(joint.transform)
        joint.position = bind_positions[uid]
    var body_node: Node3D = joints[0].get_parent() as Node3D
    var saved_body: Quaternion = Quaternion.IDENTITY
    if body_node != null:
        saved_body = body_node.quaternion
        body_node.quaternion = _authored_body_rotation_for_attack(
            "sweep", id, at)
    for slot in range(3):
        joints[slot].quaternion = _authored_rotation_for_leg(
            "sweep", id, slot, at)
    var result: Dictionary = {
        "rotation": joints[2].global_basis.get_rotation_quaternion(),
        "knee": joints[1].global_position,
        "foot": joints[2].global_position,
        "sole": joints[2].to_global(sole_local),
        "hip": joints[0].global_position,
        # The sampled pose's own floor deficit basis: the IK's
        # entry blend applies the freeze branch's whole-limb lift
        # from this value, since the DISPLAYED leg during the
        # entry is the entry snapshot, not this pose.
        "mesh_lowest": _subtree_mesh_lowest_y(joints[0]),
    }
    for slot in range(3):
        joints[slot].transform = saved[slot]
    if body_node != null:
        body_node.quaternion = saved_body
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
    # v410: the attacking LEG no longer blends to the clip during
    # the KICK/SWEEP preparation: it stays at the basic stance
    # (bittaran_foot_ik plants it on its anchor for the whole
    # windup; device request: the striking leg also returns to the
    # basic stance position before the attack). Its authored
    # motion blends in over the first part of the strike instead:
    # KICK's source clip holds its fold for the first ~0.25s of
    # clip time, so the blend completes inside that hold; SWEEP's
    # completes over the clip's full-speed outbound lead-in
    # (clip 0..0.36), before the slowed final outbound segment.
    # The SWEEP ramp must match bittaran_foot_ik's
    # SWEEP_ENTRY_BLEND_SECONDS, over which the IK blends the
    # solved entry to the sampled authored pose.
    # The Body keeps the original timing (the low crouch IS the
    # preparation), and STOMP is unchanged (its clip contains its
    # own windup from the Wait pose).
    var leg_weight: float = weight
    if kind == "kick" or kind == "sweep":
        var leg_ramp: float = 0.25 if kind == "kick" else 0.36
        var leg_in: float = clampf(
            (seconds - windup) / leg_ramp, 0.0, 1.0)
        leg_in = leg_in * leg_in * (3.0 - 2.0 * leg_in)
        leg_weight = leg_in * blend_out
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
        # v410: KICK/SWEEP legs use leg_weight (held at the entry
        # pose through the preparation, blended in over the first
        # part of the strike); Body and STOMP use weight.
        var applied_weight: float = (
            weight if bone_name == "Body" else leg_weight)
        node.quaternion = entry.slerp(
            target_rotation, applied_weight).slerp(
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
    var from_hip: Vector3
    if kind == "kick":
        # v409: the attacking leg plays the reflected source
        # trajectory in foot space, so the reference direction is
        # the trajectory's hip->foot direction, not the joint
        # retarget's: the two differ by tens of degrees on
        # non-source legs, and a yaw fitted to the retarget
        # rotated the played trajectory far off the aim point
        # (measured: metres of trajectory deviation). The aim
        # point, clamp and slew are unchanged.
        var traj: Dictionary = sample_authored_kick_source(
            id, reference_time, Vector3.ZERO)
        if traj.is_empty():
            kick_mirror_weight = saved_mirror_weight
            return
        from_hip = (traj["foot"] as Vector3) \
            - joints[0].global_position
    else:
        for slot in range(3):
            joints[slot].quaternion = _authored_rotation_for_leg(
                kind, id, slot, reference_time)
        from_hip = (
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
        var max_degrees: float = (
            ATTACK_LEG_AIM_MAX_DEGREES_KICK if kind == "kick"
            else ATTACK_LEG_AIM_MAX_DEGREES)
        wanted = clampf(wanted,
            -deg_to_rad(max_degrees),
            deg_to_rad(max_degrees))
        attack_leg_aim_yaw = move_toward(attack_leg_aim_yaw, wanted,
            deg_to_rad(ATTACK_LEG_AIM_TURN_DEGREES_PER_SECOND)
            * maxf(delta, 0.0))
    var incoming: float = smoothstep(0.0, maxf(windup, 0.001), t)
    var outgoing: float = 1.0 - smoothstep(
        windup + strike + hold,
        windup + strike + hold + maxf(recovery, 0.001), t)
    # v412: while the leg is planted through the windup (v410), do
    # not rotate its shoulder. The IK re-poses the leg from that
    # rotated basis every tick and _solve's shortest-arc alignment
    # inherits the roll, which accumulated into visible mesh
    # twist over the windup (measured: leg_rr's shin rotated
    # +105 degrees about its own axis during one windup, leg_fl's
    # thigh built up ~43 degrees and dumped it in one tick when
    # the bend plane flipped). The yaw VALUE above keeps slewing
    # so the strike starts aimed; the application ramps in over
    # the strike entry instead, over the same window the IK
    # blends the entry (0.25s kick / 0.36s sweep), so the
    # sweep's played pose yaws in with its entry rather than
    # snapping at the strike's first tick.
    var plant_ramp: float = 1.0
    if t < windup:
        plant_ramp = 0.0
    else:
        var entry_ramp: float = 0.25 if kind == "kick" else 0.36
        plant_ramp = smoothstep(0.0, entry_ramp, t - windup)
    var shoulder: Node3D = joints[0]
    var old_basis: Basis = shoulder.global_basis
    var turn: Basis = Basis(Quaternion(
        Vector3.UP, attack_leg_aim_yaw * incoming * outgoing
        * plant_ramp))
    shoulder.global_basis = (
        turn * old_basis.orthonormalized()).scaled(old_basis.get_scale())


func bone_names() -> Array[String]:
    var result: Array[String] = []
    for raw in bones.values():
        result.append(str((raw as Node3D).name))
    return result
