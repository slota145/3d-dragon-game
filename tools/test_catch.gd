extends SceneTree
## Test łapania w locie: Ugryzienie w powietrzu łapie zwierzę / człowieka, ofiara leci w szponach,
## ciężar osłabia machnięcia, upuszczenie z wysokości zabija (truchło do zjedzenia), na ziemi
## Ugryzienie zjada niesioną ofiarę; za dużej ofiary smok nie podniesie.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_catch.gd -- [katalog_na_zrzuty]

var _fails := 0
var _out := ""
var _p: DragonController


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.set("use_save", false)
	root.add_child(world)
	await _frames(5)
	_p = world.get_node("DragonPlayer")
	var vil: Villages = world.get_node("Villages")
	var cam: FollowCamera = world.get_node("FollowCamera")
	var bite_btn: TouchActionButton = world.get_node("HUD/BiteButton")
	_p.stats.set_size_instant(6.0)
	_p.stats.hunger = 40.0

	var sheep: Prey = null
	for r in vil.residents():
		if r is Prey and not (r is Villager):
			sheep = r
			break
	sheep.home_radius = 0.0

	print("1) Start i lot nad owcą")
	_p.global_position = sheep.global_position + Vector3(0, 0.3, -12)
	_p.reset_physics_interpolation()
	Input.action_press("flap")
	await _seconds(0.8)
	Input.action_release("flap")
	_check(_p.is_flying(), "w powietrzu")
	_check(bite_btn.label == "ŁAP", "przycisk: %s" % bite_btn.label)

	print("2) Łapanie")
	_p.global_position = sheep.center() + Vector3.UP * (0.15 * _p.stats.size + 0.8)
	_p.velocity = Vector3.ZERO
	_p.reset_physics_interpolation()
	await _frames(2)
	_tap("bite")
	await _frames(3)
	_check(_p.carried == sheep and sheep.carried, "owca w szponach")
	_check(bite_btn.label == "PUŚĆ", "przycisk: %s" % bite_btn.label)
	print("3) Niesienie w górę (z ciężarem) — tapnięcia Skrzydeł")
	for i in 7:
		_tap("flap")
		await _seconds(0.75)
	var h := _p.global_position.y - Terrain.height(_p.global_position.x, _p.global_position.z)
	_check(h > 12.0, "wysoko z owcą (%.1f m nad ziemią)" % h)
	_check(sheep.global_position.distance_to(_p.talon_position()) < 2.0, "owca leci razem ze smokiem")
	_check(_p.carry_load() > 0.1, "ciężar w szponach (%.2f)" % _p.carry_load())
	cam.snap_behind()
	await _seconds(0.4)
	await _shot("catch_carry.png")

	print("4) Upuszczenie z wysokości")
	_tap("bite")
	await _frames(2)
	_check(_p.carried == null and not sheep.carried, "puszczona")
	await _seconds(3.0)
	_check(not sheep.is_alive() and sheep.roasted, "upadek z wysokości zabił owcę (truchło)")

	print("5) Człowiek: złapanie, lądowanie, zjedzenie na ziemi")
	var man: Villager = null
	for r in vil.residents():
		if r is Villager:
			man = r
			break
	man.home_radius = 0.0
	await _take_off()
	_p.global_position = man.center() + Vector3.UP * (0.15 * _p.stats.size + 0.8)
	_p.velocity = Vector3.ZERO
	_p.reset_physics_interpolation()
	await _frames(2)
	_check(_p.is_flying(), "nadal w powietrzu")
	_tap("bite")
	await _frames(3)
	_check(_p.carried == man, "człowiek w szponach")
	await _seconds(4.0)  # szybowanie aż do lądowania
	var waited := 0.0
	while _p.is_flying() and waited < 15.0:
		await _seconds(0.5)
		waited += 0.5
	_check(not _p.is_flying() and _p.carried == man, "wylądował z człowiekiem")
	_check(bite_btn.label == "ZJEDZ", "przycisk: %s" % bite_btn.label)
	var hunger0 := _p.stats.hunger
	_tap("bite")
	await _seconds(1.8)
	_check(_p.stats.hunger > hunger0 and _p.carried == null, "zjedzony (najedzenie %.0f -> %.0f)" % [hunger0, _p.stats.hunger])

	print("6) Za duża ofiara")
	_p.stats.set_size_instant(4.2)
	_p.stats.stamina = 100.0
	await _take_off()
	var big: Prey = null
	for r in vil.residents():
		if r is Prey and not (r is Villager) and (r as Prey).is_alive():
			big = r
			break
	big.body_size = 3.0
	_p.global_position = big.center() + Vector3.UP * (0.15 * _p.stats.size + 0.6)
	_p.velocity = Vector3.ZERO
	_p.reset_physics_interpolation()
	await _frames(2)
	_tap("bite")
	await _frames(3)
	_check(_p.carried != big and not big.carried, "za duża — nie złapana (złapana: %s)" % (str(_p.carried.body_size) if _p.carried else "nic"))

	print("WYNIK: ", "OK" if _fails == 0 else "%d błędów" % _fails)
	quit(1 if _fails else 0)


func _take_off() -> void:
	_p.stats.stamina = 100.0
	Input.action_press("flap")
	await _seconds(0.8)
	Input.action_release("flap")
	await _seconds(0.3)


func _tap(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await physics_frame
	Input.action_release(action)


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
