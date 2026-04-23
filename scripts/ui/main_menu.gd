extends Control

@onready var background: TextureRect = $Background
@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_continue: Button = %BtnContinue
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var settings_overlay: PanelContainer = %SettingsOverlay

var _menu_texture: Texture2D


func _ready() -> void:
	_menu_texture = load("res://assets/ui/menu.png")
	if _menu_texture:
		background.texture = _menu_texture

	btn_continue.visible = GameState.has_save()

	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	settings_overlay.visible = false

	# Reposition buttons on resize to match the background image
	get_viewport().size_changed.connect(_reposition_buttons)
	_reposition_buttons()


func _reposition_buttons() -> void:
	if not _menu_texture:
		return

	var vp_size := get_viewport_rect().size
	var img_size := _menu_texture.get_size()  # 1672 x 941

	# Calculate how the image is displayed with keep_aspect_covered (stretch_mode 6)
	var scale_x := vp_size.x / img_size.x
	var scale_y := vp_size.y / img_size.y
	var scale := maxf(scale_x, scale_y)

	var displayed_w := img_size.x * scale
	var displayed_h := img_size.y * scale
	var offset_x := (vp_size.x - displayed_w) / 2.0
	var offset_y := (vp_size.y - displayed_h) / 2.0

	# Button areas in original image coordinates (1672x941)
	# These define the clickable regions over each book spine
	var buttons_data: Array[Dictionary] = [
		{"node": btn_new_game, "x": 560, "y": 58, "w": 960, "h": 185},
		{"node": btn_continue, "x": 560, "y": 252, "w": 960, "h": 185},
		{"node": btn_settings, "x": 560, "y": 446, "w": 960, "h": 185},
		{"node": btn_quit, "x": 560, "y": 642, "w": 960, "h": 185},
	]

	for data in buttons_data:
		var btn: Button = data["node"]
		var bx: float = data["x"] * scale + offset_x
		var by: float = data["y"] * scale + offset_y
		var bw: float = data["w"] * scale
		var bh: float = data["h"] * scale
		btn.position = Vector2(bx, by)
		btn.size = Vector2(bw, bh)


func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.new_game()
	# Skip intro text, go directly to the first playable scene
	SceneTransition.change_scene("res://scenes/library/library.tscn")


func _on_continue_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.load_game()
	SceneTransition.change_scene("res://scenes/library/library.tscn")


func _on_settings_pressed() -> void:
	settings_overlay.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
