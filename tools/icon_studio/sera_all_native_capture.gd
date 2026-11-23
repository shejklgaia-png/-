extends SceneTree
## Offline only: photograph all existing live SeraRig parts using the
## user-approved H02 Godot preset, with the current NEXUS mesh-ID ink.
const RigScript = preload("res://scripts/sera_rig.gd")
const EdgeScript = preload("res://scripts/sera_view_edges.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const PIXELS: int = 512
# The one canonical user preset fixes yaw/pitch/roll/scale/pan for every slot.
# Each icon retains its own authentic source mesh/material and blueprint ID.
const CAMERA_PRESET_PATH: String = "res://assets/ui/sera_icon_presets/H02.json"
const POSE_NAMES = ["NEXUS_pose", "NEXUSpose"]
const SIDE_PADDING: int = 34

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_ALL_NATIVE_ICONS_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMERA_PRESET_PATH))
    if not parsed is Dictionary or str(parsed.get("format", "")) != "SERA_ICON_PRESET_V1":
        _fail("Approved SERA_ICON_PRESET_V1 camera missing")
        return
    var render: Dictionary = parsed.get("render", {})
    var degrees: Dictionary = render.get("model_rotation_deg", {})
    var image_spec: Dictionary = render.get("image", {})
    var pan: Dictionary = render.get("pan_clip", {})
    var auto_fit: float = float(render.get("auto_fit", -1))
    var model_scale: float = float(render.get("model_scale", -1))
    var outline: Dictionary = render.get("outline", {})
    if not is_equal_approx(auto_fit, 0.76) or not is_equal_approx(model_scale, 1.0):
        _fail("Common icon scale deviates from approved 0.76 / 1.0")
        return
    if int(image_spec.get("width", 0)) != PIXELS or int(image_spec.get("height", 0)) != PIXELS or (
            str(image_spec.get("background", "")) != "transparent" or
            bool(image_spec.get("ui_frame_baked", true))):
        _fail("Every icon must be 512px RGBA with no baked background or UI frame")
        return
    if not bool(outline.get("enabled", false)) or (
            float(outline.get("stroke_px_at_512", 0)) != 3.0 or
            float(outline.get("crease_degrees", 0)) != 80.0 or
            str(outline.get("color", "")) != "#17212F"):
        _fail("Approved game ViewEdges 3px / 80 degrees / ink color differs")
        return
    var rotation: Basis = Basis.from_euler(Vector3(
        deg_to_rad(float(degrees.get("x", 0.0))),
        deg_to_rad(float(degrees.get("y", 0.0))),
        deg_to_rad(float(degrees.get("z", 0.0)))), EULER_ORDER_XYZ)
    var pan_clip := Vector3(float(pan.get("x", 0.0)), float(pan.get("y", 0.0)), 0.0)
    if Catalog.PROTOTYPES.size() != 19:
        _fail("Expected 19 actual equipment blueprints")
        return
    var rig: Node3D = RigScript.new()
    root.add_child(rig)
    await process_frame
    if not bool(rig.get("loading_ok")):
        _fail("Real SeraRig failed to load")
        return
    rig.call("set_exhibition_mode", true)
    # Copy true animated joint transforms, never flattened bind-pose parts.
    var clips: Dictionary = rig.get("animations")
    var pose_found: bool = false
    for clip_name in POSE_NAMES:
        if not clips.has(clip_name):
            continue
        var track: Dictionary = clips[clip_name]
        if (track.get("tracks", {}) as Dictionary).is_empty():
            continue
        rig.set("current_clip", clip_name)
        rig.set("clip_time", 0.0)
        rig.set("blending_for", 1.0)
        rig.set("blend_duration", 0.0)
        rig.call("_apply_animation", 0.0)
        pose_found = true
        break
    if not pose_found:
        _fail("Authored NEXUS_pose is required for all portraits")
        return
    rig.set_process(false)
    rig.set_physics_process(false)
    var handler: RefCounted = rig.get("equipment_handler") as RefCounted
    if handler == null:
        _fail("Real SeraRig equipment handler is missing")
        return
    var available: Dictionary = handler.get("available")

    var viewport := SubViewport.new()
    viewport.name = "OfflineEquipmentIconViewport"
    viewport.size = Vector2i(PIXELS, PIXELS)
    viewport.transparent_bg = true
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var scene := Node3D.new()
    viewport.add_child(scene)
    var env := Environment.new()
    env.background_mode = Environment.BG_CLEAR_COLOR
    env.background_color = Color(0.0, 0.0, 0.0, 0.0)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#bbc9e1")
    env.ambient_light_energy = 0.60
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    scene.add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
    sun.light_color = Color("#e3ecff")
    sun.light_energy = 1.7
    sun.shadow_enabled = false
    scene.add_child(sun)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 2.0
    camera.near = 0.01
    camera.far = 100.0
    camera.position = Vector3(0, 0, 10)
    scene.add_child(camera)
    camera.make_current()

    var out_dir: String = ProjectSettings.globalize_path(
        "res://assets/ui/sera_equipment_icons")
    if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
        _fail("Cannot create offline generated equipment icon directory")
        return
    var count: int = 0
    for blueprint in Catalog.ORDER:
        var id: String = str(blueprint)
        var spec: Dictionary = Catalog.spec(id)
        var slot: String = str(spec.get("slot", ""))
        var set_id: String = str(spec.get("rig_set", ""))
        if not available.has(set_id):
            _fail(id + ": real part variant not installed in the SeraRig")
            return
        var pieces: Array = (available[set_id] as Dictionary).get(slot, [])
        if pieces.is_empty():
            _fail(id + ": real part slot has no meshes: " + slot + "/" + set_id)
            return

        var portrait := Node3D.new()
        portrait.name = "Portrait_" + id
        # Identify the cloned real meshes exactly as NEXUS contact targets.
        # Without this meta the compositor assigns generic IDs rather than
        # unique RGB contact IDs, dropping seams between adjacent meshes.
        portrait.set_meta("sera_nexus_id_contact_only", true)
        portrait.set_meta("sera_graphics_outline_category", "part")
        scene.add_child(portrait)
        var spin := Node3D.new()
        portrait.add_child(spin)
        var center_shift := Node3D.new()
        spin.add_child(center_shift)

        var low := Vector3(10000, 10000, 10000)
        var high := Vector3(-10000, -10000, -10000)
        var corners: Array[Vector3] = []
        var mesh_count: int = 0
        for raw in pieces:
            var source: MeshInstance3D = raw as MeshInstance3D
            if source == null or source.mesh == null:
                _fail(id + ": missing authored source mesh")
                return
            var part := MeshInstance3D.new()
            part.name = "NativePart_%02d" % mesh_count
            part.mesh = source.mesh
            part.material_override = source.material_override
            part.transform = source.global_transform
            part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            part.visible = true
            center_shift.add_child(part)
            var bounds: AABB = part.mesh.get_aabb()
            for index in range(8):
                var point: Vector3 = part.transform * bounds.get_endpoint(index)
                low = low.min(point)
                high = high.max(point)
                corners.append(point)
            mesh_count += 1

        var center: Vector3 = (low + high) * 0.5
        spin.basis = rotation
        center_shift.position = -center
        var span_x: float = 0.0
        var span_y: float = 0.0
        for point in corners:
            var p: Vector3 = rotation * (point - center)
            span_x = maxf(span_x, absf(p.x) * 2.0)
            span_y = maxf(span_y, absf(p.y) * 2.0)
        var span: float = maxf(span_x, span_y)
        if span <= 0.00001:
            _fail(id + ": empty mesh bounds")
            return
        spin.scale = Vector3.ONE * (2.0 * auto_fit * model_scale / span)
        spin.position = pan_clip
        # The native NEXUS view now uses a depth-resolved RGB mesh-ID
        # compositor. Enable that exact mode BEFORE registering this root;
        # the legacy inverted-hull shader is not the current icon pipeline.
        var ink: Node3D = EdgeScript.new()
        ink.name = "ViewEdges"
        ink.call("set_nexus_sera_contact_mode", true)
        ink.call("set_stroke_px", 3.0)
        portrait.add_child(ink)
        await process_frame
        # Offline assets must not inherit the user's in-game 'outlines off'
        # preference; force only this private 512px capture compositor on.
        var native_compositor: Node = viewport.get_node_or_null(
            "SeraIDOutlineLayer/SeraIDOutlineControl")
        if native_compositor == null:
            _fail(id + ": NEXUS ID compositor was not registered")
            return
        native_compositor.set("_part_outline_enabled", true)
        native_compositor.set("_scan_elapsed", 0.0)
        # The compositor is deferred and has a separate ID SubViewport.
        # Render several frames before capturing the final composited color.
        for _frame in range(5):
            await RenderingServer.frame_post_draw
        var screenshot: Image = viewport.get_texture().get_image()
        if screenshot == null or screenshot.is_empty():
            _fail(id + ": framebuffer missing")
            return
        screenshot.convert(Image.FORMAT_RGBA8)
        if screenshot.get_width() != PIXELS or screenshot.get_height() != PIXELS:
            _fail(id + ": wrong render size")
            return
        var painted: int = 0
        for y in range(0, PIXELS, 4):
            for x in range(0, PIXELS, 4):
                if screenshot.get_pixel(x, y).a > 0.25:
                    painted += 1
        if painted < 20 or screenshot.get_pixel(0, 0).a > 0.05:
            _fail(id + ": blank or opaque screenshot; painted=" + str(painted))
            return
        var output: String = out_dir.path_join(id + ".png")
        screenshot = _equalize_transparent_margins(screenshot, auto_fit)
        if screenshot == null or screenshot.is_empty():
            _fail(id + ": cannot fit transparent margins")
            return
        if screenshot.save_png(output) != OK:
            _fail(id + ": screenshot file could not be saved")
            return
        print("SERA_NATIVE_EQUIPMENT_ICON_PASS id=%s meshes=%d pixels=%d" %
            [id, mesh_count, painted])
        count += 1
        portrait.queue_free()
        await process_frame
    if count != 19:
        _fail("Expected all nineteen live model captures")
        return
    print("SERA_NATIVE_EQUIPMENT_BATCH_PASS count=19 NEXUS_pose=true approved_preset=true")
    quit(0)

