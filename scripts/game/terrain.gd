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

const SIZE := 4096.0
const HALF := SIZE / 2.0
const CHUNK := 128.0
const CHUNKS := int(SIZE / CHUNK)
## Poziom wody (jezioro, rzeka).
const WATER_LEVEL := -1.2
const LAKE_CENTER := Vector2(430.0, 270.0)
const LAKE_RADIUS := 170.0
## Jeziora: [środek x, środek z, promień]. Pierwsze to jezioro przy łące (LAKE_CENTER).
const LAKES := [[430.0, 270.0, 170.0], [-760.0, 1180.0, 250.0], [1350.0, -260.0, 210.0], [140.0, -1620.0, 160.0],
	[1725.0, 470.0, 55.0], [252.0, -595.0, 60.0]]
## Wioski: [środek x, środek z, promień placu]. Plac jest wyrównany, wokół pola uprawne.
const VILLAGES := [[160.0, 640.0, 70.0], [-640.0, 480.0, 65.0], [1150.0, 860.0, 70.0], [880.0, 120.0, 60.0],
	[-260.0, 1450.0, 70.0], [-1300.0, -120.0, 60.0]]
## Zamek: [środek x, środek z, promień murów]. Stoi na usypanym wzgórzu (płaski szczyt).
const CASTLE := [400.0, 1400.0, 46.0]
## O ile wzgórze zamkowe wznosi się nad okolicę (m).
const CASTLE_RISE := 16.0
## Drogi (pary indeksów VILLAGES; indeks VILLAGES.size() = brama zamku) — ubita ziemia, jeżdżą nimi wozy.
const ROAD_PAIRS := [[0, 1], [0, 3], [3, 2], [0, 4], [1, 5], [0, 6]]
const ROAD_HALF_WIDTH := 3.2
## Szerokość pierścienia pól wokół wioski (m).
const FIELDS := 80.0
## Rzeki: łamane od gór do jezior.
const RIVERS := [
	[Vector2(250, -620), Vector2(290, -380), Vector2(310, -170), Vector2(345, -10), Vector2(395, 140), Vector2(430, 270)],
	[Vector2(900, -1150), Vector2(1030, -860), Vector2(1180, -560), Vector2(1350, -260)],
	[Vector2(-300, 420), Vector2(-390, 520), Vector2(-450, 640), Vector2(-410, 745), Vector2(-500, 830),
		Vector2(-605, 875), Vector2(-585, 985), Vector2(-655, 1080), Vector2(-760, 1180)],
]
const RIVER := [Vector2(250, -620), Vector2(290, -380), Vector2(310, -170), Vector2(345, -10),
	Vector2(395, 140), Vector2(430, 270)]
## Płaskowyże: [środek x, środek z, promień, wysokość szczytu (m n.p.m.), liczba pięter].
## Jedno piętro = urwisty stołowy szczyt; więcej = schodki (każde piętro węższe).
const MESAS := [[-1010.0, 170.0, 175.0, 66.0, 3], [1520.0, 470.0, 150.0, 84.0, 1], [-130.0, 1060.0, 125.0, 58.0, 1],
	[760.0, 820.0, 70.0, 46.0, 2],
	# ostańce na południowym wschodzie (kraina stołowych gór)
	[1260.0, 1300.0, 60.0, 72.0, 1], [1520.0, 1080.0, 48.0, 90.0, 1], [1050.0, 1560.0, 55.0, 60.0, 2],
	[1640.0, 1520.0, 80.0, 64.0, 2], [1380.0, 1700.0, 40.0, 82.0, 1]]
## Wyżyna zachodnia (elipsa: środek, półosie) — przecina ją kanion rzeki (RIVERS[2]), nad jeziorem klify.
const HIGHLAND := [-520.0, 870.0, 230.0, 310.0]
## Wysokość wyżyny i półki w kanionie (m).
const HIGHLAND_TOP := 48.0
const CANYON_LEDGE := 20.0
## Gęstość siatki dla LOD 0/1/2/3 (kratki na bok chunka).
const LOD_RES := [32, 16, 8, 4]
## Teren dalej niż tyle metrów od kamery nie jest rysowany (mgła i tak go zasłania).
const VIEW_DISTANCE := 1500.0

