# res://scripts/GachaBallInstance.gd
class_name GachaBallInstance
extends Resource



## A unique, individual instance of a GachaBall. Its state is defined by its properties.

# --- Core Properties ---
var definition_id: StringName
var ball_uuid: String
var origin_uuid: String = "" # UUID of the permanent instance this battle copy was created from.

# --- State Properties ---
var current_hp: int
var current_pwr: int

# --- Location Properties (for temporary battle state) ---
var location_container_tag: StringName = &""
var location_slot_index: int = -1

# --- Relationship Properties ---
var equipped_on_uuid: String = ""
var equipped_slot_index: int = -1
# Up to 3 equipped items (by UUID). Empty string indicates empty slot.
var equipped_item_uuids: Array[String] = ["", "", ""]

# --- Dynamic State Properties ---
var dynamic_tags: Array[StringName] = [] # For status effects like "POISONED", "HONEY_ARMOR"

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
	
	# Assign new unique ID for the battle context
	copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	copy.origin_uuid = self.ball_uuid # Link back to the original

	# CRITICAL: Explicitly copy the definition ID.
	copy.definition_id = self.definition_id

	# Copy stats 
	copy.current_hp = self.current_hp
	copy.current_pwr = self.current_pwr
	# Copy equipment state
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
	self.current_hp += item_def.bonus_hp
	self.current_pwr += item_def.bonus_pwr
	SignalBus.emit_signal("unit_stats_changed", self.ball_uuid)

func unequip_item_bonus(item_instance: GachaBallInstance) -> void:
	if not is_instance_valid(item_instance): return
	var item_def = item_instance.get_definition()
	if not is_instance_valid(item_def): return
	self.current_hp -= item_def.bonus_hp
	self.current_pwr -= item_def.bonus_pwr
	SignalBus.emit_signal("unit_stats_changed", self.ball_uuid)

# --- Stat Management ---
func set_current_hp(new_hp: int) -> void:
	if self.current_hp != new_hp:
		self.current_hp = new_hp
		SignalBus.emit_signal("unit_stats_changed", self.ball_uuid)

func set_current_hp_silent(new_hp: int) -> void:
	# Update HP without emitting UI signals. Used during simulation passes.
	self.current_hp = new_hp

func reset_battle_stats() -> void:
	var definition = get_definition()
	if not is_instance_valid(definition):
		return
	self.current_hp = definition.base_hp
	self.current_pwr = definition.base_pwr

# --- Stat Recalculation ---
func recalculate_stats(all_instances_db: Dictionary) -> void:
	var definition = get_definition()
	if not is_instance_valid(definition):
		return

	var previous_hp = self.current_hp
	var previous_pwr = self.current_pwr

	# Calculate new effective maximum stats (base + item bonuses)
	var _effective_max_hp = definition.base_hp  # Not used after fix, but kept for future reference
	var effective_max_pwr = definition.base_pwr

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
	var new_hp = previous_hp  # Preserve current HP (can exceed max due to healing effects)
	var new_pwr = min(previous_pwr, effective_max_pwr)  # Clamp PWR to effective maximum

	self.current_hp = new_hp
	self.current_pwr = new_pwr

	SignalBus.emit_signal("unit_stats_changed", self.ball_uuid)

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
	if is_instance_valid(def) and def.tags.has(tag):
		return true
	# Then check dynamic tags on this instance.
	return dynamic_tags.has(tag)

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

# --- Utilities ---
func get_definition() -> GachaBallDefinition:
	return Database.get_definition(definition_id)
