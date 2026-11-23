class_name GoldFinds
extends Node3D
## Złoto w świecie (przed pojawieniem się ludzi):
## - błyszczące znaleziska na łące (monety, kielichy, korony) — co dzień nowe (ziarno = dzień),
## - ukryte skrytki: skrzynie na szczytach skalnych słupów — jednorazowe, osiągalne tylko lotem.
## Każde znalezisko ma świetlny słup (widać je z daleka na telefonie). Zbiera się je dotykiem.

signal picked(value: int, item_name: String, where: Vector3)

const ITEMS := {  # rodzaj: [siatka, nazwa, wartość min, wartość maks., skala]
	"coins": ["Coin", "Monety", 4, 10, 1.6],
	"goblet": ["Goblet", "Kielich", 15, 25, 1.4],
	"crown": ["Crown", "Korona", 30, 45, 1.4],
	"chest": ["Chest", "Skrzynia skarbów", 90, 160, 1.3],
}

@export var finds_per_day: int = 34
@export var area: float = 320.0

var dragon: DragonController
## Znaleziska zebrane dzisiaj (id) i skrytki zebrane na zawsze (id) — zapisywane w save.
var taken_today: Array = []
var caches_taken: Array = []
var _day: int = -1
var _check_t: float = 0.0


## Rozłóż znaleziska dnia `day` i skrytki na szczytach `cache_spots` (pomija już zebrane).
func setup(day: int, cache_spots: Array[Vector3]) -> void:
	for c in get_children():
		c.queue_free()
	if day != _day and _day != -1:
		taken_today.clear()
	_day = day
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * day + 13
	for i in finds_per_day:
		var id := "d%d_%d" % [day, i]
		var roll := rng.randf()
		var kind := "coins" if roll < 0.65 else ("goblet" if roll < 0.9 else "crown")
		var pos := Vector3(rng.randf_range(-area, area), 0.0, rng.randf_range(-area, area))
		var value := rng.randi_range(ITEMS[kind][2], ITEMS[kind][3])
		if Vector2(pos.x - Lair.POSITION.x, pos.z - Lair.POSITION.z).length() < Lair.RADIUS + 3.0:
			continue
		if not Terrain.is_walkable(pos.x, pos.z):
			continue
		pos.y = Terrain.height(pos.x, pos.z)
		if not id in taken_today:
			_spawn(id, kind, pos, value, rng.randf() * TAU)
	for i in cache_spots.size():
		var id := "cache_%d" % i
		if not id in caches_taken:
			_spawn(id, "chest", cache_spots[i], 90 + (i * 37) % 71, float(i))


func _spawn(id: String, kind: String, pos: Vector3, value: int, yaw: float) -> void:
	var item: Array = ITEMS[kind]
	var root := Node3D.new()
	root.name = id
	root.position = pos
	root.set_meta("value", value)
	root.set_meta("label", item[1])
	root.set_meta("cache", kind == "chest")
	add_child(root)
	var mi := MeshInstance3D.new()
	mi.name = "Item"
	mi.mesh = Treasure.mesh(item[0])
	mi.scale = Vector3.ONE * float(item[4])
	mi.rotation.y = yaw
	if kind == "coins":  # kupka monet
		for k in 5:
			var c := MeshInstance3D.new()
			c.mesh = mi.mesh
			c.position = Vector3(cos(k * 1.3) * 0.18, 0.035 * k, sin(k * 1.3) * 0.18)
			c.rotation = Vector3(0.2 * sin(k), k, 0.2 * cos(k))
			mi.add_child(c)
	root.add_child(mi)
	# świetlny słup — złoto widać z daleka
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.16
	cyl.height = 9.0 if kind == "chest" else 5.0
	cyl.radial_segments = 6
	cyl.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.72, 0.1, 0.55)  # zwykłe mieszanie — w dzień nie blednie do bieli
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	beam.mesh = cyl
	beam.name = "Beam"
	beam.position.y = cyl.height / 2.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	_scale_beam(beam)


## „Bystre oko”: dłuższe słupy światła nad złotem.
func eye_level() -> int:
	return dragon.stats.level("eye") if dragon else 0


func refresh_beams() -> void:
	for f in get_children():
		var beam := f.get_node_or_null("Beam") as MeshInstance3D
		if beam:
			_scale_beam(beam)


func _scale_beam(beam: MeshInstance3D) -> void:
	var k := 1.0 + 0.8 * eye_level()
	beam.scale = Vector3(1.0 + 0.3 * eye_level(), k, 1.0 + 0.3 * eye_level())
	beam.position.y = (beam.mesh as CylinderMesh).height * k / 2.0


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f: Node3D in get_children():
		var item := f.get_node_or_null("Item") as Node3D
		if item:
			item.rotation.y += delta * 0.8  # powolny obrót = błysk na ściankach
			item.position.y = 0.15 + 0.1 * sin(t * 2.0 + f.position.x)
	_check_t -= delta
	if _check_t > 0.0 or not dragon:
		return
	_check_t = 0.1
	var reach := 1.2 + dragon.stats.size * 0.3 + 0.6 * eye_level()
	var dp := dragon.global_position
	for f: Node3D in get_children():
		if f.is_queued_for_deletion():
			continue
		var d := f.global_position - dp
		if Vector2(d.x, d.z).length() < reach + 0.5 and absf(d.y) < 2.0 + dragon.stats.size * 0.5:
			_collect(f)


func _collect(f: Node3D) -> void:
	if f.get_meta("cache", false):
		caches_taken.append(String(f.name))
	else:
		taken_today.append(String(f.name))
	picked.emit(int(f.get_meta("value", 0)), String(f.get_meta("label", "")), f.global_position)
	f.queue_free()


## Do testów i narzędzi: lista pozostałych znalezisk.
func remaining() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for f: Node3D in get_children():
		if not f.is_queued_for_deletion():
			out.append(f)
	return out
