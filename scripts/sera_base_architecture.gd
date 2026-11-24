extends RefCounted
const BaseClutter = preload("res://scripts/sera_base_clutter.gd")
const BasePolish = preload("res://scripts/sera_base_reference_polish.gd")
const BaseSilhouette = preload("res://scripts/sera_base_silhouette_refinement.gd")
const BaseFinish = preload("res://scripts/sera_base_functional_finish.gd")
const BaseNightFacade = preload("res://scripts/sera_base_night_facade.gd")
const BaseStructuralMass = preload("res://scripts/sera_base_structural_mass.gd")
const BaseRoofIdentity = preload("res://scripts/sera_base_roof_identity.gd")
const BaseFreshDesign = preload("res://scripts/sera_base_fresh_design.gd")
const BaseFacilityMotion = preload("res://scripts/sera_base_facility_motion.gd")
const BaseFacilityVfx = preload("res://scripts/sera_base_facility_vfx.gd")
const ACTIVE_BASE_MODEL: String = "FRESH_20261122"
# Keep the established command-bunker design family rather than the FRESH alternative.
const ARCHIVED_NEXUS_MODEL: bool = true
const BasePolygon = preload("res://scripts/sera_base_polygon_meshes.gd")
const WEATHERED_STEEL_PATH: String = "res://assets/base/industrial_steel_grunge.svg"
const WEATHERED_CANVAS_PATH: String = "res://assets/base/aged_canvas_weave.svg"
const WEATHERED_ARMOR_PATH: String = "res://assets/base/industrial_armor_chipped.svg"
const WEATHERED_OXIDE_PATH: String = "res://assets/base/industrial_oxidized_metal.svg"
## Industrial reference rebuild for the eight individually modelled base structures.
## Batched opaque meshes keep a dense kit-bashed silhouette on Android GL.
const COLORS = {
    "dark": "#202934", "void": "#121d27", "armor": "#53616f",
    "armor_light": "#72808c", "slate": "#3b4a59", "edge": "#84909a",
    "trim": "#303e4c", "crate": "#5a6573", "rubber": "#242b31",
    "gold": "#a98448", "caution": "#c4a35f", "cloth": "#68685f",
    "rust": "#785644", "blue": "#357d95", "blue_light": "#81d6ed",
    "lab_cyan": "#b6eeff",
    "amber": "#dd8647", "amber_light": "#ffc18b", "glass": "#276076",
    # Separate emissive materials for the generator cavity and terminal LCD.
    # Their opacity and correct depth test preserve the physical vent masks.
    "generator_emitter": "#a7eaff", "terminal_monitor": "#449fc9",
    "white": "#b3c1c8"
}

# Every facility's main entrance / operating face is on local +Z.
# The camera sees the yard from horizontal azimuth ~37.67 deg. Face the
# camera FIRST so all eight entrances are readable, then apply a restrained
# yaw toward the SCREEN center (not toward the world-space plaza center).
# Screen-left sites use yaw > 37.67; screen-right sites yaw < 37.67.
# NEXUS/LABO remain nearly frontal. All eight yaw values are deliberately
# different. Models, pads, light posts and rotor use the same per-site yaw;
# props keep their own separate deterministic rotation pivots.
const BODY_YAW_DEGREES = {
    "NEXUS": 33.0, "LABO": 44.0, "SMELTER": 60.0,
    "RECYCLER": 16.0, "STORAGE": 63.0, "GENERATOR": 12.0,
    "SCRAP_COLLECTOR": 56.0, "BUILD_TERMINAL": 20.0,
}

static func facility_yaw_radians(key: String) -> float:
    return deg_to_rad(float(BODY_YAW_DEGREES.get(key, 0.0)))

