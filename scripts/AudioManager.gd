extends Node

## Global Audio Manager
## Handles playing SFX and Music using a pool of AudioStreamPlayers.

const POOL_SIZE = 16

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_sfx_index: int = 0

func _ready() -> void:
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
	var stream = SoundRegistry.get_stream(sound_id)
	if not stream:
		push_warning("AudioManager: Sound not found: " + sound_id)
		return
	
	# Get next available player from pool
	var player = _sfx_pool[_current_sfx_index]
	_current_sfx_index = (_current_sfx_index + 1) % POOL_SIZE
	
	# Vocal pronunciations should have a consistent pitch and a volume boost
	var is_vocal = sound_id.begins_with("pronunciation_")
	
	# Vary pitch slightly for realism if default pitch is used (except for vocal pronunciation)
	if is_equal_approx(pitch_scale, 1.0) and not is_vocal:
		pitch_scale = randf_range(0.95, 1.05)
	
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
			_music_player.play()

		)
	else:
		_music_player.stream = stream
		_music_player.volume_db = volume_db
		_music_player.play()


func stop_music(fade_duration: float = 1.0) -> void:
	if _music_player.playing:
		var tween = create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(_music_player.stop)

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
