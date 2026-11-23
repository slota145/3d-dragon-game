class_name Terrain
extends Node3D
## Proceduralny teren świata (stałe ziarno): wzgórza i doliny, pasmo gór na północy (−Z)
## z legowiskiem u podnóża, jezioro i rzeka na wschodzie, las na zachodzie, spokojna łąka
## w środku (płaska wokół (0, 0, 0) — start piaskownicy i testów).
##
## Świat dzieli się na kawałki (chunki) CHUNK × CHUNK m. Każdy ma siatkę z LOD zależnym od
## odległości od gracza (4 / 8 / 16 m na kratkę), „spódnicę” zasłaniającą szczeliny między
## LOD-ami i — tylko w pobliżu gracza — kolizję HeightMapShape3D. Low-poly: każda ścianka ma
## własną normalną i kolor (płaskie cieniowanie), kolor zależy od wysokości, nachylenia i biomu.
## Roślinność (las, skały, trawa) dokłada TerrainDecor.

const SIZE := 2048.0
const HALF := SIZE / 2.0
const CHUNK := 128.0
const CHUNKS := int(SIZE / CHUNK)
## Poziom wody (jezioro, rzeka).
const WATER_LEVEL := -1.2
const LAKE_CENTER := Vector2(430.0, 270.0)
const LAKE_RADIUS := 170.0
const RIVER := [Vector2(250, -620), Vector2(290, -380), Vector2(310, -170), Vector2(345, -10),
	Vector2(395, 140), Vector2(430, 270)]
## Gęstość siatki dla LOD 0/1/2 (kratki na bok chunka).
const LOD_RES := [32, 16, 8]

signal chunk_built(coord: Vector2i, lod: int)

## Węzeł, wokół którego liczymy LOD i kolizję (smok).
var focus: Node3D

static var _hills: FastNoiseLite
static var _ridge: FastNoiseLite
static var _detail: FastNoiseLite
static var _forest: FastNoiseLite

var _chunks: Dictionary = {}  # Vector2i -> {"mesh": MeshInstance3D, "lod": int, "body": StaticBody3D}
var _material: StandardMaterial3D
var _focus_chunk := Vector2i(999, 999)
var _queue: Array[Vector2i] = []


# --- Funkcja wysokości (statyczna — używają jej też zwierzęta, złoto, roślinność) ------------

static func _init_noise() -> void:
	if _hills:
		return
	_hills = FastNoiseLite.new()
	_hills.seed = 1337
	_hills.frequency = 1.0 / 380.0
	_hills.fractal_octaves = 3
	_ridge = FastNoiseLite.new()
	_ridge.seed = 7331
	_ridge.frequency = 1.0 / 260.0
	_ridge.fractal_octaves = 4
	_detail = FastNoiseLite.new()
	_detail.seed = 4242
	_detail.frequency = 1.0 / 45.0
	_forest = FastNoiseLite.new()
	_forest.seed = 99
	_forest.frequency = 1.0 / 230.0


static func _smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x) if a < b else 1.0 - smoothstep(b, a, x)


## Wysokość terenu (m) w punkcie (x, z).
static func height(x: float, z: float) -> float:
	_init_noise()
	var r := Vector2(x, z).length()
	# wzgórza: łagodne w środku (łąka), wyraźne dalej; zupełnie płasko wokół startu
	# +7 m: doliny rzadko schodzą pod wodę (woda tylko w jeziorze, rzece i kilku stawach)
	var hills := _hills.get_noise_2d(x, z) * 22.0 + 7.0 + _detail.get_noise_2d(x, z) * 1.5
	var h := hills * lerpf(0.1, 1.0, smoothstep(140.0, 420.0, r)) * smoothstep(55.0, 150.0, r)
	# góry na północy: grzbiety z szumu „ridged”
	var ridge := 1.0 - absf(_ridge.get_noise_2d(x, z))
	ridge *= ridge
	var north := smoothstep(-150.0, -460.0, z)
	h += north * (55.0 + 190.0 * ridge) + north * north * 50.0
	# brzeg świata: wzgórza i turnie zamykające mapę
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(800.0, 1000.0, edge) * (90.0 + 80.0 * ridge)
	# jezioro (postrzępiony brzeg)
	var ld := Vector2(x, z).distance_to(LAKE_CENTER) + _detail.get_noise_2d(x * 0.5, z * 0.5) * 30.0
	var lake := 1.0 - smoothstep(LAKE_RADIUS * 0.55, LAKE_RADIUS, ld)
	h = lerpf(h, -6.0, lake)
	# rzeka: koryto wzdłuż łamanej (w górach głęboki wąwóz)
	var rd := river_distance(x, z)
	var width := 9.0 + 25.0 * north
	var river := 1.0 - smoothstep(width * 0.5, width * 1.6, rd)
	h = lerpf(h, minf(h, -3.0), river)
	# plac pod legowiskiem
	var pd := Vector2(x - Lair.POSITION.x, z - Lair.POSITION.z).length()
	h = lerpf(h, Lair.POSITION.y, 1.0 - smoothstep(Lair.RADIUS - 2.0, Lair.RADIUS + 28.0, pd))
	return h


