extends Node3D
## Bittaran quadruped: independent Blockbench bone rig, authored stance and
## looping IDLE/TURN/APPROACH clips. Player's SeraRig is never modified.
const SOURCE_PATH: String = "res://models/bosses/Bittaran.bbmodel"
const EMBEDDED = preload("res://assets/bittaran_data.gd")
const GROUND_CONTACTS = preload("res://assets/bittaran_ground_contacts.gd")
# Shared source timing toggle; restoring the v461 preset also restores
# the Wait->Idle handoff duration without a separate file edit.
const BittaranAttackTimings = preload("res://scripts/bittaran_attacks.gd")
# Authored contact windows are diagnostic/reference data ONLY.
# Rendering never moves individual meshes out of their skeleton hierarchy.
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
var mesh_nodes_by_uuid: Dictionary = {}
var mesh_base_positions_by_uuid: Dictionary = {}
var mesh_vertices_by_uuid: Dictionary = {}
var ground_mesh_observations: Dictionary = {}
var ground_last_clip: String = ""
var ground_last_time: float = 0.0
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
# v418: KICK's original Blockbench reach is never scaled by player
# distance. Aim yaw only rotates the trajectory's direction; hit
# detection, not a reach factor, decides whether it connects.
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
    "stomp": "踏みつけ_L", "kick": "弾き", "sweep": "なぎ払い"
}
## v450: authored source attack clips, including mirrored right rear attacks.
## Rear legs have no authored KICK; do not synthesize that animation.
const SOURCE_ATTACK_CLIPS: Dictionary = {
    "leg_fl": {
        "stomp": "踏みつけ_L", "kick": "弾き", "sweep": "なぎ払い"},
    "leg_fr": {
        "stomp": "踏みつけ_R", "kick": "弾き_R", "sweep": "なぎ払い_R"},
    "leg_rl": {
        "stomp": "後足踏みつけ_L", "sweep": "後足なぎ払い_L"},
    "leg_rr": {
        "stomp": "後足踏みつけ_R", "sweep": "後足なぎ払い_R"}
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
# v435: never blend a previously IK-solved upper leg quaternion into
# the NEXT Blockbench source key; that would treat solver output as
# authored animation and visibly wrench the limbs at gait changes.
var source_ground_ik_active: bool = false
# v443: capture the IK-grounded limb right as BODY returns to Wait.
# Afterward it glides directly to Wait. No intermediate windup pose.
var source_return_leg_start_pose: Dictionary = {}
# v446: store actual IK-corrected limb locals AFTER the game's
# final skeletal solver has run. BittaranBattle.set_motion("Idle")
# runs before the next frame and otherwise overwrites these with
# ungrounded Idle poses, causing the visible Body->leg snap.
var source_last_body_ik_solved_pose: Dictionary = {}
# v451: capture the actual post-IK grounded pose on idle frames,
# before set_motion(Idle) overwrites those skeletal joints.
# Only rear authored attacks use this to avoid an entry-frame pop.
var source_last_grounded_idle_pose: Dictionary = {}
# v459: the return finishes at exact Wait, but the standard Idle clip
# has an independent phase clock. Crossfade its FIRST 0.30s from the
# final displayed Wait locals instead of sampling Idle immediately.
const SOURCE_WAIT_TO_IDLE_BLEND_SECONDS: float = 0.30
var source_wait_to_idle_blend_from: Dictionary = {}
var source_wait_to_idle_blend_elapsed: float = 0.0
var source_rear_entry_start_pose: Dictionary = {}
var source_rear_entry_id: String = ""
var source_rear_entry_kind: String = ""
# v452: source-only attacks steer the actual hip corner, not the root.
# BODY aim and attack-shoulder additive yaw are sampled independently.
const SOURCE_HIP_AIM_MAX_DEGREES: float = 30.0
const SOURCE_SHOULDER_AIM_MAX_DEGREES: float = 30.0
const SOURCE_BODY_AIM_RATE_DEGREES: float = 100.0
const SOURCE_SHOULDER_AIM_RATE_DEGREES: float = 150.0
const SOURCE_BODY_AIM_TRANSLATION_MAX: float = 1.0
const SOURCE_BODY_AIM_TRANSLATION_SPEED: float = 2.5
const SOURCE_STOMP_APEX_DROP_METERS: float = 0.035
const SOURCE_STOMP_MIN_LIFT_METERS: float = 0.20
var source_aim_id: String = ""
var source_aim_kind: String = ""
var source_aim_body_yaw: float = 0.0
var source_aim_shoulder_yaw: float = 0.0
var source_aim_body_offset: Vector3 = Vector3.ZERO
var source_aim_future_hip_local: Vector3 = Vector3.ZERO
var source_aim_stomp_initial_height: float = -INF
var source_aim_stomp_apex_height: float = -INF
var source_aim_stomp_descent_started: bool = false
var source_aim_stomp_player_position: Vector3 = Vector3.ZERO
# The raising-leg IK can start only AFTER chest travel and both
# available yaw joints have consumed their permitted aiming range.
var source_aim_primary_settled: bool = false
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
        and animations.has("踏みつけ_L") and animations.has("弾き")
        and animations.has("なぎ払い") and animations.has("踏みつけ_R")
        and animations.has("弾き_R") and animations.has("なぎ払い_R"))
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
        # Use element UUID, not display name: several head meshes are
        # all called "mesh". Track real imported local vertices to avoid
        # false contacts caused by rotating AABB corners.
        mesh_nodes_by_uuid[entry] = mesh
        mesh_base_positions_by_uuid[entry] = mesh.position
        var mesh_vertices := PackedVector3Array()
        for raw_vertex in (element.get("vertices", {}) as Dictionary).values():
            mesh_vertices.append(_v3(raw_vertex) * UNIT)
        mesh_vertices_by_uuid[entry] = mesh_vertices

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

## Blockbench animator arrays are NOT chronological. In the original
## 17:21 asset KICK and STOMP append early keys after late keys. Sort
## each channel independently before evaluating any sampled time.
## Blockbench's linear rotation interpolates the EULER components,
## including signed values past 180 degrees, not shortest-arc SLERP.
func _key_time_ascending(a: Dictionary, b: Dictionary) -> bool:
    return float(a.get("time", 0.0)) < float(b.get("time", 0.0))


