extends SceneTree
## Independent art-layout contract: clustered objects, long open bands and
## alternating dominant sides across adjacent facility pads.
const Props = preload("res://scripts/sera_base_clutter.gd")
const KEYS := [
    "NEXUS", "LABO", "SMELTER", "RECYCLER",
    "SCRAP_COLLECTOR", "STORAGE", "GENERATOR", "BUILD_TERMINAL",
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_PROP_DENSITY_RHYTHM_FAIL: " + message)
    quit(1)

func _dense_run(sorted: Array[float]) -> int:
    var current: int = 1
    var longest: int = 1
    for i in range(1, sorted.size()):
        var span: float = sorted[i] - sorted[i - 1]
        if span >= 0.86 and span <= 1.32:
            current += 1
        else:
            current = 1
        longest = maxi(longest, current)
    return longest

func _open_gap(sorted: Array[float]) -> float:
    var widest: float = 0.0
    for i in range(1, sorted.size()):
        widest = maxf(widest, sorted[i] - sorted[i - 1])
    return widest

func _run() -> void:
    var left_dominant: int = 0
    var right_dominant: int = 0
    var total: int = 0
    var stack_variants: Dictionary = {}
    var four_box_groups: int = 0
    for key in KEYS:
        var objects: Array[Dictionary] = Props.props_for(key)
        var left: Array[float] = []
        var right: Array[float] = []
        var accent: int = 0
        for item in objects:
            # Compact satellites sit beside larger clusters; they must NOT
            # erase the original four-beat primary-object rhythm.
            if bool(item.get("accent", false)):
                continue
            var at: Vector2 = item["at"]
            var scale: float = float(item["scale"])
            if at.x < 0:
                left.append(at.y)
            else:
                right.append(at.y)
            if scale <= 0.87:
                accent += 1
            var count: int = int(item["stack"])
            if count > 1:
                stack_variants[count] = true
            if count == 4:
                four_box_groups += 1
        left.sort()
        right.sort()
        var dense: Array[float] = left if left.size() > right.size() else right
        var sparse: Array[float] = right if left.size() > right.size() else left
        if dense.size() < 4 or dense.size() < sparse.size() + 1:
            _fail(key + " lost the asymmetric density grouping")
            return
        if _dense_run(dense) < 4:
            _fail(key + " has no four-part tightly grouped visual beat")
            return
        if sparse.size() < 2 or _open_gap(sparse) < 2.50:
            _fail(key + " lacks a wide negative-space gap")
            return
        if accent < 1:
            _fail(key + " lacks a smaller visual punctuation element")
            return
        if key not in ["NEXUS", "LABO"]:
            if left.size() > right.size():
                left_dominant += 1
            else:
                right_dominant += 1
        total += objects.size()
    if total != 52 or left_dominant != 3 or right_dominant != 3:
        _fail("overall layout is not balanced across opposing dense sides")
        return
    if not stack_variants.has(2) or not stack_variants.has(3) or (
            not stack_variants.has(4)) or four_box_groups < 1:
        _fail("new 1–4 box quantity variation missing")
        return
    print("SERA_BASE_PROP_DENSITY_RHYTHM_RUNTIME_PASS groups=", total,
        " left=", left_dominant, " right=", right_dominant)
    quit(0)
