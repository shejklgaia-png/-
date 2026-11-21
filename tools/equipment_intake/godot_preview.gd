extends Node3D
## SERA equipment authoring viewer. Runs unchanged in Android GL Compatibility
## and Godot WebGL2. The same SeraRig, SeraEquipment, materials, ViewEdges and
## stage lighting as the game are used: NO Blockbench-to-WebGL reconstruction.
const RigScript = preload("res://scripts/sera_rig.gd")
const PartStats = preload("res://scripts/sera_part_stats.gd")
const IconBackdrop = preload("res://scripts/sera_icon_background.gd")
const NexusArmClearance = preload("res://scripts/sera_nexus_arm_clearance.gd")
const SLOT_ORDER = [
    "head", "torso", "arms", "legs", "booster", "weapon_r", "weapon_l"
]
const PORTRAIT_SIZE: float = 2.0
# The canonical NEXUS exhibition pose names, as used by command_nexus.gd.
const NEXUS_POSE_NAMES: Array[String] = ["NEXUS_pose", "NEXUSpose"]
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 4.0

var camera: Camera3D
var orbit: Node3D
var center: Node3D
var rig: Node3D
var handler: RefCounted
var ready_for_commands: bool = false
var view_mode: String = "body"
var icon_idle_clip: String = ""
var active_full_body_pose: String = ""
var editing_slot: String = "head"
var selected: Dictionary = {}
var rig_base_transforms: Dictionary = {}
var camera_yaw: float = 160.0
var camera_pitch: float = -18.0
var camera_roll: float = 0.0
var camera_zoom: float = 1.0
var camera_pan: Vector2 = Vector2.ZERO
var current_target_scale: float = 1.0
var keep_aspect: bool = false
var _listeners: Array = []
var _touches: Dictionary = {}
var _gesture_anchor: Dictionary = {}
var _mouse_drag: bool = false
var background_mode: String = "grid"
var background_quad: MeshInstance3D
var _js_callback: JavaScriptObject
var _last_request_seq: int = -1

func _ready() -> void:
    # Identical to main.gd:_build_world(), also used by the native icon capture.
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#111e28")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#bbc9e1")
    env.ambient_light_energy = 0.60
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
    sun.light_color = Color("#e3ecff")
    sun.light_energy = 1.7
    sun.shadow_enabled = false
    add_child(sun)

    camera = Camera3D.new()
    camera.name = "SeraIntakeOrthoCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = PORTRAIT_SIZE
    camera.near = 0.01
    camera.far = 40.0
    camera.position = Vector3(0.0, 0.0, 8.0)
    add_child(camera)
    camera.make_current()
    background_quad = MeshInstance3D.new()
    background_quad.name = "EquipmentPortraitGridBackdrop"
    var quad := QuadMesh.new()
    quad.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
    background_quad.mesh = quad
    var backdrop_material := StandardMaterial3D.new()
    backdrop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    backdrop_material.albedo_texture = IconBackdrop.texture(512, "grid")
    backdrop_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    backdrop_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    background_quad.material_override = backdrop_material
    background_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    background_quad.position = Vector3(0.0, 0.0, -10.0)
    add_child(background_quad)
    # GRID is an optional overlay on the current solid #111e28 backdrop.
    background_quad.visible = false

    orbit = Node3D.new()
    orbit.name = "IntakeCameraOrientation"
    add_child(orbit)
    center = Node3D.new()
    center.name = "IntakeCenteredModel"
    orbit.add_child(center)
    rig = RigScript.new()
    rig.name = "SeraRig"
    center.add_child(rig)
    await get_tree().process_frame
    if not bool(rig.get("loading_ok")):
        push_error("SERA_INTAKE_PREVIEW: game SeraRig did not load")
        _post({"type":"SERA_PREVIEW_ERROR","message":"SERA game rig failed to initialize"})
        return
    rig.call("set_exhibition_mode", true)
    # SeraRig's default is a combat WAIT. NEXUS explicitly samples the
    # authored NEXUS_pose before disabling processing; match that on BODY.
    icon_idle_clip = str(rig.get("current_clip"))
    rig.set_process(false)
    rig.set_physics_process(false)
    handler = rig.get("equipment_handler") as RefCounted
    if handler == null:
        push_error("SERA_INTAKE_PREVIEW: equipment handler missing")
        return
    for slot in SLOT_ORDER:
        selected[slot] = "A"
    _apply_preview_standing_pose()
    _cache_native_transforms()
    _fit_full_body_clearance()
    _apply_frame()
    ready_for_commands = true
    if OS.has_feature("web"):
        _js_callback = JavaScriptBridge.create_callback(_on_browser_message)
        var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
        window.addEventListener("message", _js_callback)
    _post({"type":"SERA_PREVIEW_READY","renderer":"Godot 4.7 GL Compatibility",
        "slots":_supported_options(), "version":1})

