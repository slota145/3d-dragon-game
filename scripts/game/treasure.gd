class_name Treasure
extends RefCounted
## Siatki skarbów z assets/models/treasure.glb (generator: tools/blender/gen_treasure.py)
## i wspólny „złoty” materiał (lekka emisja — złoto błyszczy także w ciemnej jaskini).

const MODEL := "res://assets/models/treasure.glb"

static var _meshes: Dictionary = {}


## Siatka przedmiotu: "Coin", "Goblet", "Crown", "Chest", "Gem".
static func mesh(item: String) -> Mesh:
	if _meshes.is_empty():
		var scene: Node = (load(MODEL) as PackedScene).instantiate()
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			_meshes[String(mi.name).trim_prefix("Treasure_")] = _shine(mi.mesh)
		scene.free()
	return _meshes.get(item)


## Złoto i klejnoty dostają metaliczność i delikatną emisję (widoczne z daleka i w jaskini).
static func _shine(m: Mesh) -> Mesh:
	m = m.duplicate()
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i) as StandardMaterial3D
		if mat == null:
			continue
		mat = mat.duplicate()
		var n := mat.resource_name
		if n.ends_with("Gold"):
			mat.metallic = 0.7
			mat.roughness = 0.35
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.7, 0.2)
			mat.emission_energy_multiplier = 0.25
		elif n.ends_with("Ruby") or n.ends_with("Emerald"):
			mat.roughness = 0.2
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 0.4
		m.surface_set_material(i, mat)
	return m
