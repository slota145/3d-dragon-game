extends SceneTree
## Generator tras dróg między wioskami (uruchom po zmianie terenu albo wiosek):
##   godot --headless --path . --script res://tools/gen_roads.gd
## Szuka ścieżki A* (AStarGrid2D, siatka 16 m) z kosztem: nachylenie, wysokość (góry), woda
## (dozwolona, ale droga — rzekę przecina w wąskim miejscu, jeziora omija), legowisko.
## Ścieżkę upraszcza i wygładza (Catmull-Rom) co 4 m. Wynik: assets/data/roads.json.

const CELL := 16.0
const OUT := "res://assets/data/roads.json"


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var n := int(Terrain.SIZE / CELL)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, n, n)
	grid.cell_size = Vector2.ONE * CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	for j in n:
		for i in n:
			var p := _world(i, j)
			var h := Terrain.height(p.x, p.y)
			var slope := maxf(absf(Terrain.height(p.x + CELL, p.y) - h), absf(Terrain.height(p.x, p.y + CELL) - h)) / CELL
			var w := 1.0 + slope * 40.0
			if h < Terrain.WATER_LEVEL + 0.4:
				w += 18.0  # woda: przejście możliwe (most), ale krótkie
			if h > 45.0:
				w += (h - 45.0) * 0.5  # góry omijamy
			if Vector2(p.x - Lair.POSITION.x, p.y - Lair.POSITION.z).length() < Lair.RADIUS + 40.0 \
					or Vector2(p.x - Terrain.CASTLE[0], p.y - Terrain.CASTLE[1]).length() < Terrain.CASTLE[2] + 12.0:
				grid.set_point_solid(Vector2i(i, j))
				continue
			grid.set_point_weight_scale(Vector2i(i, j), w)
	var roads := []
	for pair: Array in Terrain.ROAD_PAIRS:
		var a := Terrain.road_end(pair[0])
		var b := Terrain.road_end(pair[1])
		var path := grid.get_id_path(_cell(a), _cell(b))
		var pts := PackedVector2Array()
		for c in path:
			pts.append(_world(c.x, c.y))
		pts[0] = a
		pts[pts.size() - 1] = b
		var smooth := _resample(_catmull(_simplify(pts, 10.0)), 4.0)
		var out := []
		for p in smooth:
			out.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		roads.append(out)
		print("droga %s: %d punktów, %.0f m" % [str(pair), smooth.size(), smooth.size() * 4.0])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"cell": CELL, "roads": roads}))
	f.close()
	print("zapisano %s (%d ms)" % [OUT, Time.get_ticks_msec() - t0])
	quit()


func _world(i: int, j: int) -> Vector2:
	return Vector2(-Terrain.HALF + (i + 0.5) * CELL, -Terrain.HALF + (j + 0.5) * CELL)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x + Terrain.HALF) / CELL), int((p.y + Terrain.HALF) / CELL))


## Ramer–Douglas–Peucker: usuwa schodki siatki, zostawia zakręty.
func _simplify(pts: PackedVector2Array, tol: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var a := pts[0]
	var b := pts[pts.size() - 1]
	var best := -1.0
	var idx := 0
	for k in range(1, pts.size() - 1):
		var ab := b - a
		var t := clampf((pts[k] - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := pts[k].distance_to(a + ab * t)
		if d > best:
			best = d
			idx = k
	if best <= tol:
		return PackedVector2Array([a, b])
	var left := _simplify(pts.slice(0, idx + 1), tol)
	var right := _simplify(pts.slice(idx), tol)
	left.remove_at(left.size() - 1)
	left.append_array(right)
	return left


## Krzywa Catmull-Rom przez punkty (gęsto).
func _catmull(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in pts.size() - 1:
		var p0 := pts[maxi(k - 1, 0)]
		var p1 := pts[k]
		var p2 := pts[k + 1]
		var p3 := pts[mini(k + 2, pts.size() - 1)]
		var steps := maxi(2, int(p1.distance_to(p2) / 2.0))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


## Równe odstępy wzdłuż łamanej.
func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var seg := a.distance_to(b)
		var d := step - carry
		while d <= seg:
			out.append(a.lerp(b, d / seg))
			d += step
		carry = seg - (d - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.5:
		out.append(pts[pts.size() - 1])
	return out
