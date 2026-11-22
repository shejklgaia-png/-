extends SceneTree
## Premerge profiling harness. Run under OpenGL with a real viewport for
## comparable FPS/draw-call data; headless metrics are NOT Android GPU proof.
const SLOW = preload("res://shaders/sera_view_edges.gdshader")
const FAST = preload("res://shaders/sera_view_edges_fast.gdshader")
const CULLING = preload("res://scripts/sera_face_culling.gd")

const SAMPLES: int = 72
const WARMUP: int = 20
var _pieces: Array[MeshInstance3D] = []
var _overlays: Array[MeshInstance3D] = []

func _initialize() -> void:
    call_deferred("_run")

func _set_mode(optimized: bool) -> void:
    for piece in _pieces:
        var mat: StandardMaterial3D = piece.material_override as StandardMaterial3D
        mat.cull_mode = BaseMaterial3D.CULL_BACK if optimized else BaseMaterial3D.CULL_DISABLED
    for overlay in _overlays:
        var mat: ShaderMaterial = overlay.material_override as ShaderMaterial
        mat.shader = FAST if optimized else SLOW

func _sample(optimized: bool) -> Dictionary:
    _set_mode(optimized)
    for frame in range(WARMUP):
        await process_frame
    var cpu_t0: int = Time.get_ticks_usec()
    var draw_count: float = 0.0
    var primitive_count: float = 0.0
    var fps_sum: float = 0.0
    for frame in range(SAMPLES):
        await process_frame
        draw_count += float(RenderingServer.get_rendering_info(
            RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
        primitive_count += float(RenderingServer.get_rendering_info(
            RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
        fps_sum += Engine.get_frames_per_second()
    var ms: float = float(Time.get_ticks_usec() - cpu_t0) / 1000.0
    return {
        "mode": "optimized" if optimized else "baseline",
        "frames": SAMPLES,
        "wall_ms_per_frame": ms / float(SAMPLES),
        "render_draw_calls": draw_count / float(SAMPLES),
        "render_primitives": primitive_count / float(SAMPLES),
        "engine_fps": fps_sum / float(SAMPLES),
        "shader_depth_samples_per_fragment": 0 if optimized else 5
    }

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var camera := Camera3D.new()
    camera.position = Vector3(0.0, 6.0, 22.0)
    camera.look_at(Vector3(0.0, 0.0, 0.0))
    camera.current = true
    world.add_child(camera)
    var source_mesh := BoxMesh.new()
    # Identical repeated meshes and positions in both runs.
    var shell: ArrayMesh = CULLING.create_test_hull(source_mesh)
    if shell == null:
        push_error("SERA_RENDER_BENCH_FAIL: missing shell")
        quit(1)
        return
    for i in range(36):
        var piece := MeshInstance3D.new()
        piece.mesh = source_mesh
        piece.position = Vector3(float(i % 6) * 1.9 - 4.75,
            float(i / 6) * 1.6 - 4.0, 0.0)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.45, 0.55, 0.62)
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        piece.material_override = mat
        world.add_child(piece)
        _pieces.append(piece)
        var overlay := MeshInstance3D.new()
        overlay.mesh = shell
        var ink := ShaderMaterial.new()
        ink.shader = SLOW
        ink.set_shader_parameter("stroke_px", 3.0)
        overlay.material_override = ink
        piece.add_child(overlay)
        _overlays.append(overlay)
    await process_frame
    var baseline: Dictionary = await _sample(false)
    var optimized: Dictionary = await _sample(true)
    # A second pass detects systematic order/thermal effects.
    var reverse_optimized: Dictionary = await _sample(true)
    var reverse_baseline: Dictionary = await _sample(false)
    var results := {"renderer": ProjectSettings.get_setting(
            "rendering/renderer/rendering_method", "unknown"),
        "baseline": baseline, "optimized": optimized,
        "optimized_second": reverse_optimized, "baseline_second": reverse_baseline,
        "note": "GPU timing unavailable in headless/OpenGL; Android physical FPS must be measured separately."}
    print("SERA_RENDER_PROFILE " + JSON.stringify(results))
    world.queue_free()
    await process_frame
    print("SERA_RENDER_PERFORMANCE_BENCHMARK_PASS")
    quit(0)
