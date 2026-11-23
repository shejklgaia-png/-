extends SceneTree
## Offline only: photograph all existing live SeraRig parts using the
## user-approved H02 Godot preset, with the current NEXUS mesh-ID ink.
## Capture profiles: full 512px, warehouse native 82px, craft native 96px.
## All profiles render at 4x and reconstruct ink at final integer pixels.
const RigScript = preload("res://scripts/sera_rig.gd")
const EdgeScript = preload("res://scripts/sera_view_edges.gd")
const ConvexGeometry = preload("res://scripts/sera_base_facility_crease_geometry.gd")
const IconConvexInk = preload("res://shaders/sera_icon_capture_convex_ink.gdshader")
const PixelReconstruction = preload("res://tools/icon_studio/sera_pixel_outline_reconstruction.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const PIXELS: int = 512
const SUPERSAMPLE: int = 4
# Capture-only widths, never applied to live BASE/NEXUS/battle rendering.
const ICON_INNER_PX: float = 1.0
const ICON_OUTER_PX: float = 4.0
const ICON_CONVEX_PX: float = 3.0
const ICON_SEAM_PX: float = 2.0
# These are photographed independently by Godot at their FINAL thumbnail
# resolutions; never downsample the full-resolution thick NEXUS silhouette.
# Warehouse drops dense subpixel seams to keep narrow silhouettes readable.
const CAPTURE_PROFILES = [
    {"name": "full", "pixels": 512, "inner": 1.0, "outer": 4.0,
        "convex": 3.0, "seam": 2.0},
    {"name": "warehouse", "pixels": 82, "inner": 1.0, "outer": 1.25,
        "convex": 0.75, "seam": 0.75},
    {"name": "craft", "pixels": 96, "inner": 1.0, "outer": 1.5,
        "convex": 1.0, "seam": 1.0},
]
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
    # Three-dimensional foreground convex ribbons are drawn only while
    # producing offline PNGs; the game's runtime compositor is unmodified.
    var convex_material := ShaderMaterial.new()
    convex_material.shader = IconConvexInk
    convex_material.render_priority = -28
    convex_material.set_shader_parameter("ink_color", Color("#17212f"))
    convex_material.set_shader_parameter("crease_px", ICON_CONVEX_PX)

    var out_dir: String = ProjectSettings.globalize_path(
        "res://assets/ui/sera_equipment_icons")
    if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
        _fail("Cannot create offline generated equipment icon directory")
        return
    for profile_spec in CAPTURE_PROFILES:
        var profile_name: String = str(profile_spec["name"])
        if profile_name == "full":
            continue
        if DirAccess.make_dir_recursive_absolute(
                out_dir.path_join(profile_name)) != OK:
            _fail("Cannot create offline icon profile " + profile_name)
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
        var convex_nodes: Array[MeshInstance3D] = []
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
            # Physical corner ribbons come from the *same* authored mesh.
            # The shader filters to sharp, camera-visible convex front/front
            # edges; ordinary seams and silhouettes remain mesh-ID based.
            var convex_mesh: ArrayMesh = ConvexGeometry._build_overlay(source.mesh)
            if convex_mesh != null:
                var convex := MeshInstance3D.new()
                convex.name = "NativeConvexInk_%02d" % mesh_count
                convex.mesh = convex_mesh
                convex.material_override = convex_material
                convex.transform = source.global_transform
                convex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                convex.set_meta("sera_skip_common_id_outline", true)
                convex.set_meta("FX_NO_OUTLINE", true)
                center_shift.add_child(convex)
                convex_nodes.append(convex)
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
        # The same real 3D rig is captured separately for three UI sizes.
        # Runtime NEXUS shaders remain untouched; only this SubViewport has
        # an icon-specific visible-ID material and convex corner ribbons.
        # The latest NEXUS contact compositor uses a CanvasLayer ink rect,
        # NOT a spatial _screen_material. The final-pixel reconstruction
        # reads the RGB visible-ID buffer directly, so suppress the canvas
        # ink during both source passes and keep only convex 3D ribbons
        # in the second one. Do not modify any runtime shaders.
        var icon_id_viewport: SubViewport = native_compositor.get(
            "id_viewport") as SubViewport
        var canvas_ink: TextureRect = native_compositor.get(
            "ink") as TextureRect
        if icon_id_viewport == null or canvas_ink == null or (
                not canvas_ink.material is ShaderMaterial):
            _fail(id + ": native visible-ID viewport or canvas ink is missing")
            return
        var canvas_ink_material: ShaderMaterial = (
            canvas_ink.material as ShaderMaterial)
        canvas_ink_material.set_shader_parameter(
            "ink_color", Color(0.0, 0.0, 0.0, 0.0))

        for profile_spec in CAPTURE_PROFILES:
            var profile_name: String = str(profile_spec["name"])
            var target_px: int = int(profile_spec["pixels"])
            var capture_px: int = target_px * SUPERSAMPLE
            viewport.size = Vector2i(capture_px, capture_px)
            # The color/depth/mesh-ID render uses four times the final
            # resolution. Stroke geometry is provisional; final ink is
            # reconstructed from the visible IDs at the TARGET pixel grid.
            convex_material.set_shader_parameter(
                "crease_px", float(profile_spec["convex"]) * SUPERSAMPLE)

            # Capture original mesh shading without ink for clean per-pixel
            # color and alpha. No 3D changes are made to the real equipment.
            for ribbon in convex_nodes:
                ribbon.visible = false
            native_compositor.set("_scan_elapsed", 0.0)
            for _frame in range(6):
                await RenderingServer.frame_post_draw
            var bare: Image = viewport.get_texture().get_image()
            var ids: Image = icon_id_viewport.get_texture().get_image()
            if bare == null or ids == null or bare.is_empty() or ids.is_empty():
                _fail(id + "/" + profile_name + ": source or ID frame missing")
                return
            if bare.get_size() != Vector2i(capture_px, capture_px) or (
                    ids.get_size() != bare.get_size()):
                _fail(id + "/" + profile_name + ": high-resolution ID size mismatch")
                return
            bare.convert(Image.FORMAT_RGBA8)
            ids.convert(Image.FORMAT_RGBA8)

            # One additional inked native pass preserves the authored
            # camera-visible convex ribbons. Edges are never resized after
            # being finalized at the output PNG's integer-pixel resolution.
            for ribbon in convex_nodes:
                ribbon.visible = true
            native_compositor.set("_scan_elapsed", 0.0)
            for _frame in range(6):
                await RenderingServer.frame_post_draw
            var inked: Image = viewport.get_texture().get_image()
            if inked == null or inked.is_empty() or inked.get_size() != bare.get_size():
                _fail(id + "/" + profile_name + ": ink frame missing")
                return
            inked.convert(Image.FORMAT_RGBA8)
            var screenshot: Image = PixelReconstruction.reconstruct(
                bare, inked, ids, target_px, auto_fit, profile_spec)
            if screenshot == null or screenshot.is_empty():
                _fail(id + "/" + profile_name + ": reconstruction failed")
                return
            var painted: int = 0
            var sample_stride: int = 4 if target_px >= 512 else 2
            for y in range(0, target_px, sample_stride):
                for x in range(0, target_px, sample_stride):
                    if screenshot.get_pixel(x, y).a > 0.25:
                        painted += 1
            if painted < 20 or screenshot.get_pixel(0, 0).a > 0.05:
                _fail(id + "/" + profile_name +
                    ": blank or opaque screenshot; painted=" + str(painted))
                return
            var output: String = out_dir.path_join(id + ".png")
            if profile_name != "full":
                output = out_dir.path_join(profile_name).path_join(id + ".png")
            if screenshot.save_png(output) != OK:
                _fail(id + "/" + profile_name +
                    ": reconstructed PNG could not be saved")
                return
            print("SERA_NATIVE_EQUIPMENT_ICON id=%s profile=%s px=%d super=%d meshes=%d painted=%d" %
                [id, profile_name, target_px, SUPERSAMPLE, mesh_count, painted])
        count += 1
        portrait.queue_free()
        await process_frame
    if count != 19:
        _fail("Expected all nineteen live model captures")
        return
    print("SERA_NATIVE_EQUIPMENT_BATCH_PASS count=19 profiles=3 images=57 NEXUS_pose=true approved_preset=true")
    quit(0)
