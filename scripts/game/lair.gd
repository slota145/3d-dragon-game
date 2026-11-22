class_name Lair
extends Node3D
## Legowisko: skalne wzgórze z jaskinią (model z tools/blender/gen_lair.py), gniazdo, jajo.
## Pivot = środek komory na ziemi (gniazdo); wejście od strony +Z (lokalnie).
## Kolizja skały (trimesh) powstaje w _ready. W komorze można spać (DragonController w zasięgu).

## Położenie legowiska w świecie (wejście patrzy na łąkę wokół (0, 0, 0)).
const POSITION := Vector3(0.0, 0.0, -80.0)
## Promień wzgórza (m) — tu nie stawiamy drzew, skał ani zwierząt.
const RADIUS := 50.0
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
