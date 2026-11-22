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

	print("WYNIK: ", "OK" if _fails == 0 else "%d błędów" % _fails)
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	print(("  [OK]   " if ok else "  [FAIL] ") + what)
	if not ok:
		_fails += 1


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
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
