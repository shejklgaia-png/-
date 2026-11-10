## v101: User-authored stationary Guard pose with guarded animation state.
## v99: Retimed airborne keys and separate 0.375->0.500 landing sequence.
extends Node3D
signal foot_contact(side: String)
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
const EQUIPMENT_SCRIPT = preload("res://scripts/sera_equipment.gd")
const BIRD_EMBEDDED = preload("res://assets/sera_bird_data.gd")
const BIRD_LIVE_SOURCE: String = "res://models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel"
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
const BOOST_BACK_CLIP: String = "Boost_back"
const BOOST_RIGHT_CLIP: String = "Boost_right"
const BOOST_LEFT_CLIP: String = "Boost_Left"
const BOOST_CLIPS = [BOOST_CLIP, BOOST_BACK_CLIP, BOOST_RIGHT_CLIP, BOOST_LEFT_CLIP]
# v151: Angular interpolation stays continuous through ±180° and shares
# the visual turn response with RUN. Only rendered poses are filtered.
const BOOST_DIRECTION_BLEND_SECONDS: float = 0.045
# Keep the fast 0.08s fade for entering BOOST or leaving it for WAIT.
const BOOST_STATE_BLEND_SECONDS: float = 0.08
# v162: after main's 0.50s BOOST pose hold, smoothly enter RUN over 0.20s.
const BOOST_TO_RUN_BLEND_SECONDS: float = 0.20
# A heavy leg's ordinary SLIDE uses at most half of the Boost_* posture;
# the rest stays in the authored idle pose. Actual BOOST remains full strength.
const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50
const MELEE_APPROACH_CLIP: String = "meleeboost"
const STRIKE_CLIP: String = "melee1"
const STRIKE_2_CLIP: String = "Melee2"
const STRIKE_3_CLIP: String = "Melee3"
const STEP_RIGHT_CLIP: String = "Step_R"
const STEP_LEFT_CLIP: String = "Step_L"
const STEP_BACK_CLIP: String = "Backstep"
const STEP_FORWARD_CLIP: String = "Frontstep"
const JUMP_CLIP: String = "Jump"  # takeoff/ascent/descent then a new landing key
const JUMP_AIR_CLIP_END: float = 0.375  # old final fall key; flight ends here
const JUMP_LANDING_CLIP_END: float = 0.500  # new final landing key
const JUMP_FALL_CLIP_START: float = 0.20833 / JUMP_AIR_CLIP_END
const DAMAGE_CLIP: String = "Damageknock"
const GUARD_CLIP: String = "Guard"
const GUARD_REACTION_CLIP: String = "Guard_REACTION"
const BASH_CLIP: String = "Bash"
# v116: The existing 1.5x RUN animation is accelerated by 1.25x (1.5 * 1.25).
const RUN_ANIMATION_SPEED: float = 1.875  # Motion playback only; does not change movement speed
# v151: Filter only rendered RUN direction, leaving actual steering instant.
# Angle-based smoothing avoids the zero-vector flip from Vector2.lerp at 180°.
const RUN_DIRECTION_BLEND_SECONDS: float = 0.055
# v112: Give the dominant-thumb side a larger forward RUN sector.
# Right-hand preset widens LEFT; left-hand preset mirrors it to RIGHT.
# The other side retains v111's center 100° and ±5° hysteresis.
const RUN_MODE_BASE_CENTER_DEGREES: float = 100.0
const RUN_PREFERRED_SIDE_EXTRA_DEGREES: float = 20.0
const RUN_MODE_HYSTERESIS_DEGREES: float = 5.0
const RUN_MODE_BLEND_SECONDS: float = 0.085
const RUN_UPPER_TRACKING_SECONDS: float = 0.05
# A few degrees of finger jitter must not continuously twitch the model.
const VISUAL_TURN_DEADBAND_DEGREES: float = 3.0
# Near-opposite inputs can dither across +180/-180; remember turn side.
const VISUAL_OPPOSITE_TURN_BAND_DEGREES: float = 12.0
const RUN_ROOT_TURN_SPEED_DEGREES: float = 1440.0
# Sole-height hysteresis avoids repeating hits while a planted foot vibrates.
const FOOT_LIFTED_GAP: float = 0.055
const FOOT_TOUCH_GAP: float = 0.020
const FOOT_CONTACT_MIN_INTERVAL: float = 0.13
const RUN_TORSO_BONE_UUID: String = "29fad052-d2b7-1a2a-eefa-30dd75fa7d0a"
const RUN_CHEST_BONE_UUID: String = "1b13d772-8cee-ef23-dc57-4da6bba6ce39"
const RUN_NECK_BONE_UUID: String = "6c0141f8-17fe-6484-21e1-938ae81a620c"
const RUN_HEAD_BONE_UUID: String = "a4a11a19-29e6-e88c-b28d-3c9f2d4345ad"
# v113: Retain 35% of cyclic head angular sway relative to the Waist.
# Keep the existing target-facing joint yaw and intentional root turning bank.
const RUN_HEAD_SWAY_RETENTION: float = 0.35
const RUN_HEAD_REFERENCE_PHASES = [0.0, 0.25, 0.5, 0.75]
const RUN_HEAD_PARENT_BONES = [RUN_TORSO_BONE_UUID, RUN_CHEST_BONE_UUID, RUN_NECK_BONE_UUID]
const RUN_HEAD_UPPER_BONES = [RUN_TORSO_BONE_UUID, RUN_CHEST_BONE_UUID, RUN_NECK_BONE_UUID, RUN_HEAD_BONE_UUID]
# Cumulative target-facing weights: torso 20%, chest 50%, neck 75%, head 100%.
# Joint-level contributions have conservative anatomical clamping.
const RUN_UPPER_YAW_PARTS = [0.20, 0.30, 0.25, 0.25]
const RUN_UPPER_YAW_LIMITS_DEGREES = [25.0, 30.0, 25.0, 35.0]
# v109: Subtle procedural bank only while the RUN direction is changing.
const RUN_TURN_MAX_LEAN_DEGREES: float = 15.0
const RUN_TURN_RATE_AT_MAX_LEAN: float = 7.0  # rad/s, after v108 smoothing
const RUN_TURN_LEAN_ATTACK_SECONDS: float = 0.06
const RUN_TURN_LEAN_RETURN_SECONDS: float = 0.20