# Pixel-alpha crop is applied after the real native render, not to the
# authoritative 3D mesh. The four *occupied* margins are identical to ±1px.
func _equalize_transparent_margins(source: Image, auto_fit: float) -> Image:
    var left: int = PIXELS
    var right: int = -1
    var top: int = PIXELS
    var bottom: int = -1
    for y in range(PIXELS):
        for x in range(PIXELS):
            var alpha: float = source.get_pixel(x, y).a
            if alpha > 0.10:
                left = mini(left, x)
                right = maxi(right, x)
                top = mini(top, y)
                bottom = maxi(bottom, y)
    if right < left or bottom < top:
        return null
    var width: int = right - left + 1
    var height: int = bottom - top + 1
    # An authored auto_fit of 0.76 occupies at most 76% of the 512px canvas.
    # This preserves symmetric transparent margins without an arbitrary zoom.
    var target_side: int = roundi(PIXELS * auto_fit)
    var factor: float = minf(float(target_side) / float(width),
        float(target_side) / float(height))
    var output_width: int = clampi(roundi(float(width) * factor), 1, target_side)
    var output_height: int = clampi(roundi(float(height) * factor), 1, target_side)
    var crop: Image = source.get_region(Rect2i(left, top, width, height))
    crop.resize(output_width, output_height, Image.INTERPOLATE_LANCZOS)
    var composed: Image = Image.create(
        PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
    composed.fill(Color.TRANSPARENT)
    composed.blit_rect(crop, Rect2i(0, 0, output_width, output_height),
        Vector2i((PIXELS - output_width) / 2,
            (PIXELS - output_height) / 2))
    return composed
