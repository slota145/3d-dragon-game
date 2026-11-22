class_name HoardMenu
extends CanvasLayer
## „Sen na skarbie”: okno w czasie snu w legowisku. Smok wtapia złoto ze stosu w ciało —
## gracz wybiera ulepszenia (Upgrades), a potem budzi się rano. Stos skarbu naprawdę maleje.

signal woke

const FONT := 30

var stats: DragonStats
## Ile złota leży na stosie (czyta świat).
var get_treasure: Callable
## Zapłać ze stosu: spend.call(koszt) -> bool.
var spend: Callable

var _panel: PanelContainer
var _treasure_label: Label
var _rows: VBoxContainer


func _ready() -> void:
	layer = 9
	_build()
	visible = false


func open() -> void:
	_refresh()
	visible = true


func _build() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.03, 0.94)
	sb.border_color = Color(0.85, 0.65, 0.25, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(1180, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Sen na skarbie"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0.4))
	box.add_child(title)
	var lore := Label.new()
	lore.text = "Śpiący smok wtapia złoto i klejnoty ze swojego stosu w łuski i skrzydła.\nWybierz, co ma wzmocnić skarb — stos zmaleje."
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD
	lore.add_theme_font_size_override("font_size", 24)
	lore.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	box.add_child(lore)
	_treasure_label = Label.new()
	_treasure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_treasure_label.add_theme_font_size_override("font_size", 34)
	_treasure_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	box.add_child(_treasure_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	box.add_child(_rows)

	var wake := Button.new()
	wake.text = "Obudź się (rano)"
	wake.custom_minimum_size = Vector2(0, 90)
	wake.add_theme_font_size_override("font_size", 36)
	wake.focus_mode = Control.FOCUS_NONE
	wake.pressed.connect(func() -> void:
		visible = false
		woke.emit())
	box.add_child(wake)


func _refresh() -> void:
	var treasure: int = get_treasure.call() if get_treasure.is_valid() else 0
	_treasure_label.text = "Skarb na stosie: %d złota" % treasure
	for c in _rows.get_children():
		c.queue_free()
	for id: String in Upgrades.ORDER:
		var lvl := stats.level(id) if stats else 0
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "%s  %s\n%s" % [Upgrades.display_name(id), _pips(lvl), Upgrades.description(id)]
		info.add_theme_font_size_override("font_size", 24)
		row.add_child(info)
		var cost := Upgrades.next_cost(id, lvl)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(300, 80)
		buy.add_theme_font_size_override("font_size", FONT)
		buy.focus_mode = Control.FOCUS_NONE
		if cost < 0:
			buy.text = "Pełna moc"
			buy.disabled = true
		else:
			buy.text = "Wtop %d złota" % cost
			buy.disabled = cost > treasure
			buy.pressed.connect(_buy.bind(id, cost))
		buy.name = "Buy_" + id
		row.add_child(buy)
		_rows.add_child(row)


func _pips(lvl: int) -> String:
	return "· poziom %d/%d" % [lvl, Upgrades.MAX_LEVEL]


func _buy(id: String, cost: int) -> void:
	if spend.is_valid() and spend.call(cost):
		stats.upgrade(id)
	_refresh()
