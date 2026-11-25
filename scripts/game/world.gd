extends Node3D
## Świat: łączy gracza, kamerę, HUD i legowisko; zapis gry, sen, wyklucie (nowa gra).
## Testy ustawiają `use_save = false` przed dodaniem sceny: bez zapisu i intro, start na łące.

## false = piaskownica (testy): bez wczytywania/zapisu, bez intro, start na łące w (0, 0, 0).
@export var use_save: bool = true
## Autozapis co tyle sekund (oprócz snu i wyjścia z gry).
@export var autosave_interval: float = 60.0
## Ile najedzenia „zjada” noc snu.
@export var sleep_hunger_cost: float = 15.0

## Część niesionego złota tracona przy śmierci.
@export var death_gold_loss: float = 0.5

## Numer dnia (rośnie przy każdym śnie).
var day: int = 1
## Złoto na stosie w legowisku (skarb).
var treasure: int = 0
var _finds: GoldFinds
var _hoard: HoardMenu
var _gold_label: Label
var _lair: Lair
var _terrain: Terrain
var _decor: TerrainDecor
var _landmarks: Landmarks
var _villages: Villages
var _castle: Castle
var _gryphons: Gryphons
var _knights: Knights
var _riders: GryphonRiders
## Dowódca jeźdźców gryfów pokonany (zapis gry) — nie wraca.
var boss_defeated: bool = false
var _boss_seen: bool = false
var _armor_msg: int = -100000
var _boss_bar: Control
var _knight_msg: int = -100000
var _gryphon_msg: int = -100000
var _castle_seen: bool = false
## Rozgłos smoka 0..100: rośnie od zjadania ludzi i owiec z farm i straszenia wieśniaków,
## powoli opada (i przy śnie). Od poziomu „Plotka” wioski wystawiają myśliwych z łukami.
var renown: float = 0.0
const RENOWN_LEVELS := [0.0, 20.0, 50.0, 80.0]
const RENOWN_NAMES := ["Nieznany", "Plotka", "Postrach", "Legenda"]
var _renown_level: int = 0
## Do którego dnia (włącznie) wioska nie płaci daniny — po napaści smoka.
var village_angry_until: Array = [0, 0, 0, 0, 0, 0]
## Od tego poziomu rozgłosu („Postrach”) wioski składają daninę.
const TRIBUTE_LEVEL := 2
var _arrow_msg: int = -100000
var _loot_n: int = 0
var _poke_msg: int = -100000
var _day_night: DayNight
var _sleeping: bool = false
var _intro: bool = false
var _autosave_t: float = 0.0
var _fade: ColorRect
var _sleep_button: Button

@onready var _player: DragonController = $DragonPlayer
@onready var _camera: FollowCamera = $FollowCamera
@onready var _hud: CanvasLayer = $HUD
@onready var _spawner: PreySpawner = $Prey
var _spawn_point: Vector3


