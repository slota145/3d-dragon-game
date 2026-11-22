class_name DragonController
extends CharacterBody3D
## Sterowanie smokiem: chód, skok, start i lot. Jeden przycisk „Skrzydła” (akcja `flap`):
##
## NA ZIEMI
##   tapnięcie        – skok (z wychyloną gałką: skok w jej kierunku)
##   przytrzymanie    – odbicie od ziemi i start
## W POWIETRZU
##   tapnięcie        – machnięcie: w górę (z gałką do przodu: w przód i w górę)
##   trzymanie        – ciągłe machanie: zawis w miejscu (z gałką do przodu: lot poziomy)
##   bez przycisku    – szybowanie: gałka do przodu = nurkowanie (im stromiej, tym szybciej),
##                      do tyłu = wyrównanie i zamiana rozpędu na wysokość, w bok = skręt
## Machnięcia mają czas trwania (nie da się ich „spamować”); naciśnięcie w trakcie jest
## zapamiętywane i wykonywane zaraz po bieżącym machnięciu.
##
## Przycisk „Zryw” (akcja `dash`): na ziemi trzymanie = bieg, w powietrzu = potężne machnięcie
## mocno zwiększające prędkość w kierunku dzioba (z czasem odnowienia).

signal took_off
signal launched  ## wybicie przy starcie (pył)
signal landed(impact: float)
signal flapped
signal dashed

enum State { GROUND, AIR }

@export_group("Ziemia")
@export var walk_speed: float = 2.6
@export var acceleration: float = 3.0
@export var deceleration: float = 4.5
@export var turn_speed: float = 1.8
## Prędkość (m/s), przy której animacja Walk zgadza się z ruchem stóp (speed_scale = 1).
@export var walk_anim_speed: float = 1.2

@export_group("Skok i start")
@export var jump_speed: float = 7.0
@export var jump_forward: float = 7.0
## Ile trzeba przytrzymać przycisk na ziemi, żeby wystartować (s).
@export var takeoff_hold_time: float = 0.35
@export var takeoff_speed: float = 15.0

@export_group("Machanie i zawis")
@export var gravity: float = 12.0
@export var flap_lift: float = 11.0
## Minimalny odstęp między machnięciami = czas jednego pełnego ruchu skrzydeł (s).
@export var flap_cooldown: float = 0.7
@export var flap_thrust: float = 8.0
@export var max_climb_speed: float = 13.0
## Rytm machania przy przytrzymanym przycisku (s).
@export var flap_interval: float = 0.6
@export var hover_forward_speed: float = 15.0
## Maksymalna prędkość pozioma, którą da się „wymachać” (nurkowanie może być szybsze).
@export var max_flap_speed: float = 22.0
## Jak długo po machnięciu smok leci „machając” (poziomo), zanim gałka przód zacznie nurkowanie.
@export var flap_window: float = 0.7
@export var hover_accel: float = 6.0
@export var hover_brake: float = 5.0

@export_group("Szybowanie i nurkowanie")
## Prędkość, przy której nośność prawie równoważy grawitację (m/s).
@export var glide_speed: float = 16.0
@export var lift_factor: float = 0.92
## Jak szybko kierunek lotu dopasowuje się do kierunku dzioba.
@export var align_rate: float = 2.4
## Kąt między kierunkiem lotu a dziobem, powyżej którego skrzydła tracą nośność (przeciągnięcie).
@export var stall_angle_deg: float = 70.0
## Opór powietrza ~ v² (ogranicza prędkość nurkowania do ok. 55 m/s).
@export var drag: float = 0.004
## Dodatkowa utrata prędkości przy zadartym nosie (wznoszenie z rozpędu „zjada” energię).
@export var climb_drag: float = 0.7
@export var air_turn_rate: float = 1.3
@export var max_dive_deg: float = 75.0
@export var max_climb_deg: float = 40.0
@export var glide_pitch_deg: float = -6.0
@export var pitch_rate: float = 2.2
@export var max_bank_deg: float = 35.0

@export_group("Zryw i bieg")
@export var sprint_speed: float = 7.5
@export var dash_impulse: float = 22.0
@export var max_dash_speed: float = 75.0
@export var dash_cooldown: float = 1.4

@export var joystick: TouchJoystick
@export var camera: Node3D

var state: State = State.GROUND
## Pochylenie w locie (rad): > 0 nos w górę, < 0 nos w dół.
var pitch: float = 0.0

var _bank: float = 0.0
var _charge: float = -1.0
var _air_time: float = 0.0
var _flap_timer: float = 0.0
var _since_flap: float = 99.0
var _flap_cd: float = 0.0
var _flap_buffered: bool = false
var _dash_cd: float = 0.0
var _since_dash: float = 99.0
var _takeoff_time: float = 99.0
## 0..1: siła efektów prędkości (linie pędu, FOV, drganie) — czyta je świat/kamera.
var speed_effect: float = 0.0
var _dash_boost: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _anim: AnimationPlayer = find_child("AnimationPlayer", true, false)


