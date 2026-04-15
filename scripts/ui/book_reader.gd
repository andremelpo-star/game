extends Control

signal book_closed

# --- Nodes ---
@onready var title_label: Label = %TitleLabel
@onready var content_text: RichTextLabel = %ContentText
@onready var page_label: Label = %PageLabel
@onready var btn_prev: Button = %BtnPrev
@onready var btn_next: Button = %BtnNext
@onready var btn_close: Button = %BtnClose

# --- State ---
var _book_data: Dictionary = {}
var _pages: Array[String] = []
var _current_page: int = 0
var _reached_last_page: bool = false

const CHARS_PER_PAGE: int = 1500

# --- Swipe ---
var _swipe_start: Vector2 = Vector2.ZERO
var _swiping: bool = false
const SWIPE_THRESHOLD: float = 100.0

# --- Regex (compiled once) ---
var _re_h2: RegEx
var _re_h1: RegEx
var _re_bold: RegEx
var _re_italic: RegEx
var _re_bbcode_strip: RegEx


func _ready() -> void:
	btn_prev.pressed.connect(_go_prev_page)
	btn_next.pressed.connect(_go_next_page)
	btn_close.pressed.connect(_close_book)
	visible = false

	# Compile regex patterns once
	_re_h2 = RegEx.new()
	_re_h2.compile("^## (.+)$")
	_re_h1 = RegEx.new()
	_re_h1.compile("^# (.+)$")
	_re_bold = RegEx.new()
	_re_bold.compile("\\*\\*(.+?)\\*\\*")
	_re_italic = RegEx.new()
	_re_italic.compile("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)")
	_re_bbcode_strip = RegEx.new()
	_re_bbcode_strip.compile("\\[.*?\\]")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Opens a book by its ID, loading content via ContentLoader.
func open_book(book_id: String) -> void:
	# Find the file_path from metadata
	var all_books: Array[Dictionary] = ContentLoader.load_all_books()
	var file_path: String = ""
	for book in all_books:
		if book.get("id", "") == book_id:
			file_path = book.get("file_path", "")
			break

	if file_path.is_empty():
		push_warning("BookReader: Book '%s' not found in content" % book_id)
		return

	# Load the full book with content
	_book_data = ContentLoader.load_book(file_path)
	if _book_data.is_empty():
		push_warning("BookReader: Failed to load book '%s'" % file_path)
		return

	# Paginate
	var content: String = _book_data.get("content", "")
	_paginate(content)

	# Set title
	title_label.text = _book_data.get("title", "Unknown Book")

	# Reset navigation state
	_current_page = 0
	_reached_last_page = false

	# Show first page
	_show_page(0)
	self.visible = true


# ---------------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------------

## Splits text into pages based on CHARS_PER_PAGE, respecting paragraph boundaries.
func _paginate(text: String) -> void:
	_pages.clear()

	var bbcode: String = _md_to_bbcode(text)

	# Split by double newlines into paragraphs
	var paragraphs: PackedStringArray = bbcode.split("\n\n")
	var current_page: String = ""
	var current_length: int = 0

	for paragraph in paragraphs:
		var stripped: String = paragraph.strip_edges()
		if stripped.is_empty():
			continue

		var para_plain_len: int = _strip_bbcode(stripped).length()

		# If a single paragraph exceeds the limit, split it by sentences
		if para_plain_len > CHARS_PER_PAGE:
			# Flush current page first if it has content
			if not current_page.strip_edges().is_empty():
				_pages.append(current_page.strip_edges())
				current_page = ""
				current_length = 0

			# Split long paragraph by sentences
			var sentences: PackedStringArray = stripped.split(". ")
			var sentence_page: String = ""
			var sentence_length: int = 0

			for i in range(sentences.size()):
				var sentence: String = sentences[i]
				if i < sentences.size() - 1:
					sentence += ". "
				var s_len: int = _strip_bbcode(sentence).length()

				if sentence_length + s_len > CHARS_PER_PAGE and not sentence_page.is_empty():
					_pages.append(sentence_page.strip_edges())
					sentence_page = ""
					sentence_length = 0

				sentence_page += sentence
				sentence_length += s_len

			if not sentence_page.strip_edges().is_empty():
				_pages.append(sentence_page.strip_edges())
			continue

		# Check if adding this paragraph would exceed the limit
		if current_length + para_plain_len > CHARS_PER_PAGE and not current_page.strip_edges().is_empty():
			_pages.append(current_page.strip_edges())
			current_page = ""
			current_length = 0

		if not current_page.is_empty():
			current_page += "\n\n"
		current_page += stripped
		current_length += para_plain_len

	# Flush remaining content
	if not current_page.strip_edges().is_empty():
		_pages.append(current_page.strip_edges())

	# Ensure at least one page
	if _pages.is_empty():
		_pages.append("")


