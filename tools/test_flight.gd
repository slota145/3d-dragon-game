extends SceneTree
## Test lotu wg specyfikacji (przycisk `flap` + gałka):
##   tap na ziemi = skok; tap z gałką = skok do przodu; przytrzymanie = start;
##   trzymanie w powietrzu = zawis; tap = w górę; tap + przód = w przód i w górę;
##   gałka przód (szybowanie) = nurkowanie i przyspieszanie; gałka tył = wyrównanie i odzysk wysokości.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_flight.gd -- [katalog_na_zrzuty]

var _fails := 0
var _out := ""
var _p: DragonController
var _flaps := 0


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await _frames(10)
	_p = world.get_node("DragonPlayer")
	var anim: AnimationPlayer = _p.find_child("AnimationPlayer", true, false)
	_p.flapped.connect(func() -> void: _flaps += 1)

	print("0) Zryw na ziemi (trzymanie) = bieg")
	Input.action_press("dash")
	Input.action_press("move_forward")
	await _seconds(2.5)
	var run := _flat(_p.velocity).length()
	_check(run > _p.walk_speed * 2.0, "biegnie (%.1f m/s, chód %.1f)" % [run, _p.walk_speed])
	_check(anim.current_animation == "Run", "animacja biegu (%s)" % anim.current_animation)
	await _shot("run.png")
	_check(not _p.is_flying(), "nadal na ziemi")
	Input.action_release("move_forward")
	Input.action_release("dash")
	await _seconds(2.5)

	print("1) Tap na ziemi = skok w miejscu")
	var y0 := _p.global_position.y
	var x0 := _flat(_p.global_position)
	var peak := await _tap_and_track_peak(0.1, 2.0)
	_check(peak - y0 > 1.0, "skok w górę (%.2f m)" % (peak - y0))
	_check(_flat(_p.global_position).distance_to(x0) < 1.0, "w miejscu")
	_check(not _p.is_flying(), "wylądował")

	print("2) Tap z gałką do przodu = sus mocno do przodu po łuku")
	Input.action_press("move_forward")
	await _seconds(0.6)
	x0 = _flat(_p.global_position)
	var y2 := _p.global_position.y
	var leap_anim := ""
	Input.action_press("flap")
	await _seconds(0.1)
	Input.action_release("flap")
	var peak2 := y2
	var shot_done := false
	for i in 150:
		await physics_frame
		peak2 = maxf(peak2, _p.global_position.y)
		if _p.is_flying():
			leap_anim = anim.current_animation
			if not shot_done and _p.global_position.y > y2 + 1.5:
				shot_done = true
				await _shot("leap.png")
		elif i > 20:
			break
	var leap_dist := _flat(_p.global_position).distance_to(x0)
	Input.action_release("move_forward")
	_check(leap_dist > 12.0, "sus daleko do przodu (%.1f m)" % leap_dist)
	_check(peak2 - y2 > 2.0, "po łuku (szczyt %.1f m)" % (peak2 - y2))
	_check(leap_anim == "Leap", "animacja susu (%s)" % leap_anim)
	_check(not _p.is_flying(), "wylądował")

	print("3) Przytrzymanie na ziemi = potężny start, trzymanie = zawis")
	Input.action_press("flap")
	await _seconds(0.6)
	_check(_p.is_flying(), "wystartował")
	await _seconds(0.15)
	await _shot("flight_takeoff.png")
	await _seconds(3.5)
	var h1 := _p.global_position.y
	await _seconds(3.0)
	var h2 := _p.global_position.y
	_check(h1 > 12.0, "wysoki start (%.1f m)" % h1)
	_check(absf(h2 - h1) < 2.5, "zawis: wysokość stabilna (%.1f -> %.1f m)" % [h1, h2])
	_check(_flat(_p.velocity).length() < 1.0, "zawis: w miejscu (%.2f m/s)" % _flat(_p.velocity).length())
	_check(anim.current_animation == "Fly", "animacja machania (%s)" % anim.current_animation)
	await _shot("flight_hover.png")
	Input.action_release("flap")

	print("3b) Spamowanie machnięć nie przerywa animacji")
	await _seconds(1.0)
	_flaps = 0
	for i in 10:
		await _tap(0.04)
		await _seconds(0.06)
	await _seconds(0.05)
	_check(_flaps <= 2, "10 tapnięć w 1 s -> %d machnięcia (odstęp >= %.1f s)" % [_flaps, _p.flap_cooldown])
	await _seconds(0.8)
	_check(_flaps <= 3, "zapamiętane tapnięcie wykonane po machnięciu (%d)" % _flaps)

	print("4) Tapnięcia bez kierunku = w górę")
	var h3 := _p.global_position.y
	for i in 3:
		await _tap(0.08)
		await _seconds(0.35)
	_check(_p.global_position.y > h3 + 2.0, "wznosi się (%.1f -> %.1f m)" % [h3, _p.global_position.y])
	_check(_flat(_p.velocity).length() < 2.0, "pionowo (%.2f m/s w poziomie)" % _flat(_p.velocity).length())

	print("5) Tap + przód = w przód i w górę")
	var pos5 := _p.global_position
	Input.action_press("move_forward")
	for i in 4:
		await _tap(0.08)
		await _seconds(0.35)
	Input.action_release("move_forward")
	var sp5 := _flat(_p.velocity).length()
	_check(sp5 > 10.0, "leci do przodu (%.1f m/s)" % sp5)
	_check(_p.global_position.y > pos5.y, "i w górę (%.1f -> %.1f m)" % [pos5.y, _p.global_position.y])
	await _shot("flight_forward.png")

	print("6) Wznieś się wyżej (przytrzymanie z przodu)")
	Input.action_press("flap")
	Input.action_press("move_forward")
	for i in 10:
		await _tap(0.05)
		Input.action_press("flap")
		await _seconds(0.3)
	Input.action_release("flap")
	Input.action_release("move_forward")
	print("   wysokość %.1f m, prędkość %.1f m/s" % [_p.global_position.y, _p.velocity.length()])

	print("6b) Zryw w powietrzu = duży przyrost prędkości w kierunku dzioba")
	await _seconds(1.0)
	var v0 := _p.velocity
	Input.action_press("dash")
	await _seconds(0.1)
	Input.action_release("dash")
	var gain := (_p.velocity - v0).dot(Vector3(sin(_p.rotation.y), 0, cos(_p.rotation.y)))
	_check(gain > 15.0, "przyspieszenie w przód (+%.1f m/s)" % gain)
	_check(_p.speed_effect > 0.5, "efekty prędkości aktywne (%.2f)" % _p.speed_effect)
	await _shot("flight_dash.png")
	var v1 := _p.velocity.length()
	Input.action_press("dash")
	await _seconds(0.1)
	Input.action_release("dash")
	_check(_p.velocity.length() < v1 + 5.0, "czas odnowienia zrywu (%.1f -> %.1f m/s)" % [v1, _p.velocity.length()])
	await _seconds(1.5)

	print("7) Gałka do przodu (szybowanie) = nurkowanie")
	var s7 := _p.velocity.length()
	var h7 := _p.global_position.y
	Input.action_press("move_forward")
	await _seconds(2.0)
	_check(_p.pitch < deg_to_rad(-40), "pochylony w dół (%.0f°)" % rad_to_deg(_p.pitch))
	_check(_p.velocity.length() > s7 + 4.0, "przyspiesza (%.1f -> %.1f m/s)" % [s7, _p.velocity.length()])
	_check(_p.global_position.y < h7, "traci wysokość (%.1f -> %.1f m)" % [h7, _p.global_position.y])
	_check(anim.current_animation == "Dive", "animacja nurkowania (%s)" % anim.current_animation)
	_check(_p.speed_effect > 0.2, "linie pędu przy nurkowaniu (%.2f)" % _p.speed_effect)
	await _shot("flight_dive.png")
	Input.action_release("move_forward")

	print("8) Gałka do tyłu = wyrównanie i odzysk wysokości z rozpędu")
	var s8 := _p.velocity.length()
	Input.action_press("move_back")
	var low := _p.global_position.y
	var top := -1.0
	for i in 60:
		await _seconds(0.05)
		var y := _p.global_position.y
		if top < 0.0 and y < low:
			low = y
		elif y > low + 0.05:
			top = maxf(top, y)
	Input.action_release("move_back")
	_check(top > low + 3.0, "wyrównał i odzyskał wysokość z rozpędu (dołek %.1f -> %.1f m)" % [low, top])
	_check(_p.velocity.length() < s8, "kosztem prędkości (%.1f -> %.1f m/s)" % [s8, _p.velocity.length()])
	await _shot("flight_pullup.png")

	print("9) Szybowanie aż do lądowania")
	for i in 400:
		await _seconds(0.05)
		if not _p.is_flying():
			break
	_check(not _p.is_flying(), "wylądował (y=%.1f)" % _p.global_position.y)

	print("WYNIK: ", "OK" if _fails == 0 else "%d błędów" % _fails)
	quit(1 if _fails else 0)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _tap(hold: float) -> void:
	Input.action_press("flap")
	await _seconds(hold)
	Input.action_release("flap")


func _tap_and_track_peak(hold: float, wait: float) -> float:
	var peak := _p.global_position.y
	Input.action_press("flap")
	await _seconds(hold)
	Input.action_release("flap")
	var t := 0.0
	while t < wait:
		await physics_frame
		t += 1.0 / 60.0
		peak = maxf(peak, _p.global_position.y)
	return peak


func _check(ok: bool, what: String) -> void:
	print(("   [OK]   " if ok else "   [FAIL] ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s, true, true).timeout


func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out + "/" + name)
