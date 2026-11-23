class_name Clouds
extends Node3D
## Chmury low-poly (Cloud_A/B z nature.glb) dryfujące z wiatrem nad całym światem; za krawędzią
## mapy wracają z drugiej strony. Bez kolizji — smok może przez nie przelecieć.

@export var count: int = 46
@export var wind: Vector3 = Vector3(3.0, 0.0, 1.2)

var _clouds: Array[Node3D] = []


func _ready() -> void:
	var meshes: Array[Mesh] = []
	var scene: Node = (load("res://assets/models/nature.glb") as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("Cloud_*", "MeshInstance3D", true, false):
		meshes.append(mi.mesh)
	scene.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var lim := Terrain.HALF
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i % meshes.size()]
		var s := rng.randf_range(3.5, 8.0)
		mi.scale = Vector3(s, s * rng.randf_range(0.7, 1.0), s)
		mi.rotation.y = rng.randf() * TAU
		mi.position = Vector3(rng.randf_range(-lim, lim), rng.randf_range(170.0, 270.0), rng.randf_range(-lim, lim))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 2200.0
		add_child(mi)
		_clouds.append(mi)


func _process(delta: float) -> void:
	var lim := Terrain.HALF + 200.0
	for c in _clouds:
		c.position += wind * delta
		if c.position.x > lim:
			c.position.x -= lim * 2.0
		if c.position.z > lim:
			c.position.z -= lim * 2.0
