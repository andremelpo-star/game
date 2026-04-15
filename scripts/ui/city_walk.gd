extends Node2D

@onready var hint_label: Label = %HintLabel
@onready var event_overlay: PanelContainer = %EventOverlay
@onready var event_text: RichTextLabel = %EventText
@onready var npc_dialogue: RichTextLabel = %NPCDialogue
@onready var btn_close_event: Button = %BtnCloseEvent
@onready var npc_sprite: ColorRect = $Characters/NPCSprite

# HUD elements
@onready var day_label: Label = %DayLabel
@onready var trust_progress: ProgressBar = %TrustProgress
@onready var prosperity_progress: ProgressBar = %ProsperityProgress
@onready var safety_progress: ProgressBar = %SafetyProgress
@onready var morale_progress: ProgressBar = %MoraleProgress

# Mapping location -> zone node name
const LOCATION_TO_ZONE: Dictionary = {
	"market": "MarketZone",
	"gates": "GatesZone",
	"temple": "TempleZone",
	"smithy": "SmithyZone",
	"tavern": "TavernZone",
}

const ZONE_HINTS: Dictionary = {
	"MarketZone": "Рыночная площадь",
	"GatesZone": "Городские ворота",
	"TempleZone": "Храм",
	"SmithyZone": "Кузница",
	"TavernZone": "Таверна",
	"ReturnZone": "Вернуться в библиотеку",
}

# Zone center positions for placing NPC sprite nearby
const ZONE_POSITIONS: Dictionary = {
	"MarketZone": Vector2(400, 400),
	"GatesZone": Vector2(1600, 500),
	"TempleZone": Vector2(960, 200),
	"SmithyZone": Vector2(300, 700),
	"TavernZone": Vector2(1200, 600),
}

var _active_events: Dictionary = {}  # zone_name -> consequence data
var _viewed_events: Array[String] = []  # event IDs already viewed this visit


func _ready() -> void:
	# Load active city_walk events
	var events: Array[Dictionary] = ConsequenceEngine.get_city_walk_events()
	for event in events:
		var location: String = event.get("location", "")
		var zone_name: String = LOCATION_TO_ZONE.get(location, "")
		if zone_name != "":
			_active_events[zone_name] = event

	# Connect zone signals and highlight active zones
	var zones_parent: Node2D = $InteractiveZones
	for child in zones_parent.get_children():
		if child is Area2D:
			child.mouse_entered.connect(_on_zone_hover.bind(child))
			child.mouse_exited.connect(_on_zone_unhover.bind(child))
			child.input_event.connect(_on_zone_input_event.bind(child))

			# Highlight zones with active events
			if child.name in _active_events:
				var highlight: ColorRect = child.get_node_or_null("Highlight")
				if highlight:
					highlight.visible = true
					highlight.color = Color(1.0, 0.75, 0.0, 0.25)
					_start_pulse(highlight)

	# Hide overlay initially
	event_overlay.visible = false
	npc_sprite.visible = false
	hint_label.text = "Кликните на здание, чтобы осмотреть"

	btn_close_event.pressed.connect(_on_close_event)

	_update_hud()


func _on_zone_hover(zone: Area2D) -> void:
	if event_overlay.visible:
		return
	var highlight: ColorRect = zone.get_node_or_null("Highlight")
	if highlight and zone.name not in _active_events:
		highlight.visible = true
	hint_label.text = ZONE_HINTS.get(zone.name, "")


func _on_zone_unhover(zone: Area2D) -> void:
	var highlight: ColorRect = zone.get_node_or_null("Highlight")
	if highlight and zone.name not in _active_events:
		highlight.visible = false
	if not event_overlay.visible:
		hint_label.text = "Кликните на здание, чтобы осмотреть"


func _on_zone_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, zone: Area2D) -> void:
	if event_overlay.visible:
		return
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	_on_zone_clicked(zone)


func _on_zone_clicked(zone: Area2D) -> void:
	if zone.name == "ReturnZone":
		AudioManager.play_sfx("door")
		SceneTransition.change_scene("res://scenes/library/library.tscn")
		return

	if zone.name in _active_events:
		_show_event(zone.name, _active_events[zone.name])
	else:
		hint_label.text = "Здесь всё спокойно"


