extends SceneTree
## Widoki świata z wolnej kamery (bez HUD) — do oglądania terenu.
## Użycie: xvfb-run -a godot --path . --script res://tools/view_world.gd -- katalog "nazwa:x,y,z,yaw_deg,pitch_deg" ...
## Kamera patrzy w kierunku yaw (0 = −Z, północ; 90 = −X), pitch < 0 w dół.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.set("use_save", false)
	root.add_child(world)
	for i in 10:
		await process_frame
	var player: DragonController = world.get_node("DragonPlayer")
	player.set_physics_process(false)
	(world.get_node("HUD") as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.far = 4000.0
	world.add_child(cam)
	for k in range(1, args.size()):
		var parts := args[k].split(":")
		var v := parts[1].split(",")
		var pos := Vector3(float(v[0]), float(v[1]), float(v[2]))
		player.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z) + 2.0, pos.z)
		player.reset_physics_interpolation()
		cam.global_position = pos
		cam.rotation_degrees = Vector3(float(v[4]), float(v[3]), 0.0)
		cam.make_current()
		for f in 90:  # teren i roślinność dookoła
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("widok: ", parts[0])
	quit()
