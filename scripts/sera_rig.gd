## v101: User-authored stationary Guard pose with guarded animation state.
## v99: Retimed airborne keys and separate 0.375->0.500 landing sequence.
extends Node3D
## Rebuilds the original Blockbench meshes and its bone animation hierarchy.
## No Blender/glTF export is required: bone keyframes are read from the source JSON.
## IMPORTANT: Blockbench free-model bones use ZYX Euler order, not Godot's default YXZ.
## Rotation keys are converted to quaternions before interpolation to prevent
## unintended multi-revolution limb spins (-720 degrees etc.).

const UNIT: float = 0.065
# v84: Render the Swordeffect board at its exact Blockbench location.
# No additional Z offset or geometry fitting is applied in Godot.
const BLEND_SECONDS: float = 0.16
const SOURCE_PATH: String = "res://assets/sera_source.json"
const EMBEDDED = preload("res://assets/sera_data.gd")
const SERA_TEXTURE = preload("res://assets/sera_godot_shading_texture.png")
const WAIT_CLIP: String = "Wait_motion"
const RUN_CLIP: String = "run_front_original"
const RUN_BACK_CLIP: String = "run_back"
const RUN_RIGHT_CLIP: String = "run_right"
const RUN_LEFT_CLIP: String = "run_Left"
const RUN_CLIPS = [RUN_CLIP, RUN_BACK_CLIP, RUN_RIGHT_CLIP, RUN_LEFT_CLIP]
# v107: The four RUN clips in SERA_back.bbmodel were authored with their
# locomotion forward axis pointing left relative to Godot's target-facing -Z.
# Correct their Waist root transform, never the Player / target / camera.
const RUN_ROOT_BONE_UUID: String = "67435cb7-b6af-23e4-10f1-3cd13d8429fa"  # Waist
const RUN_ROOT_YAW_OFFSET_RADIANS: float = -PI * 0.5
# Long-drag movement uses an authored single-pose clip, separate from flick steps.
const BOOST_CLIP: String = "Boost_front"
const MELEE_APPROACH_CLIP: String = "meleeboost"
const STRIKE_CLIP: String = "melee1"
const STRIKE_2_CLIP: String = "Melee2"
const STRIKE_3_CLIP: String = "Melee3"
const STEP_RIGHT_CLIP: String = "Step_R"
const STEP_LEFT_CLIP: String = "Step_L"
const STEP_BACK_CLIP: String = "Backstep"
const JUMP_CLIP: String = "Jump"  # takeoff/ascent/descent then a new landing key
const JUMP_AIR_CLIP_END: float = 0.375  # old final fall key; flight ends here
const JUMP_LANDING_CLIP_END: float = 0.500  # new final landing key
const JUMP_FALL_CLIP_START: float = 0.20833 / JUMP_AIR_CLIP_END
const DAMAGE_CLIP: String = "Damageknock"
const GUARD_CLIP: String = "Guard"
const RUN_ANIMATION_SPEED: float = 1.5  # Motion playback only; does not change movement speed
# v108: Continuous four-way pose blending; 0.12s response for direction changes.
const RUN_DIRECTION_BLEND_SECONDS: float = 0.12

var bones: Dictionary = {}                  # uuid -> Node3D
var bind_positions: Dictionary = {}         # uuid -> Vector3
var bind_rotations: Dictionary = {}
var bind_scales: Dictionary = {}         # uuid -> Quaternion
var animations: Dictionary = {}             # name -> {length, tracks}
var current_clip: String = WAIT_CLIP
var clip_time: float = 0.0
# Weights: front, back, right, left. These always add up to 1 during RUN.
var run_blend_weights: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
var run_blend_targets: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
var blending_for: float = BLEND_SECONDS
var blend_duration: float = BLEND_SECONDS
var combat_playback: bool = false
var step_playback: bool = false
var jump_playback: bool = false
var damage_playback: bool = false
var guard_playback: bool = false
var freeze_attack_pose: bool = false
var combat_paused: bool = false
var sword_bone: Node3D
var sword_effect_mesh: MeshInstance3D
var sword_effect_bone: Node3D
var prior_rotations: Dictionary = {}
var prior_scales: Dictionary = {}        # uuid -> Quaternion
var prior_offsets: Dictionary = {}          # uuid -> Vector3
var loading_ok: bool = false

