@tool
class_name EncounterDefinition extends Resource

## Unique identifier for this encounter
@export var id: StringName

## Localization key for the encounter's name
@export var display_name_key: String

## Array of enemy unit placements with format:
## {
##     "id": StringName,      # Enemy unit definition ID
##     "position": int,       # Battlefield position (0-based)
##     "level": int,          # Unit level
##     "equipment": Array[    # Optional equipment for this unit
##         {
##             "id": StringName,  # Item definition ID
##             "level": int       # Item level
##         }
##     ]
## }
@export var enemy_placements: Array[Dictionary] = []

## Default AI behavior for enemies
@export var ai_behavior: StringName

## Battlefield environment/theme
@export var environment: StringName

## Background image for the battle
@export var background: Texture2D

## Music track to play during battle
@export var music_track: StringName

## Whether this is a boss encounter
@export var is_boss: bool = false

## Guaranteed rewards for victory
@export var victory_rewards: Array[RewardDefinition]

## Possible additional rewards
@export var possible_rewards: Array[RewardDefinition]

## Enemy trinket IDs for this encounter
@export var enemy_trinket_ids: Array[StringName] = []
