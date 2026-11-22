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


func _process(_delta: float) -> void:
	var v := _player.velocity
	var mode := "lot" if _player.is_flying() else "ziemia"
	_hud.get_node("Status").text = "%s · wys. %d m · %d km/h" % [mode, int(_player.global_position.y),
		int(v.length() * 3.6)]
