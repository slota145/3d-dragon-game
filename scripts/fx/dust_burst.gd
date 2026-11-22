class_name DustBurst
extends RefCounted
## Jednorazowa chmura pyłu (low-poly „kłęby”) rozchodząca się pierścieniem od punktu na ziemi.


static func spawn(parent: Node, at: Vector3, strength: float = 1.0,
		color: Color = Color(0.6, 0.53, 0.41)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = int(clampf(40.0 * strength, 10.0, 70.0))
	p.lifetime = 1.9
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 3.5 * sqrt(strength)
	p.emission_ring_inner_radius = 1.5 * minf(1.0, strength)
	p.emission_ring_height = 0.4
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0 * strength
	p.radial_accel_min = 6.0 * strength
	p.radial_accel_max = 14.0 * strength
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.gravity = Vector3(0, -0.6, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2 * clampf(strength, 0.6, 1.6)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.35, 1.0))
	grow.add_point(Vector2(1.0, 1.3))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.65))
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	var mesh := SphereMesh.new()
	mesh.radius = 0.6 * clampf(strength, 0.15, 1.5)
	mesh.height = 1.1 * clampf(strength, 0.15, 1.5)
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 1.0
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = Vector3(at.x, at.y + 0.3, at.z)
	p.emitting = true
	p.finished.connect(p.queue_free)
