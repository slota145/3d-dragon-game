extends Node3D
## Świat testowy: łączy gracza, kamerę i HUD.

@onready var _player: DragonController = $DragonPlayer
@onready var _camera: FollowCamera = $FollowCamera
@onready var _hud: CanvasLayer = $HUD
@onready var _spawner: PreySpawner = $Prey
var _spawn_point: Vector3


func _ready() -> void:
	_camera.target = _player
	_player.camera = _camera
	_player.joystick = _hud.get_node("Joystick")
	_spawn_point = _player.global_position
	_hud.get_node("StatBars").stats = _player.stats
	_player.stats.stage_changed.connect(_on_stage_changed)
	_player.stats.ate.connect(func(_meal: float, prey_name: String, growth: float) -> void:
		_toast("%s · +%s" % [prey_name, ("%d cm" % roundi(growth * 100.0)) if growth < 1.0 else ("%.1f m" % growth)]))
	_player.stats.died.connect(_on_died)
	_spawner.dragon = _player
	_spawner.populate()
	_update_buttons()
	_hud.get_node("Version").text = "v" + GameVersion.current()
	_player.launched.connect(func() -> void: DustBurst.spawn(self, _player.global_position, 1.4 * _player.size_k()))
	_player.landed.connect(_on_landed)
	_player.dashed.connect(func() -> void: _flash = 1.0)


var _flash: float = 0.0
var _effect: float = 0.0


func _on_landed(impact: float) -> void:
	if impact > 6.0:
		DustBurst.spawn(self, _player.global_position, clampf(impact / 14.0, 0.5, 1.5) * maxf(_player.size_k(), 0.3))


func _update_buttons() -> void:
	var flap: TouchActionButton = _hud.get_node("FlapButton")
	flap.label = "SKRZYDŁA" if _player.stats.can_fly() else "SKOK"
	# ogień pojawi się w fazie 7 — na razie przycisk zablokowany
	(_hud.get_node("FireButton") as TouchActionButton).locked = true


func _on_stage_changed(_stage: int, stage_name: String) -> void:
	var unlocks := ""
	if _player.stats.stage == DragonStats.Stage.JUVENILE:
		unlocks = "Odblokowano: LOT!"
	_banner(stage_name.to_upper() + "!", unlocks)
	_update_buttons()
	DustBurst.spawn(self, _player.global_position, 1.2 * maxf(_player.size_k(), 0.4), Color(1.0, 0.85, 0.45))


func _on_died() -> void:
	_banner("Zemdlałeś z głodu…", "Budzisz się w bezpiecznym miejscu")
	_player.global_position = _spawn_point
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()  # teleport — bez „przelotu” interpolacji
	_player.stats.revive(60.0, 45.0)


func _banner(title: String, subtitle: String) -> void:
	var b: Label = _hud.get_node("Banner")
	b.text = title + ("\n" + subtitle if subtitle != "" else "")
	b.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(b, "modulate:a", 0.0, 1.0)


func _toast(text: String) -> void:
	var t: Label = _hud.get_node("Toast")
	t.text = text
	t.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(t, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_camera.size_k = _player.size_k()
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