func _ready() -> void:
    var source: String = ""
    if FileAccess.file_exists(SOURCE_PATH):
        source = FileAccess.get_file_as_string(SOURCE_PATH)
    if source.is_empty():
        source = EMBEDDED.get_json()
    if source.is_empty():
        push_error("Sera model data is missing")
        return
    var parsed: Variant = JSON.parse_string(source)
    if not (parsed is Dictionary):
        push_error("Cannot parse Blockbench data")
        return
    var data: Dictionary = parsed
    _build_model(data)
    _build_animations(data)
    loading_ok = (bones.size() > 0 and animations.has(WAIT_CLIP)
        and animations.has(RUN_CLIP) and animations.has(RUN_BACK_CLIP)
        and animations.has(RUN_RIGHT_CLIP) and animations.has(RUN_LEFT_CLIP)
        and animations.has(BOOST_CLIP) and animations.has(MELEE_APPROACH_CLIP)
        and animations.has(STRIKE_CLIP) and animations.has(STRIKE_2_CLIP)
        and animations.has(STRIKE_3_CLIP) and animations.has(STEP_RIGHT_CLIP)
        and animations.has(STEP_LEFT_CLIP) and animations.has(STEP_BACK_CLIP)
        and animations.has(DAMAGE_CLIP) and animations.has(JUMP_CLIP)
        and animations.has(GUARD_CLIP))
    if not loading_ok:
        push_error("Sera hierarchy or animation missing")
        return
    _apply_animation(0.0)
    _build_motion_afterimage_pool()
    # Must update the authored blade transforms before main.gd tests contact.
    process_priority = -1
    set_process(true)

func _build_model(data: Dictionary) -> void:
    var groups_by_uuid: Dictionary = {}
    var elements_by_uuid: Dictionary = {}
    for group in data.get("groups", []):
        groups_by_uuid[str(group.get("uuid", ""))] = group
    for element in data.get("elements", []):
        elements_by_uuid[str(element.get("uuid", ""))] = element
    for entry in data.get("outliner", []):
        _add_entry(entry, self, Vector3.ZERO, groups_by_uuid, elements_by_uuid)

func _add_entry(entry: Variant, parent: Node3D, parent_origin: Vector3, groups: Dictionary, elements: Dictionary) -> void:
    if entry is Dictionary:
        var uid: String = str(entry.get("uuid", ""))
        if not groups.has(uid):
            return
        var group: Dictionary = groups[uid]
        var origin: Vector3 = _to_v3(group.get("origin", [0, 0, 0]))
        var pivot := Node3D.new()
        pivot.name = str(group.get("name", "Bone"))
        pivot.position = (origin - parent_origin) * UNIT
        parent.add_child(pivot)
        bones[uid] = pivot
        bind_positions[uid] = pivot.position
        bind_rotations[uid] = _blockbench_rotation(_to_v3(group.get("rotation", [0, 0, 0])))
        bind_scales[uid] = Vector3.ONE
        pivot.quaternion = bind_rotations[uid]
        if pivot.name == "Sword":
            sword_bone = pivot
        elif pivot.name == "Swordeffect":
            sword_effect_bone = pivot
        for child in entry.get("children", []):
            _add_entry(child, pivot, origin, groups, elements)
    elif entry is String:
        var uid: String = str(entry)
        if not elements.has(uid):
            return
        var element: Dictionary = elements[uid]
        if not element.has("vertices") or not element.has("faces"):
            return
        var piece := _make_mesh(element)
        if piece == null:
            return
        piece.name = str(element.get("name", "Mesh"))
        piece.position = (_to_v3(element.get("origin", [0, 0, 0])) - parent_origin) * UNIT
        parent.add_child(piece)
        if piece.name == "Swordeffect":
            sword_effect_mesh = piece
            sword_effect_mesh.visible = false

# v34: a second draw pass on Sera only, enabled while the slash is visible.
# Draws *after* sword FX without overwriting the original shading/palette.
const SERA_FOREGROUND_SHADER = preload("res://shaders/sera_foreground.gdshader")
const SERA_MOTION_BLUR_SHADER = preload("res://shaders/sera_motion_ghost.gdshader")
# v78: per-snapshot fade lifetime (step unchanged, boost shorter).
# v77: reuse one 3-instance MultiMesh for each original character part.
# Positions AND full poses are captured at emission time and never followed
# until the pool slot is reused. No duplicate skeleton, viewport, or CPU mesh.
const AFTERIMAGE_LAYERS: int = 3
const AFTERIMAGE_INTERVAL: float = 0.055
const AFTERIMAGE_STEP_LIFETIME: float = 0.22
const AFTERIMAGE_BOOST_LIFETIME: float = 0.14
const AFTERIMAGE_STEP_ALPHA: float = 0.34
const AFTERIMAGE_BOOST_ALPHA: float = 0.28
var _foreground_mat: ShaderMaterial
var _foreground_parts: Array[MeshInstance3D] = []
var _foreground_enabled: bool = false
var _afterimage_root: Node3D
var _afterimage_material: ShaderMaterial
var _afterimage_meshes: Array[MultiMeshInstance3D] = []
var _afterimage_ages: Array[float] = [-1.0, -1.0, -1.0]
var _afterimage_base_alphas: Array[float] = [0.0, 0.0, 0.0]
var _afterimage_lifetimes: Array[float] = [AFTERIMAGE_STEP_LIFETIME, AFTERIMAGE_STEP_LIFETIME, AFTERIMAGE_STEP_LIFETIME]
var _afterimage_next_slot: int = 0
var _afterimage_since_emit: float = 0.0
var _afterimage_was_moving: bool = false
var _afterimage_pool_visible: bool = false