func _show_event(zone_name: String, event: Dictionary) -> void:
	# Position NPC sprite near the zone
	var zone_pos: Vector2 = ZONE_POSITIONS.get(zone_name, Vector2(960, 540))
	npc_sprite.position = zone_pos + Vector2(60, -30)

	# Try loading a portrait image for the NPC; fall back to plain ColorRect
	var portrait_key: String = str(event.get("portrait", ""))
	var portrait_texture: Texture2D = null
	if portrait_key != "":
		portrait_texture = _try_load_portrait_texture(portrait_key)

	if portrait_texture:
		# Replace the ColorRect with a TextureRect if not done yet
		var tex_rect: TextureRect = npc_sprite.get_node_or_null("PortraitTexture")
		if tex_rect == null:
			tex_rect = TextureRect.new()
			tex_rect.name = "PortraitTexture"
			tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			npc_sprite.add_child(tex_rect)
		tex_rect.texture = portrait_texture
		tex_rect.visible = true
	else:
		var tex_rect: TextureRect = npc_sprite.get_node_or_null("PortraitTexture")
		if tex_rect:
			tex_rect.visible = false

	npc_sprite.visible = true

	# Fill overlay text
	event_text.text = event.get("scene_text", "")
	npc_dialogue.text = event.get("npc_dialogue", "")
	event_overlay.visible = true

	# Apply consequence
	var event_id: String = event.get("event_id", event.get("id", ""))
	if event_id != "" and event_id not in _viewed_events:
		ConsequenceEngine.apply_consequence(event_id)
		_viewed_events.append(event_id)


func _on_close_event() -> void:
	event_overlay.visible = false
	npc_sprite.visible = false
	_update_hud()
	hint_label.text = "Кликните на здание, чтобы осмотреть"


func _start_pulse(highlight: ColorRect) -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(highlight, "modulate:a", 0.4, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(highlight, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func _update_hud() -> void:
	day_label.text = "День %d" % GameState.current_day
	_update_progress_bar(trust_progress, GameState.city_stats.get("trust", 50))
	_update_progress_bar(prosperity_progress, GameState.city_stats.get("prosperity", 50))
	_update_progress_bar(safety_progress, GameState.city_stats.get("safety", 50))
	_update_progress_bar(morale_progress, GameState.city_stats.get("morale", 50))


func _update_progress_bar(bar: ProgressBar, value: int) -> void:
	# Animate value change
	var tween := create_tween()
	tween.tween_property(bar, "value", float(value), 0.5).set_trans(Tween.TRANS_QUAD)

	_update_progress_bar_color(bar, value)

	# Update tooltip
	var stat_name: String = ""
	if bar == trust_progress:
		stat_name = "Trust"
	elif bar == prosperity_progress:
		stat_name = "Prosperity"
	elif bar == safety_progress:
		stat_name = "Safety"
	elif bar == morale_progress:
		stat_name = "Morale"
	bar.tooltip_text = "%s: %d/100" % [stat_name, value]


func _update_progress_bar_color(bar: ProgressBar, value: int) -> void:
	var color: Color
	if value > 60:
		color = Color("#4CAF50")
	elif value >= 30:
		color = Color("#FFC107")
	else:
		color = Color("#F44336")
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", style)


## Attempts to load a portrait texture by key. First tries the Godot resource
## system, then falls back to loading the raw image via Image + ImageTexture.
static func _try_load_portrait_texture(portrait_key: String) -> Texture2D:
	var base_path: String = "res://assets/portraits/%s" % portrait_key

	for ext in ["png", "jpg", "jpeg", "webp"]:
		var path: String = "%s.%s" % [base_path, ext]

		# Method 1: Godot resource loader (works if editor has imported the file)
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex:
				return tex

		# Method 2: Raw file loading via Image (works without editor import)
		if FileAccess.file_exists(path):
			var image := Image.new()
			var err: Error = image.load(path)
			if err == OK:
				return ImageTexture.create_from_image(image)

	return null
