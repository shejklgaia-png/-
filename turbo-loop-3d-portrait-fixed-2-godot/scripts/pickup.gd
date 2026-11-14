extends Node3D
## Floating charge orb: collecting it adds a short turbo burst.

var available := true
var cooldown := 0.0
var _clock := 0.0
var _gem: Node3D

func _ready() -> void:
	_gem = Node3D.new()
	_gem.name = "FloatingTurboOrb"
	add_child(_gem)
	var core := MeshInstance3D.new()
	var diamond := SphereMesh.new()
	diamond.radius = 0.87
	diamond.height = 1.6
	diamond.radial_segments = 4
	diamond.rings = 2
	core.mesh = diamond
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color("fdd06e")
	core_mat.metallic = 0.25
	core_mat.roughness = 0.2
	core_mat.emission_enabled = true
	core_mat.emission = Color("ff9e54")
	core_mat.emission_energy_multiplier = 1.8
	core.material_override = core_mat
	_gem.add_child(core)
	var band := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.98
	ring.outer_radius = 1.08
	ring.rings = 12
	ring.ring_segments = 20
	band.mesh = ring
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color("fff0b6")
	band_mat.emission_enabled = true
	band_mat.emission = Color("e2fbef")
	band_mat.emission_energy_multiplier = 1.5
	band.material_override = band_mat
	band.rotation.x = PI / 3.0
	_gem.add_child(band)

func _process(delta: float) -> void:
	_clock += delta
	if not available:
		cooldown -= delta
		if cooldown <= 0.0:
			available = true
			_gem.visible = true
	if available:
		_gem.rotation.y += delta * 1.5
		_gem.position.y = 1.55 + sin(_clock * 3.2) * 0.22

func try_collect(kart: Node3D) -> bool:
	if not available:
		return false
	if Vector2(kart.position.x - position.x, kart.position.z - position.z).length() > 1.75:
		return false
	available = false
	cooldown = 8.0
	_gem.visible = false
	kart.add_boost(1.50)
	return true
