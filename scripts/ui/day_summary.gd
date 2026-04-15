extends Control

@onready var title_label: Label = %TitleLabel
@onready var answers_label: Label = %SummaryAnswersLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var btn_city_walk: Button = %BtnCityWalk
@onready var btn_next_day: Button = %BtnNextDay

var _stats_before: Dictionary = {}

const STAT_NAMES: Dictionary = {
	"trust": "Доверие",
	"prosperity": "Богатство",
	"safety": "Безопасность",
	"morale": "Мораль",
}


func _ready() -> void:
	btn_city_walk.pressed.connect(_on_city_walk_pressed)
	btn_next_day.pressed.connect(_on_next_day_pressed)

	# Use DayCycle snapshot for delta calculation
	_stats_before = DayCycle.get_day_start_stats()
	show_summary(GameState.current_day, _stats_before)


## Fills the UI with day number, stat deltas, and current values.
func show_summary(day: int, stats_before: Dictionary) -> void:
	title_label.text = "День %d завершен" % day
	answers_label.text = "Советов дано: %d" % GameState.answers_today

	# Clear previous stat entries
	for child in stats_container.get_children():
		child.queue_free()

	# Build stat delta display
	for stat_name in GameState.city_stats:
		var current_val: int = GameState.city_stats[stat_name]
		var before_val: int = stats_before.get(stat_name, current_val)
		var delta: int = current_val - before_val

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var name_label := Label.new()
		name_label.text = STAT_NAMES.get(stat_name, stat_name)
		name_label.custom_minimum_size.x = 140
		name_label.add_theme_color_override("font_color", Color(1, 0.973, 0.906, 1))
		name_label.add_theme_font_size_override("font_size", 20)
		hbox.add_child(name_label)

		var value_label := Label.new()
		value_label.text = str(current_val)
		value_label.custom_minimum_size.x = 40
		value_label.add_theme_color_override("font_color", Color(1, 0.973, 0.906, 1))
		value_label.add_theme_font_size_override("font_size", 20)
		hbox.add_child(value_label)

		var delta_label := Label.new()
		if delta > 0:
			delta_label.text = "(+%d)" % delta
			delta_label.add_theme_color_override("font_color", Color(0.298, 0.686, 0.314, 1))
		elif delta < 0:
			delta_label.text = "(%d)" % delta
			delta_label.add_theme_color_override("font_color", Color(0.957, 0.263, 0.212, 1))
		else:
			delta_label.text = "(0)"
			delta_label.add_theme_color_override("font_color", Color(1, 0.973, 0.906, 0.5))
		delta_label.add_theme_font_size_override("font_size", 20)
		hbox.add_child(delta_label)

		stats_container.add_child(hbox)

	# Show city walk button only if there are active city_walk events
	btn_city_walk.visible = ConsequenceEngine.get_city_walk_events().size() > 0


func _on_city_walk_pressed() -> void:
	AudioManager.play_sfx("click")
	SceneTransition.change_scene("res://scenes/city/city_walk.tscn")


func _on_next_day_pressed() -> void:
	AudioManager.play_sfx("click")
	DayCycle.start_new_day()

	# Check if an ending was triggered during start_new_day
	var ending: String = DayCycle.check_endings()
	if ending != "":
		GameState.set_meta("current_ending", ending)
		SceneTransition.change_scene("res://scenes/main/ending_scene.tscn")
	else:
		SceneTransition.change_scene("res://scenes/library/library.tscn")
