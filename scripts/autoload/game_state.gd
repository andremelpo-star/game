extends Node

## Current game day, starts at 1
var current_day: int = 1

## How many answers given today (day ends at 5)
var answers_today: int = 0

## Knowledge keys obtained from reading books
## Example: ["iron_king_mercy", "herb_guide_poisons"]
var knowledge_keys: Array[String] = []

## City state -- 4 parameters from 0 to 100
var city_stats: Dictionary = {
	"trust": 50,
	"prosperity": 50,
	"safety": 50,
	"morale": 50
}

## IDs of visitors already answered
var completed_visitors: Array[String] = []

## Deferred consequences that trigger on future days
## Format: { "event_id": String, "trigger_day": int, "applied": bool }
var pending_consequences: Array[Dictionary] = []

## Planned visitor returns
## Format: { "visitor_id": String, "visitor_name": String, "return_day": int,
##           "return_text": String, "return_city_effect": Dictionary, "shown": bool }
var pending_returns: Array[Dictionary] = []

## IDs of books already read
var read_books: Array[String] = []

## How many NEW books read today (resets each day; re-reads are free)
var books_read_today: int = 0

## Maximum new books the sage can read in a single day
const MAX_BOOKS_PER_DAY: int = 3

## Story flags -- simple booleans set by YAML presets to gate content
var story_flags: Array[String] = []

## Visitors injected into future days by preset directives
## Keyed by day number (int), value is Array of visitor ID strings
var injected_visitors: Dictionary = {}

## Visitor IDs that should be skipped (removed by preset directives)
var removed_visitors: Array[String] = []

## Visitor swaps: Array of { "original": String, "replacement": String, "day": int }
var swapped_visitors: Array[Dictionary] = []

const SAVE_PATH: String = "user://savegame.json"


## Adds knowledge keys, ignoring duplicates.
func add_knowledge(keys: Array[String]) -> void:
	for key in keys:
		if key not in knowledge_keys:
			knowledge_keys.append(key)


## Returns true if the sage can still read a new (unread) book today.
func can_read_new_book() -> bool:
	return books_read_today < MAX_BOOKS_PER_DAY


## Returns true if the key exists in knowledge_keys.
func has_knowledge(key: String) -> bool:
	return key in knowledge_keys


## Returns true if ALL provided keys exist in knowledge_keys.
func has_all_knowledge(keys: Array[String]) -> bool:
	for key in keys:
		if key not in knowledge_keys:
			return false
	return true


## Modifies a city stat. Result is clamped to 0-100.
func modify_city_stat(stat_name: String, amount: int) -> void:
	if stat_name not in city_stats:
		print_debug("GameState: Unknown city stat '%s'" % stat_name)
		return
	city_stats[stat_name] = clampi(city_stats[stat_name] + amount, 0, 100)


## Marks a book as read if not already.
func mark_book_read(book_id: String) -> void:
	if book_id not in read_books:
		read_books.append(book_id)


## Checks whether a book has been read.
func is_book_read(book_id: String) -> bool:
	return book_id in read_books


# ---------------------------------------------------------------------------
# Story flags
# ---------------------------------------------------------------------------

## Sets a story flag if not already present.
func set_flag(flag: String) -> void:
	if flag not in story_flags:
		story_flags.append(flag)


## Removes a story flag.
func remove_flag(flag: String) -> void:
	story_flags.erase(flag)


## Returns true if the flag exists.
func has_flag(flag: String) -> bool:
	return flag in story_flags


## Returns true if ALL provided flags exist.
func has_all_flags(flags: Array) -> bool:
	for f in flags:
		if str(f) not in story_flags:
			return false
	return true


## Returns true if ANY of the provided flags exist.
func has_any_flags(flags: Array) -> bool:
	for f in flags:
		if str(f) in story_flags:
			return true
	return false


# ---------------------------------------------------------------------------
# Injected / removed / swapped visitors
# ---------------------------------------------------------------------------

## Injects a visitor ID to appear on a specific future day.
func inject_visitor(visitor_id: String, day: int) -> void:
	var day_key: String = str(day)
	if not injected_visitors.has(day_key):
		injected_visitors[day_key] = []
	if visitor_id not in injected_visitors[day_key]:
		injected_visitors[day_key].append(visitor_id)


## Returns injected visitor IDs for a given day.
func get_injected_visitors(day: int) -> Array:
	var day_key: String = str(day)
	return injected_visitors.get(day_key, [])