func set_slash_player_foreground(enabled: bool) -> void:
    if enabled == _foreground_enabled:
        return
    _foreground_enabled = enabled
    _refresh_character_overlay()

func _refresh_character_overlay() -> void:
    var overlay: Material = _foreground_mat if _foreground_enabled else null
    for part in _foreground_parts:
        if is_instance_valid(part):
            part.material_overlay = overlay

func _build_motion_afterimage_pool() -> void:
    # The afterimage root is a sibling of Player (world anchored), not under
    # the animated bones / moving player. This prevents old poses following
    # the live character and keeps each capture at its historical location.
    var player_body: Node = get_parent()
    if player_body == null or player_body.get_parent() == null:
        return
    _afterimage_root = Node3D.new()
    _afterimage_root.name = "SeraTemporalAfterimages"
    player_body.get_parent().add_child(_afterimage_root)
    _afterimage_material = ShaderMaterial.new()
    _afterimage_material.shader = SERA_MOTION_BLUR_SHADER
    _afterimage_material.render_priority = -20
    _afterimage_material.set_shader_parameter("sera_palette", SERA_TEXTURE)
    _afterimage_material.set_shader_parameter("trail_alphas", Vector3.ZERO)
    for source in _foreground_parts:
        var batch := MultiMesh.new()
        batch.transform_format = MultiMesh.TRANSFORM_3D
        batch.mesh = source.mesh  # Shared GPU geometry; no mesh copies.
        batch.instance_count = AFTERIMAGE_LAYERS
        batch.visible_instance_count = 0
        # The culling box is recentered at each emission, so the effect also
        # works far away from the scene origin during unrestricted movement.
        batch.custom_aabb = AABB(Vector3(-6.0, -6.0, -6.0), Vector3(12.0, 12.0, 12.0))
        var ghosts := MultiMeshInstance3D.new()
        ghosts.name = source.name + "_AfterimageBatch"
        ghosts.multimesh = batch
        ghosts.material_override = _afterimage_material
        ghosts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _afterimage_root.add_child(ghosts)
        _afterimage_meshes.append(ghosts)

func update_motion_afterimages(delta: float, fast_movement: bool, stepping: bool) -> void:
    if _afterimage_root == null or _afterimage_material == null:
        return
    var dt: float = maxf(delta, 0.0)
    var layer_opacity := Vector3.ZERO
    var any_visible: bool = false
    # Existing snapshots fade even after the step/boost input ends.
    for slot in range(AFTERIMAGE_LAYERS):
        if _afterimage_ages[slot] < 0.0:
            continue
        var age: float = _afterimage_ages[slot] + dt
        # Each capture retains the lifetime of its own movement mode, even
        # if the player switches between step and boost during the fade.
        var lifetime: float = _afterimage_lifetimes[slot]
        if age >= lifetime:
            _afterimage_ages[slot] = -1.0
            continue
        _afterimage_ages[slot] = age
        var remaining: float = 1.0 - age / lifetime
        layer_opacity[slot] = _afterimage_base_alphas[slot] * remaining * remaining
        any_visible = true

    if fast_movement:
        if not _afterimage_was_moving:
            # Capture as soon as the fast movement begins.
            _afterimage_since_emit = AFTERIMAGE_INTERVAL
        else:
            _afterimage_since_emit += dt
        if _afterimage_since_emit >= AFTERIMAGE_INTERVAL:
            _emit_motion_afterimage(stepping)
            var emitted_slot: int = (_afterimage_next_slot + AFTERIMAGE_LAYERS - 1) % AFTERIMAGE_LAYERS
            layer_opacity[emitted_slot] = _afterimage_base_alphas[emitted_slot]
            any_visible = true
            # One capture at most per rendered frame (avoid stacked duplicates
            # after a temporary framerate drop).
            _afterimage_since_emit = 0.0
        _afterimage_was_moving = true
    else:
        _afterimage_was_moving = false
        _afterimage_since_emit = 0.0

    _afterimage_material.set_shader_parameter("trail_alphas", layer_opacity)
    if any_visible != _afterimage_pool_visible:
        _afterimage_pool_visible = any_visible
        for ghosts in _afterimage_meshes:
            ghosts.multimesh.visible_instance_count = AFTERIMAGE_LAYERS if any_visible else 0

