# res://scripts/Shop.gd
extends EncounterBase

@onready var slots_container: HBoxContainer = %ShopSlotsContainer
@onready var reroll_button: Button = %RerollButton
@onready var leave_button: Button = %LeaveButton
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel

var _current_shop_instances: Array = []
var _price_tag_nodes: Array[Control] = []
var _current_reroll_cost: int = 1


func _ready() -> void:
	SignalBus.shop_stock_refreshed.connect(populate)
	SignalBus.confirm_drop_zone_activated.connect(_on_buy_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	gui_input.connect(_handle_window_background_click)

	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_mark_action_buttons_for_avoidance([reroll_button, leave_button], &"Shop")

	Audio.play_music(SoundRegistry.BGM_SHOP)


func _update_localized_text() -> void:
	title_label.text = tr("ui.shop")
	if is_instance_valid(description_label):
		description_label.text = tr("ui.shop_desc")
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost
	leave_button.text = tr("ui.leave")


func populate(context: Dictionary) -> void:
	_current_shop_instances = context.get("shop_instances", [])
	_current_reroll_cost = context.get("reroll_cost", 1)
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost

	var slot_nodes: Array[Node] = slots_container.get_children()
	for i: int in range(slot_nodes.size()):
		var slot_view: SlotView = slot_nodes[i] as SlotView
		slot_view.visible = true
		slot_view.modulate.a = 1.0
		slot_view.set_size_scale(2.0)
		for child in slot_view.get_children():
			if child is TextureRect and (child.z_index == 10 or child.z_index == -1):
				continue
			child.queue_free()

		slot_view.populate(LocationIdentifier.new(&"Shop", i))
		slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)

		var inst_for_slot: GachaBallInstance = _find_instance_for_slot(i)
		if is_instance_valid(inst_for_slot):
			var ball_view: GachaBallView = slot_view.set_content(VisualDataAdapter.create_visual_data(inst_for_slot), true)
			if is_instance_valid(ball_view):
				ball_view.visible = false
				ball_view.scale = Vector2.ONE

	_update_fixed_price_tags()
	_animate_staggered_slot_entry(slots_container)


func _update_fixed_price_tags() -> void:
	const TAG_W: float = 84.0
	const TAG_H: float = 38.0

	if _price_tag_nodes.is_empty():
		for i: int in range(3):
			var tag: Control = _create_price_tag_node(TAG_W, TAG_H)
			add_child(tag)
			_price_tag_nodes.append(tag)

	await get_tree().process_frame

	var slot_nodes: Array[Node] = slots_container.get_children()
	for i: int in range(slot_nodes.size()):
		if i >= _price_tag_nodes.size():
			break
		var tag: Control = _price_tag_nodes[i]
		var slot: Control = slot_nodes[i] as Control
		var inst: GachaBallInstance = _find_instance_for_slot(i)
		tag.global_position = slot.global_position + Vector2(slot.size.x - TAG_W, 0.0)

		var lbl: Label = tag.get_node_or_null("PriceLabel") as Label
		if is_instance_valid(lbl):
			if is_instance_valid(inst):
				lbl.text = tr("ui.gold_price") % GameManager.get_item_cost(inst.get_definition())
			else:
				lbl.text = "Sold!"


func _create_price_tag_node(w: float, h: float) -> Control:
	var tag_wrapper := Control.new()
	tag_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_wrapper.z_index = 5
	tag_wrapper.size = Vector2(w, h)

	var tag_texture := TextureRect.new()
	tag_texture.name = "PriceTagTexture"
	tag_texture.texture = load("res://assets/PixelArt/ui/textures/PriceTag.png")
	tag_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tag_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tag_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag_texture.set_offsets_preset(Control.PRESET_FULL_RECT)
	tag_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_wrapper.add_child(tag_texture)

	var price_label := Label.new()
	price_label.name = "PriceLabel"
	price_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	price_label.set_offsets_preset(Control.PRESET_FULL_RECT)
	price_label.offset_left = 18
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color("#000000"))
	price_label.add_theme_constant_override("outline_size", 0)
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_wrapper.add_child(price_label)

	return tag_wrapper


func _find_instance_for_slot(slot_index: int) -> GachaBallInstance:
	for inst in _current_shop_instances:
		if inst is GachaBallInstance and is_instance_valid(inst) and (inst as GachaBallInstance).get_location().index == slot_index:
			return inst as GachaBallInstance
	return null


func _on_buy_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	var selected_ctx: InteractionContext = GlobalInteractionRouter.get_current_selection()
	var selected_loc: LocationIdentifier = selected_ctx.location if selected_ctx != null else null
	if selected_loc == null or selected_loc.container != &"Shop":
		return
	var instance: GachaBallInstance = _find_instance_for_slot(selected_loc.index)
	if not is_instance_valid(instance):
		return

	var actual_cost: int = GameManager.get_item_cost(instance.get_definition())
	var current_gold: int = GameManager.run_state.gold if is_instance_valid(GameManager.run_state) else 0
	var drop: Dictionary = _resolve_drop_interaction(is_drag, mouse_pos)
	var drop_pos: Vector2 = drop["drop_pos"]

	if current_gold < actual_cost:
		var main_node: Node = GameManager._active_main_node
		var gold_group: Control = main_node.get_node_or_null("%GoldGroup") as Control if is_instance_valid(main_node) else null
		var drop_zone: Control = main_node.get_node_or_null("%ConfirmDropZone") as Control if is_instance_valid(main_node) else null
		var rejection_target: Control = drop_zone if is_instance_valid(drop_zone) else reroll_button
		RejectionFeedbackScript.play_rejection_with_counter(rejection_target, gold_group, get_tree())
		if is_drag:
			ActionQueue.request(CancelDragAction.new(selected_loc, null, "insufficient_gold", drop_pos))
		else:
			GlobalInteractionRouter.apply_deselect_entity()
		return

	var action := BuyShopAction.new(selected_loc.index, actual_cost, String(instance.definition_id), drop["interaction_type"], drop_pos)
	if not ActionQueue.request(action):
		if is_drag:
			ActionQueue.request(CancelDragAction.new(selected_loc, null, "action_rejected", drop_pos))
		else:
			GlobalInteractionRouter.apply_deselect_entity()


