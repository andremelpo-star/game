extends Node


## Returns an array of consequences that should fire on the given day.
## Filters pending_consequences from GameState: trigger_day <= day AND applied == false.
## Each entry is enriched with full data from ContentLoader.load_consequences().
func get_active_consequences(day: int) -> Array[Dictionary]:
	var all_consequences: Dictionary = ContentLoader.load_consequences()
	var result: Array[Dictionary] = []

	for entry in GameState.pending_consequences:
		if entry["applied"]:
			continue
		if entry["trigger_day"] > day:
			continue

		var event_id: String = entry["event_id"]
		if all_consequences.has(event_id):
			var full_data: Dictionary = all_consequences[event_id].duplicate()
			full_data["event_id"] = event_id
			result.append(full_data)

	return result


## Returns only consequences of type "city_walk" for the current day.
func get_city_walk_events() -> Array[Dictionary]:
	var active: Array[Dictionary] = get_active_consequences(GameState.current_day)
	var result: Array[Dictionary] = []
	for event in active:
		if event.get("type", "") == "city_walk":
			result.append(event)
	return result


## Applies a consequence: modifies city_stats and marks it as applied.
func apply_consequence(event_id: String) -> void:
	var all_consequences: Dictionary = ContentLoader.load_consequences()
	if not all_consequences.has(event_id):
		push_warning("ConsequenceEngine: Unknown consequence '%s'" % event_id)
		return

	var data: Dictionary = all_consequences[event_id]
	var changes: Variant = data.get("city_state_change", null)
	if changes is Dictionary:
		for stat_name in changes:
			GameState.modify_city_stat(stat_name, int(changes[stat_name]))

	GameState.mark_consequence_applied(event_id)
