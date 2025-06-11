extends Resource
class_name SynergyDefinition

@export var tag: StringName # e.g., "Warrior"
@export var tier_thresholds: Array[int] # e.g., [2, 4] for Tier 1 and Tier 2
@export var tier_abilities: Array[Resource] # Array[AbilityDefinition], The abilities granted at each corresponding tier