var bones: Dictionary = {}                  # uuid -> Node3D
var bind_positions: Dictionary = {}         # uuid -> Vector3
var bind_rotations: Dictionary = {}
var bind_scales: Dictionary = {}         # uuid -> Quaternion
var animations: Dictionary = {}             # name -> {length, tracks}
var current_clip: String = WAIT_CLIP
var clip_time: float = 0.0
# RUN has only two authored base poses; direction changes rotate the rendered
# root without touching CharacterBody3D's target-facing transform or collider.
var run_motion_initialized: bool = false
var boost_direction_initialized: bool = false
var boost_direction_target: Vector2 = Vector2(0.0, 1.0)
var boost_direction_smoothed: Vector2 = Vector2(0.0, 1.0)
var run_left_handed: bool = false  # Right-handed by default.
# v204: SLIDE is a semantic movement state, not another authored animation.
# Heavy legs reuse Boost_* while moving normally; effects must not infer
# actual BOOST input from current_clip == BOOST_CLIP.
var heavy_slide_run_enabled: bool = false
var locomotion_mode: String = "idle"
var run_direction_target: Vector2 = Vector2(0.0, 1.0)
var run_direction_smoothed: Vector2 = Vector2(0.0, 1.0)
var run_turn_sign: float = 1.0
var boost_turn_sign: float = 1.0
var run_retreat_mode: bool = false
var run_retreat_blend: float = 0.0
# Hold turn side across center-back while forward/back gait is blending.
var run_retreat_turn_sign: float = 1.0
var run_facing_yaw: float = 0.0
var run_upper_yaw_offsets: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
# A positive bank leans toward the right side of the current travel heading.
var run_turn_lean_degrees: float = 0.0
var run_turn_previous_direction: Vector2 = Vector2.ZERO
var blending_for: float = BLEND_SECONDS
var blend_duration: float = BLEND_SECONDS
# Apply ease-in/out only to the targeted BOOST -> RUN 0.20s transition.
var boost_to_run_crossfade: bool = false
var combat_playback: bool = false
var step_playback: bool = false
# A complete 360-degree flick uses a continuous blend of authored cardinal
# step poses; forward movement uses the authored Frontstep pose.
var directional_step_active: bool = false
var directional_step_vector: Vector2 = Vector2.UP
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
var equipment_guard_transition: float = 0.095
var equipment_reaction_speed: float = 1.0
var equipment_damage_scale: float = 1.0
var equipment_guard_speed: float = 1.0
var training_ko_active: bool = false
var _ko_material: ShaderMaterial
var _ko_material_b: ShaderMaterial
const KO_DARK_SHADER = preload("res://shaders/sera_ko_dark.gdshader")
const ENERGY_FLASH_SHADER = preload("res://shaders/sera_energy_flash.gdshader")
var energy_flash_active: bool = false
var _energy_flash_material: ShaderMaterial
# v182: ping-pong only the AUTHORED early windup keyframes while chasing.
# Release jumps to the actual windup endpoint with a 0.025s pose blend.
var attack_windup_active: bool = false
var attack_windup_clip: String = ""
var attack_windup_end: float = 0.0
var attack_windup_phase: float = 0.0
var equipment_handler: RefCounted
var bird_authoring: Dictionary = {}
var bird_bone_ids: Array[String] = []
var head_c_proxy: Node3D
var head_c_proxy_base_position: Vector3 = Vector3.ZERO
var foot_contact_initialized: bool = false
var foot_lifted: Dictionary = {"L": false, "R": false}
var foot_contact_elapsed: float = 1.0

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
    _install_bird_model()
    _build_animations(data)
    _merge_bird_animation_tracks()
    # Mesh alternatives reuse the original animated pivots/UUIDs unchanged.
    equipment_handler = EQUIPMENT_SCRIPT.new()
    equipment_handler.call("setup", self)
    loading_ok = (bones.size() > 0 and animations.has(WAIT_CLIP)
        and animations.has(RUN_CLIP) and animations.has(RUN_BACK_CLIP)
        and animations.has(RUN_RIGHT_CLIP) and animations.has(RUN_LEFT_CLIP)
        and animations.has(BOOST_CLIP) and animations.has(BOOST_BACK_CLIP)
        and animations.has(BOOST_RIGHT_CLIP) and animations.has(BOOST_LEFT_CLIP)
        and animations.has(MELEE_APPROACH_CLIP)
        and animations.has(STRIKE_CLIP) and animations.has(STRIKE_2_CLIP)
        and animations.has(STRIKE_3_CLIP) and animations.has(STEP_RIGHT_CLIP)
        and animations.has(STEP_LEFT_CLIP) and animations.has(STEP_BACK_CLIP)
        and animations.has(STEP_FORWARD_CLIP)
        and animations.has(DAMAGE_CLIP) and animations.has(JUMP_CLIP)
        and animations.has(GUARD_CLIP)
        and animations.has(GUARD_REACTION_CLIP) and animations.has(BASH_CLIP))
    if not loading_ok:
        push_error("Sera hierarchy or animation missing")
        return
    _apply_animation(0.0)
    # First frame must already contact the visual floor (no one-frame float).
    equipment_handler.call("snap_grounded_sole_to_floor")
    _build_motion_afterimage_pool()
    equipment_handler.call("sync_afterimages")
    # Must update the authored blade transforms before main.gd tests contact.
    process_priority = -1
    set_process(true)

func set_equipment_motion_scales(damage_scale: float, guard_speed: float,
        transition: float, reaction_type: String) -> void:
    equipment_damage_scale = clampf(damage_scale, 0.5, 2.0)
    equipment_guard_speed = clampf(guard_speed, 0.5, 2.0)
    equipment_guard_transition = clampf(transition, 0.04, 0.25)
    equipment_reaction_speed = 1.3 if reaction_type == "small" else (
        0.8 if reaction_type == "large" else 1.0)

func set_heavy_slide_run_enabled(enabled: bool) -> void:
    heavy_slide_run_enabled = enabled

func get_locomotion_mode() -> String:
    return locomotion_mode

# The back-nozzle FX follows a *visible* BOOST pose during thumb turns:
# confirmed BOOST, the 0.50s pose hold and the remaining 0.20s RUN crossfade.
# SLIDE reuses Boost_* for heavy legs but is NOT a true BOOST pose here.
func is_boost_exhaust_pose_visible() -> bool:
    if not loading_ok or training_ko_active or combat_playback or step_playback \
            or guard_playback or damage_playback or jump_playback:
        return false
    if current_clip == BOOST_CLIP:
        return locomotion_mode == "boost" or locomotion_mode == "boost_grace"
    return (current_clip == RUN_CLIP and boost_to_run_crossfade
        and blending_for < blend_duration)

# Future VFX connections: SLIDE enables legs only, confirmed BOOST also
# enables the back booster. The visual pose hold is separately tracked by
# is_boost_exhaust_pose_visible(), not by a heavyweight SLIDE state.
# These are intent channels only; no new thruster particles are created yet.
func get_thruster_intent() -> Dictionary:
    return {
        "legs": locomotion_mode == "slide" or locomotion_mode == "boost",
        "back": locomotion_mode == "boost"
    }

# v206: Only the combat controller may activate authored back-nozzle VFX.
# This does not change gameplay animations or SLIDE's legs-only intent.
func update_back_thruster_fx(active: bool, exhaust_world: Vector3,
        delta: float, backstroke_weight: float = 0.0,
        left_sector_world: Vector3 = Vector3.ZERO,
        acceleration_burst: bool = false,
        melee_sustain: bool = false) -> void:
    if equipment_handler != null:
        equipment_handler.call("update_back_thruster_fx",
            active, exhaust_world, delta, backstroke_weight,
            left_sector_world, acceleration_burst, melee_sustain)

## Equipment categories are intentionally independent of animation clips.
func get_equipment_options(slot: String) -> Array:
    return equipment_handler.call("options_for", slot) if equipment_handler != null else ["A"]

func get_equipment_selection(slot: String) -> String:
    return str(equipment_handler.call("current_for", slot)) if equipment_handler != null else "A"

func set_equipment_selection(slot: String, set_id: String) -> bool:
    if equipment_handler == null:
        return false
    return bool(equipment_handler.call("select_part", slot, set_id))

func set_exhibition_mode(enabled: bool) -> void:
    # Display in NEXUS uses camera-relative screen fitting, not the XZ
    # training floor. Equipment swaps must NEVER move its root transform.
    if equipment_handler != null:
        equipment_handler.call("set_grounding_enabled", not enabled)


# v189: The distinct bird-leg skeleton lives alongside A's original hidden leg
# rig. Only its 6 authored pivots and 10 meshes are imported. A animations remain
# unchanged, with bird UUID tracks sampled on the same timeline.
func _read_bird_authoring() -> Dictionary:
    if FileAccess.file_exists(BIRD_LIVE_SOURCE):
        var live_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIRD_LIVE_SOURCE))
        if live_value is Dictionary and live_value.has("groups") and live_value.has("animations"):
            return live_value
    var embedded: Variant = JSON.parse_string(BIRD_EMBEDDED.get_json())
    return embedded if embedded is Dictionary else {}

func _tag_bird_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        node.set_meta("sera_bird_leg", true)
        node.visible = false
    for child in node.get_children():
        _tag_bird_meshes(child)

