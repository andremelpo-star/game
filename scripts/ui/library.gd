extends Control

signal day_complete
signal city_walk_requested

@onready var day_label: Label = %DayLabel
@onready var answers_label: Label = %AnswersLabel
@onready var trust_progress: ProgressBar = %TrustProgress
@onready var prosperity_progress: ProgressBar = %ProsperityProgress
@onready var safety_progress: ProgressBar = %SafetyProgress
@onready var morale_progress: ProgressBar = %MoraleProgress
@onready var desk_label: Label = %DeskLabel
@onready var visitor_queue: Label = %VisitorQueue
@onready var btn_visitor: Button = %BtnVisitor
@onready var btn_city_walk: Button = %BtnCityWalk
@onready var btn_end_day: Button = %BtnEndDay
@onready var btn_shelf_fiction: Button = %BtnShelfFiction
@onready var btn_shelf_practical: Button = %BtnShelfPractical
@onready var btn_shelf_rare: Button = %BtnShelfRare
@onready var shelf_overlay: PanelContainer = $ShelfOverlay
@onready var book_reader_overlay: Control = $BookReaderOverlay
@onready var visitor_overlay: Control = $VisitorOverlay


func _ready() -> void:
	# Connect shelf buttons
	btn_shelf_fiction.pressed.connect(_on_shelf_button_pressed.bind("fiction"))
	btn_shelf_practical.pressed.connect(_on_shelf_button_pressed.bind("practical"))
	btn_shelf_rare.pressed.connect(_on_shelf_button_pressed.bind("rare"))

	# Connect action buttons
	btn_visitor.pressed.connect(_on_visitor_pressed)
	btn_city_walk.pressed.connect(_on_city_walk_pressed)
	btn_end_day.pressed.connect(_on_end_day_pressed)

	# Connect overlay signals
	shelf_overlay.book_selected.connect(_on_book_selected)
	book_reader_overlay.book_closed.connect(_on_book_closed)
	visitor_overlay.answer_submitted.connect(_on_answer_submitted)
	visitor_overlay.visitor_deferred.connect(_on_visitor_deferred)

	# Initialize day
	VisitorManager.start_day(GameState.current_day)

	_update_hud()
	_update_visitor_queue()


func _update_hud() -> void:
	day_label.text = "День %d" % GameState.current_day
	answers_label.text = "Ответов: %d/5" % GameState.answers_today

	# Update progress bars
	_update_progress_bar(trust_progress, GameState.city_stats.get("trust", 50))
	_update_progress_bar(prosperity_progress, GameState.city_stats.get("prosperity", 50))
	_update_progress_bar(safety_progress, GameState.city_stats.get("safety", 50))
	_update_progress_bar(morale_progress, GameState.city_stats.get("morale", 50))

	# Update visitor button state
	if GameState.answers_today >= 5:
		btn_visitor.disabled = true
		btn_visitor.text = "День окончен"
	elif VisitorManager.get_remaining_count() <= 0:
		btn_visitor.disabled = true
		btn_visitor.text = "Нет посетителей"
	else:
		btn_visitor.disabled = false
		btn_visitor.text = "Принять посетителя"


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


func _update_visitor_queue() -> void:
	var count: int = VisitorManager.get_remaining_count()
	visitor_queue.text = "Ожидает: %d посетителей" % count


func _on_shelf_button_pressed(shelf: String) -> void:
	shelf_overlay.open_shelf(shelf)


func _on_book_selected(book_id: String) -> void:
	shelf_overlay.visible = false
	book_reader_overlay.open_book(book_id)


func _on_book_closed() -> void:
	_update_hud()


func _on_visitor_pressed() -> void:
	var visitor: Variant = VisitorManager.get_next_visitor()
	if visitor == null:
		return
	visitor_overlay.show_visitor(visitor)


func _on_answer_submitted(visitor_id: String, answer_id: String) -> void:
	VisitorManager.submit_answer(visitor_id, answer_id)
	_update_hud()
	_update_visitor_queue()

	if GameState.answers_today >= 5:
		desk_label.text = "Все посетители на сегодня приняты."
		day_complete.emit()


func _on_visitor_deferred() -> void:
	_update_visitor_queue()


func _on_city_walk_pressed() -> void:
	city_walk_requested.emit()


func _on_end_day_pressed() -> void:
	day_complete.emit()
