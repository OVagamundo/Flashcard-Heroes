<!-- Original: scripts/ItemInspectionWindow.gd -->

```gdscript
class_name ItemInspectionWindow
extends "res://scripts/InspectionWindow.gd"

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier

func _ready():
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	# Allow clicks on the description area to propagate to the root window so
	# WindowManager can register background clicks. Identical behaviour to
	# UnitInspectionWindow.
	description_label.mouse_filter = MOUSE_FILTER_PASS
	description_label.meta_hover_started.connect(func(_m): description_label.mouse_filter = MOUSE_FILTER_STOP)
	description_label.meta_hover_ended.connect(func(_m): description_label.mouse_filter = MOUSE_FILTER_PASS)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# TDD Rule: Clicking a window's background closes its children, but not itself or its parents.
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		printerr("ItemInspectionWindow: Invalid context provided.")
		queue_free()
		return

	var item_def = _instance.get_definition()
	if not is_instance_valid(item_def):
		queue_free()
		return

	name_label.text = tr(item_def.display_name_key)
	var description_text = tr(item_def.description_key)
	
	# Add item effect description
	var effect_desc = ""
	if item_def.bonus_hp > 0 and item_def.bonus_pwr > 0:
		effect_desc = tr("item.effect.both").replace("(HP)", str(item_def.bonus_hp)).replace("(PWR)", str(item_def.bonus_pwr))
	elif item_def.bonus_hp > 0:
		effect_desc = tr("item.effect.hp").replace("(HP)", str(item_def.bonus_hp))
	elif item_def.bonus_pwr > 0:
		effect_desc = tr("item.effect.pwr").replace("(PWR)", str(item_def.bonus_pwr))
	
	if not effect_desc.is_empty():
		description_label.text = "%s\n\n%s\n\n[url=effect]EFFECTS[/url]" % [description_text, effect_desc]
	else:
		description_label.text = "%s\n\n[url=effect]EFFECTS[/url]" % description_text
	
	# Store the full definition for the child window to use.
	description_label.set_meta("effect_definition", item_def)

func _on_description_meta_clicked(meta):
	if meta == "effect":
		var definition = description_label.get_meta("effect_definition")
		if definition:
			var context = {"effect_definition": definition.ability_definitions}
			var child_context = context.duplicate()
			child_context["source_view"] = _source_view
			WindowManager.open_child_inspection_window(self, &"EffectInspection", child_context)

```