func _channel_keys(keys: Array, channel: String) -> Array:
    var selected: Array = []
    for key in keys:
        if str(key.get("channel", "rotation")) == channel:
            selected.append(key)
    selected.sort_custom(_key_time_ascending)
    return selected


func _key_rotation_euler(key: Dictionary) -> Vector3:
    var points: Array = key.get("data_points", [])
    if points.is_empty():
        return Vector3.ZERO
    var p: Dictionary = points[0]
    return Vector3(float(p.get("x", 0.0)),
        float(p.get("y", 0.0)), float(p.get("z", 0.0)))

func _key_position(key: Dictionary) -> Vector3:
    var points: Array = key.get("data_points", [])
    if points.is_empty():
        return Vector3.ZERO
    var p: Dictionary = points[0]
    return Vector3(float(p.get("x", 0)), float(p.get("y", 0)),
        float(p.get("z", 0))) * UNIT

func _sample_position(keys: Array, t: float) -> Vector3:
    var positions: Array = _channel_keys(keys, "position")
    if positions.is_empty():
        return Vector3.ZERO
    if t <= float(positions[0].get("time", 0)):
        return _key_position(positions[0])
    for i in range(1, positions.size()):
        var end: float = float(positions[i].get("time", 0))
        if t <= end:
            var start: float = float(positions[i - 1].get("time", 0))
            var alpha: float = clampf(
                (t - start) / maxf(end - start, 0.0001), 0.0, 1.0)
            return _key_position(positions[i - 1]).lerp(
                _key_position(positions[i]), alpha)
    return _key_position(positions[positions.size() - 1])

func _sample_rotation(keys: Array, t: float) -> Quaternion:
    var rotations: Array = _channel_keys(keys, "rotation")
    if rotations.is_empty():
        return Quaternion.IDENTITY
    if t <= float(rotations[0].get("time", 0)):
        return _key_rotation(rotations[0])
    for i in range(1, rotations.size()):
        var end: float = float(rotations[i].get("time", 0))
        if t <= end:
            var start: float = float(rotations[i - 1].get("time", 0))
            var alpha: float = clampf(
                (t - start) / maxf(end - start, 0.0001), 0.0, 1.0)
            # SLERP takes a shorter rotation path, which changes long
            # Blockbench sweeps such as x=-10.9567 -> x=248.3667.
            # Interpolate authored Euler components in their source units.
            var euler: Vector3 = _key_rotation_euler(
                rotations[i - 1]).lerp(_key_rotation_euler(rotations[i]),
                    alpha)
            return _bb_rotation(euler)
    return _key_rotation(rotations[rotations.size() - 1])

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
            var position_offset: Vector3 = Vector3.ZERO
            var position_keys: Array = []
            if tracks.has(uid):
                position_keys = _channel_keys(
                    tracks[uid].get("keyframes", []), "position")
                position_offset = _sample_position(
                    tracks[uid].get("keyframes", []), sample_time)
            # Locomotion clips predate the newly authored Wait Body Y
            # anchor. Preserve the source Wait's neutral chassis height
            # while walking, but NEVER use it in an authored attack clip.
            if joint.name == "Body" and position_keys.is_empty() and (
                    ["Idle", "Turn", "Approach"].has(clip_name)):
                var wait_tracks: Dictionary = (
                    animations["Wait"].get("animators", {}))
                if wait_tracks.has(uid):
                    position_offset = _sample_position(
                        wait_tracks[uid].get("keyframes", []), 0.0)
            joint.position = (bind_positions[uid] as Vector3) + position_offset
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
        if not source_ground_ik_active:
            for uid in bones.keys():
                var joint: Node3D = bones[uid]
                var source: Quaternion = joint.quaternion
                if joint.name == "Head":
                    continue
                blend_from[uid] = source
        current_clip = clip_name
        elapsed = 0.0
        blend_elapsed = (
            BLEND_SECONDS if source_ground_ik_active else 0.0)
    elapsed += maxf(0.0, delta)
    blend_elapsed = minf(BLEND_SECONDS, blend_elapsed + maxf(0.0, delta))
    apply_pose(current_clip, elapsed)
    if not source_wait_to_idle_blend_from.is_empty():
        var transition_seconds: float = (
            SOURCE_WAIT_TO_IDLE_BLEND_SECONDS
            / BittaranAttackTimings.source_return_speed())
        source_wait_to_idle_blend_elapsed = minf(
            transition_seconds,
            source_wait_to_idle_blend_elapsed + maxf(delta, 0.0))
        var blend: float = _source_timed_smoothstep(
            source_wait_to_idle_blend_elapsed,
            transition_seconds)
        for uid in source_wait_to_idle_blend_from.keys():
            if not bones.has(uid):
                continue
            var joint: Node3D = bones[uid]
            var saved: Dictionary = (
                source_wait_to_idle_blend_from[uid])
            joint.position = (
                (saved["position"] as Vector3).lerp(
                    joint.position, blend))
            joint.quaternion = (
                (saved["rotation"] as Quaternion).slerp(
                    joint.quaternion, blend).normalized())
        if source_wait_to_idle_blend_elapsed >= (
                transition_seconds - 0.000001):
            source_wait_to_idle_blend_from.clear()

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
        var joint: Node3D = bones[uid]
        # v416: a KICK starts only after both diagonal pairs have
        # replanted the attacking toe at its immutable Wait anchor.
        # The visible IK orientation from the PREVIOUS kick may
        # nevertheless still be present in the shoulder/knee when
        # the next clip's entry rotation is captured. Blending from
        # that historically bent/twisted bone feeds a fraction of its
        # axial twist back into each new KICK (repro: leg_fr toe local
        # angle drifted another ~0.03-0.05° per repetition despite a
        # stable WORLD toe). Blend from original Wait keyed locals
        # instead, ONLY for the three joints of this KICK's active leg.
        # STOMP and SWEEP keep their live-current pose transitions.
        if kind == "kick" and ATTACK_LEG_BONES[id].has(joint.name):
            attack_entry_rotations[uid] = _authored_key_rotation(
                "Wait", joint.name, 0.0)
        else:
            attack_entry_rotations[uid] = joint.quaternion



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


