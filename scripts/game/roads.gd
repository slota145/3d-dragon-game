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


static func _compute_heights(pts: PackedVector2Array) -> PackedFloat32Array:
	var ys := PackedFloat32Array()
	var deck := Terrain.WATER_LEVEL + BRIDGE_DECK
	for p in pts:
		ys.append(maxf(Terrain.height(p.x, p.y), deck) if _wet(p) else Terrain.height(p.x, p.y))
	return ys


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
		# mosty: przęsła nad wodą
		for k in pts.size() - 1:
			var mid := (pts[k] + pts[k + 1]) * 0.5
			if not (_wet(pts[k]) or _wet(pts[k + 1]) or _wet(mid)):
				continue
			var dir := (pts[k + 1] - pts[k]).normalized()
			var y := maxf(ys[k], ys[k + 1])
			var seg := MeshInstance3D.new()
			seg.mesh = bridge_mesh
			seg.position = Vector3(mid.x, y, mid.y)
			seg.rotation.y = -dir.angle()  # oś X modelu wzdłuż drogi
			add_child(seg)
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(4.2, 0.3, 7.0)
			cs.shape = box
			cs.position = Vector3(0, -0.15, 0)
			body.add_child(cs)
			seg.add_child(body)


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
		var on_bridge := _wet(pts[k])
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
