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

# Door position (where visitors enter/exit)
const DOOR_POS := Vector2(960, 900)
# Desk position (where visitors stand to talk)
const DESK_POS := Vector2(1300, 500)

# Zone hint texts
const ZONE_HINTS: Dictionary = {
	"ShelfFiction": "Художественная литература -- кликните, чтобы открыть",
	"ShelfPractical": "Прикладные знания -- кликните, чтобы открыть",
	"ShelfRare": "Редкие книги -- кликните, чтобы открыть",
	"DeskZone": "Рабочий стол -- принять посетителя",
	"DoorZone": "Дверь -- выйти в город",
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

	# Connect day_complete from VisitorManager to transition to day summary
	VisitorManager.day_complete.connect(_on_visitor_manager_day_complete)

	# Connect ending signal from DayCycle
	DayCycle.ending_triggered.connect(_on_ending_triggered)

	# Initialize day
	VisitorManager.start_day(GameState.current_day)

	# Initial UI state
	visitor_sprite.visible = false
	status_bubble.visible = false
	hint_label.text = "Кликните на полку, стол или дверь"

	_update_hud()
	_update_status_bubble()


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
		hint_label.text = "Кликните на полку, стол или дверь"


func _on_zone_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, zone: Area2D) -> void:
	if _is_animating:
		return
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

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
			get_tree().change_scene_to_file("res://scenes/city/city_walk.tscn")


# ---------------------------------------------------------------------------
# Desk / Visitor logic
# ---------------------------------------------------------------------------

func _on_desk_clicked() -> void:
	if GameState.answers_today >= 5:
		hint_label.text = "Все посетители на сегодня приняты."
		return

	var visitor: Variant = VisitorManager.get_next_visitor()
	if visitor == null:
		hint_label.text = "Нет посетителей в очереди."
		return

	# Animate visitor entering, then show the dialog
	await _animate_visitor_enter()
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

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visitor_sprite, "position", DOOR_POS, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visitor_sprite, "modulate:a", 0.0, 0.4).set_delay(0.2)
	await tween.finished

	visitor_sprite.visible = false
	_is_animating = false


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
		hint_label.text = "Все посетители на сегодня приняты."


func _on_visitor_deferred(_visitor_id: String) -> void:
	await _animate_visitor_exit()
	_update_status_bubble()


# ---------------------------------------------------------------------------
# HUD updates
# ---------------------------------------------------------------------------

func _update_hud() -> void:
	day_label.text = "День %d" % GameState.current_day
	answers_label.text = "Ответов: %d/5" % GameState.answers_today

	_update_progress_bar(trust_progress, GameState.city_stats.get("trust", 50))
	_update_progress_bar(prosperity_progress, GameState.city_stats.get("prosperity", 50))
	_update_progress_bar(safety_progress, GameState.city_stats.get("safety", 50))
	_update_progress_bar(morale_progress, GameState.city_stats.get("morale", 50))


func _update_progress_bar(bar: ProgressBar, value: int) -> void:
	bar.value = value

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


func _update_status_bubble() -> void:
	var count: int = VisitorManager.get_remaining_count()
	if count > 0:
		status_bubble.visible = true
		status_bubble_label.text = "Ожидает: %d" % count
	else:
		status_bubble.visible = false


# ---------------------------------------------------------------------------
# Day cycle integration
# ---------------------------------------------------------------------------

func _on_visitor_manager_day_complete() -> void:
	# Transition to day summary screen
	get_tree().change_scene_to_file("res://scenes/main/day_summary.tscn")


func _on_ending_triggered(ending_id: String) -> void:
	# Ending scenes will be implemented in a future task
	print("ENDING: ", ending_id)
