class_name Ballista
extends Node3D
## Balista na wieży zamku: obraca łoże za smokiem, celuje (czerwona linia ostrzega gracza —
## jest czas na unik), strzela bełtem z wyprzedzeniem i długo przeładowuje. Ignoruje pisklę
## na ziemi. Zniszczona ogniem (zdrowie `health`) przestaje strzelać i dymi.

signal fired(bolt: Bolt)
signal destroyed(ballista: Ballista)

enum State { IDLE, AIM, RELOAD, BROKEN }

@export var range_m: float = 170.0
@export var aim_time: float = 2.2
@export var reload_time: float = 5.0
@export var bolt_speed: float = 85.0
@export var bolt_damage: float = 18.0
@export var max_health: float = 3.0

var dragon: DragonController
var bolt_mesh: Mesh
var state: State = State.IDLE
var health: float = 3.0
var _bow: Node3D
var _line: MeshInstance3D
var _line_mat: StandardMaterial3D
var _t: float = 0.0
var _aim_point: Vector3


func setup(base: Mesh, bow: Mesh, bolt: Mesh, bow_xf: Transform3D) -> void:
	health = max_health
	bolt_mesh = bolt
	var b := MeshInstance3D.new()
	b.mesh = base
	add_child(b)
	_bow = Node3D.new()
	_bow.position = bow_xf.origin
	add_child(_bow)
	var bm := MeshInstance3D.new()
	bm.mesh = bow
	_bow.add_child(bm)
	_line = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 1.0)
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mat.albedo_color = Color(1.0, 0.1, 0.05, 0.0)
	box.material = _line_mat
	_line.mesh = box
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.visible = false
	_line.top_level = true
	add_child(_line)


func is_working() -> bool:
	return state != State.BROKEN


## Czy smok jest celem: w zasięgu i lata albo jest już młodzikiem.
func _wants(d: DragonController) -> bool:
	if not d or d.stats.health <= 0.0:
		return false
	var dist := global_position.distance_to(d.body_center())
	return dist < range_m and (d.is_flying() or d.stats.size >= DragonStats.STAGE_MIN_SIZE[1])


func _muzzle() -> Vector3:
	return _bow.global_position + _bow.global_basis.z * 1.6


func _physics_process(delta: float) -> void:
	if state == State.BROKEN or not dragon:
		return
	_t += delta
	var center := dragon.body_center()
	match state:
		State.IDLE:
			_bow.rotation.y += delta * 0.3  # wartownik rozgląda się
			if _wants(dragon):
				state = State.AIM
				_t = 0.0
		State.AIM:
			if not _wants(dragon):
				state = State.IDLE
				_line.visible = false
				return
			var lead := center + dragon.velocity * (_muzzle().distance_to(center) / bolt_speed) * 0.8
			_aim_point = _aim_point.lerp(lead, clampf(delta * 3.0, 0.0, 1.0)) if _t > 0.1 else lead
			_point_bow(_aim_point, delta)
			_show_line(_t / aim_time)
			if _t >= aim_time:
				_fire()
		State.RELOAD:
			if _t >= reload_time:
				state = State.IDLE
				_t = 0.0


func _point_bow(at: Vector3, delta: float) -> void:
	var to := at - _bow.global_position
	var yaw := atan2(to.x, to.z) - global_rotation.y
	var pitch := -atan2(to.y, Vector2(to.x, to.z).length())
	var k := clampf(delta * 5.0, 0.0, 1.0)
	_bow.rotation.y = lerp_angle(_bow.rotation.y, yaw, k)
	_bow.rotation.x = lerp_angle(_bow.rotation.x, pitch, k)


## Ostrzegawcza linia celowania: gęstnieje, gdy strzał się zbliża.
func _show_line(p: float) -> void:
	var from := _muzzle()
	var to := _aim_point
	var len := from.distance_to(to)
	if len < 0.5:
		return
	_line.visible = true
	_line.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)
	_line.scale = Vector3(1.0 + p * 1.5, 1.0 + p * 1.5, len)
	var blink := 0.5 + 0.5 * sin(_t * (10.0 + p * 30.0)) if p > 0.7 else 1.0
	_line_mat.albedo_color.a = (0.12 + 0.5 * p) * blink


func _fire() -> void:
	_line.visible = false
	var bolt := Bolt.create(bolt_mesh, _muzzle(), _aim_point, bolt_speed, bolt_damage, dragon)
	fired.emit(bolt)
	state = State.RELOAD
	_t = 0.0
	var tw := create_tween()  # odrzut łoża
	tw.tween_property(_bow, "position:z", _bow.position.z - 0.5, 0.06)
	tw.tween_property(_bow, "position:z", _bow.position.z, 0.6)


## Obrażenia od ognia smoka.
func burn(damage: float) -> void:
	if state == State.BROKEN:
		return
	health -= damage
	if health > 0.0:
		return
	state = State.BROKEN
	_line.visible = false
	_bow.rotation = Vector3(0.5, _bow.rotation.y, 0.35)  # łoże przekrzywione
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi == _line:
			continue
		var burnt := StandardMaterial3D.new()
		burnt.albedo_color = Color(0.06, 0.05, 0.04, 0.85)
		burnt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_overlay = burnt
	var smoke := FireFx.smoke(Vector3(2, 2, 2))
	smoke.name = "Smoke"
	add_child(smoke)
	destroyed.emit(self)