signal chunk_built(coord: Vector2i, lod: int)

## Węzeł, wokół którego liczymy LOD i kolizję (smok).
var focus: Node3D

static var _hills: FastNoiseLite
static var _ridge: FastNoiseLite
static var _detail: FastNoiseLite
static var _forest: FastNoiseLite
static var _terrace_n: FastNoiseLite
static var _village_h: Dictionary = {}

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
	_terrace_n = FastNoiseLite.new()
	_terrace_n.seed = 2718
	_terrace_n.frequency = 1.0 / 520.0


static func _smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x) if a < b else 1.0 - smoothstep(b, a, x)


## Wysokość terenu (m) w punkcie (x, z) — z wyrównanymi placami wiosek.
static func height(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	var cd := Vector2(x - CASTLE[0], z - CASTLE[1]).length()
	if cd < CASTLE[2] + 130.0:  # wzgórze zamkowe: płaski szczyt, łagodne zbocza
		h = lerpf(h, castle_height(), 1.0 - smoothstep(CASTLE[2] + 14.0, CASTLE[2] + 130.0, cd))
	for i in VILLAGES.size():
		var v: Array = VILLAGES[i]
		var d := Vector2(x - v[0], z - v[1]).length()
		var r: float = v[2]
		if d < r + FIELDS:
			if not _village_h.has(i):
				_village_h[i] = maxf(_raw_height(v[0], v[1]), 1.0)
			# plac zupełnie płasko, pola łagodnie przechodzą w okoliczne wzgórza
			h = lerpf(h, _village_h[i], 1.0 - smoothstep(r, r + FIELDS, d))
	return h


static var _castle_h: float = NAN


## Wysokość dziedzińca zamku.
static func castle_height() -> float:
	if is_nan(_castle_h):
		_castle_h = _raw_height(CASTLE[0], CASTLE[1]) + CASTLE_RISE
	return _castle_h


## Środek zamku (na wysokości dziedzińca).
static func castle_center() -> Vector3:
	return Vector3(CASTLE[0], castle_height(), CASTLE[1])


## Kierunek (XZ) od środka zamku do bramy — w stronę pierwszej wioski.
static func castle_gate_dir() -> Vector2:
	var v: Array = VILLAGES[0]
	return Vector2(v[0] - CASTLE[0], v[1] - CASTLE[1]).normalized()


## Koniec drogi nr `i` w ROAD_PAIRS: środek wioski albo plac przed bramą zamku.
static func road_end(i: int) -> Vector2:
	if i < VILLAGES.size():
		return Vector2(VILLAGES[i][0], VILLAGES[i][1])
	return Vector2(CASTLE[0], CASTLE[1]) + castle_gate_dir() * (CASTLE[2] + 22.0)


## Punkty drogi nr `i` (co 4 m, od wioski do wioski) — z assets/data/roads.json, liczonego
## narzędziem tools/gen_roads.gd (A* po terenie: omija góry i jeziora, rzekę przecina mostem).
static func road_points(i: int) -> PackedVector2Array:
	_load_roads()
	return _road_cache[i]


static func _load_roads() -> void:
	if not _road_cache.is_empty():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/roads.json"))
	for road: Array in (data as Dictionary).get("roads", []):
		var pts := PackedVector2Array()
		for p: Array in road:
			pts.append(Vector2(p[0], p[1]))
		_road_cache.append(pts)
		var r := Rect2(pts[0], Vector2.ZERO)
		for q in pts:
			r = r.expand(q)
		_road_rects.append(r)
	_build_road_grid()


static var _road_rects: Array[Rect2] = []


static var _road_cache: Array = []


## Odległość (m) do najbliższej drogi.
## Siatka przestrzenna odcinków dróg (komórki ROAD_CELL m) — szybkie zapytania o odległość.
const ROAD_CELL := 32.0
## Odległość do drogi liczona dokładnie tylko do tylu metrów; dalej zwraca ROAD_FAR.
const ROAD_FAR := 40.0
static var _road_grid: Dictionary = {}  # Vector2i -> PackedVector4Array (ax, az, bx, bz)


static func _build_road_grid() -> void:
	for pts: PackedVector2Array in _road_cache:
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var seg := Vector4(a.x, a.y, b.x, b.y)
			var lo := Vector2i(floori((minf(a.x, b.x) - ROAD_FAR) / ROAD_CELL), floori((minf(a.y, b.y) - ROAD_FAR) / ROAD_CELL))
			var hi := Vector2i(floori((maxf(a.x, b.x) + ROAD_FAR) / ROAD_CELL), floori((maxf(a.y, b.y) + ROAD_FAR) / ROAD_CELL))
			for cx in range(lo.x, hi.x + 1):
				for cz in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cz)
					if not _road_grid.has(key):
						_road_grid[key] = PackedVector4Array()
					var arr: PackedVector4Array = _road_grid[key]
					arr.append(seg)
					_road_grid[key] = arr