static func river_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in RIVER.size() - 1:
		var a: Vector2 = RIVER[i]
		var b: Vector2 = RIVER[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## 0..1 — gęstość lasu (las głównie na zachodzie, kępy gdzie indziej).
static func forest(x: float, z: float) -> float:
	_init_noise()
	var f := _forest.get_noise_2d(x, z) * 0.8 + 0.6 * smoothstep(-80.0, -380.0, x) - 0.08
	f *= smoothstep(130.0, 220.0, Vector2(x, z).length())  # łąka w środku bez lasu
	return clampf(f * 2.0, 0.0, 1.0)


static func is_water(x: float, z: float) -> bool:
	return height(x, z) < WATER_LEVEL + 0.3


## Czy tu mogą chodzić zwierzęta / leżeć złoto (sucho i niezbyt stromo / wysoko).
static func is_walkable(x: float, z: float) -> bool:
	var h := height(x, z)
	if h < WATER_LEVEL + 0.4 or h > 30.0:
		return false
	return absf(height(x + 3.0, z) - h) < 2.2 and absf(height(x, z + 3.0) - h) < 2.2


# --- Kawałki terenu ------------------------------------------------------------------

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	_add_water()
	_add_bounds()


## Zbuduj od razu wszystkie kawałki (start gry) — w pobliżu `at` najdokładniej, z kolizją.
func build_all(at: Vector3) -> void:
	_focus_chunk = chunk_of(at)
	for cx in CHUNKS:
		for cz in CHUNKS:
			var c := Vector2i(cx, cz)
			_build_chunk(c, _lod_for(c))


func chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x + HALF) / CHUNK)), 0, CHUNKS - 1),
		clampi(int(floor((p.z + HALF) / CHUNK)), 0, CHUNKS - 1))


func chunk_origin(c: Vector2i) -> Vector3:
	return Vector3(c.x * CHUNK - HALF, 0.0, c.y * CHUNK - HALF)


func _lod_for(c: Vector2i) -> int:
	var d := maxi(absi(c.x - _focus_chunk.x), absi(c.y - _focus_chunk.y))
	return 0 if d <= 1 else (1 if d <= 3 else 2)


func lod_of(c: Vector2i) -> int:
	return _chunks[c]["lod"] if _chunks.has(c) else -1


func has_collision(c: Vector2i) -> bool:
	return _chunks.has(c) and _chunks[c]["body"] != null


func _process(_delta: float) -> void:
	if not focus:
		return
	var c := chunk_of(focus.global_position)
	if c != _focus_chunk:
		_focus_chunk = c
		_queue.clear()
		# najpierw najbliższe (kolizja pod smokiem jest najważniejsza)
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				var n := c + Vector2i(dx, dz)
				if n.x < 0 or n.y < 0 or n.x >= CHUNKS or n.y >= CHUNKS:
					continue
				if lod_of(n) != _lod_for(n) or has_collision(n) != (_lod_for(n) == 0):
					_queue.append(n)
		_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - c).length_squared() < (b - c).length_squared())
	# kilka kawałków na klatkę — bez przycięć
	for i in 3:
		if _queue.is_empty():
			break
		var n: Vector2i = _queue.pop_front()
		_build_chunk(n, _lod_for(n))


func _build_chunk(c: Vector2i, lod: int) -> void:
	var entry: Dictionary = _chunks.get(c, {"mesh": null, "lod": -1, "body": null})
	if entry["lod"] != lod:
		if entry["mesh"]:
			(entry["mesh"] as Node).queue_free()
		var mi := MeshInstance3D.new()
		mi.mesh = _chunk_mesh(c, LOD_RES[lod])
		mi.position = chunk_origin(c)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		entry["mesh"] = mi
		entry["lod"] = lod
	var want_body := lod == 0
	if want_body and entry["body"] == null:
		entry["body"] = _chunk_body(c)
	elif not want_body and entry["body"] != null:
		(entry["body"] as Node).queue_free()
		entry["body"] = null
	_chunks[c] = entry
	chunk_built.emit(c, lod)


