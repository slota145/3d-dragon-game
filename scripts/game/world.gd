extends Node3D
## Świat: łączy gracza, kamerę, HUD i legowisko; zapis gry, sen, wyklucie (nowa gra).
## Testy ustawiają `use_save = false` przed dodaniem sceny: bez zapisu i intro, start na łące.

## false = piaskownica (testy): bez wczytywania/zapisu, bez intro, start na łące w (0, 0, 0).
@export var use_save: bool = true
## Autozapis co tyle sekund (oprócz snu i wyjścia z gry).
@export var autosave_interval: float = 60.0
## Ile najedzenia „zjada” noc snu.
@export var sleep_hunger_cost: float = 15.0

## Numer dnia (rośnie przy każdym śnie).
var day: int = 1
var _lair: Lair
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
	_lair = Lair.new()
	_lair.name = "Lair"
	_lair.position = Lair.POSITION
	add_child(_lair)
	_build_sleep_ui()
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
	if use_save:
		pause.on_new_game = new_game
	add_child(pause)
	_spawner.dragon = _player
	_spawner.populate()
	_update_buttons()
	_hud.get_node("Version").text = "v" + GameVersion.current()
	_player.launched.connect(func() -> void: DustBurst.spawn(self, _player.global_position, 1.4 * _player.size_k()))
	_player.landed.connect(_on_landed)
	_player.dashed.connect(func() -> void: _flash = 1.0)
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
	_place_in_lair()
	_intro = true


func _load_game(data: Dictionary) -> void:
	day = int(data.get("day", 1))
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
	SaveGame.write({"day": day, "stats": _player.stats.to_save(), "pos": [pos.x, pos.y, pos.z],
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
	_sleep_button.pressed.connect(sleep)
	_hud.add_child(_sleep_button)


func can_sleep() -> bool:
	return not _sleeping and not _intro and not _player.is_flying() and _lair.is_inside(_player.global_position)


## Sen: ściemnienie, leczenie, odnowa sił, nowy dzień, zapis.
func sleep() -> void:
	if not can_sleep():
		return
	_sleeping = true
	_sleep_button.visible = false
	_player.set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	tw.tween_callback(func() -> void:
		day += 1
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
	# ogień pojawi się w fazie 7 — na razie przycisk zablokowany
	(_hud.get_node("FireButton") as TouchActionButton).locked = true


func _on_stage_changed(_stage: int, stage_name: String) -> void:
	var unlocks := ""
	var unlocked: Array[TouchActionButton] = []
	if _player.stats.stage == DragonStats.Stage.JUVENILE:
		unlocks = "Odblokowano: LOT!"
		unlocked.append(_hud.get_node("FlapButton"))
	_banner(stage_name.to_upper() + "!", unlocks)
	_update_buttons()
	for b in unlocked:
		b.celebrate()  # przycisk podskakuje i pulsuje złotem — „tu jest nowa zdolność”
	if not unlocked.is_empty():
		get_tree().create_timer(3.2).timeout.connect(func() -> void:
			_toast("Przytrzymaj SKRZYDŁA, by wystartować"))
	DustBurst.spawn(self, _player.global_position, 1.2 * maxf(_player.size_k(), 0.4), Color(1.0, 0.85, 0.45))


func _on_died() -> void:
	_banner("Zemdlałeś z głodu…", "Budzisz się w legowisku" if use_save else "Budzisz się w bezpiecznym miejscu")
	_player.global_position = _spawn_point
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()  # teleport — bez „przelotu” interpolacji
	_player.stats.revive(60.0, 45.0)
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
	status.text = "Dzień %d · %s · wys. %d m · %d km/h" % [day, mode, int(_player.global_position.y),
		int(v.length() * 3.6)]
	_sleep_button.visible = can_sleep()
	if use_save and not _intro:
		_autosave_t += delta
		if _autosave_t >= autosave_interval:
			_autosave_t = 0.0
			save_game()
