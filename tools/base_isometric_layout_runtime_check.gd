extends SceneTree
## Project real 3D volume corners into the Android portrait orthographic frame.
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_BASE_ISOMETRIC_LAYOUT_FAIL: " + reason)
    quit(1)

func _fit(rect: Rect2, view: Vector2, label: String) -> bool:
    var uv: Rect2 = Rect2(rect.position / view, rect.size / view)
    if (uv.position.x < 0.035 or uv.end.x > 0.965 or
            uv.position.y < 0.040 or uv.end.y > 0.885):
        _fail("building clipped / too close to portrait edge: " + label + " " + str(uv))
        return false
    return true

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var camera: Camera3D = hub.get("cam") as Camera3D
    var machines: Node3D = hub.get_node("BaseFacilities") as Node3D
    var nexus: Node3D = hub.get_node("NEXUSBuilding") as Node3D
    if camera == null or nexus == null or machines == null:
        _fail("base camera/buildings not loaded")
        return
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or (
            absf(camera.size - 38.0) > 0.01):
        _fail("FOV-zero appearance must be orthographic at size 38")
        return
    var view: Vector2 = camera.get_viewport().get_visible_rect().size
    if view.y < view.x or view.x < 100:
        _fail("not portrait viewport")
        return
    var all_rects: Dictionary = {}
    var nexus_rect: Rect2 = hub.call("_nexus_screen_rect")
    if not _fit(nexus_rect, view, "NEXUS"):
        return
    all_rects["NEXUS"] = nexus_rect
    var nexus_tap: Vector2 = camera.unproject_position(
        nexus.global_position + Vector3(0, 2.5, 0))
    if not bool(hub.call("_nexus_hit", nexus_tap)):
        _fail("visible NEXUS no longer opens from its own model")
        return
    var lab_uv: Vector2 = Vector2.ZERO
    var top_uv: Vector2 = nexus_tap / view
    if absf(top_uv.x - 0.50) > 0.11 or top_uv.y > 0.30:
        _fail("NEXUS not on upper center")
        return
    var names := ["LABO", "SMELTER", "RECYCLER", "STORAGE",
        "GENERATOR", "SCRAP_COLLECTOR", "BUILD_TERMINAL"]
    for name in names:
        var machine: Node3D = machines.get_node(name) as Node3D
        var rect: Rect2 = machines.call("_projected_bounds", camera, name)
        if not _fit(rect, view, name):
            return
        for earlier_name in all_rects:
            if rect.intersects(all_rects[earlier_name] as Rect2):
                _fail("screen footprints overlap: " + name + " and " + str(earlier_name))
                return
        all_rects[name] = rect
        var spot: Vector2 = camera.unproject_position(
            machine.global_position + Vector3(0.0, 1.0, 0.0))
        if name == "LABO":
            lab_uv = spot / view
        if str(machines.call("key_at", camera, spot)) != name:
            _fail("visible facility is not tappable: " + name)
            return
        if bool(hub.call("_nexus_hit", spot)):
            _fail("NEXUS touch rectangle obscures " + name)
            return
    if absf(lab_uv.x - 0.5) > 0.1 or (
            lab_uv.y < 0.60 or lab_uv.y > 0.70):
        _fail("LABO must anchor the lower edge of a modest central gap")
        return
    if lab_uv.y - top_uv.y < 0.30 or lab_uv.y - top_uv.y > 0.45:
        _fail("NEXUS and LABO vertical tiers collapsed")
        return
    machines.call("update_tags", camera)
    var tags: Dictionary = machines.get("facility_tags")
    for name in names:
        var tag: Label = tags.get(name) as Label
        if tag == null or not tag.visible:
            _fail("label hidden: " + name)
            return
        var font: Font = tag.get_theme_font("font")
        if font == null or not font.has_char(0x56DE):
            _fail("facility tag lacks Japanese glyphs: " + name)
            return
        var sign: Label3D = (machines.get_node(name) as Node3D).get_node(
            "FacilitySign") as Label3D
        if sign == null or sign.font == null or not sign.font.has_char(0x56DE):
            _fail("3D facility sign lacks Japanese glyphs: " + name)
            return
        if sign.visible:
            _fail("3D sign duplicates the on-screen facility tag: " + name)
            return
        if (tag.position.x < 4.0 or tag.position.y < 100.0 or
                tag.position.x + tag.size.x > view.x - 4.0 or
                tag.position.y + tag.size.y > view.y - 12.0):
            _fail("facility tag clipped: " + name + " " + str(tag.position))
            return
    var hint: Label = hub.get("hint") as Label
    if hint == null or not hint.get_theme_font("font").has_char(0x5EFA):
        _fail("bottom Japanese interaction hint still uses missing system font")
        return
    # Verify no camera auto-reset after one production frame (SERA hidden).
    var old_camera: Vector3 = camera.global_position
    hub.call("_process", 0.033)
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or (
            camera.global_position.distance_to(old_camera) > 0.02):
        _fail("base gameplay process reverts the isometric camera")
        return
    print("SERA_BASE_ISOMETRIC_LAYOUT_RUNTIME_PASS: all 8 buildings + 7 labels fit")
    quit(0)
