extends SceneTree
## Test wiosek i ludzi: zabudowa, mieszkańcy, reakcja wg wielkości smoka (pisklę = dźganie
## widłami, młodzik = ostrożność, dorosły = panika), zjedzenie człowieka, owce w zagrodzie.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_village.gd -- [katalog_na_zrzuty]

var _fails := 0
var _out := ""


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.set("use_save", false)
	root.add_child(world)
	await _frames(5)
	var player: DragonController = world.get_node("DragonPlayer")
	var vil: Villages = world.get_node("Villages")
	var cam: FollowCamera = world.get_node("FollowCamera")

	print("1) Wioski")
	_check(vil.get_child_count() >= Terrain.VILLAGES.size(), "wioski: %d" % Terrain.VILLAGES.size())
	for i in Terrain.VILLAGES.size():
		var c := vil.center(i)
		_check(Terrain.is_walkable(c.x, c.z), "wioska %d na suchym, płaskim terenie (y=%.1f)" % [i, c.y])
	var people := vil.residents().filter(func(r: Node3D) -> bool: return r is Villager)
	var sheep := vil.residents().filter(func(r: Node3D) -> bool: return not r is Villager)
	_check(people.size() >= Terrain.VILLAGES.size() * 5, "mieszkańcy: %d" % people.size())
	_check(sheep.size() >= Terrain.VILLAGES.size() * 4, "owce w zagrodach: %d" % sheep.size())

	# wioska 0 i jej mieszkaniec
	var c0 := vil.center(0)
	var man: Villager = null
	for p: Villager in people:
		if p.home.distance_to(c0) < 1.0:
			man = p
			break
	var pos0 := man.global_position

	print("2) Pisklę: wieśniak przegania je widłami")
	player.stats.set_size_instant(1.0)
	player.stats.health = 100.0
	player.global_position = pos0 + Vector3(6, 0.5, 0)
	player.reset_physics_interpolation()
	await _seconds(4.0)
	_check(man.mood == Villager.Mood.BOLD, "wieśniak odważny wobec pisklęcia")
	_check(player.stats.health < 100.0, "dźga widłami (zdrowie %.0f)" % player.stats.health)
	player.rotation.y = atan2(man.global_position.x - player.global_position.x, man.global_position.z - player.global_position.z) + PI
	cam.snap_behind()
	await _seconds(0.6)
	await _shot("village_hatchling.png")

	print("3) Młodzik: wieśniacy się cofają")
	player.stats.set_size_instant(5.0)
	player.stats.health = 100.0
	man.global_position = pos0
	player.global_position = pos0 + Vector3(14, 0.5, 0)
	player.reset_physics_interpolation()
	await _seconds(1.0)
	var d1 := Vector2(man.global_position.x - player.global_position.x, man.global_position.z - player.global_position.z).length()
	await _seconds(1.5)
	var d2 := Vector2(man.global_position.x - player.global_position.x, man.global_position.z - player.global_position.z).length()
	_check(man.mood == Villager.Mood.WARY and d2 > d1, "ostrożny, oddala się (%.1f -> %.1f m)" % [d1, d2])

	print("4) Dorosły: panika")
	player.stats.set_size_instant(11.0)
	man.global_position = pos0
	player.global_position = pos0 + Vector3(40, 0.5, 0)
	player.reset_physics_interpolation()
	await _seconds(1.5)
	_check(man.mood == Villager.Mood.PANIC, "panika przed dorosłym smokiem")
	player.global_position = c0 + Vector3(0, 45, 75)
	player.rotation.y = PI
	player.reset_physics_interpolation()
	cam.snap_behind()
	await _seconds(1.2)
	await _shot("village_panic.png")

	print("5) Zjedzenie człowieka")
	var h0 := player.stats.hunger
	player.stats.hunger = 20.0
	player.global_position = man.global_position - Vector3(0, 0, 4.0)
	player.rotation.y = 0.0
	player.reset_physics_interpolation()
	man.health = 0.01
	await _frames(2)
	Input.action_press("bite")
	await _frames(3)
	Input.action_release("bite")
	await _seconds(2.0)
	_check(not is_instance_valid(man) or not man.is_alive(), "człowiek zjedzony")
	_check(player.stats.hunger > 20.0, "najedzony (%.0f)" % player.stats.hunger)

	print("6) Owce zostają w zagrodzie")
	var pen := vil.pen_center(0)
	var inside := true
	for s: Prey in sheep:
		if s.home.distance_to(pen) < 1.0 and s.is_alive():
			inside = inside and Vector2(s.global_position.x - pen.x, s.global_position.z - pen.z).length() < 10.0
	_check(inside, "owce w obrębie płotu")

	print("7) Rozgłos i myśliwi")
	var r0: float = world.renown
	_check(r0 > 0.0, "rozgłos rośnie od zjedzenia człowieka i straszenia (%.1f)" % r0)
	_check(vil.hunters().is_empty() or world.renown_level() >= 1, "bez rozgłosu brak myśliwych")
	world.add_renown(30.0)
	await _frames(3)
	var hunters := vil.hunters()
	_check(world.renown_level() >= 1 and hunters.size() >= Terrain.VILLAGES.size(), "rozgłos „Plotka”: myśliwi %d" % hunters.size())
	var hunter: Villager = null
	for h: Villager in hunters:
		if h.home.distance_to(c0) < 1.0:
			hunter = h
			break
	player.stats.set_size_instant(6.0)
	player.stats.health = 100.0
	player.velocity = Vector3.ZERO
	player.global_position = hunter.global_position + Vector3(0, 0.5, 40)
	player.rotation.y = 0.0
	player.reset_physics_interpolation()
	var hits := [0]
	player.hit_by_arrow.connect(func(_d: float) -> void: hits[0] += 1)
	cam.snap_behind()
	await _seconds(1.5)
	player.rotation.y = PI
	cam.snap_behind()
	await _seconds(1.0)
	await _shot("village_hunter.png")
	await _seconds(6.0)
	_check(hits[0] >= 1, "myśliwy trafia strzałami (%d trafień, zdrowie %.0f)" % [hits[0], player.stats.health])
	player.global_position = hunter.global_position + Vector3(0, 0.5, 5)
	player.reset_physics_interpolation()
	await _seconds(1.0)
	_check(hunter.mood == Villager.Mood.WARY or hunter.mood == Villager.Mood.PANIC, "z bliska myśliwy odskakuje")

	print("8) Danina i łupienie")
	world.add_renown(60.0)
	await _frames(3)
	var finds: GoldFinds = world.get_node("GoldFinds")
	var day: int = world.day
	var tid := "tribute_0_d%d" % day
	_check(world.renown_level() >= 2 and finds.has_node(tid), "„Postrach”: danina na kamieniu ofiarnym")
	var chest: Node3D = finds.get_node(tid)
	var val: int = chest.get_meta("value")
	player.stats.set_size_instant(6.0)
	player.stats.gold = 0
	player.velocity = Vector3.ZERO
	player.global_position = chest.global_position + Vector3(0, 0.3, 0)
	player.reset_physics_interpolation()
	await _seconds(0.6)
	_check(player.stats.gold >= val, "danina zebrana (+%d złota)" % player.stats.gold)
	# napaść na wioskę 1: spalenie chaty -> gniew (brak daniny) + łup
	var tid1 := "tribute_1_d%d" % day
	_check(finds.has_node(tid1), "wioska 1 też płaci")
	var house: MeshInstance3D = null
	for n in world.get_tree().get_nodes_in_group("flammable"):
		if vil.village_at((n as Node3D).global_position) == 1:
			house = n
			break
	vil.call("_ignite", house)
	await _seconds(Villages.BURN_TIME + 0.5)
	_check(int(world.village_angry_until[1]) >= day + 3, "wioska 1 wypowiada daninę (do dnia %d)" % world.village_angry_until[1])
	_check(not finds.has_node(tid1) or finds.get_node(tid1).is_queued_for_deletion(), "dzisiejsza danina wioski 1 zabrana")
	var loot := finds.remaining().filter(func(f: Node3D) -> bool: return String(f.name).begins_with("loot_"))
	_check(loot.size() >= 1, "łup ze spalonego budynku: %s" % (loot[0].get_meta("label") if loot.size() else "brak"))
	world.call("_place_tributes")
	_check(not finds.has_node("tribute_1_d%d" % day), "rozgniewana wioska nie płaci")

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
