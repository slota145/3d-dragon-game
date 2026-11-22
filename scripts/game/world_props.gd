extends Node3D
## Rozrzuca low-poly skały i drzewa po świecie (punkty odniesienia przy chodzeniu).

@export var count: int = 220
@export var area: float = 160.0
@export var clear_radius: float = 14.0
@export var seed: int = 42


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rock_mat := _flat_material(Color(0.42, 0.41, 0.38))
	var trunk_mat := _flat_material(Color(0.33, 0.24, 0.16))
	var leaf_mats := [_flat_material(Color(0.2, 0.36, 0.18)), _flat_material(Color(0.26, 0.42, 0.2)),
		_flat_material(Color(0.17, 0.3, 0.16))]
	for i in count:
		var pos := Vector3(rng.randf_range(-area, area), 0.0, rng.randf_range(-area, area))
		if pos.length() < clear_radius:
			continue
		if rng.randf() < 0.45:
			_add_rock(pos, rng, rock_mat)
		else:
			_add_tree(pos, rng, trunk_mat, leaf_mats[rng.randi() % leaf_mats.size()])


func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m


func _add_rock(pos: Vector3, rng: RandomNumberGenerator, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 4
	var s := rng.randf_range(0.6, 3.2)
	mesh.radius = s
	mesh.height = s * 2.0
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos + Vector3.UP * s * 0.25
	mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	mi.scale = Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.4))
	add_child(mi)


func _add_tree(pos: Vector3, rng: RandomNumberGenerator, trunk_mat: Material, leaf_mat: Material) -> void:
	var h := rng.randf_range(5.0, 11.0)
	var trunk := CylinderMesh.new()
	trunk.top_radius = h * 0.03
	trunk.bottom_radius = h * 0.05
	trunk.height = h * 0.4
	trunk.radial_segments = 6
	trunk.material = trunk_mat
	var t := MeshInstance3D.new()
	t.mesh = trunk
	t.position = pos + Vector3.UP * h * 0.2
	add_child(t)
	for k in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = h * (0.28 - 0.06 * k)
		cone.height = h * 0.42
		cone.radial_segments = 7
		cone.material = leaf_mat
		var c := MeshInstance3D.new()
		c.mesh = cone
		c.position = pos + Vector3.UP * (h * (0.45 + 0.18 * k))
		c.rotation.y = rng.randf() * TAU
		add_child(c)