func _emit_motion_afterimage(stepping: bool) -> void:
    var slot: int = _afterimage_next_slot
    _afterimage_next_slot = (slot + 1) % AFTERIMAGE_LAYERS
    _afterimage_ages[slot] = 0.0
    _afterimage_base_alphas[slot] = AFTERIMAGE_STEP_ALPHA if stepping else AFTERIMAGE_BOOST_ALPHA
    _afterimage_lifetimes[slot] = AFTERIMAGE_STEP_LIFETIME if stepping else AFTERIMAGE_BOOST_LIFETIME
    var to_local: Transform3D = _afterimage_root.global_transform.affine_inverse()
    var local_center: Vector3 = _afterimage_root.to_local(global_position)
    var bounds := AABB(local_center - Vector3(6.0, 6.0, 6.0), Vector3(12.0, 12.0, 12.0))
    for i in range(_foreground_parts.size()):
        var source: MeshInstance3D = _foreground_parts[i]
        var ghosts: MultiMeshInstance3D = _afterimage_meshes[i]
        # Capture the full animated transform of every limb in WORLD space;
        # it remains untouched throughout this snapshot's lifetime.
        ghosts.multimesh.set_instance_transform(slot, to_local * source.global_transform)
        ghosts.multimesh.custom_aabb = bounds

func _exit_tree() -> void:
    if is_instance_valid(_afterimage_root):
        _afterimage_root.queue_free()

func _make_mesh(element: Dictionary) -> MeshInstance3D:
    var vertex_map: Dictionary = element.get("vertices", {})
    var faces: Dictionary = element.get("faces", {})
    if vertex_map.is_empty() or faces.is_empty():
        return null
    var centroid := Vector3.ZERO
    for value in vertex_map.values():
        centroid += _to_v3(value) * UNIT
    centroid /= float(vertex_map.size())

    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var triangle_count: int = 0
    var is_sword_fx: bool = str(element.get("name", "")) == "Swordeffect"
    for face_value in faces.values():
        var face: Dictionary = face_value
        # Blockbench free-model UVs are keyed per-face/per-vertex. Preserve
        # their correspondence when changing polygon winding for Godot.
        var points: Array[Vector3] = []
        var face_uvs: Array[Vector2] = []
        var uv_lookup: Dictionary = face.get("uv", {})
        for key in face.get("vertices", []):
            if vertex_map.has(key):
                points.append(_to_v3(vertex_map[key]) * UNIT)
                var coords: Array = uv_lookup.get(key, [0.0, 0.0])
                # The effect's UV is a self-contained 16 x 16 square,
                # not the character's 96 x 32 palette atlas.
                if is_sword_fx:
                    face_uvs.append(Vector2(float(coords[0]) / 16.0, float(coords[1]) / 16.0))
                else:
                    face_uvs.append(Vector2(float(coords[0]) / 96.0, float(coords[1]) / 32.0))
        if points.size() < 3:
            continue
        var face_center := Vector3.ZERO
        for p in points:
            face_center += p
        face_center /= float(points.size())
        var facing: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
        if facing.length_squared() < 0.000000001:
            continue
        if facing.dot(face_center - centroid) < 0.0:
            points.reverse()
            face_uvs.reverse()
        for i in range(1, points.size() - 1):
            var p0: Vector3 = points[0]
            var p1: Vector3 = points[i]
            var p2: Vector3 = points[i + 1]
            var normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
            if normal.length_squared() < 0.000000001:
                continue
            for index in [0, i, i + 1]:
                tool.set_normal(normal)
                tool.set_uv(face_uvs[index])
                tool.add_vertex(points[index])
            triangle_count += 1
    if triangle_count == 0:
        return null

    var result := MeshInstance3D.new()
    result.mesh = tool.commit()
    var material := StandardMaterial3D.new()
    # All six authored orientations are colored in the Blockbench PNG.
    # Use unshaded to avoid lighting undoing the baked upper/side/lower values.
    material.albedo_color = Color.WHITE
    material.albedo_texture = SERA_TEXTURE
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.metallic = 0.0
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    result.material_override = material
    if not is_sword_fx:
        if _foreground_mat == null:
            _foreground_mat = ShaderMaterial.new()
            _foreground_mat.shader = SERA_FOREGROUND_SHADER
            _foreground_mat.render_priority = 126
            _foreground_mat.set_shader_parameter("sera_palette", SERA_TEXTURE)
        _foreground_parts.append(result)
    # v36: Sera already uses an unshaded authored palette; do not cast
    # dynamic shadows on the ground. The separate circular floor mark replaces them.
    result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return result