class Batch:
    var host: Node3D
    var entries: Dictionary = {}
    var features: Array[String] = []
    var yaw: float = 0.0
    var pivot: Vector3 = Vector3.ZERO
    # Optional per-salvage uniform scale; equipment models stay at 1x.
    var detail_scale: float = 1.0
    # Seven outdoor machines use rectangular, sharp 90-degree mesh edges.
    # The NEXUS command bunker deliberately retains shaped bevels.
    var hard_edges: bool = false
    # Only selected machine features record their existing batched instance slots.
    var motion_names: Array = []
    var motion_indices: Dictionary = {}
    # Architectural solid mask; FX is built later in separate nodes.
    var outline_enabled: bool = false
    var outline_entries: Array[Dictionary] = []

    func _init(node: Node3D) -> void:
        host = node

    func _put(feature: String, kind: String, tint: String, basis: Basis,
            at: Vector3) -> void:
        var resolved_kind: String = kind
        # Structural bevels and thin rods stay rectilinear, while true
        # machine shapes (gears, hollow chutes, canvas, stacks and hoods)
        # keep their generated triangle topology instead of cube fallbacks.
        if hard_edges and kind in ["bevel", "tube"]:
            resolved_kind = "cube"
        var key: String = resolved_kind + "|" + tint
        if not entries.has(key):
            entries[key] = []
        # A whole 3D subassembly rotates about its own pivot, including boxes,
        # angled rods, rings and multilayer crates; batching remains intact.
        var spin := Basis(Vector3.UP, yaw)
        var moved: Vector3 = pivot + spin * ((at - pivot) * detail_scale)
        var pose := Transform3D(
            spin * basis.scaled_local(Vector3.ONE * detail_scale), moved)
        (entries[key] as Array).append(pose)
        if outline_enabled and tint not in [
                "blue_light", "lab_cyan", "amber_light", "amber", "glass",
                "generator_emitter", "terminal_monitor"]:
            outline_entries.append({
                "feature": feature, "tint": tint, "pose": pose,
                "bucket": key, "index": (entries[key] as Array).size() - 1})
        if motion_names.has(feature):
            if not motion_indices.has(feature):
                motion_indices[feature] = []
            (motion_indices[feature] as Array).append({
                "bucket": key, "index": (entries[key] as Array).size() - 1})
        if not features.has(feature):
            features.append(feature)

    func poly(feature: String, kind: String, at: Vector3,
            size: Vector3, tint: String = "armor",
            yaw: float = 0.0) -> void:
        _put(feature, kind, tint,
            Basis(Vector3.UP, yaw).scaled_local(size), at)

    func poly_tilt(feature: String, kind: String, at: Vector3,
            size: Vector3, tint: String,
            angles: Vector3) -> void:
        _put(feature, kind, tint,
            Basis.from_euler(angles).scaled_local(size), at)

    func box(feature: String, at: Vector3, size: Vector3, tint: String = "armor",
            yaw: float = 0.0) -> void:
        _put(feature, "cube", tint, Basis(Vector3.UP, yaw).scaled_local(size), at)

    # True pitched/rolled steel plates, reusing the cube MultiMesh and
    # existing opaque materials: no per-panel nodes or additional draw groups.
    func box_tilt(feature: String, at: Vector3, size: Vector3,
            tint: String = "armor", angles: Vector3 = Vector3.ZERO) -> void:
        _put(feature, "cube", tint,
            Basis.from_euler(angles).scaled_local(size), at)

    func rod(feature: String, start: Vector3, finish: Vector3, diameter: float,
            tint: String = "trim") -> void:
        var direction: Vector3 = finish - start
        if direction.length_squared() < 0.000001:
            return
        var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
        basis = basis.scaled_local(Vector3(diameter, direction.length(), diameter))
        _put(feature, "tube", tint, basis, (start + finish) * 0.5)

    func ring(feature: String, center: Vector3, radius: float,
            tint: String, axis: String = "y") -> void:
        # Eight straight segments: an angular, physically readable machine rim.
        var segments: int = 4 if hard_edges else 8
        for index in range(segments):
            var a: float = TAU * float(index) / float(segments)
            var b: float = TAU * float(index + 1) / float(segments)
            if axis == "z":
                rod(feature, center + Vector3(cos(a) * radius, sin(a) * radius, 0),
                    center + Vector3(cos(b) * radius, sin(b) * radius, 0), 0.065, tint)
            else:
                rod(feature, center + Vector3(cos(a) * radius, 0, sin(a) * radius),
                    center + Vector3(cos(b) * radius, 0, sin(b) * radius), 0.065, tint)

    func crate(at: Vector3, size: Vector3, index: int = 0) -> void:
        poly("CargoBody", "bevel", at, size, "crate" if index % 3 else "slate")
        box("CargoLid", at + Vector3(0, size.y * 0.51, 0),
            Vector3(size.x * 1.03, 0.07, size.z * 1.03), "armor_light")
        for s in [-1.0, 1.0]:
            box("CargoCornerRail", at + Vector3(s * size.x * 0.44, 0,
                size.z * 0.51), Vector3(0.08, size.y, 0.06), "trim")
            box("CargoHandle", at + Vector3(s * size.x * 0.25, size.y * 0.05,
                size.z * 0.51), Vector3(0.13, 0.07, 0.05), "gold")
        box("CargoTopRib", at + Vector3(0, size.y * 0.54, 0),
            Vector3(0.08, 0.035, size.z), "edge")

    func flush() -> void:
        # Optional images are only usable once Godot's imported cache exists.
        var steel_texture: Texture2D = null
        var canvas_texture: Texture2D = null
        if ResourceLoader.exists(WEATHERED_STEEL_PATH):
            steel_texture = load(WEATHERED_STEEL_PATH) as Texture2D
        if ResourceLoader.exists(WEATHERED_CANVAS_PATH):
            canvas_texture = load(WEATHERED_CANVAS_PATH) as Texture2D
        var armor_texture: Texture2D = null
        var oxide_texture: Texture2D = null
        if ResourceLoader.exists(WEATHERED_ARMOR_PATH):
            armor_texture = load(WEATHERED_ARMOR_PATH) as Texture2D
        if ResourceLoader.exists(WEATHERED_OXIDE_PATH):
            oxide_texture = load(WEATHERED_OXIDE_PATH) as Texture2D
        var keys: Array = entries.keys()
        keys.sort()
        var polygon_meshes: Dictionary = {}
        var motion_multimeshes: Dictionary = {}
        # RGB12 per-instance roles replace every extra edge/crease batch.
        # Retain the ORIGINAL facility-vs-clutter per-instance classification.
        var selected_by_bucket: Dictionary = {}
        if not outline_entries.is_empty():
            host.set_meta("sera_outline_role", "facility")
        for raw_entry in outline_entries:
            var selected: Dictionary = raw_entry
            var bucket: String = str(selected["bucket"])
            if not selected_by_bucket.has(bucket):
                selected_by_bucket[bucket] = []
            (selected_by_bucket[bucket] as Array).append(selected)
        for key_variant in keys:
            var key: String = str(key_variant)
            var names: PackedStringArray = key.split("|")
            var geometry: String = names[0]
            var tint: String = names[1]
            var poses: Array = entries[key]
            var mesh: Mesh
            if polygon_meshes.has(geometry):
                mesh = polygon_meshes[geometry]
            elif geometry == "tube":
                var cylinder := CylinderMesh.new()
                cylinder.height = 1.0
                cylinder.top_radius = 0.5
                cylinder.bottom_radius = 0.5
                cylinder.radial_segments = 8
                mesh = cylinder
            elif geometry == "cube":
                var cube := BoxMesh.new()
                cube.size = Vector3.ONE
                mesh = cube
            else:
                mesh = BasePolygon.make(geometry)
            if mesh == null:
                push_error("Unknown BASE geometry: " + geometry)
                continue
            polygon_meshes[geometry] = mesh
            var multi := MultiMesh.new()
            multi.transform_format = MultiMesh.TRANSFORM_3D
            multi.mesh = mesh
            # A single batched draw may mix large machine pieces and small
            # clutter; per-instance role flags keep their line widths distinct.
            multi.use_custom_data = true
            multi.instance_count = poses.size()
            var facility_indices: Dictionary = {}
            for record in selected_by_bucket.get(key, []):
                facility_indices[int(record["index"])] = true
            if not motion_indices.is_empty():
                motion_multimeshes[key] = multi
            for i in range(poses.size()):
                var pose: Transform3D = poses[i]
                multi.set_instance_transform(i, pose)
                # Only narrow WHITE architectural strips get protected ID
                # role 7. Large white panels keep ordinary black outlines.
                # This per-instance encoding adds no separate draw batch.
                var width: float = pose.basis.x.length()
                var height: float = pose.basis.y.length()
                var depth: float = pose.basis.z.length()
                var skinny: int = (int(width < 0.23) +
                    int(height < 0.23) + int(depth < 0.23))
                var is_white_light_line: bool = (tint == "white" and
                    skinny >= 2 and maxf(width, maxf(height, depth)) >= 0.30)
                multi.set_instance_custom_data(i, Color(
                    0.875 if is_white_light_line else (
                        0.25 if facility_indices.has(i) else 0.375),
                    0.0, 0.0, 1.0))
                # Clutter RGB-ID role=3 is resolved by the common pass.
            # LABO's articulated arm and single payload move between material
            # batches' original rest-pose bounds. Keep the full local work
            # envelope visible, including the shared outline pass.
            if motion_names.has("LabArmLinkA"):
                multi.custom_aabb = AABB(Vector3(-5.0, 0.0, -5.0),
                    Vector3(10.0, 6.2, 10.0)).merge(multi.get_aabb())
            var surface := StandardMaterial3D.new()
            # Texture audit: the industrial steel/armor/oxide SVGs have
            # near-white substrates, not black pixels. The BASE NEXUS front
            # instead multiplies the old near-black "dark"/"void"/"trim"
            # swatches by face/vertex shading, crushing whole wall sections.
            # Restore a readable blue-grey range only on the archived NEXUS.
            var surface_tint: Color = Color(COLORS[tint])
            if host.name == "NexusArchitecture":
                match tint:
                    "dark":
                        surface_tint = Color("#384a59")
                    "void":
                        surface_tint = Color("#2b3c4a")
                    "trim":
                        surface_tint = Color("#405363")
                    "rubber":
                        surface_tint = Color("#30414e")
            surface.albedo_color = surface_tint
            # Only generated polygons contain valid authored vertex colors.
            # Primitive cube/tube meshes lack that channel (reads as black
            # when vertex_color_use_as_albedo is forced on). BASE NEXUS
            # previously multiplied its tint + texture by additional vertex
            # paint; disable that extra darkening only on this building.
            var has_vertex_colors: bool = (
                geometry != "cube" and geometry != "tube")
            # All authored BASE buildings must receive their real local lamps.
            # Their procedural vertex tones can otherwise multiply near-black.
            var authored_facility: bool = host.name in [
                "NexusArchitecture", "IndustrialModel"]
            surface.vertex_color_use_as_albedo = (
                has_vertex_colors and not authored_facility)
            surface.metallic = 0.31 if tint != "cloth" else 0.0
            surface.roughness = 0.75 if tint != "glass" else 0.46
            # Damp oxidized mechanics and aged painted plates read as rough,
            # not bright plastic. Machine screens and emissive bars stay crisp.
            if tint in ["rust", "gold"]:
                surface.roughness = 0.87
                surface.metallic = 0.24
            elif tint in ["armor", "armor_light", "slate", "crate"]:
                surface.roughness = 0.82
            if tint == "cloth":
                surface.albedo_texture = canvas_texture
            elif tint not in [
                    "glass", "blue_light", "lab_cyan", "amber_light", "amber",
                    "generator_emitter", "terminal_monitor"]:
                # Preserve the legacy weathered steel fallback during fresh
                # editor / Android imports; all surface variants share batches.
                surface.albedo_texture = steel_texture
                if tint in ["armor", "armor_light", "slate", "crate"] and armor_texture != null:
                    surface.albedo_texture = armor_texture
                elif tint in ["rust", "gold"] and oxide_texture != null:
                    surface.albedo_texture = oxide_texture
                # Group-specific crop offsets avoid identical weathering on
                # neighboring painted pieces without per-instance draw calls.
                var variation: int = [
                    "armor", "armor_light", "slate", "crate",
                    "rust", "gold", "trim", "edge"
                ].find(tint)
                if variation >= 0:
                    surface.uv1_offset = Vector3(
                        float(variation % 4) * 0.18,
                        float(variation / 4) * 0.27, 0.0)
            if tint in ["blue_light", "lab_cyan", "amber_light", "amber",
                    "generator_emitter", "terminal_monitor"]:
                # Emitters are self-luminous, not lights reacting to nearby
                # spotlights. Keep a stable sharp core from the first frame.
                surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                surface.emission_enabled = true
                surface.emission = Color(COLORS[tint])
                if tint == "lab_cyan":
                    # Distinct LABO-only clean luminous line, readable at
                    # the BASE overhead camera without increasing real lights.
                    surface.emission_energy_multiplier = 4.0
                elif tint == "generator_emitter":
                    surface.emission_energy_multiplier = 6.0
                elif tint == "terminal_monitor":
                    surface.emission_energy_multiplier = 2.85
                else:
                    surface.emission_energy_multiplier = (
                        1.75 if tint == "amber" else 2.30)
            var draw := MultiMeshInstance3D.new()
            draw.name = "Architectural_" + geometry + "_" + tint
            draw.multimesh = multi
            draw.material_override = surface
            draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            draw.set_meta("sera_outline_instanced_roles", true)
            if host.name in ["NexusArchitecture", "IndustrialModel"]:
                # The common character shader uses render_mode unshaded and
                # ignores SpotLight3D. Retain built-in physically lit material
                # for all outdoor equipment to show the actual work lamps.
                draw.set_meta("sera_preserve_authored_material", true)
                if host.name == "NexusArchitecture":
                    draw.set_meta("sera_base_authored_material", surface)
                    draw.set_meta("sera_base_material_tint", tint)
                    draw.set_meta("sera_base_has_vertex_color", has_vertex_colors)
            if host.name == "NexusArchitecture":
                # Per-material bright-face floor without touching SERA,
                # boss, GRID or other BASE facility shading.
                draw.set_meta("sera_scene_min_brightness", 0.82)
            if tint in ["blue_light", "lab_cyan", "amber_light", "amber",
                    "generator_emitter", "terminal_monitor"]:
                # Emissive visual details can occlude opaque contours, but
                # must never receive ink themselves.
                draw.set_meta("sera_outline_occluder_only", true)
                # Use protected ID role 7 (depth-resolved but no ink).
                # Otherwise the black 4px facility outline grows ONTO
                # narrow emitter slots, making their core appear crushed.
                draw.set_meta("sera_outline_emissive_protect", true)
            host.add_child(draw)
            # No second geometric contour pass or draw nodes are produced.
        host.set_meta("unique_model_features", features.duplicate())
        if not outline_entries.is_empty():
            host.set_meta("outline_solid_entries", outline_entries.duplicate())
        if not motion_indices.is_empty():
            var motion_entries: Dictionary = {}
            for feature_variant in motion_indices.keys():
                var feature: String = str(feature_variant)
                var recorded: Array = []
                for slot_variant in motion_indices[feature]:
                    var slot: Dictionary = slot_variant
                    var mesh: MultiMesh = motion_multimeshes.get(
                        str(slot["bucket"])) as MultiMesh
                    if mesh == null:
                        continue
                    var instance_index: int = int(slot["index"])
                    var animated_record: Dictionary = {
                        "mesh": mesh, "index": instance_index,
                        "bind": mesh.get_instance_transform(instance_index)}
                    # The animated MultiMesh is also the ID pass source.
                    recorded.append(animated_record)
                motion_entries[feature] = recorded
            host.set_meta("motion_entries", motion_entries)

