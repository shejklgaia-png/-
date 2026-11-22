extends SceneTree
const FACILITY_SHADER = preload("res://shaders/sera_view_edges.gdshader")
const CREASE_SHADER = preload("res://shaders/base_facility_view_edges.gdshader")
## Acceptance: real BASE scene, actual screen-space strokes, solid-only model
## metadata, 8 door shafts, two live chimney plumes and animated floor bounce.
const FACILITIES: Array[String] = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL"
]
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_BASE_FX_OUTLINE_FAIL: " + message)
    quit(1)
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _step in range(140):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
                hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null):
            break
    if hub.get_node_or_null("BaseStartupOverlay") != null:
        _fail("real BASE did not boot")
        return
    var cam: Camera3D = hub.get("cam") as Camera3D
    if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("normal BASE camera changed")
        return
    if hub.get_node_or_null("BaseHUDLayer/BaseHUD/FacilityOutlines") != null:
        _fail("obsolete oversized screen-space cage is still present")
        return
    for key in FACILITIES:
        var model: Node3D = hub.get_node(
            "NEXUSBuilding/NexusArchitecture" if key == "NEXUS" else (
            "BaseFacilities/" + key + "/IndustrialModel")) as Node3D
        var entries: Array = model.get_meta("outline_solid_entries", [])
        if entries.size() < 18:
            _fail(key + " missing real solid architecture to outline")
            return
        for item in entries:
            var tint: String = str((item as Dictionary).get("tint", ""))
            if tint in ["blue_light", "amber_light", "amber", "glass"]:
                _fail(key + " emissive appearance entered solid-only mask")
                return
        var ink_count: int = 0
        var crease_count: int = 0
        for piece in model.get_children():
            if not piece is MultiMeshInstance3D:
                continue
            if str(piece.name).begins_with("ArchitecturalCreaseInk_"):
                var crease: MultiMeshInstance3D = piece as MultiMeshInstance3D
                crease_count += (crease.multimesh.instance_count
                    if crease.multimesh != null else 0)
                var corner_mat: ShaderMaterial = crease.material_override as ShaderMaterial
                if corner_mat == null or corner_mat.shader != CREASE_SHADER or (
                        not is_equal_approx(float(
                        corner_mat.get_shader_parameter("crease_px")), 2.0)):
                    _fail(key + " old 2px corner line changed")
                    return
                if corner_mat.get_shader_parameter("ink_color") != Color("#353535"):
                    _fail(key + " 2px polygon corners must be dark gray")
                    return
                continue
            if not str(piece.name).begins_with("ArchitecturalEdgeInk_"):
                continue
            var ink: MultiMeshInstance3D = piece as MultiMeshInstance3D
            ink_count += ink.multimesh.instance_count if ink.multimesh != null else 0
            var shaded: ShaderMaterial = ink.material_override as ShaderMaterial
            if shaded == null or shaded.shader != FACILITY_SHADER or (
                    not is_equal_approx(float(
                    shaded.get_shader_parameter("stroke_px")), 6.0)):
                _fail(key + " not using latest SERA inverted hull at 6px")
                return
            if shaded.get_shader_parameter("ink_color") != Color("#000000"):
                _fail(key + " 6px SERA silhouette must be black")
                return
        if ink_count < 18 or crease_count != ink_count:
            _fail(key + " 6px hull or original 2px crease missing")
            return
        var fx: Node3D = model.get_node_or_null("BaseFacilityVFX") as Node3D
        if fx == null:
            _fail(key + " VFX handler missing")
            return
        var entrance: MeshInstance3D = fx.get_node_or_null(
            "DoorLightLeak") as MeshInstance3D
        var floor: MeshInstance3D = fx.get_node_or_null(
            "DoorLightFloor") as MeshInstance3D
        if entrance == null or floor == null or (
                not entrance.material_override is ShaderMaterial) or (
                not floor.material_override is ShaderMaterial):
            _fail(key + " portal not illuminated with two independent VFX layers")
            return
        if model.get_meta("base_design", "") == "ARCHIVED_20261122" and key != "NEXUS":
            _fail("7 new angular stations must remain unchanged")
            return
    var smelter: Node3D = hub.get_node("BaseFacilities/SMELTER/IndustrialModel")
    var vfx: Node3D = smelter.get_node("BaseFacilityVFX")
    var smoke: Node3D = vfx.get_node_or_null("SmelterChimneySmoke")
    if smoke == null or smoke.get_child_count() != 2:
        _fail("need two separately positioned chimney plumes")
        return
    for plume in smoke.get_children():
        var smoke_particle: CPUParticles3D = plume as CPUParticles3D
        if smoke_particle == null or not smoke_particle.emitting or (
                smoke_particle.amount < 10) or smoke_particle.mesh == null:
            _fail("live smoke is not emitting translucent particles")
            return
    var bounce: MeshInstance3D = vfx.get_node_or_null(
        "SmelterFireFloorReflection") as MeshInstance3D
    if bounce == null or not bounce.material_override is ShaderMaterial:
        _fail("ground reflection shader not assigned")
        return
    var fire: OmniLight3D = smelter.get_node_or_null(
        "FurnaceHeatLight") as OmniLight3D
    if fire == null or not vfx.has_method("sample_fire"):
        _fail("existing furnace light not tied to reflection")
        return
    vfx.call("sample_fire", 0.0)
    var power_before: float = fire.light_energy
    vfx.call("sample_fire", 0.41)
    var power_after: float = fire.light_energy
    if absf(power_before - power_after) < 0.05:
        _fail("furnace light does not pulse with the floor shader")
        return
    if hub.get_node("NEXUSBuilding/NexusArchitecture").get_meta(
            "base_design", "") != "ARCHIVED_20261122":
        _fail("two-versions-ago NEXUS model was overwritten")
        return
    print("SERA_BASE_FX_PIXEL_OUTLINES_RUNTIME_PASS 8x6px+2px, 8 door portals, 2 smoke emitters, floor flicker")
    quit(0)
