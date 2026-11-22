extends Node3D
## Rozrzuca low-poly skały i drzewa (punkty odniesienia przy chodzeniu) oraz góry
## i skalne słupy z kolizją (do latania i lądowania).

@export var count: int = 220
@export var area: float = 160.0
@export var clear_radius: float = 14.0
@export var seed: int = 42
@export var mountain_count: int = 16
@export var pillar_count: int = 10


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rock_mat := _flat_material(Color(0.42, 0.41, 0.38))
	var trunk_mat := _flat_material(Color(0.33, 0.24, 0.16))
	var leaf_mats := [_flat_material(Color(0.2, 0.36, 0.18)), _flat_material(Color(0.26, 0.42, 0.2)),
		_flat_material(Color(0.17, 0.3, 0.16))]
	var mountain_mats := [_flat_material(Color(0.45, 0.44, 0.41)), _flat_material(Color(0.38, 0.37, 0.35))]
	var snow_mat := _flat_material(Color(0.92, 0.93, 0.95))
	for i in mountain_count:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(220.0, 650.0)
		var h := rng.randf_range(60.0, 160.0)
		_add_peak(Vector3(cos(ang), 0, sin(ang)) * dist, h, h * rng.randf_range(0.7, 1.1),
			mountain_mats[i % 2], snow_mat, rng)
	for i in pillar_count:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(60.0, 180.0)
		var h := rng.randf_range(18.0, 45.0)
		_add_peak(Vector3(cos(ang), 0, sin(ang)) * dist, h, rng.randf_range(6.0, 11.0), mountain_mats[0], null, rng)
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


func _add_peak(pos: Vector3, height: float, radius: float, mat: Material, snow: Material,
		rng: RandomNumberGenerator) -> void:
	"""Góra / skalny słup: stożek z kolizją, opcjonalnie ze śnieżną czapą."""
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rng.randf() * TAU
	add_child(body)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * rng.randf_range(0.05, 0.25)
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = rng.randi_range(6, 9)
	mesh.rings = 2
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = height / 2.0
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_convex_shape()
	col.position.y = height / 2.0
	body.add_child(col)
	if snow:
		var cap := CylinderMesh.new()
		cap.top_radius = mesh.top_radius * 1.02
		cap.bottom_radius = lerpf(mesh.top_radius, radius, 0.22) * 1.02
		cap.height = height * 0.22
		cap.radial_segments = mesh.radial_segments
		cap.material = snow
		var ci := MeshInstance3D.new()
		ci.mesh = cap
		ci.position.y = height - cap.height / 2.0
		body.add_child(ci)
