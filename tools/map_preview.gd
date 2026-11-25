extends SceneTree
## Podgląd mapy z góry: cieniowana wysokość + kolory terenu, wioski, zamek, legowisko.
## Użycie: godot --headless --path . --script res://tools/map_preview.gd -- out.png [rozdzielczość] [x0 z0 rozmiar]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "build/map.png"
	var res := int(args[1]) if args.size() > 1 else 512
	var x0 := float(args[2]) if args.size() > 4 else -Terrain.HALF
	var z0 := float(args[3]) if args.size() > 4 else -Terrain.HALF
	var size := float(args[4]) if args.size() > 4 else Terrain.SIZE
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	var step := size / res
	var light := Vector3(-1, 2, -1).normalized()
	for j in res:
		for i in res:
			var x := x0 + (i + 0.5) * step
			var z := z0 + (j + 0.5) * step
			var h := Terrain.height(x, z)
			var hx := Terrain.height(x + step, z)
			var hz := Terrain.height(x, z + step)
			var n := Vector3(h - hx, step, h - hz).normalized()
			var col: Color
			if h < Terrain.WATER_LEVEL:
				col = Color(0.2, 0.45, 0.75)
			else:
				col = Terrain._face_color(x, z, h, n.y)
			col = col * clampf(0.45 + 0.75 * n.dot(light), 0.25, 1.3)
			img.set_pixel(i, j, Color(col.r, col.g, col.b))
	img.save_png(out)
	print("mapa: ", out)
	quit()
