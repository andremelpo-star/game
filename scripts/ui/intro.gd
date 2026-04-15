extends Control

@onready var intro_text: RichTextLabel = %IntroText
@onready var btn_next: Button = %BtnNext
@onready var page_indicator: Label = %PageIndicator

var _current_page: int = 0

const INTRO_PAGES: Array[String] = [
	"В этом мире немногие умеют читать. Книги -- редкость, а знания передаются из уст в уста, обрастая слухами и домыслами. Лишь в Академии Мудрецов хранятся древние тексты и учат искусству совета.",

	"Вы -- выпускник Академии. Годы учёбы позади: вы читали хроники королей, изучали травы и законы, спорили с наставниками о природе справедливости. Теперь пришло время применить знания на деле.",

	"Вас направили в город N -- небольшой, но беспокойный. Здесь нет мудреца уже три года, и горожане привыкли решать проблемы сами -- не всегда удачно. Доверие к учёным людям невысоко.",

	"Ваша библиотека -- и рабочее место, и дом. Сюда будут приходить горожане со своими бедами. Читайте книги, чтобы давать мудрые советы. Каждое решение повлияет на судьбу города. У вас семь дней, чтобы доказать свою ценность."
]


func _ready() -> void:
	btn_next.pressed.connect(_on_next_pressed)
	_show_page(0)


func _show_page(index: int) -> void:
	_current_page = index
	intro_text.text = "[center]%s[/center]" % INTRO_PAGES[_current_page]
	page_indicator.text = "%d / %d" % [_current_page + 1, INTRO_PAGES.size()]

	if _current_page >= INTRO_PAGES.size() - 1:
		btn_next.text = "Начать"
	else:
		btn_next.text = "Далее"


func _on_next_pressed() -> void:
	AudioManager.play_sfx("click")
	if _current_page >= INTRO_PAGES.size() - 1:
		SceneTransition.change_scene("res://scenes/library/library.tscn")
	else:
		_show_page(_current_page + 1)
