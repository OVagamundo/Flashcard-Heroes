import re

reward_gd_content = '''extends Control

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const TokenSpendScene = preload("res://scenes/vfx/TokenSpendVFX.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")
const ACTION_BUTTON_AVOID_SCOPE_META = "action_button_avoid_scope"

# Token costs
const COST_TIER1: int = 1
const COST_TIER2: int = 2
const COST_TIER3: int = 3

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var prize_lineup: HBoxContainer = %PrizeLineup
@onready var study_button: Button = %StudyButton
@onready var leave_button: Button = %LeaveButton
@onready var effects_layer: CanvasLayer = $EffectsLayer

# Machines
@onready var tier1_machine: Control = %Tier1Machine
@onready var tier2_machine: Control = %Tier2Machine
@onready var tier3_machine: Control = %Tier3Machine
@onready var tier1_draw_button: Button = %Tier1Machine.get_node("DrawButton")
@onready var tier2_draw_button: Button = %Tier2Machine.get_node("DrawButton")
@onready var tier3_draw_button: Button = %Tier3Machine.get_node("DrawButton")

var _tokens: int = 0
var _prizes: Array[GachaBallInstance] = [null, null, null, null, null]
var _has_studied: bool = false
var _action_in_progress: bool = false
var _last_inventory_open: bool = false

func _ready() -> void:
\tAudio.play_music(SoundRegistry.BGM_REWARD)
\t
\ttier1_draw_button.pressed.connect(_on_tier1_draw_pressed)
\ttier2_draw_button.pressed.connect(_on_tier2_draw_pressed)
\ttier3_draw_button.pressed.connect(_on_tier3_draw_pressed)
\tstudy_button.pressed.connect(_on_study_pressed)
\tleave_button.pressed.connect(_on_leave_pressed)
\t
\tFlashcardManager.minigame_finished.connect(_on_flashcard_completed)
\tSignalBus.flashcard_token_earned.connect(_on_live_token_earned)
\tSignalBus.selection_changed.connect(_on_selection_changed)
\t
\tSignalBus.reward_collect_zone_activated.connect(_on_collect_pressed)
\tSignalBus.reward_sell_zone_activated.connect(_on_sell_pressed)
\t
\tgui_input.connect(_on_gui_input)
\tSignalBus.locale_changed.connect(_update_localized_text)
\t_update_localized_text()
\t_mark_reward_action_buttons()
\t_setup_prize_slots()
\t
\t_update_token_display()
\tset_process(true)

func _process(_delta: float) -> void:
\tvar is_open := WindowManager.is_run_inventory_window_open()
\tif is_open != _last_inventory_open:
\t\t_last_inventory_open = is_open
\t\tvar main_node = GameManager._active_main_node
\t\tif is_instance_valid(main_node):
\t\t\tif not is_open:
\t\t\t\tif main_node.has_method("hide_reward_drop_zones"):
\t\t\t\t\tmain_node.hide_reward_drop_zones()

func _exit_tree() -> void:
\tif FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
\t\tFlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
\tif SignalBus.flashcard_token_earned.is_connected(_on_live_token_earned):
\t\tSignalBus.flashcard_token_earned.disconnect(_on_live_token_earned)
\tif SignalBus.reward_collect_zone_activated.is_connected(_on_collect_pressed):
\t\tSignalBus.reward_collect_zone_activated.disconnect(_on_collect_pressed)
\tif SignalBus.reward_sell_zone_activated.is_connected(_on_sell_pressed):
\t\tSignalBus.reward_sell_zone_activated.disconnect(_on_sell_pressed)

\tvar main_node = GameManager._active_main_node
\tif is_instance_valid(main_node) and main_node.has_method("hide_reward_drop_zones"):
\t\tmain_node.hide_reward_drop_zones()

func _mark_reward_action_buttons() -> void:
\t_mark_action_button_for_inspection_avoidance(study_button)
\t_mark_action_button_for_inspection_avoidance(leave_button)
\t_mark_action_button_for_inspection_avoidance(tier1_draw_button)
\t_mark_action_button_for_inspection_avoidance(tier2_draw_button)
\t_mark_action_button_for_inspection_avoidance(tier3_draw_button)

func _mark_action_button_for_inspection_avoidance(button: Button) -> void:
\tif is_instance_valid(button):
\t\tbutton.set_meta(ACTION_BUTTON_AVOID_SCOPE_META, &"Rewards")

func _update_localized_text() -> void:
\ttitle_label.text = tr("ui.choose_reward")
\tstudy_button.text = tr("ui.study")
\tleave_button.text = tr("ui.leave")
\ttier1_draw_button.text = "%d Token%s" % [COST_TIER1, "" if COST_TIER1 == 1 else "s"]
\ttier2_draw_button.text = "%d Token%s" % [COST_TIER2, "" if COST_TIER2 == 1 else "s"]
\ttier3_draw_button.text = "%d Token%s" % [COST_TIER3, "" if COST_TIER3 == 1 else "s"]

func _setup_prize_slots() -> void:
\tvar slots = prize_lineup.get_children()
\tfor i in range(slots.size()):
\t\tvar slot_view = slots[i]
\t\tslot_view.set_size_scale(2.0)
\t\tfor child in slot_view.get_children():
\t\t\tif child is TextureRect and (child.z_index == 10 or child.z_index == -1): continue
\t\t\tchild.queue_free()
\t\t
\t\tvar loc = LocationIdentifier.new(&"Rewards", i)
\t\tslot_view.populate(loc)
\t\tslot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)

# --- Token Logic ---

func _on_study_pressed() -> void:
\tif _has_studied or _action_in_progress: return
\t_has_studied = true
\tstudy_button.disabled = true
\tif is_instance_valid(GameManager.run_state):
\t\tFlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func _on_live_token_earned(amount: int) -> void:
\t_tokens += amount
\t_update_token_display()

func _on_flashcard_completed(_results: Dictionary) -> void:
\tpass

func _update_token_display() -> void:
\tSignalBus.emit_signal("gacha_tokens_changed", _tokens)

# --- Draw Logic ---

func _on_tier1_draw_pressed() -> void:
\t_try_draw_tier(1, COST_TIER1, tier1_machine)

func _on_tier2_draw_pressed() -> void:
\t_try_draw_tier(2, COST_TIER2, tier2_machine)

func _on_tier3_draw_pressed() -> void:
\t_try_draw_tier(3, COST_TIER3, tier3_machine)

func _try_draw_tier(tier: int, cost: int, machine: Control) -> void:
\tif _action_in_progress: return
\t
\tvar main_node = GameManager._active_main_node
\tvar token_group = main_node.get_node_or_null("%TokenGroup") if is_instance_valid(main_node) else null
\t
\tif _tokens < cost:
\t\tRejectionFeedbackScript.play_rejection_with_counter(machine, token_group, get_tree())
\t\treturn
\t
\tvar slot_index = _find_next_prize_slot()
\tif slot_index == -1:
\t\t# Lineup full
\t\tRejectionFeedbackScript.play_rejection_with_counter(machine, null, get_tree())
\t\treturn
\t
\t_action_in_progress = true
\tvar button = machine.get_node("DrawButton")
\tbutton.disabled = true
\t
\tawait _animate_token_spend(machine, cost, token_group)
\t
\t_tokens -= cost
\t_update_token_display()
\t
\tvar definition = _draw_definition_for_tier(tier)
\tvar instance = GachaBallInstance.new()
\tinstance.initialize(definition)
\t
\t# Animate draw and add prize
\tawait _animate_prize_draw(machine, slot_index, instance)
\t_prizes[slot_index] = instance
\t_populate_prize_slot(slot_index, instance)
\t
\tbutton.disabled = false
\t_action_in_progress = false

func _draw_definition_for_tier(tier: int) -> GachaBallDefinition:
\tvar eligible: Array[GachaBallDefinition] = []
\tfor definition in Database.get_all_pool_definitions():
\t\tif not is_instance_valid(definition): continue
\t\tif definition.tier != tier: continue
\t\teligible.append(definition)
\t
\tif eligible.is_empty():
\t\treturn null
\treturn eligible[randi() % eligible.size()]

func _find_next_prize_slot() -> int:
\tfor i in range(_prizes.size()):
\t\tif _prizes[i] == null:
\t\t\treturn i
\treturn -1

# --- Animations ---

func _animate_token_spend(target_machine: Control, cost: int, token_group: Control) -> void:
\tvar start_pos: Vector2
\tif is_instance_valid(token_group):
\t\tvar token_rect = token_group.get_global_rect()
\t\tstart_pos = token_rect.get_center()
\telse:
\t\tstart_pos = Vector2(get_viewport_rect().size.x / 2, 60)
\t
\tvar machine_rect = target_machine.get_global_rect()
\tvar target_pos = Vector2(machine_rect.get_center().x, machine_rect.position.y + machine_rect.size.y * 0.4)
\t
\tvar stagger_delay = 0.12
\tfor i in range(cost):
\t\tvar token_vfx = TokenSpendScene.instantiate()
\t\teffects_layer.add_child(token_vfx)
\t\ttoken_vfx.coin_landed.connect(_on_coin_landed.bind(target_machine))
\t\tAudio.play_sfx("token_spend", 1.0 + (i * 0.05))
\t\tvar offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
\t\ttoken_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
\t
\tawait get_tree().create_timer((cost - 1) * stagger_delay + 0.55).timeout

func _on_coin_landed(_target_pos: Vector2, machine: Control) -> void:
\tif not is_instance_valid(machine): return
\tAudio.play_sfx("token_land")
\tmachine.pivot_offset = Vector2(machine.size.x / 2, machine.size.y)
\tvar tween = create_tween().set_parallel(true)
\ttween.tween_property(machine, "scale", Vector2(1.03, 0.97), 0.04)
\ttween.tween_property(machine, "scale", Vector2(0.98, 1.02), 0.06).set_delay(0.04)
\ttween.tween_property(machine, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.10).set_trans(Tween.TRANS_ELASTIC)

func _animate_prize_draw(machine: Control, slot_index: int, instance: GachaBallInstance) -> void:
\tvar start_pos = machine.get_node("DrawButton").get_global_rect().get_center()
\tvar target_slot = prize_lineup.get_child(slot_index)
\tvar end_pos = target_slot.get_global_rect().get_center()
\t
\tvar anim_ball = GachaBallViewScene.instantiate()
\teffects_layer.add_child(anim_ball)
\tanim_ball.force_inventory_mode = true
\tanim_ball.custom_minimum_size = Vector2(128, 128)
\tanim_ball.size = Vector2(128, 128)
\tanim_ball.populate(null, VisualDataAdapter.create_visual_data(instance))
\tanim_ball.pivot_offset = anim_ball.size / 2.0
\t
\tvar control_point = Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - 200)
\tvar tween = create_tween()
\ttween.tween_method(func(t: float):
\t\tvar eased_t = pow(t, 0.55)
\t\tvar scale_eased = 1.0 - pow(1.0 - t, 2)
\t\tvar current_scale = lerp(0.3, 1.0, scale_eased)
\t\tanim_ball.scale = Vector2(current_scale, current_scale)
\t\tvar inv_t = 1.0 - eased_t
\t\tvar pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
\t\tanim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
\t, 0.0, 1.0, 0.45)
\t
\tawait tween.finished
\tanim_ball.queue_free()

func _populate_prize_slot(slot_index: int, instance: GachaBallInstance) -> void:
\tvar slot = prize_lineup.get_child(slot_index)
\tif slot.has_method("set_content"):
\t\tslot.set_content(VisualDataAdapter.create_visual_data(instance), true, false)

func _clear_prize_slot(slot_index: int) -> void:
\t_prizes[slot_index] = null
\tvar slot = prize_lineup.get_child(slot_index)
\tif slot.has_method("set_content"):
\t\tslot.set_content({}, false, false)

# --- Service Overlay & Drag Drop ---

func _on_selection_changed(new_location: LocationIdentifier) -> void:
\t# Drop zone visibility is handled by Main.gd via the same signal
\tpass

func _get_selected_prize() -> Dictionary:
\tvar selected_ctx = GlobalInteractionRouter.get_current_selection()
\tif selected_ctx == null: return {}
\tvar selected_loc = selected_ctx.location if selected_ctx else null
\tif not is_instance_valid(selected_loc): return {}
\tif selected_loc.container != &"Rewards": return {}
\t
\tvar instance = _prizes[selected_loc.index]
\tif not is_instance_valid(instance): return {}
\t
\treturn {
\t\t"location": selected_loc,
\t\t"instance": instance,
\t\t"uuid": instance.ball_uuid
\t}

func _on_collect_pressed() -> void:
\tif _action_in_progress: return
\tvar prize_data = _get_selected_prize()
\tif prize_data.is_empty(): return
\t
\t_action_in_progress = true
\t
\tvar loc = prize_data.location
\tvar instance = prize_data.instance
\tvar uuid = prize_data.uuid
\t
\t_clear_prize_slot(loc.index)
\tSignalBus.emit_signal("selection_clear_requested")
\t
\tvar start_pos = _get_slot_global_center(loc.index)
\tvar visual_data = VisualDataAdapter.create_visual_data(instance)
\tvar def = instance.get_definition()
\tvar tier: int = 1
\tvar target_trinket_slot: int = -1
\tif def is GachaBallDefinition: tier = int(def.tier)
\tif is_instance_valid(def) and def.category == &"TRINKET":
\t\ttier = -1
\t\tif is_instance_valid(GameManager.run_state):
\t\t\tvar trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
\t\t\tif trinket_container and trinket_container.has_method("find_first_empty_slot"):
\t\t\t\ttarget_trinket_slot = trinket_container.find_first_empty_slot()
\t\t\t\tif target_trinket_slot < 0: target_trinket_slot = 0
\t
\tvar main_node = GameManager._active_main_node
\tif is_instance_valid(main_node) and main_node.has_method("hide_reward_drop_zones"):
\t\tmain_node.hide_reward_drop_zones()
\t
\tif tier != -1:
\t\t# Important: Add the instance to the RunState temporarily or emit the signal that usually adds it
\t\t# Since we instantiated it locally, we must pass it to the inventory manager or emit reward_chosen
\t\t# We will use the existing reward_chosen signal, but we need to pass the actual instance!
\t\t# Wait, the signal expects it to be in GameManager. Let's add it to run_instances manually so it can be found.
\t\tif is_instance_valid(GameManager.run_state):
\t\t\tGameManager.run_state.run_instances[uuid] = instance
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
\t\t_animate_gachaball_to_machine(start_pos, visual_data, tier, func(): _action_in_progress = false)
\telse:
\t\tif is_instance_valid(GameManager.run_state):
\t\t\tGameManager.run_state.run_instances[uuid] = instance
\t\t_animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid, func(): _action_in_progress = false)

func _on_sell_pressed() -> void:
\tif _action_in_progress: return
\tvar prize_data = _get_selected_prize()
\tif prize_data.is_empty(): return
\t
\t_action_in_progress = true
\t
\tvar loc = prize_data.location
\tvar instance = prize_data.instance
\tvar def = instance.get_definition()
\tvar tier = int(def.tier) if "tier" in def else 1
\tvar level = 1 # Assuming level 1 for drawn rewards
\tvar gold_yield = int(tier * level * 0.5)
\tif gold_yield < 1: gold_yield = 1
\t
\t_clear_prize_slot(loc.index)
\tSignalBus.emit_signal("selection_clear_requested")
\t
\tvar main_node = GameManager._active_main_node
\tif is_instance_valid(main_node) and main_node.has_method("hide_reward_drop_zones"):
\t\tmain_node.hide_reward_drop_zones()
\t
\tvar start_pos = _get_slot_global_center(loc.index)
\t_animate_gold_receive(gold_yield, start_pos, func():
\t\tif is_instance_valid(GameManager.run_state):
\t\t\tGameManager.run_state.add_gold(gold_yield)
\t\t_action_in_progress = false
\t)

func _get_slot_global_center(index: int) -> Vector2:
\tvar slot_view = prize_lineup.get_child(index)
\tvar start_pos: Vector2 = Vector2.ZERO
\tif is_instance_valid(slot_view):
\t\tstart_pos = slot_view.get_global_rect().get_center()
\t\tvar main_node = GameManager._active_main_node
\t\tif is_instance_valid(main_node):
\t\t\tvar content_area = main_node.get_node_or_null("%ContentArea")
\t\t\tif is_instance_valid(content_area):
\t\t\t\tstart_pos += content_area.global_position
\treturn start_pos

func _animate_gachaball_to_machine(start_pos: Vector2, visual_data: Dictionary, tier: int, on_complete: Callable) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\ton_complete.call()
\t\treturn
\t
\tvar machine = main_node.get_node_or_null("%%GachaMachine%d" % tier)
\tif not is_instance_valid(machine):
\t\ton_complete.call()
\t\treturn
\t
\tvar end_pos: Vector2 = machine.get_global_rect().get_center()
\tend_pos.y = machine.get_global_rect().position.y + machine.get_global_rect().size.y * 0.4
\t
\tvar anim_ball = GachaBallViewScene.instantiate()
\tAudio.play_sfx("ui_drag_drop")
\t
\teffects_layer.add_child(anim_ball)
\tanim_ball.force_inventory_mode = true
\tanim_ball.custom_minimum_size = Vector2(192, 192)
\tanim_ball.size = Vector2(192, 192)
\tanim_ball.populate(null, visual_data)
\tanim_ball.pivot_offset = anim_ball.size / 2.0
\t
\tvar constant_scale := 1.0
\tanim_ball.scale = Vector2(constant_scale, constant_scale)
\tanim_ball.global_position = start_pos - (anim_ball.pivot_offset * constant_scale)
\t
\tvar arc_height := 200.0
\tvar duration := 0.45
\tvar control_point := Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - arc_height)
\t
\tvar tween = anim_ball.create_tween()
\ttween.set_trans(Tween.TRANS_LINEAR)
\ttween.tween_method(func(t: float):
\t\tvar eased_t = pow(t, 1.05)
\t\tvar inv_t = 1.0 - eased_t
\t\tvar pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
\t\tanim_ball.global_position = pos - (anim_ball.pivot_offset * constant_scale)
\t, 0.0, 1.0, duration)
\t
\ttween.tween_callback(func():
\t\tAudio.play_sfx("coin_land")
\t\tanim_ball.queue_free()
\t\tif main_node.has_method("trigger_machine_bounce"):
\t\t\tmain_node.trigger_machine_bounce(tier)
\t\ton_complete.call()
\t)

func _animate_gachaball_to_trinket_bar(start_pos: Vector2, visual_data: Dictionary, target_slot_index: int, instance_uuid: String, on_complete: Callable) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
\t\ton_complete.call()
\t\treturn
\t
\tvar trinket_bar = main_node.get_node_or_null("%PlayerTrinketBar")
\tif not is_instance_valid(trinket_bar):
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
\t\ton_complete.call()
\t\treturn
\t
\tvar slot_count = trinket_bar.get_child_count()
\ttarget_slot_index = clampi(target_slot_index, 0, slot_count - 1)
\tvar target_slot = trinket_bar.get_child(target_slot_index) if target_slot_index < slot_count else null
\tif not is_instance_valid(target_slot):
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
\t\ton_complete.call()
\t\treturn
\t
\tvar end_pos: Vector2 = target_slot.get_global_rect().get_center()
\tvar anim_ball = GachaBallViewScene.instantiate()
\teffects_layer.add_child(anim_ball)
\tanim_ball.force_inventory_mode = true
\tvar target_rect_size: Vector2 = target_slot.get_global_rect().size
\tvar target_visual_size := minf(target_rect_size.x, target_rect_size.y)
\tif target_visual_size <= 0.0: target_visual_size = 96.0
\tanim_ball.custom_minimum_size = Vector2(target_visual_size, target_visual_size)
\tanim_ball.size = Vector2(target_visual_size, target_visual_size)
\tanim_ball.populate(null, visual_data)
\tanim_ball.pivot_offset = anim_ball.size / 2.0
\tanim_ball.global_position = start_pos - anim_ball.pivot_offset
\t
\tvar arc_height := 400.0
\tvar duration := 0.45
\tvar control_point := Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - arc_height)
\t
\tvar tween = create_tween()
\ttween.set_trans(Tween.TRANS_LINEAR)
\ttween.tween_method(func(t: float):
\t\tvar eased_t = pow(t, 0.55)
\t\tvar scale_eased = 1.0 - pow(1.0 - t, 2)
\t\tvar current_scale = lerp(0.3, 1.0, scale_eased)
\t\tanim_ball.scale = Vector2(current_scale, current_scale)
\t\tvar inv_t = 1.0 - eased_t
\t\tvar pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
\t\tanim_ball.global_position = pos - (anim_ball.pivot_offset * current_scale)
\t, 0.0, 1.0, duration)
\t
\ttween.tween_callback(func():
\t\tanim_ball.queue_free()
\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": instance_uuid})
\t\ton_complete.call()
\t)

func _animate_gold_receive(amount: int, start_pos: Vector2, on_complete: Callable) -> void:
\tvar main_node = GameManager._active_main_node
\tif not is_instance_valid(main_node):
\t\ton_complete.call()
\t\treturn
\t
\tvar gold_group = main_node.get_node_or_null("%GoldGroup")
\tif not is_instance_valid(gold_group):
\t\ton_complete.call()
\t\treturn
\t
\tvar gold_icon = gold_group.get_node_or_null("GoldIcon")
\tif not is_instance_valid(gold_icon): gold_icon = gold_group
\t
\tvar gold_rect = gold_icon.get_global_rect()
\tvar target_pos = Vector2(gold_rect.position.x + gold_rect.size.x / 2, gold_rect.position.y + gold_rect.size.y / 2)
\t
\tvar coins_to_spawn = mini(amount, 5)
\tvar stagger_delay = 0.08
\t
\tfor i in range(coins_to_spawn):
\t\tvar coin_vfx = GoldCoinVFXScene.new()
\t\teffects_layer.add_child(coin_vfx)
\t\tcoin_vfx.coin_landed.connect(func(_pos: Vector2):
\t\t\tAudio.play_sfx("coin_land")
\t\t\tif is_instance_valid(gold_group):
\t\t\t\tvar tween = gold_group.create_tween()
\t\t\t\tgold_group.pivot_offset = gold_group.size / 2.0
\t\t\t\ttween.tween_property(gold_group, "scale", Vector2(1.2, 1.2), 0.05)
\t\t\t\ttween.tween_property(gold_group, "scale", Vector2(1.0, 1.0), 0.1)
\t\t)
\t\tvar offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
\t\tcoin_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
\t\tAudio.play_sfx("coin_spawn", 1.0 + (i * 0.05))
\t
\tvar total_wait = (coins_to_spawn - 1) * stagger_delay + 0.45
\tvar wait_tween = create_tween()
\twait_tween.tween_interval(total_wait)
\twait_tween.tween_callback(on_complete)

func _on_leave_pressed() -> void:
\tif _action_in_progress: return
\t
\t# Auto collect sequence
\t_action_in_progress = true
\tleave_button.disabled = true
\tstudy_button.disabled = true
\ttier1_draw_button.disabled = true
\ttier2_draw_button.disabled = true
\ttier3_draw_button.disabled = true
\t
\tvar main_node = GameManager._active_main_node
\tif is_instance_valid(main_node) and main_node.has_method("hide_reward_drop_zones"):
\t\tmain_node.hide_reward_drop_zones()
\t
\t# Collect all remaining sequentially
\tfor i in range(_prizes.size()):
\t\tvar instance = _prizes[i]
\t\tif is_instance_valid(instance):
\t\t\t# Set selection context so we can re-use _on_collect_pressed? Or just run logic manually.
\t\t\tvar uuid = instance.ball_uuid
\t\t\tvar def = instance.get_definition()
\t\t\tvar tier: int = int(def.tier) if "tier" in def else 1
\t\t\tvar target_trinket_slot: int = -1
\t\t\tif is_instance_valid(def) and def.category == &"TRINKET":
\t\t\t\ttier = -1
\t\t\t\tif is_instance_valid(GameManager.run_state):
\t\t\t\t\tvar trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
\t\t\t\t\tif trinket_container and trinket_container.has_method("find_first_empty_slot"):
\t\t\t\t\t\ttarget_trinket_slot = trinket_container.find_first_empty_slot()
\t\t\t\t\t\tif target_trinket_slot < 0: target_trinket_slot = 0
\t\t\t
\t\t\tvar start_pos = _get_slot_global_center(i)
\t\t\tvar visual_data = VisualDataAdapter.create_visual_data(instance)
\t\t\t
\t\t\t_clear_prize_slot(i)
\t\t\t
\t\t\tvar anim_completed = false
\t\t\t
\t\t\tif tier != -1:
\t\t\t\tif is_instance_valid(GameManager.run_state):
\t\t\t\t\tGameManager.run_state.run_instances[uuid] = instance
\t\t\t\tSignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
\t\t\t\t_animate_gachaball_to_machine(start_pos, visual_data, tier, func(): anim_completed = true)
\t\t\telse:
\t\t\t\tif is_instance_valid(GameManager.run_state):
\t\t\t\t\tGameManager.run_state.run_instances[uuid] = instance
\t\t\t\t_animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid, func(): anim_completed = true)
\t\t\t
\t\t\twhile not anim_completed:
\t\t\t\tawait get_tree().process_frame
\t
\tSignalBus.emit_signal("gacha_tokens_changed", 0)
\tSignalBus.emit_signal("path_choice_scene_requested")
\tqueue_free()

func _on_gui_input(event: InputEvent) -> void:
\tif InputUtils.is_primary_pointer_press(event):
\t\tvar context = InteractionContext.new()
\t\tcontext.source_view_instance_id = get_instance_id()
\t\tcontext.event_type = &"SINGLE_CLICK"
\t\tcontext.location = null
\t\tcontext.entity_uuid = ""
\t\tcontext.entity_type = &"WINDOW_BACKGROUND"
\t\tcontext.interaction_mode = &"FULLY_INTERACTIVE"
\t\tcontext.window_group_id = 0
\t\tSignalBus.emit_signal("interaction_context_received", context)
\t\tget_viewport().set_input_as_handled()

func populate(context: Dictionary) -> void:
\t# Fallback in case GameManager calls populate(). With the new flow, we don't use context rewards.
\tpass
'''

with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/Reward.gd', 'w', encoding='utf-8') as f:
    f.write(reward_gd_content)
print('Reward.gd completely rewritten')
