extends Control

## Evening walk scene -- displays YAML-driven narrative entries at the end of
## each day.  Entries are filtered by story flags (require_flags / forbid_flags).
## After all entries are shown, the next day begins automatically.

@onready var narration_label: RichTextLabel = %NarrationLabel
@onready var speaker_label: Label = %SpeakerLabel
@onready var btn_continue: Button = %BtnContinue

var _entries: Array[Dictionary] = []
var _current_entry_index: int = 0
## For dialogue entries, tracks the current line within the entry
var _current_line_index: int = 0
## True when we are stepping through dialogue lines inside a single entry
var _in_dialogue: bool = false


func _ready() -> void:
	btn_continue.pressed.connect(_on_continue)

	# Load and filter walk entries for the current day
	var raw_entries: Array[Dictionary] = ContentLoader.load_walk_entries(GameState.current_day)
	_entries = _filter_entries(raw_entries)

	speaker_label.text = ""

	if _entries.size() == 0:
		# No walk content for this day -- show a brief default text then advance
		narration_label.text = "Вечер. Город спокоен. Мудрец возвращается домой."
		btn_continue.text = "Следующий день"
	else:
		_show_entry(0)


# ---------------------------------------------------------------------------
# Entry filtering
# ---------------------------------------------------------------------------

## Returns only entries whose conditions are met by current GameState flags.
func _filter_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		if _check_condition(entry):
			result.append(entry)
	return result


func _check_condition(entry: Dictionary) -> bool:
	var condition: Variant = entry.get("condition", null)
	if condition == null or not condition is Dictionary:
		return true  # no condition = always show

	var require_flags: Variant = condition.get("require_flags", null)
	if require_flags is Array and require_flags.size() > 0:
		if not GameState.has_all_flags(require_flags):
			return false

	var forbid_flags: Variant = condition.get("forbid_flags", null)
	if forbid_flags is Array and forbid_flags.size() > 0:
		if GameState.has_any_flags(forbid_flags):
			return false

	return true


# ---------------------------------------------------------------------------
# Display logic
# ---------------------------------------------------------------------------

func _show_entry(index: int) -> void:
	if index >= _entries.size():
		_finish_walk()
		return

	_current_entry_index = index
	_current_line_index = 0
	_in_dialogue = false

	var entry: Dictionary = _entries[index]
	var entry_type: String = str(entry.get("type", "narration"))

	match entry_type:
		"narration":
			_show_narration(entry)
		"dialogue":
			_show_dialogue_line(entry)
		"scene":
			_show_scene(entry)
		_:
			_show_narration(entry)


func _show_narration(entry: Dictionary) -> void:
	speaker_label.text = ""
	narration_label.text = str(entry.get("text", ""))
	btn_continue.text = "Далее"


func _show_dialogue_line(entry: Dictionary) -> void:
	_in_dialogue = true
	var lines: Array = entry.get("lines", [])
	if _current_line_index >= lines.size():
		# All dialogue lines shown, move to next entry
		_in_dialogue = false
		_show_entry(_current_entry_index + 1)
		return

	var line: Dictionary = lines[_current_line_index] if lines[_current_line_index] is Dictionary else {}
	speaker_label.text = str(line.get("speaker", ""))
	narration_label.text = str(line.get("text", ""))
	btn_continue.text = "Далее"


func _show_scene(entry: Dictionary) -> void:
	# First show the descriptive text
	speaker_label.text = ""
	narration_label.text = str(entry.get("text", ""))

	# If there is an NPC line, we show it on the next click
	var npc_line: String = str(entry.get("npc_line", ""))
	if npc_line != "":
		_in_dialogue = true  # reuse dialogue stepping for the NPC reply
		_current_line_index = 0
	btn_continue.text = "Далее"


# ---------------------------------------------------------------------------
# Continue button
# ---------------------------------------------------------------------------

func _on_continue() -> void:
	AudioManager.play_sfx("click")

	# If we have no entries, just finish
	if _entries.size() == 0:
		_finish_walk()
		return

	var entry: Dictionary = _entries[_current_entry_index]
	var entry_type: String = str(entry.get("type", "narration"))

	if entry_type == "dialogue" and _in_dialogue:
		_current_line_index += 1
		_show_dialogue_line(entry)
		return

	if entry_type == "scene" and _in_dialogue:
		# Show NPC line after the scene description
		var npc_name: String = str(entry.get("npc_name", ""))
		var npc_line: String = str(entry.get("npc_line", ""))
		speaker_label.text = npc_name
		narration_label.text = npc_line
		_in_dialogue = false
		return

	# Move to next entry
	_show_entry(_current_entry_index + 1)


# ---------------------------------------------------------------------------
# Finish walk and advance day
# ---------------------------------------------------------------------------

func _finish_walk() -> void:
	# Apply all active consequences (flag type and any others) at end of walk
	var active: Array[Dictionary] = ConsequenceEngine.get_active_consequences(GameState.current_day)
	for event in active:
		var event_id: String = event.get("event_id", event.get("id", ""))
		if event_id != "":
			ConsequenceEngine.apply_consequence(event_id)

	DayCycle.start_new_day()

	# Check if an ending was triggered
	var ending: String = DayCycle.check_endings()
	if ending != "":
		GameState.set_meta("current_ending", ending)
		SceneTransition.change_scene("res://scenes/main/ending_scene.tscn")
	else:
		SceneTransition.change_scene("res://scenes/library/library.tscn")
