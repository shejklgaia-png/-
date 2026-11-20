extends RefCounted
## Canonical CRATE mesh factory, shared without variation by the outdoor base and LABO.
## The same tracked robot silhouette, visor, hand pivots and material palette
## are constructed in both worlds. No facial glyphs, textures or shader passes.
static var _materials: Dictionary = {}

static func _mat(color: String, glowing: bool = false) -> StandardMaterial3D:
    var key: String = color + ("_light" if glowing else "_solid")
    if _materials.has(key):
        return _materials[key] as StandardMaterial3D
    var result := StandardMaterial3D.new()
    result.albedo_color = Color(color)
    result.metallic = 0.32
    result.roughness = 0.62
    if glowing:
        result.emission_enabled = true
        result.emission = Color(color)
        result.emission_energy_multiplier = 1.25
    _materials[key] = result
    return result

static func _box(parent: Node3D, name: String, pos: Vector3,
        extent: Vector3, color: String, glowing: bool = false) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = name
    var box := BoxMesh.new()
    box.size = extent
    part.mesh = box
    part.material_override = _mat(color, glowing)
    part.position = pos
    parent.add_child(part)
    return part

static func _wheel(parent: Node3D, name: String, pos: Vector3,
        radius: float, color: String) -> void:
    var wheel := MeshInstance3D.new()
    wheel.name = name
    var disk := CylinderMesh.new()
    disk.top_radius = radius
    disk.bottom_radius = radius
    disk.height = 0.07
    disk.radial_segments = 10
    wheel.mesh = disk
    wheel.material_override = _mat(color)
    wheel.position = pos
    wheel.rotation_degrees.z = 90.0
    parent.add_child(wheel)

static func _shell(parent: Node3D, name: String, pos: Vector3,
        size: Vector3, color: String) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = name
    var shell := SphereMesh.new()
    shell.radius = 0.5
    shell.height = 1.0
    shell.radial_segments = 12
    shell.rings = 6
    part.mesh = shell
    part.material_override = _mat(color)
    part.position = pos
    part.scale = size
    parent.add_child(part)
    return part