## Diagnostic only. The authored model has 18 separate mesh elements, but
## every one MUST stay attached to its source joint. Contact intervals are
## useful to identify the likely surface impact, not permission to move
## an individual MeshInstance3D out of the joint hierarchy.
func _ground_mesh_lowest_world_y(uid: String) -> float:
    if not mesh_nodes_by_uuid.has(uid):
        return INF
    var mesh: MeshInstance3D = mesh_nodes_by_uuid[uid]
    if not is_instance_valid(mesh):
        return INF
    var vertices: PackedVector3Array = mesh_vertices_by_uuid.get(
        uid, PackedVector3Array())
    var lowest: float = INF
    for vertex in vertices:
        lowest = minf(lowest, mesh.to_global(vertex).y)
    return lowest


## Read-only per-mesh contact inspection. Do not translate any mesh,
## joint, Body, HEAD or weapon in response to these measurements.
## Grounding is exclusively performed by BittaranFootIK for SUPPORT legs,
## with _keep_chassis_above_ground protecting ordinary locomotion.
func inspect_blockbench_ground_contacts(clip_name: String,
        seconds: float) -> Dictionary:
    ground_last_clip = clip_name
    ground_last_time = seconds
    ground_mesh_observations.clear()
    var catalog: Dictionary = GROUND_CONTACTS.DATA.get("clips", {})
    var windows: Dictionary = {}
    var t: float = seconds
    if catalog.has(clip_name):
        var record: Dictionary = catalog[clip_name]
        t = clampf(seconds, 0.0, float(record.get("length", 0.0)))
        windows = record.get("meshes", {})
    for uid in mesh_nodes_by_uuid.keys():
        var author_contact: bool = false
        if windows.has(uid):
            for window in windows[uid]:
                if t >= float(window[0]) - 0.00001 and (
                        t <= float(window[1]) + 0.00001):
                    author_contact = true
                    break
        ground_mesh_observations[uid] = {
            "authored_contact": author_contact,
            "actual_lowest_world_y": _ground_mesh_lowest_world_y(str(uid))
        }
    return ground_mesh_observations.duplicate(true)


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


func _authored_key_position(clip_name: String,
        bone_name: String, seconds: float) -> Vector3:
    var uid: String = str(bone_uuid_by_name.get(bone_name, ""))
    if uid.is_empty():
        return Vector3.ZERO
    var position: Vector3 = bind_positions.get(uid, Vector3.ZERO)
    if not animations.has(clip_name):
        return position
    var clip: Dictionary = animations[clip_name]
    var track: Dictionary = (clip.get("animators", {}) as Dictionary).get(
        uid, {})
    return position + _sample_position(
        track.get("keyframes", []), seconds)


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
    # v419: ONE transform for every attack kind and every quadrant.
    # Source WORLD joint rotations are produced by the ORIGINAL
    # front-left Body+leg keys, then reflected across the rig's X/Z
    # anatomical planes. Convert the mirrored world pose to the
    # destination's actual local parent frame: the BODY already
    # carries its own mirrored authored motion in the live scene.
    var root_q: Quaternion = global_basis.orthonormalized(
        ).get_rotation_quaternion()
    var source_body: Quaternion = (
        root_q * _authored_key_rotation(
            str(ATTACK_NAMES[kind]), "Body", at)).normalized()
    var mirrored: Array = _mirrored_chain_worlds(
        kind, target_id, at, source_body)
    var parent_q: Quaternion
    if bone_slot == 0:
        var body: Node3D = find_child(
            "Body", true, false) as Node3D
        parent_q = (body.global_basis.orthonormalized(
            ).get_rotation_quaternion()
            if body != null else root_q)
    else:
        parent_q = mirrored[bone_slot - 1] as Quaternion
    return (parent_q.inverse()
        * (mirrored[bone_slot] as Quaternion)).normalized()

func _authored_rotation_for_leg(kind: String,
        target_id: String, bone_slot: int, at: float) -> Quaternion:
    # v419: no separate KICK shoulder morph, SWEEP absolute-quat
    # shortcut or STOMP delta family. All three source joints are
    # mirrored as WORLD rotations by precisely the same X/Z map.
    return _mirrored_chain_local_for_leg(
        kind, target_id, bone_slot, at)

func _authored_body_rotation_for_attack(kind: String, id: String,
        at: float) -> Quaternion:
    # v419: mirror the same Blockbench BODY animation for every
    # KICK/SWEEP/STOMP and all four leg quadrants:
    # FL = source, FR = X, RL = Z, RR = X+Z.
    # The quaternion is Wait-relative to keep the standing BODY
    # attachment orientation consistent in every mirrored direction.
    # No additional front/rear pitch, torso-roll damping or
    # attack-specific body rotation is introduced.
    var source: Quaternion = _authored_key_rotation(
        str(ATTACK_NAMES[kind]), "Body", at)
    return _mirror_body_delta_for_attack(source, id,
        id.ends_with("r"), id.begins_with("leg_r"))

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
    # v419 compatibility entry: original BODY clip never damped.
    return source

# v404: the attack Body rotation WITHOUT the pitch/roll damping
# (source pose, mirrored for SWEEP): the reference the attacking
# leg's locals were authored against.
func _authored_body_full_rotation(kind: String, id: String,
        at: float) -> Quaternion:
    # v419: this is the exact selected-quadrant authored BODY pose.
    return _authored_body_rotation_for_attack(kind, id, at)

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
    # v419: no damped Body and therefore no shoulder compensation.
    return Quaternion.IDENTITY

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
## Source-trajectory owner for ALL horizontal authored attacks.
## Reflect the front-left chain in one rig-root space before translating
## it to each destination hip. Bone rotations and positional trajectories
## are transformed together: never mirror shoulder quaternions under
## one frame and knee/ankle positions under another.
func sample_authored_kick_source(id: String, at: float,
        source_sole_local: Vector3) -> Dictionary:
    return _sample_authored_mirrored_source(
        "kick", id, at, source_sole_local)


