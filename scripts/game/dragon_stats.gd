class_name DragonStats
extends Node
## Statystyki smoka: rozmiar (płynny wzrost), stadia wg progów rozmiaru, zdrowie, głód.
## Rozmiar = długość smoka w metrach (model 1:1 ma `model_size` m).

signal size_changed(size: float)
signal stage_changed(stage: int, stage_name: String)
signal ate(food: float, prey_name: String)
signal died

enum Stage { HATCHLING, JUVENILE, ADULT, ANCIENT }
const STAGE_NAMES := ["Pisklę", "Młodzik", "Dorosły", "Pradawny"]
## Progi rozmiaru (m), od których zaczyna się dane stadium.
const STAGE_MIN_SIZE := [0.0, 4.0, 9.0, 16.0]

@export var start_size: float = 2.4
@export var max_size: float = 20.0
## Długość modelu smoka przy skali 1 (m).
@export var model_size: float = 12.0
## Przyrost rozmiaru (m) za 1 punkt jedzenia przy rozmiarze startowym; maleje z rozmiarem.
@export var growth_rate: float = 0.15
## Trawienie: zjedzony wzrost przybywa płynnie (m/s, minimum) — bez skoków rozmiaru.
@export var digest_speed: float = 0.35
## Spadek głodu (pkt/s): 100 -> 0 w ok. 3,7 min.
@export var hunger_decay: float = 0.45
## Ile głodu zaspokaja 1 punkt jedzenia.
@export var hunger_per_food: float = 12.0
@export var starve_damage: float = 2.0
@export var regen: float = 1.5

var size: float = 2.4
var health: float = 100.0
var hunger: float = 70.0
var stage: int = Stage.HATCHLING
## Wzrost czekający na „strawienie” (m).
var pending_growth: float = 0.0


func _ready() -> void:
	size = start_size
	stage = stage_for(size)


func scale_factor() -> float:
	return size / model_size


static func stage_for(s: float) -> int:
	var result := 0
	for i in STAGE_MIN_SIZE.size():
		if s >= STAGE_MIN_SIZE[i]:
			result = i
	return result


func stage_name() -> String:
	return STAGE_NAMES[stage]


func next_stage_size() -> float:
	return STAGE_MIN_SIZE[stage + 1] if stage + 1 < STAGE_MIN_SIZE.size() else max_size


## Postęp (0..1) od początku bieżącego stadium do następnego progu.
func stage_progress() -> float:
	var lo: float = STAGE_MIN_SIZE[stage] if stage > 0 else start_size
	return clampf((size - lo) / maxf(next_stage_size() - lo, 0.001), 0.0, 1.0)


func can_fly() -> bool:
	return stage >= Stage.JUVENILE


func can_fire() -> bool:
	return stage >= Stage.JUVENILE


## Zjedzenie ofiary. Małe ofiary dają dużemu smokowi coraz mniej.
func eat(food: float, prey_size: float, prey_name: String) -> void:
	var effective := food * clampf(3.0 * prey_size / size, 0.15, 1.0)
	hunger = minf(100.0, hunger + food * hunger_per_food)
	pending_growth += growth_rate * effective * (start_size / size)
	ate.emit(effective, prey_name)


func set_size(s: float) -> void:
	size = clampf(s, 0.5, max_size)
	size_changed.emit(size)
	var new_stage := stage_for(size)
	if new_stage != stage:
		var up := new_stage > stage
		stage = new_stage
		if up:
			stage_changed.emit(stage, stage_name())


func damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		died.emit()


func revive(hp: float, food: float) -> void:
	health = hp
	hunger = food


func _process(delta: float) -> void:
	if pending_growth > 0.0:
		var step := minf(pending_growth, maxf(digest_speed, pending_growth * 1.2) * delta)
		pending_growth -= step
		set_size(size + step)
	hunger = maxf(0.0, hunger - hunger_decay * delta)
	if hunger <= 0.0:
		damage(starve_damage * delta)
	elif hunger > 50.0 and health > 0.0:
		health = minf(100.0, health + regen * delta)
