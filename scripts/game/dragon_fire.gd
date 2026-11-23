class_name DragonFire
extends Node
## Ogień smoka (przycisk Ogień, akcja `fire`), odblokowany od stadium Młodzika:
## - Młodzik (4–9 m): kula ognia — tapnięcie, czas odnowienia,
## - Dorosły (≥ 9 m): strumień ognia — trzymanie (do `stream_max` s, potem chwila odpoczynku).
## Ogień rani zwierzęta i ludzi (upieczone można zjeść) i podpala budynki (`flammable`).
## Kierunek: pysk smoka (w locie z pochyleniem — można ostrzeliwać z góry).

signal fire_hit(at: Vector3, radius: float, damage: float)
signal breathed  ## kula / początek strumienia (dźwięk, efekty)

@export var fireball_cooldown: float = 2.2
@export var fireball_speed: float = 38.0
@export var fireball_damage: float = 3.0
@export var stream_max: float = 3.5
@export var stream_cooldown: float = 1.6
@export var stream_dps: float = 6.0

var dragon: DragonController
## 0..1 — gotowość ognia (pierścień na przycisku).
var readiness: float = 1.0
var streaming: bool = false

var _cd: float = 0.0
var _cd_total: float = 1.0
var _stream_t: float = 0.0
var _tick: float = 0.0
var _flames: CPUParticles3D


func _ready() -> void:
	_flames = FireFx.flame_stream()
	add_child(_flames)


func _physics_process(delta: float) -> void:
	if not dragon:
		return
	var st := dragon.stats
	_cd = maxf(0.0, _cd - delta)
	readiness = 1.0 - _cd / maxf(_cd_total, 0.01)
	var can := st.can_fire() and st.health > 0.0
	var adult := st.size >= DragonStats.STAGE_MIN_SIZE[DragonStats.Stage.ADULT]
	if can and not adult and Input.is_action_just_pressed("fire") and _cd <= 0.0:
		_shoot_fireball()
	var want_stream := can and adult and Input.is_action_pressed("fire") and _cd <= 0.0
	if want_stream:
		if not streaming:
			breathed.emit()
		streaming = true
		_stream_t += delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.15
			_stream_damage(0.15)
		if _stream_t >= stream_max:
			_stop_stream(stream_cooldown)
	elif streaming:
		_stop_stream(stream_cooldown * clampf(_stream_t / stream_max, 0.3, 1.0))
	_flames.emitting = streaming
	if streaming:
		var k := st.size / 12.0
		_flames.global_position = dragon.mouth_position()
		_flames.global_basis = Basis.looking_at(-dragon.fire_direction(), Vector3.UP)
		_flames.scale_amount_min = 1.2 * k
		_flames.scale_amount_max = 2.6 * k
		_flames.initial_velocity_min = 20.0 * sqrt(k) + 6.0
		_flames.initial_velocity_max = 28.0 * sqrt(k) + 8.0
	dragon.jaw_open = lerpf(dragon.jaw_open, 1.0 if (streaming or _cd > _cd_total - 0.35) else 0.0,
		clampf(12.0 * delta, 0.0, 1.0))


func _stop_stream(cooldown: float) -> void:
	streaming = false
	_stream_t = 0.0
	_cd = cooldown
	_cd_total = cooldown


func _shoot_fireball() -> void:
	_cd = fireball_cooldown
	_cd_total = fireball_cooldown
	var size := dragon.stats.size
	var ball := Fireball.new()
	ball.size = clampf(size / 5.0, 0.8, 1.8)
	ball.radius = 3.0 + size * 0.35
	ball.velocity = dragon.fire_direction() * fireball_speed * clampf(sqrt(size / 5.0), 0.9, 1.4) \
		+ dragon.velocity * 0.5
	dragon.get_parent().add_child(ball)
	ball.global_position = dragon.mouth_position()
	ball.exploded.connect(func(at: Vector3, r: float) -> void:
		fire_hit.emit(at, r, fireball_damage * (1.0 + size / 8.0)))
	breathed.emit()


## Strumień: kilka „kul” obrażeń wzdłuż płomienia (stożek przed pyskiem).
func _stream_damage(dt: float) -> void:
	var size := dragon.stats.size
	var from := dragon.mouth_position()
	var dir := dragon.fire_direction()
	var reach := 8.0 + size * 0.9
	for i in 4:
		var d := reach * (0.3 + 0.7 * float(i) / 3.0)
		var at := from + dir * d
		var ground := Terrain.height(at.x, at.z)
		if at.y < ground:  # płomień ślizga się po ziemi
			at.y = ground + 0.5
		fire_hit.emit(at, 1.5 + d * 0.18, stream_dps * dt * (1.0 + size / 12.0))