func _ready() -> void:
	_camera.target = _player
	_player.camera = _camera
	_player.joystick = _hud.get_node("Joystick")
	_terrain = Terrain.new()
	_terrain.name = "Terrain"
	add_child(_terrain)
	_decor = TerrainDecor.new()
	var decor := _decor
	decor.name = "TerrainDecor"
	decor.terrain = _terrain
	_terrain.add_child(decor)
	_landmarks = Landmarks.new()
	_landmarks.name = "Landmarks"
	_landmarks.dragon = _player
	add_child(_landmarks)
	_landmarks.discovered.connect(func(label: String, count: int, all: int) -> void:
		_banner("ODKRYTO: " + label.to_upper(), "Ciekawe miejsca: %d / %d · w pobliżu leży skarb" % [count, all])
		save_game())
	var landforms := Landforms.new()
	landforms.name = "Landforms"
	add_child(landforms)
	var roads := Roads.new()
	roads.name = "Roads"
	add_child(roads)
	_villages = Villages.new()
	_villages.name = "Villages"
	_villages.dragon = _player
	add_child(_villages)
	_castle = Castle.new()
	_castle.name = "Castle"
	_castle.dragon = _player
	_castle.villages = _villages
	add_child(_castle)
	_castle.repopulate()
	_castle.bolt_hit.connect(func(_d: float) -> void:
		_flash = 0.9
		if Time.get_ticks_msec() - _arrow_msg > 2500:
			_arrow_msg = Time.get_ticks_msec()
			_toast("Trafiony bełtem z balisty! Uważaj na czerwone linie celowania"))
	_castle.ballista_destroyed.connect(func(_b: Ballista) -> void:
		add_renown(6.0)
		var left := _castle.working_ballistas()
		_toast("Balista zniszczona! Zostało: %d" % left if left > 0 else "Wszystkie balisty zniszczone — skarbiec czeka!"))
	_castle.guard_eaten.connect(func(_g: Prey) -> void: add_renown(5.0))
	_riders = GryphonRiders.new()
	_riders.name = "GryphonRiders"
	_riders.dragon = _player
	_riders.villages = _villages
	_riders.castle = _castle
	add_child(_riders)
	_riders.repopulate(false, true)
	_riders.attacked.connect(func(by: Prey, _d: float) -> void:
		_flash = 0.8
		if by is GryphonCommander:
			return
		if Time.get_ticks_msec() - _gryphon_msg > 4000:
			_gryphon_msg = Time.get_ticks_msec()
			_toast("Jeździec gryfa uderza kopią!"))
	_riders.rider_killed.connect(func(r: GryphonRider) -> void:
		add_renown(10.0)
		_loot_n += 1
		var at := r.global_position
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			var p := r.global_position if is_instance_valid(r) else at
			_finds.add_special("loot_%d" % _loot_n, "coins", Vector3(p.x, Terrain.height(p.x, p.z), p.z) + Vector3(2, 0, 2),
				randi_range(60, 110), "Sakiewka jeźdźca"))
		_toast("Jeździec gryfa strącony!"))
	_riders.boss_killed.connect(_on_boss_killed)
	_riders.boss_phase_two.connect(func(_b: GryphonCommander) -> void:
		_banner("DOWÓDCA WZYWA POSIŁKI", "Z wież zamku wylatują jeźdźcy gryfów!"))
	_riders.armor_blocked.connect(func(_b: GryphonCommander) -> void:
		if Time.get_ticks_msec() - _armor_msg > 5000:
			_armor_msg = Time.get_ticks_msec()
			_toast("Pancerz dowódcy odbija ciosy — przebije go tylko pradawny smok!"))
	_knights = Knights.new()
	_knights.name = "Knights"
	_knights.dragon = _player
	_knights.villages = _villages
	add_child(_knights)
	_knights.repopulate()
	_knights.attacked.connect(func(by: Knight, _d: float) -> void:
		_flash = 0.6
		if Time.get_ticks_msec() - _knight_msg > 3500:
			_knight_msg = Time.get_ticks_msec()
			_toast("Kusznik trafia cię bełtem!" if by and by.crossbow else
				("Rycerz rani cię włócznią!" if _player.stats.stage == 0 else "Rycerz ciska oszczepem!")))
	_knights.knight_killed.connect(func(k: Knight) -> void:
		add_renown(6.0)
		_loot_n += 1
		_finds.add_special("loot_%d" % _loot_n, "coins", k.global_position + Vector3(randf_range(-2, 2), 0, 2.5),
			randi_range(20, 45), "Sakiewka rycerza")
		_toast("%s pokonany! Upuścił sakiewkę" % k.display_name))
	_knights.scared.connect(func(_k: Knight) -> void:
		add_renown(0.6)
		if Time.get_ticks_msec() - _knight_msg > 3500:
			_knight_msg = Time.get_ticks_msec()
			_toast("Rycerz w panice zawraca konia!"))
	_gryphons = Gryphons.new()
	_gryphons.name = "Gryphons"
	_gryphons.dragon = _player
	add_child(_gryphons)
	_gryphons.repopulate()
	_gryphons.attacked.connect(func(_g: Prey, _d: float) -> void:
		_flash = 0.7
		if Time.get_ticks_msec() - _gryphon_msg > 4000:
			_gryphon_msg = Time.get_ticks_msec()
			_toast("Gryf broni gniazda! Ogień albo uciekaj — nad gniazdem są dwa"))
	_gryphons.gryphon_killed.connect(func(_g: Prey) -> void:
		add_renown(8.0)
		_toast("Gryf pokonany! Spada — możesz go zjeść"))
	_villages.poked.connect(func(by: Villager, _dmg: float) -> void:
		if Time.get_ticks_msec() - _poke_msg > 3000:
			_poke_msg = Time.get_ticks_msec()
			_toast("%s dźga cię widłami! Uciekaj albo walcz" % by.display_name))
	_villages.eaten_from_village.connect(func(p: Prey) -> void:
		_anger_village(_villages.village_at(p.home if p.home_radius > 0.0 else p.global_position))
		add_renown(8.0 if p is Villager else 3.0))
	_villages.scared.connect(func(_by: Villager) -> void: add_renown(0.4))
	_spawner.attacked.connect(func(by: Prey, _dmg: float) -> void:
		_flash = 0.4
		if Time.get_ticks_msec() - _poke_msg > 3000:
			_poke_msg = Time.get_ticks_msec()
			_toast("%s szarżuje! Pisklę to dla niego nie smok — podleć albo urośnij" % by.display_name))
	_player.hit_by_arrow.connect(func(_dmg: float) -> void:
		_flash = 0.6
		if Time.get_ticks_msec() - _arrow_msg > 3000:
			_arrow_msg = Time.get_ticks_msec()
			_toast("Trafiony strzałą! Myśliwi polują na smoka"))
	_villages.cart_destroyed.connect(func(c: MerchantCart) -> void:
		add_renown(4.0)
		_loot_n += 1
		_finds.add_special("loot_%d" % _loot_n, "chest", c.global_position + c.global_basis.x * 3.5,
			randi_range(60, 120), "Łup z wozu kupieckiego")
		_toast("Wóz kupiecki spłonął! Zostawił skrzynię"))
	_villages.building_burnt.connect(func(b: Node3D) -> void:
		add_renown(5.0)
		_anger_village(_villages.village_at(b.global_position))
		# łup: ze spalonej chaty / stodoły wysypuje się złoto
		var is_barn := String((b as MeshInstance3D).mesh.resource_name).find("Barn") >= 0
		_loot_n += 1
		_finds.add_special("loot_%d" % _loot_n, "chest" if is_barn else "coins",
			b.global_position + Vector3(randf_range(-3, 3), 0, 4.0), randi_range(40, 70) if is_barn else randi_range(12, 30),
			"Łup ze stodoły" if is_barn else "Łup z chaty"))
	_player.fire.fire_hit.connect(_on_fire_hit)
	_player.grabbed.connect(func(prey: Prey) -> void:
		_toast("Porwany: %s · Ugryzienie = puść" % prey.display_name)
		if prey is Villager:
			add_renown(2.0))
	var fauna := Fauna.new()
	fauna.name = "Fauna"
	fauna.dragon = _player
	add_child(fauna)
	var clouds := Clouds.new()
	clouds.name = "Clouds"
	add_child(clouds)
	_lair = Lair.new()
	_lair.name = "Lair"
	_lair.position = Lair.POSITION
	add_child(_lair)
	_build_sleep_ui()
	# niebo z gwiazdami i księżycem (assets/shaders/sky.gdshader) zamiast proceduralnego
	var env := ($WorldEnvironment as WorldEnvironment).environment
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/sky.gdshader")
	env.sky.sky_material = sky_mat
	_day_night = DayNight.new()
	_day_night.name = "DayNight"
	_day_night.sun = $Sun
	_day_night.environment = ($WorldEnvironment as WorldEnvironment).environment
	_day_night.paused = not use_save  # testy: stałe południe/poranek
	add_child(_day_night)
	($Fauna as Fauna).day_night = _day_night
	_day_night.set_hour(8.0)
	_day_night.midnight.connect(func() -> void:
		day += 1
		_finds.setup(day, _cache_spots())
		_place_castle_treasury()
		_place_tributes())
	_finds = GoldFinds.new()
	_finds.name = "GoldFinds"
	_finds.dragon = _player
	add_child(_finds)
	_finds.picked.connect(_on_gold_picked)
	_build_gold_label()
	_hoard = HoardMenu.new()
	_hoard.name = "HoardMenu"
	_hoard.stats = _player.stats
	_hoard.get_treasure = func() -> int: return treasure
	_hoard.spend = spend_treasure
	add_child(_hoard)
	_hoard.woke.connect(_wake)
	_player.stats.upgraded.connect(func(id: String, _lvl: int) -> void:
		if id == "eye":
			_finds.refresh_beams())
	_day_night.dusk.connect(func() -> void:
		if not _lair.is_inside(_player.global_position):
			_toast("Zapada zmrok — wróć do legowiska i prześpij noc"))
	_spawn_point = _lair.nest_position()
	var data := SaveGame.load_data() if use_save else {}
	if not use_save:
		_spawn_point = _player.global_position  # piaskownica: łąka
	elif data.is_empty():
		_start_new_game()
	else:
		_load_game(data)
	_hud.get_node("StatBars").stats = _player.stats
	_player.stats.stage_changed.connect(_on_stage_changed)
	_player.stats.ate.connect(func(_meal: float, prey_name: String, growth: float) -> void:
		_toast("%s · +%s" % [prey_name, ("%d cm" % roundi(growth * 100.0)) if growth < 1.0 else ("%.1f m" % growth)]))
	_player.stats.died.connect(_on_died)
	_player.exhausted.connect(func() -> void:
		if Time.get_ticks_msec() - _exhausted_msg > 2500:
			_exhausted_msg = Time.get_ticks_msec()
			_toast("Brak sił! Szybuj w dół i odpocznij na ziemi"))
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	pause.stats = _player.stats
	pause.on_stats_changed = _update_buttons
	pause.on_teleport_castle = teleport_to_castle
	pause.on_teleport_nest = teleport_to_nest
	pause.on_teleport_knights = teleport_to_knights
	if use_save:
		pause.on_new_game = new_game
	pause.on_gyro_changed = func(on: bool) -> void: _camera.gyro_enabled = on
	_camera.gyro_enabled = PauseMenu.gyro_enabled()
	var crosshair := Crosshair.new()
	crosshair.name = "Crosshair"
	crosshair.dragon = _player
	_hud.add_child(crosshair)
	_hud.move_child(crosshair, 1)
	add_child(pause)
	_spawner.dragon = _player
	_spawner.populate()
	_update_buttons()
	_hud.get_node("Version").text = "v" + GameVersion.current()
	_player.launched.connect(func() -> void: DustBurst.spawn(self, _player.global_position, 1.4 * _player.size_k()))
	_player.landed.connect(_on_landed)
	_player.dashed.connect(func() -> void: _flash = 1.0)
	# teren: od razu cały świat (wokół smoka najdokładniej, z kolizją), potem LOD w biegu
	_terrain.focus = _player
	_terrain.build_all(_player.global_position)
	_decor.build_around(_player.global_position)
	_finds.setup(day, _cache_spots())
	_place_castle_treasury()
	_place_tributes()
	_lair.pile.set_gold(treasure)
	if _intro:
		_play_intro()


