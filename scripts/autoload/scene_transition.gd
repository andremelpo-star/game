extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var _is_transitioning: bool = false


func _ready() -> void:
	layer = 100  # render on top of everything
	# Create ColorRect programmatically if not present in scene
	if not has_node("ColorRect"):
		var rect := ColorRect.new()
		rect.name = "ColorRect"
		rect.color = Color(0, 0, 0, 0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(rect)
		color_rect = rect


## Smooth scene transition: fade out -> change scene -> fade in
func change_scene(path: String, duration: float = 0.4) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# 1. Fade to black
	await fade_out(duration * 0.5)

	# 2. Change scene
	get_tree().change_scene_to_file(path)

	# 3. Wait one frame for the new scene to load
	await get_tree().process_frame

	# 4. Fade from black
	await fade_in(duration * 0.5)

	_is_transitioning = false


## Fade to black (alpha 0 -> 1)
func fade_out(duration: float = 0.3) -> void:
	if color_rect == null:
		return
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished


## Fade from black (alpha 1 -> 0)
func fade_in(duration: float = 0.3) -> void:
	if color_rect == null:
		return
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