# Small local point lights are tied to the physical machines, not screen UI.
# Unshadowed lights avoid costly extra passes on mobile GL Compatibility.
static func _light(parent: Node3D, label: String, at: Vector3,
        tint: String, power: float, reach: float) -> void:
    var lamp := OmniLight3D.new()
    lamp.name = label
    var yaw: float = float(parent.get_meta("body_yaw", 0.0))
    lamp.position = Basis(Vector3.UP, yaw) * (at * float(parent.get_meta("visual_model_scale", 1.0)))
    lamp.light_color = Color(tint)
    lamp.light_energy = power
    lamp.omni_range = reach * float(parent.get_meta("visual_model_scale", 1.0))
    lamp.shadow_enabled = false
    parent.add_child(lamp)

static func _facade(g: Batch, half_width: float, height: float,
        depth: float) -> void:
    for side in [-1.0, 1.0]:
        g.box("FacadePillars", Vector3(side * half_width, height * 0.5, depth),
            Vector3(0.19, height, 0.24), "trim")
        for row in range(3):
            g.box("WallArmorBands", Vector3(side * (half_width - 0.17),
                0.72 + float(row) * 1.0, depth), Vector3(0.10, 0.12, 0.24), "edge")

static func build_nexus(parent: Node3D) -> void:
    var node := Node3D.new()
    node.name = "NexusArchitecture"
    parent.add_child(node)
    var g := Batch.new(node)
    g.yaw = facility_yaw_radians("NEXUS")
    g.motion_names = BaseFacilityMotion.MOTION_FEATURES["NEXUS"]
    g.outline_enabled = true
    # Broaden the hub silhouette without enlarging the surrounding clutter.
    g.detail_scale = 1.14
    node.set_meta("visual_model_scale", g.detail_scale)
    node.set_meta("body_yaw", g.yaw)
    if ACTIVE_BASE_MODEL == "FRESH_20261122" and not ARCHIVED_NEXUS_MODEL:
        node.set_meta("base_design", ACTIVE_BASE_MODEL)
        BaseFreshDesign.add_details(g, "NEXUS")
        # Retain existing site dressing only, not old building geometry.
        g.detail_scale = 1.0
        g.outline_enabled = false
        BaseClutter.decorate(g, "NEXUS")
        g.flush()
        var fresh_motion := BaseFacilityMotion.new()
        fresh_motion.bind_to(node, "NEXUS")
        # Shutter-gap fixture and local light are now built by VFX, not
        # by a broad amber lamp washing the whole NEXUS side.
        var fresh_vfx := BaseFacilityVfx.new()
        fresh_vfx.setup(node, "NEXUS")
        return
    # Reinterpret the archived command bunker as one coherent architectural
    # assembly. Keep its flat roof, V insignia, blast gate and service mast.
    node.set_meta("base_design", "NEXUS_COMMAND_BUNKER_20261124")
    _nexus_command_bunker(g)
    g.detail_scale = 1.0
    g.outline_enabled = false
    BaseClutter.decorate(g, "NEXUS")
    g.flush()
    var archived_motion := BaseFacilityMotion.new()
    archived_motion.bind_to(node, "NEXUS")
    # A narrow shutter-gap fixture replaces the old exterior floodlight.
    var archived_vfx := BaseFacilityVfx.new()
    archived_vfx.setup(node, "NEXUS")


