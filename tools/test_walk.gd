extends SceneTree
## Test sterowania: symuluje gałkę na ekranie (dotyk) i klawisze, sprawdza ruch i animację.
## Użycie: tools/screenshot.sh-podobnie: xvfb-run godot --path . --script res://tools/test_walk.gd -- [out_dir]

var _fails := 0


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await _frames(10)
	var player: DragonController = world.get_node("DragonPlayer")
	var joy: Control = world.get_node("HUD/Joystick")
	var anim: AnimationPlayer = player.find_child("AnimationPlayer", true, false)
	var start := player.global_position

	# 1) klawiatura: do przodu (od kamery)
	Input.action_press("move_forward")
	await _seconds(3.0)
	_check(player.global_position.distance_to(start) > 2.0, "ruch klawiaturą (%.2f m)" % player.global_position.distance_to(start))
	_check(anim.current_animation == "Walk", "animacja Walk podczas ruchu (%s)" % anim.current_animation)
	if out != "":
		await _shot(out + "/walk_keys.png")
	Input.action_release("move_forward")
	await _seconds(2.5)
	_check(anim.current_animation == "Idle", "powrót do Idle (%s)" % anim.current_animation)

	# 2) gałka dotykowa: przeciągnięcie w prawo
	# współrzędne sceny (1920x1080) -> współrzędne okna (jak prawdziwy dotyk)
	var to_window := root.get_final_transform()
	var center: Vector2 = to_window * joy.get_global_rect().get_center()
	var push := to_window.get_scale().x * 110.0
	var yaw0 := player.rotation.y
	_touch(center, true)
	_drag(center + Vector2(push, 0))
	await _frames(2)
	_check(joy.output.x > 0.8, "gałka: wyjście w prawo (%s)" % str(joy.output))
	var p0 := player.global_position
	await _seconds(3.0)
	_check(absf(angle_difference(yaw0, player.rotation.y)) > 0.5, "skręt gałką (%.2f rad)" % angle_difference(yaw0, player.rotation.y))
	_check(player.global_position.distance_to(p0) > 1.0, "ruch gałką (%.2f m)" % player.global_position.distance_to(p0))
	if out != "":
		await _shot(out + "/walk_joystick.png")
	_touch(center + Vector2(push, 0), false)
	await _frames(2)
	_check(joy.output == Vector2.ZERO, "gałka puszczona -> zero")

	# 3) sprint i skręt o 90° — bez driftu: ruch podąża za kierunkiem smoka
	await _seconds(1.5)
	Input.action_press("dash")
	Input.action_press("move_forward")
	await _seconds(2.5)
	Input.action_release("move_forward")
	Input.action_press("move_right")
	var worst := 0.0
	for i in 30:
		await _seconds(0.05)
		var v := Vector3(player.velocity.x, 0, player.velocity.z)
		if v.length() > 0.3 and i > 10:
			var facing := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
			worst = maxf(worst, rad_to_deg(v.normalized().angle_to(facing)))
	Input.action_release("move_right")
	Input.action_release("dash")
	_check(worst < 10.0, "sprint + skręt bez driftu (maks. %.1f° między ruchem a kierunkiem smoka)" % worst)

	# 4) przybliżenie kamery: szczypanie dwoma palcami (poza gałką i przyciskami)
	var cam: FollowCamera = world.get_node("FollowCamera")
	var arm: SpringArm3D = cam.get_node("SpringArm3D")
	var vp := root.get_viewport().get_visible_rect().size
	var mid := Vector2(vp.x * 0.5, vp.y * 0.35)
	var len0 := arm.spring_length
	var yaw_before := cam.rotation.y
	_touch(mid + Vector2(-200, 0), true, 5)
	_touch(mid + Vector2(200, 0), true, 6)
	for i in 10:
		_drag(mid + Vector2(-200 + 15 * i, 0), 5)
		_drag(mid + Vector2(200 - 15 * i, 0), 6)
		await _frames(1)
	_touch(mid + Vector2(-65, 0), false, 5)
	_touch(mid + Vector2(65, 0), false, 6)
	await _seconds(1.0)
	_check(arm.spring_length > len0 * 1.5, "szczypanie (zsunięcie palców) oddala kamerę (%.2f -> %.2f m)" % [len0, arm.spring_length])
	_check(absf(angle_difference(yaw_before, cam.rotation.y)) < 0.3, "szczypanie nie obraca kamery")
	cam.set_user_zoom(0.0)
	await _seconds(1.0)
	_check(arm.spring_length < len0 * 0.4, "przybliżenie z bliska (%.2f m)" % arm.spring_length)
	await _shot(out + "/walk_zoom.png")

	print("WYNIK: ", "OK" if _fails == 0 else "%d błędów" % _fails)
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	print(("  [OK]   " if ok else "  [FAIL] ") + what)
	if not ok:
		_fails += 1


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2, index: int = 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("  zrzut: ", path)
