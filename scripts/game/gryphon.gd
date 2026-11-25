class_name Gryphon
extends Prey
## Dziki gryf: siedzi w gnieździe na szczycie, krąży nad nim, a gdy smok wleci na jego
## terytorium — atakuje: szarża szponami, odskok, kolejna szarża. Ranny ucieka. Zabity
## (ogniem, ugryzieniem) spada — truchło można zjeść; duży smok może go złapać w locie
## i zrzucić. Ruch w powietrzu i animacja skrzydeł w kodzie (części modelu jak u Prey).

enum Mode { PERCH, PATROL, ATTACK, RETREAT, FLEE }

## Promień terytorium wokół gniazda (m).
@export var territory: float = 190.0
@export var attack_damage: float = 8.0
@export var attack_speed: float = 27.0
@export var patrol_speed: float = 13.0
## Ranny ucieka (dowódca jeźdźców walczy do końca).
@export var can_flee: bool = true

var nest: Vector3
var mode: Mode = Mode.PERCH
var vel: Vector3 = Vector3.ZERO
var _mode_t: float = 0.0
var _mode_len: float = 10.0
var _orbit: float = 0.0
var _flap: float = 0.0
var _perch_spot: Vector3


func _ready() -> void:
	super._ready()
	_perch_spot = nest + Vector3(_rng.randf_range(-1.0, 1.0), 0.3, _rng.randf_range(-1.0, 1.0))
	_orbit = _rng.randf() * TAU
	_set_mode(Mode.PERCH if _rng.randf() < 0.5 else Mode.PATROL)
	if mode == Mode.PERCH:
		global_position = _perch_spot


func is_flying() -> bool:
	return mode != Mode.PERCH and state != State.DEAD


func center() -> Vector3:
	return global_position + Vector3.UP * 1.9


func _set_mode(m: Mode) -> void:
	mode = m
	_mode_t = 0.0
	_mode_len = _rng.randf_range(8.0, 18.0) if m == Mode.PERCH else _rng.randf_range(18.0, 35.0)


func _physics_process(delta: float) -> void:
	if _process_fall(delta) or state == State.DEAD:
		return
	_mode_t += delta
	var dc := dragon as DragonController
	var near := dc != null and dc.stats.health > 0.0 and dc.global_position.distance_to(nest) < territory
	if can_flee and health < max_health * 0.35 and mode != Mode.FLEE:
		_set_mode(Mode.FLEE)
	match mode:
		Mode.PERCH:
			vel = Vector3.ZERO
			global_position = global_position.lerp(_perch_spot, clampf(delta * 3.0, 0.0, 1.0))
			if near:
				_take_off(Mode.ATTACK)
			elif _mode_t > _mode_len:
				_take_off(Mode.PATROL)
		Mode.PATROL:
			_orbit += delta * patrol_speed / 60.0
			var target := nest + Vector3(cos(_orbit) * 60.0, 32.0 + sin(_orbit * 2.3) * 8.0, sin(_orbit) * 60.0)
			_steer(target, patrol_speed, delta, 1.5)
			if near:
				mode = Mode.ATTACK
				_mode_t = 0.0
			elif _mode_t > _mode_len:
				_steer_home(delta)
		Mode.ATTACK:
			if not dc or (not near and dc.global_position.distance_to(nest) > territory * 1.3):
				_set_mode(Mode.PATROL)
			else:
				var tgt := dc.body_center()
				_steer(tgt, attack_speed, delta, 3.0)
				if global_position.distance_to(tgt) < 2.0 + dc.stats.size * 0.45:
					_strike(dc)
		Mode.RETREAT:
			var away := (global_position - dc.global_position) if dc else Vector3.FORWARD
			away.y = 0.0
			_steer(global_position + away.normalized() * 30.0 + Vector3.UP * 14.0, attack_speed * 0.8, delta, 2.5)
			if _mode_t > 2.4:
				mode = Mode.ATTACK if near else Mode.PATROL
				_mode_t = 0.0
		Mode.FLEE:
			var away2 := (global_position - dc.global_position) if dc else Vector3.FORWARD
			away2.y = 0.0
			_steer(global_position + away2.normalized() * 40.0 + Vector3.UP * 8.0, attack_speed, delta, 2.0)
			health = minf(max_health, health + delta * 0.15)  # liże rany
			if _mode_t > 9.0 and health > max_health * 0.5:
				_set_mode(Mode.PATROL)
	_animate(delta)


