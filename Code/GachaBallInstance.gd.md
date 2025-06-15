<!-- Original: GachaBallInstance.gd -->

```gdscript
extends Resource
class_name GachaBallInstance

enum LocationState {
	UNDEFINED,
	IN_MASTER_RUN_POOL_TIER_1,
	IN_MASTER_RUN_POOL_TIER_2,
	IN_MASTER_RUN_POOL_TIER_3,
	IN_BATTLE_GACHA_POOL_TIER_1,
	IN_BATTLE_GACHA_POOL_TIER_2,
	IN_BATTLE_GACHA_POOL_TIER_3,
	IN_PLAYER_BENCH,
	IN_PLAYER_LINEUP,
	IN_ENEMY_LINEUP,
	IN_BATTLE_INVENTORY,
	EQUIPPED_ON_UNIT,
	IN_BATTLE_DISCARD_PILE
}

var definition: GachaBallDefinition
var uuid: String
var current_hp: int
var current_pwr: int
var current_location_state: int = LocationState.UNDEFINED
var equipped_item_uuids: Array[String] = []

func _init(p_definition: GachaBallDefinition):
	definition = p_definition
	uuid = _generate_uuid()
	current_hp = definition.base_hp
	current_pwr = definition.base_pwr

# Create a deep copy of this instance for battle use
func create_battle_copy() -> GachaBallInstance:
	var copy = get_script().new(definition)
	copy.current_hp = current_hp
	copy.current_pwr = current_pwr
	copy.equipped_item_uuids = equipped_item_uuids.duplicate()
	return copy

# Helper to generate a unique ID for this instance
func _generate_uuid() -> String:
	return "%s_%s" % [definition.id, str(randi() % 1000000)]

# Take damage and return true if the unit was defeated
func take_damage(amount: int) -> bool:
	current_hp = max(0, current_hp - amount)
	return current_hp <= 0

# Heal the unit (won't exceed max HP)
func heal(amount: int) -> void:
	current_hp = min(definition.base_hp, current_hp + amount)

# Check if this is a unit (as opposed to an item)
func is_unit() -> bool:
	return definition.ball_category == 0  # 0 is UNIT in GachaBallDefinition

# Check if this is an item
func is_item() -> bool:
	return definition.ball_category == 1  # 1 is ITEM in GachaBallDefinition

# Get the display name from the definition
func get_display_name() -> String:
	return definition.display_name_key

# Get the current HP as a string (e.g., "5/10")
func get_hp_string() -> String:
	return "%d/%d" % [current_hp, definition.base_hp]

```