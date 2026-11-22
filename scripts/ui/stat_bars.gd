class_name StatBars
extends Control
## Paski: zdrowie, głód, wzrost (do następnego stadium) i siła lotu (gdy smok lata)
## + nazwa stadium i rozmiar.

var stats: DragonStats

const W := 420.0
const H := 22.0
const GAP := 12.0


func _process(_delta: float) -> void:
	queue_redraw()


func _bar(y: float, value: float, color: Color, label: String) -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(0, y, W, H), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(2, y + 2, (W - 4) * clampf(value, 0.0, 1.0), H - 4), color)
	draw_string(font, Vector2(8, y + H - 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.95))


func _draw() -> void:
	if not stats:
		return
	var font := get_theme_default_font()
	var title := "%s · %.1f m" % [stats.stage_name(), stats.size]
	draw_string(font, Vector2(0, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.93, 0.75))
	var y := 40.0
	_bar(y, stats.health / 100.0, Color(0.85, 0.22, 0.2), "Zdrowie")
	y += H + GAP
	var hunger_col := Color(0.95, 0.6, 0.15) if stats.hunger > 20.0 else Color(1, 0.3, 0.1)
	_bar(y, stats.hunger / 100.0, hunger_col, "Najedzenie")
	y += H + GAP
	var next_name: String = DragonStats.STAGE_NAMES[stats.stage + 1] if stats.stage + 1 < DragonStats.STAGE_NAMES.size() else "max"
	_bar(y, stats.stage_progress(), Color(0.35, 0.8, 0.35), "Wzrost → %s (%.0f m)" % [next_name, stats.next_stage_size()])
	if stats.can_fly():
		y += H + GAP
		var st := stats.stamina / 100.0
		var col := Color(0.4, 0.75, 1.0)
		if st < 0.25:  # mało sił — pasek miga
			var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
			col = Color(1.0, 0.35, 0.25).lerp(Color(1, 0.8, 0.7), blink * 0.5)
		_bar(y, st, col, "Siła lotu" if st > 0.0 else "Brak sił — wyląduj, by odpocząć")