static func _nexus_command_bunker(g: Batch) -> void:
    # All dimensions are in the established pre-scale local space. +Z is
    # the public entrance. The existing 1.14 scale and yaw remain unchanged.
    # Split the shell so the central gate is genuinely recessed, rather than
    # a decorative door glued onto the face of a solid building.
    g.poly("NexusArmoredRearCore", "bevel", Vector3(0, 2.20, -0.87),
        Vector3(5.68, 3.60, 3.30), "armor")
    g.poly("NexusFoundationSkirt", "bevel", Vector3(0, 0.51, -0.02),
        Vector3(5.80, 0.25, 5.00), "trim")
    for side in [-1.0, 1.0]:
        g.poly("NexusFrontStructuralWing", "bevel",
            Vector3(side * 2.04, 2.17, 1.65),
            Vector3(1.64, 3.55, 2.00), "armor")
        g.poly_tilt("NexusLoadBearingButtress", "bevel",
            Vector3(side * 2.70, 2.22, 2.37),
            Vector3(0.47, 3.55, 0.62), "slate",
            Vector3(0, 0, side * 0.08))
        g.poly("NexusButtressFoot", "bevel", Vector3(side * 2.66, 0.65, 2.39),
            Vector3(0.76, 0.46, 0.86), "trim")
        g.poly("NexusButtressShoulder", "nexus_shallow_bevel",
            Vector3(side * 2.60, 3.88, 2.24),
            Vector3(0.75, 0.42, 0.78), "armor_light")
        # Broad, mechanically plausible removable armor plates, not rivet noise.
        for row in range(2):
            var y: float = 1.30 + float(row) * 1.56
            g.poly("NexusFrontalArmorCassette", "bevel",
                Vector3(side * 1.96, y, 2.68),
                Vector3(0.99, 1.39, 0.28), "armor_light" if row == 1 else "armor")
            g.box("NexusArmorCassetteRetainer",
                Vector3(side * 1.96, y - 0.57, 2.84),
                Vector3(0.78, 0.12, 0.07), "trim")
        # Actual service/thermal grille and warning window on the outer flank.
        g.poly("NexusCoolingBayHousing", "bevel",
            Vector3(side * 2.92, 2.42, 0.15),
            Vector3(0.25, 1.45, 1.92), "trim")
        g.poly_tilt("NexusCoolingBayLouvers", "louver",
            Vector3(side * 3.06, 2.42, 0.15),
            Vector3(1.65, 1.18, 0.15), "slate",
            Vector3(0, side * PI * 0.5, 0))
        g.poly("NexusServiceAccessPanel", "bevel",
            Vector3(side * 2.93, 1.42, -1.54),
            Vector3(0.24, 1.62, 1.02), "armor_light")
        g.box("NexusServiceHandle",
            Vector3(side * 3.08, 1.46, -1.23),
            Vector3(0.09, 0.29, 0.15), "dark")
        g.box("NexusStatusWindowRecess",
            Vector3(side * 2.30, 2.52, 2.86),
            Vector3(0.38, 0.25, 0.10), "dark")
        g.box("NexusStatusWindow",
            Vector3(side * 2.30, 2.52, 2.925),
            Vector3(0.28, 0.12, 0.035), "amber_light")
    # Layered lintel carries the roof across the recessed airlock.
    g.poly("NexusGateLoadBearingLintel", "nexus_shallow_bevel", Vector3(0, 3.58, 1.71),
        Vector3(2.74, 0.80, 1.87), "armor")
    g.poly("NexusAirlockBackplate", "bevel", Vector3(0, 1.72, 2.39),
        Vector3(2.45, 2.72, 0.24), "dark")
    g.poly("NexusBlastDoor", "bevel", Vector3(0, 1.65, 2.63),
        Vector3(1.96, 2.52, 0.24), "slate")
    # Four overlapping shutter slats and visible guides, with open lower gap
    # facing the existing VFX lamp at (0, 0.34, 2.97).
    for row in range(4):
        var y: float = 0.70 + float(row) * 0.62
        g.poly("NexusBlastShutterSlat", "bevel", Vector3(0, y, 2.78),
            Vector3(1.83, 0.55, 0.11), "armor" if row % 2 == 0 else "slate")
    # Single U-frame with clean planar chamfers. No overlapping diagonal
    # blocks, exposed intersections, or discontinuous header/column seams.
    g.poly("NexusIntegratedAirlockPortal", "nexus_portal",
        Vector3(0, 1.86, 2.94), Vector3(2.94, 3.02, 0.44), "slate")
    for side in [-1.0, 1.0]:
        g.box("NexusGuideLightRecess", Vector3(side * 1.30, 1.64, 3.19),
            Vector3(0.16, 1.73, 0.08), "void")
        g.box("NexusBlueGuideLight", Vector3(side * 1.30, 1.64, 3.24),
            Vector3(0.085, 1.58, 0.035), "blue_light")
    g.box("NexusEntryDirectionStripe", Vector3(0, 3.13, 3.1775),
        Vector3(1.69, 0.085, 0.035), "blue_light")
    # Preserve the distinctive V insignia above the projector mount.
    g.poly("NexusInsigniaPlate", "bevel", Vector3(0, 3.87, 2.68),
        Vector3(1.10, 0.60, 0.13), "trim")
    g.rod("NexusVInsignia", Vector3(-0.43, 4.08, 2.77),
        Vector3(0, 3.65, 2.77), 0.105, "white")
    g.rod("NexusVInsignia", Vector3(0.43, 4.08, 2.77),
        Vector3(0, 3.65, 2.77), 0.105, "white")
    g.box("NexusVInsigniaCenter", Vector3(0, 3.99, 2.78),
        Vector3(0.13, 0.26, 0.06), "edge")
    # Flat, low, overhanging armored roof. Three readable roof zones:
    # armored central deck, two accessible HVAC housings, and a rear mast.
    g.poly("NexusRoofSlab", "nexus_shallow_bevel", Vector3(0, 4.25, -0.12),
        Vector3(6.08, 0.42, 5.17), "slate")
    g.poly("NexusRoofCentralArmor", "nexus_shallow_bevel", Vector3(0, 4.52, -0.05),
        Vector3(2.55, 0.26, 4.48), "armor")
    g.poly("NexusRoofFrontFascia", "nexus_shallow_bevel", Vector3(0, 4.48, 2.35),
        Vector3(5.76, 0.30, 0.36), "armor_light")
    for side in [-1.0, 1.0]:
        g.poly("NexusRoofCoolingModule", "nexus_shallow_bevel",
            Vector3(side * 1.99, 4.62, 0.48),
            Vector3(1.35, 0.53, 2.13), "armor")
        g.poly_tilt("NexusRoofExhaustLouvers", "louver",
            Vector3(side * 1.99, 4.91, 0.48),
            Vector3(1.04, 1.74, 0.15), "trim",
            Vector3(-PI * 0.5, 0, 0))
        g.rod("NexusRoofCoolantPipe", Vector3(side * 2.73, 4.55, -1.84),
            Vector3(side * 2.73, 4.55, 1.68), 0.16, "gold")
        g.rod("NexusRoofPipeElbow", Vector3(side * 2.73, 4.55, 1.68),
            Vector3(side * 2.43, 4.55, 1.68), 0.16, "gold")
    # Existing VFX beacon is at (2.42, 6.18, -1.78); support the housing.
    g.poly("NexusAntennaPedestal", "nexus_shallow_bevel", Vector3(2.42, 4.58, -1.78),
        Vector3(0.66, 0.38, 0.66), "armor_light")
    g.rod("NexusCommunicationMast", Vector3(2.42, 4.76, -1.78),
        Vector3(2.42, 5.67, -1.78), 0.16, "trim")
    g.rod("NexusCommunicationMast", Vector3(2.42, 5.67, -1.78),
        Vector3(2.42, 6.10, -1.78), 0.075, "edge")
    g.rod("NexusMastCrossbar", Vector3(2.09, 5.48, -1.78),
        Vector3(2.75, 5.48, -1.78), 0.09, "edge")
    g.rod("NexusMastAntenna", Vector3(2.09, 5.48, -1.78),
        Vector3(2.09, 5.81, -1.78), 0.06, "edge")
    g.rod("NexusMastAntenna", Vector3(2.75, 5.48, -1.78),
        Vector3(2.75, 5.81, -1.78), 0.06, "edge")
    # Retain the salvaged canvas service awning, with its own frame and
    # one readable equipment case instead of many tiny overlapping crates.
    g.poly_tilt("NexusServiceAwning", "canvas", Vector3(-2.67, 2.73, 3.05),
        Vector3(1.38, 0.23, 1.17), "cloth", Vector3(0.12, 0, 0))
    for side in [-1.0, 1.0]:
        var x: float = -2.67 + side * 0.56
        g.rod("NexusAwningFrame", Vector3(x, 0.44, 3.53),
            Vector3(x, 2.65, 3.53), 0.10, "trim")
        g.rod("NexusAwningRafter", Vector3(x, 2.65, 3.53),
            Vector3(x, 2.78, 2.53), 0.09, "edge")
    g.poly("NexusServiceEquipmentCase", "cargo_case", Vector3(-2.68, 0.77, 3.12),
        Vector3(0.78, 0.65, 0.55), "crate")

