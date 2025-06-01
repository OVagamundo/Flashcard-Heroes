extends Control

@onready var player_units_container: HBoxContainer = $MainContainer/BattleArea/PlayerSide/PlayerUnits
@onready var enemy_units_container: HBoxContainer = $MainContainer/BattleArea/EnemySide/EnemyUnits
@onready var battle_log: TextEdit = $BattleLog
@onready var end_turn_button: Button = $MainContainer/Actions/EndTurnButton
@onready var gacha_button: Button = $MainContainer/Actions/GachaButton
@onready var player_health_label: Label = $MainContainer/Header/PlayerInfo/PlayerHealth
@onready var gacha_tokens_label: Label = $MainContainer/Header/PlayerInfo/GachaTokens
@onready var turn_indicator: Label = $MainContainer/Header/TurnIndicator
var unit_info_modal = null

const MAX_UNITS_PER_SIDE = 6 # As per GDD
const UNIT_SCENE = preload("res://scenes/Unit.tscn")

# Gacha system variables
var gacha_tokens: int = 5  # Starting Gacha Tokens as per GDD

# Arrays to hold references to the UnitSlot instances in the scene
var player_lineup_slots: Array[UnitSlot] = []
var enemy_lineup_slots: Array[UnitSlot] = []

# Arrays to hold actual unit instances
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var is_player_turn: bool = true

# Merge and selection state
var selected_unit: Unit = null
var selected_slot: UnitSlot = null
var pending_merge_units: Array[Unit] = []
var pending_result_unit_id: String = ""
var is_awaiting_merge_confirmation: bool = false
var pending_merge_slot: UnitSlot = null
@onready var merge_confirmation_dialog: Window = null

func _ready() -> void:
	# Connect button signals (can be kept, but their actions will be simplified)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	gacha_button.pressed.connect(_on_gacha_pressed)
	
	# EventBus connections (can be kept, but signals won't be emitted by battle logic for now)
	# EventBus.unit_spawned.connect(_on_unit_spawned)
	# EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_died.connect(_on_unit_died_eventbus) # Connect to the new handler
	# EventBus.battle_ended.connect(_on_battle_ended)

	EventBus.unit_selected_for_action.connect(_on_unit_selected_for_action)
	EventBus.slot_clicked_for_action.connect(_on_slot_clicked_for_action)
	
	# Try to load and add unit info modal to the scene
	var modal_scene = load("res://scenes/UnitInfoModal.tscn") as PackedScene
	if modal_scene:
		unit_info_modal = modal_scene.instantiate()
		if unit_info_modal:
			add_child(unit_info_modal)
			print("Unit info modal loaded successfully")
	else:
		print("Could not load UnitInfoModal.tscn. Unit info display will be unavailable.")
	
	# Initialize battle visuals and gacha system
	setup_battle_scene()
	# _initialize_gacha_pool() # Removed, UnitLibrary is used directly
	_spawn_initial_units() # Spawn units after scene setup
	_update_gacha_tokens_display() # Renamed from _update_coin_display

	_initialize_merge_confirmation_dialog()

func _initialize_merge_confirmation_dialog() -> void:
	if not merge_confirmation_dialog:
		merge_confirmation_dialog = Window.new()
		merge_confirmation_dialog.title = "Merge Units"
		merge_confirmation_dialog.unresizable = true
		merge_confirmation_dialog.exclusive = true
		merge_confirmation_dialog.wrap_controls = true
		merge_confirmation_dialog.size = Vector2(400, 200)
		merge_confirmation_dialog.close_requested.connect(_on_merge_canceled)
		# Ensure the window is visible and interactive
		merge_confirmation_dialog.visible = false
		merge_confirmation_dialog.show()
		add_child(merge_confirmation_dialog)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 10)
		vbox.add_theme_constant_override("margin_left", 10)
		vbox.add_theme_constant_override("margin_top", 10)
		vbox.add_theme_constant_override("margin_right", 10)
		vbox.add_theme_constant_override("margin_bottom", 10)
		
		var label = Label.new()
		label.name = "MessageLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(label)
		
		var button_container = HBoxContainer.new()
		button_container.alignment = BoxContainer.ALIGNMENT_CENTER
		button_container.add_theme_constant_override("separation", 10)
		
		var merge_button = Button.new()
		merge_button.text = "Merge"
		merge_button.pressed.connect(_on_merge_confirmed)
		button_container.add_child(merge_button)
		
		var swap_button = Button.new()
		swap_button.text = "Swap"
		swap_button.pressed.connect(_on_swap_units)  # Connect to swap handler
		button_container.add_child(swap_button)
		
		vbox.add_child(button_container)
		merge_confirmation_dialog.add_child(vbox)
		add_child(merge_confirmation_dialog)
		
		# Set exclusive window mode to capture input
		merge_confirmation_dialog.exclusive = true
		print("Merge confirmation dialog initialized")

func setup_battle_scene() -> void:
	clear_all_slots() # Clear any previous children
	setup_visual_slots() # Populate the slot node arrays
	
	is_player_turn = true
	update_turn_indicator()
	
	# Buttons can be enabled, but their functionality will be placeholder
	end_turn_button.disabled = false 
	gacha_button.disabled = false
	
	add_log_message("Battle scene initialized. Lineup slots displayed.")

func clear_all_slots() -> void:
	# Clear units from player lineup slots
	for slot_node in player_lineup_slots:
		if is_instance_valid(slot_node) and not slot_node.is_empty():
			var unit = slot_node.clear_unit()
			if is_instance_valid(unit):
				unit.queue_free() # Free the unit node itself
	# Clear units from enemy lineup slots
	for slot_node in enemy_lineup_slots:
		if is_instance_valid(slot_node) and not slot_node.is_empty():
			var unit = slot_node.clear_unit()
			if is_instance_valid(unit):
				unit.queue_free()
	
	player_units.clear() # Also clear logical unit arrays
	enemy_units.clear()

