extends Control

signal answer_submitted(visitor_id: String, answer_id: String)
signal visitor_deferred(visitor_id: String)

@onready var visitor_name: Label = %VisitorName
@onready var importance_label: Label = %ImportanceLabel
@onready var question_text: RichTextLabel = %QuestionText
@onready var answers_list: VBoxContainer = %AnswersList
@onready var btn_defer: Button = %BtnDefer
@onready var btn_apply_knowledge: Button = %BtnApplyKnowledge
@onready var visitor_portrait: TextureRect = %VisitorPortrait

var _current_visitor: Dictionary = {}
var _knowledge_revealed: bool = false
var _answer_buttons: Array[Button] = []


func _ready() -> void:
	btn_defer.pressed.connect(_on_defer_pressed)
	btn_apply_knowledge.pressed.connect(_on_apply_knowledge_pressed)
	visible = false


## Shows a visitor with their question and answer options.
func show_visitor(visitor: Dictionary) -> void:
	_current_visitor = visitor
	_knowledge_revealed = false
	_answer_buttons.clear()

	visitor_name.text = visitor.get("name", "Unknown")
	importance_label.text = "Важность: %s" % _translate_importance(visitor.get("importance", "low"))

	question_text.text = ""
	question_text.append_text(visitor.get("question_text", ""))

	# Clear existing answer buttons
	for child in answers_list.get_children():
		child.queue_free()

	# Create answer buttons
	var answers: Array = visitor.get("answers", [])
	for answer in answers:
		if not answer is Dictionary:
			continue

		var btn := Button.new()
		btn.text = str(answer.get("text", "???"))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 44
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Style the button
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = Color("#E8D5B5")
		style_normal.border_color = Color("#8B7355")
		style_normal.border_width_left = 1
		style_normal.border_width_right = 1
		style_normal.border_width_top = 1
		style_normal.border_width_bottom = 1
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_top_right = 4
		style_normal.corner_radius_bottom_left = 4
		style_normal.corner_radius_bottom_right = 4
		style_normal.content_margin_left = 12.0
		style_normal.content_margin_right = 12.0
		style_normal.content_margin_top = 8.0
		style_normal.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override("normal", style_normal)

		var style_hover := StyleBoxFlat.new()
		style_hover.bg_color = Color("#D4C4A0")
		style_hover.border_color = Color("#6B5335")
		style_hover.border_width_left = 1
		style_hover.border_width_right = 1
		style_hover.border_width_top = 1
		style_hover.border_width_bottom = 1
		style_hover.corner_radius_top_left = 4
		style_hover.corner_radius_top_right = 4
		style_hover.corner_radius_bottom_left = 4
		style_hover.corner_radius_bottom_right = 4
		style_hover.content_margin_left = 12.0
		style_hover.content_margin_right = 12.0
		style_hover.content_margin_top = 8.0
		style_hover.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override("hover", style_hover)

		btn.add_theme_color_override("font_color", Color("#2C1810"))
		btn.add_theme_color_override("font_hover_color", Color("#2C1810"))

		var vid: String = visitor.get("id", "")
		var aid: String = str(answer.get("id", ""))
		btn.pressed.connect(_on_answer_pressed.bind(vid, aid))

		answers_list.add_child(btn)
		_answer_buttons.append(btn)

	# Determine "Apply Knowledge" button visibility
	var helpful: Array = visitor.get("helpful_knowledge", [])
	var has_relevant_knowledge: bool = false
	for key in helpful:
		if GameState.has_knowledge(str(key)):
			has_relevant_knowledge = true
			break

	btn_apply_knowledge.visible = has_relevant_knowledge
	btn_apply_knowledge.disabled = false
	btn_apply_knowledge.text = "Применить знания"

	self.visible = true


func _on_answer_pressed(visitor_id: String, answer_id: String) -> void:
	self.visible = false
	answer_submitted.emit(visitor_id, answer_id)


func _on_defer_pressed() -> void:
	self.visible = false
	visitor_deferred.emit(_current_visitor.get("id", ""))


func _on_apply_knowledge_pressed() -> void:
	_knowledge_revealed = true
	btn_apply_knowledge.disabled = true
	btn_apply_knowledge.text = "Знания применены"

	var answers: Array = _current_visitor.get("answers", [])
	for i in range(answers.size()):
		if i >= _answer_buttons.size():
			break
		var answer: Dictionary = answers[i]
		var req_keys: Array = answer.get("requires_knowledge", [])
		if req_keys.is_empty():
			continue

		var typed_keys: Array[String] = []
		for k in req_keys:
			typed_keys.append(str(k))

		if GameState.has_all_knowledge(typed_keys):
			var btn: Button = _answer_buttons[i]
			btn.text = "[Книга] " + btn.text

			var stylebox := StyleBoxFlat.new()
			stylebox.bg_color = Color("#F5E6C8")
			stylebox.border_color = Color("#DAA520")
			stylebox.border_width_left = 3
			stylebox.border_width_right = 3
			stylebox.border_width_top = 3
			stylebox.border_width_bottom = 3
			stylebox.corner_radius_top_left = 4
			stylebox.corner_radius_top_right = 4
			stylebox.corner_radius_bottom_left = 4
			stylebox.corner_radius_bottom_right = 4
			stylebox.content_margin_left = 12.0
			stylebox.content_margin_right = 12.0
			stylebox.content_margin_top = 8.0
			stylebox.content_margin_bottom = 8.0
			btn.add_theme_stylebox_override("normal", stylebox)

			var hover_stylebox := StyleBoxFlat.new()
			hover_stylebox.bg_color = Color("#EBD9A8")
			hover_stylebox.border_color = Color("#DAA520")
			hover_stylebox.border_width_left = 3
			hover_stylebox.border_width_right = 3
			hover_stylebox.border_width_top = 3
			hover_stylebox.border_width_bottom = 3
			hover_stylebox.corner_radius_top_left = 4
			hover_stylebox.corner_radius_top_right = 4
			hover_stylebox.corner_radius_bottom_left = 4
			hover_stylebox.corner_radius_bottom_right = 4
			hover_stylebox.content_margin_left = 12.0
			hover_stylebox.content_margin_right = 12.0
			hover_stylebox.content_margin_top = 8.0
			hover_stylebox.content_margin_bottom = 8.0
			btn.add_theme_stylebox_override("hover", hover_stylebox)

	# Show hint text if available
	var hint: String = _current_visitor.get("without_knowledge_hint", "")
	if not hint.is_empty():
		var hint_label := Label.new()
		hint_label.text = hint
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.add_theme_color_override("font_color", Color("#8B7355"))
		hint_label.add_theme_font_size_override("font_size", 14)
		answers_list.add_child(hint_label)


func _translate_importance(importance: String) -> String:
	match importance:
		"low":
			return "низкая"
		"medium":
			return "средняя"
		"high":
			return "высокая"
		"critical":
			return "критическая"
		_:
			return importance
