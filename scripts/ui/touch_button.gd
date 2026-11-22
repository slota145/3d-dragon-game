class_name TouchActionButton
extends Control
## Okrągły przycisk na ekranie, który naciska akcję wejścia (np. `flap`).
## Obsługuje wiele palców naraz (gałka + przycisk) i mysz (emulacja dotyku).

@export var action: StringName = &"flap"
@export var label: String = "SKRZYDŁA"
## "wings", "dash", "bite" lub "fire"
@export var icon: String = "wings"
## Zablokowany: wyszarzony, z kłódką, nie naciska akcji (np. ogień przed stadium Młodzika).
@export var locked: bool = false
@export var radius: float = 120.0
@export var color_idle: Color = Color(1, 1, 1, 0.22)
@export var color_pressed: Color = Color(1, 0.85, 0.5, 0.5)

var _touch_index: int = -1
## Czas pozostały animacji odblokowania (s) — pulsowanie i złote fale.
var _celebrate_t: float = 0.0

const CELEBRATE_TIME := 3.0
const GOLD := Color(1.0, 0.82, 0.35)


## Animacja odblokowania: przycisk podskakuje i pulsuje złotem, rozchodzą się od niego fale.
func celebrate() -> void:
	_celebrate_t = CELEBRATE_TIME


func is_celebrating() -> bool:
	return _celebrate_t > 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _touch_index != -1:  # puszczenie w czasie pauzy by nie dotarło
		_touch_index = -1
		Input.action_release(action)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _hit(event.position):
			_touch_index = event.index
			if not locked:
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
	var pressed := not locked and (_touch_index != -1 or Input.is_action_pressed(action))
	var glow := 0.0
	if _celebrate_t > 0.0:
		var t := CELEBRATE_TIME - _celebrate_t  # 0 -> CELEBRATE_TIME
		var fade := clampf(_celebrate_t / 0.8, 0.0, 1.0)
		for i in 3:  # fale co 0.6 s
			var ph := fmod(t - 0.6 * i, 1.8) / 1.8
			if t >= 0.6 * i and ph >= 0.0:
				draw_arc(c, radius * (1.0 + 0.9 * ph), 0.0, TAU, 64,
					Color(GOLD, (1.0 - ph) * 0.8 * fade), 8.0 * (1.0 - ph) + 2.0, true)
		glow = (0.55 + 0.45 * sin(t * 9.0)) * fade
		# podskok: szybkie powiększenie i sprężyste wygaszenie
		var bounce := 1.0 + 0.22 * exp(-3.0 * t) * absf(sin(t * 7.0)) + 0.05 * glow
		draw_set_transform(c * (1.0 - bounce), 0.0, Vector2.ONE * bounce)
	var fill := color_pressed if pressed else (Color(0.2, 0.2, 0.2, 0.25) if locked else color_idle)
	draw_circle(c, radius, fill.lerp(Color(GOLD, 0.55), glow))
	if glow > 0.0:
		draw_arc(c, radius, 0.0, TAU, 64, Color(GOLD, glow), 8.0, true)
	draw_arc(c, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.2 if locked else 0.45), 4.0, true)
	var wing := Color(1, 1, 1, 0.3 if locked else 0.85)
	var k := radius / 120.0
	if icon == "bite":  # paszcza: dwa rzędy zębów
		for row: float in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 7:
				var x := (-42.0 + 14.0 * i) * k
				var y := (row * 22.0 + (0.0 if i % 2 == 0 else -row * 18.0)) * k - 8.0 * k
				pts.append(c + Vector2(x, y))
			draw_polyline(pts, wing, 6.0 * k, true)
	elif icon == "fire":  # płomień
		var pts := PackedVector2Array()
		for i in 25:
			var t := float(i) / 24.0 * TAU
			var r := (26.0 + 10.0 * sin(t * 3.0)) * k
			pts.append(c + Vector2(sin(t) * r * 0.8, -cos(t) * r * (1.25 if cos(t) > 0 else 0.8) - 6.0 * k))
		draw_polyline(pts, wing, 6.0 * k, true)
	elif icon == "dash":
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
	if locked:  # kłódka
		var lc := Color(1, 1, 1, 0.8)
		var o := c + Vector2(radius * 0.45, -radius * 0.5)
		draw_rect(Rect2(o + Vector2(-12, -2), Vector2(24, 18)), lc)
		draw_arc(o + Vector2(0, -4), 8.0, PI, TAU, 12, lc, 4.0, true)


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


func _process(delta: float) -> void:
	_celebrate_t = maxf(0.0, _celebrate_t - delta)
	queue_redraw()
