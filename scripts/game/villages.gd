class_name Villages
extends Node3D
## Wioski (Terrain.VILLAGES): studnia na środku, chaty wokół placu, stodoła, stogi siana,
## zagroda z owcami (płot) i pola dookoła (kolor terenu). Mieszkańcy: wieśniacy z widłami
## i pasterz przy zagrodzie (Villager). Modele: village.glb i people.glb (generatory Blendera).
## Zjedzeni mieszkańcy i owce wracają następnego dnia (`repopulate`).

signal poked(by: Villager, damage: float)
signal scared(by: Villager)
signal eaten_from_village(prey: Prey)
signal building_burnt(building: Node3D)

@export var villagers_per_village: int = 5
@export var sheep_per_pen: int = 5

var dragon: DragonController
var sheep_model: PackedScene

var _meshes: Dictionary = {}
var _people: Dictionary = {}  # rola -> Array[[name, mesh, pivot Transform3D]]
var _residents: Array[Node3D] = []
var _hunters: Array[Villager] = []
var _burnable: Array[MeshInstance3D] = []
## Jak długo płonie budynek, zanim zostanie zgliszczem (s).
const BURN_TIME := 12.0
## Myśliwi na wioskę (zależy od rozgłosu smoka; ustawia świat).
var hunters_per_village: int = 0


func _ready() -> void:
	for path in ["res://assets/models/village.glb"]:
		var scene: Node = (load(path) as PackedScene).instantiate()
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			_meshes[String(mi.name).trim_prefix("Village_")] = mi.mesh
		scene.free()
	var ppl: Node = (load("res://assets/models/people.glb") as PackedScene).instantiate()
	for mi: MeshInstance3D in ppl.find_children("*", "MeshInstance3D", true, false):
		var parts := String(mi.name).split("_")
		if not _people.has(parts[0]):
			_people[parts[0]] = []
		var xf := mi.transform
		xf.origin.x = 0.0 if parts[1] == "Body" else xf.origin.x - _role_offset(ppl, parts[0])
		_people[parts[0]].append([parts[1], mi.mesh, xf])
	ppl.free()
	for i in Terrain.VILLAGES.size():
		_build_village(i)
	repopulate()


## Generator rozstawia postacie wzdłuż X (podgląd) — przesunięcie roli = położenie jej tułowia.
func _role_offset(scene: Node, role: String) -> float:
	var body := scene.find_child(role + "_Body", true, false) as Node3D
	return body.transform.origin.x if body else 0.0


func center(i: int) -> Vector3:
	var v: Array = Terrain.VILLAGES[i]
	return Vector3(v[0], Terrain.height(v[0], v[1]), v[1])


func pen_center(i: int) -> Vector3:
	var v: Array = Terrain.VILLAGES[i]
	var a := float(i) * 1.7 + 0.6
	var r: float = v[2] * 0.62
	var p := Vector3(v[0] + cos(a) * r, 0.0, v[1] + sin(a) * r)
	p.y = Terrain.height(p.x, p.z)
	return p


