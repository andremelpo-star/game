extends Node

## Shared utility that processes YAML preset directives from answer data or
## consequence data. Called by both VisitorManager.submit_answer() and
## ConsequenceEngine.apply_consequence() to avoid duplication.
##
## Supported preset keys:
##   set_flags:        Array[String]   -- flags to add to GameState.story_flags
##   remove_flags:     Array[String]   -- flags to remove
##   inject_visitors:  Array[Dict]     -- { visitor_id, day } to add to future days
##   remove_visitors:  Array[String]   -- visitor IDs to skip on future days
##   swap_visitors:    Array[Dict]     -- { original, replacement, day }
##   add_consequence:  Array[Dict]     -- { event_id, delay } to schedule


## Processes all preset directives found in the given data dictionary.
func apply_presets(data: Dictionary) -> void:
	_process_set_flags(data)
	_process_remove_flags(data)
	_process_inject_visitors(data)
	_process_remove_visitors(data)
	_process_swap_visitors(data)
	_process_add_consequence(data)


# ---------------------------------------------------------------------------
# Individual preset processors
# ---------------------------------------------------------------------------

func _process_set_flags(data: Dictionary) -> void:
	var flags: Variant = data.get("set_flags", null)
	if flags == null:
		return
	if flags is Array:
		for flag in flags:
			GameState.set_flag(str(flag))


func _process_remove_flags(data: Dictionary) -> void:
	var flags: Variant = data.get("remove_flags", null)
	if flags == null:
		return
	if flags is Array:
		for flag in flags:
			GameState.remove_flag(str(flag))


func _process_inject_visitors(data: Dictionary) -> void:
	var entries: Variant = data.get("inject_visitors", null)
	if entries == null:
		return
	if entries is Array:
		for entry in entries:
			if entry is Dictionary:
				var visitor_id: String = str(entry.get("visitor_id", ""))
				var day: int = int(entry.get("day", 0))
				if visitor_id != "" and day > 0:
					GameState.inject_visitor(visitor_id, day)


func _process_remove_visitors(data: Dictionary) -> void:
	var entries: Variant = data.get("remove_visitors", null)
	if entries == null:
		return
	if entries is Array:
		for entry in entries:
			# Can be a string ID or a dict with visitor_id
			if entry is Dictionary:
				var vid: String = str(entry.get("visitor_id", ""))
				if vid != "":
					GameState.remove_visitor(vid)
			else:
				var vid: String = str(entry)
				if vid != "":
					GameState.remove_visitor(vid)


func _process_swap_visitors(data: Dictionary) -> void:
	var entries: Variant = data.get("swap_visitors", null)
	if entries == null:
		return
	if entries is Array:
		for entry in entries:
			if entry is Dictionary:
				var original: String = str(entry.get("original", ""))
				var replacement: String = str(entry.get("replacement", ""))
				var day: int = int(entry.get("day", 0))
				if original != "" and replacement != "" and day > 0:
					GameState.swap_visitor(original, replacement, day)


func _process_add_consequence(data: Dictionary) -> void:
	var entries: Variant = data.get("add_consequence", null)
	if entries == null:
		return
	if entries is Array:
		for entry in entries:
			if entry is Dictionary:
				var event_id: String = str(entry.get("event_id", ""))
				var delay: int = int(entry.get("delay", 1))
				if event_id != "":
					var trigger_day: int = GameState.current_day + delay
					GameState.add_consequence(event_id, trigger_day)
