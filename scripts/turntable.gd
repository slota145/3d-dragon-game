class_name Turntable
extends Node3D
## Powoli obraca węzeł wokół osi Y — do podglądu modeli w scenie testowej.

@export var degrees_per_second: float = 20.0


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(degrees_per_second) * delta)
