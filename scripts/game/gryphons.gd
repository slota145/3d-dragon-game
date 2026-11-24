class_name Gryphons
extends Node3D
## Gniazda dzikich gryfów na szczytach gór (NESTS) — w każdym para gryfów i skarb (świat
## wystawia go przez GoldFinds). Nowy dzień: zabite gryfy wracają.

signal attacked(gryphon: Prey, damage: float)
signal gryphon_killed(gryphon: Prey)

## Gniazda: [x, z] — wierzchołki gór na północy.
const NESTS := [[440.0, -750.0], [-740.0, -650.0], [-660.0, -1150.0]]
const PER_NEST := 2

var dragon: DragonController
var _gryphons: Array[Gryphon] = []


func _ready() -> void:
	Wildlife._load()
	for i in NESTS.size():
		var mi := MeshInstance3D.new()
		mi.name = "Nest_%d" % i
		mi.mesh = (Wildlife._parts["Nest"][0] as Array)[1]
		mi.scale = Vector3.ONE * 1.4
		add_child(mi)
		mi.global_position = nest_position(i) - Vector3.UP * 0.4


static func nest_position(i: int) -> Vector3:
	var n: Array = NESTS[i]
	return Vector3(n[0], Terrain.height(n[0], n[1]), n[1])


func gryphons() -> Array[Gryphon]:
	var out: Array[Gryphon] = []
	for g in _gryphons:
		if is_instance_valid(g) and g.is_alive():
			out.append(g)
	return out


func repopulate() -> void:
	for g in _gryphons:
		if is_instance_valid(g) and not g.carried:
			g.queue_free()
	_gryphons.clear()
	for i in NESTS.size():
		for k in PER_NEST:
			_spawn(i)


func _spawn(i: int) -> Gryphon:
	var g := Gryphon.new()
	g.species = "gryphon"
	g.display_name = "Gryf"
	g.max_health = 18.0
	g.food = 8.0
	g.body_size = 5.0  # unieść go może dopiero dorosły smok
	g.radius = 1.9
	g.flies = true
	g.nest = nest_position(i)
	g.dragon = dragon
	var body := Wildlife.build_body("Gryphon", 900.0)
	body.scale = Vector3.ONE * 1.6
	g.add_child(body)
	add_child(g)
	g.global_position = g.nest + Vector3(randf_range(-30, 30), 30.0, randf_range(-30, 30))
	g.attacked.connect(func(by: Prey, d: float) -> void: attacked.emit(by, d))
	g.killed.connect(func(p: Prey) -> void: gryphon_killed.emit(p))
	_gryphons.append(g)
	return g
