extends Control

@onready var player_units_container: HBoxContainer = $MainContainer/BattleArea/PlayerSide/PlayerUnits
@onready var enemy_units_container: HBoxContainer = $MainContainer/BattleArea/EnemySide/EnemyUnits
@onready var battle_log: TextEdit = $BattleLog
@onready var end_turn_button: Button = $MainContainer/Actions/EndTurnButton
@onready var gacha_button: Button = $MainContainer/Actions/GachaButton
@onready var player_health_label: Label = $MainContainer/Header/PlayerInfo/PlayerHealth
@onready var gacha_tokens_label: Label = $MainContainer/Header/PlayerInfo/GachaTokens
@onready var turn_indicator: Label = $MainContainer/Header/TurnIndicator

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
var is_awaiting_merge_confirmation: bool = false
var pending_merge_slot: UnitSlot = null

func _ready() -> void:
	# Initialize the battle state
	is_player_turn = true
	is_awaiting_merge_confirmation = false
	
	# Connect signals
	EventBus.unit_died.connect(_on_unit_died_eventbus)
	EventBus.unit_health_changed.connect(_on_unit_health_changed)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.slot_clicked_for_action.connect(_on_slot_clicked_for_action)
	EventBus.unit_selected_for_action.connect(_on_unit_selected_for_action)
	
	# Initialize UI elements
	if has_node("MainContainer/Actions/EndTurnButton"):
		$MainContainer/Actions/EndTurnButton.pressed.connect(_on_end_turn_pressed)
	if has_node("MainContainer/Actions/GachaButton"):
		$MainContainer/Actions/GachaButton.pressed.connect(_on_gacha_pressed)
		
	# Initialize battle visuals and gacha system
	setup_battle_scene()
	_spawn_initial_units() # Spawn units after scene setup
	_update_gacha_tokens_display() # Update gacha tokens display

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

func _deselect_current_unit() -> void:
	if is_instance_valid(selected_unit):
		if selected_unit.has_method("set_selected"):
			selected_unit.set_selected(false)
		elif selected_unit.has_method("update_selection_visual"):
			selected_unit.update_selection_visual(false)
		
	selected_unit = null
	
	if selected_slot and is_instance_valid(selected_slot) and selected_slot.has_method("set_highlight"):
		selected_slot.set_highlight("")
	
	selected_slot = null
	add_log_message("Current unit deselected.")

func show_unit_inspection(unit: Unit) -> void:
	if not is_instance_valid(unit) or not unit.unit_data:
		return
	
	# Create a full-screen background to capture clicks
	var bg = ColorRect.new()
	bg.size = get_viewport_rect().size
	bg.color = Color(0, 0, 0, 0.5)  # Semi-transparent black
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to underlying elements
	bg.name = "InspectionBackground"
	add_child(bg)
	
	# Create the inspection panel
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(320, 240)
	panel.position = (get_viewport_rect().size - panel.size) * 0.5  # Center on screen
	panel.theme_type_variation = "InspectionPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.add_child(panel)
	
	# Add a close button (X) in the top-right corner
	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.position = Vector2(panel.size.x - 30, 10)
	close_button.pressed.connect(bg.queue_free)
	panel.add_child(close_button)
	
	# Main container for content
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Unit name
	var name_label = Label.new()
	name_label.text = unit.unit_data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)
	
	# Tier and type
	var tier_type_label = Label.new()
	tier_type_label.text = "Tier %d • %s" % [unit.unit_data.tier, unit.unit_data.unit_type_tag.capitalize()]
	tier_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tier_type_label)
	
	# Stats
	var stats_hbox = HBoxContainer.new()
	stats_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var hp_label = Label.new()
	hp_label.text = "❤️ %d" % unit.unit_data.max_hp
	stats_hbox.add_child(hp_label)
	
	var pwr_label = Label.new()
	pwr_label.text = "⚔️ %d" % unit.unit_data.pwr
	pwr_label.add_theme_constant_override("margin_left", 20)
	stats_hbox.add_child(pwr_label)
	
	vbox.add_child(stats_hbox)
	
	# Separator
	var separator = HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(separator)
	
	# Ability description
	if unit.unit_data.ability_description:
		var help_container = VBoxContainer.new()
		help_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var help_label = Label.new()
		help_label.text = "Ability: " + unit.unit_data.ability_description
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		help_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		
		var scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var vbox_scroll = VBoxContainer.new()
		vbox_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_scroll.add_child(help_label)
		
		scroll.add_child(vbox_scroll)
		help_container.add_child(scroll)
		vbox.add_child(help_container)
	
	# Close when clicking outside the panel
	# Close when clicking outside the panel or pressing escape
	bg.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					var local_pos = panel.get_local_mouse_position()
					if not panel.get_rect().has_point(local_pos):
						bg.queue_free()
			elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				bg.queue_free()
	)
	
	# Also close when the background is clicked directly
	bg.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				bg.queue_free()
	)