func sample_authored_sweep_source(id: String, at: float,
        source_sole_local: Vector3) -> Dictionary:
    return _sample_authored_mirrored_source(
        "sweep", id, at, source_sole_local)


func _sample_authored_mirrored_source(kind: String, id: String,
        at: float, source_sole_local: Vector3) -> Dictionary:
    if not loading_ok or not ATTACK_NAMES.has(kind) or not ATTACK_LEG_BONES.has(id):
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
        body_node.quaternion = _authored_body_rotation_for_attack(
            kind, "leg_fl", at)
    for slot in range(3):
        joints[slot].quaternion = _authored_rotation_for_leg(
            kind, "leg_fl", slot, at)
    var rotation: Quaternion = (
        joints[2].global_basis.get_rotation_quaternion())
    var knee: Vector3 = joints[1].global_position
    var foot: Vector3 = joints[2].global_position
    var sole: Vector3 = joints[2].to_global(source_sole_local)
    var source_hip: Vector3 = joints[0].global_position
    var mesh_low: float = _subtree_mesh_lowest_y(joints[0])
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
        "sole": sole, "hip": target_hip,
        "mesh_lowest": mesh_low + target_hip.y - source_hip.y,
        "source_mesh_lowest": mesh_low}


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
    # Legacy public name retained for the scene/fixture callers.
    # Both SWEEP and KICK now use the same front-left source-space
    # reflection including knee, ankle, sole and joint orientation.
    return sample_authored_sweep_source(id, at, sole_local)


## v424 front attack test: use the authored L/R track without procedural mirroring.
## v427: Enter SWEEP key zero through the full Wait stance, never from
## a previous IK-corrected pose. Time is independent of the author's
## SWEEP play clock (which remains at key zero during windup).
const FRONT_SWEEP_ENTRY_SECONDS: float = 0.32

func _apply_front_test_attack(frame: Dictionary) -> void:
    var id: String = str(frame.get("id", ""))
    var kind: String = str(frame.get("kind", ""))
    if not ["leg_fl", "leg_fr"].has(id):
        return
    var clip_name: String = str(ATTACK_NAMES.get(kind, ""))
    if id == "leg_fr":
        clip_name = ("踏みつけ_R" if kind == "stomp" else clip_name + "_R")
    if not animations.has(clip_name):
        push_error("Bittaran: missing front test clip " + clip_name)
        return
    var at: float = float(frame.get("authored_time", 0.0))
    var attack_time: float = float(frame.get("time", 0.0))
    var windup: float = float(frame.get("windup", 0.7))
    var strike: float = float(frame.get("strike", 1.0))
    var hold: float = float(frame.get("hold", 0.0))
    var recovery: float = float(frame.get("recovery", 0.6))
    if kind == "stomp":
        at = minf(at, windup + strike)
    at = clampf(at, 0.0, float(animations[clip_name].get("length", 0.0)))
    var exit_time: float = clampf(
        (attack_time - windup - strike - hold) / maxf(recovery, 0.001),
        0.0, 1.0)
    var out_weight: float = 1.0 - exit_time * exit_time * (3.0 - 2.0 * exit_time)
    var targets: Array[String] = ["Body"]
    for bone in ATTACK_LEG_BONES[id]:
        targets.append(str(bone))
    for bone_name in targets:
        var uid: String = str(bone_uuid_by_name.get(bone_name, ""))
        if uid.is_empty() or not bones.has(uid):
            continue
        var pose: Quaternion = _authored_key_rotation(
            clip_name, bone_name, at)
        var neutral: Quaternion = _authored_key_rotation(
            "Wait", bone_name, 0.0)
        if kind == "sweep":
            var entry_t: float = clampf(
                attack_time / FRONT_SWEEP_ENTRY_SECONDS, 0.0, 1.0)
            var entry_weight: float = (
                entry_t * entry_t * (3.0 - 2.0 * entry_t))
            # Wait -> authored key 0; only after the entry window does
            # the attack director advance its authored SWEEP clip time.
            pose = neutral.slerp(pose, entry_weight).normalized()
        (bones[uid] as Node3D).quaternion = pose.slerp(
            neutral, 1.0 - out_weight).normalized()


## v434 source-only renderer: exact Blockbench clip bone transforms.
## No gait, IK, pose crossfade, procedural extra yaw, contact adjustment,
## root height correction, or independent mesh translation. Source keys
## are evaluated by channel, sorted by time, and rotation channels
## interpolate EULER components before building the joint quaternion.
func apply_source_clip_exact(clip_name: String, seconds: float) -> void:
    if not loading_ok or not animations.has(clip_name):
        return
    var clip: Dictionary = animations[clip_name]
    var t: float = clampf(seconds, 0.0, float(clip.get("length", 0.0)))
    var tracks: Dictionary = clip.get("animators", {})
    for uid in bones.keys():
        var joint: Node3D = bones[uid]
        if joint.name == "Head":
            # The imported runtime Head consolidates three separate
            # Blockbench head groups. Keep its Wait neutral transform.
            # Live head tracking is disabled during the source-only stage.
            continue
        var keys: Array = (
            tracks[uid].get("keyframes", []) if tracks.has(uid) else [])
        joint.position = (bind_positions[uid] as Vector3) + (
            _sample_position(keys, t))
        joint.quaternion = (
            (bind_rotations[uid] as Quaternion)
            * _sample_rotation(keys, t)).normalized()


## Blend ONLY across clip boundaries. During the actual strike
## apply_source_clip_exact remains pure Blockbench with its linear Euler
## animation interpolation. Slerp here is for transition between two
## separate posed clips, not for interpolation inside a source clip.
func _source_timed_smoothstep(seconds: float,
        total_seconds: float) -> float:
    var u: float = clampf(
        seconds / maxf(total_seconds, 0.000001), 0.0, 1.0)
    return u * u * (3.0 - 2.0 * u)


## v445: C2-continuous return velocity profile for the attacking arm.
## The quintic curve has zero angular/linear velocity AND acceleration
## at both endpoints, unlike the previous cubic smoothstep whose
## acceleration jumped at the start/finish.
## Each joint uses the SAME scalar time to preserve a coherent chain.
func _source_timed_smootherstep(seconds: float,
        total_seconds: float) -> float:
    var u: float = clampf(
        seconds / maxf(total_seconds, 0.000001), 0.0, 1.0)
    return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