func _build_animations(data: Dictionary) -> void:
    for raw_clip in data.get("animations", []):
        var clip_name: String = str(raw_clip.get("name", ""))
        var tracks: Dictionary = {}
        var last_key_time: float = 0.0
        var raw_animators: Dictionary = raw_clip.get("animators", {})
        for uid_variant in raw_animators.keys():
            var uid: String = str(uid_variant)
            if not bones.has(uid):
                continue
            var animator: Dictionary = raw_animators[uid_variant]
            var channels: Dictionary = {"rotation": [], "position": [], "scale": []}
            for frame_value in animator.get("keyframes", []):
                var frame: Dictionary = frame_value
                var channel: String = str(frame.get("channel", ""))
                if channel != "rotation" and channel != "position" and channel != "scale":
                    continue
                var points: Array = frame.get("data_points", [])
                if points.is_empty():
                    continue
                var raw_point: Dictionary = points[0]
                var point := Vector3(
                    float(raw_point.get("x", 0)),
                    float(raw_point.get("y", 0)),
                    float(raw_point.get("z", 0))
                )
                var key_time: float = float(frame.get("time", 0))
                last_key_time = maxf(last_key_time, key_time)
                channels[channel].append({"time": key_time, "value": point})
            for channel in ["rotation", "position", "scale"]:
                var channel_frames: Array = channels[channel]
                channel_frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
                if channel == "rotation":
                    for frame in channel_frames:
                        frame["quaternion"] = _blockbench_rotation(frame["value"])
                channels[channel] = channel_frames
            tracks[uid] = channels
        animations[clip_name] = {
            "length": float(raw_clip.get("length", 1.0)),
            "looped": str(raw_clip.get("loop", "loop")) != "once",
            "last_key_time": last_key_time,
            "tracks": tracks
        }

func _switch_clip(wanted: String, fade_seconds: float) -> void:
    if wanted == current_clip or not animations.has(wanted):
        return
    # Capture the actual displayed pose to avoid popping at state transitions.
    prior_rotations.clear()
    prior_offsets.clear()
    prior_scales.clear()
    for uid in bones.keys():
        var pivot: Node3D = bones[uid]
        prior_rotations[uid] = pivot.quaternion
        prior_offsets[uid] = pivot.position - bind_positions[uid]
        prior_scales[uid] = pivot.scale
    current_clip = wanted
    clip_time = 0.0
    blending_for = 0.0
    blend_duration = fade_seconds

func start_guard() -> void:
    if not loading_ok or guard_playback or combat_playback or step_playback or jump_playback or damage_playback:
        return
    guard_playback = true
    _switch_clip(GUARD_CLIP, 0.095)

func finish_guard() -> void:
    if not guard_playback:
        return
    guard_playback = false
    _switch_clip(WAIT_CLIP, 0.11)

# Use signed target-relative axes to mix two neighboring authored RUN cycles.
# For example forward-right at 45 degrees has 50% front and 50% right.
func _set_run_blend_targets(local_direction: Vector2) -> void:
    var total: float = absf(local_direction.x) + absf(local_direction.y)
    if total < 0.000001:
        run_blend_targets = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
        return
    run_blend_targets[0] = maxf(local_direction.y, 0.0) / total  # front
    run_blend_targets[1] = maxf(-local_direction.y, 0.0) / total # back
    run_blend_targets[2] = maxf(local_direction.x, 0.0) / total  # right
    run_blend_targets[3] = maxf(-local_direction.x, 0.0) / total # left

func get_run_dominant_clip() -> String:
    var best: int = 0
    for i in range(1, RUN_CLIPS.size()):
        if run_blend_weights[i] > run_blend_weights[best]:
            best = i
    return str(RUN_CLIPS[best])

