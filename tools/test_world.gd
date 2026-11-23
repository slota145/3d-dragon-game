extends SceneTree
## Test dużego świata: teren z kawałków (LOD, kolizja wokół smoka), jezioro, rzeka, las, góry
## z legowiskiem; doczytywanie kawałków po przeniesieniu smoka daleko; zrzuty z lotu ptaka.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_world.gd -- [katalog_na_zrzuty]

var _fails := 0
var _out := ""


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var t0 := Time.get_ticks_msec()
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.set("use_save", false)
	root.add_child(world)
	print("  budowa świata: %d ms" % (Time.get_ticks_msec() - t0))
	await _frames(5)
	var player: DragonController = world.get_node("DragonPlayer")
	var terrain: Terrain = world.get_node("Terrain")

	print("1) Teren")
	_check(absf(Terrain.height(0, 0)) < 0.01 and absf(Terrain.height(40, -30)) < 0.05, "łąka startowa płaska (y=0)")
	_check(absf(Terrain.height(Lair.POSITION.x + 30, Lair.POSITION.z)) < 0.2, "plac pod legowiskiem płaski")
	_check(Terrain.height(0, -700) > 100.0, "góry na północy (%.0f m)" % Terrain.height(0, -700))
	_check(Terrain.is_water(Terrain.LAKE_CENTER.x, Terrain.LAKE_CENTER.y), "jezioro")
	var rv: Vector2 = Terrain.RIVER[3]
	_check(Terrain.is_water(rv.x, rv.y), "rzeka")
	_check(Terrain.forest(-500, 100) > 0.4, "las na zachodzie (%.2f)" % Terrain.forest(-500, 100))
	var c0 := terrain.chunk_of(player.global_position)
	_check(terrain.has_collision(c0) and terrain.lod_of(c0) == 0, "kolizja i pełny LOD pod smokiem")
	_check(terrain.lod_of(Vector2i(0, 0)) == 2, "daleki kawałek w niskim LOD")
	await _seconds(1.0)
	_check(player.global_position.y > -0.5 and player.is_on_floor(), "smok stoi na terenie (y=%.2f)" % player.global_position.y)

	print("2) Smok na wzgórzach daleko od startu")
	var far := Vector3(-420.0, 0.0, 380.0)
	far.y = Terrain.height(far.x, far.z) + 3.0
	player.global_position = far
	player.reset_physics_interpolation()
	await _frames(20)
	var cf := terrain.chunk_of(far)
	_check(terrain.has_collision(cf), "kolizja doczytana w nowym miejscu")
	await _seconds(1.5)
	_check(player.global_position.y > Terrain.height(player.global_position.x, player.global_position.z) - 0.5,
		"nie przeleciał przez teren (y=%.1f, teren %.1f)" % [player.global_position.y, Terrain.height(far.x, far.z)])
	Input.action_press("move_forward")
	await _seconds(2.0)
	Input.action_release("move_forward")
	_check(player.is_on_floor(), "chodzi po zboczu")

	print("3) Zrzuty z lotu ptaka")
	player.stats.set_size_instant(14.0)
	var cam: FollowCamera = world.get_node("FollowCamera")
	for shot: Array in [["world_lair.png", Vector3(0, 70, 120), PI], ["world_lake.png", Vector3(250, 90, 60), 2.3],
			["world_forest.png", Vector3(-250, 80, 250), -2.2], ["world_meadow.png", Vector3(0, 4, 60), 0.0]]:
		player.global_position = shot[1]
		player.rotation.y = shot[2]
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		cam.snap_behind()
		await _seconds(1.2)
		await _shot(shot[0])

	print("WYNIK: ", "OK" if _fails == 0 else "%d błędów" % _fails)
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	print(("  [OK]   " if ok else "  [FAIL] ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out + "/" + name)
	print("  zrzut: ", _out + "/" + name)
