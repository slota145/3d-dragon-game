class_name PreySpawner
extends Node3D
## Utrzymuje populację zwierzyny wokół smoka: nowe zwierzęta pojawiają się poza zasięgiem
## wzroku, dalekie znikają. Owce chodzą stadami.

@export var rabbit_model: PackedScene
@export var sheep_model: PackedScene
@export var rabbit_count: int = 22
@export var sheep_herds: int = 4
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
	for i in rabbit_count:
		_spawn_rabbit(_random_point(8.0 if i < 5 else spawn_min, spawn_max))
	for i in sheep_herds:
		_spawn_herd(_random_point(25.0 if i == 0 else spawn_min * 1.5, spawn_max))


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or not dragon:
		return
	_timer = 1.0
	var rabbits := 0
	var sheep := 0
	for p in get_children():
		if not p is Prey:
			continue
		if p.global_position.distance_to(dragon.global_position) > despawn_distance and p.is_alive():
			p.queue_free()
			continue
		if p.display_name == "Owca":
			sheep += 1
		else:
			rabbits += 1
	if rabbits < rabbit_count:
		_spawn_rabbit(_random_point(spawn_max * 0.6, spawn_max))
	if sheep < sheep_herds * 3:
		_spawn_herd(_random_point(spawn_max * 0.7, spawn_max * 1.2))


func _random_point(r_min: float, r_max: float) -> Vector3:
	var center := dragon.global_position if dragon else Vector3.ZERO
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(r_min, r_max)
	return Vector3(center.x + cos(a) * r, 0.0, center.z + sin(a) * r)


func _make(model: PackedScene, pos: Vector3) -> Prey:
	var p := Prey.new()
	var body := model.instantiate() as Node3D
	body.name = "Body"
	p.add_child(body)
	p.dragon = dragon
	p.rotation.y = _rng.randf() * TAU
	add_child(p)
	p.global_position = pos
	return p


func _spawn_rabbit(pos: Vector3) -> void:
	var p := _make(rabbit_model, pos)
	p.display_name = "Królik"


func _spawn_herd(center: Vector3) -> void:
	for i in _rng.randi_range(3, 5):
		var off := Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
		var p := _make(sheep_model, center + off)
		p.display_name = "Owca"
		p.max_health = 3.0
		p.health = 3.0
		p.food = 4.0
		p.body_size = 1.3
		p.radius = 0.7
		p.walk_speed = 0.5
		p.flee_speed = 3.0
		p.stamina = 5.0
		p.hops = false
		p.zigzag = 0.25
		p.alert_range = 9.0