func set_moving(moving: bool, boosting: bool = false, local_direction: Vector2 = Vector2(0.0, 1.0)) -> void:
    if not loading_ok or combat_playback or step_playback or jump_playback or damage_playback or guard_playback:
        return
    # Direction changes only update blending weights. The RUN clock stays
    # continuous instead of resetting every time the dominant axis changes.
    if moving and not boosting:
        _set_run_blend_targets(local_direction)
        if current_clip not in RUN_CLIPS:
            # Enter from WAIT/BOOST/STEP with the correct initial direction.
            # The existing _switch_clip still blends from the displayed pose.
            run_blend_weights = run_blend_targets.duplicate()
    var wanted: String = WAIT_CLIP
    if moving:
        wanted = BOOST_CLIP if boosting else RUN_CLIP
    _switch_clip(wanted, BLEND_SECONDS)

func start_side_step(side: int) -> void:
    if not loading_ok or damage_playback or guard_playback or (side != 1 and side != -1):
        return
    step_playback = true
    _switch_clip(STEP_RIGHT_CLIP if side > 0 else STEP_LEFT_CLIP, 0.055)

func start_back_step() -> void:
    # The authored Backstep clip is a single-key pose (time 0).
    # Travel is handled collision-safely by main.gd, never by root motion.
    if not loading_ok or damage_playback or guard_playback:
        return
    step_playback = true
    _switch_clip(STEP_BACK_CLIP, 0.055)

func finish_side_step(resume_moving: bool, airborne_fall: bool = false) -> void:
    if not step_playback:
        return
    step_playback = false
    if airborne_fall:
        resume_jump_fall()
    else:
        _switch_clip(RUN_CLIP if resume_moving else WAIT_CLIP, 0.11)

func start_jump() -> void:
    if not loading_ok or damage_playback or guard_playback or jump_playback:
        return
    jump_playback = true
    _switch_clip(JUMP_CLIP, 0.055)

func set_jump_progress(progress: float) -> void:
    # The source is now 0.5s, but 0..0.375s is the unchanged airborne clip.
    # Never reach the new 0.5s landing pose before actual floor contact.
    if not jump_playback or current_clip != JUMP_CLIP:
        return
    clip_time = JUMP_AIR_CLIP_END * clampf(progress, 0.0, 1.0)

func start_landing() -> void:
    if not loading_ok or damage_playback:
        return
    jump_playback = true
    _switch_clip(JUMP_CLIP, 0.0)
    clip_time = JUMP_AIR_CLIP_END

func set_landing_progress(progress: float) -> void:
    if not jump_playback or damage_playback or current_clip != JUMP_CLIP:
        return
    clip_time = lerpf(JUMP_AIR_CLIP_END, JUMP_LANDING_CLIP_END, clampf(progress, 0.0, 1.0))

func resume_jump_fall() -> void:
    # Re-enter just the authored descending keys, never the takeoff pose.
    if not loading_ok or damage_playback:
        return
    jump_playback = true
    _switch_clip(JUMP_CLIP, 0.075)
    set_jump_progress(JUMP_FALL_CLIP_START)

func finish_jump(resume_moving: bool, boosting: bool = false) -> void:
    if not jump_playback:
        return
    jump_playback = false
    _switch_clip((BOOST_CLIP if boosting else RUN_CLIP) if resume_moving else WAIT_CLIP, 0.11)

func set_combat_paused(paused: bool) -> void:
    combat_paused = paused

func get_clip_time() -> float:
    return clip_time

func get_blade_world_segment() -> PackedVector3Array:
    if sword_bone == null or not loading_ok:
        return PackedVector3Array()
    # Derived from the original Blockbench 'Blade' mesh vertices:
    # core blade Y=3..5, Z=-8..8 in sword bone local units; not guessed screen points.
    var base: Vector3 = sword_bone.to_global(Vector3(0, 4.0 * UNIT, 7.5 * UNIT))
    var tip: Vector3 = sword_bone.to_global(Vector3(0, 4.0 * UNIT, -7.5 * UNIT))
    return PackedVector3Array([base, tip])

func start_melee_approach() -> void:
    if not loading_ok or damage_playback or guard_playback:
        return
    combat_playback = true
    combat_paused = false
    freeze_attack_pose = false
    _switch_clip(MELEE_APPROACH_CLIP, 0.045)

func melee_approach_last_key_reached() -> bool:
    return (loading_ok and current_clip == MELEE_APPROACH_CLIP
        and clip_time >= float(animations[MELEE_APPROACH_CLIP]["last_key_time"]))

func hold_melee_approach_last_pose() -> void:
    if not loading_ok or current_clip != MELEE_APPROACH_CLIP:
        return
    # Exactly the last authored key, not the nominal clip duration (0.5s).
    clip_time = float(animations[MELEE_APPROACH_CLIP]["last_key_time"])
    freeze_attack_pose = true
    _apply_animation(0.0)

