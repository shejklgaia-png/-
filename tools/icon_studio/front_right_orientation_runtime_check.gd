extends SceneTree
## Lock the authored model's actual front (-Z), right (+X), and roof (+Y)
## toward the fixed orthographic camera at world +Z. Catch a mirrored side
## or rear photograph even if PNG encoding, pose and margins all validate.
## Run in actual Godot: EULER_ORDER_XYZ rotates the X tilt AFTER Y, 
## so a POSITIVE X pitch exposes the upward surface toward camera +Z.
const SOURCE = preload("res://scripts/sera_prototype_catalog.gd")
const FRONT_RIGHT_TOP: Vector3 = Vector3(26.0, -146.0, 0.0)

func _initialize() -> void:
    var rotation := Basis.from_euler(Vector3(
        deg_to_rad(FRONT_RIGHT_TOP.x), deg_to_rad(FRONT_RIGHT_TOP.y),
        deg_to_rad(FRONT_RIGHT_TOP.z)), EULER_ORDER_XYZ)
    var toward_camera := Vector3.BACK
    var front_visibility: float = (rotation * Vector3.FORWARD).dot(toward_camera)
    var right_visibility: float = (rotation * Vector3.RIGHT).dot(toward_camera)
    var top_visibility: float = (rotation * Vector3.UP).dot(toward_camera)
    if front_visibility <= 0.65:
        push_error("SERA_ICON_FRONT_RIGHT_FAIL: rear view instead of face: "
            + str(front_visibility))
        quit(1)
        return
    if right_visibility <= 0.45:
        push_error("SERA_ICON_FRONT_RIGHT_FAIL: wrong lateral side: "
            + str(right_visibility))
        quit(1)
        return
    if top_visibility <= 0.23:
        push_error("SERA_ICON_FRONT_RIGHT_FAIL: underside instead of roof: "
            + str(top_visibility))
        quit(1)
        return
    if SOURCE.ORDER.size() != 19:
        push_error("SERA_ICON_FRONT_RIGHT_FAIL: catalog no longer has 19 parts")
        quit(1)
        return
    print("SERA_ICON_FRONT_RIGHT_PASS front=%.3f right=%.3f top=%.3f parts=%d" % [
        front_visibility, right_visibility, top_visibility, SOURCE.ORDER.size()])
    quit(0)