## Odległość (m) do najbliższej drogi (dokładna do ROAD_FAR, dalej = ROAD_FAR).
static func road_distance(x: float, z: float) -> float:
	_load_roads()
	var cell: Variant = _road_grid.get(Vector2i(floori(x / ROAD_CELL), floori(z / ROAD_CELL)))
	if cell == null:
		return ROAD_FAR
	var p := Vector2(x, z)
	var best := ROAD_FAR
	for seg: Vector4 in cell:
		var a := Vector2(seg.x, seg.y)
		var ab := Vector2(seg.z, seg.w) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## 0..1 — gdzie leżą pola wioski (pierścień wokół placu); -1 gdy daleko od wiosek.
static func farmland(x: float, z: float) -> float:
	for v: Array in VILLAGES:
		var d := Vector2(x - v[0], z - v[1]).length()
		var r: float = v[2]
		if d < r + FIELDS:
			if road_distance(x, z) < ROAD_HALF_WIDTH + 5.0:
				return -1.0  # pas drogi — pola obok, nie na drodze
			return clampf((d - r * 0.85) / FIELDS, 0.0, 1.0) if d > r * 0.85 else 0.0
	return -1.0


static func _raw_height(x: float, z: float) -> float:
	_init_noise()
	var r := Vector2(x, z).length()
	# wzgórza: łagodne w środku (łąka), wyraźne dalej; zupełnie płasko wokół startu
	# +7 m: doliny rzadko schodzą pod wodę (woda tylko w jeziorze, rzece i kilku stawach)
	var hills := _hills.get_noise_2d(x, z) * 22.0 + 7.0 + _detail.get_noise_2d(x, z) * 1.5
	var h := hills * lerpf(0.1, 1.0, smoothstep(140.0, 420.0, r)) * smoothstep(55.0, 150.0, r)
	# góry na północy: grzbiety z szumu „ridged”
	var ridge := 1.0 - absf(_ridge.get_noise_2d(x, z))
	ridge *= ridge
	# pasmo gór na północy (za nim wyżyna z jeziorem)
	var north := smoothstep(-150.0, -460.0, z) * (1.0 - smoothstep(-1150.0, -1450.0, z))
	h += north * (55.0 + 190.0 * ridge) + north * north * 50.0
	h += smoothstep(-1150.0, -1450.0, z) * 30.0
	# brzeg świata: wzgórza i turnie zamykające mapę
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(HALF - 230.0, HALF - 30.0, edge) * (90.0 + 80.0 * ridge)
	# pogórza: strefy grzbietów (do ~75 m) z dala od łąki — potem tarasowane
	var hill_zone := smoothstep(0.0, 0.35, _terrace_n.get_noise_2d(x * 0.7 + 400.0, z * 0.7 - 250.0)) \
		* smoothstep(520.0, 850.0, r) * (1.0 - north)
	if hill_zone > 0.0:
		var hn := clampf(_hills.get_noise_2d(x * 2.2 + 77.0, z * 2.2) * 0.8 + 0.5, 0.0, 1.0)
		h += hill_zone * (pow(hn, 1.6) * 60.0 + 4.0)
	# tarasy: część wzgórz (poza łąką i szczytami) schodzi stopniami z urwistymi progami
	var tmask := smoothstep(-0.05, 0.25, _terrace_n.get_noise_2d(x, z)) * smoothstep(360.0, 620.0, r) \
		* (1.0 - smoothstep(80.0, 130.0, h))
	tmask = maxf(tmask, hill_zone * (1.0 - smoothstep(80.0, 130.0, h)))  # pogórza zawsze tarasowane
	if tmask > 0.0:
		h = lerpf(h, terrace(h, 12.0), tmask)
	for m: Array in MESAS:
		h = _mesa(h, x, z, m)
	h = _highland(h, x, z)
	# jeziora (postrzępiony brzeg)
	var shore := _detail.get_noise_2d(x * 0.5, z * 0.5) * 30.0
	# przy wyżynie brzeg jeziora jest urwisty (klify nad wodą), gdzie indziej łagodny
	var steep := 1.0 - smoothstep(1.0, 1.3, Vector2((x - HIGHLAND[0]) / HIGHLAND[2], (z - HIGHLAND[1]) / HIGHLAND[3]).length())
	for lk: Array in LAKES:
		var ld := Vector2(x, z).distance_to(Vector2(lk[0], lk[1])) + shore
		var lr: float = lk[2]
		h = lerpf(h, -6.0, 1.0 - smoothstep(lr * lerpf(0.55, 0.88, steep), lr, ld))
	# rzeka: koryto wzdłuż łamanej (w górach głęboki wąwóz)
	var rd := river_distance(x, z)
	var width := 9.0 + 25.0 * smoothstep(-150.0, -460.0, z)
	var river := 1.0 - smoothstep(width * 0.5, width * 1.6, rd)
	h = lerpf(h, minf(h, -3.0), river)
	# plac pod legowiskiem
	var pd := Vector2(x - Lair.POSITION.x, z - Lair.POSITION.z).length()
	h = lerpf(h, Lair.POSITION.y, 1.0 - smoothstep(Lair.RADIUS - 2.0, Lair.RADIUS + 28.0, pd))
	return h


