extends Node3D
# v119: restore Godot 4 environment constant; lightweight static hangar, noninteractive equipment.
const DARK := Color("#222935")
const MID := Color("#384050")
const LIGHT := Color("#5c6577")
const CYAN := Color("#35c9f6")
const AMBER := Color("#e3a832")
func _mat(c: Color, glowing: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = 0.18
    m.roughness = 0.7
    if glowing:
        m.emission_enabled = true
        m.emission = c
        m.emission_energy_multiplier = 1.7
    return m
func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: bool = false) -> void:
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    mesh.material_override = _mat(color, glow)
    mesh.position = pos
    parent.add_child(mesh)
func _ring(parent: Node3D, pos: Vector3, radius: float, count: int, color: Color, glow: bool = false) -> void:
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        var piece := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(TAU * radius / count * 0.85, 0.13, 0.32)
        piece.mesh = mesh
        piece.material_override = _mat(color, glow)
        piece.position = pos + Vector3(sin(angle) * radius, 0, cos(angle) * radius)
        piece.rotation.y = angle
        parent.add_child(piece)
func _terminal(pos: Vector3, wide: bool = false) -> void:
    var n := Node3D.new()
    n.position = pos
    add_child(n)
    var w := 2.4 if wide else 1.25
    _box(n, Vector3(0, 0.85, 0), Vector3(w, 1.7, 0.8), MID)
    _box(n, Vector3(0, 1.72, -0.22), Vector3(w * 0.94, 1.1, 0.22), LIGHT)
    _box(n, Vector3(0, 1.72, -0.35), Vector3(w * 0.78, 0.82, 0.035), Color("#123c57"), true)
    _box(n, Vector3(0, 1.04, -0.52), Vector3(w * 0.7, 0.08, 0.12), CYAN, true)
func _gate() -> void:
    var n := Node3D.new()
    n.position = Vector3(5.1, 0, -8.8)
    add_child(n)
    for x in [-2.1, 2.1]:
        _box(n, Vector3(x, 2.2, 0), Vector3(0.65, 4.4, 0.9), MID)
        _box(n, Vector3(x, 2.1, -0.52), Vector3(0.1, 2.4, 0.05), CYAN, true)
    _box(n, Vector3(0, 4.35, 0), Vector3(4.85, 0.7, 0.9), MID)
    for x in [-1.6, -0.8, 0.8, 1.6]:
        _box(n, Vector3(x, 4.74, -0.05), Vector3(0.34, 0.06, 0.8), AMBER)
    _box(n, Vector3(0, 0.05, -1.8), Vector3(3.5, 0.1, 3.6), DARK)
    for x in [-1.5, 1.5]:
        _box(n, Vector3(x, 0.12, -1.8), Vector3(0.07, 0.03, 3.5), CYAN, true)
func _ready() -> void:
    _box(self, Vector3(0, -0.15, -2), Vector3(19, 0.3, 23), DARK)
    _box(self, Vector3(0, 5.8, -13.2), Vector3(19, 11.6, 0.45), DARK)
    for x in [-9.2, 9.2]:
        _box(self, Vector3(x, 5.2, -2), Vector3(0.5, 10.4, 23), MID)
    for x in [-7.5, -4.5, 4.5, 7.5]:
        _box(self, Vector3(x, 5.4, -12.7), Vector3(0.55, 10.8, 0.7), MID)
    for z in range(-12, 9, 3):
        _box(self, Vector3(0, -0.002, z), Vector3(18, 0.015, 0.025), LIGHT)
    for x in range(-8, 9, 2):
        _box(self, Vector3(x, 0.0, -2), Vector3(0.025, 0.015, 22), LIGHT)
    _box(self, Vector3(0, 5, -10.8), Vector3(2.2, 10, 2), MID)
    _ring(self, Vector3(0, 9.0, -10.7), 2.6, 12, MID)
    _ring(self, Vector3(0, 8.78, -10.7), 2.2, 12, CYAN, true)
    _ring(self, Vector3(0, 0.25, -4.2), 2.1, 16, MID)
    _ring(self, Vector3(0, 0.36, -4.2), 1.93, 12, CYAN, true)
    _box(self, Vector3(0, 0.25, -4.2), Vector3(2.7, 0.3, 2.7), MID)
    _terminal(Vector3(-5.8, 0, -8.0), true)
    _terminal(Vector3(-5.7, 0, -1.8))
    _terminal(Vector3(5.7, 0, -1.8))
    _gate()
    var rig := Node3D.new()
    rig.set_script(load("res://scripts/sera_rig.gd"))
    rig.position = Vector3(0, 0.43, -4.2)
    rig.rotation.y = PI
    add_child(rig)
    var cam := Camera3D.new()
    cam.position = Vector3(0, 5.5, 13.5)
    add_child(cam)
    cam.look_at(Vector3(0, 3.1, -5.2))
    cam.current = true
    cam.fov = 55
    var ambient := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#0b101a")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_sky_contribution = 0.0
    env.ambient_light_color = Color("#a0b8d4")
    env.ambient_light_energy = 0.65
    ambient.environment = env
    add_child(ambient)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, -25, 0)
    light.light_energy = 1.0
    add_child(light)
    _labels()
func _labels() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(ui)
    for entry in [
        ["SERA SYSTEM", Vector2(25, 22), 28],
        ["DATA ARCHIVE", Vector2(22, 360), 22],
        ["DEPLOYMENT", Vector2(490, 320), 22],
        ["TRAINING", Vector2(20, 645), 24],
        ["SYSTEM", Vector2(515, 650), 24],
        ["CUSTOMIZE", Vector2(255, 900), 27]
    ]:
        var label := Label.new()
        label.text = entry[0]
        label.position = entry[1]
        label.add_theme_font_size_override("font_size", entry[2])
        label.add_theme_color_override("font_color", CYAN)
        ui.add_child(label)