# --- Nowa gra, zapis, wczytanie -----------------------------------------------------

func _place_in_lair() -> void:
	_player.global_position = _lair.nest_position()
	_player.rotation.y = _lair.exit_yaw()  # pyskiem do wyjścia
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_camera.snap_behind()


func _start_new_game() -> void:
	day = 1
	_day_night.set_hour(7.0)  # wyklucie o świcie
	_place_in_lair()
	_intro = true


func _load_game(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	_day_night.set_hour(float(data.get("hour", 8.0)))
	treasure = int(data.get("treasure", 0))
	_finds.taken_today = data.get("finds_taken", [])
	_finds.caches_taken = data.get("caches_taken", [])
	_landmarks.found = data.get("landmarks_found", [])
	renown = float(data.get("renown", 0.0))
	var angry: Array = data.get("village_angry_until", [])
	for i in mini(angry.size(), village_angry_until.size()):
		village_angry_until[i] = int(angry[i])
	_renown_level = renown_level()
	_villages.set_hunters(_hunters_for(_renown_level))
	for h in _hunts_for(_renown_level):
		_knights.send_hunt()
	boss_defeated = bool(data.get("boss_defeated", false))
	_riders.repopulate(_renown_level >= RIDER_HUNT_LEVEL, not boss_defeated)
	_player.stats.restore(data.get("stats", {}))
	_lair.show_shells()
	var p: Array = data.get("pos", [])
	if p.size() == 3:
		_player.global_position = Vector3(p[0], p[1], p[2])
		_player.rotation.y = float(data.get("yaw", 0.0))
		_player.reset_physics_interpolation()
		_camera.snap_behind()
	else:
		_place_in_lair()


func save_game() -> void:
	if not use_save or _intro or _player.stats.health <= 0.0:
		return
	var pos := _player.global_position
	SaveGame.write({"day": day, "hour": _day_night.hour, "treasure": treasure,
		"finds_taken": _finds.taken_today, "caches_taken": _finds.caches_taken,
		"landmarks_found": _landmarks.found, "renown": renown,
		"village_angry_until": village_angry_until, "boss_defeated": boss_defeated, "stats": _player.stats.to_save(), "pos": [pos.x, pos.y, pos.z],
		"yaw": _player.rotation.y, "version": GameVersion.current()})


## Nowa gra (menu pauzy): kasuje zapis i wczytuje świat od nowa (intro wyklucia).
func new_game() -> void:
	SaveGame.delete()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _notification(what: int) -> void:
	# telefon: przejście do tła / zamknięcie — zapisz, bo system może zabić aplikację
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


# --- Wyklucie (intro nowej gry) ---------------------------------------------------

func _play_intro() -> void:
	_player.visible = false
	_player.set_physics_process(false)
	_lair.play_hatch(func() -> void:
		_player.visible = true
		_player.set_physics_process(true)
		var anim: AnimationPlayer = _player.find_child("AnimationPlayer", true, false)
		if anim:
			anim.play("Roar", 0.05)
		_intro = false
		_banner("WYKLUŁEŚ SIĘ!", "Wyjdź z jaskini i zapoluj")
		get_tree().create_timer(3.5).timeout.connect(func() -> void:
			_toast("Ugryzienie: poluj na króliki"))
		save_game())


# --- Ogień --------------------------------------------------------------------------

## Ogień smoka (kula / strumień): rani i piecze zwierzęta i ludzi, podpala budynki.
func _on_fire_hit(at: Vector3, radius: float, damage: float) -> void:
	for n in get_tree().get_nodes_in_group("prey"):
		var prey := n as Prey
		if prey and prey.is_alive() and prey.center().distance_to(at) < radius + prey.radius:
			prey.burn(damage)
	_villages.ignite_near(at, radius)
	_castle.burn_near(at, radius, damage)
	for c in _villages.carts():
		if c.is_alive() and c.global_position.distance_to(at) < radius + 3.0:
			c.burn()


## Przed bramą zamku, przodem do niej (narzędzie dewelopera, testy).
func teleport_to_castle() -> void:
	var g := Terrain.castle_gate_dir()
	var p := Vector2(Terrain.CASTLE[0], Terrain.CASTLE[1]) + g * (Terrain.CASTLE[2] + 70.0)
	_player.global_position = Vector3(p.x, Terrain.height(p.x, p.y) + 1.0, p.y)
	_player.rotation.y = atan2(-g.x, -g.y)
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_camera.snap_behind()


## W powietrzu 260 m od pierwszego gniazda gryfów, przodem do niego (narzędzie dewelopera).
func teleport_to_nest() -> void:
	var np := Gryphons.nest_position(0)
	var p := np + Vector3(0, 40.0, 260.0)
	_player.global_position = p
	_player.rotation.y = PI
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_camera.snap_behind()


## Przy drodze 70 m przed pierwszym patrolem rycerzy, przodem do niego (narzędzie dewelopera, testy).
func teleport_to_knights() -> void:
	var pts := _knights.knights().filter(func(k: Knight) -> bool: return k.mode == Knight.Mode.PATROL)
	if pts.is_empty():
		return
	var lead := pts[0] as Knight
	var kp: Vector3 = lead.patrol.slot_position(-10)  # 10 miejsc w szyku przed prowadzącym
	var off := Vector3.ZERO
	for a in 12:  # miejsce, gdzie da się stanąć
		var o := Vector3(0, 0, 6.0).rotated(Vector3.UP, a * TAU / 12.0)
		if Terrain.is_walkable(kp.x + o.x, kp.z + o.z):
			off = o
			break
	var p := kp + off
	_player.global_position = Vector3(p.x, Terrain.height(p.x, p.z) + 1.0, p.z)
	var look := lead.global_position - p
	_player.rotation.y = atan2(look.x, look.z)
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_camera.snap_behind()


## Skarbiec zamku: skrzynie przed donżonem (co dzień nowe, jeśli zabrane).
func _place_castle_treasury() -> void:
	var spots := _castle.treasury_spots()
	for i in spots.size():
		_finds.add_special("castle_%d_d%d" % [i, day], "chest", spots[i], 220 + 40 * i, "Skarbiec zamku")
	for i in Gryphons.NESTS.size():  # gryfy znoszą do gniazd błyskotki
		var np := Gryphons.nest_position(i)
		_finds.add_special("nest_%d_d%d" % [i, day], "crown", np + Vector3(1.2, 0.4, 0.6), 90 + 20 * i, "Korona z gniazda gryfa")
		_finds.add_special("nest_%d_g_d%d" % [i, day], "goblet", np + Vector3(-1.0, 0.4, -0.8), 50, "Kielich z gniazda gryfa")


# --- Danina i łupienie --------------------------------------------------------------

## Każdego dnia wioski, które boją się smoka (rozgłos „Postrach”+) i nie zostały ostatnio
## napadnięte, zostawiają daninę na kamieniu ofiarnym.
func _place_tributes() -> void:
	if renown_level() < TRIBUTE_LEVEL:
		return
	for i in Terrain.VILLAGES.size():
		if day <= int(village_angry_until[i]):
			continue
		var value := int(20.0 + renown * 0.8)
		_finds.add_special("tribute_%d_d%d" % [i, day], "chest", _villages.tribute_stone(i) + Vector3.UP * 0.7,
			value, "Danina od wioski " + Villages.NAMES[i])


## Napaść na wioskę: przez 3 dni nie płaci daniny (zabiera też dzisiejszą, jeśli leży).
func _anger_village(i: int) -> void:
	if i < 0:
		return
	var was_paying := day > int(village_angry_until[i])
	village_angry_until[i] = day + 3
	var id := "tribute_%d_d%d" % [i, day]
	if _finds.has_node(id):
		_finds.get_node(id).queue_free()
	if was_paying and renown_level() >= TRIBUTE_LEVEL:
		_toast("%s wypowiada daninę na 3 dni!" % Villages.NAMES[i])


# --- Rozgłos -----------------------------------------------------------------------

func renown_level() -> int:
	var lvl := 0
	for i in RENOWN_LEVELS.size():
		if renown >= RENOWN_LEVELS[i]:
			lvl = i
	return lvl


func _hunters_for(level: int) -> int:
	return [0, 1, 2, 3][level]


## Od tego poziomu rozgłosu („Legenda”) jeźdźcy gryfów polują na smoka w całym świecie.
const RIDER_HUNT_LEVEL := 3


## Oddziały pościgowe rycerzy z zamku: od „Postrachu” jeden, przy „Legendzie” dwa.
func _hunts_for(level: int) -> int:
	return maxi(0, level - 1)


func add_renown(amount: float) -> void:
	renown = clampf(renown + amount, 0.0, 100.0)
	var lvl := renown_level()
	if lvl > _renown_level:
		for h in range(_hunts_for(_renown_level), _hunts_for(lvl)):
			_knights.send_hunt()
		if lvl >= RIDER_HUNT_LEVEL and _renown_level < RIDER_HUNT_LEVEL:
			_riders.send_hunters()
			get_tree().create_timer(8.0).timeout.connect(func() -> void:
				_toast("Z zamku wylatują jeźdźcy gryfów — polują na ciebie!"))
		_banner("ROZGŁOS: " + RENOWN_NAMES[lvl].to_upper(),
			"Wioski wysyłają myśliwych z łukami!" if lvl == 1 else
			("Wioski zaczną składać ci daninę na kamieniach ofiarnych" if lvl == TRIBUTE_LEVEL
				else "Z zamku wyrusza drugi oddział rycerzy — prosto na ciebie!"))
		if lvl == TRIBUTE_LEVEL:
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				_toast("Z zamku wyrusza oddział rycerzy, by cię dopaść!"))
		if lvl >= TRIBUTE_LEVEL:
			_place_tributes()
		_villages.set_hunters(_hunters_for(lvl))
	_renown_level = lvl