## Schodki: wysokość zaokrąglona do pięter `step` z krótkim, stromym progiem między nimi.
static func terrace(h: float, step: float) -> float:
	var k := h / step
	var f := k - floorf(k)
	return (floorf(k) + smoothstep(0.7, 0.92, f)) * step


## Płaskowyż: urwiste ściany (postrzępiony obrys), piarg u podnóża, płaski szczyt.
static func _mesa(h: float, x: float, z: float, m: Array) -> float:
	var R: float = m[2]
	var d := Vector2(x - m[0], z - m[1]).length()
	if d > R * 1.25 + 80.0:
		return h
	d += _detail.get_noise_2d(x * 0.5, z * 0.5) * R * 0.22
	var top: float = m[3]
	var tiers: int = m[4]
	var out := maxf(h, lerpf(h, top * 0.3, 1.0 - smoothstep(R * 0.9, R + 60.0, d)))  # piarg
	for t in tiers:
		var rt := R * (1.0 - 0.3 * t)
		var ht := top * float(t + 1) / tiers + _detail.get_noise_2d(x * 2.0, z * 2.0) * 1.0
		out = maxf(out, lerpf(out, ht, 1.0 - smoothstep(rt - 9.0, rt + 3.0, d)))
	return out


## 0..1 — jak bardzo punkt leży na wyżynie zachodniej (obrys postrzępiony).
static func highland_mask(x: float, z: float) -> float:
	var e := Vector2((x - HIGHLAND[0]) / HIGHLAND[2], (z - HIGHLAND[1]) / HIGHLAND[3]).length()
	if e > 1.4:
		return 0.0
	e += _detail.get_noise_2d(x * 0.4, z * 0.4) * 0.12
	return 1.0 - smoothstep(0.96, 1.02, e)


