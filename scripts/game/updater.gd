class_name Updater
extends Control
## Sprawdza najnowsze wydanie na GitHubie. Jeśli jest nowsze i zawiera łatkę
## `game-<wersja silnika>.pck` zgodną z tym plikiem .exe, pozwala ją pobrać; po ponownym
## uruchomieniu boot.gd wczytuje łatkę. Bez zgodnej łatki (np. nowy silnik) otwiera stronę wydania.

const REPO := "slota145/3d-dragon-game"

@onready var _label: Label = $Panel/VBox/Label
@onready var _button: Button = $Panel/VBox/Button
@onready var _panel: Control = $Panel

var _latest_tag := ""
var _patch_url := ""
var _release_page := ""
var _api: HTTPRequest
var _download: HTTPRequest
var _ready_to_restart := false


func _ready() -> void:
	_panel.visible = false
	_button.pressed.connect(_on_button_pressed)
	_api = HTTPRequest.new()
	add_child(_api)
	_api.request_completed.connect(_on_release_info)
	var headers := ["User-Agent: DragonGame-Updater", "Accept: application/vnd.github+json"]
	# DRAGON_UPDATE_API pozwala podmienić źródło (testy z lokalnym serwerem)
	var url := OS.get_environment("DRAGON_UPDATE_API")
	if url == "":
		url = "https://api.github.com/repos/%s/releases/latest" % REPO
	_api.request(url, headers)


static func patch_asset_name() -> String:
	var v := Engine.get_version_info()
	var engine := "%d.%d.%d" % [v.major, v.minor, v.patch]
	# Android potrzebuje innych formatów tekstur (ETC2/ASTC) niż Windows (S3TC/BPTC)
	return "game-%s-android.pck" % engine if OS.has_feature("android") else "game-%s.pck" % engine


func _on_release_info(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("Updater: brak informacji o wydaniach (", result, "/", code, ")")
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return
	_latest_tag = str(data.get("tag_name", ""))
	_release_page = str(data.get("html_url", ""))
	for asset in data.get("assets", []):
		if str(asset.get("name", "")) == patch_asset_name():
			_patch_url = str(asset.get("browser_download_url", ""))
	if _latest_tag == "" or GameVersion.compare(_latest_tag, GameVersion.current()) <= 0:
		print("Updater: gra aktualna (", GameVersion.current(), ")")
		return
	_label.text = "Dostępna aktualizacja %s" % _latest_tag
	_button.text = "Pobierz" if _patch_url != "" else "Otwórz stronę"
	_panel.visible = true


func _on_button_pressed() -> void:
	if _ready_to_restart:
		_restart()
	elif _patch_url != "":
		_start_download()
	elif _release_page != "":
		OS.shell_open(_release_page)


func _start_download() -> void:
	_button.disabled = true
	_label.text = "Pobieranie %s…" % _latest_tag
	_download = HTTPRequest.new()
	_download.download_file = GameVersion.PATCH_PATH + ".part"
	_download.max_redirects = 10
	add_child(_download)
	_download.request_completed.connect(_on_downloaded)
	_download.request(_patch_url, ["User-Agent: DragonGame-Updater"])


func _process(_delta: float) -> void:
	if _download and _download.get_body_size() > 0:
		var pct := 100.0 * _download.get_downloaded_bytes() / _download.get_body_size()
		_label.text = "Pobieranie %s… %d%%" % [_latest_tag, int(pct)]


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var part := GameVersion.PATCH_PATH + ".part"
	_download.queue_free()
	_download = null
	_button.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_label.text = "Błąd pobierania (%d/%d)" % [result, code]
		_button.text = "Spróbuj ponownie"
		return
	DirAccess.remove_absolute(GameVersion.PATCH_PATH)
	DirAccess.rename_absolute(part, GameVersion.PATCH_PATH)
	var f := FileAccess.open(GameVersion.PATCH_VERSION_PATH, FileAccess.WRITE)
	f.store_string(_latest_tag.trim_prefix("v"))
	f.close()
	_ready_to_restart = true
	if OS.has_feature("pc"):
		_label.text = "Zaktualizowano do %s" % _latest_tag
		_button.text = "Uruchom ponownie"
	else:
		_label.text = "Zaktualizowano do %s — uruchom grę ponownie" % _latest_tag
		_button.text = "Zamknij"


func _restart() -> void:
	if OS.has_feature("pc"):
		OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	get_tree().quit()
