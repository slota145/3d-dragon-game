class_name Fireball
extends Node3D
## Kula ognia młodzika: leci prosto z lekkim opadaniem, wybucha przy ziemi, przy ofierze /
## budynku albo po przeleceniu zasięgu. Wybuch zgłasza `exploded` (obrażenia liczy DragonFire).

signal exploded(at: Vector3, radius: float)

var velocity: Vector3
var radius: float = 4.0
var size: float = 1.0
var _life: float = 2.2
var _done: bool = false


func _ready() -> void:
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35 * size
	sm.height = 0.7 * size
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	sm.material = mat
	core.mesh = sm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.omni_range = 6.0 * size
	light.light_energy = 2.0
	add_child(light)
	add_child(FireFx.fireball_trail(size))


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life -= delta
	velocity.y -= 4.0 * delta
	global_position += velocity * delta
	var p := global_position
	var hit := p.y < Terrain.height(p.x, p.z) + 0.3 or _life <= 0.0
	if not hit:
		for n in get_tree().get_nodes_in_group("prey"):
			var prey := n as Prey
			if prey and prey.is_alive() and prey.center().distance_to(p) < prey.radius + 0.6 * size:
				hit = true
				break
	if not hit:
		for n in get_tree().get_nodes_in_group("flammable"):
			var b := n as Node3D
			if b and Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length() < 4.0 \
					and p.y < b.global_position.y + 6.0:
				hit = true
				break
	if hit:
		_done = true
		FireFx.explosion(get_parent(), p, radius)
		exploded.emit(p, radius)
		queue_free()
