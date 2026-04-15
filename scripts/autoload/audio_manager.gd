extends Node

## AudioStreamPlayer for background music / ambient
var _music_player: AudioStreamPlayer
## AudioStreamPlayer for sound effects
var _sfx_player: AudioStreamPlayer

## Preloaded sound resources
var _sounds: Dictionary = {}

## Currently playing music path (to avoid restarting the same track)
var _current_music_path: String = ""


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	_preload_sounds()


func _preload_sounds() -> void:
	var sound_files: Dictionary = {
		"page_turn": "res://assets/audio/page_turn.wav",
		"footsteps": "res://assets/audio/footsteps.wav",
		"door": "res://assets/audio/door.wav",
		"click": "res://assets/audio/click.wav",
	}
	for key in sound_files:
		if ResourceLoader.exists(sound_files[key]):
			_sounds[key] = load(sound_files[key])


## Play a sound effect by name. Silently skips if the sound file is missing.
func play_sfx(sound_name: String) -> void:
	if sound_name in _sounds:
		_sfx_player.stream = _sounds[sound_name]
		_sfx_player.volume_db = linear_to_db(SettingsManager.sfx_volume)
		_sfx_player.play()


## Play background music with optional fade-in. Does nothing if already playing the same track.
func play_music(path: String, fade_duration: float = 1.0) -> void:
	if path == _current_music_path and _music_player.playing:
		return

	if not ResourceLoader.exists(path):
		return

	# Fade out current music if playing
	if _music_player.playing:
		var fade_out := create_tween()
		fade_out.tween_property(_music_player, "volume_db", -80.0, fade_duration * 0.5)
		await fade_out.finished
		_music_player.stop()

	# Load and play new music
	_music_player.stream = load(path)
	_music_player.volume_db = -80.0
	_music_player.play()
	_current_music_path = path

	# Fade in
	var target_db: float = linear_to_db(SettingsManager.music_volume)
	var fade_in := create_tween()
	fade_in.tween_property(_music_player, "volume_db", target_db, fade_duration * 0.5)


## Stop music with fade-out.
func stop_music(fade_duration: float = 1.0) -> void:
	if not _music_player.playing:
		return

	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
	await tween.finished
	_music_player.stop()
	_current_music_path = ""
