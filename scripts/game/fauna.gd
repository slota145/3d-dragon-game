class_name Fauna
extends Node3D
## Drobne życie wokół smoka (tylko w jego pobliżu — stały, mały koszt na telefonie):
## - w dzień: stada ptaków krążące na niebie, motyle nad łąkami kwiatów,
## - nocą: świetliki nad trawą.
## Machanie skrzydłami robi shader (instance uniform `phase`), ruch — prosty kod.

@export var flocks: int = 3
@export var birds_per_flock: int = 6
@export var butterflies: int = 18

var dragon: DragonController
var day_night: DayNight

var _birds: Array[Dictionary] = []  # {node, flock, angle, radius, height, speed}
var _flock_centers: Array[Vector3] = []
var _butterflies: Array[Dictionary] = []  # {node, anchor, phase}
var _fireflies: CPUParticles3D
var _flap_shader: Shader
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 314
	_flap_shader = _make_flap_shader()
	var bird_mesh := _make_bird_mesh()
	for f in flocks:
		_flock_centers.append(Vector3.ZERO)
		for b in birds_per_flock:
			var mi := MeshInstance3D.new()
			mi.mesh = bird_mesh
			mi.set_instance_shader_parameter("phase", _rng.randf() * TAU)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_birds.append({"node": mi, "flock": f, "angle": _rng.randf() * TAU,
				"radius": _rng.randf_range(4.0, 12.0), "height": _rng.randf_range(-3.0, 3.0),
				"speed": _rng.randf_range(0.25, 0.35)})
	var colors := [Color(1.0, 0.55, 0.1), Color(0.3, 0.6, 1.0), Color(1.0, 0.95, 0.4), Color(0.95, 0.4, 0.8),
		Color(1, 1, 1)]
	var fly_mesh := _make_butterfly_mesh()
	for i in butterflies:
		var mi := MeshInstance3D.new()
		mi.mesh = fly_mesh
		mi.set_instance_shader_parameter("phase", _rng.randf() * TAU)
		mi.set_instance_shader_parameter("tint", colors[i % colors.size()])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_butterflies.append({"node": mi, "anchor": Vector3.INF, "phase": _rng.randf() * 100.0})
	_fireflies = _make_fireflies()
	add_child(_fireflies)


func _process(delta: float) -> void:
	if not dragon:
		return
	var night := day_night.night_factor() if day_night else 0.0
	var day := night < 0.5
	var t := Time.get_ticks_msec() / 1000.0
	var dp := dragon.global_position
	# ptaki: stada krążą wokół punktów w pobliżu smoka, w dzień
	for f in flocks:
		var c := _flock_centers[f]
		if c == Vector3.ZERO or Vector2(c.x - dp.x, c.z - dp.z).length() > 260.0:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(60.0, 180.0)
			c = Vector3(dp.x + cos(a) * r, 0.0, dp.z + sin(a) * r)
			c.y = maxf(Terrain.height(c.x, c.z), Terrain.WATER_LEVEL) + _rng.randf_range(35.0, 80.0)
			_flock_centers[f] = c
	for b in _birds:
		var mi: MeshInstance3D = b["node"]
		mi.visible = day
		if not day:
			continue
		b["angle"] += b["speed"] * delta
		var c := _flock_centers[b["flock"]]
		var a: float = b["angle"]
		var r: float = 28.0 + float(b["radius"])
		var p: Vector3 = c + Vector3(cos(a) * r, float(b["height"]) + sin(t * 0.7 + a) * 2.0, sin(a) * r)
		mi.position = p
		mi.rotation = Vector3(0.0, -a, 0.25)  # przodem wzdłuż okręgu, lekko w przechyle
	# motyle: nad łąkami kwiatów (albo trawą) blisko smoka, w dzień
	for bf in _butterflies:
		var mi: MeshInstance3D = bf["node"]
		mi.visible = day and dragon.stats.size < 10.0
		if not mi.visible:
			continue
		var anchor: Vector3 = bf["anchor"]
		if anchor == Vector3.INF or Vector2(anchor.x - dp.x, anchor.z - dp.z).length() > 45.0:
			anchor = _butterfly_spot(dp)
			bf["anchor"] = anchor
		var ph: float = bf["phase"] + t * 0.6
		var p := anchor + Vector3(sin(ph * 1.3) * 3.0, 0.8 + sin(ph * 2.1) * 0.5, cos(ph * 0.9) * 3.0)
		var vel := Vector3(cos(ph * 1.3) * 1.3 * 3.0, 0.0, -sin(ph * 0.9) * 0.9 * 3.0)
		mi.position = p
		mi.rotation.y = atan2(vel.x, vel.z)
	# świetliki: nocą wokół smoka, przy ziemi
	_fireflies.emitting = night > 0.5 and dp.y - Terrain.height(dp.x, dp.z) < 40.0
	_fireflies.global_position = Vector3(dp.x, Terrain.height(dp.x, dp.z) + 1.2, dp.z)


