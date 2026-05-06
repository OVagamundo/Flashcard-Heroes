# res://scripts/GachaBallInstance.gd
class_name GachaBallInstance
extends Resource


## A unique, individual instance of a GachaBall. Its state is defined by its properties.

# --- Core Properties ---
var definition_id: StringName
var ball_uuid: String
var origin_uuid: String = "" # UUID of the permanent instance this battle copy was created from.
var variant_id: StringName = &"" # Unique instance variant (e.g. &"prismatic")

# --- State Properties ---
var current_hp: int
var current_pwr: int

# --- Permanent Progression Properties ---
var base_hp_modifier: int = 0
var base_pwr_modifier: int = 0

# --- Location Properties (for temporary battle state) ---
var location_container_tag: StringName = &""
var location_slot_index: int = -1

# --- Relationship Properties ---
var equipped_on_uuid: String = ""
var equipped_slot_index: int = -1
# Equipped items (by UUID). Units currently support a single slot.
var equipped_item_uuids: Array[String] = []

# --- Dynamic State Properties ---
var dynamic_tags: Array[StringName] = [] # For status effects like "POISONED", "HONEY_ARMOR"
var status_effects: Dictionary = {} # Key: StringName (effect_id), Value: int (stack_count)

# --- Abilities ---
var abilities: Array[AbilityDefinition] = []

# --- Initialization ---
func initialize(definition: GachaBallDefinition) -> void:
	if not is_instance_valid(definition):
		return

	self.definition_id = definition.id
	self.ball_uuid = UUIDUtils.generate_uuid(definition.id)
	self.abilities = definition.ability_definitions.duplicate(true) # Deep copy
	self.current_hp = definition.base_hp
	self.current_pwr = definition.base_pwr

	# Initialize equipment state
	self.equipped_on_uuid = ""
	self.equipped_slot_index = -1
	self.equipped_item_uuids.clear()
	self.equipped_item_uuids.resize(definition.item_slot_count)
	self.equipped_item_uuids.fill("")

# --- Cloning ---
func create_battle_copy() -> GachaBallInstance:
	var copy = self.duplicate(false) # Shallow copy of value types
	var definition = get_definition()
	if not is_instance_valid(definition):
		return null

	# Deep copy mutable types
	copy.abilities = self.abilities.duplicate(true)
	copy.dynamic_tags = self.dynamic_tags.duplicate(true)
	copy.status_effects = self.status_effects.duplicate(true)
	copy.variant_id = self.variant_id
	
	# Copy progression modifiers
	copy.base_hp_modifier = self.base_hp_modifier
	copy.base_pwr_modifier = self.base_pwr_modifier
	
	# Assign new unique ID for the battle context
	copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	copy.origin_uuid = self.ball_uuid # Link back to the original

	# CRITICAL: Explicitly copy the definition ID.
	copy.definition_id = self.definition_id

	# Reset to base stats from definition (ignoring any changes from previous battles)
	var def = get_definition()
	if is_instance_valid(def):
		if def is GachaBallDefinition:
			copy.current_hp = def.base_hp + copy.base_hp_modifier
			copy.current_pwr = def.base_pwr + copy.base_pwr_modifier
		elif "base_hp" in def and "base_pwr" in def:
			copy.current_hp = def.base_hp + copy.base_hp_modifier
			copy.current_pwr = def.base_pwr + copy.base_pwr_modifier
		else:
			copy.current_hp = 0
			copy.current_pwr = 0
	else:
		copy.current_hp = self.current_hp
		copy.current_pwr = self.current_pwr
	
	# Copy equipment state - equipment bonuses will be applied when recalculate_stats is called
	copy.equipped_on_uuid = self.equipped_on_uuid
	copy.equipped_slot_index = self.equipped_slot_index
	copy.equipped_item_uuids = self.equipped_item_uuids.duplicate()

	return copy


