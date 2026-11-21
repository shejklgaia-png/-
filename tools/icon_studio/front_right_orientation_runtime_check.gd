extends SceneTree
## User-approved H02 camera is the universal 19-equipment icon orientation.
## With EULER_ORDER_XYZ and a +Z camera the +156.9007 yaw intentionally
## exposes the model's left side, not the old right-three-quarter angle.
const SOURCE = preload("res://scripts/sera_prototype_catalog.gd")
const CAMERA_PRESET_PATH: String = "res://assets/ui/sera_icon_presets/H02.json"
const APPROVED_POSE: Vector3 = Vector3(11.8749389648438, 156.900744628906, 0.0)

func _fail(reason: String) -> void:
    push_error("SERA_ICON_PRESET_ORIENTATION_FAIL: " + reason)
    quit(1)

func _initialize() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMERA_PRESET_PATH))
    if not parsed is Dictionary:
        _fail("Missing common approved portrait camera")
        return
    var render: Dictionary = parsed.get("render", {})
    var angles: Dictionary = render.get("model_rotation_deg", {})
    var chosen := Vector3(float(angles.get("x", -999)),
        float(angles.get("y", -999)), float(angles.get("z", -999)))
    if not chosen.is_equal_approx(APPROVED_POSE):
        _fail("Camera differs from user-supplied exact 11.87494/156.90074/0")
        return
    if not is_equal_approx(float(render.get("auto_fit", -1)), 0.76):
        _fail("Approved auto_fit 0.76 lost")
        return
    var rotation := Basis.from_euler(Vector3(
        deg_to_rad(chosen.x), deg_to_rad(chosen.y),
        deg_to_rad(chosen.z)), EULER_ORDER_XYZ)
    var toward_camera := Vector3.BACK
    var front_visibility: float = (rotation * Vector3.FORWARD).dot(toward_camera)
    var left_visibility: float = (rotation * Vector3.LEFT).dot(toward_camera)
    var top_visibility: float = (rotation * Vector3.UP).dot(toward_camera)
    if front_visibility <= 0.65:
        _fail("Approved camera would photograph the rear of the model")
        return
    if left_visibility <= 0.25:
        _fail("Approved left-facing three-quarter orientation mirrored")
        return
    if top_visibility <= 0.15:
        _fail("Approved model pitch would photograph the underside")
        return
    if SOURCE.ORDER.size() != 19:
        _fail("Expected exactly nineteen existing equipment slots")
        return
    print("SERA_ICON_PRESET_ORIENTATION_PASS front=%.3f left=%.3f top=%.3f parts=%d" % [
        front_visibility, left_visibility, top_visibility, SOURCE.ORDER.size()])
    quit(0)