## v445: attacking 3-joint chain returns DIRECTLY to Wait using the
## same quintic ease for upper/lower/foot, after torso recovery.
## No lift pose, no disconnected meshes, no procedural per-joint lag.
const FRONT_ATTACK_LIMB_NAMES: Dictionary = {
    "leg_fl": ["FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L"],
    "leg_fr": ["FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R"]
}
## All four legs return from the last IK-solved pose after BODY recovery.
const SOURCE_ATTACK_LIMB_NAMES: Dictionary = {
    "leg_fl": ["FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L"],
    "leg_fr": ["FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R"],
    "leg_rl": ["RearLeg_L", "RearLowerLeg_L", "RearFoot_L"],
    "leg_rr": ["RearLeg_R", "RearLowerLeg_R", "RearFoot_R"]
}


## Called by source IK AFTER pinning the toe through Body rise.
## The saved THREE skeletal joint transforms are the actual displayed
## pose, not the next frame's Idle source keys; no mesh offset is saved.
func remember_source_body_grounded_limb(leg_id: String) -> void:
    source_last_body_ik_solved_pose.clear()
    for limb_name in SOURCE_ATTACK_LIMB_NAMES.get(leg_id, []):
        var uid: String = str(bone_uuid_by_name.get(limb_name, ""))
        if not bones.has(uid):
            continue
        var bone: Node3D = bones[uid]
        source_last_body_ik_solved_pose[limb_name] = {
            "position": bone.position,
            "rotation": bone.quaternion
        }


func _source_return_leg_to_wait(joint: Node3D,
        from_rotation: Quaternion, from_position: Vector3,
        neutral_rotation: Quaternion, neutral_position: Vector3,
        seconds: float, duration: float) -> void:
    var ease: float = _source_timed_smootherstep(seconds, duration)
    joint.position = from_position.lerp(neutral_position, ease)
    joint.quaternion = from_rotation.slerp(
        neutral_rotation, ease).normalized()


## Capture an actual grounded skeletal pose at the end of a nonattack
## frame. The next source attack can start from it without snapping to
## the uncorrected Wait pose at its first entry tick.
func remember_source_grounded_attack_entry() -> void:
    if not loading_ok:
        return
    source_last_grounded_idle_pose.clear()
    for uid in bones.keys():
        var joint: Node3D = bones[uid]
        if joint.name == "Head":
            continue
        source_last_grounded_idle_pose[uid] = {
            "position": joint.position, "rotation": joint.quaternion
        }
    source_rear_entry_id = ""
    source_rear_entry_kind = ""
    source_rear_entry_start_pose.clear()
    source_aim_id = ""
    source_aim_kind = ""
    source_aim_body_yaw = 0.0
    source_aim_shoulder_yaw = 0.0
    source_aim_body_offset = Vector3.ZERO
    source_aim_future_hip_local = Vector3.ZERO
    source_aim_stomp_initial_height = -INF
    source_aim_stomp_apex_height = -INF
    source_aim_stomp_descent_started = false
    source_aim_primary_settled = false


## Return a WORLD-Y yaw from the bone's current horizontal bearing
## toward SERA. The signed cross product chooses the shortest yaw.
static func _source_horizontal_aim_angle(
        bearing: Vector3, destination: Vector3) -> float:
    bearing.y = 0.0
    destination.y = 0.0
    if bearing.length_squared() <= 0.000001 or (
            destination.length_squared() <= 0.000001):
        return 0.0
    bearing = bearing.normalized()
    destination = destination.normalized()
    return atan2(bearing.cross(destination).y,
        bearing.dot(destination))


## Compute the strike-bearing waypoint from the AUTHOR's future pose.
## For a SWEEP, this is the MIDDLE of the first damaging floor arc
## (never the currently raised foot). For a KICK, the extending toe.
## Cache the offset in boss-root coordinates so moving the BODY does
## not drag the aiming waypoint or feed corrections back into itself.
func _source_attack_waypoint_offset(kind: String,
        leg_id: String, shoulder: Node3D,
        foot: Node3D) -> Vector3:
    var waypoint_t: float = 0.0
    match kind:
        "sweep":
            waypoint_t = (0.50 if leg_id.begins_with("leg_r")
                else 1.0)
        "kick":
            waypoint_t = 0.65
        _:
            return global_basis.inverse() * (
                foot.global_position - shoulder.global_position)
    var sample: Dictionary = _sample_authored_mirrored_source(
        kind, leg_id, waypoint_t, Vector3.ZERO)
    if sample.is_empty():
        return global_basis.inverse() * (
            foot.global_position - shoulder.global_position)
    return global_basis.inverse() * (
        (sample["foot"] as Vector3) - (sample["hip"] as Vector3))