# --- Złoto -------------------------------------------------------------------------

## Skrytki ze złotem: skrzynie przy ciekawych miejscach (na drzewie i łuku — tylko lotem).
func _cache_spots() -> Array[Vector3]:
	return _landmarks.cache_spots()

func _build_gold_label() -> void:
	_gold_label = Label.new()
	_gold_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_gold_label.offset_left = -300
	_gold_label.offset_right = 300
	_gold_label.offset_top = 14
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 30)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	_gold_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 0.9))
	_gold_label.add_theme_constant_override("outline_size", 8)
	_hud.add_child(_gold_label)


func _on_gold_picked(value: int, item_name: String, where: Vector3) -> void:
	_player.stats.gold += value
	_toast("%s · +%d złota" % [item_name, value])
	DustBurst.spawn(self, where, 0.4, Color(1.0, 0.82, 0.3))


func _update_gold() -> void:
	var carried := _player.stats.gold
	# odłóż niesione złoto na stos, gdy smok jest w komorze legowiska
	if carried > 0 and not _intro and _lair.is_inside(_player.global_position):
		treasure += carried
		_player.stats.gold = 0
		_lair.pile.set_gold(treasure)
		_toast("+%d złota na stosie! Skarb: %d" % [carried, treasure])
		DustBurst.spawn(self, _lair.pile.global_position, 0.8, Color(1.0, 0.82, 0.3))
		save_game()
		carried = 0
	_gold_label.text = ("Złoto %d  ·  " % carried if carried > 0 else "") + "Skarb %d" % treasure \
		+ "  ·  Miejsca %d/%d" % [_landmarks.found.size(), _landmarks.total()] \
		+ "  ·  Rozgłos: %s" % RENOWN_NAMES[_renown_level]


