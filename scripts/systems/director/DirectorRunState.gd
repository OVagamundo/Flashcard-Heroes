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
var unlocked_recipes: Array[String] = []
var encountered_bosses: Array[String] = []

func has_unlocked_recipe(recipe_id: String) -> bool:
    return unlocked_recipes.has(recipe_id)
