extends SceneTree
## Robi zrzut ekranu sceny (do weryfikacji wizualnej przez agenta/CI).
## Użycie: tools/screenshot.sh [res://scena.tscn] [plik.png] [klatki]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/main.tscn"
	var out_path: String = args[1] if args.size() > 1 else "user://screenshot.png"
	var frames: int = int(args[2]) if args.size() > 2 else 30

	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_error("Nie można wczytać sceny: %s" % scene_path)
		quit(1)
		return
	root.add_child(scene.instantiate())

	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_viewport().get_texture().get_image()
	var err := image.save_png(out_path)
	if err != OK:
		push_error("Zapis nie powiódł się: %s" % out_path)
		quit(1)
		return
	print("Zrzut zapisany: ", ProjectSettings.globalize_path(out_path))
	quit(0)