static func _labo(g: Batch) -> void:
    # Smaller, busy semi-open workshop: tarpaulin canopy, worktables and consoles.
    # A genuinely open-front workshop, rather than a sealed rectangular hall.
    g.poly("LabOpenWorkshopRearWall", "bevel", Vector3(0, 1.57, -1.69),
        Vector3(3.65, 2.82, 0.37), "slate")
    g.box("LabOpenWorkshopBackPanel", Vector3(0, 1.40, -1.43),
        Vector3(2.97, 2.27, 0.12), "void")
    for side in [-1.0, 1.0]:
        g.poly("LabOpenWorkshopSideWall", "bevel", Vector3(side * 1.74, 1.56, -0.84),
            Vector3(0.17, 2.73, 1.87), "armor")
        for rib in range(3):
            g.box("LabOpenWorkshopFrameRib", Vector3(side * 1.70,
                0.56 + float(rib) * 0.95, -0.11),
                Vector3(0.22, 0.10, 1.66), "edge")
    g.box("LabWorkFloor", Vector3(0, 0.28, 0.97),
        Vector3(3.55, 0.17, 2.85), "slate")
    g.box("LabCanopyFrame", Vector3(0, 3.18, -1.69),
        Vector3(3.84, 0.14, 0.17), "edge")
    for i in range(6):
        var x: float = -1.74 + float(i) * 0.68
        g.poly("LabDrapedCanopy", "canvas", Vector3(x, 3.38 + 0.02 * cos(i * 1.2), -1.07),
            Vector3(0.11, 0.10, 1.22), "cloth")
    for side in [-1.0, 1.0]:
        g.rod("CanopyAwningPosts", Vector3(side * 1.82, 0.20, 2.16),
            Vector3(side * 1.82, 3.20, 2.16), 0.10, "dark")
        g.box("LabShelf", Vector3(side * 1.32, 1.12, -1.12),
            Vector3(0.52, 1.65, 0.45), "trim")
        for row in range(3):
            g.box("LabShelfEquipment", Vector3(side * 1.30,
                0.50 + row * 0.53, -0.83),
                Vector3(0.32, 0.29, 0.10), "amber" if row == 1 else "armor")
    # Secondary tool bench belongs at the side, NOT in front of the printer.
    g.box("LabWorkbench", Vector3(1.23, 0.86, 1.34),
        Vector3(0.75, 0.17, 0.75), "armor_light")
    g.box("LabWorkbenchFrame", Vector3(1.23, 0.46, 1.34),
        Vector3(0.68, 0.62, 0.62), "trim")
    g.box("LabConsoleScreen", Vector3(1.22, 1.75, 1.57),
        Vector3(0.70, 0.51, 0.08), "glass")
    g.box("LabConsoleDisplay", Vector3(1.22, 1.76, 1.63),
        Vector3(0.57, 0.38, 0.05), "blue")
    for row in range(3):
        g.box("LabConsoleTelemetry", Vector3(1.14, 1.64 + row * 0.10, 1.66),
            Vector3(0.26 + row * 0.09, 0.024, 0.015), "blue_light")
    for i in range(6):
        g.box("LabWallTool", Vector3(-1.25 + (i % 3) * 0.44,
            1.15 + (i / 3) * 0.55, 1.66),
            Vector3(0.10, 0.38, 0.09), "edge")
    g.box("LabAmberLamp", Vector3(0, 2.49, -0.73),
        Vector3(1.18, 0.10, 0.08), "amber_light")
    # Tables, tool trays and overhead gantry make the semi-open interior read.
    # Retire the overlapping front crossbar: only the dedicated printer
    # bridge is allowed near the visible machine face.
    g.box("LabOpenWorkshopGantry", Vector3(0, 2.58, -1.06),
        Vector3(3.30, 0.13, 0.16), "edge")
    g.box("LabTaskLighting", Vector3(-0.65, 2.49, -0.96),
        Vector3(0.96, 0.13, 0.08), "amber_light")
    g.box("LabToolTray", Vector3(-0.55, 0.91, 0.87),
        Vector3(0.84, 0.12, 0.52), "rust")
    # Tools remain physically real but away from the main print bed.
    for item in range(4):
        g.box("LabLooseTools", Vector3(-1.12 + float(item % 2) * 0.24,
            1.02, -0.69 + float(item / 2) * 0.28),
            Vector3(0.07, 0.09, 0.23), "edge" if item % 2 else "gold")
    for tier in range(3):
        g.box("LabOpenWorkshopServerRack", Vector3(-1.13,
            0.67 + float(tier) * 0.52, -1.32),
            Vector3(0.66, 0.39, 0.13), "armor_light")
        g.box("LabOpenWorkshopServerLight", Vector3(-1.32,
            0.65 + float(tier) * 0.52, -1.24),
            Vector3(0.21, 0.08, 0.05), "blue_light")
    g.crate(Vector3(-1.50, 0.43, 2.14), Vector3(0.56, 0.62, 0.48))
    g.crate(Vector3(1.56, 0.33, -1.30), Vector3(0.52, 0.46, 0.48), 1)

