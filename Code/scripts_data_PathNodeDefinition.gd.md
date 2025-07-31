<!-- Original: scripts/data/PathNodeDefinition.gd -->

```gdscript
@tool
class_name PathNodeDefinition extends Resource

## The primary type of the node ("BATTLE", "SHOP", "EVENT", "REST")
@export var node_type: StringName

## A variant of the node type ("COMMON", "ELITE", "MINIBOSS", "BOSS", etc.)
@export var subtype: StringName

## Localization key for the node's display name
@export var display_name_key: String

## Localization key for the node's description
@export var description_key: String

## Visual representation of the node on the path
@export var icon: Texture2D

## For "BATTLE" nodes, references an EncounterDefinition
@export var encounter_id: StringName

## Potential rewards for completing this node
@export var rewards: Array[RewardDefinition]

## Relative difficulty level (1-5)
@export var difficulty: int = 1 
```