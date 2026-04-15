extends Node

signal day_started(day_number: int)
signal ending_triggered(ending_id: String)
signal notification_triggered(title: String, text: String)

const MAX_DAYS: int = 7

## Snapshot of city_stats at the start of the current day, used for delta calculation.
var _day_start_stats: Dictionary = {}


func _ready() -> void:
	_snapshot_stats()


## Saves a copy of current city_stats for later delta calculation.
func _snapshot_stats() -> void:
	_day_start_stats = GameState.city_stats.duplicate()


## Returns the stat snapshot taken at the beginning of the day.
func get_day_start_stats() -> Dictionary:
	return _day_start_stats


## Advances to the next day: increments day counter, resets daily state,
## processes auto-trigger consequences, loads visitors, autosaves, and
## checks for endings.
func start_new_day() -> void:
	GameState.current_day += 1
	GameState.reset_for_new_day()

	# Process "visitor" type consequences -- inject them as visitors for today
	_process_visitor_consequences()

	# Process "notification" type consequences -- apply presets and mark done
	_process_notification_consequences()

	VisitorManager.start_day(GameState.current_day)
	GameState.save_game()
	_snapshot_stats()
	day_started.emit(GameState.current_day)

	var ending: String = check_endings()
	if ending != "":
		ending_triggered.emit(ending)


## Evaluates ending conditions based on current game state.
## Returns an ending id string, or "" if the game continues.
func check_endings() -> String:
	if GameState.city_stats.get("trust", 50) < 20:
		return "burned"

	for stat_name in GameState.city_stats:
		if GameState.city_stats[stat_name] == 0:
			return "city_falls"

	if GameState.current_day > MAX_DAYS:
		var all_high: bool = true
		for stat_name in GameState.city_stats:
			if GameState.city_stats[stat_name] <= 70:
				all_high = false
				break
		if all_high:
			return "best_ending"
		return "neutral_ending"

	return ""


## Processes "visitor" type consequences: injects their visitor_id into today.
func _process_visitor_consequences() -> void:
	var visitor_events: Array[Dictionary] = ConsequenceEngine.get_visitor_events()
	for event in visitor_events:
		var visitor_id: String = str(event.get("visitor_id", ""))
		if visitor_id != "":
			GameState.inject_visitor(visitor_id, GameState.current_day)
		var event_id: String = event.get("event_id", event.get("id", ""))
		if event_id != "":
			ConsequenceEngine.apply_consequence(event_id)


## Processes "notification" type consequences: emits notification signals and
## applies any presets attached to them.
func _process_notification_consequences() -> void:
	var notif_events: Array[Dictionary] = ConsequenceEngine.get_notification_events()
	for event in notif_events:
		var title: String = str(event.get("title", ""))
		var text: String = str(event.get("text", ""))
		if title != "" or text != "":
			notification_triggered.emit(title, text)
		var event_id: String = event.get("event_id", event.get("id", ""))
		if event_id != "":
			ConsequenceEngine.apply_consequence(event_id)