static func _collector(g: Batch) -> void:
    # A real pick-and-drop scrap recovery claw over a low sorting hopper.
    g.poly("CollectorBase", "bevel", Vector3(0, 0.35, 0), Vector3(2.17, 0.55, 2.0), "trim")
    g.poly("CollectorFunnel", "hopper", Vector3(0.35, 0.67, 0.22),
        Vector3(1.34, 0.70, 1.24), "slate")
    for side in [-1.0, 1.0]:
        g.box("HopperRim", Vector3(side * 0.67 + 0.35, 1.08, 0.22),
            Vector3(0.11, 0.16, 1.34), "edge")
    for i in range(8):
        var x: float = 0.02 + float(i % 4) * 0.25
        var z: float = -0.18 + float(i / 4) * 0.43
        g.box("RecoveredMetalScrap", Vector3(x, 1.06 + float(i % 3) * 0.08, z),
            Vector3(0.30, 0.12, 0.21), "armor_light" if i % 2 else "dark",
            0.22 * i)
    g.box("CollectorMotor", Vector3(-0.84, 0.78, -0.30),
        Vector3(0.46, 0.88, 0.60), "armor")
    # Old duplicate bright booms compete with the raised arm in the
    # dedicated identity pass. Retain mechanics as dark support cylinders.
    g.rod("HydraulicCrane", Vector3(-0.76, 1.05, -0.30),
        Vector3(-0.62, 2.25, -0.35), 0.17, "slate")
    g.rod("HydraulicCrane", Vector3(-0.62, 2.25, -0.35),
        Vector3(0.46, 2.12, 0.02), 0.16, "slate")
    g.rod("HydraulicPiston", Vector3(-0.62, 1.35, -0.34),
        Vector3(0.07, 2.04, -0.15), 0.10, "edge")
    g.rod("GrabberChain", Vector3(0.46, 2.12, 0.02),
        Vector3(0.46, 1.52, 0.02), 0.08, "dark")
    for side in [-1.0, 1.0]:
        g.rod("ClawFinger", Vector3(0.46, 1.50, 0.02),
            Vector3(0.46 + side * 0.23, 1.14, 0.05), 0.12, "edge")
        g.rod("ClawTooth", Vector3(0.46 + side * 0.23, 1.14, 0.05),
            Vector3(0.46 + side * 0.11, 0.96, 0.11), 0.08, "armor_light")
    g.box("CollectorWarningLight", Vector3(-0.84, 1.43, 0.20),
        Vector3(0.40, 0.10, 0.06), "blue_light")