## Marks a visitor ID to be removed (skipped) from any future day.
func remove_visitor(visitor_id: String) -> void:
	if visitor_id not in removed_visitors:
		removed_visitors.append(visitor_id)


## Returns true if a visitor has been removed.
func is_visitor_removed(visitor_id: String) -> bool:
	return visitor_id in removed_visitors


## Registers a visitor swap for a specific day.
func swap_visitor(original_id: String, replacement_id: String, day: int) -> void:
	swapped_visitors.append({
		"original": original_id,
		"replacement": replacement_id,
		"day": day
	})


## Returns the replacement visitor ID if a swap exists for this visitor on this day.
## Returns empty string if no swap found.
func get_swap_replacement(visitor_id: String, day: int) -> String:
	for swap in swapped_visitors:
		if swap.get("original", "") == visitor_id and int(swap.get("day", 0)) == day:
			return str(swap.get("replacement", ""))
	return ""


## Adds a consequence entry to pending_consequences.
func add_consequence(event_id: String, trigger_day: int) -> void:
	pending_consequences.append({
		"event_id": event_id,
		"trigger_day": trigger_day,
		"applied": false
	})


## Returns consequences where trigger_day <= current_day and applied == false.
func get_active_consequences() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in pending_consequences:
		if c["trigger_day"] <= current_day and not c["applied"]:
			result.append(c)
	return result


## Marks a consequence as applied.
func mark_consequence_applied(event_id: String) -> void:
	for c in pending_consequences:
		if c["event_id"] == event_id:
			c["applied"] = true
			return


## Resets daily counters to 0. Does NOT reset other data.
func reset_for_new_day() -> void:
	answers_today = 0
	books_read_today = 0


## Serializes ALL state variables to JSON and writes to savegame.json.
func save_game() -> void:
	var data: Dictionary = {
		"current_day": current_day,
		"answers_today": answers_today,
		"books_read_today": books_read_today,
		"knowledge_keys": knowledge_keys,
		"city_stats": city_stats,
		"completed_visitors": completed_visitors,
		"pending_consequences": pending_consequences,
		"pending_returns": pending_returns,
		"read_books": read_books,
		"story_flags": story_flags,
		"injected_visitors": injected_visitors,
		"removed_visitors": removed_visitors,
		"swapped_visitors": swapped_visitors
	}
	var json_string: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		print_debug("GameState: Failed to open save file for writing")


## Loads state from savegame.json. Returns true on success, false otherwise.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		print_debug("GameState: Failed to parse save file")
		return false

	var data: Dictionary = json.data
	current_day = data.get("current_day", 1)
	answers_today = data.get("answers_today", 0)
	books_read_today = data.get("books_read_today", 0)

	knowledge_keys.clear()
	for key in data.get("knowledge_keys", []):
		knowledge_keys.append(key)

	city_stats = data.get("city_stats", {
		"trust": 50, "prosperity": 50, "safety": 50, "morale": 50
	})

	completed_visitors.clear()
	for v in data.get("completed_visitors", []):
		completed_visitors.append(v)

	pending_consequences.clear()
	for c in data.get("pending_consequences", []):
		pending_consequences.append(c)

	pending_returns.clear()
	for r in data.get("pending_returns", []):
		pending_returns.append(r)

	read_books.clear()
	for b in data.get("read_books", []):
		read_books.append(b)

	story_flags.clear()
	for f in data.get("story_flags", []):
		story_flags.append(f)

	injected_visitors = data.get("injected_visitors", {})

	removed_visitors.clear()
	for rv in data.get("removed_visitors", []):
		removed_visitors.append(rv)

	swapped_visitors.clear()
	for sv in data.get("swapped_visitors", []):
		swapped_visitors.append(sv)

	return true


## Checks if a save file exists.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Resets ALL variables to initial values.
func new_game() -> void:
	current_day = 1
	answers_today = 0
	books_read_today = 0
	knowledge_keys.clear()
	city_stats = {
		"trust": 50,
		"prosperity": 50,
		"safety": 50,
		"morale": 50
	}
	completed_visitors.clear()
	pending_consequences.clear()
	pending_returns.clear()
	read_books.clear()
	story_flags.clear()
	injected_visitors.clear()
	removed_visitors.clear()
	swapped_visitors.clear()
