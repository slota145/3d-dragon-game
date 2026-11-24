extends SceneTree
## Test ognia (faza 7): pisklę bez ognia; młodzik — kula ognia (odnowienie, pieczeń do zjedzenia,
## podpalenie chaty → zgliszcza, rozgłos); dorosły — strumień ognia; odbudowa po nocy.
## Użycie: xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_fire.gd -- [katalog_na_zrzuty]

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
	var fire_btn: TouchActionButton = world.get_node("HUD/FireButton")
	var balls := [0]
	player.fire.breathed.connect(func() -> void: balls[0] += 1)

	print("1) Pisklę: bez ognia")
	_check(fire_btn.locked, "przycisk Ogień zablokowany")
	_press("fire")
	await _frames(3)
	_release("fire")
	_check(balls[0] == 0, "pisklę nie zieje")

	print("2) Młodzik: kula ognia piecze człowieka; pieczeń można zjeść")
	player.stats.set_size_instant(5.0)
	world.call("_update_buttons")
	await _frames(2)
	_check(not fire_btn.locked and fire_btn.label == "OGIEŃ", "przycisk odblokowany (%s)" % fire_btn.label)
	var man: Villager = vil.residents().filter(func(r: Node3D) -> bool: return r is Villager)[0]
	man.active_range = 0.0  # stoi w miejscu
	_aim_at(player, man.global_position, 14.0)
	cam.snap_behind()
	await _frames(3)
	_press("fire")
	await _frames(2)
	_release("fire")
	_check(balls[0] == 1, "kula ognia wystrzelona")
	_check(player.fire.readiness < 0.5, "odnawianie (%.2f)" % player.fire.readiness)
	await _seconds(0.25)
	await _shot("fire_ball.png")
	man.max_health = 2.0
	await _seconds(1.2)
	if man.is_alive():  # druga kula po odnowieniu
		await _seconds(1.2)
		_press("fire")
		await _frames(2)
		_release("fire")
		await _seconds(1.5)
	_check(not man.is_alive() and man.roasted, "człowiek upieczony")
	var hunger0 := player.stats.hunger
	player.stats.hunger = 30.0
	_aim_at(player, man.global_position, 3.5)
	await _frames(3)
	_press("bite")
	await _frames(3)
	_release("bite")
	await _seconds(1.8)
	_check(player.stats.hunger > 30.0, "pieczeń zjedzona (najedzenie %.0f)" % player.stats.hunger)

	print("3) Podpalenie chaty")
	var cottage: MeshInstance3D = null
	for n in world.get_tree().get_nodes_in_group("flammable"):
		if n is MeshInstance3D and String((n as MeshInstance3D).mesh.resource_name).find("Cottage") >= 0:
			cottage = n
			break
	if cottage == null:
		cottage = world.get_tree().get_nodes_in_group("flammable")[0]
	var r0: float = world.renown
	_aim_at(player, cottage.global_position + Vector3.UP * 2.0, 22.0)
	cam.snap_behind()
	await _seconds(2.5)
	_press("fire")
	await _frames(2)
	_release("fire")
	await _seconds(2.0)
	_check(not cottage.is_in_group("flammable") and cottage.get_node_or_null("Fire") != null, "chata płonie")
	await _shot("fire_cottage.png")
	await _seconds(Villages.BURN_TIME)
	_check(cottage.material_overlay != null, "zgliszcza po pożarze")
	_check(world.renown > r0 + 4.0, "rozgłos za spalenie (%.1f -> %.1f)" % [r0, world.renown])

	print("4) Dorosły: strumień ognia")
	player.stats.set_size_instant(12.0)
	world.call("_update_buttons")
	_check(fire_btn.label == "STRUMIEŃ", "przycisk: %s" % fire_btn.label)
	var flock := vil.residents().filter(func(r: Node3D) -> bool: return r is Prey and (r as Prey).species == "sheep")
	print("   owiec: %d, żywych: %d" % [flock.size(), flock.filter(func(r: Node3D) -> bool: return (r as Prey).is_alive()).size()])
	var sheep: Prey = flock.filter(func(r: Node3D) -> bool: return (r as Prey).is_alive())[0]
	sheep.max_health = 3.0
	_aim_at(player, sheep.global_position, 9.0)
	cam.snap_behind()
	await _frames(3)
	_press("fire")
	await _seconds(1.0)
	_check(player.fire.streaming and player.jaw_open > 0.5, "zieje strumieniem, pysk otwarty (%.2f)" % player.jaw_open)
	await _shot("fire_stream.png")
	await _seconds(1.5)
	_release("fire")
	await _frames(3)
	_check(not sheep.is_alive(), "owca upieczona strumieniem")
	_check(not player.fire.streaming and player.fire.readiness < 1.0, "po strumieniu odpoczynek")

	print("4b) Celowanie: głowa za kamerą, pomoc w celowaniu")
	player.global_position = Vector3(0, 0.2, 0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	cam.snap_behind()
	cam.set("_yaw", PI + deg_to_rad(50.0))  # kamera patrzy 50° w lewo od smoka
	await _seconds(1.0)
	var fd := player.fire_direction()
	var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	var ang := rad_to_deg(fwd.signed_angle_to(Vector3(fd.x, 0, fd.z).normalized(), Vector3.UP))
	_check(ang > 30.0, "ogień leci tam, gdzie kamera (%.0f° od dzioba)" % ang)
	_check(player.get("_head_yaw") > 0.4, "głowa obrócona (%.2f rad)" % player.get("_head_yaw"))
	await _shot("aim_head.png")
	# cel prawie na środku ekranu -> pomoc w celowaniu go łapie
	var target_sheep: Prey = null
	for r in vil.residents():
		if r is Prey and (r as Prey).species == "sheep" and (r as Prey).is_alive():
			target_sheep = r
			break
	var aim_fwd := player.fire_direction()
	target_sheep.global_position = player.mouth_position() + Vector3(aim_fwd.x, 0, aim_fwd.z).normalized() * 25.0 + Vector3.RIGHT.rotated(Vector3.UP, cam.rotation.y) * 2.0
	target_sheep.global_position.y = Terrain.height(target_sheep.global_position.x, target_sheep.global_position.z)
	target_sheep.home_radius = 0.0
	target_sheep.set_physics_process(false)
	await _seconds(0.5)
	_check(player.aim_target == target_sheep, "pomoc w celowaniu złapała owcę (cel: %s)" % (player.aim_target.get("display_name") if player.aim_target else "brak"))
	await _shot("aim_lock.png")

	print("5) Odbudowa")
	vil.rebuild()
	await _frames(3)
	_check(cottage.is_in_group("flammable") and cottage.material_overlay == null, "chata odbudowana")

	print("WYNIK: ", "OK" if _fails == 0 else "%d błędów" % _fails)
	quit(1 if _fails else 0)


## Ustaw smoka w odległości `dist` od celu, pyskiem do niego.
func _aim_at(player: DragonController, target: Vector3, dist: float) -> void:
	var dir := Vector3(1, 0, 0.4).normalized()
	var p := target - dir * dist
	p.y = Terrain.height(p.x, p.z) + 0.2
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.rotation.y = atan2(dir.x, dir.z)
	player.reset_physics_interpolation()


func _press(action: String) -> void:
	Input.action_press(action)


func _release(action: String) -> void:
	Input.action_release(action)


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
