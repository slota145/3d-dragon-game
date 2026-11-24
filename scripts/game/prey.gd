class_name Prey
extends Node3D
## Zwierzyna: pasie się i wędruje, ucieka przed smokiem (większego widzi z daleka),
## po ugryzieniu traci zdrowie, po śmierci zostaje zjedzona. Ruch i animacja w kodzie, bez
## szkieletu: model `Body` z częściami (Head, LegFL/FR/BL/BR, ptaki: LegL/LegR, WingL/WingR —
## patrz Wildlife) — chód, galop, kicanie, skubanie trawy, machanie skrzydłami.

signal killed(prey: Prey)
## Dzik zaatakował małego smoka.
signal attacked(prey: Prey, damage: float)

enum State { GRAZE, FLEE, DEAD, CHARGE }
## Gdzie zwierzę może chodzić: łąki i lasy / górskie zbocza (koza) / woda (kaczka).
enum Habitat { LAND, MOUNTAIN, WATER }

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
## Gatunek (klucz Wildlife.SPECIES).
@export var species: String = ""
## Jak nisko schyla głowę przy skubaniu trawy (rad).
@export var graze_pitch: float = 0.6
@export var habitat: Habitat = Habitat.LAND
## Ptak: spłoszony odlatuje (kaczka).
@export var flies: bool = false
## Szarżuje na smoka mniejszego niż ten rozmiar (dzik; 0 = nigdy).
@export var charge_below: float = 0.0
@export var charge_damage: float = 0.0

## Zwierzę z zagrody: nie oddala się od `home` dalej niż `home_radius` (0 = bez uwiązania).
var home: Vector3
var home_radius: float = 0.0
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
## Części modelu (nazwa -> węzeł), np. "Head", "LegFL", "WingL".
var _parts: Dictionary = {}
var _fly_h: float = 0.0
var _charge_cd: float = 0.0
var _look_t: float = 0.0


func _ready() -> void:
	add_to_group("prey")
	health = max_health
	_stamina_left = stamina
	_rng.randomize()
	_body = get_node_or_null("Body")
	if _body:
		for c in _body.get_children():
			_parts[String(c.name)] = c
	_look_t = _rng.randf() * 10.0
	_pick_wander()


## Wysokość, na której stoi / pływa zwierzę.
func _ground_y(x: float, z: float) -> float:
	var h := Terrain.height(x, z)
	if habitat == Habitat.WATER and h < Terrain.WATER_LEVEL:
		return Terrain.WATER_LEVEL - 0.08
	return h


## Czy wolno tu wejść (siedlisko gatunku).
func _can_go(x: float, z: float) -> bool:
	match habitat:
		Habitat.WATER:
			return Terrain.height(x, z) < Terrain.WATER_LEVEL - 0.2
		Habitat.MOUNTAIN:
			var h := Terrain.height(x, z)
			return h > Terrain.WATER_LEVEL + 0.4 and absf(Terrain.height(x + 3.0, z) - h) < 4.5 \
				and absf(Terrain.height(x, z + 3.0) - h) < 4.5
	return Terrain.is_walkable(x, z)


func is_flying() -> bool:
	return _fly_h > 0.3


func is_alive() -> bool:
	return state != State.DEAD


func center() -> Vector3:
	return global_position + Vector3.UP * radius