func _butterfly_spot(near: Vector3) -> Vector3:
	var best := Vector3.ZERO
	for i in 10:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(6.0, 30.0)
		var p := Vector3(near.x + cos(a) * r, 0.0, near.z + sin(a) * r)
		if not Terrain.is_walkable(p.x, p.z):
			continue
		best = p
		if Terrain.flower_patch(p.x, p.z) >= 0:
			break  # wolą kwiaty
	best.y = Terrain.height(best.x, best.z)
	return best


# --- Siatki i materiały ----------------------------------------------------------

func _make_flap_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
instance uniform float phase = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
uniform float flap_speed = 9.0;
uniform float flap_amount = 0.8;
void vertex() {
	float w = abs(VERTEX.x);
	VERTEX.y += w * flap_amount * sin(TIME * flap_speed + phase);
}
void fragment() {
	ALBEDO = COLOR.rgb * tint.rgb;
	ROUGHNESS = 1.0;
}
"""
	return sh


func _flap_material(speed: float, amount: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _flap_shader
	m.set_shader_parameter("flap_speed", speed)
	m.set_shader_parameter("flap_amount", amount)
	return m


## Ptak: ciemny tułów i dwa trójkątne skrzydła (~1,2 m rozpiętości).
func _make_bird_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.18, 0.18, 0.22))
	for s: float in [-1.0, 1.0]:
		st.add_vertex(Vector3(0, 0, 0.25)); st.add_vertex(Vector3(0.6 * s, 0.05, -0.05)); st.add_vertex(Vector3(0, 0, -0.15))
	st.add_vertex(Vector3(0, 0.06, 0.35)); st.add_vertex(Vector3(0.06, 0, -0.35)); st.add_vertex(Vector3(-0.06, 0, -0.35))
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _flap_material(11.0, 0.7))
	return m


## Motyl: dwie pary skrzydeł (kolor z instancji), ~12 cm.
func _make_butterfly_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	for s: float in [-1.0, 1.0]:
		st.add_vertex(Vector3(0, 0, 0.03)); st.add_vertex(Vector3(0.09 * s, 0, 0.07)); st.add_vertex(Vector3(0.08 * s, 0, -0.02))
		st.add_vertex(Vector3(0, 0, -0.01)); st.add_vertex(Vector3(0.07 * s, 0, -0.03)); st.add_vertex(Vector3(0.04 * s, 0, -0.08))
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _flap_material(16.0, 4.0))
	return m


func _make_fireflies() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 5.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(35.0, 1.5, 35.0)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.18
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	g.colors = PackedColorArray([Color(0.8, 1.0, 0.3, 0.0), Color(0.85, 1.0, 0.35, 1.0), Color(0.6, 0.9, 0.2, 0.2),
		Color(0.85, 1.0, 0.35, 1.0), Color(0.8, 1.0, 0.3, 0.0)])
	p.color_ramp = g
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