# Function to set up UnitSlot instances as children of the existing Control nodes
func setup_visual_slots() -> void:
	# Clear all slot arrays
	player_lineup_slots.clear()
	enemy_lineup_slots.clear()

	# Setup player lineup slots
	setup_slot_container(player_units_container, "PlayerSlot", true, true, player_lineup_slots)
	
	# Setup enemy lineup slots
	setup_slot_container(enemy_units_container, "EnemySlot", true, false, enemy_lineup_slots)

# Helper function to set up slots in a container
func setup_slot_container(container: Control, slot_prefix: String, is_lineup: bool, is_player: bool, slot_array: Array) -> void:
	var child_count = container.get_child_count()
	var slot_controls = []
	
	# First, collect all slot controls and their numeric indices from node names
	for i in range(child_count):
		var slot_control = container.get_child(i)
		var slot_number = slot_control.name.trim_prefix(slot_prefix).to_int()
		slot_controls.append({"control": slot_control, "number": slot_number})
	
	# Sort slot controls by their numeric value
	slot_controls.sort_custom(func(a, b): return a["number"] < b["number"])
	
	# No need to reverse the array anymore - we're using slot_position for ordering
	
	# Process slots in sorted order
	for slot_data in slot_controls:
		var slot_control = slot_data["control"]
		var slot_number = slot_data["number"]
		
		# Clear existing UnitSlot nodes
		for child in slot_control.get_children():
			if child is UnitSlot:
				slot_control.remove_child(child)
				child.queue_free()
		
		# Create and configure UnitSlot
		var unit_slot = UnitSlot.new()
		unit_slot.slot_id = "%s%d" % [slot_prefix, slot_number - 1]
		unit_slot.is_lineup_slot = is_lineup
		unit_slot.is_player_slot = is_player
		# Set slot position (0=backline, 5=frontline)
		unit_slot.slot_position = slot_number - 1
		unit_slot.slot_clicked.connect(_on_slot_clicked_for_action)
		slot_control.add_child(unit_slot)
		slot_array.append(unit_slot)
		print("Assigned %s to slot %d (node: %s)" % [unit_slot.slot_id, slot_number - 1, slot_control.name])
		
		# Configure the UnitSlot to fill its parent Control but leave room for the floor visual
		unit_slot.anchor_left = 0.0
		unit_slot.anchor_right = 1.0
		unit_slot.anchor_top = 0.0
		unit_slot.anchor_bottom = 1.0
		unit_slot.offset_left = 0
		unit_slot.offset_right = 0
		unit_slot.offset_top = 0
		unit_slot.offset_bottom = 20  # Leave space for the floor visual at the bottom
		unit_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		unit_slot.z_index = 1  # Ensure units appear above floor visuals
		
		# Log the slot assignment for debugging
		print("Assigned %s to slot %d (node: %s)" % [unit_slot.slot_id, slot_number - 1, slot_control.name])

	# Ensure both teams have consistent slot ordering (index 0 = frontline, higher indices = backline)
	# No need to reverse enemy_lineup_slots anymore as we handle it in the scene setup

	# Initialize/resize the logical unit arrays to match the number of UnitSlots
	player_units.resize(player_lineup_slots.size())
	for i in range(player_units.size()):
		player_units[i] = null # This array stores the Unit instance at a logical slot index
	
	enemy_units.resize(enemy_lineup_slots.size())
	for i in range(enemy_units.size()):
		enemy_units[i] = null
	
	add_log_message("Battle.setup_visual_slots(): Setup complete. " + \
		"Player lineup slots: %d, Enemy lineup slots: %d" % [player_lineup_slots.size(), enemy_lineup_slots.size()])

func _spawn_initial_units() -> void:
	_spawn_hero_unit()
	_generate_enemy_lineup()

func _spawn_hero_unit() -> void:
	if not UnitLibrary:
		push_error("Battle._spawn_hero_unit(): UnitLibrary autoload not found!")
		return

	var hero_data: UnitData = UnitLibrary.get_unit_data("hero")
	if not hero_data:
		push_error("Battle._spawn_hero_unit(): Could not retrieve Hero data from UnitLibrary.")
		return

	if player_lineup_slots.is_empty():
		push_warning("Battle._spawn_hero_unit(): No player lineup slots available for Hero.")
		return

	# GDD: Hero automatically starts in the backmost available Lineup slot.
	# Assuming player slots are 0 (front/left) to N-1 (back/right).
	var hero_slot_index = player_lineup_slots.size() - 1
	var hero_slot = player_lineup_slots[hero_slot_index]
	
	# Make sure the slot is valid and empty
	if not is_instance_valid(hero_slot):
		push_error("Battle._spawn_hero_unit(): Invalid hero slot at index %d." % hero_slot_index)
		return
		
	if not hero_slot.is_empty():
		push_warning("Battle._spawn_hero_unit(): Hero slot %d is already occupied." % hero_slot_index)
		return

	# Spawn the hero in the lineup
	var hero_unit = _spawn_unit(hero_data, true, hero_slot_index)
	if hero_unit:
		add_log_message("Hero unit '%s' spawned in lineup slot %d." % [hero_data.display_name, hero_slot_index])
	else:
		push_error("Battle._spawn_hero_unit(): Failed to spawn hero unit.")

