@tool
class_name DirectorRunState
extends RefCounted


enum Purpose {
	ANY,
	ENCOUNTER,
	SHOP,
	REWARD,
	NODE_GENERATION
}

var current_purpose: Purpose = Purpose.ANY

var current_day: int = 1
var player_gold: int = 0
var flashcard_mastery: float = 0.0
var unlock_percentage: float = 0.0
var unlocked_recipes: Array[String] = []
var encountered_bosses: Array[String] = []
var excluded_entity_ids: Array[StringName] = []

func has_unlocked_recipe(recipe_id: String) -> bool:
    return unlocked_recipes.has(recipe_id)

func clear_exclusions() -> void:
    excluded_entity_ids.clear()

func exclude_entity(id: StringName) -> void:
    if not excluded_entity_ids.has(id):
        excluded_entity_ids.append(id)