## Source-accurate animation remains intact. Only its final 3D pose is
## aimed: BODY can translate horizontally <=1m and yaw <=30 degrees,
## the attacking SHOULDER can yaw <=30 degrees about WORLD UP. Applying
## one yaw at the upper joint preserves all child hinge connections;
## no axial bone twist or isolated mesh rotation is introduced.
## The other three toes are replanted by source-ground IK afterwards.
func apply_source_attack_aim(
        frame: Dictionary, player_position: Vector3,
        delta: float) -> void:
    if not loading_ok or frame.is_empty() or (
            not bool(frame.get("original_attack_only", false))):
        return
    var leg_id: String = str(frame.get("id", ""))
    var kind: String = str(frame.get("kind", ""))
    if not ATTACK_LEG_BONES.has(leg_id):
        return
    var body_uid: String = str(bone_uuid_by_name.get("Body", ""))
    var upper_name: String = str(ATTACK_LEG_BONES[leg_id][0])
    var foot_name: String = str(ATTACK_LEG_BONES[leg_id][2])
    var upper_uid: String = str(bone_uuid_by_name.get(upper_name, ""))
    var foot_uid: String = str(bone_uuid_by_name.get(foot_name, ""))
    if not bones.has(body_uid) or not bones.has(upper_uid) or (
            not bones.has(foot_uid)):
        return
    var body: Node3D = bones[body_uid]
    var shoulder: Node3D = bones[upper_uid]
    var foot: Node3D = bones[foot_uid]
    var phase: String = str(frame.get("phase", ""))
    var source_t: float = float(frame.get("authored_time", 0.0))
    if source_aim_id != leg_id or source_aim_kind != kind or (
            float(frame.get("time", 0.0)) <= 0.0):
        source_aim_id = leg_id
        source_aim_kind = kind
        source_aim_body_yaw = 0.0
        source_aim_shoulder_yaw = 0.0
        source_aim_body_offset = Vector3.ZERO
        source_aim_stomp_initial_height = -INF
        source_aim_stomp_apex_height = -INF
        source_aim_stomp_descent_started = false
        source_aim_primary_settled = false
        source_aim_stomp_player_position = player_position
        source_aim_future_hip_local = _source_attack_waypoint_offset(
            kind, leg_id, shoulder, foot)

    # Track STOMP continuously throughout the raised anticipation,
    # including the source clip's long leg lift. The first REAL
    # downward reversal locks all four steering axes immediately.
    # Front and rear are measured independently; no one-size-fits-all
    # timer is used to decide the stomp's maximum height.
    if kind == "stomp" and phase == "strike":
        var height: float = foot.global_position.y
        if source_aim_stomp_initial_height == -INF:
            source_aim_stomp_initial_height = height
            source_aim_stomp_apex_height = height
        source_aim_stomp_apex_height = maxf(
            source_aim_stomp_apex_height, height)
        if source_aim_stomp_apex_height >= (
                source_aim_stomp_initial_height
                + SOURCE_STOMP_MIN_LIFT_METERS) and (
                source_aim_stomp_apex_height - height
                    >= SOURCE_STOMP_APEX_DROP_METERS):
            source_aim_stomp_descent_started = true
    var tracking: bool = phase == "entry" or phase == "strike"
    if kind == "stomp":
        tracking = tracking and not source_aim_stomp_descent_started
    elif kind == "sweep":
        tracking = tracking and source_t < (
            BittaranAttackTimings.SWEEP_REAR_FIRST_STROKE_START_KEY_SECONDS
            if leg_id.begins_with("leg_r") else
            BittaranAttackTimings.SWEEP_FRONT_FIRST_STROKE_START_KEY_SECONDS)
    elif kind == "kick":
        tracking = tracking and source_t < (
            BittaranAttackTimings.KICK_EXTENSION_START_KEY_SECONDS)

    if tracking:
        var hip_corner: Vector3 = (
            shoulder.global_position - body.global_position)
        var toward: Vector3 = player_position - body.global_position
        var yaw_goal: float = clampf(
            _source_horizontal_aim_angle(hip_corner, toward),
            -deg_to_rad(SOURCE_HIP_AIM_MAX_DEGREES),
            deg_to_rad(SOURCE_HIP_AIM_MAX_DEGREES))
        source_aim_body_yaw = move_toward(
            source_aim_body_yaw, yaw_goal,
            deg_to_rad(SOURCE_BODY_AIM_RATE_DEGREES)
                * maxf(delta, 0.0))
        # First steer the HIP socket; then face the attack arc with
        # the SHOULDER. Only after both limited rotations are chosen
        # does the BODY translate to consume the remaining miss.
        # The STOMP uses the current rising toe position, whereas
        # SWEEP uses the FIRST ground-stroke midpoint.
        var chest_turn := Quaternion(Vector3.UP, source_aim_body_yaw)
        var hip_from_chest: Vector3 = (
            shoulder.global_position - body.global_position)
        var predicted_hip: Vector3 = (
            body.global_position + chest_turn * hip_from_chest)
        var forward_path: Vector3 = (
            global_basis * source_aim_future_hip_local)
        if kind == "stomp":
            forward_path = (
                foot.global_position - shoulder.global_position)
        var chest_path: Vector3 = chest_turn * forward_path
        var wanted_shoulder: float = clampf(
            _source_horizontal_aim_angle(chest_path,
                player_position - predicted_hip),
            -deg_to_rad(SOURCE_SHOULDER_AIM_MAX_DEGREES),
            deg_to_rad(SOURCE_SHOULDER_AIM_MAX_DEGREES))
        source_aim_shoulder_yaw = move_toward(
            source_aim_shoulder_yaw, wanted_shoulder,
            deg_to_rad(SOURCE_SHOULDER_AIM_RATE_DEGREES)
                * maxf(delta, 0.0))
        var shoulder_turn := Quaternion(
            Vector3.UP, source_aim_shoulder_yaw)
        var predicted_toe: Vector3 = (
            predicted_hip + shoulder_turn * chest_path)
        # Prefer full movement of the BODY (<=1m) over changing any
        # knee/shin angle. The actor root and support-foot anchors
        # are untouched; their IK solve comes after this stage.
        var remaining: Vector3 = (
            player_position - predicted_toe)
        remaining.y = 0.0
        var desired_offset: Vector3 = remaining.limit_length(
            SOURCE_BODY_AIM_TRANSLATION_MAX)
        source_aim_body_offset = source_aim_body_offset.move_toward(
            desired_offset, SOURCE_BODY_AIM_TRANSLATION_SPEED
                * maxf(delta, 0.0))
        # Explicit steering priority: no extra upper-arm reach while
        # BODY translation, BODY yaw, or shoulder yaw is still moving
        # toward the player's current position. Saturated ±30deg / 1m
        # limits count as settled once the clamped targets are reached.
        source_aim_primary_settled = (
            absf(yaw_goal - source_aim_body_yaw)
                <= deg_to_rad(1.5)
            and absf(wanted_shoulder - source_aim_shoulder_yaw)
                <= deg_to_rad(1.5)
            and source_aim_body_offset.distance_to(desired_offset)
                <= 0.035)
        if kind == "stomp":
            source_aim_stomp_player_position = player_position

    # BODY translation is strictly XZ. The source keyframed Y position
    # and its pitch/roll are untouched, as are the 3 support anchors.
    var body_weight: float = 1.0
    var limb_weight: float = 1.0
    if phase == "recovery":
        var recovery: float = float(frame.get("phase_elapsed", 0.0))
        var body_seconds: float = maxf(
            float(frame.get("body_return_seconds", 0.62)), 0.001)
        var limb_seconds: float = maxf(
            float(frame.get("leg_return_seconds", 1.20)), 0.001)
        var body_t: float = clampf(recovery / body_seconds, 0.0, 1.0)
        body_weight = 1.0 - body_t * body_t * (
            3.0 - 2.0 * body_t)
        var limb_delay: float = (
            0.0 if bool(frame.get("parallel_recovery", false))
            else body_seconds)
        var limb_t: float = clampf(
            (recovery - limb_delay) / limb_seconds, 0.0, 1.0)
        limb_weight = 1.0 - limb_t * limb_t * limb_t * (
            limb_t * (limb_t * 6.0 - 15.0) + 10.0)
    var body_shift: Vector3 = source_aim_body_offset * body_weight
    body_shift.y = 0.0
    body.global_position += body_shift
    var turn_body: float = source_aim_body_yaw * body_weight
    if absf(turn_body) > 0.000001:
        var body_scale: Vector3 = body.global_basis.get_scale()
        var body_old: Quaternion = (
            body.global_basis.get_rotation_quaternion())
        body.global_basis = Basis(
            Quaternion(Vector3.UP, turn_body) * body_old).scaled(
                body_scale)

    # The shoulder yaw was determined BEFORE chest displacement
    # using the original future strike path. Applying it now avoids
    # a second steer pass that would override BODY-first priority.
    var turn_shoulder: float = (
        source_aim_shoulder_yaw * limb_weight)
    if absf(turn_shoulder) > 0.000001:
        var upper_scale: Vector3 = shoulder.global_basis.get_scale()
        var shoulder_old: Quaternion = (
            shoulder.global_basis.get_rotation_quaternion())
        shoulder.global_basis = Basis(
            Quaternion(Vector3.UP, turn_shoulder)
            * shoulder_old).scaled(upper_scale)


