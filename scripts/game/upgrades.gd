class_name Upgrades
extends RefCounted
## Ulepszenia za złoto — „sen na skarbie”: śpiący smok wtapia złoto i klejnoty ze stosu
## w swoje ciało (łuski twardnieją i złocieją, skrzydła się wzmacniają). Kupuje się je
## przy śnie w legowisku, a stos skarbu naprawdę maleje. Poziomy 0..MAX_LEVEL.

const MAX_LEVEL := 3

## id: [nazwa, opis działania, koszty kolejnych poziomów]
const DEFS := {
	"scales": ["Twarde łuski", "−15% obrażeń na poziom; łuski złocieją", [80, 250, 600]],
	"wings": ["Silne skrzydła", "−20% zużycia siły lotu i +25% jej odnowy na poziom", [80, 250, 600]],
	"vitality": ["Smocze zdrowie", "+50% regeneracji zdrowia i −12% głodu na poziom", [80, 250, 600]],
	"eye": ["Bystre oko", "dłuższe słupy światła nad złotem i większy zasięg zbierania", [60, 180, 450]],
}
const ORDER := ["scales", "wings", "vitality", "eye"]


static func display_name(id: String) -> String:
	return DEFS[id][0]


static func description(id: String) -> String:
	return DEFS[id][1]


## Koszt następnego poziomu (-1 = maksymalny poziom osiągnięty).
static func next_cost(id: String, level: int) -> int:
	var costs: Array = DEFS[id][2]
	return costs[level] if level < costs.size() else -1
