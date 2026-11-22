@tool
extends EditorScenePostImport
## Post-import dla dragon.glb:
## - wszystkie materiały używają koloru wierzchołków (losowa jasność ścianek = efekt "ciosanego" low-poly),
## - błona skrzydeł renderowana dwustronnie,
## - animacje Idle, Walk, Fly, Glide i Dive zapętlone.

const LOOPING := ["Idle", "Walk", "Fly", "Glide", "Dive"]


func _post_import(scene: Node) -> Object:
	_fix_materials(scene)
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	if player:
		for anim_name in player.get_animation_list():
			if anim_name in LOOPING:
				player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return scene


func _fix_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var mat := node.mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			mat.vertex_color_use_as_albedo = true
			if mat.resource_name.ends_with("Membrane"):
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in node.get_children():
		_fix_materials(child)