func _exit_tree() -> void:
    if OS.has_feature("web") and _js_callback != null:
        JavaScriptBridge.get_interface("window").removeEventListener("message",_js_callback)

func _supported_options() -> Dictionary:
    var output: Dictionary = {}
    for slot in SLOT_ORDER:
        output[slot] = handler.call("options_for",slot)
    return output

func _cache_native_transforms() -> void:
    var available: Dictionary = handler.get("available")
    for set_data in available.values():
        for pieces in (set_data as Dictionary).values():
            for piece in pieces:
                if piece is MeshInstance3D:
                    rig_base_transforms[piece.get_instance_id()] = piece.transform

func _restore_transforms() -> void:
    var available: Dictionary = handler.get("available")
    for set_data in available.values():
        for pieces in (set_data as Dictionary).values():
            for piece in pieces:
                if piece is MeshInstance3D and rig_base_transforms.has(piece.get_instance_id()):
                    piece.transform = rig_base_transforms[piece.get_instance_id()]

func _mesh_in_slot(slot: String, set_id: String) -> Array:
    var available: Dictionary = handler.get("available")
    return (available.get(set_id, {}) as Dictionary).get(slot, [])

func _bounds_of(parts: Array) -> AABB:
    var lo := Vector3(INF,INF,INF)
    var hi := Vector3(-INF,-INF,-INF)
    var inv: Transform3D = rig.global_transform.affine_inverse()
    for piece in parts:
        if not piece is MeshInstance3D or piece.mesh == null:
            continue
        var transform_to_rig: Transform3D = inv * piece.global_transform
        var aabb: AABB = piece.mesh.get_aabb()
        for i in range(8):
            var point: Vector3 = transform_to_rig * aabb.get_endpoint(i)
            lo = lo.min(point)
            hi = hi.max(point)
    if is_inf(lo.x):
        return AABB(Vector3.ZERO,Vector3.ONE)
    return AABB(lo,hi-lo)

func _visible_mesh_bounds() -> AABB:
    var parts: Array = []
    var available: Dictionary = handler.get("available")
    for set_key in available:
        for slot_key in (available[set_key] as Dictionary):
            for piece in (available[set_key] as Dictionary)[slot_key]:
                if piece is MeshInstance3D and piece.visible:
                    if view_mode == "body" or str(slot_key) == editing_slot:
                        parts.append(piece)
    return _bounds_of(parts)

func _apply_edit_size() -> void:
    _restore_transforms()
    if is_equal_approx(current_target_scale,1.0) and view_mode=="body":
        # The 100% editing target is still normalized to A's bounding box.
        pass
    var target: Array = _mesh_in_slot(editing_slot,str(selected.get(editing_slot,"A")))
    var standard: Array = _mesh_in_slot(editing_slot,"A")
    if target.is_empty() or standard.is_empty():
        return
    var ref_box: AABB = _bounds_of(standard)
    var model_box: AABB = _bounds_of(target)
    var ratios := Vector3(
        ref_box.size.x / maxf(model_box.size.x,0.00001),
        ref_box.size.y / maxf(model_box.size.y,0.00001),
        ref_box.size.z / maxf(model_box.size.z,0.00001))
    if keep_aspect:
        ratios = Vector3.ONE * minf(ratios.x,minf(ratios.y,ratios.z))
    ratios *= clampf(current_target_scale,MIN_ZOOM,MAX_ZOOM)
    var source_center: Vector3 = model_box.get_center()
    var standard_center: Vector3 = ref_box.get_center()
    var inv: Transform3D = rig.global_transform.affine_inverse()
    var scale_basis := Basis.IDENTITY.scaled(ratios)
    # Scale the complete target assembly around its shared bounds center,
    # preserving the real Godot mesh materials, UVs, topology and joints.
    var translation: Vector3 = standard_center-scale_basis*source_center
    var fit_transform := Transform3D(scale_basis,translation)
    for piece in target:
        if piece is MeshInstance3D:
            var before: Transform3D = inv * piece.global_transform
            piece.global_transform = rig.global_transform * fit_transform * before

