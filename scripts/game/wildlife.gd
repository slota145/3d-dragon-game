class_name Wildlife
extends RefCounted
## Gatunki zwierzyny: modele z ruchomych części (assets/models/animals.glb, generator
## tools/blender/gen_animals.py) i parametry zachowania. `create("deer")` zwraca gotową ofiarę.

## Gatunek -> parametry Prey (+ siedlisko, szarża, latanie).
const SPECIES := {
	"rabbit": {"name": "Królik", "model": "Rabbit", "hp": 1.0, "food": 1.2, "size": 0.5, "radius": 0.35,
		"walk": 0.7, "flee": 4.2, "stamina": 3.5, "hops": true, "zigzag": 0.7, "alert": 7.0, "graze": 0.35},
	"sheep": {"name": "Owca", "model": "Sheep", "hp": 3.0, "food": 4.0, "size": 1.3, "radius": 0.7,
		"walk": 0.5, "flee": 3.0, "stamina": 5.0, "zigzag": 0.25, "alert": 9.0, "graze": 0.75},
	"deer": {"name": "Sarna", "model": "Deer", "hp": 2.5, "food": 3.5, "size": 1.4, "radius": 0.6,
		"walk": 0.8, "flee": 7.5, "stamina": 6.0, "zigzag": 0.35, "alert": 16.0, "graze": 0.95},
	"boar": {"name": "Dzik", "model": "Boar", "hp": 5.0, "food": 5.0, "size": 1.2, "radius": 0.55,
		"walk": 0.6, "flee": 5.0, "stamina": 5.0, "zigzag": 0.15, "alert": 10.0, "graze": 0.55,
		"charge_below": 3.2, "charge_damage": 6.0},
	"goat": {"name": "Koza", "model": "Goat", "hp": 2.5, "food": 3.0, "size": 1.1, "radius": 0.5,
		"walk": 0.6, "flee": 4.8, "stamina": 6.0, "zigzag": 0.45, "alert": 11.0, "graze": 0.8,
		"habitat": Prey.Habitat.MOUNTAIN},
	"duck": {"name": "Kaczka", "model": "Duck", "hp": 0.8, "food": 0.8, "size": 0.4, "radius": 0.3,
		"walk": 0.5, "flee": 8.0, "stamina": 9.0, "zigzag": 0.2, "alert": 8.0, "graze": 0.6,
		"habitat": Prey.Habitat.WATER, "flies": true},
	"chicken": {"name": "Kura", "model": "Chicken", "hp": 0.6, "food": 0.7, "size": 0.4, "radius": 0.3,
		"walk": 0.6, "flee": 3.4, "stamina": 2.5, "zigzag": 0.9, "alert": 6.0, "graze": 0.9},
}

## Model -> Array[[nazwa części, Mesh, Transform3D]].
static var _parts: Dictionary = {}


static func _load() -> void:
	if not _parts.is_empty():
		return
	var scene: Node = (load("res://assets/models/animals.glb") as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var bits := String(mi.name).split("_")
		if not _parts.has(bits[0]):
			_parts[bits[0]] = []
		_parts[bits[0]].append([bits[1], mi.mesh, mi.transform])
	scene.free()


## Węzeł „Body” z częściami modelu (Body, Head, LegFL… / LegL, WingL…).
static func build_body(model: String, view_range: float) -> Node3D:
	_load()
	var body := Node3D.new()
	body.name = "Body"
	for p: Array in _parts.get(model, []):
		var mi := MeshInstance3D.new()
		mi.name = p[0]
		mi.mesh = p[1]
		mi.transform = p[2]
		mi.visibility_range_end = view_range
		mi.visibility_range_end_margin = view_range * 0.1
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if view_range < 200.0 and p[0] != "Body":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # cień rzuca tylko tułów
		body.add_child(mi)
	return body


## Nowa ofiara danego gatunku (jeszcze poza drzewem sceny). `young` — mniejsze młode.
static func create(species: String, young: bool = false) -> Prey:
	var s: Dictionary = SPECIES[species]
	var p := Prey.new()
	var k := 0.6 if young else 1.0
	p.species = species
	p.display_name = s["name"]
	p.max_health = s["hp"] * k
	p.food = s["food"] * k
	p.body_size = s["size"] * k
	p.radius = s["radius"] * k
	p.walk_speed = s["walk"]
	p.flee_speed = s["flee"]
	p.stamina = s["stamina"]
	p.hops = s.get("hops", false)
	p.zigzag = s["zigzag"]
	p.alert_range = s["alert"]
	p.graze_pitch = s["graze"]
	p.habitat = s.get("habitat", Prey.Habitat.LAND)
	p.flies = s.get("flies", false)
	p.charge_below = 0.0 if young else s.get("charge_below", 0.0)
	p.charge_damage = s.get("charge_damage", 0.0)
	var body := build_body(s["model"], 140.0 if s["size"] < 1.0 else 260.0)
	body.scale = Vector3.ONE * k
	p.add_child(body)
	return p
