extends SceneTree
## Test legowiska: nowa gra (wyklucie z jaja w jaskini), wyjście z jaskini, sen (nowy dzień,
## leczenie, zapis), wczytanie zapisu, łagodna śmierć (budzisz się w legowisku, wzrost zostaje).
## UWAGA: kasuje zapis gry (user://save.json).
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_lair.gd -- [katalog_na_zrzuty]

var _fails := 0
var _out := ""


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	SaveGame.delete()

	print("1) Nowa gra: wyklucie w jaskini")
	var world := _spawn_world()
	await _frames(5)
	var player: DragonController = world.get_node("DragonPlayer")
	var lair: Lair = world.get_node("Lair")
	_check(not player.visible, "na początku jest tylko jajo")
	_check(player.global_position.distance_to(lair.nest_position()) < 0.5, "pisklę startuje w gnieździe")
	await _shot("lair_egg.png")
	await _seconds(4.5)
	_check(player.visible, "pisklę się wykluło")
	_check(SaveGame.exists(), "zapis po wykluciu")
	await _shot("lair_hatched.png")

	print("2) Kolizja jaskini: ściana zatrzymuje smoka")
	player.rotation.y = PI  # w głąb komory (od wyjścia)
	Input.action_press("move_forward")
	Input.action_press("dash")
	await _seconds(6.0)
	Input.action_release("move_forward")
	Input.action_release("dash")
	var d := player.global_position - lair.global_position
	_check(Vector2(d.x, d.z).length() < Lair.SLEEP_RADIUS + 3.0, "nie przeszedł przez ścianę (%.1f m od gniazda)" % Vector2(d.x, d.z).length())

	print("2b) Noc")
	var dn: DayNight = world.get_node("DayNight")
	dn.set_hour(22.5)
	var sun: DirectionalLight3D = world.get_node("Sun")
	_check(dn.is_night() and sun.light_energy < 0.5, "noc: ciemniej (światło %.2f)" % sun.light_energy)

	print("3) Sen: nowy dzień, leczenie, zapis")
	player.global_position = lair.nest_position()
	player.reset_physics_interpolation()
	player.stats.health = 40.0
	player.stats.set_size_instant(2.5)
	await _frames(3)
	_check(world.can_sleep(), "w komorze można spać (przycisk ŚPIJ)")
	world.sleep()
	await _seconds(3.5)
	_check(world.day == 2, "dzień %d" % world.day)
	_check(absf(dn.hour - 7.0) < 0.1, "sen przewija do rana (%s)" % dn.clock_text())
	_check(not dn.is_night(), "po śnie jest dzień")
	_check(player.stats.health >= 99.0, "zdrowie odnowione (%.0f)" % player.stats.health)
	var data := SaveGame.load_data()
	_check(int(data.get("day", 0)) == 2, "zapis: dzień %s" % str(data.get("day")))

	print("4) Poza jaskinią nie można spać")
	dn.set_hour(21.5)  # nocne ujęcie legowiska
	player.global_position = Lair.POSITION + Vector3(0, 0, 70)
	player.reset_physics_interpolation()
	await _frames(3)
	_check(not world.can_sleep(), "na łące brak przycisku ŚPIJ")
	player.rotation.y = PI  # pyskiem do legowiska
	world.get_node("FollowCamera").snap_behind()
	await _seconds(1.5)
	await _shot("lair_night.png")
	dn.set_hour(12.0)
	await _seconds(0.3)
	await _shot("lair_outside.png")
	dn.set_hour(19.3)
	await _seconds(0.3)
	await _shot("lair_dusk.png")
	world.save_game()

	print("5) Wczytanie zapisu")
	world.queue_free()
	await _frames(3)
	world = _spawn_world()
	await _frames(5)
	player = world.get_node("DragonPlayer")
	_check(world.day == 2, "dzień po wczytaniu: %d" % world.day)
	_check(absf((world.get_node("DayNight") as DayNight).hour - 19.3) < 0.2, "godzina po wczytaniu")
	_check(absf(player.stats.size - 2.5) < 0.05, "rozmiar po wczytaniu: %.2f m" % player.stats.size)
	_check(player.visible, "bez intro przy wczytaniu")
	_check(player.global_position.distance_to(Lair.POSITION + Vector3(0, 0, 70)) < 2.0, "pozycja z zapisu")

	print("6) Łagodna śmierć: budzisz się w legowisku, wzrost zostaje")
	player.stats.damage(1000.0)
	await _frames(3)
	lair = world.get_node("Lair")
	_check(player.global_position.distance_to(lair.nest_position()) < 1.0, "odrodzenie w gnieździe")
	_check(absf(player.stats.size - 2.5) < 0.05, "rozmiar zachowany (%.2f m)" % player.stats.size)

	SaveGame.delete()
	print("WYNIK: ", "OK" if _fails == 0 else "%d błędów" % _fails)
	quit(1 if _fails else 0)


func _spawn_world() -> Node:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	return world


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