func _apply_preview_standing_pose() -> void:
    if rig == null:
        return
    var animations: Dictionary = rig.get("animations")
    # Mirror command_nexus.gd:_apply_nexus_pose exactly: use the authored
    # SeraRig clip, including the animation tracks merged for bird legs.
    for pose_name in NEXUS_POSE_NAMES:
        if not animations.has(pose_name):
            continue
        var clip: Dictionary = animations[pose_name]
        if (clip.get("tracks", {}) as Dictionary).is_empty():
            continue
        rig.set("current_clip", pose_name)
        rig.set("clip_time", 0.0)
        rig.set("blending_for", 1.0)
        rig.set("blend_duration", 0.0)
        rig.call("_apply_animation", 0.0)
        active_full_body_pose = pose_name
        return
    # Match NEXUS's bind-pose fallback if a future rig omits the authored
    # NEXUS clip. Never fall back to the crouched Wait_motion for BODY.
    var bones: Dictionary = rig.get("bones")
    var bind_positions: Dictionary = rig.get("bind_positions")
    var bind_rotations: Dictionary = rig.get("bind_rotations")
    var arm_angles := {"UpperArm_R": -38.0, "UpperArm_L": 38.0,
        "Forearm_R": -8.0, "Forearm_L": 8.0,
        "Shoulder_R": -5.0, "Shoulder_L": 5.0}
    for uid in bones.keys():
        var bone: Node3D = bones[uid]
        bone.position = bind_positions[uid]
        bone.quaternion = bind_rotations[uid]
        bone.scale = Vector3.ONE
        if arm_angles.has(bone.name):
            bone.quaternion = bone.quaternion * Quaternion(
                Vector3.BACK, deg_to_rad(float(arm_angles[bone.name])))
    active_full_body_pose = "NEXUS_fallback"


func _fit_full_body_clearance() -> void:
    if view_mode != "body" or rig == null:
        return
    # Use the displayed, independently selected arm/leg meshes at their edited
    # size. Capture fresh NEXUS_pose quaternions AFTER sampling the authored
    # clip; otherwise consecutive size/part edits would accumulate rotation.
    var rest: Dictionary = {}
    var names: Array[String] = ["Shoulder_L", "Shoulder_R", "UpperArm_L", "UpperArm_R"]
    var bones: Dictionary = rig.get("bones")
    for raw_bone in bones.values():
        var bone: Node3D = raw_bone
        if names.has(str(bone.name)):
            rest[str(bone.name)] = bone.quaternion
    if rest.size() != 4:
        return
    NexusArmClearance.new().fit(rig, rest)


func _apply_equipment() -> void:
    if handler == null:
        return
    _restore_transforms()
    # One authoritative, non-persistent equip operation per slot. This is
    # the exact game path including Katana two-hand occupancy and leg variants.
    for slot in SLOT_ORDER:
        var request: String = str(selected.get(slot,"A"))
        var options: Array = handler.call("options_for",slot)
        if not options.has(request):
            request="A"
        handler.call("select_part",slot,request,false)
        selected[slot]=request
    # Sample the NEXUS stand after every equip operation, before mesh size,
    # bounds normalization and camera framing; restores on BODY/ICON switches.
    _apply_preview_standing_pose()
    if view_mode=="icon":
        var available: Dictionary = handler.get("available")
        for set_data in available.values():
            for slot_key in (set_data as Dictionary):
                if str(slot_key)!=editing_slot:
                    for piece in (set_data as Dictionary)[slot_key]:
                        if piece is MeshInstance3D:
                            piece.visible=false
    _apply_edit_size()
    _fit_full_body_clearance()
    _apply_frame()

