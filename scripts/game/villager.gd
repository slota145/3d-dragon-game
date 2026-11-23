class_name Villager
extends Prey
## Człowiek (wieśniak / pasterz / myśliwy). Reakcja zależy od wielkości smoka:
## - pisklę (< 4 m): odważny — podchodzi i dźga widłami (obrażenia), przegania smoka,
## - młodzik (4–9 m): ostrożny — cofa się, z bliska ucieka,
## - dorosły (≥ 9 m): panika — ucieka z daleka, ręce w górze.
## Smok może go ugryźć i zjeść (Prey). Chodzi po swojej wiosce (`home`, `home_radius`).
## Model: części z people.glb (Body, LegL/R, ArmL/R) — chód i dźganie w kodzie.

signal poked_dragon(villager: Villager, damage: float)
signal scared(villager: Villager)

enum Mood { CALM, BOLD, WARY, PANIC }

@export var poke_damage: float = 5.0
@export var poke_cooldown: float = 1.3
@export var run_speed: float = 4.6
## Poniżej działa tylko, gdy smok jest bliżej (oszczędność na telefonie).
@export var active_range: float = 260.0

var mood: int = Mood.CALM
var _poke_cd: float = 0.0
var _poke_t: float = 99.0
var _was_scared: bool = false
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []


func _ready() -> void:
	super._ready()
	hops = false
	var body := get_node_or_null("Body")
	if body:
		for c in body.get_children():
			var n := String(c.name)
			if n.ends_with("LegL") or n.ends_with("LegR"):
				_legs.append(c)
			elif n.ends_with("ArmL") or n.ends_with("ArmR"):
				_arms.append(c)


func _physics_process(delta: float) -> void:
	var dc := dragon as DragonController
	if state == State.DEAD or not dc:
		return
	var to_dragon := dragon.global_position - global_position
	to_dragon.y = 0.0
	var dist := to_dragon.length()
	if dist > active_range:
		return
	var dsize: float = dc.stats.size
	_poke_cd = maxf(0.0, _poke_cd - delta)
	_poke_t += delta
	_timer -= delta
	var flying: bool = dc.is_flying() and dc.global_position.y - global_position.y > 6.0
	mood = Mood.CALM
	if dsize < DragonStats.STAGE_MIN_SIZE[1]:
		if dist < 16.0 and not flying:
			mood = Mood.BOLD
	elif dsize < DragonStats.STAGE_MIN_SIZE[2]:
		if dist < 28.0:
			mood = Mood.WARY
	elif dist < 45.0 + dsize * 2.0:
		mood = Mood.PANIC
	if health < max_health and dsize >= DragonStats.STAGE_MIN_SIZE[1]:
		mood = Mood.PANIC  # ranny przez większego smoka — w nogi

	match mood:
		Mood.BOLD:
			_dir = to_dragon.normalized()
			var reach := 1.3 + dsize * 0.5
			if dist > reach:
				_speed = run_speed * 0.8
			else:
				_speed = 0.0
				rotation.y = atan2(_dir.x, _dir.z)
				if _poke_cd <= 0.0:
					_poke()
		Mood.WARY:
			_dir = -to_dragon.normalized()
			_speed = run_speed if dist < 12.0 else walk_speed * 2.0
			_mark_scared()
		Mood.PANIC:
			var wiggle := sin(Time.get_ticks_msec() / 1000.0 * 2.0 + get_instance_id()) * 0.4
			_dir = (-to_dragon.normalized()).rotated(Vector3.UP, wiggle)
			_speed = run_speed
			_mark_scared()
		_:
			_was_scared = false
			if _timer <= 0.0:
				_pick_wander()
	_move(delta)
	if mood == Mood.WARY:  # cofa się, ale patrzy na smoka
		rotation.y = lerp_angle(rotation.y, atan2(to_dragon.x, to_dragon.z), clampf(6.0 * delta, 0.0, 1.0))


func _poke() -> void:
	_poke_cd = poke_cooldown
	_poke_t = 0.0
	var dmg := poke_damage
	(dragon as DragonController).stats.damage(dmg)
	poked_dragon.emit(self, dmg)


func _mark_scared() -> void:
	if not _was_scared:
		_was_scared = true
		scared.emit(self)


func _animate(delta: float) -> void:
	if _speed > 0.05:
		_phase += delta * (4.0 + _speed * 2.2)
	var swing := sin(_phase) * clampf(_speed / run_speed, 0.25, 1.0) * 0.8 if _speed > 0.05 else 0.0
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i == 0 else -1.0)
	for i in _arms.size():
		var a := -swing * 0.7 * (1.0 if i == 0 else -1.0)
		if mood == Mood.PANIC:
			a = PI * 0.85 + sin(_phase * 2.0 + i) * 0.2  # ręce w górze
		elif i == 1 and _poke_t < 0.35:
			a = -1.3 * sin(_poke_t / 0.35 * PI)  # pchnięcie widłami do przodu
		elif mood == Mood.BOLD and i == 1:
			a = -0.5  # widły nastawione
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, a, clampf(14.0 * delta, 0.0, 1.0))
	if _body:
		_body.position.y = absf(sin(_phase)) * 0.05 * clampf(_speed, 0.0, 1.0)
