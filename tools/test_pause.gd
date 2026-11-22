extends SceneTree
## Test menu pauzy i okienka trybu deweloperskiego (zmiana stadium, reset wzrostu).
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_pause.gd -- [katalog_na_zrzuty]

var _fails := 0
var _out := ""


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.set("use_save", false)  # piaskownica: bez zapisu i intro, start na łące
	root.add_child(world)
	await _frames(10)
	var player: DragonController = world.get_node("DragonPlayer")
	var stats := player.stats
	var menu: PauseMenu = world.get_node("PauseMenu")
	var dev_before: bool = menu._dev_toggle.button_pressed

	print("1) Pauza")
	menu.open()
	await _frames(3)
	_check(paused, "gra zatrzymana")
	var pos := player.global_position
	await _frames(10)
	_check(player.global_position == pos, "smok stoi w czasie pauzy")
	menu._dev_toggle.button_pressed = true  # emituje toggled -> pokazuje okienko i zapisuje
	await _frames(3)
	_check(menu._dev_panel.visible, "tryb deweloperski włączony")
	await _shot("pause_menu.png")
	menu.close()
	await _frames(3)
	_check(not paused, "wznowiono")

	print("2) Okienko dewelopera: stadia i reset")
	var names := DragonStats.STAGE_NAMES
	for i in names.size():
		menu._set_stage(i)
		await _frames(5)
		_check(stats.stage == i, "%s -> stadium %s (%.1f m)" % [names[i], stats.stage_name(), stats.size])
	_check(stats.can_fly(), "Pradawny lata")
	await _seconds(1.0)
	await _shot("dev_panel.png")
	menu._reset_growth()
	await _frames(5)
	_check(stats.stage == DragonStats.Stage.HATCHLING and absf(stats.size - stats.start_size) < 0.01,
		"reset wzrostu -> %s %.1f m" % [stats.stage_name(), stats.size])
	_check(not stats.can_fly(), "pisklę po resecie nie lata")
	_check(stats.pending_growth == 0.0, "bez zaległego wzrostu")

	menu._dev_toggle.button_pressed = dev_before  # przywróć zapisane ustawienie
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
	await create_timer(s, true).timeout


func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out + "/" + name)
	print("  zrzut: ", _out + "/" + name)
