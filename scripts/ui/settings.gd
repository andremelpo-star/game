extends PanelContainer

@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var btn_font_small: Button = %BtnFontSmall
@onready var btn_font_medium: Button = %BtnFontMedium
@onready var btn_font_large: Button = %BtnFontLarge
@onready var btn_close_settings: Button = %BtnCloseSettings

const ACTIVE_COLOR := Color("#D4C4A0")
const INACTIVE_COLOR := Color("#8B7355")


func _ready() -> void:
	music_slider.value = SettingsManager.music_volume * 100.0
	sfx_slider.value = SettingsManager.sfx_volume * 100.0
	_update_music_label()
	_update_sfx_label()
	_update_font_buttons()

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	btn_font_small.pressed.connect(_on_font_small)
	btn_font_medium.pressed.connect(_on_font_medium)
	btn_font_large.pressed.connect(_on_font_large)
	btn_close_settings.pressed.connect(_on_close)


func _on_music_changed(value: float) -> void:
	SettingsManager.music_volume = value / 100.0
	SettingsManager.apply_audio_settings()
	_update_music_label()


func _on_sfx_changed(value: float) -> void:
	SettingsManager.sfx_volume = value / 100.0
	SettingsManager.apply_audio_settings()
	_update_sfx_label()


func _on_font_small() -> void:
	SettingsManager.font_size = 0
	_update_font_buttons()


func _on_font_medium() -> void:
	SettingsManager.font_size = 1
	_update_font_buttons()


func _on_font_large() -> void:
	SettingsManager.font_size = 2
	_update_font_buttons()


func _on_close() -> void:
	SettingsManager.save_settings()
	visible = false


func _update_music_label() -> void:
	music_value.text = "%d%%" % int(music_slider.value)


func _update_sfx_label() -> void:
	sfx_value.text = "%d%%" % int(sfx_slider.value)


func _update_font_buttons() -> void:
	btn_font_small.add_theme_color_override("font_color",
		ACTIVE_COLOR if SettingsManager.font_size == 0 else INACTIVE_COLOR)
	btn_font_medium.add_theme_color_override("font_color",
		ACTIVE_COLOR if SettingsManager.font_size == 1 else INACTIVE_COLOR)
	btn_font_large.add_theme_color_override("font_color",
		ACTIVE_COLOR if SettingsManager.font_size == 2 else INACTIVE_COLOR)
