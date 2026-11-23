class_name TerrainDecor
extends Node3D
## Roślinność i skały na kawałkach terenu (MultiMesh na kawałek — tanie na telefonie),
## tworzone w pierścieniu wokół smoka i usuwane, gdy się oddali (świat 4×4 km):
## - drzewa (las wg Terrain.forest) i głazy — do BIG_RING kawałków od smoka,
## - trawa, kwiaty i krzaki (punkty odniesienia przy ziemi) — do SMALL_RING.
## Wszystko stoi na wysokości terenu i omija wodę, legowisko i strome zbocza.

@export var trees_per_chunk: int = 140
@export var rocks_per_chunk: int = 10
@export var grass_per_chunk: int = 1100
@export var flowers_per_chunk: int = 300
@export var bushes_per_chunk: int = 28

var terrain: Terrain

const BIG_RING := 5
const SMALL_RING := 1
## Ile kawałków roślinności tworzyć na klatkę (bez przycięć).
const PER_FRAME := 2

var _tree_mesh: Mesh
var _rock_mesh: Mesh
var _grass_mesh: Mesh
var _flower_mesh: Mesh
var _bush_mesh: Mesh
var _big: Dictionary = {}  # Vector2i -> Node3D (drzewa + skały)
var _small: Dictionary = {}  # Vector2i -> Node3D (trawa, kwiaty, krzaki)
var _center := Vector2i(-999, -999)
var _todo: Array[Vector2i] = []


## Siatki z nature.glb (tools/blender/gen_nature.py): drzewa, kamienie, krzewy.
var _nature: Dictionary = {}
## Tanie sylwetki drzew na dalszy plan (LOD): stożek (iglaste) i kula (liściaste).
var _far_cone: Mesh
var _far_round: Mesh
## Kolor sylwetki z daleka wg gatunku.
const SPECIES_FAR_COLOR := {
	"Pine": Color(0.16, 0.4, 0.22), "PineTall": Color(0.14, 0.36, 0.2), "Oak": Color(0.32, 0.62, 0.2),
	"Birch": Color(0.55, 0.78, 0.3), "Autumn": Color(0.95, 0.52, 0.15), "Blossom": Color(0.98, 0.7, 0.78),
}
## Drzewa szczegółowe do tej odległości, dalej sylwetki.
const TREE_NEAR := 230.0


func _ready() -> void:
	var scene: Node = (load("res://assets/models/nature.glb") as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		_nature[String(mi.name)] = mi.mesh
	scene.free()
	_far_cone = _make_far_tree(true)
	_far_round = _make_far_tree(false)
	_grass_mesh = _make_grass_mesh()
	_flower_mesh = _make_flower_mesh()


## Od razu zbuduj roślinność wokół punktu (start gry, teleport).
func build_around(at: Vector3) -> void:
	_center = terrain.chunk_of(at)
	_refresh_todo()
	while not _todo.is_empty():
		_build(_todo.pop_front())


func _process(_delta: float) -> void:
	if not terrain.focus:
		return
	var c := terrain.chunk_of(terrain.focus.global_position)
	if c != _center:
		_center = c
		_refresh_todo()
		_drop_far()
	for i in PER_FRAME:
		if _todo.is_empty():
			break
		_build(_todo.pop_front())


func _ring(c: Vector2i) -> int:
	return maxi(absi(c.x - _center.x), absi(c.y - _center.y))


func _refresh_todo() -> void:
	_todo.clear()
	for dx in range(-BIG_RING, BIG_RING + 1):
		for dz in range(-BIG_RING, BIG_RING + 1):
			var c := _center + Vector2i(dx, dz)
			if c.x < 0 or c.y < 0 or c.x >= Terrain.CHUNKS or c.y >= Terrain.CHUNKS:
				continue
			if not _big.has(c) or (_ring(c) <= SMALL_RING and not _small.has(c)):
				_todo.append(c)
	_todo.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _ring(a) < _ring(b))


func _build(c: Vector2i) -> void:
	if not _big.has(c):
		_big[c] = _scatter_big(c)
	if _ring(c) <= SMALL_RING and not _small.has(c):
		_small[c] = _scatter_small(c)


func _drop_far() -> void:
	for c: Vector2i in _big.keys():
		if _ring(c) > BIG_RING + 1:
			(_big[c] as Node).queue_free()
			_big.erase(c)
	for c: Vector2i in _small.keys():
		if _ring(c) > SMALL_RING + 2:
			(_small[c] as Node).queue_free()
			_small.erase(c)


static func _blocked(x: float, z: float) -> bool:
	if Vector2(x - Lair.POSITION.x, z - Lair.POSITION.z).length() < Lair.RADIUS + 4.0:
		return true
	return Terrain.height(x, z) < Terrain.WATER_LEVEL + 0.6


func _rng_for(c: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, salt))
	return rng