static func create_model() -> Node3D:
    var robot := Node3D.new()
    robot.name = "CRATE"
    var track_colors := ["#27343d", "#34434e", "#526574"]
    # Both tracks have a believable continuous belt, wheel hubs and tread plates.
    for side in [-1, 1]:
        var s: float = float(side)
        var track := Node3D.new()
        track.name = "LeftTrack" if side < 0 else "RightTrack"
        track.position.x = s * 0.49
        robot.add_child(track)
        _box(track, "TrackBelt", Vector3(0, 0.24, 0.02),
            Vector3(0.29, 0.37, 1.00), track_colors[0])
        _box(track, "TrackShoulder", Vector3(s * 0.12, 0.37, 0.00),
            Vector3(0.055, 0.18, 0.84), "#718b9a")
        for k in range(3):
            var wheel_z: float = -0.33 + float(k) * 0.33
            _wheel(track, "RoadWheel", Vector3(s * 0.168, 0.23, wheel_z),
                0.135, "#465967")
            _wheel(track, "WheelHub", Vector3(s * 0.211, 0.23, wheel_z),
                0.055, "#a5b8c3")
        for k in range(10):
            _box(track, "TreadPlate", Vector3(0, 0.047, -0.435 + float(k)*0.096),
                Vector3(0.30, 0.058, 0.071), "#526574")
        _box(track, "ForwardGuard", Vector3(0, 0.46, -0.42),
            Vector3(0.31, 0.13, 0.18), "#8198a7")

    _box(robot, "LowerFrame", Vector3(0, 0.37, 0.02),
        Vector3(0.85, 0.28, 0.80), "#344654")
    _box(robot, "ArmoredBody", Vector3(0, 0.56, 0.02),
        Vector3(0.90, 0.31, 0.76), "#8ea3b1")
    _box(robot, "FrontBreastplate", Vector3(0, 0.54, -0.375),
        Vector3(0.72, 0.20, 0.072), "#c0cbd1")
    _box(robot, "BodyTealAccent", Vector3(0, 0.69, -0.375),
        Vector3(0.55, 0.033, 0.037), "#38b5ca", true)
    for side in [-1, 1]:
        var s: float = float(side)
        _box(robot, "ShoulderPanel", Vector3(s*0.43, 0.66, -0.10),
            Vector3(0.18, 0.24, 0.49), "#b0bfc8")
        _box(robot, "SideVent", Vector3(s*0.46, 0.70, 0.26),
            Vector3(0.025, 0.075, 0.20), "#405967")
    _box(robot, "RearToolTray", Vector3(0, 0.73, 0.33),
        Vector3(0.59, 0.22, 0.25), "#556c7a")
    for i in range(4):
        _box(robot, "TrayRib", Vector3(-0.21 + float(i)*0.14, 0.84, 0.33),
            Vector3(0.04, 0.04, 0.22), "#8da6b4")

    var head := Node3D.new()
    head.name = "HeadPivot"
    head.position = Vector3(0, 0.89, -0.05)
    robot.add_child(head)
    _box(head, "NeckGimbal", Vector3(0, -0.10, 0.05),
        Vector3(0.41, 0.16, 0.38), "#3f5363")
    _shell(head, "RoundedHelmet", Vector3(0, 0.10, 0.02),
        Vector3(0.99, 0.52, 0.70), "#c3d0d7")
    _box(head, "ForeheadArmor", Vector3(0, 0.29, -0.16),
        Vector3(0.72, 0.085, 0.32), "#e0e6e8")
    _box(head, "VisorRecess", Vector3(0, 0.11, -0.334),
        Vector3(0.78, 0.22, 0.08), "#152c39")
    _box(head, "ContinuousVisor", Vector3(0, 0.11, -0.384),
        Vector3(0.68, 0.13, 0.033), "#43d1e5", true)
    _box(head, "VisorUpperBrow", Vector3(0, 0.235, -0.369),
        Vector3(0.77, 0.04, 0.075), "#778f9d")
    for side in [-1, 1]:
        _box(head, "CameraEar", Vector3(float(side)*0.485, 0.10, 0.025),
            Vector3(0.09, 0.17, 0.26), "#647f90")

    for side in [-1, 1]:
        var s: float = float(side)
        var arm := Node3D.new()
        arm.name = "LeftArmPivot" if side < 0 else "RightArmPivot"
        arm.position = Vector3(s*0.52, 0.64, -0.11)
        robot.add_child(arm)
        _box(arm, "ShoulderJoint", Vector3(s*0.05, 0.01, 0),
            Vector3(0.21, 0.22, 0.22), "#364e60")
        _box(arm, "UpperArm", Vector3(s*0.145, -0.05, -0.17),
            Vector3(0.19, 0.17, 0.35), "#9ab1bd")
        _box(arm, "ElbowCuff", Vector3(s*0.15, -0.07, -0.35),
            Vector3(0.23, 0.22, 0.15), "#526979")
        _box(arm, "Forearm", Vector3(s*0.15, -0.07, -0.53),
            Vector3(0.15, 0.14, 0.34), "#b8c7cd")
        _box(arm, "Palm", Vector3(s*0.15, -0.07, -0.72),
            Vector3(0.23, 0.14, 0.14), "#667f8f")
        # Three C-shaped mechanical fingers (claw tips curve inwards).
        for finger in range(3):
            var x: float = s*0.15 + (float(finger)-1.0)*0.095
            _box(arm, "FingerBase", Vector3(x, -0.075, -0.84),
                Vector3(0.062, 0.075, 0.19), "#aabfc9")
            _box(arm, "FingerHook", Vector3(x, -0.105, -0.94),
                Vector3(0.065, 0.12, 0.065), "#d0dade")
    return robot