func _chunk_mesh(c: Vector2i, res: int) -> ArrayMesh:
	var o := chunk_origin(c)
	var step := CHUNK / res
	var hs := PackedFloat32Array()
	hs.resize((res + 1) * (res + 1))
	for j in res + 1:
		for i in res + 1:
			hs[j * (res + 1) + i] = height(o.x + i * step, o.z + j * step)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for j in res:
		for i in res:
			var p00 := Vector3(i * step, hs[j * (res + 1) + i], j * step)
			var p10 := Vector3((i + 1) * step, hs[j * (res + 1) + i + 1], j * step)
			var p01 := Vector3(i * step, hs[(j + 1) * (res + 1) + i], (j + 1) * step)
			var p11 := Vector3((i + 1) * step, hs[(j + 1) * (res + 1) + i + 1], (j + 1) * step)
			# przekątna na przemian — mniej „pasków” w low-poly
			if (i + j) % 2 == 0:
				_tri(verts, norms, cols, o, p00, p10, p11)
				_tri(verts, norms, cols, o, p00, p11, p01)
			else:
				_tri(verts, norms, cols, o, p00, p10, p01)
				_tri(verts, norms, cols, o, p10, p11, p01)
	# spódnica: pionowy pas w dół wzdłuż brzegów (zasłania szczeliny między LOD-ami)
	for k in res:
		for e in 4:
			var a: Vector3
			var b: Vector3
			match e:
				0: a = Vector3(k * step, hs[k], 0); b = Vector3((k + 1) * step, hs[k + 1], 0)
				1: a = Vector3((k + 1) * step, hs[res * (res + 1) + k + 1], CHUNK); b = Vector3(k * step, hs[res * (res + 1) + k], CHUNK)
				2: a = Vector3(0, hs[(k + 1) * (res + 1)], (k + 1) * step); b = Vector3(0, hs[k * (res + 1)], k * step)
				_: a = Vector3(CHUNK, hs[k * (res + 1) + res], k * step); b = Vector3(CHUNK, hs[(k + 1) * (res + 1) + res], (k + 1) * step)
			var a2 := a + Vector3.DOWN * 8.0
			var b2 := b + Vector3.DOWN * 8.0
			_tri(verts, norms, cols, o, a, a2, b, true)
			_tri(verts, norms, cols, o, b, a2, b2, true)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	return mesh


func _tri(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, o: Vector3,
		a: Vector3, b: Vector3, c: Vector3, skirt: bool = false) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0 and not skirt:
		n = -n
	var center := (a + b + c) / 3.0
	var col := _face_color(o.x + center.x, o.z + center.z, center.y, n.y)
	# kolejność zgodna z ruchem wskazówek zegara patrząc od strony normalnej (przód w Godocie)
	if (b - a).cross(c - a).dot(n) > 0.0:
		verts.append(a)
		verts.append(c)
		verts.append(b)
	else:
		verts.append(a)
		verts.append(b)
		verts.append(c)
	for k in 3:
		norms.append(n)
		cols.append(col)


## Kolor ścianki: piasek przy wodzie, łąka, las, skała na stromiznach, śnieg na szczytach.
static func _face_color(x: float, z: float, h: float, ny: float) -> Color:
	_init_noise()
	var jitter := 1.0 + 0.06 * sin(x * 12.9898 + z * 78.233) * 1.0
	var col: Color
	if h < WATER_LEVEL + 0.8:
		col = Color(0.62, 0.56, 0.4) if h > WATER_LEVEL - 1.0 else Color(0.42, 0.4, 0.32)
	elif ny < 0.72:
		col = Color(0.45, 0.43, 0.4)  # skała
	elif h > 150.0 and ny > 0.8:
		col = Color(0.92, 0.93, 0.96)  # śnieg
	elif h > 60.0:
		col = Color(0.42, 0.45, 0.32).lerp(Color(0.5, 0.48, 0.44), clampf((h - 60.0) / 80.0, 0.0, 1.0))
	else:
		var f := forest(x, z)
		var meadow := Color(0.38, 0.55, 0.27).lerp(Color(0.45, 0.58, 0.28), 0.5 + 0.5 * _detail.get_noise_2d(x * 0.3, z * 0.3))
		col = meadow.lerp(Color(0.24, 0.38, 0.2), f)
	return Color(col.r * jitter, col.g * jitter, col.b * jitter)


func _chunk_body(c: Vector2i) -> StaticBody3D:
	var res: int = LOD_RES[0]
	var step := CHUNK / res
	var o := chunk_origin(c)
	var shape := HeightMapShape3D.new()
	shape.map_width = res + 1
	shape.map_depth = res + 1
	var data := PackedFloat32Array()
	data.resize((res + 1) * (res + 1))
	for j in res + 1:
		for i in res + 1:
			data[j * (res + 1) + i] = height(o.x + i * step, o.z + j * step)
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "TerrainBody_%d_%d" % [c.x, c.y]
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3(step, 1.0, step)
	body.add_child(col)
	body.position = o + Vector3(CHUNK / 2.0, 0.0, CHUNK / 2.0)
	add_child(body)
	return body


func _add_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE + 400.0, SIZE + 400.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.45, 0.62, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.25
	plane.material = mat
	water.mesh = plane
	water.position.y = WATER_LEVEL
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


## Niewidzialne ściany na krawędzi świata.
func _add_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldBounds"
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var cs := CollisionShape3D.new()
		var ws := WorldBoundaryShape3D.new()
		ws.plane = Plane(n, -(HALF - 40.0))
		cs.shape = ws
		body.add_child(cs)
	add_child(body)
