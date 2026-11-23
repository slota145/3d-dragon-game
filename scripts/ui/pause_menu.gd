class_name PauseMenu
extends CanvasLayer
## Menu pauzy (przycisk „II” w prawym górnym rogu lub Esc) i okienko trybu deweloperskiego.
## Tryb deweloperski włącza się w menu pauzy; ustawienie zapisuje się w user://settings.cfg.
## Okienko dewelopera działa w trakcie gry (zwijane) — narzędzia do testowania.

signal resumed

const SETTINGS_PATH := "user://settings.cfg"
const FONT := 34
const BUTTON_H := 84.0

var stats: DragonStats
## Woła świat po zmianie stadium z okienka dewelopera (odświeżenie przycisków i HUD).
var on_stats_changed: Callable
## Nowa gra (kasuje zapis) — ustawia świat; pusty = opcja ukryta.
var on_new_game: Callable
## Zmiana opcji „Celowanie żyroskopem” (świat przekazuje ją kamerze).
var on_gyro_changed: Callable

var _gyro_toggle: CheckButton

var _new_game_button: Button
var _new_game_armed: bool = false

var _pause_button: Button
var _dim: ColorRect
var _menu: PanelContainer
var _dev_toggle: CheckButton
var _dev_panel: PanelContainer
var _dev_body: VBoxContainer
var _dev_fold: Button
var _dev_info: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause_button()
	_build_menu()
	_build_dev_panel()
	_dev_panel.visible = _load_dev_enabled()
	_dev_toggle.set_pressed_no_signal(_dev_panel.visible)
	_menu.visible = false
	_dim.visible = false


func is_open() -> bool:
	return _menu.visible


func open() -> void:
	_new_game_armed = false
	_new_game_button.text = "Nowa gra"
	_new_game_button.visible = on_new_game.is_valid()
	_menu.visible = true
	_dim.visible = true
	_pause_button.visible = false
	get_tree().paused = true


func close() -> void:
	_menu.visible = false
	_dim.visible = false
	_pause_button.visible = true
	get_tree().paused = false
	resumed.emit()


func _notification(what: int) -> void:
	# Android: systemowy „wstecz” otwiera / zamyka pauzę (quit_on_go_back = false)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_open():
			close()
		else:
			open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _dev_panel.visible and _dev_body.visible and stats:
		_dev_info.text = "%s · %.2f m · siła %d" % [stats.stage_name(), stats.size, int(stats.stamina)]


# --- Budowa interfejsu ---------------------------------------------------------

func _button(text: String, cb: Callable, font_size: int = FONT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BUTTON_H)
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _panel_style(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.1, alpha)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(28)
	return sb


func _build_pause_button() -> void:
	_pause_button = _button("II", open, 40)
	_pause_button.custom_minimum_size = Vector2(96, 96)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.offset_left = -120
	_pause_button.offset_right = -24
	_pause_button.offset_top = 20
	_pause_button.offset_bottom = 116
	_pause_button.modulate = Color(1, 1, 1, 0.75)
	add_child(_pause_button)


func _build_menu() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", _panel_style(0.92))
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.custom_minimum_size = Vector2(620, 0)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_menu.add_child(box)

	var title := Label.new()
	title.text = "Pauza"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	box.add_child(title)
	box.add_child(_button("Wznów grę", close))

	_dev_toggle = CheckButton.new()
	_dev_toggle.text = "Tryb deweloperski"
	_dev_toggle.custom_minimum_size = Vector2(0, BUTTON_H)
	_dev_toggle.add_theme_font_size_override("font_size", FONT)
	_dev_toggle.focus_mode = Control.FOCUS_NONE
	_dev_toggle.toggled.connect(_on_dev_toggled)
	box.add_child(_dev_toggle)

	_gyro_toggle = CheckButton.new()
	_gyro_toggle.text = "Celowanie żyroskopem"
	_gyro_toggle.custom_minimum_size = Vector2(0, BUTTON_H)
	_gyro_toggle.add_theme_font_size_override("font_size", FONT)
	_gyro_toggle.focus_mode = Control.FOCUS_NONE
	_gyro_toggle.set_pressed_no_signal(gyro_enabled())
	_gyro_toggle.toggled.connect(func(on: bool) -> void:
		_save_setting("controls", "gyro", on)
		if on_gyro_changed.is_valid():
			on_gyro_changed.call(on))
	box.add_child(_gyro_toggle)

	_new_game_button = _button("Nowa gra", _on_new_game)
	box.add_child(_new_game_button)
	box.add_child(_button("Wyjdź z gry", func() -> void: get_tree().quit()))


