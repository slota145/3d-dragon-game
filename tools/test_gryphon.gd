extends SceneTree
## Test gryfów: gniazda na szczytach, para w każdym, atak na smoka na terytorium (szarża
## i odskok), zabity w locie spada i można go zjeść, zrzucony z wysoka ginie; zrzuty.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_gryphon.gd -- [katalog_na_zrzuty]

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
	var gr: Gryphons = world.get_node("Gryphons")
	var cam: FollowCamera = world.get_node("FollowCamera")

	print("1) Gniazda i gryfy")
	_check(gr.gryphons().size() == Gryphons.NESTS.size() * Gryphons.PER_NEST, "gryfów: %d" % gr.gryphons().size())
	_check(Gryphons.nest_position(0).y > 200.0, "gniazdo na szczycie (%.0f m)" % Gryphons.nest_position(0).y)
	var finds: GoldFinds = world.get_node("GoldFinds")
	var nest_loot := finds.remaining().filter(func(f: Node3D) -> bool: return String(f.name).begins_with("nest_"))
	_check(nest_loot.size() == Gryphons.NESTS.size() * 2, "skarby w gniazdach: %d" % nest_loot.size())
	var g: Gryphon = gr.gryphons()[0]
	var parts := g.get_node("Body").get_children().map(func(n: Node) -> String: return String(n.name))
	_check(parts.has("WingL") and parts.has("WingR") and parts.has("Head") and parts.has("LegFL"), "części: %s" % str(parts))

	print("2) Smok na terytorium — gryf atakuje")
	_p.stats.set_size_instant(12.0)
	var hits := []
	gr.attacked.connect(func(_by: Prey, d: float) -> void: hits.append(d))
	world.call("teleport_to_nest")
	var np := Gryphons.nest_position(0)
	_p.global_position = np + Vector3(0, 5.0, 90.0)
	_p.reset_physics_interpolation()
	cam.snap_behind()
	var hp := _p.stats.health
	var attacking := false
	for i in 40:
		await _seconds(0.25)
		for x in gr.gryphons():
			if x.mode == Gryphon.Mode.ATTACK and x.nest.distance_to(np) < 1.0:
				attacking = true
		if hits.size() > 0:
			break
	_check(attacking, "gryf w trybie ataku")
	await _shot("gryphon_attack.png")
	_check(hits.size() > 0 and _p.stats.health < hp, "szarża trafiła (zdrowie %.0f -> %.0f)" % [hp, _p.stats.health])

	print("3) Zabity w locie spada — truchło do zjedzenia")
	var victim: Gryphon = null
	for x in gr.gryphons():
		if x.is_flying():
			victim = x
			break
	_check(victim != null, "jest gryf w powietrzu")
	if victim:
		victim.burn(100.0)
		_check(not victim.is_alive(), "zabity ogniem")
		var fell := false
		for i in 60:
			await _seconds(0.25)
			var gp := victim.global_position
			if gp.y <= Terrain.height(gp.x, gp.z) + 0.5:
				fell = true
				break
		_check(fell and victim.is_edible(), "leży na ziemi i jest jadalny")

	print("4) Zrzucony z wysoka ginie")
	var other: Gryphon = gr.gryphons()[0]
	var gp2 := other.global_position
	other.pick_up()
	other.global_position = Vector3(gp2.x, Terrain.height(gp2.x, gp2.z) + 45.0, gp2.z)
	other.drop(Vector3(0, -2, 0))
	for i in 40:
		await _seconds(0.2)
		if not other.is_alive():
			break
	_check(not other.is_alive() and other.is_edible(), "zginął od upadku")

	print("5) Zrzut z bliska")
	_p.stats.set_size_instant(6.0)
	_p.global_position = Vector3(0, 0.5, 40)
	_p.rotation.y = PI
	_p.reset_physics_interpolation()
	for x in gr.gryphons():
		x.set_physics_process(false)
	var a: Gryphon = gr.gryphons()[0]
	a.global_position = Vector3(-3, 0, 26)
	a.mode = Gryphon.Mode.PERCH
	a.rotation = Vector3(0, PI * 0.6, 0)
	a._animate(1.0)
	var b: Gryphon = gr.gryphons()[1]
	b.global_position = Vector3(5, 7, 24)
	b.mode = Gryphon.Mode.PATROL
	b.vel = Vector3(-8, 2, 0)
	b.rotation = Vector3(0, -PI * 0.5, 0)
	b._flap = 1.4
	b._animate(0.016)
	cam.snap_behind()
	await _seconds(1.0)
	await _shot("gryphon_close.png")

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
