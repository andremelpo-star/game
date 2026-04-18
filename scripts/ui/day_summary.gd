extends Control

## Day summary is now a thin redirect -- the evening walk handles the
## end-of-day narrative.  If this scene is loaded (e.g. from an old save),
## it immediately transitions to the evening walk.


func _ready() -> void:
	# Redirect straight to the evening walk
	SceneTransition.change_scene("res://scenes/city/evening_walk.tscn")
