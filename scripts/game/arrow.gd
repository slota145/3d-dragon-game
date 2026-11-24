class_name Arrow
extends Node3D
## Strzała myśliwego: leci łukiem (lekka grawitacja), trafia smoka (odległość od jego środka),
## po chybieniu ginie w ziemi albo po kilku sekundach.

const GRAVITY := 6.0

var velocity: Vector3
var damage: float = 6.0
var target: DragonController
var _life: float = 4.0
## Własna reakcja na trafienie (np. rycerze: inny komunikat) — wtedy bez sygnału hit_by_arrow.
var on_hit: Callable


## Pocisk: strzała (domyślnie), oszczep (`length` 2 m) albo bełt kuszy (krótki, gruby).
static func create(from: Vector3, aim: Vector3, speed: float, dmg: float, dragon: DragonController,
		length: float = 0.9, thick: float = 0.02, color: Color = Color(0.35, 0.22, 0.1)) -> Arrow:
	var a := Arrow.new()
	a.position = from
	var t := from.distance_to(aim) / speed
	a.velocity = (aim - from) / maxf(t, 0.05) + Vector3.UP * GRAVITY * t * 0.5  # kompensacja opadania
	a.damage = dmg
	a.target = dragon
	var mi := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = thick
	shaft.bottom_radius = thick
	shaft.height = length
	shaft.radial_segments = 4
	shaft.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	shaft.material = mat
	mi.mesh = shaft
	mi.rotation.x = PI / 2.0  # walec wzdłuż Z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mi)
	return a


func _physics_process(delta: float) -> void:
	_life -= delta
	velocity.y -= GRAVITY * delta
	position += velocity * delta
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)
	if target and is_instance_valid(target):
		var center := target.body_center()
		if global_position.distance_to(center) < 0.8 + target.stats.size * 0.35:
			target.stats.damage(damage)
			if on_hit.is_valid():
				on_hit.call(damage)
			else:
				target.hit_by_arrow.emit(damage)
			queue_free()
			return
	if _life <= 0.0 or global_position.y < Terrain.height(global_position.x, global_position.z) - 0.2:
		queue_free()