func play_transaction_log(event_log: Dictionary) -> void:
	if not event_log.get("success", false):
		_finish_active_action()
		return
	var slot_index: int = int(event_log.get("slot_index", -1))
	var cost: int = int(event_log.get("cost", 0))
	var instance: GachaBallInstance = event_log.get("purchased_instance", null) as GachaBallInstance
	var drop_pos: Vector2 = event_log.get("drop_pos", Vector2.ZERO)
	execute_buy_visuals(slot_index, cost, instance, drop_pos)


func execute_buy_visuals(slot_index: int, cost: int, instance: GachaBallInstance = null, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(instance):
		instance = _find_instance_for_slot(slot_index)
	if not is_instance_valid(instance):
		_finish_active_action()
		return

	var interaction_pos: Vector2 = _consume_animation_start_pos(_get_content_slot_global_center(slots_container, slot_index), p_drop_pos)
	var visual_data: Dictionary = VisualDataAdapter.create_visual_data(instance)
	var def: Resource = instance.get_definition()
	var tier: int = int((def as GachaBallDefinition).tier) if def is GachaBallDefinition else 1
	if is_instance_valid(def) and "category" in def and def.category == &"TRINKET":
		tier = 3

	var source_anchor: Node = WindowManager.find_view_for_location(LocationIdentifier.new(&"Shop", slot_index))
	if is_instance_valid(source_anchor):
		for child in source_anchor.get_children():
			if child is GachaBallView:
				(child as GachaBallView).modulate.a = 0.0
				(child as GachaBallView).visible = false

	var vfx_ball: GachaBallView = _spawn_vfx_gachaball(visual_data, Vector2(192, 192), false, true)
	vfx_ball.set_is_interactive(false)
	vfx_ball.global_position = interaction_pos - vfx_ball.pivot_offset

	CurrencyAnimator.animate_gold_spend(cost, interaction_pos, func() -> void:
		Audio.play_sfx("shop_buy")
		_animate_shop_ball_to_machine(vfx_ball, interaction_pos, tier)
		var main_node: Node = GameManager._active_main_node
		if is_instance_valid(main_node):
			main_node.hide_confirm_drop_zone()
		_finish_active_action()
	)


func _on_reroll_pressed() -> void:
	var current_gold: int = GameManager.run_state.gold if is_instance_valid(GameManager.run_state) else 0
	if current_gold < _current_reroll_cost:
		var main_node: Node = GameManager._active_main_node
		var gold_group: Control = main_node.get_node_or_null("%GoldGroup") as Control if is_instance_valid(main_node) else null
		RejectionFeedbackScript.play_rejection_with_counter(reroll_button, gold_group, get_tree())
		return
	ActionQueue.request(RerollShopAction.new())


func execute_reroll_visuals(cost: int = -1) -> void:
	reroll_button.disabled = true
	var target_pos: Vector2 = reroll_button.get_global_rect().get_center()
	var spend_cost: int = cost if cost >= 0 else _current_reroll_cost
	CurrencyAnimator.animate_gold_spend(spend_cost, target_pos, func() -> void:
		SignalBus.selection_clear_requested.emit()
		Audio.play_sfx("shop_reroll")
		reroll_button.disabled = false
		_finish_active_action()
	)


func _animate_shop_ball_to_machine(anim_ball: GachaBallView, start_pos: Vector2, tier: int) -> void:
	if not is_instance_valid(anim_ball):
		return
	var main_node: Node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		anim_ball.queue_free()
		return
	var machine: Control = main_node.get_gacha_machine(tier) as Control
	if not is_instance_valid(machine):
		anim_ball.queue_free()
		return

	var machine_rect: Rect2 = machine.get_global_rect()
	var end_pos := Vector2(machine_rect.get_center().x, machine_rect.position.y + machine_rect.size.y * 0.4)
	Audio.play_sfx("ui_drag_drop")

	var tween: Tween = ArcTossAnimator.toss_bezier(anim_ball, start_pos, end_pos, {
		"arc_height": 200.0,
		"duration": 0.45,
		"ease_power": 1.05,
	})
	tween.tween_callback(func() -> void:
		Audio.play_sfx("coin_land")
		anim_ball.queue_free()
		if is_instance_valid(main_node):
			main_node.animate_machine_inventory_change(tier, 1)
	)


func _on_leave_pressed() -> void:
	ActionQueue.request(LeaveShopAction.new())


func execute_leave_visuals() -> void:
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_confirm_drop_zone()
	SignalBus.path_choice_scene_requested.emit()
	queue_free()
