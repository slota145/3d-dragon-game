extends SceneTree
## Test jeźdźców gryfów i dowódcy (boss): jeźdźcy na wieżach i dowódca na wieży-gnieździe,
## atak przy zamku, pancerz dowódcy (pełne obrażenia dopiero od pradawnego), 2. faza z posiłkami,
## pokonany dowódca spada i zostawia skarb, łowcy ścigają smoka po świecie; zrzuty.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_riders.gd -- [katalog_na_zrzuty]

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
	var gr: GryphonRiders = world.get_node("GryphonRiders")
	var castle: Castle = world.get_node("Castle")
	var cam: FollowCamera = world.get_node("FollowCamera")

	print("1) Jeźdźcy na wieżach, dowódca na gnieździe")
	_check(gr.riders().size() == 2, "jeźdźców: %d" % gr.riders().size())
	_check(gr.boss_alive(), "dowódca jest")
	_check(gr.boss.global_position.distance_to(castle.eyrie_top()) < 3.0, "dowódca na wieży-gnieździe (%.0f m)" % castle.eyrie_top().y)
	var parts := gr.riders()[0].get_node("Body").get_children().map(func(n: Node) -> String: return String(n.name))
	_check(parts.has("Rider") and parts.has("Tack") and parts.has("WingL"), "części: %s" % str(parts))

	print("2) Dorosły smok pod zamkiem — jeźdźcy atakują, pancerz dowódcy odbija ciosy")
	_p.stats.set_size_instant(12.0)
	var hits := []
	gr.attacked.connect(func(_by: Prey, d: float) -> void: hits.append(d))
	world.call("teleport_to_castle")
	var hp := _p.stats.health
	for i in 80:
		await _seconds(0.25)
		_p.stats.health = maxf(_p.stats.health, 50.0)
		if hits.size() > 0 and gr.boss.mode != Gryphon.Mode.PERCH:
			break
	_check(hits.size() > 0, "szarża trafiła (%d, zdrowie %.0f)" % [hits.size(), hp])
	_check(gr.boss.mode != Gryphon.Mode.PERCH, "dowódca startuje do walki")
	await _shot("riders_attack.png")
	var bh := gr.boss.health
	gr.boss.take_bite(10.0)
	_check(is_equal_approx(bh - gr.boss.health, 10.0 * GryphonCommander.ARMOR_FACTOR),
		"pancerz: dorosły zadaje %.1f z 10" % (bh - gr.boss.health))

	print("3) Pradawny — pełne obrażenia, 2. faza z posiłkami")
	_p.stats.set_size_instant(17.0)
	bh = gr.boss.health
	gr.boss.take_bite(10.0)
	_check(is_equal_approx(bh - gr.boss.health, 10.0), "pradawny zadaje %.1f z 10" % (bh - gr.boss.health))
	var before := gr.riders().size()
	gr.boss.health = gr.boss.max_health * 0.52
	gr.boss.take_bite(20.0)
	await _frames(2)
	_check(gr.boss.phase == 2, "faza 2")
	_check(gr.riders().size() == before + 2, "posiłki: %d -> %d jeźdźców" % [before, gr.riders().size()])
	_check(gr.boss.mode != Gryphon.Mode.FLEE, "dowódca nie ucieka")

	print("4) Pokonany dowódca spada i zostawia skarb")
	var boss := gr.boss
	boss.burn(1000.0)
	_check(not boss.is_alive(), "pokonany")
	_check(bool(world.get("boss_defeated")), "zapisany jako pokonany")
	await _seconds(5.0)
	var bp := boss.global_position
	_check(bp.y <= Terrain.height(bp.x, bp.z) + 1.0 or bp.y < castle.eyrie_top().y - 5.0, "spadł (%.0f m)" % bp.y)
	var finds: GoldFinds = world.get_node("GoldFinds")
	_check(finds.has_node("boss_loot"), "skarb dowódcy")

	print("5) Łowcy ścigają smoka po świecie")
	gr.repopulate(false, false)
	await _frames(2)
	_check(not gr.boss_alive(), "nowy dzień: pokonany dowódca nie wraca")
	_p.stats.set_size_instant(12.0)
	_p.global_position = Vector3(0, 0.5, 0)
	_p.reset_physics_interpolation()
	gr.send_hunters()
	var hunter: GryphonRider = gr.riders().filter(func(r: GryphonRider) -> bool: return r.hunter)[0]
	var d0 := hunter.global_position.distance_to(_p.global_position)
	await _seconds(4.0)
	var d1 := hunter.global_position.distance_to(_p.global_position)
	_check(d1 < d0 - 50.0, "łowca leci do smoka (%.0f -> %.0f m)" % [d0, d1])

	print("6) Zrzut z bliska")
	gr.repopulate(false, true)
	await _frames(2)
	_p.stats.set_size_instant(6.0)
	_p.global_position = Vector3(0, 0.5, 40)
	_p.rotation.y = PI
	_p.reset_physics_interpolation()
	for r in gr.riders():
		r.set_physics_process(false)
	gr.boss.set_physics_process(false)
	var a: GryphonRider = gr.riders()[0]
	a.global_position = Vector3(-5, 3, 24)
	a.mode = Gryphon.Mode.ATTACK
	a.vel = Vector3(6, 0, 0)
	a.rotation = Vector3(0, PI * 0.5, 0)
	a._flap = 1.2
	for i in 10:
		a._animate(0.05)
	var b := gr.boss
	b.global_position = Vector3(7, 6, 14)
	b.mode = Gryphon.Mode.PATROL
	b.vel = Vector3(-6, 1, 0)
	b.rotation = Vector3(0, -PI * 0.6, 0)
	b._flap = 1.5
	for i in 10:
		b._animate(0.05)
	cam.snap_behind()
	await _seconds(1.0)
	await _shot("riders_close.png")

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