func _is_click_inside_ui(click_position: Vector2) -> bool:
	# Check if click is inside any UI elements
	var space_rid = get_world_2d().space
	var space_state = PhysicsServer2D.space_get_direct_state(space_rid)
	var params = PhysicsPointQueryParameters2D.new()
	params.position = click_position
	params.collision_mask = 1 # UI layer
	var results = space_state.intersect_point(params)
	return not results.is_empty()

func show_merge_swap_popup(unit1: Unit, unit2: Unit, target_slot: UnitSlot) -> void:
	print("\n=== CREATING MERGE/SWAP POPUP ===")
	print("Unit 1: ", unit1.unit_data.id if unit1.unit_data else "No unit data")
	print("Unit 2: ", unit2.unit_data.id if unit2.unit_data else "No unit data")
	print("Target slot: ", target_slot.name if target_slot else "No target slot")
	
	# Set flag to prevent input from clearing selection
	is_awaiting_merge_confirmation = true
	
	# Create a full-screen background to capture clicks
	var bg = ColorRect.new()
	bg.size = get_viewport_rect().size
	bg.color = Color(0, 0, 0, 0.3)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	
	# Create a panel for the popup
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(200, 100)
	panel.position = get_global_mouse_position()
	panel.size = Vector2(200, 100)
	bg.add_child(panel)
	
	# Ensure panel is within screen bounds
	var viewport_size = get_viewport_rect().size
	panel.position.x = clamp(panel.position.x, 0, viewport_size.x - panel.size.x)
	panel.position.y = clamp(panel.position.y, 0, viewport_size.y - panel.size.y)
	
	# Create merge button
	var merge_btn = Button.new()
	merge_btn.text = "Merge"
	merge_btn.position = Vector2(10, 10)
	merge_btn.size = Vector2(180, 30)
	panel.add_child(merge_btn)
	
	# Create swap button
	var swap_btn = Button.new()
	swap_btn.text = "Swap"
	swap_btn.position = Vector2(10, 50)
	swap_btn.size = Vector2(180, 30)
	panel.add_child(swap_btn)
	
	# Store references to units and slots that we'll need later
	var first_unit = unit1
	var second_unit = unit2
	var first_slot = selected_slot
	
	# Function to clean up the popup
	var cleanup = func():
		is_awaiting_merge_confirmation = false
		if is_instance_valid(bg) and is_instance_valid(bg.get_parent()):
			bg.queue_free()
		_clear_selection()
	
	# Connect button signals
	merge_btn.pressed.connect(
		func():
			print("Merge button pressed")
			# Double check merge is still valid
			if is_instance_valid(first_unit) and is_instance_valid(second_unit) and \
			   is_instance_valid(first_slot) and is_instance_valid(target_slot) and \
			   first_slot.occupying_unit == first_unit and \
			   target_slot.occupying_unit == second_unit and \
			   first_unit.unit_data.tier < 3 and second_unit.unit_data.tier < 3:
				
				var result_unit_id = UnitLibrary.get_merge_result_for_units(first_unit.unit_data, second_unit.unit_data)
				if result_unit_id:
					print("Performing merge")
					_perform_merge(first_unit, second_unit, target_slot, result_unit_id)
			cleanup.call()
	)
	
	swap_btn.pressed.connect(
		func():
			print("Swap button pressed")
			if is_instance_valid(first_unit) and is_instance_valid(second_unit) and \
			   is_instance_valid(first_slot) and is_instance_valid(target_slot) and \
			   first_slot.occupying_unit == first_unit and target_slot.occupying_unit == second_unit:
				_attempt_swap_units(first_unit, first_slot, second_unit, target_slot)
			cleanup.call()
	)
	
	# Close when clicking outside
	bg.gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				cleanup.call()
	)

