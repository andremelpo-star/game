extends Control

# Design viewport size matching project.godot settings.
const DESIGN_SIZE := Vector2(1920.0, 1080.0)

@onready var background: TextureRect = $Background
@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_continue: Button = %BtnContinue
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var settings_overlay: PanelContainer = %SettingsOverlay

var _menu_texture: Texture2D

# Button rects in design-space coordinates (1920x1080), kept in sync with
# main_menu.tscn so that the editor layout is the single source of truth.
# Format: [left, top, right, bottom] matching offset_left/top/right/bottom.
var _button_rects: Array[Dictionary] = []


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

	# Store the design-space rects that match main_menu.tscn offsets.
	_button_rects = [
		{"node": btn_new_game, "left": 828.0, "top": 282.0, "right": 1635.0, "bottom": 451.0},
		{"node": btn_continue, "left": 822.0, "top": 440.0, "right": 1623.0, "bottom": 606.0},
		{"node": btn_settings, "left": 808.0, "top": 602.0, "right": 1622.0, "bottom": 754.0},
		{"node": btn_quit, "left": 792.0, "top": 758.0, "right": 1650.0, "bottom": 921.0},
	]

	# Reposition buttons on resize to match the background image
	get_viewport().size_changed.connect(_reposition_buttons)
	_reposition_buttons()


func _reposition_buttons() -> void:
	if not _menu_texture:
		return

	var vp_size := get_viewport_rect().size
	var img_size := _menu_texture.get_size()  # e.g. 1672 x 941

	# How the image fills the design viewport with keep_aspect_covered
	var design_scale_x := DESIGN_SIZE.x / img_size.x
	var design_scale_y := DESIGN_SIZE.y / img_size.y
	var design_scale := maxf(design_scale_x, design_scale_y)
	var design_offset_x := (DESIGN_SIZE.x - img_size.x * design_scale) / 2.0
	var design_offset_y := (DESIGN_SIZE.y - img_size.y * design_scale) / 2.0

	# How the image fills the actual viewport with keep_aspect_covered
	var vp_scale_x := vp_size.x / img_size.x
	var vp_scale_y := vp_size.y / img_size.y
	var vp_scale := maxf(vp_scale_x, vp_scale_y)
	var vp_offset_x := (vp_size.x - img_size.x * vp_scale) / 2.0
	var vp_offset_y := (vp_size.y - img_size.y * vp_scale) / 2.0

	for data in _button_rects:
		var btn: Button = data["node"]
		var left: float = data["left"]
		var top: float = data["top"]
		var right: float = data["right"]
		var bottom: float = data["bottom"]

		# Convert design-space coords to image-space coords
		var img_left := (left - design_offset_x) / design_scale
		var img_top := (top - design_offset_y) / design_scale
		var img_right := (right - design_offset_x) / design_scale
		var img_bottom := (bottom - design_offset_y) / design_scale

		# Convert image-space coords to current viewport coords
		var screen_left := img_left * vp_scale + vp_offset_x
		var screen_top := img_top * vp_scale + vp_offset_y
		var screen_right := img_right * vp_scale + vp_offset_x
		var screen_bottom := img_bottom * vp_scale + vp_offset_y

		btn.position = Vector2(screen_left, screen_top)
		btn.size = Vector2(screen_right - screen_left, screen_bottom - screen_top)


func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.new_game()
	SceneTransition.change_scene("res://scenes/library/library.tscn")


func _on_continue_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.load_game()
	SceneTransition.change_scene("res://scenes/library/library.tscn")


func _on_settings_pressed() -> void:
	settings_overlay.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