# --- Trinket Initialization ---
# Initialize this instance from a TrinketDefinition (no base stats, no item slots).
# Copies ability_definitions into abilities so AbilityResolver can process them.
func initialize_from_trinket(trinket_def: Resource) -> void:
	if not is_instance_valid(trinket_def):
		return
	# Use the trinket's id as definition_id so Database.get_definition can resolve metadata if needed.
	self.definition_id = trinket_def.id if "id" in trinket_def else &""
	self.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	# Copy ability definitions directly onto the instance abilities array
	if "ability_definitions" in trinket_def and trinket_def.ability_definitions != null:
		self.abilities = trinket_def.ability_definitions.duplicate(true)
	else:
		self.abilities = []
	# Neutralize stats and equipment for trinkets
	self.current_hp = 0
	self.current_pwr = 0
	self.equipped_on_uuid = ""
	self.equipped_slot_index = -1
	self.equipped_item_uuids.clear()
	# Initialize location properties to avoid validation errors
	self.location_container_tag = &""
	self.location_slot_index = -1

# --- Equipment Stat Modification ---
func equip_item_bonus(item_instance: GachaBallInstance) -> void:
	if not is_instance_valid(item_instance): return
	var item_def = item_instance.get_definition()
	if not is_instance_valid(item_def): return
	var old_hp = self.current_hp
	var old_pwr = self.current_pwr
	self.current_hp += item_def.bonus_hp
	self.current_pwr += item_def.bonus_pwr
	if item_def.bonus_hp != 0:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", old_hp, self.current_hp)
	if item_def.bonus_pwr != 0:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"pwr", old_pwr, self.current_pwr)

func unequip_item_bonus(item_instance: GachaBallInstance) -> void:
	if not is_instance_valid(item_instance): return
	var item_def = item_instance.get_definition()
	if not is_instance_valid(item_def): return
	var old_hp = self.current_hp
	var old_pwr = self.current_pwr
	self.current_hp -= item_def.bonus_hp
	self.current_pwr -= item_def.bonus_pwr
	if item_def.bonus_hp != 0:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", old_hp, self.current_hp)
	if item_def.bonus_pwr != 0:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"pwr", old_pwr, self.current_pwr)

# --- Stat Management ---
func set_current_hp(new_hp: int) -> void:
	var old_hp = self.current_hp
	if old_hp != new_hp:
		self.current_hp = new_hp
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", old_hp, new_hp)

func set_current_hp_silent(new_hp: int) -> void:
	# Update HP without emitting UI signals. Used during simulation passes.
	self.current_hp = new_hp

func set_current_pwr_silent(new_pwr: int) -> void:
	# Update PWR without emitting UI signals. Used during simulation passes.
	self.current_pwr = new_pwr

func reset_battle_stats() -> void:
	# Store old values for granular signal
	var old_hp = current_hp
	var old_pwr = current_pwr
	
	# Restore HP and PWR to base values (without equipment bonuses)
	var definition = get_definition()
	if is_instance_valid(definition):
		if definition is GachaBallDefinition:
			current_hp = definition.base_hp + base_hp_modifier
			current_pwr = definition.base_pwr + base_pwr_modifier
		elif "base_hp" in definition and "base_pwr" in definition:
			# Non-unit definitions (items, trinkets) may have 0 HP/PWR
			current_hp = definition.base_hp + base_hp_modifier
			current_pwr = definition.base_pwr + base_pwr_modifier
		else:
			current_hp = 0
			current_pwr = 0
	
	# Clear all status effects (poison, etc.)
	status_effects.clear()
	
	# Reset dynamic tags
	dynamic_tags.clear()
	
	# Emit granular signals for each stat that changed
	if old_hp != current_hp:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", old_hp, current_hp)
	if old_pwr != current_pwr:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"pwr", old_pwr, current_pwr)

func reset_battle_stats_silent() -> void:
	# Restore HP and PWR to base values (without equipment bonuses) - SILENT VERSION
	var definition = get_definition()
	if is_instance_valid(definition):
		if definition is GachaBallDefinition:
			current_hp = definition.base_hp + base_hp_modifier
			current_pwr = definition.base_pwr + base_pwr_modifier
		elif "base_hp" in definition and "base_pwr" in definition:
			# Non-unit definitions (items, trinkets) may have 0 HP/PWR
			current_hp = definition.base_hp + base_hp_modifier
			current_pwr = definition.base_pwr + base_pwr_modifier
		else:
			current_hp = 0
			current_pwr = 0
	
	# Clear all status effects (poison, etc.)
	status_effects.clear()
	
	# Reset dynamic tags
	dynamic_tags.clear()

