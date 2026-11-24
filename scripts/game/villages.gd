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
signal cart_destroyed(cart: MerchantCart)

var _carts: Array[MerchantCart] = []

## Nazwy wiosek (komunikaty: danina, gniew).
const NAMES := ["Wierzbin", "Dębowo", "Złotopole", "Mokradło", "Brzezie", "Kamionka"]

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


## Wioska, do której należy punkt (najbliższy środek w zasięgu placu i pól), albo -1.
func village_at(p: Vector3) -> int:
	for i in Terrain.VILLAGES.size():
		var v: Array = Terrain.VILLAGES[i]
		if Vector2(p.x - v[0], p.z - v[1]).length() < float(v[2]) + Terrain.FIELDS + 10.0:
			return i
	return -1


## Kamień ofiarny na skraju placu, od strony legowiska — tam wioska zostawia daninę.
func tribute_stone(i: int) -> Vector3:
	var v: Array = Terrain.VILLAGES[i]
	var c := Vector2(v[0], v[1])
	var to_lair := (Vector2(Lair.POSITION.x, Lair.POSITION.z) - c).normalized()
	var p := c + to_lair * float(v[2]) * 0.8
	return Vector3(p.x, Terrain.height(p.x, p.y), p.y)


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
	_build_fields(i, root)
	# kamień ofiarny (płaski głaz) — miejsce daniny
	var stone := MeshInstance3D.new()
	stone.mesh = _nature_mesh("Rock_Flat")
	var sp := tribute_stone(i)
	stone.position = sp
	stone.scale = Vector3(1.6, 1.4, 1.6)
	root.add_child(stone)
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


## Granice działek pól: żywopłoty albo kamienne murki (z przerwami-przejściami),
## pastwisko ogrodzone płotem. MultiMesh — setki odcinków bez setek węzłów.
func _build_fields(i: int, root: Node3D) -> void:
	var v: Array = Terrain.VILLAGES[i]
	var c := Vector2(v[0], v[1])
	var r: float = v[2]
	var sectors := Terrain.FIELD_SECTORS
	var walls_first := i % 2 == 1  # część wiosek ma murki, część żywopłoty
	var parts := {"Hedge": [], "StoneWall": [], "Fence": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = 901 + i
	var seg := 4.0
	# granice promieniste (między wycinkami)
	for k in sectors:
		var a := float(k) / sectors * TAU - PI
		var dir := Vector2.from_angle(a)
		var pasture_edge := Terrain.is_pasture(Vector3i(i, k, 0)) or Terrain.is_pasture(Vector3i(i, (k - 1 + sectors) % sectors, 0))
		var d := r + 2.0
		while d < r + Terrain.FIELDS - 2.0:
			var p := c + dir * (d + seg * 0.5)
			var kind: String = "Fence" if pasture_edge and d < r + Terrain.FIELDS * 0.5 else \
				("StoneWall" if (walls_first != (k % 3 == 0)) else "Hedge")
			if rng.randf() > 0.1:  # przerwy — przejścia
				parts[kind].append(_seg_xf(p, a))
			d += seg
	# granice łukowe: środek pola i zewnętrzny brzeg
	for ring_r: float in [r + 1.0, r + Terrain.FIELDS * 0.5, r + Terrain.FIELDS - 1.0]:
		var n := int(TAU * ring_r / seg)
		for k in n:
			var a := (float(k) + 0.5) / n * TAU - PI
			var sector := int(floor((a + PI) / TAU * sectors)) % sectors
			var pasture := Terrain.is_pasture(Vector3i(i, sector, 0)) and ring_r < r + Terrain.FIELDS * 0.6
			if ring_r == r + 1.0 and not pasture:
				continue  # od strony wioski otwarte, poza pastwiskiem
			var kind: String = "Fence" if pasture else ("StoneWall" if walls_first else "Hedge")
			if rng.randf() > 0.08:
				parts[kind].append(_seg_xf(c + Vector2.from_angle(a) * ring_r, a + PI / 2.0))
	for kind: String in parts:
		if parts[kind].is_empty():
			continue
		var mesh: Mesh = _meshes.get(kind) if kind == "Fence" else _nature_mesh(kind)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = parts[kind].size()
		for k in parts[kind].size():
			mm.set_instance_transform(k, parts[kind][k])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.visibility_range_end = 900.0
		root.add_child(inst)


## Odcinek granicy (4 m wzdłuż osi X modelu) wzdłuż kierunku `angle` (płaszczyzna XZ).
func _seg_xf(p: Vector2, angle: float) -> Transform3D:
	var basis := Basis(Vector3.UP, -angle)
	return Transform3D(basis, Vector3(p.x, Terrain.height(p.x, p.y) - 0.05, p.y))


var _nature_meshes: Dictionary = {}


func _nature_mesh(name: String) -> Mesh:
	if _nature_meshes.is_empty():
		var scene: Node = (load("res://assets/models/nature.glb") as PackedScene).instantiate()
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			_nature_meshes[String(mi.name)] = mi.mesh
		scene.free()
	return _nature_meshes.get(name)


## Środek pastwiska wioski (globalnie).
func pasture_center(i: int) -> Vector3:
	var v: Array = Terrain.VILLAGES[i]
	var sector := (i * 3 + 2) % Terrain.FIELD_SECTORS
	var a := (float(sector) + 0.5) / Terrain.FIELD_SECTORS * TAU - PI
	var d: float = float(v[2]) + Terrain.FIELDS * 0.25
	var p := Vector2(v[0], v[1]) + Vector2.from_angle(a) * d
	return Vector3(p.x, Terrain.height(p.x, p.y), p.y)


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


var _night_lights: Array[OmniLight3D] = []


## Noc (0..1): okna chat świecą ciepło, nad placem wioski lampa.
func set_night(n: float) -> void:
	var cottage: Mesh = _meshes.get("Cottage")
	if cottage:
		for i in cottage.get_surface_count():
			var mat := cottage.surface_get_material(i) as StandardMaterial3D
			if mat and mat.resource_name.ends_with("Window"):
				mat.emission_enabled = n > 0.01
				mat.emission = Color(1.0, 0.72, 0.35)
				mat.emission_energy_multiplier = 3.0 * n
	if _night_lights.is_empty() and n > 0.01:
		for i in Terrain.VILLAGES.size():
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.7, 0.4)
			l.omni_range = 38.0
			l.position = center(i) + Vector3.UP * 6.0
			add_child(l)
			_night_lights.append(l)
	for l in _night_lights:
		l.light_energy = 1.6 * n
		l.visible = n > 0.01


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
			var pastc := pasture_center(i)  # owce na ogrodzonym pastwisku
			for k in 4:
				_spawn_sheep(pastc + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), pastc, 12.0)
	_hunters.clear()
	set_hunters(hunters_per_village)
	_spawn_carts()