# --- Sen w legowisku -------------------------------------------------------------

func _build_sleep_ui() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.05, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_fade)
	_sleep_button = Button.new()
	_sleep_button.text = "ŚPIJ"
	_sleep_button.add_theme_font_size_override("font_size", 40)
	_sleep_button.custom_minimum_size = Vector2(260, 96)
	_sleep_button.focus_mode = Control.FOCUS_NONE
	_sleep_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sleep_button.offset_left = -130
	_sleep_button.offset_right = 130
	_sleep_button.offset_top = -150
	_sleep_button.offset_bottom = -54
	_sleep_button.visible = false
	_sleep_button.pressed.connect(sleep.bind(false))
	_hud.add_child(_sleep_button)


func can_sleep() -> bool:
	return not _sleeping and not _intro and not _player.is_flying() and _lair.is_inside(_player.global_position)


## Zapłać ze stosu skarbu (ulepszenia „snu na skarbie”); stos od razu maleje.
func spend_treasure(cost: int) -> bool:
	if cost > treasure:
		return false
	treasure -= cost
	_lair.pile.set_gold(treasure)
	return true


## Sen: ściemnienie → „Sen na skarbie” (ulepszenia za złoto) → rano: leczenie, odnowa sił,
## nowy dzień, zapis. `skip_hoard` = bez okna ulepszeń (testy).
func sleep(skip_hoard: bool = false) -> void:
	if not can_sleep():
		return
	_sleeping = true
	_sleep_button.visible = false
	_player.set_physics_process(false)
	_day_night.paused = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.85, 0.8)
	if skip_hoard:
		tw.tween_callback(_wake)
	else:
		tw.tween_callback(_hoard.open)


