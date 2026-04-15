extends Node

const SETTINGS_PATH: String = "user://settings.json"

## Music volume, 0.0 to 1.0
var music_volume: float = 0.8

## SFX volume, 0.0 to 1.0
var sfx_volume: float = 0.8

## Font size preset: 0 = small, 1 = medium, 2 = large
var font_size: int = 1

## Mapping from font_size preset to scale multiplier
const FONT_SCALE: Dictionary = {
	0: 0.85,
	1: 1.0,
	2: 1.2,
}


func _ready() -> void:
	load_settings()


## Returns the font scale multiplier for the current font_size setting.
func get_font_scale() -> float:
	return FONT_SCALE.get(font_size, 1.0)


## Persists current settings to user://settings.json.
func save_settings() -> void:
	var data: Dictionary = {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"font_size": font_size,
	}
	var json_string: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		print_debug("SettingsManager: Failed to open settings file for writing")


## Loads settings from user://settings.json if the file exists.
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		print_debug("SettingsManager: Failed to parse settings file")
		return

	var data: Dictionary = json.data
	music_volume = data.get("music_volume", 0.8)
	sfx_volume = data.get("sfx_volume", 0.8)
	font_size = data.get("font_size", 1)

	apply_audio_settings()


## Applies current audio volume settings to the AudioServer buses.
## Silently skips if the bus does not exist yet.
func apply_audio_settings() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume))