# --- Core Logic for Movement and Swapping ---
func _handle_second_click(target_slot: UnitSlot, target_unit: Unit) -> void:
	print("\n=== HANDLE SECOND CLICK ===")
	print("Selected unit: ", selected_unit.unit_data.id if selected_unit and selected_unit.unit_data else "No selected unit")
	print("Target unit: ", target_unit.unit_data.id if target_unit and target_unit.unit_data else "No target unit")
	print("Target slot: ", target_slot.name if target_slot else "No target slot")
	
	if not selected_slot or not selected_unit or not is_instance_valid(selected_unit):
		print("No valid selection, deselecting")
		_deselect_current_unit()
		return

	# If clicked on empty slot, move the unit there
	if target_slot.is_empty():
		print("Target slot is empty, attempting move")
		_attempt_move_to_empty_slot(selected_unit, selected_slot, target_slot)
		_clear_selection()
		return

	# If clicked on another unit
	if target_unit and target_unit != selected_unit:
		print("Target is another unit, checking team")
		# Check if both units are on the same team
		if selected_unit.is_player_team_unit != target_unit.is_player_team_unit:
			print("Different teams, cannot interact")
			add_log_message("Cannot interact with enemy units!")
			_clear_selection()
			return
		
		print("Same team, checking merge possibility")
		# Store references before any potential clearing
		var first_unit = selected_unit
		var first_slot = selected_slot
		
		# Check if units can be merged
		var result_unit_id = UnitLibrary.get_merge_result_for_units(first_unit.unit_data, target_unit.unit_data)
		print("Merge result unit ID: ", result_unit_id)
		
		if result_unit_id:
			# Show merge/swap popup - don't clear selection yet
			print("Can merge, showing popup")
			show_merge_swap_popup(first_unit, target_unit, target_slot)
		else:
			# If merge not possible, swap the units
			print("Cannot merge, attempting swap")
			_attempt_swap_units(first_unit, first_slot, target_unit, target_slot)
			_clear_selection()

# --- EventBus Handlers for Unit/Slot Interaction ---
func _input(event: InputEvent) -> void:
	print("\n=== INPUT DETECTED ===")
	print("Selected unit: ", selected_unit.unit_data.id if selected_unit and selected_unit.unit_data else "No selected unit")
	print("Awaiting merge confirmation: ", is_awaiting_merge_confirmation)
	
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
		
	if selected_unit and not is_awaiting_merge_confirmation:
		var mouse_pos = get_global_mouse_position()
		print("Mouse position: ", mouse_pos)
		
		# Don't clear if clicking on the selected unit
		if is_instance_valid(selected_unit) and selected_unit.get_global_rect().has_point(mouse_pos):
			print("Clicked on selected unit, not clearing selection")
			return
			
		# Don't clear if clicking on another unit
		for unit in player_units:
			if unit != selected_unit and is_instance_valid(unit) and unit.get_global_rect().has_point(mouse_pos):
				print("Clicked on another unit, not clearing selection")
				return
				
		for slot in player_lineup_slots:
			if slot != selected_slot and is_instance_valid(slot) and slot.get_global_rect().has_point(mouse_pos):
				print("Clicked on a slot, not clearing selection")
				return
		
		# If we got here, we clicked outside any unit or slot
		print("Clicked outside units and slots, clearing selection")
		_clear_selection()
	else:
		print("No selection or awaiting merge confirmation, not clearing")

