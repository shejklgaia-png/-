extends SceneTree
## Parse BASE motion in isolation so a broken preload cannot hide the true error.
func _initialize() -> void:
    var source: String = FileAccess.get_file_as_string(
        "res://scripts/sera_base_facility_motion.gd")
    if source.is_empty():
        push_error("SERA_BASE_MOTION_SOURCE_MISSING")
        quit(1)
        return
    var compiled := GDScript.new()
    compiled.source_code = source
    var status: Error = compiled.reload()
    if status != OK:
        push_error("SERA_BASE_MOTION_COMPILE_FAIL " + str(status))
        quit(1)
        return
    print("SERA_BASE_MOTION_COMPILE_PASS")
    quit(0)