func _install_bird_model() -> void:
    var data: Dictionary = _read_bird_authoring()
    if data.is_empty() or not bones.has(RUN_ROOT_BONE_UUID):
        return
    var groups: Dictionary = {}
    var elements: Dictionary = {}
    for raw_group in data.get("groups", []):
        groups[str(raw_group.get("uuid", ""))] = raw_group
    for raw_element in data.get("elements", []):
        elements[str(raw_element.get("uuid", ""))] = raw_element
    var entries: Array = data.get("outliner", [])
    for candidate in entries:
        if candidate is Dictionary:
            var name: String = str(groups.get(str(candidate.get("uuid", "")), {}).get("name", ""))
            if name == "Waist":
                entries = candidate.get("children", [])
                break
    var base_root: Node3D = bones[RUN_ROOT_BONE_UUID]
    var root_origin: Vector3 = base_root.get_meta("bb_origin", Vector3.ZERO)
    var installed: int = 0
    for entry in entries:
        if entry is Dictionary:
            var uid: String = str(entry.get("uuid", ""))
            var group: Dictionary = groups.get(uid, {})
            if str(group.get("name", "")) not in ["Bird_Thigh_L", "Bird_Thigh_R"]:
                continue
            _add_entry(entry, base_root, root_origin, groups, elements)
            if bones.has(uid):
                _tag_bird_meshes(bones[uid])
                installed += 1
        elif entry is String:
            var element: Dictionary = elements.get(str(entry), {})
            if not str(element.get("name", "")).begins_with("Bird_Waist_Armor"):
                continue
            var previous_count: int = base_root.get_child_count()
            _add_entry(entry, base_root, root_origin, groups, elements)
            if base_root.get_child_count() > previous_count:
                _tag_bird_meshes(base_root.get_child(previous_count))
    if installed != 2:
        push_warning("SERA bird-leg skeleton incomplete: expected two thighs")
        return
    for side in ["L", "R"]:
        for part in ["Thigh", "LowerLeg", "Foot"]:
            var expected: String = "Bird_%s_%s" % [part, side]
            for group in groups.values():
                if str(group.get("name", "")) == expected and bones.has(str(group.get("uuid", ""))):
                    bird_bone_ids.append(str(group.get("uuid", "")))
    if bird_bone_ids.size() == 6:
        bird_authoring = data
    else:
        push_warning("SERA bird-leg skeleton incomplete: missing joint")

func _merge_bird_animation_tracks(only_clip: String = "") -> void:
    if bird_authoring.is_empty():
        return
    for raw_clip in bird_authoring.get("animations", []):
        var clip_name: String = str(raw_clip.get("name", ""))
        # Historical authored Jump clip uses a Japanese name in this file.
        if clip_name == "ジャンプ":
            clip_name = "Jump"
        if not animations.has(clip_name) or (not only_clip.is_empty() and clip_name != only_clip):
            continue
        var tracks: Dictionary = animations[clip_name]["tracks"]
        var source_tracks: Dictionary = raw_clip.get("animators", {})
        for uid in bird_bone_ids:
            if not source_tracks.has(uid):
                continue
            var animator: Dictionary = source_tracks[uid]
            var channels: Dictionary = {"rotation": [], "position": [], "scale": []}
            for frame in animator.get("keyframes", []):
                var channel: String = str(frame.get("channel", ""))
                if not channels.has(channel):
                    continue
                var points: Array = frame.get("data_points", [])
                if points.is_empty():
                    continue
                var point: Dictionary = points[0]
                var value := Vector3(float(point.get("x", 0)), float(point.get("y", 0)),
                    float(point.get("z", 0)))
                (channels[channel] as Array).append({"time": float(frame.get("time", 0)), "value": value})
            for channel in ["rotation", "position", "scale"]:
                var frames: Array = channels[channel]
                frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
                    return a["time"] < b["time"])
                if channel == "rotation":
                    for keyframe in frames:
                        keyframe["quaternion"] = _blockbench_rotation(keyframe["value"])
                channels[channel] = frames
            tracks[uid] = channels
    if not only_clip.is_empty():
        return
    # No newly authored keys for these clips yet. Preserve motion in every
    # gameplay state by reusing the nearest compatible bird movement/pose.
    _fallback_bird_animation("run_back", "run_front_original")
    _fallback_bird_animation("run_right", "run_Left")
    _fallback_bird_animation("Jump", "Wait_motion")
    # Some Step/Boost/Guard/Frontstep clips have only 3-5 of 6 bird joint
    # keys. A missing track previously reset those joints to the *bind*
    # rotation in one frame. Hold their authored Wait_motion pose instead.
    var idle_tracks: Dictionary = animations[WAIT_CLIP]["tracks"]
    for clip_key in animations.keys():
        var clip_tracks: Dictionary = animations[clip_key]["tracks"]
        for uid in bird_bone_ids:
            var idle_channels: Dictionary = idle_tracks.get(uid, {})
            var idle_rotations: Array = idle_channels.get("rotation", [])
            if idle_rotations.is_empty():
                continue
            if not clip_tracks.has(uid):
                clip_tracks[uid] = {"rotation": [], "position": [], "scale": []}
            var channels: Dictionary = clip_tracks[uid]
            if (channels.get("rotation", []) as Array).is_empty():
                channels["rotation"] = [idle_rotations[0].duplicate(true)]

func _fallback_bird_animation(target: String, source: String) -> void:
    if not animations.has(target) or not animations.has(source):
        return
    var target_tracks: Dictionary = animations[target]["tracks"]
    var source_tracks: Dictionary = animations[source]["tracks"]
    for uid in bird_bone_ids:
        if not target_tracks.has(uid) and source_tracks.has(uid):
            target_tracks[uid] = (source_tracks[uid] as Dictionary).duplicate(true)

# C uses its own corrected head pivot; it inherits the authored A Head rotation
# without shifting the shared A/B skeleton or their animation keyframes.
func register_head_c_pivot(pivot: Node3D) -> void:
    head_c_proxy = pivot
    head_c_proxy_base_position = pivot.position

# v190: A single bind-pose sole measurement drives both equipment height and
# audible footfalls. Training has a visual XZ plane, not physics floor collisions.
func get_grounding_height_offset() -> float:
    return float(equipment_handler.call("get_grounding_height_offset")) if equipment_handler != null else 0.0

func reset_foot_contacts() -> void:
    foot_contact_initialized = false
    foot_lifted["L"] = false
    foot_lifted["R"] = false
    foot_contact_elapsed = 1.0

