extends Control

@onready var background: ColorRect = $Background
@onready var ending_title: Label = %EndingTitle
@onready var ending_text: RichTextLabel = %EndingText
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var btn_main_menu: Button = %BtnMainMenu


func _ready() -> void:
	btn_main_menu.pressed.connect(_on_main_menu_pressed)

	var ending_id: String = GameState.get_meta("current_ending", "neutral_ending")
	_load_ending(ending_id)
	_populate_stats()


func _load_ending(ending_id: String) -> void:
	var endings: Dictionary = ContentLoader.load_endings()
	if endings.is_empty():
		print_debug("EndingScene: No endings loaded")
		return

	var ending: Dictionary = endings.get(ending_id, {})
	if ending.is_empty():
		print_debug("EndingScene: Ending '%s' not found" % ending_id)
		return

	ending_title.text = ending.get("title", "")

	var text_content: String = ending.get("text", "")
	ending_text.text = "[center]%s[/center]" % text_content

	var bg_color_str: String = ending.get("background_color", "#3A3A2E")
	background.color = Color(bg_color_str)


func _populate_stats() -> void:
	var stats: Array[String] = [
		"Дней прожито: %d из 7" % GameState.current_day,
		"Советов дано: %d" % GameState.completed_visitors.size(),
		"Книг прочитано: %d" % GameState.read_books.size(),
		"",
		"Доверие: %d" % GameState.city_stats.get("trust", 0),
		"Процветание: %d" % GameState.city_stats.get("prosperity", 0),
		"Безопасность: %d" % GameState.city_stats.get("safety", 0),
		"Мораль: %d" % GameState.city_stats.get("morale", 0),
	]
	for text in stats:
		var label := Label.new()
		label.text = text
		label.add_theme_color_override("font_color", Color("#D4C4A0"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(label)


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