## Wozy kupieckie: po jednym na każdej drodze (nowy dzień — zniszczone wracają).
func _spawn_carts() -> void:
	for c in _carts:
		if is_instance_valid(c):
			c.queue_free()
	_carts.clear()
	for i in Terrain.ROAD_PAIRS.size():
		var cart := MerchantCart.new()
		cart.name = "Cart_%d" % i
		add_child(cart)
		cart.setup(Terrain.road_points(i), _meshes.get("Wagon"), _meshes.get("Horse"), 0.3 + 0.1 * i)
		cart.destroyed.connect(func(c: MerchantCart) -> void: cart_destroyed.emit(c))
		_carts.append(cart)


func carts() -> Array[MerchantCart]:
	var out: Array[MerchantCart] = []
	for c in _carts:
		if is_instance_valid(c):
			out.append(c)
	return out


## Myśliwi z łukami w każdej wiosce (więcej przy większym rozgłosie).
func set_hunters(per_village: int) -> void:
	hunters_per_village = per_village
	_hunters = hunters()
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
	var out: Array[Villager] = []
	for h in _hunters:
		if is_instance_valid(h) and h.is_alive():
			out.append(h)
	return out


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


func _spawn_sheep(pos: Vector3, pen: Vector3, leash: float = 7.0) -> void:
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
	p.home_radius = leash
	p.dragon = dragon
	add_child(p)
	p.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z), pos.z)
	p.killed.connect(func(pr: Prey) -> void: eaten_from_village.emit(pr))
	_residents.append(p)


func residents() -> Array[Node3D]:
	# bez typu parametru — zwolnione (zjedzone) obiekty nie mogą przerwać filtrowania
	var out: Array[Node3D] = []
	for r in _residents:
		if is_instance_valid(r):
			out.append(r)
	return out