func _update_foot_contacts(delta: float) -> void:
    foot_contact_elapsed += maxf(delta, 0.0)
    if equipment_handler == null or current_clip not in RUN_CLIPS:
        reset_foot_contacts()
        return
    var wearer: Node = get_parent()
    # The existing gameplay floor is horizontal Y=0 (jump is debug-only).
    if wearer is Node3D and absf((wearer as Node3D).position.y) > 0.05:
        reset_foot_contacts()
        return
    var heights: Dictionary = equipment_handler.call("get_active_foot_heights")
    if not heights.has("L") or not heights.has("R"):
        reset_foot_contacts()
        return
    # The training stage has no floor collider. Treat the lower of the two
    # rendered soles as the planted reference for each grounded RUN frame.
    # This tracks authored stride motion even if its root bob floats above
    # A's bind-pose floor; height correction itself still uses A's static sole.
    var effective_ground: float = minf(float(heights["L"]), float(heights["R"]))
    for side in ["L", "R"]:
        var gap: float = float(heights[side]) - effective_ground
        if not foot_contact_initialized:
            foot_lifted[side] = gap > FOOT_LIFTED_GAP
        elif gap >= FOOT_LIFTED_GAP:
            foot_lifted[side] = true
        elif gap <= FOOT_TOUCH_GAP and bool(foot_lifted[side]):
            foot_lifted[side] = false
            if foot_contact_elapsed >= FOOT_CONTACT_MIN_INTERVAL:
                foot_contact_elapsed = 0.0
                # The foot touches the ground only on its sound frame.
                # Do not snap the entire character vertically for one frame.
                if str(equipment_handler.call("current_for", "legs")) != "C":
                    equipment_handler.call("snap_run_contact_foot_to_floor", side)
                foot_contact.emit(side)
    foot_contact_initialized = true

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
        # Keep the authored absolute pivot for retargeting geometry if a new
        # set's group/mesh names have changed but its hierarchy still matches.
        pivot.set_meta("bb_origin", origin)
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
        if str(piece.name).begins_with("Bird_"):
            # Keep bird-foot authored -22.5 degree mesh tilt, not only bone pose.
            piece.quaternion = _blockbench_rotation(
                _to_v3(element.get("rotation", [0, 0, 0])))
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
var _foreground_mat_b: ShaderMaterial
const B_SET_TINT_RGB: Vector3 = Vector3(1.0, 0.18, 0.18)
var _foreground_parts: Array[MeshInstance3D] = []
var _foreground_enabled: bool = false
var _afterimage_root: Node3D
var _afterimage_material: ShaderMaterial
var _afterimage_material_b: ShaderMaterial
var _afterimage_meshes: Array[MultiMeshInstance3D] = []
var _afterimage_ages: Array[float] = [-1.0, -1.0, -1.0]
var _afterimage_base_alphas: Array[float] = [0.0, 0.0, 0.0]
var _afterimage_lifetimes: Array[float] = [AFTERIMAGE_STEP_LIFETIME, AFTERIMAGE_STEP_LIFETIME, AFTERIMAGE_STEP_LIFETIME]
var _afterimage_next_slot: int = 0
var _afterimage_since_emit: float = 0.0
var _afterimage_was_moving: bool = false
var _afterimage_pool_visible: bool = false

func set_training_ko(active: bool) -> void:
    if training_ko_active == active:
        return
    training_ko_active = active
    if active:
        attack_windup_active = false
        _clear_motion_afterimages()
        # Force the last AUTHORED damage key, not the clip's nominal end
        # (which can include hold frames). Bypass transition blending.
        combat_playback = false
        step_playback = false
        jump_playback = false
        guard_playback = false
        damage_playback = true
        combat_paused = false
        freeze_attack_pose = true
        if loading_ok and animations.has(DAMAGE_CLIP):
            current_clip = DAMAGE_CLIP
            clip_time = float(animations[DAMAGE_CLIP]["last_key_time"])
            prior_rotations.clear()
            prior_offsets.clear()
            prior_scales.clear()
            blending_for = BLEND_SECONDS
            blend_duration = BLEND_SECONDS
            boost_to_run_crossfade = false
            _apply_animation(0.0)
    else:
        # Restore the normal wait pose and animation state from any KO.
        freeze_attack_pose = false
        combat_paused = false
        damage_playback = false
        guard_playback = false
        combat_playback = false
        step_playback = false
        jump_playback = false
        if loading_ok:
            if current_clip == WAIT_CLIP:
                clip_time = 0.0
                _apply_animation(0.0)
            else:
                _switch_clip(WAIT_CLIP, 0.10)
    _refresh_character_overlay()

func set_energy_flash_active(active: bool) -> void:
    if energy_flash_active == active:
        return
    energy_flash_active = active
    if active and _energy_flash_material == null:
        _energy_flash_material = ShaderMaterial.new()
        _energy_flash_material.shader = ENERGY_FLASH_SHADER
    # Preserve authored materials and existing slash/KO overlays.
    _refresh_character_overlay()

func set_slash_player_foreground(enabled: bool) -> void:
    if enabled == _foreground_enabled:
        return
    _foreground_enabled = enabled
    _refresh_character_overlay()

func _refresh_character_overlay() -> void:
    # KO has visual priority over the slash foreground and preserves A/B tint.
    if training_ko_active and _ko_material == null:
        _ko_material = ShaderMaterial.new()
        _ko_material.shader = KO_DARK_SHADER
        _ko_material.set_shader_parameter("sera_palette", SERA_TEXTURE)
        _ko_material_b = _ko_material.duplicate() as ShaderMaterial
        _ko_material_b.set_shader_parameter("set_tint", B_SET_TINT_RGB)
    for part in _foreground_parts:
        if not is_instance_valid(part):
            continue
        var overlay: Material = null
        if training_ko_active:
            overlay = _ko_material_b if str(part.get_meta("sera_equipment_set", "A")) == "B" else _ko_material
        elif energy_flash_active:
            overlay = _energy_flash_material
        elif _foreground_enabled:
            if str(part.get_meta("sera_equipment_set", "A")) == "B":
                if _foreground_mat_b == null:
                    _foreground_mat_b = _foreground_mat.duplicate() as ShaderMaterial
                    _foreground_mat_b.set_shader_parameter("set_tint", B_SET_TINT_RGB)
                overlay = _foreground_mat_b
            else:
                overlay = _foreground_mat
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
    _afterimage_material_b = _afterimage_material.duplicate() as ShaderMaterial
    _afterimage_material_b.set_shader_parameter("set_tint", B_SET_TINT_RGB)
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
        ghosts.material_override = _afterimage_material_b if str(source.get_meta(
            "sera_equipment_set", "A")) == "B" else _afterimage_material
        ghosts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _afterimage_root.add_child(ghosts)
        _afterimage_meshes.append(ghosts)

func _clear_motion_afterimages() -> void:
    _afterimage_was_moving = false
    _afterimage_since_emit = 0.0
    _afterimage_pool_visible = false
    for slot in range(AFTERIMAGE_LAYERS):
        _afterimage_ages[slot] = -1.0
        _afterimage_base_alphas[slot] = 0.0
    if _afterimage_material != null:
        _afterimage_material.set_shader_parameter("trail_alphas", Vector3.ZERO)
    if _afterimage_material_b != null:
        _afterimage_material_b.set_shader_parameter("trail_alphas", Vector3.ZERO)
    for ghosts in _afterimage_meshes:
        if is_instance_valid(ghosts) and ghosts.multimesh != null:
            ghosts.multimesh.visible_instance_count = 0

func update_motion_afterimages(delta: float, fast_movement: bool, stepping: bool) -> void:
    if training_ko_active:
        return
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
    _afterimage_material_b.set_shader_parameter("trail_alphas", layer_opacity)
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
    # Capture BOOST -> RUN intent BEFORE changing current_clip. If a new
    # BOOST starts during the fade, _switch_clip resets this flag immediately.
    boost_to_run_crossfade = (current_clip == BOOST_CLIP and wanted == RUN_CLIP)
    # Capture the actual displayed pose to avoid popping at state transitions.
    prior_rotations.clear()
    prior_offsets.clear()
    prior_scales.clear()
    for uid in bones.keys():
        var pivot: Node3D = bones[uid]
        prior_rotations[uid] = pivot.quaternion
        prior_offsets[uid] = pivot.position - bind_positions[uid]
        prior_scales[uid] = pivot.scale
    attack_windup_active = false
    current_clip = wanted
    clip_time = 0.0
    blending_for = 0.0
    blend_duration = fade_seconds

func start_guard() -> void:
    if not loading_ok or guard_playback or combat_playback or step_playback or jump_playback or damage_playback:
        return
    guard_playback = true
    _switch_clip(GUARD_CLIP, equipment_guard_transition / equipment_guard_speed)

func finish_guard() -> void:
    if not guard_playback:
        return
    guard_playback = false
    _switch_clip(WAIT_CLIP, 0.11)

