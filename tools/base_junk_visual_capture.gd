extends SceneTree
## Actual 720x1280 Godot software-GL close-up for six live geometry presets.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const Junk = preload("res://scripts/sera_base_junk_geometry.gd")

func _initialize() -> void:
    call_deferred("_run")

func _text(host: Node3D, title: String, at: Vector3) -> void:
    var label := Label3D.new()
    label.name = title.replace(" ", "_")
    label.text = title
    label.font_size = 72
    label.pixel_size = 0.0032
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = Color("#d4e0e5")
    label.position = at
    host.add_child(label)

func _run() -> void:
    var scene := Node3D.new()
    scene.name = "SERA_3D_JUNK_VISUAL_REVIEW"
    root.add_child(scene)
    var ground := MeshInstance3D.new()
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(5.4, 0.12, 8.1)
    ground.mesh = floor_mesh
    ground.position = Vector3(0, -0.11, 0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#28323c")
    mat.metallic = 0.16
    mat.roughness = 0.80
    ground.material_override = mat
    scene.add_child(ground)
    for row in range(9):
        var seam := MeshInstance3D.new()
        var seam_mesh := BoxMesh.new()
        seam_mesh.size = Vector3(5.2, 0.008, 0.016)
        seam.mesh = seam_mesh
        seam.position = Vector3(0, -0.044, -3.7 + float(row) * 0.90)
        var seam_mat := StandardMaterial3D.new()
        seam_mat.albedo_color = Color("#4a5865")
        seam.material_override = seam_mat
        scene.add_child(seam)

    var g := Architecture.Batch.new(scene)
    var panels := [
        Vector2(-0.91, -2.55),
        Vector2(0.92, -2.55),
    ]
    for i in range(panels.size()):
        var p: Vector2 = panels[i]
        # Two overlapping six-sheet models each, just like the live yard.
        Junk.panel_stack(g, p, 1.0, i)
        var elevated := Junk.PANEL_SHAPES
        # preview builds a second actual tilted kit with shifted physical height
        var lifted := Node3D.new()
        lifted.position = Vector3(0, 0.36, 0)
        scene.add_child(lifted)
        var second := Architecture.Batch.new(lifted)
        Junk.panel_stack(second, p, 1.0, i + 1)
        second.flush()
        _text(scene, "PANEL  " + str(i + 1),
            Vector3(p.x, 1.25, p.y))
    for i in range(4):
        var slot_x: float = -0.96 if i % 2 == 0 else 0.98
        var slot_z: float = -0.02 if i < 2 else 2.29
        var spot := Vector3(slot_x, 0, slot_z)
        g.pivot = spot
        g.yaw = deg_to_rad(float(-17 + i * 13))
        Junk.scrap_heap(g, spot, i)
        _text(scene, "SCRAP  " + str(i + 1),
            spot + Vector3(0, 1.08, 0))
    g.flush()

    var light := DirectionalLight3D.new()
    light.rotation = Vector3(-0.85, 0.45, -0.23)
    light.light_energy = 1.55
    scene.add_child(light)
    var fill := DirectionalLight3D.new()
    fill.rotation = Vector3(-0.55, -1.35, 0.20)
    fill.light_energy = 0.55
    scene.add_child(fill)
    var camera := Camera3D.new()
    camera.name = "ReviewCamera"
    scene.add_child(camera)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 8.4
    camera.position = Vector3(4.6, 7.2, 13.0)
    camera.look_at(Vector3(0, 0.37, -0.1))
    camera.current = true

    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var img: Image = root.get_texture().get_image()
    if img == null or img.is_empty():
        push_error("SERA_BASE_JUNK_SCREENSHOT_FAIL: no framebuffer")
        quit(1)
        return
    var dir: String = OS.get_environment("SERA_UI_RENDER_DIR")
    if dir.is_empty():
        push_error("SERA_BASE_JUNK_SCREENSHOT_FAIL: output directory missing")
        quit(1)
        return
    var err: Error = img.save_png(dir.path_join("sera_base_junk_detail.png"))
    if err != OK:
        push_error("SERA_BASE_JUNK_SCREENSHOT_FAIL: cannot save screenshot")
        quit(1)
        return
    print("SERA_BASE_JUNK_SCREENSHOT_PASS: " + str(img.get_size()))
    quit(0)
