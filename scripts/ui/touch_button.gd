class_name TouchActionButton
extends Control
## Okrągły przycisk na ekranie, który naciska akcję wejścia (np. `flap`).
## Obsługuje wiele palców naraz (gałka + przycisk) i mysz (emulacja dotyku).

@export var action: StringName = &"flap"
@export var label: String = "SKRZYDŁA"
## "wings" lub "dash"
@export var icon: String = "wings"
@export var radius: float = 120.0
@export var color_idle: Color = Color(1, 1, 1, 0.22)
@export var color_pressed: Color = Color(1, 0.85, 0.5, 0.5)

var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _hit(event.position):
			_touch_index = event.index
			Input.action_press(action)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			Input.action_release(action)
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		get_viewport().set_input_as_handled()


func _hit(screen_pos: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_pos
	return local.distance_to(size / 2.0) <= radius


func _draw() -> void:
	var c := size / 2.0
	var pressed := _touch_index != -1 or Input.is_action_pressed(action)
	draw_circle(c, radius, color_pressed if pressed else color_idle)
	draw_arc(c, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 4.0, true)
	var wing := Color(1, 1, 1, 0.85)
	var k := radius / 120.0
	if icon == "dash":
		for i in 2:  # podwójna strzałka w przód
			var y := (12.0 - 26.0 * i) * k
			draw_polyline(PackedVector2Array([c + Vector2(-30, y + 22) * Vector2(k, 1), c + Vector2(0, y - 4),
				c + Vector2(30, y + 22) * Vector2(k, 1)]), wing, 7.0 * k, true)
	else:
		_draw_wings(c, wing)
	var font := get_theme_default_font()
	var fs := int(22 * clampf(k, 0.8, 1.0))
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, c + Vector2(-w / 2.0, radius * 0.62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, wing)


func _draw_wings(c: Vector2, wing: Color) -> void:
	# ikona: dwa skrzydła (łuki) nad strzałką w górę
	for s in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			pts.append(c + Vector2(s * (12.0 + 60.0 * t), -10.0 - 34.0 * sin(t * PI * 0.9) + 20.0 * t))
		draw_polyline(pts, wing, 7.0, true)
	draw_line(c + Vector2(0, 40), c + Vector2(0, -6), wing, 7.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(-16, 12), c + Vector2(0, -6), c + Vector2(16, 12)]), wing, 7.0, true)


func _process(_delta: float) -> void:
	queue_redraw()
