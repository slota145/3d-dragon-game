class_name Lair
extends Node3D
## Legowisko: skalne wzgórze z jaskinią (model z tools/blender/gen_lair.py), gniazdo, jajo.
## Pivot = środek komory na ziemi (gniazdo); wejście od strony +Z (lokalnie).
## Kolizja skały (trimesh) powstaje w _ready. W komorze można spać (DragonController w zasięgu).

## Położenie legowiska w świecie: w zboczu gór na północ od łąki, wejście patrzy na łąkę
## wokół (0, 0, 0). Przed wejściem półka skalna (LEDGE) nad doliną, z niej w dół ścieżka (RAMP).
## Teren wokół (masyw, półkę, ścieżkę, wycięcie pod jaskinię) rzeźbi Terrain.lair_carve.
const POSITION := Vector3(0.0, 22.0, -230.0)
## Promień skalnej kopuły (m) — tu nie stawiamy drzew, skał ani zwierząt.
const RADIUS := 50.0
## Półka przed wejściem (lokalnie, +Z = na zewnątrz): połowa szerokości i koniec (krawędź urwiska).
const LEDGE_HALF := 42.0
const LEDGE_START := 31.0
const LEDGE_END := 66.0
## Wylot tunelu w ścianie urwiska (lokalnie z) — tu stoi łuk skalny.
const MOUTH_Z := 33.0
## Ścieżka z półki w dół: pas wzdłuż +X przy krawędzi półki [z od, z do], długość (m).
const RAMP_Z := [50.0, 63.0]
const RAMP_LEN := 120.0
## Promień komory, w której można spać (m).
const SLEEP_RADIUS := 15.0
const EGG_COLOR := Color(0.93, 0.88, 0.74)

signal hatched

## Stos skarbu przy tylnej ścianie komory.
var pile: TreasurePile
var _egg: MeshInstance3D
var _shells: Node3D


func _ready() -> void:
	var model: Node3D = load("res://assets/models/lair.glb").instantiate()
	add_child(model)
	var rock := model.find_child("Lair_Rock", true, false) as MeshInstance3D
	if rock:
		rock.create_trimesh_collision()
	var arch := model.find_child("Lair_Arch", true, false) as MeshInstance3D
	if arch:  # łuk skalny z nawisem nad wylotem tunelu
		arch.create_trimesh_collision()
	pile = TreasurePile.new()
	pile.name = "TreasurePile"
	pile.position = Vector3(0, 0, -9.5)
	add_child(pile)
	var light := OmniLight3D.new()  # ciepłe światło w komorze (gniazdo)
	light.position = Vector3(0, 6, 0)
	light.light_color = Color(1.0, 0.78, 0.5)
	light.light_energy = 1.6
	light.omni_range = 22.0
	add_child(light)
	var glow := OmniLight3D.new()  # chłodny poblask kryształów
	glow.position = Vector3(0, 4, -12)
	glow.light_color = Color(0.5, 0.85, 1.0)
	glow.light_energy = 0.9
	glow.omni_range = 16.0
	add_child(glow)
	_build_lid()


## Wieczko: zbocze nad komorą i tunelem. Teren (mapa wysokości) ma tam podłogę jaskini, więc
## z góry byłby otwór — wieczko to siatka zbocza bez wycięcia (Terrain.lair_lid_height),
## z kolorami terenu i kolizją (smok może wylądować na zboczu nad jaskinią).
const LID_FRONT := 12.0