func _build_village(i: int) -> void:
	var v: Array = Terrain.VILLAGES[i]
	var c := center(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 555 + i
	var root := Node3D.new()
	root.name = "Village_%d" % i
	add_child(root)
	_place(root, "Well", c, rng.randf() * TAU)
	var r: float = v[2]
	var n := rng.randi_range(5, 7)
	var pen_dir := float(i) * 1.7 + 0.6
	for k in n:
		var a := TAU * k / n + rng.randf_range(-0.2, 0.2)
		if absf(angle_difference(a, pen_dir)) < 0.6:
			continue  # tam stoi zagroda
		var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(r * 0.3, r * 0.5)
		# drzwiami (+Z modelu) do studni
		_place(root, "Barn" if k == 0 else "Cottage", p, atan2(c.x - p.x, c.z - p.z), true)
		if rng.randf() < 0.6:
			var hp := p + Vector3(cos(a + 0.5), 0, sin(a + 0.5)) * 9.0
			_place(root, "Hay", hp, rng.randf() * TAU)
	# zagroda: płot na okręgu
	var pc := pen_center(i)
	var pen_r := 9.0
	var segs := 14
	for k in segs:
		var a0 := TAU * k / segs
		var mid := pc + Vector3(cos(a0 + PI / segs), 0, sin(a0 + PI / segs)) * pen_r
		if k == 0:
			continue  # brama
		_place(root, "Fence", mid, -(a0 + PI / segs) + PI / 2.0, true)


func _place(root: Node3D, item: String, pos: Vector3, yaw: float, collide: bool = false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes.get(item)
	mi.position = Vector3(pos.x, Terrain.height(pos.x, pos.z), pos.z)
	mi.rotation.y = yaw
	mi.visibility_range_end = 1300.0
	root.add_child(mi)
	if item in ["Cottage", "Barn", "Hay"]:
		mi.add_to_group("flammable")
		_burnable.append(mi)
	if collide and mi.mesh:
		var aabb: AABB = mi.mesh.get_aabb()
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = aabb.size
		cs.shape = shape
		cs.position = aabb.get_center()
		body.add_child(cs)
		mi.add_child(body)


## Ogień smoka w punkcie: podpala budynki w zasięgu.
func ignite_near(at: Vector3, radius: float) -> void:
	for mi in _burnable:
		if not mi.is_in_group("flammable"):
			continue
		var half: Vector3 = mi.mesh.get_aabb().size * 0.5
		var d := Vector2(mi.global_position.x - at.x, mi.global_position.z - at.z).length()
		if d < radius + maxf(half.x, half.z) and at.y < mi.global_position.y + half.y * 2.5 + radius:
			_ignite(mi)


func _ignite(mi: MeshInstance3D) -> void:
	mi.remove_from_group("flammable")
	var size: Vector3 = mi.mesh.get_aabb().size
	var flames := FireFx.building_fire(size)
	flames.name = "Fire"
	mi.add_child(flames)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = maxf(size.x, size.z) * 1.6
	light.light_energy = 2.5
	light.position = Vector3(0, size.y * 0.7, 0)
	mi.add_child(light)
	get_tree().create_timer(BURN_TIME).timeout.connect(func() -> void:
		if not is_instance_valid(mi):
			return
		flames.emitting = false
		light.queue_free()
		var burnt := StandardMaterial3D.new()  # zgliszcza
		burnt.albedo_color = Color(0.08, 0.06, 0.05, 0.85)
		burnt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_overlay = burnt
		var smoke := FireFx.smoke(size)
		smoke.name = "Smoke"
		mi.add_child(smoke)
		building_burnt.emit(mi))


func burning_or_burnt() -> Array[MeshInstance3D]:
	return _burnable.filter(func(mi: MeshInstance3D) -> bool: return not mi.is_in_group("flammable"))


## Odbudowa spalonych budynków (nowy dzień).
func rebuild() -> void:
	for mi in _burnable:
		if mi.is_in_group("flammable"):
			continue
		mi.material_overlay = null
		for n in ["Fire", "Smoke", "FireLight"]:
			var c := mi.get_node_or_null(n)
			if c:
				c.queue_free()
		mi.add_to_group("flammable")


## Mieszkańcy i owce w zagrodach (nowa gra / nowy dzień — zjedzeni wracają).
func repopulate() -> void:
	for r in _residents:
		if is_instance_valid(r):
			r.queue_free()
	_residents.clear()
	for i in Terrain.VILLAGES.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = 777 + i
		var c := center(i)
		var v: Array = Terrain.VILLAGES[i]
		for k in villagers_per_village:
			var p: Vector3 = c + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * float(v[2]) * 0.4
			_spawn_person("Villager", "Wieśniak", p, c, float(v[2]) * 0.55)
		var pc := pen_center(i)
		_spawn_person("Shepherd", "Pasterz", pc + Vector3(11, 0, 0), pc, 16.0)
		if sheep_model:
			for k in sheep_per_pen:
				_spawn_sheep(pc + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), pc)
	_hunters.clear()
	set_hunters(hunters_per_village)


## Myśliwi z łukami w każdej wiosce (więcej przy większym rozgłosie).
func set_hunters(per_village: int) -> void:
	hunters_per_village = per_village
	_hunters = _hunters.filter(func(h: Villager) -> bool: return is_instance_valid(h) and h.is_alive())
	for i in Terrain.VILLAGES.size():
		var here := _hunters.filter(func(h: Villager) -> bool: return h.home.distance_to(center(i)) < 1.0)
		for k in range(here.size(), per_village):
			var c := center(i)
			var a := randf() * TAU
			var h := _spawn_person("Hunter", "Myśliwy", c + Vector3(cos(a), 0, sin(a)) * 12.0, c,
				float(Terrain.VILLAGES[i][2]) * 0.8)
			h.archer = true
			h.max_health = 3.0
			h.health = 3.0
			h.shot_arrow.connect(func(arrow: Node3D) -> void: add_child(arrow))
			_hunters.append(h)


func hunters() -> Array[Villager]:
	return _hunters.filter(func(h: Villager) -> bool: return is_instance_valid(h) and h.is_alive())


func _spawn_person(role: String, label: String, pos: Vector3, home: Vector3, radius: float) -> Villager:
	var v := Villager.new()
	v.display_name = label
	v.max_health = 2.5
	v.food = 3.5
	v.body_size = 1.0
	v.radius = 0.45
	v.walk_speed = 0.9
	v.flee_speed = 4.6
	v.stamina = 8.0
	v.home = home
	v.home_radius = radius
	v.dragon = dragon
	var body := Node3D.new()
	body.name = "Body"
	for p: Array in _people.get(role, []):
		var mi := MeshInstance3D.new()
		mi.name = p[0]
		mi.mesh = p[1]
		mi.transform = p[2]
		body.add_child(mi)
	v.add_child(body)
	add_child(v)
	v.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z), pos.z)
	v.poked_dragon.connect(func(by: Villager, dmg: float) -> void: poked.emit(by, dmg))
	v.scared.connect(func(by: Villager) -> void: scared.emit(by))
	v.killed.connect(func(p: Prey) -> void: eaten_from_village.emit(p))
	_residents.append(v)
	return v


func _spawn_sheep(pos: Vector3, pen: Vector3) -> void:
	var p := Prey.new()
	var body := sheep_model.instantiate() as Node3D
	body.name = "Body"
	p.add_child(body)
	p.display_name = "Owca z farmy"
	p.max_health = 3.0
	p.food = 4.0
	p.body_size = 1.3
	p.radius = 0.7
	p.walk_speed = 0.5
	p.flee_speed = 2.6
	p.stamina = 4.0
	p.hops = false
	p.zigzag = 0.25
	p.alert_range = 9.0
	p.home = pen
	p.home_radius = 7.0
	p.dragon = dragon
	add_child(p)
	p.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z), pos.z)
	p.killed.connect(func(pr: Prey) -> void: eaten_from_village.emit(pr))
	_residents.append(p)


func residents() -> Array[Node3D]:
	return _residents.filter(func(r: Node3D) -> bool: return is_instance_valid(r))
