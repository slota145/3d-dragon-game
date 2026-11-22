class_name SaveGame
extends RefCounted
## Zapis gry w user://save.json: pełny przy śnie w legowisku, ciche autozapisy co chwilę
## i przy wyjściu / zminimalizowaniu aplikacji (Android potrafi zabić grę w tle).

const PATH := "user://save.json"
const FORMAT := 1


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func load_data() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary or int(data.get("format", 0)) != FORMAT:
		return {}
	return data


static func write(data: Dictionary) -> void:
	data["format"] = FORMAT
	# najpierw plik tymczasowy, potem podmiana — przerwany zapis nie psuje poprzedniego
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Nie można zapisać gry: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
