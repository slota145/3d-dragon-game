class_name Crosshair
extends Control
## Celownik ognia: kółko w punkcie, w który poleci ogień (rzut aim_point na ekran), a gdy
## pomoc w celowaniu złapie cel — pomarańczowa obwódka wokół celu. Widoczny, gdy smok może ziać.

var dragon: DragonController


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not dragon:
		return
	var cam := get_viewport().get_camera_3d()
	# w locie: znacznik ofiary, po którą smok może zapikować (Ugryzienie = ŁAP)
	var prey := dragon.catch_target()
	if prey and cam and not cam.is_position_behind(prey.center()):
		var q := cam.unproject_position(prey.center())
		var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 150.0)
		var c := Color(0.45, 0.9, 1.0, 0.95)
		draw_arc(q, 30.0 * pulse, 0.0, TAU, 32, c, 3.0, true)
		draw_line(q + Vector2(0, -44), q + Vector2(0, -34), c, 3.0, true)
		draw_line(q + Vector2(-6, -40), q + Vector2(0, -34), c, 3.0, true)
		draw_line(q + Vector2(6, -40), q + Vector2(0, -34), c, 3.0, true)
	if not dragon.stats.can_fire():
		return
	if not cam or cam.is_position_behind(dragon.aim_point):
		return
	var p := cam.unproject_position(dragon.aim_point)
	var locked := dragon.aim_target != null and is_instance_valid(dragon.aim_target)
	var col := Color(1.0, 0.55, 0.15, 0.95) if locked else Color(1, 1, 1, 0.6)
	var r := 26.0 if locked else 14.0
	draw_arc(p, r, 0.0, TAU, 32, col, 3.0, true)
	if locked:  # cztery „zęby” obwódki
		for k in 4:
			var a := k * PI / 2.0 + PI / 4.0
			draw_line(p + Vector2(cos(a), sin(a)) * (r + 4.0), p + Vector2(cos(a), sin(a)) * (r + 14.0), col, 3.0, true)
	else:
		draw_circle(p, 2.5, col)
