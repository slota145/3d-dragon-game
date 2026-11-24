class_name Knight
extends Prey
## Rycerz na koniu bojowym (włócznia + oszczepy) albo konny kusznik. Patroluje drogę razem
## ze swoim oddziałem (Knights.Patrol — miejsce w szyku za dowódcą), a gdy zobaczy smoka:
## - pisklę na ziemi: rycerz szarżuje z włócznią (uderzenie + odrzut), kusznik strzela,
## - młodzik / smok w powietrzu: rycerz trzyma dystans i rzuca oszczepami, kusznik strzela,
## - dorosły: część rycerzy (tchórze) ucieka w panice, reszta walczy,
## - pradawny: uciekają wszyscy poza kusznikami.
## Gdy smok zniknie — wraca na drogę. Oddział pościgowy (`patrol.hunt`) zjeżdża drogą z zamku,
## a potem jedzie prosto na smoka.
## Model: koń (Body: tułów + LegFL/FR/BL/BR — animacja Prey) i jeździec (Body/Rider: ręce, nogi).

signal threw(projectile: Node3D)
signal scared(knight: Knight)

enum Mode { PATROL, ENGAGE, RETURN, HUNT }

@export var crossbow: bool = false
## Tchórz: przed dorosłym smokiem ucieka (kusznicy nigdy).
@export var coward: bool = false
@export var gallop_speed: float = 9.5
@export var lance_damage: float = 7.0
@export var javelin_damage: float = 8.0
@export var bolt_damage: float = 7.0

## Oddział patrolu (null = pościg za smokiem) i miejsce w szyku.
var patrol: RefCounted
var slot: int = 0
var mode: Mode = Mode.PATROL
## Przerażony (ucieka, ręce w górze).
var panic: bool = false

var _cd: float = 0.0
var _act_t: float = 99.0  # czas od rzutu / strzału / ciosu (animacja ręki)
var _pass_t: float = 0.0  # przejazd po ciosie włócznią
var _lost_t: float = 0.0
var _was_scared: bool = false
var _rider: Node3D
var _rider_y: float = 0.0
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D


func _ready() -> void:
	super._ready()
	hops = false
	_rider = _body.get_node_or_null("Rider") if _body else null
	if _rider:
		_rider_y = _rider.position.y
		_arm_l = _rider.get_node_or_null("ArmL")
		_arm_r = _rider.get_node_or_null("ArmR")
		_leg_l = _rider.get_node_or_null("LegL")
		_leg_r = _rider.get_node_or_null("LegR")
	_cd = _rng.randf_range(0.5, 2.0)


## Z oddziału pościgowego (nie wraca na patrol).
func is_hunter() -> bool:
	return patrol == null or patrol.hunt


func center() -> Vector3:
	return global_position + Vector3.UP * 1.6


## Zasięg, z którego rycerze widzą smoka (większego — z daleka).
func detect_range(dsize: float) -> float:
	return 50.0 + dsize * 4.0


