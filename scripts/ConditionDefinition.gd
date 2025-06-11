extends Resource
class_name ConditionDefinition

enum ConditionType {
    NONE,
    HAS_TAG,                  # Checks if target has a specific tag
    HAS_STATUS_EFFECT,        # Checks if target has a specific status effect
    HAS_ITEM_EQUIPPED,       # Checks if target has a specific item equipped
    HP_PERCENT_BELOW,        # Current HP % is below value
    HP_PERCENT_ABOVE,        # Current HP % is above value
    RANDOM_CHANCE,           # Random chance based on value (0-1)
    TURN_COUNT_EQUALS,       # Current turn count equals value
    TURN_COUNT_GREATER_THAN, # Current turn count > value
    TURN_COUNT_LESS_THAN,    # Current turn count < value
    HAS_ALLY_WITH_TAG,       # Has at least X allies with tag
    HAS_ENEMY_WITH_TAG,      # Has at least X enemies with tag
    IS_CRITICAL_HIT,         # Current attack is a critical hit
    IS_FRONTLINE,            # Unit is in front 3 positions
    IS_BACKLINE,             # Unit is in back 3 positions
    HAS_ACTIVE_ABILITY,      # Unit has a specific ability ID
    HAS_ACTIVE_EFFECT        # Unit has an effect with specific ID
}

enum ComparisonOperator {
    EQUALS,
    NOT_EQUALS,
    GREATER_THAN,
    LESS_THAN,
    GREATER_THAN_OR_EQUAL,
    LESS_THAN_OR_EQUAL
}

@export var condition_type: ConditionType = ConditionType.NONE
@export var string_value: String = ""
@export var numeric_value: float = 0.0
@export var comparison: ComparisonOperator = ComparisonOperator.EQUALS
@export var secondary_numeric_value: float = 0.0

# The 'evaluate' method is complex and depends on BattleManager.
# It will be fully implemented alongside the AbilityResolver and BattleManager.
func evaluate(source: GachaBallInstance, target: GachaBallInstance, battle_manager, event_data: Dictionary = {}) -> bool:
    # Placeholder logic
    return true
