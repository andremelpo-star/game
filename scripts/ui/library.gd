extends Node2D

signal day_complete
signal city_walk_requested

# --- HUD elements (on CanvasLayer) ---
@onready var day_label: Label = %DayLabel
@onready var answers_label: Label = %AnswersLabel
@onready var trust_progress: ProgressBar = %TrustProgress
@onready var prosperity_progress: ProgressBar = %ProsperityProgress
@onready var safety_progress: ProgressBar = %SafetyProgress
@onready var morale_progress: ProgressBar = %MoraleProgress
@onready var hint_label: Label = %HintLabel
@onready var status_bubble: PanelContainer = %StatusBubble
@onready var status_bubble_label: Label = %StatusBubbleLabel

# --- Overlays (on CanvasLayer) ---
@onready var shelf_overlay: PanelContainer = %ShelfOverlay
@onready var book_reader_overlay: Control = %BookReaderOverlay
@onready var visitor_overlay: Control = %VisitorOverlay

# --- Interactive zones ---
@onready var shelf_fiction: Area2D = $InteractiveZones/ShelfFiction
@onready var shelf_practical: Area2D = $InteractiveZones/ShelfPractical
@onready var shelf_rare: Area2D = $InteractiveZones/ShelfRare
@onready var desk_zone: Area2D = $InteractiveZones/DeskZone
@onready var door_zone: Area2D = $InteractiveZones/DoorZone

# --- Character sprites ---
@onready var visitor_sprite: ColorRect = $Characters/VisitorSprite

# --- State ---
var _is_animating: bool = false

# --- Touch / long-press support ---
var _touch_timer: Timer
var _touch_zone: Area2D = null

# Door position (where visitors enter/exit)
const DOOR_POS := Vector2(960, 900)
# Desk position (where visitors stand to talk)
const DESK_POS := Vector2(1300, 500)

# Zone hint texts
const ZONE_HINTS: Dictionary = {
	"ShelfFiction": "Fiction shelf -- click to browse",
	"ShelfPractical": "Practical knowledge -- click to browse",
	"ShelfRare": "Rare books -- click to browse",
	"DeskZone": "Desk -- receive a visitor",
	"DoorZone": "Door -- go to the city",
}


func _ready() -> void:
	# Connect Area2D signals for all interactive zones
	var zones: Array[Area2D] = [shelf_fiction, shelf_practical, shelf_rare, desk_zone, door_zone]
	for zone in zones:
		zone.mouse_entered.connect(_on_zone_hover.bind(zone))
		zone.mouse_exited.connect(_on_zone_unhover.bind(zone))
		zone.input_event.connect(_on_zone_input_event.bind(zone))

	# Connect overlay signals
	shelf_overlay.book_selected.connect(_on_book_selected)
	book_reader_overlay.book_closed.connect(_on_book_closed)
	visitor_overlay.answer_submitted.connect(_on_answer_submitted)
	visitor_overlay.visitor_deferred.connect(_on_visitor_deferred)
	visitor_overlay.return_acknowledged.connect(_on_return_acknowledged)
	visitor_overlay.dialogue_finished.connect(_on_dialogue_finished)

	# Connect day_complete from VisitorManager to transition to day summary
	VisitorManager.day_complete.connect(_on_visitor_manager_day_complete)

	# Connect ending signal from DayCycle
	DayCycle.ending_triggered.connect(_on_ending_triggered)

	# Initialize day
	VisitorManager.start_day(GameState.current_day)

	# Initial UI state
	visitor_sprite.visible = false
	status_bubble.visible = false
	hint_label.text = "Click on a shelf, desk, or door"

	_update_hud()
	_update_status_bubble()

	# Setup long-press timer for mobile touch tooltip support
	_setup_touch_tooltip()

	# Play ambient music if available
	AudioManager.play_music("res://assets/audio/library_ambient.ogg")

	# Check returning visitors after a short delay (let the scene load first)
	await get_tree().create_timer(0.5).timeout
	_check_returning_visitors()


# ---------------------------------------------------------------------------
# Zone interaction
# ---------------------------------------------------------------------------