func _physics_process(delta: float) -> void:
	if _process_fall(delta) or state == State.DEAD:
		if carried:
			panic = true
			_animate_rider(delta)
		return
	var dc := dragon as DragonController
	if not dc:
		return
	var to := dc.global_position - global_position
	var dy := to.y
	to.y = 0.0
	var dist := to.length()
	_cd = maxf(0.0, _cd - delta)
	_act_t += delta
	var dsize: float = dc.stats.size
	var sees := dc.stats.health > 0.0 and dist < detect_range(dsize) and dy < 70.0
	match mode:
		Mode.PATROL:
			if sees:
				mode = Mode.ENGAGE
				_lost_t = 0.0
			else:
				_follow_road(delta, dist)
				return
		Mode.RETURN:
			if sees:
				mode = Mode.ENGAGE
				_lost_t = 0.0
			else:
				var slot_p: Vector3 = patrol.slot_position(slot)
				var back := slot_p - global_position
				back.y = 0.0
				if back.length() < 3.0:
					mode = Mode.PATROL
					panic = false
					return
				_dir = _steer_dir(back.normalized())
				_speed = gallop_speed * 0.6
				panic = false
		Mode.HUNT:
			if sees:
				mode = Mode.ENGAGE
				_lost_t = 0.0
			elif patrol and not patrol.done and dist > 250.0:
				_follow_road(delta, dist)  # z zamku najpierw drogą
				return
			else:
				_dir = _steer_dir(to.normalized()) if dist > 0.1 else _dir
				_speed = gallop_speed * 0.8
				panic = false
	if mode == Mode.ENGAGE:
		if dist > detect_range(dsize) * 1.8 or dc.stats.health <= 0.0:
			_lost_t += delta
			if _lost_t > 5.0:
				mode = Mode.HUNT if is_hunter() else Mode.RETURN
		else:
			_lost_t = 0.0
		_fight(delta, dc, to, dist, dy, dsize)
	_move(delta)
	if _speed < 0.1 and mode == Mode.ENGAGE and not panic:  # stoi — patrzy na smoka
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(6.0 * delta, 0.0, 1.0))


## Walka: wybór taktyki wg wielkości smoka (patrz opis klasy).
func _fight(_delta: float, dc: DragonController, to: Vector3, dist: float, dy: float, dsize: float) -> void:
	var dir := to.normalized() if dist > 0.01 else _dir
	var stage := DragonStats.stage_for(dsize)
	var afraid := not crossbow and ((stage >= 2 and coward) or stage >= 3)
	if health < max_health * 0.4 and stage >= 1:
		afraid = true  # ranny — w nogi
	panic = afraid
	if afraid:
		_dir = _steer_dir(-dir.rotated(Vector3.UP, sin(Time.get_ticks_msec() / 700.0 + slot) * 0.4))
		_speed = gallop_speed
		if not _was_scared:
			_was_scared = true
			scared.emit(self)
		return
	if _pass_t > 0.0:  # przejazd po uderzeniu — dalej prosto, potem zawrót
		_pass_t -= _delta
		_speed = gallop_speed
		return
	var airborne := dc.is_flying() and dy > 4.0 + dsize * 0.5
	if not crossbow and stage == 0 and not airborne:
		# szarża z włócznią na pisklę
		_dir = _steer_dir(dir)
		_speed = gallop_speed
		if dist < 2.2 + dsize * 0.5 and _cd <= 0.0:
			_strike(dc, dir)
		return
	# dystans: kusznik dalej, rycerz bliżej (rzut oszczepem)
	var near := (22.0 if crossbow else 16.0) + dsize * 1.5
	var far := (48.0 if crossbow else 34.0) + dsize * 1.5
	var range3d := Vector2(dist, dy).length()
	if dist < near:
		_dir = _steer_dir(-dir)
		_speed = gallop_speed * 0.8
	elif dist > far:
		_dir = _steer_dir(dir)
		_speed = gallop_speed * 0.9
	else:
		_speed = 0.0
	if _cd <= 0.0 and range3d < far + 15.0:
		_shoot(dc)


## Cios włócznią w szarży: obrażenia, odrzut smoka, przejazd i zawrót.
func _strike(dc: DragonController, dir: Vector3) -> void:
	_cd = 2.8
	_act_t = 0.0
	_pass_t = 1.4
	dc.stats.damage(lance_damage)
	dc.velocity += dir * 7.0 + Vector3.UP * 2.0
	attacked.emit(self, lance_damage)


## Rzut oszczepem / strzał z kuszy (z wyprzedzeniem celu).
func _shoot(dc: DragonController) -> void:
	_cd = (2.8 if crossbow else 3.4) * _rng.randf_range(0.85, 1.2)
	_act_t = 0.0
	var speed := 46.0 if crossbow else 28.0
	var from := global_position + Vector3.UP * 2.7 + global_basis.z * 0.6
	var target := dc.body_center()
	var lead := target + dc.velocity * (from.distance_to(target) / speed) * 0.7
	var p: Arrow
	if crossbow:
		p = Arrow.create(from, lead, speed, bolt_damage, dc, 0.55, 0.035, Color(0.25, 0.16, 0.08))
	else:
		p = Arrow.create(from, lead, speed, javelin_damage, dc, 2.0, 0.04, Color(0.4, 0.26, 0.12))
	p.on_hit = func(d: float) -> void:
		if is_instance_valid(self):
			attacked.emit(self, d)
	threw.emit(p)


