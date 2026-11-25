class_name Castle
extends Node3D
## Zamek królewski na wzgórzu (Terrain.CASTLE): ośmiokątny mur z wieżami, brama od strony
## drogi, donżon ze skarbcem. Na czterech wieżach balisty (Ballista), na murach łucznicy.
## Moduły z assets/models/castle.glb (generator tools/blender/gen_castle.py).
## Skarbiec (skrzynie przed donżonem) wystawia świat przez GoldFinds — `treasury_spots()`.
## Za donżonem wieża-gniazdo dowódcy jeźdźców gryfów (`eyrie_top()`), jeźdźcy siadają na
## wieżach z balistami (`rider_perch()`) — patrz GryphonRiders.

signal ballista_destroyed(b: Ballista)
signal bolt_hit(damage: float)
signal guard_eaten(guard: Prey)
signal guard_poked(guard: Villager, damage: float)

const SIDES := 8
## Wieże z balistami (indeksy wierzchołków ośmiokąta); pozostałe mają dachy.
const BALLISTA_TOWERS := [0, 2, 4, 6]
const WALL_H := 9.0
const TOWER_H := 15.0

var dragon: DragonController
var villages: Villages
var _meshes: Dictionary = {}
var _xforms: Dictionary = {}
var _ballistas: Array[Ballista] = []
var _guards: Array[Villager] = []


