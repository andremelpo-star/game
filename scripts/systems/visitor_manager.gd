extends Node

signal day_complete

var today_visitors: Array[Dictionary] = []
var current_visitor_index: int = 0


## Loads visitors for the given day, filtering out already completed ones.
func start_day(day: int) -> void:
	today_visitors = ContentLoader.load_visitors_for_day(day)
	current_visitor_index = 0
	# Filter out already answered visitors
	var filtered: Array[Dictionary] = []
	for v in today_visitors:
		if v.get("id", "") not in GameState.completed_visitors:
			filtered.append(v)
	today_visitors = filtered


## Returns the next unvisited visitor Dictionary, or null if none remain.
func get_next_visitor() -> Variant:
	while current_visitor_index < today_visitors.size():
		var visitor: Dictionary = today_visitors[current_visitor_index]
		var vid: String = visitor.get("id", "")
		current_visitor_index += 1
		if vid not in GameState.completed_visitors:
			return visitor
	return null


## Returns how many visitors have not yet been answered.
func get_remaining_count() -> int:
	var count: int = 0
	for v in today_visitors:
		if v.get("id", "") not in GameState.completed_visitors:
			count += 1
	return count


## Processes the player's answer: applies city effects, consequences, increments counters.
func submit_answer(visitor_id: String, answer_id: String) -> void:
	var visitor: Dictionary = _find_visitor(visitor_id)
	if visitor.is_empty():
		push_warning("VisitorManager: Visitor '%s' not found" % visitor_id)
		return

	var answer: Dictionary = _find_answer(visitor, answer_id)
	if answer.is_empty():
		push_warning("VisitorManager: Answer '%s' not found for visitor '%s'" % [answer_id, visitor_id])
		return

	# Apply city effects
	if answer.has("city_effect"):
		var effects: Dictionary = answer["city_effect"]
		for stat in effects:
			GameState.modify_city_stat(stat, int(effects[stat]))

	# Add consequence if present
	if answer.has("consequence_event") and answer["consequence_event"] != null:
		var event_id: String = str(answer["consequence_event"])
		var consequences: Dictionary = ContentLoader.load_consequences()
		var trigger_delay: int = 1
		if consequences.has(event_id):
			trigger_delay = int(consequences[event_id].get("trigger_delay", 1))
		var trigger_day: int = GameState.current_day + trigger_delay
		GameState.add_consequence(event_id, trigger_day)

	GameState.answers_today += 1
	GameState.completed_visitors.append(visitor_id)

	if GameState.answers_today >= 5:
		day_complete.emit()


## Defers a visitor -- resets the index so they can appear again.
func defer_visitor(_visitor_id: String) -> void:
	# Simply decrement the index so the visitor can be picked up again
	if current_visitor_index > 0:
		current_visitor_index -= 1


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _find_visitor(visitor_id: String) -> Dictionary:
	for v in today_visitors:
		if v.get("id", "") == visitor_id:
			return v
	return {}


func _find_answer(visitor: Dictionary, answer_id: String) -> Dictionary:
	var answers: Array = visitor.get("answers", [])
	for a in answers:
		if a is Dictionary and a.get("id", "") == answer_id:
			return a
	return {}
