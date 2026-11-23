class_name DragonProportions
extends SkeletonModifier3D
## Płynne proporcje pisklę -> dorosły: modyfikator szkieletu działający po animacji.
## `youth` = 1 dla świeżo wyklutego pisklęcia, 0 dla dorosłego. Pisklę ma dużą głowę,
## krótką szyję, małe skrzydła, krótszy ogon i masywniejsze łapy.
## Szyję skracamy przesunięciem kości (nie skalą), żeby nie robiła się cienka.

## 0..1 — ustawiane przez kontroler smoka wg rozmiaru (DragonStats.youth()).
@export_range(0.0, 1.0) var youth: float = 0.0
## 0..1 — dodatkowe otwarcie pyska (zianie ogniem), niezależnie od animacji.
var jaw_open: float = 0.0
## Kąt pełnego otwarcia pyska (rad, oś X kości Jaw).
@export var jaw_angle: float = -0.55

@export_group("Pisklę (youth = 1)")
## Głowa: X = szerokość, Y = długość (pysk), Z = wysokość — pisklę ma krótki pyszczek.
@export var head_scale: Vector3 = Vector3(1.6, 1.1, 1.55)
@export var neck_length: float = 0.6
@export var wing_scale: float = 0.5
@export var tail_scale: float = 0.7
@export var leg_scale: float = 1.05

const NECK_CHILDREN := ["Neck2", "Neck3", "Neck4", "Head"]
const WINGS := ["UpperArm.L", "UpperArm.R"]
const LEGS := ["Thigh.L", "Thigh.R"]

var _ids: Dictionary = {}


func _ready() -> void:
	_cache_ids()


func _cache_ids() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	for bone_name in NECK_CHILDREN + WINGS + LEGS + ["Tail1", "Jaw"]:
		_ids[bone_name] = skel.find_bone(bone_name)


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _ids.is_empty():
		_cache_ids()
	if jaw_open > 0.01:
		var jid: int = _ids.get("Jaw", -1)
		if jid >= 0:
			var q := skel.get_bone_pose_rotation(jid) * Quaternion(Vector3.RIGHT, jaw_angle * jaw_open)
			skel.set_bone_pose_rotation(jid, q)
	if youth <= 0.001:
		return
	var y := youth
	var neck := lerpf(1.0, neck_length, y)
	for bone_name in NECK_CHILDREN:
		var id: int = _ids.get(bone_name, -1)
		if id >= 0:
			skel.set_bone_pose_position(id, skel.get_bone_pose_position(id) * neck)
	_scale_bone_v(skel, "Head", Vector3.ONE.lerp(head_scale, y))
	_scale_bone(skel, "Tail1", lerpf(1.0, tail_scale, y))
	for bone_name in WINGS:
		_scale_bone(skel, bone_name, lerpf(1.0, wing_scale, y))
	for bone_name in LEGS:
		_scale_bone(skel, bone_name, lerpf(1.0, leg_scale, y))


func _scale_bone(skel: Skeleton3D, bone_name: String, s: float) -> void:
	_scale_bone_v(skel, bone_name, Vector3.ONE * s)


func _scale_bone_v(skel: Skeleton3D, bone_name: String, s: Vector3) -> void:
	var id: int = _ids.get(bone_name, -1)
	if id >= 0:
		skel.set_bone_pose_scale(id, skel.get_bone_pose_scale(id) * s)
