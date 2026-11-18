class_name GlossaryTogglePill
extends PanelContainer

@onready var toggle_button: Button = %ToggleButton

const FIXED_SIZE = Vector2(176, 30)

func _ready() -> void:
	custom_minimum_size = FIXED_SIZE
	size = FIXED_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	if is_instance_valid(toggle_button):
		toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
		toggle_button.pressed.connect(_on_pressed)
		toggle_button.clip_text = true
	SignalBus.glossary_lock_changed.connect(_on_glossary_lock_changed)
	_update_label(WindowManager.is_glossary_locked)

func _exit_tree() -> void:
	if SignalBus.glossary_lock_changed.is_connected(_on_glossary_lock_changed):
		SignalBus.glossary_lock_changed.disconnect(_on_glossary_lock_changed)

func _on_pressed() -> void:
	WindowManager.toggle_glossary_lock()

func _on_glossary_lock_changed(is_locked: bool) -> void:
	_update_label(is_locked)

func _update_label(is_locked: bool) -> void:
	if not is_instance_valid(toggle_button):
		return
	var font = Database.get_current_locale_font()
	toggle_button.add_theme_font_override("font", font)
	toggle_button.add_theme_font_size_override("font_size", 18)
	toggle_button.text = tr("ui.details")
	if is_locked:
		_set_font_color(Color("#FCD34D"))
	else:
		_set_font_color(Color("#F8FAFC"))
	custom_minimum_size = FIXED_SIZE
	size = FIXED_SIZE

func _set_font_color(color: Color) -> void:
	toggle_button.add_theme_color_override("font_color", color)
	toggle_button.add_theme_color_override("font_hover_color", color)
	toggle_button.add_theme_color_override("font_pressed_color", color)
	toggle_button.add_theme_color_override("font_hover_pressed_color", color)
	toggle_button.add_theme_color_override("font_focus_color", color)