func _physics_process(delta: float) -> void:
	if _process_fall(delta) or state == State.DEAD:
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
	_charge_cd = maxf(0.0, _charge_cd - delta)
	if charge_below > 0.0 and dragon_size < charge_below and dist < alert and _charge_cd <= 0.0 \
			and dragon.global_position.y - global_position.y < 2.0 + dragon_size:
		state = State.CHARGE  # dzik na pisklę: szarża zamiast ucieczki
	elif dist < alert:
		state = State.FLEE
		_flee_time = 2.5

	_timer -= delta
	if state == State.CHARGE:
		_dir = to_dragon.normalized() if dist > 0.01 else _dir
		_speed = flee_speed * 1.1
		if dist < radius + dragon_size * 0.45 + 0.4:
			_charge_cd = 2.5  # uderzenie kłami, potem odskok
			state = State.FLEE
			_flee_time = 1.2
			var st: Variant = dragon.get("stats")
			if st:
				st.damage(charge_damage)
			attacked.emit(self, charge_damage)
		elif dist > alert * 1.6 or dragon_size >= charge_below:
			state = State.GRAZE
			_pick_wander()
	elif state == State.FLEE:
		_flee_time -= delta
		_stamina_left -= delta
		var away := -to_dragon.normalized() if dist < INF and dist > 0.01 else _dir
		var wiggle := sin(Time.get_ticks_msec() / 1000.0 * 3.5 + get_instance_id()) * zigzag
		_dir = away.rotated(Vector3.UP, wiggle).normalized()
		_speed = flee_speed if _stamina_left > 0.0 else walk_speed * 1.6
		if flies:
			_fly_h = minf(_fly_h + delta * 5.0, 14.0)  # zrywa się do lotu
			_dir.y = 0.0
		if _flee_time <= 0.0 and dist > alert * 1.5:
			state = State.GRAZE
			_pick_wander()
	else:
		_stamina_left = minf(stamina, _stamina_left + delta * 0.5)
		if _fly_h > 0.0:  # po locie wraca nad swoją wodę i siada
			var back := home - global_position
			back.y = 0.0
			_speed = flee_speed * 0.7
			if back.length() > 6.0:
				_dir = back.normalized()
			elif _can_go(global_position.x, global_position.z):
				_fly_h = maxf(0.0, _fly_h - delta * 4.0)
				_speed = 1.5
			if _fly_h <= 0.0:
				_pick_wander()
		elif _timer <= 0.0:
			_pick_wander()

	_move(delta)


## Ruch po terenie: granice świata, zagroda, omijanie wody i stromizn.
func _move(delta: float) -> void:
	if home_radius > 0.0:
		var off := global_position + _dir * 1.5 - home
		off.y = 0.0
		if off.length() > home_radius:  # płot — zawróć do środka zagrody
			_dir = (home - global_position).normalized().rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
			_dir.y = 0.0
	var pos := global_position + _dir * _speed * delta
	pos.x = clampf(pos.x, -Terrain.HALF + 150.0, Terrain.HALF - 150.0)
	pos.z = clampf(pos.z, -Terrain.HALF + 150.0, Terrain.HALF - 150.0)
	# nie wchodź do wody ani na strome / wysokie zbocza (kaczka: nie wychodź z wody) — zawróć
	if _speed > 0.01 and _fly_h <= 0.0 and not _can_go(pos.x + _dir.x * 1.5, pos.z + _dir.z * 1.5):
		_dir = -_dir.rotated(Vector3.UP, _rng.randf_range(-0.8, 0.8))
		pos = global_position
	pos.y = maxf(_ground_y(pos.x, pos.z), Terrain.WATER_LEVEL) + _fly_h if _fly_h > 0.0 else _ground_y(pos.x, pos.z)
	global_position = pos
	if _speed > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(_dir.x, _dir.z), clampf(8.0 * delta, 0.0, 1.0))
	if not dragon or global_position.distance_squared_to(dragon.global_position) < 160.0 * 160.0:
		_animate(delta)  # dalekich nie animujemy (i tak ich prawie nie widać)


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
	var moving := _speed > 0.05
	var w := clampf(20.0 * delta, 0.0, 1.0)
	if moving:
		_phase += delta * (5.0 + _speed * (3.0 if hops else 2.0))
	_look_t += delta
	if _parts.has("WingL"):
		_animate_bird(delta, moving, w)
	elif hops:
		var h := absf(sin(_phase)) * (0.12 + 0.05 * _speed) if moving else 0.0
		_body.position.y = lerpf(_body.position.y, h, w)
		_body.rotation.x = -cos(_phase) * 0.25 if moving else 0.0
		_legs4(cos(_phase) * 0.5, cos(_phase) * 0.5, -cos(_phase) * 0.7, -cos(_phase) * 0.7, moving, w)
	else:
		var run := _speed > walk_speed * 2.5
		var amp := (0.75 if run else 0.45) * clampf(_speed / maxf(walk_speed, 0.1), 0.3, 1.0)
		var sp := sin(_phase)
		if run:  # galop: przednie razem, tylne razem z przesunięciem
			var sb := sin(_phase + 2.2)
			_legs4(sp * amp, sin(_phase + 0.4) * amp, sb * amp, sin(_phase + 2.6) * amp, moving, w)
			_body.rotation.x = cos(_phase) * 0.06
			_body.position.y = absf(sin(_phase)) * 0.06 * body_size
		else:  # stęp: nogi po przekątnej
			_legs4(sp * amp, -sp * amp, -sp * amp, sp * amp, moving, w)
			_body.rotation.z = sin(_phase) * 0.04 * clampf(_speed, 0.0, 1.0)
			_body.rotation.x = lerpf(_body.rotation.x, 0.0, w)
			_body.position.y = absf(sin(_phase * 2.0)) * 0.03 * clampf(_speed, 0.0, 1.0)
	_animate_head(delta, moving)


