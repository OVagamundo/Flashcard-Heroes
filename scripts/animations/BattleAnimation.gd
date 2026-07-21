class_name BattleAnimation
extends RefCounted

## Base class for all combat animations.
## Concrete implementations should override execute().

# Execute the animation.
# animator: The BattleAnimator instance (provides context like visual_registry, tree, etc.)
# targets: Array of target UUIDs
# payload: The typed visual payload from the CombatEvent
func execute(_animator: Node, _targets: Array[String], _payload: CombatPayload) -> void:
	push_warning("BattleAnimation.execute() not implemented")
	pass
