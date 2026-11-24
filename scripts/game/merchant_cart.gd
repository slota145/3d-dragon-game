class_name MerchantCart
extends Node3D
## Wóz kupiecki: koń ciągnie wóz drogą między wioskami (tam i z powrotem). Ogień smoka go
## niszczy — wóz płonie, a w miejscu zostaje skrzynia z łupem (złoto, rozgłos).

signal destroyed(cart: MerchantCart)

@export var speed: float = 2.6

var road: PackedVector2Array
## Wysokość drogi w punktach (most nad wodą) — z Roads.heights.
var road_y: PackedFloat32Array
var _t: float = 0.0  # odległość wzdłuż drogi (m)
var _dir: float = 1.0
var _length: float = 0.0
var _dead: bool = false


func setup(points: PackedVector2Array, wagon: Mesh, horse: Mesh, start: float) -> void:
	road = points
	for k in road.size() - 1:
		_length += road[k].distance_to(road[k + 1])
	_t = start * _length
	var w := MeshInstance3D.new()
	w.mesh = wagon
	w.name = "Wagon"
	add_child(w)
	var h := MeshInstance3D.new()
	h.mesh = horse
	h.name = "Horse"
	h.position = Vector3(0, 0, 4.4)  # koń przed wozem (przód modelu = +Z)
	add_child(h)
	add_to_group("flammable")  # cel dla pomocy w celowaniu i kul ognia
	_update_pose(0.0)


func is_alive() -> bool:
	return not _dead


func _process(delta: float) -> void:
	if _dead:
		return
	_t += speed * delta * _dir
	if _t > _length - 75.0 or _t < 75.0:  # w wiosce — zawróć
		_dir = -_dir
		_t = clampf(_t, 75.0, _length - 75.0)
	_update_pose(delta)


## Wysokość drogi w odległości `dist` od początku.
func _height_at(dist: float) -> float:
	var d := clampf(dist, 0.0, _length)
	for k in road.size() - 1:
		var seg := road[k].distance_to(road[k + 1])
		if d <= seg:
			return lerpf(road_y[k], road_y[k + 1], d / maxf(seg, 0.01))
		d -= seg
	return road_y[road_y.size() - 1]


func _point_at(dist: float) -> Vector2:
	var d := clampf(dist, 0.0, _length)
	for k in road.size() - 1:
		var seg := road[k].distance_to(road[k + 1])
		if d <= seg:
			return road[k].lerp(road[k + 1], d / maxf(seg, 0.01))
		d -= seg
	return road[road.size() - 1]


func _update_pose(delta: float) -> void:
	var p := _point_at(_t)
	var ahead := _point_at(_t + 3.0 * _dir)
	position = Vector3(p.x, _height_at(_t) if road_y.size() == road.size() else Terrain.height(p.x, p.y), p.y)
	var yaw := atan2(ahead.x - p.x, ahead.y - p.y)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(3.0 * delta, 0.0, 1.0)) if delta > 0.0 else yaw
	var horse := get_node_or_null("Horse") as Node3D
	if horse:  # koń lekko kołysze się w marszu
		horse.position.y = absf(sin(Time.get_ticks_msec() / 260.0)) * 0.08


## Ogień smoka: wóz płonie, koń ucieka (znika), zostaje łup.
func burn() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("flammable")
	var horse := get_node_or_null("Horse")
	if horse:
		horse.queue_free()
	var flames := FireFx.building_fire(Vector3(2.0, 2.4, 3.4))
	add_child(flames)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.05, 0.85)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(get_node("Wagon") as MeshInstance3D).material_overlay = dark
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_instance_valid(flames):
			flames.emitting = false)
	destroyed.emit(self)