func _take_off(m: Mode) -> void:
	vel = Vector3.UP * 8.0
	mode = m
	_mode_t = 0.0
	_mode_len = _rng.randf_range(18.0, 35.0)


## Powrót do gniazda: nadlatuje i siada.
func _steer_home(delta: float) -> void:
	var to := _perch_spot - global_position
	if to.length() < 3.0:
		_set_mode(Mode.PERCH)
		return
	_steer(_perch_spot + Vector3.UP * clampf(to.length() * 0.3, 0.0, 10.0), patrol_speed, delta, 2.0)


func _steer(target: Vector3, speed: float, delta: float, turn: float) -> void:
	var want := (target - global_position).normalized() * speed
	vel = vel.lerp(want, clampf(turn * delta, 0.0, 1.0))
	var pos := global_position + vel * delta
	var ground := maxf(Terrain.height(pos.x, pos.z), Terrain.WATER_LEVEL) + 2.5
	if pos.y < ground and mode != Mode.PERCH:
		pos.y = ground
		vel.y = maxf(vel.y, 2.0)
	global_position = pos
	if vel.length() > 1.0:  # przód w stronę lotu, lekko pochylony
		rotation.y = lerp_angle(rotation.y, atan2(vel.x, vel.z), clampf(6.0 * delta, 0.0, 1.0))
		rotation.x = lerpf(rotation.x, clampf(-vel.y / maxf(vel.length(), 0.1), -0.6, 0.6) * 0.7, clampf(4.0 * delta, 0.0, 1.0))


## Uderzenie szponami, potem odskok.
func _strike(dc: DragonController) -> void:
	dc.stats.damage(attack_damage)
	dc.velocity += vel.normalized() * 6.0
	attacked.emit(self, attack_damage)
	mode = Mode.RETREAT
	_mode_t = 0.0


## Ugryzienie / ogień. Zabity w powietrzu spada (truchło do zjedzenia).
func take_bite(damage: float) -> bool:
	var died := super.take_bite(damage)
	if state == State.FLEE:
		state = State.GRAZE  # Prey ustawia ucieczkę — gryf ma własne tryby
	if died:
		roasted = true
		if mode != Mode.PERCH:
			drop(vel * 0.5)
		rotation.x = 0.0
	return died


func pick_up() -> void:
	super.pick_up()
	mode = Mode.PATROL


func drop(velocity: Vector3) -> void:
	super.drop(velocity)
	vel = Vector3.ZERO


func _animate(delta: float) -> void:
	if not _body:
		return
	var t := Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 13)
	var flying := is_flying()
	var wl: Node3D = _parts.get("WingL")
	var wr: Node3D = _parts.get("WingR")
	var k := clampf(8.0 * delta, 0.0, 1.0)
	if flying:
		var climbing := vel.y > 1.0 or mode == Mode.ATTACK or mode == Mode.FLEE
		var rate := 9.0 if climbing else 4.0
		_flap += delta * rate
		var amp := 0.75 if climbing else (0.25 if fmod(t, 5.0) < 3.0 else 0.0)  # szybowanie
		var a := sin(_flap) * amp + 0.05
		wl.rotation = Vector3(0.0, 0.0, a)
		wr.rotation = Vector3(0.0, 0.0, -a)
		_body.position.y = -sin(_flap) * amp * 0.15
	else:  # skrzydła złożone wzdłuż boków
		wl.rotation = wl.rotation.lerp(Vector3(0.0, 1.3, 0.3), k)
		wr.rotation = wr.rotation.lerp(Vector3(0.0, -1.3, -0.3), k)
		_body.position.y = 0.0
	for n: String in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		var leg: Node3D = _parts.get(n)
		if leg:
			var want := 0.0
			if flying:
				want = -0.9 if (mode == Mode.ATTACK and n.begins_with("LegF")) else 1.0  # szpony naprzód do ataku
			leg.rotation.x = lerpf(leg.rotation.x, want, k)
	var head: Node3D = _parts.get("Head")
	if head:
		var look := 0.0 if flying else sin(t * 0.7) * 0.6
		head.rotation.y = lerpf(head.rotation.y, look, k * 0.5)
		head.rotation.x = lerpf(head.rotation.x, 0.25 if mode == Mode.ATTACK else 0.0, k)