func trigger_guard_reaction() -> void:
    if not loading_ok or not guard_playback:
        return
    _switch_clip(GUARD_REACTION_CLIP, 0.045)
    # If two impacts arrive during the same reaction, restart its authored
    # sequence instead of ignoring the second contact.
    clip_time = 0.0

func guard_reaction_playing() -> bool:
    return guard_playback and current_clip == GUARD_REACTION_CLIP

# Input is target-relative (X right, Y toward target); never rotate the
# actual movement vector, touch input, step direction or player collision.
func _run_forward_sector_center(direction: Vector2) -> float:
    var favored_side: bool = (
        (direction.x < 0.0 and not run_left_handed)
        or (direction.x > 0.0 and run_left_handed))
    return RUN_MODE_BASE_CENTER_DEGREES + (
        RUN_PREFERRED_SIDE_EXTRA_DEGREES if favored_side else 0.0)

func _run_input_angle_degrees(direction: Vector2) -> float:
    return absf(rad_to_deg(atan2(direction.x, direction.y)))

func set_run_left_handed(enabled: bool) -> void:
    if run_left_handed == enabled:
        return
    run_left_handed = enabled
    if run_motion_initialized:
        # Explicit preset changes should update the active gait immediately,
        # but existing crossfade / root yaw limits still smooth the visual pose.
        run_retreat_mode = (_run_input_angle_degrees(run_direction_smoothed)
            > _run_forward_sector_center(run_direction_smoothed))

func _set_run_motion_direction(local_direction: Vector2) -> void:
    if local_direction.length_squared() < 0.000001:
        return
    var direction: Vector2 = local_direction.normalized()
    if not run_motion_initialized or current_clip not in RUN_CLIPS:
        run_motion_initialized = true
        run_direction_target = direction
        run_direction_smoothed = direction
        run_turn_sign = 1.0
        run_retreat_mode = (_run_input_angle_degrees(direction)
            > _run_forward_sector_center(direction))
        run_retreat_turn_sign = 1.0 if direction.x >= 0.0 else -1.0
        run_retreat_blend = 1.0 if run_retreat_mode else 0.0
        run_facing_yaw = _run_yaw_for_direction(direction, run_retreat_blend)
        run_upper_yaw_offsets = _run_joint_yaw_targets()
        run_turn_previous_direction = _run_heading_from_weights()
        run_turn_lean_degrees = 0.0
        return
    # Never update the RUN/retreat clip from raw target direction: it must
    # transition with the SAME smoothed heading as the model's Waist yaw.
    run_direction_target = direction

func _update_run_retreat_mode(direction: Vector2) -> void:
    var angle: float = _run_input_angle_degrees(direction)
    var edge_center: float = _run_forward_sector_center(direction)
    # Keep the original retreat turn hemisphere while the mixed gait is
    # transitioning. Raw x sign at center-back otherwise flips the Waist.
    if not run_retreat_mode and run_retreat_blend < 0.05 and absf(direction.x) > 0.02:
        run_retreat_turn_sign = 1.0 if direction.x >= 0.0 else -1.0
    # Preserve ±5° hysteresis and handedness bias, but use visual heading.
    if run_retreat_mode:
        if angle < edge_center - RUN_MODE_HYSTERESIS_DEGREES:
            run_retreat_mode = false
    elif angle > edge_center + RUN_MODE_HYSTERESIS_DEGREES:
        run_retreat_mode = true

func _run_yaw_for_direction(direction: Vector2, retreat_weight: float) -> float:
    # As gait changes to backpedal, rotate the Waist continuously instead of
    # jumping 180° when the RUN/retreat mode first changes.
    var travel_angle: float = atan2(direction.x, direction.y)
    # Right-back rotates toward the right; left-back toward the left.
    # One unconditional -PI sends right-back through the long rotation arc.
    return wrapf(-travel_angle + PI * retreat_weight * run_retreat_turn_sign, -PI, PI)

# A normalized angle blend never shrinks a 180° reversal through Vector2.ZERO.
# The last turn sign resolves noisy input on opposite sides of ±180°.
func _smooth_visual_direction(current: Vector2, target: Vector2,
        delta: float, response_seconds: float, last_turn_sign: float) -> Dictionary:
    var angle_now: float = atan2(current.x, current.y)
    var angle_goal: float = atan2(target.x, target.y)
    var angle_delta: float = wrapf(angle_goal - angle_now, -PI, PI)
    var updated_sign: float = last_turn_sign
    if absf(absf(angle_delta) - PI) < deg_to_rad(VISUAL_OPPOSITE_TURN_BAND_DEGREES):
        angle_delta = absf(angle_delta) * updated_sign
    elif absf(angle_delta) > 0.0001:
        updated_sign = 1.0 if angle_delta > 0.0 else -1.0
    var new_angle: float = angle_now
    if absf(angle_delta) > deg_to_rad(VISUAL_TURN_DEADBAND_DEGREES):
        var alpha: float = 1.0 - exp(-maxf(delta, 0.0) / response_seconds)
        new_angle += angle_delta * alpha
    return {"heading": Vector2(sin(new_angle), cos(new_angle)),
        "turn_sign": updated_sign}

func get_run_dominant_clip() -> String:
    return RUN_BACK_CLIP if run_retreat_mode else RUN_CLIP

# Four authored BOOST poses are static Blockbench keyframes. Blend the two
# neighboring cardinal poses in target-relative travel space; leave RUN's
# forward/retreat gait and body tracking completely separate.
func _set_boost_motion_direction(local_direction: Vector2) -> void:
    if local_direction.length_squared() < 0.000001:
        return
    var direction: Vector2 = local_direction.normalized()
    if not boost_direction_initialized or current_clip != BOOST_CLIP:
        boost_direction_initialized = true
        boost_direction_smoothed = direction
        boost_turn_sign = 1.0
    boost_direction_target = direction

func get_boost_dominant_clip() -> String:
    if absf(boost_direction_smoothed.x) > absf(boost_direction_smoothed.y):
        return BOOST_RIGHT_CLIP if boost_direction_smoothed.x >= 0.0 else BOOST_LEFT_CLIP
    return BOOST_CLIP if boost_direction_smoothed.y >= 0.0 else BOOST_BACK_CLIP

func _sample_boost_pose(clip_name: String, uid: String) -> Dictionary:
    var source_tracks: Dictionary = animations[clip_name]["tracks"]
    var bone_tracks: Dictionary = source_tracks.get(uid, {})
    var rotations: Array = bone_tracks.get("rotation", [])
    var positions: Array = bone_tracks.get("position", [])
    var scales: Array = bone_tracks.get("scale", [])
    return {
        "rotation": _rotation_at(rotations, 0.0) if not rotations.is_empty() else bind_rotations[uid],
        "position": _value_at(positions, 0.0) * UNIT,
        "scale": _value_at(scales, 0.0) if not scales.is_empty() else Vector3.ONE
    }

func _blended_boost_pose(uid: String) -> Dictionary:
    var direction: Vector2 = boost_direction_smoothed
    if direction.length_squared() < 0.000001:
        direction = Vector2(0.0, 1.0)
    var fore_aft: String = BOOST_CLIP if direction.y >= 0.0 else BOOST_BACK_CLIP
    var lateral: String = BOOST_RIGHT_CLIP if direction.x >= 0.0 else BOOST_LEFT_CLIP
    # 0=forward/back, 1=right/left; exact authored cardinal poses at endpoints.
    var lateral_weight: float = atan2(absf(direction.x), absf(direction.y)) / (PI * 0.5)
    var fore_aft_pose: Dictionary = _sample_boost_pose(fore_aft, uid)
    var lateral_pose: Dictionary = _sample_boost_pose(lateral, uid)
    var fore_aft_rotation: Quaternion = fore_aft_pose["rotation"]
    var lateral_rotation: Quaternion = lateral_pose["rotation"]
    var fore_aft_position: Vector3 = fore_aft_pose["position"]
    var lateral_position: Vector3 = lateral_pose["position"]
    var fore_aft_scale: Vector3 = fore_aft_pose["scale"]
    var lateral_scale: Vector3 = lateral_pose["scale"]
    return {
        "rotation": fore_aft_rotation.slerp(lateral_rotation, lateral_weight).normalized(),
        "position": fore_aft_position.lerp(lateral_position, lateral_weight),
        "scale": fore_aft_scale.lerp(lateral_scale, lateral_weight)
    }

