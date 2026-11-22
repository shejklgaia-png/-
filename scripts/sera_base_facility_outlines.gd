extends Control
## BASE only: screen-space 6px architectural silhouette and 2px *front*
## corners. Unlike an inverted-hull material this remains pixel-constant in
## orthographic play and never touches smoke, emissive quads or ground bloom.
const BLUE_GREY: Color = Color("#55798A")
const SILHOUETTE_WIDTH: float = 6.0
const EDGE_WIDTH: float = 2.0
const KEYS: Array[String] = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL"
]
const CORNER_FEATURES: Dictionary = {
    "NEXUS": ["NexusCutCornerShell", "ArmoredRoof", "GatePortal",
        "NexusLeftMaintenanceAnnex", "NexusRightServiceTower"],
    "LABO": ["FreshLabRearWall", "FreshLabSideWall",
        "FreshLabWorkbenchPlatform", "FreshLabFabricationBed"],
    "SCRAP_COLLECTOR": ["FreshCollectorTurntable", "FreshCollectorSortPan",
        "FreshCollectorBoomPivot", "FreshCollectorClawHead"],
    "SMELTER": ["FreshSmelterFurnaceBase", "FreshSmelterBlastJacket",
        "FreshSmelterHotThroat", "FreshSmelterCombustionHood"],
    "RECYCLER": ["FreshRecyclerLowerBody", "FreshRecyclerRearGearbox",
        "FreshRecyclerOpenVJaws"],
    "GENERATOR": ["FreshGeneratorMotorFrame", "FreshGeneratorHousingUpper",
        "FreshGeneratorPowerCabinet"],
    "STORAGE": ["FreshStorageLoadPallet", "FreshStorageOffsetStacks",
        "FreshStorageLoadingLift"],
    "BUILD_TERMINAL": ["FreshTerminalConsoleBase", "FreshTerminalSignalBody",
        "FreshTerminalDisplayFrame"],
}
var _hub: Node3D
var _camera: Camera3D
var _models: Dictionary = {}
var _last_pose: Transform3D = Transform3D.IDENTITY
var _last_camera_size: float = -1.0
var _refresh: float = 0.0

func bind(hub: Node3D, cam: Camera3D) -> void:
    name = "FacilityOutlines"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hub = hub
    _camera = cam
    _models["NEXUS"] = hub.get_node("NEXUSBuilding/NexusArchitecture")
    for key in KEYS:
        if key == "NEXUS":
            continue
        _models[key] = hub.get_node(
            "BaseFacilities/" + key + "/IndustrialModel")
    queue_redraw()

func _process(delta: float) -> void:
    if _hub == null or _camera == null:
        return
    var display: bool = not _hub.get("power_view_active")
    if visible != display:
        visible = display
    if not display:
        return
    _refresh += delta
    # On BASE/GRID camera travel, refresh every frame. Otherwise the actual
    # static silhouette needs only occasional redraws (mobile GPU-friendly).
    var moved: bool = _camera.global_transform != _last_pose or (
        not is_equal_approx(_camera.size, _last_camera_size))
    if moved or _refresh >= 0.35:
        _refresh = 0.0
        _last_pose = _camera.global_transform
        _last_camera_size = _camera.size
        queue_redraw()

func _project_corners(model: Node3D, record: Dictionary) -> PackedVector2Array:
    var points := PackedVector2Array()
    var pose: Transform3D = record["pose"]
    var transform: Transform3D = model.global_transform * pose
    for ix in [-0.5, 0.5]:
        for iy in [-0.5, 0.5]:
            for iz in [-0.5, 0.5]:
                var world: Vector3 = transform * Vector3(ix, iy, iz)
                if not _camera.is_position_behind(world):
                    points.append(_camera.unproject_position(world))
    return points

func silhouette_for(key: String) -> PackedVector2Array:
    var model: Node3D = _models.get(key) as Node3D
    if model == null or _camera == null:
        return PackedVector2Array()
    var vertices := PackedVector2Array()
    var solids: Array = model.get_meta("outline_solid_entries", [])
    for item in solids:
        var record: Dictionary = item
        # Solid-only metadata is authored before any FX node is created;
        # emissive material buckets, smoke and floor planes are all omitted.
        for point in _project_corners(model, record):
            vertices.append(point)
    if vertices.size() < 3:
        return PackedVector2Array()
    return Geometry2D.convex_hull(vertices)

func _draw_front_edges(model: Node3D, key: String) -> void:
    var solids: Array = model.get_meta("outline_solid_entries", [])
    var feature_names: Array = CORNER_FEATURES.get(key, [])
    for item in solids:
        var record: Dictionary = item
        if not feature_names.has(str(record["feature"])):
            continue
        # Pick the *camera-side* 3D corner, then draw the three meeting edges.
        # This guarantees foreground corners even though a silhouette-only
        # post-process would miss them. Lines remain on screen over nearby faces.
        var local_pose: Transform3D = record["pose"]
        var part: Transform3D = model.global_transform * local_pose
        var cam_local: Vector3 = part.affine_inverse() * _camera.global_position
        var near: Vector3 = Vector3(
            0.5 if cam_local.x >= 0.0 else -0.5,
            0.5 if cam_local.y >= 0.0 else -0.5,
            0.5 if cam_local.z >= 0.0 else -0.5)
        var world_a: Vector3 = part * near
        if _camera.is_position_behind(world_a):
            continue
        var a: Vector2 = _camera.unproject_position(world_a)
        for axis in range(3):
            var far_corner: Vector3 = near
            if axis == 0:
                far_corner.x = -near.x
            elif axis == 1:
                far_corner.y = -near.y
            else:
                far_corner.z = -near.z
            var world_b: Vector3 = part * far_corner
            if not _camera.is_position_behind(world_b):
                var b: Vector2 = _camera.unproject_position(world_b)
                draw_line(a, b, Color("#55798A"), 2.0, true)

func _draw() -> void:
    if _camera == null or not visible:
        return
    for key in KEYS:
        var rim: PackedVector2Array = silhouette_for(key)
        if rim.size() < 3:
            continue
        var loop: PackedVector2Array = rim.duplicate()
        loop.append(rim[0])
        draw_polyline(loop, Color("#55798A"), 6.0, true)
        var model: Node3D = _models.get(key) as Node3D
        if model != null:
            _draw_front_edges(model, key)
