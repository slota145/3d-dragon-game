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
	_player.launched.connect(func() -> void: DustBurst.spawn(self, _player.global_position, 1.4))
	_player.landed.connect(_on_landed)
	_player.dashed.connect(func() -> void: _flash = 1.0)


var _flash: float = 0.0
var _effect: float = 0.0


func _on_landed(impact: float) -> void:
	if impact > 6.0:
		DustBurst.spawn(self, _player.global_position, clampf(impact / 14.0, 0.5, 1.5))


func _process(delta: float) -> void:
	_effect = lerpf(_effect, _player.speed_effect, clampf(5.0 * delta, 0.0, 1.0))
	_flash = maxf(0.0, _flash - delta * 2.5)
	_camera.effect = _effect
	var lines := _hud.get_node("SpeedLines") as ColorRect
	(lines.material as ShaderMaterial).set_shader_parameter("intensity", _effect)
	(lines.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	var v := _player.velocity
	var mode := "lot" if _player.is_flying() else "ziemia"
	_hud.get_node("Status").text = "%s · wys. %d m · %d km/h" % [mode, int(_player.global_position.y),
		int(v.length() * 3.6)]
