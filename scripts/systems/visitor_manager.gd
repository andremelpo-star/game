extends Node

signal day_complete

var today_visitors: Array[Dictionary] = []
var current_visitor_index: int = 0


## Loads visitors for the given day, merges injected visitors, applies swaps,
## removes flagged visitors, and filters by condition flags.
func start_day(day: int) -> void:
	today_visitors = ContentLoader.load_visitors_for_day(day)
	current_visitor_index = 0

	# Merge injected visitors for this day
	var injected_ids: Array = GameState.get_injected_visitors(day)
	for vid in injected_ids:
		# Check if this visitor already exists in today's list
		var already_present: bool = false
		for v in today_visitors:
			if v.get("id", "") == str(vid):
				already_present = true
				break
		if not already_present:
			# Try to find the visitor definition in day files or conditional file
			var injected_visitor: Dictionary = ContentLoader.load_visitor_by_id(str(vid), day)
			if not injected_visitor.is_empty():
				today_visitors.append(injected_visitor)

	# Apply visitor swaps
	for i in range(today_visitors.size()):
		var v_id: String = today_visitors[i].get("id", "")
		var replacement_id: String = GameState.get_swap_replacement(v_id, day)
		if replacement_id != "":
			var replacement: Dictionary = ContentLoader.load_visitor_by_id(replacement_id, day)
			if not replacement.is_empty():
				today_visitors[i] = replacement

	# Filter out removed visitors, already completed, and condition-gated visitors
	var filtered: Array[Dictionary] = []
	for v in today_visitors:
		var vid: String = v.get("id", "")

		# Skip removed visitors
		if GameState.is_visitor_removed(vid):
			continue

		# Skip already answered visitors
		if vid in GameState.completed_visitors:
			continue

		# Check condition flags if present
		if not _check_visitor_conditions(v):
			continue

		filtered.append(v)
	today_visitors = filtered


## Checks whether a visitor's condition (require_flags / forbid_flags) is met.
## Returns true if the visitor should be shown, false if it should be hidden.
func _check_visitor_conditions(visitor: Dictionary) -> bool:
	var condition: Variant = visitor.get("condition", null)
	if condition == null or not condition is Dictionary:
		return true

	# Check require_flags -- all must be present
	var require_flags: Variant = condition.get("require_flags", null)
	if require_flags is Array and require_flags.size() > 0:
		if not GameState.has_all_flags(require_flags):
			return false

	# Check forbid_flags -- none must be present
	var forbid_flags: Variant = condition.get("forbid_flags", null)
	if forbid_flags is Array and forbid_flags.size() > 0:
		if GameState.has_any_flags(forbid_flags):
			return false

	return true


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

	# Schedule return if applicable
	schedule_return(visitor, answer)

	# Process YAML preset directives (set_flags, inject_visitors, etc.)
	PresetProcessor.apply_presets(answer)

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
# Returning visitors
# ---------------------------------------------------------------------------

## Schedules a visitor to return on a future day if the answer has return fields.
func schedule_return(visitor: Dictionary, answer: Dictionary) -> void:
	var return_day_offset: int = int(answer.get("return_day", 0))
	if return_day_offset <= 0 or not answer.has("return_text"):
		return

	var return_day: int = GameState.current_day + return_day_offset
	var entry: Dictionary = {
		"visitor_id": visitor.get("id", ""),
		"visitor_name": visitor.get("name", "Unknown"),
		"return_day": return_day,
		"return_text": str(answer.get("return_text", "")),
		"return_city_effect": answer.get("return_city_effect", {}),
		"shown": false
	}
	GameState.pending_returns.append(entry)


## Returns all visitors scheduled to return on the given day that have not been shown yet.
func get_returning_visitors(day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in GameState.pending_returns:
		if entry.get("return_day", 0) == day and not entry.get("shown", false):
			result.append(entry)
	return result


## Marks a returning visitor entry as shown so it is not displayed again.
func mark_return_shown(visitor_id: String) -> void:
	for entry in GameState.pending_returns:
		if entry.get("visitor_id", "") == visitor_id:
			entry["shown"] = true


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
