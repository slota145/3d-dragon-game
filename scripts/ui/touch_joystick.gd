class_name TouchJoystick
extends Control
## Gałka na ekranie (dotyk; na PC działa też myszą dzięki emulacji dotyku).
## `output`: Vector2 w zakresie -1..1 (y < 0 = do przodu), jak Input.get_vector().

@export var radius: float = 120.0
@export var knob_radius: float = 50.0
@export var dead_zone: float = 0.12
@export var base_color: Color = Color(1, 1, 1, 0.18)
@export var knob_color: Color = Color(1, 1, 1, 0.55)

var output: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:  # puszczenie palca w czasie pauzy by nie dotarło
		_touch_index = -1
		_knob = Vector2.ZERO
		output = Vector2.ZERO
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and get_global_rect().has_point(event.position):
			_touch_index = event.index
			_update(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_knob = Vector2.ZERO
			output = Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position)
		get_viewport().set_input_as_handled()


func _update(screen_pos: Vector2) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_pos
	_knob = (local - size / 2.0).limit_length(radius)
	var v := _knob / radius
	output = Vector2.ZERO if v.length() < dead_zone else v
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, radius, base_color)
	draw_arc(c, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(c + _knob, knob_radius, knob_color)
