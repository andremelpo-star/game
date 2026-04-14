extends PanelContainer

signal book_selected(book_id: String)

@onready var shelf_title: Label = %ShelfTitle
@onready var book_list: VBoxContainer = %BookList
@onready var btn_close_shelf: Button = %BtnCloseShelf

var _shelf_names: Dictionary = {
	"fiction": "Художественная литература",
	"practical": "Прикладные знания",
	"rare": "Редкие книги"
}


func _ready() -> void:
	btn_close_shelf.pressed.connect(_on_close_pressed)
	visible = false


## Opens the shelf panel, showing books filtered by shelf category.
func open_shelf(shelf: String) -> void:
	# Clear existing book entries
	for child in book_list.get_children():
		child.queue_free()

	shelf_title.text = _shelf_names.get(shelf, shelf)

	var books: Array[Dictionary] = ContentLoader.load_all_books()
	var shelf_books: Array[Dictionary] = []
	for book in books:
		if book.get("shelf", "") == shelf:
			shelf_books.append(book)

	if shelf_books.is_empty():
		var empty_label := Label.new()
		empty_label.text = "На этой полке пока пусто"
		empty_label.add_theme_color_override("font_color", Color("#8B7355"))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		book_list.add_child(empty_label)
	else:
		for book in shelf_books:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)

			var btn := Button.new()
			btn.text = book.get("title", "???")
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size.y = 40

			# Style the button
			var style_normal := StyleBoxFlat.new()
			style_normal.bg_color = Color("#A0845C")
			style_normal.corner_radius_top_left = 4
			style_normal.corner_radius_top_right = 4
			style_normal.corner_radius_bottom_left = 4
			style_normal.corner_radius_bottom_right = 4
			style_normal.content_margin_left = 12.0
			style_normal.content_margin_right = 12.0
			style_normal.content_margin_top = 6.0
			style_normal.content_margin_bottom = 6.0
			btn.add_theme_stylebox_override("normal", style_normal)

			var style_hover := StyleBoxFlat.new()
			style_hover.bg_color = Color("#C4A265")
			style_hover.corner_radius_top_left = 4
			style_hover.corner_radius_top_right = 4
			style_hover.corner_radius_bottom_left = 4
			style_hover.corner_radius_bottom_right = 4
			style_hover.content_margin_left = 12.0
			style_hover.content_margin_right = 12.0
			style_hover.content_margin_top = 6.0
			style_hover.content_margin_bottom = 6.0
			btn.add_theme_stylebox_override("hover", style_hover)

			btn.add_theme_color_override("font_color", Color("#FFF8E7"))
			btn.add_theme_color_override("font_hover_color", Color("#FFF8E7"))

			var book_id: String = book.get("id", "")
			btn.pressed.connect(_on_book_button_pressed.bind(book_id))
			row.add_child(btn)

			var status_label := Label.new()
			if GameState.is_book_read(book_id):
				status_label.text = "Прочитана"
				status_label.add_theme_color_override("font_color", Color("#4CAF50"))
			else:
				status_label.text = "Не прочитана"
				status_label.add_theme_color_override("font_color", Color("#8B7355"))
			status_label.custom_minimum_size.x = 140
			status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(status_label)

			book_list.add_child(row)

	self.visible = true


func _on_book_button_pressed(book_id: String) -> void:
	self.visible = false
	book_selected.emit(book_id)


func _on_close_pressed() -> void:
	self.visible = false
