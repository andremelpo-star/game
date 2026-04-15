extends Control

@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_continue: Button = %BtnContinue
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var settings_overlay: PanelContainer = %SettingsOverlay


func _ready() -> void:
	btn_continue.visible = GameState.has_save()

	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	settings_overlay.visible = false


func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.new_game()
	SceneTransition.change_scene("res://scenes/main/intro.tscn")


func _on_continue_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.load_game()
	SceneTransition.change_scene("res://scenes/library/library.tscn")


func _on_settings_pressed() -> void:
	settings_overlay.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