func _ready() -> void:
	if _anim:
		_anim.play("Idle")


func is_flying() -> bool:
	return state == State.AIR


func _physics_process(delta: float) -> void:
	var stick := _read_stick()
	var pressed := Input.is_action_just_pressed("flap")
	var held := Input.is_action_pressed("flap")
	_flap_cd = maxf(0.0, _flap_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_since_dash += delta
	_takeoff_time += delta
	_dash_boost = maxf(0.0, _dash_boost - delta * 1.2)
	if state == State.GROUND:
		_process_ground(delta, stick, pressed, held)
	else:
		_process_air(delta, stick, pressed, held)
	_update_visual(delta, stick)
	_update_animation(held)
	var speed := velocity.length()
	speed_effect = maxf(clampf((speed - 22.0) / 38.0, 0.0, 1.0), _dash_boost)


func _read_stick() -> Vector2:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if joystick and joystick.output.length() > input.length():
		input = joystick.output
	return input


func _facing_flat() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))  # model patrzy w +Z


func _facing_3d() -> Vector3:
	return Vector3(sin(rotation.y) * cos(pitch), sin(pitch), cos(rotation.y) * cos(pitch))


func _camera_wish(stick: Vector2) -> Vector3:
	var b := camera.global_basis if camera else global_basis
	var forward := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	return right * stick.x - forward * stick.y


# --- Ziemia ------------------------------------------------------------------

