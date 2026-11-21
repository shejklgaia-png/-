extends SceneTree
## Approved BASE dressing: larger props with intact entrances, feet, and batching.
const Props = preload("res://scripts/sera_base_clutter.gd")
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const KEYS = [
    "NEXUS", "LABO", "SMELTER", "RECYCLER",
    "SCRAP_COLLECTOR", "STORAGE", "GENERATOR", "BUILD_TERMINAL",
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_ENLARGED_DRESSING_FAIL: " + message)
    quit(1)

func _run() -> void:
    var grown: int = 0
    var substantial: int = 0
    for key in KEYS:
        var original: Array[Dictionary] = Props._authored_props_for(key)
        var displayed: Array[Dictionary] = Props.props_for(key)
        if displayed.size() != original.size():
            _fail(key + ": prop count changed")
            return
        var on_site_growth: int = 0
        for i in range(original.size()):
            var before: Dictionary = original[i]
            var after: Dictionary = displayed[i]
            if before["kind"] != after["kind"] or before["at"] != after["at"]:
                _fail(key + ": authored object placement changed")
                return
            var ratio: float = float(after["scale"]) / float(before["scale"])
            if ratio < 0.999 or ratio > 1.261:
                _fail(key + ": outside the approved enlarged prop range " + str(ratio))
                return
            if ratio >= 1.059:
                grown += 1
                on_site_growth += 1
            if ratio >= 1.149:
                substantial += 1
        if on_site_growth < 2:
            _fail(key + ": most site accents were left unchanged")
            return
    if grown < 28 or substantial < 15:
        _fail("overall dressing is not visibly larger; grew " + str(grown) +
            ", substantial " + str(substantial))
        return

    # The geometry Batch must enlarge around an existing anchor, with no
    # extra draw nodes. All ordinary machines keep its default 1x transform.
    var host := Node3D.new()
    var batch := Architecture.Batch.new(host)
    batch.pivot = Vector3(4.0, 0.0, 6.0)
    batch.detail_scale = 1.20
    batch.box("test", Vector3(5.0, 0.5, 6.0), Vector3.ONE, "armor")
    var poses: Array = batch.entries["cube|armor"]
    var pose: Transform3D = poses[0]
    if not pose.origin.is_equal_approx(Vector3(5.2, 0.6, 6.0)) or (
            not pose.basis.get_scale().is_equal_approx(Vector3.ONE * 1.20)):
        _fail("salvage enlargement did not preserve the anchor")
        return

    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    if scene == null:
        _fail("BASE scene does not load")
        return
    var base: Node3D = scene.instantiate()
    root.add_child(base)
    for frame in range(4):
        await process_frame
    var scaled_piles: int = 0
    for i in range(16):
        var pile: Node3D = base.get_node_or_null(
            "ScrapPile_%02d" % i) as Node3D
        if pile == null:
            _fail("original sixteen salvage anchors not preserved")
            return
        var scale: float = float(pile.get_meta("visual_scale", 1.0))
        if scale < 1.079 or scale > 1.261:
            _fail("independent scrap pile scale outside safe range")
            return
        scaled_piles += 1
    if scaled_piles != 16:
        _fail("missing yard salvage geometry")
        return
    print("SERA_BASE_ENLARGED_DRESSING_RUNTIME_PASS: grown=", grown,
        " substantial=", substantial, " scrap=", scaled_piles)
    quit(0)