func _build_dev_panel() -> void:
	_dev_panel = PanelContainer.new()
	_dev_panel.add_theme_stylebox_override("panel", _panel_style(0.8))
	# lewa strona, pod paskami statystyk (prawy górny róg zajmuje pauza i aktualizacja)
	_dev_panel.offset_left = 24
	_dev_panel.offset_right = 444
	_dev_panel.offset_top = 236
	add_child(_dev_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_dev_panel.add_child(box)

	_dev_fold = _button("Deweloper ▾", _toggle_fold, 28)
	_dev_fold.custom_minimum_size = Vector2(0, 64)
	box.add_child(_dev_fold)

	_dev_body = VBoxContainer.new()
	_dev_body.add_theme_constant_override("separation", 10)
	box.add_child(_dev_body)
	_dev_info = Label.new()
	_dev_info.add_theme_font_size_override("font_size", 24)
	_dev_body.add_child(_dev_info)

	var head := Label.new()
	head.text = "Rozmiar → stadium"
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	_dev_body.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_dev_body.add_child(grid)
	for i in DragonStats.STAGE_NAMES.size():
		var stage_size: float = DragonStats.STAGE_MIN_SIZE[i] if i > 0 else -1.0
		var label := "%s (%s)" % [DragonStats.STAGE_NAMES[i], "start" if i == 0 else "%d m" % int(stage_size)]
		var b := _button(label, _set_stage.bind(i), 26)
		b.custom_minimum_size = Vector2(190, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	var reset := _button("Reset wzrostu", _reset_growth, 26)
	reset.custom_minimum_size = Vector2(0, 72)
	_dev_body.add_child(reset)


## Nowa gra wymaga drugiego naciśnięcia (potwierdzenie) — kasuje zapis.
func _on_new_game() -> void:
	if not _new_game_armed:
		_new_game_armed = true
		_new_game_button.text = "Na pewno? Zapis zniknie!"
		return
	if on_new_game.is_valid():
		on_new_game.call()


func _toggle_fold() -> void:
	_dev_body.visible = not _dev_body.visible
	_dev_fold.text = "Deweloper ▾" if _dev_body.visible else "Deweloper ▸"


# --- Narzędzia dewelopera ------------------------------------------------------

func _set_stage(stage: int) -> void:
	if not stats:
		return
	var target: float = DragonStats.STAGE_MIN_SIZE[stage] if stage > 0 else stats.start_size
	stats.set_size_instant(target)
	_changed()


func _reset_growth() -> void:
	if not stats:
		return
	stats.set_size_instant(stats.start_size)
	_changed()


func _changed() -> void:
	stats.stamina = 100.0
	if on_stats_changed.is_valid():
		on_stats_changed.call()


# --- Ustawienia ----------------------------------------------------------------

func _on_dev_toggled(on: bool) -> void:
	_dev_panel.visible = on
	_save_setting("dev", "enabled", on)


func _save_setting(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(section, key, value)
	cfg.save(SETTINGS_PATH)


## Zapisana opcja celowania żyroskopem (domyślnie wyłączona).
static func gyro_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return false
	return bool(cfg.get_value("controls", "gyro", false))


func _load_dev_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return false
	return bool(cfg.get_value("dev", "enabled", false))
