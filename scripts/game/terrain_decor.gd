class_name TerrainDecor
extends Node3D
## Roślinność i skały na kawałkach terenu (MultiMesh na kawałek — tanie na telefonie):
## - drzewa (las wg Terrain.forest) i głazy — dla każdego kawałka od razu,
## - trawa, kwiaty i krzaki (punkty odniesienia przy ziemi) — dopiero gdy smok jest blisko.
## Wszystko stoi na wysokości terenu i omija wodę, legowisko i strome zbocza.

@export var trees_per_chunk: int = 140
@export var rocks_per_chunk: int = 10
@export var grass_per_chunk: int = 1100
@export var flowers_per_chunk: int = 300
@export var bushes_per_chunk: int = 28

var terrain: Terrain

var _tree_mesh: Mesh
var _rock_mesh: Mesh
var _grass_mesh: Mesh
var _flower_mesh: Mesh
var _bush_mesh: Mesh
var _done_big: Dictionary = {}
var _done_small: Dictionary = {}


func _ready() -> void:
	_tree_mesh = _make_tree_mesh()
	_rock_mesh = _make_rock_mesh()
	_grass_mesh = _make_grass_mesh()
	_flower_mesh = _make_flower_mesh()
	_bush_mesh = _make_bush_mesh()
	terrain.chunk_built.connect(_on_chunk_built)


func _on_chunk_built(c: Vector2i, lod: int) -> void:
	if not _done_big.has(c):
		_done_big[c] = true
		_scatter_big(c)
	if lod == 0 and not _done_small.has(c):
		_done_small[c] = true
		_scatter_small(c)


static func _blocked(x: float, z: float) -> bool:
	if Vector2(x - Lair.POSITION.x, z - Lair.POSITION.z).length() < Lair.RADIUS + 4.0:
		return true
	return Terrain.height(x, z) < Terrain.WATER_LEVEL + 0.6


func _rng_for(c: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, salt))
	return rng


func _scatter_big(c: Vector2i) -> void:
	var o := terrain.chunk_origin(c)
	var rng := _rng_for(c, 1)
	var trees: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	for i in trees_per_chunk:
		var x := o.x + rng.randf() * Terrain.CHUNK
		var z := o.z + rng.randf() * Terrain.CHUNK
		var f := Terrain.forest(x, z)
		var h := Terrain.height(x, z)
		# las gęsty, poza nim pojedyncze drzewa; nie na skałach/szczytach
		if rng.randf() > f * 0.95 + 0.03 or h > 70.0 or _blocked(x, z):
			continue
		if absf(Terrain.height(x + 2.0, z) - h) > 1.6:
			continue
		var s := rng.randf_range(0.7, 1.35) * (1.0 + 0.3 * f)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		trees.append(Transform3D(basis, Vector3(x, h - 0.2, z)))
		tree_cols.append(Color(1, 1, 1).darkened(rng.randf() * 0.25))
	_add_multimesh(_tree_mesh, trees, tree_cols, 900.0, true)
	var rocks: Array[Transform3D] = []
	for i in rocks_per_chunk:
		var x := o.x + rng.randf() * Terrain.CHUNK
		var z := o.z + rng.randf() * Terrain.CHUNK
		if _blocked(x, z):
			continue
		var s := rng.randf_range(0.6, 3.2)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)) \
			.scaled(Vector3(s * rng.randf_range(0.8, 1.5), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.4)))
		rocks.append(Transform3D(basis, Vector3(x, Terrain.height(x, z) + s * 0.1, z)))
	_add_multimesh(_rock_mesh, rocks, [], 700.0, true)


