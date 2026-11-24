extends SceneTree
## Test rycerzy: patrole na drogach (szyk, ruch), szarża z włócznią na pisklę, oszczepy i bełty
## na młodzika, panika przed dorosłym / pradawnym, sakiewka i rozgłos po zabiciu rycerza,
## oddział pościgowy z zamku; zrzuty.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_knights.gd -- [katalog_na_zrzuty]

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
	var kn: Knights = world.get_node("Knights")
	var cam: FollowCamera = world.get_node("FollowCamera")

	print("1) Patrole na drogach")
	var expected := 0
	for d: Array in Knights.PATROLS:
		expected += int(d[1])
	_check(kn.knights().size() == expected, "rycerzy: %d" % kn.knights().size())
	var k0: Knight = kn.knights()[0]
	var parts := k0.get_node("Body").get_children().map(func(n: Node) -> String: return String(n.name))
	_check(parts.has("Rider") and parts.has("LegFL") and parts.has("LegBR"), "części: %s" % str(parts))
	var crossbows := kn.knights().filter(func(k: Knight) -> bool: return k.crossbow).size()
	_check(crossbows == Knights.PATROLS.size(), "kusznik w każdym patrolu (%d)" % crossbows)
	var start := k0.global_position
	await _seconds(2.0)
	var moved := k0.global_position.distance_to(start)
	_check(moved > 2.0 and moved < 10.0, "patrol jedzie drogą (%.1f m w 2 s)" % moved)
	var gap := kn.knights()[0].global_position.distance_to(kn.knights()[1].global_position)
	_check(gap > 4.0 and gap < 10.0, "szyk: odstęp %.1f m" % gap)

	print("2) Pisklę przy patrolu — szarża z włócznią")
	_p.stats.set_size_instant(1.5)
	var hits := []
	kn.attacked.connect(func(_by: Knight, d: float) -> void: hits.append(d))
	world.call("teleport_to_knights")
	var hp := _p.stats.health
	var engaged := false
	for i in 120:
		await _seconds(0.25)
		_p.stats.health = maxf(_p.stats.health, 40.0)  # nie umieraj w teście
		for k in kn.knights():
			if k.mode == Knight.Mode.ENGAGE:
				engaged = true
		if hits.size() > 0:
			break
	_check(engaged, "rycerze ruszają na smoka")
	await _shot("knights_charge.png")
	_check(hits.size() > 0, "trafienie (włócznia / bełt), zdrowie %.0f -> %.0f" % [hp, _p.stats.health])

	print("3) Dorosły smok — tchórze uciekają, reszta walczy")
	_p.stats.set_size_instant(12.0)
	await _seconds(1.5)
	var near := kn.knights().filter(func(k: Knight) -> bool: return k.mode == Knight.Mode.ENGAGE)
	var panicking := near.filter(func(k: Knight) -> bool: return k.panic)
	var fighting := near.filter(func(k: Knight) -> bool: return not k.panic)
	_check(panicking.size() > 0 and fighting.size() > 0,
		"w panice %d, walczy %d (z %d)" % [panicking.size(), fighting.size(), near.size()])
	print("4) Pradawny — uciekają wszyscy poza kusznikami")
	_p.stats.set_size_instant(17.0)
	await _seconds(1.0)
	var bad := near.filter(func(k: Knight) -> bool:
		return is_instance_valid(k) and k.is_alive() and k.panic == k.crossbow)
	_check(bad.is_empty(), "rycerze uciekają, kusznicy zostają (%d wyjątków)" % bad.size())
	await _shot("knights_panic.png")

	print("5) Zabity rycerz — sakiewka i rozgłos")
	var finds: GoldFinds = world.get_node("GoldFinds")
	var renown: float = world.get("renown")
	var victim: Knight = near[0]
	victim.burn(100.0)
	await _frames(3)
	_check(not victim.is_alive() and victim.is_edible(), "upieczony rycerz jadalny")
	var loot := finds.remaining().filter(func(f: Node3D) -> bool: return String(f.name).begins_with("loot_"))
	_check(loot.size() > 0, "sakiewka na ziemi")
	_check(float(world.get("renown")) > renown, "rozgłos rośnie (%.1f -> %.1f)" % [renown, world.get("renown")])

	print("6) Oddział pościgowy z zamku")
	_p.stats.set_size_instant(6.0)
	_p.global_position = Vector3(0, 0.5, 0)
	_p.reset_physics_interpolation()
	var before := kn.knights().size()
	kn.send_hunt()
	var hunt := kn.knights().filter(func(k: Knight) -> bool: return k.is_hunter())
	_check(kn.knights().size() == before + Knights.HUNT_SIZE and hunt.size() == Knights.HUNT_SIZE,
		"oddział: %d rycerzy" % hunt.size())
	var h0: Knight = hunt[0]
	var d0 := h0.global_position.distance_to(_p.global_position)
	await _seconds(4.0)
	var d1 := h0.global_position.distance_to(_p.global_position)
	_check(d1 < d0 - 10.0, "jedzie na smoka (%.0f -> %.0f m)" % [d0, d1])
	world.set("renown", 0.0)
	kn.repopulate(0)
	await _frames(2)
	_check(kn.knights().size() == expected, "nowy dzień: same patrole (%d)" % kn.knights().size())

	print("7) Zrzut z bliska")
	_p.stats.set_size_instant(3.0)
	_p.global_position = Vector3(0, 0.5, 40)
	_p.rotation.y = PI
	_p.reset_physics_interpolation()
	for k in kn.knights():
		k.set_physics_process(false)
	var a: Knight = kn.knights()[0]
	a.global_position = Vector3(-3, 0, 28)
	a.rotation.y = PI * 0.7
	a.mode = Knight.Mode.ENGAGE
	a._speed = a.gallop_speed
	a._phase = 1.0
	for i in 10:
		a._animate(0.05)
	var b: Knight = kn.knights().filter(func(k: Knight) -> bool: return k.crossbow)[0]
	b.global_position = Vector3(4, 0, 27)
	b.rotation.y = -PI * 0.75
	b.mode = Knight.Mode.ENGAGE
	b._speed = 0.0
	for i in 10:
		b._animate(0.05)
	var c: Knight = kn.knights()[1]
	c.global_position = Vector3(0.5, 0, 22)
	c.rotation.y = -PI * 0.5
	c.mode = Knight.Mode.PATROL
	c._speed = 2.4
	for i in 10:
		c._animate(0.05)
	cam.snap_behind()
	await _seconds(1.0)
	await _shot("knights_close.png")

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
