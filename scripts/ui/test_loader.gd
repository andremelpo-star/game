extends Control

@onready var output: RichTextLabel = %Output
@onready var btn_all_books: Button = %BtnAllBooks
@onready var btn_full_book: Button = %BtnFullBook
@onready var btn_visitors: Button = %BtnVisitors
@onready var btn_consequences: Button = %BtnConsequences
@onready var btn_game_state: Button = %BtnGameState


func _ready() -> void:
	btn_all_books.pressed.connect(_on_load_all_books)
	btn_full_book.pressed.connect(_on_load_full_book)
	btn_visitors.pressed.connect(_on_load_visitors)
	btn_consequences.pressed.connect(_on_load_consequences)
	btn_game_state.pressed.connect(_on_test_game_state)
	_log("Test scene ready. Press any button to begin.\n")


func _log(text: String) -> void:
	output.append_text(text + "\n")


func _on_load_all_books() -> void:
	_log("[b]--- Load All Books ---[/b]")
	var books: Array[Dictionary] = ContentLoader.load_all_books()
	_log("Found %d book(s):" % books.size())
	for book in books:
		_log("  [color=yellow]%s[/color] (id: %s, shelf: %s, pages: %s)" % [
			book.get("title", "?"),
			book.get("id", "?"),
			book.get("shelf", "?"),
			str(book.get("pages", "?"))
		])
		_log("    tags: %s" % str(book.get("tags", [])))
		_log("    knowledge_keys: %s" % str(book.get("knowledge_keys", [])))
	_log("")


func _on_load_full_book() -> void:
	_log("[b]--- Load Full Book ---[/b]")
	var book: Dictionary = ContentLoader.load_book("res://content/books/fiction/tale_of_iron_king.md")
	if book.is_empty():
		_log("[color=red]ERROR: Book not found![/color]")
		return
	_log("Title: [color=yellow]%s[/color]" % book.get("title", "?"))
	_log("ID: %s" % book.get("id", "?"))
	var content: String = book.get("content", "")
	if content.length() > 500:
		content = content.substr(0, 500) + "..."
	_log("Content (first 500 chars):\n[color=gray]%s[/color]" % content)
	_log("")


func _on_load_visitors() -> void:
	_log("[b]--- Load Visitors Day 1 ---[/b]")
	var visitors: Array[Dictionary] = ContentLoader.load_visitors_for_day(1)
	_log("Found %d visitor(s):" % visitors.size())
	for v in visitors:
		_log("  [color=green]%s[/color] (id: %s, importance: %s)" % [
			v.get("name", "?"),
			v.get("id", "?"),
			str(v.get("importance", "?"))
		])
		_log("  Question: %s" % str(v.get("question_text", "?")))
		var answers: Variant = v.get("answers", [])
		if answers is Array:
			_log("  Answers (%d):" % answers.size())
			for a in answers:
				if a is Dictionary:
					_log("    [%s] %s (outcome: %s)" % [
						str(a.get("id", "?")),
						str(a.get("text", "?")),
						str(a.get("outcome", "?"))
					])
	_log("")


func _on_load_consequences() -> void:
	_log("[b]--- Load Consequences ---[/b]")
	var consequences: Dictionary = ContentLoader.load_consequences()
	_log("Found %d consequence(s):" % consequences.size())
	for key in consequences:
		var c: Dictionary = consequences[key]
		_log("  [color=cyan]%s[/color] (delay: %s, type: %s)" % [
			key,
			str(c.get("trigger_delay", "?")),
			str(c.get("type", "?"))
		])
	_log("")


func _on_test_game_state() -> void:
	_log("[b]--- Test GameState ---[/b]")

	# Step 1: New game
	GameState.new_game()
	_log("1. new_game() called")
	_log("   day=%d, answers=%d, city=%s" % [
		GameState.current_day,
		GameState.answers_today,
		str(GameState.city_stats)
	])

	# Step 2: Add knowledge
	var keys: Array[String] = ["iron_king_mercy", "herb_guide_drought"]
	GameState.add_knowledge(keys)
	_log("2. add_knowledge(%s)" % str(keys))
	_log("   knowledge_keys=%s" % str(GameState.knowledge_keys))
	_log("   has_knowledge('iron_king_mercy')=%s" % str(GameState.has_knowledge("iron_king_mercy")))
	_log("   has_knowledge('unknown_key')=%s" % str(GameState.has_knowledge("unknown_key")))

	# Step 3: Modify city stats
	GameState.modify_city_stat("trust", 10)
	GameState.modify_city_stat("prosperity", -20)
	_log("3. modify_city_stat('trust', +10), modify_city_stat('prosperity', -20)")
	_log("   city_stats=%s" % str(GameState.city_stats))

	# Step 4: Mark book read
	GameState.mark_book_read("tale_of_iron_king")
	_log("4. mark_book_read('tale_of_iron_king')")
	_log("   is_book_read('tale_of_iron_king')=%s" % str(GameState.is_book_read("tale_of_iron_king")))
	_log("   is_book_read('unknown_book')=%s" % str(GameState.is_book_read("unknown_book")))

	# Step 5: Add consequence
	GameState.add_consequence("farmer_witch_peace", 3)
	GameState.current_day = 3
	_log("5. add_consequence('farmer_witch_peace', trigger_day=3), set day=3")
	var active := GameState.get_active_consequences()
	_log("   active_consequences=%s" % str(active))

	# Step 6: Save
	GameState.save_game()
	_log("6. save_game() called")
	_log("   has_save()=%s" % str(GameState.has_save()))

	# Step 7: Reset and verify
	GameState.new_game()
	_log("7. new_game() -- reset all")
	_log("   day=%d, knowledge=%s, city=%s" % [
		GameState.current_day,
		str(GameState.knowledge_keys),
		str(GameState.city_stats)
	])

	# Step 8: Load and verify
	var loaded: bool = GameState.load_game()
	_log("8. load_game() returned %s" % str(loaded))
	_log("   day=%d, knowledge=%s" % [GameState.current_day, str(GameState.knowledge_keys)])
	_log("   city=%s" % str(GameState.city_stats))
	_log("   read_books=%s" % str(GameState.read_books))
	_log("   pending_consequences=%s" % str(GameState.pending_consequences))

	_log("[color=green]GameState test complete![/color]\n")
