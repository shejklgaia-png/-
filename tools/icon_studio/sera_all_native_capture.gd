extends SceneTree
## Offline only: photograph every installed real SeraRig part with the SERA
## GL Compatibility renderer. The authored H02 preset is handled separately.
const RigScript = preload("res://scripts/sera_rig.gd")
const EdgeScript = preload("res://scripts/sera_view_edges.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const PIXELS: int = 512
const ANGLES: Dictionary = {
    "head": Vector3(-14.0, 28.0, 0.0),
    "torso": Vector3(-12.0, 31.0, 0.0),
    "arms": Vector3(-10.0, 34.0, 0.0),
    "legs": Vector3(-6.0, 29.0, 0.0),
    "booster": Vector3(-11.0, 155.0, 0.0),
    "weapon_r": Vector3(-15.0, 37.0, 0.0),
    "weapon_l": Vector3(-12.0, 34.0, 0.0)
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_ALL_NATIVE_ICONS_FAIL: " + reason)
    quit(1)

func _run() -> void:
    if Catalog.PROTOTYPES.size() != 19:
        _fail("Expected 19 actual equipment blueprints")
        return
    var rig: Node3D = RigScript.new()
    root.add_child(rig)
    await process_frame
    if not bool(rig.get("loading_ok")):
        _fail("Real SeraRig failed to load")
        return
    rig.set_process(false)
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
        if id == "H02":
            continue # Preserve authored IRIS preset/capture in its dedicated script.
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
        var degrees: Vector3 = ANGLES.get(slot, Vector3(-12, 30, 0))
        if id == "WR03":
            degrees = Vector3(-14, 48, 0)
        var rotation: Basis = Basis.from_euler(Vector3(
            deg_to_rad(degrees.x), deg_to_rad(degrees.y),
            deg_to_rad(degrees.z)), EULER_ORDER_XYZ)
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
        spin.scale = Vector3.ONE * (1.64 / span)
        var ink: Node3D = EdgeScript.new()
        ink.name = "ViewEdges"
        portrait.add_child(ink)
        await process_frame
        await RenderingServer.frame_post_draw
        await RenderingServer.frame_post_draw
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
        if screenshot.save_png(output) != OK:
            _fail(id + ": screenshot file could not be saved")
            return
        print("SERA_NATIVE_EQUIPMENT_ICON_PASS id=%s meshes=%d pixels=%d" %
            [id, mesh_count, painted])
        count += 1
        portrait.queue_free()
        await process_frame
    if count != 18:
        _fail("Expected eighteen extra captures plus the dedicated IRIS")
        return
    print("SERA_NATIVE_EQUIPMENT_BATCH_PASS count=18 plus IRIS=1")
    quit(0)
