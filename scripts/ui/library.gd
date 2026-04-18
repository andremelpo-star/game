extends Node2D

signal day_complete

# --- Overlays (on CanvasLayer) ---
@onready var hint_label: Label = %HintLabel
@onready var shelf_overlay: PanelContainer = %ShelfOverlay
@onready var book_reader_overlay: Control = %BookReaderOverlay
@onready var visitor_overlay: Control = %VisitorOverlay

# --- Interactive zones ---
@onready var shelf_fiction: Area2D = $InteractiveZones/ShelfFiction
@onready var shelf_practical: Area2D = $InteractiveZones/ShelfPractical
@onready var shelf_rare: Area2D = $InteractiveZones/ShelfRare
@onready var desk_zone: Area2D = $InteractiveZones/DeskZone

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
}

# In-world messages shown when the sage is too tired to read more
const READING_EXHAUSTED_MESSAGES: Array = [
	"Голова раскалывается. Ещё одну книгу сегодня не осилю.",
	"Строчки расплываются перед глазами. Хватит на сегодня.",
	"Нет, нужно дать голове отдохнуть. Завтра продолжу.",
]


func _ready() -> void:
	# Connect Area2D signals for all interactive zones
	var zones: Array[Area2D] = [shelf_fiction, shelf_practical, shelf_rare, desk_zone]
	for zone in zones:
		zone.mouse_entered.connect(_on_zone_hover.bind(zone))
		zone.mouse_exited.connect(_on_zone_unhover.bind(zone))
		zone.input_event.connect(_on_zone_input_event.bind(zone))

	# Connect overlay signals
	shelf_overlay.book_selected.connect(_on_book_selected)
	shelf_overlay.reading_exhausted.connect(_on_reading_exhausted)
	book_reader_overlay.book_closed.connect(_on_book_closed)
	visitor_overlay.answer_submitted.connect(_on_answer_submitted)
	visitor_overlay.visitor_deferred.connect(_on_visitor_deferred)
	visitor_overlay.return_acknowledged.connect(_on_return_acknowledged)
	visitor_overlay.dialogue_finished.connect(_on_dialogue_finished)

	# Connect day_complete from VisitorManager to transition to evening walk
	VisitorManager.day_complete.connect(_on_visitor_manager_day_complete)

	# Connect ending signal from DayCycle
	DayCycle.ending_triggered.connect(_on_ending_triggered)

	# Initialize day
	VisitorManager.start_day(GameState.current_day)

	# Initial UI state
	visitor_sprite.visible = false
	hint_label.text = "Click on a shelf or desk"

	_update_desk_indicator()

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
		hint_label.text = "Click on a shelf or desk"


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
	if GameState.answers_today >= VisitorManager.max_visitors_today:
		hint_label.text = "Тишина. Сегодня больше никто не придёт."
		return

	var visitor: Variant = VisitorManager.get_next_visitor()
	if visitor == null:
		hint_label.text = "Никого нет в очереди."
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
	_update_desk_indicator()


func _on_reading_exhausted() -> void:
	var msg: String = READING_EXHAUSTED_MESSAGES[randi() % READING_EXHAUSTED_MESSAGES.size()]
	hint_label.text = msg


func _on_answer_submitted(visitor_id: String, answer_id: String) -> void:
	VisitorManager.submit_answer(visitor_id, answer_id)

	# Animate visitor leaving
	await _animate_visitor_exit()

	_update_desk_indicator()

	if GameState.answers_today >= VisitorManager.max_visitors_today:
		hint_label.text = "Тишина. Сегодня больше никто не придёт."


func _on_visitor_deferred(_visitor_id: String) -> void:
	await _animate_visitor_exit()


# ---------------------------------------------------------------------------
# Desk indicator (no HUD -- just subtle highlight when visitors are waiting)
# ---------------------------------------------------------------------------

## Shows a blinking indicator on the desk when visitors are available
func _update_desk_indicator() -> void:
	var desk_highlight: ColorRect = desk_zone.get_node_or_null("Highlight")
	if desk_highlight == null:
		return

	var has_visitors: bool = VisitorManager.get_remaining_count() > 0 and GameState.answers_today < VisitorManager.max_visitors_today
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
	# Transition directly to evening walk (no day_summary screen)
	SceneTransition.change_scene("res://scenes/city/evening_walk.tscn")


func _on_ending_triggered(ending_id: String) -> void:
	GameState.set_meta("current_ending", ending_id)
	SceneTransition.change_scene("res://scenes/main/ending_scene.tscn")
