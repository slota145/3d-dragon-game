extends SceneTree
## Test zamku: wzgórze i mury, brama przepuszcza, mur blokuje, balisty celują (linia ostrzegawcza)
## i trafiają bełtem, ogień niszczy balistę, łucznicy na murach, skarbiec przed donżonem.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_castle.gd -- [katalog_na_zrzuty]

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
	var castle: Castle = world.get_node("Castle")
	var cam: FollowCamera = world.get_node("FollowCamera")
	var c := castle.position

	print("1) Zamek na wzgórzu")
	_check(c.y > Terrain.height(Terrain.CASTLE[0] + 250.0, Terrain.CASTLE[1]) + 8.0, "dziedziniec wyżej niż okolica (%.0f m)" % c.y)
	_check(absf(Terrain.height(c.x + 30.0, c.z) - c.y) < 0.1, "dziedziniec płaski")
	_check(castle.ballistas().size() == 4 and castle.working_ballistas() == 4, "balisty: %d" % castle.ballistas().size())
	_check(castle.guards().size() >= 8, "łucznicy na murach: %d" % castle.guards().size())
	var g0: Villager = castle.guards()[1]
	_check(g0.global_position.y > c.y + 7.0, "łucznik stoi na murze (%.1f m nad dziedzińcem)" % (g0.global_position.y - c.y))
	var road := Terrain.road_points(Terrain.ROAD_PAIRS.size() - 1)
	var end := road[road.size() - 1]
	_check(end.distance_to(Terrain.road_end(Terrain.VILLAGES.size())) < 1.0, "droga kończy się przed bramą")
	var finds: GoldFinds = world.get_node("GoldFinds")
	var chests := finds.remaining().filter(func(f: Node3D) -> bool: return String(f.name).begins_with("castle_"))
	_check(chests.size() == 3 and castle.inside(chests[0].global_position), "skarbiec: %d skrzynie w murach" % chests.size())

	print("2) Brama przepuszcza, mur blokuje (młodzik idzie pieszo)")
	world.call("teleport_to_castle")
	for b in castle.ballistas():
		b.set_physics_process(false)
	for gd in castle.guards():
		gd.set_physics_process(false)
	await _seconds(0.6)
	await _shot("castle_gate.png")
	_p.stats.set_size_instant(3.0)
	var gd2 := Terrain.castle_gate_dir()
	var gp := Vector2(c.x, c.z) + gd2 * (Terrain.CASTLE[2] + 14.0)
	_p.global_position = Vector3(gp.x, Terrain.height(gp.x, gp.y) + 1.0, gp.y)
	_p.reset_physics_interpolation()
	Input.action_press("move_forward")
	Input.action_press("dash")
	await _seconds(10.0)
	Input.action_release("dash")
	Input.action_release("move_forward")
	_check(castle.inside(_p.global_position), "wszedł przez bramę na dziedziniec (%.0f m od środka)" % Vector2(_p.global_position.x - c.x, _p.global_position.z - c.z).length())
	# mur: idź od środka w bok (nie w bramę)
	var side := Basis(Vector3.UP, castle.rotation.y + PI * 0.5) * Vector3(0, 0, 1)
	_p.global_position = c + side * 20.0 + Vector3.UP
	_p.rotation.y = atan2(side.x, side.z)
	_p.reset_physics_interpolation()
	cam.snap_behind()
	Input.action_press("move_forward")
	Input.action_press("dash")
	await _seconds(10.0)
	Input.action_release("dash")
	Input.action_release("move_forward")
	_check(castle.inside(_p.global_position), "mur zatrzymał smoka")
	for gd in castle.guards():
		gd.set_physics_process(true)

	print("3) Balista celuje i trafia dorosłego smoka")
	_p.stats.set_size_instant(12.0)
	var b: Ballista = castle.ballistas()[0]
	var out := (b.global_position - c)
	out.y = 0.0
	out = out.normalized()
	var spot := b.global_position + out * 90.0
	_p.global_position = Vector3(spot.x, Terrain.height(spot.x, spot.z) + 1.0, spot.z)
	_p.rotation.y = atan2(-out.x, -out.z)
	_p.reset_physics_interpolation()
	cam.snap_behind()
	var shots := []
	b.fired.connect(func(bolt: Bolt) -> void: shots.append(bolt))
	var hits := []
	castle.bolt_hit.connect(func(d: float) -> void: hits.append(d))
	b.set_physics_process(true)
	var hp := _p.stats.health
	await _seconds(1.4)
	_check(b.state == Ballista.State.AIM, "celuje (stan %d)" % b.state)
	await _shot("castle_aim.png")
	await _seconds(2.5)
	_check(shots.size() == 1, "wystrzeliła bełt")
	_check(hits.size() == 1 and _p.stats.health < hp - 10.0, "trafiony (zdrowie %.0f -> %.0f)" % [hp, _p.stats.health])
	_check(b.state == Ballista.State.RELOAD, "przeładowuje")

	print("4) Ogień niszczy balistę")
	castle.burn_near(b.global_position, 4.0, 5.0)
	_check(not b.is_working() and castle.working_ballistas() == 3, "zniszczona (zostały %d)" % castle.working_ballistas())
	await _seconds(6.0)
	_check(shots.size() == 1, "zniszczona nie strzela")

	print("5) Widok zamku z lotu")
	var g := Terrain.castle_gate_dir()
	_p.global_position = c + Vector3(g.x, 0, g.y) * 140.0 + Vector3.UP * 50.0
	_p.rotation.y = atan2(-g.x, -g.y)
	_p.velocity = Vector3.ZERO
	_p.reset_physics_interpolation()
	for x in castle.ballistas():
		x.set_physics_process(false)
	cam.snap_behind()
	await _seconds(1.0)
	await _shot("castle_air.png")

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