func _ready() -> void:
	var scene: Node = (load("res://assets/models/castle.glb") as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var key := String(mi.name).trim_prefix("Castle_")
		_meshes[key] = mi.mesh
		_xforms[key] = mi.transform
	scene.free()
	position = Terrain.castle_center()
	var g := Terrain.castle_gate_dir()
	rotation.y = atan2(g.x, g.y)  # lokalne +Z = brama
	_build()


func radius() -> float:
	return Terrain.CASTLE[2]


## Wierzchołek ośmiokąta murów (lokalnie). Bok 0 (brama) jest między wierzchołkami 7 i 0.
func _vertex(k: int) -> Vector3:
	var a := (k + 0.5) * TAU / SIDES
	return Vector3(sin(a), 0.0, cos(a)) * radius()


func _build() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	var side_len := 2.0 * radius() * sin(PI / SIDES)
	var apothem := radius() * cos(PI / SIDES)
	for k in SIDES:
		var basis := Basis(Vector3.UP, k * TAU / SIDES)
		var mid := basis * Vector3(0, 0, apothem)
		# odcinki murów między wieżami (na boku 0 — po obu stronach bramy)
		var spans := [[-side_len * 0.5 + 3.5, -7.0], [7.0, side_len * 0.5 - 3.5]] if k == 0 \
			else [[-side_len * 0.5 + 3.5, side_len * 0.5 - 3.5]]
		for sp: Array in spans:
			var span: float = sp[1] - sp[0]
			var n := ceili(span / 10.0)
			var piece := span / n
			for j in n:
				var x: float = sp[0] + piece * (j + 0.5)
				_mesh("Wall", Transform3D(basis.scaled(Vector3(piece / 10.0, 1.0, 1.0)), mid + basis * Vector3(x, 0, 0)))
			_box(body, Transform3D(basis, mid + basis * Vector3((sp[0] + sp[1]) * 0.5, WALL_H * 0.5 - 0.5, 0)),
				Vector3(span, WALL_H + 1.0, 3.6))
		if k == 0:
			_mesh("Gate", Transform3D(basis, mid))
			for x in [-5.0, 5.0]:  # filary bramy i nadproże — przejazd 6 × 7 m zostaje wolny
				_box(body, Transform3D(basis, mid + basis * Vector3(x, 6.0, 0)), Vector3(4.0, 13.0, 8.0))
			_box(body, Transform3D(basis, mid + basis * Vector3(0, 9.5, 0)), Vector3(6.0, 5.0, 8.0))
	for k in SIDES:  # wieże w narożnikach
		var v := _vertex(k)
		var flat := k in BALLISTA_TOWERS
		_mesh("Tower" if flat else "TowerRoof", Transform3D(Basis(Vector3.UP, (k + 0.5) * TAU / SIDES), v))
		var cyl := CylinderShape3D.new()
		cyl.radius = 5.0
		cyl.height = TOWER_H + 1.5
		var cs := CollisionShape3D.new()
		cs.shape = cyl
		cs.position = v + Vector3.UP * (TOWER_H * 0.5 - 0.7)
		body.add_child(cs)
		if flat:
			_add_ballista(v + Vector3.UP * TOWER_H, k)
	var keep_pos := _keep_pos()
	_mesh("Keep", Transform3D(Basis.IDENTITY, keep_pos))
	_box(body, Transform3D(Basis.IDENTITY, keep_pos + Vector3.UP * 11.0), Vector3(18.0, 23.0, 18.0))
	_mesh("Eyrie", Transform3D(Basis.IDENTITY, EYRIE_POS))
	var ecyl := CylinderShape3D.new()
	ecyl.radius = 5.2
	ecyl.height = 27.0
	var ecs := CollisionShape3D.new()
	ecs.shape = ecyl
	ecs.position = EYRIE_POS + Vector3.UP * 12.5
	body.add_child(ecs)


## Wieża-gniazdo dowódcy (lokalnie) — za donżonem, przy tylnym murze.
const EYRIE_POS := Vector3(0.0, 0.0, -32.0)


## Miejsce dowódcy na podeście wieży-gniazda (globalnie).
func eyrie_top() -> Vector3:
	return to_global(EYRIE_POS + Vector3.UP * 26.6)


## Miejsce jeźdźca gryfa `i` (0, 1) na platformie wieży z balistą, obok balisty (globalnie).
func rider_perch(i: int) -> Vector3:
	var k: int = [2, 6][i]
	var v := _vertex(k)
	return to_global(v - v.normalized() * 2.6 + Vector3.UP * TOWER_H)


func _keep_pos() -> Vector3:
	return Vector3(0, 0, -radius() * 0.32)


func _mesh(key: String, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes.get(key)
	mi.transform = xf
	add_child(mi)
	return mi


func _box(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


func _add_ballista(pos: Vector3, k: int) -> void:
	var b := Ballista.new()
	b.name = "Ballista_%d" % k
	add_child(b)
	b.position = pos
	b.rotation.y = (k + 0.5) * TAU / SIDES  # na zewnątrz
	b.setup(_meshes["BallistaBase"], _meshes["BallistaBow"], _meshes["Bolt"], _xforms["BallistaBow"])
	b.dragon = dragon
	b.fired.connect(func(bolt: Bolt) -> void:
		get_parent().add_child(bolt)
		bolt.hit.connect(func(d: float) -> void: bolt_hit.emit(d)))
	b.destroyed.connect(func(x: Ballista) -> void: ballista_destroyed.emit(x))
	_ballistas.append(b)


func ballistas() -> Array[Ballista]:
	return _ballistas


func working_ballistas() -> int:
	return _ballistas.filter(func(b: Ballista) -> bool: return b.is_working()).size()


func guards() -> Array[Villager]:
	var out: Array[Villager] = []
	for g in _guards:
		if is_instance_valid(g) and g.is_alive():
			out.append(g)
	return out


## Nowy dzień: balisty naprawione, łucznicy wracają na mury.
func repopulate() -> void:
	for b in _ballistas:
		b.queue_free()
	_ballistas.clear()
	for k in SIDES:
		if k in BALLISTA_TOWERS:
			_add_ballista(_vertex(k) + Vector3.UP * TOWER_H, k)
	for g in _guards:
		if is_instance_valid(g):
			g.queue_free()
	_guards.clear()
	if not villages:
		return
	var apothem := radius() * cos(PI / SIDES)
	for k in SIDES:
		var basis := Basis(Vector3.UP, k * TAU / SIDES)
		var spots: Array = [Vector3(-9.0, 12.0, apothem - 0.5), Vector3(9.0, 12.0, apothem - 0.5)] if k == 0 \
			else [Vector3(0.0, WALL_H, apothem - 0.3)]
		for p: Vector3 in spots:
			_spawn_guard(to_global(basis * p))


func _spawn_guard(pos: Vector3) -> void:
	var g := villages.make_person("Hunter", "Łucznik zamkowy")
	g.archer = true
	g.perch = true
	g.max_health = 3.0
	g.shoot_range = 80.0
	g.arrow_speed = 42.0
	g.shoot_cooldown = 3.0
	g.home = pos
	g.dragon = dragon
	add_child(g)
	g.top_level = true
	g.global_position = pos
	g.global_rotation.y = rotation.y
	g.shot_arrow.connect(func(arrow: Node3D) -> void: get_parent().add_child(arrow))
	g.poked_dragon.connect(func(by: Villager, dmg: float) -> void: guard_poked.emit(by, dmg))
	g.killed.connect(func(p: Prey) -> void: guard_eaten.emit(p))
	_guards.append(g)


## Ogień smoka: niszczy balisty (łuczników piecze świat — są w grupie „prey”).
func burn_near(at: Vector3, r: float, damage: float) -> void:
	for b in _ballistas:
		if b.is_working() and b.global_position.distance_to(at) < r + 2.5:
			b.burn(damage)


## Miejsca skrzyń skarbca: przed wrotami donżonu (globalnie).
func treasury_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in [-4.0, 0.0, 4.0]:
		out.append(to_global(_keep_pos() + Vector3(x, 0.0, 12.0)))
	return out


## Czy punkt jest w obrębie murów.
func inside(p: Vector3) -> bool:
	return Vector2(p.x - position.x, p.z - position.z).length() < radius() - 3.0