func start_strike(clip_name: String = STRIKE_CLIP) -> void:
    if not loading_ok or damage_playback or guard_playback:
        return
    if clip_name != STRIKE_CLIP and clip_name != STRIKE_2_CLIP and clip_name != STRIKE_3_CLIP:
        return
    freeze_attack_pose = false
    combat_paused = false
    combat_playback = true
    # Follow-up swings interrupt recovery through the existing pose blend.
    _switch_clip(clip_name, 0.065)

func finish_attack(resume_moving: bool, airborne_fall: bool = false) -> void:
    if damage_playback:
        return
    freeze_attack_pose = false
    combat_paused = false
    combat_playback = false
    if airborne_fall:
        resume_jump_fall()
    else:
        _switch_clip(RUN_CLIP if resume_moving else WAIT_CLIP, BLEND_SECONDS)

func start_damage() -> void:
    # The short Blockbench damage pose is visual-only. World displacement
    # for knockback is handled by the CharacterBody3D in main.gd.
    if not loading_ok or damage_playback or guard_playback:
        return
    combat_playback = false
    step_playback = false
    jump_playback = false
    combat_paused = false
    freeze_attack_pose = false
    damage_playback = true
    _switch_clip(DAMAGE_CLIP, 0.025)

func damage_finished() -> bool:
    return damage_playback and clip_finished(DAMAGE_CLIP)

func finish_damage(resume_moving: bool) -> void:
    if not damage_playback:
        return
    damage_playback = false
    _switch_clip(RUN_CLIP if resume_moving else WAIT_CLIP, 0.085)

func clip_finished(name: String) -> bool:
    if not loading_ok or current_clip != name or not animations.has(name):
        return false
    return clip_time >= float(animations[name]["length"])

func _process(delta: float) -> void:
    if not loading_ok:
        return
    if not freeze_attack_pose and not combat_paused and not (jump_playback and current_clip == JUMP_CLIP):
        clip_time += delta * (RUN_ANIMATION_SPEED if current_clip in RUN_CLIPS else 1.0)
    if not combat_paused:
        blending_for += delta
        if current_clip in RUN_CLIPS:
            # Exponential smoothing is stable across changing frame rates.
            var direction_alpha: float = 1.0 - exp(-maxf(delta, 0.0) / RUN_DIRECTION_BLEND_SECONDS)
            for i in range(RUN_CLIPS.size()):
                run_blend_weights[i] = lerpf(run_blend_weights[i], run_blend_targets[i], direction_alpha)
    _apply_animation(delta)

# Sample all four compatible 1-second RUN clips at the same phase. Blend
# rotations with shortest-arc quaternions, and positions/scales linearly.
# v107's root yaw compensation is applied to EACH clip before mixing.
func _blended_run_pose(uid: String, t: float) -> Dictionary:
    var total_weight: float = 0.0
    var blended_rotation: Quaternion = Quaternion.IDENTITY
    var blended_translation: Vector3 = Vector3.ZERO
    var blended_scale: Vector3 = Vector3.ONE
    for i in range(RUN_CLIPS.size()):
        var weight: float = run_blend_weights[i]
        if weight <= 0.000001:
            continue
        var source_tracks: Dictionary = animations[str(RUN_CLIPS[i])]["tracks"]
        var bone_tracks: Dictionary = source_tracks.get(uid, {})
        var rotation_values: Array = bone_tracks.get("rotation", [])
        var position_values: Array = bone_tracks.get("position", [])
        var scale_values: Array = bone_tracks.get("scale", [])
        var sample_rotation: Quaternion = _rotation_at(rotation_values, t) if not rotation_values.is_empty() else bind_rotations[uid]
        var sample_translation: Vector3 = _value_at(position_values, t) * UNIT
        var sample_scale: Vector3 = _value_at(scale_values, t) if not scale_values.is_empty() else Vector3.ONE
        if uid == RUN_ROOT_BONE_UUID:
            var run_yaw_correction := Quaternion(Vector3.UP, RUN_ROOT_YAW_OFFSET_RADIANS)
            sample_rotation = run_yaw_correction * sample_rotation
            sample_translation = run_yaw_correction * sample_translation
        if total_weight <= 0.000001:
            blended_rotation = sample_rotation
            blended_translation = sample_translation
            blended_scale = sample_scale
        else:
            var fraction: float = weight / (total_weight + weight)
            blended_rotation = blended_rotation.slerp(sample_rotation, fraction).normalized()
            blended_translation = blended_translation.lerp(sample_translation, fraction)
            blended_scale = blended_scale.lerp(sample_scale, fraction)
        total_weight += weight
    return {"rotation": blended_rotation, "position": blended_translation, "scale": blended_scale}

