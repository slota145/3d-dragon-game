class_name Roads
extends Node3D
## Drogi jako gładka wstęga (środek z ubitej ziemi + ciemniejsze pobocza) wzdłuż tras z
## assets/data/roads.json (tools/gen_roads.gd). Nad wodą — drewniany most (przęsła z kolizją).
## Wysokość drogi w każdym punkcie (`heights`) przydaje się wozom kupieckim.

const LIFT := 0.16  # wstęga tuż nad terenem (bez migotania)
const BRIDGE_DECK := 1.5  # pomost nad poziomem wody

static var _heights: Array = []  # Array[PackedFloat32Array] — wysokość drogi w punktach


## Wysokość nawierzchni drogi `i` w jej punktach (most nad wodą).
static func heights(i: int) -> PackedFloat32Array:
	if _heights.is_empty():
		for r in Terrain.ROAD_PAIRS.size():
			_heights.append(_compute_heights(Terrain.road_points(r)))
	return _heights[i]


## Wysokości drogi: po terenie, a nad wodą — most od szczytu jednego brzegu do szczytu
## drugiego, prosto (gdy brzegi są na różnej wysokości — pochylona kładka).
static func _compute_heights(pts: PackedVector2Array) -> PackedFloat32Array:
	var ys := PackedFloat32Array()
	for p in pts:
		ys.append(Terrain.height(p.x, p.y))
	for span in bridge_spans(pts):
		var a: int = span.x
		var b: int = span.y
		for k in range(a, b + 1):
			var t := float(k - a) / maxf(float(b - a), 1.0)
			ys[k] = maxf(lerpf(ys[a], ys[b], t), Terrain.WATER_LEVEL + BRIDGE_DECK)
	return ys


## Przęsła mostów: pary indeksów [brzeg, brzeg] obejmujące wodę — rozszerzone w obie strony
## do szczytu brzegu (dopóki teren dalej się wznosi, maks. ~40 m).
static func bridge_spans(pts: PackedVector2Array) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	var k := 0
	while k < pts.size():
		if not _wet(pts[k]):
			k += 1
			continue
		var a := k
		while k < pts.size() and _wet(pts[k]):
			k += 1
		var b := mini(k, pts.size() - 1)
		a = maxi(a - 1, 0)
		for i in 10:  # wspinaj się na brzeg
			if a > 0 and _h(pts[a - 1]) > _h(pts[a]) + 0.05:
				a -= 1
			else:
				break
		for i in 10:
			if b < pts.size() - 1 and _h(pts[b + 1]) > _h(pts[b]) + 0.05:
				b += 1
			else:
				break
		spans.append(Vector2i(a, b))
	return spans


static func _h(p: Vector2) -> float:
	return Terrain.height(p.x, p.y)


static func _wet(p: Vector2) -> bool:
	return Terrain.height(p.x, p.y) < Terrain.WATER_LEVEL + 0.6


func _ready() -> void:
	var bridge_mesh := _village_mesh("Bridge")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	for i in Terrain.ROAD_PAIRS.size():
		var pts := Terrain.road_points(i)
		var ys := heights(i)
		var mi := MeshInstance3D.new()
		mi.name = "Road_%d" % i
		mi.mesh = _ribbon(pts, ys, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		# mosty: przęsła od brzegu do brzegu, pomost na wysokości drogi (pochylony jak kładka)
		for span in bridge_spans(pts):
			for k in range(span.x, span.y):
				var mid := (pts[k] + pts[k + 1]) * 0.5
				var y := (ys[k] + ys[k + 1]) * 0.5
				if y - Terrain.height(mid.x, mid.y) < 0.35:
					continue  # tu pomost leży na ziemi — wystarczy droga
				var dir := (pts[k + 1] - pts[k]).normalized()
				var seg := MeshInstance3D.new()
				seg.mesh = bridge_mesh
				seg.position = Vector3(mid.x, y, mid.y)
				# oś X modelu wzdłuż drogi, pochylenie jak kładka między brzegami
				seg.basis = Basis(Vector3.UP, -dir.angle()) * Basis(Vector3.BACK, atan2(ys[k + 1] - ys[k], pts[k].distance_to(pts[k + 1])))
				add_child(seg)
				var body := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(4.3, 0.3, 7.0)
				cs.shape = box
				cs.position = Vector3(0, -0.15, 0)
				body.add_child(cs)
				seg.add_child(body)
				_add_pillars(mid, dir, y)


## Słupy pod przęsłem sięgające gruntu (głębokie doliny), po obu stronach pomostu.
func _add_pillars(mid: Vector2, dir: Vector2, deck: float) -> void:
	var side := Vector2(-dir.y, dir.x) * 3.3
	for s: float in [-1.0, 1.0]:
		var p := mid + side * s
		var ground := minf(Terrain.height(p.x, p.y), Terrain.WATER_LEVEL - 1.0)
		var h := deck - 0.3 - ground
		if h < 3.0:
			continue  # krótkie słupy ma już model przęsła
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.26
		cyl.height = h
		cyl.radial_segments = 6
		cyl.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.2, 0.1)
		cyl.material = mat
		mi.mesh = cyl
		mi.position = Vector3(p.x, ground + h * 0.5, p.y)
		add_child(mi)


## Wstęga: pobocze | środek | pobocze, wierzchołki na wysokości terenu (lub mostu).
func _ribbon(pts: PackedVector2Array, ys: PackedFloat32Array, mat: Material) -> ArrayMesh:
	var half := Terrain.ROAD_HALF_WIDTH
	var offsets := [-half, -half + 0.8, half - 0.8, half]
	var cols := [Color(0.42, 0.36, 0.24), Color(0.72, 0.58, 0.38), Color(0.72, 0.58, 0.38), Color(0.42, 0.36, 0.24)]
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in pts.size():
		var a := pts[maxi(k - 1, 0)]
		var b := pts[mini(k + 1, pts.size() - 1)]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var on_bridge := ys[k] - Terrain.height(pts[k].x, pts[k].y) > 0.3
		for o in 4:
			var q: Vector2 = pts[k] + n * float(offsets[o])
			var y := ys[k] if on_bridge else Terrain.height(q.x, q.y)
			verts.append(Vector3(q.x, y + LIFT - (0.4 if on_bridge else 0.0), q.y))  # pod deskami mostu ukryta
			# delikatne koleiny: co drugi punkt odrobinę ciemniej
			var c: Color = cols[o]
			colors.append(c.darkened(0.05) if (k % 2 == 0 and o in [1, 2]) else c)
			normals.append(Vector3.UP)
	for k in pts.size() - 1:
		for o in 3:
			var v0 := k * 4 + o
			var v1 := v0 + 1
			var v2 := v0 + 4
			var v3 := v1 + 4
			idx.append_array([v0, v2, v1, v1, v2, v3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh


func _village_mesh(name: String) -> Mesh:
	var scene: Node = (load("res://assets/models/village.glb") as PackedScene).instantiate()
	var mi := scene.find_child("Village_" + name, true, false) as MeshInstance3D
	var m: Mesh = mi.mesh if mi else null
	scene.free()
	return m
