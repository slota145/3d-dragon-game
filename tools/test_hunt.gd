extends SceneTree
## Test fazy 3: pisklę bez lotu, głód, ugryzienie i jedzenie, owca na kilka ugryzień,
## płynny wzrost, przejście do stadium Młodzika (odblokowanie lotu), głodowanie.
## xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_hunt.gd -- [katalog]

var _fails := 0
var _out := ""
var _p: DragonController
var _stage_events: Array[String] = []


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await _frames(15)
	_p = world.get_node("DragonPlayer")
	var spawner: PreySpawner = world.get_node("Prey")
	var stats := _p.stats
	var anim: AnimationPlayer = _p.find_child("AnimationPlayer", true, false)
	stats.stage_changed.connect(func(_s: int, n: String) -> void: _stage_events.append(n))

	print("1) Start jako pisklę")
	_check(stats.stage == DragonStats.Stage.HATCHLING, "stadium: %s" % stats.stage_name())
	_check(absf(stats.size - 2.4) < 0.01, "rozmiar %.1f m" % stats.size)
	_check(spawner.get_child_count() > 15, "zwierzyna w świecie (%d)" % spawner.get_child_count())
	await _shot("hunt_start.png")

	print("2) Pisklę nie lata: przytrzymanie = tylko skok")
	var peak := 0.0
	Input.action_press("flap")
	for i in 90:
		await physics_frame
		peak = maxf(peak, _p.global_position.y)
	Input.action_release("flap")
	await _seconds(1.5)
	_check(not _p.is_flying(), "na ziemi po skoku")
	_check(peak < 3.0, "nie wystartował (max %.1f m)" % peak)

	print("3) Głód spada")
	var h0 := stats.hunger
	await _seconds(2.0)
	_check(stats.hunger < h0, "%.1f -> %.1f" % [h0, stats.hunger])

	print("4) Ugryzienie królika = zabicie i zjedzenie, smok rośnie")
	var size0 := stats.size
	var hunger0 := stats.hunger
	var rabbit := _spawn_in_front(spawner, "rabbit", 1.0)
	Input.action_press("bite")
	await _frames(2)
	Input.action_release("bite")
	await _seconds(0.5)
	_check(not rabbit.is_alive(), "królik zabity")
	_check(anim.current_animation == "Eat", "animacja jedzenia (%s)" % anim.current_animation)
	await _shot("hunt_eat.png")
	await _seconds(1.5)
	_check(stats.size > size0, "urósł (%.2f -> %.2f m)" % [size0, stats.size])
	_check(stats.hunger > hunger0, "najedzony (%.0f -> %.0f)" % [hunger0, stats.hunger])
	_check(not is_instance_valid(rabbit), "królik zniknął (zjedzony)")

	print("5) Owca wymaga kilku ugryzień pisklęcia i ucieka")
	var sheep := _spawn_in_front(spawner, "sheep", 1.3)
	var bites := 0
	while sheep.is_alive() and bites < 6:
		_place_in_front(sheep, 1.3)
		Input.action_press("bite")
		await _frames(2)
		Input.action_release("bite")
		await _seconds(0.7)
		bites += 1
		if bites == 1:
			_check(sheep.is_alive() and sheep.state == Prey.State.FLEE, "po 1. ugryzieniu żyje i ucieka")
	_check(not sheep.is_alive(), "owca upolowana (%d ugryzienia)" % bites)
	await _seconds(1.6)

	print("6) Płynny wzrost do Młodzika (trawienie)")
	var max_step := 0.0
	var t0 := Time.get_ticks_msec()
	while stats.size < 4.0 and Time.get_ticks_msec() - t0 < 60000:
		if stats.pending_growth < 0.05:
			stats.eat(4.0, 1.3, "Owca")
		var before := stats.size
		await _seconds(0.25)
		max_step = maxf(max_step, stats.size - before)
	_check(stats.size >= 4.0, "urósł do %.2f m" % stats.size)
	_check(max_step < 0.3, "płynnie: maks. przyrost %.2f m na 0,25 s (posiłek: owca)" % max_step)
	_check(_stage_events.has("Młodzik"), "zdarzenie stadium: %s" % str(_stage_events))
	_check(stats.can_fly(), "lot odblokowany")
	await _seconds(0.3)
	await _shot("hunt_juvenile.png")
	stats.hunger = 90.0

	print("7) Młodzik startuje")
	Input.action_press("flap")
	await _seconds(1.2)
	_check(_p.is_flying(), "w powietrzu (%.1f m)" % _p.global_position.y)
	await _shot("hunt_first_flight.png")
	Input.action_release("flap")
	for i in 200:
		await _seconds(0.05)
		if not _p.is_flying():
			break

	print("8) Głodowanie zabiera zdrowie")
	stats.hunger = 0.0
	var hp := stats.health
	await _seconds(1.5)
	_check(stats.health < hp, "zdrowie %.1f -> %.1f" % [hp, stats.health])

	print("WYNIK: ", "OK" if _fails == 0 else "%d błędów" % _fails)
	quit(1 if _fails else 0)


func _spawn_in_front(spawner: PreySpawner, kind: String, dist_extra: float) -> Prey:
	var pos := _p.global_position
	if kind == "rabbit":
		spawner._spawn_rabbit(pos)
	else:
		spawner._spawn_herd(pos)
	var p: Prey = spawner.get_child(spawner.get_child_count() - 1)
	# owce: zostaw jedną, resztę stada odsuń
	_place_in_front(p, dist_extra)
	return p


func _place_in_front(p: Prey, extra: float) -> void:
	var f := Vector3(sin(_p.rotation.y), 0, cos(_p.rotation.y))
	p.global_position = _p.global_position + f * (_p.bite_reach * _p.size_k() + extra * 0.3)


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