func _apply_animation(_delta: float) -> void:
    var clip: Dictionary = animations[current_clip]
    var clip_length: float = maxf(float(clip.get("length", 1.0)), 0.001)
    # 'once' clips MUST NOT wrap. A boost is frozen on its final authored
    # keyframe for the entire approach, until 'melee1' begins.
    var t: float = fposmod(clip_time, clip_length) if bool(clip["looped"]) else minf(clip_time, clip_length)
    var tracks: Dictionary = clip["tracks"]
    var blend_weight: float = clampf(blending_for / maxf(blend_duration, 0.00001), 0.0, 1.0)
    var running_pose: bool = current_clip in RUN_CLIPS
    for uid in bones.keys():
        var bone: Node3D = bones[uid]
        var q: Quaternion = Quaternion.IDENTITY
        var translation: Vector3 = Vector3.ZERO
        var scale_value: Vector3 = Vector3.ONE
        if running_pose:
            var pose: Dictionary = _blended_run_pose(str(uid), t)
            q = pose["rotation"]
            translation = pose["position"]
            scale_value = pose["scale"]
        else:
            var tracks_for_bone: Dictionary = tracks.get(uid, {})
            var rotation_values: Array = tracks_for_bone.get("rotation", [])
            var position_values: Array = tracks_for_bone.get("position", [])
            var scale_values: Array = tracks_for_bone.get("scale", [])
            scale_value = _value_at(scale_values, t) if not scale_values.is_empty() else Vector3.ONE
            translation = _value_at(position_values, t) * UNIT
            q = _rotation_at(rotation_values, t) if not rotation_values.is_empty() else bind_rotations[uid]
        if blend_weight < 1.0 and prior_rotations.has(uid):
            q = (prior_rotations[uid] as Quaternion).slerp(q, blend_weight)
            translation = (prior_offsets[uid] as Vector3).lerp(translation, blend_weight)
            scale_value = (prior_scales[uid] as Vector3).lerp(scale_value, blend_weight)
        bone.quaternion = q
        bone.position = (bind_positions[uid] as Vector3) + translation
        bone.scale = scale_value

## Blockbench/Three.js default is ZYX: Rz * Ry * Rx.
## Normalize multi-turn authoring values so large angles don't amplify numerical error.
func _blockbench_rotation(angles: Vector3) -> Quaternion:
    var x: float = deg_to_rad(wrapf(angles.x, -180.0, 180.0))
    var y: float = deg_to_rad(wrapf(angles.y, -180.0, 180.0))
    var z: float = deg_to_rad(wrapf(angles.z, -180.0, 180.0))
    return (Quaternion(Vector3.BACK, z) \
        * Quaternion(Vector3.UP, y) \
        * Quaternion(Vector3.RIGHT, x)).normalized()

## Shortest-arc spherical interpolation avoids Euler wrap and gimbal artifacts.
## Key poses are preserved exactly: only the in-between rotations change.
func _rotation_at(keys: Array, t: float) -> Quaternion:
    if keys.is_empty():
        return Quaternion.IDENTITY
    if t <= float(keys[0]["time"]):
        return keys[0]["quaternion"]
    for i in range(1, keys.size()):
        var end_t: float = float(keys[i]["time"])
        if t <= end_t:
            var start_t: float = float(keys[i - 1]["time"])
            var factor: float = clampf((t - start_t) / maxf(end_t - start_t, 0.000001), 0.0, 1.0)
            var a: Quaternion = keys[i - 1]["quaternion"]
            var b: Quaternion = keys[i]["quaternion"]
            return a.slerp(b, factor).normalized()
    return keys[keys.size() - 1]["quaternion"]

func _value_at(keys: Array, t: float) -> Vector3:
    if keys.is_empty():
        return Vector3.ZERO
    if t <= float(keys[0]["time"]):
        return keys[0]["value"]
    for i in range(1, keys.size()):
        var end_t: float = float(keys[i]["time"])
        if t <= end_t:
            var start_t: float = float(keys[i - 1]["time"])
            var factor: float = clampf((t - start_t) / maxf(end_t - start_t, 0.000001), 0.0, 1.0)
            return (keys[i - 1]["value"] as Vector3).lerp(keys[i]["value"], factor)
    return keys[keys.size() - 1]["value"]

func _to_v3(value: Variant) -> Vector3:
    if value is Array and value.size() >= 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO

func get_sword_effect_mesh() -> MeshInstance3D:
    return sword_effect_mesh
