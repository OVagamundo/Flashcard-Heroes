class_name Audio
extends Node

## Static helper to access the AudioManager instance since we can't easily add AutoLoads via script.
## Usage: Audio.play_sfx("ui_click")

static func play_sfx(sound_id: String, pitch_scale: float = 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var manager: Node = tree.get_first_node_in_group("audio_manager")
	if is_instance_valid(manager):
		manager.play_sfx(sound_id, pitch_scale)

static func play_music(stream: AudioStream, fade: float = 0.1, volume_db: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var manager: Node = tree.get_first_node_in_group("audio_manager")
	if is_instance_valid(manager):
		manager.play_music(stream, fade, volume_db)

static func set_music_pitch(pitch: float, duration: float = 0.5) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var manager: Node = tree.get_first_node_in_group("audio_manager")
	if is_instance_valid(manager):
		manager.set_music_pitch(pitch, duration)
