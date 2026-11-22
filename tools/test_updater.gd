extends SceneTree
## Test aktualizatora (z lokalnym serwerem, DRAGON_UPDATE_API):
##   faza "download": wykrycie nowszej wersji, pobranie łatki do user://
##   faza "boot":     ponowne uruchomienie — boot wczytuje łatkę, HUD pokazuje nową wersję

func _init() -> void:
	var phase: String = OS.get_cmdline_user_args()[0]
	var expect: String = OS.get_cmdline_user_args()[1]
	root.add_child(load("res://scenes/boot.tscn").instantiate())
	for i in 30:
		await process_frame
	var world := current_scene if current_scene else root.get_child(root.get_child_count() - 1)
	var ok := false
	if phase == "download":
		var updater: Control = world.get_node("HUD/Updater")
		for i in 100:
			await create_timer(0.1).timeout
			if updater.get_node("Panel").visible:
				break
		print("panel: ", updater.get_node("Panel/VBox/Label").text)
		updater.get_node("Panel/VBox/Button").emit_signal("pressed")
		for i in 100:
			await create_timer(0.1).timeout
			if FileAccess.file_exists(GameVersion.PATCH_PATH):
				break
		await create_timer(0.3).timeout
		var v := FileAccess.get_file_as_string(GameVersion.PATCH_VERSION_PATH).strip_edges()
		print("po pobraniu: ", updater.get_node("Panel/VBox/Label").text, " | zapisana wersja: ", v)
		ok = FileAccess.file_exists(GameVersion.PATCH_PATH) and v == expect
	else:
		var label: Label = world.get_node("HUD/Version")
		print("wersja w HUD: ", label.text, " | GameVersion.current(): ", GameVersion.current())
		ok = label.text == "v" + expect and GameVersion.current() == expect
	print("WYNIK: ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)
