class_name Landforms
extends Node3D
## Elementy krajobrazu poza siatką terenu (Terrain): wodospady i kamienne turnie.
## - Wodospad: wstęga wody ułożona po terenie wzdłuż trasy (WATERFALLS); na urwisku woda
##   odrywa się od krawędzi i spada łukiem aż do podnóża (nie wchodzi w ścianę), na dole mgiełka.
##   Shader assets/shaders/waterfall.gdshader (smugi z prądem, piana na spadku).
## - Turnie: smukłe słupy piaskowca (cliffs.glb, tools/blender/gen_cliffs.py) w Dolinie Turni
##   na południowym wschodzie, z kolizją walcową (smok o nie zahacza, może na nich usiąść).

## Wodospady: [punkt startu (źródło, wyżej), punkt końca (u podnóża, w wodzie), szerokość (m)].
const WATERFALLS := [
	# wielki wodospad u źródła rzeki — z gór na północ od łąki
	[Vector2(232.0, -790.0), Vector2(251.0, -612.0), 14.0],
	# kaskady spływające z wyżyny zachodniej do kanionu
	[Vector2(-370.0, 812.0), Vector2(-452.0, 790.0), 7.0],
	[Vector2(-655.0, 960.0), Vector2(-590.0, 972.0), 8.0],
	# z płaskowyżu wschodniego do stawu u podnóża
	[Vector2(1600.0, 470.0), Vector2(1712.0, 470.0), 10.0],
]
## Dolina Turni: środek, promień, liczba turni.
const SPIRE_VALLEY := [Vector2(1300.0, 1420.0), 280.0, 18]

var _waterfalls: Array[Dictionary] = []  # {"top": Vector3, "bottom": Vector3}
var _spires: Array[Vector3] = []


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/waterfall.gdshader")
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.03
	tex.noise = n
	mat.set_shader_parameter("streaks", tex)
	for i in WATERFALLS.size():
		var w: Array = WATERFALLS[i]
		_build_waterfall(i, w[0], w[1], w[2], mat)
	_build_spires()


func waterfalls() -> Array[Dictionary]:
	return _waterfalls


func spires() -> Array[Vector3]:
	return _spires


## Profil wody wzdłuż trasy: po terenie, a na urwisku łuk od krawędzi do podnóża.
static func water_profile(a: Vector2, b: Vector2, step: float = 2.0) -> Array[Vector3]:
	# źródło w najwyższym punkcie trasy (woda nie płynie pod górę)
	var best := a
	var best_h := -INF
	for k in 41:
		var q := a.lerp(b, k / 40.0 * 0.7)
		var hq := Terrain.height(q.x, q.y)
		if hq > best_h:
			best_h = hq
			best = q
	a = best
	var length := a.distance_to(b)
	var n := maxi(2, int(length / step))
	var ground: Array[float] = []
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		ground.append(maxf(Terrain.height(p.x, p.y), Terrain.WATER_LEVEL) + 0.4)
	var ys: Array[float] = ground.duplicate()
	var k := 0
	while k < n:
		if ground[k] - ground[k + 1] > step * 1.2:  # krawędź urwiska — szukaj podnóża
			var e := k + 1
			while e < n and ground[e] - ground[e + 1] > step * 0.35:
				e += 1
			var top := ground[k]
			var bottom := ground[e]
			for j in range(k + 1, e + 1):
				var t := float(j - k) / float(e - k)
				ys[j] = maxf(top - (top - bottom) * t * t, ground[j] + 0.4)  # rzut poziomy — parabola
			k = e
		else:
			k += 1
	var out: Array[Vector3] = []
	for j in n + 1:
		var p := a.lerp(b, float(j) / n)
		out.append(Vector3(p.x, ys[j], p.y))
	return out