func _build_lid() -> void:
	const STEP := 2.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var p0 := global_position
	for gz in range(-28, int(MOUTH_Z) - 1, int(STEP)):
		for gx in range(-28, 28, int(STEP)):
			var cx := float(gx) + STEP * 0.5
			var cz := float(gz) + STEP * 0.5
			# komórki nad wnętrzem (z marginesem — mapa wysokości ma oczka 4 m)
			var near := false
			for o: Vector2 in [Vector2(0, 0), Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
				if Terrain.in_lair_interior(cx + o.x, cz + o.y):
					near = true
			if not near or (cz > LID_FRONT and absf(cx) < 20.0):
				continue  # dalej (nad wylotem tunelu) zbocze zakrywa łuk skalny z nawisem
			var c: Array[Vector3] = []
			for k: Vector2 in [Vector2(gx, gz), Vector2(gx + STEP, gz), Vector2(gx + STEP, gz + STEP), Vector2(gx, gz + STEP)]:
				c.append(Vector3(k.x, Terrain.lair_lid_height(p0.x + k.x, p0.z + k.y) - p0.y + 0.25, k.y))
			for tri: Array in [[c[0], c[2], c[1]], [c[0], c[3], c[2]]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var e: Vector3 = tri[2]
				var n := (b - a).cross(e - a).normalized()
				if n.y > 0.0:  # przód ścianki w Godocie: wierzchołki zgodnie z ruchem wskazówek
					var t := b
					b = e
					e = t
				else:
					n = -n
				var mid := (a + b + e) / 3.0
				var col := Terrain._face_color(p0.x + mid.x, p0.z + mid.z, p0.y + mid.y, n.y)
				for v: Vector3 in [a, b, e]:
					verts.append(v)
					norms.append(n)
					cols.append(col)
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Lid"
	mi.mesh = mesh
	add_child(mi)
	mi.create_trimesh_collision()


## Punkt startu / odrodzenia: gniazdo (globalnie).
func nest_position() -> Vector3:
	return global_position + Vector3(0, 0.05, 0)


## Kierunek do wyjścia (rotacja Y smoka patrzącego na wejście).
func exit_yaw() -> float:
	return global_rotation.y


func is_inside(pos: Vector3) -> bool:
	var d := pos - global_position
	return Vector2(d.x, d.z).length() < SLEEP_RADIUS and d.y < 10.0


## Skorupki jaja w gnieździe (po wykluciu zostają jako ozdoba).
func show_shells() -> void:
	if _shells:
		return
	_shells = Node3D.new()
	add_child(_shells)
	var mat := _egg_material()
	for i in 2:
		var half := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.24
		m.height = 0.55
		m.is_hemisphere = true
		m.radial_segments = 9
		m.rings = 3
		m.material = mat
		half.mesh = m
		half.position = Vector3(0.6 if i == 0 else -0.55, 0.12, 0.45 if i == 0 else -0.35)
		# jedna skorupka do góry dnem, druga przewrócona na bok
		half.rotation = Vector3(PI if i == 0 else PI * 0.55, 0.8 * i + 0.3, 0.25)
		_shells.add_child(half)


## Intro nowej gry: jajo w gnieździe kołysze się coraz mocniej i pęka.
## `on_crack` woła się w chwili pęknięcia (świat pokazuje wtedy pisklę).
func play_hatch(on_crack: Callable) -> void:
	_egg = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.38
	m.height = 0.95
	m.radial_segments = 10
	m.rings = 6
	m.material = _egg_material()
	_egg.mesh = m
	_egg.position = Vector3(0, 0.47, 0)
	add_child(_egg)
	var tw := create_tween()
	tw.tween_interval(0.8)
	for i in 4:  # coraz mocniejsze kołysanie
		var a := 0.12 + 0.1 * i
		tw.tween_property(_egg, "rotation:z", a, 0.12)
		tw.tween_property(_egg, "rotation:z", -a, 0.18)
		tw.tween_property(_egg, "rotation:z", 0.0, 0.12)
		tw.tween_interval(0.5 - 0.1 * i)
	tw.tween_property(_egg, "scale", Vector3(1.15, 0.85, 1.15), 0.12)
	tw.tween_callback(func() -> void:
		_egg.queue_free()
		_egg = null
		show_shells()
		DustBurst.spawn(get_parent(), global_position, 0.35, EGG_COLOR)
		on_crack.call()
		hatched.emit())


func _egg_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = EGG_COLOR
	mat.roughness = 0.7
	return mat