func _generate_enemy_lineup() -> void:
	if not UnitLibrary:
		push_error("Battle._generate_enemy_lineup(): UnitLibrary autoload not found!")
		return

	var num_enemies = randi_range(3, min(6, enemy_lineup_slots.size())) # 3 to 6 enemies, capped by available slots
	add_log_message("Generating %d enemies." % num_enemies)

	var enemy_options: Array[UnitData] = UnitLibrary.get_enemy_pool_t1()
	if enemy_options.is_empty():
		push_warning("Battle._generate_enemy_lineup(): No T1 enemy types available in UnitLibrary.")
		return

	for i in range(num_enemies):
		var slot_index = enemy_lineup_slots.size() - 1 - i  # Start from highest index (frontline) to lowest (backline)
		if slot_index < 0 or slot_index >= enemy_lineup_slots.size():
			push_warning("Battle._generate_enemy_lineup(): Invalid slot index %d for enemy %d." % [slot_index, i])
			break
		
		var random_enemy_data: UnitData = enemy_options.pick_random()
		if random_enemy_data:
			# Spawn enemies from front to back (highest to lowest index)
			_spawn_unit(random_enemy_data, false, slot_index)
			add_log_message("Spawned enemy '%s' in enemy slot %d (front to back)." % [random_enemy_data.display_name, slot_index])
		else:
			push_warning("Battle._generate_enemy_lineup(): Failed to pick random enemy data.")

func _spawn_unit(unit_data: UnitData, is_player_team: bool, slot_index: int = -1) -> Unit:
	if not UNIT_SCENE:
		push_error("Battle._spawn_unit(): UNIT_SCENE is not loaded.")
		return null
	if not unit_data:
		push_error("Battle._spawn_unit(): unit_data is null.")
		return null

	var unit_instance = UNIT_SCENE.instantiate()
	if not unit_instance:
		push_error("Battle._spawn_unit(): Failed to instantiate unit.")
		return null

	# Determine which container to add the unit to
	var target_container = player_units_container if is_player_team else enemy_units_container
	if not is_instance_valid(target_container):
		push_error("Battle._spawn_unit(): Invalid target container.")
		unit_instance.queue_free()
		return null

	# Add the unit to the scene tree first
	target_container.add_child(unit_instance)

	# Initialize the unit with data
	var team_color = Color(0.3, 0.7, 1.0) if is_player_team else Color(1.0, 0.4, 0.4)
	unit_instance.initialize(unit_data, is_player_team, team_color)

	# If slot_index is provided, assign to that slot
	if slot_index >= 0:
		var target_slots = player_lineup_slots if is_player_team else enemy_lineup_slots
		if slot_index < target_slots.size():
			var target_slot = target_slots[slot_index]
			if is_instance_valid(target_slot):
				# If the slot is occupied, remove the current unit
				if not target_slot.is_empty():
					var old_unit = target_slot.clear_unit()
					if is_instance_valid(old_unit):
						old_unit.queue_free()
				target_slot.assign_unit(unit_instance)

	# Add to the appropriate units array
	if is_player_team:
		player_units.append(unit_instance)
	else:
		enemy_units.append(unit_instance)

	# Update the unit's display
	if is_instance_valid(unit_instance):
		unit_instance._update_display()
	
	return unit_instance

# This function is no longer needed since we're using anchors for positioning
# Keeping it as a stub for compatibility with any existing calls
func _finalize_unit_position(unit: Unit, slot_node: Control) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(slot_node):
		push_warning("Battle._finalize_unit_position: Unit or slot_node is invalid.")
		return
	
	# Units now use anchors for positioning, so no manual position calculation is needed
	add_log_message("Unit '%s' positioned using anchors (Control.PRESET_BOTTOM_WIDE)" % [unit.name if unit.name else 'Unknown'])

func _on_end_turn_pressed() -> void:
	add_log_message("Starting combat phase...")
	# Disable UI during combat
	end_turn_button.disabled = true
	gacha_button.disabled = true
	
	# Start combat coroutine
	_process_combat_phase()

func _process_combat_phase() -> void:
	# Player team acts first
	add_log_message("Player team's turn!")
	await _process_team_turn(player_lineup_slots, enemy_lineup_slots, true)
	
	# Check if combat ended
	if _check_combat_ended():
		return
	
	# Enemy team's turn
	add_log_message("Enemy team's turn!")
	await _process_team_turn(enemy_lineup_slots, player_lineup_slots, false)
	
	# Check if combat ended
	if _check_combat_ended():
		return
	
	# End of combat phase
	add_log_message("Combat phase ended.")
	
	# Re-enable UI for next turn
	end_turn_button.disabled = false
	gacha_button.disabled = false