## Wyżyna: dwa piętra klifów na obrzeżu, szczyt na HIGHLAND_TOP; kanion rzeki z półką skalną.
static func _highland(h: float, x: float, z: float) -> float:
	var e := Vector2((x - HIGHLAND[0]) / HIGHLAND[2], (z - HIGHLAND[1]) / HIGHLAND[3]).length()
	if e > 1.4:
		return h
	e += _detail.get_noise_2d(x * 0.4, z * 0.4) * 0.12
	var low := 1.0 - smoothstep(1.06, 1.1, e)  # dolny stopień
	var high := 1.0 - smoothstep(0.96, 1.0, e)
	var top := HIGHLAND_TOP + _detail.get_noise_2d(x, z) * 2.0
	var out := maxf(h, lerpf(h, CANYON_LEDGE + 2.0, low))
	out = maxf(out, lerpf(out, top, high))
	if high <= 0.0:
		return out
	# kanion: dno z rzeką, po bokach półka, wyżej ściany do szczytu wyżyny
	var rd := river_distance(x, z) + _detail.get_noise_2d(x * 1.3, z * 1.3) * 5.0
	var ledge := 1.0 - smoothstep(44.0, 50.0, rd)
	var floor_k := 1.0 - smoothstep(22.0, 28.0, rd)
	var carved := lerpf(out, CANYON_LEDGE + _detail.get_noise_2d(x * 2.0, z * 2.0) * 1.0, ledge)
	carved = lerpf(carved, 0.6, floor_k)
	return lerpf(out, minf(out, carved), high)


static func river_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for river: Array in RIVERS:
		for i in river.size() - 1:
			var a: Vector2 = river[i]
			var b: Vector2 = river[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


## 0..1 — gęstość lasu (las głównie na zachodzie, kępy gdzie indziej).
static func forest(x: float, z: float) -> float:
	_init_noise()
	var f := _forest.get_noise_2d(x, z) * 0.8 + 0.6 * smoothstep(-80.0, -380.0, x) - 0.08
	f *= smoothstep(130.0, 220.0, Vector2(x, z).length())  # łąka w środku bez lasu
	f *= smoothstep(ROAD_HALF_WIDTH + 2.0, ROAD_HALF_WIDTH + 10.0, road_distance(x, z))  # drogi bez drzew
	for v: Array in VILLAGES:  # wioski i pola bez lasu
		f *= smoothstep(v[2] + FIELDS * 0.8, v[2] + FIELDS + 60.0, Vector2(x - v[0], z - v[1]).length())
	f *= smoothstep(CASTLE[2] + 40.0, CASTLE[2] + 150.0, Vector2(x - CASTLE[0], z - CASTLE[1]).length())  # zamek na polanie
	return clampf(f * 2.0, 0.0, 1.0)


static func is_water(x: float, z: float) -> bool:
	return height(x, z) < WATER_LEVEL + 0.3


## Czy tu mogą chodzić zwierzęta / leżeć złoto (sucho i niezbyt stromo / wysoko).
static func is_walkable(x: float, z: float) -> bool:
	var h := height(x, z)
	if h < WATER_LEVEL + 0.4 or (h > 30.0 and farmland(x, z) < 0.0):
		return false
	return absf(height(x + 3.0, z) - h) < 2.2 and absf(height(x, z + 3.0) - h) < 2.2


# --- Kawałki terenu ------------------------------------------------------------------

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	# rozgrzej statyczne dane (szum, drogi, wioski) w głównym wątku — potem czytają je wątki w tle
	road_distance(0.0, 0.0)
	forest(0.0, 0.0)
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
	return 0 if d <= 1 else (1 if d <= 3 else (2 if d <= 6 else 3))


func lod_of(c: Vector2i) -> int:
	return _chunks[c]["lod"] if _chunks.has(c) else -1


func has_collision(c: Vector2i) -> bool:
	return _chunks.has(c) and _chunks[c]["body"] != null


func _process(_delta: float) -> void:
	_check_depth_task()
	if not focus:
		return
	var c := chunk_of(focus.global_position)
	if c != _focus_chunk:
		_focus_chunk = c
		_queue.clear()
		# najpierw najbliższe (kolizja pod smokiem jest najważniejsza)
		for dx in range(-8, 9):
			for dz in range(-8, 9):
				var n := c + Vector2i(dx, dz)
				if n.x < 0 or n.y < 0 or n.x >= CHUNKS or n.y >= CHUNKS:
					continue
				if lod_of(n) != _lod_for(n) or has_collision(n) != (_lod_for(n) == 0):
					_queue.append(n)
		_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - c).length_squared() < (b - c).length_squared())
	# kawałki liczone w wątkach w tle; w głównym wątku tylko wstawienie gotowych danych
	while not _queue.is_empty() and _pending.size() < MAX_TASKS:
		var n: Vector2i = _queue.pop_front()
		if _pending.has(n):
			continue
		var lod := _lod_for(n)
		var need_mesh := lod_of(n) != lod
		var need_body := lod == 0 and not has_collision(n)
		_pending[n] = WorkerThreadPool.add_task(_chunk_task.bind(n, lod, need_mesh, need_body))
	for n: Vector2i in _pending.keys():
		if not WorkerThreadPool.is_task_completed(_pending[n]):
			continue
		WorkerThreadPool.wait_for_task_completion(_pending[n])
		_pending.erase(n)
		_mutex.lock()
		var r: Dictionary = _results.get(n, {})
		_results.erase(n)
		_mutex.unlock()
		if not r.is_empty():
			var arrays: Array = r["arrays"]
			var lod: int = r["lod"]
			if arrays.is_empty() and lod_of(n) != lod:
				arrays = _chunk_arrays(n, LOD_RES[lod])  # (nie powinno się zdarzyć)
			_build_chunk(n, lod, arrays, r["body"])


