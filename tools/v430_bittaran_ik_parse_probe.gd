extends SceneTree
## Explicit parse probe; exits on failure instead of hanging a headless
## battle test after a deferred call fails to load BittaranFootIK.
func _initialize() -> void:
    var path: String = "res://scripts/bittaran_foot_ik.gd"
    var source: String = FileAccess.get_file_as_string(path)
    if source.is_empty():
        push_error("V430_IK_PARSE_PROBE_FAIL: missing source")
        quit(1)
        return
    var parsed: GDScript = GDScript.new()
    parsed.source_code = source
    var code_error: Error = parsed.reload()
    print("V430_IK_PARSE_PROBE_CODE: ", error_string(code_error))
    if code_error != OK:
        push_error("V430_IK_PARSE_PROBE_FAIL: check parser error and line above")
        quit(1)
        return
    print("GODOT_V430_IK_PARSE_PASS")
    quit(0)