func _process_team_turn(attacking_team: Array, defending_team: Array, is_player_team: bool) -> void:
	# Debug: Print team info
	var team_name = "Player" if is_player_team else "Enemy"
	print("\n=== %s Team's Turn ===" % team_name)
	
	# Print attacking team slots
	var attacking_slots = []
	for i in range(attacking_team.size()):
		attacking_slots.append("%d:%s" % [i, attacking_team[i].slot_id])
	print("Attacking team slots (index:slot_id): ", attacking_slots)
	
	# Print defending team slots
	var defending_slots = []
	for i in range(defending_team.size()):
		defending_slots.append("%d:%s" % [i, defending_team[i].slot_id])
	print("Defending team slots (index:slot_id): ", defending_slots)
	
	# Create a list to track which units have already acted this turn
	var acted_this_turn = {}
	
	# Continue processing turns until all units have acted or combat ends
	var turn_ended = false
	var turn_count = 0
	while not turn_ended:
		turn_count += 1
		turn_ended = true  # Assume we're done unless we find units that can act
		
		# Process units from front to back (highest to lowest index)
		for i in range(attacking_team.size() - 1, -1, -1):
			var slot = attacking_team[i]
			if not is_instance_valid(slot) or slot.is_empty():
				continue
				
			var unit = slot.occupying_unit
			if not is_instance_valid(unit) or unit.current_hp <= 0:
				if is_instance_valid(slot) and is_instance_valid(unit) and not is_instance_valid(unit.unit_data):
					slot.clear_unit()  # Clean up invalid unit
				continue
			
			# Skip if this unit has already acted this turn
			if acted_this_turn.has(unit):
				continue
			
			# Mark that we found at least one unit that can act
			turn_ended = false
			
			# Mark this unit as having acted this turn
			acted_this_turn[unit] = true
			
			# Debug: Print attacker info
			print("\n[Turn %d] %s (slot: %s, index: %d) is attacking" % 
				[turn_count, unit.unit_data.display_name, slot.slot_id, i])
			
			# Find target - frontmost unit in the opposing team
			var target_slot = _find_frontmost_unit(defending_team)
			if not target_slot or not is_instance_valid(target_slot.occupying_unit):
				add_log_message("No valid targets found!")
				continue
				
			var target = target_slot.occupying_unit
			if not is_instance_valid(target) or not is_instance_valid(target.unit_data):
				add_log_message("Invalid target found, skipping attack")
				continue
			
			# Perform the attack
			add_log_message("%s attacks %s!" % [unit.unit_data.display_name, target.unit_data.display_name])
			var damage = unit.unit_data.pwr
			target.take_damage(damage)
			add_log_message("%s deals %d damage to %s" % [unit.unit_data.display_name, damage, target.unit_data.display_name])
			
			# Wait for animation/damage to be applied
			await get_tree().create_timer(0.5).timeout
			
			# Check if target was defeated
			if is_instance_valid(target) and target.current_hp <= 0:
				add_log_message("%s was defeated!" % target.unit_data.display_name)
				EventBus.unit_died.emit(target)
				if is_instance_valid(target_slot):
					target_slot.clear_unit()
				if _check_combat_ended():
					return
			
			# Small delay between unit actions for better visibility
			await get_tree().create_timer(0.3).timeout

func _find_frontmost_unit(team_slots: Array) -> UnitSlot:
	var frontmost_slot = null
	var highest_position = -1
	
	for slot in team_slots:
		if not is_instance_valid(slot) or slot.is_empty():
			continue
			
		var unit = slot.occupying_unit
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			# Clean up invalid units
			if is_instance_valid(slot) and is_instance_valid(unit) and not is_instance_valid(unit.unit_data):
				slot.clear_unit()
			continue
			
		# Check if this unit is in a more forward position
		if slot.slot_position > highest_position:
			highest_position = slot.slot_position
			frontmost_slot = slot
	
	return frontmost_slot

func _check_combat_ended() -> bool:
	# Check if all enemy units are defeated
	var all_enemies_defeated = true
	for slot in enemy_lineup_slots:
		if is_instance_valid(slot) and not slot.is_empty() and is_instance_valid(slot.occupying_unit):
			if slot.occupying_unit.current_hp > 0:
				all_enemies_defeated = false
				break
	
	if all_enemies_defeated:
		add_log_message("All enemies defeated! Victory!")
		# TODO: Add victory rewards and transition
		return true
	
	# Check if all player units are defeated
	var all_players_defeated = true
	for slot in player_lineup_slots:
		if is_instance_valid(slot) and not slot.is_empty() and is_instance_valid(slot.occupying_unit):
			if slot.occupying_unit.current_hp > 0:
				all_players_defeated = false
				break
	
	if all_players_defeated:
		add_log_message("All player units defeated! Game Over!")
		# TODO: Handle game over
		return true
	
	return false

func _on_gacha_pressed() -> void:
	if not UnitLibrary:
		push_error("Battle._on_gacha_pressed(): UnitLibrary autoload not found!")
		return

	if gacha_tokens < 1:
		add_log_message("Not enough gacha tokens!")
		return

	gacha_tokens -= 1
	_update_gacha_tokens_display()
	
	var gacha_options: Array[UnitData] = UnitLibrary.get_gacha_pool_t1()
	if gacha_options.is_empty():
		add_log_message("Gacha pool is empty!")
		return

	var drawn_unit_data: UnitData = gacha_options.pick_random()
	
	if not drawn_unit_data:
		add_log_message("Failed to draw unit from gacha (pool might be okay, but pick_random failed).")
		return

	add_log_message("Gacha draw: %s" % drawn_unit_data.display_name)

	# Try to place in the first available lineup slot
	var placed_in_slot = -1
	for i in range(player_lineup_slots.size()):
		var slot = player_lineup_slots[i]
		if is_instance_valid(slot) and slot.is_empty():
			# Spawn the unit in the lineup
			var unit = _spawn_unit(drawn_unit_data, true, i)
			if unit:
				add_log_message("Gacha unit '%s' placed in lineup slot %d." % [drawn_unit_data.display_name, i])
				placed_in_slot = i
				break

	# Handle case where the unit couldn't be placed
	if placed_in_slot == -1:
		add_log_message("No space in lineup for the new unit.")
		# Optional: Refund the gacha token since we couldn't place the unit
		# gacha_tokens += 1
		# _update_gacha_tokens_display()
		# add_log_message("Gacha token refunded - no space for unit.")

func _update_gacha_tokens_display() -> void:
	if gacha_tokens_label:
		gacha_tokens_label.text = "Tokens: %d" % gacha_tokens

func _get_frontmost_live_unit(unit_array: Array[Unit]) -> Variant:
	if unit_array.is_empty():
		return null
		
	# Check if this is the player or enemy team (commented out as it's not currently used)
	var _is_player_team = unit_array == player_units  # Currently unused, but keeping for potential future use
	
	# For both teams, the frontmost unit is the one with the highest index in their respective arrays
	# because enemy_lineup_slots were already reversed during setup
	for i in range(unit_array.size() - 1, -1, -1):
		var unit = unit_array[i]
		if is_instance_valid(unit) and unit.current_hp > 0:
			return unit
			
	return null