func set_moving(moving: bool, boosting: bool = false,
        local_direction: Vector2 = Vector2(0.0, 1.0),
        boost_input_active: bool = false) -> void:
    if not loading_ok or combat_playback or step_playback or jump_playback or damage_playback or guard_playback:
        return
    # Boosting includes the old 0.50s visual grace. Actual BOOST is passed
    # separately so reusing its pose for heavy SLIDE never enables BOOST FX.
    var sliding: bool = (moving and heavy_slide_run_enabled
        and not boost_input_active and not boosting)
    var use_boost_pose: bool = boosting or sliding
    if not moving:
        locomotion_mode = "idle"
    elif boost_input_active:
        locomotion_mode = "boost"
    elif sliding:
        locomotion_mode = "slide"
    elif boosting:
        locomotion_mode = "boost_grace"
    else:
        locomotion_mode = "run"
    if moving and use_boost_pose:
        _set_boost_motion_direction(local_direction)
    elif moving:
        _set_run_motion_direction(local_direction)
    var wanted: String = WAIT_CLIP
    if moving:
        wanted = BOOST_CLIP if use_boost_pose else RUN_CLIP
    # v162: BOOST pose stays for 0.50s (main.gd), then BOOST -> RUN uses
    # a distinct 0.20s blend. BOOST entry and BOOST -> WAIT keep 0.08s;
    # RUN <-> WAIT remains 0.16s. Heavy SLIDE uses the same static 4-way pose.
    var fade_seconds: float = BLEND_SECONDS
    if current_clip == BOOST_CLIP and wanted == RUN_CLIP:
        fade_seconds = BOOST_TO_RUN_BLEND_SECONDS
    elif wanted == BOOST_CLIP or current_clip == BOOST_CLIP:
        fade_seconds = BOOST_STATE_BLEND_SECONDS
    _switch_clip(wanted, fade_seconds)

func _sample_step_clip_pose(clip_name: String, uid: String, elapsed: float) -> Dictionary:
    var sample_t: float = minf(maxf(0.0, elapsed), float(animations[clip_name]["length"]))
    var tracks: Dictionary = animations[clip_name]["tracks"]
    var joint: Dictionary = tracks.get(uid, {})
    var rotations: Array = joint.get("rotation", [])
    var positions: Array = joint.get("position", [])
    var scales: Array = joint.get("scale", [])
    return {
        "rotation": _rotation_at(rotations, sample_t) if not rotations.is_empty() else bind_rotations[uid],
        "position": _value_at(positions, sample_t) * UNIT,
        "scale": _value_at(scales, sample_t) if not scales.is_empty() else Vector3.ONE
    }

func _blended_directional_step_pose(uid: String, t: float) -> Dictionary:
    # Cardinal keys are exact. Any diagonal smoothly interpolates between
    # lateral STEP_L/R and authored forward Frontstep or backward Backstep.
    var direction: Vector2 = directional_step_vector
    var fore_aft: Dictionary = _sample_step_clip_pose(STEP_FORWARD_CLIP, uid, 0.0) if direction.y < 0.0 else (
        _sample_step_clip_pose(STEP_BACK_CLIP, uid, 0.0))
    var side_clip: String = STEP_RIGHT_CLIP if direction.x >= 0.0 else STEP_LEFT_CLIP
    var lateral: Dictionary = _sample_step_clip_pose(side_clip, uid, t)
    var alpha: float = atan2(absf(direction.x), absf(direction.y)) / (PI * 0.5)
    return {
        "rotation": (fore_aft["rotation"] as Quaternion).slerp(lateral["rotation"], alpha).normalized(),
        "position": (fore_aft["position"] as Vector3).lerp(lateral["position"], alpha),
        "scale": (fore_aft["scale"] as Vector3).lerp(lateral["scale"], alpha)
    }

func start_omni_step(direction: Vector2) -> void:
    if not loading_ok or damage_playback or guard_playback or direction.length_squared() < 0.000001:
        return
    # Use the authored Step_R timeline as the interpolation clock; its
    # animation is not imposed on left/back/forward at weight zero.
    # Full-pose crossfade captures the exact displayed frame for entry.
    directional_step_vector = direction.normalized()
    directional_step_active = true
    step_playback = true
    if current_clip == STEP_RIGHT_CLIP:
        # _switch_clip would otherwise ignore a repeated rightward step.
        current_clip = WAIT_CLIP
    _switch_clip(STEP_RIGHT_CLIP, 0.12)

func start_side_step(side: int) -> void:
    if not loading_ok or damage_playback or guard_playback or (side != 1 and side != -1):
        return
    step_playback = true
    directional_step_active = false
    _switch_clip(STEP_RIGHT_CLIP if side > 0 else STEP_LEFT_CLIP, 0.12)

func start_back_step() -> void:
    # The authored Backstep clip is a single-key pose (time 0).
    # Travel is handled collision-safely by main.gd, never by root motion.
    if not loading_ok or damage_playback or guard_playback:
        return
    step_playback = true
    directional_step_active = false
    _switch_clip(STEP_BACK_CLIP, 0.12)

func finish_side_step(resume_moving: bool, airborne_fall: bool = false) -> void:
    if not step_playback:
        return
    step_playback = false
    directional_step_active = false
    if airborne_fall:
        resume_jump_fall()
    else:
        _switch_clip(RUN_CLIP if resume_moving else WAIT_CLIP, 0.16)

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

func start_attack_windup(clip_name: String, windup_end: float) -> void:
    # Bash, Melee2 and Melee3 each use their own Blockbench windup key.
    if not loading_ok or damage_playback or guard_playback:
        return
    if clip_name != BASH_CLIP and clip_name != STRIKE_2_CLIP and clip_name != STRIKE_3_CLIP:
        return
    combat_paused = false
    freeze_attack_pose = false
    combat_playback = true
    _switch_clip(clip_name, 0.065)
    attack_windup_clip = clip_name
    attack_windup_end = minf(maxf(windup_end, 0.01),
        float(animations[clip_name]["last_key_time"]))
    attack_windup_phase = 0.0
    attack_windup_active = true
    clip_time = 0.0

func release_attack_windup() -> void:
    if not attack_windup_active or current_clip != attack_windup_clip:
        return
    # On entering reach, stop ONLY the ping-pong loop. Never jump to the
    # windup's final keyframe: that skipped the authored preparatory motion
    # whenever the enemy was already close or approached mid-loop.
    # Retain the exact currently rendered clip_time and advance the same
    # animation normally through its remaining windup and contact frames.
    # The combat state/target chase ends at the exact same time as v182.
    attack_windup_active = false

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

