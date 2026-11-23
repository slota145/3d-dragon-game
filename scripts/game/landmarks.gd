class_name Landmarks
extends Node3D
## Ciekawe miejsca (zasada „co ~20 s lotu coś ciekawego”): kamienne kręgi, ruiny wież, pradawne
## drzewa, szkielety olbrzymich smoków, skalne łuki (model: tools/blender/gen_landmarks.py).
## Rozstawione deterministycznie po świecie, osadzone w terenie, z kolizją. Każde trzeba
## odkryć (podejść / podlecieć) — przy każdym leży skrzynia skarbów (skrytka GoldFinds).

signal discovered(label: String, count: int, total: int)

const MODEL := "res://assets/models/landmarks.glb"
## rodzaj: [nazwa, miejsce na skrzynię (lokalnie, Godot), promień podstawy]
const KINDS := {
	"StoneCircle": ["Kamienny krąg", Vector3(0, 1.1, 0), 12.0],
	"Tower": ["Ruiny wieży", Vector3(0, 0.1, 0), 9.0],
	"Tree": ["Pradawne drzewo", Vector3(0.4, 32.0, 0.5), 9.0],
	"Bones": ["Szkielet pradawnego smoka", Vector3(0, 0.4, 2.0), 14.0],
	"Arch": ["Skalny łuk", Vector3(0, 25.5, 0), 18.0],
}
## Pierwsze miejsca blisko łąki (żeby pisklę szybko coś odkryło), potem losowo po świecie.
const ANCHORS := [["StoneCircle", Vector2(230, 170)], ["Tower", Vector2(-230, 260)], ["Bones", Vector2(160, -250)],
	["Tree", Vector2(-330, -40)], ["Arch", Vector2(40, 420)]]
const MIN_SPACING := 380.0
const TARGET := 40

var dragon: DragonController
## Id odkrytych miejsc (zapis gry).
var found: Array = []

var _places: Array[Dictionary] = []  # {id, kind, pos, yaw, node}
var _check_t: float = 0.0


func _ready() -> void:
	var scene: Node = (load(MODEL) as PackedScene).instantiate()
	var meshes := {}
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mi.name).trim_prefix("Landmark_")] = mi.mesh
	scene.free()
	_plan()
	for p in _places:
		var mi := MeshInstance3D.new()
		mi.name = p["id"]
		mi.mesh = meshes.get(p["kind"])
		mi.position = p["pos"]
		mi.rotation.y = p["yaw"]
		mi.visibility_range_end = 1600.0
		add_child(mi)
		mi.create_trimesh_collision()
		p["node"] = mi


func total() -> int:
	return _places.size()


func places() -> Array[Dictionary]:
	return _places


## Miejsca na skrzynie skarbów (globalnie) — przekazywane do GoldFinds jako skrytki.
func cache_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in _places:
		var local: Vector3 = KINDS[p["kind"]][1]
		out.append(global_position + p["pos"] + local.rotated(Vector3.UP, p["yaw"]))
	return out


func _plan() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var kinds: Array = KINDS.keys()
	for a: Array in ANCHORS:
		_try_place(a[0], a[1], rng, true)
	var tries := 0
	while _places.size() < TARGET and tries < 2000:
		tries += 1
		var lim := Terrain.HALF - 260.0
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		_try_place(kinds[rng.randi() % kinds.size()], p, rng, false)


func _try_place(kind: String, at: Vector2, rng: RandomNumberGenerator, search: bool) -> void:
	var radius: float = KINDS[kind][2]
	for attempt in (80 if search else 1):
		# kotwice: spirala wokół wskazanego punktu, aż znajdzie się dobre miejsce
		var p := at + (Vector2.from_angle(attempt * 2.4) * sqrt(attempt) * 22.0 if attempt > 0 else Vector2.ZERO)
		if not _good_spot(kind, p, radius):
			continue
		var base := INF
		for k in 6:  # najniższy punkt podstawy — model osadzony w terenie
			var q := p + (Vector2.from_angle(k * TAU / 6.0) * radius if k > 0 else Vector2.ZERO)
			base = minf(base, Terrain.height(q.x, q.y))
		_places.append({"id": "lm_%d_%d" % [int(p.x), int(p.y)], "kind": kind,
			"pos": Vector3(p.x, base - 0.4, p.y), "yaw": rng.randf() * TAU, "node": null})
		return


func _good_spot(kind: String, p: Vector2, radius: float) -> bool:
	if p.length() < 140.0:  # łąka startowa zostaje pusta
		return false
	if p.distance_to(Vector2(Lair.POSITION.x, Lair.POSITION.z)) < Lair.RADIUS + 60.0:
		return false
	for v: Array in Terrain.VILLAGES:  # z dala od wiosek i pól
		if p.distance_to(Vector2(v[0], v[1])) < v[2] + Terrain.FIELDS + 40.0:
			return false
	# blisko łąki gęściej (pisklę ma szybko coś odkryć), dalej co ~400 m
	var spacing := 230.0 if p.length() < 600.0 else MIN_SPACING
	for other in _places:
		var o: Vector3 = other["pos"]
		if p.distance_to(Vector2(o.x, o.z)) < spacing:
			return false
	var h := Terrain.height(p.x, p.y)
	if h < Terrain.WATER_LEVEL + 1.0 or h > (140.0 if kind == "Arch" else 45.0):
		return false
	for k in 4:  # w miarę płasko pod podstawą
		var q := p + Vector2.from_angle(k * TAU / 4.0) * radius
		var hq := Terrain.height(q.x, q.y)
		if hq < Terrain.WATER_LEVEL + 0.5 or absf(hq - h) > (8.0 if kind == "Arch" else 4.0):
			return false
	return true


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0 or not dragon:
		return
	_check_t = 0.3
	var dp := dragon.global_position
	for p in _places:
		if p["id"] in found:
			continue
		var pos: Vector3 = p["pos"]
		var reach: float = KINDS[p["kind"]][2] + 25.0 + dragon.stats.size * 2.0
		if Vector2(dp.x - pos.x, dp.z - pos.z).length() < reach and dp.y < pos.y + 80.0:
			found.append(p["id"])
			discovered.emit(KINDS[p["kind"]][0], found.size(), _places.size())