func is_sleeping() -> bool:
	return _sleeping


func _wake() -> void:
	_day_night.paused = not use_save
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func() -> void:
		if _day_night.hour >= 7.0:
			day += 1  # po północy dzień już się zmienił — śpisz tylko do rana
		_day_night.set_hour(7.0)
		_finds.setup(day, _cache_spots())  # nowy dzień — nowe znaleziska
		_place_castle_treasury()
		_castle.repopulate()  # balisty naprawione, łucznicy na murach
		_gryphons.repopulate()  # gryfy wracają do gniazd
		_place_tributes()
		renown = maxf(0.0, renown - 5.0)  # przez noc plotki cichną
		_renown_level = renown_level()
		_knights.repopulate(_hunts_for(_renown_level))
		_riders.repopulate(_renown_level >= RIDER_HUNT_LEVEL, not boss_defeated)
		_boss_seen = false  # patrole w komplecie, pościg przy dużym rozgłosie
		_villages.hunters_per_village = _hunters_for(_renown_level)
		_villages.repopulate()  # zjedzeni mieszkańcy i owce wracają
		_villages.rebuild()  # spalone chaty odbudowane
		var st := _player.stats
		st.health = 100.0
		st.stamina = 100.0
		st.hunger = maxf(5.0, st.hunger - sleep_hunger_cost)
		save_game())
	tw.tween_interval(0.7)
	tw.tween_callback(func() -> void:
		_banner("DZIEŃ %d" % day, "Gra zapisana · zdrowie odnowione"))
	tw.tween_property(_fade, "color:a", 0.0, 1.0)
	tw.tween_callback(func() -> void:
		_player.set_physics_process(true)
		_sleeping = false)


