@tool
class_name RewardDefinition extends Resource

## Type of reward ("GOLD", "ITEM", "UNIT", "CARD", "UPGRADE")
@export var type: StringName

## Quantity or value of the reward
@export var amount: int

## For ITEM/UNIT rewards, the definition ID
@export var item_id: StringName

## For random rewards, the weights for each rarity
@export var rarity_weights: Dictionary

## Minimum tier for random rewards
@export var min_tier: int = 1

## Maximum tier for random rewards
@export var max_tier: int = 3 
