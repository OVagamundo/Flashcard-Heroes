extends Node

## Global Audio Manager
## Handles playing SFX and Music using a pool of AudioStreamPlayers.

const POOL_SIZE = 16
const AUDIO_SETTINGS_PATH := "user://audio_settings.save"

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_sfx_index: int = 0
var pronunciation_enabled: bool = true

var _frame_sfx_counts: Dictionary = {}
var _last_frame: int = -1

func _ready() -> void:
	# Load settings first
	_load_audio_settings()
	
	# Create pool of SFX players
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)
	
	# Create Music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	
	# PREWARM BGM: Touch all BGM streams to ensure they're fully loaded
	# This prevents delays when first playing each track
	_prewarm_bgm_streams()

## Play a sound effect by ID
func play_sfx(sound_id: String, pitch_scale: float = 1.0) -> void:
	var is_vocal = sound_id.begins_with("pronunciation_")
	if is_vocal and not pronunciation_enabled:
		return
		
	var stream = SoundRegistry.get_stream(sound_id)
	if not stream:
		push_warning("AudioManager: Sound not found: " + sound_id)
		return
	
	# Enforce polyphony limit to prevent clipping when multiple async events play simultaneously
	var frame = Engine.get_process_frames()
	if frame != _last_frame:
		_last_frame = frame
		_frame_sfx_counts.clear()
		
	var count = _frame_sfx_counts.get(sound_id, 0)
	if count >= 2:
		return # Polyphony limit reached
	_frame_sfx_counts[sound_id] = count + 1
	
	# Get next available player from pool
	var player = _sfx_pool[_current_sfx_index]
	_current_sfx_index = (_current_sfx_index + 1) % POOL_SIZE
	
	# Vary pitch slightly for realism if default pitch is used (except for vocal pronunciation)
	if is_equal_approx(pitch_scale, 1.0) and not is_vocal:
		pitch_scale = RNGManager.cosmetic_rng.randf_range(0.95, 1.05)
	
	player.stream = stream
	player.pitch_scale = pitch_scale
	
	if is_vocal:
		player.volume_db = 6.0 # Boost vocal pronunciation to make it stand out
	else:
		player.volume_db = 0.0 # Full volume
		
	player.play()

## Play background music with crossfade and looping
func play_music(stream: AudioStream, crossfade_duration: float = 0.1, volume_db: float = 0.0) -> void:
	if _music_player.stream == stream and _music_player.playing:
		# If already playing, just update volume if it differs
		if not is_equal_approx(_music_player.volume_db, volume_db):
			var tween = create_tween()
			tween.tween_property(_music_player, "volume_db", volume_db, 0.2)
		return
	
	# Enable looping for OGG Vorbis streams
	if stream is AudioStreamOggVorbis:
		stream.loop = true
		
	if _music_player.playing:
		# Quick fade out for snappy transitions
		var tween = create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, crossfade_duration)
		tween.tween_callback(func():
			_music_player.stop()
			_music_player.stream = stream
			_music_player.volume_db = volume_db
			_music_player.pitch_scale = 1.0
			_music_player.play()
		)
	else:
		_music_player.stream = stream
		_music_player.volume_db = volume_db
		_music_player.pitch_scale = 1.0
		_music_player.play()


func stop_music(fade_duration: float = 1.0) -> void:
	if _music_player.playing:
		var tween = create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(_music_player.stop)

func set_music_pitch(pitch: float, duration: float = 0.5) -> void:
	if is_instance_valid(_music_player):
		var tween = create_tween()
		tween.tween_property(_music_player, "pitch_scale", pitch, duration).set_trans(Tween.TRANS_SINE)

func _prewarm_bgm_streams() -> void:
	"""Prewarm all BGM streams to eliminate first-play loading delay.
	This 'touches' each stream to ensure it's fully decoded and ready."""
	var bgm_streams = [
		SoundRegistry.BGM_TITLE,
		SoundRegistry.BGM_LOADOUT,
		SoundRegistry.BGM_PATHCHOICE,
		SoundRegistry.BGM_REST,
		SoundRegistry.BGM_REWARD,
		SoundRegistry.BGM_MINIGAME,
		SoundRegistry.BGM_MENU,
		SoundRegistry.BGM_BATTLE,
		SoundRegistry.BGM_SHOP
	]
	
	for stream in bgm_streams:
		if is_instance_valid(stream):
			# Touch the stream's length to force decode/load
			var _length = stream.get_length()

func _load_audio_settings() -> void:
	if not FileAccess.file_exists(AUDIO_SETTINGS_PATH):
		return
		
	var file := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
		
	var data: Variant = file.get_var()
	file.close()
	
	if data is Dictionary:
		var master_idx = AudioServer.get_bus_index("Master")
		var music_idx = AudioServer.get_bus_index("Music")
		var sfx_idx = AudioServer.get_bus_index("SFX")
		
		if master_idx >= 0 and data.has("master_vol"):
			AudioServer.set_bus_volume_db(master_idx, linear_to_db(data["master_vol"]))
		if music_idx >= 0 and data.has("music_vol"):
			AudioServer.set_bus_volume_db(music_idx, linear_to_db(data["music_vol"]))
		if sfx_idx >= 0 and data.has("sfx_vol"):
			AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(data["sfx_vol"]))
		if data.has("pronunciation_enabled"):
			pronunciation_enabled = data["pronunciation_enabled"]