## v460: the authored Wait snapshot is taken BEFORE the foot IK.
## Replace its contents at the end of the same physics frame with
## the actually rendered, floor-corrected four-leg pose. Otherwise
## Wait->Idle starts from a floating pre-IK sample on the next tick.
func remember_grounded_source_wait_handoff() -> void:
    if not loading_ok or source_wait_to_idle_blend_from.is_empty():
        return
    for uid in source_wait_to_idle_blend_from.keys():
        if not bones.has(uid):
            continue
        var joint: Node3D = bones[uid]
        source_wait_to_idle_blend_from[uid] = {
            "position": joint.position,
            "rotation": joint.quaternion
        }


func apply_original_attack_only(frame: Dictionary) -> void:
    if not loading_ok or frame.is_empty():
        return
    var leg_id: String = str(frame.get("id", ""))
    var kind: String = str(frame.get("kind", ""))
    if not SOURCE_ATTACK_CLIPS.has(leg_id):
        return
    var clips: Dictionary = SOURCE_ATTACK_CLIPS[leg_id]
    var clip_name: String = str(clips.get(kind, ""))
    if clip_name.is_empty():
        return
    if not animations.has(clip_name):
        return
    var clip_t: float = float(frame.get("authored_time", 0.0))
    var phase: String = str(frame.get("phase", "strike"))
    var stage: String = str(frame.get("recovery_stage", ""))
    if phase == "entry":
        # Interrupted/next attack must not inherit a previous attack's
        # end-of-return Idle bridge.
        source_wait_to_idle_blend_from.clear()
    if leg_id.begins_with("leg_r") and phase == "entry" and (
            source_rear_entry_id != leg_id or
            source_rear_entry_kind != kind):
        source_rear_entry_id = leg_id
        source_rear_entry_kind = kind
        source_rear_entry_start_pose = (
            source_last_grounded_idle_pose.duplicate(true))
    if phase != "recovery":
        source_return_leg_start_pose.clear()
        source_last_body_ik_solved_pose.clear()
    elif (stage == "leg" or stage == "parallel") and (
            source_return_leg_start_pose.is_empty()):
        # The physics loop calls set_motion(Idle) BEFORE source replay,
        # which overwrites prior IK angles. Prefer the explicit pose
        # captured at the END of the preceding body's grounded solve.
        for limb_name in SOURCE_ATTACK_LIMB_NAMES.get(leg_id, []):
            var grounded: Dictionary = (
                source_last_body_ik_solved_pose.get(limb_name, {}))
            if not grounded.is_empty():
                source_return_leg_start_pose[limb_name] = (
                    grounded.duplicate())
                continue
            # Standalone source-clock tests with no IK still need the
            # unmodified authored pose as a valid start.
            var bone_uid: String = str(bone_uuid_by_name.get(
                limb_name, ""))
            if not bones.has(bone_uid):
                continue
            var bone: Node3D = bones[bone_uid]
            source_return_leg_start_pose[limb_name] = {
                "position": bone.position,
                "rotation": bone.quaternion
            }
    apply_source_clip_exact(clip_name, clip_t)
    if not bool(frame.get("source_timed_attack", false)):
        # Keep the direct source mode usable by independent replay tests.
        return
    if phase == "strike" or phase == "hold":
        # Source keys must stay 100% original through the strike/hold.
        return
    var transition: float = float(frame.get("phase_elapsed", 0.0))
    var entry_seconds: float = float(
        frame.get("entry_seconds", 0.32))
    var body_return_seconds: float = float(
        frame.get("body_return_seconds", 0.62))
    var leg_return_seconds: float = float(
        frame.get("leg_return_seconds", 1.20))
    var striking_joint_names: Array = SOURCE_ATTACK_LIMB_NAMES.get(
        leg_id, [])
    var entry_weight: float = _source_timed_smoothstep(
        transition, entry_seconds)
    var body_return_weight: float = _source_timed_smoothstep(
        transition, body_return_seconds)
    for uid in bones.keys():
        var joint: Node3D = bones[uid]
        if joint.name == "Head":
            continue
        var from: Quaternion = joint.quaternion
        var from_position: Vector3 = joint.position
        var neutral: Quaternion = _authored_key_rotation(
            "Wait", joint.name, 0.0)
        var neutral_position: Vector3 = _authored_key_position(
            "Wait", joint.name, 0.0)
        if phase == "entry":
            # On rear attacks start with the last actually grounded
            # stance, not the unsolved Wait keys (rear foot differs by
            # ~24cm). Fixed snapshot avoids a first-frame pose jump.
            var entry_position: Vector3 = neutral_position
            var entry_rotation: Quaternion = neutral
            if leg_id.begins_with("leg_r"):
                var saved_entry: Dictionary = (
                    source_rear_entry_start_pose.get(uid, {}))
                if not saved_entry.is_empty():
                    entry_position = saved_entry.get(
                        "position", neutral_position)
                    entry_rotation = saved_entry.get(
                        "rotation", neutral)
            joint.position = entry_position.lerp(
                from_position, entry_weight)
            joint.quaternion = entry_rotation.slerp(
                from, entry_weight).normalized()
        elif phase == "recovery":
            if bool(frame.get("authored_full_sweep", false)):
                # Both the sweep stroke and the complete leg/chest return
                # were already authored in Blockbench (front t=2.5,
                # rear t=1.25). Do not replay the old independent
                # BODY-then-leg or simultaneous-toe return here.
                # Only bridge the terminal authored pose to neutral.
                var settle: float = _source_timed_smootherstep(
                    transition, maxf(float(
                    frame.get("recovery", 0.20)), 0.001))
                joint.position = from_position.lerp(
                    neutral_position, settle)
                joint.quaternion = from.slerp(
                    neutral, settle).normalized()
                continue
            if striking_joint_names.has(joint.name):
                # v463: in parallel mode the leg starts returning
                # at the SAME instant as the body. Sequential mode
                # retains its original planted-toe BODY stage.
                var concurrent: bool = bool(
                    frame.get("parallel_recovery", false))
                if not concurrent and transition <= body_return_seconds:
                    continue
                # Both paths use the last POST-IK, not the rest-sampled
                # local pose at the attack-to-recovery boundary.
                var saved: Dictionary = (
                    source_return_leg_start_pose.get(joint.name, {}))
                var from_q: Quaternion = saved.get("rotation", from)
                var from_pos: Vector3 = saved.get(
                    "position", from_position)
                _source_return_leg_to_wait(
                    joint, from_q, from_pos,
                    neutral, neutral_position,
                    (transition if concurrent
                        else transition - body_return_seconds),
                    leg_return_seconds)
                continue
            # BODY and other limbs reach Wait first and stay there
            # while the striking chain returns without any lift.
            joint.position = from_position.lerp(
                neutral_position, body_return_weight)
            joint.quaternion = from.slerp(
                neutral, body_return_weight).normalized()
    if phase == "recovery" and (
            (stage == "parallel" and transition >= maxf(
                body_return_seconds, leg_return_seconds)
                - 0.000001)
            or (stage == "leg" and transition >=
                body_return_seconds + leg_return_seconds
                - 0.000001)):
        # Sample the exact terminal Wait AFTER all four local
        # chains have converged. set_motion(Idle) runs BEFORE source
        # playback, so cache this pose for the NEXT tick.
        source_wait_to_idle_blend_from.clear()
        source_wait_to_idle_blend_elapsed = 0.0
        for uid in bones.keys():
            var joint: Node3D = bones[uid]
            if joint.name == "Head":
                continue
            source_wait_to_idle_blend_from[uid] = {
                "position": joint.position,
                "rotation": joint.quaternion
            }



