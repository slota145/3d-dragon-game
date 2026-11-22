extends Node
## Scena startowa: wczytuje pobraną łatkę (.pck), jeśli jest nowsza niż wersja wbudowana,
## a potem przechodzi do świata gry.

const WORLD_SCENE := "res://scenes/world.tscn"


func _ready() -> void:
	_apply_patch()
	get_tree().change_scene_to_file.call_deferred(WORLD_SCENE)


func _apply_patch() -> void:
	if not FileAccess.file_exists(GameVersion.PATCH_PATH):
		return
	var version := FileAccess.get_file_as_string(GameVersion.PATCH_VERSION_PATH).strip_edges()
	if version == "" or GameVersion.compare(version, GameVersion.builtin()) <= 0:
		return  # łatka starsza niż gra (np. po instalacji nowego .exe) – ignorujemy
	if ProjectSettings.load_resource_pack(GameVersion.PATCH_PATH, true):
		GameVersion.patched_version = version
		print("Wczytano aktualizację ", version)
	else:
		push_warning("Nie udało się wczytać łatki %s" % GameVersion.PATCH_PATH)
