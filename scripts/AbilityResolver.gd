# res://scripts/AbilityResolver.gd
extends Node

## A global script that processes ability effects and conditions.
## MVP Scope: This is a placeholder for future implementation.

var ability_queue: Array = []

## MVP Scope Note: This method's logic is commented out for the MVP.
func _apply_effect(_effect_data: Dictionary) -> void:
	# match _effect_data.get("type"):
	# 	"DAMAGE":
	# 		pass
	# 	"HEAL":
	# 		pass
	# 	"APPLY_STATUS":
	# 		pass
	pass

## MVP Scope Note: This method simply clears the queue for the MVP.
func resolve_queue() -> void:
	ability_queue.clear()