## Nogi czworonoga (kąty wychylenia; w miejscu — powrót do pionu).
func _legs4(fl: float, fr: float, bl: float, br: float, moving: bool, w: float) -> void:
	var a := [fl, fr, bl, br] if moving else [0.0, 0.0, 0.0, 0.0]
	var i := 0
	for n: String in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		var leg: Node3D = _parts.get(n)
		if leg:
			leg.rotation.x = lerpf(leg.rotation.x, a[i], w)
		i += 1


## Głowa: skubie trawę na postoju (co jakiś czas podnosi się i rozgląda), w biegu uniesiona.
func _animate_head(delta: float, moving: bool) -> void:
	var head: Node3D = _parts.get("Head")
	if not head:
		return
	var pitch := 0.0
	var yaw := 0.0
	if state == State.FLEE or state == State.CHARGE:
		pitch = -0.15 if state == State.FLEE else 0.25  # dzik w szarży pochyla łeb
	elif not moving and not is_flying():
		var cyc := fmod(_look_t, 7.0)
		if cyc < 4.5:  # skubie — lekkie szarpnięcia
			pitch = graze_pitch + sin(_look_t * 9.0) * 0.06
		else:  # rozgląda się
			yaw = sin((cyc - 4.5) * 2.5) * 0.5
	else:
		pitch = sin(_phase * 2.0) * 0.06
	var k := clampf(6.0 * delta, 0.0, 1.0)
	head.rotation.x = lerpf(head.rotation.x, pitch, k)
	head.rotation.y = lerpf(head.rotation.y, yaw, k)


## Ptak: drepcze, kołysze się, dziobie; w locie (lub w panice) macha skrzydłami.
func _animate_bird(delta: float, moving: bool, w: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 97)
	var flap := 0.0
	if is_flying():
		flap = sin(t * 16.0) * 0.9
	elif state == State.FLEE:
		flap = sin(t * 22.0) * 0.6 * (1.0 if habitat != Habitat.WATER else 0.5)  # trzepot w biegu
	elif fmod(_look_t, 9.0) > 8.5:
		flap = sin(t * 18.0) * 0.4  # rozprostowanie skrzydeł
	var wl: Node3D = _parts.get("WingL")
	var wr: Node3D = _parts.get("WingR")
	wl.rotation.z = lerpf(wl.rotation.z, 0.2 + flap if is_flying() else flap, w)
	wr.rotation.z = lerpf(wr.rotation.z, -(0.2 + flap) if is_flying() else -flap, w)
	var step := sin(_phase * 1.6) * 0.6 if moving and not is_flying() else 0.0
	for n: String in ["LegL", "LegR"]:
		var leg: Node3D = _parts.get(n)
		if leg:
			leg.rotation.x = lerpf(leg.rotation.x, step if n == "LegL" else -step, w)
			leg.rotation.x = 0.9 if is_flying() else leg.rotation.x  # w locie nogi podkulone
	_body.rotation.z = sin(_phase * 1.6) * 0.1 if moving and not is_flying() else lerpf(_body.rotation.z, 0.0, w)
	if habitat == Habitat.WATER and not is_flying():  # kołysanie na wodzie
		_body.position.y = sin(t * 2.0) * 0.02
	else:
		_body.position.y = 0.0