var _flash: float = 0.0
var _exhausted_msg: int = -100000
var _effect: float = 0.0


func _on_landed(impact: float) -> void:
	if impact > 6.0:
		DustBurst.spawn(self, _player.global_position, clampf(impact / 14.0, 0.5, 1.5) * maxf(_player.size_k(), 0.3))


func _update_buttons() -> void:
	var flap: TouchActionButton = _hud.get_node("FlapButton")
	flap.label = "SKRZYDŁA" if _player.stats.can_fly() else "SKOK"
	# ogień od stadium Młodzika (kula ognia), od Dorosłego strumień
	var fire_btn := _hud.get_node("FireButton") as TouchActionButton
	fire_btn.locked = not _player.stats.can_fire()
	fire_btn.label = "STRUMIEŃ" if _player.stats.stage >= DragonStats.Stage.ADULT else "OGIEŃ"


func _on_stage_changed(_stage: int, stage_name: String) -> void:
	var unlocks := ""
	var unlocked: Array[TouchActionButton] = []
	if _player.stats.stage == DragonStats.Stage.JUVENILE:
		unlocks = "Odblokowano: LOT i KULA OGNIA!"
		unlocked.append(_hud.get_node("FlapButton"))
		unlocked.append(_hud.get_node("FireButton"))
	_banner(stage_name.to_upper() + "!", unlocks)
	_update_buttons()
	for b in unlocked:
		b.celebrate()  # przycisk podskakuje i pulsuje złotem — „tu jest nowa zdolność”
	if not unlocked.is_empty():
		get_tree().create_timer(3.2).timeout.connect(func() -> void:
			_toast("Przytrzymaj SKRZYDŁA, by wystartować"))
	DustBurst.spawn(self, _player.global_position, 1.2 * maxf(_player.size_k(), 0.4), Color(1.0, 0.85, 0.45))


func _on_died() -> void:
	_player.release_carried()
	_banner("Zemdlałeś z głodu…", "Budzisz się w legowisku" if use_save else "Budzisz się w bezpiecznym miejscu")
	_player.global_position = _spawn_point
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()  # teleport — bez „przelotu” interpolacji
	_player.stats.revive(60.0, 45.0)
	var lost := int(ceil(_player.stats.gold * death_gold_loss))
	if lost > 0:
		_player.stats.gold -= lost
		get_tree().create_timer(2.5).timeout.connect(func() -> void: _toast("Zgubiłeś %d złota" % lost))
	save_game()


