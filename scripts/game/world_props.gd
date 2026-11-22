extends Node3D
## Rozrzuca low-poly skały i drzewa (punkty odniesienia przy chodzeniu) oraz góry
## i skalne słupy z kolizją (do latania i lądowania).

@export var count: int = 220
@export var area: float = 160.0
@export var clear_radius: float = 14.0
@export var seed: int = 42
@export var mountain_count: int = 16
@export var pillar_count: int = 10
@export_group("Drobne punkty odniesienia (skala smoka)")
@export var detail_radius: float = 140.0
@export var grass_count: int = 3500
@export var flower_count: int = 1200
@export var bush_count: int = 220

## Szczyty skalnych słupów (globalnie) — tam leżą ukryte skrytki ze złotem (tylko dla latających).
var pillar_tops: Array[Vector3] = []


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
		var pillar_pos := Vector3(cos(ang), 0, sin(ang)) * dist
		if _in_lair(pillar_pos, 15.0):
			continue
		_add_peak(pillar_pos, h, rng.randf_range(6.0, 11.0), mountain_mats[0], null, rng)
		pillar_tops.append(global_position + pillar_pos + Vector3.UP * h)
	_add_ground_details(rng)
	for i in count:
		var pos := Vector3(rng.randf_range(-area, area), 0.0, rng.randf_range(-area, area))
		if pos.length() < clear_radius or _in_lair(pos, 4.0):
			continue
		if rng.randf() < 0.45:
			_add_rock(pos, rng, rock_mat)
		else:
			_add_tree(pos, rng, trunk_mat, leaf_mats[rng.randi() % leaf_mats.size()])


## Czy punkt leży na wzgórzu legowiska (tam nic nie stawiamy).
func _in_lair(pos: Vector3, margin: float = 0.0) -> bool:
	return Vector2(pos.x - Lair.POSITION.x, pos.z - Lair.POSITION.z).length() < Lair.RADIUS + margin


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


# --- Drobiazgi przy ziemi: trawa, kwiaty, krzaki (MultiMesh — tanie na telefonie) -----

func _add_ground_details(rng: RandomNumberGenerator) -> void:
	var grass := _multimesh(_grass_mesh(), grass_count, rng, 0.25, 0.45, false)
	grass.name = "Grass"
	var flowers := _multimesh(_flower_mesh(), flower_count, rng, 0.25, 0.4, true)
	flowers.name = "Flowers"
	var palette := [Color(1.0, 0.85, 0.2), Color(0.95, 0.35, 0.4), Color(0.6, 0.5, 1.0), Color(1, 1, 1),
		Color(1.0, 0.55, 0.15)]
	for i in flower_count:
		flowers.multimesh.set_instance_color(i, palette[rng.randi() % palette.size()])
	var bushes := _multimesh(_bush_mesh(), bush_count, rng, 0.7, 1.4, false)
	bushes.name = "Bushes"


func _multimesh(mesh: Mesh, n: int, rng: RandomNumberGenerator, s_min: float, s_max: float,
		colors: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = n
	for i in n:
		# gęściej blisko startu, rzadziej dalej
		var r := detail_radius * sqrt(rng.randf()) * (0.4 + 0.6 * rng.randf())
		var a := rng.randf() * TAU
		var sc := rng.randf_range(s_min, s_max)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
		var pos := Vector3(cos(a) * r, 0.0, sin(a) * r)
		if _in_lair(pos):
			basis = basis.scaled(Vector3.ZERO)  # na wzgórzu / w jaskini — ukryj (stała liczba instancji)
		mm.set_instance_transform(i, Transform3D(basis, pos))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst


func _grass_mesh() -> Mesh:
	# kępa: 3 trójkątne źdźbła (wys. ~1 m przed skalowaniem)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := TAU * k / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.12
		var tip := d * 0.25 + Vector3.UP * 1.0
		st.add_vertex(-side)
		st.add_vertex(side)
		st.add_vertex(tip)
		st.add_vertex(side)
		st.add_vertex(-side)
		st.add_vertex(tip)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _flat_material(Color(0.42, 0.66, 0.3)))
	return m


func _flower_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# łodyżka (cienki trójkąt) + główka (ośmiościan)
	st.set_color(Color(0.3, 0.6, 0.25))
	st.add_vertex(Vector3(-0.03, 0, 0))
	st.add_vertex(Vector3(0.03, 0, 0))
	st.add_vertex(Vector3(0, 0.9, 0))
	var c := Vector3(0, 0.95, 0)
	var pts := [Vector3(0.18, 0, 0), Vector3(0, 0, 0.18), Vector3(-0.18, 0, 0), Vector3(0, 0, -0.18)]
	for i in 4:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 4]
		for tip in [Vector3(0, 0.12, 0), Vector3(0, -0.08, 0)]:
			st.set_color(Color.WHITE)
			st.add_vertex(c + a)
			st.add_vertex(c + b)
			st.add_vertex(c + tip)
	st.generate_normals()
	var m := st.commit()
	var mat := _flat_material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	return m


func _bush_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 0.9
	sm.radial_segments = 7
	sm.rings = 4
	sm.material = _flat_material(Color(0.25, 0.5, 0.22))
	return sm
