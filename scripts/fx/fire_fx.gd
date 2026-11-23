class_name FireFx
extends RefCounted
## Efekty ognia (CPUParticles3D — tanie na telefonie): kula ognia, wybuch, strumień ognia,
## płomienie na płonącym budynku, dym.

static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / (cols.size() - 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


static func _flame_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# zwykłe mieszanie (nie „add”) — w dzień płomienie zostają pomarańczowe, nie bieleją
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


static func _particles(amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = _flame_material()
	p.mesh = quad
	p.color_ramp = _ramp([Color(1.0, 0.88, 0.35, 0.95), Color(1.0, 0.5, 0.06, 0.92), Color(0.78, 0.17, 0.03, 0.75),
		Color(0.16, 0.12, 0.1, 0.0)])
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = grow
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Smuga za kulą ognia (dziecko pocisku).
static func fireball_trail(size: float) -> CPUParticles3D:
	var p := _particles(36, 0.45, 0.9 * size)
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.2 * size
	p.gravity = Vector3(0, 1.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3 * size
	return p


## Jednorazowy wybuch ognia (np. kula ognia trafia w ziemię).
static func explosion(parent: Node, at: Vector3, radius: float) -> void:
	var p := _particles(int(clampf(30.0 + radius * 6.0, 30.0, 90.0)), 0.9, 1.2 + radius * 0.35)
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = radius * 1.2
	p.initial_velocity_max = radius * 3.0
	p.damping_min = radius * 2.0
	p.damping_max = radius * 3.0
	p.gravity = Vector3(0, 3.0, 0)
	p.emitting = true
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)


## Strumień ognia z pyska (dziecko smoka; emitting włącza/wyłącza DragonFire).
static func flame_stream() -> CPUParticles3D:
	var p := _particles(90, 0.6, 1.4)
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.spread = 9.0
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 28.0
	p.damping_min = 8.0
	p.damping_max = 14.0
	p.gravity = Vector3(0, 4.0, 0)
	p.emitting = false
	return p


## Płomienie na płonącym budynku / stogu (dziecko budynku).
static func building_fire(size: Vector3) -> CPUParticles3D:
	var p := _particles(40, 1.2, 1.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.45, 0.3, size.z * 0.45)
	p.position = Vector3(0, size.y * 0.75, 0)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, 1.0, 0)
	return p


## Dym nad pogorzeliskiem.
static func smoke(size: Vector3) -> CPUParticles3D:
	var p := _particles(14, 3.5, 2.6)
	(p.mesh.material as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	p.color_ramp = _ramp([Color(0.3, 0.28, 0.26, 0.0), Color(0.25, 0.24, 0.22, 0.45), Color(0.4, 0.4, 0.4, 0.0)])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.3, 0.2, size.z * 0.3)
	p.position = Vector3(0, size.y * 0.6, 0)
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0.4, 0.4, 0)
	return p