func _banner(title: String, subtitle: String) -> void:
	var b: Label = _hud.get_node("Banner")
	b.text = title + ("\n" + subtitle if subtitle != "" else "")
	b.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(b, "modulate:a", 0.0, 1.0)


func _toast(text: String) -> void:
	var t: Label = _hud.get_node("Toast")
	t.text = text
	t.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(t, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_camera.size_k = _player.size_k()
	_effect = lerpf(_effect, _player.speed_effect, clampf(5.0 * delta, 0.0, 1.0))
	_flash = maxf(0.0, _flash - delta * 2.5)
	_camera.effect = _effect
	var lines := _hud.get_node("SpeedLines") as ColorRect
	(lines.material as ShaderMaterial).set_shader_parameter("intensity", _effect)
	(lines.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	var v := _player.velocity
	var mode := "lot" if _player.is_flying() else "ziemia"
	var status: Label = _hud.get_node("Status")
	status.position.y = 184.0 if _player.stats.can_fly() else 150.0  # pod paskiem siły lotu
	status.text = "Dzień %d, %s · %s · wys. %d m · %d km/h" % [day, _day_night.clock_text(), mode, int(_player.global_position.y),
		int(v.length() * 3.6)]
	_sleep_button.visible = can_sleep()
	_villages.set_night(_day_night.night_factor())
	if not _castle_seen and _player.global_position.distance_to(_castle.position) < 320.0:
		_castle_seen = true
		_banner("ZAMEK KRÓLEWSKI", "Balisty na wieżach i łucznicy na murach · w skarbcu złoto królestwa")
	(_hud.get_node("FireButton") as TouchActionButton).charge = _player.fire.readiness
	var bite_btn := _hud.get_node("BiteButton") as TouchActionButton
	var carrying := _player.carried != null and is_instance_valid(_player.carried)
	if carrying:
		bite_btn.label = "PUŚĆ" if _player.is_flying() else "ZJEDZ"
	else:
		bite_btn.label = "ŁAP" if _player.is_flying() and _player.stats.can_fly() else "UGRYZIENIE"
	renown = maxf(0.0, renown - delta * 0.01)  # ok. 0,6 pkt na minutę
	_renown_level = mini(_renown_level, renown_level())
	_update_gold()
	_update_boss_bar()
	if use_save and not _intro:
		_autosave_t += delta
		if _autosave_t >= autosave_interval:
			_autosave_t = 0.0
			save_game()


# --- Dowódca jeźdźców gryfów (boss) ---------------------------------------------------

func _on_boss_killed(b: GryphonCommander) -> void:
	boss_defeated = true
	add_renown(25.0)
	_banner("DOWÓDCA JEŹDŹCÓW POKONANY", "Królestwo drży przed tobą · skarb dowódcy spadł razem z nim")
	var at := b.global_position
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		var p := b.global_position if is_instance_valid(b) else at
		_finds.add_special("boss_loot", "chest", Vector3(p.x, Terrain.height(p.x, p.z) + 0.7, p.z) + Vector3(3, 0, 0),
			900, "Skarb dowódcy jeźdźców")
		save_game())


## Pasek zdrowia dowódcy u góry ekranu, gdy walczy (blisko smoka).
func _update_boss_bar() -> void:
	var b := _riders.boss
	var show := _riders.boss_alive() and b.mode != Gryphon.Mode.PERCH \
		and b.global_position.distance_to(_player.global_position) < 500.0
	if show and not _boss_seen:
		_boss_seen = true
		_banner("DOWÓDCA JEŹDŹCÓW GRYFÓW", "Elita królestwa · pancerz przebije tylko pradawny smok")
	if not _boss_bar:
		if not show:
			return
		_boss_bar = VBoxContainer.new()
		_boss_bar.name = "BossBar"
		_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_boss_bar.position = Vector2(-300, 70)
		_boss_bar.custom_minimum_size = Vector2(600, 0)
		var l := Label.new()
		l.text = "Dowódca jeźdźców gryfów"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		_boss_bar.add_child(l)
		var bar := ProgressBar.new()
		bar.name = "Bar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(600, 22)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.75, 0.1, 0.1)
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.55)
		bar.add_theme_stylebox_override("background", bg)
		_boss_bar.add_child(bar)
		_hud.add_child(_boss_bar)
	_boss_bar.visible = show
	if show:
		var bar := _boss_bar.get_node("Bar") as ProgressBar
		bar.max_value = b.max_health
		bar.value = b.health