func start_bash() -> void:
    if not loading_ok or damage_playback or guard_playback:
        return
    freeze_attack_pose = false
    combat_paused = false
    combat_playback = true
    _switch_clip(BASH_CLIP, 0.055)

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
    if not loading_ok or training_ko_active:
        return
    if attack_windup_active and not combat_paused and current_clip == attack_windup_clip:
        # Reverse within 0..windup_end instead of restarting at frame zero.
        # This continuously loops the real windup keys without a snap at wrap.
        attack_windup_phase += maxf(delta, 0.0)
        var cycle: float = attack_windup_end * 2.0
        var phase: float = fposmod(attack_windup_phase, cycle)
        clip_time = phase if phase <= attack_windup_end else cycle - phase
    elif not freeze_attack_pose and not combat_paused and not (jump_playback and current_clip == JUMP_CLIP):
        clip_time += delta * (RUN_ANIMATION_SPEED if current_clip in RUN_CLIPS else (
            1.0 / equipment_damage_scale if current_clip == DAMAGE_CLIP else (
                equipment_reaction_speed if current_clip == GUARD_REACTION_CLIP else 1.0)))
    if guard_reaction_playing() and clip_time >= float(animations[GUARD_REACTION_CLIP]["length"]):
        # The authored clip is tagged loop, but each guarded hit plays once.
        _switch_clip(GUARD_CLIP, 0.075)
    if not combat_paused:
        blending_for += delta
        if current_clip in RUN_CLIPS and run_motion_initialized:
            var run_update: Dictionary = _smooth_visual_direction(
                run_direction_smoothed, run_direction_target, delta,
                RUN_DIRECTION_BLEND_SECONDS, run_turn_sign)
            run_direction_smoothed = run_update["heading"]
            run_turn_sign = run_update["turn_sign"]
            var heading: Vector2 = _run_heading_from_weights()
            # The posture change, body yaw and authored RUN gait now share
            # one filtered heading instead of racing three independent inputs.
            _update_run_retreat_mode(heading)
            var retreat_alpha: float = 1.0 - exp(-maxf(delta, 0.0) / RUN_MODE_BLEND_SECONDS)
            run_retreat_blend = lerpf(run_retreat_blend, 1.0 if run_retreat_mode else 0.0, retreat_alpha)
            if not heading.is_zero_approx():
                var wanted_yaw: float = _run_yaw_for_direction(heading, run_retreat_blend)
                var yaw_error: float = wrapf(wanted_yaw - run_facing_yaw, -PI, PI)
                var yaw_step: float = deg_to_rad(RUN_ROOT_TURN_SPEED_DEGREES) * maxf(delta, 0.0)
                run_facing_yaw = wrapf(
                    run_facing_yaw + clampf(yaw_error, -yaw_step, yaw_step), -PI, PI)
            var upper_targets: PackedFloat32Array = _run_joint_yaw_targets()
            var upper_alpha: float = 1.0 - exp(-maxf(delta, 0.0) / RUN_UPPER_TRACKING_SECONDS)
            for i in range(4):
                run_upper_yaw_offsets[i] = lerpf(
                    run_upper_yaw_offsets[i], upper_targets[i], upper_alpha)
            _update_run_turn_lean(delta)
        else:
            # Non-RUN actions preserve their authored poses and previous fade.
            run_motion_initialized = false
            run_turn_previous_direction = Vector2.ZERO
            run_turn_lean_degrees = 0.0
        if current_clip == BOOST_CLIP and boost_direction_initialized:
            var boost_update: Dictionary = _smooth_visual_direction(
                boost_direction_smoothed, boost_direction_target, delta,
                BOOST_DIRECTION_BLEND_SECONDS, boost_turn_sign)
            boost_direction_smoothed = boost_update["heading"]
            boost_turn_sign = boost_update["turn_sign"]
        else:
            boost_direction_initialized = false
    _apply_animation(delta)
    # v200: combat (all strikes, bash, guard), steps, boosts and non-contact
    # RUN frames use the original v198 bind-height behavior.
    equipment_handler.call("restore_grounding_baseline")
    equipment_handler.call("restore_run_contact_foot_positions")
    if (current_clip == WAIT_CLIP and not step_playback and not combat_playback
            and not guard_playback and not jump_playback and not damage_playback):
        if str(equipment_handler.call("current_for", "legs")) == "C":
            equipment_handler.call("smooth_bird_grounding", delta)
        else:
            equipment_handler.call("snap_grounded_sole_to_floor")
    elif current_clip in RUN_CLIPS and not step_playback:
        # Bird C follows its current support soles continuously; only A/B/D
        # use the one-frame shoe contact on the audible footstep.
        if str(equipment_handler.call("current_for", "legs")) == "C":
            equipment_handler.call("smooth_bird_grounding", delta)
        _update_foot_contacts(delta)
    else:
        reset_foot_contacts()

func _run_heading_from_weights() -> Vector2:
    # Kept for v109 banking compatibility; now uses smoothed travel direction.
    if run_direction_smoothed.length_squared() < 0.0001:
        return Vector2.ZERO
    return run_direction_smoothed.normalized()

# Desired joint angles are calculated as differences of cumulative gaze targets,
# not 20% + 50% + 75% + 100% independently applied to each joint.
func _run_joint_yaw_targets() -> PackedFloat32Array:
    var look_error: float = wrapf(-run_facing_yaw, -PI, PI)
    var targets := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
    for i in range(4):
        var requested: float = look_error * float(RUN_UPPER_YAW_PARTS[i])
        var limit: float = deg_to_rad(float(RUN_UPPER_YAW_LIMITS_DEGREES[i]))
        targets[i] = clampf(requested, -limit, limit)
    return targets

func _update_run_turn_lean(delta: float) -> void:
    if delta <= 0.0:
        return
    var heading: Vector2 = _run_heading_from_weights()
    var desired_lean: float = 0.0
    if not heading.is_zero_approx() and not run_turn_previous_direction.is_zero_approx():
        var signed_turn: float = (
            run_turn_previous_direction.y * heading.x
            - run_turn_previous_direction.x * heading.y)
        var turn_rate: float = signed_turn / delta
        desired_lean = RUN_TURN_MAX_LEAN_DEGREES * clampf(
            turn_rate / RUN_TURN_RATE_AT_MAX_LEAN, -1.0, 1.0)
    run_turn_previous_direction = heading
    var moving_toward_turn: bool = (absf(desired_lean) > absf(run_turn_lean_degrees)
        or desired_lean * run_turn_lean_degrees < 0.0)
    var response: float = (RUN_TURN_LEAN_ATTACK_SECONDS if moving_toward_turn
        else RUN_TURN_LEAN_RETURN_SECONDS)
    var alpha: float = 1.0 - exp(-delta / response)
    run_turn_lean_degrees = lerpf(run_turn_lean_degrees, desired_lean, alpha)

# Sample forward-run / backpedal clips at a SHARED 1-second gait phase.
# Each source is first corrected by v107's 90-degree authored-root offset.
# Procedural root yaw, upper target tracking and 15-degree turning bank are
# applied only after the poses have been mixed.
# Stabilize the *combined* upper-body/head orientation. Damping only the
# Head's authored keys would remove their compensation for torso/chest motion.
# Average four phases of the current front/back blend, with gaze offsets
# included; this preserves target tracking and avoids locking to world space.
func _run_head_reference_orientation() -> Quaternion:
    var reference: Quaternion = Quaternion.IDENTITY
    var sample_count: int = 0
    for phase in RUN_HEAD_REFERENCE_PHASES:
        var upper_orientation: Quaternion = Quaternion.IDENTITY
        for bone_uuid in RUN_HEAD_UPPER_BONES:
            # Disable stabilization during reference sampling to avoid recursion.
            var sampled: Dictionary = _blended_run_pose(str(bone_uuid), float(phase), false)
            var joint_rotation: Quaternion = sampled["rotation"]
            upper_orientation = (upper_orientation * joint_rotation).normalized()
        sample_count += 1
        if sample_count == 1:
            reference = upper_orientation
        else:
            reference = reference.slerp(
                upper_orientation, 1.0 / float(sample_count)).normalized()
    return reference