func update_turn_indicator() -> void:
	if end_turn_button.disabled: # Battle is over
		return
		
	if player_units.is_empty() and enemy_units.is_empty():
		# This condition might be met briefly during setup if called before _spawn_initial_units
		turn_indicator.text = "Preparing Battle..."
		turn_indicator.add_theme_color_override("font_color", Color.WHITE) # Neutral color
		return

	if is_player_turn:
		turn_indicator.text = "Player's Turn"
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2)) # Green
	else:
		turn_indicator.text = "Enemy's Turn"
		turn_indicator.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2)) # Red

func add_log_message(message: String) -> void:
	var timestamp = "[%s] " % Time.get_time_string_from_system(false) # Corrected: removed extra arg
	if battle_log.text.is_empty():
		battle_log.text = timestamp + message
	else:
		battle_log.text += "\n" + timestamp + message
	battle_log.scroll_vertical = INF

# --- Helper Functions for Selection and Movement ---
func _get_slot_for_unit(unit_to_find: Unit) -> UnitSlot:
	if not is_instance_valid(unit_to_find):
		return null

	# Check player lineup slots
	for slot in player_lineup_slots:
		if is_instance_valid(slot) and slot.occupying_unit == unit_to_find:
			return slot

	# Check enemy lineup slots
	for slot in enemy_lineup_slots:
		if is_instance_valid(slot) and slot.occupying_unit == unit_to_find:
			return slot

	return null

func _clear_selection() -> void:
	if selected_unit and is_instance_valid(selected_unit):
		selected_unit.update_selection_visual(false)
	selected_unit = null
	if selected_slot and is_instance_valid(selected_slot):
		selected_slot.set_highlight("")
	selected_slot = null
	# Clear any pending merge state
	pending_merge_units.clear()
	pending_result_unit_id = ""
	is_awaiting_merge_confirmation = false
	pending_merge_slot = null
	# TODO: Call _highlight_valid_slots(false) when implemented
	add_log_message("Current unit deselected.")

# --- Core Logic for Movement and Swapping ---
func _handle_second_click(target_slot: UnitSlot, target_unit: Unit) -> void:
	if not selected_slot or not selected_unit:
		_clear_selection()
		return
	
	# If clicking on an empty slot on the same team
	if not target_unit and target_slot.is_player_slot == selected_unit.is_player_team_unit:
		_attempt_move_to_empty_slot(selected_unit, selected_slot, target_slot)
	# If clicking on another unit on the same team
	elif target_unit and target_unit.is_player_team_unit == selected_unit.is_player_team_unit:
		# Check if units can be merged
		if is_instance_valid(target_unit.unit_data) and is_instance_valid(selected_unit.unit_data):
			var result_unit_id = UnitLibrary.get_merge_result_for_units(selected_unit.unit_data, target_unit.unit_data)
			if result_unit_id and target_unit.tier == selected_unit.tier and target_unit.tier < 3:
				# Show merge confirmation dialog
				_show_merge_confirmation(selected_unit, target_unit, target_slot, result_unit_id)
				# Don't clear selection here - wait for confirmation
				return
			else:
				# If merge not possible, swap the units
				_attempt_swap_units(selected_unit, selected_slot, target_unit, target_slot)
		else:
			# If unit data is invalid, just swap
			_attempt_swap_units(selected_unit, selected_slot, target_unit, target_slot)
	
	# Only clear selection if we're not waiting for merge confirmation
	if not is_awaiting_merge_confirmation:
		_clear_selection()

# --- EventBus Handlers for Unit/Slot Interaction ---
func _on_unit_selected_for_action(clicked_unit: Unit) -> void:
	if not is_instance_valid(clicked_unit):
		_clear_selection()
		return
	
	# If we're already showing a merge confirmation, don't allow selection changes
	if is_awaiting_merge_confirmation:
		return
		
	# If we already have a selected unit and it's the same as the clicked unit
	if is_instance_valid(selected_unit) and selected_unit == clicked_unit:
		# Show unit info if available, otherwise just deselect
		if unit_info_modal:
			unit_info_modal.show_unit_info(clicked_unit)
		_clear_selection()
		return
	
	# If we have a selected unit and it's different from the clicked unit
	if is_instance_valid(selected_unit) and selected_unit != clicked_unit:
		# Try to merge or swap
		var clicked_slot = _get_slot_for_unit(clicked_unit)
		if is_instance_valid(clicked_slot):
			_handle_second_click(clicked_slot, clicked_unit)
		return
	
	# If we don't have a selected unit, select the clicked unit
	selected_unit = clicked_unit
	selected_slot = _get_slot_for_unit(clicked_unit)
	
	if is_instance_valid(selected_slot):
		selected_slot.set_highlight("selected")
		add_log_message("Selected " + clicked_unit.unit_data.display_name)

func _on_slot_clicked_for_action(clicked_slot: UnitSlot) -> void:
	if not is_instance_valid(clicked_slot):
		_clear_selection()
		return
	
	# If we have a selected unit
	if is_instance_valid(selected_unit) and is_instance_valid(selected_slot):
		# If clicking the same slot, deselect
		if clicked_slot == selected_slot:
			_clear_selection()
			return
		
		# Handle the second click based on the target slot
		_handle_second_click(clicked_slot, clicked_slot.occupying_unit)
	else:
		# If no unit is selected, select the unit in the clicked slot if it exists
		if is_instance_valid(clicked_slot.occupying_unit):
			selected_unit = clicked_slot.occupying_unit
			selected_slot = clicked_slot
			selected_slot.set_highlight("selected")
		else:
			_clear_selection()

