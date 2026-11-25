class_name GryphonRiders
extends Node3D
## Jeźdźcy gryfów królestwa: dwóch strzeże zamku z wież (Castle.rider_perch), dowódca (boss)
## siedzi na wieży-gnieździe (Castle.eyrie_top). Przy rozgłosie „Legenda” para łowców wylatuje
## polować na smoka w całym świecie. W 2. fazie walki z dowódcą z wież wylatują posiłki.
## Nowy dzień: `repopulate` (pokonany dowódca nie wraca — zapis gry).

signal attacked(by: Prey, damage: float)
signal rider_killed(rider: GryphonRider)
signal boss_killed(boss: GryphonCommander)
signal boss_phase_two(boss: GryphonCommander)
signal armor_blocked(boss: GryphonCommander)

## Promień obrony zamku (m) — od wieży, na której siedzi jeździec.
const CASTLE_TERRITORY := 230.0
const HUNTERS := 2

var dragon: DragonController
var villages: Villages
var castle: Castle
var boss: GryphonCommander
var _riders: Array[GryphonRider] = []


func riders() -> Array[GryphonRider]:
	var out: Array[GryphonRider] = []
	for r in _riders:
		if is_instance_valid(r) and r.is_alive() and r != boss:
			out.append(r)
	return out


func boss_alive() -> bool:
	return is_instance_valid(boss) and boss.is_alive()


## Nowy dzień: jeźdźcy na wieżach, dowódca na gnieździe (jeśli żyje), łowcy przy „Legendzie”.
func repopulate(hunters: bool, with_boss: bool) -> void:
	for r in _riders:
		if is_instance_valid(r) and not r.carried:
			r.queue_free()
	_riders.clear()
	boss = null
	for i in 2:
		var r := _spawn_rider(castle.rider_perch(i), CASTLE_TERRITORY)
		r.global_position = r.nest
	if with_boss:
		_spawn_boss()
	if hunters:
		send_hunters()


## Łowcy: para jeźdźców wylatuje z gniazda dowódcy i ściga smoka po całym świecie.
func send_hunters() -> void:
	for i in HUNTERS:
		var r := _spawn_rider(castle.eyrie_top(), 1.0e7)
		r.hunter = true
		r.global_position = r.nest + Vector3(randf_range(-20, 20), 40.0, randf_range(-20, 20))
		r.mode = Gryphon.Mode.ATTACK


## Posiłki w 2. fazie walki z dowódcą: dwóch jeźdźców startuje z wież.
func reinforce() -> void:
	for i in 2:
		var r := _spawn_rider(castle.rider_perch(i), CASTLE_TERRITORY * 1.5)
		r.global_position = r.nest + Vector3.UP * 3.0
		r.mode = Gryphon.Mode.ATTACK


func _spawn_rider(perch: Vector3, territory: float) -> GryphonRider:
	var r := GryphonRider.new()
	r.display_name = "Jeździec gryfa"
	r.max_health = 26.0
	r.attack_damage = 10.0
	r.attack_speed = 29.0
	r.food = 9.0
	r.body_size = 5.0
	r.radius = 2.0
	r.territory = territory
	_build(r, perch, 1.6, "Knight", 1.1)
	r.killed.connect(func(p: Prey) -> void: rider_killed.emit(p as GryphonRider))
	return r


func _spawn_boss() -> void:
	var b := GryphonCommander.new()
	b.display_name = "Dowódca jeźdźców"
	b.max_health = 260.0
	b.attack_damage = 16.0
	b.attack_speed = 31.0
	b.patrol_speed = 15.0
	b.food = 30.0
	b.body_size = 9.0  # unieść go może tylko pradawny smok
	b.radius = 3.0
	b.territory = CASTLE_TERRITORY
	b.can_flee = false
	_build(b, castle.eyrie_top(), 2.4, "Commander", 1.3)
	b.global_position = b.nest
	b.mode = Gryphon.Mode.PERCH
	b.killed.connect(func(p: Prey) -> void: boss_killed.emit(p as GryphonCommander))
	b.phase_two.connect(func(x: GryphonCommander) -> void:
		reinforce()
		boss_phase_two.emit(x))
	b.armor_blocked.connect(func(x: GryphonCommander) -> void: armor_blocked.emit(x))
	boss = b


## Gryf (animals.glb) w rzędzie (people.glb: Tack) z jeźdźcem `role` w siodle.
func _build(r: GryphonRider, perch: Vector3, scale: float, role: String, rider_scale: float) -> void:
	r.species = "gryphon"
	r.flies = true
	r.nest = perch
	r.dragon = dragon
	var body := Wildlife.build_body("Gryphon", 1400.0)
	body.scale = Vector3.ONE * scale
	body.add_child(villages.build_role("Tack", "Tack"))
	var rider := villages.build_role(role, "Rider")
	var k := rider_scale / scale
	rider.scale = Vector3.ONE * k
	rider.position = Vector3(0.0, 1.95 - 0.9 * k, 0.0)  # biodra na siodle
	body.add_child(rider)
	r.add_child(body)
	add_child(r)
	r.attacked.connect(func(by: Prey, d: float) -> void: attacked.emit(by, d))
	_riders.append(r)