const MAX_TASKS := 4
var _pending: Dictionary = {}  # Vector2i -> id zadania WorkerThreadPool
var _results: Dictionary = {}
var _mutex := Mutex.new()


## Zadanie w tle: dane siatki (gdy zmienia się LOD) i wysokości do kolizji (gdy potrzebna).
func _chunk_task(c: Vector2i, lod: int, need_mesh: bool, need_body: bool) -> void:
	var r := {"lod": lod, "arrays": _chunk_arrays(c, LOD_RES[lod]) if need_mesh else [],
		"body": _body_heights(c) if need_body else PackedFloat32Array()}
	_mutex.lock()
	_results[c] = r
	_mutex.unlock()


func _build_chunk(c: Vector2i, lod: int, arrays: Array = [], body_data := PackedFloat32Array()) -> void:
	var entry: Dictionary = _chunks.get(c, {"mesh": null, "lod": -1, "body": null})
	if entry["lod"] != lod:
		if entry["mesh"]:
			(entry["mesh"] as Node).queue_free()
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh_from_arrays(arrays) if not arrays.is_empty() else _chunk_mesh(c, LOD_RES[lod])
		mi.position = chunk_origin(c)
		mi.visibility_range_end = VIEW_DISTANCE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		entry["mesh"] = mi
		entry["lod"] = lod
	var want_body := lod == 0
	if want_body and entry["body"] == null:
		entry["body"] = _chunk_body(c, body_data)
	elif not want_body and entry["body"] != null:
		(entry["body"] as Node).queue_free()
		entry["body"] = null
	_chunks[c] = entry
	chunk_built.emit(c, lod)


func _chunk_mesh(c: Vector2i, res: int) -> ArrayMesh:
	return _mesh_from_arrays(_chunk_arrays(c, res))