func _on_unit_selected_for_action(clicked_unit: Unit) -> void:
	print("\n=== UNIT SELECTED FOR ACTION ===")
	print("Clicked unit: ", clicked_unit.unit_data.id if clicked_unit and clicked_unit.unit_data else "No unit data")
	print("Selected unit: ", selected_unit.unit_data.id if selected_unit and selected_unit.unit_data else "No selected unit")
	
	if not is_instance_valid(clicked_unit):
		print("Clicked unit is not valid, returning")
		return
		
	if not is_player_turn or is_awaiting_merge_confirmation:
		print("Not player's turn or awaiting merge confirmation, returning")
		return

	var clicked_slot = _get_slot_for_unit(clicked_unit)
	print("Clicked slot: ", clicked_slot.name if clicked_slot else "No slot found")
	
	if not clicked_slot:
		print("No valid slot found, clearing selection")
		_clear_selection()
		return

	# If we have a selected unit and we're clicking a different unit
	if selected_unit and selected_unit != clicked_unit:
		print("Second unit clicked, handling second click")
		_handle_second_click(clicked_slot, clicked_unit)
		return

	# Handle single click on already selected unit (show inspection)
	if selected_unit == clicked_unit:
		print("Same unit clicked again, showing inspection")
		show_unit_inspection(clicked_unit)
		_clear_selection()
	else:
		print("First selection - setting new selection")
		# First selection - clear any existing selection first
		_clear_selection()
		
		# Set new selection
		selected_unit = clicked_unit
		selected_slot = clicked_slot
		print("New selection - Unit: ", selected_unit.unit_data.id if selected_unit.unit_data else "No unit data", ", Slot: ", selected_slot.name if selected_slot else "No slot")
		
		# Update visuals
		if selected_unit.has_method("set_selected"):
			selected_unit.set_selected(true)
		
		if selected_slot and selected_slot.has_method("set_highlight"):
			selected_slot.set_highlight("selected")
			_update_merge_highlights(clicked_unit)