## Wybór kierunku omijający wodę i strome zbocza (odchylenia o coraz większy kąt).
func _steer_dir(want: Vector3) -> Vector3:
	want.y = 0.0
	if want.length() < 0.01:
		return _dir
	want = want.normalized()
	for a: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.4, -2.4]:
		var d := want.rotated(Vector3.UP, a)
		var p := global_position + d * 5.0
		if Terrain.is_walkable(p.x, p.z):
			return d
	return -want


## Jazda po drodze na swoim miejscu w szyku patrolu.
func _follow_road(delta: float, dist: float) -> void:
	var pose: Array = patrol.slot_pose(slot)
	var p: Vector3 = pose[0]
	global_position = p
	rotation.y = lerp_angle(rotation.y, pose[1], clampf(3.0 * delta, 0.0, 1.0))
	_speed = patrol.speed
	_was_scared = false
	panic = false
	if dist < 220.0:
		_animate(delta)


func take_bite(damage: float) -> bool:
	var died := super.take_bite(damage)
	if state == State.FLEE:
		state = State.GRAZE  # Prey ustawia ucieczkę — rycerz ma własne tryby
	if not died and mode != Mode.ENGAGE:
		mode = Mode.ENGAGE
	return died


func pick_up() -> void:
	super.pick_up()
	mode = Mode.HUNT if is_hunter() else Mode.RETURN


func _animate(delta: float) -> void:
	super._animate(delta)
	_animate_rider(delta)


## Jeździec: nogi w strzemionach, ręce wg akcji (włócznia w pionie / w szarży poziomo,
## zamach oszczepem, kusza przy oku, panika — ręce w górze).
func _animate_rider(delta: float) -> void:
	if not _rider:
		return
	var k := clampf(10.0 * delta, 0.0, 1.0)
	if _leg_l and _leg_r:
		_leg_l.rotation = Vector3(-0.75, 0.0, 0.5)
		_leg_r.rotation = Vector3(-0.75, 0.0, -0.5)
	var t := Time.get_ticks_msec() / 1000.0
	var r := 0.0
	var l := -0.35  # lewa trzyma wodze / tarczę
	var charging := mode == Mode.ENGAGE and not crossbow and _speed > gallop_speed * 0.9 and _pass_t <= 0.0
	if panic:
		r = PI * 0.85 + sin(t * 9.0) * 0.2
		l = PI * 0.85 + sin(t * 9.0 + 1.0) * 0.2
	elif crossbow and mode == Mode.ENGAGE:
		r = -1.5  # kusza przy ramieniu, celuje
		l = -1.3
		if _act_t < 0.25:
			r = -1.5 + 0.35 * sin(_act_t / 0.25 * PI)  # odrzut
	elif not crossbow and _act_t < 0.6 and _pass_t <= 0.0 and mode == Mode.ENGAGE:
		# rzut oszczepem: zamach w górę-tył i wyrzut do przodu
		r = lerpf(2.6, 4.5, smoothstep(0.0, 0.35, _act_t))
		_arm_r.rotation.x = r
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, l, k)
		return
	elif charging or _pass_t > 0.0:
		r = -1.45  # włócznia opuszczona do ataku
	else:
		r = sin(_phase) * 0.08
	if _arm_r.rotation.x > PI:  # po wyrzucie wróć krótszą drogą
		_arm_r.rotation.x -= TAU
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, r, k)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, l, k)
	_rider.position.y = _rider_y + absf(sin(_phase)) * 0.06 * clampf(_speed / gallop_speed, 0.2, 1.0)