func _apply_frame() -> void:
    if rig == null or orbit == null or camera == null:
        return
    var aabb: AABB = _visible_mesh_bounds()
    center.position=-aabb.get_center()
    var size_max: float = maxf(aabb.size.x,maxf(aabb.size.y,aabb.size.z))
    orbit.basis=Basis.from_euler(Vector3(deg_to_rad(camera_pitch),
        deg_to_rad(camera_yaw),deg_to_rad(camera_roll)),EULER_ORDER_XYZ)
    orbit.scale=Vector3.ONE * (PORTRAIT_SIZE*0.76 /
        maxf(size_max,0.00001)*camera_zoom)
    orbit.position=Vector3(camera_pan.x,camera_pan.y,0.0)

func _apply_command(data: Dictionary) -> void:
    if not ready_for_commands:
        return
    var kind: String = str(data.get("mode","body"))
    view_mode="icon" if kind=="icon" else "body"
    editing_slot=str(data.get("editing_slot","head"))
    if not SLOT_ORDER.has(editing_slot):
        editing_slot="head"
    var requested: Variant = data.get("selected",{})
    if requested is Dictionary:
        for slot in SLOT_ORDER:
            selected[slot]=str(requested.get(slot,"A"))
    current_target_scale=clampf(float(data.get("size",1.0)),MIN_ZOOM,MAX_ZOOM)
    background_mode = "solid" if str(data.get("background_mode","grid"))=="solid" else "grid"
    background_quad.visible = view_mode == "icon" and background_mode == "grid"
    keep_aspect=bool(data.get("keep_aspect",false))
    var view: Variant = data.get("camera",{})
    if view is Dictionary:
        camera_yaw=clampf(float(view.get("yaw",camera_yaw)),-180.0,180.0)
        camera_pitch=clampf(float(view.get("pitch",camera_pitch)),-89.0,89.0)
        camera_roll=clampf(float(view.get("roll",camera_roll)),-180.0,180.0)
        camera_zoom=clampf(float(view.get("zoom",camera_zoom)),MIN_ZOOM,MAX_ZOOM)
        camera_pan=Vector2(clampf(float(view.get("panX",camera_pan.x)),-0.7,0.7),
            clampf(float(view.get("panY",camera_pan.y)),-0.7,0.7))
        var ink: Node3D = rig.get_node_or_null("ViewEdges")
        if ink != null:
            var mat: Variant = ink.get("_ink_material")
            if mat is ShaderMaterial:
                mat.set_shader_parameter("stroke_px",
                    clampf(float(view.get("outlinePx",3.0)),0.0,6.0))
    _apply_equipment()
    var seq: int = int(data.get("seq",-1))
    _last_request_seq=seq
    await RenderingServer.frame_post_draw
    _post({"type":"SERA_PREVIEW_RENDERED","seq":seq,"mode":view_mode})

func _on_browser_message(args: Array) -> void:
    if args.is_empty() or not ready_for_commands:
        return
    var evt: JavaScriptObject = args[0]
    var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
    if str(evt.origin)!=str(window.location.origin):
        return
    var raw: String = str(evt.data)
    if raw.length()>16000:
        return
    var data: Variant = JSON.parse_string(raw)
    if not data is Dictionary or str(data.get("namespace",""))!="SERA_EQUIPMENT_GODOT_V1":
        return
    match str(data.get("type","")):
        "SET":
            _apply_command.call_deferred(data)
        "SNAPSHOT":
            _snapshot.call_deferred(int(data.get("seq",-1)))
        "RESET_CAMERA":
            camera_yaw=160.0
            camera_pitch=-18.0
            camera_roll=0.0
            camera_pan=Vector2.ZERO
            camera_zoom=1.0
            _apply_frame()
            _announce_camera()

func _post(data: Dictionary) -> void:
    if not OS.has_feature("web"):
        return
    var packed: String = JSON.stringify(JSON.stringify(data))
    # Cross-frame messages stay same-origin; the containing page owns the UI.
    JavaScriptBridge.eval("window.parent.postMessage("+packed+",window.location.origin)",true)