func _on_zone_hover(zone: Area2D) -> void:
	if _is_animating:
		return
	var highlight: ColorRect = zone.get_node("Highlight")
	if highlight:
		highlight.visible = true
	hint_label.text = ZONE_HINTS.get(zone.name, "")


func _on_zone_unhover(zone: Area2D) -> void:
	var highlight: ColorRect = zone.get_node("Highlight")
	if highlight:
		highlight.visible = false
	if not _is_animating:
		hint_label.text = "Click on a shelf, desk, or door"


func _on_zone_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, zone: Area2D) -> void:
	if _is_animating:
		return

	# Handle mouse click
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_handle_zone_click(zone)
		return

	# Handle touch for long-press tooltips
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_on_zone_touch_start(zone)
		else:
			_on_zone_touch_end()
			_handle_zone_click(zone)


func _handle_zone_click(zone: Area2D) -> void:
	AudioManager.play_sfx("click")

	match zone.name:
		"ShelfFiction":
			shelf_overlay.open_shelf("fiction")
		"ShelfPractical":
			shelf_overlay.open_shelf("practical")
		"ShelfRare":
			shelf_overlay.open_shelf("rare")
		"DeskZone":
			_on_desk_clicked()
		"DoorZone":
			AudioManager.play_sfx("door")
			SceneTransition.change_scene("res://scenes/city/city_walk.tscn")


# ---------------------------------------------------------------------------
# Touch / long-press support (mobile)
# ---------------------------------------------------------------------------

func _setup_touch_tooltip() -> void:
	_touch_timer = Timer.new()
	_touch_timer.one_shot = true
	_touch_timer.wait_time = 0.5
	_touch_timer.timeout.connect(_on_long_press)
	add_child(_touch_timer)


func _on_zone_touch_start(zone: Area2D) -> void:
	_touch_zone = zone
	_touch_timer.start()


func _on_zone_touch_end() -> void:
	_touch_timer.stop()
	_touch_zone = null


func _on_long_press() -> void:
	if _touch_zone:
		hint_label.text = ZONE_HINTS.get(_touch_zone.name, "")


# ---------------------------------------------------------------------------
# Desk / Visitor logic
# ---------------------------------------------------------------------------

func _on_desk_clicked() -> void:
	if GameState.answers_today >= 5:
		hint_label.text = "All visitors received for today."
		return

	var visitor: Variant = VisitorManager.get_next_visitor()
	if visitor == null:
		hint_label.text = "No visitors in the queue."
		return

	# Animate visitor entering, then show dialogue or question
	AudioManager.play_sfx("footsteps")
	await _animate_visitor_enter()

	var dialogue: Array = visitor.get("dialogue", [])
	if dialogue.size() > 0:
		visitor_overlay.show_dialogue(visitor)
	else:
		visitor_overlay.show_visitor(visitor)


func _animate_visitor_enter() -> void:
	_is_animating = true
	visitor_sprite.visible = true
	visitor_sprite.position = DOOR_POS
	visitor_sprite.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visitor_sprite, "position", DESK_POS, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visitor_sprite, "modulate:a", 1.0, 0.4)
	await tween.finished

	_is_animating = false


func _animate_visitor_exit() -> void:
	_is_animating = true
	AudioManager.play_sfx("footsteps")

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visitor_sprite, "position", DOOR_POS, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visitor_sprite, "modulate:a", 0.0, 0.4).set_delay(0.2)
	await tween.finished

	visitor_sprite.visible = false
	_is_animating = false


# ---------------------------------------------------------------------------
# Returning visitors
# ---------------------------------------------------------------------------

func _check_returning_visitors() -> void:
	var returns: Array[Dictionary] = VisitorManager.get_returning_visitors(GameState.current_day)
	if returns.size() > 0:
		_show_return_dialogue(returns[0])


func _show_return_dialogue(entry: Dictionary) -> void:
	AudioManager.play_sfx("footsteps")
	await _animate_visitor_enter()
	visitor_overlay.show_return(entry)