## Converts basic Markdown to BBCode for RichTextLabel.
func _md_to_bbcode(md: String) -> String:
	var lines: PackedStringArray = md.split("\n")
	var result_lines: PackedStringArray = []

	for line in lines:
		var converted: String = line

		# Headers: ## before # (order matters)
		var m2 := _re_h2.search(converted)
		if m2:
			converted = "[font_size=24][b]%s[/b][/font_size]" % m2.get_string(1)
			result_lines.append(converted)
			continue

		var m1 := _re_h1.search(converted)
		if m1:
			converted = "[font_size=28][b]%s[/b][/font_size]" % m1.get_string(1)
			result_lines.append(converted)
			continue

		result_lines.append(converted)

	var result: String = "\n".join(result_lines)

	# Bold: **text**
	result = _re_bold.sub(result, "[b]$1[/b]", true)

	# Italic: *text* (not preceded/followed by *)
	result = _re_italic.sub(result, "[i]$1[/i]", true)

	return result


## Strips all BBCode tags from text for accurate length counting.
func _strip_bbcode(text: String) -> String:
	return _re_bbcode_strip.sub(text, "", true)


# ---------------------------------------------------------------------------
# Page navigation
# ---------------------------------------------------------------------------

## Displays the page at the given index.
func _show_page(index: int) -> void:
	index = clampi(index, 0, _pages.size() - 1)
	_current_page = index

	content_text.text = ""
	content_text.append_text(_pages[index])

	page_label.text = "Pg. %d of %d" % [index + 1, _pages.size()]
	btn_prev.disabled = (index == 0)
	btn_next.disabled = (index == _pages.size() - 1)

	if index == _pages.size() - 1:
		_reached_last_page = true


func _go_prev_page() -> void:
	if _current_page > 0:
		AudioManager.play_sfx("page_turn")
		_show_page(_current_page - 1)


func _go_next_page() -> void:
	if _current_page < _pages.size() - 1:
		AudioManager.play_sfx("page_turn")
		_show_page(_current_page + 1)


# ---------------------------------------------------------------------------
# Swipe support
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
			_swiping = true
		else:
			if _swiping:
				var delta: Vector2 = event.position - _swipe_start
				if absf(delta.x) > SWIPE_THRESHOLD:
					if delta.x < 0:
						_go_next_page()
					else:
						_go_prev_page()
				_swiping = false


# ---------------------------------------------------------------------------
# Close book and record knowledge
# ---------------------------------------------------------------------------

## Closes the book. If the reader reached the last page, records knowledge
## and marks the book as read in GameState.
func _close_book() -> void:
	if _reached_last_page and not _book_data.is_empty():
		# Get knowledge keys and ensure typed array
		var raw_keys: Variant = _book_data.get("knowledge_keys", [])
		var typed_keys: Array[String] = []
		if raw_keys is Array:
			for k in raw_keys:
				typed_keys.append(str(k))
		GameState.add_knowledge(typed_keys)
		GameState.mark_book_read(_book_data.get("id", ""))

	_book_data = {}
	_pages.clear()
	_current_page = 0
	_reached_last_page = false
	self.visible = false
	book_closed.emit()