static func _smelter(g: Batch) -> void:
    # Glowing heat chamber, copper chimney and exposed pressure pipes.
    g.poly("FurnaceOctagonalBody", "bevel", Vector3(0, 0.93, 0),
        Vector3(1.73, 1.50, 1.70), "armor")
    g.box("FurnaceMouth", Vector3(0, 0.94, 0.90),
        Vector3(1.17, 0.98, 0.09), "amber")
    g.box("FurnaceGlow", Vector3(0, 0.91, 0.96),
        Vector3(0.87, 0.72, 0.05), "amber_light")
    for i in range(5):
        g.box("FurnaceGrille", Vector3(-0.46 + i * 0.23, 0.98, 1.02),
            Vector3(0.065, 0.92, 0.07), "dark")
    for side in [-1.0, 1.0]:
        g.box("FurnaceOuterRib", Vector3(side * 0.89, 1.05, 0),
            Vector3(0.20, 1.98, 1.84), "trim")
        g.rod("HeatPipe", Vector3(side * 0.80, 1.73, -0.35),
            Vector3(side * 1.01, 2.35, -0.35), 0.17, "rust")
        g.rod("HeatPipe", Vector3(side * 1.01, 2.35, -0.35),
            Vector3(side * 1.01, 2.35, 0.58), 0.15, "gold")
    g.poly("FurnaceArmorLid", "bevel", Vector3(0, 1.86, -0.09),
        Vector3(2.18, 0.25, 1.98), "edge")
    g.rod("ExhaustStack", Vector3(-0.66, 1.88, -0.55),
        Vector3(-0.66, 2.82, -0.55), 0.53, "slate")
    g.ring("ExhaustStackRim", Vector3(-0.66, 2.81, -0.55), 0.31, "edge")
    g.box("FurnaceControl", Vector3(0.87, 0.88, 0.54),
        Vector3(0.30, 0.59, 0.34), "trim")
    g.box("FurnaceControlLight", Vector3(1.04, 1.09, 0.62),
        Vector3(0.04, 0.17, 0.13), "blue_light")
    for i in range(5):
        g.box("HazardStripe", Vector3(-0.74 + i * 0.35, 0.26, 1.06),
            Vector3(0.12, 0.08, 0.15), "caution")

static func _recycler(g: Batch) -> void:
    # Open crushing mouth with exposed grooved cylindrical cutters and discharge bin.
    g.poly("CrusherDeck", "bevel", Vector3(0, 0.35, 0),
        Vector3(2.23, 0.44, 2.01), "armor")
    for side in [-1.0, 1.0]:
        g.poly("CrusherSideGuard", "bevel", Vector3(side * 0.96, 1.22, 0),
            Vector3(0.22, 1.32, 1.86), "trim")
        g.box("CrusherMotor", Vector3(side * 0.99, 0.93, -0.58),
            Vector3(0.34, 0.54, 0.51), "slate")
    g.box("CrusherThroat", Vector3(0, 1.0, 0.0),
        Vector3(1.66, 0.33, 1.39), "void")
    for row in range(5):
        var z: float = -0.48 + float(row) * 0.24
        g.poly_tilt("CrusherCutterDrum", "gear",
            Vector3(0, 1.11, z), Vector3(0.24, 1.50, 0.24),
            "edge", Vector3(0, 0, PI * 0.5))
        for k in range(6):
            g.box("CrusherCutterTeeth", Vector3(-0.58 + float(k) * 0.23,
                1.24, z), Vector3(0.12, 0.10, 0.06), "dark")
    g.box("CrusherOutputTray", Vector3(0, 0.54, 1.04),
        Vector3(1.66, 0.11, 0.76), "armor_light")
    for i in range(5):
        g.box("CrusherCautionStripes", Vector3(-0.75 + 0.35 * i,
            0.67, 1.28), Vector3(0.15, 0.04, 0.25), "caution")
    g.box("CrusherStatusLight", Vector3(1.02, 1.71, 0.57),
        Vector3(0.17, 0.10, 0.25), "amber_light")

static func _generator(g: Batch) -> void:
    # Horizontal blue turbine and a separate dark power conditioning cabinet.
    g.poly("GeneratorSkid", "bevel", Vector3(0, 0.31, 0),
        Vector3(2.2, 0.44, 1.99), "trim")
    for side in [-1.0, 1.0]:
        g.box("EnergyBearing", Vector3(side * 0.58, 0.91, 0.0),
            Vector3(0.25, 1.24, 1.26), "armor")
        g.ring("EnergyEndRim", Vector3(side * 0.62, 1.08, 0.0),
            0.43, "edge", "z")
    g.poly_tilt("GeneratorRadialRotor", "drum",
        Vector3(0.0, 1.11, 0.0), Vector3(0.75, 0.91, 1.06),
        "blue", Vector3(0, 0, PI * 0.5))
    for index in range(7):
        g.box("EnergyCoil", Vector3(-0.38 + float(index) * 0.13,
            1.10, 0.63), Vector3(0.065, 0.54, 0.06), "blue_light")
    g.poly("GeneratorPowerCabinet", "bevel", Vector3(0.87, 1.36, -0.32),
        Vector3(0.59, 1.98, 1.06), "crate")
    g.box("GeneratorPanel", Vector3(0.86, 1.56, 0.25),
        Vector3(0.41, 0.58, 0.08), "dark")
    for row in range(4):
        g.box("GeneratorPanelMeters", Vector3(0.84, 1.37 + row * 0.13,
            0.32), Vector3(0.24, 0.045, 0.03), "blue_light")
    for side in [-1.0, 1.0]:
        g.rod("PowerConduit", Vector3(side * 0.7, 0.60, -0.45),
            Vector3(side * 0.94, 0.34, -0.84), 0.12, "rubber")
    g.box("GeneratorAmberIndicator", Vector3(-0.90, 1.87, 0.34),
        Vector3(0.22, 0.14, 0.08), "amber_light")

