class_name Bolt
extends Node3D
## Bełt balisty: ciężki pocisk (lekka grawitacja), trafia smoka (odległość od środka ciała),
## rani mocno i odrzuca. Chybiony ginie w ziemi albo po kilku sekundach.

signal hit(damage: float)

const GRAVITY := 3.0

var velocity: Vector3
var damage: float = 18.0
var target: DragonController
var _life: float = 5.0


static func create(mesh: Mesh, from: Vector3, aim: Vector3, speed: float, dmg: float, dragon: DragonController) -> Bolt:
	var b := Bolt.new()
	b.position = from
	var t := from.distance_to(aim) / speed
	b.velocity = (aim - from) / maxf(t, 0.05) + Vector3.UP * GRAVITY * t * 0.5
	b.damage = dmg
	b.target = dragon
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE * 1.4
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(mi)
	return b


func _physics_process(delta: float) -> void:
	_life -= delta
	velocity.y -= GRAVITY * delta
	position += velocity * delta
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP, true)  # model: grot w +Z
	if target and is_instance_valid(target):
		var center := target.body_center()
		if global_position.distance_to(center) < 1.0 + target.stats.size * 0.35:
			target.stats.damage(damage)
			target.velocity += velocity.normalized() * 9.0  # odrzut
			hit.emit(damage)
			queue_free()
			return
	if _life <= 0.0 or global_position.y < Terrain.height(global_position.x, global_position.z) - 0.3:
		queue_free()
