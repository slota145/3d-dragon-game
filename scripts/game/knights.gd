class_name Knights
extends Node3D
## Rycerze królestwa: konne patrole jeżdżą drogami tam i z powrotem (PATROLS), a przy dużym
## rozgłosie („Postrach”, „Legenda”) z zamku wyrusza oddział pościgowy prosto na smoka.
## Zabici wracają następnego dnia (`repopulate`). Modele: people.glb (Knight, Crossbow, Warhorse).

signal attacked(knight: Knight, damage: float)
signal knight_killed(knight: Knight)
signal scared(knight: Knight)

## Patrole: [indeks drogi w Terrain.ROAD_PAIRS, liczba rycerzy, start (0..1 długości)].
## Ostatni w szyku jest kusznikiem.
const PATROLS := [[5, 3, 0.45], [1, 2, 0.3], [4, 2, 0.6]]
## Oddział pościgowy (na każdy poziom rozgłosu od „Postrachu”).
const HUNT_SIZE := 4
## Odstęp w szyku (m).
const SPACING := 7.0

var dragon: DragonController
var villages: Villages

var _patrols: Array[Patrol] = []
var _knights: Array[Knight] = []


## Oddział na drodze: punkt prowadzącego przesuwa się po drodze tam i z powrotem, reszta
## jedzie za nim w odstępach SPACING.
class Patrol:
	extends RefCounted
	var road: PackedVector2Array
	var road_y: PackedFloat32Array
	var length: float = 0.0
	var t: float = 0.0
	var dir: float = 1.0
	var speed: float = 2.4
	var size: int = 2
	## Oddział pościgowy: jedzie drogą od zamku raz, bez zawracania (`done` na końcu).
	var hunt: bool = false
	var done: bool = false

	func _init(pts: PackedVector2Array, heights: PackedFloat32Array, start: float, n: int) -> void:
		road = pts
		road_y = heights
		for k in road.size() - 1:
			length += road[k].distance_to(road[k + 1])
		t = start * length
		size = n

	func advance(delta: float) -> void:
		if done:
			return
		t += speed * delta * dir
		var margin := 70.0 + SPACING * size
		if hunt and (t < margin or t > length - 20.0):
			done = true
			return
		if t > length - 70.0 or t < margin:  # wioska / brama — zawróć
			dir = -dir
			t = clampf(t, margin, length - 70.0)

	## Miejsce w szyku: odległość wzdłuż drogi.
	func _slot_t(slot: int) -> float:
		return t - dir * SPACING * slot

	func slot_position(slot: int) -> Vector3:
		var d := _slot_t(slot)
		var p := _point_at(d)
		return Vector3(p.x, _height_at(d), p.y)

	## [pozycja, kąt obrotu Y] — przodem w kierunku jazdy.
	func slot_pose(slot: int) -> Array:
		var d := _slot_t(slot)
		var p := _point_at(d)
		var ahead := _point_at(d + 3.0 * dir)
		return [Vector3(p.x, _height_at(d), p.y), atan2(ahead.x - p.x, ahead.y - p.y)]

	func _point_at(dist: float) -> Vector2:
		var d := clampf(dist, 0.0, length)
		for k in road.size() - 1:
			var seg := road[k].distance_to(road[k + 1])
			if d <= seg:
				return road[k].lerp(road[k + 1], d / maxf(seg, 0.01))
			d -= seg
		return road[road.size() - 1]

	func _height_at(dist: float) -> float:
		var p := _point_at(dist)
		if road_y.size() != road.size():
			return Terrain.height(p.x, p.y)
		var d := clampf(dist, 0.0, length)
		for k in road.size() - 1:
			var seg := road[k].distance_to(road[k + 1])
			if d <= seg:
				return lerpf(road_y[k], road_y[k + 1], d / maxf(seg, 0.01))
			d -= seg
		return road_y[road_y.size() - 1]


func _physics_process(delta: float) -> void:
	for p in _patrols:
		p.advance(delta)


func knights() -> Array[Knight]:
	var out: Array[Knight] = []
	for k in _knights:
		if is_instance_valid(k) and k.is_alive():
			out.append(k)
	return out


func patrols() -> Array[Patrol]:
	return _patrols


## Nowy dzień: patrole w komplecie, `hunts` oddziałów pościgowych (wg rozgłosu).
func repopulate(hunts: int = 0) -> void:
	for k in _knights:
		if is_instance_valid(k) and not k.carried:
			k.queue_free()
	_knights.clear()
	_patrols.clear()
	for i in PATROLS.size():
		var def: Array = PATROLS[i]
		var road: int = def[0]
		var p := Patrol.new(Terrain.road_points(road), Roads.heights(road), def[2], def[1])
		_patrols.append(p)
		for s in p.size:
			var k := _spawn(s == p.size - 1, s % 2 == 1)
			k.patrol = p
			k.slot = s
			var pose := p.slot_pose(s)
			k.global_position = pose[0]
			k.rotation.y = pose[1]
	for h in hunts:
		send_hunt()


## Oddział pościgowy: wyjeżdża spod bramy zamku drogą (z wzgórza zamkowego), a gdy smok
## jest blisko albo droga się kończy — jedzie prosto na niego.
func send_hunt() -> void:
	var road := Terrain.ROAD_PAIRS.size() - 1  # droga do zamku
	var pts := Terrain.road_points(road)
	var p := Patrol.new(pts, Roads.heights(road), 0.0, HUNT_SIZE)
	p.hunt = true
	p.speed = 6.5
	# ostatni punkt drogi to plac przed bramą: start 40 m przed nim, jazda w stronę wioski
	p.t = p.length - 40.0
	p.dir = -1.0
	_patrols.append(p)
	for s in HUNT_SIZE:
		var k := _spawn(s == HUNT_SIZE - 1, s == 1)
		k.mode = Knight.Mode.HUNT
		k.patrol = p
		k.slot = s
		var pose := p.slot_pose(s)
		k.global_position = pose[0]
		k.rotation.y = pose[1]
		k.reset_physics_interpolation()


func _spawn(crossbow: bool, coward: bool) -> Knight:
	var k := Knight.new()
	k.crossbow = crossbow
	k.coward = coward
	k.species = "knight"
	k.display_name = "Kusznik" if crossbow else "Rycerz"
	k.max_health = 6.0 if crossbow else 8.0
	k.food = 7.0
	k.body_size = 3.0
	k.radius = 1.1
	k.walk_speed = 2.4
	k.flee_speed = 9.5
	k.dragon = dragon
	k.graze_pitch = 0.0
	var body := villages.build_role("Warhorse", "Body")
	var rider := villages.build_role("Crossbow" if crossbow else "Knight", "Rider")
	rider.position = Vector3(0.0, 0.98, 0.05)
	body.add_child(rider)
	k.add_child(body)
	add_child(k)
	k.attacked.connect(func(by: Prey, d: float) -> void: attacked.emit(by as Knight, d))
	k.killed.connect(func(p: Prey) -> void: knight_killed.emit(p as Knight))
	k.scared.connect(func(by: Knight) -> void: scared.emit(by))
	k.threw.connect(func(n: Node3D) -> void: add_child(n))
	_knights.append(k)
	return k