## Martwe ciało do zjedzenia (upieczone ogniem albo zabite upadkiem z wysokości).
var roasted: bool = false
## Niesiona w szponach smoka (AI i ruch wyłączone; pozycję ustawia smok).
var carried: bool = false
var _falling: bool = false
var _fall_velocity: Vector3


## Złapana przez smoka w locie.
func pick_up() -> void:
	carried = true
	_falling = false
	_speed = 0.0


## Upuszczona: spada; upadek z wysokości zabija (truchło do zjedzenia), z niska — ogłusza.
func drop(velocity: Vector3) -> void:
	carried = false
	_falling = true
	_fall_velocity = velocity


## Spadanie po upuszczeniu. Zwraca true, gdy ofiara jest w locie (wtedy bez AI).
func _process_fall(delta: float) -> bool:
	if carried:
		_animate_carried(delta)
		return true
	if not _falling:
		return false
	_fall_velocity.y -= 18.0 * delta
	global_position += _fall_velocity * delta
	rotation.x += delta * 4.0
	var ground := _ground_y(global_position.x, global_position.z)
	if global_position.y <= ground:
		global_position.y = ground
		rotation.x = 0.0
		_falling = false
		var impact := -_fall_velocity.y
		if impact > 13.0 and state != State.DEAD:
			health = 0.0
			state = State.DEAD
			roasted = true  # truchło — smok może je zjeść
			rotation.z = PI / 2.0
			killed.emit(self)
			get_tree().create_timer(90.0).timeout.connect(func() -> void:
				if is_instance_valid(self):
					queue_free())
		elif state != State.DEAD:
			state = State.FLEE
			_flee_time = 3.0
	return true


## Szarpanie się w szponach (wierzga nogami, ptak trzepocze).
func _animate_carried(_delta: float) -> void:
	_fly_h = 0.0
	if _body and state != State.DEAD:
		var t := Time.get_ticks_msec() / 90.0 + get_instance_id()
		_body.rotation.z = sin(t) * 0.35
		var i := 0
		for n: String in ["LegFL", "LegFR", "LegBL", "LegBR", "LegL", "LegR"]:
			var leg: Node3D = _parts.get(n)
			if leg:
				leg.rotation.x = sin(t * 1.7 + i * 1.3) * 0.8
			i += 1
		for n: String in ["WingL", "WingR"]:
			var wing: Node3D = _parts.get(n)
			if wing:
				wing.rotation.z = sin(t * 2.0) * (0.9 if n == "WingL" else -0.9)


## Obrażenia od ognia. Zabita ofiara zostaje upieczona — smok może ją zjeść ugryzieniem.
func burn(damage: float) -> void:
	if state == State.DEAD:
		return
	if take_bite(damage):
		roasted = true
		for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color(0.12, 0.08, 0.05, 0.75)
			dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_overlay = dark
		var tw := create_tween()  # przewraca się
		tw.tween_property(self, "rotation:z", PI / 2.0, 0.4)
		get_tree().create_timer(90.0).timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free())


## Czy smok może to zjeść (żywe lub upieczone).
func is_edible() -> bool:
	return is_alive() or roasted


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
