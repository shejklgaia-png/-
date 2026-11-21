extends SceneTree
## Full independent geometry validation for reproducible variable-sized cargo piles.
const Props = preload("res://scripts/sera_base_clutter.gd")
const SITES: Array[String] = [
    "NEXUS", "LABO", "SMELTER", "RECYCLER",
    "SCRAP_COLLECTOR", "STORAGE", "GENERATOR", "BUILD_TERMINAL",
]
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_BASE_CONTAINER_STACK_VARIATION_FAIL: " + why)
    quit(1)
func _run() -> void:
    var item_counts: Dictionary = {}
    var triple_support: int = 0
    var small_on_big: int = 0
    var size_levels: Dictionary = {}
    var group_count: int = 0
    for key in SITES:
        var objects: Array[Dictionary] = Props.props_for(key)
        if objects != Props.props_for(key):
            _fail("same facility must reproduce the same random layout")
            return
        for idx in range(objects.size()):
            var p: Dictionary = objects[idx]
            var kind: String = str(p["kind"])
            if not Props.is_stack_container(kind):
                continue
            var plan: Array[Dictionary] = Props.container_plan_for(
                key, kind, idx)
            var count: int = int(p["stack"])
            if count != plan.size() or count < 1 or count > 4:
                _fail("container count mismatch " + key + "/" + kind)
                return
            var footprint: Vector2 = Props.bounds_for(kind)
            item_counts[count] = true
            group_count += 1
            for j in range(plan.size()):
                var box: Dictionary = plan[j]
                var center: Vector2 = box["at"]
                var size: Vector3 = box["size"]
                var bottom: float = float(box["bottom"])
                var supports: Array[int] = box["supports"]
                size_levels[snappedf(size.x, 0.01)] = true
                if size.x <= 0 or size.y <= 0 or size.z <= 0:
                    _fail("invalid box dimensions")
                    return
                if absf(center.x) + size.x * 0.52 > footprint.x * 0.5 or (
                        absf(center.y) + size.z * 0.52 > footprint.y * 0.5):
                    _fail(key + " cargo exceeds its authored cluster footprint")
                    return
                if bottom < -0.0001 or bottom > 2.0:
                    _fail("invalid elevation")
                    return
                if j == 0 and bottom != 0.0:
                    _fail("first container must rest on ground")
                    return
                if bottom > 0.0:
                    if supports.is_empty():
                        _fail("floating upper container")
                        return
                    var largest_support: float = 0.0
                    for index in supports:
                        if index >= j or index < 0:
                            _fail("invalid support index")
                            return
                        var base: Dictionary = plan[index]
                        var below_top: float = float(base["bottom"]) + (
                            base["size"] as Vector3).y
                        if not is_equal_approx(bottom, below_top):
                            _fail("upper object is floating or intersects lower object")
                            return
                        var offset: Vector2 = center - (base["at"] as Vector2)
                        var width: float = maxf(0.0,
                            ((base["size"] as Vector3).x + size.x) * 0.5 -
                            absf(offset.x))
                        var depth: float = maxf(0.0,
                            ((base["size"] as Vector3).z + size.z) * 0.5 -
                            absf(offset.y))
                        largest_support = maxf(largest_support, width * depth)
                    if largest_support < 0.032:
                        _fail("insufficient supporting surface")
                        return
                for earlier in range(j):
                    var previous: Dictionary = plan[earlier]
                    var upper: float = float(previous["bottom"]) + (
                        previous["size"] as Vector3).y
                    if bottom >= upper - 0.0001 or (
                            bottom + size.y <= float(previous["bottom"]) + 0.0001):
                        continue
                    var prev_center: Vector2 = previous["at"]
                    var prev_size: Vector3 = previous["size"]
                    if absf(prev_center.x - center.x) < (
                            prev_size.x + size.x) * 0.5 - 0.002 and (
                            absf(prev_center.y - center.y) < (
                            prev_size.z + size.z) * 0.5 - 0.002):
                        _fail("containers occupy identical volume")
                        return
                if supports.size() == 2:
                    triple_support += 1
                if supports.size() == 1:
                    var support: Dictionary = plan[supports[0]]
                    if (support["size"] as Vector3).x > size.x * 1.5:
                        small_on_big += 1
    if group_count < 7 or item_counts.size() != 4:
        _fail("not all counts 1,2,3,4 are represented")
        return
    if triple_support < 2 or small_on_big < 1 or size_levels.size() < 3:
        _fail("pyramid and big-base/small-top combinations not diverse enough")
        return
    print("SERA_BASE_CONTAINER_STACK_VARIATION_RUNTIME_PASS groups=",
        group_count, " pyramids=", triple_support, " stepped=", small_on_big)
    quit(0)