func _show_merge_confirmation(unit1: Unit, unit2: Unit, target_slot: UnitSlot, result_unit_id: String) -> void:
	print("Showing merge confirmation dialog")
	var result_data = UnitLibrary.get_unit_data(result_unit_id)
	if not result_data:
		print("No result data found for unit id: ", result_unit_id)
		_clear_selection()
		return

	# Store merge info for confirmation
	pending_merge_slot = target_slot
	pending_merge_units = [unit1, unit2]
	pending_result_unit_id = result_unit_id
	is_awaiting_merge_confirmation = true

	# Update dialog text
	var unit1_name = unit1.unit_data.display_name if unit1 and unit1.unit_data else "Unit 1"
	var unit2_name = unit2.unit_data.display_name if unit2 and unit2.unit_data else "Unit 2"
	var result_name = result_data.display_name if result_data else "New Unit"
	
	# Ensure the dialog is initialized
	_initialize_merge_confirmation_dialog()
	
	# Update dialog content
	var vbox = merge_confirmation_dialog.get_child(0) as VBoxContainer
	if vbox:
		var label = vbox.get_node("MessageLabel") as Label
		if label:
			label.text = "Merge %s and %s to create %s?" % [unit1_name, unit2_name, result_name]
	else:
		print("Warning: Could not find VBoxContainer in merge dialog")
	
	# Show the dialog
	print("Showing merge dialog at position: ", get_global_mouse_position())
	merge_confirmation_dialog.popup_centered_ratio(0.4)
	merge_confirmation_dialog.move_to_center()
	merge_confirmation_dialog.grab_focus()
	print("Dialog should be visible now")

func _on_merge_confirmed() -> void:
	print("Merge confirmed, performing merge...")
	# Hide dialog first to prevent multiple clicks
	if is_instance_valid(merge_confirmation_dialog):
		merge_confirmation_dialog.hide()
	
	# Verify we have everything we need
	if (pending_merge_units.size() != 2 or 
		not is_instance_valid(pending_merge_units[0]) or 
		not is_instance_valid(pending_merge_units[1]) or 
		not is_instance_valid(pending_merge_slot) or 
		pending_result_unit_id.is_empty()):
		
		print("Merge validation failed, cleaning up...")
		_clear_merge_state()
		return
	
	print("Performing merge with valid parameters")
	# Perform the merge
	_perform_merge(
		pending_merge_units[0], 
		pending_merge_units[1], 
		pending_merge_slot, 
		pending_result_unit_id
	)
	
	print("Merge complete, cleaning up...")
	# Clean up
	_clear_merge_state()
	
	if (pending_merge_units.size() >= 2 and 
		pending_result_unit_id and 
		pending_merge_slot and
		is_instance_valid(pending_merge_units[0]) and 
		is_instance_valid(pending_merge_units[1])):
		
		var unit1 = pending_merge_units[0]
		var unit2 = pending_merge_units[1]
		var target_slot = pending_merge_slot
		var result_id = pending_result_unit_id
		
		# Clear state before performing merge to prevent re-entry issues
		is_awaiting_merge_confirmation = false
		pending_merge_units.clear()
		pending_merge_slot = null
		pending_result_unit_id = ""
		
		_perform_merge(unit1, unit2, target_slot, result_id)
	else:
		var error_msg = "Merge failed: Invalid merge state. "
		error_msg += "Units: %d, " % pending_merge_units.size()
		error_msg += "Result ID: %s, " % ("yes" if pending_result_unit_id else "no")
		error_msg += "Slot: %s, " % ("valid" if pending_merge_slot else "invalid")
		if pending_merge_units.size() > 0:
			error_msg += "Unit1: %s, " % ("valid" if is_instance_valid(pending_merge_units[0]) else "invalid")
		if pending_merge_units.size() > 1:
			error_msg += "Unit2: %s" % ("valid" if is_instance_valid(pending_merge_units[1]) else "invalid")
		
		push_error(error_msg)
		add_log_message(error_msg)
		is_awaiting_merge_confirmation = false
		_clear_selection()

func _input(event: InputEvent) -> void:
	# Only process input if the merge dialog is visible
	if is_instance_valid(merge_confirmation_dialog) and merge_confirmation_dialog.visible and event is InputEventMouseButton and event.pressed:
		var dialog_rect = Rect2(merge_confirmation_dialog.position, merge_confirmation_dialog.size)
		# Check if click is outside the dialog
		if not dialog_rect.has_point(event.global_position):
			print("Clicked outside merge dialog, cancelling...")
			merge_confirmation_dialog.hide()
			_on_merge_canceled()
			# Mark the input as handled to prevent other nodes from processing it
			get_viewport().set_input_as_handled()

func _on_swap_units() -> void:
	print("Swap units requested")
	# Hide dialog first to prevent multiple clicks
	if is_instance_valid(merge_confirmation_dialog):
		merge_confirmation_dialog.hide()
	
	print("Pending merge units count: ", pending_merge_units.size())
	# Perform the swap
	if pending_merge_units.size() == 2 and is_instance_valid(pending_merge_units[0]) and is_instance_valid(pending_merge_units[1]):
		var unit1 = pending_merge_units[0]
		var unit2 = pending_merge_units[1]
		print("Found valid units for swap")
		
		var slot1 = _get_slot_for_unit(unit1)
		var slot2 = _get_slot_for_unit(unit2)
		
		print("Slot1 valid: ", is_instance_valid(slot1), " Slot2 valid: ", is_instance_valid(slot2))
		
		if is_instance_valid(slot1) and is_instance_valid(slot2):
			print("Attempting to swap units...")
			_attempt_swap_units(unit1, slot1, unit2, slot2)
	else:
		print("Invalid units for swap")
	
	# Clean up
	print("Cleaning up after swap")
	_clear_merge_state()

func _on_merge_canceled() -> void:
	_clear_merge_state()