func apply_authored_attack_pose(frame: Dictionary) -> void:
    if frame.is_empty() or not loading_ok:
        return
    if bool(frame.get("original_attack_only", false)):
        apply_original_attack_only(frame)
        return
    if bool(frame.get("direct_front_test", false)):
        _apply_front_test_attack(frame)
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
    # v419: source pose at attack entry is already mirrored exactly.
    # No delayed KICK mirror interpolation or mismatched joint
    # families. Source clip t=0 is the same in all four directions.
    kick_mirror_weight = 1.0
    # v418: KICK always uses the complete source-animated limb reach.
    # Aim determines HORIZONTAL DIRECTION only, never the foot's
    # distance. Do not scale or truncate the clip for a nearby/faraway
    # player; the hit test may naturally miss when out of range.
    kick_reach_factor = 1.0
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
    # v419: BODY and all three active-leg joints use the SAME authored
    # time from the very first attack frame. Pre-attack leg replanting
    # happens in the separate stance phase, before this timeline.
    # Recovery alone blends the mirrored keyframed pose toward Wait.
    var leg_weight: float = 1.0
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
        # v419: exact source mirror even on the very FIRST frame.
        # Weighting this against the previous IK/Gait pose made
        # source keyframes differ across quadrants at attack entry.
        # The attack-stance transition finishes BEFORE this frame.
        node.quaternion = target_rotation.slerp(
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
        var demand: float = (
            atan2(to_player.x, to_player.z)
            - atan2(from_hip.x, from_hip.z))
        var max_degrees: float = (
            ATTACK_LEG_AIM_MAX_DEGREES_KICK if kind == "kick"
            else ATTACK_LEG_AIM_MAX_DEGREES)
        # v423: unwrap the demand against the CURRENT yaw before
        # clamping. When the demand sits near the +-180-degree seam
        # (a rear leg whose player crossed to the front-opposite
        # sector during the stance/windup, or any leg whose player
        # crossed behind it mid-strike), the extending clip keeps
        # rotating the reference direction across the seam, so the
        # wrapped demand flips sign between ticks and the clamped
        # target jumped from -85 to +85 degrees: the slew then
        # dragged the whole kick 170 degrees around during the
        # strike and hold (measured on leg_rl/leg_rr: hold sole
        # error 6.43m, foot orientation error 170 degrees). Taking
        # the representative nearest the current yaw keeps the
        # slew continuous and on one side. In that unreachable
        # geometry the residual miss is ~90 degrees on either
        # side, but the kick no longer somersaults mid-strike.
        var wanted: float = clampf(
            attack_leg_aim_yaw + wrapf(
                demand - attack_leg_aim_yaw, -PI, PI),
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
