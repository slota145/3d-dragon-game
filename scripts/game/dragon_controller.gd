class_name DragonController
extends CharacterBody3D
## Sterowanie smokiem na ziemi: chód w kierunku gałki/WASD względem kamery.
## Ciężki zwierz: najpierw obraca się w stronę ruchu, a prędkość zależy od tego,
## jak bardzo patrzy w kierunku, w którym chcemy iść.

@export var walk_speed: float = 2.6
@export var acceleration: float = 3.0
@export var deceleration: float = 4.5
@export var turn_speed: float = 1.8
## Prędkość (m/s), przy której animacja Walk zgadza się z ruchem stóp (speed_scale = 1).
@export var walk_anim_speed: float = 1.2
@export var joystick: TouchJoystick
@export var camera: Node3D

@onready var _anim: AnimationPlayer = find_child("AnimationPlayer", true, false)

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	if _anim:
		_anim.play("Idle")


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if joystick and joystick.output.length() > input.length():
		input = joystick.output
	var basis_src := camera.global_basis if camera else global_basis
	var forward := Vector3(-basis_src.z.x, 0.0, -basis_src.z.z).normalized()
	var right := Vector3(basis_src.x.x, 0.0, basis_src.x.z).normalized()
	var wish := right * input.x - forward * input.y

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length() > 0.05:
		var target_yaw := atan2(wish.x, wish.z)  # model patrzy w +Z
		rotation.y = rotate_toward(rotation.y, target_yaw, turn_speed * delta)
		var facing := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		var align := clampf(facing.dot(wish.normalized()), 0.0, 1.0)
		var target_speed := walk_speed * minf(1.0, wish.length()) * align
		flat = flat.move_toward(facing * target_speed, acceleration * delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	_update_animation(flat.length(), wish.length() > 0.05)


func _update_animation(speed: float, wants_move: bool) -> void:
	if not _anim:
		return
	if speed > 0.12 or (wants_move and speed > 0.02):
		if _anim.current_animation != "Walk":
			_anim.play("Walk", 0.35)
		_anim.speed_scale = clampf(speed / walk_anim_speed, 0.4, 2.5)
	else:
		if _anim.current_animation != "Idle":
			_anim.play("Idle", 0.5)
		_anim.speed_scale = 1.0