func _on_return_acknowledged(_visitor_id: String) -> void:
	await _animate_visitor_exit()
	_update_hud()
	# Check if there are more returning visitors
	var returns := VisitorManager.get_returning_visitors(GameState.current_day)
	if returns.size() > 0:
		await get_tree().create_timer(0.3).timeout
		_show_return_dialogue(returns[0])


func _on_dialogue_finished(visitor_id: String) -> void:
	# After dialogue ends, show the visitor's question with answer options
	var visitor: Variant = null
	for v in VisitorManager.today_visitors:
		if v.get("id", "") == visitor_id:
			visitor = v
			break
	if visitor != null:
		visitor_overlay.show_visitor(visitor)


# ---------------------------------------------------------------------------
# Overlay callbacks
# ---------------------------------------------------------------------------

func _on_book_selected(book_id: String) -> void:
	shelf_overlay.visible = false
	book_reader_overlay.open_book(book_id)


func _on_book_closed() -> void:
	_update_hud()


func _on_answer_submitted(visitor_id: String, answer_id: String) -> void:
	VisitorManager.submit_answer(visitor_id, answer_id)

	# Animate visitor leaving
	await _animate_visitor_exit()

	_update_hud()
	_update_status_bubble()

	if GameState.answers_today >= 5:
		hint_label.text = "All visitors received for today."


func _on_visitor_deferred(_visitor_id: String) -> void:
	await _animate_visitor_exit()
	_update_status_bubble()


# ---------------------------------------------------------------------------
# HUD updates
# ---------------------------------------------------------------------------

func _update_hud() -> void:
	day_label.text = "Day %d" % GameState.current_day
	answers_label.text = "Answers: %d/5" % GameState.answers_today

	_update_progress_bar(trust_progress, GameState.city_stats.get("trust", 50), "Trust")
	_update_progress_bar(prosperity_progress, GameState.city_stats.get("prosperity", 50), "Prosperity")
	_update_progress_bar(safety_progress, GameState.city_stats.get("safety", 50), "Safety")
	_update_progress_bar(morale_progress, GameState.city_stats.get("morale", 50), "Morale")

	_update_desk_indicator()


func _update_progress_bar(bar: ProgressBar, value: int, stat_name: String) -> void:
	# Animate value change
	var tween := create_tween()
	tween.tween_property(bar, "value", float(value), 0.5).set_trans(Tween.TRANS_QUAD)

	# Update color based on value
	var color: Color
	if value > 60:
		color = Color("#4CAF50")
	elif value >= 30:
		color = Color("#FFC107")
	else:
		color = Color("#F44336")

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", style)

	# Update tooltip
	bar.tooltip_text = "%s: %d/100" % [stat_name, value]


func _update_status_bubble() -> void:
	var count: int = VisitorManager.get_remaining_count()
	if count > 0:
		status_bubble.visible = true
		status_bubble_label.text = "Waiting: %d" % count
	else:
		status_bubble.visible = false


## Shows a blinking indicator on the desk when visitors are available
func _update_desk_indicator() -> void:
	var desk_highlight: ColorRect = desk_zone.get_node_or_null("Highlight")
	if desk_highlight == null:
		return

	var has_visitors: bool = VisitorManager.get_remaining_count() > 0 and GameState.answers_today < 5
	if has_visitors:
		desk_highlight.visible = true
		desk_highlight.color = Color(1.0, 0.85, 0.0, 0.2)
		# Pulse animation
		var tween := create_tween().set_loops()
		tween.tween_property(desk_highlight, "color:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
		tween.tween_property(desk_highlight, "color:a", 0.1, 0.8).set_trans(Tween.TRANS_SINE)
	else:
		desk_highlight.visible = false


# ---------------------------------------------------------------------------
# Day cycle integration
# ---------------------------------------------------------------------------

func _on_visitor_manager_day_complete() -> void:
	# Transition to day summary screen
	SceneTransition.change_scene("res://scenes/main/day_summary.tscn")


func _on_ending_triggered(ending_id: String) -> void:
	GameState.set_meta("current_ending", ending_id)
	SceneTransition.change_scene("res://scenes/main/ending_scene.tscn")