func _on_slot_clicked_for_action(clicked_slot: UnitSlot) -> void:
	print("\n=== SLOT CLICKED ===")
	print("Valid slot: ", is_instance_valid(clicked_slot))
	print("Player turn: ", is_player_turn)
	print("Awaiting merge confirmation: ", is_awaiting_merge_confirmation)
	
	if not is_instance_valid(clicked_slot):
		print("Invalid slot - ignoring click")
		return
		
	if not is_player_turn:
		print("Not player's turn - ignoring click")
		return
		
	if is_awaiting_merge_confirmation:
		print("Already processing a merge - ignoring click")
		return

	# If we have a selected unit, handle the slot click
	if selected_unit:
		print("Has selected unit: ", selected_unit.unit_data.id if selected_unit.unit_data else "No unit data")
		# Ensure the clicked slot is a player-controllable slot
		if not clicked_slot.is_player_slot:
			print("Clicked enemy slot - ignoring")
			add_log_message("Cannot interact with enemy slots directly.")
			_clear_selection()
			return

		add_log_message("Player slot clicked: %s. Selected unit: %s" % [clicked_slot.slot_id, selected_unit.get_name_for_log()])

		if clicked_slot == selected_slot:
			print("Clicked same slot - showing inspection")
			# Clicked the same slot - show inspection modal
			show_unit_inspection(selected_unit)
			_deselect_current_unit()
		elif clicked_slot.is_empty():
			print("Clicked empty slot - attempting move")
			# Clicked an empty slot - move unit there
			_attempt_move_to_empty_slot(selected_unit, selected_slot, clicked_slot)
			_deselect_current_unit()
		elif is_instance_valid(clicked_slot.occupying_unit):
			print("Clicked occupied slot - checking merge possibility")
			var target_unit = clicked_slot.occupying_unit
			print("Target unit: ", target_unit.unit_data.id if target_unit.unit_data else "No unit data")
			print("Selected unit tier: ", selected_unit.unit_data.tier if selected_unit.unit_data else "No unit data")
			print("Target unit tier: ", target_unit.unit_data.tier if target_unit.unit_data else "No unit data")
			
			if target_unit.unit_data.tier == selected_unit.unit_data.tier and target_unit.unit_data.tier < 3:  # Max tier is 3
				print("Merge condition met - showing popup")
				print("Unit 1: ", selected_unit.unit_data.id, " Tier: ", selected_unit.unit_data.tier)
				print("Unit 2: ", target_unit.unit_data.id, " Tier: ", target_unit.unit_data.tier)
				# Same tier - show merge/swap popup
				show_merge_swap_popup(selected_unit, target_unit, clicked_slot)
			else:
				print("Merge condition not met - tiers don't match or max tier reached")
				# Different tiers or max tier - just swap
				_attempt_swap_units(selected_unit, selected_slot, target_unit, clicked_slot)
				_deselect_current_unit()
	else:
		# No unit selected, select the unit in the clicked slot if there is one
		if clicked_slot.occupying_unit and clicked_slot.is_player_slot:
			selected_unit = clicked_slot.occupying_unit
			selected_slot = clicked_slot
			selected_slot.set_highlight("selected")
			_update_merge_highlights(selected_unit)
		else:
			# Clicked empty slot with no selection - deselect
			_deselect_current_unit()


func _show_merge_confirmation(unit1: Unit, unit2: Unit, target_slot: UnitSlot, result_unit_id: String) -> void:
	var result_data = UnitLibrary.get_unit_data(result_unit_id)
	if not result_data:
		_deselect_current_unit()
		return

	# Store merge info for confirmation
	pending_merge_slot = target_slot
	is_awaiting_merge_confirmation = true

	# Show confirmation dialog (you'll need to implement this in your UI)
	# For now, we'll auto-confirm after a short delay
	await get_tree().create_timer(0.5).timeout
	_perform_merge(unit1, unit2, target_slot, result_unit_id)

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

func _clear_selection() -> void:
	# Clear highlights from selected unit
	if selected_unit and is_instance_valid(selected_unit):
		if selected_unit.has_method("set_selected"):
			selected_unit.set_selected(false)
		elif selected_unit.has_method("update_selection_visual"):
			selected_unit.update_selection_visual(false)
	
	# Clear highlights from selected slot
	if selected_slot and is_instance_valid(selected_slot):
		if selected_slot.has_method("set_highlight"):
			selected_slot.set_highlight("")
	
	# Clear all references
	var was_selected = selected_unit != null
	selected_unit = null
	selected_slot = null
	is_awaiting_merge_confirmation = false
	pending_merge_slot = null
	
	# Clear any merge highlights from all slots
	for slot in player_lineup_slots:
		if slot and is_instance_valid(slot) and slot.has_method("set_highlight"):
			slot.set_highlight("")
	
	# Update UI if we had a selection
	if was_selected:
		add_log_message("Selection cleared")

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
func _on_unit_health_changed(unit: Object, new_health: int, old_health: int, max_health: int) -> void:
	# Update health display if needed
	print("Unit health changed: ", unit.unit_data.id if unit.unit_data else "Unknown", " from ", old_health, " to ", new_health)

func _on_turn_ended(turn_owner: String) -> void:
	print("Turn ended for: ", turn_owner)
	# Handle turn end logic here
	if turn_owner == "player":
		# Start enemy turn
		is_player_turn = false
		# Add any enemy turn logic here
	else:
		# Start player turn
		is_player_turn = true
		# Add any player turn start logic here

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
		_deselect_current_unit()

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
