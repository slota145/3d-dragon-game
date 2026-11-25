extends SceneTree
## Test dużego świata: teren z kawałków (LOD, kolizja wokół smoka), jezioro, rzeka, las, góry
## z legowiskiem; doczytywanie kawałków po przeniesieniu smoka daleko; zrzuty z lotu ptaka.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_world.gd -- [katalog_na_zrzuty]

var _fails := 0
var _out := ""


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var t0 := Time.get_ticks_msec()
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.set("use_save", false)
	root.add_child(world)
	print("  budowa świata: %d ms" % (Time.get_ticks_msec() - t0))
	await _frames(5)
	var player: DragonController = world.get_node("DragonPlayer")
	var terrain: Terrain = world.get_node("Terrain")

	print("1) Teren")
	_check(absf(Terrain.height(0, 0)) < 0.01 and absf(Terrain.height(40, -30)) < 0.05, "łąka startowa płaska (y=0)")
	_check(absf(Terrain.height(Lair.POSITION.x + 30, Lair.POSITION.z)) < 0.2, "plac pod legowiskiem płaski")
	_check(Terrain.height(0, -700) > 100.0, "góry na północy (%.0f m)" % Terrain.height(0, -700))
	_check(Terrain.is_water(Terrain.LAKE_CENTER.x, Terrain.LAKE_CENTER.y), "jezioro")
	var rv: Vector2 = Terrain.RIVER[3]
	_check(Terrain.is_water(rv.x, rv.y), "rzeka")
	_check(Terrain.forest(-500, 100) > 0.4, "las na zachodzie (%.2f)" % Terrain.forest(-500, 100))
	var c0 := terrain.chunk_of(player.global_position)
	_check(terrain.has_collision(c0) and terrain.lod_of(c0) == 0, "kolizja i pełny LOD pod smokiem")
	_check(terrain.lod_of(Vector2i(0, 0)) >= 2, "daleki kawałek w niskim LOD")
	await _seconds(1.0)
	_check(player.global_position.y > -0.5 and player.is_on_floor(), "smok stoi na terenie (y=%.2f)" % player.global_position.y)

	print("2) Smok na wzgórzach daleko od startu")
	var far := Vector3(-420.0, 0.0, 380.0)
	far.y = Terrain.height(far.x, far.z) + 3.0
	player.global_position = far
	player.reset_physics_interpolation()
	await _frames(20)
	var cf := terrain.chunk_of(far)
	_check(terrain.has_collision(cf), "kolizja doczytana w nowym miejscu")
	await _seconds(1.5)
	_check(player.global_position.y > Terrain.height(player.global_position.x, player.global_position.z) - 0.5,
		"nie przeleciał przez teren (y=%.1f, teren %.1f)" % [player.global_position.y, Terrain.height(far.x, far.z)])
	Input.action_press("move_forward")
	await _seconds(2.0)
	Input.action_release("move_forward")
	_check(player.is_on_floor(), "chodzi po zboczu")

	print("2b) Świat 4×4 km")
	_check(Terrain.SIZE >= 4096.0, "rozmiar świata %.0f m" % Terrain.SIZE)
	for lk: Array in Terrain.LAKES:
		_check(Terrain.is_water(lk[0], lk[1]), "jezioro w (%.0f, %.0f)" % [lk[0], lk[1]])
	_check(Terrain.height(0, -1700) < Terrain.height(0, -700), "za górami wyżyna (%.0f m)" % Terrain.height(0, -1700))

	print("2b1) Rzeźba terenu: płaskowyże, kanion, wodospady, turnie")
	for m: Array in Terrain.MESAS:
		var top := Terrain.height(m[0], m[1])
		var foot := Terrain.height(m[0] + m[2] * 1.4, m[1])
		_check(top > foot + 25.0, "płaskowyż (%.0f, %.0f): szczyt %.0f m, podnóże %.0f m" % [m[0], m[1], top, foot])
	var river: Array = Terrain.RIVERS[2]
	var mid: Vector2 = river[5]
	_check(Terrain.is_water(mid.x, mid.y), "rzeka w kanionie")
	var rim: Vector2 = mid + ((river[6] as Vector2) - (river[4] as Vector2)).normalized().orthogonal() * 80.0
	_check(Terrain.height(rim.x, rim.y) > Terrain.HIGHLAND_TOP - 8.0, "ściana kanionu: %.0f m nad rzeką" % Terrain.height(rim.x, rim.y))
	var lf: Landforms = world.get_node("Landforms")
	_check(lf.waterfalls().size() == Landforms.WATERFALLS.size(), "wodospady: %d" % lf.waterfalls().size())
	for w: Dictionary in lf.waterfalls():
		_check(float(w["height"]) > 15.0, "wodospad spada %.0f m" % w["height"])
	_check(lf.spires().size() >= 12, "turnie: %d" % lf.spires().size())
	var sp: Vector3 = lf.spires()[0]
	var hit: Dictionary = (world as Node3D).get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		sp + Vector3(30, 8, 0), sp + Vector3(-30, 8, 0)))
	_check(not hit.is_empty(), "turnia ma kolizję")

	print("2b2) Drogi i mosty")
	var roads: Roads = world.get_node("Roads")
	var bridges := roads.get_children().filter(func(n: Node) -> bool: return not String(n.name).begins_with("Road_"))
	_check(roads.get_child_count() >= Terrain.ROAD_PAIRS.size(), "drogi: %d" % Terrain.ROAD_PAIRS.size())
	_check(bridges.size() > 0, "mosty nad rzekami: %d przęseł" % bridges.size())
	var through_fields := 0
	for r in Terrain.ROAD_PAIRS.size():
		for p in Terrain.road_points(r):
			if Terrain.field_parcel(p.x, p.y).x >= 0 and Terrain.farmland(p.x, p.y) > 0.05:
				through_fields += 1
	_check(through_fields == 0, "drogi nie biegną przez pola (%d punktów)" % through_fields)

	print("2c) Ciekawe miejsca")
	var lm: Landmarks = world.get_node("Landmarks")
	_check(lm.total() >= 25, "rozstawione: %d" % lm.total())
	var kinds := {}
	for p: Dictionary in lm.places():
		kinds[p["kind"]] = true
	_check(kinds.size() == 5, "wszystkie rodzaje: %s" % str(kinds.keys()))
	var near := 0
	for p: Dictionary in lm.places():
		if Vector2((p["pos"] as Vector3).x, (p["pos"] as Vector3).z).length() < 500.0:
			near += 1
	_check(near >= 4, "blisko łąki (do 500 m): %d" % near)
	var finds: GoldFinds = world.get_node("GoldFinds")
	var chests := finds.remaining().filter(func(f: Node3D) -> bool: return f.get_meta("cache", false))
	_check(chests.size() >= lm.total(), "skrzynie przy miejscach i słupach: %d" % chests.size())
	var first: Dictionary = lm.places()[0]
	var fp: Vector3 = first["pos"]
	var events := []
	lm.discovered.connect(func(label: String, c: int, t: int) -> void: events.append(label))
	player.global_position = fp + Vector3(18, 0, 18)
	player.global_position.y = Terrain.height(player.global_position.x, player.global_position.z) + 1.0
	player.reset_physics_interpolation()
	await _seconds(0.8)
	_check(events.size() == 1 and first["id"] in lm.found, "odkrycie: %s" % str(events))

	print("3) Zrzuty z lotu ptaka")
	var by_kind := {}
	for p: Dictionary in lm.places():
		if not by_kind.has(p["kind"]):
			by_kind[p["kind"]] = p
	player.stats.set_size_instant(8.0)
	var cam0: FollowCamera = world.get_node("FollowCamera")
	for kind: String in by_kind:
		var lp: Vector3 = by_kind[kind]["pos"]
		player.global_position = lp + Vector3(0, 30, 70)
		player.rotation.y = PI
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		cam0.snap_behind()
		await _seconds(1.2)
		await _shot("landmark_%s.png" % kind)
	player.stats.set_size_instant(14.0)
	var cam: FollowCamera = world.get_node("FollowCamera")
	for shot: Array in [["world_lair.png", Vector3(0, 70, 120), PI], ["world_lake.png", Vector3(250, 90, 60), 2.3],
			["world_forest.png", Vector3(-250, 80, 250), -2.2], ["world_meadow.png", Vector3(0, 4, 60), 0.0]]:
		player.global_position = shot[1]
		player.rotation.y = shot[2]
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		cam.snap_behind()
		await _seconds(1.2)
		await _shot(shot[0])

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