func _clear_merge_state() -> void:
	print("Clearing merge state...")
	is_awaiting_merge_confirmation = false
	_clear_selection()
	if is_instance_valid(merge_confirmation_dialog):
		merge_confirmation_dialog.hide()
	
	# Clear pending merge state
	pending_merge_units.clear()
	pending_merge_slot = null
	pending_result_unit_id = ""
	print("Merge state cleared")

func _perform_merge(unit1: Unit, unit2: Unit, target_slot: UnitSlot, result_unit_id: String) -> void:
	if not is_instance_valid(unit1) or not is_instance_valid(unit2) or not is_instance_valid(target_slot):
		_clear_selection()
		return

	var result_data = UnitLibrary.get_unit_data(result_unit_id)
	if not result_data:
		_clear_selection()
		return

	# Get the other slot
	var other_slot = target_slot if (unit1 == selected_unit) else selected_slot
	if not is_instance_valid(other_slot):
		_clear_selection()
		return
	
	# Calculate combined stats from both units
	var combined_hp = unit1.current_hp + unit2.current_hp
	var combined_pwr = unit1.unit_data.pwr + unit2.unit_data.pwr
	
	# Add a small bonus for merging (10% of combined stats)
	combined_pwr = int(combined_pwr * 1.1)
	
	# Create a copy of the result data to modify
	var merged_data = result_data.duplicate()
	merged_data.max_hp = combined_hp  # Set the base health to combined current HP
	merged_data.pwr = combined_pwr
	
	# Remove both units from their slots
	var removed_unit1 = selected_slot.clear_unit()
	var removed_unit2 = target_slot.clear_unit()

	# Create and place the new unit with combined stats
	var slot_index = player_lineup_slots.find(target_slot)
	if slot_index == -1:
		push_error("Target slot not found in player_lineup_slots")
		_clear_selection()
		return
		
	var new_unit = _spawn_unit(merged_data, true, slot_index)
	if new_unit:
		# The unit will be initialized with the combined HP since we set max_hp = combined_hp
		# and the Unit.initialize() method sets current_hp = data.max_hp
		
		target_slot.assign_unit(new_unit)
		# Update player_units array
		player_units.erase(removed_unit1)
		player_units.erase(removed_unit2)
		player_units.append(new_unit)

		# Emit merge event
		EventBus.units_merged.emit(unit1, unit2, new_unit)

	# Clean up old units
	if is_instance_valid(removed_unit1):
		removed_unit1.queue_free()
	if is_instance_valid(removed_unit2):
		removed_unit2.queue_free()

	_clear_selection()
	
	# Force update the display
	if is_instance_valid(new_unit):
		new_unit._update_display()

func _update_merge_highlights(unit_to_highlight: Unit) -> void:
	if not unit_to_highlight:
		return

	for slot in player_lineup_slots:
		if slot == selected_slot:
			slot.set_highlight("selected")
		elif slot.occupying_unit:
			var result = UnitLibrary.get_merge_result_for_units(selected_unit.unit_data, slot.occupying_unit.unit_data)
			slot.set_highlight("merge" if result else "invalid")
		else:
			slot.set_highlight("")


func _attempt_move_to_empty_slot(unit_to_move: Unit, from_slot: UnitSlot, to_slot: UnitSlot) -> bool:
	# 1. Validate Inputs & State
	if not is_instance_valid(unit_to_move) or not is_instance_valid(from_slot) or not is_instance_valid(to_slot):
		add_log_message("Move failed: Invalid unit or slot instance(s).")
		return false

	if from_slot.occupying_unit != unit_to_move:
		add_log_message("Move failed: Unit %s is not in the specified from_slot %s." % [unit_to_move.get_name_for_log(), from_slot.slot_id])
		return false

	if not to_slot.is_empty():
		add_log_message("Move failed: Target slot %s is not empty." % to_slot.slot_id)
		return false

	# 2. Hero Constraint Check (using UnitSlot's own check)
	if unit_to_move.unit_data and unit_to_move.unit_data.unit_type_tag == "hero":
		if not to_slot.can_accommodate_hero():
			add_log_message("Move failed: Invalid target slot for unit %s" % unit_to_move.get_name_for_log())
			return false

	# 3. Perform Move (Visual and Slot Logic)
	var unit_ref = from_slot.clear_unit() # Should be unit_to_move
	if unit_ref != unit_to_move: # Should not happen if logic is correct
		push_error("Battle._attempt_move_to_empty_slot: Mismatch in unit cleared from from_slot!")
		# Attempt to recover or fail gracefully
		if is_instance_valid(unit_ref) and not is_instance_valid(from_slot.occupying_unit):
			from_slot.assign_unit(unit_ref) # Put it back if something went wrong
		return false
	
	to_slot.assign_unit(unit_to_move)

	# 4. Update Logical Array (player_units)
	var from_slot_idx = player_lineup_slots.find(from_slot)
	var to_slot_idx = player_lineup_slots.find(to_slot)

	if from_slot_idx == -1 or to_slot_idx == -1:
		add_log_message("Move failed: Could not find one or both slots in player_lineup_slots array. This is a critical error.")
		# Attempt to revert visual move if logical update fails catastrophically
		to_slot.clear_unit()
		from_slot.assign_unit(unit_to_move)
		return false

	player_units[from_slot_idx] = null
	player_units[to_slot_idx] = unit_to_move

	add_log_message("Move successful: %s moved from %s to %s." % [unit_to_move.get_name_for_log(), from_slot.slot_id, to_slot.slot_id])
	return true


