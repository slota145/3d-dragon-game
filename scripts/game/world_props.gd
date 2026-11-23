extends Node3D
## Skalne słupy (turnie) z kolizją wokół łąki — cel lotu i lądowania; na ich szczytach leżą
## ukryte skrytki ze złotem (GoldFinds). Teren, las, skały i trawę robią Terrain i TerrainDecor.

@export var seed: int = 42
@export var pillar_count: int = 12

## Szczyty skalnych słupów (globalnie) — tam leżą ukryte skrytki ze złotem (tylko dla latających).
var pillar_tops: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.44, 0.41)
	mat.roughness = 1.0
	var tries := 0
	while pillar_tops.size() < pillar_count and tries < 200:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(70.0, 360.0)
		var pos := Vector3(cos(ang), 0, sin(ang)) * dist
		var h := rng.randf_range(20.0, 48.0)
		var radius := rng.randf_range(6.0, 11.0)
		var top_r := radius * rng.randf_range(0.12, 0.25)
		var sides := rng.randi_range(6, 9)
		var yaw := rng.randf() * TAU
		if _in_lair(pos, 15.0) or not Terrain.is_walkable(pos.x, pos.z):
			continue
		pos.y = Terrain.height(pos.x, pos.z) - 2.0  # osadzony w terenie
		_add_pillar(pos, h + 2.0, radius, top_r, sides, yaw, mat)
		pillar_tops.append(global_position + pos + Vector3.UP * (h + 2.0))


## Czy punkt leży na wzgórzu legowiska (tam nic nie stawiamy).
func _in_lair(pos: Vector3, margin: float = 0.0) -> bool:
	return Vector2(pos.x - Lair.POSITION.x, pos.z - Lair.POSITION.z).length() < Lair.RADIUS + margin


func _add_pillar(pos: Vector3, height: float, radius: float, top_r: float, sides: int, yaw: float,
		mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 2
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = height / 2.0
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_convex_shape()
	col.position.y = height / 2.0
	body.add_child(col)
