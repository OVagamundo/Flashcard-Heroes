<!-- Original: scripts/BattleResult.gd -->

```gdscript
@tool
class_name BattleResult extends Resource

## Whether the player won
@export var victory: bool

## Number of rounds taken
@export var rounds: int

## Number of player units defeated
@export var player_units_lost: int

## Number of enemy units defeated
@export var enemy_units_defeated: int

## Gold earned from the battle
@export var gold_earned: int

## Experience points gained
@export var experience_gained: int

## Item/unit drops from the battle
@export var drops: Array[StringName]

## Any achievements unlocked
@export var achievements: Array[StringName] 
```