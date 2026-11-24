extends SceneTree
## Test dzikiej zwierzyny: gatunki z ruchomymi częściami, animacja nóg / głowy / skrzydeł,
## siedliska (las, góry, jezioro), kaczka odlatuje, dzik szarżuje na pisklę, kury w wiosce.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_wildlife.gd -- [katalog_na_zrzuty]

var _fails := 0
var _out := ""
var _p: DragonController


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.set("use_save", false)
	root.add_child(world)
	await _frames(15)
	_p = world.get_node("DragonPlayer")
	var spawner: PreySpawner = world.get_node("Prey")

	print("1) Gatunki i części modeli")
	for sp: String in Wildlife.SPECIES:
		var a := Wildlife.create(sp)
		var body := a.get_node("Body")
		var names := body.get_children().map(func(n: Node) -> String: return String(n.name))
		var ok := names.has("Body") and names.has("Head")
		ok = ok and (names.has("WingL") and names.has("LegL") if a.flies or sp == "chicken" else names.has("LegFL") and names.has("LegBR"))
		_check(ok, "%s: %s" % [a.display_name, str(names)])
		a.free()

	print("2) Animacja: nogi idącej sarny się ruszają, pasąca się schyla głowę")
	var deer := Wildlife.create("deer")
	spawner.spawn(deer, Vector3(30, 0, 30))
	deer.set_physics_process(false)
	deer._speed = deer.walk_speed
	var leg: Node3D = deer.get_node("Body/LegFL")
	var mn := 9.0
	var mx := -9.0
	for i in 60:
		deer._animate(1.0 / 60.0)
		mn = minf(mn, leg.rotation.x)
		mx = maxf(mx, leg.rotation.x)
	_check(mx - mn > 0.3, "zakres ruchu nogi %.2f rad" % (mx - mn))
	deer._speed = 0.0
	deer._look_t = 0.0
	for i in 60:
		deer._animate(1.0 / 60.0)
		deer._look_t = 1.0
	_check((deer.get_node("Body/Head") as Node3D).rotation.x > 0.5, "głowa w dół (%.2f)" % (deer.get_node("Body/Head") as Node3D).rotation.x)
	deer.queue_free()

	print("3) Siedliska")
	_check(PreySpawner.suits("deer", -500, 100) or PreySpawner.suits("deer", -520, 120), "sarna w lesie na zachodzie")
	_check(PreySpawner.suits("duck", Terrain.LAKE_CENTER.x, Terrain.LAKE_CENTER.y), "kaczka na jeziorze")
	_check(not PreySpawner.suits("duck", 0, 0), "kaczka nie na łące")
	_check(not PreySpawner.suits("goat", 0, 0), "koza nie na łące")
	var goat_spot := false
	for z in range(-500, -900, -20):
		if PreySpawner.suits("goat", 0, z):
			goat_spot = true
			break
	_check(goat_spot, "koza znajdzie miejsce w górach")

	print("4) Kaczka: pływa, spłoszona odlatuje")
	var lc := Vector3(Terrain.LAKE_CENTER.x, 0, Terrain.LAKE_CENTER.y)
	var duck := Wildlife.create("duck")
	spawner.spawn(duck, lc)
	duck.home = lc
	duck.home_radius = 30.0
	_check(absf(duck.global_position.y - Terrain.WATER_LEVEL) < 0.3, "na wodzie (y=%.2f)" % duck.global_position.y)
	_p.global_position = lc + Vector3(4, 3, 0)
	_p.reset_physics_interpolation()
	await _seconds(2.0)
	_check(duck.is_flying() and duck.global_position.y > Terrain.WATER_LEVEL + 3.0, "w powietrzu (y=%.1f)" % duck.global_position.y)
	await _shot("wild_duck.png")
	var shore := lc + Vector3(0, 0, -(Terrain.LAKE_RADIUS + 20.0))
	_p.global_position = Vector3(shore.x, Terrain.height(shore.x, shore.z) + 1.0, shore.z)
	_p.reset_physics_interpolation()
	var landed := false
	for k in 20:
		await _seconds(0.5)
		if not is_instance_valid(duck):
			break
		if not duck.is_flying():
			landed = true
			break
	_check(landed and is_instance_valid(duck) and Vector2(duck.global_position.x - lc.x, duck.global_position.z - lc.z).length() < 40.0,
		"wraca na swoje jezioro i siada")
	_p.global_position = Vector3(0, 1, 0)
	_p.reset_physics_interpolation()
	await _seconds(1.0)

	print("5) Dzik szarżuje na pisklę")
	var boar := Wildlife.create("boar")
	spawner.spawn(boar, _p.global_position + Vector3(6, 0, 0))
	var hits := []
	spawner.attacked.connect(func(by: Prey, d: float) -> void: hits.append(d))
	var hp := _p.stats.health
	await _seconds(3.0)
	_check(hits.size() > 0 and _p.stats.health < hp, "atak (%d, zdrowie %.0f -> %.0f)" % [hits.size(), hp, _p.stats.health])
	_p.stats.set_size_instant(6.0)
	boar.global_position = _p.global_position + Vector3(6, 0, 0)
	boar.state = Prey.State.GRAZE
	await _seconds(0.5)
	_check(boar.state == Prey.State.FLEE, "przed dużym smokiem ucieka (stan %d)" % boar.state)
	_p.stats.set_size_instant(1.0)

	print("6) Kury w wiosce")
	var vil: Villages = world.get_node("Villages")
	var hens := vil.residents().filter(func(r: Node3D) -> bool: return r is Prey and (r as Prey).species == "chicken")
	_check(hens.size() >= Terrain.VILLAGES.size() * 3, "kur: %d" % hens.size())

	print("7) Zrzut: zwierzęta z bliska")
	_p.stats.set_size_instant(3.0)
	var base := Vector3(40, 0, -40)
	var i := 0
	for sp: String in Wildlife.SPECIES:
		var a := Wildlife.create(sp)
		spawner.spawn(a, base + Vector3(i * 2.2 - 7.0, 0, 0))
		a.set_physics_process(false)
		a.rotation.y = PI * 0.5
		a._speed = a.walk_speed
		a._phase = 0.9
		a._animate(0.02)
		i += 1
	_p.global_position = base + Vector3(0, 0, 9)
	_p.rotation.y = PI
	_p.reset_physics_interpolation()
	var cam: FollowCamera = world.get_node("FollowCamera")
	cam.snap_behind()
	await _seconds(1.0)
	await _shot("wild_lineup.png")

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