func _attempt_swap_units(unit1: Unit, from_slot1: UnitSlot, unit2: Unit, from_slot2: UnitSlot) -> bool:
	# 1. Validate Inputs & State
	if (not is_instance_valid(unit1) or not is_instance_valid(from_slot1) or 
	   not is_instance_valid(unit2) or not is_instance_valid(from_slot2)):
		add_log_message("Swap failed: Invalid unit or slot instance(s).")
		return false

	# Make sure the units are actually in the specified slots
	if from_slot1.occupying_unit != unit1 or from_slot2.occupying_unit != unit2:
		add_log_message("Swap failed: Unit-slot mismatch.")
		return false

	# 2. Check if both units are on the same team (can't swap with enemy units)
	if unit1.is_player_team_unit != unit2.is_player_team_unit:
		add_log_message("Swap failed: Cannot swap units from different teams.")
		return false

	# 3. Check hero constraints for both slots
	if unit1.unit_data.unit_type_tag == "hero" and not from_slot2.can_accommodate_hero():
		add_log_message("Swap failed: Hero unit %s cannot move to slot %s." % [unit1.get_name_for_log(), from_slot2.slot_id])
		return false

	if unit2.unit_data.unit_type_tag == "hero" and not from_slot1.can_accommodate_hero():
		add_log_message("Swap failed: Hero unit %s cannot move to slot %s." % [unit2.get_name_for_log(), from_slot1.slot_id])
		return false

	# 4. Perform the swap
	# First clear both slots
	var temp_unit1 = from_slot1.clear_unit()
	var temp_unit2 = from_slot2.clear_unit()

	# Sanity check
	if temp_unit1 != unit1 or temp_unit2 != unit2:
		push_error("Battle._attempt_swap_units: Mismatch in units cleared from slots!")
		# Attempt to revert
		if is_instance_valid(temp_unit1): from_slot1.assign_unit(temp_unit1)
		if is_instance_valid(temp_unit2): from_slot2.assign_unit(temp_unit2)
		return false
	
	from_slot1.assign_unit(unit2)
	from_slot2.assign_unit(unit1)
	
	# 5. Update logical arrays if these are player units
	if unit1.is_player_team_unit:  # Both units are on the same team, so just check one
		var slot1_idx = player_lineup_slots.find(from_slot1)
		var slot2_idx = player_lineup_slots.find(from_slot2)

		if slot1_idx != -1 and slot2_idx != -1:
			# Update the logical arrays
			player_units[slot1_idx] = unit2
			player_units[slot2_idx] = unit1

	add_log_message("Swapped %s and %s" % [unit1.get_name_for_log(), unit2.get_name_for_log()])
	return true


# --- Existing EventBus Handlers (Modified) ---
func _on_unit_died_eventbus(unit_died: Unit) -> void:
	if not is_instance_valid(unit_died):
		return

	var unit_name = unit_died.get_name_for_log()
	add_log_message("EventBus: Unit %s died." % unit_name)

	var slot_of_died_unit: UnitSlot = _get_slot_for_unit(unit_died)

	if is_instance_valid(slot_of_died_unit):
		var team_info = "Player" if slot_of_died_unit.is_player_slot else "Enemy"
		var slot_idx = -1
		
		if slot_of_died_unit.is_player_slot:
			slot_idx = player_lineup_slots.find(slot_of_died_unit)
			if slot_idx != -1 and slot_idx < player_units.size() and player_units[slot_idx] == unit_died:
				player_units[slot_idx] = null
		else: # Enemy unit
			slot_idx = enemy_lineup_slots.find(slot_of_died_unit)
			if slot_idx != -1 and slot_idx < enemy_units.size() and enemy_units[slot_idx] == unit_died:
				enemy_units[slot_idx] = null
		
		slot_of_died_unit.clear_unit()
		add_log_message("Unit %s cleared from %s lineup slot %s. Corresponding logical array updated." % [unit_name, team_info, slot_of_died_unit.slot_id])
	else:
		# Fallback if unit wasn't in a tracked slot (shouldn't happen for units in play)
		push_warning("Battle._on_unit_died_eventbus: Died unit %s was not found in any tracked slot." % unit_name)

	# If the died unit was selected, deselect it
	if selected_unit == unit_died:
		_clear_selection()

	# Visually remove the unit from the scene (queue_free is now handled by clear_unit if it was parented to slot, or here if not)
	if is_instance_valid(unit_died) and not unit_died.is_queued_for_deletion():
		# If clear_unit didn't queue_free it (e.g., it wasn't parented to the slot directly for some reason)
		# or if it wasn't found in a slot, ensure it's freed.
		unit_died.queue_free()

	# Check for win/loss conditions only if the battle isn't already marked as ended
	if not end_turn_button.disabled:
		if player_units.is_empty() and not enemy_units.is_empty():
			add_log_message("All player units defeated! Enemy wins!")
			EventBus.battle_ended.emit(false) # Player lost
			_end_battle_actions(false)
		elif enemy_units.is_empty() and not player_units.is_empty():
			add_log_message("All enemy units defeated! Player wins!")
			EventBus.battle_ended.emit(true) # Player won
			_end_battle_actions(true)
		elif player_units.is_empty() and enemy_units.is_empty():
			# This case could happen if the last units on both sides die simultaneously
			add_log_message("All units defeated! It's a draw!")
			EventBus.battle_ended.emit(false) # Consider a draw as a loss or specific state
			_end_battle_actions(false)

func _end_battle_actions(player_won: bool) -> void:
	end_turn_button.disabled = true
	gacha_button.disabled = true
	
	# Don't reset coins here since we want to keep them during battle
	# They'll be reset when a new battle starts
	
	if player_won:
		add_log_message("Victory!")
	else:
		add_log_message("Defeat!")
	add_log_message("Battle ended. Player %s." % ["won" if player_won else "lost"])
	var message = "Player Won!" if player_won else "Player Lost!"
	turn_indicator.text = "Battle Over: %s" % message
	if player_won:
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Bright Green
	else:
		turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Bright Red