# --- Stat Recalculation ---
func recalculate_stats(all_instances_db: Dictionary) -> void:
	var definition = get_definition()
	if not is_instance_valid(definition):
		return

	var previous_hp = self.current_hp
	var previous_pwr = self.current_pwr

	# Calculate new effective maximum stats (base + item bonuses)
	var _effective_max_hp = 0
	var effective_max_pwr = 0
	
	if definition is GachaBallDefinition:
		_effective_max_hp = definition.base_hp + base_hp_modifier
		effective_max_pwr = definition.base_pwr + base_pwr_modifier
	elif "base_hp" in definition and "base_pwr" in definition:
		_effective_max_hp = definition.base_hp + base_hp_modifier
		effective_max_pwr = definition.base_pwr + base_pwr_modifier


	# Add bonuses from each equipped item by looking up its UUID in the provided database.
	for item_uuid in equipped_item_uuids:
		if not item_uuid.is_empty():
			var item_instance: GachaBallInstance = all_instances_db.get(item_uuid)
			if is_instance_valid(item_instance):
				var item_def = item_instance.get_definition()
				if is_instance_valid(item_def):
					_effective_max_hp += item_def.bonus_hp
					effective_max_pwr += item_def.bonus_pwr

	# Preserve current HP/PWR - only clamp PWR to maximum, allow HP to exceed max due to healing
	var new_hp = previous_hp # Preserve current HP (can exceed max due to healing effects)
	var new_pwr = previous_pwr # Allow PWR to scale indefinitely (needed for merge logic)

	self.current_hp = new_hp
	self.current_pwr = new_pwr

	# Emit granular signals
	if previous_hp != current_hp:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", previous_hp, current_hp)
	if previous_pwr != current_pwr:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"pwr", previous_pwr, current_pwr)

# --- Tag Helpers ---
func add_tag(tag: StringName) -> void:
	if not dynamic_tags.has(tag):
		dynamic_tags.append(tag)

func remove_tag(tag: StringName) -> void:
	if dynamic_tags.has(tag):
		dynamic_tags.erase(tag)

func has_tag(tag: StringName) -> bool:
	# Check static tags on the definition first.
	var def = get_definition()
	if is_instance_valid(def) and "tags" in def and def.tags.has(tag):
		return true
	# Then check dynamic tags on this instance.
	return dynamic_tags.has(tag)

# --- Status Effect Helpers ---
func add_status_effect(effect_id: StringName, amount: int) -> void:
	if amount == 0: return
	
	var current = status_effects.get(effect_id, 0)
	var new_amount = current + amount
	
	if new_amount <= 0:
		status_effects.erase(effect_id)
		new_amount = 0
	else:
		status_effects[effect_id] = new_amount
		
	# Emit granular signal with stat name like "armor_stacks", "burn_stacks"
	var stat_name = StringName(String(effect_id) + "_stacks")
	SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, stat_name, current, new_amount)

func add_status_effect_silent(effect_id: StringName, amount: int) -> void:
	# Update status effect without emitting UI signals. Used during simulation.
	if amount == 0: return
	
	var current = status_effects.get(effect_id, 0)
	var new_amount = current + amount
	
	if new_amount <= 0:
		status_effects.erase(effect_id)
	else:
		status_effects[effect_id] = new_amount

func get_status_effect_amount(effect_id: StringName) -> int:
	return status_effects.get(effect_id, 0)

func clear_status_effect(effect_id: StringName) -> void:
	var current = status_effects.get(effect_id, 0)
	if current > 0:
		status_effects.erase(effect_id)
		# Emit granular signal with stat name like "armor_stacks", "burn_stacks"
		var stat_name = StringName(String(effect_id) + "_stacks")
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, stat_name, current, 0)

