class_name FollowCamera
extends Node3D
## Kamera trzecioosobowa: podąża za celem, obrót prawą gałką pada, Q/E, przeciąganiem myszy
## lub palca po ekranie. Gdy gracz nie obraca kamerą, powoli ustawia się za smokiem.

@export var target: Node3D
@export var height: float = 3.0
@export var distance: float = 17.0
@export var pitch_deg: float = -16.0
@export var follow_speed: float = 6.0
@export var stick_speed: float = 2.2
@export var drag_sensitivity: float = 0.006
@export var auto_align_delay: float = 2.0
@export var auto_align_speed: float = 1.2
## Na ziemi kierunek gałki liczy się względem kamery — auto-ustawianie kamery za smokiem
## tworzy wtedy pętlę (kamera kręci się przy lekkim wychyleniu), więc domyślnie tylko w locie.
@export var align_on_ground: bool = false
## Kamera oddala się wolniej niż rośnie smok (wykładnik < 1), żeby wzrost był widoczny.
@export var zoom_exponent: float = 0.6
@export_group("Lot")
@export var flight_distance: float = 26.0
@export var flight_height: float = 4.5
@export var flight_follow_speed: float = 9.0
@export var flight_align_delay: float = 0.6
@export var flight_align_speed: float = 2.2

@export_group("Efekty prędkości")
@export var base_fov: float = 55.0
@export var fov_boost: float = 22.0
@export var shake_amount: float = 0.35

## 0..1 — ustawiane co klatkę przez świat (z DragonController.speed_effect).
var effect: float = 0.0
## Skala smoka (rozmiar / rozmiar modelu) — odległość i wysokość kamery rosną razem ze smokiem.
var size_k: float = 1.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _cam: Camera3D = $SpringArm3D/Camera3D

var _yaw: float = PI
var _pitch: float = 0.0
var _idle_time: float = 0.0


func _ready() -> void:
	top_level = true
	# Kamera porusza się co klatkę obrazu (_process), a nie co krok fizyki — bez interpolacji.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pitch = deg_to_rad(pitch_deg)
	_arm.spring_length = distance
	if target is CollisionObject3D:
		_arm.add_excluded_object(target.get_rid())
	if target:
		global_position = target.global_position + Vector3.UP * height
		_yaw = target.global_rotation.y + PI


func _unhandled_input(event: InputEvent) -> void:
	var rel := Vector2.ZERO
	if event is InputEventScreenDrag:
		rel = event.relative
	elif event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		rel = event.relative
	if rel != Vector2.ZERO:
		_yaw -= rel.x * drag_sensitivity
		_pitch = clampf(_pitch - rel.y * drag_sensitivity, deg_to_rad(-60), deg_to_rad(10))
		_idle_time = 0.0


func _process(delta: float) -> void:
	if not target:
		return
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if look != Vector2.ZERO:
		_yaw -= look.x * stick_speed * delta
		_pitch = clampf(_pitch - look.y * stick_speed * 0.6 * delta, deg_to_rad(-60), deg_to_rad(10))
		_idle_time = 0.0
	else:
		_idle_time += delta
	var flying: bool = target.has_method("is_flying") and target.is_flying()
	var zoom := clampf(pow(size_k, zoom_exponent), 0.18, 1.8)
	var flight_zoom := maxf(zoom, 0.35)
	_arm.spring_length = lerpf(_arm.spring_length, flight_distance * flight_zoom if flying else distance * zoom,
		clampf(1.5 * delta, 0.0, 1.0))
	var body := target as CharacterBody3D
	var delay := flight_align_delay if flying else auto_align_delay
	var align_speed := flight_align_speed if flying else auto_align_speed
	if (flying or align_on_ground) and _idle_time > delay and body \
			and Vector2(body.velocity.x, body.velocity.z).length() > 0.3:
		var behind := target.global_rotation.y + PI
		_yaw = rotate_toward(_yaw, behind, align_speed * delta)
	# płynna (interpolowana) pozycja smoka — przy ekranach 90/120 Hz fizyka (60 Hz) dawałaby drganie
	var target_pos := target.get_global_transform_interpolated().origin
	var goal := target_pos + Vector3.UP * (flight_height * flight_zoom if flying else height * zoom)
	var follow := flight_follow_speed if flying else follow_speed
	global_position = global_position.lerp(goal, clampf(follow * delta, 0.0, 1.0))
	rotation = Vector3(_pitch, _yaw, 0.0)
	_cam.fov = lerpf(_cam.fov, base_fov + fov_boost * effect, clampf(4.0 * delta, 0.0, 1.0))
	var t := Time.get_ticks_msec() / 1000.0
	var shake := shake_amount * effect * effect
	_cam.h_offset = shake * (sin(t * 37.0) + sin(t * 23.0) * 0.5)
	_cam.v_offset = shake * (sin(t * 31.0 + 1.3) + sin(t * 19.0) * 0.5)
