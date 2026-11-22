class_name DragonStats
extends Node
## Statystyki smoka: rozmiar (płynny wzrost), stadia wg progów rozmiaru, zdrowie, głód.
## Rozmiar = długość smoka w metrach (model 1:1 ma `model_size` m).

signal size_changed(size: float)
signal stage_changed(stage: int, stage_name: String)
signal ate(food: float, prey_name: String, growth: float)
signal died

enum Stage { HATCHLING, JUVENILE, ADULT, ANCIENT }
const STAGE_NAMES := ["Pisklę", "Młodzik", "Dorosły", "Pradawny"]
## Progi rozmiaru (m), od których zaczyna się dane stadium.
const STAGE_MIN_SIZE := [0.0, 4.0, 9.0, 16.0]

@export var start_size: float = 1.0
@export var max_size: float = 20.0
## Długość modelu smoka przy skali 1 (m).
@export var model_size: float = 12.0
## Wzrost procentowy: przyrost = rozmiar × growth_rate × wartość posiłku.
## Wartość posiłku = jedzenie × (rozmiar ofiary / rozmiar smoka, maks. 1) — małe ofiary
## dają dużemu smokowi coraz mniej.
@export var growth_rate: float = 0.1
## Trawienie: zjedzony wzrost przybywa płynnie (m/s, minimum) — bez skoków rozmiaru.
@export var digest_speed: float = 0.35
## Spadek głodu (pkt/s): 100 -> 0 w ok. 3,7 min.
@export var hunger_decay: float = 0.45
## Ile głodu zaspokaja 1 punkt jedzenia.
@export var hunger_per_food: float = 12.0
@export var starve_damage: float = 2.0
@export_group("Wytrzymałość lotu")
## Odnowa siły lotu na ziemi (pkt/s) i opóźnienie po lądowaniu (s).
@export var stamina_regen: float = 22.0
@export var stamina_regen_delay: float = 0.6
## Zużycie siły maleje z rozmiarem: mnożnik = (4 m / rozmiar)^wykładnik — młodzik
## męczy się szybko, dorosły prawie wcale.
@export var stamina_exponent: float = 2.5
@export_group("")
@export var regen: float = 1.5

var size: float = 2.4
var health: float = 100.0
var hunger: float = 70.0
var stage: int = Stage.HATCHLING
## Siła lotu 0..100: machanie, zawis, zryw i start ją zużywają; odnawia się na ziemi.
var stamina: float = 100.0
## Złoto niesione przy sobie (odkłada się na stos w legowisku; po śmierci część przepada).
var gold: int = 0
## Poziomy ulepszeń za złoto („sen na skarbie”): id -> poziom (patrz Upgrades).
var upgrades: Dictionary = {}

signal upgraded(id: String, level: int)
var _regen_wait: float = 0.0
## Wzrost czekający na „strawienie” (m).
var pending_growth: float = 0.0


func _ready() -> void:
	size = start_size
	stage = stage_for(size)


func scale_factor() -> float:
	return size / model_size


## „Młodość” proporcji: 1 = świeżo wyklute pisklę (start_size), 0 = dorosły (próg Dorosłego).
## Liczona logarytmicznie — proporcje zmieniają się najszybciej, gdy smok jest mały.
func youth() -> float:
	var adult: float = STAGE_MIN_SIZE[Stage.ADULT]
	var t := log(maxf(size, 0.01) / start_size) / log(adult / start_size)
	return 1.0 - smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))


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
	var meal := food * clampf(prey_size / size, 0.05, 1.0)
	var growth := size * growth_rate * meal
	hunger = minf(100.0, hunger + food * hunger_per_food * clampf(2.0 * prey_size / size, 0.1, 1.0))
	pending_growth += growth
	ate.emit(meal, prey_name, growth)


func set_size(s: float) -> void:
	size = clampf(s, 0.5, max_size)
	size_changed.emit(size)
	var new_stage := stage_for(size)
	if new_stage != stage:
		var up := new_stage > stage
		stage = new_stage
		if up:
			stage_changed.emit(stage, stage_name())


func level(id: String) -> int:
	return int(upgrades.get(id, 0))


## Kup kolejny poziom ulepszenia (koszt płaci świat ze stosu skarbu).
func upgrade(id: String) -> void:
	upgrades[id] = mini(level(id) + 1, Upgrades.MAX_LEVEL)
	upgraded.emit(id, level(id))


## Mnożnik zużycia siły lotu (1 = świeży młodzik 4 m); „Silne skrzydła” go zmniejszają.
func stamina_drain_mult() -> float:
	var wings := 1.0 - 0.2 * level("wings")
	return clampf(pow(STAGE_MIN_SIZE[Stage.JUVENILE] / size, stamina_exponent), 0.03, 1.0) * wings


## Zużyj siłę lotu (koszt dla młodzika; skalowany rozmiarem). Zwraca false, gdy brak sił.
func use_stamina(cost: float) -> bool:
	var c := cost * stamina_drain_mult()
	_regen_wait = stamina_regen_delay
	if stamina <= 0.0 or (cost > 0.0 and stamina < c * 0.5):
		return false
	stamina = maxf(0.0, stamina - c)
	return true


## Odnowa siły (na ziemi) — woła kontroler co klatkę fizyki.
func rest(delta: float) -> void:
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	stamina = minf(100.0, stamina + stamina_regen * (1.0 + 0.25 * level("wings")) * delta)


## Wczytanie stanu z zapisu: bez napisów o nowym stadium.
func restore(data: Dictionary) -> void:
	pending_growth = float(data.get("pending_growth", 0.0))
	health = float(data.get("health", 100.0))
	hunger = float(data.get("hunger", 70.0))
	stamina = float(data.get("stamina", 100.0))
	gold = int(data.get("gold", 0))
	upgrades.clear()
	var up: Dictionary = data.get("upgrades", {})
	for id in up:
		upgrades[id] = int(up[id])
		upgraded.emit(id, int(up[id]))
	size = clampf(float(data.get("size", start_size)), 0.5, max_size)
	stage = stage_for(size)
	size_changed.emit(size)


func to_save() -> Dictionary:
	return {"size": size, "pending_growth": pending_growth, "health": health, "hunger": hunger,
		"stamina": stamina, "gold": gold, "upgrades": upgrades.duplicate()}


## Natychmiastowa zmiana rozmiaru (narzędzia dewelopera): bez trawienia zaległego wzrostu.
func set_size_instant(s: float) -> void:
	pending_growth = 0.0
	set_size(s)


func damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount * (1.0 - 0.15 * level("scales")))
	if health <= 0.0:
		died.emit()


func revive(hp: float, food: float) -> void:
	health = hp
	hunger = food


func _process(delta: float) -> void:
	if pending_growth > 0.0:
		var step := minf(pending_growth, maxf(digest_speed * size / 4.0, pending_growth * 1.2) * delta)
		pending_growth -= step
		set_size(size + step)
	hunger = maxf(0.0, hunger - hunger_decay * (1.0 - 0.12 * level("vitality")) * delta)
	if hunger <= 0.0:
		damage(starve_damage * delta)
	elif hunger > 50.0 and health > 0.0:
		health = minf(100.0, health + regen * (1.0 + 0.5 * level("vitality")) * delta)