func _build_waterfall(i: int, a: Vector2, b: Vector2, width: float, mat: Material) -> void:
	var pts := water_profile(a, b)
	var side := Vector3(b.y - a.y, 0.0, -(b.x - a.x)).normalized() * width * 0.5
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var dist := 0.0
	var origin := pts[0]
	var biggest := 0.0
	var fall_at := pts[pts.size() - 1]
	for j in pts.size():
		if j > 0:
			dist += pts[j].distance_to(pts[j - 1])
		var drop := (pts[j - 1].y - pts[j].y) if j > 0 else 0.0
		var steep := clampf(drop / 2.5, 0.0, 1.0)
		if drop > biggest:
			biggest = drop
		var w := 1.0 + steep * 0.25  # na spadku woda się rozlewa
		for s in [-1.0, 1.0]:
			verts.append(pts[j] - origin + side * s * w)
			uvs.append(Vector2(s * 0.5 + 0.5, dist))
			cols.append(Color(steep, 0, 0))
			norms.append(Vector3.UP)
	var idx := PackedInt32Array()
	for j in pts.size() - 1:
		var q := j * 2
		idx.append_array([q, q + 1, q + 2, q + 1, q + 3, q + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Waterfall_%d" % i
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = origin
	# podnóże największego spadku — tam mgiełka
	for j in range(pts.size() - 1, 0, -1):
		if pts[j - 1].y - pts[j].y > 1.0:
			fall_at = pts[j]
			break
	_waterfalls.append({"top": pts[0], "bottom": pts[pts.size() - 1], "foot": fall_at,
		"height": pts[0].y - pts[pts.size() - 1].y})
	if pts[0].y - fall_at.y > 8.0:
		_add_mist(fall_at, width)


## Mgiełka u podnóża wodospadu: kilka jasnych, powoli rosnących obłoczków.
func _add_mist(at: Vector3, width: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "Mist"
	p.amount = 14
	p.lifetime = 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width * 0.5, 0.5, width * 0.3)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -0.4, 0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1, 1, 1, 0.35)
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.visibility_range_end = 600.0
	add_child(p)
	p.global_position = at + Vector3.UP * 0.5


func _build_spires() -> void:
	var scene: Node = (load("res://assets/models/cliffs.glb") as PackedScene).instantiate()
	var meshes: Dictionary = {}
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mi.name)] = mi.mesh
	scene.free()
	var kinds := ["Spire_A", "Spire_B", "Spire_C"]
	var radius := {"Spire_A": 5.5, "Spire_B": 5.8, "Spire_C": 7.5}
	var height := {"Spire_A": 34.0, "Spire_B": 24.0, "Spire_C": 14.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var center: Vector2 = SPIRE_VALLEY[0]
	var r_max: float = SPIRE_VALLEY[1]
	var want: int = SPIRE_VALLEY[2]
	var body := StaticBody3D.new()
	body.name = "SpireCollision"
	add_child(body)
	var tries := 0
	while _spires.size() < want and tries < 600:
		tries += 1
		var p := center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r_max
		if not _spire_spot_ok(p):
			continue
		var kind: String = kinds[rng.randi() % kinds.size()]
		var s := rng.randf_range(0.8, 1.35)
		var base := INF
		for k in 6:
			var q: Vector2 = p + Vector2.from_angle(k * TAU / 6.0) * float(radius[kind]) * s * 0.8
			base = minf(base, Terrain.height(q.x, q.y))
		var pos := Vector3(p.x, base, p.y)
		var mi := MeshInstance3D.new()
		mi.name = "Spire_%d" % _spires.size()
		mi.mesh = meshes.get(kind)
		mi.visibility_range_end = 1500.0
		add_child(mi)
		mi.global_transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos)
		var cyl := CylinderShape3D.new()
		cyl.radius = radius[kind] * s * 0.85
		cyl.height = height[kind] * s
		var cs := CollisionShape3D.new()
		cs.shape = cyl
		body.add_child(cs)
		cs.global_position = pos + Vector3.UP * cyl.height * 0.5
		_spires.append(pos)


func _spire_spot_ok(p: Vector2) -> bool:
	if not Terrain.is_walkable(p.x, p.y) or Terrain.road_distance(p.x, p.y) < 22.0:
		return false
	if p.distance_to(Vector2(Terrain.CASTLE[0], Terrain.CASTLE[1])) < Terrain.CASTLE[2] + 180.0:
		return false
	for v: Array in Terrain.VILLAGES:
		if p.distance_to(Vector2(v[0], v[1])) < v[2] + Terrain.FIELDS + 40.0:
			return false
	for s in _spires:
		if p.distance_to(Vector2(s.x, s.z)) < 30.0:
			return false
	return true