# --- Location Helpers ---
# Assembles the definitive location of this instance based on its state.
# This is the single source of truth for an instance's location.
func get_location() -> LocationIdentifier:
	var loc = LocationIdentifier.new()
	
	# If an item is equipped, its location is defined by its parent unit.
	if not equipped_on_uuid.is_empty():
		loc.container = C.CONTAINER_EQUIPPED_ITEM
		loc.unit_uuid = equipped_on_uuid
		loc.index = equipped_slot_index
	# Otherwise, its location is defined by the container it's in.
	else:
		loc.container = location_container_tag
		loc.index = location_slot_index
		
	return loc

# --- Equipment Helpers ---
# Returns the UUID of the item equipped in the given slot (0-2). Returns an
# empty string if the slot is out of range or empty.
func get_equipped_item_uuid(slot_index: int) -> String:
	if slot_index >= 0 and slot_index < equipped_item_uuids.size():
		return equipped_item_uuids[slot_index]
	return ""

# --- Abilities Helpers ---
# Safely retrieve an ability definition by index. Returns null if the index is
# out of bounds or the slot is empty.
func get_ability(index: int) -> AbilityDefinition:
	if abilities == null:
		return null
	if index >= 0 and index < abilities.size():
		return abilities[index]
	return null

# --- Serialization ---
## Converts this instance to a Dictionary for saving.
func to_save_dict() -> Dictionary:
	return {
		"definition_id": String(definition_id),
		"ball_uuid": ball_uuid,
		"origin_uuid": origin_uuid,
		"current_hp": current_hp,
		"current_pwr": current_pwr,
		"base_hp_modifier": base_hp_modifier,
		"base_pwr_modifier": base_pwr_modifier,
		"location_container_tag": String(location_container_tag),
		"location_slot_index": location_slot_index,
		"equipped_on_uuid": equipped_on_uuid,
		"equipped_slot_index": equipped_slot_index,
		"equipped_item_uuids": equipped_item_uuids.duplicate(),
		"dynamic_tags": _serialize_tags(),
		"status_effects": status_effects.duplicate(),
		"variant_id": String(variant_id),
	}

## Restores this instance from a saved Dictionary.
func from_save_dict(data: Dictionary) -> void:
	definition_id = StringName(data.get("definition_id", ""))
	ball_uuid = data.get("ball_uuid", "")
	origin_uuid = data.get("origin_uuid", "")
	current_hp = data.get("current_hp", 0)
	current_pwr = data.get("current_pwr", 0)
	base_hp_modifier = data.get("base_hp_modifier", 0)
	base_pwr_modifier = data.get("base_pwr_modifier", 0)
	location_container_tag = StringName(data.get("location_container_tag", ""))
	location_slot_index = data.get("location_slot_index", -1)
	equipped_on_uuid = data.get("equipped_on_uuid", "")
	equipped_slot_index = data.get("equipped_slot_index", -1)
	
	# Restore equipped_item_uuids
	var saved_items: Array = data.get("equipped_item_uuids", [])
	equipped_item_uuids.clear()
	for item_uuid in saved_items:
		equipped_item_uuids.append(str(item_uuid))
	
	_deserialize_tags(data.get("dynamic_tags", []))
	
	# Restore status effects
	var saved_effects: Dictionary = data.get("status_effects", {})
	status_effects.clear()
	for key in saved_effects.keys():
		status_effects[StringName(str(key))] = saved_effects[key]
	
	variant_id = StringName(data.get("variant_id", ""))
	
	# Re-initialize abilities from definition
	var def = get_definition()
	if is_instance_valid(def) and "ability_definitions" in def and def.ability_definitions != null:
		abilities.clear()
		for ability_def in def.ability_definitions:
			abilities.append(ability_def.duplicate())

func _serialize_tags() -> Array:
	var result: Array = []
	for tag in dynamic_tags:
		result.append(String(tag))
	return result

func _deserialize_tags(data: Array) -> void:
	dynamic_tags.clear()
	for tag_str in data:
		dynamic_tags.append(StringName(str(tag_str)))

# --- Utilities ---
func get_definition() -> Resource:
	return Database.get_definition(definition_id)