func _scatter_big(c: Vector2i) -> Node3D:
	var group := Node3D.new()
	add_child(group)
	var o := terrain.chunk_origin(c)
	var rng := _rng_for(c, 1)
	var by_species: Dictionary = {}  # gatunek -> Array[Transform3D]
	var far_cone: Array[Transform3D] = []
	var far_cone_cols: Array[Color] = []
	var far_round: Array[Transform3D] = []
	var far_round_cols: Array[Color] = []
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
		var s := rng.randf_range(0.75, 1.3) * (1.0 + 0.25 * f)
		var sp := Terrain.tree_species(x, z, rng.randf())
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
		var xf := Transform3D(basis, Vector3(x, h - 0.2, z))
		if not by_species.has(sp):
			by_species[sp] = [] as Array[Transform3D]
		by_species[sp].append(xf)
		var far_col: Color = SPECIES_FAR_COLOR[sp]
		if sp.begins_with("Pine"):
			far_cone.append(xf)
			far_cone_cols.append(far_col.darkened(rng.randf() * 0.15))
		else:
			far_round.append(xf)
			far_round_cols.append(far_col.darkened(rng.randf() * 0.15))
	for sp: String in by_species:
		_add_multimesh(group, _nature["Tree_" + sp], by_species[sp], [], TREE_NEAR, true)
	_add_multimesh(group, _far_cone, far_cone, far_cone_cols, 700.0, false, TREE_NEAR - 15.0)
	_add_multimesh(group, _far_round, far_round, far_round_cols, 700.0, false, TREE_NEAR - 15.0)
	# kamienie: kilka rodzajów, w górach więcej
	var rock_kinds := ["Rock_A", "Rock_B", "Rock_Flat", "Rock_Mossy"]
	var rocks: Dictionary = {}
	for i in rocks_per_chunk:
		var x := o.x + rng.randf() * Terrain.CHUNK
		var z := o.z + rng.randf() * Terrain.CHUNK
		if _blocked(x, z):
			continue
		var h := Terrain.height(x, z)
		var kind: String = rock_kinds[rng.randi() % 4]
		if Terrain.forest(x, z) > 0.4:
			kind = "Rock_Mossy"
		var s := rng.randf_range(0.5, 2.6) * (1.6 if h > 40.0 else 1.0)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.8, 1.3), s, s * rng.randf_range(0.8, 1.3)))
		if not rocks.has(kind):
			rocks[kind] = [] as Array[Transform3D]
		rocks[kind].append(Transform3D(basis, Vector3(x, h - 0.1 * s, z)))
	for kind: String in rocks:
		_add_multimesh(group, _nature[kind], rocks[kind], [], 700.0, true)
	return group


func _scatter_small(c: Vector2i) -> Node3D:
	var group := Node3D.new()
	add_child(group)
	var o := terrain.chunk_origin(c)
	var rng := _rng_for(c, 2)
	for kind in 4:
		var n: int = [grass_per_chunk, flowers_per_chunk, bushes_per_chunk, bushes_per_chunk / 3][kind]
		var mesh: Mesh = [_grass_mesh, _flower_mesh, _nature["Bush_Round"], _nature["Bush_Berry"]][kind]
		var xs: Array[Transform3D] = []
		var cols: Array[Color] = []
		for i in n:
			var x := o.x + rng.randf() * Terrain.CHUNK
			var z := o.z + rng.randf() * Terrain.CHUNK
			var h := Terrain.height(x, z)
			if h > 45.0 or _blocked(x, z):
				continue
			var patch := Terrain.flower_patch(x, z)
			if kind == 1 and patch < 0 and rng.randf() < 0.6:
				continue  # poza łąkami kwiatów kwiatki rzadziej
			var s: float = [rng.randf_range(0.25, 0.45), rng.randf_range(0.28, 0.45), rng.randf_range(0.6, 1.3),
				rng.randf_range(0.6, 1.1)][kind]
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h, z)))
			if kind == 1:
				cols.append(Terrain.FLOWER_COLORS[patch] if patch >= 0 else
					Terrain.FLOWER_COLORS[rng.randi() % Terrain.FLOWER_COLORS.size()])
		# na łąkach kwiatów — dodatkowe gęste kępy kwiatów
		if kind == 1:
			for i in n * 2:
				var x := o.x + rng.randf() * Terrain.CHUNK
				var z := o.z + rng.randf() * Terrain.CHUNK
				var patch := Terrain.flower_patch(x, z)
				if patch < 0 or _blocked(x, z):
					continue
				var s := rng.randf_range(0.3, 0.5)
				xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, Terrain.height(x, z), z)))
				cols.append(Terrain.FLOWER_COLORS[patch])
		_add_multimesh(group, mesh, xs, cols, 160.0 if kind < 2 else 300.0, kind >= 2)
	return group


func _add_multimesh(parent: Node3D, mesh: Mesh, xs: Array[Transform3D], cols: Array, vis_range: float,
		shadows: bool, vis_begin: float = 0.0) -> void:
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
	inst.visibility_range_begin = vis_begin
	inst.visibility_range_end = vis_range
	inst.visibility_range_end_margin = vis_range * 0.1
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


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


## Tania sylwetka drzewa z daleka (kolor z instancji): stożek lub kula na pniu.
func _make_far_tree(cone: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 0.0, 2.5, 0.3, 0.2, 4, Color(0.55, 0.42, 0.35))
	if cone:
		_cone(st, 1.5, 9.5, 2.6, 0.0, 6, Color.WHITE)
	else:
		_cone(st, 2.5, 5.0, 2.6, 2.8, 6, Color.WHITE)
		_cone(st, 5.0, 8.0, 2.8, 0.4, 6, Color.WHITE)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _vc_material())
	return m


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