func _stabilize_run_head_rotation(t: float, authored_head: Quaternion) -> Quaternion:
    var parent_orientation: Quaternion = Quaternion.IDENTITY
    for bone_uuid in RUN_HEAD_PARENT_BONES:
        var sampled: Dictionary = _blended_run_pose(str(bone_uuid), t, false)
        var joint_rotation: Quaternion = sampled["rotation"]
        parent_orientation = (parent_orientation * joint_rotation).normalized()
    var current_orientation: Quaternion = (parent_orientation * authored_head).normalized()
    var target_orientation: Quaternion = _run_head_reference_orientation()
    var stabilized: Quaternion = target_orientation.slerp(
        current_orientation, RUN_HEAD_SWAY_RETENTION).normalized()
    # Head local space cancels only periodic motion inherited from its parents.
    # The Waist's current facing/bank and all non-RUN animations remain intact.
    return (parent_orientation.inverse() * stabilized).normalized()

func _blended_run_pose(uid: String, t: float, stabilize_head: bool = true) -> Dictionary:
    var total_weight: float = 0.0
    var blended_rotation: Quaternion = Quaternion.IDENTITY
    var blended_translation: Vector3 = Vector3.ZERO
    var blended_scale: Vector3 = Vector3.ONE
    for i in range(2):
        var weight: float = (1.0 - run_retreat_blend) if i == 0 else run_retreat_blend
        if weight <= 0.000001:
            continue
        var source_name: String = RUN_CLIP if i == 0 else RUN_BACK_CLIP
        var source_tracks: Dictionary = animations[source_name]["tracks"]
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
    if uid == RUN_ROOT_BONE_UUID:
        var facing := Quaternion(Vector3.UP, run_facing_yaw)
        blended_rotation = (facing * blended_rotation).normalized()
        # Source waist sway/position must follow the same travel-facing axis;
        # rotating only the quaternion leaves lateral motion in target space.
        blended_translation = facing * blended_translation
        if not is_zero_approx(run_turn_lean_degrees):
            # Bank axis rotates WITH locomotion facing, not with the target.
            # The collider and camera remain unbanked.
            var bank_axis: Vector3 = facing * Vector3.BACK
            var bank := Quaternion(bank_axis, -deg_to_rad(run_turn_lean_degrees))
            blended_rotation = (bank * blended_rotation).normalized()
    else:
        var part_index: int = -1
        if uid == RUN_TORSO_BONE_UUID:
            part_index = 0
        elif uid == RUN_CHEST_BONE_UUID:
            part_index = 1
        elif uid == RUN_NECK_BONE_UUID:
            part_index = 2
        elif uid == RUN_HEAD_BONE_UUID:
            part_index = 3
        if part_index >= 0:
            # Joint contributions sum to 100% gaze compensation when possible.
            # Each is clamped individually, including at large side angles.
            var gaze := Quaternion(Vector3.UP, run_upper_yaw_offsets[part_index])
            blended_rotation = (gaze * blended_rotation).normalized()
    if uid == RUN_HEAD_BONE_UUID and stabilize_head:
        blended_rotation = _stabilize_run_head_rotation(t, blended_rotation)
    return {"rotation": blended_rotation, "position": blended_translation, "scale": blended_scale}

func _apply_animation(_delta: float) -> void:
    var clip: Dictionary = animations[current_clip]
    var clip_length: float = maxf(float(clip.get("length", 1.0)), 0.001)
    # 'once' clips MUST NOT wrap. A boost is frozen on its final authored
    # keyframe for the entire approach, until 'melee1' begins.
    # KO must use the last key even when Blockbench marks Damageknock looped:
    # fposmod(last_key_time, clip_length) would wrap at the final frame.
    var t: float = clip_time if (step_playback and directional_step_active) else (
        clip_time if training_ko_active and current_clip == DAMAGE_CLIP else (
        fposmod(clip_time, clip_length) if bool(clip["looped"]) else minf(clip_time, clip_length)))
    var tracks: Dictionary = clip["tracks"]
    var blend_weight: float = clampf(blending_for / maxf(blend_duration, 0.00001), 0.0, 1.0)
    if boost_to_run_crossfade or (step_playback and directional_step_active):
        # Cubic easing avoids a hard acceleration change at either endpoint.
        blend_weight = blend_weight * blend_weight * (3.0 - 2.0 * blend_weight)
    var running_pose: bool = current_clip in RUN_CLIPS
    for uid in bones.keys():
        var bone: Node3D = bones[uid]
        var q: Quaternion = Quaternion.IDENTITY
        var translation: Vector3 = Vector3.ZERO
        var scale_value: Vector3 = Vector3.ONE
        if step_playback and directional_step_active:
            var step_pose: Dictionary = _blended_directional_step_pose(str(uid), t)
            q = step_pose["rotation"]
            translation = step_pose["position"]
            scale_value = step_pose["scale"]
        elif running_pose:
            var pose: Dictionary = _blended_run_pose(str(uid), t)
            q = pose["rotation"]
            translation = pose["position"]
            scale_value = pose["scale"]
        elif current_clip == BOOST_CLIP:
            var boost_pose: Dictionary = _blended_boost_pose(str(uid))
            q = boost_pose["rotation"]
            translation = boost_pose["position"]
            scale_value = boost_pose["scale"]
            if locomotion_mode == "slide":
                # A heavy SLIDE never assumes the full BOOST pose during RUN.
                # Mix the entire authored WAIT transform (rotation, root
                # offsets and scale), not just the waist angle.
                var idle_pose: Dictionary = _sample_step_clip_pose(WAIT_CLIP, str(uid), 0.0)
                q = (idle_pose["rotation"] as Quaternion).slerp(
                    q, SLIDE_BOOST_POSE_MAX_WEIGHT).normalized()
                translation = (idle_pose["position"] as Vector3).lerp(
                    translation, SLIDE_BOOST_POSE_MAX_WEIGHT)
                scale_value = (idle_pose["scale"] as Vector3).lerp(
                    scale_value, SLIDE_BOOST_POSE_MAX_WEIGHT)
        else:
            var tracks_for_bone: Dictionary = tracks.get(uid, {})
            var rotation_values: Array = tracks_for_bone.get("rotation", [])
            var position_values: Array = tracks_for_bone.get("position", [])
            var scale_values: Array = tracks_for_bone.get("scale", [])
            scale_value = _value_at(scale_values, t) if not scale_values.is_empty() else Vector3.ONE
            translation = _value_at(position_values, t) * UNIT
            q = _rotation_at(rotation_values, t) if not rotation_values.is_empty() else bind_rotations[uid]
            if uid in bird_bone_ids and current_clip == WAIT_CLIP \
                    and rotation_values.size() > 1:
                # The authored bird idle ankle's final key is at ~0.22s,
                # but the loop lasts 3.6s. Fade it back to its first key
                # over the final 0.20s so there is no loop-boundary snap.
                var loop_return_start: float = maxf(
                    float(rotation_values[rotation_values.size() - 1]["time"]),
                    clip_length - 0.20)
                if t > loop_return_start and clip_length > loop_return_start:
                    var loop_alpha: float = clampf(
                        (t - loop_return_start) / (clip_length - loop_return_start),
                        0.0, 1.0)
                    q = q.slerp(rotation_values[0]["quaternion"], loop_alpha).normalized()
        if blend_weight < 1.0 and prior_rotations.has(uid):
            q = (prior_rotations[uid] as Quaternion).slerp(q, blend_weight)
            translation = (prior_offsets[uid] as Vector3).lerp(translation, blend_weight)
            scale_value = (prior_scales[uid] as Vector3).lerp(scale_value, blend_weight)
        bone.quaternion = q
        bone.position = (bind_positions[uid] as Vector3) + translation
        bone.scale = scale_value
    if is_instance_valid(head_c_proxy) and bones.has(RUN_HEAD_BONE_UUID):
        var standard_head: Node3D = bones[RUN_HEAD_BONE_UUID]
        head_c_proxy.quaternion = standard_head.quaternion
        head_c_proxy.scale = standard_head.scale
        head_c_proxy.position = head_c_proxy_base_position + (
            standard_head.position - bind_positions[RUN_HEAD_BONE_UUID])

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
