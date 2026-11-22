extends Node3D
## Scena prezentacyjna modelu: odtwarza animację i ustawia kamerę wg presetu.
## Argumenty z linii poleceń (po `--`, np. przez tools/screenshot.sh):
##   anim=Idle|Fly|Glide|Roar  t=1.2  cam=ref|side|front|top|head|low|idle

const CAMERAS := {
	"ref": [Vector3(-8.6, 2.6, 7.6), Vector3(0.0, 2.3, 2.2)],
	"side": [Vector3(-17.0, 3.2, -1.0), Vector3(0.0, 2.2, -1.0)],
	"front": [Vector3(0.0, 4.0, 15.0), Vector3(0.0, 2.6, 0.0)],
	"top": [Vector3(0.0, 21.0, 2.0), Vector3(0.0, 0.0, -0.6)],
	"head": [Vector3(-2.7, 3.25, 6.4), Vector3(0.0, 2.75, 4.25)],
	"roarhead": [Vector3(-3.6, 2.6, 6.6), Vector3(0.0, 2.0, 3.9)],
	"idle": [Vector3(-9.5, 4.5, 7.0), Vector3(0.0, 2.2, 0.8)],
	"low": [Vector3(-7.0, 0.8, 9.0), Vector3(0.0, 3.0, 0.5)],
}

@export var model: Node3D
@export var animation: StringName = &"Idle"
## >= 0: zatrzymaj animację w tym momencie (sekundy).
@export var freeze_at: float = -1.0
@export var camera_preset: String = "ref"

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"anim": animation = StringName(kv[1])
			"t": freeze_at = float(kv[1])
			"cam": camera_preset = kv[1]
	var preset: Array = CAMERAS.get(camera_preset, CAMERAS["ref"])
	_camera.look_at_from_position(preset[0], preset[1])
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player and player.has_animation(animation):
		player.play(animation)
		if freeze_at >= 0.0:
			player.seek(freeze_at, true)
			player.pause()