func _mesh_from_arrays(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	return mesh


## Dane siatki kawałka (bez zasobów silnika) — można liczyć w wątku w tle.
func _chunk_arrays(c: Vector2i, res: int) -> Array:
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
	return arrays


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
		col = Color(0.88, 0.78, 0.52) if h > WATER_LEVEL - 1.0 else Color(0.5, 0.56, 0.4)  # piasek / dno
	elif ny < 0.72:
		# skała: w górach chłodna szarość, na klifach płaskowyżów, tarasów i kanionu — piaskowiec
		var mountain := smoothstep(-250.0, -420.0, z) * (1.0 - smoothstep(-1300.0, -1450.0, z)) \
			+ smoothstep(110.0, 140.0, h)
		var band := 0.04 * sin(h * 0.9)  # warstwy skalne
		col = Color(0.72 + band, 0.55 + band, 0.4 + band).lerp(Color(0.52, 0.49, 0.48), clampf(mountain, 0.0, 1.0))
	elif h > 150.0 and ny > 0.8:
		col = Color(0.97, 0.98, 1.0)  # śnieg
	elif h > 90.0:
		col = Color(0.36, 0.54, 0.24).lerp(Color(0.55, 0.52, 0.5), clampf((h - 90.0) / 70.0, 0.0, 1.0))
	elif road_distance(x, z) < ROAD_HALF_WIDTH * 0.7:
		col = Color(0.55, 0.43, 0.28)  # podkład pod wstęgą drogi (Roads)
	elif farmland(x, z) > 0.05 and farmland(x, z) < 0.95:
		col = field_color(x, z)
	else:
		var f := forest(x, z)
		var meadow := Color(0.27, 0.49, 0.18).lerp(Color(0.38, 0.55, 0.2), 0.5 + 0.5 * _detail.get_noise_2d(x * 0.3, z * 0.3))
		col = meadow.lerp(Color(0.2, 0.44, 0.17), f)
		var patch := flower_patch(x, z)
		if patch >= 0:  # łąka kwiatów widoczna z daleka
			col = col.lerp(FLOWER_COLORS[patch], 0.35)
	return Color(col.r * jitter, col.g * jitter, col.b * jitter)


# --- Pola, łąki kwiatów, gatunki drzew ----------------------------------------------

## Kolory łąk kwiatów: maki, łubin, jaskry, rumianek, lawenda.
const FLOWER_COLORS := [Color(0.95, 0.25, 0.2), Color(0.55, 0.45, 0.95), Color(1.0, 0.85, 0.25),
	Color(0.98, 0.97, 0.92), Color(0.78, 0.55, 0.95)]
## Uprawy na działkach pól: pszenica, zaorana ziemia, młode zboże, lawenda, kapusta, rzepak.
const CROPS := [Color(0.92, 0.7, 0.25), Color(0.5, 0.33, 0.2), Color(0.45, 0.7, 0.22),
	Color(0.6, 0.45, 0.85), Color(0.3, 0.55, 0.38), Color(0.95, 0.82, 0.15)]
## Działki: tyle wycinków kąta × 2 pierścienie wokół wioski.
const FIELD_SECTORS := 10


## Numer działki pola (wioska, wycinek, pierścień) albo -1 poza polami.
static func field_parcel(x: float, z: float) -> Vector3i:
	for i in VILLAGES.size():
		var v: Array = VILLAGES[i]
		var d := Vector2(x - v[0], z - v[1])
		var r: float = v[2]
		if d.length() > r and d.length() < r + FIELDS:
			var sector := int(floor((d.angle() + PI) / TAU * FIELD_SECTORS)) % FIELD_SECTORS
			var ring := 0 if d.length() < r + FIELDS * 0.5 else 1
			return Vector3i(i, sector, ring)
	return Vector3i(-1, -1, -1)


## Pastwisko: jedna działka wewnętrznego pierścienia każdej wioski (ogrodzona, z owcami).
static func is_pasture(p: Vector3i) -> bool:
	return p.x >= 0 and p.z == 0 and p.y == (p.x * 3 + 2) % FIELD_SECTORS


static func field_color(x: float, z: float) -> Color:
	var p := field_parcel(x, z)
	if p.x < 0 or is_pasture(p):
		return Color(0.34, 0.62, 0.2)
	var crop := absi(hash(p)) % CROPS.size()
	var col: Color = CROPS[crop]
	# rzędy upraw: delikatne pasy w poprzek działki
	var stripe := sin((x * 0.7 + z * 0.7) * 0.9 + p.y) > 0.0
	return col.darkened(0.08) if stripe else col


## Numer koloru łąki kwiatów (FLOWER_COLORS) albo -1.
static func flower_patch(x: float, z: float) -> int:
	_init_noise()
	if forest(x, z) > 0.35 or farmland(x, z) >= 0.0:
		return -1
	var n := _forest.get_noise_2d(x * 3.1 + 500.0, z * 3.1 - 300.0)
	if n < 0.32:
		return -1
	return absi(hash(Vector2i(int(floor(x / 160.0)), int(floor(z / 160.0))))) % FLOWER_COLORS.size()


## Gatunek drzewa w danym miejscu: iglaste w górach i na północy, liściaste kępami
## (dąb, brzoza, jesienne, kwitnące), `r` = los 0..1 dla domieszek.
static func tree_species(x: float, z: float, r: float) -> String:
	_init_noise()
	var h := height(x, z)
	if h > 35.0 or z < -170.0:
		return "PineTall" if r < 0.5 else "Pine"
	var n := _hills.get_noise_2d(x * 2.3 + 900.0, z * 2.3)  # „rodzina” kępy
	if r < 0.15:
		return "Pine"
	if n > 0.35:
		return "Autumn" if r < 0.8 else "Oak"
	if n < -0.35:
		return "Birch" if r < 0.75 else "Pine"
	if n > 0.15 and r > 0.85:
		return "Blossom"
	return "Oak" if r < 0.7 else "Birch"


## Wysokości do kolizji kawałka — można liczyć w wątku w tle.
func _body_heights(c: Vector2i) -> PackedFloat32Array:
	var res: int = LOD_RES[0]
	var step := CHUNK / res
	var o := chunk_origin(c)
	var data := PackedFloat32Array()
	data.resize((res + 1) * (res + 1))
	for j in res + 1:
		for i in res + 1:
			data[j * (res + 1) + i] = height(o.x + i * step, o.z + j * step)
	return data


func _chunk_body(c: Vector2i, data: PackedFloat32Array = PackedFloat32Array()) -> StaticBody3D:
	var res: int = LOD_RES[0]
	var step := CHUNK / res
	var o := chunk_origin(c)
	if data.is_empty():
		data = _body_heights(c)
	var shape := HeightMapShape3D.new()
	shape.map_width = res + 1
	shape.map_depth = res + 1
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
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/water.gdshader")
	for k in 2:  # zmarszczki: dwie przesuwane mapy normalnych z szumu
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.as_normal_map = true
		tex.bump_strength = 6.0 if k == 0 else 3.0
		var n := FastNoiseLite.new()
		n.seed = 11 + k
		n.frequency = 0.02 if k == 0 else 0.045
		tex.noise = n
		mat.set_shader_parameter("ripples_a" if k == 0 else "ripples_b", tex)
	plane.material = mat
	_water_mat = mat
	# mapa głębokości wody — w tle (kilka sekund na telefonie), potem piana przy brzegach
	for v: Array in VILLAGES:  # wartości z pamięci podręcznej najpierw w głównym wątku
		height(v[0], v[1])
	_depth_task = WorkerThreadPool.add_task(_bake_depth_map)
	water.mesh = plane
	water.position.y = WATER_LEVEL
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


var _water_mat: ShaderMaterial
var _depth_task: int = -1
var _depth_image: Image
const DEPTH_RES := 512


## Głębokość wody (R = (poziom wody − teren) / 8 m) na siatce 8 m — dla shadera wody.
func _bake_depth_map() -> void:
	var img := Image.create(DEPTH_RES, DEPTH_RES, false, Image.FORMAT_R8)
	var step := SIZE / DEPTH_RES
	for j in DEPTH_RES:
		for i in DEPTH_RES:
			var h := height(-HALF + (i + 0.5) * step, -HALF + (j + 0.5) * step)
			img.set_pixel(i, j, Color(clampf((WATER_LEVEL - h) / 8.0, 0.0, 1.0), 0, 0))
	_depth_image = img


func _check_depth_task() -> void:
	if _depth_task < 0 or not WorkerThreadPool.is_task_completed(_depth_task):
		return
	WorkerThreadPool.wait_for_task_completion(_depth_task)
	_depth_task = -1
	_water_mat.set_shader_parameter("depth_map", ImageTexture.create_from_image(_depth_image))
	_water_mat.set_shader_parameter("world_size", SIZE)
	_water_mat.set_shader_parameter("has_depth_map", true)


func _exit_tree() -> void:
	if _depth_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_depth_task)
	for n: Vector2i in _pending.keys():
		WorkerThreadPool.wait_for_task_completion(_pending[n])
	_pending.clear()


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
