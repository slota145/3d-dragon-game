extends Node
## Uruchamia animację AnimationPlayera w węźle-rodzicu (np. zaimportowanym modelu .glb).

@export var animation: StringName = &"Fly"


func _ready() -> void:
	var player: AnimationPlayer = get_parent().find_child("AnimationPlayer", true, false)
	if player and player.has_animation(animation):
		player.play(animation)
