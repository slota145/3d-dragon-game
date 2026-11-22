class_name TreasurePile
extends Node3D
## Proceduralny stos skarbu w legowisku: złoty kopiec + monety (MultiMesh) + kielichy, korony
## i klejnoty na wierzchu. Rośnie wraz ze złotem (promień ~ √złota), zawsze taki sam dla
## tej samej ilości (stałe ziarno) — po wczytaniu gry wygląda identycznie.

## Maksymalny promień stosu (m) — dalej rośnie już tylko w górę (komora ma ~17 m promienia).
@export var max_radius: float = 6.0
@export var max_coins: int = 2500

var gold: int = 0

var _mound: MeshInstance3D
var _coins: MultiMeshInstance3D
var _items: Node3D


func _ready() -> void:
	_mound = MeshInstance3D.new()
	add_child(_mound)
	_coins = MultiMeshInstance3D.new()
	_coins.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coins)
	_items = Node3D.new()
	add_child(_items)
	set_gold(gold)


## Promień i wysokość kopca dla danej ilości złota.
func shape_for(amount: int) -> Vector2:
	if amount <= 0:
		return Vector2.ZERO
	var r := 0.4 + 0.13 * sqrt(float(amount))
	var h := r * 0.45
	if r > max_radius:  # komora się kończy — stos rośnie w górę
		h *= pow(r / max_radius, 1.5)
		r = max_radius
	return Vector2(r, h)


func set_gold(amount: int) -> void:
	gold = maxi(amount, 0)
	if not is_inside_tree():
		return
	for c in _items.get_children():
		c.queue_free()
	var sh := shape_for(gold)
	_mound.visible = gold >= 20
	if _mound.visible:
		var cone := CylinderMesh.new()
		cone.top_radius = sh.x * 0.08
		cone.bottom_radius = sh.x * 0.92
		cone.height = sh.y * 0.9
		cone.radial_segments = 12
		cone.rings = 2
		cone.material = Treasure.mesh("Coin").surface_get_material(0)
		_mound.mesh = cone
		_mound.position.y = cone.height / 2.0 - 0.05
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := mini(max_coins, gold / 2 + mini(gold, 12))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Treasure.mesh("Coin")
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, _surface_xf(rng, sh, 1.0))
	_coins.multimesh = mm
	# większe przedmioty na wierzchu: co 40 złota jeden (maks. 40)
	var specials := ["Goblet", "Crown", "Gem", "Gem", "Goblet"]
	for i in mini(gold / 40, 40):
		var mi := MeshInstance3D.new()
		mi.mesh = Treasure.mesh(specials[i % specials.size()])
		mi.transform = _surface_xf(rng, sh, 1.3 + rng.randf() * 0.4)
		_items.add_child(mi)


## Losowy punkt na powierzchni kopca z lekkim, losowym przechyłem.
func _surface_xf(rng: RandomNumberGenerator, sh: Vector2, scale_k: float) -> Transform3D:
	var r := sh.x * sqrt(rng.randf())
	var a := rng.randf() * TAU
	var y := sh.y * pow(1.0 - r / maxf(sh.x, 0.01), 1.3) if sh.x > 0.0 else 0.0
	var tilt := Basis(Vector3(cos(a), 0, sin(a)), rng.randf_range(-0.6, 0.6)) * Basis(Vector3.UP, rng.randf() * TAU)
	return Transform3D(tilt.scaled(Vector3.ONE * scale_k), Vector3(cos(a) * r, y, sin(a) * r))
