extends Node3D
## Świat testowy: łączy gracza, kamerę i HUD.

@onready var _player: DragonController = $DragonPlayer
@onready var _camera: FollowCamera = $FollowCamera
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	_camera.target = _player
	_player.camera = _camera
	_player.joystick = _hud.get_node("Joystick")
	_hud.get_node("Version").text = "v" + GameVersion.current()