func _snapshot(seq: int) -> void:
    await RenderingServer.frame_post_draw
    var img: Image=get_viewport().get_texture().get_image()
    if img==null or img.is_empty():
        _post({"type":"SERA_PREVIEW_ERROR","message":"Framebuffer unavailable","seq":seq})
        return
    var raw: PackedByteArray=img.save_png_to_buffer()
    _post({"type":"SERA_PREVIEW_SNAPSHOT","seq":seq,
        "data_uri":"data:image/png;base64,"+Marshalls.raw_to_base64(raw)})

func _announce_camera() -> void:
    _post({"type":"SERA_PREVIEW_CAMERA","camera":{
        "yaw":camera_yaw,"pitch":camera_pitch,"roll":camera_roll,
        "panX":camera_pan.x,"panY":camera_pan.y,"zoom":camera_zoom}})

func _reanchor_gesture() -> void:
    # Finger count changes are discontinuities, NEVER interpreted as drags.
    _gesture_anchor.clear()
    if _touches.size() != 2:
        return
    var points: Array = _touches.values()
    var a: Vector2 = points[0]
    var b: Vector2 = points[1]
    _gesture_anchor = {
        "center": (a + b) * 0.5,
        "distance": a.distance_to(b)
    }

func _on_preview_touch(index: int, pressed: bool, position: Vector2) -> void:
    if pressed:
        _touches[index] = position
    else:
        _touches.erase(index)
    _reanchor_gesture()

func _on_preview_drag(index: int, position: Vector2) -> void:
    if not _touches.has(index):
        return
    var old_position: Vector2 = _touches[index]
    _touches[index] = position
    if _touches.size() == 2:
        var values: Array = _touches.values()
        var a: Vector2 = values[0]
        var b: Vector2 = values[1]
        var next_center: Vector2 = (a + b) * 0.5
        var next_distance: float = a.distance_to(b)
        if _gesture_anchor.is_empty():
            _reanchor_gesture()
            return
        var last_center: Vector2 = _gesture_anchor["center"]
        var last_distance: float = float(_gesture_anchor["distance"])
        # Normalize by viewport width, not by raw physical pixels.
        var width: float = maxf(float(get_viewport().get_visible_rect().size.x), 100.0)
        var movement: Vector2 = next_center - last_center
        if movement.length() < width * 0.18:
            camera_pan += Vector2(movement.x, -movement.y) * (2.0 / width)
        if last_distance > 24.0 and next_distance > 24.0:
            var relative: float = clampf(next_distance / last_distance, 0.88, 1.12)
            camera_zoom = clampf(camera_zoom * relative, MIN_ZOOM, MAX_ZOOM)
        _gesture_anchor["center"] = next_center
        _gesture_anchor["distance"] = next_distance
    elif _touches.size() == 1:
        _gesture_anchor.clear()
        var delta: Vector2 = position - old_position
        var width: float = maxf(float(get_viewport().get_visible_rect().size.x), 100.0)
        if delta.length() < width * 0.18:
            camera_yaw = wrapf(camera_yaw + delta.x * 0.4, -180.0, 180.0)
            camera_pitch = clampf(camera_pitch - delta.y * 0.4, -89.0, 89.0)
    camera_pan = camera_pan.clamp(Vector2(-0.7, -0.7), Vector2(0.7, 0.7))
    _apply_frame()
    _announce_camera()

func _input(event: InputEvent) -> void:
    if not ready_for_commands:
        return
    if event is InputEventScreenTouch:
        _on_preview_touch(event.index, event.pressed, event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        _on_preview_drag(event.index, event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        if not _touches.is_empty():
            return
        if event.button_index == MOUSE_BUTTON_LEFT:
            _mouse_drag = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_zoom = clampf(camera_zoom * 1.1, MIN_ZOOM, MAX_ZOOM)
            _apply_frame()
            _announce_camera()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_zoom = clampf(camera_zoom / 1.1, MIN_ZOOM, MAX_ZOOM)
            _apply_frame()
            _announce_camera()
    elif event is InputEventMouseMotion and _mouse_drag and _touches.is_empty():
        camera_yaw = wrapf(camera_yaw + event.relative.x * 0.4, -180.0, 180.0)
        camera_pitch = clampf(camera_pitch - event.relative.y * 0.4, -89.0, 89.0)
        _apply_frame()
        _announce_camera()