static func _storage(g: Batch) -> void:
    g.poly("CargoStoragePallet", "bevel", Vector3(0, 0.24, 0),
        Vector3(2.3, 0.29, 2.07), "trim")
    # Tiered cargo now steps toward the visible loading face instead of
    # hiding both rows under one rear awning in the orthographic game view.
    for i in range(6):
        var x: float = -0.72 + float(i % 3) * 0.70
        var y: float = 0.68 + float(i / 3) * 0.68
        var z: float = 0.30 if i >= 3 else -0.50
        g.crate(Vector3(x, y, z), Vector3(0.59, 0.58, 0.90), i)
    # Positive upper-cargo silhouette in the open portion of the shed.
    g.poly("StorageExposedUpperCargo", "bevel",
        Vector3(-0.69, 1.77, 0.30), Vector3(0.63, 0.20, 0.75), "rust")
    # One low cargo restraint per side, not the former three horizontal
    # rails that hid the goods at the 27-degree gameplay angle.
    for side in [-1.0, 1.0]:
        g.box("CargoStoragePalletRail", Vector3(side * 1.12,
            0.56, -0.12), Vector3(0.095, 0.15, 1.65), "edge")
        g.rod("CargoStorageCornerPost", Vector3(side * 1.10, 0.18, -0.90),
            Vector3(side * 1.10, 1.86, -0.90), 0.10, "gold")
    # Only the back row needs weatherproof canvas. The open front shows
    # high-grade cargo from the fixed angled overhead camera.
    g.poly("CargoStorageTarp", "canvas", Vector3(0.0, 1.76, -0.78),
        Vector3(2.15, 0.22, 0.68), "cloth")
    for i in range(4):
        g.box("CargoStorageTieStrap", Vector3(-0.73 + i * 0.48,
            1.82, -0.78), Vector3(0.04, 0.04, 0.65), "rust")

static func _construction(g: Batch) -> void:
    # Operator-height terminal with an angled holographic blueprint stand.
    g.poly("BlueprintTerminalFoot", "bevel", Vector3(0, 0.30, 0.11),
        Vector3(1.97, 0.43, 1.85), "trim")
    g.poly("BlueprintTerminalBody", "bevel", Vector3(0, 0.90, -0.23),
        Vector3(1.68, 0.80, 0.86), "armor")
    g.poly("BlueprintScreenHousing", "bevel", Vector3(0, 1.68, -0.31),
        Vector3(1.73, 1.07, 0.34), "edge")
    g.box("BlueprintScreenDark", Vector3(0, 1.70, -0.09),
        Vector3(1.48, 0.85, 0.08), "void")
    g.box("BlueprintScreen", Vector3(0, 1.71, -0.045),
        Vector3(1.31, 0.70, 0.042), "glass")
    for row in range(5):
        g.box("BlueprintGridHorizontal", Vector3(0, 1.47 + row * 0.11,
            -0.009), Vector3(1.15, 0.012, 0.011), "blue")
    for col in range(6):
        g.box("BlueprintGridVertical", Vector3(-0.51 + col * 0.20,
            1.71, -0.006), Vector3(0.012, 0.57, 0.011), "blue")
    g.box("BlueprintWireframe", Vector3(0.02, 1.78, 0.018),
        Vector3(0.44, 0.28, 0.014), "blue_light")
    g.box("BlueprintKeypad", Vector3(0, 1.02, 0.51),
        Vector3(1.45, 0.18, 0.65), "slate")
    for row in range(3):
        for col in range(6):
            g.box("BlueprintKeys", Vector3(-0.53 + col * 0.20,
                1.13, 0.32 + 0.17 * row), Vector3(0.12, 0.02, 0.08),
                "edge" if col % 2 else "blue")
    g.rod("BlueprintAntenna", Vector3(0.79, 1.58, -0.54),
        Vector3(0.79, 2.45, -0.54), 0.065, "edge")
    g.box("BlueprintAntennaTip", Vector3(0.79, 2.48, -0.54),
        Vector3(0.15, 0.18, 0.15), "amber_light")

static func build_facility(parent: Node3D, key: String) -> void:
    var node := Node3D.new()
    node.name = "IndustrialModel"
    parent.add_child(node)
    var g := Batch.new(node)
    g.hard_edges = true
    g.motion_names = BaseFacilityMotion.animated_features_for(key)
    g.outline_enabled = true
    g.yaw = facility_yaw_radians(key)
    # Seven work buildings grow into the unused portrait space; NEXUS retains
    # its own 1.14x size. Keep all pad, tap anchor and clutter placements.
    g.detail_scale = 1.45 if key == "LABO" else 1.55
    node.set_meta("visual_model_scale", g.detail_scale)
    node.set_meta("body_yaw", g.yaw)
    if ACTIVE_BASE_MODEL == "FRESH_20261122":
        node.set_meta("base_design", ACTIVE_BASE_MODEL)
        BaseFreshDesign.add_details(g, key)
    else:
        # Original geometry remains available and never draws in fresh mode.
        _build_original_facility_geometry(g, key)
    g.detail_scale = 1.0
    g.outline_enabled = false
    BaseClutter.decorate(g, key)
    g.flush()
    var device_motion := BaseFacilityMotion.new()
    device_motion.bind_to(node, key)
    _add_facility_lights(node, key)
    var device_vfx := BaseFacilityVfx.new()
    device_vfx.setup(node, key)


static func _build_original_facility_geometry(g: Batch, key: String) -> void:
    match key:
        "LABO":
            _labo(g)
        "SCRAP_COLLECTOR":
            _collector(g)
        "SMELTER":
            _smelter(g)
        "RECYCLER":
            _recycler(g)
        "GENERATOR":
            _generator(g)
        "STORAGE":
            _storage(g)
        "BUILD_TERMINAL":
            _construction(g)
        _:
            push_warning("Unknown base device: " + key)
            return
    # Original-only structural overlays; fresh design builds none of these.
    # Shared bolted skid and utility conduits, with unique anatomy above.
    for side in [-1.0, 1.0]:
        g.box("BaseMountingRail", Vector3(side * 0.72, 0.24, 0.0),
            Vector3(0.10, 0.15, 1.65), "dark")
        for end in [-1.0, 1.0]:
            g.box("BaseMountingBolt", Vector3(side * 0.72, 0.34, end * 0.71),
                Vector3(0.11, 0.055, 0.11), "edge")
    BasePolish.add_details(g, key)
    BaseSilhouette.add_details(g, key)
    BaseFinish.add_details(g, key)
    BaseNightFacade.add_details(g, key)
    BaseStructuralMass.add_details(g, key)
    BaseRoofIdentity.add_details(g, key)


static func _add_facility_lights(node: Node3D, key: String) -> void:
    match key:
        "SMELTER":
            # Furnace fire is an area heat source, not a searchlight.
            _light(node, "FurnaceHeatLight", Vector3(0, 1.10, 1.14),
                "#ff904d", 2.05, 3.40)
        # LABO, BUILD_TERMINAL and the other sites now use one real aimed
        # SpotLight per visible projector in BaseFacilityVFX. Remove their
        # former broad unmodelled OmniLights to avoid double lighting.