func _process_ground(delta: float, stick: Vector2, pressed: bool, held: bool) -> void:
	var wish := _camera_wish(stick)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length() > 0.05:
		rotation.y = rotate_toward(rotation.y, atan2(wish.x, wish.z), turn_speed * delta)
		var facing := _facing_flat()
		var align := clampf(facing.dot(wish.normalized()), 0.0, 1.0)
		var top := sprint_speed if Input.is_action_pressed("dash") else walk_speed
		var accel := acceleration * (2.5 if top > walk_speed else 1.0)
		flat = flat.move_toward(facing * top * minf(1.0, wish.length()) * align, accel * delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z

	if pressed:
		_charge = 0.0
		if _anim:  # przysiad przed skokiem/startem (początek animacji TakeOff)
			_anim.play("TakeOff", 0.15)
			_anim.speed_scale = 1.0
	if _charge >= 0.0:
		if held:
			_charge += delta
			if _charge >= takeoff_hold_time:
				_take_off(stick)
		else:
			_jump(wish)

	if state == State.GROUND:
		velocity.y -= gravity * delta
	move_and_slide()


func _jump(wish: Vector3) -> void:
	_charge = -1.0
	velocity.y = jump_speed
	if wish.length() > 0.2:
		rotation.y = atan2(wish.x, wish.z)
		var dir := wish.normalized() * minf(1.0, wish.length())
		velocity.x += dir.x * jump_forward
		velocity.z += dir.z * jump_forward
	_enter_air()


func _take_off(stick: Vector2) -> void:
	_charge = -1.0
	velocity.y = takeoff_speed
	velocity += _facing_flat() * maxf(0.0, -stick.y) * 5.0
	_enter_air()
	_takeoff_time = 0.0  # animacja TakeOff gra dalej: wybicie z łap + potężne machnięcie
	_flap_cd = flap_cooldown
	launched.emit()


func _enter_air() -> void:
	state = State.AIR
	_air_time = 0.0
	_flap_timer = flap_interval
	pitch = 0.0
	took_off.emit()


# --- Powietrze ---------------------------------------------------------------

func _process_air(delta: float, stick: Vector2, pressed: bool, held: bool) -> void:
	_air_time += delta
	_since_flap += delta
	var fwd := -stick.y  # > 0 gałka do przodu, < 0 do tyłu
	rotation.y -= stick.x * air_turn_rate * delta

	var target_pitch: float
	if held:
		target_pitch = deg_to_rad(2.0) if fwd > 0.2 else deg_to_rad(10.0)
	elif _since_flap < flap_window:
		target_pitch = deg_to_rad(4.0)  # tuż po machnięciu: lot poziomy, bez nurkowania
	elif fwd > 0.05:
		target_pitch = -fwd * deg_to_rad(max_dive_deg)
	elif fwd < -0.05:
		target_pitch = -fwd * deg_to_rad(max_climb_deg)
	else:
		target_pitch = deg_to_rad(glide_pitch_deg)
	pitch = move_toward(pitch, target_pitch, pitch_rate * delta)

	if pressed:
		if _flap_cd <= 0.0:
			_flap(fwd)
		else:
			_flap_buffered = true  # wykona się po bieżącym machnięciu
	elif _flap_buffered and _flap_cd <= 0.0:
		_flap_buffered = false
		_flap(fwd)
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_dash()
	if held:
		_flap_timer -= delta
		if _flap_timer <= 0.0:
			_flap_timer = flap_interval  # rytm machania w zawisie (animacja Fly w pętli)
		_hover(delta, fwd)
	else:
		_glide(delta)

	move_and_slide()
	if _air_time > 0.25 and is_on_floor() and velocity.y <= 0.5:
		_land()


func _dash() -> void:
	_dash_cd = dash_cooldown
	_since_dash = 0.0
	_dash_boost = 1.0
	var boosted := velocity + _facing_3d() * dash_impulse
	velocity = boosted.limit_length(maxf(max_dash_speed, velocity.length()))
	if _anim:
		_anim.play("Fly", 0.08)
		_anim.seek(0.05, true)
		_anim.speed_scale = 2.6
	dashed.emit()


func _flap(fwd: float) -> void:
	_since_flap = 0.0
	_flap_cd = flap_cooldown
	flapped.emit()
	_flap_timer = flap_interval
	velocity.y = clampf(maxf(velocity.y, 0.0) + flap_lift, 0.0, max_climb_speed)
	if fwd > 0.1:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var boosted := flat + _facing_flat() * flap_thrust * fwd
		boosted = boosted.limit_length(maxf(max_flap_speed, flat.length()))
		velocity.x = boosted.x
		velocity.z = boosted.z
	_start_flap_anim()


func _hover(delta: float, fwd: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if fwd > 0.1:
		flat = flat.move_toward(_facing_flat() * hover_forward_speed * fwd, hover_accel * delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, hover_brake * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	# machanie równoważy grawitację: spadanie szybko wyhamowane, wznoszenie po machnięciu wygasa łagodnie
	velocity.y = move_toward(velocity.y, 0.0, (14.0 if velocity.y < 0.0 else 7.0) * delta)


func _glide(delta: float) -> void:
	var facing := _facing_3d()
	var speed := velocity.length()
	var airspeed := 0.0  # prędkość wzdłuż dzioba – tylko ona daje nośność
	if speed > 0.5:
		var dir := velocity / speed
		var cos_a := dir.dot(facing)
		var stall_cos := cos(deg_to_rad(stall_angle_deg))
		var grip := clampf((cos_a - stall_cos) / (1.0 - stall_cos), 0.0, 1.0)  # 0 = przeciągnięcie
		var t := clampf(align_rate * grip * clampf(speed / glide_speed, 0.0, 1.5) * delta, 0.0, 1.0)
		velocity = dir.slerp(facing, t).normalized() * speed
		airspeed = maxf(0.0, velocity.dot(facing))
	var lift := gravity * lift_factor * clampf(pow(airspeed / glide_speed, 2.0), 0.0, 1.0) * cos(pitch)
	velocity.y += (lift - gravity) * delta
	var bleed := drag * speed + climb_drag * maxf(0.0, sin(pitch))
	velocity -= velocity * clampf(bleed * delta, 0.0, 0.5)


func _land() -> void:
	var impact := maxf(-velocity.y, Vector2(velocity.x, velocity.z).length() * 0.5)
	state = State.GROUND
	_flap_buffered = false
	pitch = 0.0
	velocity.y = 0.0
	var flat := Vector3(velocity.x, 0.0, velocity.z).limit_length(walk_speed * 1.5)
	velocity.x = flat.x
	velocity.z = flat.z
	landed.emit(impact)


# --- Wygląd ------------------------------------------------------------------

func _update_visual(delta: float, stick: Vector2) -> void:
	var target_bank := stick.x * deg_to_rad(max_bank_deg) if state == State.AIR else 0.0
	_bank = lerpf(_bank, target_bank, clampf(4.0 * delta, 0.0, 1.0))
	var vis_pitch := pitch if state == State.AIR else 0.0
	_visual.rotation.x = lerp_angle(_visual.rotation.x, -vis_pitch, clampf(8.0 * delta, 0.0, 1.0))
	_visual.rotation.z = _bank


func _start_flap_anim() -> void:
	if _anim:
		_anim.play("Fly", 0.1)
		_anim.seek(0.05, true)
		# jedno machnięcie = jeden pełny cykl animacji (1.5 s) w czasie flap_cooldown
		_anim.speed_scale = 1.5 / flap_cooldown


func _play(anim_name: StringName, blend: float, speed_scale: float) -> void:
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, blend)
	_anim.speed_scale = speed_scale


func _update_animation(held: bool) -> void:
	if not _anim:
		return
	if state == State.GROUND:
		var speed := Vector2(velocity.x, velocity.z).length()
		if _charge >= 0.0:
			return  # przysiad (TakeOff) gra od naciśnięcia
		elif speed > 0.12:
			_play(&"Walk", 0.35, clampf(speed / walk_anim_speed, 0.4, 3.2))
		else:
			_play(&"Idle", 0.5, 1.0)
		return
	if _takeoff_time < 0.85:
		return  # dokończ wybicie i potężne machnięcie (TakeOff)
	if _since_dash < 0.5:
		return  # mocne machnięcie zrywu
	if _since_flap < flap_cooldown:
		return  # machnięcie trwa do końca — bez przerywania
	if held:
		_play(&"Fly", 0.2, 1.3)
	elif pitch < deg_to_rad(-30.0):
		_play(&"Dive", 0.4, 1.0)
	else:
		_play(&"Glide", 0.4, 1.0)
