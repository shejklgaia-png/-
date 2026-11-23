extends SceneTree
## Native equipment portrait: the SAME SeraRig mesh/UV/material and ViewEdges
## NEXUS visible-mesh-ID outlines as the game, under native lighting.
## Run with Godot GL Compatibility in a real display.
## The browser preset remains the camera/position authority; no external
## renderer, artificial 3D re-meshing, or runtime on-device icon generation.
const RigScript = preload("res://scripts/sera_rig.gd")
const EdgeScript = preload("res://scripts/sera_view_edges.gd")
const PRESET_PATH: String = "res://assets/ui/sera_icon_presets/H02.json"
const MODEL_PATH: String = "res://models/storage/カメラアイ頭部.bbmodel"
const PIXELS: int = 512


func _initialize() -> void:
    call_deferred("_capture")


func _fail(message: String) -> void:
    push_error("SERA_NATIVE_ICON_CAPTURE_FAIL: " + message)
    quit(1)


func _capture() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESET_PATH))
    if not parsed is Dictionary:
        _fail("SERA_ICON_PRESET_V1 not found")
        return
    var preset: Dictionary = parsed
    var identity: Dictionary = preset.get("equipment", {})
    var render: Dictionary = preset.get("render", {})
    var source_info: Dictionary = preset.get("source", {})
    if str(preset.get("format", "")) != "SERA_ICON_PRESET_V1" or (
            str(identity.get("blueprint_id", "")) != "H02" or
            str(identity.get("slot", "")) != "head" or
            str(identity.get("rig_set", "")) != "D"):
        _fail("H02 identity invalid")
        return
    if str(source_info.get("repository_path", "")) != (
            "models/storage/カメラアイ頭部.bbmodel"):
        _fail("H02 source is not the canonical head D")
        return
    var authored: String = FileAccess.get_file_as_string(MODEL_PATH)
    if authored.is_empty() or authored.sha256_text() != str(source_info.get("fingerprint", "")):
        _fail("Source fingerprint does not match the user's approved preset")
        return
    var image_spec: Dictionary = render.get("image", {})
    if int(image_spec.get("width", 0)) != PIXELS or (
            int(image_spec.get("height", 0)) != PIXELS or
            str(image_spec.get("background", "")) != "transparent"):
        _fail("Expected a transparent 512x512 screenshot")
        return

    # Build real SERA equipment first, preserving the 16px texture, original
    # mesh surfaces, UVs, game material and the normal HEAD D mesh path.
    var source_scene := Node3D.new()
    source_scene.name = "NativeIconSourceRig"
    root.add_child(source_scene)
    var rig: Node3D = RigScript.new()
    source_scene.add_child(rig)
    await process_frame
    if not bool(rig.get("loading_ok")):
        _fail("Real SERA animation rig failed to load")
        return
    var handler: RefCounted = rig.get("equipment_handler") as RefCounted
    if handler == null:
        _fail("No equipment handler on the real rig")
        return
    var available: Dictionary = handler.get("available")
    var head_d: Dictionary = available.get("D", {})
    var source_meshes: Array = head_d.get("head", [])
    var source_pivot: Node3D = rig.get_node_or_null(
        "Waist/Torso/Chest/Neck/Head/CameraEyeHeadD") as Node3D
    if source_pivot == null or source_meshes.size() != 6:
        _fail("The canonical HEAD D has no six-mesh runtime assembly")
        return

    var viewport := SubViewport.new()
    viewport.name = "NativeIconViewport"
    viewport.size = Vector2i(PIXELS, PIXELS)
    viewport.transparent_bg = true
    viewport.own_world_3d = true
    viewport.disable_3d = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)

    var world := Node3D.new()
    viewport.add_child(world)

    # Combat-stage light/environment as defined in main.gd:_build_world().
    # These are the actual game values, not the old browser's fake Lambert.
    var env := Environment.new()
    env.background_mode = Environment.BG_CLEAR_COLOR
    env.background_color = Color(0.0, 0.0, 0.0, 0.0)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#bbc9e1")
    env.ambient_light_energy = 0.60
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    world.add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
    sun.light_color = Color("#e3ecff")
    sun.light_energy = 1.7
    sun.shadow_enabled = false
    world.add_child(sun)

    var camera := Camera3D.new()
    camera.name = "OrthographicPortraitCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 2.0
    camera.near = 0.01
    camera.far = 20.0
    camera.position = Vector3(0.0, 0.0, 5.0)
    world.add_child(camera)
    camera.make_current()

    var portrait := Node3D.new()
    portrait.name = "PortraitHeadD"
    world.add_child(portrait)
    var spin := Node3D.new()
    spin.name = "PresetRotationAndPan"
    portrait.add_child(spin)
    var center_shift := Node3D.new()
    center_shift.name = "CenterCanonicalMesh"
    spin.add_child(center_shift)

    var low := Vector3(10000.0, 10000.0, 10000.0)
    var high := Vector3(-10000.0, -10000.0, -10000.0)
    var count: int = 0
    for source in source_meshes:
        if not source is MeshInstance3D or source.mesh == null:
            _fail("Broken runtime HEAD D mesh")
            return
        var part := MeshInstance3D.new()
        part.name = "CameraEye_" + str(count)
        part.mesh = source.mesh
        part.material_override = source.material_override
        # Include the actual D fitting transform applied by the game.
        # The orthographic fit absorbs its uniform global scale.
        part.transform = source_pivot.transform * source.transform
        part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        part.visible = true
        center_shift.add_child(part)
        var local_bounds: AABB = part.mesh.get_aabb()
        for corner in range(8):
            var point: Vector3 = part.transform * local_bounds.get_endpoint(corner)
            low = low.min(point)
            high = high.max(point)
        count += 1
    if count != 6:
        _fail("HEAD D model was not cloned completely")
        return

    var center: Vector3 = (low + high) * 0.5
    var extent: Vector3 = high - low
    var longest: float = maxf(extent.x, maxf(extent.y, extent.z))
    if longest <= 0.00001:
        _fail("Head D mesh bounds are empty")
        return

    # Icon Studio's rotatePoint is explicitly X then Y then Z.
    # Godot's default Node3D Euler is YXZ: use XYZ on a Basis instead.
    var degrees: Dictionary = render.get("model_rotation_deg", {})
    spin.basis = Basis.from_euler(Vector3(
        deg_to_rad(float(degrees.get("x", 0.0))),
        deg_to_rad(float(degrees.get("y", 0.0))),
        deg_to_rad(float(degrees.get("z", 0.0)))),
        EULER_ORDER_XYZ)
    center_shift.position = -center
    spin.scale = Vector3.ONE * (2.0 * float(render.get("auto_fit", 0.82)) /
        longest * float(render.get("model_scale", 1.0)))
    var pan: Dictionary = render.get("pan_clip", {})
    spin.position = Vector3(float(pan.get("x", 0.0)),
        float(pan.get("y", 0.0)), 0.0)

    # Match the current NEXUS visible-mesh-ID/depth contact compositor.
    # The former inverted-hull edge shader is not the active rendering path.
    var ink: Node3D = EdgeScript.new()
    ink.name = "ViewEdges"
    ink.call("set_nexus_sera_contact_mode", true)
    ink.call("set_stroke_px", 3.0)
    portrait.add_child(ink)
    await process_frame
    for _frame in range(5):
        await RenderingServer.frame_post_draw

    var image: Image = viewport.get_texture().get_image()
    if image == null or image.is_empty():
        _fail("Godot framebuffer readback failed")
        return
    if image.get_width() != PIXELS or image.get_height() != PIXELS:
        _fail("Framebuffer dimensions invalid")
        return
    image.convert(Image.FORMAT_RGBA8)
    var painted: int = 0
    for y in range(0, PIXELS, 8):
        for x in range(0, PIXELS, 8):
            if image.get_pixel(x, y).a > 0.25:
                painted += 1
    if painted < 350 or image.get_pixel(0, 0).a > 0.05:
        _fail("Empty/opaque portrait (check GL rendering and transparency)")
        return

    var output_dir: String = OS.get_environment("SERA_UI_RENDER_DIR")
    if output_dir.is_empty():
        output_dir = OS.get_user_data_dir()
    if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
        _fail("Unable to create output directory")
        return
    var output_path: String = output_dir.path_join("SERA_H02_IRIS_GODOT_512.png")
    if image.save_png(output_path) != OK:
        _fail("Unable to write the Godot-native portrait")
        return
    print("SERA_GODOT_NATIVE_ICON_PASS %s opaque_samples=%d" %
        [output_path, painted])
    quit(0)