func _scatter_small(c: Vector2i) -> void:
	var o := terrain.chunk_origin(c)
	var rng := _rng_for(c, 2)
	for kind in 3:
		var n: int = [grass_per_chunk, flowers_per_chunk, bushes_per_chunk][kind]
		var mesh: Mesh = [_grass_mesh, _flower_mesh, _bush_mesh][kind]
		var xs: Array[Transform3D] = []
		var cols: Array[Color] = []
		for i in n:
			var x := o.x + rng.randf() * Terrain.CHUNK
			var z := o.z + rng.randf() * Terrain.CHUNK
			var h := Terrain.height(x, z)
			if h > 45.0 or _blocked(x, z):
				continue
			var s: float = [rng.randf_range(0.25, 0.45), rng.randf_range(0.25, 0.4), rng.randf_range(0.6, 1.4)][kind]
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h, z)))
			if kind == 1:
				cols.append([Color(0.95, 0.85, 0.3), Color(0.9, 0.45, 0.6), Color(0.95, 0.95, 0.95),
					Color(0.6, 0.55, 0.95)][rng.randi() % 4])
		_add_multimesh(mesh, xs, cols, 160.0 if kind < 2 else 300.0, kind == 2)


func _add_multimesh(mesh: Mesh, xs: Array[Transform3D], cols: Array, vis_range: float, shadows: bool) -> void:
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.visibility_range_end = vis_range
	inst.visibility_range_end_margin = vis_range * 0.1
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


# --- Siatki (low-poly, kolor wierzchołków) ------------------------------------------

static func _vc_material(cull: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	if not cull:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Stożek/walec low-poly z płaskimi ściankami do SurfaceTool.
static func _cone(st: SurfaceTool, base_y: float, top_y: float, r0: float, r1: float, sides: int, col: Color) -> void:
	st.set_color(col)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var b0 := Vector3(cos(a0) * r0, base_y, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, base_y, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, top_y, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, top_y, sin(a1) * r1)
		st.add_vertex(b0); st.add_vertex(t0); st.add_vertex(b1)
		if r1 > 0.001:
			st.add_vertex(b1); st.add_vertex(t0); st.add_vertex(t1)


func _make_tree_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 0.0, 2.6, 0.32, 0.22, 6, Color(0.33, 0.24, 0.16))
	var greens := [Color(0.2, 0.36, 0.18), Color(0.23, 0.4, 0.2), Color(0.18, 0.32, 0.16)]
	for k in 3:
		var y0 := 1.8 + k * 1.7
		_cone(st, y0, y0 + 3.0 - k * 0.5, 2.5 - k * 0.6, 0.0, 7, greens[k])
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _vc_material())
	return m


func _make_rock_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radial_segments = 7
	sm.rings = 4
	sm.radius = 1.0
	sm.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.41, 0.38)
	mat.roughness = 1.0
	sm.material = mat
	return sm


func _make_grass_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.42, 0.66, 0.3))
	for k in 3:
		var a := TAU * k / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.12
		var tip := d * 0.25 + Vector3.UP * 1.0
		st.add_vertex(-side); st.add_vertex(side); st.add_vertex(tip)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _vc_material(false))
	return m


func _make_flower_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.3, 0.6, 0.25))
	st.add_vertex(Vector3(-0.03, 0, 0)); st.add_vertex(Vector3(0.03, 0, 0)); st.add_vertex(Vector3(0, 0.9, 0))
	var c := Vector3(0, 0.95, 0)
	var pts := [Vector3(0.18, 0, 0), Vector3(0, 0, 0.18), Vector3(-0.18, 0, 0), Vector3(0, 0, -0.18)]
	st.set_color(Color.WHITE)
	for i in 4:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 4]
		for tip: Vector3 in [Vector3(0, 0.12, 0), Vector3(0, -0.08, 0)]:
			st.add_vertex(c + a); st.add_vertex(c + b); st.add_vertex(c + tip)
	st.generate_normals()
	var m := st.commit()
	var mat := _vc_material(false)
	m.surface_set_material(0, mat)
	return m


func _make_bush_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 0.9
	sm.radial_segments = 7
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.5, 0.22)
	mat.roughness = 1.0
	sm.material = mat
	return sm
