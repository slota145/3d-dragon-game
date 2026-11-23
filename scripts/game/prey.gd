class_name Prey
extends Node3D
## Zwierzyna: pasie się i wędruje, ucieka przed smokiem (większego widzi z daleka),
## po ugryzieniu traci zdrowie, po śmierci zostaje zjedzona. Ruch i „animacja” w kodzie
## (kicanie / kołysanie modelu `Body`), bez szkieletu.

signal killed(prey: Prey)

enum State { GRAZE, FLEE, DEAD }

@export var display_name: String = "Królik"
@export var max_health: float = 1.0
## Punkty jedzenia (wzrost + głód).
@export var food: float = 1.2
## Długość zwierzęcia (m) — małe ofiary dają dużemu smokowi mniej.
@export var body_size: float = 0.5
## Promień trafienia (m).
@export var radius: float = 0.35
@export var walk_speed: float = 0.7
@export var flee_speed: float = 4.2
## Ile sekund może uciekać pełną prędkością, zanim się zmęczy.
@export var stamina: float = 3.5
## Kicanie (królik) zamiast kołysania (owca).
@export var hops: bool = true
@export var zigzag: float = 0.7
## Bazowy zasięg czujności (m), rośnie z rozmiarem smoka.
@export var alert_range: float = 7.0

var dragon: Node3D
var state: State = State.GRAZE
var health: float = 1.0

var _dir: Vector3 = Vector3.FORWARD
var _speed: float = 0.0
var _timer: float = 0.0
var _stamina_left: float = 0.0
var _phase: float = 0.0
var _flee_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _body: Node3D


func _ready() -> void:
	add_to_group("prey")
	health = max_health
	_stamina_left = stamina
	_rng.randomize()
	_body = get_node_or_null("Body")
	_pick_wander()


func is_alive() -> bool:
	return state != State.DEAD


func center() -> Vector3:
	return global_position + Vector3.UP * radius


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var to_dragon := Vector3.ZERO
	var dist := INF
	if dragon:
		to_dragon = dragon.global_position - global_position
		to_dragon.y = 0.0
		dist = to_dragon.length()
	var dragon_size: float = dragon.get("stats").size if dragon and dragon.get("stats") else 2.4
	var alert := alert_range + dragon_size * 1.5
	if dragon is CharacterBody3D and Vector2(dragon.velocity.x, dragon.velocity.z).length() < 0.6 * dragon_size / 2.4:
		alert *= 0.6  # smok skrada się (wolno) — łatwiej podejść
	if dist < alert:
		state = State.FLEE
		_flee_time = 2.5

	_timer -= delta
	if state == State.FLEE:
		_flee_time -= delta
		_stamina_left -= delta
		var away := -to_dragon.normalized() if dist < INF and dist > 0.01 else _dir
		var wiggle := sin(Time.get_ticks_msec() / 1000.0 * 3.5 + get_instance_id()) * zigzag
		_dir = away.rotated(Vector3.UP, wiggle).normalized()
		_speed = flee_speed if _stamina_left > 0.0 else walk_speed * 1.6
		if _flee_time <= 0.0 and dist > alert * 1.5:
			state = State.GRAZE
			_pick_wander()
	else:
		_stamina_left = minf(stamina, _stamina_left + delta * 0.5)
		if _timer <= 0.0:
			_pick_wander()

	var pos := global_position + _dir * _speed * delta
	pos.x = clampf(pos.x, -Terrain.HALF + 150.0, Terrain.HALF - 150.0)
	pos.z = clampf(pos.z, -Terrain.HALF + 150.0, Terrain.HALF - 150.0)
	# nie wchodź do wody ani na strome / wysokie zbocza — zawróć
	if _speed > 0.01 and not Terrain.is_walkable(pos.x + _dir.x * 1.5, pos.z + _dir.z * 1.5):
		_dir = -_dir.rotated(Vector3.UP, _rng.randf_range(-0.8, 0.8))
		pos = global_position
	pos.y = Terrain.height(pos.x, pos.z)
	global_position = pos
	if _speed > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(_dir.x, _dir.z), clampf(8.0 * delta, 0.0, 1.0))
	_animate(delta)


func _pick_wander() -> void:
	_timer = _rng.randf_range(1.5, 5.0)
	if _rng.randf() < 0.45:
		_speed = 0.0  # pasie się
	else:
		_speed = walk_speed
		_dir = Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)


func _animate(delta: float) -> void:
	if not _body:
		return
	if _speed > 0.05:
		_phase += delta * (5.0 + _speed * (3.0 if hops else 2.0))
	if hops:
		var h := absf(sin(_phase)) * (0.12 + 0.05 * _speed) if _speed > 0.05 else 0.0
		_body.position.y = lerpf(_body.position.y, h, clampf(20.0 * delta, 0.0, 1.0))
		_body.rotation.x = -cos(_phase) * 0.25 if _speed > 0.05 else 0.0
	else:
		_body.rotation.z = sin(_phase) * 0.07 * clampf(_speed, 0.0, 1.0)
		_body.position.y = absf(sin(_phase * 2.0)) * 0.04 * clampf(_speed, 0.0, 1.0)
		# pasąca się owca opuszcza głowę (całe ciało lekko w przód)
		_body.rotation.x = lerpf(_body.rotation.x, 0.12 if _speed < 0.05 else 0.0, clampf(3.0 * delta, 0.0, 1.0))


## Ugryzienie przez smoka. Zwraca true, jeśli ofiara zginęła.
func take_bite(damage: float) -> bool:
	if state == State.DEAD:
		return false
	health -= damage
	if health <= 0.0:
		state = State.DEAD
		killed.emit(self)
		return true
	state = State.FLEE
	_flee_time = 4.0
	_stamina_left = stamina  # zryw paniki
	var tw := create_tween()  # „podskok” z bólu
	scale = Vector3.ONE * 1.25
	tw.tween_property(self, "scale", Vector3.ONE, 0.25)
	return false


## Zjedzenie: ofiara przesuwa się do pyska i znika w obłoku puchu.
func consume(mouth: Vector3, duration: float, fluff: Color) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", mouth, duration * 0.6)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, duration)
	tw.chain().tween_callback(func() -> void:
		DustBurst.spawn(get_parent(), global_position, clampf(body_size * 0.4, 0.15, 0.6), fluff)
		queue_free())
