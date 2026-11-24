class_name PreySpawner
extends Node3D
## Utrzymuje populację dzikiej zwierzyny wokół smoka: nowe zwierzęta pojawiają się poza
## zasięgiem wzroku w swoim siedlisku, dalekie znikają. Króliki i owce na łąkach, sarny i dziki
## w lasach, kozy w górach, kaczki na jeziorach (gatunki: Wildlife.SPECIES).

## Dzik zaatakował smoka.
signal attacked(prey: Prey, damage: float)

## Gatunek -> [docelowa liczba, wielkość stada min, max].
const POPULATION := {
	"rabbit": [20, 1, 1], "sheep": [12, 3, 5], "deer": [8, 1, 3], "boar": [6, 1, 4], "goat": [8, 2, 4],
	"duck": [10, 2, 4],
}

@export var spawn_min: float = 18.0
@export var spawn_max: float = 90.0
@export var despawn_distance: float = 220.0

var dragon: Node3D
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0


func _ready() -> void:
	_rng.randomize()


## Pierwsze zasiedlenie (część zwierząt blisko, żeby od razu było na co polować).
func populate() -> void:
	for i in 20:
		_spawn_group("rabbit", _random_point(8.0 if i < 5 else spawn_min, spawn_max, "rabbit"))
	for i in 3:
		_spawn_group("sheep", _random_point(25.0 if i == 0 else spawn_min * 1.5, spawn_max, "sheep"))
	for sp: String in ["deer", "boar", "goat", "duck"]:
		for i in 3:
			_try_spawn(sp, spawn_min, spawn_max * 1.3)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or not dragon:
		return
	_timer = 1.0
	var counts := {}
	for p in get_children():
		if not p is Prey:
			continue
		if p.global_position.distance_to(dragon.global_position) > _despawn() and p.is_alive():
			p.queue_free()
			continue
		counts[p.species] = int(counts.get(p.species, 0)) + 1
	for sp: String in POPULATION:
		if int(counts.get(sp, 0)) < int(POPULATION[sp][0]):
			_try_spawn(sp, _range_max() * 0.6, _range_max() * 1.2)


## Większy smok widzi dalej — zwierzęta pojawiają się i znikają dalej.
func _range_max() -> float:
	var s: float = dragon.get("stats").size if dragon and dragon.get("stats") else 2.4
	return spawn_max + s * 4.0


func _despawn() -> float:
	return despawn_distance + _range_max() - spawn_max


## Czy punkt pasuje do siedliska gatunku.
static func suits(species: String, x: float, z: float) -> bool:
	match species:
		"deer":
			return Terrain.forest(x, z) > 0.25 and Terrain.is_walkable(x, z)
		"boar":
			return Terrain.forest(x, z) > 0.4 and Terrain.is_walkable(x, z)
		"goat":
			var h := Terrain.height(x, z)
			return h > 35.0 and absf(Terrain.height(x + 3.0, z) - h) < 4.0 and absf(Terrain.height(x, z + 3.0) - h) < 4.0
		"duck":
			return Terrain.height(x, z) < Terrain.WATER_LEVEL - 1.0
	# łąki: nie w lesie, nie na polach
	return Terrain.is_walkable(x, z) and Terrain.forest(x, z) < 0.35 and Terrain.farmland(x, z) <= 0.05


## Kilka losowych prób znalezienia miejsca w siedlisku (w lesie / w górach / na wodzie).
func _try_spawn(species: String, r_min: float, r_max: float) -> void:
	for i in 10:
		var p := _random_point_raw(r_min, r_max)
		if suits(species, p.x, p.z):
			_spawn_group(species, p)
			return


func _random_point(r_min: float, r_max: float, species: String) -> Vector3:
	var p := Vector3.ZERO
	for i in 12:
		p = _random_point_raw(r_min, r_max)
		if suits(species, p.x, p.z):
			break
	p.y = Terrain.height(p.x, p.z)
	return p


func _random_point_raw(r_min: float, r_max: float) -> Vector3:
	var center := dragon.global_position if dragon else Vector3.ZERO
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(r_min, r_max)
	var p := Vector3(center.x + cos(a) * r, 0.0, center.z + sin(a) * r)
	# nie na wzgórzu legowiska — wypchnij poza jego obrys
	var off := p - Lair.POSITION
	off.y = 0.0
	if off.length() < Lair.RADIUS + 4.0:
		p = Lair.POSITION + (off.normalized() if off.length() > 0.1 else Vector3.BACK) * (Lair.RADIUS + 4.0 + _rng.randf() * 20.0)
	return p


## Stado / rodzina wokół punktu (dziki: locha z warchlakami).
func _spawn_group(species: String, center: Vector3) -> void:
	var pop: Array = POPULATION[species]
	var n := _rng.randi_range(pop[1], pop[2])
	for i in n:
		var off := Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4)) if i > 0 else Vector3.ZERO
		var pos := center + off
		var p := Wildlife.create(species, species == "boar" and i > 0)
		if not p._can_go(pos.x, pos.z):
			pos = center
		spawn(p, pos)
		if species == "duck":  # kaczki trzymają się swojego jeziora
			p.home = center
			p.home_radius = 30.0


## Dodaje gotową ofiarę do świata.
func spawn(p: Prey, pos: Vector3) -> void:
	p.dragon = dragon
	p.rotation.y = _rng.randf() * TAU
	add_child(p)
	p.global_position = Vector3(pos.x, p._ground_y(pos.x, pos.z), pos.z)
	p.attacked.connect(func(by: Prey, dmg: float) -> void: attacked.emit(by, dmg))
