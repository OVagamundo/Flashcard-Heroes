# res://scripts/OptionsWindow.gd
extends Control

## Options window for game settings, including language selection

@onready var language_dropdown: OptionButton = %LanguageDropdown
@onready var close_button: Button = %CloseButton
@onready var title_label: Label = %TitleLabel

@onready var crt_checkbox: CheckBox = %CRTCheckbox
@onready var glow_checkbox: CheckBox = %GlowCheckbox
@onready var glow_debug_label: Label = %GlowDebugLabel
@onready var glow_debug_dropdown: OptionButton = %GlowDebugDropdown
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider

const AUDIO_SETTINGS_PATH := "user://audio_settings.save"

const LANGUAGES = [
	{"locale": "en", "name_key": "ui.english"},
	{"locale": "pt_BR", "name_key": "ui.portuguese"},
]
const GLOW_DEBUG_VIEW_NORMAL := 0
const GLOW_DEBUG_VIEW_SOURCE_MASK := 1
const GLOW_DEBUG_VIEW_WEIGHT_MASK := 2
const GLOW_DEBUG_OPTIONS = [
	{"id": GLOW_DEBUG_VIEW_NORMAL, "label": "Normal"},
	{"id": GLOW_DEBUG_VIEW_SOURCE_MASK, "label": "Source Mask"},
	{"id": GLOW_DEBUG_VIEW_WEIGHT_MASK, "label": "Glow Weight"},
]

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	language_dropdown.item_selected.connect(_on_language_selected)
	
	# Connect to locale changes to update the window's own text
	SignalBus.locale_changed.connect(_update_labels)
	
	_populate_language_dropdown()
	_update_labels()
	
	_init_graphics_settings()
	_init_audio_settings()

func _init_graphics_settings() -> void:
	if crt_checkbox:
		crt_checkbox.button_pressed = CRTEffect.is_enabled()
		crt_checkbox.toggled.connect(func(enabled: bool):
			CRTEffect.set_enabled(enabled)
		)

	if glow_checkbox:
		glow_checkbox.button_pressed = CRTEffect.is_glow_enabled()
		glow_checkbox.toggled.connect(func(enabled: bool):
			CRTEffect.set_glow_enabled(enabled)
		)

	if glow_debug_dropdown:
		_populate_glow_debug_dropdown()
		glow_debug_dropdown.item_selected.connect(_on_glow_debug_selected)

func _init_audio_settings() -> void:
	# Load settings first
	_load_audio_settings()
	
	# Set slider starting values
	var master_idx = AudioServer.get_bus_index("Master")
	var music_idx = AudioServer.get_bus_index("Music")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	
	if master_slider and master_idx >= 0:
		master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
		master_slider.value_changed.connect(_on_master_slider_changed)
		
	if music_slider and music_idx >= 0:
		music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx))
		music_slider.value_changed.connect(_on_music_slider_changed)
		
	if sfx_slider and sfx_idx >= 0:
		sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)

func _on_master_slider_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
		_save_audio_settings()

func _on_music_slider_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
		_save_audio_settings()

func _on_sfx_slider_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
		_save_audio_settings()

func _save_audio_settings() -> void:
	var master_vol = master_slider.value if is_instance_valid(master_slider) else 1.0
	var music_vol = music_slider.value if is_instance_valid(music_slider) else 1.0
	var sfx_vol = sfx_slider.value if is_instance_valid(sfx_slider) else 1.0
	
	var file := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_var({
			"master_vol": master_vol,
			"music_vol": music_vol,
			"sfx_vol": sfx_vol
		})
		file.close()

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

func _populate_language_dropdown() -> void:
	language_dropdown.clear()
	var current_locale := TranslationServer.get_locale()
	var selected_idx := 0
	
	for i in range(LANGUAGES.size()):
		var lang = LANGUAGES[i]
		var display_name := tr(lang.name_key)
		language_dropdown.add_item(display_name, i)
		if lang.locale == current_locale:
			selected_idx = i
	
	language_dropdown.select(selected_idx)

func _update_labels() -> void:
	title_label.text = tr("ui.options")
	close_button.text = tr("ui.confirm")
	
	if crt_checkbox:
		crt_checkbox.text = tr("ui.crt_effect")
	
	if glow_checkbox:
		glow_checkbox.text = tr("ui.glow_effect")

	if glow_debug_label:
		var translated := tr("ui.glow_debug")
		glow_debug_label.text = translated if translated != "ui.glow_debug" else "Glow Debug:"
	
	# Update Audio label texts if we want to localize those (e.g. Master, Music, SFX)
	# For now, using inline localization, but ideally should be added to CSV.
	if has_node("%AudioLabel"):
		get_node("%AudioLabel").text = tr("ui.audio_settings") if tr("ui.audio_settings") != "ui.audio_settings" else "Audio Settings"
	
	var master_label = find_child("MasterControl").get_child(0) if find_child("MasterControl") else null
	if master_label: master_label.text = tr("ui.master_volume") if tr("ui.master_volume") != "ui.master_volume" else "Master:"
		
	var music_label = find_child("MusicControl").get_child(0) if find_child("MusicControl") else null
	if music_label: music_label.text = tr("ui.music_volume") if tr("ui.music_volume") != "ui.music_volume" else "Music:"
		
	var sfx_label = find_child("SFXControl").get_child(0) if find_child("SFXControl") else null
	if sfx_label: sfx_label.text = tr("ui.sfx_volume") if tr("ui.sfx_volume") != "ui.sfx_volume" else "SFX:"
		
	# Re-populate dropdown with translated names
	var current_idx := language_dropdown.selected
	_populate_language_dropdown()
	if current_idx >= 0 and current_idx < language_dropdown.item_count:
		language_dropdown.select(current_idx)

func _on_language_selected(index: int) -> void:
	if index < 0 or index >= LANGUAGES.size():
		return
	
	var selected_locale: String = LANGUAGES[index].locale
	Database.set_locale(selected_locale)

func _on_close_pressed() -> void:
	queue_free()

func populate(_context: Dictionary = {}) -> void:
	# Options window doesn't need external context
	pass

func _populate_glow_debug_dropdown() -> void:
	glow_debug_dropdown.clear()
	var selected_idx := 0
	var current_view := CRTEffect.get_glow_debug_view()
	for i in range(GLOW_DEBUG_OPTIONS.size()):
		var option = GLOW_DEBUG_OPTIONS[i]
		glow_debug_dropdown.add_item(option.label, option.id)
		if option.id == current_view:
			selected_idx = i
	glow_debug_dropdown.select(selected_idx)

func _on_glow_debug_selected(index: int) -> void:
	if index < 0 or index >= GLOW_DEBUG_OPTIONS.size():
		return
	CRTEffect.set_glow_debug_view(GLOW_DEBUG_OPTIONS[index].id)
