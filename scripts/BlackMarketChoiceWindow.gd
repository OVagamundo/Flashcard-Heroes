class_name BlackMarketChoiceWindow
extends PanelContainer

const InputUtils = preload("res://scripts/InputUtils.gd")

signal remove_requested
signal transform_requested

@onready var prompt_label: Label = %PromptLabel
@onready var remove_button: Button = %RemoveButton
@onready var transform_button: Button = %TransformButton

var _item_name: String = ""
var _remove_cost: int = 5
var _transform_cost: int = 5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	remove_button.pressed.connect(func(): remove_requested.emit())
	transform_button.pressed.connect(func(): transform_requested.emit())
	gui_input.connect(_on_gui_input)
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

func _exit_tree() -> void:
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)

func populate(item_name: String, remove_cost: int, transform_cost: int) -> void:
	_item_name = item_name
	_remove_cost = remove_cost
	_transform_cost = transform_cost
	_update_localized_text()

func _update_localized_text() -> void:
	prompt_label.text = tr("ui.black_market_prompt") % _item_name
	remove_button.text = tr("ui.remove_cost") % _remove_cost
	transform_button.text = tr("ui.transform_cost") % _transform_cost

func _on_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		get_viewport().set_input_as_handled()
		accept_event()
