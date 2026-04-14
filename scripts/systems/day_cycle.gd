extends Node

signal day_started(day_number: int)
signal ending_triggered(ending_id: String)

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
## loads visitors, autosaves, and checks for endings.
func start_new_day() -> void:
	GameState.current_day += 1
	GameState.reset_for_new_day()
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
