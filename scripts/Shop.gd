# res://scripts/Shop.gd
extends VBoxContainer

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")

@onready var slots_container: HBoxContainer = %ShopSlotsContainer
@onready var buy_button: Button = %BuyButton
@onready var reroll_button: Button = %RerollButton
@onready var leave_button: Button = %LeaveButton

var _current_shop_instances: Array = []
var _selected_cost: int = 0
var _price_labels_container: HBoxContainer

func _ready() -> void:
	SignalBus.shop_stock_refreshed.connect(populate)
	SignalBus.selection_changed.connect(_on_selection_changed)

	buy_button.pressed.connect(_on_buy_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	# Create price labels container
	_price_labels_container = HBoxContainer.new()
	_price_labels_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_price_labels_container.add_theme_constant_override("separation", 20)
	add_child(_price_labels_container)
	move_child(_price_labels_container, 2) # Place after slots container
	
	# Add background input handling for the new InteractionContext system
	gui_input.connect(_on_gui_input)

func populate(context: Dictionary) -> void:
	_current_shop_instances = context.get("shop_instances", [])
	var reroll_cost: int = context.get("reroll_cost", 1)
	reroll_button.text = "Reroll (%d Gold)" % reroll_cost

	# Debug: Print info about the instances we received
	# print("Shop received instances: ", _current_shop_instances.size())
	for i in range(_current_shop_instances.size()):
		var inst = _current_shop_instances[i]
		if is_instance_valid(inst):
			var _def = inst.get_definition()
			# print("  [%d] UUID: %s, Type: %s, HP: %d, PWR: %d" % [
			# 	i,
			# 	inst.ball_uuid,
			# 	def.id if is_instance_valid(def) else "No Def",
			# 	inst.current_hp,
			# 	inst.current_pwr
			# ])

	# Clear existing price labels
	for child in _price_labels_container.get_children():
		child.queue_free()

	var slot_nodes = slots_container.get_children()

	for i in range(slot_nodes.size()):
		var slot_view = slot_nodes[i]
		for child in slot_view.get_children():
			child.queue_free()

		var loc = LocationIdentifier.new(&"Shop", i)
		slot_view.populate(loc)
		slot_view.set_interaction_context(&"SELECTION_ONLY", 0)

		var inst_for_slot = _find_instance_for_slot(i)
		if is_instance_valid(inst_for_slot):
			# Debug: Print instance info before populating the view
			var def = inst_for_slot.get_definition()
			# print("Populating slot ", i, " with instance: ", 
			# 	def.id if is_instance_valid(def) else "No Def", 
			# 	" (HP: ", inst_for_slot.current_hp, ", PWR: ", inst_for_slot.current_pwr, ")")
			
			var gacha_view = GachaBallViewScene.instantiate()
			slot_view.add_child(gacha_view)
			
			# Ensure the instance has valid stats before populating
			if inst_for_slot.current_hp <= 0 or inst_for_slot.current_pwr <= 0:
				print("Warning: Instance has invalid stats, resetting from definition")
				if is_instance_valid(def):
					inst_for_slot.current_hp = def.base_hp
					inst_for_slot.current_pwr = def.base_pwr
			
			gacha_view.populate(loc, inst_for_slot, true, false)
		
		# Always create a price label for each slot to maintain positioning
		var price_label = Label.new()
		if is_instance_valid(inst_for_slot):
			var shop_def = inst_for_slot.get_definition()
			var price = (shop_def.tier if (shop_def is GachaBallDefinition) else 1)
			price_label.text = "%d Gold" % price
		else:
			price_label.text = "" # Empty text for slots without items
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 12)
		price_label.custom_minimum_size = Vector2(120, 30)
		_price_labels_container.add_child(price_label)
	
	# Don't clear selection here as it might interfere with double-click inspection

func _find_instance_for_slot(slot_index: int) -> GachaBallInstance:
	for inst in _current_shop_instances:
		if is_instance_valid(inst) and inst.get_location().index == slot_index:
			return inst
	return null

## Handle selection changes from the new InteractionContext system
func _on_selection_changed(new_location: LocationIdentifier) -> void:
	if new_location and new_location.container == &"Shop":
		var instance = _find_instance_for_slot(new_location.index)
		if is_instance_valid(instance):
			var shop_def = instance.get_definition()
			_selected_cost = (shop_def.tier if (shop_def is GachaBallDefinition) else 1)
			buy_button.text = "Buy (%d Gold)" % _selected_cost
			buy_button.disabled = false
			return

	buy_button.text = "Buy"
	buy_button.disabled = true
	_selected_cost = 0

func _on_buy_pressed() -> void:
	# Get the currently selected location from the new InteractionManager
	var selected_ctx = GlobalInteractionRouter.get_current_selection()
	var selected_loc = selected_ctx.location if selected_ctx else null
	if selected_loc and selected_loc.container == &"Shop":
		var instance = _find_instance_for_slot(selected_loc.index)
		if is_instance_valid(instance):
			SignalBus.emit_signal("shop_purchase_requested", instance.ball_uuid, _selected_cost)

func _on_reroll_pressed() -> void:
	SignalBus.emit_signal("shop_reroll_requested")

func _on_leave_pressed() -> void:
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	# Handle background clicks using the new InteractionContext system
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Create and emit InteractionContext for shop background
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0 # Main window group
		
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()
