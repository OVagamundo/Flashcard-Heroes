# res://scripts/TrinketDefinition.gd
@tool
class_name TrinketDefinition
extends WeightableEntity

@export var name_key: String
@export var description_key: String
@export var icon: Texture2D
@export var category: StringName = &"TRINKET"
@export var is_player_exclusive: bool = false
@export var is_enemy_exclusive: bool = false
@export var linked_trait_id: StringName = &""
const DEFAULT_TRINKET_COST: int = 10

@export var ability_definitions: Array[AbilityDefinition]

## Budget cost for encounter generation and shop valuation.
var cost: int:
	get:
		return DEFAULT_TRINKET_COST

func meets_prerequisites(run_state) -> bool:
	if run_state is DirectorRunState:
		if run_state.excluded_entity_ids.has(id):
			return false
	return super(run_state)
