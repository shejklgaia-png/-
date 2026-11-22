extends SceneTree
## The only approved 6px diagnostic is explicit and reversible.
const BASE_INK = preload("res://scripts/sera_base_facility_outlines.gd")
const SAFE = preload("res://shaders/base_facility_silhouette_edges.gdshader")
const FAST = preload("res://shaders/base_facility_silhouette_edges.gdshader")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BASE_OUTLINE_PROBE_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _frame in range(150):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
                hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") != null):
            break
    var button: Button = hub.get_node_or_null(
        "BaseHUDLayer/BaseHUD/LayoutTools/OutlineProbeButton") as Button
    if button == null or not button.text.contains("輪郭検査"):
        _fail("user cannot open visible outline diagnostic; source may be stale")
        return
    var mat: ShaderMaterial = BASE_INK.material()
    if mat.shader != SAFE or mat.get_shader_parameter("ink_color") != Color("#000000") or (
            bool(mat.get_shader_parameter("force_all_edges"))):
        _fail("normal black 6px facility silhouette was changed")
        return
    hub.call("_cycle_outline_probe")
    if mat.shader != SAFE or mat.get_shader_parameter("ink_color") != Color("#ff00ff"):
        _fail("pink selected-contour probe does not use the actual production shader")
        return
    hub.call("_cycle_outline_probe")
    if mat.shader != FAST or mat.get_shader_parameter("ink_color") != Color("#ff00ff") or (
            not bool(mat.get_shader_parameter("force_all_edges"))):
        _fail("pink all-edge probe must reveal geometry for diagnosis")
        return
    hub.call("_cycle_outline_probe")
    if mat.shader != SAFE or mat.get_shader_parameter("ink_color") != Color("#000000"):
        _fail("diagnostic did not restore production black shader")
        return
    if not is_equal_approx(float(mat.get_shader_parameter("stroke_px")), 6.0):
        _fail("reversible probe changed approved six-pixel stroke")
        return
    print("SERA_BASE_OUTLINE_PROBE_RUNTIME_PASS safe/masked and fast/no-depth switching")
    quit(0)
